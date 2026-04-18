import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final dbPath = 'test_db.sqlite';
  if (File(dbPath).existsSync()) {
    File(dbPath).deleteSync();
  }
  
  final db = await databaseFactory.openDatabase(dbPath, options: OpenDatabaseOptions(
    version: 15,
    onCreate: (db, version) async {
      print('Creating DB...');
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const textType = 'TEXT NOT NULL';
      const integerType = 'INTEGER NOT NULL';
      const nullableTextType = 'TEXT';
      
      await db.execute('''
      CREATE TABLE decks (
        id $idType,
        name $textType,
        description $nullableTextType,
        created_at $integerType,
        deck_type $nullableTextType,
        thumbnail_path $nullableTextType,
        is_srs_enabled INTEGER NOT NULL DEFAULT 0,
        parent_unit_id $nullableTextType,
        parent_deck_id INTEGER,
        section $nullableTextType,
        category $nullableTextType,
        is_official INTEGER NOT NULL DEFAULT 0,
        download_count INTEGER NOT NULL DEFAULT 0,
        is_ai_generated INTEGER NOT NULL DEFAULT 0
      )
      ''');
    },
  ));

  print('DB created. Trying to insert a deck...');
  
  try {
    final map = {
      'name': 'Test Deck',
      'description': 'Description',
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'deck_type': 'unit',
      'thumbnail_path': null,
      'is_srs_enabled': 1,
      'parent_unit_id': 'unit_1',
      'parent_deck_id': null,
      'section': null,
      'category': null,
      'is_official': 0,
      'download_count': 0,
      'is_ai_generated': 0,
    };
    await db.insert('decks', map);
    print('Deck inserted successfully!');
  } catch (e) {
    print('Insert failed: $e');
  }
}
