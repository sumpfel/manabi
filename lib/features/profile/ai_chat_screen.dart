import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:manabi/features/vocab/widgets/vocab_table_view.dart';
import 'package:manabi/core/database/vocab_repository.dart';
import 'package:manabi/core/models/deck.dart';
import 'package:flutter/services.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/i18n/app_strings.dart';
import '../../core/database/ai_repository.dart';
import '../../core/database/database_service.dart';
import 'ai_settings_screen.dart';
import '../../core/database/unit_repository.dart';
import '../../core/models/unit.dart';
import '../../core/models/lesson.dart';
import '../../core/models/vocab.dart';
import '../units/units_screen.dart';

// ── Data Models ──

class ChatMessage {
  final int? id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isEdited;
  final int? parentMessageId;
  final int versionIndex;
  final int totalVersions;
  final List<String> allVersionContents;

  ChatMessage({
    this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isEdited = false,
    this.parentMessageId,
    this.versionIndex = 0,
    this.totalVersions = 1,
    this.allVersionContents = const [],
  });

  String get role => isUser ? 'user' : 'assistant';

  bool get hasVersions => totalVersions > 1;

  ChatMessage withVersion(int newIndex) {
    if (newIndex < 0 || newIndex >= totalVersions || allVersionContents.isEmpty) return this;
    return ChatMessage(
      id: id,
      content: allVersionContents[newIndex],
      isUser: isUser,
      timestamp: timestamp,
      isEdited: isEdited,
      parentMessageId: parentMessageId,
      versionIndex: newIndex,
      totalVersions: totalVersions,
      allVersionContents: allVersionContents,
    );
  }
}

class ChatConversation {
  final int id;
  final String title;
  final DateTime updatedAt;

  ChatConversation({required this.id, required this.title, required this.updatedAt});

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['conversation_id'],
      title: json['title'] ?? 'Chat',
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

// ── State Management ──

final aiChatProvider = StateNotifierProvider<AiChatNotifier, List<ChatMessage>>((ref) => AiChatNotifier(ref));
final conversationsProvider = StateNotifierProvider<ConversationsNotifier, List<ChatConversation>>((ref) => ConversationsNotifier(ref));
final activeConversationIdProvider = StateProvider<int?>((ref) => null);
final aiLoadingProvider = StateProvider<bool>((ref) => false);

class ConversationsNotifier extends StateNotifier<List<ChatConversation>> {
  final Ref _ref;
  ConversationsNotifier(this._ref) : super([]);

  Future<void> loadConversations() async {
    final aiRepo = _ref.read(aiRepositoryProvider);
    state = await aiRepo.getConversations();
  }

  Future<void> deleteConversation(int id) async {
    await _ref.read(aiRepositoryProvider).deleteConversation(id);
    state = state.where((c) => c.id != id).toList();
  }
}

class AiChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  AiChatNotifier(this._ref) : super([]);

  Future<void> loadMessages(int conversationId) async {
    state = await _ref.read(aiRepositoryProvider).getMessages(conversationId);
  }

  void clearMessages() => state = [];

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    int? currentConvoId = _ref.read(activeConversationIdProvider);
    final isFirstMessage = currentConvoId == null;
    if (currentConvoId == null) {
      final title = 'Chat ${DateTime.now().toLocal().toString().substring(0, 16)}';
      currentConvoId = await _ref.read(aiRepositoryProvider).addConversation(title);
      _ref.read(activeConversationIdProvider.notifier).state = currentConvoId;
      _ref.read(conversationsProvider.notifier).loadConversations();
    }
    
    final userMsg = ChatMessage(content: text, isUser: true, timestamp: DateTime.now());
    final userMsgId = await _ref.read(aiRepositoryProvider).addMessage(currentConvoId, userMsg);
    state = [...state, ChatMessage(id: userMsgId, content: userMsg.content, isUser: true, timestamp: userMsg.timestamp)];
    _ref.read(aiLoadingProvider.notifier).state = true;
    await _ref.read(aiRepositoryProvider).updateConversationTime(currentConvoId);

