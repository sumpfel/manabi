class Vocab {
  final int? id;
  final int deckId;
  final String? kanji;
  final String kana;
  final String translation; // legacy fallback (may contain 'EN | DE')
  final String? translationEn;
  final String? translationDe;
  final String? notes;
  final int interval;
  final int repetition;
  final double efactor;
  final int dueDate;

  // New V2 Tracking Fields
  final String? mangaTitle;
  final String? chapter;
  final String? page; // usually image URL or page number
  final String? sourceUrl;

  // New V3 Fields
  final String? exampleSentence;
  final String? exampleTranslation; // legacy fallback
  final String? exampleTranslationEn;
  final String? exampleTranslationDe;
  
  // New V4 Fields
  final String? imagePath; // Path to vocab card image
  final String? lessonId; // ID of the lesson this vocab belongs to (for Units)
  // V12 Fields
  final bool isSrsHidden; // User can hide individual words from SRS

  Vocab({
    this.id,
    required this.deckId,
    this.kanji,
    required this.kana,
    required this.translation,
    this.translationEn,
    this.translationDe,
    this.notes,
    this.interval = 0,
    this.repetition = 0,
    this.efactor = 2.5,
    required this.dueDate,
    this.mangaTitle,
    this.chapter,
    this.page,
    this.sourceUrl,
    this.exampleSentence,
    this.exampleTranslation,
    this.exampleTranslationEn,
    this.exampleTranslationDe,
    this.imagePath,
    this.lessonId,
    this.isSrsHidden = false,
  });

  Vocab copyWith({
    int? id,
    int? deckId,
    String? kanji,
    String? kana,
    String? translation,
    String? translationEn,
    String? translationDe,
    String? notes,
    int? interval,
    int? repetition,
    double? efactor,
    int? dueDate,
    String? mangaTitle,
    String? chapter,
    String? page,
    String? sourceUrl,
    String? exampleSentence,
    String? exampleTranslation,
    String? exampleTranslationEn,
    String? exampleTranslationDe,
    String? imagePath,
    String? lessonId,
    bool? isSrsHidden,
  }) {
    return Vocab(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      kanji: kanji ?? this.kanji,
      kana: kana ?? this.kana,
      translation: translation ?? this.translation,
      translationEn: translationEn ?? this.translationEn,
      translationDe: translationDe ?? this.translationDe,
      notes: notes ?? this.notes,
      interval: interval ?? this.interval,
      repetition: repetition ?? this.repetition,
      efactor: efactor ?? this.efactor,
      dueDate: dueDate ?? this.dueDate,
      mangaTitle: mangaTitle ?? this.mangaTitle,
      chapter: chapter ?? this.chapter,
      page: page ?? this.page,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      exampleTranslation: exampleTranslation ?? this.exampleTranslation,
      exampleTranslationEn: exampleTranslationEn ?? this.exampleTranslationEn,
      exampleTranslationDe: exampleTranslationDe ?? this.exampleTranslationDe,
      imagePath: imagePath ?? this.imagePath,
      lessonId: lessonId ?? this.lessonId,
      isSrsHidden: isSrsHidden ?? this.isSrsHidden,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'deck_id': deckId,
      'kanji': kanji,
      'kana': kana,
      'translation': translation,
      'translation_en': translationEn,
      'translation_de': translationDe,
      'notes': notes,
      'interval': interval,
      'repetition': repetition,
      'efactor': efactor,
      'due_date': dueDate,
      'manga_title': mangaTitle,
      'chapter': chapter,
      'page': page,
      'source_url': sourceUrl,
      'example_sentence': exampleSentence,
      'example_translation': exampleTranslation,
      'example_translation_en': exampleTranslationEn,
      'example_translation_de': exampleTranslationDe,
      'image_path': imagePath,
      'lesson_id': lessonId,
      'is_srs_hidden': isSrsHidden ? 1 : 0,
    };
  }

  factory Vocab.fromMap(Map<String, dynamic> map) {
    return Vocab(
      id: map['id'],
      deckId: map['deck_id'],
      kanji: map['kanji'],
      kana: map['kana'],
      translation: map['translation'],
      translationEn: map['translation_en'],
      translationDe: map['translation_de'],
      notes: map['notes'],
      interval: map['interval'] ?? 0,
      repetition: map['repetition'] ?? 0,
      efactor: (map['efactor'] ?? 2.5).toDouble(),
      dueDate: map['due_date'],
      mangaTitle: map['manga_title'],
      chapter: map['chapter'],
      page: map['page'],
      sourceUrl: map['source_url'],
      exampleSentence: map['example_sentence'],
      exampleTranslation: map['example_translation'],
      exampleTranslationEn: map['example_translation_en'],
      exampleTranslationDe: map['example_translation_de'],
      imagePath: map['image_path'],
      lessonId: map['lesson_id'],
      isSrsHidden: (map['is_srs_hidden'] ?? 0) == 1,
    );
  }

  /// Returns the translation in the requested language.
  String localizedTranslation(String contentLang) {
    if (contentLang == 'de' && translationDe != null && translationDe!.isNotEmpty) return translationDe!;
    if (contentLang == 'en' && translationEn != null && translationEn!.isNotEmpty) return translationEn!;
    
    // Fallback: check if the legacy `translation` contains " | "
    if (translation.contains(' | ')) {
       final parts = translation.split(' | ');
       if (parts.length >= 2) {
          if (contentLang == 'de') return parts[1].trim();
          return parts[0].trim();
       }
    }
    return translation;
  }

  String localizedExample(String contentLang) {
    if (contentLang == 'de' && exampleTranslationDe != null) return exampleTranslationDe!;
    if (contentLang == 'en' && exampleTranslationEn != null) return exampleTranslationEn!;
    return exampleTranslation ?? '';
  }
}
