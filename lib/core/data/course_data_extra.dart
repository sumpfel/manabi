import '../models/unit.dart';
import '../models/lesson.dart';
import '../models/vocab.dart';
import 'exercise_generator.dart';

/// Units 4-10 separated to keep file sizes manageable.
class CourseDataExtra {
  static Vocab _vocab(String kanji, String kana, String en, String de, String jpEx, String enEx, String deEx) {
    return Vocab(
      deckId: 0, kanji: kanji, kana: kana, 
      translation: en,
      translationEn: en,
      translationDe: de,
      dueDate: DateTime.now().millisecondsSinceEpoch, 
      exampleSentence: jpEx, 
      exampleTranslation: enEx,
      exampleTranslationEn: enEx,
      exampleTranslationDe: deEx,
    );
  }

  static List<Unit> get units => [_unit4(), _unit5(), _unit6(), _unit7(), _unit8(), _unit9(), _unit10()];

  // ── Unit 4: U-Verbs (Daily Actions) ──
  static Unit _unit4() {
    final vocab = [
      _vocab('行く', 'いく', 'To go', 'Gehen', '学校に行きます。', 'I go to school.', 'Ich gehe zur Schule.'),
      _vocab('帰る', 'かえる', 'To return', 'Zurückkehren', '家に帰ります。', 'I return home.', 'Ich kehre nach Hause zurück.'),
      _vocab('待つ', 'まつ', 'To wait', 'Warten', 'ここで待ちます。', 'I wait here.', 'Ich warte hier.'),
      _vocab('買う', 'かう', 'To buy', 'Kaufen', '本を買います。', 'I buy a book.', 'Ich kaufe ein Buch.'),
      _vocab('作る', 'つくる', 'To make', 'Machen / Herstellen', 'ご飯を作ります。', 'I make rice.', 'Ich koche Reis.'),
      _vocab('遊ぶ', 'あそぶ', 'To play', 'Spielen', '公園で遊びます。', 'I play in the park.', 'Ich spiele im Park.'),
      _vocab('死ぬ', 'しぬ', 'To die', 'Sterben', '花が死にます。', 'The flower dies.', 'Die Blume stirbt.'),
      _vocab('泳ぐ', 'およぐ', 'To swim', 'Schwimmen', 'プールで泳ぎます。', 'I swim in the pool.', 'Ich schwimme im Pool.'),
      _vocab('乗る', 'のる', 'To ride', 'Einsteigen / Fahren', '電車に乗ります。', 'I ride the train.', 'Ich fahre mit dem Zug.'),
      _vocab('走る', 'はしる', 'To run', 'Laufen / Rennen', '毎朝走ります。', 'I run every morning.', 'Ich laufe jeden Morgen.'),
      _vocab('話す', 'はなす', 'To speak', 'Sprechen', '英語を話します。', 'I speak English.', 'Ich spreche Englisch.'),
      _vocab('聞く', 'きく', 'To listen / Ask', 'Hören / Fragen', '音楽を聞きます。', 'I listen to music.', 'Ich höre Musik.'),
      _vocab('書く', 'かく', 'To write', 'Schreiben', '手紙を書きます。', 'I write a letter.', 'Ich schreibe einen Brief.'),
      _vocab('読む', 'よむ', 'To read', 'Lesen', '本を読みます。', 'I read a book.', 'Ich lese ein Buch.'),
      _vocab('呼ぶ', 'よぶ', 'To call', 'Rufen', '友達を呼びます。', 'I call a friend.', 'Ich rufe einen Freund.'),
      _vocab('貸す', 'かす', 'To lend', 'Leihen', '鉛筆を貸します。', 'I lend a pencil.', 'Ich leihe einen Bleistift aus.'),
      _vocab('消す', 'けす', 'To turn off / Erase', 'Ausschalten / Löschen', 'テレビを消します。', 'I turn off the TV.', 'Ich schalte den Fernseher aus.'),
      _vocab('使う', 'つかう', 'To use', 'Benutzen', '携帯を使います。', 'I use a mobile phone.', 'Ich benutze ein Handy.'),
      _vocab('手伝う', 'てつだう', 'To help', 'Helfen', '母を手伝います。', 'I help my mother.', 'Ich helfe meiner Mutter.'),
      _vocab('会う', 'あう', 'To meet', 'Treffen', '友達に会います。', 'I meet a friend.', 'Ich treffe einen Freund.'),
      _vocab('笑う', 'わらう', 'To laugh', 'Lachen', 'たくさん笑います。', 'I laugh a lot.', 'Ich lache viel.'),
      _vocab('歌う', 'うたう', 'To sing', 'Singen', '歌を歌います。', 'I sing a song.', 'Ich singe ein Lied.'),
      _vocab('洗う', 'あらう', 'To wash', 'Waschen', '手を洗います。', 'I wash my hands.', 'Ich wasche meine Hände.'),
      _vocab('急ぐ', 'いそぐ', 'To hurry', 'Sich beeilen', '会社へ急ぎます。', 'I hurry to the company.', 'Ich beeile mich zur Firma.'),
      _vocab('頑張る', 'がんばる', 'To do ones best', 'Sich anstrengen', '勉強を頑張ります。', 'I do my best in studying.', 'Ich gebe mein Bestes beim Lernen.'),
    ];

    return Unit(
      id: 'unit_4', title: 'Lektion 4: U-Verben', description: 'Meistere die Wörterbuchform und die ます-Konjugation für U-Verben.',
      unitVocab: vocab,
      lessons: [
        Lesson(id: 'u4_l1', title: 'Vokabel-Training', description: 'U-Verben meistern.', lessonType: LessonType.vocabGate, requiredAccuracy: 0.9, vocabularyList: [
          {'word': '行く (いく)', 'translation': 'Gehen'}, {'word': '帰る (かえる)', 'translation': 'Zurückkehren'},
          {'word': '待つ (まつ)', 'translation': 'Warten'}, {'word': '買う (かう)', 'translation': 'Kaufen'},
          {'word': '話す (はなす)', 'translation': 'Sprechen'},
        ], grammarExplanation: '', exercises: [
          ...vocab.take(10).map((v) => MultipleChoiceExercise(
            question: v.kanji ?? v.kana, instruction: 'Übersetze',
            options: ([v.translation, ...vocab.where((o) => o != v).take(3).map((o) => o.translation)]..shuffle()),
            correctOption: v.translation,
          )),
        ]),
        Lesson(id: 'u4_l2', title: 'Grammatik: U-Verb ます-Form', description: 'Höfliche Verbkonjugation.',
          lessonType: LessonType.grammarIntro, vocabularyList: [],
          grammarExplanation: '''
**U-Verb ます-Form**
So konjugierst du U-Verben in die höfliche Form:
- Ändere die finale **う-Zeile** Kana in ihr **い-Zeile** Äquivalent und füge dann **ます** hinzu.

| Wörterbuch | い-Äquivalent | ます-Form |
|-----------|---------------|----------|
| 行**く** | き | 行**き**ます |
| 帰**る** | り | 帰**り**ます |
| 待**つ** | ち | 待**ち**ます |
| 買**う** | い | 買**い**ます |
| 話**す** | し | 話**し**ます |
''',
          exercises: [
            MultipleChoiceExercise(question: 'Was ist die ます-Form von 行く?', instruction: 'Konjugation', options: ['行きます', '行けます', '行かます', '行ります'], correctOption: '行きます'),
            MultipleChoiceExercise(question: 'Was ist die ます-Form von 話す?', instruction: 'Konjugation', options: ['話します', '話せます', '話すます', '話なます'], correctOption: '話します'),
            MultipleChoiceExercise(question: 'Was ist die ます-Form von 待つ?', instruction: 'Konjugation', options: ['待ちます', '待たます', '待つます', '待けます'], correctOption: '待ちます'),
            MultipleChoiceExercise(question: 'Was ist die ます-Form von 買う?', instruction: 'Konjugation', options: ['買います', '買うます', '買えます', '買かます'], correctOption: '買います'),
            TypingExercise(question: 'Übersetze: "Ich höre Musik."', instruction: 'Satz', answer: '音楽を聞きます。'),
            TypingExercise(question: 'Übersetze: "Ich gehe zur Schule."', instruction: 'Satz', answer: '学校に行きます。'),
            SentenceBuildingExercise(question: 'Ich schreibe einen Brief.', instruction: 'Satzbau', correctWords: ['手紙', 'を', '書きます', '。'], wordBank: ['手紙', 'を', '書きます', '。', 'が']),
          ]),
        Lesson(id: 'u4_l3', title: 'Produktion', description: 'U-Verb Sätze bilden.',
          lessonType: LessonType.grammarProduction, vocabularyList: [], grammarExplanation: '', exercises: [
            TypingExercise(question: 'Übersetze: "Ich gehe zur Schule."', instruction: 'Satz', answer: '学校に行きます。'),
            TypingExercise(question: 'Übersetze: "Ich lese ein Buch."', instruction: 'Satz', answer: '本を読みます。'),
            TypingExercise(question: 'Übersetze: "Ich kaufe Brot."', instruction: 'Satz', answer: 'パンを買います。'),
            TypingExercise(question: 'Übersetze: "Ich warte auf den Bus."', instruction: 'Satz', answer: 'バスを待ちます。'),
            SpeakingExercise(question: 'Sag "Laufen" auf Japanisch.', instruction: 'Sprechen', targetText: '走る', translation: 'Laufen'),
            SpeakingExercise(question: 'Sag "Ich schreibe" auf Japanisch.', instruction: 'Sprechen', targetText: '書きます', translation: 'Ich schreibe'),
            ListeningTypingExercise(question: 'Schreibe was du hörst.', instruction: 'Diktat', audioText: 'てがみをかきます', correctAnswer: '手紙を書きます。'),
          ]),
        Lesson(id: 'u4_l4', title: 'Gemischte Übung', description: 'U-Verben wiederholen.',
          lessonType: LessonType.mixedReinforcement, vocabularyList: [], grammarExplanation: '', exercises: [
            MatchingExercise(question: 'Ordne die Verben zu.', instruction: 'Zuordnung', pairs: {'行く': 'Gehen', '書く': 'Schreiben', '読む': 'Lesen', '歩く': 'Gehen/Laufen'}),
            ...vocab.take(5).map((v) => MultipleChoiceExercise(
              question: v.kanji ?? v.kana, instruction: 'Übersetze',
              options: ([v.translationDe ?? v.translation, ...vocab.where((o) => o != v).take(3).map((o) => o.translationDe ?? o.translation)]..shuffle()),
              correctOption: v.translationDe ?? v.translation,
            )),
          ]),
        Lesson(id: 'u4_l5', title: 'Lektion 4 Test', description: 'Beweise dein Wissen über U-Verben.',
          lessonType: LessonType.unitTest, requiredAccuracy: 0.85, vocabularyList: [], grammarExplanation: '', exercises: [
            TypingExercise(question: 'Übersetze: "Ich helfe meiner Mutter."', instruction: 'Satz', answer: '母を手伝います。'),
            TypingExercise(question: 'Übersetze: "Ich lese ein Buch."', instruction: 'Satz', answer: '本を読みます。'),
            MultipleChoiceExercise(question: 'Was ist die ます-Form von 書く?', instruction: 'Konjugation', options: ['書きます', '書けます', '書くます', '書います'], correctOption: '書きます'),
            MultipleChoiceExercise(question: 'Was ist die ます-Form von 読む?', instruction: 'Konjugation', options: ['読みます', '読めます', '読むます', '読なます'], correctOption: '読みます'),
            SpeakingExercise(question: 'Sag "Ich gehe nach Hause" auf Japanisch.', instruction: 'Sprechen', targetText: '家に帰ります', translation: 'Ich gehe nach Hause'),
          ]),
      ],
    );
  }

