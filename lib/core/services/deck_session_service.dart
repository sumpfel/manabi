import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_service.dart';
import 'backend_service.dart';
import 'settings_service.dart';

final deckSessionServiceProvider = Provider<DeckSessionService>((ref) {
  final dbService = ref.watch(databaseProvider);
  return DeckSessionService(dbService, ref);
});

class DeckSession {
  final int? id;
  final int deckId;
  final String method;
  final int currentIndex;
  final int totalItems;
  final int correctCount;
  final int wrongCount;
  final int lastStudiedAt;
  final bool isCompleted;
  final List<int>? shuffledVocabIds;

  DeckSession({
    this.id,
    required this.deckId,
    required this.method,
    this.currentIndex = 0,
    this.totalItems = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    required this.lastStudiedAt,
    this.isCompleted = false,
    this.shuffledVocabIds,
  });

  factory DeckSession.fromMap(Map<String, dynamic> map) {
    return DeckSession(
      id: map['id'],
      deckId: map['deck_id'],
      method: map['method'],
      currentIndex: map['current_index'] ?? 0,
      totalItems: map['total_items'] ?? 0,
      correctCount: map['correct_count'] ?? 0,
      wrongCount: map['wrong_count'] ?? 0,
      lastStudiedAt: map['last_studied_at'],
      isCompleted: (map['is_completed'] ?? 0) == 1,
      shuffledVocabIds: map['shuffled_vocab_ids'] != null 
          ? List<int>.from(map['shuffled_vocab_ids'] is String 
              ? (jsonDecode(map['shuffled_vocab_ids']) as List) 
              : (map['shuffled_vocab_ids'] as List))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'deck_id': deckId,
      'method': method,
      'current_index': currentIndex,
      'total_items': totalItems,
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'last_studied_at': lastStudiedAt,
      'is_completed': isCompleted ? 1 : 0,
      'shuffled_vocab_ids': shuffledVocabIds != null ? jsonEncode(shuffledVocabIds) : null,
    };
  }

  double get progressPercent => totalItems > 0 ? currentIndex / totalItems : 0.0;
  double get accuracyPercent => (correctCount + wrongCount) > 0 ? correctCount / (correctCount + wrongCount) : 0.0;
  double get errorRatePercent => (correctCount + wrongCount) > 0 ? wrongCount / (correctCount + wrongCount) : 0.0;
}

class VocabStat {
  final int vocabId;
  final int correctCount;
  final int wrongCount;
  final int lastStudiedAt;
  final int streak;

  VocabStat({
    required this.vocabId,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.lastStudiedAt = 0,
    this.streak = 0,
  });

  factory VocabStat.fromMap(Map<String, dynamic> map) {
    return VocabStat(
      vocabId: map['vocab_id'],
      correctCount: map['correct_count'] ?? 0,
      wrongCount: map['wrong_count'] ?? 0,
      lastStudiedAt: map['last_studied_at'] ?? 0,
      streak: map['streak'] ?? 0,
    );
  }

  double get accuracyPercent {
    final total = correctCount + wrongCount;
    return total > 0 ? correctCount / total : 0.0;
  }
}

class DeckSessionService {
  final DatabaseService _dbService;
  final Ref _ref;

  DeckSessionService(this._dbService, this._ref);

  DatabaseService get dbService => _dbService;

  // ── Deck Sessions ──

  /// Get the most recent incomplete session for a deck + method
  Future<DeckSession?> getActiveSession(int deckId, String method) async {
    // 1. Try local
    final db = await _dbService.database;
    final maps = await db.query(
      'deck_sessions',
      where: 'deck_id = ? AND method = ? AND is_completed = 0',
      whereArgs: [deckId, method],
      orderBy: 'last_studied_at DESC',
      limit: 1,
    );
    
    DeckSession? localSession;
    if (maps.isNotEmpty) {
      localSession = DeckSession.fromMap(maps.first);
    }

    // 2. Try remote
    final backend = _ref.read(backendServiceProvider);
    if (backend.isAvailable) {
      final remoteData = await backend.getRemoteSession(deckId, method);
      if (remoteData != null) {
        final remoteSession = DeckSession.fromMap({
          ...remoteData,
          'deck_id': remoteData['deck_id'],
          'method': remoteData['study_method'],
          'last_studied_at': DateTime.parse(remoteData['updated_at']).millisecondsSinceEpoch,
          // 'id' is NOT the local id, so we skip it to avoid conflicts or handle it.
        });
        
        // If remote is newer, or local doesn't exist, use remote
        if (localSession == null || remoteSession.lastStudiedAt > localSession.lastStudiedAt) {
          return remoteSession;
        }
      }
    }

    return localSession;
  }