    try {
      final settings = _ref.read(settingsProvider);
      final responseTextRaw = await _callAi(settings, text);
      
      final botMsg = ChatMessage(content: responseTextRaw, isUser: false, timestamp: DateTime.now());
      final botMsgId = await _ref.read(aiRepositoryProvider).addMessage(currentConvoId, botMsg);
      state = [...state, ChatMessage(id: botMsgId, content: botMsg.content, isUser: false, timestamp: botMsg.timestamp)];
      
      await _ref.read(aiRepositoryProvider).updateConversationTime(currentConvoId);
      _ref.read(conversationsProvider.notifier).loadConversations();
      
      if (isFirstMessage) {
        _generateConversationTitle(currentConvoId, text);
      }
    } catch (e) {
      state = [...state, ChatMessage(content: 'Error: $e', isUser: false, timestamp: DateTime.now())];
    } finally {
      _ref.read(aiLoadingProvider.notifier).state = false;
    }
  }

  /// Generates a short title from the user's first message via AI (fire-and-forget).
  Future<void> _generateConversationTitle(int convoId, String firstMessage) async {
    try {
      final titleText = await _ref.read(aiServiceProvider).queryAi(
        prompt: 'Generate a very short 3-5 word title for this conversation topic: "$firstMessage". Return ONLY the title text, no quotes, no punctuation at the end.',
      );
      final cleanTitle = titleText.trim().replaceAll('"', '').replaceAll("'", '');
      if (cleanTitle.isNotEmpty && cleanTitle.length < 60) {
        await _ref.read(aiRepositoryProvider).updateConversationTitle(convoId, cleanTitle);
        _ref.read(conversationsProvider.notifier).loadConversations();
      }
    } catch (_) {
      // Silently ignore title generation failures
    }
  }

  String _buildSystemPrompt(AppSettings settings) {
    final languageLevel = settings.getEffectiveLanguageLevel();
    final explanationLangId = settings.aiExplanationLanguage ?? settings.motherTongue;
    final explanationLang = explanationLangId == 'ja' ? 'Japanisch' : 'Deutsch';
    
    final colorInstruction = settings.showColorGrammar
      ? '''FARB-FORMATIERUNGSREGELN:
Wende diese Farben auf ALLE japanischen Wörter an, basierend auf ihrer Rolle. Färbe KEINE deutschen Sätze ein.
- Partikel (は, を, に, の, が...): <color=#4FC3F7>Japanisch</color>
- Verben (alle Formen): <color=#FF8A65>Japanisch</color>
- Nomen: <color=#81C784>Japanisch</color>
- Adjektive: <color=#CE93D8>Japanisch</color>
- Adverbien: <color=#FFD54F>Japanisch</color>'''
      : 'Nutze KEINE <color> Tags.';

    final romajiInstruction = settings.showRomajiInChat
      ? 'Füge Romaji-Lesungen in Klammern nach japanischen Begriffen ein, falls hilfreich.'
      : 'Nutze KEIN Romaji. Nutze NUR Kanji und Kana für japanische Begriffe.';

    final furiganaInstruction = settings.showHiraganaInChat
      ? 'Füge Hiragana-Lesungen direkt nach Kanji ein. Format: 漢字<furigana:かんじ/> (innerhalb der Color-Tags).'
      : '';

    return '''Du bist ein erfahrener Japanisch-Tutor. Nimm jede Frage als die eines Schülers auf.
Sprachbereich: $languageLevel. Erkläre ausführlich auf $explanationLang.

FORMATIERUNGS-REGELN:
1. Nutze Markdown (Überschriften, Listen) für Übersichtlichkeit.
2. IMMER japanische Schrift (Kanji/Kana) für japanische Begriffe nutzen.
3. $romajiInstruction
4. $furiganaInstruction
5. $colorInstruction

STRENGES ANTWORT-FORMAT FÜR BEISPIELE:
# [Thema]
## [Beispiel]
- JP: <Japanischer Satz mit Farben>
- DE: <Deutsche Übersetzung ohne Farben>
<Erklärung auf $explanationLang>''';
  }

  /// Call the active AI provider (Gemini, OpenAI, or Anthropic).
  Future<String> _callAi(AppSettings settings, String text) async {
    final systemPrompt = _buildSystemPrompt(settings);
    final history = state.map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.content,
    }).toList();
    
    // Remove the message we just added in sendMessage, because queryAi expects prompt + history
    if (history.isNotEmpty && history.last['content'] == text) {
      history.removeLast();
    }

    try {
      return await _ref.read(aiServiceProvider).queryAi(
        prompt: text,
        systemPrompt: systemPrompt,
        history: history,
      );
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }


  Future<void> editAndResend(int messageIndex, String newContent) async {
    if (messageIndex >= state.length) return;
    final msg = state[messageIndex];
    if (!msg.isUser || msg.id == null) return;
    
    await _ref.read(aiRepositoryProvider).updateMessageContent(msg.id!, newContent);
    int currentConvoId = _ref.read(activeConversationIdProvider)!;
    
    // Reload and truncate to the edited message, then resend
    state = await _ref.read(aiRepositoryProvider).getMessages(currentConvoId);
    if (messageIndex < state.length) {
      state = state.sublist(0, messageIndex + 1);
    }
    
    // Re-send with the new content
    _ref.read(aiLoadingProvider.notifier).state = true;
    try {
      final settings = _ref.read(settingsProvider);
      final responseText = await _callAi(settings, newContent);
      
      final botMsg = ChatMessage(content: responseText, isUser: false, timestamp: DateTime.now());
      final botMsgId = await _ref.read(aiRepositoryProvider).addMessage(currentConvoId, botMsg);
      state = [...state, ChatMessage(id: botMsgId, content: botMsg.content, isUser: false, timestamp: botMsg.timestamp)];
    } catch (e) {
      state = [...state, ChatMessage(content: 'Fehler: $e', isUser: false, timestamp: DateTime.now())];
    } finally {
      _ref.read(aiLoadingProvider.notifier).state = false;
    }
  }

  Future<void> regenerateLastResponse() async {
    if (state.isEmpty) return;
    final settings = _ref.read(settingsProvider);
    
    // Find the last assistant message (the one to regenerate)
    final lastBotIndex = state.lastIndexWhere((m) => !m.isUser);
    if (lastBotIndex < 0) return;
    final originalBotMsg = state[lastBotIndex];
    
    // Determine the parent_message_id: if it already has a parent, use that; otherwise use its own id
    final parentId = originalBotMsg.parentMessageId ?? originalBotMsg.id;
    
    // Don't remove the current message from UI, just show loading
    _ref.read(aiLoadingProvider.notifier).state = true;
    try {
      final lastUserMsg = state.lastWhere((m) => m.isUser, orElse: () => ChatMessage(content: '', isUser: true, timestamp: DateTime.now()));
      if (lastUserMsg.content.isEmpty) return;
      
      final responseText = await _callAi(settings, lastUserMsg.content);
      int? currentConvoId = _ref.read(activeConversationIdProvider);
      
      if (currentConvoId != null) {
        final botMsg = ChatMessage(content: responseText, isUser: false, timestamp: DateTime.now());
        await _ref.read(aiRepositoryProvider).addMessage(currentConvoId, botMsg, parentMessageId: parentId);
        await _ref.read(aiRepositoryProvider).updateConversationTime(currentConvoId);
        // Reload from DB to get proper version grouping
        state = await _ref.read(aiRepositoryProvider).getMessages(currentConvoId);
      }
    } catch (e) {
      state = [...state, ChatMessage(content: 'Fehler: $e', isUser: false, timestamp: DateTime.now())];
    } finally {
      _ref.read(aiLoadingProvider.notifier).state = false;
    }
  }

  void switchVersion(int messageIndex, int newVersionIndex) {
    if (messageIndex < 0 || messageIndex >= state.length) return;
    final msg = state[messageIndex];
    if (!msg.hasVersions) return;
    final updated = msg.withVersion(newVersionIndex);
    state = [...state.sublist(0, messageIndex), updated, ...state.sublist(messageIndex + 1)];
  }
}

