/// Centralized UI strings for DE / EN / JA.
/// Usage: `S.of(context).appTitle` or `S.get('de').appTitle`
class AppStrings {
  final String lang;
  AppStrings(this.lang);
  bool get isGerman => lang == 'de';

  static AppStrings of(String lang) => AppStrings(lang);

  // Helper
  String _t(String de, String en, String ja) {
    if (lang == 'ja') return ja;
    if (lang == 'en') return en;
    return de;
  }

  // ── App-wide ──
  String get appTitle => _t('Japanisch Manga Lernen', 'Japanese Manga Learn', '日本語マンガ学習');
  String get errors => _t('Fehlerquote', 'Errors', 'エラー率');
  String get tryAgain => _t('Nochmal versuchen', 'Try Again', 'もう一度試す');
  String get all => _t('Alle', 'All', 'すべて');
  String get ai => _t('KI', 'AI', 'AI');

  // ── Bottom nav ──
  String get navManga => _t('Manga', 'Manga', 'マンガ');
  String get navDecks => _t('Decks', 'Decks', 'デッキ');
  String get navPath => _t('Lernpfad', 'Path', '学習パス');
  String get navWriting => _t('Schreiben', 'Kana/Kanji', '書く練習');
  String get navSettings => _t('Einstellungen', 'Settings', '設定');

  // ── Home / Manga ──
  String get searchManga => _t('Manga suchen...', 'Search manga...', 'マンガ検索...');
  String get explore => _t('Entdecken', 'Explore', '探す');
  String get myLibrary => _t('Meine Bibliothek', 'My Library', 'マイライブラリ');
  String get customUrl => _t('Eigene URL', 'Custom URL', 'カスタムURL');
  String get loadMore => _t('Mehr laden', 'Load More', 'もっと読み込む');
  String get noMangaFound => _t('Keine Manga gefunden', 'No Manga Found', 'マンガが見つかりません');
  String get libraryEmpty => _t('Deine Bibliothek ist leer. Schau dich um!', 'Your library is empty. Go explore!', 'ライブラリが空です。探検しよう！');
  String get openAnyManga => _t('Beliebige Manga-Webseite öffnen', 'Open any manga website', '好きなマンガサイトを開く');
  String get enterUrlHint => _t('Gib eine URL ein um Manga von einer beliebigen Seite zu lesen.\nTippe auf japanischen Text um Vokabeln hinzuzufügen.', 'Enter a URL to browse manga from any site.\nTap on Japanese text to add words to your vocabulary.', 'URLを入力してマンガを閲覧。\n日本語テキストをタップして単語を追加。');
  String get mangaUrl => _t('Manga URL', 'Manga URL', 'マンガURL');
  String get openInBrowser => _t('Im Browser öffnen', 'Open in Browser', 'ブラウザで開く');
  String get quickLinks => _t('Schnellzugriff', 'Quick Links', 'クイックリンク');

  // ── Vocab / Decks ──
  String get vocabDecks => _t('Vokabel-Decks', 'Vocabulary Decks', '単語デッキ');
  String get custom => _t('Eigene', 'Custom', 'カスタム');
  String get manga => _t('Manga', 'Manga', 'マンガ');
  String get units => _t('Lektionen', 'Units', 'ユニット');
  String get addNewDeck => _t('Neues Deck erstellen', 'Add New Deck', '新しいデッキを追加');
  String get deckName => _t('Deckname', 'Deck Name', 'デッキ名');
  String get descriptionOptional => _t('Beschreibung (Optional)', 'Description (Optional)', '説明（任意）');
  String get cancel => _t('Abbrechen', 'Cancel', 'キャンセル');
  String get create => _t('Erstellen', 'Create', '作成');
  String get delete => _t('Löschen', 'Delete', '削除');
  String get save => _t('Speichern', 'Save', '保存');
  String get cloneToCustom => _t('In eigenes Deck klonen', 'Clone to Custom Deck', 'カスタムデッキにクローン');
  String get deleteDeck => _t('Deck löschen', 'Delete Deck', 'デッキを削除');
  String get deckDeleted => _t('Deck gelöscht.', 'Deck deleted.', 'デッキが削除されました。');
  String get noDecksCustom => _t('Erstelle ein eigenes Deck!', 'Create a custom deck to get started.', 'カスタムデッキを作成しましょう！');
  String get noMangaDecks => _t('Noch keine Manga-Decks.\nFüge beim Lesen Wörter hinzu!', 'No manga decks yet.\nAdd words while reading manga!', 'マンガデッキはまだありません。\n読みながら単語を追加しましょう！');
  String get unitDecksAuto => _t('Lektions-Decks werden automatisch erstellt.', 'Unit decks auto-create\nwhen you unlock units.', 'ユニットデッキはユニット解除時に自動作成されます。');