  // ── Unit 5: Adjectives (い/な) ──
  static Unit _unit5() {
    final vocab = [
      _vocab('大きい', 'おおきい', 'Big', 'Groß', '大きい家です。', 'It\'s a big house.', 'Es ist ein großes Haus.'),
      _vocab('小さい', 'ちいさい', 'Small', 'Klein', '小さい猫です。', 'It\'s a small cat.', 'Es ist eine kleine Katze.'),
      _vocab('高い', 'たかい', 'Expensive / Tall', 'Teuer / Hoch', '高い山です。', 'It\'s a tall mountain.', 'Es ist ein hoher Berg.'),
      _vocab('安い', 'やすい', 'Cheap', 'Billig', '安い本です。', 'It\'s a cheap book.', 'Es ist ein billiges Buch.'),
      _vocab('新しい', 'あたらしい', 'New', 'Neu', '新しい車です。', 'It\'s a new car.', 'Es ist ein neues Auto.'),
      _vocab('古い', 'ふるい', 'Old', 'Alt', '古い家です。', 'It\'s an old house.', 'Es ist ein altes Haus.'),
      _vocab('静か', 'しずか', 'Quiet', 'Ruhig', '静かな町です。', 'It\'s a quiet town.', 'Es ist eine ruhige Stadt.'),
      _vocab('元気', 'げんき', 'Healthy / Energetic', 'Gesund / Energetisch', '元気な人です。', 'A healthy person.', 'Ein gesunder Mensch.'),
      _vocab('きれい', 'きれい', 'Beautiful / Clean', 'Schön / Sauber', 'きれいな花です。', 'Beautiful flowers.', 'Schöne Blumen.'),
      _vocab('有名', 'ゆうめい', 'Famous', 'Berühmt', '有名な先生です。', 'A famous teacher.', 'Ein berühmter Lehrer.'),
      _vocab('暑い', 'あつい', 'Hot (weather)', 'Heiß (Wetter)', '今日は暑いです。', 'It is hot today.', 'Heute ist es heiß.'),
      _vocab('寒い', 'さむい', 'Cold (weather)', 'Kalt (Wetter)', '冬は寒いです。', 'Winter is cold.', 'Der Winter ist kalt.'),
      _vocab('冷たい', 'つめたい', 'Cold (to touch)', 'Kalt (anfassen)', '冷たい水です。', 'It is cold water.', 'Es ist kaltes Wasser.'),
      _vocab('難しい', 'むずかしい', 'Difficult', 'Schwierig', 'テストは難しいです。', 'The test is difficult.', 'Der Test ist schwierig.'),
      _vocab('易しい', 'やさしい', 'Easy', 'Einfach', '易しい問題です。', 'An easy problem.', 'Ein einfaches Problem.'),
      _vocab('面白い', 'おもしろい', 'Interesting / Funny', 'Interessant / Lustig', '面白い本です。', 'An interesting book.', 'Ein interessantes Buch.'),
      _vocab('長い', 'ながい', 'Long', 'Lang', '道が長いです。', 'The road is long.', 'Der Weg ist lang.'),
      _vocab('短い', 'みじかい', 'Short', 'Kurz', '鉛筆が短いです。', 'The pencil is short.', 'Der Bleistift ist kurz.'),
      _vocab('速い', 'はやい', 'Fast', 'Schnell', '車が速いです。', 'The car is fast.', 'Das Auto ist schnell.'),
      _vocab('遅い', 'おそい', 'Slow', 'Langsam', '電車が遅いです。', 'The train is slow.', 'Der Zug ist langsam.'),
      _vocab('悪い', 'わるい', 'Bad', 'Schlecht', '天気が悪いです。', 'The weather is bad.', 'Das Wetter ist schlecht.'),
      _vocab('いい', 'いい', 'Good', 'Gut', 'いい天気です。', 'Good weather.', 'Gutes Wetter.'),
      _vocab('明るい', 'あかるい', 'Bright', 'Hell', '部屋が明るいです。', 'The room is bright.', 'Das Zimmer ist hell.'),
      _vocab('暗い', 'くらい', 'Dark', 'Dunkel', '外は暗いです。', 'It is dark outside.', 'Draußen ist es dunkel.'),
      _vocab('便利', 'べんり', 'Convenient', 'Praktisch', '携帯は便利です。', 'Mobile phones are convenient.', 'Handys sind praktisch.'),
    ];

    return Unit(
      id: 'unit_5', title: 'Lektion 5: Adjektive', description: 'Dinge mit い- und な-Adjektiven beschreiben.',
      unitVocab: vocab,
      lessons: [
        Lesson(id: 'u5_l1', title: 'Vokabel-Training', description: 'Adjektive meistern.', lessonType: LessonType.vocabGate, requiredAccuracy: 0.9, vocabularyList: [
          {'word': '大きい', 'translation': 'Groß'}, {'word': '静か', 'translation': 'Ruhig'},
          {'word': '難しい', 'translation': 'Schwierig'}, {'word': '便利', 'translation': 'Praktisch'},
        ], grammarExplanation: '', exercises: [
          ...vocab.take(10).map((v) => MultipleChoiceExercise(
            question: v.kanji ?? v.kana, instruction: 'Übersetze',
            options: ([v.translation, ...vocab.where((o) => o != v).take(3).map((o) => o.translation)]..shuffle()),
            correctOption: v.translation,
          )),
        ]),
        Lesson(id: 'u5_l2', title: 'Grammatik: い vs な', description: 'Regeln für Adjektive und Nomen.',
          lessonType: LessonType.grammarIntro, vocabularyList: [],
          grammarExplanation: '''
**い-Adjektive**: Enden auf い. Werden direkt mit Nomen verbunden.
- 大き**い**家 (großes Haus)

**な-Adjektive**: Benötigen な zwischen dem Adjektiv und dem Nomen.
- 静か**な**町 (ruhige Stadt)
''',
          exercises: [
             MultipleChoiceExercise(question: 'Welches Adjektiv nutzt 「な」?', instruction: 'Grammatik', options: ['静か', '大きい', '新しい', '古い'], correctOption: '静か'),
          ]),
        Lesson(id: 'u5_l3', title: 'Praxis', description: 'Beschreibe deine Umgebung.',
          lessonType: LessonType.grammarProduction, vocabularyList: [], grammarExplanation: '', exercises: [
            TypingExercise(question: 'Übersetze: "Eine ruhige Stadt."', instruction: 'Phrase', answer: '静かな町'),
          ]),
        Lesson(id: 'u5_l4', title: 'Gemischte Übung', description: 'Adjektive wiederholen.',
          lessonType: LessonType.mixedReinforcement, vocabularyList: [], grammarExplanation: '', exercises: [
            MatchingExercise(question: 'Zuordnen.', instruction: 'Zuordnung', pairs: {'大きい': 'Groß', '小さい': 'Klein', '暑い': 'Heiß', '寒い': 'Kalt'}),
          ]),
        Lesson(id: 'u5_l5', title: 'Lektion 5 Test', description: 'Beweise dein Können.',
          lessonType: LessonType.unitTest, requiredAccuracy: 0.85, vocabularyList: [], grammarExplanation: '', exercises: [
            TypingExercise(question: 'Übersetze: "Das Zimmer ist hell."', instruction: 'Satz', answer: '部屋は明るいです。'),
          ]),
      ],
    );
  }

