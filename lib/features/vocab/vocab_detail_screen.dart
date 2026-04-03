import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../core/database/vocab_repository.dart';
import '../../core/models/deck.dart';
import '../../core/models/vocab.dart';
import '../../core/data/course_data.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/csv_service.dart';
import '../../core/i18n/app_strings.dart';
import 'widgets/deck_study_bottom_sheet.dart';
import '../reader/webview_reader_screen.dart';

class VocabDetailScreen extends ConsumerStatefulWidget {
  final Deck deck;

  const VocabDetailScreen({super.key, required this.deck});

  @override
  ConsumerState<VocabDetailScreen> createState() => _VocabDetailScreenState();
}

class _VocabDetailScreenState extends ConsumerState<VocabDetailScreen> {

  void _refresh() {
    setState(() {});
  }

  bool get _isEditable => widget.deck.deckType != DeckType.unit;

  void _showAddVocabDialog(BuildContext context, VocabRepository repo) {
    final kanaController = TextEditingController();
    final kanjiController = TextEditingController();
    final meaningController = TextEditingController();
    final exampleController = TextEditingController();
    final exampleTranslController = TextEditingController();

    final isKanjiDeck = widget.deck.deckType == DeckType.kanji;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isKanjiDeck ? 'Kanji hinzufügen' : 'Vokabel hinzufügen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: kanjiController,
                  decoration: InputDecoration(labelText: isKanjiDeck ? 'Kanji *' : 'Kanji (Optional)'),
                ),
                TextField(
                  controller: kanaController,
                  decoration: InputDecoration(labelText: isKanjiDeck ? 'Kana (Lesung) (Optional)' : 'Kana (Lesung) *'),
                ),
                TextField(
                  controller: meaningController,
                  decoration: const InputDecoration(labelText: 'Bedeutung (Übersetzung) *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: exampleController,
                  decoration: const InputDecoration(
                    labelText: 'Beispielsatz (Optional)',
                    hintText: 'z.B. 日本語を勉強しています',
                  ),
                ),
                TextField(
                  controller: exampleTranslController,
                  decoration: const InputDecoration(
                    labelText: 'Beispielsatz Übersetzung (Optional)',
                    hintText: 'z.B. Ich studiere Japanisch',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (isKanjiDeck) {
                  if (kanjiController.text.trim().isEmpty || meaningController.text.trim().isEmpty) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kanji und Bedeutung sind erforderlich!')));
                     return;
                  }
                } else {
                  if (kanaController.text.trim().isEmpty || meaningController.text.trim().isEmpty) {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kana und Bedeutung sind erforderlich!')));
                     return;
                  }
                }

                final vocab = Vocab(
                   deckId: widget.deck.id!,
                   kana: kanaController.text.trim().isEmpty ? (kanjiController.text.trim()) : kanaController.text.trim(),
                   kanji: kanjiController.text.trim().isEmpty ? null : kanjiController.text.trim(),
                   translation: meaningController.text.trim(),
                   exampleSentence: exampleController.text.trim().isEmpty ? null : exampleController.text.trim(),
                   exampleTranslation: exampleTranslController.text.trim().isEmpty ? null : exampleTranslController.text.trim(),
                   mangaTitle: 'Custom Added',
                   dueDate: DateTime.now().millisecondsSinceEpoch,
                );

                await repo.addVocab(vocab);
                if (mounted) {
                   Navigator.pop(context);
                   _refresh();
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hinzugefügt!')));
                }
              },
              child: const Text('Hinzufügen'),
            ),
          ],
        );
      },
    );
  }

  void _showAddSubDeckDialog(BuildContext context, VocabRepository repo) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unterkategorie erstellen'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'z.B. Grammatik, Verben, Kapitel 1...',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await repo.getOrCreateSubDeck(
                  widget.deck.id!,
                  nameController.text.trim(),
                  widget.deck.deckType,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _refresh();
              }
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, VocabRepository repo) async {
    final vocabList = await repo.getVocabForDeck(widget.deck.id!);
    if (vocabList.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keine Vokabeln zum Exportieren')));
      return;
    }

    // Column selection state
    final selected = List<bool>.filled(allCsvColumns.length, false);
    // Pre-select common columns
    for (int i = 0; i < allCsvColumns.length; i++) {
      if (['kanji', 'kana', 'translation', 'example_sentence'].contains(allCsvColumns[i].key)) {
        selected[i] = true;
      }
    }
    bool includeHeader = true;

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('CSV Export'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CheckboxListTile(
                  title: const Text('Spaltenüberschriften'),
                  value: includeHeader,
                  onChanged: (v) => setDialogState(() => includeHeader = v ?? true),
                  dense: true,
                ),
                const Divider(),
                const Text('Spalten auswählen & sortieren:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                ...List.generate(allCsvColumns.length, (i) => CheckboxListTile(
                  title: Text(allCsvColumns[i].label, style: const TextStyle(fontSize: 14)),
                  value: selected[i],
                  onChanged: (v) => setDialogState(() => selected[i] = v ?? false),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
            ElevatedButton(
              onPressed: () async {
                final cols = <CsvColumn>[];
                for (int i = 0; i < allCsvColumns.length; i++) {
                  if (selected[i]) cols.add(allCsvColumns[i]);
                }
                if (cols.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mindestens eine Spalte auswählen')));
                  return;
                }
                Navigator.pop(ctx);
                await CsvService.exportToCsv(
                  vocabList: vocabList,
                  columns: cols,
                  includeHeader: includeHeader,
                  deckName: widget.deck.name,
                );
              },
              child: const Text('Exportieren'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importCsv(BuildContext context, VocabRepository repo) async {
    final vocabs = await CsvService.importFromCsv(deckId: widget.deck.id!);
    if (vocabs == null) return; // User cancelled
    if (vocabs.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keine Vokabeln in der CSV-Datei gefunden')));
      return;
    }

    // Ask if user wants to fill missing columns with AI
    final settings = ref.read(settingsProvider);
    final hasMissing = vocabs.any((v) => v.exampleSentence == null || v.translationDe == null || v.translationEn == null);

    bool fillWithAi = false;
    if (hasMissing && settings.hasAnyAiKey && context.mounted) {
      fillWithAi = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Fehlende Spalten mit KI füllen?'),
          content: Text('${vocabs.length} Vokabeln importiert. Einige haben fehlende Felder (Beispielsätze, Übersetzungen). Soll die KI diese ergänzen?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nein')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ja, mit KI füllen')),
          ],
        ),
      ) ?? false;
    }

    // Insert vocabs
    for (final v in vocabs) {
      await repo.addVocab(v);
    }

    if (fillWithAi && context.mounted) {
      _fillMissingWithAi(context, repo, vocabs);
    }

    _refresh();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${vocabs.length} Vokabeln importiert!'), backgroundColor: Colors.green));
    }
  }

  Future<void> _fillMissingWithAi(BuildContext context, VocabRepository repo, List<Vocab> vocabs) async {
    final settings = ref.read(settingsProvider);
    final lang = settings.motherTongue == 'de' ? 'German' : 'English';

    // Build a batch prompt for all vocabs needing data
    final needsFill = vocabs.where((v) => v.exampleSentence == null || v.translationDe == null || v.translationEn == null).toList();
    if (needsFill.isEmpty) return;

    final wordsJson = needsFill.map((v) => '{"kanji":"${v.kanji ?? ""}","kana":"${v.kana}","translation":"${v.translation}"}').join(',');
    final prompt = 'For each Japanese word below, provide missing fields. '
        'Return a JSON array where each element has: "kana", "translation_de" ($lang), "translation_en" (English), '
        '"example_sentence" (Japanese example), "example_translation_de" ($lang translation of example), '
        '"example_translation_en" (English translation of example). '
        'Words: [$wordsJson]. Return ONLY valid JSON array, no markdown.';

    try {
      final text = await _callAiProvider(settings, prompt);
      if (text == null) return;

      final arrMatch = RegExp(r'\[[\s\S]*\]').firstMatch(text);
      if (arrMatch == null) return;

      final results = jsonDecode(arrMatch.group(0)!) as List;
      final allVocab = await repo.getVocabForDeck(widget.deck.id!);

      for (final r in results) {
        if (r is! Map) continue;
        final kana = r['kana'] as String? ?? '';
        final match = allVocab.where((v) => v.kana == kana).toList();
        if (match.isEmpty) continue;

        final v = match.first;
        await repo.updateVocab(v.copyWith(
          translationDe: v.translationDe ?? r['translation_de'],
          translationEn: v.translationEn ?? r['translation_en'],
          exampleSentence: v.exampleSentence ?? r['example_sentence'],
          exampleTranslationDe: v.exampleTranslationDe ?? r['example_translation_de'],
          exampleTranslationEn: v.exampleTranslationEn ?? r['example_translation_en'],
        ));
      }
      _refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fehlende Felder mit KI ergänzt!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KI-Fehler: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<String?> _callAiProvider(AppSettings settings, String prompt) async {
    try {
      return await ref.read(aiServiceProvider).queryAi(prompt: prompt);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vocabRepo = ref.watch(vocabRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.name),
        actions: [
          if (_isEditable)
            IconButton(
              icon: const Icon(Icons.create_new_folder),
              tooltip: 'Unterkategorie erstellen',
              onPressed: () => _showAddSubDeckDialog(context, vocabRepo),
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'export') {
                _showExportDialog(context, vocabRepo);
              } else if (value == 'import') {
                _importCsv(context, vocabRepo);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.file_download), title: Text('CSV Export'), dense: true)),
              if (_isEditable)
                const PopupMenuItem(value: 'import', child: ListTile(leading: Icon(Icons.file_upload), title: Text('CSV Import'), dense: true)),
            ],
          ),
        ],
      ),
      floatingActionButton: _isEditable ? FloatingActionButton(
        onPressed: () => _showAddVocabDialog(context, vocabRepo),
        child: const Icon(Icons.add),
      ) : null,
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          vocabRepo.getVocabForDeck(widget.deck.id!),
          vocabRepo.getSubDecks(widget.deck.id!),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final vocabList = snapshot.data![0] as List<Vocab>;
          final subDecks = snapshot.data![1] as List<Deck>;

          if (vocabList.isEmpty && subDecks.isEmpty) {
            return const Center(child: Text('Keine Vokabeln in diesem Deck.'));
          }

          // Group vocab by manga title or lesson
          final Map<String, List<Vocab>> groupedVocab = {};
          for (var vocab in vocabList) {
            String groupKey = 'Allgemein';

            if (widget.deck.deckType == DeckType.unit && vocab.lessonId != null) {
              final lesson = CourseData.findLessonById(vocab.lessonId!);
              groupKey = lesson?.title ?? 'Lektion: ${vocab.lessonId}';
            } else if (vocab.mangaTitle != null && vocab.mangaTitle!.isNotEmpty) {
              groupKey = vocab.mangaTitle!;
            }

            if (!groupedVocab.containsKey(groupKey)) {
              groupedVocab[groupKey] = [];
            }
            groupedVocab[groupKey]!.add(vocab);
          }

          final groupKeys = groupedVocab.keys.toList();

          return CustomScrollView(
            slivers: [
              // Study button
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverToBoxAdapter(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      DeckStudyMethodBottomSheet.show(context, widget.deck, vocabList);
                    },
                    icon: const Icon(Icons.school),
                    label: Text(AppStrings(ref.read(settingsProvider).appLanguage).studyDeck),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
              // Sub-decks section
              if (subDecks.isNotEmpty) ...[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyHeaderDelegate(
                    minHeight: 40, maxHeight: 40,
                    child: Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Unterkategorien', style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final sub = subDecks[index];
                      return ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(sub.section ?? sub.name),
                        subtitle: FutureBuilder<List<Vocab>>(
                          future: vocabRepo.getVocabForDeck(sub.id!),
                          builder: (ctx, snap) => Text('${snap.data?.length ?? 0} Vokabeln'),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.quiz, size: 20),
                              tooltip: 'Nur diese Kategorie üben',
                              onPressed: () async {
                                final subVocab = await vocabRepo.getVocabForDeck(sub.id!);
                                if (context.mounted && subVocab.isNotEmpty) {
                                  DeckStudyMethodBottomSheet.show(context, sub, subVocab);
                                }
                              },
                            ),
                            const Icon(Icons.arrow_forward_ios, size: 16),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(
                            builder: (_) => VocabDetailScreen(deck: sub),
                          ));
                          _refresh();
                        },
                      );
                    },
                    childCount: subDecks.length,
                  ),
                ),
              ],
              // Vocab groups
              ...groupKeys.map((groupTitle) {
                final words = groupedVocab[groupTitle]!;
                return SliverMainAxisGroup(
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyHeaderDelegate(
                        minHeight: 40,
                        maxHeight: 40,
                        child: Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            groupTitle,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final vocab = words[index];
                          return _isEditable
                            ? Dismissible(
                                key: ValueKey(vocab.id ?? index.toString()),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20.0),
                                  color: Colors.red,
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                onDismissed: (direction) async {
                                   if (vocab.id != null) {
                                      await vocabRepo.deleteVocab(vocab.id!);
                                      words.removeAt(index);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vokabel gelöscht')));
                                   }
                                },
                                child: _buildVocabTile(context, vocab),
                              )
                            : _buildVocabTile(context, vocab);
                        },
                        childCount: words.length,
                      ),
                    ),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildVocabTile(BuildContext context, Vocab vocab) {
    final vocabRepo = ref.read(vocabRepositoryProvider);
    final contentLang = ref.watch(settingsProvider).contentLanguage;
    final word = vocab.kanji?.isNotEmpty == true ? vocab.kanji! : vocab.kana;
    final showReading = vocab.kanji != null && vocab.kanji!.isNotEmpty && vocab.kanji != vocab.kana;

    return ListTile(
      title: Row(
        children: [
          Text(word, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          if (showReading) ...[
            const SizedBox(width: 8),
            Text(vocab.kana, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(vocab.localizedTranslation(contentLang), style: const TextStyle(fontSize: 14)),
          if (vocab.exampleSentence != null && vocab.exampleSentence!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                vocab.exampleSentence!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (vocab.chapter != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(vocab.chapter!, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey)),
            ),
          if (vocab.sourceUrl != null && vocab.sourceUrl!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.open_in_browser, size: 20, color: Colors.blue),
              tooltip: 'Quelle öffnen',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => WebviewReaderScreen(url: vocab.sourceUrl!, title: vocab.mangaTitle ?? 'Manga'),
                  ),
                );
              },
            ),
          if (_isEditable)
            const Icon(Icons.edit, size: 18, color: Colors.grey),
        ],
      ),
      onTap: _isEditable ? () => _showEditVocabDialog(context, vocabRepo, vocab) : null,
    );
  }

  void _showEditVocabDialog(BuildContext context, VocabRepository repo, Vocab vocab) {
    final kanaCtrl = TextEditingController(text: vocab.kana);
    final kanjiCtrl = TextEditingController(text: vocab.kanji ?? '');
    final translCtrl = TextEditingController(text: vocab.translation);
    final exampleCtrl = TextEditingController(text: vocab.exampleSentence ?? '');
    final exampleTranslCtrl = TextEditingController(text: vocab.exampleTranslation ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vokabel bearbeiten'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: kanaCtrl, decoration: const InputDecoration(labelText: 'Kana (Lesung) *')),
              TextField(controller: kanjiCtrl, decoration: const InputDecoration(labelText: 'Kanji (Optional)')),
              TextField(controller: translCtrl, decoration: const InputDecoration(labelText: 'Übersetzung *')),
              const SizedBox(height: 12),
              TextField(
                controller: exampleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Beispielsatz (Optional)',
                  hintText: 'z.B. 日本語を勉強しています',
                ),
              ),
              TextField(
                controller: exampleTranslCtrl,
                decoration: const InputDecoration(
                  labelText: 'Beispielsatz Übersetzung (Optional)',
                  hintText: 'z.B. Ich studiere Japanisch',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (vocab.id != null) {
                await repo.deleteVocab(vocab.id!);
                _refresh();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vokabel gelöscht')));
                }
              }
            },
            child: const Text('Löschen', style: TextStyle(color: Colors.red)),
          ),
          const Spacer(),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (kanaCtrl.text.trim().isEmpty || translCtrl.text.trim().isEmpty) return;
              final updated = vocab.copyWith(
                kana: kanaCtrl.text.trim(),
                kanji: kanjiCtrl.text.trim().isEmpty ? null : kanjiCtrl.text.trim(),
                translation: translCtrl.text.trim(),
                exampleSentence: exampleCtrl.text.trim().isEmpty ? null : exampleCtrl.text.trim(),
                exampleTranslation: exampleTranslCtrl.text.trim().isEmpty ? null : exampleTranslCtrl.text.trim(),
              );
              await repo.updateVocab(updated);
              if (ctx.mounted) Navigator.pop(ctx);
              _refresh();
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}