  // Study methods
  String get flashcards => _t('Karteikarten', 'Flashcards', 'フラッシュカード');
  String get flashcardsDesc => _t('Klassische SRS-Wiederholung', 'Classic SRS repetition', 'SRS反復学習');
  String get typingToJp => _t('Tippen (Übersetzung → Japanisch)', 'Typing (Translation → Japanese)', 'タイピング（翻訳→日本語）');
  String get typingToJpDesc => _t('Lesung oder Kanji eintippen', 'Type the reading or kanji', '読みまたは漢字を入力');
  String get readingToTr => _t('Lesen (Japanisch → Übersetzung)', 'Reading (Japanese → Translation)', 'リーディング（日本語→翻訳）');
  String get readingToTrDesc => _t('Bedeutung eintippen', 'Type the meaning', '意味を入力');
  String get listenMode => _t('Zuhör-Modus', 'Listen Mode', 'リスニングモード');
  String get listenModeDesc => _t('Audio liest Deck in zufälliger Reihenfolge vor', 'Audio reads deck in random order', '音声がデッキをランダムに読み上げ');
  String get editViewCards => _t('Karten bearbeiten / ansehen', 'Edit / View Cards', 'カードを編集/表示');
  String get manageVocab => _t('Vokabeln in diesem Deck verwalten', 'Manage vocabulary in this deck', 'このデッキの単語を管理');

  // Vocab detail
  String get editVocab => _t('Vokabel bearbeiten', 'Edit Vocabulary', '単語を編集');
  String get kanaReading => _t('Kana (Lesung) *', 'Kana (Reading) *', 'かな（読み）*');
  String get kanjiOptional => _t('Kanji (Optional)', 'Kanji (Optional)', '漢字（任意）');
  String get translationReq => _t('Übersetzung *', 'Translation *', '翻訳 *');
  String get vocabDeleted => _t('Vokabel gelöscht', 'Vocabulary deleted', '単語が削除されました');
  String get studyDeck => _t('Dieses Deck lernen', 'Study This Deck', 'このデッキを勉強する');

  // ── Writing ──
  String get writingPractice => _t('Schreibübung', 'Writing Practice', '書く練習');
  String get hiragana => _t('Hiragana', 'Hiragana', 'ひらがな');
  String get katakana => _t('Katakana', 'Katakana', 'カタカナ');
  String get kanji => _t('Kanji', 'Kanji', '漢字');
  String get unitKanji => _t('Lektions-Kanji', 'Unit Kanji', 'ユニット漢字');
  String get customKanji => _t('Eigene', 'Custom', 'カスタム');
  String get unlockKanji => _t('Schließe diese Lektion ab, um die Kanji freizuschalten!', 'Complete this unit to unlock its kanji!', 'このユニットを完了して漢字をアンロック！');
  String get clear => _t('Löschen', 'Clear', 'クリア');
  String get next => _t('Weiter', 'Next', '次へ');