  // ── Unit 6: Body & Health ──
  static Unit _unit6() {
    final vocab = [
       _vocab('頭', 'あたま', 'Head', 'Kopf', '頭が痛いです。', 'I have a headache.', 'Ich habe Kopfschmerzen.'),
       _vocab('目', 'め', 'Eye', 'Auge', '目がきれいです。', 'Eyes are beautiful.', 'Die Augen sind schön.'),
       _vocab('耳', 'みみ', 'Ear', 'Ohr', '耳が大きいです。', 'Ears are big.', 'Die Ohren sind groß.'),
       _vocab('鼻', 'はな', 'Nose', 'Nase', '高い鼻です。', 'A tall nose.', 'Eine hohe Nase.'),
       _vocab('口', 'くち', 'Mouth', 'Mund', '口を閉めます。', 'I close my mouth.', 'Ich schließe meinen Mund.'),
       _vocab('手', 'て', 'Hand', 'Hand', '手を洗います。', 'I wash my hands.', 'Ich wasche meine Hände.'),
       _vocab('足', 'あし', 'Foot / Leg', 'Fuß / Bein', '足が速いです。', 'I am fast.', 'Ich bin schnell zu Fuß.'),
       _vocab('お腹', 'おなか', 'Stomach', 'Bauch', 'お腹が空きました。', 'I am hungry.', 'Ich habe Hunger.'),
       _vocab('喉', 'のど', 'Throat', 'Hals', '喉が渇きました。', 'I am thirsty.', 'Ich habe Durst.'),
       _vocab('背中', 'せなか', 'Back', 'Rücken', '背中が痛いです。', 'My back hurts.', 'Mein Rücken tut weh.'),
       _vocab('病院', 'びょういん', 'Hospital', 'Krankenhaus', '病院に行きます。', 'I go to the hospital.', 'Ich gehe ins Krankenhaus.'),
       _vocab('薬', 'くすり', 'Medicine', 'Medikament', '薬を飲みます。', 'I take medicine.', 'Ich nehme Medizin.'),
       _vocab('風邪', 'かぜ', 'Cold (illness)', 'Erkältung', '風邪をひきました。', 'I caught a cold.', 'Ich habe mich erkältet.'),
       _vocab('熱', 'ねつ', 'Fever', 'Fieber', '熱があります。', 'I have a fever.', 'Ich habe Fieber.'),
       _vocab('休む', 'やすむ', 'To rest', 'Ausruhen', '今日は休みます。', 'I rest today.', 'Ich ruhe mich heute aus.'),
       _vocab('走る', 'はしる', 'To run', 'Laufen', '公園を走ります。', 'I run through the park.', 'Ich laufe durch den Park.'),
       _vocab('歩く', 'あるく', 'To walk', 'Gehen / Wandern', 'ゆっくり歩きます。', 'I walk slowly.', 'Ich gehe langsam.'),
       _vocab('立つ', 'たつ', 'To stand', 'Stehen', 'ここに立ちます。', 'I stand here.', 'Ich stehe hier.'),
       _vocab('座る', 'すわる', 'To sit', 'Sitzen', '椅子に座ります。', 'I sit on the chair.', 'Ich sitze auf dem Stuhl.'),
       _vocab('動く', 'うごく', 'To move', 'Sich bewegen', '体が動きません。', 'My body won\'t move.', 'Mein Körper bewegt sich nicht.'),
       _vocab('健康', 'けんこう', 'Health', 'Gesundheit', '健康は大切です。', 'Health is important.', 'Gesundheit ist wichtig.'),
       _vocab('痛い', 'いたい', 'Painful / Hurt', 'Schmerzhaft', '足が痛いです。', 'My leg hurts.', 'Mein Bein tut weh.'),
       _vocab('強い', 'つよい', 'Strong', 'Stark', '強い人です。', 'He is a strong person.', 'Er ist ein starker Mensch.'),
       _vocab('弱い', 'よわい', 'Weak', 'Schwach', '体は弱いです。', 'My body is weak.', 'Mein Körper ist schwach.'),
       _vocab('背が高い', 'せがたかい', 'Tall', 'Groß (gewachsen)', '彼は背が高いです。', 'He is tall.', 'Er ist groß.'),
    ];
    return _lessonUnit('unit_6', 'Lektion 6: Körper & Gesundheit', 'Körperteile und Gesundheitszustände.', vocab);
  }

