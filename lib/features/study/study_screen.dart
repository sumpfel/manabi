import 'package:flutter/material.dart';
import '../../core/models/deck.dart';
import '../../core/models/vocab.dart';
import '../../core/services/srs_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/database/vocab_repository.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudyScreen extends ConsumerStatefulWidget {
  final Deck deck;
  final String method; // 'flashcards', 'typing_writing', 'typing_reading'

  const StudyScreen({super.key, required this.deck, required this.method});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  final TextEditingController _textController = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  List<Vocab> _queue = [];
  int _currentIndex = 0;
  
  bool _isLoading = true;
  bool _isAnswerRevealed = false;
  String _feedback = '';
  Color _feedbackColor = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadVocab();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ja-JP");
    final ttsSpeed = ref.read(settingsProvider).ttsSpeed;
    await _flutterTts.setSpeechRate(ttsSpeed);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  Future<void> _loadVocab() async {
    final repo = ref.read(vocabRepositoryProvider);
    final allVocab = await repo.getVocabForDeck(widget.deck.id!);
    
    // Sort so due cards come first
    final now = DateTime.now().millisecondsSinceEpoch;
    final dueCards = allVocab.where((v) => (v.dueDate ?? 0) <= now).toList();
    
    // Fallback: If no due cards, study all cards
    _queue = dueCards.isNotEmpty ? dueCards : allVocab;
    _queue.shuffle(); // Randomize study order
    
    setState(() {
      _isLoading = false;
    });
  }

  Vocab? get _currentVocab => _currentIndex < _queue.length ? _queue[_currentIndex] : null;

  void _nextCard() {
    setState(() {
      _currentIndex++;
      _isAnswerRevealed = false;
      _feedback = '';
      _feedbackColor = Colors.transparent;
      _textController.clear();
    });
  }

  Future<void> _recordAnswer(int quality) async {
    if (_currentVocab == null) return;
    final repo = ref.read(vocabRepositoryProvider);
    
    final updatedVocab = SRSService.calculateNextReview(_currentVocab!, quality);
    await repo.updateVocab(updatedVocab);
    
    _nextCard();
  }

  void _checkTypingAnswer() {
    if (_currentVocab == null) return;
    final input = _textController.text.trim().toLowerCase();
    
    bool isCorrect = false;
    if (widget.method == 'typing_writing') {
      final expectedKana = _currentVocab!.kana;
      final expectedKanji = _currentVocab!.kanji ?? expectedKana;
      if (input == expectedKana || input == expectedKanji) isCorrect = true;
    } else if (widget.method == 'typing_reading') {
      final contentLang = ref.read(settingsProvider).contentLanguage;
      final expectedTranslation = _currentVocab!.localizedTranslation(contentLang).toLowerCase();
      // Simple string matching, could be improved
      if (expectedTranslation.contains(input) && input.length >= 3) isCorrect = true;
      if (input == expectedTranslation) isCorrect = true;
    }

    setState(() {
      _isAnswerRevealed = true;
      if (isCorrect) {
        _feedback = 'Correct!';
        _feedbackColor = Colors.green;
      } else {
        _feedback = widget.method == 'typing_writing' 
            ? 'Incorrect. Expected: ${(_currentVocab!.kanji ?? _currentVocab!.kana)}'
            : 'Incorrect. Expected: ${_currentVocab!.localizedTranslation(ref.read(settingsProvider).contentLanguage)}';
        _feedbackColor = Colors.redAccent;
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    if (_currentVocab == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Study: ${widget.deck.name}')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              Text('Session Complete!', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Deck'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.deck.name} (${_currentIndex + 1}/${_queue.length})'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: widget.method == 'flashcards' 
          ? _buildFlashcardUI() 
          : _buildTypingUI(),
      ),
    );
  }

  Widget _buildFlashcardUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0, horizontal: 16.0),
            child: Column(
              children: [
                Text(
                  _currentVocab!.kanji?.isNotEmpty == true ? _currentVocab!.kanji! : _currentVocab!.kana,
                  style: Theme.of(context).textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 32),
                  onPressed: () => _speak(_currentVocab!.kanji?.isNotEmpty == true ? _currentVocab!.kanji! : _currentVocab!.kana),
                ),
                if (_isAnswerRevealed) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  Text(_currentVocab!.kana, style: Theme.of(context).textTheme.headlineSmall),
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () => _speak(_currentVocab!.kana),
                  ),
                  const SizedBox(height: 8),
                  Text(_currentVocab!.localizedTranslation(ref.read(settingsProvider).contentLanguage), style: Theme.of(context).textTheme.titleLarge),
                ]
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        if (!_isAnswerRevealed)
          ElevatedButton(
            onPressed: () => setState(() => _isAnswerRevealed = true),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
            child: const Text('Reveal Answer', style: TextStyle(fontSize: 18)),
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RatingButton(label: 'Again', color: Colors.red, onPressed: () => _recordAnswer(1)),
              _RatingButton(label: 'Hard', color: Colors.orange, onPressed: () => _recordAnswer(3)),
              _RatingButton(label: 'Good', color: Colors.green, onPressed: () => _recordAnswer(4)),
              _RatingButton(label: 'Easy', color: Colors.blue, onPressed: () => _recordAnswer(5)),
            ],
          ),
      ],
    );
  }

  Widget _buildTypingUI() {
    final contentLang = ref.read(settingsProvider).contentLanguage;
    final questionText = widget.method == 'typing_writing' 
      ? _currentVocab!.localizedTranslation(contentLang) 
      : (_currentVocab!.kanji?.isNotEmpty == true ? _currentVocab!.kanji! : _currentVocab!.kana);
    
    final hintText = widget.method == 'typing_writing' 
      ? 'Type Kana/Kanji here' 
      : 'Type the meaning here';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.method == 'typing_writing' ? 'Translate to Japanese:' : 'Translate to English:',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              questionText,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (widget.method == 'typing_reading')
              IconButton(
                icon: const Icon(Icons.volume_up),
                onPressed: () => _speak(questionText),
              ),
          ],
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _textController,
          enabled: !_isAnswerRevealed,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: hintText,
          ),
          onSubmitted: (_) => _checkTypingAnswer(),
        ),
        const SizedBox(height: 16),
        if (!_isAnswerRevealed) ...[
          ElevatedButton(
            onPressed: _checkTypingAnswer,
            child: const Text('Check Answer'),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _feedbackColor.withAlpha(51),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _feedback,
              style: TextStyle(color: _feedbackColor, fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Rate 4 if correct, 1 if incorrect
              _recordAnswer(_feedbackColor == Colors.green ? 4 : 1);
            },
            child: const Text('Next'),
          ),
        ],
      ],
    );
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _RatingButton({required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
