import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final databaseProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

class DatabaseService {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('ja_manga.db');
    return _db!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version: 15, // V15: Local Units & Lessons
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );

    final result = await db.rawQuery('PRAGMA table_info(decks)');
    final columns = result.map((row) => row['name'] as String).toList();
    if (!columns.contains('parent_unit_id')) {
      await _safeAddColumn(db, 'decks', 'parent_unit_id', 'TEXT');
    }
    if (!columns.contains('is_srs_enabled')) {
      await _safeAddColumn(db, 'decks', 'is_srs_enabled', 'INTEGER NOT NULL DEFAULT 0');
    }
    if (!columns.contains('is_ai_generated')) {
      await _safeAddColumn(db, 'decks', 'is_ai_generated', 'INTEGER NOT NULL DEFAULT 0');
    }

    return db;
  }

  /// Safely adds a column, ignoring "duplicate column name" errors
  Future<void> _safeAddColumn(Database db, String table, String column, String type) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    } catch (e) {
      // Column already exists — ignore
    }
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _safeAddColumn(db, 'vocab', 'manga_title', 'TEXT');
      await _safeAddColumn(db, 'vocab', 'chapter', 'TEXT');
      await _safeAddColumn(db, 'vocab', 'page', 'TEXT');
      await _safeAddColumn(db, 'vocab', 'source_url', 'TEXT');

      const textType = 'TEXT NOT NULL';
      const integerType = 'INTEGER NOT NULL';

      await db.execute('''
      CREATE TABLE IF NOT EXISTS saved_manga (
        url TEXT PRIMARY KEY,
        title $textType,
        cover_url $textType,
        source $textType,
        is_favorite $integerType
      )
      ''');

      await db.execute('''
      CREATE TABLE IF NOT EXISTS downloaded_chapters (
        chapter_url TEXT PRIMARY KEY,
        manga_url $textType,
        chapter_title $textType,
        local_folder_path $textType,
        page_count $integerType,
        downloaded_at $integerType,
        FOREIGN KEY (manga_url) REFERENCES saved_manga (url) ON DELETE CASCADE
      )
      ''');
    }
    if (oldVersion < 3) {
      await _safeAddColumn(db, 'vocab', 'example_sentence', 'TEXT');
      await _safeAddColumn(db, 'vocab', 'example_translation', 'TEXT');
    }
    if (oldVersion < 4) {
      await _safeAddColumn(db, 'decks', 'deck_type', 'TEXT DEFAULT "custom"');
      await _safeAddColumn(db, 'decks', 'thumbnail_path', 'TEXT');
      await _safeAddColumn(db, 'vocab', 'image_path', 'TEXT');
    }
    if (oldVersion < 5) {
      await _safeAddColumn(db, 'vocab', 'translation_en', 'TEXT');
      await _safeAddColumn(db, 'vocab', 'translation_de', 'TEXT');
      await _safeAddColumn(db, 'vocab', 'example_translation_en', 'TEXT');
      await _safeAddColumn(db, 'vocab', 'example_translation_de', 'TEXT');
    }
    if (oldVersion < 6) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS deck_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        deck_id INTEGER NOT NULL,
        method TEXT NOT NULL,
        current_index INTEGER NOT NULL DEFAULT 0,
        total_items INTEGER NOT NULL DEFAULT 0,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
        last_studied_at INTEGER NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (deck_id) REFERENCES decks (id) ON DELETE CASCADE
      )
      ''');
      await db.execute('''
      CREATE TABLE IF NOT EXISTS vocab_stats (
        vocab_id INTEGER PRIMARY KEY,
        correct_count INTEGER NOT NULL DEFAULT 0,
        wrong_count INTEGER NOT NULL DEFAULT 0,
        last_studied_at INTEGER NOT NULL DEFAULT 0,
        streak INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (vocab_id) REFERENCES vocab (id) ON DELETE CASCADE
      )
      ''');
    }
    if (oldVersion < 8) {
      await _safeAddColumn(db, 'decks', 'is_srs_enabled', 'INTEGER NOT NULL DEFAULT 0');
      await _safeAddColumn(db, 'decks', 'parent_unit_id', 'TEXT');
    }
    if (oldVersion < 9) {
      await _safeAddColumn(db, 'vocab', 'lesson_id', 'TEXT');
    }
    if (oldVersion < 10) {
      await _safeAddColumn(db, 'decks', 'parent_deck_id', 'INTEGER');
      await _safeAddColumn(db, 'decks', 'section', 'TEXT');
    }
    if (oldVersion < 11) {
      await _safeAddColumn(db, 'decks', 'category', 'TEXT');
    }
    if (oldVersion < 12) {
      await _safeAddColumn(db, 'vocab', 'is_srs_hidden', 'INTEGER NOT NULL DEFAULT 0');
      await _safeAddColumn(db, 'decks', 'is_official', 'INTEGER NOT NULL DEFAULT 0');
      await _safeAddColumn(db, 'decks', 'download_count', 'INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 13) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
      ''');
      await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        conversation_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        is_edited INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (conversation_id) REFERENCES ai_conversations (id) ON DELETE CASCADE
      )
      ''');
    }
    if (oldVersion < 14) {
      await _safeAddColumn(db, 'ai_messages', 'parent_message_id', 'INTEGER');
    }
    if (oldVersion < 15) {
      await db.execute('''
      CREATE TABLE IF NOT EXISTS units (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
      ''');
      await db.execute('''
      CREATE TABLE IF NOT EXISTS lessons (
        id TEXT PRIMARY KEY,
        unit_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        lesson_type TEXT NOT NULL,
        grammar_explanation TEXT,
        required_accuracy REAL,
        exercises_json TEXT NOT NULL,
        vocab_json TEXT NOT NULL,
        FOREIGN KEY (unit_id) REFERENCES units (id) ON DELETE CASCADE
      )
      ''');
    }
    // Clean up Default Deck (legacy)
    await db.delete('decks', where: 'name = ? AND deck_type IS NULL', whereArgs: ['Default Deck']);
    await db.delete('decks', where: 'name = ? AND deck_type = ?', whereArgs: ['Default Deck', 'custom']);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const nullableTextType = 'TEXT';

    // Deck table for Spaced Repetition decks
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

    // Vocab / Flashcards table
    await db.execute('''
    CREATE TABLE vocab (
      id $idType,
      deck_id $integerType,
      kanji $nullableTextType,
      kana $textType,
      translation $textType,
      translation_en $nullableTextType,
      translation_de $nullableTextType,
      notes $nullableTextType,
      interval $integerType,
      repetition $integerType,
      efactor REAL NOT NULL,
      due_date $integerType,
      manga_title $nullableTextType,
      chapter $nullableTextType,
      page $nullableTextType,
      source_url $nullableTextType,
      example_sentence $nullableTextType,
      example_translation $nullableTextType,
      example_translation_en $nullableTextType,
      example_translation_de $nullableTextType,
      image_path $nullableTextType,
      lesson_id $nullableTextType,
      is_srs_hidden INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (deck_id) REFERENCES decks (id) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE saved_manga (
      url TEXT PRIMARY KEY,
      title $textType,
      cover_url $textType,
      source $textType,
      is_favorite $integerType
    )
    ''');

    await db.execute('''
    CREATE TABLE downloaded_chapters (
      chapter_url TEXT PRIMARY KEY,
      manga_url $textType,
      chapter_title $textType,
      local_folder_path $textType,
      page_count $integerType,
      downloaded_at $integerType,
      FOREIGN KEY (manga_url) REFERENCES saved_manga (url) ON DELETE CASCADE
    )
    ''');
    
    // Deck study session tracking
    await db.execute('''
    CREATE TABLE deck_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      deck_id $integerType,
      method $textType,
      current_index $integerType,
      total_items $integerType,
      correct_count $integerType,
      wrong_count $integerType,
      last_studied_at $integerType,
      is_completed $integerType,
      shuffled_vocab_ids $nullableTextType,
      FOREIGN KEY (deck_id) REFERENCES decks (id) ON DELETE CASCADE
    )
    ''');

    // Per-vocab statistics
    await db.execute('''
    CREATE TABLE vocab_stats (
      vocab_id INTEGER PRIMARY KEY,
      correct_count $integerType,
      wrong_count $integerType,
      last_studied_at $integerType,
      streak $integerType,
      FOREIGN KEY (vocab_id) REFERENCES vocab (id) ON DELETE CASCADE
    )
    ''');
    // Local AI Chat History
    await db.execute('''
    CREATE TABLE ai_conversations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      updated_at INTEGER NOT NULL
    )
    ''');
    await db.execute('''
    CREATE TABLE ai_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      conversation_id INTEGER NOT NULL,
      role TEXT NOT NULL,
      content TEXT NOT NULL,
      is_edited INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      parent_message_id INTEGER,
      FOREIGN KEY (conversation_id) REFERENCES ai_conversations (id) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE units (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      created_at INTEGER NOT NULL
    )
    ''');
    
    await db.execute('''
    CREATE TABLE lessons (
      id TEXT PRIMARY KEY,
      unit_id TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      lesson_type TEXT NOT NULL,
      grammar_explanation TEXT,
      required_accuracy REAL,
      exercises_json TEXT NOT NULL,
      vocab_json TEXT NOT NULL,
      FOREIGN KEY (unit_id) REFERENCES units (id) ON DELETE CASCADE
    )
    ''');
  }
}