  // ── Unit 7: Past Tense ──
  static Unit _unit7() {
     final vocab = [
       _vocab('昨日', 'きのう', 'Yesterday', 'Gestern', '昨日は休みでした。', 'Yesterday was a holiday.', 'Gestern war ein Feiertag.'),
       _vocab('先週', 'せんしゅう', 'Last week', 'Letzte Woche', '先週勉強しました。', 'I studied last week.', 'Ich habe letzte Woche gelernt.'),
       _vocab('先月', 'せんげつ', 'Last month', 'Letzter Monat', '先月日本に行きました。', 'I went to Japan last month.', 'Letzten Monat bin ich nach Japan geflogen.'),
       _vocab('去年', 'きょねん', 'Last year', 'Letztes Jahr', '去年車を買いました。', 'I bought a car last year.', 'Letztes Jahr habe ich ein Auto gekauft.'),
       _vocab('一昨日', 'おととい', 'Day before yesterday', 'Vorgestern', '一昨日は雨でした。', 'It rained the day before yesterday.', 'Vorgestern hat es geregnet.'),
       _vocab('食べた', 'たべた', 'Ate', 'Aß', '朝ご飯を食べました。', 'I ate breakfast.', 'Ich habe gefrühstückt.'),
       _vocab('見た', 'みた', 'Saw / Watched', 'Sah / Schaute', '映画を見ました。', 'I watched a movie.', 'Ich habe einen Film geschaut.'),
       _vocab('買った', 'かった', 'Bought', 'Kaufte', '本を買いました。', 'I bought a book.', 'Ich habe ein Buch gekauft.'),
       _vocab('行った', 'いった', 'Went', 'Ging', '駅に行きました。', 'I went to the station.', 'Ich bin zum Bahnhof gegangen.'),
       _vocab('帰った', 'かえった', 'Returned', 'Kehrte zurück', '家に帰りました。', 'I returned home.', 'Ich bin nach Hause zurückgekehrt.'),
       _vocab('会った', 'あった', 'Met', 'Traf', '友達に会いました。', 'I met a friend.', 'Ich habe einen Freund getroffen.'),
       _vocab('聞いた', 'きいた', 'Heard / Asked', 'Hörte / Fragte', '話を聞きました。', 'I heard the story.', 'Ich habe die Geschichte gehört.'),
       _vocab('言った', 'いった', 'Said', 'Sagte', '名前を言いました。', 'I said the name.', 'Ich habe den Namen gesagt.'),
       _vocab('書いた', 'かいた', 'Wrote', 'Schrieb', '手紙を書きました。', 'I wrote a letter.', 'Ich habe einen Brief geschrieben.'),
       _vocab('読んだ', 'よんだ', 'Read', 'Las', '本を読みました。', 'I read a book.', 'Ich habe ein Buch gelesen.'),
       _vocab('遊んだ', 'あそんだ', 'Played', 'Spielte', '公園で遊びました。', 'I played in the park.', 'Ich habe im Park gespielt.'),
       _vocab('飲んだ', 'のんだ', 'Drank', 'Trank', '水を飲みました。', 'I drank water.', 'Ich habe Wasser getrunken.'),
       _vocab('待った', 'まった', 'Waited', 'Wartete', '１時間待ちました。', 'I waited for an hour.', 'Ich habe eine Stunde gewartet.'),
       _vocab('呼んだ', 'よんだ', 'Called', 'Rief', 'タクシーを呼びました。', 'I called a taxi.', 'Ich habe ein Taxi gerufen.'),
       _vocab('死んだ', 'しんだ', 'Died', 'Starb', '魚が死にました。', 'The fish died.', 'Der Fisch ist gestorben.'),
       _vocab('楽しかった', 'たのしかった', 'Was fun', 'Machte Spaß', '旅行は楽しかったです。', 'The trip was fun.', 'Die Reise hat Spaß gemacht.'),
       _vocab('美味しかった', 'おいしかった', 'Was delicious', 'War lecker', 'パンは美味しかったです。', 'The bread was delicious.', 'Das Brot war lecker.'),
       _vocab('暑かった', 'あつかった', 'Was hot', 'War heiß', '昨日は暑かったです。', 'Yesterday was hot.', 'Gestern war es heiß.'),
       _vocab('寒かった', 'さむかった', 'Was cold', 'War kalt', '冬は寒かったです。', 'Winter was cold.', 'Der Winter war kalt.'),
       _vocab('暇だった', 'ひまだった', 'Was free', 'Hatte Zeit', '昨日は暇でした。', 'I was free yesterday.', 'Gestern hatte ich frei.'),
     ];
     return _lessonUnit('unit_7', 'Lektion 7: Vergangenheit', 'Vergangenheitsform für Verben und Adjektive lernen.', vocab);
  }

