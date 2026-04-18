import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Hardcoded production domain — switch when you deploy to a server.
const kProductionBackendUrl = 'https://jmanga-api.example.com';

class AppSettings {
  final bool showRomaji;
  final double ttsSpeed;
  final int themeColorValue;
  final String deepLKey;
  final bool showVocabImages;
  final String backendUrl;
  final String motherTongue; // Single field: 'de' or 'en' — drives UI + translations
  final bool speakingExercisesEnabled;
  final bool showDashboardWidgets;
  final int themeModeIndex; // 0=system, 1=light, 2=dark
  final String aiLanguageLevel; // 'A1', 'A2', 'B1', 'B2', 'C1'
  final bool restrictToKnownVocab;
  final int maxNewWordsPerResponse;
  // AI Color settings
  final String colorParticles;
  final String colorVerbs;
  final String colorNouns;
  final String colorAdjectives;
  final String colorAdverbs;
  // AI Deck routing
  final String aiDeckRouting; // 'per_chat', 'per_n_words', 'target_deck'
  final int aiDeckRoutingCount;
  final int? aiTargetDeckId;
  // AI display preferences
  final String? ollamaLocalUrl;
  final bool showRomajiInChat;
  final bool showHiraganaInChat;
  final bool colorGermanSentences;
  final String aiExplanationLanguage; // 'de' or 'ja'
  // AI model selection
  final String selectedOllamaModel;
  final String selectedIcon; // 'MainActivityDefault', 'MainActivityManga', 'MainActivityKanji'
  // Direct AI API key (Gemini etc.) for offline use without backend
  final String geminiApiKey;
  // AI provider selection: 'gemini', 'openai', 'anthropic'
  final String aiProvider;
  final String openaiApiKey;
  final String anthropicApiKey;
  final String aiModel; // e.g. 'gemini-2.0-flash', 'gpt-4o-mini', 'claude-sonnet-4-5-20250514'
  final bool showColorGrammar; // Global toggle for AI grammar coloring
  final bool showFurigana; // Local toggle for showing Hiragana over Kanji
  // SRS settings
  final bool autoAddMangaSrs; // Automatically add manga vocab decks to SRS
  final String srsMode; // 'shared' = one SRS across all methods, 'individual' = per method

  AppSettings({
    this.showRomaji = false, 
    this.ttsSpeed = 0.5,
    this.themeColorValue = 0xFF2196F3,
    this.deepLKey = '',
    this.showVocabImages = true,
    this.backendUrl = '',
    this.motherTongue = 'de',
    this.speakingExercisesEnabled = true,
    this.showDashboardWidgets = false,
    this.themeModeIndex = 0,
    this.aiLanguageLevel = 'A1',
    this.restrictToKnownVocab = false,
    this.maxNewWordsPerResponse = 2,
    this.colorParticles = '#4FC3F7',
    this.colorVerbs = '#FF8A65',
    this.colorNouns = '#81C784',
    this.colorAdjectives = '#CE93D8',
    this.colorAdverbs = '#FFD54F',
    this.aiDeckRouting = 'per_chat',
    this.aiDeckRoutingCount = 20,
    this.aiTargetDeckId,
    this.showRomajiInChat = true,
    this.showHiraganaInChat = true,
    this.colorGermanSentences = true,
    this.aiExplanationLanguage = 'de',
    this.ollamaLocalUrl,
    this.showFurigana = true,
    this.showColorGrammar = true,
    this.selectedOllamaModel = 'llama3.2:3b',
    this.selectedIcon = 'MainActivityDefault',
    this.geminiApiKey = '',
    this.aiProvider = 'gemini',
    this.openaiApiKey = '',
    this.anthropicApiKey = '',
    this.aiModel = 'gemini-2.0-flash',
    this.autoAddMangaSrs = false,
    this.srsMode = 'shared',
  });

  bool get hasBackend => backendUrl.isNotEmpty;
  bool get isGerman => motherTongue == 'de';
  bool get hasGeminiKey => geminiApiKey.isNotEmpty;
  bool get hasOpenaiKey => openaiApiKey.isNotEmpty;
  bool get hasAnthropicKey => anthropicApiKey.isNotEmpty;
  bool get hasAnyAiKey => hasGeminiKey || hasOpenaiKey || hasAnthropicKey;
  String get activeApiKey {
    switch (aiProvider) {
      case 'openai': return openaiApiKey;
      case 'anthropic': return anthropicApiKey;
      default: return geminiApiKey;
    }
  }
  