  // ── Settings ──
  String get settings => _t('Einstellungen', 'Settings', '設定');
  String get languageSetting => _t('UI-Sprache', 'UI Language', 'UI言語');
  String get contentLanguageSetting => _t('Lern-Sprache (Übersetzung)', 'Learning Language (Translation)', '学習言語（翻訳）');
  String get showRomaji => _t('Romaji anzeigen', 'Show Romaji', 'ローマ字を表示');
  String get showRomajiDesc => _t('Romaji neben Kana in der ganzen App anzeigen', 'Display Romaji alongside Kana across the app', 'アプリ全体でかなの横にローマ字を表示');
  String get showVocabImages => _t('Vokabel-Bilder anzeigen', 'Show Vocabulary Images', '単語画像を表示');
  String get showVocabImagesDesc => _t('KI-generierte Bilder auf Vokabelkarten anzeigen', 'Display AI-generated images on vocabulary cards', 'AI生成画像を単語カードに表示');
  String get ttsSpeed => _t('Sprechgeschwindigkeit', 'TTS Speed', '読み上げ速度');
  String get themeColor => _t('Designfarbe', 'Theme Color', 'テーマカラー');
  String get deepLKey => _t('DeepL API-Schlüssel', 'DeepL API Key', 'DeepL APIキー');
  String get backendServer => _t('Backend-Server', 'Backend Server', 'バックエンドサーバー');
  String get backendHint => _t('IP oder URL eingeben', 'Enter IP or URL', 'IPまたはURLを入力');
  String get offline => _t('Offline', 'Offline', 'オフライン');
  String get clearDownloads => _t('Downloads löschen', 'Clear Downloads', 'ダウンロードを削除');
  String get clearDownloadsDesc => _t('Alle heruntergeladenen Manga-Seiten löschen', 'Delete all downloaded manga pages', 'ダウンロード済みのマンガページを全削除');
  String get aiLanguageLevel => _t('KI-Sprachniveau (Sensei)', 'AI Language Level (Sensei)', 'AI言語レベル');
  String get aiLevelA1 => _t('Anfänger (A1)', 'Beginner (A1)', '初級 (A1)');
  String get aiLevelA2 => _t('Grundlagen (A2)', 'Elementary (A2)', '初級 (A2)');
  String get aiLevelB1 => _t('Mittelstufe (B1)', 'Intermediate (B1)', '中級 (B1)');
  String get aiLevelB2 => _t('Gute Mittelstufe (B2)', 'Upper Intermediate (B2)', '中級 (B2)');
  String get aiLevelC1 => _t('Fortgeschritten (C1)', 'Advanced (C1)', '上級 (C1)');

  // ── Path / Grammar ──
  String get learningPath => _t('Lernpfad', 'Learning Path', '学習パス');

  // ── Listen ──
  String get listen => _t('Zuhören', 'Listen', '聞く');

  // ── Exercise / Lesson ──
  String get correct => _t('Richtig! ✓', 'Correct! ✓', '正解！✓');
  String get incorrectPrefix => _t('Falsch. Antwort: ', 'Incorrect. Answer: ', '不正解。答え: ');
  String get incorrectGeneric => _t('Falsch.', 'Incorrect.', '不正解。');
  String get learnWords => _t('📝 Lerne diese Wörter', '📝 Learn these words', '📝 この単語を学ぶ');
  String get grammarLabel => _t('📖 Grammatik', '📖 Grammar', '📖 文法');
  String get typeYourAnswer => _t('Antwort eingeben', 'Type your answer', '答えを入力');
  String get tapToListen => _t('Tippe zum Anhören', 'Tap to listen', 'タップして聞く');
  String get sayAloud => _t('Laut aussprechen:', 'Say this aloud:', '声に出して言って:');
  String get greatJob => _t('Super! ✓', 'Great job! ✓', '素晴らしい！✓');
  String get keepPracticing => _t('Weiter üben!', 'Keep practicing!', '練習を続けよう！');
  String get lessonComplete => _t('Lektion abgeschlossen!', 'Lesson Complete!', 'レッスン完了！');
  String get accuracy => _t('Genauigkeit', 'Accuracy', '正確さ');
  String get checkAnswer => _t('Antwort prüfen', 'Check Answer', '答えを確認');
  String get nextStep => _t('Weiter', 'Next', '次へ');
  String get finish => _t('Abschließen', 'Finish', '完了');
  String get backToPath => _t('Zurück zum Lernpfad', 'Back to Learning Path', '学習パスに戻る');

  // ── Settings (additional) ──
  String get resetAllProgress => _t('Gesamten Fortschritt zurücksetzen', 'Reset All Progress', 'すべての進捗をリセット');
  String get resetAllConfirm => _t('Wirklich alles zurücksetzen?\nDies löscht den gesamten Lernfortschritt und alle Decks.', 'Reset everything?\nThis will erase all learning progress and decks.', '本当にリセットしますか？\nすべての学習進捗とデッキが削除されます。');
  String get resetAllDone => _t('Alles zurückgesetzt!', 'Everything has been reset!', 'すべてリセットされました！');
  String get confirm => _t('Bestätigen', 'Confirm', '確認');