  // ── Unit 8: Hobbies & Activities ──
  static Unit _unit8() {
     final vocab = [
        _vocab('趣味', 'しゅみ', 'Hobby', 'Hobby', '趣味は何ですか。', 'What is your hobby?', 'Was ist dein Hobby?'),
        _vocab('スポーツ', 'すぽーつ', 'Sports', 'Sport', 'スポーツが好きです。', 'I like sports.', 'Ich mag Sport.'),
        _vocab('読書', 'どくしょ', 'Reading', 'Lesen', '読書が趣味です。', 'Reading is my hobby.', 'Lesen ist mein Hobby.'),
        _vocab('料理', 'りょうり', 'Cooking', 'Kochen', '料理を作ります。', 'I cook food.', 'Ich koche Essen.'),
        _vocab('旅行', 'りょこう', 'Travel', 'Reisen', '日本を旅行します。', 'I travel Japan.', 'Ich reise durch Japan.'),
        _vocab('写真', 'しゃしん', 'Photos', 'Fotos', '写真を撮ります。', 'I take photos.', 'Ich mache Fotos.'),
        _vocab('撮る', 'とる', 'To take (photo)', 'Aufnehmen', '写真を撮ります。', 'I take a photo.', 'Ich mache ein Foto.'),
        _vocab('絵', 'え', 'Picture / Drawing', 'Bild / Zeichnung', '絵を描きます。', 'I draw a picture.', 'Ich zeichne ein Bild.'),
        _vocab('描く', 'かく', 'To draw', 'Zeichnen', '絵を描きます。', 'I draw a picture.', 'Ich zeichne ein Bild.'),
        _vocab('歌', 'うた', 'Song', 'Lied', '歌が好きです。', 'I like songs.', 'Ich mag Lieder.'),
        _vocab('歌う', 'うたう', 'To sing', 'Singen', '歌を歌います。', 'I sing a song.', 'Ich singe ein Lied.'),
        _vocab('ダンス', 'だんす', 'Dance', 'Tanz', 'ダンスをします。', 'I dance.', 'Ich tanze.'),
        _vocab('ギター', 'ぎたー', 'Guitar', 'Gitarre', 'ギターを弾きます。', 'I play the guitar.', 'Ich spiele Gitarre.'),
        _vocab('弾く', 'ひく', 'To play (string)', 'Spielen (Saiten)', 'ギターを弾きます。', 'I play the guitar.', 'Ich spiegle Gitarre.'),
        _vocab('ゲーム', 'げーむ', 'Game', 'Spiel', 'ゲームが好きです。', 'I like games.', 'Ich mag Spiele.'),
        _vocab('泳ぐ', 'およぐ', 'To swim', 'Schwimmen', '海で泳ぎます。', 'I swim in the sea.', 'Ich schwimme im Meer.'),
        _vocab('走る', 'はしる', 'To run', 'Laufen', '公園を走ります。', 'I run in the park.', 'Ich laufe im Park.'),
        _vocab('登る', 'のぼる', 'To climb', 'Besteigen', '山に登ります。', 'I climb a mountain.', 'Ich besteige einen Berg.'),
        _vocab('釣り', 'つり', 'Fishing', 'Angeln', '釣りが好きです。', 'I like fishing.', 'Ich mag Angeln.'),
        _vocab('散歩', 'さんぽ', 'Walk / Stroll', 'Spaziergang', '散歩をします。', 'I take a walk.', 'Ich mache einen Spaziergang.'),
        _vocab('買い物', 'かいもの', 'Shopping', 'Einkaufen', '週末に買い物します。', 'I shop on weekends.', 'Am Wochenende gehe ich einkaufen.'),
        _vocab('ピアノ', 'ぴあの', 'Piano', 'Klavier', 'ピアノを練習します。', 'I practice piano.', 'Ich übe Klavier.'),
        _vocab('練習', 'れんしゅう', 'Practice', 'Üben', '毎日練習します。', 'I practice every day.', 'Ich übe jeden Morgen.'),
        _vocab('映画館', 'えいがかん', 'Movie theater', 'Kino', '映画館に行きます。', 'I go to the movie theater.', 'Ich gehe ins Kino.'),
        _vocab('暇', 'ひま', 'Free time', 'Freizeit', '暇な時、何をしますか。', 'What do you do in your free time?', 'Was machst du in deiner Freizeit?'),
     ];
     return _lessonUnit('unit_8', 'Lektion 8: Hobbys', 'Über Hobbys und Aktivitäten sprechen.', vocab);
  }

