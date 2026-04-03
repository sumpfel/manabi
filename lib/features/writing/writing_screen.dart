import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../core/services/progress_service.dart';
import '../../core/data/course_data.dart';
import '../../core/database/vocab_repository.dart';
import '../../core/models/deck.dart';
import '../../core/models/vocab.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/i18n/app_strings.dart';
import 'practice_session_screen.dart';

class CharacterSet {
  final String name;
  final String subtitle;
  final List<String> characters;
  final List<String> readings;
  final int? deckId;
  CharacterSet(this.name, this.subtitle, this.characters, this.readings, {this.deckId});
}

// ── Full Hiragana ──
final hiraganaSets = [
  CharacterSet('Vowels', 'a, i, u, e, o', ['あ', 'い', 'う', 'え', 'お'], ['a', 'i', 'u', 'e', 'o']),
  CharacterSet('K-Group', 'ka, ki, ku, ke, ko', ['か', 'き', 'く', 'け', 'こ'], ['ka', 'ki', 'ku', 'ke', 'ko']),
  CharacterSet('S-Group', 'sa, shi, su, se, so', ['さ', 'し', 'す', 'せ', 'そ'], ['sa', 'shi', 'su', 'se', 'so']),
  CharacterSet('T-Group', 'ta, chi, tsu, te, to', ['た', 'ち', 'つ', 'て', 'と'], ['ta', 'chi', 'tsu', 'te', 'to']),
  CharacterSet('N-Group', 'na, ni, nu, ne, no', ['な', 'に', 'ぬ', 'ね', 'の'], ['na', 'ni', 'nu', 'ne', 'no']),
  CharacterSet('H-Group', 'ha, hi, fu, he, ho', ['は', 'ひ', 'ふ', 'へ', 'ほ'], ['ha', 'hi', 'fu', 'he', 'ho']),
  CharacterSet('M-Group', 'ma, mi, mu, me, mo', ['ま', 'み', 'む', 'め', 'も'], ['ma', 'mi', 'mu', 'me', 'mo']),
  CharacterSet('Y-Group', 'ya, yu, yo', ['や', 'ゆ', 'よ'], ['ya', 'yu', 'yo']),
  CharacterSet('R-Group', 'ra, ri, ru, re, ro', ['ら', 'り', 'る', 'れ', 'ろ'], ['ra', 'ri', 'ru', 're', 'ro']),
  CharacterSet('W-Group + N', 'wa, wo, n', ['わ', 'を', 'ん'], ['wa', 'wo', 'n']),
  CharacterSet('Dakuten G', 'ga, gi, gu, ge, go', ['が', 'ぎ', 'ぐ', 'げ', 'ご'], ['ga', 'gi', 'gu', 'ge', 'go']),
  CharacterSet('Dakuten Z', 'za, ji, zu, ze, zo', ['ざ', 'じ', 'ず', 'ぜ', 'ぞ'], ['za', 'ji', 'zu', 'ze', 'zo']),
  CharacterSet('Dakuten D', 'da, di, du, de, do', ['だ', 'ぢ', 'づ', 'で', 'ど'], ['da', 'di', 'du', 'de', 'do']),
  CharacterSet('Dakuten B', 'ba, bi, bu, be, bo', ['ば', 'び', 'ぶ', 'べ', 'ぼ'], ['ba', 'bi', 'bu', 'be', 'bo']),
  CharacterSet('Handakuten P', 'pa, pi, pu, pe, po', ['ぱ', 'ぴ', 'ぷ', 'ぺ', 'ぽ'], ['pa', 'pi', 'pu', 'pe', 'po']),
  CharacterSet('All Hiragana', 'Complete set',
    ['あ', 'い', 'う', 'え', 'お', 'か', 'き', 'く', 'け', 'こ', 'さ', 'し', 'す', 'せ', 'そ', 'た', 'ち', 'つ', 'て', 'と', 'な', 'に', 'ぬ', 'ね', 'の', 'は', 'ひ', 'ふ', 'へ', 'ほ', 'ま', 'み', 'む', 'め', 'も', 'や', 'ゆ', 'よ', 'ら', 'り', 'る', 'れ', 'ろ', 'わ', 'を', 'ん'],
    ['a', 'i', 'u', 'e', 'o', 'ka', 'ki', 'ku', 'ke', 'ko', 'sa', 'shi', 'su', 'se', 'so', 'ta', 'chi', 'tsu', 'te', 'to', 'na', 'ni', 'nu', 'ne', 'no', 'ha', 'hi', 'fu', 'he', 'ho', 'ma', 'mi', 'mu', 'me', 'mo', 'ya', 'yu', 'yo', 'ra', 'ri', 'ru', 're', 'ro', 'wa', 'wo', 'n'],
  ),
];

