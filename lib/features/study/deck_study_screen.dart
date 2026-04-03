import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/models/lesson.dart';
import '../../core/models/vocab.dart';
import '../../core/services/streak_service.dart';
import 'lesson_screen.dart';

import '../../core/services/deck_session_service.dart';
import '../../core/models/deck.dart';

/// Generates a virtual Lesson from deck vocabulary and opens LessonScreen.
class DeckStudyScreen {
  /// Creates a Lesson with auto-generated exercises from vocab list and navigates to it.
  /// [method] can be: 'all' (default / unit-style), 'flashcards', 'typing_writing', 'typing_reading'
  /// [contentLang] determines which translation is shown (e.g. 'de' for German)
  static Future<void> start(
    BuildContext context, 
    Deck deck, 
    List<Vocab> vocabList, {
    String method = 'all', 
    bool speakingEnabled = true, 
    String contentLang = 'de',
    DeckSession? session,
  }) async {
    final sessionService = ProviderScope.containerOf(context).read(deckSessionServiceProvider);
    
    // Check for active session
    final activeSession = await sessionService.getActiveSession(deck.id!, method);
    
    if (activeSession != null && activeSession.currentIndex > 0 && !activeSession.isCompleted) {
      if (!context.mounted) return;
      final resume = await showDialog<bool>(
        context: context,
        builder: (dlg) => AlertDialog(
          title: Text('Übung fortsetzen (${(activeSession.progressPercent * 100).toInt()}%)?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlg, false),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Neustart'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dlg, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Ja, fortsetzen', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (!context.mounted) return;
      if (resume == true) {
        return _launchLesson(context, deck, vocabList, method, speakingEnabled, contentLang, activeSession);
      } else if (resume == false) {
        await sessionService.clearSession(deck.id!, method);
      } else {
        return; // Dialog dismissed
      }
    }

    return _launchLesson(context, deck, vocabList, method, speakingEnabled, contentLang, session);
  }

  static Future<void> _launchLesson(
    BuildContext context, 
    Deck deck, 
    List<Vocab> vocabList, 
    String method, 
    bool speakingEnabled, 
    String contentLang,
    DeckSession? session,
  ) async {
    if (vocabList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Noch keine Vokabeln in diesem Deck.')),
      );
      return;
    }

    // Determine fixed order if resuming
    final fixedOrderIds = session?.shuffledVocabIds;

    final exercises = _generateExercises(
      vocabList, 
      method, 
      speakingEnabled: speakingEnabled, 
      contentLang: contentLang,
      fixedOrderIds: fixedOrderIds,
    );

    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nicht genug Vokabeln für Übungen.')),
      );
      return;
    }
    
    final sessionService = ProviderScope.containerOf(context).read(deckSessionServiceProvider);
    
     // Create or use existing session
    DeckSession activeSession = session ?? DeckSession(
      deckId: deck.id!,
      method: method,
      currentIndex: 0,
      totalItems: exercises.length,
      lastStudiedAt: DateTime.now().millisecondsSinceEpoch,
      shuffledVocabIds: vocabList.map((v) => v.id!).toList(), // Save final order
    );
    
    // Save initial if new
    if (activeSession.id == null) {
       final id = await sessionService.saveSession(activeSession);
       activeSession = DeckSession(
         id: id,
         deckId: deck.id!,
         method: method,
         currentIndex: 0,
         totalItems: exercises.length,
         lastStudiedAt: DateTime.now().millisecondsSinceEpoch,
         shuffledVocabIds: activeSession.shuffledVocabIds,
       );
    }

    // Phase 3/4: Record Recent Activity
    final streakNotifier = ProviderScope.containerOf(context).read(recentActivityProvider.notifier);
    streakNotifier.record(RecentActivity(
      id: 'deck_${deck.id}',
      type: 'deck',
      title: deck.name,
      subtitle: 'Üben: $method',
      metadata: {
        'deckId': deck.id,
        'method': method,
        'progress': 0.0,
        'isCompleted': false,
      },
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));

    // Save last activity reference
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_activity_type', 'study');
    await prefs.setInt('last_activity_deck_id', deck.id!);
    await prefs.setString('last_activity_method', method);

    final lesson = Lesson(
      id: 'deck_practice_${DateTime.now().millisecondsSinceEpoch}',
      title: deck.name,
      description: 'Übungen für dein Deck.',
      lessonType: LessonType.grammarProduction,
      vocabularyList: vocabList.map((v) {
        final word = v.kanji ?? v.kana;
        final reading = (v.kanji != null && v.kanji!.isNotEmpty && v.kanji != v.kana) ? v.kana : '';
        return {
          'word': word,
          'reading': reading,
          'translation': v.localizedTranslation(contentLang),
        };
      }).toList(),
      exercises: exercises,
    );

    if (!context.mounted) return;

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => LessonScreen(
          lesson: lesson,
          initialIndex: activeSession.currentIndex,
          onProgress: (currentIndex, correctCount, wrongCount) {
             final updatedSession = DeckSession(
               id: activeSession.id,
               deckId: activeSession.deckId,
               method: activeSession.method,
               currentIndex: currentIndex,
               totalItems: activeSession.totalItems,
               correctCount: correctCount,
               wrongCount: wrongCount,
               lastStudiedAt: DateTime.now().millisecondsSinceEpoch,
               isCompleted: false,
               shuffledVocabIds: activeSession.shuffledVocabIds,
             );
             sessionService.saveSession(updatedSession);

             // Update recent activity progress
             streakNotifier.record(RecentActivity(
                id: 'deck_${deck.id}',
                type: 'deck',
                title: deck.name,
                subtitle: 'Üben: $method',
                metadata: {
                  'deckId': deck.id,
                  'method': method,
                  'progress': currentIndex / exercises.length,
                  'isCompleted': false,
                },
                timestamp: DateTime.now().millisecondsSinceEpoch,
             ));
          },
          onCompleted: (passed) {
             sessionService.completeSession(activeSession.id!);

             // Mark as completed in recent activities
             streakNotifier.record(RecentActivity(
                id: 'deck_${deck.id}',
                type: 'deck',
                title: deck.name,
                subtitle: 'Abgeschlossen: $method',
                metadata: {
                  'deckId': deck.id,
                  'method': method,
                  'progress': 1.0,
                  'isCompleted': true,
                },
                timestamp: DateTime.now().millisecondsSinceEpoch,
             ));
          },
          onVocabAnswered: (query, correct) {
             try {
                final vocab = vocabList.firstWhere((v) => 
                   (v.kana == query) || 
                   (v.kanji == query) || 
                   (v.localizedTranslation(contentLang) == query) ||
                   (query.contains(v.kana)) ||
                   (v.kanji != null && query.contains(v.kanji!))
                );
                if (vocab.id != null) {
                   sessionService.recordAnswer(vocab.id!, correct);
                }
             } catch (_) {}
          },
        ),
      ),
    );
  }

  static List<Exercise> _generateExercises(
    List<Vocab> vocabList, 
    String method, {
    bool speakingEnabled = true, 
    String contentLang = 'de',
    List<int>? fixedOrderIds,
  }) {
    final exercises = <Exercise>[];
    
    List<Vocab> workingList;
    if (fixedOrderIds != null) {
      // Re-order based on saved IDs
      workingList = [];
      for (var id in fixedOrderIds) {
        try {
          workingList.add(vocabList.firstWhere((v) => v.id == id));
        } catch (_) {}
      }
      // If some are missing or new, add them at the end
      final missing = vocabList.where((v) => !fixedOrderIds.contains(v.id)).toList();
      workingList.addAll(missing);
    } else {
      workingList = List<Vocab>.from(vocabList)..shuffle();
    }

    final shuffled = workingList;

    // Helper to get localized translation
    String tr(Vocab v) => v.localizedTranslation(contentLang);

    switch (method) {
      case 'flashcards':
        for (var v in shuffled) {
          exercises.add(FlashcardExercise(
            question: v.kanji ?? v.kana,
            instruction: 'Karteikarte',
            answer: tr(v),
            hint: (v.kanji != null && v.kanji!.isNotEmpty && v.kanji != v.kana) ? v.kana : null,
          ));
        }
        break;

      case 'typing_writing':
        for (var v in shuffled) {
          exercises.add(TypingExercise(
            question: tr(v),
            instruction: 'Japanisches Wort eintippen',
            answer: v.kanji ?? v.kana,
            hint: (v.kanji != null && v.kanji!.isNotEmpty && v.kanji != v.kana) ? v.kana : null,
          ));
        }
        break;

      case 'reading_to_translation':
        for (var v in shuffled) {
          exercises.add(TypingExercise(
            question: v.kanji ?? v.kana,
            instruction: 'Bedeutung eintippen',
            answer: tr(v),
          ));
        }
        break;

      default: // 'all' — mixed exercises
        // 1. Matching exercise (up to 6 pairs)
        if (shuffled.length >= 2) {
          final pairs = <String, String>{};
          for (var v in shuffled.take(6)) {
            pairs[v.kanji ?? v.kana] = tr(v);
          }
          exercises.add(MatchingExercise(
            question: 'Ordne die Wörter ihren Übersetzungen zu.',
            instruction: 'Zuordnung',
            pairs: pairs,
          ));
        }

        // 2. JP→Translation Multiple Choice
        for (var v in shuffled) {
          final word = v.kanji ?? v.kana;
          final correctTrans = tr(v);
          final otherTranslations = vocabList
              .where((o) => tr(o) != correctTrans)
              .map((o) => tr(o))
              .toSet()
              .toList()..shuffle();

          if (otherTranslations.length >= 2) {
            exercises.add(MultipleChoiceExercise(
              question: word,
              instruction: 'Was bedeutet das?',
              options: ([correctTrans, ...otherTranslations.take(3)]..shuffle()),
              correctOption: correctTrans,
            ));
          }
        }

        // 3. Translation→JP Typing
        for (var v in shuffled) {
          exercises.add(TypingExercise(
            question: tr(v),
            instruction: 'Japanisches Wort eintippen',
            answer: v.kanji ?? v.kana,
            hint: (v.kanji != null && v.kanji!.isNotEmpty && v.kanji != v.kana) ? v.kana : null,
          ));
        }

        // 4. Listening exercises
        for (var v in shuffled) {
          final correctTrans = tr(v);
          final otherTranslations = vocabList
              .where((o) => tr(o) != correctTrans)
              .map((o) => tr(o))
              .toSet()
              .toList()..shuffle();

          if (otherTranslations.length >= 2) {
            exercises.add(ListeningExercise(
              question: 'Höre zu und wähle die Übersetzung.',
              instruction: 'Hörverständnis',
              audioText: v.kana,
              options: ([correctTrans, ...otherTranslations.take(2)]..shuffle()),
              correctOption: correctTrans,
            ));
          }
        }

        // 5. Speaking (if enabled)
        if (speakingEnabled) {
          for (var v in shuffled.take((shuffled.length * 0.3).ceil())) {
            exercises.add(SpeakingExercise(
              question: 'Sprich das Wort laut aus.',
              instruction: 'Sprechen',
              targetText: v.kanji ?? v.kana,
              translation: tr(v),
            ));
          }
        }
        break;
    }

    if (fixedOrderIds == null) {
      exercises.shuffle();
    }
    return exercises;
  }
}
