import '../models/unit.dart';
import '../models/lesson.dart';
import '../models/vocab.dart';
import 'course_data_extra.dart';
import 'exercise_generator.dart';

class CourseData {
  static List<Unit> get units => [_unit1(), _unit2(), ...CourseDataExtra.units];

  static Lesson? findLessonById(String id) {
    for (var unit in units) {
      for (var lesson in unit.lessons) {
        if (lesson.id == id) return lesson;
      }
    }
    return null;
  }

  static Vocab _vocab(String kanji, String kana, String en, String de, String jpEx, String enEx, String deEx) {
    return Vocab(
      deckId: 0, kanji: kanji, kana: kana, 
      translation: en, // primary/fallback
      translationEn: en,
      translationDe: de,
      dueDate: DateTime.now().millisecondsSinceEpoch, 
      exampleSentence: jpEx, 
      exampleTranslation: enEx,
      exampleTranslationEn: enEx,
      exampleTranslationDe: deEx,
    );
  }

  static Unit _unit1() {
    // Lesson 1.1: Basics & Nouns
    final l1Vocab = [
      _vocab('私', 'わたし', 'I', 'Ich', '私。', 'Me.', 'Ich.'),
      _vocab('学生', 'がくせい', 'Student', 'Student', '学生。', 'Student.', 'Student.'),
      _vocab('先生', 'せんせい', 'Teacher', 'Lehrer', '先生。', 'Teacher.', 'Lehrer.'),
      _vocab('はい', 'はい', 'Yes', 'Ja', 'はい。', 'Yes.', 'Ja.'),
    ];

    // Lesson 1.2: Grammar "X wa Y desu" (uses L1.1 vocab)
    final l2Vocab = [
      _vocab('あなた', 'あなた', 'You', 'Du', 'あなたは学生です。', 'You are a student.', 'Du bist Student.'),
      _vocab('いいえ', 'いいえ', 'No', 'Nein', 'いいえ、学生です。', 'No, student.', 'Nein, Student.'),
    ];

    // Lesson 1.3: Greetings (uses previous grammar/vocab)
    final l3Vocab = [
      _vocab('おはよう', 'おはよう', 'Good morning', 'Guten Morgen', 'おはよう、先生。', 'Good morning, teacher.', 'Guten Morgen, Lehrer.'),
      _vocab('こんにちは', 'こんにちは', 'Hello', 'Hallo', 'こんにちは、あなた。', 'Hello, you.', 'Hallo, du.'),
      _vocab('さようなら', 'さようなら', 'Goodbye', 'Auf Wiedersehen', 'さようなら、先生。', 'Goodbye, teacher.', 'Auf Wiedersehen, Lehrer.'),
      _vocab('ありがとう', 'ありがとう', 'Thank you', 'Danke', 'はい、ありがとう。', 'Yes, thank you.', 'Ja, danke.'),
    ];

    // Lesson 1.4: Demonstratives (uses previous grammar/vocab)
    final l4Vocab = [
      _vocab('これ', 'これ', 'This', 'Dies', 'これは私です。', 'This is me.', 'Das bin ich.'),
      _vocab('本', 'ほん', 'Book', 'Buch', 'これは本です。', 'This is a book.', 'Das ist ein Buch.'),
      _vocab('何', 'なに', 'What', 'Was', 'これは何ですか。', 'What is this?', 'Was ist das?'),
    ];

    final allUnit1Vocab = [...l1Vocab, ...l2Vocab, ...l3Vocab, ...l4Vocab];

    return Unit(
      id: 'unit_1', 
      title: 'Lektion 1: Selbstvorstellung & Grundlagen', 
      description: 'Lerne, dich selbst vorzustellen, einfache Objekte zu benennen und Hallo zu sagen.',
      unitVocab: allUnit1Vocab,
      lessons: [
        Lesson(
          id: 'u1_l1', 
          unitId: 'unit_1',
          title: 'Wortschatz: Wer sind wir?', 
          description: 'Lerne deine allerersten japanischen Wörter.', 
          lessonType: LessonType.vocabGate, 
          requiredAccuracy: 0.9,
          vocabularyList: ExerciseGenerator.vocabDisplayList(l1Vocab, 'de'),
          grammarExplanation: 'Willkommen zu deiner ersten Lektion! Präge dir diese 4 Wörter gut ein.',
          exercises: ExerciseGenerator.vocabGate(l1Vocab, 'de'),
        ),
        Lesson(
          id: 'u1_l2', 
          unitId: 'unit_1',
          title: 'Grammatik: X ist Y', 
          description: 'Die wichtigste japanische Satzstruktur.',
          lessonType: LessonType.grammarIntro, 
          vocabularyList: ExerciseGenerator.vocabDisplayList(l2Vocab, 'de'),
          grammarExplanation: '''
**Die Kopula (です) und das Thema-Partikel (は)**
Im Japanischen fungiert das Verb **です** (desu) wie "sein" (bin, ist, sind).
Das Thema des Satzes (Worüber wir sprechen) wird mit **は** (wa) markiert!

**Struktur:**
[Nomen A] は [Nomen B] です。
(A ist B.)

**Beispiel:**
私は学生です。
(Ich bin Student.)
''',
          // Notice: Exercises ONLY use words from l1Vocab and l2Vocab!
          exercises: [
            MultipleChoiceExercise(question: 'Was macht "は" in "私は学生です"?', instruction: 'Grammatik', options: ['Markiert das Thema', 'Beendet den Satz', 'Bedeutet "ist"', 'Macht es zu einer Frage'], correctOption: 'Markiert das Thema'),
            MultipleChoiceExercise(question: 'Welches Wort bedeutet "bin/ist/sind"?', instruction: 'Grammatik', options: ['です', 'は', '私', '先生'], correctOption: 'です'),
            FillInBlankExercise(question: 'Ich bin Student.', instruction: 'Fülle das Thema-Partikel aus', sentencePartsBefore: '私', sentencePartsAfter: '学生です。', correctAnswer: 'は', wordBank: ['は', 'の', 'を', 'が']),
            TypingExercise(question: 'Tippe: "Ich bin Student." auf Japanisch.', instruction: 'Satzstruktur', answer: '私は学生です。'),
            SentenceBuildingExercise(question: 'Übersetze: "Du bist Lehrer."', instruction: 'Bauen', correctWords: ['あなた', 'は', '先生', 'です', '。'], wordBank: ['あなた', 'は', '先生', 'です', '。', '私']),
          ]
        ),
        Lesson(
          id: 'u1_l3', 
          unitId: 'unit_1',
          title: 'Alltag: Höfliche Begrüßungen', 
          description: 'Sag Hallo und Tschüss auf Japanisch.',
          lessonType: LessonType.grammarProduction, 
          vocabularyList: ExerciseGenerator.vocabDisplayList(l3Vocab, 'de'), 
          grammarExplanation: 'Lass uns nützliche Begrüßungen üben!', 
          exercises: [
            TypingExercise(question: 'おはよう', instruction: 'Tippe: Guten Morgen', answer: 'おはよう。'),
            TypingExercise(question: 'こんにちは', instruction: 'Tippe: Hallo', answer: 'こんにちは。'),
            SentenceBuildingExercise(question: 'Übersetze: "Ja, danke."', instruction: 'Bauen', correctWords: ['はい', '、', 'ありがとう', '。'], wordBank: ['はい', '、', 'ありがとう', '。', 'いいえ']),
            SpeakingExercise(question: 'Sage "Hallo" auf Japanisch.', instruction: 'Sprechen', targetText: 'こんにちは', translation: 'Hallo'),
            ListeningTypingExercise(question: 'Tippe, was du hörst.', instruction: 'Diktat', audioText: 'さようなら', correctAnswer: 'さようなら。'),
          ]
        ),
        Lesson(
          id: 'u1_l4', 
          unitId: 'unit_1',
          title: 'Grammatik: Was ist das?', 
          description: 'So fragst du nach Dingen.',
          lessonType: LessonType.mixedReinforcement, 
          vocabularyList: ExerciseGenerator.vocabDisplayList(l4Vocab, 'de'), 
          grammarExplanation: '''
**Fragen stellen mit か (ka)**
Wenn du ein **か** an das Ende eines Satzes hängst, wird er zu einer Frage! (Wie ein ?)

**Struktur:**
[Satz] + か。

**Beispiel:**
これは本ですか。 (Ist das ein Buch?)
これは何ですか。 (Was ist das?)
''', 
          exercises: [
            MultipleChoiceExercise(question: 'Welches Zeichen macht den Satz zur Frage?', instruction: 'Grammatik', options: ['か', 'は', 'です', '何'], correctOption: 'か'),
            SentenceBuildingExercise(question: 'Übersetze: "Ist das ein Buch?"', instruction: 'Bauen', correctWords: ['これ', 'は', '本', 'です', 'か', '。'], wordBank: ['これ', 'は', '本', 'です', 'か', '。', '何']),
            FillInBlankExercise(question: 'Was ist das?', instruction: 'Das Fragewort', sentencePartsBefore: 'これは', sentencePartsAfter: 'ですか。', correctAnswer: '何', wordBank: ['何', '本', '先生', '私']),
            TypingExercise(question: 'Übersetze: "Was ist das?"', instruction: 'Tippen', answer: 'これは何ですか。'),
            MatchingExercise(question: 'Wörter zuordnen.', instruction: 'Zuordnen', pairs: {'これ': 'Dies', '何': 'Was', '本': 'Buch', '私': 'Ich'}),
          ]
        ),
        Lesson(
          id: 'u1_l5', 
          unitId: 'unit_1',
          title: 'Abschlusstest: Lektion 1', 
          description: 'Beweise, dass du dich vorstellen und Dinge benennen kannst.',
          lessonType: LessonType.unitTest, 
          requiredAccuracy: 0.85, 
          vocabularyList: [], 
          grammarExplanation: '', 
          exercises: [
            TypingExercise(question: '私は学生です。', instruction: 'Tippe: Ich bin Student.', answer: '私は学生です。'),
            TypingExercise(question: 'これは何ですか。', instruction: 'Tippe: Was ist das?', answer: 'これは何ですか。'),
            SpeakingExercise(question: 'Laut vorlesen.', instruction: 'Sprechen', targetText: 'あなたは先生ですか。', translation: 'Bist du Lehrer?'),
            ListeningTypingExercise(question: 'Tippe, was du hörst.', instruction: 'Diktat', audioText: 'こんにちは', correctAnswer: 'こんにちは。'),
          ]
        ),
      ],
    );
  }

