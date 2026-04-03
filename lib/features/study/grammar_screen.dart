import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/data/course_data.dart';
import '../../core/models/lesson.dart';
import '../../core/models/unit.dart';
import '../../core/services/progress_service.dart';
import '../../core/services/study_service.dart';
import 'lesson_screen.dart';

class GrammarScreen extends ConsumerWidget {
  const GrammarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = CourseData.units;
    final progress = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Lernpfad')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        itemCount: units.length,
        itemBuilder: (context, uIndex) {
          final unit = units[uIndex];
          final color = _getUnitColor(uIndex);
          bool previousLessonCompleted = uIndex == 0;

          if (uIndex > 0) {
            final prevUnit = units[uIndex - 1];
            final lastLessonId = prevUnit.lessons.last.id;
            previousLessonCompleted = progress.isCompleted(lastLessonId);
          }

          // Auto-sync vocab when unit is unlocked
          if (previousLessonCompleted) {
            int maxUnlockedIndex = unit.lessons.lastIndexWhere((l) => progress.isCompleted(l.id)) + 1;
            Future.microtask(() => ref.read(studyServiceProvider).syncUnitVocab(unit, maxUnlockedIndex));
          }

          List<Widget> unitChildren = [
            _buildUnitHeader(context, ref, 'Unit ${uIndex + 1}', unit, color, previousLessonCompleted),
          ];

          for (int i = 0; i < unit.lessons.length; i++) {
            final lesson = unit.lessons[i];
            
            final isCompleted = progress.isCompleted(lesson.id);
            final isUnlocked = previousLessonCompleted;
            final accuracy = progress.getAccuracy(lesson.id);
            
            double offset = 0;
            if (i % 2 != 0) {
              offset = (i % 4 == 1) ? -40 : 40;
            }
            
            unitChildren.add(_buildLessonNode(
              context, ref, lesson,
              isCompleted: isCompleted,
              isLocked: !isUnlocked,
              offset: offset,
              accuracy: accuracy,
            ));
            
            previousLessonCompleted = isCompleted;
          }
          
          unitChildren.add(const SizedBox(height: 32));

          return Column(children: unitChildren);
        },
      ),
    );
  }

  Color _getUnitColor(int index) {
    const colors = [Colors.purple, Colors.blue, Colors.orange, Colors.teal, Colors.red, Colors.indigo, Colors.pink, Colors.cyan, Colors.amber, Colors.deepPurple];
    return colors[index % colors.length];
  }

  IconData _getLessonTypeIcon(LessonType type) {
    switch (type) {
      case LessonType.vocabGate: return Icons.key;
      case LessonType.grammarIntro: return Icons.menu_book;
      case LessonType.grammarProduction: return Icons.edit;
      case LessonType.mixedReinforcement: return Icons.refresh;
      case LessonType.unitTest: return Icons.emoji_events;
    }
  }

  String _getLessonTypeLabel(LessonType type) {
    switch (type) {
      case LessonType.vocabGate: return 'Vocab Gate';
      case LessonType.grammarIntro: return 'Grammar';
      case LessonType.grammarProduction: return 'Production';
      case LessonType.mixedReinforcement: return 'Mixed';
      case LessonType.unitTest: return 'Abschlusstest';
    }
  }

  Widget _buildUnitHeader(BuildContext context, WidgetRef ref, String unitNumber, Unit unit, Color color, bool isUnlocked) {
    return GestureDetector(
      onTap: () => _showUnitSummary(context, ref, unit, isUnlocked),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(unitNumber.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                if (isUnlocked)
                  const Icon(Icons.lock_open, color: Colors.white70, size: 16)
                else
                  const Icon(Icons.lock, color: Colors.white54, size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Text(unit.title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(unit.description, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text('${unit.unitVocab.length} Wörter • ${unit.lessons.length} Lektionen • Tippe für Details',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUnitSummary(BuildContext context, WidgetRef ref, Unit unit, bool isUnlocked) {
    final totalExercises = unit.lessons.fold<int>(0, (sum, l) => sum + l.exercises.length);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(unit.title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(unit.description, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 16),
                Text('📊 Übersicht', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('• ${unit.unitVocab.length} Vokabeln'),
                Text('• ${unit.lessons.length} Lektionen'),
                Text('• $totalExercises Übungen insgesamt'),
                const SizedBox(height: 16),
                Text('📚 Lektionen', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...unit.lessons.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(_getLessonTypeIcon(l.lessonType), size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l.title, style: const TextStyle(fontSize: 13))),
                      Text('${l.exercises.length}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                )),
                if (unit.unitVocab.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('📝 Vokabel-Vorschau', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: unit.unitVocab.take(15).map((v) => Chip(
                      label: Text('${v.kanji ?? v.kana} ${v.translationDe ?? v.translation}', style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  ),
                  if (unit.unitVocab.length > 15)
                    Text('  ...und ${unit.unitVocab.length - 15} weitere', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          // Force-unlock button for locked units
          if (!isUnlocked)
            TextButton.icon(
              icon: const Icon(Icons.lock_open, size: 18, color: Colors.orange),
              label: const Text('Unit freischalten 🔓', style: TextStyle(color: Colors.orange)),
              onPressed: () {
                showDialog(
                  context: ctx,
                  builder: (confirmCtx) => AlertDialog(
                    title: const Text('Unit freischalten?'),
                    content: Text('Möchtest du "${unit.title}" wirklich freischalten?\n\nAlle vorherigen Lektionen werden als abgeschlossen markiert.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(confirmCtx), child: const Text('Abbrechen')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        onPressed: () {
                          Navigator.pop(confirmCtx);
                          Navigator.pop(ctx);
                          // Mark all lessons of ALL previous units as completed
                          final units = CourseData.units;
                          final currentIdx = units.indexWhere((u) => u.id == unit.id);
                          for (int i = 0; i < currentIdx; i++) {
                            for (final lesson in units[i].lessons) {
                              ref.read(progressProvider.notifier).markLessonCompleted(lesson.id);
                            }
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('✅ "${unit.title}" freigeschaltet!'), backgroundColor: Colors.green),
                            );
                          }
                        },
                        child: const Text('Freischalten'),
                      ),
                    ],
                  ),
                );
              },
            ),
          // Skip unit via test button
          if (isUnlocked && unit.lessons.any((l) => l.lessonType == LessonType.unitTest))
            TextButton.icon(
              icon: const Icon(Icons.skip_next, size: 18),
              label: const Text('Test zum Überspringen'),
              onPressed: () async {
                Navigator.pop(ctx);
                final testLesson = unit.lessons.firstWhere((l) => l.lessonType == LessonType.unitTest);
                final result = await Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (context) => LessonScreen(lesson: testLesson)),
                );
                if (result == true && context.mounted) {
                  // Mark ALL lessons in this unit as completed
                  for (final lesson in unit.lessons) {
                    ref.read(progressProvider.notifier).markLessonCompleted(lesson.id);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Unit "${unit.title}" übersprungen! ✓')),
                  );
                }
              },
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Schließen')),
        ],
      ),
    );
  }

  Widget _buildLessonNode(BuildContext context, WidgetRef ref, Lesson lesson, {required bool isCompleted, bool isLocked = false, double offset = 0, double? accuracy}) {
    final statusColor = isLocked ? Colors.grey : (isCompleted ? Colors.amber : Theme.of(context).primaryColor);
    final icon = isLocked ? Icons.lock : (isCompleted ? Icons.star : _getLessonTypeIcon(lesson.lessonType));

    return GestureDetector(
      onTap: isLocked ? null : () async {
        final result = await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
          builder: (context) => LessonScreen(lesson: lesson)
        ));
        
        if (result == true && context.mounted) {
           ref.read(progressProvider.notifier).markLessonCompleted(lesson.id);
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lektion "${lesson.title}" abgeschlossen!')));
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12.0),
        transform: Matrix4.translationValues(offset, 0, 0),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Icon(icon, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 4),
            // Lesson type label
            Text(
              _getLessonTypeLabel(lesson.lessonType),
              style: TextStyle(fontSize: 10, color: isLocked ? Colors.grey : Colors.grey.shade600, fontWeight: FontWeight.bold),
            ),
            // Accuracy badge
            if (accuracy != null)
              Text(
                '${(accuracy * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: accuracy >= (lesson.requiredAccuracy ?? 0) ? Colors.green : Colors.orange,
                ),
              ),
            // Required accuracy badge
            if (lesson.requiredAccuracy != null && !isCompleted)
              Text(
                '≥${(lesson.requiredAccuracy! * 100).toStringAsFixed(0)}% needed',
                style: const TextStyle(fontSize: 9, color: Colors.red),
              ),
            const SizedBox(height: 2),
            InkWell(
              onTap: isLocked ? null : () => _showGrammarSummary(context, lesson),
              child: Text(
                lesson.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: isLocked ? null : TextDecoration.underline,
                  color: isLocked ? Colors.grey : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGrammarSummary(BuildContext context, Lesson lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(lesson.title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_getLessonTypeLabel(lesson.lessonType)} • ${lesson.exercises.length} exercises',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                if (lesson.requiredAccuracy != null)
                  Text('Requires ≥${(lesson.requiredAccuracy! * 100).toStringAsFixed(0)}% accuracy',
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
                const Divider(),
                if (lesson.grammarExplanation.isNotEmpty) ...[
                  const Text('Grammar Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),
                  MarkdownBody(data: lesson.grammarExplanation),
                  const SizedBox(height: 20),
                ],
                if (lesson.vocabularyList.isNotEmpty) ...[
                  const Text('Vocabulary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Divider(),
                  ...lesson.vocabularyList.map((v) => ListTile(
                    dense: true,
                    title: Text(v['word'] ?? ''),
                    subtitle: Text(v['translation'] ?? ''),
                  )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                builder: (context) => LessonScreen(lesson: lesson)
              ));
            },
            child: const Text('Start Lesson'),
          ),
        ],
      ),
    );
  }
}