// ── Full Katakana ──
final katakanaSets = [
  CharacterSet('Vowels', 'a, i, u, e, o', ['ア', 'イ', 'ウ', 'エ', 'オ'], ['a', 'i', 'u', 'e', 'o']),
  CharacterSet('K-Group', 'ka, ki, ku, ke, ko', ['カ', 'キ', 'ク', 'ケ', 'コ'], ['ka', 'ki', 'ku', 'ke', 'ko']),
  CharacterSet('S-Group', 'sa, shi, su, se, so', ['サ', 'シ', 'ス', 'セ', 'ソ'], ['sa', 'shi', 'su', 'se', 'so']),
  CharacterSet('T-Group', 'ta, chi, tsu, te, to', ['タ', 'チ', 'ツ', 'テ', 'ト'], ['ta', 'chi', 'tsu', 'te', 'to']),
  CharacterSet('N-Group', 'na, ni, nu, ne, no', ['ナ', 'ニ', 'ヌ', 'ネ', 'ノ'], ['na', 'ni', 'nu', 'ne', 'no']),
  CharacterSet('H-Group', 'ha, hi, fu, he, ho', ['ハ', 'ヒ', 'フ', 'ヘ', 'ホ'], ['ha', 'hi', 'fu', 'he', 'ho']),
  CharacterSet('M-Group', 'ma, mi, mu, me, mo', ['マ', 'ミ', 'ム', 'メ', 'モ'], ['ma', 'mi', 'mu', 'me', 'mo']),
  CharacterSet('Y-Group', 'ya, yu, yo', ['ヤ', 'ユ', 'ヨ'], ['ya', 'yu', 'yo']),
  CharacterSet('R-Group', 'ra, ri, ru, re, ro', ['ラ', 'リ', 'ル', 'レ', 'ロ'], ['ra', 'ri', 'ru', 're', 'ro']),
  CharacterSet('W-Group + N', 'wa, wo, n', ['ワ', 'ヲ', 'ン'], ['wa', 'wo', 'n']),
  CharacterSet('Dakuten G', 'ga, gi, gu, ge, go', ['ガ', 'ギ', 'グ', 'ゲ', 'ゴ'], ['ga', 'gi', 'gu', 'ge', 'go']),
  CharacterSet('Dakuten Z', 'za, ji, zu, ze, zo', ['ザ', 'ジ', 'ズ', 'ゼ', 'ゾ'], ['za', 'ji', 'zu', 'ze', 'zo']),
  CharacterSet('Dakuten D', 'da, di, du, de, do', ['ダ', 'ヂ', 'ヅ', 'デ', 'ド'], ['da', 'di', 'du', 'de', 'do']),
  CharacterSet('Dakuten B', 'ba, bi, bu, be, bo', ['バ', 'ビ', 'ブ', 'ベ', 'ボ'], ['ba', 'bi', 'bu', 'be', 'bo']),
  CharacterSet('Handakuten P', 'pa, pi, pu, pe, po', ['パ', 'ピ', 'プ', 'ペ', 'ポ'], ['pa', 'pi', 'pu', 'pe', 'po']),
  CharacterSet('All Katakana', 'Complete set',
    ['ア', 'イ', 'ウ', 'エ', 'オ', 'カ', 'キ', 'ク', 'ケ', 'コ', 'サ', 'シ', 'ス', 'セ', 'ソ', 'タ', 'チ', 'ツ', 'テ', 'ト', 'ナ', 'ニ', 'ヌ', 'ネ', 'ノ', 'ハ', 'ヒ', 'フ', 'ヘ', 'ホ', 'マ', 'ミ', 'ム', 'メ', 'モ', 'ヤ', 'ユ', 'ヨ', 'ラ', 'リ', 'ル', 'レ', 'ロ', 'ワ', 'ヲ', 'ン'],
    ['a', 'i', 'u', 'e', 'o', 'ka', 'ki', 'ku', 'ke', 'ko', 'sa', 'shi', 'su', 'se', 'so', 'ta', 'chi', 'tsu', 'te', 'to', 'na', 'ni', 'nu', 'ne', 'no', 'ha', 'hi', 'fu', 'he', 'ho', 'ma', 'mi', 'mu', 'me', 'mo', 'ya', 'yu', 'yo', 'ra', 'ri', 'ru', 're', 'ro', 'wa', 'wo', 'n'],
  ),
];