  // ── Speaking Exercises ──
  String get speakingExercises => _t('Sprechübungen', 'Speaking Exercises', 'スピーキング練習');
  String get speakingExercisesDesc => _t('Sprechübungen in Lektionen ein-/ausschalten', 'Enable/disable speaking exercises in lessons', 'レッスンでのスピーキング練習を有効/無効');
  String get skipSpeaking => _t('Überspringen', 'Skip', 'スキップ');
  String get skippedSpeaking => _t('Übersprungen', 'Skipped', 'スキップ済み');
  String get tapToSpeak => _t('Zum Sprechen tippen', 'Tap to speak', 'タップして話す');
  String get listening => _t('Hört zu...', 'Listening...', '聞いています...');
  String get hearModel => _t('Anhören', 'Hear Model', 'お手本を聞く');
  String get didYouSayCorrectly => _t('Hast du es richtig gesagt?', 'Did you say it correctly?', '正しく言えましたか？');
  String get yesIDid => _t('Ja!', 'Yes, I did!', 'はい！');
  String get notYet => _t('Noch nicht', 'Not yet', 'まだ');

  // ── Deck Progress ──
  String get continueSession => _t('Fortsetzen', 'Continue', '続ける');
  String get restartSession => _t('Neu starten', 'Restart', '最初から');
  String get continueOrRestart => _t('Fortsetzen oder Neu starten?', 'Continue or Restart?', '続けますか、それとも最初から？');
  String get continueOrRestartDesc => _t('Du hast eine laufende Sitzung. Möchtest du fortsetzen oder neu starten?', 'You have an ongoing session. Continue or restart?', '進行中のセッションがあります。続けますか？');
  String get lastStudied => _t('Zuletzt gelernt', 'Last studied', '最終学習');
  String get correctWrong => _t('Richtig / Falsch', 'Correct / Wrong', '正解 / 不正解');
  String get progress => _t('Fortschritt', 'Progress', '進捗');
  String get noProgress => _t('Noch nicht gelernt', 'Not studied yet', '未学習');

  // ── Statistics ──
  String get statistics => _t('Statistiken', 'Statistics', '統計');
  String get totalVocab => _t('Gesamt-Vokabelliste', 'Total Vocabulary', '総単語数');
  String get vocabMastered => _t('Gelernt', 'Mastered', '習得済み');
  String get dueToday => _t('Heute fällig', 'Due Today', '今日の復習');
  String get studyStreak => _t('Lernserie', 'Study Streak', '連続学習');
  String get days => _t('Tage', 'days', '日');
  String get accuracyRate => _t('Genauigkeit', 'Accuracy Rate', '正答率');
  String get deckStats => _t('Deck-Statistiken', 'Deck Statistics', 'デッキ統計');

  // ── Global SRS ──
  String get globalReview => _t('Globale Wiederholung', 'Global Review', '全体復習');
  String get globalReviewDesc => _t('Alle Vokabeln aus allen Decks', 'All vocab from all decks', '全デッキの単語');
  String get kanjiReview => _t('Kanji Wiederholung', 'Kanji Review', '漢字復習');
  String get kanjiReviewDesc => _t('Schwächste Kanji üben', 'Practice weakest kanji', '苦手な漢字を練習');
  String get noDueCards => _t('Keine fälligen Karten!', 'No due cards!', '復習するカードはありません！');
  String get allCaughtUp => _t('Alles erledigt! Komm später wieder.', 'All caught up! Come back later.', 'すべて完了！後で戻ってきてください。');

  // ── Dashboard Widgets ──
  String get randomVocab => _t('Zufällige Vokabel', 'Random Vocab', 'ランダム単語');
  String get randomKanji => _t('Zufälliges Kanji', 'Random Kanji', 'ランダム漢字');
  String get tapToReveal => _t('Tippe zum Aufdecken', 'Tap to reveal', 'タップして表示');
  String get dashboard => _t('Übersicht', 'Dashboard', 'ダッシュボード');

  // ── Content Language ──
  String get autoTranslateTitle => _t('Vokabeln übersetzen?', 'Translate vocabulary?', '単語を翻訳しますか？');
  String get autoTranslateDesc => _t('Sollen alle vorhandenen Vokabeln automatisch ins Englische übersetzt werden?', 'Should existing vocabulary be auto-translated to English?', '既存の単語を英語に自動翻訳しますか？');
  String get translateNow => _t('Jetzt übersetzen', 'Translate now', '今すぐ翻訳');
  String get skipTranslation => _t('Überspringen', 'Skip', 'スキップ');

