import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../core/models/deck.dart';
import '../../core/models/vocab.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/srs_service.dart';
import '../../core/database/vocab_repository.dart';
import '../../core/services/deck_session_service.dart';

/// SRS flashcard mode: swipe left (didn't know) / right (knew it).
/// Tap card to flip. Speaker icon to read aloud. No back/next buttons.
class SrsFlashcardScreen extends ConsumerStatefulWidget {
  final Deck deck;
  final List<Vocab> vocabList;

  const SrsFlashcardScreen({super.key, required this.deck, required this.vocabList});

  @override
  ConsumerState<SrsFlashcardScreen> createState() => _SrsFlashcardScreenState();
}

class _SrsFlashcardScreenState extends ConsumerState<SrsFlashcardScreen> with SingleTickerProviderStateMixin {
  late List<Vocab> _cards;
  int _currentIndex = 0;
  bool _isFlipped = false;
  final FlutterTts _tts = FlutterTts();

  // Swipe animation
  double _dragX = 0;
  bool _isSwiping = false;

  // Stats
  int _knewCount = 0;
  int _didntKnowCount = 0;

  @override
  void initState() {
    super.initState();
    _cards = List<Vocab>.from(widget.vocabList)..shuffle();
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

  bool _isKanjiSameAsKana(Vocab vocab) {
    if (vocab.kanji == null || vocab.kanji!.isEmpty) return true;
    return vocab.kanji == vocab.kana;
  }

  Future<void> _handleSwipe(bool knewIt) async {
    if (_isSwiping) return;
    _isSwiping = true;

    final vocab = _cards[_currentIndex];
    final quality = knewIt ? 4 : 1; // 4 = good, 1 = wrong
    final updated = SRSService.calculateNextReview(vocab, quality);

    // Update in database
    final vocabRepo = ref.read(vocabRepositoryProvider);
    await vocabRepo.updateVocab(updated);

    // Record stats
    final sessionService = ref.read(deckSessionServiceProvider);
    if (vocab.id != null) {
      await sessionService.recordAnswer(vocab.id!, knewIt);
    }

    if (knewIt) {
      _knewCount++;
    } else {
      _didntKnowCount++;
    }

    setState(() {
      _dragX = 0;
      _isFlipped = false;
      if (_currentIndex < _cards.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = _cards.length; // triggers completion
      }
    });

    _isSwiping = false;
  }

  @override
  Widget build(BuildContext context) {
    final contentLang = ref.watch(settingsProvider).contentLanguage;
    final theme = Theme.of(context);
    final isDone = _currentIndex >= _cards.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.name),
        actions: [
          if (!isDone)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_currentIndex + 1}/${_cards.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: isDone
          ? _buildCompletionScreen(context)
          : _buildCardView(context, contentLang, theme),
    );
  }

  Widget _buildCardView(BuildContext context, String contentLang, ThemeData theme) {
    final vocab = _cards[_currentIndex];
    final screenWidth = MediaQuery.of(context).size.width;
    final swipeThreshold = screenWidth * 0.3;

    // Determine swipe indicator color
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
          value: _cards.isNotEmpty ? (_currentIndex) / _cards.length : 0,
        ),
        const SizedBox(height: 8),
        // Swipe hint
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
            onTap: _flip,
            onHorizontalDragUpdate: (details) {
              setState(() => _dragX += details.delta.dx);
            },
            onHorizontalDragEnd: (details) {
              if (_dragX > swipeThreshold) {
                _handleSwipe(true); // swipe right = knew it
              } else if (_dragX < -swipeThreshold) {
                _handleSwipe(false); // swipe left = didn't know
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
                child: Stack(
                  children: [
                    Card(
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
                            // Speaker icon top-right
                            Positioned(
                              top: 0, right: 0,
                              child: IconButton(
                                icon: Icon(Icons.volume_up, color: theme.colorScheme.primary, size: 28),
                                onPressed: () => _speak(vocab),
                              ),
                            ),
                            // Swipe direction indicator
                            if (overlayIcon != null)
                              Positioned(
                                top: 0, left: 0,
                                child: Icon(overlayIcon,
                                    size: 40,
                                    color: _dragX > 0 ? Colors.green : Colors.red),
                              ),
                            // Card content
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (!_isFlipped) ...[
                                    Text(
                                      vocab.kanji ?? vocab.kana,
                                      style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (!_isKanjiSameAsKana(vocab)) ...[
                                      const SizedBox(height: 12),
                                      Text(vocab.kana, style: TextStyle(fontSize: 22, color: Colors.grey.shade500)),
                                    ],
                                  ] else ...[
                                    Text(
                                      vocab.localizedTranslation(contentLang),
                                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
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
                                        Text(vocab.localizedExample(contentLang),
                                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
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
                  ],
                ),
              ),
            ),
          ),
        ),
        // Score display
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

  Widget _buildCompletionScreen(BuildContext context) {
    final total = _knewCount + _didntKnowCount;
    final percentage = total > 0 ? ((_knewCount / total) * 100).round() : 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            const Text('Fertig!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('$_knewCount von $total gewusst ($percentage%)',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            if (_didntKnowCount > 0)
              Text('$_didntKnowCount Vokabeln werden bald erneut abgefragt.',
                  style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Zurück'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
