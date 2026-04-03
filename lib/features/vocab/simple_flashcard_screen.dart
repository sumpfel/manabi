import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/models/deck.dart';
import '../../core/models/vocab.dart';
import '../../core/services/settings_service.dart';

/// Simple flashcard viewer: tap to flip, big prev/next buttons, speaker icon on card.
class SimpleFlashcardScreen extends ConsumerStatefulWidget {
  final Deck deck;
  final List<Vocab> vocabList;

  const SimpleFlashcardScreen({super.key, required this.deck, required this.vocabList});

  @override
  ConsumerState<SimpleFlashcardScreen> createState() => _SimpleFlashcardScreenState();
}

class _SimpleFlashcardScreenState extends ConsumerState<SimpleFlashcardScreen> {
  late List<Vocab> _shuffled;
  int _currentIndex = 0;
  bool _isFlipped = false;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _shuffled = List<Vocab>.from(widget.vocabList)..shuffle();
    _initTts();
  }

  void _initTts() async {
    await _tts.setLanguage("ja-JP");
    await _tts.setSpeechRate(0.4);
  }

  void _flip() {
    setState(() => _isFlipped = !_isFlipped);
  }

  void _speak(Vocab vocab) {
    _tts.speak(vocab.kanji ?? vocab.kana);
  }

  void _next() {
    if (_currentIndex < _shuffled.length - 1) {
      setState(() {
        _currentIndex++;
        _isFlipped = false;
      });
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _isFlipped = false;
      });
    }
  }

  /// Returns true if kanji and kana are effectively the same (both hiragana/katakana only)
  bool _isKanjiSameAsKana(Vocab vocab) {
    if (vocab.kanji == null || vocab.kanji!.isEmpty) return true;
    return vocab.kanji == vocab.kana;
  }

  @override
  Widget build(BuildContext context) {
    final contentLang = ref.watch(settingsProvider).contentLanguage;
    final vocab = _shuffled[_currentIndex];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.name),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text('${_currentIndex + 1}/${_shuffled.length}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentIndex + 1) / _shuffled.length,
          ),
          Expanded(
            child: GestureDetector(
              onTap: _flip,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Card(
                    key: ValueKey('$_currentIndex-$_isFlipped'),
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      child: Stack(
                        children: [
                          // Speaker icon top-right
                          Positioned(
                            top: 0, right: 0,
                            child: IconButton(
                              icon: Icon(Icons.volume_up, color: theme.colorScheme.primary, size: 28),
                              onPressed: () => _speak(vocab),
                            ),
                          ),
                          // Card content
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!_isFlipped) ...[
                                  // Front: Japanese word
                                  Text(
                                    vocab.kanji ?? vocab.kana,
                                    style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  // Only show kana reading if it's different from kanji
                                  if (!_isKanjiSameAsKana(vocab)) ...[
                                    const SizedBox(height: 12),
                                    Text(vocab.kana, style: TextStyle(fontSize: 22, color: Colors.grey.shade500)),
                                  ],
                                ] else ...[
                                  // Back: Translation
                                  Text(
                                    vocab.localizedTranslation(contentLang),
                                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  // Japanese word (smaller)
                                  Text(
                                    vocab.kanji ?? vocab.kana,
                                    style: TextStyle(fontSize: 22, color: Colors.grey.shade500),
                                  ),
                                  if (!_isKanjiSameAsKana(vocab)) ...[
                                    const SizedBox(height: 4),
                                    Text(vocab.kana, style: TextStyle(fontSize: 16, color: Colors.grey.shade400)),
                                  ],
                                  if (vocab.exampleSentence != null && vocab.exampleSentence!.isNotEmpty) ...[
                                    const SizedBox(height: 20),
                                    const Divider(),
                                    const SizedBox(height: 12),
                                    Text(vocab.exampleSentence!, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic)),
                                    if (vocab.localizedExample(contentLang).isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(vocab.localizedExample(contentLang), style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                                    ],
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
          // Two big navigation buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _currentIndex > 0 ? _prev : null,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Zurück', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _currentIndex < _shuffled.length - 1 ? _next : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Weiter', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