// ── Unit-Linked Kanji (keyed by unit_id) ──
final Map<String, List<CharacterSet>> unitKanjiSets = {
  'unit_1': [
    CharacterSet('Unit 1 Kanji', 'People & Things', ['私', '友', '先', '生', '学', '本', '水', '猫', '犬', '何', '誰', '人', '家', '車'], ['watashi', 'tomo', 'sen/saki', 'sei/nama', 'gaku', 'hon', 'mizu', 'neko', 'inu', 'nani', 'dare', 'hito', 'ie', 'kuruma']),
  ],
  'unit_2': [
    CharacterSet('Unit 2 Kanji', 'Daily Life', ['朝', '昼', '夜', '駅', '映', '画', '音', '楽', '公', '園', '手', '紙'], ['asa', 'hiru', 'yoru', 'eki', 'ei', 'ga', 'on/oto', 'gaku/tanoshi', 'kou/ooyake', 'en/sono', 'te/shu', 'kami/shi']),
  ],
  'unit_3': [
    CharacterSet('Unit 3 Kanji', 'Routine Verbs', ['出', '起', '寝', '見', '食', '飲'], ['de(ru)/shutsu', 'o(kiru)/ki', 'ne(ru)/shin', 'mi(ru)/ken', 'ta(beru)/shoku', 'no(mu)/in']),
  ],
};

// ── Preset Kanji (always available) ──
final presetKanjiSets = [
  CharacterSet('Numbers', '1 to 10', ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'], ['ichi', 'ni', 'san', 'yon', 'go', 'roku', 'nana', 'hachi', 'kyuu', 'juu']),
  CharacterSet('Days & Elements', 'Sun, Moon, Fire...', ['日', '月', '火', '水', '木', '金', '土'], ['nichi', 'getsu', 'ka', 'sui', 'moku', 'kin', 'do']),
  CharacterSet('Basic Nouns', 'Person, Tree...', ['人', '木', '本', '口', '目', '手', '足', '耳'], ['hito', 'ki', 'hon', 'kuchi', 'me', 'te', 'ashi', 'mimi']),
  CharacterSet('Actions', 'Enter, Exit...', ['入', '出', '上', '下', '中', '大', '小'], ['iri/nyuu', 'de/shutsu', 'ue/jou', 'shita/ka', 'naka/chuu', 'oo/dai', 'chiisa/shou']),
  CharacterSet('Colors', 'Red, Blue, White...', ['赤', '青', '白', '黒', '黄', '緑'], ['aka', 'ao', 'shiro', 'kuro', 'ki', 'midori']),
  CharacterSet('Animals', 'Dog, Cat, Bird...', ['犬', '猫', '鳥', '魚', '馬', '虫', '牛'], ['inu', 'neko', 'tori', 'sakana', 'uma', 'mushi', 'ushi']),
  CharacterSet('Weather', 'Rain, Snow, Wind...', ['雨', '雪', '風', '雲', '天', '空', '花'], ['ame', 'yuki', 'kaze', 'kumo', 'ten', 'sora', 'hana']),
  CharacterSet('Body Parts', 'Head, Hand...', ['頭', '手', '足', '目', '耳', '口', '心', '体'], ['atama', 'te', 'ashi', 'me', 'mimi', 'kuchi', 'kokoro', 'karada']),
  CharacterSet('Time', 'Year, Month, Day...', ['年', '月', '日', '時', '分', '今', '前', '後'], ['nen/toshi', 'gatsu/tsuki', 'nichi/hi', 'ji/toki', 'fun/bun', 'ima/kon', 'mae/zen', 'ato/go']),
  CharacterSet('Directions', 'North, South...', ['北', '南', '東', '西', '左', '右'], ['kita', 'minami', 'higashi', 'nishi', 'hidari', 'migi']),
];

int _savedWritingTabIndex = 0;

class WritingScreen extends ConsumerStatefulWidget {
  const WritingScreen({super.key});

  @override
  ConsumerState<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends ConsumerState<WritingScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: (_savedWritingTabIndex < 3) ? _savedWritingTabIndex : 0);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _savedWritingTabIndex = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final s = AppStrings(settings.appLanguage);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.writingPractice),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Theme.of(context).brightness == Brightness.dark ? Colors.white54 : Colors.black54,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(50),
            color: Theme.of(context).primaryColor,
          ),
          splashBorderRadius: BorderRadius.circular(50),
          tabs: [
            Tab(text: s.hiragana),
            Tab(text: s.katakana),
            Tab(text: s.kanji),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGridList(context, hiraganaSets, Colors.pink),
          _buildGridList(context, katakanaSets, Colors.blue),
          const _KanjiSubTabView(),
        ],
      ),
    );
  }

  Widget _buildGridList(BuildContext context, List<CharacterSet> sets, MaterialColor baseColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sets.length,
      itemBuilder: (context, index) => buildCharCard(context, sets[index], baseColor),
    );
  }
}

