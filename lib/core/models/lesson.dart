enum LessonType {
  vocabGate,
  grammarIntro,
  grammarProduction,
  mixedReinforcement,
  unitTest,
}

class Lesson {
  final String id;
  final String title;
  final String description;
  final LessonType lessonType;
  final String? unitId;
  final List<Map<String, String>> vocabularyList;
  final String grammarExplanation;
  final List<Exercise> exercises;
  final bool isCompleted;
  final bool isUnlocked;
  final double? requiredAccuracy; // e.g. 0.9 for vocab gate, 0.85 for unit test

  Lesson({
    required this.id,
    required this.title,
    required this.description,
    this.lessonType = LessonType.grammarIntro,
    this.vocabularyList = const [],
    this.grammarExplanation = '',
    required this.exercises,
    this.isCompleted = false,
    this.isUnlocked = false,
    this.requiredAccuracy,
    this.unitId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'lessonType': lessonType.name,
      'vocabularyList': vocabularyList,
      'grammarExplanation': grammarExplanation,
      'exercises': exercises.map((e) => (e as dynamic).toMap()).toList(),
      'isCompleted': isCompleted,
      'isUnlocked': isUnlocked,
      'requiredAccuracy': requiredAccuracy,
      'unitId': unitId,
    };
  }

  factory Lesson.fromMap(Map<String, dynamic> map) {
    return Lesson(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      lessonType: LessonType.values.firstWhere(
        (e) => e.name == map['lessonType'],
        orElse: () => LessonType.grammarIntro,
      ),
      vocabularyList: List<Map<String, String>>.from(
        (map['vocabularyList'] as List?)?.map((x) => Map<String, String>.from(x)) ?? [],
      ),
      grammarExplanation: map['grammarExplanation'] ?? '',
      exercises: List<Exercise>.from(
        (map['exercises'] as List?)?.map((x) => Exercise.fromMap(x)) ?? [],
      ),
      isCompleted: map['isCompleted'] ?? false,
      isUnlocked: map['isUnlocked'] ?? true,
      requiredAccuracy: (map['requiredAccuracy'] as num?)?.toDouble(),
      unitId: map['unitId'],
    );
  }
}

abstract class Exercise {
  final String question;
  final String instruction;

  Exercise({required this.question, required this.instruction});

  Map<String, dynamic> toMap();

  static Exercise fromMap(Map<String, dynamic> map) {
    final type = map['type'];
    if (type == 'multiple_choice') return MultipleChoiceExercise.fromMap(map);
    if (type == 'fill_in_blank') return FillInBlankExercise.fromMap(map);
    if (type == 'matching') return MatchingExercise.fromMap(map);
    if (type == 'typing') return TypingExercise.fromMap(map);
    if (type == 'sentence_building') return SentenceBuildingExercise.fromMap(map);
    if (type == 'listening') return ListeningExercise.fromMap(map);
    if (type == 'listening_typing') return ListeningTypingExercise.fromMap(map);
    if (type == 'speaking') return SpeakingExercise.fromMap(map);
    if (type == 'flashcard') return FlashcardExercise.fromMap(map);
    throw Exception('Unknown Exercise type: $type');
  }
}

class MultipleChoiceExercise extends Exercise {
  final List<String> options;
  final String correctOption;

  MultipleChoiceExercise({
    required super.question,
    required super.instruction,
    required this.options,
    required this.correctOption,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'multiple_choice',
      'question': question,
      'instruction': instruction,
      'options': options,
      'correctOption': correctOption,
    };
  }

  factory MultipleChoiceExercise.fromMap(Map<String, dynamic> map) {
    return MultipleChoiceExercise(
      question: map['question'],
      instruction: map['instruction'],
      options: List<String>.from(map['options'] ?? []),
      correctOption: map['correctOption'],
    );
  }
}

class FillInBlankExercise extends Exercise {
  final String sentencePartsBefore;
  final String sentencePartsAfter;
  final String correctAnswer;
  final List<String> wordBank;

  FillInBlankExercise({
    required super.question,
    required super.instruction,
    required this.sentencePartsBefore,
    required this.sentencePartsAfter,
    required this.correctAnswer,
    required this.wordBank,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'fill_in_blank',
      'question': question,
      'instruction': instruction,
      'sentencePartsBefore': sentencePartsBefore,
      'sentencePartsAfter': sentencePartsAfter,
      'correctAnswer': correctAnswer,
      'wordBank': wordBank,
    };
  }

  factory FillInBlankExercise.fromMap(Map<String, dynamic> map) {
    return FillInBlankExercise(
      question: map['question'],
      instruction: map['instruction'],
      sentencePartsBefore: map['sentencePartsBefore'],
      sentencePartsAfter: map['sentencePartsAfter'],
      correctAnswer: map['correctAnswer'],
      wordBank: List<String>.from(map['wordBank'] ?? []),
    );
  }
}