  // ── Worst Kanji ──
  String get practiceWorstKanji => _t('Schwächste Kanji üben', 'Practice Worst Kanji', '苦手な漢字を練習');
  String get practiceWorstKanjiDesc => _t('Deine schwierigsten Kanji wiederholen', 'Review your most difficult kanji', '最も苦手な漢字を復習');

  // ── Study Methods (localized) ──
  String get chooseStudyMethod => _t('Lernmethode wählen', 'Choose Study Method', '学習方法を選択');
  String get exercisesUnitStyle => _t('Übungen (Unit-Stil)', 'Exercises (Unit-Style)', '練習（ユニット形式）');
  String get exercisesUnitStyleDesc => _t('MC, Tippen, Hören & Sprechen', 'MC, Typing, Listening & Speaking', 'MC、タイピング、リスニング＆スピーキング');
  String get editViewCardsDesc => _t('Vokabeln in diesem Deck verwalten', 'Manage vocab in this deck', 'このデッキの単語を管理');
  String get sessionComplete => _t('Sitzung abgeschlossen!', 'Session Complete!', 'セッション完了！');
  String get backToDeck => _t('Zurück zum Deck', 'Back to Deck', 'デッキに戻る');
  String get revealAnswer => _t('Antwort aufdecken', 'Reveal Answer', '答えを表示');
  String get again => _t('Nochmal', 'Again', 'もう一度');
  String get hard => _t('Schwer', 'Hard', '難しい');
  String get good => _t('Gut', 'Good', '良い');
  String get easy => _t('Einfach', 'Easy', '簡単');
  String get translateToJp => _t('Auf Japanisch übersetzen:', 'Translate to Japanese:', '日本語に翻訳:');
  String get translateToMeaning => _t('Bedeutung eingeben:', 'Translate to meaning:', '意味を入力:');
  String get typeKanaKanji => _t('Kana/Kanji eingeben', 'Type Kana/Kanji', 'かな/漢字を入力');
  String get typeMeaning => _t('Bedeutung eingeben', 'Type meaning', '意味を入力');
  String get incorrect => _t('Falsch', 'Incorrect', '不正解');
  String get expected => _t('Richtig wäre', 'Expected', '正解は');
  String get yourInput => _t('Deine Eingabe', 'Your input', 'あなたの入力');
  String get exercise => _t('Übung', 'Exercise', '練習');
  String get vocabulary => _t('Vokabeln', 'Vocabulary', '単語');
  String get grammar => _t('Grammatik', 'Grammar', '文法');
  String get review => _t('Wiederholung', 'Review', '復習');
  String get weiter => _t('Weiter', 'Next', '次へ');
  String get pruefen => _t('Prüfen', 'Check', '確認');
  String get skip3Wrong => _t('Überspringen\n(-5%)', 'Skip\n(-5%)', 'スキップ\n(-5%)');

  // ── Misc ──
  String get addCustomVocab => _t('Vokabel hinzufügen', 'Add Custom Vocabulary', 'カスタム単語を追加');
  String get kanaRequired => _t('Kana und Bedeutung sind erforderlich', 'Kana and Meaning are required', 'かなと意味は必須です');
  String get vocabAdded => _t('Vokabel hinzugefügt', 'Vocabulary added', '単語を追加しました');
  String get noVocabInDeck => _t('Noch keine Vokabeln in diesem Deck.', 'No vocabulary in this deck yet.', 'このデッキにはまだ単語がありません。');
  String get add => _t('Hinzufügen', 'Add', '追加');
  String get meaning => _t('Bedeutung *', 'Meaning *', '意味 *');

  String get startGlobalReview => _t('Alle Vokabeln wiederholen', 'Review All Vocab', '全単語を復習');
  String get continueRecentDeck => _t('Kürzliche Aktivitäten', 'Recent Activity', '最近のアクティビティ');
  String get continueManga => _t('Manga weiterlesen', 'Continue Reading', 'マンガを続ける');
  String get continueLearning => _t('Lernpfad fortsetzen', 'Continue Learning', '学習を続ける');
  String get globalVocabSrs => _t('Vokabel-SRS', 'Vocab SRS', '単語SRS');
  String get kanjiSrs => _t('Kanji-SRS', 'Kanji SRS', '漢字SRS');
  String get dueCards => _t('fällige Karten', 'cards due', '枚復習');
  String get noActivity => _t('Noch keine Aktivität', 'No activity yet', 'アクティビティなし');
  String get nothingDue => _t('Nichts fällig — alles gelernt! 🎉', 'Nothing due — all caught up! 🎉', '復習なし — 完了！🎉');

