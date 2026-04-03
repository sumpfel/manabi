import '../models/lesson.dart';
import '../models/vocab.dart';

/// Shared exercise generator for Vocab Gates.
/// Generates ~30 randomized exercises from a vocab list.
/// All instructions in German.
class ExerciseGenerator {

  /// Generate ~30 vocab gate exercises from a word list.
  /// Uses random sampling so exercises differ each time.
  static List<Exercise> vocabGate(List<Vocab> vocab, String contentLang) {
    final ex = <Exercise>[];
    final shuffled = List<Vocab>.from(vocab)..shuffle();

    String tr(Vocab v) {
      return contentLang == 'de' ? (v.translationDe ?? v.translation) : (v.translationEn ?? v.translation);
    }

    // Scale exercise count to vocab size, min 15总
    final vocabCount = vocab.length;
    final mcCount = (vocabCount * 2).clamp(6, 15);
    final listenCount = (vocabCount * 1).clamp(4, 8);
    final typingCount = (vocabCount * 1).clamp(3, 8);
    final speakCount = (vocabCount * 1).clamp(2, 5);

    // Helper to get random item that might repeat in small sets
    Iterable<Vocab> _getRandomSubset(int count) {
       final result = <Vocab>[];
       for (int i = 0; i < count; i++) {
         result.add((vocab.toList()..shuffle()).first);
       }
       return result;
    }

    // MC JP→Translation
    for (var v in _getRandomSubset(mcCount)) {
      final others = vocab.where((o) => o != v).toList()..shuffle();
      ex.add(MultipleChoiceExercise(
        question: v.kanji ?? v.kana,
        instruction: 'Übersetze',
        options: ([tr(v), ...others.take(3).map((o) => tr(o))]..shuffle()),
        correctOption: tr(v),
      ));
    }

    // Listening
    for (var v in _getRandomSubset(listenCount)) {
      final others = vocab.where((o) => o != v).toList()..shuffle();
      ex.add(ListeningExercise(
        question: 'Höre zu und wähle die Übersetzung.',
        instruction: 'Hörverständnis',
        audioText: v.kana,
        options: ([tr(v), ...others.take(2).map((o) => tr(o))]..shuffle()),
        correctOption: tr(v),
      ));
    }

    // Typing
    for (var v in _getRandomSubset(typingCount)) {
      ex.add(TypingExercise(
        question: tr(v),
        instruction: 'Auf Japanisch schreiben',
        answer: v.kanji ?? v.kana,
        hint: (v.kanji != null && v.kanji!.isNotEmpty && v.kanji != v.kana) ? v.kana : null,
      ));
    }

    // Speaking
    for (var v in _getRandomSubset(speakCount)) {
      ex.add(SpeakingExercise(
        question: 'Sprich dieses Wort laut aus.',
        instruction: 'Sprechen',
        targetText: v.kanji ?? v.kana,
        translation: tr(v),
      ));
    }

    // Matching (1-2 groups of 5)
    final matchGroups = vocabCount >= 10 ? 2 : 1;
    final matchShuffle = vocab.toList()..shuffle();
    for (int i = 0; i < matchGroups && i * 5 < matchShuffle.length; i++) {
      final group = matchShuffle.skip(i * 5).take(5);
      if (group.length >= 2) {
        ex.add(MatchingExercise(
          question: 'Ordne die Wörter zu.',
          instruction: 'Zuordnung',
          pairs: {for (var v in group) (v.kanji ?? v.kana): tr(v)},
        ));
      }
    }

    ex.shuffle();
    return ex;
  }

  /// Generate vocabulary list for display in lesson.
  static List<Map<String, String>> vocabDisplayList(List<Vocab> vocab, String contentLang) {
    return vocab.map((v) {
      final trans = contentLang == 'de' ? (v.translationDe ?? v.translation) : (v.translationEn ?? v.translation);
      final word = v.kanji ?? v.kana;
      final reading = (v.kanji != null && v.kanji!.isNotEmpty && v.kanji != v.kana) ? v.kana : '';
      return {'word': word, 'reading': reading, 'translation': trans};
    }).toList();
  }
}
