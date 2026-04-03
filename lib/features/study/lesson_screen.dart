import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/services/settings_service.dart';
import '../../core/services/streak_service.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/models/lesson.dart';

enum LessonStepType { vocabulary, grammar, exercise }

class LessonStep {
  final LessonStepType type;
  final Exercise? exercise;
  final bool isReinserted; // Reinserted exercises don't count toward accuracy
  LessonStep({required this.type, this.exercise, this.isReinserted = false});
}

class LessonScreen extends ConsumerStatefulWidget {
  final Lesson lesson;
  final int initialIndex;
  final void Function(int currentIndex, int correctCount, int wrongCount)? onProgress;
  final void Function(bool passed)? onCompleted;
  final void Function(String questionOrAnswer, bool correct)? onVocabAnswered;

  const LessonScreen({
    super.key, 
    required this.lesson,
    this.initialIndex = 0,
    this.onProgress,
    this.onCompleted,
    this.onVocabAnswered,
  });

  @override
  ConsumerState<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends ConsumerState<LessonScreen> {
  late int _currentIndex;
  String? _selectedOption;
  bool _isAnswerRevealed = false;
  String _feedback = '';
  Color _feedbackColor = Colors.transparent;
  
  String? _droppedWord;
  late List<LessonStep> _steps;
  
  // Accuracy tracking
  int _correctCount = 0;
  int _totalScoredCount = 0; // Only non-reinserted exercises
  
  // For TypingExercise & ListeningTypingExercise
  final TextEditingController _textController = TextEditingController();
  
  // For MatchingExercise
  final Map<String, String> _userPairs = {};
  String? _selectedLeft;
  String? _selectedRight;

  // For SentenceBuildingExercise
  final List<String> _builtSentence = [];
  late List<String> _sentenceWordBank;

  // 3x wrong skip tracking
  int _wrongStreak = 0;

  final FlutterTts _tts = FlutterTts();

  // Speech-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _sttAvailable = false;
  bool _isListening = false;
  String _sttResult = '';

  List<String> _matchingLeftItems = [];
  List<String> _matchingRightItems = [];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initTts();
    // _initStt(); // This was replaced by the inline _speech.initialize call
    _speech.initialize(
      onStatus: (status) => debugPrint('STT Status: $status'),
      onError: (error) => debugPrint('STT Error: $error'),
    ).then((available) {
      if (mounted) setState(() => _sttAvailable = available);
    });

    // Record activity for Dashboard "Continue"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentActivityProvider.notifier).record(RecentActivity(
        id: 'unit_lesson_${widget.lesson.id}',
        type: 'lesson',
        title: 'Lektion: ${widget.lesson.title}',
        subtitle: 'Lerne Grammatik & Vokabeln',
        metadata: {'unitId': widget.lesson.unitId ?? 'unknown', 'lessonId': widget.lesson.id},
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ));
    });

    
    _steps = [];
    
    final settings = ref.read(settingsProvider);
    
    // Vocab learning step (if there's vocab)
    if (widget.lesson.vocabularyList.isNotEmpty) {
      _steps.add(LessonStep(type: LessonStepType.vocabulary));
    }
    
    // Grammar explanation step (if there's grammar)
    if (widget.lesson.grammarExplanation.isNotEmpty) {
      _steps.add(LessonStep(type: LessonStepType.grammar));
    }
    
    // All exercises from CourseData (deterministic, no dynamic generation)
    for (var e in widget.lesson.exercises) {
      // Filter out speaking exercises if disabled
      if (e is SpeakingExercise && !settings.speakingExercisesEnabled) continue;
      _steps.add(LessonStep(type: LessonStepType.exercise, exercise: e));
    }
    
    // Phase 3: Enforce 90% gate for Unit Tests if no accuracy is set
    _requiredAccuracy = widget.lesson.requiredAccuracy ?? 
        (widget.lesson.lessonType == LessonType.unitTest ? 0.9 : 0.0);
    
    _initExerciseState();
  }

  late double _requiredAccuracy;

  void _initExerciseState() {
    if (_currentIndex < _steps.length) {
      final step = _steps[_currentIndex];
      if (step.type == LessonStepType.exercise && step.exercise != null) {
        final ex = step.exercise!;
        if (ex is MatchingExercise) {
          _matchingLeftItems = List.from(ex.pairs.keys)..shuffle();
          _matchingRightItems = List.from(ex.pairs.values)..shuffle();
        } else if (ex is SentenceBuildingExercise) {
          _sentenceWordBank = List.from(ex.wordBank)..shuffle();
        }
      }
    }
  }

  void _initTts() async {
    await _tts.setLanguage("ja-JP");
    await _tts.setSpeechRate(0.4);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _initStt() async {
    _sttAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (mounted) setState(() => _isListening = false);
      },
    );
  }

  void _speak(String text) async {
    await _tts.speak(text);
  }

  Future<void> _startListening() async {
    if (!_sttAvailable) return;
    _sttResult = '';
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _sttResult = result.recognizedWords;
          });
        }
      },
      localeId: 'ja_JP',
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    if (_isAnswerRevealed) return;

    final currentStep = _steps[_currentIndex];
    
    if (currentStep.type != LessonStepType.exercise) {
      _nextExercise();
      return;
    }

    final currentExercise = currentStep.exercise!;
    bool isCorrect = false;

    // No more legacy pipe localize — translations are now direct
    String loc(String? s) => s ?? '';

    if (currentExercise is MultipleChoiceExercise) {
      isCorrect = _selectedOption == loc(currentExercise.correctOption);
    } else if (currentExercise is FillInBlankExercise) {
      isCorrect = _droppedWord == currentExercise.correctAnswer;
    } else if (currentExercise is TypingExercise) {
      // Dot optional: strip trailing dots/periods from both sides
      final userAns = _textController.text.trim().replaceAll(RegExp(r'[。\.]+$'), '');
      final correctAns = currentExercise.answer.trim().replaceAll(RegExp(r'[。\.]+$'), '');
      isCorrect = userAns == correctAns;
    } else if (currentExercise is MatchingExercise) {
       isCorrect = true;
       for (var entry in currentExercise.pairs.entries) {
         if (_userPairs[entry.key] != loc(entry.value)) {
            isCorrect = false;
            break;
         }
       }
    } else if (currentExercise is SentenceBuildingExercise) {
       isCorrect = _builtSentence.join('') == currentExercise.correctWords.join('');
    } else if (currentExercise is ListeningExercise) {
      isCorrect = _selectedOption == loc(currentExercise.correctOption);
    } else if (currentExercise is ListeningTypingExercise) {
      final userAns = _textController.text.trim().replaceAll(RegExp(r'[。\.]+$'), '');
      final correctAns = currentExercise.correctAnswer.trim().replaceAll(RegExp(r'[。\.]+$'), '');
      isCorrect = userAns == correctAns;
    } else if (currentExercise is SpeakingExercise) {
      // Compare STT result if available
      final loc = AppStrings(ref.read(settingsProvider).appLanguage);
      if (!_sttAvailable) {
         isCorrect = true; // Fallback pass
      } else {
        final target = currentExercise.targetText.replaceAll(RegExp(r'[\s　]+'), '').toLowerCase();
        final spoken = _sttResult.replaceAll(RegExp(r'[\s　]+'), '').toLowerCase();
        isCorrect = target == spoken || spoken.contains(target) || target.contains(spoken);
        
        if (!isCorrect) {
           // DO NOT FAIL THE USER! Just tell them to try again, no penalty!
           setState(() {
              _feedback = 'Versuch es nochmal! ($spoken)';
              _feedbackColor = Colors.orange;
              _sttResult = ''; // clear for next try
           });
           return; // Early return to avoid marking answer as revealed or wrong
        }
      }
    } else if (currentExercise is FlashcardExercise) {
      isCorrect = true; // Flow continues, user handles quality evaluation
    }

    // Track accuracy (only for non-reinserted exercises)
    if (!currentStep.isReinserted) {
      _totalScoredCount++;
      if (isCorrect) _correctCount++;
      
      if (widget.onVocabAnswered != null) {
        String query = '';
        if (currentExercise is MultipleChoiceExercise) query = currentExercise.question;
        else if (currentExercise is TypingExercise) query = currentExercise.question;
        else if (currentExercise is ListeningExercise) query = currentExercise.audioText;
        else if (currentExercise is SpeakingExercise) query = currentExercise.targetText;
        else if (currentExercise is MatchingExercise) query = currentExercise.pairs.keys.first;
        
        if (query.isNotEmpty) {
          widget.onVocabAnswered!(query, isCorrect);
        }
      }
    }

    // Track wrong streak
    if (isCorrect) {
      _wrongStreak = 0;
    } else {
      _wrongStreak++;
    }

    setState(() {
      _isAnswerRevealed = true;
      if (isCorrect) {
        _feedback = 'Richtig! ✓';
        _feedbackColor = Colors.green;
      } else {
        _feedback = _getIncorrectFeedback(currentExercise);
        _feedbackColor = Colors.redAccent;
        
        // Error reinsertion: insert similar exercise 3-5 steps ahead
        _reinsertExercise(currentExercise);
      }
    });
  }

  /// Skip exercise after 3 wrong — costs 5% accuracy
  void _skipExercise() {
    // Deduct 5% from accuracy
    final penalty = (_totalScoredCount * 0.05).ceil().clamp(1, 3);
    _totalScoredCount += penalty; // Add penalty as missed answers
    _wrongStreak = 0;
    setState(() {
      _feedback = 'Übersprungen (−5% Genauigkeit)';
      _feedbackColor = Colors.orange;
      _isAnswerRevealed = true;
    });
  }

  String _getIncorrectFeedback(Exercise exercise) {
    String loc(String? s) => s ?? '';

    if (exercise is MultipleChoiceExercise) return 'Falsch. Antwort: ${loc(exercise.correctOption)}';
    if (exercise is FillInBlankExercise) return 'Falsch. Antwort: ${exercise.correctAnswer}';
    if (exercise is TypingExercise) {
      final user = _textController.text.trim();
      final correct = exercise.answer;
      if (user.isEmpty) return 'Falsch. Antwort: $correct';
      return 'Falsch. Richtig: $correct\nDeine Eingabe: $user';
    }
    if (exercise is MatchingExercise) return 'Falsch. Einige Zuordnungen sind falsch.';
    if (exercise is SentenceBuildingExercise) return 'Falsch. Richtig: ${exercise.correctWords.join(' ')}';
    if (exercise is ListeningExercise) return 'Falsch. Antwort: ${loc(exercise.correctOption)}';
    if (exercise is ListeningTypingExercise) {
      final user = _textController.text.trim();
      return 'Falsch. Richtig: ${exercise.correctAnswer}\nDeine Eingabe: $user';
    }
    return 'Falsch.';
  }

  void _reinsertExercise(Exercise exercise) {
    // Insert a copy 3-5 positions ahead (reinserted = true, doesn't count)
    final insertAt = (_currentIndex + 4).clamp(0, _steps.length);
    _steps.insert(insertAt, LessonStep(
      type: LessonStepType.exercise,
      exercise: exercise, // Same exercise, could vary vocab in future
      isReinserted: true,
    ));
  }

  void _handleSpeakingSelfEval(bool correct) {
    final currentStep = _steps[_currentIndex];
    final s = AppStrings(ref.read(settingsProvider).appLanguage);
    if (!currentStep.isReinserted) {
      _totalScoredCount++;
      if (correct) _correctCount++;
      
      if (widget.onVocabAnswered != null && currentStep.exercise is SpeakingExercise) {
        widget.onVocabAnswered!((currentStep.exercise as SpeakingExercise).targetText, correct);
      }
    }
    if (!correct) {
      _reinsertExercise(currentStep.exercise!);
    }
    setState(() {
      _isAnswerRevealed = true;
      _feedback = correct ? s.greatJob : s.keepPracticing;
      _feedbackColor = correct ? Colors.green : Colors.orange;
      _sttResult = '';
    });
  }

  void _handleFlashcardEval(int quality) {
    // quality: 0=Again, 1=Hard, 2=Good, 3=Easy
    final currentStep = _steps[_currentIndex];
    final s = AppStrings(ref.read(settingsProvider).appLanguage);
    
    final bool correct = quality >= 2;
    
    if (!currentStep.isReinserted) {
      _totalScoredCount++;
      if (correct) _correctCount++;
      
      if (widget.onVocabAnswered != null && currentStep.exercise is FlashcardExercise) {
        widget.onVocabAnswered!((currentStep.exercise as FlashcardExercise).question, correct);
      }
    }
    
    if (!correct) {
      _reinsertExercise(currentStep.exercise!);
    }
    
    setState(() {
      _isAnswerRevealed = true;
      _feedback = correct ? s.greatJob : s.keepPracticing;
      _feedbackColor = correct ? Colors.green : Colors.orange;
    });
  }

  /// Skip speaking exercise without penalty (always available)
  void _skipSpeakingExercise() {
    final s = AppStrings(ref.read(settingsProvider).appLanguage);
    setState(() {
      _isAnswerRevealed = true;
      _feedback = s.skippedSpeaking;
      _feedbackColor = Colors.grey;
      _sttResult = '';
    });
  }

  void _nextExercise() {
    if (_currentIndex < _steps.length - 1) {
      if (widget.onProgress != null) {
         widget.onProgress!(_currentIndex + 1, _correctCount, _totalScoredCount - _correctCount);
      }
      setState(() {
        _currentIndex++;
        _isAnswerRevealed = false;
        _selectedOption = null;
        _droppedWord = null;
        _feedback = '';
        _feedbackColor = Colors.transparent;
        _textController.clear();
        _userPairs.clear();
        _selectedLeft = null;
        _selectedRight = null;
        _builtSentence.clear();
        _initExerciseState();
      });
    } else {
      // Lesson finished — check accuracy gate
      _showCompletionScreen();
    }
  }

  void _showCompletionScreen() {
    final s = AppStrings(ref.read(settingsProvider).appLanguage);
    final accuracy = _totalScoredCount > 0 ? _correctCount / _totalScoredCount : 1.0;
    final accuracyPct = (accuracy * 100).toStringAsFixed(0);
    final passed = accuracy >= _requiredAccuracy;
    final requiredPct = (_requiredAccuracy * 100).toStringAsFixed(0);

    if (passed) {
      ref.read(streakProvider.notifier).recordStudyActivity();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(passed ? '🎉 ${s.lessonComplete}' : '❌ ${s.incorrectGeneric}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$accuracyPct% ${s.accuracy}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: passed ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text('$_correctCount / $_totalScoredCount'),
            if (!passed) ...[
              const SizedBox(height: 16),
              Text(
                'Benötigt: $requiredPct% Genauigkeit',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onCompleted != null) {
                widget.onCompleted!(passed);
              }
              Navigator.pop(context, passed);
            },
            child: Text(passed ? s.nextStep : s.backToPath),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.lesson.title)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text('Diese Lektion hat keinen Inhalt.', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zurück zum Lernpfad'),
              ),
            ],
          ),
        ),
      );
    }
    final currentStep = _steps[_currentIndex];
    final totalExercises = _steps.where((s) => s.type == LessonStepType.exercise && !s.isReinserted).length;
    final currentExerciseNum = _steps.take(_currentIndex + 1).where((s) => s.type == LessonStepType.exercise && !s.isReinserted).length;
    
    // Lesson type label
    String lessonTypeLabel;
    switch (widget.lesson.lessonType) {
      case LessonType.vocabGate:
        lessonTypeLabel = 'Vokabeltest';
        break;
      case LessonType.grammarIntro:
        lessonTypeLabel = 'Grammatik';
        break;
      case LessonType.grammarProduction:
        lessonTypeLabel = 'Übungen';
        break;
      case LessonType.mixedReinforcement:
        lessonTypeLabel = 'Wiederholung';
        break;
      case LessonType.unitTest:
        lessonTypeLabel = 'Abschlusstest';
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.lesson.title, style: const TextStyle(fontSize: 16)),
            Text(lessonTypeLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: _steps.isEmpty ? 0 : (_currentIndex + 1) / _steps.length,
          ),
          // Accuracy indicator
          if (_totalScoredCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Genauigkeit: ${(_totalScoredCount > 0 ? (_correctCount / _totalScoredCount * 100).toStringAsFixed(0) : "—")}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: (_correctCount / _totalScoredCount) >= (widget.lesson.requiredAccuracy ?? 0.0) 
                          ? Colors.green : Colors.orange,
                    ),
                  ),
                  if (widget.lesson.requiredAccuracy != null)
                    Text(
                      ' / ${(widget.lesson.requiredAccuracy! * 100).toStringAsFixed(0)}% benötigt',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
            ),
          // Step counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currentStep.type == LessonStepType.exercise
                    ? 'Übung $currentExerciseNum / $totalExercises'
                    : currentStep.type == LessonStepType.vocabulary ? 'Vokabeln' : 'Grammatik',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (currentStep.isReinserted)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Wiederholung', style: TextStyle(fontSize: 11, color: Colors.orange)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepContent(currentStep),
            ),
          ),
          // Feedback + buttons
          if (_feedback.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: _feedbackColor.withAlpha(30),
              child: Text(_feedback, style: TextStyle(color: _feedbackColor, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Skip button — shows after 3 wrong answers in a row
                  if (_wrongStreak >= 3 && !_isAnswerRevealed)
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _skipExercise,
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                            child: const Text('Überspringen\n(-5%)', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 56,
                      child: (currentStep.type == LessonStepType.exercise && currentStep.exercise is FlashcardExercise && _isAnswerRevealed && _feedback.isEmpty)
                        ? Row(
                            children: [
                              _buildEvalBtn(0, 'Nochmal', Colors.red),
                              const SizedBox(width: 4),
                              _buildEvalBtn(1, 'Schwer', Colors.orange),
                              const SizedBox(width: 4),
                              _buildEvalBtn(2, 'Gut', Colors.green),
                              const SizedBox(width: 4),
                              _buildEvalBtn(3, 'Leicht', Colors.blue),
                            ],
                          )
                        : ElevatedButton(
                            onPressed: _isAnswerRevealed ? _nextExercise : _checkAnswer,
                            child: Text(
                              _isAnswerRevealed ? 'Weiter' 
                                : (currentStep.type != LessonStepType.exercise ? 'Weiter' : (currentStep.exercise is FlashcardExercise ? 'Umdrehen' : 'Prüfen')),
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(LessonStep step) {
    final contentLang = ref.watch(settingsProvider).contentLanguage;
    String localize(String? s) => s ?? '';

    if (step.type == LessonStepType.vocabulary) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lerne diese Wörter', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...widget.lesson.vocabularyList.map((v) {
            final word = v['word'] ?? '';
            final reading = v['reading'] ?? '';
            return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Row(
                children: [
                  Text(word, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (reading.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(reading, style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(localize(v['translation']), style: const TextStyle(fontSize: 16)),
                  if (v['example'] != null) ...[
                    const SizedBox(height: 4),
                    Text(v['example']!, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                    if (v['example_translation'] != null)
                      Text(localize(v['example_translation']), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.volume_up),
                onPressed: () => _speak(word),
              ),
            ),
          );
          }),
        ],
      );
    }
    
    if (step.type == LessonStepType.grammar) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Grammatik', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(widget.lesson.grammarExplanation, style: const TextStyle(fontSize: 16, height: 1.6)),
        ],
      );
    }
    
    // Exercise
    final exercise = step.exercise!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(exercise.instruction, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        Text(localize(exercise.question), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildExerciseInteractive(exercise, localize),
      ],
    );
  }

  Widget _buildExerciseInteractive(Exercise exercise, String Function(String?) localize) {
    var theme = Theme.of(context);
    if (exercise is MultipleChoiceExercise) {
      return Column(
        children: _buildMultipleChoiceOptions(exercise.options.map((o) => localize(o)).toList(), localize(exercise.correctOption)),
      );
    } else if (exercise is FillInBlankExercise) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(exercise.sentencePartsBefore, style: const TextStyle(fontSize: 20)),
              DragTarget<String>(
                builder: (context, candidateData, rejectedData) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: candidateData.isNotEmpty ? Colors.blue : Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                      color: _droppedWord != null ? Colors.blue.withAlpha(25) : null,
                    ),
                    child: Text(
                      _droppedWord ?? '___',
                      style: TextStyle(fontSize: 20, color: _droppedWord != null ? Colors.blue : Colors.grey),
                    ),
                  );
                },
                onAcceptWithDetails: (details) {
                  if (!_isAnswerRevealed) setState(() => _droppedWord = details.data);
                },
              ),
              Text(exercise.sentencePartsAfter, style: const TextStyle(fontSize: 20)),
            ],
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: exercise.wordBank.map((word) => Draggable<String>(
              data: word,
              feedback: Material(child: Chip(label: Text(word, style: const TextStyle(fontSize: 18)))),
              childWhenDragging: Opacity(opacity: 0.3, child: Chip(label: Text(word, style: const TextStyle(fontSize: 18)))),
              child: ActionChip(
                label: Text(word, style: const TextStyle(fontSize: 18)),
                onPressed: _isAnswerRevealed ? null : () => setState(() => _droppedWord = word),
              ),
            )).toList(),
          ),
        ],
      );
    } else if (exercise is TypingExercise) {
      return Column(
        children: [
          if (exercise.hint != null && _wrongStreak >= 2) ...[
            Text('Hinweis: ${exercise.hint}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _textController,
            enabled: !_isAnswerRevealed,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: 'Deine Antwort',
              suffixIcon: _isAnswerRevealed 
                ? Icon(
                    _textController.text.trim() == exercise.answer.trim() ? Icons.check_circle : Icons.error,
                    color: _textController.text.trim() == exercise.answer.trim() ? Colors.green : Colors.red,
                  ) 
                : null,
            ),
            style: const TextStyle(fontSize: 20),
            onSubmitted: (_) => _checkAnswer(),
          ),
        ],
      );
    } else if (exercise is MatchingExercise) {
       return Row(
         children: [
           Expanded(
             child: Column(
               children: _matchingLeftItems.map((item) {
                 final isSelected = _selectedLeft == item;
                 final isMatched = _userPairs.containsKey(item);
                 return _buildMatchingCard(item, isSelected, isMatched, true);
               }).toList(),
             ),
           ),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               children: _matchingRightItems.map((item) {
                 final isSelected = _selectedRight == item;
                 final isMatched = _userPairs.containsValue(item);
                 return _buildMatchingCard(item, isSelected, isMatched, false);
               }).toList(),
             ),
           ),
         ],
       );
    } else if (exercise is SentenceBuildingExercise) {
       return Column(
         children: [
           Container(
             padding: const EdgeInsets.all(16),
             constraints: const BoxConstraints(minHeight: 100),
             decoration: BoxDecoration(
               border: Border.all(color: Colors.grey.shade400),
               borderRadius: BorderRadius.circular(12),
               color: Colors.grey.shade50,
             ),
             child: Wrap(
               spacing: 8,
               runSpacing: 8,
               children: _builtSentence.map((word) => Chip(
                 label: Text(word, style: const TextStyle(fontSize: 16)),
                 onDeleted: _isAnswerRevealed ? null : () {
                   setState(() {
                     _builtSentence.remove(word);
                     _sentenceWordBank.add(word);
                   });
                 },
               )).toList(),
             ),
           ),
           const SizedBox(height: 32),
           Wrap(
             spacing: 8,
             runSpacing: 8,
             children: _sentenceWordBank.map((word) => ActionChip(
               label: Text(word, style: const TextStyle(fontSize: 16)),
               onPressed: _isAnswerRevealed ? null : () {
                 setState(() {
                   _builtSentence.add(word);
                   _sentenceWordBank.remove(word);
                 });
               },
             )).toList(),
           ),
         ],
       );
      } else if (exercise is ListeningExercise) {
        return Column(
          children: [
            Center(
              child: IconButton(
                iconSize: 64,
                icon: const Icon(Icons.volume_up, color: Colors.blue),
                onPressed: () => _speak(exercise.audioText),
              ),
            ),
            const Center(child: Text('Tippe zum Anhören', style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 32),
            ..._buildMultipleChoiceOptions(exercise.options.map((o) => localize(o)).toList(), localize(exercise.correctOption)),
          ],
        );
     } else if (exercise is ListeningTypingExercise) {
        return Column(
          children: [
            Center(
              child: IconButton(
                iconSize: 64,
                icon: const Icon(Icons.volume_up, color: Colors.blue),
                onPressed: () => _speak(exercise.audioText),
              ),
            ),
            const Center(child: Text('Höre zu und tippe was du hörst', style: TextStyle(color: Colors.grey))),
            const SizedBox(height: 24),
            if (exercise.hint != null) ...[
              Text('Hinweis: ${exercise.hint}', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _textController,
              enabled: !_isAnswerRevealed,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Deine Antwort',
                suffixIcon: _isAnswerRevealed 
                  ? Icon(
                      _textController.text.trim() == exercise.correctAnswer.trim() ? Icons.check_circle : Icons.error,
                      color: _textController.text.trim() == exercise.correctAnswer.trim() ? Colors.green : Colors.red,
                    ) 
                  : null,
              ),
              style: const TextStyle(fontSize: 20),
              onSubmitted: (_) => _checkAnswer(),
            ),
          ],
        );
      } else if (exercise is SpeakingExercise) {
        final s = AppStrings(ref.read(settingsProvider).appLanguage);
        return Column(
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(16),
                color: Colors.blue.withAlpha(15),
              ),
              child: Column(
                children: [
                   Text(s.sayAloud, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                   const SizedBox(height: 12),
                   Text(exercise.targetText, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                   if (exercise.translation != null) ...[
                     const SizedBox(height: 8),
                     Text(localize(exercise.translation), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                   ],
                 ],
               ),
             ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.volume_up),
                    label: Text(s.hearModel),
                    onPressed: () => _speak(exercise.targetText),
                  ),
                ),
              ],
            ),
            if (!_isAnswerRevealed) ...[
              const SizedBox(height: 16),
              // STT Mic Button
              if (_sttAvailable) ...[
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _isListening ? _stopListening : _startListening,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening ? Colors.red : Colors.blue,
                            boxShadow: _isListening ? [
                              BoxShadow(color: Colors.red.withAlpha(100), blurRadius: 20, spreadRadius: 5),
                            ] : null,
                          ),
                          child: Icon(
                            _isListening ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isListening ? s.listening : s.tapToSpeak,
                        style: TextStyle(color: _isListening ? Colors.red : Colors.grey),
                      ),
                      if (_sttResult.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _sttResult,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_sttResult.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _checkAnswer,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: Text(s.checkAnswer),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              // Skip button (always available for speaking)
              TextButton.icon(
                icon: const Icon(Icons.skip_next, color: Colors.grey),
                label: Text(s.skipSpeaking, style: const TextStyle(color: Colors.grey)),
                onPressed: _skipSpeakingExercise,
              ),
            ],
          ],
        );
      } else if (exercise is FlashcardExercise) {
        return Column(
          children: [
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Text(exercise.question, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  if (exercise.hint != null) ...[
                    const SizedBox(height: 8),
                    Text(exercise.hint!, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                  if (_isAnswerRevealed) ...[
                    const Divider(height: 48),
                    Text(exercise.answer, style: const TextStyle(fontSize: 32, color: Colors.blue, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (!_isAnswerRevealed)
              const Text('Versuche dich an die Bedeutung zu erinnern.', style: TextStyle(color: Colors.grey)),
          ],
        );
      }
    
    return const Center(child: Text('Unbekannter Übungstyp'));
  }

  List<Widget> _buildMultipleChoiceOptions(List<String> options, String correctOption) {
    return options.map((option) {
      final isSelected = _selectedOption == option;
      Color? cardColor;
      if (_isAnswerRevealed) {
        if (option == correctOption) {
          cardColor = Colors.green.withAlpha(80); // Brighter
        } else if (isSelected) {
          cardColor = Colors.red.withAlpha(80); // Brighter
        } else {
          cardColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        }
      } else if (isSelected) {
        cardColor = Colors.blue.shade700; // Distinct high contrast color
      } else {
        cardColor = Theme.of(context).colorScheme.surfaceContainerHighest;
      }

      return Card(
        color: cardColor,
        elevation: isSelected && !_isAnswerRevealed ? 4 : 0, // Lift up when selected
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isSelected && !_isAnswerRevealed 
              ? Theme.of(context).primaryColor.withAlpha(100) 
              : (_isAnswerRevealed && option == correctOption ? Colors.green : Colors.transparent),
            width: isSelected || (_isAnswerRevealed && option == correctOption) ? 3 : 0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: _isAnswerRevealed ? null : () {
            setState(() => _selectedOption = option);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(
              child: Text(option, 
                style: TextStyle(
                  fontSize: 18, 
                  color: (isSelected && !_isAnswerRevealed) ? Colors.white : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                )),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildMatchingCard(String text, bool isSelected, bool isMatched, bool isLeft) {
    Color? cardColor;
    if (isMatched) {
       cardColor = Colors.green.withAlpha(80);
    } else if (isSelected) {
       cardColor = Theme.of(context).primaryColor.withAlpha(200);
    } else {
       cardColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    }

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isMatched ? Colors.green : (isSelected ? Theme.of(context).primaryColor.withAlpha(100) : Colors.transparent),
          width: isMatched || isSelected ? 3 : 0,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: _isAnswerRevealed ? null : () {
          setState(() {
            if (isLeft) {
              _selectedLeft = text;
            } else {
              _selectedRight = text;
            }
            
            if (_selectedLeft != null && _selectedRight != null) {
              _userPairs[_selectedLeft!] = _selectedRight!;
              _matchingLeftItems.remove(_selectedLeft);
              _matchingRightItems.remove(_selectedRight);
              _selectedLeft = null;
              _selectedRight = null;
            }
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Center(
            child: Text(text, 
              style: TextStyle(
                 fontSize: 16,
                 color: (isSelected && !isMatched) ? Colors.white : null,
                 fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
              ), 
              textAlign: TextAlign.center
            )
          ),
        ),
      ),
    );
  }

  Widget _buildEvalBtn(int quality, String label, Color color) {
    return Expanded(
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => _handleFlashcardEval(quality),
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