  static Unit _unit2() {
    // Lesson 2.1: Food and Verbs Intro
    final l1Vocab = [
      _vocab('食べる', 'たべる', 'Eat', 'Essen', '食べます。', 'Eat.', 'Ich esse.'),
      _vocab('飲む', 'のむ', 'Drink', 'Trinken', '飲みます。', 'Drink.', 'Ich trinke.'),
      _vocab('水', 'みず', 'Water', 'Wasser', '水ですか。', 'Water?', 'Ist es Wasser?'),
      _vocab('パン', 'ぱん', 'Bread', 'Brot', 'パンです。', 'Bread.', 'Es ist Brot.'),
    ];

    // Lesson 2.2: Object Particle (Wo)
    final l2Vocab = [
      _vocab('肉', 'にく', 'Meat', 'Fleisch', '肉を食べます。', 'I eat meat.', 'Ich esse Fleisch.'),
      _vocab('お茶', 'おちゃ', 'Tea', 'Tee', 'お茶を飲みます。', 'I drink tea.', 'Ich trinke Tee.'),
    ];

    // Lesson 2.3: Places & Move Particle (Ni/E)
    final l3Vocab = [
      _vocab('行く', 'いく', 'Go', 'Gehen', '行きます。', 'I go.', 'Ich gehe.'),
      _vocab('学校', 'がっこう', 'School', 'Schule', '学校に行きます。', 'I go to school.', 'Ich gehe zur Schule.'),
      _vocab('日本', 'にほん', 'Japan', 'Japan', '日本に行きます。', 'I go to Japan.', 'Ich gehe nach Japan.'),
    ];

    final allUnit2Vocab = [...l1Vocab, ...l2Vocab, ...l3Vocab];

    return Unit(
      id: 'unit_2', 
      title: 'Lektion 2: Essen, Trinken & Orte', 
      description: 'Lerne deine ersten Verben und wie man Handlungen mit Objekten verknüpft.',
      unitVocab: allUnit2Vocab,
      lessons: [
        Lesson(
          id: 'u2_l1', 
          unitId: 'unit_2',
          title: 'Wortschatz: Hunger & Durst', 
          description: 'Nahrungsmittel und grundlegende Aktionen.',
          lessonType: LessonType.vocabGate, 
          requiredAccuracy: 0.9,
          vocabularyList: ExerciseGenerator.vocabDisplayList(l1Vocab, 'de'),
          grammarExplanation: '',
          exercises: ExerciseGenerator.vocabGate(l1Vocab, 'de'),
        ),
        Lesson(
          id: 'u2_l2', 
          unitId: 'unit_2',
          title: 'Grammatik: Das Objekt (を)', 
          description: 'Aktionen auf Objekte anwenden.',
          lessonType: LessonType.grammarIntro, 
          vocabularyList: ExerciseGenerator.vocabDisplayList(l2Vocab, 'de'),
          grammarExplanation: '''
**Das Objektpartikel を (wo)**
Wenn du eine Handlung auf ein Objekt ausübst (z.B. ein Buch lesen, Fleisch essen), markierst du das Objekt mit **を**.

Verben im Japanischen stehen **immer** am Ende des Satzes!
Die höfliche Form von Verben endet auf **ます** (masu).

**Struktur:**
[Objekt] を [Verb]ます。

**Beispiel:**
パンを食べます。 (Ich esse Brot.)
水を飲みます。 (Ich trinke Wasser.)
''',
          exercises: [
            MultipleChoiceExercise(question: 'Was macht "を" im Satz?', instruction: 'Grammatik', options: ['Markiert das Objekt', 'Markiert das Thema', 'Bedeutet "ist"', 'Ist eine Frage'], correctOption: 'Markiert das Objekt'),
            FillInBlankExercise(question: 'Ich trinke Wasser.', instruction: 'Partikel einsetzen', sentencePartsBefore: '水', sentencePartsAfter: '飲みます。', correctAnswer: 'を', wordBank: ['を', 'は', 'か', 'です']),
            SentenceBuildingExercise(question: 'Ich esse Brot.', instruction: 'Satzbau', correctWords: ['パン', 'を', '食べます', '。'], wordBank: ['パン', 'を', '食べます', '。', '飲みます']),
            TypingExercise(question: 'Übersetze: "Ich trinke Tee."', instruction: 'Satzstruktur', answer: 'お茶を飲みます。'),
            MatchingExercise(question: 'Handlungen zuordnen', instruction: 'Quiz', pairs: {'食べる': 'Essen', '飲む': 'Trinken', '肉': 'Fleisch', 'お茶': 'Tee'}),
          ]
        ),
        Lesson(
          id: 'u2_l3', 
          unitId: 'unit_2',
          title: 'Grammatik: Richtungen (に)', 
          description: 'Sagen, wohin du gehst.',
          lessonType: LessonType.grammarIntro, 
          vocabularyList: ExerciseGenerator.vocabDisplayList(l3Vocab, 'de'), 
          grammarExplanation: '''
**Das Richtungspartikel に (ni)**
Um ein Ziel oder eine Richtung für Bewegungsverben (wie Gehen - 行きます) anzugeben, verwenden wir **に**.

**Beispiel:**
学校に行きます。 (Ich gehe zur Schule.)
日本に行きますか。 (Gehst du nach Japan?)
''', 
          exercises: [
            TypingExercise(question: 'Übersetze: "Ich gehe zur Schule."', instruction: 'Satz', answer: '学校に行きます。'),
            SentenceBuildingExercise(question: 'Übersetze: "Gehst du nach Japan?"', instruction: 'Bauen', correctWords: ['日本', 'に', '行きます', 'か', '。'], wordBank: ['日本', 'に', '行きます', 'か', '。', 'を']),
            FillInBlankExercise(question: 'Ich gehe nach Japan.', instruction: 'Richtungs-Partikel', sentencePartsBefore: '日本', sentencePartsAfter: '行きます。', correctAnswer: 'に', wordBank: ['に', 'を', 'は', 'か']),
            SpeakingExercise(question: 'Sage "Ich gehe nach Japan" auf Japanisch.', instruction: 'Sprechen', targetText: '日本に行きます', translation: 'Ich gehe nach Japan.'),
            ListeningTypingExercise(question: 'Tippe, was du hörst.', instruction: 'Diktat', audioText: 'がっこうにいきます。', correctAnswer: '学校に行きます。'),
          ]
        ),
        Lesson(
          id: 'u2_l4', 
          unitId: 'unit_2',
          title: 'Abschlusstest: Lektion 2', 
          description: 'Teste dein Wissen über Objekte und Richtungen!',
          lessonType: LessonType.unitTest, 
          requiredAccuracy: 0.85, 
          vocabularyList: [], 
          grammarExplanation: '', 
          exercises: [
            TypingExercise(question: '肉を食べます。', instruction: 'Tippe: Ich esse Fleisch.', answer: '肉を食べます。'),
            TypingExercise(question: '学校に行きます。', instruction: 'Tippe: Ich gehe zur Schule.', answer: '学校に行きます。'),
            SpeakingExercise(question: 'Laut vorlesen.', instruction: 'Sprechen', targetText: 'お茶を飲みますか。', translation: 'Trinken Sie Tee?'),
            ListeningTypingExercise(question: 'Tippe, was du hörst.', instruction: 'Diktat', audioText: 'ぱんをたべます', correctAnswer: 'パンを食べます。'),
            SentenceBuildingExercise(question: 'Übersetze: "Ich trinke Wasser."', instruction: 'Bauen', correctWords: ['水', 'を', '飲みます', '。'], wordBank: ['水', 'を', '飲みます', '。', 'に']),
          ]
        ),
      ],
    );
  }
}
