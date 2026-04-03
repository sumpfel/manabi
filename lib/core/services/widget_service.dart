import 'dart:convert';
import 'dart:math';
import 'package:home_widget/home_widget.dart';
import '../database/vocab_repository.dart';
import '../models/vocab.dart';
import '../models/deck.dart';
import 'settings_service.dart';
import 'deck_session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WidgetService {
  static const _maxVocabListSize = 50;

  static Future<void> updateAllWidgets(
      VocabRepository vocabRepo, 
      DeckSessionService sessionService,
      String contentLang) async {
    
    // 1 & 2. Vocab & Flip Card Widgets
    final allVocab = await vocabRepo.getAllVocab();
    if (allVocab.isEmpty) return;

    // Build a shuffled list of vocab entries for next/prev navigation
    final shuffled = List<Vocab>.from(allVocab)..shuffle();
    final subset = shuffled.take(_maxVocabListSize).toList();

    final vocabListJson = jsonEncode(subset.map((v) => {
      'word': v.kanji?.isNotEmpty == true ? v.kanji! : v.kana,
      'kana': v.kana,
      'translation': v.localizedTranslation(contentLang),
      'example': v.exampleSentence ?? '',
      'example_translation': v.localizedExample(contentLang),
    }).toList());

    // Set the first item as the current displayed vocab
    final first = subset.first;
    final word = first.kanji?.isNotEmpty == true ? first.kanji! : first.kana;

    await HomeWidget.saveWidgetData<String>('vocab_word', word);
    await HomeWidget.saveWidgetData<String>('vocab_kana', first.kana);
    await HomeWidget.saveWidgetData<String>('vocab_translation', first.localizedTranslation(contentLang));
    await HomeWidget.saveWidgetData<String>('vocab_example', first.exampleSentence ?? '');
    await HomeWidget.saveWidgetData<String>('vocab_example_translation', first.localizedExample(contentLang));
    await HomeWidget.saveWidgetData<String>('vocab_list_json', vocabListJson);
    await HomeWidget.saveWidgetData<int>('vocab_current_index', 0);

    await HomeWidget.updateWidget(name: 'VocabWidgetProvider', androidName: 'VocabWidgetProvider');
    await HomeWidget.updateWidget(name: 'VocabFlipWidgetProvider', androidName: 'VocabFlipWidgetProvider');
    await HomeWidget.updateWidget(name: 'VocabFlipJaEnWidgetProvider', androidName: 'VocabFlipJaEnWidgetProvider');
    await HomeWidget.updateWidget(name: 'VocabListenWidgetProvider', androidName: 'VocabListenWidgetProvider');

    // 2.5 Kanji Widget
    final allDecks = await vocabRepo.getDecks();
    final kanjiDecks = allDecks.where((d) => d.deckType == DeckType.kanji).toList();
    final kanjiVocab = <Vocab>[];
    for (var deck in kanjiDecks) {
        final v = await vocabRepo.getVocabForDeck(deck.id!);
        kanjiVocab.addAll(v);
    }
    
    if (kanjiVocab.isNotEmpty) {
      final shuffledKanji = List<Vocab>.from(kanjiVocab)..shuffle();
      final kanjiSubset = shuffledKanji.take(_maxVocabListSize).toList();
      final kanjiListJson = jsonEncode(kanjiSubset.map((v) => {
        'kanji': v.kanji ?? '',
        'word': v.kanji?.isNotEmpty == true ? v.kanji! : v.kana,
        'kana': v.kana,
        'translation': v.localizedTranslation(contentLang),
        'manga_title': kanjiDecks.firstWhere((d) => d.id == v.deckId).name,
      }).toList());

      await HomeWidget.saveWidgetData<String>('kanji_list_json', kanjiListJson);
      await HomeWidget.saveWidgetData<int>('kanji_current_index', 0);
      await HomeWidget.updateWidget(name: 'KanjiWidgetProvider', androidName: 'KanjiWidgetProvider');
    }

    // 3 & 4. Stats & Progress Widgets
    final prefs = await SharedPreferences.getInstance();
    final streak = prefs.getInt('currentStreak') ?? 0;
    
    final overallStats = await sessionService.getOverallStats();
    final totalCorrect = overallStats['total_correct'] as int? ?? 0;
    final totalWrong = overallStats['total_wrong'] as int? ?? 0;
    final totalAttempts = totalCorrect + totalWrong;
    final accuracy = totalAttempts > 0 ? ((totalCorrect / totalAttempts) * 100).round() : 0;
    
    // Approximate "Learned" as items with an active review scheduled or some stats.
    // For simplicity without a dedicated query, let's use the count of items in Stats table:
    final rawStats = await sessionService.dbService.database.then((db) => db.query('vocab_stats'));
    final learnedCount = rawStats.length;

    await HomeWidget.saveWidgetData<int>('widget_streak', streak);
    await HomeWidget.saveWidgetData<int>('widget_learned', learnedCount);
    await HomeWidget.saveWidgetData<int>('widget_accuracy', accuracy);

    await HomeWidget.updateWidget(name: 'VocabStreakWidgetProvider', androidName: 'VocabStreakWidgetProvider');
    await HomeWidget.updateWidget(name: 'VocabProgressWidgetProvider', androidName: 'VocabProgressWidgetProvider');
  }
}