  // ── Unit 9: Locations & Directions ──
  static Unit _unit9() {
     final vocab = [
        _vocab('こちら', 'こちら', 'This way / Here', 'Dieser Weg / Hier', 'こちらへどうぞ。', 'This way, please.', 'Hier entlang bitte.'),
        _vocab('あちら', 'あちら', 'That way / There', 'Jener Weg / Dort', 'あちらは駅です。', 'Over there is the station.', 'Dort drüben ist der Bahnhof.'),
        _vocab('上', 'うえ', 'Up / Above', 'Oben', '机の上に本があります。', 'There is a book on the desk.', 'Auf dem Tisch liegt ein Buch.'),
        _vocab('下', 'した', 'Down / Below', 'Unten', '机の下に猫がいます。', 'There is a cat under the desk.', 'Unter dem Tisch ist eine Katze.'),
        _vocab('前', 'まえ', 'Front / Before', 'Vorne / Vor', '学校の前にいます。', 'I am in front of the school.', 'Ich stehe vor der Schule.'),
        _vocab('後', 'うしろ', 'Back / Behind', 'Hinten', '家の後ろに庭があります。', 'There is a garden behind the house.', 'Hinter dem Haus ist ein Garten.'),
        _vocab('右', 'みぎ', 'Right', 'Rechts', '右に曲がります。', 'Turn right.', 'Biegen Sie rechts ab.'),
        _vocab('左', 'ひだり', 'Left', 'Links', '左を見てください。', 'Please look left.', 'Bitte schauen Sie nach links.'),
        _vocab('中', 'なか', 'Inside', 'Innen', '箱の中に何がありますか。', 'What is inside the box?', 'Was ist in der Box?'),
        _vocab('外', 'そと', 'Outside', 'Außen', '外は寒いです。', 'It is cold outside.', 'Draußen ist es kalt.'),
        _vocab('隣', 'となり', 'Next to', 'Neben', '隣の部屋です。', 'It is the next room.', 'Es ist das Zimmer nebenan.'),
        _vocab('近く', 'ちかく', 'Near', 'In der Nähe', '駅の近くに住んでいます。', 'I live near the station.', 'Ich wohne in der Nähe des Bahnhofs.'),
        _vocab('遠い', 'とおい', 'Far', 'Weit weg', '会社は遠いです。', 'The company is far.', 'Die Firma ist weit weg.'),
        _vocab('真っすぐ', 'まっすぐ', 'Straight', 'Geradeaus', '真っすぐ行ってください。', 'Please go straight.', 'Bitte gehen Sie geradeaus.'),
        _vocab('北', 'きた', 'North', 'Norden', '北に行きます。', 'I go North.', 'Ich gehe nach Norden.'),
        _vocab('南', 'みなみ', 'South', 'Süden', '南は暑いです。', 'South is hot.', 'Der Süden ist heiß.'),
        _vocab('東', 'ひがし', 'East', 'Osten', '東京は東にあります。', 'Tokyo is in the East.', 'Tokio liegt im Osten.'),
        _vocab('西', 'にし', 'West', 'Westen', '西に太陽が沈みます。', 'The sun sets in the West.', 'Die Sonne geht im Westen unter.'),
        _vocab('地図', 'ちず', 'Map', 'Karte', '地図を見ます。', 'I look at the map.', 'Ich schaue auf die Karte.'),
        _vocab('銀行', 'ぎんこう', 'Bank', 'Bank', '銀行でお金を下ろします。', 'I withdraw money from the bank.', 'Ich hebe Geld bei der Bank ab.'),
        _vocab('郵便局', 'ゆうびんきょく', 'Post office', 'Post', '郵便局に行きます。', 'I go to the post office.', 'Ich gehe zur Post.'),
        _vocab('交番', 'こうばん', 'Police box', 'Polizeiwache', '交番で道を聞きます。', 'I ask for directions at the police box.', 'Ich frage bei der Polizeiwache nach dem Weg.'),
        _vocab('信号', 'しんごう', 'Signal', 'Ampel', '信号が赤です。', 'The signal is red.', 'Die Ampel ist rot.'),
        _vocab('橋', 'はし', 'Bridge', 'Brücke', '橋を渡ります。', 'I cross the bridge.', 'Ich überquere die Brücke.'),
        _vocab('道', 'みち', 'Road / Way', 'Weg / Straße', '道に迷いました。', 'I got lost.', 'Ich habe mich verlaufen.'),
     ];
     return _lessonUnit('unit_9', 'Lektion 9: Orte', 'Wegbeschreibungen geben und danach fragen.', vocab);
  }

