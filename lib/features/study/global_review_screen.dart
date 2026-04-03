import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/database/vocab_repository.dart';
import '../../core/models/vocab.dart';
import '../../core/services/srs_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/deck_session_service.dart';
import '../../core/i18n/app_strings.dart';

enum SrsMethod { flashcard, multiChoiceMeaning, multiChoiceTranslation, typing }

/// Global SRS review screen - reviews due vocab from SRS-enabled decks
class GlobalReviewScreen extends ConsumerStatefulWidget {
  final bool isKanjiOnly;
  const GlobalReviewScreen({super.key, this.isKanjiOnly = false});

  @override
  ConsumerState<GlobalReviewScreen> createState() => _GlobalReviewScreenState();
}

class _GlobalReviewScreenState extends ConsumerState<GlobalReviewScreen> {
  List<Vocab> _dueVocab = [];
  int _currentIndex = 0;
  bool _isRevealed = false;
  bool _isLoading = true;
  SrsMethod? _selectedMethod;
  final FlutterTts _tts = FlutterTts();

  // Swipe state (for flashcard mode)
  double _dragX = 0;
  bool _isSwiping = false;
  int _knewCount = 0;
  int _didntKnowCount = 0;

  // Multi-choice state
  String? _selectedOption;
  bool? _answerCorrect;

