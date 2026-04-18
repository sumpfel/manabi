import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../vocab/vocab_screen.dart';
import '../writing/writing_screen.dart';
import '../../core/services/settings_service.dart';
import '../../core/database/vocab_repository.dart';
import '../../core/services/ai_service.dart';
import '../../core/models/deck.dart';
import '../../core/models/vocab.dart';

class DecksScreen extends ConsumerStatefulWidget {
  const DecksScreen({super.key});

  @override
  ConsumerState<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends ConsumerState<DecksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild to show/hide FAB
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final accentColor = Color(settings.themeColorValue);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        titleSpacing: 0,
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: accentColor,
          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.symmetric(horizontal: 16),
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(color: accentColor, width: 3),
            insets: const EdgeInsets.symmetric(horizontal: 24),
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.style),
              text: 'Vokabeln',
            ),
            Tab(
              icon: Icon(Icons.public),
              text: 'Community',
            ),
            Tab(
              icon: Icon(Icons.gesture),
              text: 'Schreiben',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          VocabScreen(),
          _CommunityDecksBrowser(),
          WritingScreen(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? _VocabFabs(accentColor: accentColor)
          : null,
    );
  }
}

// ── Vocab FABs (Add + AI) ──

class _VocabFabs extends ConsumerWidget {
  final Color accentColor;

  const _VocabFabs({required this.accentColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.extended(
          heroTag: 'vocab_add_deck',
          onPressed: () => _showCreateManualDeckDialog(context, ref),
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Neues Deck', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.grey[700],
        ),
        const SizedBox(height: 8),
        FloatingActionButton.extended(
          heroTag: 'vocab_ai_deck',
          onPressed: () => _showCreateDeckDialog(context, ref),
          icon: const Icon(Icons.auto_awesome, color: Colors.white),
          label: const Text(
            'KI-Deck',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: accentColor,
        ),
      ],
    );
  }

  void _showCreateManualDeckDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neues Deck erstellen'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Deck-Name', hintText: 'z.B. JLPT N5')),
            TextField(controller: descController, decoration: const InputDecoration(labelText: 'Beschreibung (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                final vocabRepo = ref.read(vocabRepositoryProvider);
                await vocabRepo.addDeck(Deck(
                  name: nameController.text.trim(),
                  description: descController.text.trim(),
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                  deckType: DeckType.custom,
                ));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ref.invalidate(decksProvider);
                }
              }
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }

  void _showCreateDeckDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _CreateDeckSheet(),
    );
  }
}

class _CreateDeckSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_CreateDeckSheet> createState() => _CreateDeckSheetState();
}