  String getEffectiveLanguageLevel() => aiLanguageLevel;
  String get appLanguage => motherTongue;
  String get contentLanguage => motherTongue;

  String get effectiveBackendUrl {
    if (backendUrl.isEmpty) return '';
    if (backendUrl.startsWith('http://') || backendUrl.startsWith('https://')) return backendUrl;
    return 'http://$backendUrl';
  }

  AppSettings copyWith({
    bool? showRomaji, 
    double? ttsSpeed, 
    int? themeColorValue, 
    String? deepLKey, 
    bool? showVocabImages, 
    String? backendUrl, 
    String? motherTongue,
    bool? speakingExercisesEnabled, 
    bool? showDashboardWidgets, 
    int? themeModeIndex,
    String? aiLanguageLevel,
    bool? restrictToKnownVocab,
    int? maxNewWordsPerResponse,
    String? colorParticles,
    String? colorVerbs,
    String? colorNouns,
    String? colorAdjectives,
    String? colorAdverbs,
    String? aiDeckRouting,
    int? aiDeckRoutingCount,
    int? aiTargetDeckId,
    bool? showRomajiInChat,
    bool? showHiraganaInChat,
    bool? colorGermanSentences,
    String? aiExplanationLanguage,
    String? ollamaLocalUrl,
    bool? showFurigana,
    bool? showColorGrammar,
    String? selectedOllamaModel,
    String? selectedIcon,
    String? geminiApiKey,
    String? aiProvider,
    String? openaiApiKey,
    String? anthropicApiKey,
    String? aiModel,
    bool? autoAddMangaSrs,
    String? srsMode,
  }) {
    return AppSettings(
      showRomaji: showRomaji ?? this.showRomaji,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      themeColorValue: themeColorValue ?? this.themeColorValue,
      deepLKey: deepLKey ?? this.deepLKey,
      showVocabImages: showVocabImages ?? this.showVocabImages,
      backendUrl: backendUrl ?? this.backendUrl,
      motherTongue: motherTongue ?? this.motherTongue,
      speakingExercisesEnabled: speakingExercisesEnabled ?? this.speakingExercisesEnabled,
      showDashboardWidgets: showDashboardWidgets ?? this.showDashboardWidgets,
      themeModeIndex: themeModeIndex ?? this.themeModeIndex,
      aiLanguageLevel: aiLanguageLevel ?? this.aiLanguageLevel,
      restrictToKnownVocab: restrictToKnownVocab ?? this.restrictToKnownVocab,
      maxNewWordsPerResponse: maxNewWordsPerResponse ?? this.maxNewWordsPerResponse,
      colorParticles: colorParticles ?? this.colorParticles,
      colorVerbs: colorVerbs ?? this.colorVerbs,
      colorNouns: colorNouns ?? this.colorNouns,
      colorAdjectives: colorAdjectives ?? this.colorAdjectives,
      colorAdverbs: colorAdverbs ?? this.colorAdverbs,
      aiDeckRouting: aiDeckRouting ?? this.aiDeckRouting,
      aiDeckRoutingCount: aiDeckRoutingCount ?? this.aiDeckRoutingCount,
      aiTargetDeckId: aiTargetDeckId ?? this.aiTargetDeckId,
      showRomajiInChat: showRomajiInChat ?? this.showRomajiInChat,
      showHiraganaInChat: showHiraganaInChat ?? this.showHiraganaInChat,
      colorGermanSentences: colorGermanSentences ?? this.colorGermanSentences,
      aiExplanationLanguage: aiExplanationLanguage ?? this.aiExplanationLanguage,
      ollamaLocalUrl: ollamaLocalUrl ?? this.ollamaLocalUrl,
      showFurigana: showFurigana ?? this.showFurigana,
      showColorGrammar: showColorGrammar ?? this.showColorGrammar,
      selectedOllamaModel: selectedOllamaModel ?? this.selectedOllamaModel,
      selectedIcon: selectedIcon ?? this.selectedIcon,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      aiProvider: aiProvider ?? this.aiProvider,
      openaiApiKey: openaiApiKey ?? this.openaiApiKey,
      anthropicApiKey: anthropicApiKey ?? this.anthropicApiKey,
      aiModel: aiModel ?? this.aiModel,
      autoAddMangaSrs: autoAddMangaSrs ?? this.autoAddMangaSrs,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _loadSettings();
    return AppSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Migrate: if old appLanguage exists but no motherTongue, use appLanguage
    String motherTongue = prefs.getString('motherTongue') ?? 
                          prefs.getString('appLanguage') ?? 'de';
    
    state = AppSettings(
      showRomaji: prefs.getBool('showRomaji') ?? false,
      ttsSpeed: prefs.getDouble('ttsSpeed') ?? 0.5,
      themeColorValue: prefs.getInt('themeColorValue') ?? 0xFF2196F3,
      deepLKey: prefs.getString('deepLKey') ?? '',
      showVocabImages: prefs.getBool('showVocabImages') ?? true,
      backendUrl: prefs.getString('backendUrl') ?? '',
      motherTongue: motherTongue,
      speakingExercisesEnabled: prefs.getBool('speakingExercisesEnabled') ?? true,
      showDashboardWidgets: prefs.getBool('showDashboardWidgets') ?? false,
      themeModeIndex: prefs.getInt('themeModeIndex') ?? 0,
      aiLanguageLevel: prefs.getString('aiLanguageLevel') ?? 'A1',
      restrictToKnownVocab: prefs.getBool('restrictToKnownVocab') ?? false,
      maxNewWordsPerResponse: prefs.getInt('maxNewWordsPerResponse') ?? 2,
      colorParticles: prefs.getString('colorParticles') ?? '#4FC3F7',
      colorVerbs: prefs.getString('colorVerbs') ?? '#FF8A65',
      colorNouns: prefs.getString('colorNouns') ?? '#81C784',
      colorAdjectives: prefs.getString('colorAdjectives') ?? '#CE93D8',
      colorAdverbs: prefs.getString('colorAdverbs') ?? '#FFD54F',
      aiDeckRouting: prefs.getString('aiDeckRouting') ?? 'per_chat',
      aiDeckRoutingCount: prefs.getInt('aiDeckRoutingCount') ?? 20,
      aiTargetDeckId: prefs.getInt('aiTargetDeckId'),
      showRomajiInChat: prefs.getBool('showRomajiInChat') ?? true,
      showHiraganaInChat: prefs.getBool('showHiraganaInChat') ?? true,
      colorGermanSentences: prefs.getBool('colorGermanSentences') ?? true,
      aiExplanationLanguage: prefs.getString('aiExplanationLanguage') ?? 'de',
      ollamaLocalUrl: prefs.getString('ollamaLocalUrl') ?? 'http://localhost:11434',
      showColorGrammar: prefs.getBool('showColorGrammar') ?? true,
      selectedOllamaModel: prefs.getString('selectedOllamaModel') ?? 'llama3.2:3b',
      selectedIcon: prefs.getString('selectedIcon') ?? 'MainActivityDefault',
      geminiApiKey: prefs.getString('geminiApiKey') ?? '',
      aiProvider: prefs.getString('aiProvider') ?? 'gemini',
      openaiApiKey: prefs.getString('openaiApiKey') ?? '',
      anthropicApiKey: prefs.getString('anthropicApiKey') ?? '',
      aiModel: prefs.getString('aiModel') ?? 'gemini-2.0-flash',
      autoAddMangaSrs: prefs.getBool('autoAddMangaSrs') ?? false,
      srsMode: prefs.getString('srsMode') ?? 'shared',
    );
  }

  Future<void> toggleRomaji(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showRomaji', value);
    state = state.copyWith(showRomaji: value);
  }

  Future<void> updateTtsSpeed(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('ttsSpeed', speed);
    state = state.copyWith(ttsSpeed: speed);
  }

  Future<void> updateThemeColor(int colorValue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColorValue', colorValue);
    state = state.copyWith(themeColorValue: colorValue);
  }

  Future<void> updateDeepLKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deepLKey', key);
    state = state.copyWith(deepLKey: key);
  }

