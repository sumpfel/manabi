import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/course_data.dart';
import '../../core/models/unit.dart';
import '../../core/models/lesson.dart';
import '../study/lesson_screen.dart';
import '../profile/ai_chat_screen.dart';
import './create_unit_screen.dart';
import '../../core/services/progress_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/study_service.dart';
import '../../core/database/vocab_repository.dart';

import '../../core/database/unit_repository.dart';

final unitsProvider = FutureProvider<List<Unit>>((ref) async {
  final customUnits = await ref.read(unitRepositoryProvider).getCustomUnits();
  return [...CourseData.units, ...customUnits];
});

class _NodeItem {
  final bool isHeader;
  final Unit? unit;
  final Lesson? lesson;
  final int globalLessonIndex;
  final int unitIndex;

  _NodeItem.header(this.unit, this.unitIndex) : isHeader = true, lesson = null, globalLessonIndex = -1;
  _NodeItem.lesson(this.lesson, this.globalLessonIndex, this.unitIndex) : isHeader = false, unit = null;
}

class UnitsScreen extends ConsumerWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final Size screenSize = MediaQuery.of(context).size;

    final unitsAsync = ref.watch(unitsProvider);
    final progress = ref.watch(progressProvider);
    final studyService = ref.read(studyServiceProvider);

    return unitsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Fehler beim Laden der Units: $err'))),
      data: (units) {
        final List<_NodeItem> nodes = [];
        int globalLessonIndex = 0;
        int firstIncompleteGlobalIndex = -1;
        
        for (int i = 0; i < units.length; i++) {
          final unit = units[i];
          nodes.add(_NodeItem.header(unit, i));
          
          for (int j = 0; j < unit.lessons.length; j++) {
            final lesson = unit.lessons[j];
            nodes.add(_NodeItem.lesson(lesson, globalLessonIndex, i));
            
            if (firstIncompleteGlobalIndex == -1 && !progress.isCompleted(lesson.id)) {
              firstIncompleteGlobalIndex = globalLessonIndex;
            }
            globalLessonIndex++;
          }
        }

        if (firstIncompleteGlobalIndex == -1) firstIncompleteGlobalIndex = globalLessonIndex;
        final int currentLessonIndex = firstIncompleteGlobalIndex;

        return Scaffold(
          // ... (existing AppBar and body with ListView.builder)
      appBar: AppBar(
        title: const Text('Lernpfad', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateUnitScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.colorScheme.surface, theme.colorScheme.surface.withAlpha(200)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Timeline Content
          ListView.builder(
            padding: const EdgeInsets.only(top: 20, bottom: 80),
            itemCount: nodes.length,
            itemBuilder: (context, index) {
              final node = nodes[index];

              if (node.isHeader) {
                return _buildUnitHeader(node.unit!, index, theme);
              }

              final lessonIdx = node.globalLessonIndex;
              
              // A lesson is unlocked if it's the first incomplete lesson in the whole list
              // OR if it's already completed.
              final isCompleted = progress.isCompleted(node.lesson!.id);
              final isUnlocked = lessonIdx <= currentLessonIndex;
              final isCurrent = lessonIdx == currentLessonIndex;

              // To make the path zig-zag beautifully, we check its index relative to the lessons
              final isEven = lessonIdx % 2 == 0;
              final xOffset = isEven ? screenSize.width * 0.15 : -screenSize.width * 0.15;

              // Check if there's a NEXT lesson node (not a header) to draw a path to it
              bool hasNextLessonNode = false;
              if (index + 1 < nodes.length && !nodes[index + 1].isHeader) {
                hasNextLessonNode = true;
              }

              return SizedBox(
                height: 140, // Spacing between nodes
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // The connecting path line
                    if (index < nodes.length - 1 && node.lesson != null)
                      Positioned(
                        top: 35, // starting from center of the 70px circle
                        left: (screenSize.width / 2) - (screenSize.width * 0.2), // spans from left offset to right offset
                        child: CustomPaint(
                          painter: _PathPainter(
                            isEven: isEven,
                            color: isUnlocked ? Colors.blue.shade300 : Colors.grey.shade300,
                            width: screenSize.width * 0.4,
                          ),
                          size: Size(screenSize.width * 0.4, 140),
                        ),
                      ),
                    
                    // The Node
                    Transform.translate(
                      offset: Offset(xOffset, 0),
                      child: GestureDetector(
                        onTap: () {
                          if (isUnlocked) {
                            _showLessonDetails(context, ref, node.lesson!, node.unitIndex, isCompleted);
                          } else {
                          }
                        },
                        child: _UnitNode(
                          title: node.lesson!.title,
                          isUnlocked: isUnlocked,
                          isCompleted: isCompleted,
                          isCurrent: isCurrent,
                          theme: theme,
                          lessonType: node.lesson!.lessonType,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            colors: [Colors.amber, Colors.orange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withAlpha(100),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI Sensei wird geladen...'), duration: Duration(milliseconds: 500)));
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiChatScreen()),
            );
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome, color: Colors.white),
              SizedBox(width: 8),
              Text('Ask AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
        );
      },
    );
  }

  Widget _buildUnitHeader(Unit unit, int index, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withAlpha(50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  unit.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            unit.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }

  void _showLessonDetails(BuildContext context, WidgetRef ref, Lesson lesson, int unitIndex, bool isCompleted) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 350,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lektion', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
              const SizedBox(height: 4),
              Text(lesson.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(lesson.description, style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 24),
              Text('Übungen: ${lesson.exercises.length}', style: const TextStyle(fontSize: 14)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    // Phase 4: Record Recent Activity before starting
                    final streakNotifier = ref.read(recentActivityProvider.notifier);
                    streakNotifier.record(RecentActivity(
                      id: 'unit_${CourseData.units[unitIndex].id}',
                      type: 'lesson',
                      title: CourseData.units[unitIndex].title,
                      subtitle: 'Lektion: ${lesson.title}',
                      metadata: {
                        'unitIndex': unitIndex,
                        'lessonId': lesson.id,
                      },
                      timestamp: DateTime.now().millisecondsSinceEpoch,
                    ));

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lektion wird gestartet...'), duration: Duration(milliseconds: 500)));
                    Navigator.pop(context);
                    final passed = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LessonScreen(
                          lesson: lesson,
                        ),
                      ),
                    );
                    
                    if (passed == true) {
                      ref.read(progressProvider.notifier).markLessonCompleted(lesson.id);
                    }
                  },
                  child: Text(isCompleted ? 'Wiederholen' : 'Starten', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnitNode extends StatelessWidget {
  final String title;
  final bool isUnlocked;
  final bool isCompleted;
  final bool isCurrent;
  final ThemeData theme;
  final LessonType lessonType;

  const _UnitNode({
    required this.title,
    required this.isUnlocked,
    required this.isCompleted,
    required this.isCurrent,
    required this.theme,
    required this.lessonType,
  });

  IconData _getLessonIcon() {
    switch (lessonType) {
      case LessonType.vocabGate: return Icons.style;
      case LessonType.grammarIntro: return Icons.menu_book;
      case LessonType.grammarProduction: return Icons.create;
      case LessonType.mixedReinforcement: return Icons.fitness_center;
      case LessonType.unitTest: return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    Color ringColor = Colors.grey.shade300;
    Color centerColor = Colors.grey.shade200;
    IconData icon = Icons.lock;
    Color iconColor = Colors.grey.shade400;

    if (isCompleted) {
      ringColor = Colors.amber;
      centerColor = Colors.amber.shade100;
      icon = Icons.check;
      iconColor = Colors.amber.shade700;
    } else if (isCurrent) {
      ringColor = Colors.blue;
      centerColor = Colors.white;
      icon = _getLessonIcon();
      iconColor = Colors.blue;
    } else if (isUnlocked) {
      ringColor = Colors.blue.shade200;
      centerColor = Colors.white;
      icon = _getLessonIcon();
      iconColor = Colors.blue.shade400;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: centerColor,
            border: Border.all(color: ringColor, width: isCurrent ? 6 : 4),
            boxShadow: isCurrent ? [BoxShadow(color: Colors.blue.withAlpha(100), blurRadius: 15, spreadRadius: 5)] : [],
          ),
          child: Center(
            child: Icon(icon, size: 30, color: iconColor),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 100,
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isUnlocked ? theme.colorScheme.onSurface : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
}

class _PathPainter extends CustomPainter {
  final bool isEven;
  final Color color;
  final double width;

  _PathPainter({required this.isEven, required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    if (isEven) {
      // Current node is on the right, next is on the left
      // Start at top-right (size.width, 0)
      path.moveTo(size.width, 0);
      path.quadraticBezierTo(size.width, size.height / 2, 0, size.height);
    } else {
      // Current node is on the left, next is on the right
      // Start at top-left (0, 0)
      path.moveTo(0, 0);
      path.quadraticBezierTo(0, size.height / 2, size.width, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
