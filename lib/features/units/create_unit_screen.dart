import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/models/lesson.dart';
import '../../core/models/unit.dart';
import '../../core/models/deck.dart';
import '../../core/database/unit_repository.dart';
import '../../core/database/vocab_repository.dart';
import 'units_screen.dart';

// ── Unit Creator Screen ──

class CreateUnitScreen extends ConsumerStatefulWidget {
  const CreateUnitScreen({super.key});

  @override
  ConsumerState<CreateUnitScreen> createState() => _CreateUnitScreenState();
}

class _CreateUnitScreenState extends ConsumerState<CreateUnitScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _cefrLevel = 'A1';
  bool _isPublic = false;
  final List<_LessonDraft> _lessons = [];
  bool _isSaving = false;
  bool _isAiGenerating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Unit erstellen', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('KI erstellen'),
            onPressed: _isAiGenerating ? null : _showAiGenerateDialog,
          ),
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Speichern', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title & Description ──
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Unit Titel *',
                hintText: 'z.B. "Grundlegende Begrüßungen"',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Beschreibung',
                hintText: 'Was lernt man in dieser Unit?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            // ── Settings Row ──
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _cefrLevel,
                    decoration: InputDecoration(
                      labelText: 'Niveau',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                    items: ['A1', 'A2', 'B1', 'B2', 'C1'].map((l) =>
                      DropdownMenuItem(value: l, child: Text('$l (${l == 'A1' ? 'N5' : l == 'A2' ? 'N4' : l == 'B1' ? 'N3' : l == 'B2' ? 'N2' : 'N1'})'))).toList(),
                    onChanged: (val) => setState(() => _cefrLevel = val ?? 'A1'),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    const Text('Öffentlich', style: TextStyle(fontSize: 12)),
                    Switch(value: _isPublic, onChanged: (v) => setState(() => _isPublic = v)),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),

            // ── Lessons List ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Lektionen (${_lessons.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _addLesson,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Lektion'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._lessons.asMap().entries.map((entry) {
              final idx = entry.key;
              final lesson = entry.value;
              return _LessonCard(
                lesson: lesson,
                index: idx,
                onDelete: () => setState(() => _lessons.removeAt(idx)),
                onChanged: () => setState(() {}),
              );
            }),
            if (_lessons.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3), style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.school_outlined, size: 40, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                      const SizedBox(height: 8),
                      Text('Noch keine Lektionen', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.3))),
                      const SizedBox(height: 4),
                      Text('Füge Lektionen mit Grammatik und Übungen hinzu', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.2), fontSize: 12)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  void _addLesson() {
    setState(() {
      _lessons.add(_LessonDraft(
        title: 'Lektion ${_lessons.length + 1}',
        description: '',
        grammarMarkdown: '',
        requiredAccuracy: null,
        exercises: [],
        vocabList: [],
      ));
    });
  }

  void _showAiGenerateDialog() {
    final promptController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unit per KI generieren'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Beschreibe was die Unit lehren soll. Die KI erstellt automatisch Lektionen mit Grammatik, Übungen und Vokabeln.', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: promptController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'z.B. "Japanische Begrüßungen und Vorstellung im Alltag"',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _generateWithAi(promptController.text);
            },
            child: const Text('Generieren ✨'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateWithAi(String prompt) async {
    if (prompt.trim().isEmpty) return;
    setState(() => _isAiGenerating = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KI generiert Unit... Das kann 1-2 Minuten dauern.')));
    
    try {
      final settings = ref.read(settingsProvider);
      final aiService = ref.read(aiServiceProvider);
      
      final mtName = settings.motherTongue == 'en' ? 'English' : 'Deutsch';
      
      final sysPrompt = '''Du bist ein erfahrener Japanisch-Lehrer. Erstelle eine vollständige Lerneinheit (Unit) basierend auf dem Thema des Benutzers.
Sprachniveau: $_cefrLevel.
Antworte ausschließlich im JSON-Format.

FORMAT-VORGABE (JSON):
{
  "title": "Unit Titel",
  "description": "Kurze Beschreibung",
  "lessons": [
    {
      "title": "Lektionstitel",
      "description": "Was man lernt",
      "lesson_type": "grammarIntro",
      "grammar_explanation": "Ausführliche Erklärung in $mtName mit Beispielen",
      "vocab": [
        {"word": "私", "reading": "わたし", "translation": "Ich"}
      ],
      "exercises": [
        {
          "type": "multiple_choice",
          "question": "Frage",
          "instruction": "Anweisung",
          "options": ["O1", "O2", "O3", "O4"],
          "correctOption": "O1"
        }
      ]
    }
  ]
}
Gültige Lesson-Typen: vocabGate, grammarIntro, grammarProduction, mixedReinforcement, unitTest.
Gültige Übungs-Typen: multiple_choice, typing, fill_in_blank, flashcard, matching, sentence_building.
Generiere 2-3 Lektionen.''';

      final response = await aiService.queryAi(
        prompt: prompt,
        systemPrompt: sysPrompt,
      );
      
      final cleanJson = response.contains('```json') 
          ? response.split('```json')[1].split('```')[0].trim()
          : response.trim();
          
      final data = jsonDecode(cleanJson);
      
      setState(() {
        _titleController.text = data['title'] ?? _titleController.text;
        _descController.text = data['description'] ?? _descController.text;
        _lessons.clear();
        
        final List<dynamic> lessonsRaw = data['lessons'] ?? [];
        for (final l in lessonsRaw) {
          _lessons.add(_LessonDraft(
            title: l['title'] ?? 'Neue Lektion',
            description: l['description'] ?? '',
            grammarMarkdown: l['grammar_explanation'] ?? '',
            requiredAccuracy: (l['required_accuracy'] as num?)?.toDouble() ?? 0.8,
            vocabList: (l['vocab'] as List? ?? []).map((v) => {
              'word': (v['word'] ?? '').toString(),
              'reading': (v['reading'] ?? '').toString(),
              'translation': (v['translation'] ?? '').toString(),
            }).toList(),
            exercises: (l['exercises'] as List? ?? []).map((e) => Exercise.fromMap(e)).toList(),
          ));
        }
      });

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ KI-Entwurf erstellt! Bitte prüfen und speichern.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('KI Fehler: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isAiGenerating = false);
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte einen Titel eingeben')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final settings = ref.read(settingsProvider);
      final unitRepo = ref.read(unitRepositoryProvider);
      final vocabRepo = ref.read(vocabRepositoryProvider);
      
      final unitId = 'custom_unit_${DateTime.now().millisecondsSinceEpoch}';
      
      // 1. Create Lessons
      final List<Lesson> lessons = [];
      for (int i = 0; i < _lessons.length; i++) {
        final d = _lessons[i];
        lessons.add(Lesson(
          id: '${unitId}_l$i',
          unitId: unitId,
          title: d.title,
          description: d.description,
          lessonType: LessonType.grammarIntro, // Standard fallback
          grammarExplanation: d.grammarMarkdown,
          requiredAccuracy: d.requiredAccuracy,
          exercises: d.exercises,
          vocabularyList: d.vocabList,
        ));
      }

      // 2. Create Unit
      final unit = Unit(
        id: unitId,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        lessons: lessons,
        unitVocab: [], // Populated in the deck
      );

      // 3. Save to local DB
      await unitRepo.insertUnit(unit);

      // 4. Create a Deck for this unit
      final deckId = await vocabRepo.insertDeck(Deck(
        name: 'Unit: ${unit.title}',
        deckType: DeckType.unit,
        parentUnitId: unitId,
        isAiGenerated: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

      // 5. Add all vocab to the deck
      for (final l in _lessons) {
        for (final v in l.vocabList) {
          await vocabRepo.insertVocabFromStrings(
            deckId: deckId,
            wordText: v['word'] ?? '',
            readingText: v['reading'] ?? '',
            translationText: v['translation'] ?? '',
          );
        }
      }

      // 6. Optional: Sync to backend if available
      if (settings.hasBackend) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('jwt_token') ?? '';
          await http.post(
            Uri.parse('${settings.effectiveBackendUrl}/api/units/'),
            headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
            body: jsonEncode({
              'title': unit.title,
              'description': unit.description,
              'language_level': _cefrLevel,
              'is_public': _isPublic,
              'lessons': _lessons.map((l) => {
                'title': l.title,
                'description': l.description,
                'grammar_markdown': l.grammarMarkdown,
                'required_accuracy': l.requiredAccuracy,
                'exercises': l.exercises.map((e) => e.toMap()).toList(),
                'vocab': l.vocabList,
              }).toList(),
            }),
          ).timeout(const Duration(seconds: 10));
        } catch (_) {
          // Ignore backend sync failures, local is saved
        }
      }

      if (mounted) {
        ref.invalidate(unitsProvider);
        ref.invalidate(decksProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Unit lokal gespeichert!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Speichern: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ── Lesson Draft Model ──

class _LessonDraft {
  String title;
  String description;
  String grammarMarkdown;
  double? requiredAccuracy;
  List<Exercise> exercises;
  List<Map<String, String>> vocabList;

  _LessonDraft({
    required this.title,
    required this.description,
    required this.grammarMarkdown,
    this.requiredAccuracy,
    required this.exercises,
    required this.vocabList,
  });
}

// ── Lesson Card Widget ──

class _LessonCard extends StatefulWidget {
  final _LessonDraft lesson;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _LessonCard({required this.lesson, required this.index, required this.onDelete, required this.onChanged});

  @override
  State<_LessonCard> createState() => _LessonCardState();
}

class _LessonCardState extends State<_LessonCard> {
  bool _expanded = false;
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _grammarCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.lesson.title);
    _descCtrl = TextEditingController(text: widget.lesson.description);
    _grammarCtrl = TextEditingController(text: widget.lesson.grammarMarkdown);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // ── Header ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                    child: Text('${widget.index + 1}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.lesson.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${widget.lesson.exercises.length} Übung(en) · ${widget.lesson.vocabList.length} Vokabeln${widget.lesson.requiredAccuracy != null ? ' · ${(widget.lesson.requiredAccuracy! * 100).toInt()}% nötig' : ''}',
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: widget.onDelete),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),

          // ── Expanded Content ──
          if (_expanded) Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                // Title
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Titel', isDense: true),
                  onChanged: (v) { widget.lesson.title = v; widget.onChanged(); },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Beschreibung', isDense: true),
                  onChanged: (v) { widget.lesson.description = v; widget.onChanged(); },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _grammarCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(labelText: 'Grammatik-Erklärung (Markdown)', isDense: true, helperText: 'Unterstützt Markdown-Formatierung'),
                  onChanged: (v) { widget.lesson.grammarMarkdown = v; widget.onChanged(); },
                ),
                const SizedBox(height: 12),

                // ── Accuracy Lock ──
                Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 16),
                    const SizedBox(width: 6),
                    const Text('Genauigkeit für Freischaltung: ', style: TextStyle(fontSize: 12)),
                    DropdownButton<double?>(
                      value: widget.lesson.requiredAccuracy,
                      underline: const SizedBox(),
                      isDense: true,
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Keine')),
                        const DropdownMenuItem(value: 0.7, child: Text('70%')),
                        const DropdownMenuItem(value: 0.8, child: Text('80%')),
                        const DropdownMenuItem(value: 0.9, child: Text('90%')),
                        const DropdownMenuItem(value: 0.95, child: Text('95%')),
                      ],
                      onChanged: (val) { setState(() => widget.lesson.requiredAccuracy = val); widget.onChanged(); },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Vocab Section ──
                _SectionHeader(
                  title: 'Vokabeln (${widget.lesson.vocabList.length})',
                  onAdd: () {
                    setState(() => widget.lesson.vocabList.add({'word': '', 'reading': '', 'translation': ''}));
                    widget.onChanged();
                  },
                ),
                ...widget.lesson.vocabList.asMap().entries.map((e) {
                  final i = e.key;
                  final v = e.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: TextField(
                          decoration: const InputDecoration(hintText: 'Wort', isDense: true, contentPadding: EdgeInsets.all(8)),
                          controller: TextEditingController(text: v['word']),
                          onChanged: (val) => widget.lesson.vocabList[i]['word'] = val,
                        )),
                        const SizedBox(width: 4),
                        Expanded(child: TextField(
                          decoration: const InputDecoration(hintText: 'Lesung', isDense: true, contentPadding: EdgeInsets.all(8)),
                          controller: TextEditingController(text: v['reading']),
                          onChanged: (val) => widget.lesson.vocabList[i]['reading'] = val,
                        )),
                        const SizedBox(width: 4),
                        Expanded(child: TextField(
                          decoration: const InputDecoration(hintText: 'Deutsch', isDense: true, contentPadding: EdgeInsets.all(8)),
                          controller: TextEditingController(text: v['translation']),
                          onChanged: (val) => widget.lesson.vocabList[i]['translation'] = val,
                        )),
                        IconButton(icon: const Icon(Icons.close, size: 16, color: Colors.red), onPressed: () {
                          setState(() => widget.lesson.vocabList.removeAt(i));
                          widget.onChanged();
                        }),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),

                // ── Exercises Section ──
                _SectionHeader(
                  title: 'Übungen (${widget.lesson.exercises.length})',
                  onAdd: () => _showAddExerciseDialog(),
                ),
                ...widget.lesson.exercises.asMap().entries.map((e) {
                  final i = e.key;
                  final ex = e.value;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_exerciseIcon(ex), size: 20, color: theme.colorScheme.primary),
                    title: Text(ex.question, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                    subtitle: Text(_exerciseTypeName(ex), style: const TextStyle(fontSize: 10)),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red), onPressed: () {
                      setState(() => widget.lesson.exercises.removeAt(i));
                      widget.onChanged();
                    }),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _exerciseTypeName(Exercise ex) {
    if (ex is MultipleChoiceExercise) return 'Multiple Choice';
    if (ex is TypingExercise) return 'Eintippen';
    if (ex is FillInBlankExercise) return 'Lückentext';
    if (ex is MatchingExercise) return 'Zuordnung';
    if (ex is SentenceBuildingExercise) return 'Satzbau';
    if (ex is FlashcardExercise) return 'Karteikarte';
    return 'Übung';
  }

  IconData _exerciseIcon(Exercise ex) {
    if (ex is MultipleChoiceExercise) return Icons.checklist;
    if (ex is TypingExercise) return Icons.keyboard;
    if (ex is FillInBlankExercise) return Icons.edit_note;
    if (ex is MatchingExercise) return Icons.compare_arrows;
    if (ex is SentenceBuildingExercise) return Icons.sort;
    if (ex is FlashcardExercise) return Icons.style;
    return Icons.quiz;
  }

  void _showAddExerciseDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _AddExerciseSheet(
        onAdd: (exercise) {
          setState(() => widget.lesson.exercises.add(exercise));
          widget.onChanged();
        },
      ),
    );
  }
}

