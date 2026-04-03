import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/unit.dart';
import '../models/lesson.dart';
import '../database/vocab_repository.dart';
import '../models/deck.dart';
import '../models/vocab.dart';
import '../data/course_data.dart';
import '../services/progress_service.dart';

final initialSyncCompleteProvider = StateProvider<bool>((ref) => false);

final studyServiceProvider = Provider<StudyService>((ref) {
  final vocabRepo = ref.watch(vocabRepositoryProvider);
  return StudyService(vocabRepo, ref);
});

/// Kanji sets per unit (same data as writing_screen.dart unitKanjiSets)
const _unitKanjiData = <String, List<Map<String, String>>>{
  'unit_1': [
    {'kanji': '私', 'reading': 'watashi', 'meaning': 'Ich'}, {'kanji': '友', 'reading': 'tomo', 'meaning': 'Freund'},
    {'kanji': '先', 'reading': 'sen', 'meaning': 'Vorher'}, {'kanji': '生', 'reading': 'sei', 'meaning': 'Leben'},
    {'kanji': '学', 'reading': 'gaku', 'meaning': 'Lernen'}, {'kanji': '本', 'reading': 'hon', 'meaning': 'Buch'},
    {'kanji': '水', 'reading': 'mizu', 'meaning': 'Wasser'}, {'kanji': '猫', 'reading': 'neko', 'meaning': 'Katze'},
    {'kanji': '犬', 'reading': 'inu', 'meaning': 'Hund'}, {'kanji': '何', 'reading': 'nani', 'meaning': 'Was'},
    {'kanji': '誰', 'reading': 'dare', 'meaning': 'Wer'}, {'kanji': '人', 'reading': 'hito', 'meaning': 'Mensch'},
    {'kanji': '家', 'reading': 'ie', 'meaning': 'Haus'}, {'kanji': '車', 'reading': 'kuruma', 'meaning': 'Auto'},
  ],
  'unit_2': [
    {'kanji': '朝', 'reading': 'asa', 'meaning': 'Morgen'}, {'kanji': '昼', 'reading': 'hiru', 'meaning': 'Mittag'},
    {'kanji': '夜', 'reading': 'yoru', 'meaning': 'Nacht'}, {'kanji': '駅', 'reading': 'eki', 'meaning': 'Bahnhof'},
    {'kanji': '映', 'reading': 'ei', 'meaning': 'Reflektieren'}, {'kanji': '画', 'reading': 'ga', 'meaning': 'Bild'},
    {'kanji': '音', 'reading': 'on', 'meaning': 'Geräusch'}, {'kanji': '楽', 'reading': 'gaku', 'meaning': 'Vergnügen'},
    {'kanji': '公', 'reading': 'kou', 'meaning': 'Öffentlich'}, {'kanji': '園', 'reading': 'en', 'meaning': 'Garten'},
    {'kanji': '手', 'reading': 'te', 'meaning': 'Hand'}, {'kanji': '紙', 'reading': 'kami', 'meaning': 'Papier'},
  ],
  'unit_3': [
    {'kanji': '出', 'reading': 'de', 'meaning': 'Herausgehen'}, {'kanji': '起', 'reading': 'ki', 'meaning': 'Aufwachen'},
    {'kanji': '寝', 'reading': 'ne', 'meaning': 'Schlafen'}, {'kanji': '見', 'reading': 'mi', 'meaning': 'Sehen'},
    {'kanji': '食', 'reading': 'ta', 'meaning': 'Essen'}, {'kanji': '飲', 'reading': 'no', 'meaning': 'Trinken'},
  ],
};

class StudyService {
  final VocabRepository _vocabRepo;
  final ProviderRef _ref;
  final _syncLock = <String>{};
  bool hasInitiallySynced = false;
  bool _isSyncing = false;

  StudyService(this._vocabRepo, this._ref);

  Future<void> syncAllReachedUnits(ProgressState progress) async {
    if (!progress.isLoaded || _isSyncing) return;
    _isSyncing = true;
    try {
      hasInitiallySynced = true;
      final units = CourseData.units;
    for (int ui = 0; ui < units.length; ui++) {
      final unit = units[ui];

      if (ui > 0) {
        final prevUnit = units[ui - 1];
        if (prevUnit.lessons.isNotEmpty && !progress.isCompleted(prevUnit.lessons.last.id)) {
          continue;
        }
      }

      int unitMaxUnlocked = -1;
      for (int j = 0; j < unit.lessons.length; j++) {
         bool lessonUnlocked = true;
         for (int k = 0; k < j; k++) {
           if (!progress.isCompleted(unit.lessons[k].id)) {
             lessonUnlocked = false;
             break;
           }
         }
         if (lessonUnlocked) unitMaxUnlocked = j;
      }
      await syncUnitVocab(unit, unitMaxUnlocked);
    }
    } finally {
      _isSyncing = false;
      _ref.read(initialSyncCompleteProvider.notifier).state = true;
    }
  }