  /// Get all sessions for a deck (for showing progress on deck cards)
  Future<List<DeckSession>> getSessionsForDeck(int deckId) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'deck_sessions',
      where: 'deck_id = ?',
      whereArgs: [deckId],
      orderBy: 'last_studied_at DESC',
    );
    return maps.map((m) => DeckSession.fromMap(m)).toList();
  }

  /// Get the latest session for a deck + method (for progress bar in method selector)
  Future<DeckSession?> getLatestSession(int deckId, String method) async {
    final db = await _dbService.database;
    final maps = await db.query(
      'deck_sessions',
      where: 'deck_id = ? AND method = ?',
      whereArgs: [deckId, method],
      orderBy: 'last_studied_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DeckSession.fromMap(maps.first);
  }

  /// Get the absolute most recently studied session across ALL decks (even completed ones)
  Future<DeckSession?> getMostRecentSessionOverall() async {
    final db = await _dbService.database;
    final maps = await db.query(
      'deck_sessions',
      orderBy: 'last_studied_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DeckSession.fromMap(maps.first);
  }

  /// Save or update a session
  Future<int> saveSession(DeckSession session) async {
    final db = await _dbService.database;
    int id;
    if (session.id != null) {
      await db.update(
        'deck_sessions',
        session.toMap(),
        where: 'id = ?',
        whereArgs: [session.id],
      );
      id = session.id!;
    } else {
      id = await db.insert('deck_sessions', session.toMap());
    }

    // Sync to backend
    final backend = _ref.read(backendServiceProvider);
    if (backend.isAvailable) {
      await backend.saveRemoteSession({
        'deck_id': session.deckId,
        'study_method': session.method,
        'current_index': session.currentIndex,
        'shuffled_vocab_ids': session.shuffledVocabIds,
        'is_active': !session.isCompleted,
      });
    }

    return id;
  }

  /// Mark session as completed
  Future<void> completeSession(int sessionId) async {
    final db = await _dbService.database;
    await db.update(
      'deck_sessions',
      {'is_completed': 1, 'last_studied_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Clear active (incomplete) session for deck + method
  Future<void> clearSession(int deckId, String method) async {
    final db = await _dbService.database;
    await db.delete(
      'deck_sessions',
      where: 'deck_id = ? AND method = ? AND is_completed = 0',
      whereArgs: [deckId, method],
    );
  }

  // ── Vocab Stats ──

  /// Record an answer for a vocab item
  Future<void> recordAnswer(int vocabId, bool correct) async {
    final db = await _dbService.database;
    final existing = await db.query('vocab_stats', where: 'vocab_id = ?', whereArgs: [vocabId]);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (existing.isEmpty) {
      await db.insert('vocab_stats', {
        'vocab_id': vocabId,
        'correct_count': correct ? 1 : 0,
        'wrong_count': correct ? 0 : 1,
        'last_studied_at': now,
        'streak': correct ? 1 : 0,
      });
    } else {
      final stat = VocabStat.fromMap(existing.first);
      await db.update('vocab_stats', {
        'correct_count': stat.correctCount + (correct ? 1 : 0),
        'wrong_count': stat.wrongCount + (correct ? 0 : 1),
        'last_studied_at': now,
        'streak': correct ? stat.streak + 1 : 0,
      }, where: 'vocab_id = ?', whereArgs: [vocabId]);
    }
  }

  /// Get stats for a specific vocab
  Future<VocabStat?> getVocabStat(int vocabId) async {
    final db = await _dbService.database;
    final maps = await db.query('vocab_stats', where: 'vocab_id = ?', whereArgs: [vocabId]);
    if (maps.isEmpty) return null;
    return VocabStat.fromMap(maps.first);
  }

  /// Get worst performing vocab (lowest accuracy > 0 attempts)
  Future<List<VocabStat>> getWorstVocab({int limit = 20}) async {
    final db = await _dbService.database;
    final maps = await db.rawQuery('''
      SELECT * FROM vocab_stats 
      WHERE (correct_count + wrong_count) > 0
      ORDER BY CAST(correct_count AS REAL) / (correct_count + wrong_count) ASC
      LIMIT ?
    ''', [limit]);
    return maps.map((m) => VocabStat.fromMap(m)).toList();
  }

  /// Get aggregate stats across all vocab
  Future<Map<String, int>> getOverallStats() async {
    final db = await _dbService.database;
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(correct_count), 0) as total_correct,
        COALESCE(SUM(wrong_count), 0) as total_wrong,
        COUNT(*) as total_studied
      FROM vocab_stats
    ''');
    if (result.isEmpty) return {'total_correct': 0, 'total_wrong': 0, 'total_studied': 0};
    return {
      'total_correct': (result.first['total_correct'] as int?) ?? 0,
      'total_wrong': (result.first['total_wrong'] as int?) ?? 0,
      'total_studied': (result.first['total_studied'] as int?) ?? 0,
    };
  }

  /// Get last study date across all sessions
  Future<int?> getLastStudyDate() async {
    final db = await _dbService.database;
    final result = await db.rawQuery('SELECT MAX(last_studied_at) as last_date FROM deck_sessions');
    return result.first['last_date'] as int?;
  }
}