// ── Section Header Widget ──

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  const _SectionHeader({required this.title, required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        TextButton.icon(icon: const Icon(Icons.add, size: 16), label: const Text('Hinzu', style: TextStyle(fontSize: 12)), onPressed: onAdd),
      ],
    );
  }
}

// ── Add Exercise Sheet ──

class _AddExerciseSheet extends StatefulWidget {
  final Function(Exercise) onAdd;
  const _AddExerciseSheet({required this.onAdd});

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  String _type = 'multiple_choice';
  final _questionCtrl = TextEditingController();
  final _instructionCtrl = TextEditingController();
  // MC
  final _correctOptionCtrl = TextEditingController();
  final List<TextEditingController> _optionCtrls = [TextEditingController(), TextEditingController(), TextEditingController(), TextEditingController()];
  // Typing
  final _answerCtrl = TextEditingController();
  final _hintCtrl = TextEditingController();
  // Fill in blank
  final _beforeCtrl = TextEditingController();
  final _afterCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            const Text('Übung hinzufügen', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            // ── Type Selector ──
            DropdownButtonFormField<String>(
              value: _type,
              decoration: InputDecoration(labelText: 'Typ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              items: const [
                DropdownMenuItem(value: 'multiple_choice', child: Text('Multiple Choice')),
                DropdownMenuItem(value: 'typing', child: Text('Eintippen')),
                DropdownMenuItem(value: 'fill_in_blank', child: Text('Lückentext')),
                DropdownMenuItem(value: 'flashcard', child: Text('Karteikarte')),
              ],
              onChanged: (val) => setState(() => _type = val ?? 'multiple_choice'),
            ),
            const SizedBox(height: 12),
            // ── Common Fields ──
            TextField(controller: _questionCtrl, decoration: InputDecoration(labelText: 'Frage *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 8),
            TextField(controller: _instructionCtrl, decoration: InputDecoration(labelText: 'Anweisung', hintText: 'z.B. "Übersetze ins Deutsche"', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 12),
            // ── Type-specific fields ──
            if (_type == 'multiple_choice') ..._buildMCFields(),
            if (_type == 'typing') ..._buildTypingFields(),
            if (_type == 'fill_in_blank') ..._buildFillInBlankFields(),
            if (_type == 'flashcard') ..._buildFlashcardFields(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: _submit,
                child: const Text('Übung hinzufügen', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMCFields() => [
    TextField(controller: _correctOptionCtrl, decoration: InputDecoration(labelText: 'Richtige Antwort *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 8),
    ...List.generate(4, (i) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(controller: _optionCtrls[i], decoration: InputDecoration(labelText: 'Option ${i + 1}${i == 0 ? ' (=richtig)' : ''}', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), isDense: true)),
    )),
  ];

  List<Widget> _buildTypingFields() => [
    TextField(controller: _answerCtrl, decoration: InputDecoration(labelText: 'Richtige Antwort *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 8),
    TextField(controller: _hintCtrl, decoration: InputDecoration(labelText: 'Hinweis (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
  ];

  List<Widget> _buildFillInBlankFields() => [
    TextField(controller: _beforeCtrl, decoration: InputDecoration(labelText: 'Satz vor Lücke', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 8),
    TextField(controller: _answerCtrl, decoration: InputDecoration(labelText: 'Richtige Antwort (Lücke) *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 8),
    TextField(controller: _afterCtrl, decoration: InputDecoration(labelText: 'Satz nach Lücke', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
  ];

  List<Widget> _buildFlashcardFields() => [
    TextField(controller: _answerCtrl, decoration: InputDecoration(labelText: 'Rückseite (Antwort) *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
    const SizedBox(height: 8),
    TextField(controller: _hintCtrl, decoration: InputDecoration(labelText: 'Hinweis (z.B. Kana)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
  ];

  void _submit() {
    if (_questionCtrl.text.trim().isEmpty) return;
    Exercise exercise;
    switch (_type) {
      case 'multiple_choice':
        final options = _optionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
        final correct = _correctOptionCtrl.text.isNotEmpty ? _correctOptionCtrl.text.trim() : (options.isNotEmpty ? options.first : '');
        if (!options.contains(correct) && correct.isNotEmpty) options.insert(0, correct);
        exercise = MultipleChoiceExercise(question: _questionCtrl.text, instruction: _instructionCtrl.text, options: options, correctOption: correct);
        break;
      case 'typing':
        exercise = TypingExercise(question: _questionCtrl.text, instruction: _instructionCtrl.text, answer: _answerCtrl.text, hint: _hintCtrl.text.isEmpty ? null : _hintCtrl.text);
        break;
      case 'fill_in_blank':
        exercise = FillInBlankExercise(question: _questionCtrl.text, instruction: _instructionCtrl.text, sentencePartsBefore: _beforeCtrl.text, sentencePartsAfter: _afterCtrl.text, correctAnswer: _answerCtrl.text, wordBank: [_answerCtrl.text]);
        break;
      case 'flashcard':
        exercise = FlashcardExercise(question: _questionCtrl.text, instruction: _instructionCtrl.text, answer: _answerCtrl.text, hint: _hintCtrl.text.isEmpty ? null : _hintCtrl.text);
        break;
      default:
        return;
    }
    widget.onAdd(exercise);
    Navigator.pop(context);
  }
}