  Future<void> toggleVocabImages(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showVocabImages', value);
    state = state.copyWith(showVocabImages: value);
  }

  Future<void> updateBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backendUrl', url.trim());
    state = state.copyWith(backendUrl: url.trim());
  }

  /// Single mother tongue setter — replaces both appLanguage and contentLanguage
  Future<void> updateMotherTongue(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('motherTongue', lang);
    // Also update legacy keys for backward compatibility
    await prefs.setString('appLanguage', lang);
    await prefs.setString('contentLanguage', lang);
    state = state.copyWith(motherTongue: lang);
  }

  /// Legacy - redirects to updateMotherTongue
  Future<void> updateLanguage(String lang) async => updateMotherTongue(lang);
  Future<void> updateContentLanguage(String lang) async => updateMotherTongue(lang);

  Future<void> toggleSpeakingExercises(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('speakingExercisesEnabled', value);
    state = state.copyWith(speakingExercisesEnabled: value);
  }

  Future<void> toggleDashboardWidgets(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showDashboardWidgets', value);
    state = state.copyWith(showDashboardWidgets: value);
  }

  Future<void> updateThemeMode(int modeIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeModeIndex', modeIndex);
    state = state.copyWith(themeModeIndex: modeIndex);
  }

  Future<void> updateAiLevel(String level) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aiLanguageLevel', level);
    state = state.copyWith(aiLanguageLevel: level);
  }

  Future<void> toggleRestrictVocab(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('restrictToKnownVocab', value);
    state = state.copyWith(restrictToKnownVocab: value);
  }

  Future<void> updateMaxNewWords(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('maxNewWordsPerResponse', value);
    state = state.copyWith(maxNewWordsPerResponse: value);
  }

  // AI Color settings
  Future<void> updateColorParticles(String color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('colorParticles', color);
    state = state.copyWith(colorParticles: color);
  }

  Future<void> updateColorVerbs(String color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('colorVerbs', color);
    state = state.copyWith(colorVerbs: color);
  }

  Future<void> updateColorNouns(String color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('colorNouns', color);
    state = state.copyWith(colorNouns: color);
  }

  Future<void> updateColorAdjectives(String color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('colorAdjectives', color);
    state = state.copyWith(colorAdjectives: color);
  }

  Future<void> updateColorAdverbs(String color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('colorAdverbs', color);
    state = state.copyWith(colorAdverbs: color);
  }

  Future<void> updateAiDeckRouting(String routing) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aiDeckRouting', routing);
    state = state.copyWith(aiDeckRouting: routing);
  }

  Future<void> updateAiDeckRoutingCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('aiDeckRoutingCount', count);
    state = state.copyWith(aiDeckRoutingCount: count);
  }

  Future<void> updateAiTargetDeckId(int? deckId) async {
    final prefs = await SharedPreferences.getInstance();
    if (deckId != null) {
      await prefs.setInt('aiTargetDeckId', deckId);
    } else {
      await prefs.remove('aiTargetDeckId');
    }
    state = state.copyWith(aiTargetDeckId: deckId);
  }

  Future<void> toggleShowRomajiInChat(bool value) async {
    state = state.copyWith(showRomajiInChat: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showRomajiInChat', value);
  }

  Future<void> toggleShowHiraganaInChat(bool value) async {
    state = state.copyWith(showHiraganaInChat: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showHiraganaInChat', value);
  }

  Future<void> toggleColorGerman(bool value) async {
    state = state.copyWith(colorGermanSentences: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('colorGermanSentences', value);
  }

  Future<void> updateOllamaUrl(String url) async {
    state = state.copyWith(ollamaLocalUrl: url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ollamaLocalUrl', url);
  }

  Future<void> toggleShowColorGrammar(bool value) async {
    state = state.copyWith(showColorGrammar: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showColorGrammar', value);
  }

  Future<void> toggleShowFurigana(bool value) async {
    state = state.copyWith(showFurigana: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showFurigana', value);
  }

  Future<void> updateAiExplanationLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aiExplanationLanguage', lang);
    state = state.copyWith(aiExplanationLanguage: lang);
  }

  Future<void> updateOllamaModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedOllamaModel', model);
    state = state.copyWith(selectedOllamaModel: model);
  }

  Future<void> updateSelectedIcon(String iconName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedIcon', iconName);
    state = state.copyWith(selectedIcon: iconName);
  }

  Future<void> updateGeminiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('geminiApiKey', key.trim());
    state = state.copyWith(geminiApiKey: key.trim());
  }

  Future<void> updateAiProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aiProvider', provider);
    state = state.copyWith(aiProvider: provider);
  }

  Future<void> updateOpenaiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openaiApiKey', key.trim());
    state = state.copyWith(openaiApiKey: key.trim());
  }

  Future<void> updateAnthropicApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('anthropicApiKey', key.trim());
    state = state.copyWith(anthropicApiKey: key.trim());
  }

  Future<void> updateAiModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('aiModel', model);
    state = state.copyWith(aiModel: model);
  }

  Future<void> toggleAutoAddMangaSrs(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoAddMangaSrs', value);
    state = state.copyWith(autoAddMangaSrs: value);
  }

  Future<void> updateSrsMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('srsMode', mode);
    state = state.copyWith(srsMode: mode);
  }
}