// ── Color tag parser (Markdown Integration) ──

class ColorTagSyntax extends md.InlineSyntax {
  ColorTagSyntax() : super(r"""<(?:color|font\s+color\s*)=['"]?(#[A-Fa-f0-9]{6})['"]?>(.*?)</(?:color|font)>""");

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final hexColor = match.group(1)!;
    final text = match.group(2)!;
    // Allow nested tags (like furigana) inside color tags
    // In markdown 7.3.1, we create a new parser instance for the inner text
    final children = md.InlineParser(text, parser.document).parse();
    final el = md.Element('color_tag', children);
    el.attributes['c'] = hexColor;
    parser.addNode(el);
    return true;
  }
}

class FuriganaTagSyntax extends md.InlineSyntax {
  FuriganaTagSyntax() : super(r'([^\s<]+)<furigana:(.*?)\/>');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final base = match.group(1)!;
    final reading = match.group(2)!;
    final el = md.Element.text('furigana_tag', base);
    el.attributes['r'] = reading;
    parser.addNode(el);
    return true;
  }
}

class FuriganaTagBuilder extends MarkdownElementBuilder {
  final bool show;
  FuriganaTagBuilder({required this.show});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final baseText = element.textContent;
    final reading = element.attributes['r']!;
    
    if (!show) {
      return Text(baseText, style: preferredStyle);
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          reading,
          style: (preferredStyle ?? const TextStyle()).copyWith(
            fontSize: (preferredStyle?.fontSize ?? 14) * 0.6,
            height: 0.5,
          ),
        ),
        Text(
          baseText,
          style: preferredStyle,
        ),
      ],
    );
  }
}

class ColorTagBuilder extends MarkdownElementBuilder {
  final double fontSize;
  final bool show;
  ColorTagBuilder({required this.fontSize, required this.show});

  @override
  Widget visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final colorStr = element.attributes['c']!;
    final color = show 
      ? Color(int.parse('FF${colorStr.substring(1)}', radix: 16))
      : (preferredStyle?.color ?? Colors.white70);
    
    return Text(
      element.textContent,
      style: preferredStyle?.copyWith(color: color, fontSize: fontSize, fontWeight: show ? FontWeight.bold : FontWeight.normal) ??
          TextStyle(color: color, fontSize: fontSize, fontWeight: show ? FontWeight.bold : FontWeight.normal),
    );
  }
}

// ── Quick Prompt Starters ──

const _quickPrompts = [
  '👋 Begrüßungen auf Japanisch',
  '🍱 Essen bestellen im Restaurant',
  '🚉 Nach dem Weg fragen',
  '📖 Einen einfachen Satz bilden',
  '🎌 Sich vorstellen auf Japanisch',
  '🔢 Zahlen und Zählen lernen',
];