  Future<void> syncUnitVocab(Unit unit, int maxUnlockedIndex) async {
    // Prevent concurrent syncs for the same unit (race condition → duplicates)
    if (_syncLock.contains(unit.id)) return;
    _syncLock.add(unit.id);
    try {
      await _syncUnitVocabImpl(unit, maxUnlockedIndex);
    } finally {
      _syncLock.remove(unit.id);
    }
  }

  Future<void> _syncUnitVocabImpl(Unit unit, int maxUnlockedIndex) async {
    // 1. Get or create a course deck — lookup by parentUnitId to avoid duplicates
    Deck? deck = await _vocabRepo.getDeckByParentUnitId(unit.id);

    // Fallback: also check legacy name format
    deck ??= await _vocabRepo.getDeckByName('Course: ${unit.title}');
    deck ??= await _vocabRepo.getDeckByName(unit.title);

    int deckId;
    if (deck == null) {
      deckId = await _vocabRepo.addDeck(Deck(
        name: unit.title,
        description: unit.description,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        deckType: DeckType.unit,
        parentUnitId: unit.id,
        isSrsEnabled: true,
      ));
    } else {
      deckId = deck.id!;
      // Fix legacy name, ensure parentUnitId is set, enable SRS
      final needsUpdate = deck.parentUnitId == null || deck.name.startsWith('Course: ') || !deck.isSrsEnabled;
      if (needsUpdate) {
        await _vocabRepo.updateDeck(deck.copyWith(
          parentUnitId: unit.id,
          name: unit.title,
          isSrsEnabled: true,
        ));
      }
    }

    // Ensure all vocab in unit deck has repetition >= 1 (so it appears in SRS)
    await _vocabRepo.ensureUnitVocabInSrs(deckId);

    // Always clean up duplicates safely (catches leftovers from race conditions)
    await _vocabRepo.deduplicateUnitDecks(unit.id, deckId);

    // 2. Sync lesson vocab for all unlocked lessons.
    for (int i = 0; i < unit.lessons.length; i++) {
       if (i <= maxUnlockedIndex) {
         await syncLessonVocab(unit.lessons[i], deckId);
       }
    }

    // 3. Auto-add unit kanji to a kanji deck (for Kanji SRS)
    await _syncUnitKanji(unit.id, unit.title);
  }

  Future<void> syncLessonVocab(Lesson lesson, int deckId) async {
    for (var vMap in lesson.vocabularyList) {
      final kanji = vMap['word'] ?? '';
      final kana = vMap['reading'] ?? '';
      bool exists = await _vocabRepo.vocabExists(kanji, kana, deckId);
      if (!exists) {
        await _vocabRepo.addVocab(Vocab(
          kanji: kanji,
          kana: kana,
          translation: vMap['translation'] ?? '',
          deckId: deckId,
          lessonId: lesson.id,
          dueDate: DateTime.now().millisecondsSinceEpoch,
          repetition: 1, // Auto-add to SRS immediately
        ));
      }
    }
  }

  /// Create/update a kanji deck for this unit's kanji and enable SRS
  Future<void> _syncUnitKanji(String unitId, String unitTitle) async {
    final kanjiData = _unitKanjiData[unitId];
    if (kanjiData == null || kanjiData.isEmpty) return;

    final deckName = '$unitTitle - Kanji';
    // Look up by parentUnitId + kanji type first
    Deck? deck = await _vocabRepo.getKanjiDeckByUnitId(unitId);
    // Fallback: legacy name
    deck ??= await _vocabRepo.getDeckByName('Kanji: $unitId');
    deck ??= await _vocabRepo.getDeckByName(deckName);
    int deckId;
    if (deck == null) {
      deckId = await _vocabRepo.addDeck(Deck(
        name: deckName,
        description: 'Kanji aus $unitTitle',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        deckType: DeckType.kanji,
        parentUnitId: unitId,
        isSrsEnabled: true,
      ));
    } else {
      deckId = deck.id!;
      // Fix name and ensure SRS enabled
      final needsUpdate = !deck.isSrsEnabled || deck.parentUnitId == null || deck.name != deckName;
      if (needsUpdate) {
        await _vocabRepo.updateDeck(deck.copyWith(
          isSrsEnabled: true, parentUnitId: unitId, name: deckName,
        ));
      }
    }

    for (final k in kanjiData) {
      final kanji = k['kanji']!;
      final reading = k['reading']!;
      final meaning = k['meaning'] ?? '';
      final exists = await _vocabRepo.vocabExists(kanji, reading, deckId);
      if (!exists) {
        await _vocabRepo.addVocab(Vocab(
          deckId: deckId,
          kanji: kanji,
          kana: reading,
          translation: meaning,
          translationDe: meaning,
          dueDate: DateTime.now().millisecondsSinceEpoch,
          repetition: 1, // Auto-add to Kanji SRS immediately
        ));
      }
    }
  }
}
