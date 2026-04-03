import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../../core/data/course_data.dart';
import '../../core/services/progress_service.dart';
import '../../core/database/vocab_repository.dart';
import '../../core/models/deck.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/deck_session_service.dart';
import 'widgets/deck_study_bottom_sheet.dart';
import 'vocab_detail_screen.dart';
import '../../core/services/study_service.dart';

/// Unit colors for deck cards — matches grammar_screen._getUnitColor
const _unitColors = [Colors.purple, Colors.blue, Colors.orange, Colors.teal, Colors.red, Colors.indigo, Colors.pink, Colors.cyan, Colors.amber, Colors.deepPurple];

class VocabScreen extends ConsumerStatefulWidget {
  const VocabScreen({super.key});
  @override
  ConsumerState<VocabScreen> createState() => _VocabScreenState();
}

class _VocabScreenState extends ConsumerState<VocabScreen> {
  String _selectedFilter = 'All';

  void _refresh() => setState(() {});

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(initialSyncCompleteProvider);
    final vocabRepo = ref.watch(vocabRepositoryProvider);
    final s = AppStrings(ref.watch(settingsProvider).appLanguage);

    return Scaffold(
        body: FutureBuilder<List<Deck>>(
          future: vocabRepo.getDecks(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Keine Decks gefunden. Erstelle eines!'));
            }

            final allDecks = snapshot.data!;
            final progress = ref.watch(progressProvider);
            final visibleDecks = allDecks.where((d) {
              // Hide ALL kanji-type decks from vocab screen (they belong in Schreiben > Kanji)
              if (d.deckType == DeckType.kanji) return false;
              // Hide sub-decks from top-level list
              if (d.parentDeckId != null) return false;
              // Hide locked unit decks
              if (d.deckType == DeckType.unit && d.parentUnitId != null) {
                final units = CourseData.units;
                final unitIndex = units.indexWhere((u) => u.id == d.parentUnitId);
                if (unitIndex < 0) return false;
                // Unit 0 always visible; others need previous unit completed
                if (unitIndex > 0) {
                  final prevUnit = units[unitIndex - 1];
                  if (prevUnit.lessons.isNotEmpty && !progress.isCompleted(prevUnit.lessons.last.id)) {
                    return false;
                  }
                }
                return true;
              }
              return true;
            }).toList();
            
            final categories = visibleDecks
                .map((d) => d.category)
                .where((c) => c != null && c.trim().isNotEmpty)
                .map((c) => c!)
                .toSet()
                .toList()..sort();

            final filteredDecks = visibleDecks.where((d) {
              if (_selectedFilter == 'All') return true;
              if (_selectedFilter == 'Unit') return d.deckType == DeckType.unit;
              if (_selectedFilter == 'AI') return d.deckType == DeckType.aiChat;
              if (_selectedFilter == 'Custom') return d.deckType == DeckType.custom;
              if (_selectedFilter == 'Manga') return d.deckType == DeckType.manga;
              return d.category == _selectedFilter;
            }).toList();

            return Column(
              children: [
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _buildFilterChip('All', s.all),
                      const SizedBox(width: 8),
                      _buildFilterChip('Unit', s.units),
                      const SizedBox(width: 8),
                      _buildFilterChip('AI', s.ai),
                      const SizedBox(width: 8),
                      _buildFilterChip('Custom', s.custom),
                      const SizedBox(width: 8),
                      _buildFilterChip('Manga', s.manga),
                      for (var cat in categories) ...[
                        const SizedBox(width: 8),
                        _buildFilterChip(cat, cat),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: _buildDeckList(context, vocabRepo, filteredDecks),
                ),
              ],
            );
          },
        ),
        // FAB handled by parent DecksScreen
    );
  }

  void _showDeckActions(BuildContext context, VocabRepository vocabRepo, Deck deck) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(deck.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.list_alt),
              title: Text(deck.deckType == DeckType.unit ? 'Vokabeln anzeigen' : 'Vokabeln anzeigen & bearbeiten'),
              onTap: () async {
                Navigator.pop(ctx);
                await Navigator.push(context, MaterialPageRoute(builder: (_) => VocabDetailScreen(deck: deck)));
                _refresh();
              },
            ),
            ListTile(
              leading: Icon(deck.isSrsEnabled ? Icons.notifications_active : Icons.notifications_off),
              title: Text(deck.isSrsEnabled ? 'Aus SRS entfernen' : 'Zu SRS hinzufügen'),
              subtitle: Text(deck.isSrsEnabled ? 'Nicht mehr im globalen SRS Review' : 'Vokabeln erscheinen im globalen SRS Review'),
              onTap: () async {
                Navigator.pop(ctx);
                await vocabRepo.updateDeck(deck.copyWith(isSrsEnabled: !deck.isSrsEnabled));
                _refresh();
              },
            ),
            if (deck.deckType != DeckType.unit)
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('Kategorie setzen'),
                subtitle: Text(deck.category ?? 'Keine'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCategoryDialog(context, vocabRepo, deck);
                },
              ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Deck klonen'),
              subtitle: const Text('Bearbeitbare Kopie erstellen'),
              onTap: () async {
                Navigator.pop(ctx);
                final nameController = TextEditingController(text: '${deck.name} (Kopie)');
                showDialog(
                  context: context,
                  builder: (dlg) => AlertDialog(
                    title: const Text('Deck klonen'),
                    content: TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Neuer Name')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dlg), child: const Text('Abbrechen')),
                      ElevatedButton(
                        onPressed: () async {
                          await vocabRepo.cloneDeck(deck.id!, nameController.text.trim());
                          if (dlg.mounted) {
                            Navigator.pop(dlg);
                            _refresh();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deck geklont!')));
                            }
                          }
                        },
                        child: const Text('Klonen'),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (deck.deckType != DeckType.unit) ...[
              ListTile(
                leading: const Icon(Icons.publish, color: Colors.blue),
                title: const Text('In Community veröffentlichen'),
                subtitle: const Text('Andere Nutzer können das Deck klonen'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final settings = ref.read(settingsProvider);
                  if (!settings.hasBackend) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backend-URL erforderlich')));
                    return;
                  }
                  try {
                    final vocabs = await vocabRepo.getVocabForDeck(deck.id!);
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('jwt_token') ?? '';
                    final body = {
                      'deck': deck.toMap(),
                      'vocab': vocabs.map((v) => v.toMap()).toList(),
                    };
                    final res = await http.post(
                      Uri.parse('${settings.effectiveBackendUrl}/api/community/publish'),
                      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                      body: jsonEncode(body),
                    ).timeout(const Duration(seconds: 30));
                    if (context.mounted) {
                      if (res.statusCode == 200 || res.statusCode == 201) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deck veröffentlicht!'), backgroundColor: Colors.green));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: ${res.statusCode}'), backgroundColor: Colors.red));
                      }
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.public_off),
                title: const Text('Privat machen'),
                subtitle: const Text('Entfernt das Deck aus der Community'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final settings = ref.read(settingsProvider);
                  if (!settings.hasBackend) return;
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final token = prefs.getString('jwt_token') ?? '';
                    await http.post(
                      Uri.parse('${settings.effectiveBackendUrl}/api/community/unpublish'),
                      headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
                      body: jsonEncode({'name': deck.name}),
                    );
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deck wurde wieder privat.'), backgroundColor: Colors.amber));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
                  }
                },
              ),
            ],
            if (deck.deckType != DeckType.unit) // Can't delete unit decks
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Deck löschen', style: TextStyle(color: Colors.red)),
                subtitle: const Text('Kann nicht rückgängig gemacht werden'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dlg) => AlertDialog(
                      title: const Text('Deck löschen?'),
                      content: Text('"${deck.name}" und alle Vokabeln löschen?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dlg, false), child: const Text('Abbrechen')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(dlg, true),
                          child: const Text('Löschen', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await vocabRepo.deleteDeck(deck.id!);
                    _refresh();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deck gelöscht.')));
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, VocabRepository vocabRepo, Deck deck) {
    final controller = TextEditingController(text: deck.category ?? '');
    showDialog(
      context: context,
      builder: (dlg) => AlertDialog(
        title: const Text('Kategorie'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Kategorie-Name',
                hintText: 'z.B. JLPT, Manga, Arbeit...',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: ['JLPT', 'Manga', 'Arbeit', 'Reise'].map((cat) =>
                ActionChip(label: Text(cat), onPressed: () => controller.text = cat),
              ).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dlg);
              await vocabRepo.updateDeck(deck.copyWith(category: ''));
              _refresh();
            },
            child: const Text('Entfernen'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dlg);
              if (controller.text.trim().isNotEmpty) {
                await vocabRepo.updateDeck(deck.copyWith(category: controller.text.trim()));
                _refresh();
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

  void _showStudyMethodSheet(BuildContext context, VocabRepository vocabRepo, Deck deck) async {
    final vocabList = await vocabRepo.getVocabForDeck(deck.id!);
    if (!context.mounted) return;
    DeckStudyMethodBottomSheet.show(context, deck, vocabList);
  }

  Widget _buildFilterChip(String filter, String label) {
    final isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) { if (val) setState(() => _selectedFilter = filter); },
    );
  }

  Widget _buildDeckList(BuildContext context, VocabRepository vocabRepo, List<Deck> decks) {
    if (decks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.library_books, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'All' ? 'Keine Decks gefunden. Erstelle eines!' : 'Keine Decks in dieser Kategorie.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: decks.length,
      itemBuilder: (context, index) {
        final deck = decks[index];
        
        Color gradientStart, gradientEnd;
        IconData deckIcon;
        switch (deck.deckType) {
          case DeckType.unit:
            final unitColor = _unitColors[index % _unitColors.length];
            gradientStart = unitColor.shade400;
            gradientEnd = unitColor.shade700;
            deckIcon = Icons.school;
            break;
          case DeckType.manga:
            gradientStart = Colors.orange.shade400;
            gradientEnd = Colors.deepOrange.shade600;
            deckIcon = Icons.photo_library;
            break;
          case DeckType.custom:
            gradientStart = Colors.purple.shade400;
            gradientEnd = Colors.deepPurple.shade700;
            deckIcon = Icons.library_books;
            break;
          case DeckType.kanji:
            gradientStart = Colors.teal.shade400;
            gradientEnd = Colors.teal.shade700;
            deckIcon = Icons.translate;
            break;
          case DeckType.aiChat:
            gradientStart = Colors.indigo.shade400;
            gradientEnd = Colors.blue.shade900;
            deckIcon = Icons.auto_awesome;
            break;
        }

        return GestureDetector(
          onTap: () => _showStudyMethodSheet(context, vocabRepo, deck),
          onLongPress: () => _showDeckActions(context, vocabRepo, deck),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background: thumbnail or gradient
                  if (deck.thumbnailPath != null && File(deck.thumbnailPath!).existsSync())
                    Image.file(File(deck.thumbnailPath!), fit: BoxFit.cover)
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [gradientStart, gradientEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  // Dark overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black.withAlpha(180)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(50),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(deckIcon, color: Colors.white, size: 28),
                        ),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                deck.name,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.2),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (deck.description != null && deck.description!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  deck.description!,
                                  style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Progress bar
                  FutureBuilder<List<DeckSession>>(
                    future: ref.read(deckSessionServiceProvider).getSessionsForDeck(deck.id!),
                    builder: (context, sessionSnapshot) {
                      if (!sessionSnapshot.hasData || sessionSnapshot.data!.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      // Show the latest session's progress
                      final latest = sessionSnapshot.data!.first;
                      final total = latest.correctCount + latest.wrongCount;
                      return Positioned(
                        left: 0, right: 0, bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(150),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(24),
                              bottomRight: Radius.circular(24),
                            ),
                          ),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: latest.progressPercent,
                                  backgroundColor: Colors.white24,
                                  color: latest.isCompleted ? Colors.green : Colors.blue,
                                  minHeight: 4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                total > 0 ? '${latest.correctCount}✓ ${latest.wrongCount}✗' : '',
                                style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
