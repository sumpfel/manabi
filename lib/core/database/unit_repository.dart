import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/unit.dart';
import '../models/lesson.dart';
import 'database_service.dart';

final unitRepositoryProvider = Provider<UnitRepository>((ref) {
  return UnitRepository(ref.read(databaseProvider));
});

class UnitRepository {
  final DatabaseService _dbService;

  UnitRepository(this._dbService);

  Future<void> insertUnit(Unit unit) async {
    final db = await _dbService.database;
    await db.transaction((txn) async {
      await txn.insert('units', {
        'id': unit.id,
        'title': unit.title,
        'description': unit.description,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      for (final lesson in unit.lessons) {
        await txn.insert('lessons', {
          'id': lesson.id,
          'unit_id': unit.id,
          'title': lesson.title,
          'description': lesson.description,
          'lesson_type': lesson.lessonType.name,
          'grammar_explanation': lesson.grammarExplanation,
          'required_accuracy': lesson.requiredAccuracy,
          'exercises_json': jsonEncode(lesson.exercises.map((e) => (e as dynamic).toMap()).toList()),
          'vocab_json': jsonEncode(lesson.vocabularyList),
        });
      }
    });
  }

  Future<List<Unit>> getCustomUnits() async {
    final db = await _dbService.database;
    final unitMaps = await db.query('units', orderBy: 'created_at DESC');
    
    final List<Unit> units = [];
    for (final uMap in unitMaps) {
      final unitId = uMap['id'] as String;
      final lessonMaps = await db.query('lessons', where: 'unit_id = ?', whereArgs: [unitId]);
      
      final lessons = lessonMaps.map((lMap) {
        return Lesson(
          id: lMap['id'] as String,
          unitId: unitId,
          title: lMap['title'] as String,
          description: lMap['description'] as String,
          lessonType: LessonType.values.firstWhere(
            (e) => e.name == lMap['lesson_type'],
            orElse: () => LessonType.grammarIntro,
          ),
          grammarExplanation: lMap['grammar_explanation'] as String? ?? '',
          requiredAccuracy: (lMap['required_accuracy'] as num?)?.toDouble(),
          exercises: (jsonDecode(lMap['exercises_json'] as String) as List)
              .map((e) => Exercise.fromMap(e as Map<String, dynamic>))
              .toList(),
          vocabularyList: (jsonDecode(lMap['vocab_json'] as String) as List)
              .map((v) => Map<String, String>.from(v as Map))
              .toList(),
        );
      }).toList();

      units.add(Unit(
        id: unitId,
        title: uMap['title'] as String,
        description: uMap['description'] as String,
        lessons: lessons,
        unitVocab: [], // Vocab for units is usually handled separately or generated on the fly
      ));
    }
    return units;
  }

  Future<void> deleteUnit(String unitId) async {
    final db = await _dbService.database;
    await db.delete('units', where: 'id = ?', whereArgs: [unitId]);
  }
}
