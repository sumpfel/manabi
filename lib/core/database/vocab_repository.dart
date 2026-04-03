import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';
import '../services/backend_service.dart';
import '../models/deck.dart';
import '../models/vocab.dart';

final vocabRepositoryProvider = Provider<VocabRepository>((ref) {
  final dbService = ref.watch(databaseProvider);
  final backendService = ref.watch(backendServiceProvider);
  return VocabRepository(dbService, backendService);
});

class VocabRepository {
  final DatabaseService _dbService;
  final BackendService _backendService;

  VocabRepository(this._dbService, this._backendService);

  Future<List<Deck>> getDecks() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('decks');
    return List.generate(maps.length, (i) => Deck.fromMap(maps[i]));
  }

  Future<Deck?> getDeckById(int id) async {
    final db = await _dbService.database;
    final maps = await db.query('decks', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Deck.fromMap(maps.first);
  }

  Future<int> addDeck(Deck deck) async {
    final db = await _dbService.database;
    final id = await db.insert('decks', deck.toMap());
    // Trigger Cloud Sync asynchronously
    _backendService.syncDecks();
    return id;
  }

  Future<List<Vocab>> getVocabForDeck(int deckId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'vocab',
      where: 'deck_id = ?',
      whereArgs: [deckId],
    );
    return List.generate(maps.length, (i) => Vocab.fromMap(maps[i]));
  }

  /// Get all vocab from all decks (for global SRS review)
  Future<List<Vocab>> getAllVocab() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('vocab');
    return List.generate(maps.length, (i) => Vocab.fromMap(maps[i]));
  }

  /// Get due vocab across all decks
  Future<List<Vocab>> getDueVocab() async {
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final List<Map<String, dynamic>> maps = await db.query(
      'vocab',
      where: 'due_date <= ?',
      whereArgs: [now],
    );
    return List.generate(maps.length, (i) => Vocab.fromMap(maps[i]));
  }

  /// Get due VOCAB (words/phrases) from non-kanji SRS-enabled decks.
  /// Deduplicates by kanji+kana (keeps earliest due date).
  Future<List<Vocab>> getDueSrsVocab() async {
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT v.* FROM vocab v
      INNER JOIN decks d ON v.deck_id = d.id
      WHERE v.due_date <= ?
        AND d.deck_type != 'kanji'
        AND (d.deck_type = 'unit' OR d.is_srs_enabled = 1)
        AND v.is_srs_hidden = 0
        AND (v.repetition > 0 OR EXISTS (SELECT 1 FROM vocab_stats vs WHERE vs.vocab_id = v.id))
      ORDER BY v.due_date ASC
    ''', [now]);

    final allVocab = List.generate(maps.length, (i) => Vocab.fromMap(maps[i]));

    // Deduplicate by kanji+kana
    final seen = <String>{};
    final deduped = <Vocab>[];
    for (final v in allVocab) {
      final key = '${v.kanji ?? ''}|${v.kana}';
      if (seen.add(key)) deduped.add(v);
    }
    return deduped;
  }

  /// Get due KANJI (single characters) from kanji-type SRS-enabled decks.
  /// Deduplicates by kanji character (each kanji only once).
  Future<List<Vocab>> getDueSrsKanji() async {
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT v.* FROM vocab v
      INNER JOIN decks d ON v.deck_id = d.id
      WHERE v.due_date <= ?
        AND d.deck_type = 'kanji'
        AND d.is_srs_enabled = 1
        AND v.is_srs_hidden = 0
        AND v.kanji IS NOT NULL AND LENGTH(v.kanji) = 1
        AND (v.repetition > 0 OR EXISTS (SELECT 1 FROM vocab_stats vs WHERE vs.vocab_id = v.id))
      ORDER BY v.due_date ASC
    ''', [now]);

    final allVocab = List.generate(maps.length, (i) => Vocab.fromMap(maps[i]));

    // Deduplicate by kanji character
    final seen = <String>{};
    final deduped = <Vocab>[];
    for (final v in allVocab) {
      if (v.kanji != null && seen.add(v.kanji!)) deduped.add(v);
    }
    return deduped;
  }

  Future<int> addVocab(Vocab vocab) async {
    final db = await _dbService.database;
    return await db.insert('vocab', vocab.toMap());
  }

  Future<int> updateVocab(Vocab vocab) async {
    final db = await _dbService.database;
    return await db.update(
      'vocab',
      vocab.toMap(),
      where: 'id = ?',
      whereArgs: [vocab.id],
    );
  }

  Future<int> deleteVocab(int vocabId) async {
    final db = await _dbService.database;
    return await db.delete(
      'vocab',
      where: 'id = ?',
      whereArgs: [vocabId],
    );
  }

  /// Get sub-decks (children) of a parent deck
  Future<List<Deck>> getSubDecks(int parentDeckId) async {
    final db = await _dbService.database;
    final maps = await db.query('decks', where: 'parent_deck_id = ?', whereArgs: [parentDeckId]);
    return List.generate(maps.length, (i) => Deck.fromMap(maps[i]));
  }

  /// Get or create a manga vocab deck, returns the deck ID
  Future<int> getOrCreateMangaDeck(String mangaTitle) async {
    final db = await _dbService.database;
    final existing = await db.query('decks',
        where: 'name = ? AND deck_type = ?',
        whereArgs: [mangaTitle, 'manga']);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    return await db.insert('decks', Deck(
      name: mangaTitle,
      description: 'Vokabeln aus $mangaTitle',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      deckType: DeckType.manga,
    ).toMap());
  }

  /// Get or create a sub-section within a parent deck
  Future<int> getOrCreateSubDeck(int parentDeckId, String sectionName, DeckType type) async {
    final db = await _dbService.database;
    final existing = await db.query('decks',
        where: 'parent_deck_id = ? AND section = ?',
        whereArgs: [parentDeckId, sectionName]);
    if (existing.isNotEmpty) return existing.first['id'] as int;
    final parentDeck = await getDeckById(parentDeckId);
    return await db.insert('decks', Deck(
      name: '${parentDeck?.name ?? ''} - $sectionName',
      description: sectionName,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      deckType: type,
      parentDeckId: parentDeckId,
      section: sectionName,
    ).toMap());
  }

  /// Check if a vocab word exists in any deck (for yellow marking)
  Future<bool> vocabExistsGlobally(String kanji, String kana) async {
    final db = await _dbService.database;
    final maps = await db.query('vocab',
        where: '(kanji = ? OR kana = ?) AND (kanji IS NOT NULL OR kana IS NOT NULL)',
        whereArgs: [kanji, kana],
        limit: 1);
    return maps.isNotEmpty;
  }

  Future<Deck?> getDeckByName(String name) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'decks',
      where: 'name = ?',
      whereArgs: [name],
    );
    if (maps.isEmpty) return null;
    return Deck.fromMap(maps.first);
  }

  /// Find a kanji deck by its parent unit ID
  Future<Deck?> getKanjiDeckByUnitId(String unitId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'decks',
      where: 'parent_unit_id = ? AND deck_type = ?',
      whereArgs: [unitId, 'kanji'],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Deck.fromMap(maps.first);
  }

  /// Find a deck by its parent unit ID (for unit decks)
  Future<Deck?> getDeckByParentUnitId(String unitId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'decks',
      where: 'parent_unit_id = ? AND deck_type = ?',
      whereArgs: [unitId, 'unit'],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Deck.fromMap(maps.first);
  }

  /// Remove duplicate unit decks for the same unit, keeping only [keepDeckId].
  /// Extracted vocab strings are re-assigned, and custom decks are untouched.
  Future<void> deduplicateUnitDecks(String unitId, int keepDeckId) async {
    final db = await _dbService.database;
    // Find precise duplicates spawned by Unit synchronizations ONLY
    final duplicates = await db.query(
      'decks',
      where: 'parent_unit_id = ? AND deck_type = ? AND id != ?',
      whereArgs: [unitId, 'unit', keepDeckId],
    );

    for (final dup in duplicates) {
      final dupId = dup['id'] as int;
      // Re-assign vocab
      await db.update('vocab', {'deck_id': keepDeckId}, where: 'deck_id = ?', whereArgs: [dupId]);
      // Remove structural deck shell
      await db.delete('decks', where: 'id = ?', whereArgs: [dupId]);
    }
  }

  Future<bool> vocabExists(String kanji, String kana, int deckId) async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'vocab',
      where: 'kanji = ? AND kana = ? AND deck_id = ?',
      whereArgs: [kanji, kana, deckId],
    );
    return maps.isNotEmpty;
  }

  Future<int> deleteDeck(int deckId) async {
    final db = await _dbService.database;
    // Delete all vocab in deck first
    await db.delete('vocab', where: 'deck_id = ?', whereArgs: [deckId]);
    return await db.delete('decks', where: 'id = ?', whereArgs: [deckId]);
  }

  Future<int> updateDeck(Deck deck) async {
    final db = await _dbService.database;
    return await db.update('decks', deck.toMap(), where: 'id = ?', whereArgs: [deck.id]);
  }

  Future<int> cloneDeck(int sourceId, String newName) async {
    final db = await _dbService.database;
    
    // Get source deck
    final deckMaps = await db.query('decks', where: 'id = ?', whereArgs: [sourceId]);
    if (deckMaps.isEmpty) return -1;
    final sourceDeck = Deck.fromMap(deckMaps.first);

    // Create new deck
    final newDeckId = await db.insert('decks', Deck(
      name: newName,
      description: sourceDeck.description,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      deckType: DeckType.custom,
    ).toMap());

    // Clone all vocab
    final vocabs = await getVocabForDeck(sourceId);
    for (var v in vocabs) {
      await db.insert('vocab', v.copyWith(
        id: null, // Remove ID so it auto-increments
        deckId: newDeckId,
      ).toMap()..remove('id'));
    }

    // Trigger Cloud Sync asynchronously
    _backendService.syncDecks();

    return newDeckId;
  }

  // ── Real Statistics Queries ──

  /// Total unique vocab count from non-kanji decks (deduplicated by kanji+kana)
  Future<int> getTotalVocabCount() async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM (
        SELECT DISTINCT COALESCE(v.kanji, '') || '|' || v.kana as vocab_key
        FROM vocab v
        INNER JOIN decks d ON v.deck_id = d.id
        WHERE d.deck_type != 'kanji'
      )
    ''');
    return result.first['cnt'] as int? ?? 0;
  }

  /// Total unique kanji count from kanji decks + unit kanji (single characters only, deduplicated)
  Future<int> getTotalKanjiCount() async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM (
        SELECT DISTINCT v.kanji
        FROM vocab v
        INNER JOIN decks d ON v.deck_id = d.id
        WHERE d.deck_type = 'kanji'
          AND v.kanji IS NOT NULL AND LENGTH(v.kanji) = 1
      )
    ''');
    return result.first['cnt'] as int? ?? 0;
  }

  /// Average accuracy from vocab_stats (percentage 0-100)
  Future<double> getOverallAccuracy() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT AVG(correct_count * 100.0 / (correct_count + wrong_count)) as acc '
      'FROM vocab_stats WHERE (correct_count + wrong_count) > 0'
    );
    final acc = result.first['acc'];
    if (acc == null) return 0;
    return (acc as num).toDouble();
  }

  /// Count of vocab due for SRS review (non-kanji decks, deduplicated)
  Future<int> getDueVocabCount() async {
    final vocab = await getDueSrsVocab();
    return vocab.length;
  }

  /// Count of kanji due for SRS review (kanji decks only, deduplicated)
  Future<int> getDueKanjiCount() async {
    final vocab = await getDueSrsKanji();
    return vocab.length;
  }

  /// Set repetition=1 for all vocab in a deck that has repetition=0 (so it appears in SRS)
  Future<void> ensureUnitVocabInSrs(int deckId) async {
    final db = await _dbService.database;
    await db.rawUpdate(
      'UPDATE vocab SET repetition = 1 WHERE deck_id = ? AND repetition = 0',
      [deckId],
    );
  }

  /// Delete unit decks and their kanji decks for units that are not yet reached.
  /// [reachedUnitIds] is the set of unit IDs the user has unlocked.
  Future<void> cleanupLockedUnitDecks(Set<String> reachedUnitIds) async {
    final db = await _dbService.database;
    // Find all unit-type decks and kanji decks with a parentUnitId
    final unitDecks = await db.query('decks',
      where: 'parent_unit_id IS NOT NULL AND (deck_type = ? OR deck_type = ?)',
      whereArgs: ['unit', 'kanji'],
    );
    for (final deckMap in unitDecks) {
      final parentUnitId = deckMap['parent_unit_id'] as String?;
      if (parentUnitId != null && !reachedUnitIds.contains(parentUnitId)) {
        final deckId = deckMap['id'] as int;
        await db.delete('vocab', where: 'deck_id = ?', whereArgs: [deckId]);
        await db.delete('decks', where: 'id = ?', whereArgs: [deckId]);
      }
    }
  }

  // ── Selective Reset Methods ──

  /// Reset unit progress (completed lessons, accuracies)
  Future<void> resetUnitProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('completed_lessons');
    await prefs.remove('lesson_accuracies');
  }

  /// Delete all custom decks and their vocab
  Future<void> deleteCustomDecks() async {
    final db = await _dbService.database;
    final customDecks = await db.query('decks', where: 'deck_type = ?', whereArgs: ['custom']);
    for (final deck in customDecks) {
      final deckId = deck['id'] as int;
      await db.delete('vocab', where: 'deck_id = ?', whereArgs: [deckId]);
      await db.delete('vocab_stats', where: 'vocab_id IN (SELECT id FROM vocab WHERE deck_id = ?)', whereArgs: [deckId]);
    }
    await db.delete('decks', where: 'deck_type = ?', whereArgs: ['custom']);
  }

  /// Delete all unit decks and their vocab
  Future<void> deleteUnitDecks() async {
    final db = await _dbService.database;
    final unitDecks = await db.query('decks', where: 'deck_type = ?', whereArgs: ['unit']);
    for (final deck in unitDecks) {
      final deckId = deck['id'] as int;
      await db.delete('vocab', where: 'deck_id = ?', whereArgs: [deckId]);
    }
    await db.delete('decks', where: 'deck_type = ?', whereArgs: ['unit']);
  }

  /// Delete all manga decks and their vocab
  Future<void> deleteMangaDecks() async {
    final db = await _dbService.database;
    final mangaDecks = await db.query('decks', where: 'deck_type = ?', whereArgs: ['manga']);
    for (final deck in mangaDecks) {
      final deckId = deck['id'] as int;
      await db.delete('vocab', where: 'deck_id = ?', whereArgs: [deckId]);
    }
    await db.delete('decks', where: 'deck_type = ?', whereArgs: ['manga']);
  }

  /// Delete all manga bookmarks
  Future<void> deleteMangaBookmarks() async {
    final db = await _dbService.database;
    await db.delete('saved_manga');
  }

  /// Clear all vocab stats and deck sessions
  Future<void> deleteVocabStats() async {
    final db = await _dbService.database;
    await db.delete('vocab_stats');
    await db.delete('deck_sessions');
  }
}