Widget buildCharCard(BuildContext context, CharacterSet set, MaterialColor baseColor, {bool locked = false}) {
  return Card(
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 4,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: locked ? () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schließe diese Lektion ab, um die Kanji freizuschalten!')),
        );
      } : () {
        if (set.deckId != null) {
           Navigator.pushNamed(context, '/vocab_detail', arguments: set.deckId!);
        } else {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => PracticeSessionScreen(characterSet: set),
          ));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              locked ? Colors.grey.shade400 : baseColor.shade300,
              locked ? Colors.grey.shade700 : baseColor.shade700,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(set.name, style: TextStyle(color: locked ? Colors.white54 : Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                if (locked) const Icon(Icons.lock, color: Colors.white54, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(set.subtitle, style: TextStyle(color: locked ? Colors.white38 : Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: set.characters.map((c) => Text(
                c, style: TextStyle(color: locked ? Colors.white54 : Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
              )).toList(),
            ),
          ],
        ),
      ),
    ),
  );
}

class _KanjiSubTabView extends ConsumerStatefulWidget {
  const _KanjiSubTabView();
  @override
  ConsumerState<_KanjiSubTabView> createState() => _KanjiSubTabViewState();
}

class _KanjiSubTabViewState extends ConsumerState<_KanjiSubTabView> with SingleTickerProviderStateMixin {
  late TabController _kanjiTabController;
  bool _isLoading = true;
  List<CharacterSet> _vocabDeckKanjiSets = [];
  List<Deck> _kanjiDecks = [];