  // ── Unit 10: Review & Mastery ──
  static Unit _unit10() {
     final vocab = [
        _vocab('文法', 'ぶんぽう', 'Grammar', 'Grammatik', '文法を勉強します。', 'I study grammar.', 'Ich lerne Grammatik.'),
        _vocab('語彙', 'ごい', 'Vocabulary', 'Vokabeln', '語彙を増やします。', 'I increase my vocabulary.', 'Ich erweitere meinen Wortschatz.'),
        _vocab('会話', 'かいわ', 'Conversation', 'Gespräch', '日本語で会話します。', 'I converse in Japanese.', 'Ich unterhalte mich auf Japanisch.'),
        _vocab('読む', 'よむ', 'To read', 'Lesen', 'たくさん読みます。', 'I read a lot.', 'Ich lese viel.'),
        _vocab('書く', 'かく', 'To write', 'Schreiben', '毎日書きます。', 'I write every day.', 'Ich schreibe jeden Tag.'),
        _vocab('聞く', 'きく', 'To listen', 'Hören', 'よく聞きます。', 'I listen well.', 'Ich höre gut zu.'),
        _vocab('話す', 'はなす', 'To speak', 'Sprechen', '上手に話したいです。', 'I want to speak well.', 'Ich möchte gut sprechen können.'),
        _vocab('試験', 'しけん', 'Exam', 'Prüfung', '試験があります。', 'There is an exam.', 'Es gibt eine Prüfung.'),
        _vocab('合格', 'ごうかく', 'Pass (exam)', 'Bestehen', '試験に合格しました。', 'I passed the exam.', 'Ich habe die Prüfung bestanden.'),
        _vocab('卒業', 'そつぎょう', 'Graduation', 'Abschluss', '大学を卒業しました。', 'I graduated from university.', 'Ich habe die Uni abgeschlossen.'),
        _vocab('将来', 'しょうらい', 'Future', 'Zukunft', '将来、日本に行きたいです。', 'In the future, I want to go to Japan.', 'In Zukunft möchte ich nach Japan gehen.'),
        _vocab('夢', 'ゆめ', 'Dream', 'Traum', '夢があります。', 'I have a dream.', 'Ich habe einen Traum.'),
        _vocab('目標', 'もくひょう', 'Goal', 'Ziel', '目標は大切です。', 'Goals are important.', 'Ziele sind wichtig.'),
        _vocab('成功', 'せいこう', 'Success', 'Erfolg', '成功を祈ります。', 'I pray for success.', 'Ich wünsche viel Erfolg.'),
        _vocab('幸せ', 'しあわせ', 'Happy', 'Glücklich', '幸せな人生です。', 'It is a happy life.', 'Es ist ein glückliches Leben.'),
        _vocab('悲しい', 'かなしい', 'Sad', 'Traurig', '悲しいニュースです。', 'It is sad news.', 'Es sind traurige Nachrichten.'),
        _vocab('怒る', 'おこる', 'To get angry', 'Sich ärgern', '怒らないでください。', 'Please don\'t get angry.', 'Bitte ärgern Sie sich nicht.'),
        _vocab('驚く', 'おどろく', 'To be surprised', 'Überrascht sein', '本当に驚きました。', 'I was really surprised.', 'Ich war wirklich überrascht.'),
        _vocab('考える', 'かんがえる', 'To think', 'Nachdenken', 'よく考えてください。', 'Please think well.', 'Bitte denken Sie gut nach.'),
        _vocab('わかる', 'わかる', 'To understand', 'Verstehen', '意味がわかります。', 'I understand the meaning.', 'Ich verstehe die Bedeutung.'),
        _vocab('できる', 'できる', 'Can do', 'Können', '日本語ができます。', 'I can do Japanese.', 'Ich kann Japanisch.'),
        _vocab('一生懸命', 'いっしょうけんめい', 'With all effort', 'Mit aller Anstrengung', '一生懸命頑張ります。', 'I do my best with all effort.', 'Ich gebe mir alle Mühe.'),
        _vocab('続ける', 'つづける', 'To continue', 'Weitermachen', '勉強を続けます。', 'I continue studying.', 'Ich lerne weiter.'),
        _vocab('覚える', 'おぼえる', 'To remember', 'Sich merken', '忘れないように覚えます。', 'I remember so I won\'t forget.', 'Ich merke es mir, um es nicht zu vergessen.'),
        _vocab('マスター', 'ますたー', 'Master', 'Meister', '日本語をマスターします。', 'I master Japanese.', 'Ich werde ein Meister des Japanischen.'),
     ];
     return _lessonUnit('unit_10', 'Lektion 10: Meisterschaft', 'Umfassende Wiederholung und Zukunftsziele.', vocab);
  }

