import 'lesson.dart';
import 'vocab.dart';

class Unit {
  final String id;
  final String title;
  final String description;
  final List<Lesson> lessons;
  final List<Vocab> unitVocab; // Vocab that belongs to this unit

  Unit({
    required this.id,
    required this.title,
    required this.description,
    required this.lessons,
    required this.unitVocab,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'lessons': lessons.map((l) => l.toMap()).toList(),
      'unitVocab': unitVocab.map((v) => v.toMap()).toList(),
    };
  }

  factory Unit.fromMap(Map<String, dynamic> map) {
    return Unit(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      lessons: List<Lesson>.from(map['lessons']?.map((x) => Lesson.fromMap(x)) ?? []),
      unitVocab: List<Vocab>.from(map['unitVocab']?.map((x) => Vocab.fromMap(x)) ?? []),
    );
  }
}
