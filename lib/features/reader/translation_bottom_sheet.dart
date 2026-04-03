import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/database/vocab_repository.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/models/deck.dart';
import '../../core/models/vocab.dart';

class TranslationBottomSheet extends ConsumerStatefulWidget {
  final String text;
  final String mangaTitle;
  final String? sourceUrl;
  final String? pagePosition;

  const TranslationBottomSheet({
    super.key,
    required this.text,
    this.mangaTitle = 'Unknown Manga',
    this.sourceUrl,
    this.pagePosition,
  });

  @override
  ConsumerState<TranslationBottomSheet> createState() => _TranslationBottomSheetState();
}

class _TranslationBottomSheetState extends ConsumerState<TranslationBottomSheet> {
  late FlutterTts _flutterTts;
  bool _isPlaying = false;
  bool _isTranslating = false;
  String? _translationResult;
  bool _alreadyKnown = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _translate();
    _checkIfKnown();
  }

  Future<void> _checkIfKnown() async {
    final repo = ref.read(vocabRepositoryProvider);
    final exists = await repo.vocabExistsGlobally(widget.text, widget.text);
    if (mounted) setState(() => _alreadyKnown = exists);
  }

  @override
  void didUpdateWidget(TranslationBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translationResult = null;
      _translate();
      _speak();
    }
  }

  Future<void> _translate() async {
    if (!mounted) return;
    setState(() => _isTranslating = true);

    try {
      final settings = ref.read(settingsProvider);
      final apiKey = settings.deepLKey.trim();
      final targetLang = settings.contentLanguage.toUpperCase(); // 'EN' or 'DE'
      final targetLangLower = settings.contentLanguage.toLowerCase(); // 'en' or 'de'

      if (apiKey.isNotEmpty) {
        // DeepL API Free/Pro
        final url = apiKey.endsWith(':fx') 
            ? 'https://api-free.deepl.com/v2/translate' 
            : 'https://api.deepl.com/v2/translate';
            
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'DeepL-Auth-Key $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'text': [widget.text],
            'target_lang': targetLang
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _translationResult = data['translations'][0]['text'];
        }
      } 
      
      // Fallback or if DeepL key is empty: Google Translate Free API
      if (_translationResult == null || _translationResult!.isEmpty) {
        final encodedText = Uri.encodeComponent(widget.text);
        final url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=ja&tl=$targetLangLower&dt=t&q=$encodedText';
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final translatedText = data[0][0][0];
          _translationResult = translatedText;
        } else {
          _translationResult = 'Translation failed.';
        }
      }
    } catch (e) {
      _translationResult = 'Error: $e';
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("ja-JP");
    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlaying = false);
    });
    // Auto-speak on launch
    _speak();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speak() async {
    if (_isPlaying) {
      await _flutterTts.stop();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }
    if (mounted) setState(() => _isPlaying = true);
    await _flutterTts.speak(widget.text);
  }

  Future<String> _queryAi(String prompt) async {
    return await ref.read(aiServiceProvider).queryAi(prompt: prompt);
  }

  Future<void> _addToDeck() async {
    final repo = ref.read(vocabRepositoryProvider);
    final decks = await repo.getDecks();

    if (!mounted) return;

    Deck targetDeck;
    try {
      targetDeck = decks.firstWhere((d) => d.name == widget.mangaTitle);
    } catch (_) {
      final newDeck = Deck(
         name: widget.mangaTitle, 
         description: 'Vocabulary from ${widget.mangaTitle}',
         createdAt: DateTime.now().millisecondsSinceEpoch,
         deckType: DeckType.manga, // Ensure it's sorted into the manga tab
      );
      final id = await repo.addDeck(newDeck);
      targetDeck = Deck(
         id: id,
         name: newDeck.name,
         description: newDeck.description,
         createdAt: newDeck.createdAt,
         deckType: newDeck.deckType,
      );
      decks.add(targetDeck);
    }
    
    final customDecks = decks.where((d) => d.deckType == DeckType.custom).toList();
    Deck? additionalDeck;

    // 2. Edit Details
    final kanjiController = TextEditingController(text: widget.text);
    final kanaOnlyRegex = RegExp(r'^[\u3040-\u309F\u30A0-\u30FF]+$');
    final kanaController = TextEditingController(
      text: kanaOnlyRegex.hasMatch(widget.text) ? widget.text : '',
    );
    final translationController = TextEditingController(text: _translationResult ?? '');
    final exampleController = TextEditingController();
    final exampleTranslationController = TextEditingController();
    
    bool isAiLoading = false;
    List<Map<String, dynamic>>? splitWords;
    List<bool>? checkedWords;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Zum Deck hinzufügen'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Automatisches Ziel-Deck:', style: Theme.of(context).textTheme.bodySmall),
                      Text(targetDeck.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<Deck>(
                        value: additionalDeck,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Zusätzliches Deck auswählen (Optional)'),
                        items: customDecks.map((d) => DropdownMenuItem(value: d, child: Text(d.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setDialogState(() => additionalDeck = v),
                      ),
                      const SizedBox(height: 16),
                      
                      if (splitWords != null) ...[
                        Text('AI Satz-Zertrennung:', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        ...List.generate(splitWords!.length, (index) {
                            final word = splitWords![index];
                            return Card(
                               margin: const EdgeInsets.only(bottom: 8),
                               elevation: 2,
                               child: CheckboxListTile(
                                 value: checkedWords![index],
                                 onChanged: (v) => setDialogState(() => checkedWords![index] = v ?? false),
                                 title: Column(
                                   children: [
                                      TextFormField(
                                         initialValue: word['kanji'] ?? '',
                                         decoration: const InputDecoration(labelText: 'Kanji / Original'),
                                         onChanged: (v) => word['kanji'] = v,
                                      ),
                                      TextFormField(
                                         initialValue: word['kana'] ?? '',
                                         decoration: const InputDecoration(labelText: 'Kana / Lesung'),
                                         onChanged: (v) => word['kana'] = v,
                                      ),
                                      TextFormField(
                                         initialValue: word['translation'] ?? '',
                                         decoration: const InputDecoration(labelText: 'Übersetzung'),
                                         onChanged: (v) => word['translation'] = v,
                                      ),
                                      TextFormField(
                                         initialValue: word['example'] ?? '',
                                         decoration: const InputDecoration(labelText: 'Beispiel'),
                                         onChanged: (v) => word['example'] = v,
                                         maxLines: 2,
                                         minLines: 1,
                                      ),
                                      TextFormField(
                                         initialValue: word['example_translation'] ?? '',
                                         decoration: const InputDecoration(labelText: 'Beispiel-Übersetzung'),
                                         onChanged: (v) => word['example_translation'] = v,
                                         maxLines: 2,
                                         minLines: 1,
                                      ),
                                   ]
                                 )
                               )
                            );
                        }),
                      ] else ...[
                        TextField(
                          controller: kanjiController,
                          decoration: const InputDecoration(labelText: 'Kanji (Originaltext)'),
                        ),
                        TextField(
                          controller: kanaController,
                          decoration: const InputDecoration(labelText: 'Kana / Lesung'),
                        ),
                        TextField(
                          controller: translationController,
                          decoration: const InputDecoration(labelText: 'Übersetzung / Bedeutung'),
                        ),
                        TextField(
                          controller: exampleController,
                          decoration: const InputDecoration(labelText: 'Beispielsatz (Japanisch)'),
                          maxLines: 2,
                          minLines: 1,
                        ),
                        TextField(
                          controller: exampleTranslationController,
                          decoration: const InputDecoration(labelText: 'Beispiel-Übersetzung'),
                          maxLines: 2,
                          minLines: 1,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isAiLoading ? null : () async {
                               setDialogState(() => isAiLoading = true);
                               try {
                                 final settings = ref.read(settingsProvider);
                                 final prompt = '''
For the Japanese text "${widget.text}":
Provide the kana reading, a simple JLPT example sentence using it, and the ${settings.isGerman ? "German" : "English"} translation.
Return ONLY valid JSON with keys: "kana", "example", "example_translation". Do not include markdown formatting.
''';
                                 final content = await _queryAi(prompt);
                                 final startIndex = content.indexOf('{');
                                 final endIndex = content.lastIndexOf('}');
                                 if (startIndex != -1 && endIndex != -1) {
                                    final parsed = jsonDecode(content.substring(startIndex, endIndex + 1));
                                    setDialogState(() {
                                      if (parsed['kana'] != null) kanaController.text = parsed['kana'];
                                      if (parsed['example'] != null) exampleController.text = parsed['example'];
                                      if (parsed['example_translation'] != null) exampleTranslationController.text = parsed['example_translation'];
                                    });
                                 }
                               } catch (e) {
                                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                               } finally {
                                 setDialogState(() => isAiLoading = false);
                               }
                            },
                            icon: isAiLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
                            label: const Text('AI Auto-Fill (Lokal/Direkt)'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isAiLoading ? null : () async {
                               setDialogState(() => isAiLoading = true);
                               try {
                                 final settings = ref.read(settingsProvider);
                                 final prompt = '''
Split this Japanese sentence into its individual vocabulary words (excluding basic particles unless part of a word): "${widget.text}"
For each word provide: 'kanji' (the word), 'kana' (reading), 'translation' (in ${settings.isGerman ? "German" : "English"}), 'example' (a Japanese sentence), and 'example_translation'.
Return ONLY a valid JSON Array of objects `[{"kanji": "...", "kana": "..."}]`. Do not include markdown formatting.
''';
                                 final content = await _queryAi(prompt);
                                 final startIndex = content.indexOf('[');
                                 final endIndex = content.lastIndexOf(']');
                                 if (startIndex != -1 && endIndex != -1) {
                                    final List<dynamic> parsedList = jsonDecode(content.substring(startIndex, endIndex + 1));
                                    setDialogState(() {
                                      splitWords = parsedList.map((e) => e as Map<String, dynamic>).toList();
                                      checkedWords = List.generate(splitWords!.length, (index) => true);
                                    });
                                 }
                               } catch (e) {
                                 if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                               } finally {
                                 setDialogState(() => isAiLoading = false);
                               }
                            },
                            icon: isAiLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.call_split),
                            label: const Text('AI Satz in Vokabeln zerlegen'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
                ElevatedButton(
                  onPressed: () async {
                    if (splitWords != null) {
                       // Bulk save split words
                       int savedCount = 0;
                       for (int i = 0; i < splitWords!.length; i++) {
                         if (checkedWords![i]) {
                            final w = splitWords![i];
                            final vocab = Vocab(
                              deckId: targetDeck.id!,
                              kanji: (w['kanji']?.toString().isNotEmpty ?? false) ? w['kanji'] : null,
                              kana: w['kana'] ?? '',
                              translation: w['translation'] ?? '',
                              exampleSentence: (w['example']?.toString().isNotEmpty ?? false) ? w['example'] : null,
                              exampleTranslation: (w['example_translation']?.toString().isNotEmpty ?? false) ? w['example_translation'] : null,
                              mangaTitle: widget.mangaTitle,
                              sourceUrl: widget.sourceUrl,
                              page: widget.pagePosition,
                              dueDate: DateTime.now().millisecondsSinceEpoch,
                            );
                            await repo.addVocab(vocab);
                            if (additionalDeck != null) {
                               final vocabCopy = vocab.copyWith(deckId: additionalDeck!.id!, id: null);
                               await repo.addVocab(vocabCopy);
                            }
                            savedCount++;
                         }
                       }
                       if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$savedCount Vokabeln gespeichert!')));
                       }
                    } else {
                       // Save single word
                       final translation = translationController.text.trim();
                       String kana = kanaController.text.trim();
                       if (kana.isEmpty && kanaOnlyRegex.hasMatch(widget.text)) {
                         kana = widget.text;
                       }
                       if (translation.isEmpty || kana.isEmpty) {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text('Bitte mindestens Kana/Lesung und Übersetzung angeben')),
                         );
                         return;
                       }
                       
                       final vocab = Vocab(
                         deckId: targetDeck.id!,
                         kanji: kanjiController.text.trim().isNotEmpty ? kanjiController.text.trim() : null,
                         kana: kana,
                         translation: translation,
                         exampleSentence: exampleController.text.trim().isNotEmpty ? exampleController.text.trim() : null,
                         exampleTranslation: exampleTranslationController.text.trim().isNotEmpty ? exampleTranslationController.text.trim() : null,
                         mangaTitle: widget.mangaTitle,
                         sourceUrl: widget.sourceUrl,
                         page: widget.pagePosition,
                         dueDate: DateTime.now().millisecondsSinceEpoch,
                       );
                       
                       await repo.addVocab(vocab);
                       if (additionalDeck != null) {
                          final vocabCopy = vocab.copyWith(deckId: additionalDeck!.id!, id: null);
                          await repo.addVocab(vocabCopy);
                       }
                       if (mounted) {
                         Navigator.pop(context);
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vokabel gespeichert!')));
                       }
                    }
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      width: double.infinity,
      decoration: BoxDecoration(
         color: Theme.of(context).scaffoldBackgroundColor,
         borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Originaltext', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey)),
              IconButton(
                icon: Icon(_isPlaying ? Icons.stop_circle : Icons.volume_up, color: Theme.of(context).primaryColor),
                onPressed: _speak,
                tooltip: 'Vorlesen',
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  widget.text,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    backgroundColor: _alreadyKnown ? Colors.yellow.withAlpha(80) : null,
                  ),
                ),
              ),
              if (_alreadyKnown)
                Tooltip(
                  message: 'Bereits in einem Deck vorhanden',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(50),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: const Text('Bekannt', style: TextStyle(fontSize: 12, color: Colors.amber)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Text('Übersetzungs-Engine', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          if (_isTranslating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            Text(
              _translationResult ?? 'Keine Übersetzung gefunden.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18),
            ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addToDeck,
              icon: const Icon(Icons.add),
              label: const Text('Zum Deck hinzufügen'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