// ── Main Screen ──

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;
  bool _showHistory = false;
  bool _phoneCallMode = false;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _tts.setLanguage("ja-JP");
    _tts.setSpeechRate(0.5);
    Future.microtask(() => ref.read(conversationsProvider.notifier).loadConversations());
  }

  void _initSpeech() async {
    _speechEnabled = await _speech.initialize();
    if (mounted) setState(() {});
  }

  void _listen() async {
    if (!_isListening) {
      if (_speechEnabled) {
        setState(() => _isListening = true);
        _speech.listen(onResult: (val) => setState(() => _controller.text = val.recognizedWords), localeId: 'ja_JP');
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _speak(String text) async {
    // 1. Clean up tags and redundant text
    // Remove Furigana tags: <furigana:かんじ/> -> empty
    String cleanText = text.replaceAll(RegExp(r'<furigana:[^>]*/>'), '');
    // Remove Color tags
    cleanText = cleanText.replaceAll(RegExp(r'<(?:color|font\s+color\s*)=[^>]*>|</(?:color|font)>'), '');
    // Remove Romaji lines specifically
    cleanText = cleanText.split('\n').where((line) => !line.trim().startsWith('- Romaji:')).join('\n');
    
    // 2. Split into segments by line or punctuation to handle language switching
    final segments = cleanText.split(RegExp(r'(?<=\n)|(?<=[.!?]\s)'));
    
    for (var segment in segments) {
      if (segment.trim().isEmpty) continue;
      
      bool hasJapanese = RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]').hasMatch(segment);
      String locale = hasJapanese ? 'ja-JP' : 'de-DE';
      
      // Remove prefixes like "- JP:" or "- DE:" for cleaner speech
      String speakText = segment.replaceAll(RegExp(r'^- (?:JP|DE):\s*', caseSensitive: false), '').trim();
      if (speakText.isEmpty) continue;

      await _tts.setLanguage(locale);
      await _tts.speak(speakText);
      
      // Wait for the segment to finish before moving to the next language/segment
      // Note: flutter_tts doesn't always await perfectly on all platforms, 
      // but this is the standard approach.
      await Future.delayed(const Duration(milliseconds: 500)); 
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _togglePhoneCall() {
    if (_phoneCallMode) {
      // End call
      setState(() => _phoneCallMode = false);
      _speech.stop();
      _tts.stop();
      setState(() { _isListening = false; _isSpeaking = false; });
    } else {
      // Start call
      setState(() => _phoneCallMode = true);
      _startPhoneListening();
    }
  }

  void _startPhoneListening() async {
    if (!_speechEnabled || !_phoneCallMode) return;
    setState(() => _isListening = true);
    _speech.listen(
      onResult: (val) {
        if (val.finalResult && val.recognizedWords.trim().isNotEmpty) {
          setState(() => _isListening = false);
          _sendPhoneMessage(val.recognizedWords);
        }
      },
      localeId: 'ja_JP',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _sendPhoneMessage(String text) async {
    await ref.read(aiChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
    // Read the response aloud, then listen again
    final messages = ref.read(aiChatProvider);
    if (messages.isNotEmpty && !messages.last.isUser) {
      final clean = messages.last.content.replaceAll(RegExp(r'<color=[^>]*>|</color>'), '');
      setState(() => _isSpeaking = true);
      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _isSpeaking = false);
          if (_phoneCallMode) _startPhoneListening();
        }
      });
      await _tts.speak(clean);
    } else if (_phoneCallMode) {
      _startPhoneListening();
    }
  }

  void _startNewChat() {
    ref.read(activeConversationIdProvider.notifier).state = null;
    ref.read(aiChatProvider.notifier).clearMessages();
    setState(() => _showHistory = false);
  }

  void _loadConversation(ChatConversation convo) {
    ref.read(activeConversationIdProvider.notifier).state = convo.id;
    ref.read(aiChatProvider.notifier).loadMessages(convo.id);
    setState(() => _showHistory = false);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiChatProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);
    final conversations = ref.watch(conversationsProvider);
    final isLoading = ref.watch(aiLoadingProvider);

    const bgColor = Color(0xFF0F0F0F);
    const cardColor = Color(0xFF1A1A1A);
    final borderColor = Colors.white.withOpacity(0.08);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(_showHistory ? 'Chat-Verlauf' : 'AI Sensei', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: bgColor,
        elevation: 0,
        leading: InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(24),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 8),
              Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
              Text('Menü', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        leadingWidth: 80,
        actions: [
          // History toggle
          TextButton.icon(
            icon: Icon(_showHistory ? Icons.chat : Icons.history, color: Colors.white70, size: 20),
            label: Text(_showHistory ? 'Chat' : 'Verlauf', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            onPressed: () => setState(() => _showHistory = !_showHistory),
          ),
          // New chat
          if (!_showHistory)
            TextButton.icon(
              icon: const Icon(Icons.add, color: Colors.white70, size: 20),
              label: const Text('Neu', style: TextStyle(color: Colors.white70, fontSize: 12)),
              onPressed: _startNewChat,
            ),
          // More options
          if (!_showHistory)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white70),
              color: const Color(0xFF2A2A2A),
              onSelected: (value) {
                if (value == 'settings') _showAiSettings(context);
                if (value == 'unit') _showMakeUnitDialog();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings, color: Colors.white54, size: 18), SizedBox(width: 8), Text('Einstellungen', style: TextStyle(color: Colors.white))])),
                if (messages.isNotEmpty)
                  const PopupMenuItem(value: 'unit', child: Row(children: [Icon(Icons.school, color: Colors.amber, size: 18), SizedBox(width: 8), Text('Lektion erstellen', style: TextStyle(color: Colors.white))])),
              ],
            ),
        ],
      ),
      body: _phoneCallMode
          ? _buildPhoneCallOverlay(cardColor, borderColor, messages, isLoading)
          : _showHistory
              ? _buildHistoryPanel(conversations, cardColor, borderColor)
              : _buildChatPanel(messages, isLoading, cardColor, borderColor, settings),
    );
  }

  // ── Phone Call Mode Overlay ──

  Widget _buildPhoneCallOverlay(Color cardColor, Color borderColor, List<ChatMessage> messages, bool isLoading) {
    final lastAiMsg = messages.where((m) => !m.isUser).isEmpty
        ? null
        : messages.where((m) => !m.isUser).last;

    return Container(
      color: const Color(0xFF0F0F0F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: _isListening ? 140 : (_isSpeaking ? 120 : 100),
              height: _isListening ? 140 : (_isSpeaking ? 120 : 100),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening
                    ? Colors.red.withAlpha(40)
                    : _isSpeaking
                        ? Colors.amber.withAlpha(40)
                        : isLoading
                            ? Colors.blue.withAlpha(40)
                            : Colors.grey.withAlpha(20),
                border: Border.all(
                  color: _isListening ? Colors.red : (_isSpeaking ? Colors.amber : Colors.grey),
                  width: 3,
                ),
              ),
              child: Icon(
                _isListening ? Icons.mic : (_isSpeaking ? Icons.volume_up : (isLoading ? Icons.hourglass_top : Icons.phone_in_talk)),
                size: 48,
                color: _isListening ? Colors.red : (_isSpeaking ? Colors.amber : Colors.white54),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isListening ? 'Ich höre zu...' : (_isSpeaking ? 'Sensei spricht...' : (isLoading ? 'Denke nach...' : 'Sprachanruf aktiv')),
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 16),
            if (lastAiMsg != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  lastAiMsg.content.replaceAll(RegExp(r"""<(?:color|font\s+color\s*)=[^>]*>|</(?:color|font)>"""), ''),
                  style: const TextStyle(color: Colors.white38, fontSize: 14),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 48),
            // End call button
            GestureDetector(
              onTap: _togglePhoneCall,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.call_end, color: Colors.white, size: 32),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Auflegen', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // ── History Panel ──

  Widget _buildHistoryPanel(List<ChatConversation> conversations, Color cardColor, Color borderColor) {
    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.white.withOpacity(0.15)),
            const SizedBox(height: 12),
            Text('Noch keine Chats', style: TextStyle(color: Colors.white.withOpacity(0.3))),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final convo = conversations[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: cardColor, border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: const Icon(Icons.chat_bubble_outline, color: Colors.white54),
            title: Text(convo.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${convo.updatedAt.day}.${convo.updatedAt.month}.${convo.updatedAt.year}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => ref.read(conversationsProvider.notifier).deleteConversation(convo.id)),
            onTap: () => _loadConversation(convo),
          ),
        );
      },
    );
  }

  // ── Chat Panel ──

  Widget _buildChatPanel(List<ChatMessage> messages, bool isLoading, Color cardColor, Color borderColor, AppSettings settings) {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _buildMessageBubble(messages[index], index, messages.length, cardColor, borderColor, settings),
                ),
        ),
        if (isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber)),
                const SizedBox(width: 12),
                Text('Sensei denkt nach...', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
              ],
            ),
          ),
        _buildInputBar(cardColor, borderColor),
      ],
    );
  }

  // ── Empty state with quick prompts ──

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.school, size: 64, color: Colors.white.withOpacity(0.12)),
          const SizedBox(height: 16),
          Text('Willkommen beim AI Sensei! 🎌', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Frag mich alles über Japanisch', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14)),
          const SizedBox(height: 32),
          Text('Schnellstart:', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickPrompts.map((prompt) => ActionChip(
              label: Text(prompt, style: const TextStyle(fontSize: 13)),
              backgroundColor: const Color(0xFF1A1A1A),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
              onPressed: () {
                ref.read(aiChatProvider.notifier).sendMessage(prompt);
                _scrollToBottom();
              },
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ── Message Bubble ──

  Widget _buildMessageBubble(ChatMessage msg, int index, int totalMessages, Color cardColor, Color borderColor, AppSettings settings) {
    final theme = Theme.of(context);
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: msg.isUser ? () => _showEditDialog(index, msg.content) : null,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          decoration: BoxDecoration(
            color: msg.isUser ? theme.colorScheme.primary.withAlpha(200) : cardColor,
            border: msg.isUser ? null : Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(16).copyWith(
              bottomRight: msg.isUser ? const Radius.circular(2) : const Radius.circular(16),
              bottomLeft: msg.isUser ? const Radius.circular(16) : const Radius.circular(2),
            ),
          ),
          child: Column(
            crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (msg.isEdited)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('(bearbeitet)', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, fontStyle: FontStyle.italic)),
                ),
              msg.isUser
                  ? SelectableText(msg.content, style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 15))
                  : MarkdownBody(
                      data: msg.content,
                      selectable: true,
                      extensionSet: md.ExtensionSet.gitHubFlavored,
                      inlineSyntaxes: [
                        ColorTagSyntax(),
                        FuriganaTagSyntax(),
                      ],
                      builders: {
                        'color_tag': ColorTagBuilder(
                          fontSize: 15, 
                          show: settings.showColorGrammar,
                        ),
                        'furigana_tag': FuriganaTagBuilder(
                          show: settings.showFurigana,
                        ),
                      },
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
                        h1: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 2.0),
                        h2: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, height: 1.8),
                        h3: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.6),
                        listBullet: const TextStyle(color: Colors.amber, fontSize: 15),
                        strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        blockquote: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
                        code: TextStyle(color: Colors.amber.shade200, backgroundColor: Colors.black26),
                      ),
                    ),
              if (!msg.isUser && msg.hasVersions)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: msg.versionIndex > 0
                            ? () => ref.read(aiChatProvider.notifier).switchVersion(index, msg.versionIndex - 1)
                            : null,
                        child: Icon(Icons.chevron_left, size: 20, color: msg.versionIndex > 0 ? Colors.amber : Colors.white12),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '${msg.versionIndex + 1}/${msg.totalVersions}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      InkWell(
                        onTap: msg.versionIndex < msg.totalVersions - 1
                            ? () => ref.read(aiChatProvider.notifier).switchVersion(index, msg.versionIndex + 1)
                            : null,
                        child: Icon(Icons.chevron_right, size: 20, color: msg.versionIndex < msg.totalVersions - 1 ? Colors.amber : Colors.white12),
                      ),
                    ],
                  ),
                ),
              if (!msg.isUser)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.volume_up, size: 18, color: Colors.white38),
                      tooltip: 'Vorlesen',
                      onPressed: () => _speak(msg.content),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (index == totalMessages - 1)
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18, color: Colors.white38),
                        tooltip: 'Neue Antwort generieren',
                        onPressed: () => ref.read(aiChatProvider.notifier).regenerateLastResponse(),
                        visualDensity: VisualDensity.compact,
                      ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18, color: Colors.white38),
                      tooltip: 'Kopieren',
                      onPressed: () {
                        final clean = msg.content.replaceAll(RegExp(r'<color=[^>]*>|</color>'), '');
                        Clipboard.setData(ClipboardData(text: clean));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('In Zwischenablage kopiert'), duration: Duration(seconds: 1)));
                      },
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              if (msg.isUser)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Lang drücken zum Bearbeiten', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 9)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Input Bar ──

  Widget _buildInputBar(Color cardColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: cardColor, border: Border(top: BorderSide(color: borderColor))),
      child: SafeArea(
        child: Row(
          children: [
            // Voice/Mic Button
            IconButton(
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : Colors.white54),
              tooltip: _isListening ? 'Zuhören stoppen' : 'Sprechen',
              onPressed: _listen,
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _isListening ? 'Ich höre zu...' : 'Frag den Sensei...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.amber.withOpacity(0.5))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled: true,
                  fillColor: const Color(0xFF252525),
                ),
                onSubmitted: (val) {
                  ref.read(aiChatProvider.notifier).sendMessage(val);
                  _controller.clear();
                  _scrollToBottom();
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.amber, Colors.orange]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.orange.withAlpha(100), blurRadius: 4, offset: const Offset(0, 2))
                ]
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    ref.read(aiChatProvider.notifier).sendMessage(_controller.text);
                    _controller.clear();
                    _scrollToBottom();
                  }
                },
              ),
            ),
            const SizedBox(width: 4),
            // Phone call mode button
            Container(
              decoration: BoxDecoration(
                color: _phoneCallMode ? Colors.red : const Color(0xFF252525),
                borderRadius: BorderRadius.circular(24),
              ),
              child: IconButton(
                icon: Icon(
                  _phoneCallMode ? Icons.call_end : Icons.phone,
                  color: _phoneCallMode ? Colors.white : Colors.white54,
                  size: 20,
                ),
                tooltip: _phoneCallMode ? 'Anruf beenden' : 'Sprachanruf starten',
                onPressed: _togglePhoneCall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit Dialog ──

  void _showEditDialog(int index, String currentContent) {
    final editController = TextEditingController(text: currentContent);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Nachricht bearbeiten', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editController, maxLines: 5, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: const Color(0xFF2A2A2A)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () { Navigator.pop(ctx); ref.read(aiChatProvider.notifier).editAndResend(index, editController.text); }, 
            child: const Text('Absenden')
          ),
        ],
      ),
    );
  }

  void _showMakeUnitDialog() {
    final convId = ref.read(activeConversationIdProvider);
    if (convId == null) return;
    
    final promptController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Lerneinheit erstellen', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aus diesem Chat eine Lerneinheit (Unit) generieren.', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            TextField(
              controller: promptController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Zusätzliche Anweisungen...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('Abbrechen', style: TextStyle(color: Colors.white54))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              _makeUnitFromChat(convId, additionalPrompt: promptController.text.isNotEmpty ? promptController.text : null);
            },
            child: const Text('Generieren ✨'),
          ),
        ],
      ),
    );
  }


  Future<void> _makeUnitFromChat(int conversationId, {String? additionalPrompt, int exerciseCount = 3, int taskCount = 5}) async {
    final settings = ref.read(settingsProvider);
    final aiService = ref.read(aiServiceProvider);
    final aiRepo = ref.read(aiRepositoryProvider);
    final unitRepo = ref.read(unitRepositoryProvider);
    final vocabRepo = ref.read(vocabRepositoryProvider);

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generiere Lerneinheit (Unit)...')));
    
    try {
      // 1. Get history
      final messages = await aiRepo.getMessages(conversationId);
      final chatContent = messages.map((m) => '${m.isUser ? "User" : "Assistant"}: ${m.content}').join('\n');
      final mtName = settings.motherTongue == 'ja' ? 'Japanisch' : 'Deutsch';

      // 2. Build Prompt (replicated from ai.py)
      final sysPrompt = '''Du bist ein Kurs-Designer für Japanisch. 
Erstelle eine Lerneinheit (Unit) basierend auf dem Chat-Inhalt.
Antworte NUR im JSON-Format.''';

      final userPrompt = '''Erstelle eine strukturierte Unit mit $exerciseCount Lektionen.
Chat-Inhalt:
$chatContent

Zusatz-Instruktion: $additionalPrompt

FORMAT-VORGABE (JSON):
{
  "title": "Unit Titel",
  "description": "Beschreibung",
  "lessons": [
    {
      "title": "Lektionstitel",
      "description": "Was man lernt",
      "lesson_type": "grammarIntro",
      "grammar_explanation": "Ausführliche Erklärung in $mtName mit Beispielen",
      "required_accuracy": 0.8,
      "vocab": [
        {"word": "私", "reading": "わたし", "translation": "Ich"}
      ],
      "exercises": [
        {
          "type": "multiple_choice",
          "question": "Frage",
          "instruction": "Anweisung",
          "options": ["O1", "O2", "O3", "O4"],
          "correctOption": "O1"
        }
      ]
    }
  ]
}
Gültige Lesson-Typen: vocabGate, grammarIntro, grammarProduction, mixedReinforcement, unitTest.
Gültige Übungs-Typen: multiple_choice, typing, fill_in_blank, flashcard, matching, sentence_building.
Gib NUR das JSON zurück.''';

      final response = await aiService.queryAi(
        prompt: userPrompt,
        systemPrompt: sysPrompt,
      );

      // 3. Parse JSON
      final Map<String, dynamic> unitData = jsonDecode(_cleanJsonResponse(response));
      
      // 4. Create Unit & Lessons
      final unitId = 'ai_unit_${DateTime.now().millisecondsSinceEpoch}';
      final List<Lesson> lessons = [];
      final List<Vocab> unitVocab = [];

      final List<dynamic> lessonsRaw = unitData['lessons'] ?? [];
      for (int i = 0; i < lessonsRaw.length; i++) {
        final l = lessonsRaw[i];
        final lessonId = '${unitId}_l$i';
        
        final lesson = Lesson.fromMap({
          ...l,
          'id': lessonId,
          'unitId': unitId,
          'vocabularyList': l['vocab'] ?? [],
        });
        lessons.add(lesson);

        // Collect vocab for the unit deck
        for (final v in (l['vocab'] as List? ?? [])) {
          unitVocab.add(Vocab(
            deckId: 0, 
            kanji: v['word'], 
            kana: v['reading'], 
            translation: v['translation'],
            translationDe: settings.motherTongue == 'de' ? v['translation'] : null,
            translationEn: settings.motherTongue == 'en' ? v['translation'] : null,
            dueDate: DateTime.now().millisecondsSinceEpoch,
          ));
        }
      }

      final unit = Unit(
        id: unitId,
        title: unitData['title'] ?? 'Neue Lektion',
        description: unitData['description'] ?? 'Durch KI generiert.',
        lessons: lessons,
        unitVocab: unitVocab,
      );

      // 5. Save Unit to DB
      await unitRepo.insertUnit(unit);

      // 6. Create a Deck for this unit (for SRS)
      final deckId = await vocabRepo.insertDeck(Deck(
        name: 'Unit: ${unit.title}',
        deckType: DeckType.unit,
        parentUnitId: unitId,
        isAiGenerated: true,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

      for (final v in unitVocab) {
        await vocabRepo.insertVocabFromStrings(
          deckId: deckId,
          wordText: v.kanji ?? '',
          readingText: v.kana,
          translationText: v.translation,
        );
      }

      if (mounted) {
        // Invalidate providers
        ref.invalidate(unitsProvider);
        ref.invalidate(decksProvider);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Lerneinheit erfolgreich erstellt!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red));
    }
  }

  String _cleanJsonResponse(String raw) {
    String clean = raw.trim();
    if (clean.contains('```json')) {
      clean = clean.split('```json')[1].split('```')[0].trim();
    } else if (clean.contains('```')) {
      clean = clean.split('```')[1].split('```')[0].trim();
    }
    // Remove potential leading/trailing text if the AI didn't follow "ONLY JSON"
    final startBracket = clean.indexOf('[');
    final lastBracket = clean.lastIndexOf(']');
    if (startBracket != -1 && lastBracket != -1 && lastBracket > startBracket) {
      return clean.substring(startBracket, lastBracket + 1);
    }
    final startObj = clean.indexOf('{');
    final lastObj = clean.lastIndexOf('}');
    if (startObj != -1 && lastObj != -1 && lastObj > startObj) {
      return clean.substring(startObj, lastObj + 1);
    }
    return clean;
  }

  // ── Settings Dialog ──

  void _showAiSettings(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AiSettingsScreen()));
  }
}