  static Unit _lessonUnit(String id, String title, String description, List<Vocab> vocab, {List<Vocab> previousVocab = const []}) {
    final uid = id.replaceAll('unit_', 'u');

    String tr(Vocab v) => v.translationDe ?? v.translation;
    String trEx(Vocab v) => v.exampleTranslationDe ?? v.exampleTranslation ?? '';

    // ── Mixed Review with previous unit review ──
    final mixedEx = <Exercise>[
      MatchingExercise(question: 'Ordne die Wörter zu.', instruction: 'Wiederholung',
        pairs: {for (var v in vocab.take(5)) (v.kanji ?? v.kana): tr(v)}),
    ];
    if (previousVocab.isNotEmpty) {
      final review = (previousVocab.toList()..shuffle()).take(3);
      for (var v in review) {
        final others = previousVocab.where((o) => o != v).toList()..shuffle();
        mixedEx.add(MultipleChoiceExercise(
          question: v.kanji ?? v.kana, instruction: 'Wiederholung',
          options: ([tr(v), ...others.take(3).map((o) => tr(o))]..shuffle()),
          correctOption: tr(v),
        ));
      }
    }
    // Add more mixed exercises to reach 15
    for (var v in (vocab.toList()..shuffle()).take(8)) {
      mixedEx.add(TypingExercise(
        question: trEx(v), instruction: 'Auf Japanisch schreiben',
        answer: v.exampleSentence ?? '', hint: v.kana,
      ));
    }
    for (var v in (vocab.toList()..shuffle()).take(3)) {
      mixedEx.add(ListeningExercise(
        question: 'Höre zu und wähle.', instruction: 'Hörverständnis',
        audioText: v.kana,
        options: ([tr(v), ...vocab.where((o) => o != v).take(2).map((o) => tr(o))]..shuffle()),
        correctOption: tr(v),
      ));
    }

    return Unit(id: id, title: title, description: description, unitVocab: vocab, lessons: [
      Lesson(id: '${uid}_l1', title: 'Vokabel-Training', description: 'Meistere die Vokabeln.',
        lessonType: LessonType.vocabGate, requiredAccuracy: 0.9,
        vocabularyList: ExerciseGenerator.vocabDisplayList(vocab, 'de'),
        grammarExplanation: '',
        exercises: ExerciseGenerator.vocabGate(vocab, 'de')),
      Lesson(id: '${uid}_l2', title: 'Grammatik Einführung', description: 'Lerne die Kernstrukturen.',
        lessonType: LessonType.grammarIntro, vocabularyList: [],
        grammarExplanation: 'Detaillierte Grammatik für $title.', exercises: [
          ...vocab.take(5).map((v) => TypingExercise(question: v.exampleSentence ?? '', instruction: 'Diesen Satz schreiben', answer: v.exampleSentence ?? '')),
          ...vocab.skip(5).take(5).map((v) => MultipleChoiceExercise(
            question: v.kanji ?? v.kana, instruction: 'Übersetze',
            options: ([tr(v), ...vocab.where((o) => o != v).take(3).map((o) => tr(o))]..shuffle()),
            correctOption: tr(v),
          )),
          ...vocab.skip(10).take(5).map((v) => ListeningExercise(
            question: 'Höre zu und wähle.', instruction: 'Hörverständnis',
            audioText: v.kana,
            options: ([tr(v), ...vocab.where((o) => o != v).take(2).map((o) => tr(o))]..shuffle()),
            correctOption: tr(v),
          )),
        ]),
      Lesson(id: '${uid}_l3', title: 'Praxis', description: 'Sätze produzieren.',
        lessonType: LessonType.grammarProduction, vocabularyList: [], grammarExplanation: '', exercises: [
          ...vocab.take(15).map((v) => TypingExercise(question: trEx(v), instruction: 'Auf Japanisch schreiben', answer: v.exampleSentence ?? '')),
          ...vocab.take(5).map((v) => SpeakingExercise(
            question: 'Sprich nach.', instruction: 'Sprechen',
            targetText: v.exampleSentence ?? '', translation: trEx(v),
          )),
          ...vocab.skip(15).take(5).map((v) => ListeningExercise(
            question: 'Höre zu und wähle.', instruction: 'Hörverständnis',
            audioText: v.kana,
            options: ([tr(v), ...vocab.where((o) => o != v).take(2).map((o) => tr(o))]..shuffle()),
            correctOption: tr(v),
          )),
        ]),
      Lesson(id: '${uid}_l4', title: 'Gemischte Übung', description: 'Verstärkende Übungen.',
        lessonType: LessonType.mixedReinforcement, vocabularyList: [], grammarExplanation: '', exercises: mixedEx),
      Lesson(id: '${uid}_l5', title: 'Lektion Test', description: 'Beweise dein Können.',
        lessonType: LessonType.unitTest, requiredAccuracy: 0.85, vocabularyList: [], grammarExplanation: '', exercises: [
          ...vocab.skip(10).take(8).map((v) => TypingExercise(question: trEx(v), instruction: 'Auf Japanisch schreiben', answer: v.exampleSentence ?? '')),
          ...vocab.take(4).map((v) => SpeakingExercise(
            question: 'Sprich nach.', instruction: 'Sprechen',
            targetText: v.exampleSentence ?? '', translation: trEx(v),
          )),
          ...vocab.skip(4).take(4).map((v) => ListeningExercise(
            question: 'Höre zu und wähle.', instruction: 'Hörverständnis',
            audioText: v.kana,
            options: ([tr(v), ...vocab.where((o) => o != v).take(2).map((o) => tr(o))]..shuffle()),
            correctOption: tr(v),
          )),
          ...vocab.skip(15).take(4).map((v) => MultipleChoiceExercise(
            question: v.kanji ?? v.kana, instruction: 'Übersetze',
            options: ([tr(v), ...vocab.where((o) => o != v).take(3).map((o) => tr(o))]..shuffle()),
            correctOption: tr(v),
          )),
        ]),
    ]);
  }
}