  // Typing state
  final _typingController = TextEditingController();
  bool _typingSubmitted = false;
  bool _typingCorrect = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage("ja-JP");
    await _tts.setSpeechRate(0.4);
  }

  Future<void> _loadDueVocab() async {
    final vocabRepo = ref.read(vocabRepositoryProvider);
    final allVocab = widget.isKanjiOnly
        ? await vocabRepo.getDueSrsKanji()
        : await vocabRepo.getDueSrsVocab();
    setState(() {
      _dueVocab = allVocab;
      _isLoading = false;
    });
  }

  void _startReview(SrsMethod method) {
    setState(() => _selectedMethod = method);
    _loadDueVocab();
  }

  void _answer(int quality) async {
    final vocab = _dueVocab[_currentIndex];
    final updated = SRSService.calculateNextReview(vocab, quality);

    final vocabRepo = ref.read(vocabRepositoryProvider);
    await vocabRepo.updateVocab(updated);

    final sessionService = ref.read(deckSessionServiceProvider);
    if (vocab.id != null) {
      await sessionService.recordAnswer(vocab.id!, quality >= 3);
    }

    setState(() {
      _isRevealed = false;
      _selectedOption = null;
      _answerCorrect = null;
      _typingController.clear();
      _typingSubmitted = false;
      _typingCorrect = false;
      if (_currentIndex < _dueVocab.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = _dueVocab.length;
      }
    });
  }

  @override
  void dispose() {
    _typingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final s = AppStrings(settings.appLanguage);
    final contentLang = settings.contentLanguage;

    if (_selectedMethod == null) {
      return _buildMethodSelection(context, s);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isKanjiOnly ? s.kanjiSrs : s.globalReview),
        actions: [
          if (_dueVocab.isNotEmpty && _currentIndex < _dueVocab.length)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_currentIndex + 1}/${_dueVocab.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _dueVocab.isEmpty || _currentIndex >= _dueVocab.length
          ? _buildCompletionScreen(s)
          : _buildReviewCard(context, s, contentLang),
    );
  }

  Widget _buildMethodSelection(BuildContext context, AppStrings s) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isKanjiOnly ? s.kanjiSrs : s.globalReview)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.school, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            Text('SRS-Methode wählen', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Wie möchtest du heute lernen?', style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            _methodCard(Icons.flip, 'Karteikarten', 'Karte umdrehen, Schwierigkeit bewerten', SrsMethod.flashcard),
            const SizedBox(height: 12),
            _methodCard(Icons.quiz, 'Multiple Choice (Bedeutung)', 'Japanisch sehen → Deutsche Bedeutung wählen', SrsMethod.multiChoiceMeaning),
            const SizedBox(height: 12),
            _methodCard(Icons.translate, 'Multiple Choice (Übersetzung)', 'Deutsch sehen → Japanisches Wort wählen', SrsMethod.multiChoiceTranslation),
            const SizedBox(height: 12),
            _methodCard(Icons.keyboard, 'Tippen', 'Deutsch sehen → Japanisch eintippen', SrsMethod.typing),
          ],
        ),
      ),
    );
  }

  Widget _methodCard(IconData icon, String title, String subtitle, SrsMethod method) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _startReview(method),
      ),
    );
  }

  Widget _buildCompletionScreen(AppStrings s) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 80, color: Colors.green),
          const SizedBox(height: 16),
          Text(s.allCaughtUp, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(s.noDueCards, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: Text(s.backToDeck),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, AppStrings s, String contentLang) {
    switch (_selectedMethod!) {
      case SrsMethod.flashcard:
        return _buildFlashcard(context, s, contentLang);
      case SrsMethod.multiChoiceMeaning:
        return _buildMultiChoice(context, s, contentLang, isMeaning: true);
      case SrsMethod.multiChoiceTranslation:
        return _buildMultiChoice(context, s, contentLang, isMeaning: false);
      case SrsMethod.typing:
        return _buildTyping(context, s, contentLang);
    }
  }

  bool _isKanjiSameAsKana(Vocab vocab) {
    if (vocab.kanji == null || vocab.kanji!.isEmpty) return true;
    return vocab.kanji == vocab.kana;
  }

  Future<void> _handleSwipe(bool knewIt) async {
    if (_isSwiping) return;
    _isSwiping = true;

    final vocab = _dueVocab[_currentIndex];
    final quality = knewIt ? 4 : 1;
    final updated = SRSService.calculateNextReview(vocab, quality);

    final vocabRepo = ref.read(vocabRepositoryProvider);
    await vocabRepo.updateVocab(updated);

    final sessionService = ref.read(deckSessionServiceProvider);
    if (vocab.id != null) {
      await sessionService.recordAnswer(vocab.id!, knewIt);
    }

    if (knewIt) { _knewCount++; } else { _didntKnowCount++; }

    setState(() {
      _dragX = 0;
      _isRevealed = false;
      if (_currentIndex < _dueVocab.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = _dueVocab.length;
      }
    });
    _isSwiping = false;
  }

  Widget _buildFlashcard(BuildContext context, AppStrings s, String contentLang) {
    final vocab = _dueVocab[_currentIndex];
    final screenWidth = MediaQuery.of(context).size.width;
    final swipeThreshold = screenWidth * 0.3;
    final theme = Theme.of(context);

    Color? overlayColor;
    IconData? overlayIcon;
    if (_dragX > 40) {
      overlayColor = Colors.green.withAlpha((((_dragX / swipeThreshold) * 80).clamp(0, 80)).toInt());
      overlayIcon = Icons.check_circle;
    } else if (_dragX < -40) {
      overlayColor = Colors.red.withAlpha((((-_dragX / swipeThreshold) * 80).clamp(0, 80)).toInt());
      overlayIcon = Icons.cancel;
    }

    return Column(
      children: [
        LinearProgressIndicator(
          value: _dueVocab.isNotEmpty ? _currentIndex / _dueVocab.length : 0,
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.arrow_back, size: 14, color: Colors.red.shade300),
                const SizedBox(width: 4),
                Text('Nicht gewusst', style: TextStyle(fontSize: 12, color: Colors.red.shade300)),
              ]),
              Row(children: [
                Text('Gewusst', style: TextStyle(fontSize: 12, color: Colors.green.shade300)),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14, color: Colors.green.shade300),
              ]),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isRevealed = !_isRevealed),
            onHorizontalDragUpdate: (details) {
              setState(() => _dragX += details.delta.dx);
            },
            onHorizontalDragEnd: (details) {
              if (_dragX > swipeThreshold) {
                _handleSwipe(true);
              } else if (_dragX < -swipeThreshold) {
                _handleSwipe(false);
              } else {
                setState(() => _dragX = 0);
              }
            },
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                transform: Matrix4.identity()
                  ..translate(_dragX, 0, 0)
                  ..rotateZ(_dragX * 0.001),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: overlayColor,
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0, right: 0,
                          child: IconButton(
                            icon: Icon(Icons.volume_up, color: theme.colorScheme.primary, size: 28),
                            onPressed: () => _tts.speak(vocab.kanji ?? vocab.kana),
                          ),
                        ),
                        if (overlayIcon != null)
                          Positioned(
                            top: 0, left: 0,
                            child: Icon(overlayIcon, size: 40, color: _dragX > 0 ? Colors.green : Colors.red),
                          ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (!_isRevealed) ...[
                                Text(vocab.kanji ?? vocab.kana, style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                if (!_isKanjiSameAsKana(vocab)) ...[
                                  const SizedBox(height: 12),
                                  Text(vocab.kana, style: TextStyle(fontSize: 22, color: Colors.grey.shade500)),
                                ],
                                const SizedBox(height: 32),
                                Text('Antippen zum Umdrehen', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
                              ] else ...[
                                Text(vocab.localizedTranslation(contentLang), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                Text(vocab.kanji ?? vocab.kana, style: TextStyle(fontSize: 22, color: Colors.grey.shade500)),
                                if (!_isKanjiSameAsKana(vocab)) ...[
                                  const SizedBox(height: 4),
                                  Text(vocab.kana, style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
                                ],
                                if (vocab.exampleSentence != null && vocab.exampleSentence!.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  Text(vocab.exampleSentence!, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                                ],
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, color: Colors.red.shade300, size: 18),
              const SizedBox(width: 4),
              Text('$_didntKnowCount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red.shade300)),
              const SizedBox(width: 24),
              Icon(Icons.check_circle, color: Colors.green.shade300, size: 18),
              const SizedBox(width: 4),
              Text('$_knewCount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade300)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMultiChoice(BuildContext context, AppStrings s, String contentLang, {required bool isMeaning}) {
    final vocab = _dueVocab[_currentIndex];
    final String question;
    final String correctAnswer;
    List<String> options;

    if (isMeaning) {
      // JP → DE choices
      question = vocab.kanji ?? vocab.kana;
      correctAnswer = vocab.localizedTranslation(contentLang);
      final others = _dueVocab
          .where((v) => v.localizedTranslation(contentLang) != correctAnswer)
          .map((v) => v.localizedTranslation(contentLang))
          .toSet()
          .toList()..shuffle();
      options = [correctAnswer, ...others.take(3)]..shuffle();
    } else {
      // DE → JP choices
      question = vocab.localizedTranslation(contentLang);
      correctAnswer = vocab.kanji ?? vocab.kana;
      final others = _dueVocab
          .where((v) => (v.kanji ?? v.kana) != correctAnswer)
          .map((v) => v.kanji ?? v.kana)
          .toSet()
          .toList()..shuffle();
      options = [correctAnswer, ...others.take(3)]..shuffle();
    }

    if (options.length < 2) {
      // Not enough options, fall back to flashcard
      return _buildFlashcard(context, s, contentLang);
    }

    return Column(
      children: [
        LinearProgressIndicator(
          value: _dueVocab.isNotEmpty ? (_currentIndex + 1) / _dueVocab.length : 0,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(question, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                if (isMeaning && vocab.kanji != null && vocab.kanji!.isNotEmpty && vocab.kanji != vocab.kana) ...[
                  const SizedBox(height: 8),
                  Text(vocab.kana, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                ],
                const SizedBox(height: 40),
                ...options.map((option) {
                  Color? bgColor;
                  if (_answerCorrect != null) {
                    if (option == correctAnswer) {
                      bgColor = Colors.green.shade100;
                    } else if (option == _selectedOption && !_answerCorrect!) {
                      bgColor = Colors.red.shade100;
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: bgColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _answerCorrect != null ? null : () {
                          final correct = option == correctAnswer;
                          setState(() {
                            _selectedOption = option;
                            _answerCorrect = correct;
                          });
                          _tts.speak(vocab.kanji ?? vocab.kana);
                          Future.delayed(const Duration(milliseconds: 1200), () {
                            if (mounted) _answer(correct ? 4 : 1);
                          });
                        },
                        child: Text(option, style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTyping(BuildContext context, AppStrings s, String contentLang) {
    final vocab = _dueVocab[_currentIndex];
    final question = vocab.localizedTranslation(contentLang);
    final correctAnswer = vocab.kanji ?? vocab.kana;

    return Column(
      children: [
        LinearProgressIndicator(
          value: _dueVocab.isNotEmpty ? (_currentIndex + 1) / _dueVocab.length : 0,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(question, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('Tippe das japanische Wort', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                TextField(
                  controller: _typingController,
                  enabled: !_typingSubmitted,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    hintText: 'Japanisch eingeben...',
                    suffixIcon: !_typingSubmitted ? IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () => _submitTyping(correctAnswer),
                    ) : null,
                  ),
                  onSubmitted: (_) => _submitTyping(correctAnswer),
                ),
                if (_typingSubmitted) ...[
                  const SizedBox(height: 16),
                  Icon(_typingCorrect ? Icons.check_circle : Icons.cancel,
                    color: _typingCorrect ? Colors.green : Colors.red, size: 48),
                  const SizedBox(height: 8),
                  if (!_typingCorrect)
                    Text('Richtig: $correctAnswer', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (vocab.kanji != null && vocab.kanji!.isNotEmpty && vocab.kanji != vocab.kana) ...[
                    const SizedBox(height: 8),
                    Text(vocab.kana, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _answer(_typingCorrect ? 4 : 1),
                    child: const Text('Weiter'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _submitTyping(String correctAnswer) {
    final input = _typingController.text.trim();
    if (input.isEmpty) return;
    final correct = input == correctAnswer;
    setState(() {
      _typingSubmitted = true;
      _typingCorrect = correct;
    });
    _tts.speak(correctAnswer);
  }
}