// ── AI Settings Dialog ──

class AiSettingsDialog extends ConsumerWidget {
  const AiSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final s = AppStrings.of(settings.motherTongue);

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: Text(s.aiSettings, style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AI Provider Status ──
            Text('AI PROVIDER', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF252525),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    settings.hasGeminiKey ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: settings.hasGeminiKey ? Colors.green : Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      settings.hasGeminiKey
                          ? 'Gemini API Key konfiguriert (gemini-2.0-flash)'
                          : settings.hasBackend
                              ? 'Kein Gemini Key — Backend wird verwendet'
                              : 'Kein API Key! Bitte unter Profil > API Keys konfigurieren.',
                      style: TextStyle(color: settings.hasGeminiKey ? Colors.white70 : Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 16),

            // ── Display ──
            Text(s.isGerman ? 'ANZEIGE' : 'DISPLAY', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 4),
            _compactSwitch(s.showRomaji, settings.showRomajiInChat, (v) => notifier.toggleShowRomajiInChat(v)),
            _compactSwitch(s.showFurigana, settings.showHiraganaInChat, (v) => notifier.toggleShowHiraganaInChat(v)),
            _compactSwitch(s.colorGrammar, settings.colorGermanSentences, (v) => notifier.toggleColorGerman(v)),
            const Divider(color: Colors.white12, height: 16),
            
            // ── Level ──
            Text(s.isGerman ? 'NIVEAU' : 'LEVEL', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: settings.aiLanguageLevel,
              dropdownColor: const Color(0xFF2A2A2A),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              items: ['A1', 'A2', 'B1', 'B2', 'C1'].map((l) => DropdownMenuItem(value: l, child: Text('JLPT ${l == 'A1' ? 'N5' : l == 'A2' ? 'N4' : l == 'B1' ? 'N3' : l == 'B2' ? 'N2' : 'N1'} ($l)'))).toList(),
              onChanged: (val) { if (val != null) notifier.updateAiLevel(val); },
            ),
            const SizedBox(height: 8),
            _compactSwitch(s.isGerman ? 'Vokabular einschränken' : 'Restrict vocabulary', settings.restrictToKnownVocab, (v) => notifier.toggleRestrictVocab(v)),
            if (settings.restrictToKnownVocab)
              Row(
                children: [
                  Text(s.isGerman ? 'Max. neue Wörter: ' : 'Max new words: ', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  DropdownButton<int>(
                    value: settings.maxNewWordsPerResponse,
                    dropdownColor: const Color(0xFF2A2A2A),
                    underline: const SizedBox(),
                    items: [1, 2, 3, 5, 10].map((e) => DropdownMenuItem(value: e, child: Text('$e', style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (val) { if (val != null) notifier.updateMaxNewWords(val); },
                  ),
                ],
              ),
            const Divider(color: Colors.white12, height: 16),
            
            // ── Colors (compact) ──
            ExpansionTile(
              title: Text(s.isGerman ? 'Farbeinstellungen' : 'Color Settings', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              iconColor: Colors.white38,
              children: [
                _colorRow(s.isGerman ? 'Partikel' : 'Particles', settings.colorParticles, (c) => notifier.updateColorParticles(c)),
                _colorRow(s.isGerman ? 'Verben' : 'Verbs', settings.colorVerbs, (c) => notifier.updateColorVerbs(c)),
                _colorRow(s.isGerman ? 'Nomen' : 'Nouns', settings.colorNouns, (c) => notifier.updateColorNouns(c)),
                _colorRow(s.isGerman ? 'Adjektive' : 'Adjectives', settings.colorAdjectives, (c) => notifier.updateColorAdjectives(c)),
                _colorRow(s.isGerman ? 'Adverbien' : 'Adverbs', settings.colorAdverbs, (c) => notifier.updateColorAdverbs(c)),
              ],
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(s.isGerman ? 'Schließen' : 'Close'))],
    );
  }

  Widget _compactSwitch(String label, bool value, Function(bool) onChanged) {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
          Switch(value: value, onChanged: onChanged, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ],
      ),
    );
  }

  Widget _colorRow(String label, String hexColor, Function(String) onChanged) {
    final colors = ['#4FC3F7', '#FF8A65', '#81C784', '#CE93D8', '#FFD54F', '#EF5350', '#42A5F5', '#26A69A', '#FFA726', '#AB47BC'];
    final color = Color(int.parse('FF${hexColor.substring(1)}', radix: 16));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const Spacer(),
          DropdownButton<String>(
            value: colors.contains(hexColor) ? hexColor : colors.first,
            dropdownColor: const Color(0xFF2A2A2A),
            underline: const SizedBox(),
            isDense: true,
            items: colors.map((c) {
              final cc = Color(int.parse('FF${c.substring(1)}', radix: 16));
              return DropdownMenuItem(value: c, child: Container(width: 18, height: 18, decoration: BoxDecoration(color: cc, shape: BoxShape.circle)));
            }).toList(),
            onChanged: (val) { if (val != null) onChanged(val); },
          ),
        ],
      ),
    );
  }
}
