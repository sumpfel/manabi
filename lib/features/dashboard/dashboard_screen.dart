import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/data/course_data.dart';
import '../../core/models/lesson.dart';
import '../study/lesson_screen.dart';
import '../study/global_review_screen.dart';
import '../study/deck_study_screen.dart';
import '../reader/webview_reader_screen.dart';
import '../units/units_screen.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/services/deck_session_service.dart';
import '../../core/services/progress_service.dart';
import '../../core/database/vocab_repository.dart';
import '../../core/models/deck.dart';
import '../../core/services/study_service.dart';
import '../writing/practice_session_screen.dart';
import '../writing/writing_screen.dart' show CharacterSet;
import './widgets/dashboard_widgets.dart';
import '../../main.dart';
import 'dart:io';

// ── Dashboard Stats Providers ──

class DashboardStats {
  final int vocabCount;
  final int kanjiCount;
  final double accuracy;
  final int completedUnits;
  final int totalUnits;
  final int dueVocabCount;
  final int dueKanjiCount;

  DashboardStats({
    required this.vocabCount,
    required this.kanjiCount,
    required this.accuracy,
    required this.completedUnits,
    required this.totalUnits,
    required this.dueVocabCount,
    required this.dueKanjiCount,
  });

  String get vocabDisplay {
    if (vocabCount >= 1000) return '${(vocabCount / 1000).toStringAsFixed(1)}k';
    return vocabCount.toString();
  }

  String get kanjiDisplay => kanjiCount.toString();
  String get accuracyDisplay => accuracy > 0 ? '${accuracy.round()}%' : '—';
  String get unitsDisplay => '$completedUnits/$totalUnits';
}

