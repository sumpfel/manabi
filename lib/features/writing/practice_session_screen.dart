
import 'package:flutter/material.dart';
import 'writing_screen.dart'; // For CharacterSet
import 'package:flutter_tts/flutter_tts.dart';

enum PracticeType { draw, match, dictation, reverseMatch }

class _PracticeItem {
  final String character;
  final PracticeType type;
  _PracticeItem(this.character, this.type);
}

class PracticeSessionScreen extends StatefulWidget {
  final CharacterSet characterSet;

  const PracticeSessionScreen({super.key, required this.characterSet});

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  int _currentIndex = 0;
  late List<_PracticeItem> _exercises;
  final FlutterTts _tts = FlutterTts();

  // Accuracy tracking
  int _correctCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _setupTTS();
    _generateExercises();
  }

  /// Generate 4 exercise types per character → e.g. 5 chars = 20 exercises
  void _generateExercises() {
    _exercises = [];
    final types = PracticeType.values;
    for (var char in widget.characterSet.characters) {
      for (var type in types) {
        _exercises.add(_PracticeItem(char, type));
      }
    }
    _exercises.shuffle();
  }

  Future<void> _setupTTS() async {
    await _tts.setLanguage("ja-JP");
    await _tts.setSpeechRate(0.4);
  }

  void _onCorrect() {
    _correctCount++;
    _totalCount++;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Richtig! ✓'), duration: Duration(milliseconds: 500), backgroundColor: Colors.green),
    );
    _advance();
  }

  void _onWrong() {
    _totalCount++;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Falsch!'), duration: Duration(milliseconds: 500), backgroundColor: Colors.redAccent),
    );
  }

  void _advance() {
    setState(() {
      _currentIndex++;
    });
    if (_currentIndex >= _exercises.length) {
      _showCompletion();
    }
  }

  double get _accuracy => _totalCount > 0 ? _correctCount / _totalCount : 0.0;

  Color _accuracyColor(double acc) {
    if (acc >= 0.9) return Colors.green;
    if (acc >= 0.7) return Colors.orange;
    return Colors.redAccent;
  }

  void _showCompletion() {
    final acc = _accuracy;
    final pct = (acc * 100).round();
    final color = _accuracyColor(acc);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(children: [
          Icon(acc >= 0.7 ? Icons.check_circle : Icons.cancel, color: color, size: 32),
          const SizedBox(width: 8),
          const Text('Übung abgeschlossen!'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.characterSet.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('$pct% Genauigkeit', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
            Text('$_correctCount / $_totalCount richtig', style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
        actions: [
          if (acc < 0.7)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _currentIndex = 0;
                  _correctCount = 0;
                  _totalCount = 0;
                  _generateExercises();
                });
              },
              child: const Text('Nochmal versuchen'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Fertig', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= _exercises.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fertig')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final item = _exercises[_currentIndex];

    Widget body;
    switch (item.type) {
      case PracticeType.draw:
        body = _buildDrawExercise(item.character);
        break;
      case PracticeType.match:
        body = _buildMatchExercise(item.character);
        break;
      case PracticeType.dictation:
        body = _buildDictationExercise(item.character);
        break;
      case PracticeType.reverseMatch:
        body = _buildReverseMatchExercise(item.character);
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.characterSet.name} (${_currentIndex + 1}/${_exercises.length})'),
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: _currentIndex / _exercises.length,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(_accuracyColor(_accuracy)),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  // --- DRAW EXERCISE ---
  final List<Offset?> _drawPoints = [];

  Widget _buildDrawExercise(String character) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Zeichne dieses Zeichen nach', style: Theme.of(context).textTheme.titleLarge),
        ),
        Row(
           mainAxisAlignment: MainAxisAlignment.end,
           children: [
             IconButton(
               icon: const Icon(Icons.clear, size: 30),
               onPressed: () => setState(() => _drawPoints.clear()),
               tooltip: 'Löschen',
             ),
             const SizedBox(width: 16),
           ],
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        character,
                        style: TextStyle(
                          fontSize: 180,
                          color: Colors.grey.shade200,
                        ),
                      ),
                    ),
                    Builder(
                      builder: (innerContext) {
                        return GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              RenderBox renderBox = innerContext.findRenderObject() as RenderBox;
                              _drawPoints.add(renderBox.globalToLocal(details.globalPosition));
                            });
                          },
                          onPanEnd: (details) {
                            setState(() {
                              _drawPoints.add(null);
                            });
                          },
                          child: CustomPaint(
                            painter: StrokePainter(points: _drawPoints),
                            size: Size.infinite,
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () {
              _drawPoints.clear();
              _onCorrect();
            },
            icon: const Icon(Icons.check),
            label: const Text('Prüfen & Weiter', style: TextStyle(fontSize: 18)),
          ),
        )
      ],
    );
  }

  // --- MATCH EXERCISE: character → reading ---
  Widget _buildMatchExercise(String character) {
    final charIndex = widget.characterSet.characters.indexOf(character);
    final correctRomaji = widget.characterSet.readings[charIndex];

    final allRomaji = widget.characterSet.readings.toList();
    allRomaji.remove(correctRomaji);
    allRomaji.shuffle();
    final options = [correctRomaji, ...allRomaji.take(3)]..shuffle();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
         const Text('Welche Lesung hat dieses Zeichen?', style: TextStyle(fontSize: 24)),
         const SizedBox(height: 32),
         Text(character, style: const TextStyle(fontSize: 120, fontWeight: FontWeight.bold)),
         const SizedBox(height: 48),
         Wrap(
           spacing: 16,
           runSpacing: 16,
           alignment: WrapAlignment.center,
           children: options.map((opt) => ElevatedButton(
             style: ElevatedButton.styleFrom(
               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
               textStyle: const TextStyle(fontSize: 24)
             ),
             onPressed: () {
               if (opt == correctRomaji) {
                 _onCorrect();
               } else {
                 _onWrong();
               }
             },
             child: Text(opt),
           )).toList()
         )
      ],
    );
  }

  // --- REVERSE MATCH: reading → character ---
  Widget _buildReverseMatchExercise(String character) {
    final charIndex = widget.characterSet.characters.indexOf(character);
    final correctRomaji = widget.characterSet.readings[charIndex];

    final allChars = widget.characterSet.characters.toList();
    allChars.remove(character);
    allChars.shuffle();
    final options = [character, ...allChars.take(3)]..shuffle();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
         const Text('Welches Zeichen ist das?', style: TextStyle(fontSize: 24)),
         const SizedBox(height: 32),
         Text(correctRomaji, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blue)),
         const SizedBox(height: 48),
         Wrap(
           spacing: 16,
           runSpacing: 16,
           alignment: WrapAlignment.center,
           children: options.map((opt) => ElevatedButton(
             style: ElevatedButton.styleFrom(
               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
               textStyle: const TextStyle(fontSize: 48)
             ),
             onPressed: () {
               if (opt == character) {
                 _onCorrect();
               } else {
                 _onWrong();
               }
             },
             child: Text(opt),
           )).toList()
         )
      ],
    );
  }

  // --- DICTATION EXERCISE ---
  final _dictationController = TextEditingController();
  Widget _buildDictationExercise(String character) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Höre zu & Tippe', style: TextStyle(fontSize: 24)),
        const SizedBox(height: 32),
        IconButton(
          iconSize: 80,
          color: Theme.of(context).primaryColor,
          icon: const Icon(Icons.volume_up),
          onPressed: () => _tts.speak(character),
        ),
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 64.0),
          child: TextField(
            controller: _dictationController,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32),
            decoration: const InputDecoration(
              hintText: 'Romaji oder Kana eingeben',
            ),
            onSubmitted: (value) => _checkDictation(character),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => _checkDictation(character),
          child: const Text('Prüfen'),
        )
      ],
    );
  }

  void _checkDictation(String character) {
    final correctRomaji = widget.characterSet.readings[widget.characterSet.characters.indexOf(character)];
    final input = _dictationController.text.trim().toLowerCase();
    if (input == correctRomaji || input == character) {
      _dictationController.clear();
      _onCorrect();
    } else {
      _onWrong();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Richtig wäre: $character ($correctRomaji)')),
      );
    }
  }
}

class StrokePainter extends CustomPainter {
  final List<Offset?> points;

  StrokePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black87
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 10.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(StrokePainter oldDelegate) => true;
}
