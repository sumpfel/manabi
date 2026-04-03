import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/vocab_repository.dart';
import '../../core/models/deck.dart';
import '../../core/models/vocab.dart';
import '../../core/services/settings_service.dart';

class DeckListenScreen extends ConsumerStatefulWidget {
  final Deck deck;
  final int initialIndex;
  const DeckListenScreen({super.key, required this.deck, this.initialIndex = 0});

  @override
  ConsumerState<DeckListenScreen> createState() => _DeckListenScreenState();
}

enum ListenElement {
  japaneseWord,
  translation,
  exampleSentence,
  exampleTranslation,
}

class _DeckListenScreenState extends ConsumerState<DeckListenScreen> {
  final FlutterTts _tts = FlutterTts();
  AudioSession? _audioSession;
  List<Vocab> _vocabList = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _showTranslation = false;

  // Settings
  double _gapSeconds = 2.5;
  double _volume = 1.0;
  bool _loopDeck = false;

  List<ListenElement> _elementOrder = [
    ListenElement.japaneseWord,
    ListenElement.translation,
    ListenElement.exampleSentence,
    ListenElement.exampleTranslation,
  ];

  Map<ListenElement, bool> _elementEnabled = {
    ListenElement.japaneseWord: true,
    ListenElement.translation: true,
    ListenElement.exampleSentence: false,
    ListenElement.exampleTranslation: false,
  };

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initAudioSession();
    _loadSettings();
    _loadVocab();
    HardwareKeyboard.instance.addHandler(_handleKey);
    _tts.setLanguage('ja-JP');
    _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers
        ]);
  }

  Future<void> _initAudioSession() async {
    _audioSession = await AudioSession.instance;
    await _audioSession!.configure(const AudioSessionConfiguration.music());
    _audioSession!.interruptionEventStream.listen((event) {
      if (event.begin && _isPlaying) {
        _pause();
      }
    });
    _audioSession!.becomingNoisyEventStream.listen((_) {
      if (_isPlaying) _pause();
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _gapSeconds = prefs.getDouble('listen_gap_seconds') ?? 2.5;
      _volume = prefs.getDouble('listen_volume') ?? 1.0;
      _loopDeck = prefs.getBool('listen_loop_deck') ?? false;

      final orderStr = prefs.getString('listen_element_order');
      if (orderStr != null) {
        try {
          final List<dynamic> decoded = jsonDecode(orderStr);
          _elementOrder = decoded.map((e) => ListenElement.values.firstWhere((el) => el.name == e)).toList();
        } catch (_) {}
      }

      final enabledStr = prefs.getString('listen_element_enabled');
      if (enabledStr != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(enabledStr);
          for (final key in decoded.keys) {
            final el = ListenElement.values.firstWhere((e) => e.name == key, orElse: () => ListenElement.japaneseWord);
            _elementEnabled[el] = decoded[key] == true;
          }
        } catch (_) {}
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('listen_gap_seconds', _gapSeconds);
    await prefs.setDouble('listen_volume', _volume);
    await prefs.setBool('listen_loop_deck', _loopDeck);
    await prefs.setString('listen_element_order', jsonEncode(_elementOrder.map((e) => e.name).toList()));
    final enabledMapStr = _elementEnabled.map((k, v) => MapEntry(k.name, v));
    await prefs.setString('listen_element_enabled', jsonEncode(enabledMapStr));
  }

  Future<void> _saveListenPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_activity_type', 'listen');
    await prefs.setInt('last_activity_deck_id', widget.deck.id!);
    await prefs.setInt('last_listen_index', _currentIndex);
  }

  Future<void> _loadVocab() async {
    final repo = ref.read(vocabRepositoryProvider);
    final vocab = await repo.getVocabForDeck(widget.deck.id!);
    vocab.shuffle();
    setState(() => _vocabList = vocab);
    if (vocab.isNotEmpty) _startListening();
  }

  Future<void> _startListening() async {
    final settings = ref.read(settingsProvider);
    await _tts.setSpeechRate(settings.ttsSpeed);
    await _tts.setVolume(_volume);
    await _audioSession?.setActive(true);
    setState(() => _isPlaying = true);

    while (_isPlaying) {
      for (int i = _currentIndex; i < _vocabList.length && _isPlaying; i++) {
        if (!mounted) break;
        setState(() {
          _currentIndex = i;
          _showTranslation = false;
        });
      _saveListenPosition();

      final vocab = _vocabList[i];
      final wordJa = vocab.kanji?.isNotEmpty == true ? vocab.kanji! : vocab.kana;
      final wordTr = vocab.localizedTranslation(ref.read(settingsProvider).contentLanguage);
      final trLang = settings.appLanguage == 'de' ? 'de-DE' : 'en-US';
      final gapMs = (_gapSeconds * 1000).toInt();

      // Ensure at least *some* state updates happen to show UI changes
      setState(() => _showTranslation = true);

      for (var element in _elementOrder) {
        if (!mounted || !_isPlaying) break;
        if (_elementEnabled[element] != true) continue;

        switch (element) {
          case ListenElement.japaneseWord:
            await _tts.setLanguage('ja-JP');
            await _tts.setVolume(_volume);
            await _tts.speak(wordJa);
            await _tts.awaitSpeakCompletion(true);
            break;
          case ListenElement.translation:
            if (wordTr.isNotEmpty) {
              await _tts.setLanguage(trLang);
              await _tts.setVolume(_volume);
              await _tts.speak(wordTr);
              await _tts.awaitSpeakCompletion(true);
            }
            break;
          case ListenElement.exampleSentence:
            if (vocab.exampleSentence != null && vocab.exampleSentence!.isNotEmpty) {
              await _tts.setLanguage('ja-JP');
              await _tts.setVolume(_volume);
              await _tts.speak(vocab.exampleSentence!);
              await _tts.awaitSpeakCompletion(true);
            }
            break;
          case ListenElement.exampleTranslation:
            final exTr = vocab.localizedExample(settings.contentLanguage);
            if (exTr.isNotEmpty) {
              await _tts.setLanguage(trLang);
              await _tts.setVolume(_volume);
              await _tts.speak(exTr);
              await _tts.awaitSpeakCompletion(true);
            }
            break;
        }
        
        if (!mounted || !_isPlaying) break;
        await Future.delayed(Duration(milliseconds: (gapMs * 0.4).toInt()));
      }

      if (!mounted || !_isPlaying) break;

      // Rest of the gap between cards
      await Future.delayed(Duration(milliseconds: (gapMs * 0.6).toInt()));
    }

    if (mounted && _isPlaying) {
      if (_loopDeck) {
        // Loop back to start, shuffle
        _vocabList.shuffle();
        setState(() => _currentIndex = 0);
      } else {
        setState(() => _isPlaying = false);
      }
    }
  }

    if (mounted) setState(() => _isPlaying = false);
  }

  void _pause() {
    _tts.stop();
    setState(() => _isPlaying = false);
    _saveListenPosition();
  }

  void _resume() => _startListening();

  bool _handleKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.mediaPlayPause || event.logicalKey == LogicalKeyboardKey.mediaPlay || event.logicalKey == LogicalKeyboardKey.mediaPause) {
        if (_isPlaying) {
          _pause();
        } else {
          _resume();
        }
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.mediaTrackNext) {
        _next();
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious) {
        _previous();
        return true;
      }
    }
    return false;
  }

  void _seekTo(int index) {
    _tts.stop();
    setState(() {
      _currentIndex = index;
      _isPlaying = false;
      _showTranslation = false;
    });
    _startListening();
  }

  void _next() {
    if (_currentIndex < _vocabList.length - 1) {
      _seekTo(_currentIndex + 1);
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      _seekTo(_currentIndex - 1);
    }
  }

  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vorlesen-Einstellungen',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                const Text('Reihenfolge & Auswahl (Ziehen zum Sortieren)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withAlpha(50)),
                  ),
                  child: ReorderableListView(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    onReorder: (oldIndex, newIndex) {
                      setSheetState(() {
                        if (newIndex > oldIndex) {
                          newIndex -= 1;
                        }
                        final item = _elementOrder.removeAt(oldIndex);
                        _elementOrder.insert(newIndex, item);
                      });
                      setState(() {});
                      _saveSettings();
                    },
                    children: [
                      for (int i = 0; i < _elementOrder.length; i++)
                        Container(
                          key: ValueKey(_elementOrder[i]),
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 2, offset: const Offset(0, 1))
                            ],
                          ),
                          child: SwitchListTile(
                            contentPadding: const EdgeInsets.only(left: 16, right: 8),
                            title: Text(_getElementName(_elementOrder[i]), style: const TextStyle(fontSize: 14)),
                            value: _elementEnabled[_elementOrder[i]] ?? false,
                            secondary: const Icon(Icons.drag_handle, color: Colors.grey),
                            onChanged: (v) {
                              setSheetState(() => _elementEnabled[_elementOrder[i]] = v);
                              setState(() {});
                              _saveSettings();
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Loop
                SwitchListTile(
                  title: const Text('Deck wiederholen'),
                  subtitle: const Text('Mischen & neu starten wenn fertig'),
                  value: _loopDeck,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) {
                    setSheetState(() => _loopDeck = v);
                    setState(() {});
                    _saveSettings();
                  },
                ),

                const SizedBox(height: 16),

                // Gap between vocabs
                Text('Pause zwischen Wörtern: ${_gapSeconds.toStringAsFixed(1)}s',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: _gapSeconds,
                  min: 0.5,
                  max: 5.0,
                  divisions: 9,
                  label: '${_gapSeconds.toStringAsFixed(1)}s',
                  onChanged: (v) {
                    setSheetState(() => _gapSeconds = v);
                    setState(() {});
                    _saveSettings();
                  },
                ),

                const SizedBox(height: 8),

                // Volume
                Text('Lautstärke: ${(_volume * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Slider(
                  value: _volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  label: '${(_volume * 100).toInt()}%',
                  onChanged: (v) {
                    setSheetState(() => _volume = v);
                    setState(() {});
                    _tts.setVolume(v);
                    _saveSettings();
                  },
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getElementName(ListenElement e) {
    switch (e) {
      case ListenElement.japaneseWord: return 'Japanisches Wort';
      case ListenElement.translation: return 'Übersetzung';
      case ListenElement.exampleSentence: return 'Beispielsatz (JP)';
      case ListenElement.exampleTranslation: return 'Beispiel-Übersetzung';
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _tts.stop();
    _saveListenPosition();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_vocabList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Vorlesen: ${widget.deck.name}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final vocab = _vocabList[_currentIndex];
    final word = vocab.kanji?.isNotEmpty == true ? vocab.kanji! : vocab.kana;
    final showKanaReading = vocab.kanji != null && vocab.kanji!.isNotEmpty && vocab.kanji != vocab.kana;
    final contentLang = ref.read(settingsProvider).contentLanguage;

    return Scaffold(
      appBar: AppBar(
        title: Text('Vorlesen: ${widget.deck.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Einstellungen',
            onPressed: _showSettingsPanel,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/${_vocabList.length}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Seekable progress bar (YouTube-style) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_currentIndex + 1}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Theme.of(context).primaryColor,
                      inactiveTrackColor: Colors.grey.shade300,
                      thumbColor: Theme.of(context).primaryColor,
                      overlayColor: Theme.of(context).primaryColor.withAlpha(40),
                      trackHeight: 4.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: _currentIndex.toDouble(),
                      min: 0,
                      max: (_vocabList.length - 1).toDouble().clamp(0, double.infinity),
                      divisions: _vocabList.length > 1 ? _vocabList.length - 1 : 1,
                      onChanged: (v) {
                        _seekTo(v.toInt());
                      },
                    ),
                  ),
                ),
                Text(
                  '${_vocabList.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),

          // ── Vocab display ──
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity == null) return;
                if (details.primaryVelocity! < -100) {
                  _next();
                } else if (details.primaryVelocity! > 100) {
                  _previous();
                }
              },
              child: Container(
                color: Colors.transparent, // needed for gesture detection
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(word,
                            style: const TextStyle(
                                fontSize: 56, fontWeight: FontWeight.bold)),
                        if (showKanaReading) ...[
                          const SizedBox(height: 8),
                          Text(vocab.kana,
                              style: TextStyle(
                                  fontSize: 24, color: Colors.grey.shade500)),
                        ],
                        const SizedBox(height: 32),
                        AnimatedOpacity(
                          opacity: _showTranslation ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            vocab.localizedTranslation(contentLang),
                            style: TextStyle(
                                fontSize: 22,
                                color: Theme.of(context).primaryColor),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (vocab.exampleSentence != null &&
                            vocab.exampleSentence!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          AnimatedOpacity(
                            opacity: _showTranslation ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 500),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  Text(vocab.exampleSentence!,
                                      style: const TextStyle(fontSize: 18),
                                      textAlign: TextAlign.center),
                                  if (vocab.localizedExample(contentLang).isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        vocab.localizedExample(contentLang),
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Playback controls ──
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36),
                  onPressed: _currentIndex > 0 ? _previous : null,
                ),
                FloatingActionButton(
                  heroTag: 'listen_play',
                  onPressed: _isPlaying ? _pause : _resume,
                  child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 32),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 36),
                  onPressed:
                      _currentIndex < _vocabList.length - 1 ? _next : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