final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final vocabRepo = ref.read(vocabRepositoryProvider);
  final progress = ref.watch(progressProvider);

  final vocabCount = await vocabRepo.getTotalVocabCount();
  final kanjiCount = await vocabRepo.getTotalKanjiCount();
  final accuracy = await vocabRepo.getOverallAccuracy();
  final dueVocab = await vocabRepo.getDueVocabCount();
  final dueKanji = await vocabRepo.getDueKanjiCount();

  // Count completed units by checking if all unit-test lessons are completed
  final allUnits = CourseData.units;
  int completedUnits = 0;
  for (final unit in allUnits) {
    final unitTests = unit.lessons.where((l) => l.lessonType == LessonType.unitTest);
    if (unitTests.isNotEmpty && unitTests.every((t) => progress.isCompleted(t.id))) {
      completedUnits++;
    }
  }

  return DashboardStats(
    vocabCount: vocabCount,
    kanjiCount: kanjiCount,
    accuracy: accuracy,
    completedUnits: completedUnits,
    totalUnits: allUnits.length,
    dueVocabCount: dueVocab,
    dueKanjiCount: dueKanji,
  );
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<ProgressState>(progressProvider, (previous, next) {
      if (next.isLoaded) {
        bool shouldSync = (previous == null || !previous.isLoaded) || 
                          (previous.completedLessons.length != next.completedLessons.length);
        if (shouldSync) {
          ref.read(studyServiceProvider).syncAllReachedUnits(next).then((_) {
            ref.invalidate(dashboardStatsProvider);
            ref.invalidate(decksProvider);
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final progress = ref.read(progressProvider);
      final studyService = ref.read(studyServiceProvider);
      if (progress.isLoaded && !StudyService.hasInitiallySynced) {
        studyService.syncAllReachedUnits(progress).then((_) {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(decksProvider);
        });
      }
    });

    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final s = AppStrings(settings.appLanguage);
    final streak = ref.watch(streakProvider);
    final recentActivities = ref.watch(recentActivityProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    // Softer dark, but still properly dark like ja_manga_app
    const bgColor = Color(0xFF12121D);
    const cardColor = Color(0xFF1E1E2C);
    final borderColor = Colors.white.withOpacity(0.08);

    final stats = statsAsync.valueOrNull;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          s.appTitle,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: theme.colorScheme.onSurface,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          backgroundColor: cardColor,
          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildStatsRow(context, s, streak, cardColor, borderColor, stats),
                   const SizedBox(height: 24),
                   _buildSectionTitle(s.continueRecentDeck),
                   const SizedBox(height: 12),
                   _buildResumeCarousel(context, ref, s, recentActivities, cardColor, borderColor),
                   const SizedBox(height: 24),
                   _buildSectionTitle('Training'),
                   const SizedBox(height: 12),
                   const AIAssistantTeaserSmall(),
                   const SizedBox(height: 12),
                   _buildSrsGrid(context, s, cardColor, borderColor, stats),
                   const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, AppStrings s, int streak, Color color, Color border, DashboardStats? stats) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(Icons.style, stats?.vocabDisplay ?? '0', s.vocabulary, Colors.blueAccent),
          _buildStatVerticalDivider(border),
          _buildStatItem(Icons.translate, stats?.kanjiDisplay ?? '0', 'Kanji', Colors.tealAccent),
          _buildStatVerticalDivider(border),
          _buildStatItem(Icons.local_fire_department, streak.toString(), 'Streak', Colors.orangeAccent),
          _buildStatVerticalDivider(border),
          _buildStatItem(Icons.percent, stats?.accuracyDisplay ?? '—', s.accuracy, Colors.greenAccent),
          _buildStatVerticalDivider(border),
          _buildStatItem(Icons.school, stats?.unitsDisplay ?? '0/0', s.units, Colors.pinkAccent),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color iconColor) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: iconColor.withOpacity(0.8), size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.withOpacity(0.8),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  Widget _buildStatVerticalDivider(Color border) => Container(height: 24, width: 1, color: border);

  Widget _buildResumeCarousel(BuildContext context, WidgetRef ref, AppStrings s, List<RecentActivity> activities, Color color, Color border) {
    if (activities.isEmpty) {
      return _buildFlatCard(
        color: color,
        border: border,
        onTap: () {
          final lesson = CourseData.units.first.lessons.first;
          Navigator.push(context, MaterialPageRoute(builder: (_) => LessonScreen(lesson: lesson)));
        },
        child: Row(
          children: [
            const Icon(Icons.play_circle_outline, color: Colors.blueAccent, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(s.continueLearning, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                   const Text('Starte deine erste Lektion', style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: border),
          ],
        ),
      );
    }

    // Show exactly one of each type: manga, lesson, deck (most recent each)
    final Map<String, RecentActivity> latestByType = {};
    for (final activity in activities) {
      if (!latestByType.containsKey(activity.type)) {
        latestByType[activity.type] = activity;
      }
    }
    // Fixed order: manga, lesson, deck
    final ordered = <RecentActivity>[];
    for (final type in ['manga', 'lesson', 'deck']) {
      if (latestByType.containsKey(type)) ordered.add(latestByType[type]!);
    }

    return Column(
      children: ordered.map((activity) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildRecentCard(context, ref, activity, color, border, s),
        );
      }).toList(),
    );
  }

  Widget _buildRecentCard(BuildContext context, WidgetRef ref, RecentActivity activity, Color color, Color border, AppStrings s) {
     IconData icon;
     Color iconColor;
     String actionText = activity.subtitle;
     double progress = 0;

     switch (activity.type) {
       case 'manga': 
         icon = Icons.menu_book_rounded; 
         iconColor = Colors.orangeAccent;
         progress = 0.5; // Placeholder or use metadata
         break;
       case 'deck': 
         icon = Icons.style_rounded; 
         iconColor = Colors.purpleAccent;
         progress = (activity.metadata['progress'] as num?)?.toDouble() ?? 0.0;
         if (activity.metadata['isCompleted'] == true) {
           actionText = s.tryAgain;
         }
         break;
       case 'lesson': 
         icon = Icons.school_rounded; 
         iconColor = Colors.blueAccent;
         progress = 0.8; // Placeholder or use metadata
         break;
       default: 
         icon = Icons.play_arrow_rounded; 
         iconColor = Colors.white70;
     }

    return GestureDetector(
      onTap: () => _handleActivityTap(context, ref, activity, s),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activity.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      activity.imageUrl!,
                      width: 40,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(icon, color: iconColor, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              activity.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _timeAgo(activity.timestamp),
                            style: TextStyle(
                              color: Colors.grey.withOpacity(0.7),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        actionText,
                        style: TextStyle(
                          color: iconColor.withOpacity(0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation<Color>(iconColor.withOpacity(0.5)),
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(int timestamp) {
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Future<void> _handleActivityTap(BuildContext context, WidgetRef ref, RecentActivity activity, AppStrings s) async {
    if (activity.type == 'manga') {
      final url = activity.metadata['url'];
      if (url != null) {
         Navigator.push(context, MaterialPageRoute(builder: (_) => WebviewReaderScreen(url: url, title: activity.title)));
      }
    } else if (activity.type == 'deck') {
      final deckId = activity.metadata['deckId'];
      final method = activity.metadata['method'];
      if (deckId != null && method != null) {
         final vocabRepo = ref.read(vocabRepositoryProvider);
         final deck = await vocabRepo.getDeckById(deckId);
         if (deck != null) {
            if (deck.deckType == DeckType.kanji && method == 'practice') {
               // Specialized continuation for Kanji drawings
               final vocabList = await vocabRepo.getVocabForDeck(deckId);
               final kanjiRegex = RegExp(r'[\u4E00-\u9FAF]');
               final kanjiChars = <String>[];
               final readings = <String>[];
               for (var v in vocabList) {
                 final text = v.kanji ?? v.kana;
                 for (var m in kanjiRegex.allMatches(text)) {
                   final c = m.group(0)!;
                   if (!kanjiChars.contains(c)) {
                     kanjiChars.add(c);
                     readings.add(v.kana);
                   }
                 }
               }
               if (!context.mounted) return;
               Navigator.push(context, MaterialPageRoute(
                 builder: (_) => PracticeSessionScreen(characterSet: CharacterSet(deck.name, '${kanjiChars.length} Kanji', kanjiChars, readings, deckId: deckId)),
               ));
            } else {
               // Standard DeckStudyScreen resumption
               final sessionService = ref.read(deckSessionServiceProvider);
               final vocabList = await vocabRepo.getVocabForDeck(deckId);
               final session = await sessionService.getActiveSession(deckId, method);
               
               if (!context.mounted) return;
               
               if (activity.metadata['isCompleted'] == true) {
                  DeckStudyScreen.start(context, deck, vocabList, method: method);
               } else if (session != null) {
                  DeckStudyScreen.start(context, deck, vocabList, method: method, session: session);
               } else {
                  DeckStudyScreen.start(context, deck, vocabList, method: method);
               }
            }
         }
      }
    } else if (activity.type == 'lesson') {
       final unitId = activity.metadata['unitId'];
       final lessonId = activity.metadata['lessonId'];
       if (unitId != null && lessonId != null) {
          try {
             final unit = CourseData.units.firstWhere((u) => u.id == unitId);
             final lesson = unit.lessons.firstWhere((l) => l.id == lessonId);
             Navigator.push(context, MaterialPageRoute(builder: (_) => LessonScreen(lesson: lesson)));
          } catch (_) {
             // Fallback gracefully if not found
          }
       }
    }
  }

  Widget _buildSrsGrid(BuildContext context, AppStrings s, Color color, Color border, DashboardStats? stats) {
    final dueVocab = stats?.dueVocabCount ?? 0;
    final dueKanji = stats?.dueKanjiCount ?? 0;
    return Row(
      children: [
        Expanded(
          child: _buildFlatCard(
            color: color, border: border,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalReviewScreen())),
            child: Column(
              children: [
                const Icon(Icons.style_outlined, color: Colors.purpleAccent, size: 24),
                const SizedBox(height: 8),
                Text(s.globalVocabSrs, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                Text('$dueVocab fällig', style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFlatCard(
            color: color, border: border,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalReviewScreen(isKanjiOnly: true))),
            child: Column(
              children: [
                const Icon(Icons.brush_outlined, color: Colors.orangeAccent, size: 24),
                const SizedBox(height: 8),
                Text(s.kanjiSrs, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center),
                Text('$dueKanji fällig', style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlatCard({required Widget child, required Color color, required Color border, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: child,
      ),
    );
  }
}