class MatchingExercise extends Exercise {
  final Map<String, String> pairs;

  MatchingExercise({
    required super.question,
    required super.instruction,
    required this.pairs,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'matching',
      'question': question,
      'instruction': instruction,
      'pairs': pairs,
    };
  }

  factory MatchingExercise.fromMap(Map<String, dynamic> map) {
    return MatchingExercise(
      question: map['question'],
      instruction: map['instruction'],
      pairs: Map<String, String>.from(map['pairs'] ?? {}),
    );
  }
}

class TypingExercise extends Exercise {
  final String answer;
  final String? hint;

  TypingExercise({
    required super.question,
    required super.instruction,
    required this.answer,
    this.hint,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'typing',
      'question': question,
      'instruction': instruction,
      'answer': answer,
      'hint': hint,
    };
  }

  factory TypingExercise.fromMap(Map<String, dynamic> map) {
    return TypingExercise(
      question: map['question'],
      instruction: map['instruction'],
      answer: map['answer'],
      hint: map['hint'],
    );
  }
}

class SentenceBuildingExercise extends Exercise {
  final List<String> correctWords;
  final List<String> wordBank;

  SentenceBuildingExercise({
    required super.question,
    required super.instruction,
    required this.correctWords,
    required this.wordBank,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'sentence_building',
      'question': question,
      'instruction': instruction,
      'correctWords': correctWords,
      'wordBank': wordBank,
    };
  }

  factory SentenceBuildingExercise.fromMap(Map<String, dynamic> map) {
    return SentenceBuildingExercise(
      question: map['question'],
      instruction: map['instruction'],
      correctWords: List<String>.from(map['correctWords'] ?? []),
      wordBank: List<String>.from(map['wordBank'] ?? []),
    );
  }
}

class ListeningExercise extends Exercise {
  final String audioText;
  final List<String> options;
  final String correctOption;

  ListeningExercise({
    required super.question,
    required super.instruction,
    required this.audioText,
    required this.options,
    required this.correctOption,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'listening',
      'question': question,
      'instruction': instruction,
      'audioText': audioText,
      'options': options,
      'correctOption': correctOption,
    };
  }

  factory ListeningExercise.fromMap(Map<String, dynamic> map) {
    return ListeningExercise(
      question: map['question'],
      instruction: map['instruction'],
      audioText: map['audioText'],
      options: List<String>.from(map['options'] ?? []),
      correctOption: map['correctOption'],
    );
  }
}

/// Audio plays, user must TYPE what they heard (dictation)
class ListeningTypingExercise extends Exercise {
  final String audioText;
  final String correctAnswer;
  final String? hint;

  ListeningTypingExercise({
    required super.question,
    required super.instruction,
    required this.audioText,
    required this.correctAnswer,
    this.hint,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'listening_typing',
      'question': question,
      'instruction': instruction,
      'audioText': audioText,
      'correctAnswer': correctAnswer,
      'hint': hint,
    };
  }

  factory ListeningTypingExercise.fromMap(Map<String, dynamic> map) {
    return ListeningTypingExercise(
      question: map['question'],
      instruction: map['instruction'],
      audioText: map['audioText'],
      correctAnswer: map['correctAnswer'],
      hint: map['hint'],
    );
  }
}

/// User reads aloud. Phase 1: self-evaluation. Phase 2: AI comparison.
class SpeakingExercise extends Exercise {
  final String targetText; // The JP text user should say
  final String? translation; // English hint

  SpeakingExercise({
    required super.question,
    required super.instruction,
    required this.targetText,
    this.translation,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'speaking',
      'question': question,
      'instruction': instruction,
      'targetText': targetText,
      'translation': translation,
    };
  }

  factory SpeakingExercise.fromMap(Map<String, dynamic> map) {
    return SpeakingExercise(
      question: map['question'],
      instruction: map['instruction'],
      targetText: map['targetText'],
      translation: map['translation'],
    );
  }
}

/// Flashcard for self-evaluation (Again, Hard, Good, Easy)
class FlashcardExercise extends Exercise {
  final String answer; // The back of the card
  final String? hint;   // Extra info (e.g. kana)

  FlashcardExercise({
    required super.question,
    required super.instruction,
    required this.answer,
    this.hint,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': 'flashcard',
      'question': question,
      'instruction': instruction,
      'answer': answer,
      'hint': hint,
    };
  }

  factory FlashcardExercise.fromMap(Map<String, dynamic> map) {
    return FlashcardExercise(
      question: map['question'],
      instruction: map['instruction'],
      answer: map['answer'],
      hint: map['hint'],
    );
  }
}