  // ── AI Chat ──
  String get aiSensei => _t('KI-Sensei', 'AI Sensei', 'AIセンセイ');
  String get aiChat => _t('KI-Chat', 'AI Chat', 'AIチャット');
  String get newChat => _t('Neuer Chat', 'New Chat', '新しいチャット');
  String get conversations => _t('Gespräche', 'Conversations', '会話');
  String get deleteConversation => _t('Gespräch löschen', 'Delete Conversation', '会話を削除');
  String get sendMessage => _t('Nachricht senden...', 'Send message...', 'メッセージを送信...');
  String get aiThinking => _t('KI denkt nach...', 'AI is thinking...', 'AI思考中...');
  String get createDeckFromChat => _t('Deck aus Chat erstellen', 'Create Deck from Chat', 'チャットからデッキ作成');
  String get createUnitFromChat => _t('Unit aus Chat erstellen', 'Create Unit from Chat', 'チャットからユニット作成');
  String get regenerate => _t('Neu generieren', 'Regenerate', '再生成');
  String get editMessage => _t('Nachricht bearbeiten', 'Edit Message', 'メッセージを編集');
  String get aiSettings => _t('KI-Einstellungen', 'AI Settings', 'AI設定');
  String get showFurigana => _t('Furigana anzeigen', 'Show Furigana', 'ふりがなを表示');
  String get showFuriganaDesc => _t('Furigana (Lesung) über Kanji anzeigen', 'Show Furigana (reading) above Kanji', '漢字の上にふりがなを表示');
  String get colorGrammar => _t('Grammatik einfärben', 'Color Grammar', '文法着色');
  String get colorGrammarDesc => _t('Partikel, Verben, Nomen usw. farbig markieren', 'Color particles, verbs, nouns etc.', '助詞、動詞、名詞などを色分け');
  
  // ── Model Selector ──
  String get aiModel => _t('KI-Modell', 'AI Model', 'AIモデル');
  String get modelFastLow => _t('⚡ Schnell (kompakt)', '⚡ Fast (compact)', '⚡ 高速（コンパクト）');
  String get modelBalanced => _t('⚖️ Ausgewogen', '⚖️ Balanced', '⚖️ バランス');
  String get modelSlowHigh => _t('🧠 Langsam (hohe Qualität)', '🧠 Slow (high quality)', '🧠 低速（高品質）');
  String get modelCustom => _t('Eigenes Modell', 'Custom Model', 'カスタムモデル');

  // ── Library ──
  String get ownDecks => _t('Eigene', 'My Decks', 'マイデッキ');
  String get communityDecks => _t('Community', 'Community', 'コミュニティ');
  String get searchDecks => _t('Decks suchen...', 'Search decks...', 'デッキを検索...');
  String get downloaded => _t('Heruntergeladen', 'Downloaded', 'ダウンロード済み');
  String get favorites => _t('Favoriten', 'Favorites', 'お気に入り');
  String get aiGenerated => _t('KI-generiert', 'AI Generated', 'AI生成');

  // ── Unit Creator ──
  String get createUnit => _t('Unit erstellen', 'Create Unit', 'ユニット作成');
  String get vocabLesson => _t('Vokabel-Lektion', 'Vocab Lesson', '単語レッスン');
  String get grammarLesson => _t('Grammatik-Lektion', 'Grammar Lesson', '文法レッスン');
  String get addExercise => _t('Übung hinzufügen', 'Add Exercise', '練習を追加');
  String get multipleChoice => _t('Multiple Choice', 'Multiple Choice', '選択問題');
  String get matchPairs => _t('Zuordnung', 'Match Pairs', 'マッチング');
  String get reorderSentence => _t('Satzreihenfolge', 'Reorder Sentence', '文の並べ替え');
  String get translateExercise => _t('Übersetzen', 'Translate', '翻訳');
  String get listenAndType => _t('Hören & Tippen', 'Listen & Type', '聞いて入力');
  String get speakExercise => _t('Sprechen', 'Speak', 'スピーキング');
  String get publish => _t('Veröffentlichen', 'Publish', '公開');
}