class _CreateDeckSheetState extends ConsumerState<_CreateDeckSheet> {
  final _themeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('Neues KI-Vokabeldeck', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Beschreibe ein Thema und die KI erstellt ein Deck mit Vokabeln.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _themeController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'z.B. "Essen und Trinken", "Reise und Transport", "Büro-Vokabeln"...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.auto_awesome),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createDeck,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Deck generieren ✨', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createDeck() async {
    if (_themeController.text.trim().isEmpty) {
      setState(() => _error = 'Bitte ein Thema eingeben');
      return;
    }
    setState(() { _isLoading = true; _error = null; });

    try {
      final settings = ref.read(settingsProvider);
      final theme = _themeController.text.trim();

      if (settings.hasAnyAiKey || settings.aiProvider == 'ollama') {
        // Use configured AI provider directly (locally/via proxy)
        await _createDeckWithAi(settings, theme);
      } else {
        setState(() => _error = 'Bitte einen KI-Anbieter in den Einstellungen hinterlegen.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Call the configured AI provider (Gemini / OpenAI / Anthropic) and return
  /// the raw text response, or null on error.
  Future<String?> _callAiProvider(AppSettings settings, String prompt) async {
    try {
      return await ref.read(aiServiceProvider).queryAi(prompt: prompt);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      return null;
    }
  }

  Future<void> _createDeckWithAi(AppSettings settings, String theme) async {
    final motherTongue = settings.motherTongue == 'de' ? 'German' : 'English';
    final prompt = 'Erstelle ein Japanisch-Lern-Vokabeldeck zum Thema "$theme" (Niveau: ${settings.aiLanguageLevel}). '
        'ANTWORTE NUR MIT EINEM JSON-OBJEKT im Format: {"vocab": [{"word": "...", "reading": "...", "translation": "$motherTongue", "example": "...", "example_translation": "$motherTongue"}]}. '
        'REGELN: "word" (Kanji) und "reading" (Kana) MÜSSEN Japanisch sein. BENUTZE UNTER KEINEN UMSTÄNDEN ROMAJI FÜR DIESE FELDER. '
        'Erzeuge 15-20 Wörter. Nur valides JSON, kein Markdown.';

    final text = await _callAiProvider(settings, prompt);
    if (text == null) return;
    // Extract JSON from response (object or array, may be wrapped in markdown)
    final objMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    final arrMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);

    if (objMatch == null && arrMatch == null) {
      setState(() => _error = 'KI-Antwort konnte nicht verarbeitet werden.');
      return;
    }

    final vocabRepo = ref.read(vocabRepositoryProvider);
    int totalCount = 0;

    // Try parsing as structured object first
    if (objMatch != null) {
      try {
        String rawJson = objMatch.group(0)!;
        // Clean up common AI escaping errors
        rawJson = rawJson.replaceAll(r'\"', '"'); 
        final obj = jsonDecode(rawJson) as Map<String, dynamic>;
        final deckName = obj['title'] as String? ?? theme;
        final sections = obj['sections'] as List?;
        final flatWords = (obj['vocab'] ?? obj['words']) as List?;

        final deckId = await vocabRepo.addDeck(Deck(
          name: deckName,
          description: 'KI-generiert: $theme',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          deckType: DeckType.aiChat,
        ));

        Future<void> addWords(List words, int targetDeckId) async {
          for (final v in words) {
            if (v is! Map) continue;
            await vocabRepo.addVocab(Vocab(
              deckId: targetDeckId,
              kanji: v['kanji'] ?? v['word'] ?? v['character'],
              kana: v['kana'] ?? v['reading'] ?? '',
              translation: v['meaning_de'] ?? v['translation_de'] ?? v['translation_en'] ?? v['meaning_en'] ?? v['translation'] ?? '',
              translationDe: v['meaning_de'] ?? v['translation_de'],
              translationEn: v['meaning_en'] ?? v['translation_en'],
              exampleSentence: v['example_sentence'] ?? v['example'],
              exampleTranslationDe: v['example_translation_de'] ?? v['example_translation'],
              exampleTranslationEn: v['example_translation_en'] ?? v['example_translation'],
              dueDate: DateTime.now().millisecondsSinceEpoch,
            ));
            totalCount++;
          }
        }

        if (sections != null && sections.isNotEmpty) {
          // Create sub-decks for each section
          for (final section in sections) {
            if (section is! Map) continue;
            final sectionName = section['name'] as String? ?? 'Sektion';
            final sectionWords = (section['words'] ?? section['vocab']) as List? ?? [];
            final subDeckId = await vocabRepo.getOrCreateSubDeck(deckId, sectionName, DeckType.aiChat);
            await addWords(sectionWords, subDeckId);
          }
        } else {
          // Fallback to flatWords if sections is null
          await addWords(flatWords ?? [], deckId);
        }

        if (mounted) {
          Navigator.pop(context);
          ref.invalidate(decksProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deck "$deckName" mit $totalCount Vokabeln erstellt!'), backgroundColor: Colors.green),
          );
        }
        return;
      } catch (_) {
        // Fall through to array parsing
      }
    }

    // Fallback: parse as flat array
    String rawArr = arrMatch!.group(0)!;
    rawArr = rawArr.replaceAll(r'\"', '"');
    final vocabList = jsonDecode(rawArr) as List;

    final deckId = await vocabRepo.addDeck(Deck(
      name: theme,
      description: 'KI-generiert: $theme',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      deckType: DeckType.aiChat,
    ));

    for (final v in vocabList) {
      if (v is! Map) continue;
      await vocabRepo.addVocab(Vocab(
        deckId: deckId,
        kanji: v['kanji'] ?? v['word'],
        kana: v['kana'] ?? v['reading'] ?? '',
        translation: v['translation_de'] ?? v['meaning_de'] ?? v['translation_en'] ?? v['meaning_en'] ?? v['translation'] ?? '',
        translationDe: v['translation_de'] ?? v['meaning_de'],
        translationEn: v['translation_en'] ?? v['meaning_en'],
        exampleSentence: v['example_sentence'] ?? v['example'],
        exampleTranslationDe: v['example_translation_de'] ?? v['example_translation'],
        exampleTranslationEn: v['example_translation_en'] ?? v['example_translation'],
        dueDate: DateTime.now().millisecondsSinceEpoch,
      ));
    }

    if (mounted) {
      Navigator.pop(context);
      ref.invalidate(decksProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deck "$theme" mit ${vocabList.length} Vokabeln erstellt!'), backgroundColor: Colors.green),
      );
    }
  }
}

// ── Community Decks Browser ──

class _CommunityDecksBrowser extends ConsumerStatefulWidget {
  const _CommunityDecksBrowser();

  @override
  ConsumerState<_CommunityDecksBrowser> createState() => _CommunityDecksBrowserState();
}

class _CommunityDecksBrowserState extends ConsumerState<_CommunityDecksBrowser> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;
  String _filter = 'all'; // 'all', 'vocab', 'kanji', 'official', 'community'

  @override
  void initState() {
    super.initState();
    // Initial fetch from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _search();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final filtered = _applyFilter(_results);

    if (!settings.hasBackend) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.primary.withOpacity(0.5)),
              const SizedBox(height: 16),
              const Text('Community-Decks erfordern eine Verbindung zum Server', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Bitte konfiguriere die Backend-IP in den Profileinstellungen, um Decks zu teilen und herunterzuladen.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to profile/settings - assuming it's available or we can trigger it
                  // For now, let's just show a snackbar or instruction
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil/Einstellungen öffen, um Server-IP einzugeben.')));
                },
                icon: const Icon(Icons.settings),
                label: const Text('Einstellungen öffnen'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Decks durchsuchen...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.search), onPressed: _search),
                  IconButton(icon: const Icon(Icons.refresh), tooltip: 'Neu laden', onPressed: _search),
                ],
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              filled: true,
            ),
            onSubmitted: (_) => _search(),
          ),
        ),
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _filterChip('Alle', 'all'),
              const SizedBox(width: 8),
              _filterChip('Vokabeln', 'vocab'),
              const SizedBox(width: 8),
              _filterChip('Kanji', 'kanji'),
              const SizedBox(width: 8),
              _filterChip('Offiziell', 'official'),
              const SizedBox(width: 8),
              _filterChip('Community', 'community'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.public, size: 48, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                          const SizedBox(height: 12),
                          Text('Keine Decks gefunden', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final deck = filtered[index];
                        final isOfficial = deck['is_official'] == true || deck['official'] == true;
                        final isKanji = deck['type'] == 'kanji';
                        final downloads = deck['downloads'] ?? deck['download_count'] ?? 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isOfficial ? Colors.amber.shade100 : (isKanji ? Colors.purple.shade100 : Colors.blue.shade100),
                              child: Icon(
                                isOfficial ? Icons.verified : (isKanji ? Icons.draw : Icons.style),
                                color: isOfficial ? Colors.amber.shade800 : (isKanji ? Colors.purple : Colors.blue),
                                size: 20,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(deck['name'] ?? 'Unbenannt', style: const TextStyle(fontWeight: FontWeight.bold))),
                                if (isOfficial)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                                    child: Text('Offiziell', style: TextStyle(fontSize: 10, color: Colors.amber.shade800, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(deck['description'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.download, size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text('$downloads', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                    const SizedBox(width: 12),
                                    Icon(isKanji ? Icons.draw : Icons.style, size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(isKanji ? 'Kanji' : 'Vokabeln', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.download, color: Colors.green),
                              tooltip: 'Zu eigenen Decks klonen',
                              onPressed: () => _cloneCommunityDeck(context, deck),
                            ),
                            onTap: () => _previewDeck(context, deck),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : null)),
      selected: isSelected,
      onSelected: (v) => setState(() => _filter = v ? value : 'all'),
      selectedColor: Theme.of(context).primaryColor,
      checkmarkColor: Colors.white,
    );
  }

  List<dynamic> _applyFilter(List<dynamic> decks) {
    return decks.where((d) {
      if (_filter == 'vocab') return d['type'] != 'kanji';
      if (_filter == 'kanji') return d['type'] == 'kanji';
      if (_filter == 'official') return d['is_official'] == true || d['official'] == true;
      if (_filter == 'community') return d['is_official'] != true && d['official'] != true;
      return true;
    }).toList();
  }

  void _previewDeck(BuildContext context, Map<String, dynamic> deck) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(deck['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(deck['description'] ?? '', style: TextStyle(color: Colors.grey[600])),
              if (deck['level'] != null) ...[
                const SizedBox(height: 8),
                Chip(label: Text(deck['level'])),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.download, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text('${deck['downloads'] ?? deck['download_count'] ?? 0} Downloads', style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _cloneCommunityDeck(context, deck);
                  },
                  icon: const Icon(Icons.download),
                  label: const Text('Zu meinen Decks hinzufügen'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cloneCommunityDeck(BuildContext context, Map<String, dynamic> deck) async {
    final vocabRepo = ref.read(vocabRepositoryProvider);
    final settings = ref.read(settingsProvider);
    final isKanji = deck['type'] == 'kanji';
    final isOfficial = deck['is_official'] == true || deck['official'] == true;

    // For official JLPT decks, generate content with AI
    if (isOfficial && settings.hasAnyAiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deck wird mit KI generiert...')),
      );

      try {
        final lang = settings.motherTongue == 'de' ? 'German' : 'English';
        final level = deck['level'] ?? 'N5';
        String prompt;
        if (isKanji) {
          prompt = 'Generate a list of common JLPT $level kanji. Return ONLY a JSON array of objects with: '
              '"character" (single kanji), "onyomi" (on reading in katakana), "kunyomi" (kun reading in hiragana), '
              '"meaning_de" ($lang meaning), "meaning_en" (English meaning). '
              'Generate 30 kanji ordered by frequency. Return ONLY valid JSON, no markdown.';
        } else {
          prompt = 'Generate a list of common JLPT $level vocabulary words. Return ONLY a JSON array of objects with: '
              '"kanji" (kanji if applicable, null otherwise), "kana" (hiragana reading), '
              '"meaning_de" ($lang translation), "meaning_en" (English translation), '
              '"example_sentence" (Japanese example), "example_translation_de" ($lang example translation), '
              '"example_translation_en" (English example translation). '
              'Generate 30 words ordered by frequency. Return ONLY valid JSON, no markdown.';
        }

        final text = await _callAiForCommunity(settings, prompt);
        if (text == null) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KI-Fehler'), backgroundColor: Colors.red));
          return;
        }

        final arrMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
        if (arrMatch == null) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KI-Antwort konnte nicht verarbeitet werden'), backgroundColor: Colors.red));
          return;
        }

        final items = jsonDecode(arrMatch.group(0)!) as List;
        final deckId = await vocabRepo.addDeck(Deck(
          name: deck['name'],
          description: deck['description'],
          createdAt: DateTime.now().millisecondsSinceEpoch,
          deckType: isKanji ? DeckType.kanji : DeckType.custom,
          isOfficial: true,
        ));

        for (final item in items) {
          if (item is! Map) continue;
          if (isKanji) {
            await vocabRepo.addVocab(Vocab(
              deckId: deckId,
              kanji: item['character'] ?? '',
              kana: item['kunyomi'] ?? item['onyomi'] ?? '',
              translation: item['meaning_de'] ?? item['meaning_en'] ?? '',
              translationDe: item['meaning_de'],
              translationEn: item['meaning_en'],
              notes: 'ON: ${item['onyomi'] ?? ''} / KUN: ${item['kunyomi'] ?? ''}',
              dueDate: DateTime.now().millisecondsSinceEpoch,
            ));
          } else {
            await vocabRepo.addVocab(Vocab(
              deckId: deckId,
              kanji: item['kanji'] ?? item['word'] ?? item['character'],
              kana: item['kana'] ?? item['reading'] ?? '',
              translation: item['meaning_de'] ?? item['translation_de'] ?? item['translation_en'] ?? item['meaning_en'] ?? item['translation'] ?? '',
              translationDe: item['meaning_de'] ?? item['translation_de'],
              translationEn: item['meaning_en'] ?? item['translation_en'],
              exampleSentence: item['example_sentence'] ?? item['example'],
              exampleTranslationDe: item['example_translation_de'] ?? item['example_translation'],
              exampleTranslationEn: item['example_translation_en'] ?? item['example_translation'],
              dueDate: DateTime.now().millisecondsSinceEpoch,
            ));
          }
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${deck['name']}" mit ${items.length} Einträgen erstellt!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
        }
      }
    } else if (isOfficial) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen AI API-Key in den Einstellungen hinterlegen um offizielle Decks zu generieren.')),
      );
    } else {
      // Community deck from backend - clone via API
      try {
        final settings = ref.read(settingsProvider);
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token') ?? '';
        final res = await http.post(
          Uri.parse('${settings.effectiveBackendUrl}/api/community/clone/${deck['id']}'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 30));
        
        if (res.statusCode == 200 && context.mounted) {
          final data = jsonDecode(res.body);
          final clonedDeckData = data['deck'];
          final clonedVocabList = data['vocab'] as List;
          
          final localDeckId = await vocabRepo.addDeck(Deck(
            name: clonedDeckData['name'],
            description: clonedDeckData['description'] ?? '',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            deckType: DeckType.custom,
          ));
          
          for (final v in clonedVocabList) {
            await vocabRepo.addVocab(Vocab(
              deckId: localDeckId,
              kanji: v['word_text'],
              kana: v['reading_text'] ?? '',
              translation: v['translation'] ?? '',
              dueDate: DateTime.now().millisecondsSinceEpoch,
            ));
          }
          
          ref.invalidate(decksProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${deck['name']}" lokal gespeichert!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<String?> _callAiForCommunity(AppSettings settings, String prompt) async {
    try {
      return await ref.read(aiServiceProvider).queryAi(prompt: prompt);
    } catch (e) {
      return null;
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    setState(() => _isLoading = true);

    try {
      final settings = ref.read(settingsProvider);
      if (settings.hasBackend) {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('jwt_token') ?? '';
        final res = await http.get(
          Uri.parse('${settings.effectiveBackendUrl}/api/community/search?q=$query&type=deck'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          setState(() {
            _results = data['decks'] ?? [];
            _isLoading = false;
          });
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backend Fehler: ${res.statusCode}')));
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verbindungsfehler: $e')));
      setState(() => _isLoading = false);
    }
  }
}