  @override
  void initState() {
    super.initState();
    _kanjiTabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _kanjiTabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final vocabRepo = ref.read(vocabRepositoryProvider);
    final allDecks = await vocabRepo.getDecks();

    final userVocabDecks = allDecks.where((d) => d.deckType == DeckType.custom || d.deckType == DeckType.manga || (d.deckType == DeckType.unit && d.isSrsEnabled)).toList();
    final kanjiRegex = RegExp(r'[\u4E00-\u9FAF]');
    
    List<CharacterSet> vocabKanjiSets = [];
    for (var deck in userVocabDecks) {
      final vocabList = await vocabRepo.getVocabForDeck(deck.id!);
      final kanjiChars = <String>[];
      final readings = <String>[];
      for (var vocab in vocabList) {
        final text = vocab.kanji ?? vocab.kana;
        for (var m in kanjiRegex.allMatches(text)) {
          final char = m.group(0)!;
          if (!kanjiChars.contains(char)) {
            kanjiChars.add(char);
            readings.add(''); // Blank reading extracted so it fetches AI later
          }
        }
      }
      if (kanjiChars.isNotEmpty) {
        vocabKanjiSets.add(CharacterSet(deck.name, '${kanjiChars.length} Kanji', kanjiChars, readings, deckId: deck.id!));
      }
    }

    final userKanjiDecks = allDecks.where((d) => d.deckType == DeckType.kanji && d.parentDeckId == null && d.parentUnitId == null).toList();

    if (mounted) {
      setState(() {
        _vocabDeckKanjiSets = vocabKanjiSets;
        _kanjiDecks = userKanjiDecks;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        TabBar(
          controller: _kanjiTabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Lektionen'),
            Tab(text: 'Presets'),
            Tab(text: 'Eigene'),
            Tab(text: 'Extrahierte Kanji'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _kanjiTabController,
            children: [
              _buildUnitKanjiTab(context),
              _buildPresetsTab(context),
              _buildEigeneTab(context),
              _buildVocabKanjiTab(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnitKanjiTab(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final units = CourseData.units;
    final entries = <MapEntry<String, List<CharacterSet>>>[];
    for (var unit in units) {
      if (unitKanjiSets.containsKey(unit.id)) {
        entries.add(MapEntry(unit.id, unitKanjiSets[unit.id]!));
      }
    }
    if (entries.isEmpty) {
      return const Center(child: Text('Noch keine Lektions-Kanji verfügbar.', style: TextStyle(color: Colors.grey)));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: entries.map((entry) {
        final unit = units.firstWhere((u) => u.id == entry.key);
        final unitIndex = units.indexOf(unit);
        final isUnlocked = unitIndex == 0 || (unitIndex > 0 && units[unitIndex - 1].lessons.isNotEmpty && progress.isCompleted(units[unitIndex - 1].lessons.last.id));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(isUnlocked ? Icons.check_circle : Icons.lock_outline, color: isUnlocked ? Colors.green : Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(unit.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            ...entry.value.map((set) => buildCharCard(context, set, Colors.teal, locked: !isUnlocked)),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPresetsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: presetKanjiSets.map((set) => buildCharCard(context, set, Colors.teal)).toList(),
    );
  }

  Widget _buildEigeneTab(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return Stack(
      children: [
        _kanjiDecks.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.draw, size: 48, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                    const SizedBox(height: 12),
                    Text('Noch keine eigenen Kanji-Decks', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 120),
                itemCount: _kanjiDecks.length,
                itemBuilder: (context, index) {
                  final deck = _kanjiDecks[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.draw, color: Colors.purple),
                      ),
                      title: Text(deck.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(deck.description ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(deck.isSrsEnabled ? Icons.notifications_active : Icons.notifications_off_outlined, color: deck.isSrsEnabled ? Colors.green : Colors.grey),
                            tooltip: deck.isSrsEnabled ? 'Aus Kanji-SRS entfernen' : 'Zu Kanji-SRS hinzufügen',
                            onPressed: () async {
                              final repo = ref.read(vocabRepositoryProvider);
                              await repo.updateDeck(deck.copyWith(isSrsEnabled: !deck.isSrsEnabled));
                              _loadData();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Deck löschen?'),
                                  content: Text('Möchtest du "${deck.name}" wirklich löschen?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final repo = ref.read(vocabRepositoryProvider);
                                await repo.deleteDeck(deck.id!);
                                _loadData();
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () async {
                        final repo = ref.read(vocabRepositoryProvider);
                        final vocabList = await repo.getVocabForDeck(deck.id!);
                        final kanjiRegex = RegExp(r'[\u4E00-\u9FAF]');
                        final kanjiChars = <String>[];
                        final readings = <String>[];
                        for (var v in vocabList) {
                          final text = v.kanji ?? v.kana;
                          for (var m in kanjiRegex.allMatches(text)) {
                            final c = m.group(0)!;
                            if (!kanjiChars.contains(c)) {
                              kanjiChars.add(c);
                              readings.add(v.kana);
                            }
                          }
                        }
                        if (kanjiChars.isEmpty) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keine Kanji in diesem Deck')));
                          return;
                        }
                        if (context.mounted) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => PracticeSessionScreen(characterSet: CharacterSet(deck.name, '${kanjiChars.length} Kanji', kanjiChars, readings, deckId: deck.id)),
                          ));
                        }
                      },
                    ),
                  );
                },
              ),
        Positioned(
          bottom: 16, left: 16, right: 16,
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _createNewKanjiDeck(),
                  icon: const Icon(Icons.add),
                  label: const Text('Neues Deck'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: settings.hasAnyAiKey ? () => _createAiKanjiDeck() : null,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('KI-Kanji'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVocabKanjiTab(BuildContext context) {
    if (_vocabDeckKanjiSets.isEmpty) {
      return const Center(child: Text('Noch keine Kanji in deinen Vokabel-Decks.', style: TextStyle(color: Colors.grey)));
    }
    final vocabRepo = ref.read(vocabRepositoryProvider);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vocabDeckKanjiSets.length,
      itemBuilder: (context, index) {
        final set = _vocabDeckKanjiSets[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => PracticeSessionScreen(characterSet: set),
              ));
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade300, Colors.indigo.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(set.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                      TextButton.icon(
                        onPressed: () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (ctx) => const Center(child: CircularProgressIndicator()),
                          );
                          await _addVocabKanjiToSrs(set, vocabRepo);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${set.characters.length} Kanji zu Kanji-SRS hinzugefügt'), backgroundColor: Colors.green),
                            );
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white70, size: 18),
                        label: const Text('Zu SRS', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    ],
                  ),
                  Text(set.subtitle, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 4,
                    children: set.characters.take(10).map((c) => Text(c, style: const TextStyle(color: Colors.white, fontSize: 22))).toList(),
                  ),
                  if (set.characters.length > 10)
                    Text('  ...+${set.characters.length - 10}', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addVocabKanjiToSrs(CharacterSet set, VocabRepository vocabRepo) async {
    final aiService = ref.read(aiServiceProvider);
    Map<String, String> kanjiMeanings = {};
    if (ref.read(settingsProvider).hasAnyAiKey && set.characters.isNotEmpty) {
      try {
        final prompt = 'Translate the following isolated Japanese Kanji characters to basic German. Reply ONLY with a valid JSON format: {"kanji1": "German meaning", "kanji2": "German meaning"}. No markdown formatting.\nKanji list: ${set.characters.join(',')}';
        final result = await aiService.queryAi(prompt: prompt);
        final cleanJson = result.replaceAll(RegExp(r'```(?:json)?|```'), '').trim();
        final Map<String, dynamic> decoded = jsonDecode(cleanJson);
        for (final k in decoded.keys) {
          kanjiMeanings[k] = decoded[k].toString();
        }
      } catch (e) {
        debugPrint('Failed to fetch AI kanji translations: $e');
      }
    }

    final deckName = '${set.name} - Kanji';
    Deck? existing = await vocabRepo.getDeckByName(deckName);
    int deckId;
    if (existing == null) {
      deckId = await vocabRepo.addDeck(Deck(
        name: deckName,
        description: 'Kanji aus ${set.name}',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        deckType: DeckType.kanji,
        isSrsEnabled: true,
      ));
    } else {
      deckId = existing.id!;
      if (!existing.isSrsEnabled) {
        await vocabRepo.updateDeck(existing.copyWith(isSrsEnabled: true));
      }
    }
    
    for (int i = 0; i < set.characters.length; i++) {
      final kanji = set.characters[i];
      final reading = i < set.readings.length ? set.readings[i] : '';
      final translation = kanjiMeanings[kanji] ?? '';
      final exists = await vocabRepo.vocabExists(kanji, reading, deckId);
      if (!exists) {
        await vocabRepo.addVocab(Vocab(
          deckId: deckId,
          kanji: kanji,
          kana: reading,
          translation: translation,
          translationDe: translation,
          dueDate: DateTime.now().millisecondsSinceEpoch,
          repetition: 1,
        ));
      }
    }
  }

  void _createNewKanjiDeck() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Neues Kanji-Deck'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name'), autofocus: true),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Beschreibung (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty) {
                final repo = ref.read(vocabRepositoryProvider);
                await repo.addDeck(Deck(
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                  deckType: DeckType.kanji,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
                _loadData();
              }
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }

  void _createAiKanjiDeck() {
    final themeCtrl = TextEditingController();
    bool isLoading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('KI Kanji-Deck', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Beschreibe ein Thema und die KI erstellt Kanji dazu.', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: themeCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'z.B. "Natur", "Zahlen bis 100", "JLPT N4 Kanji"...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.auto_awesome),
                ),
              ),
              if (error != null)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[700], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: isLoading ? null : () async {
                    if (themeCtrl.text.trim().isEmpty) return;
                    setSheetState(() { isLoading = true; error = null; });
                    try {
                      final ai = ref.read(aiServiceProvider);
                      final repo = ref.read(vocabRepositoryProvider);
                      final prompt = 'Generate a list of 10-15 Japanese kanji related to the topic: "${themeCtrl.text}". Reply ONLY with a valid JSON array of objects with keys "kanji", "reading", "translation". No markdown formatting.';
                      final res = await ai.queryAi(prompt: prompt);
                      final clean = res.replaceAll(RegExp(r'```[a-z]*|```'), '').trim();
                      final List<dynamic> parsed = jsonDecode(clean);
                      
                      final deckId = await repo.addDeck(Deck(
                        name: 'KI: ${themeCtrl.text.trim()}',
                        description: 'Von KI generiert',
                        createdAt: DateTime.now().millisecondsSinceEpoch,
                        deckType: DeckType.kanji,
                      ));
                      
                      for (final k in parsed) {
                        await repo.addVocab(Vocab(
                          deckId: deckId,
                          kanji: k['kanji']?.toString() ?? '',
                          kana: k['reading']?.toString() ?? '',
                          translation: k['translation']?.toString() ?? '',
                          dueDate: DateTime.now().millisecondsSinceEpoch,
                        ));
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadData();
                    } catch (e) {
                      setSheetState(() { isLoading = false; error = 'Fehler bei der Generierung. Versuche es genauer zu formulieren.'; });
                    }
                  },
                  child: isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                   : const Text('Generieren', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}