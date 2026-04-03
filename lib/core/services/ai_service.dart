import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

final aiServiceProvider = Provider<AiService>((ref) => AiService(ref));

class AiService {
  final Ref _ref;
  AiService(this._ref);

  List<String>? _cachedModels;
  DateTime? _lastModelFetch;

  /// Standard entry point for AI queries.
  /// [prompt] the instruction for the AI.
  /// [systemPrompt] optional system-level instruction.
  /// [history] optional chat history for conversational providers.
  Future<String> queryAi({
    required String prompt,
    String? systemPrompt,
    List<Map<String, String>>? history,
  }) async {
    final settings = _ref.read(settingsProvider);
    final provider = settings.aiProvider;

    try {
      if (provider == 'ollama') {
        if (!settings.hasBackend) {
          throw Exception('Für Ollama muss in den Entwickler-Einstellungen eine Backend-IP konfiguriert sein.');
        }
        return await _callOllama(settings, prompt, systemPrompt, history);
      } else if (provider == 'openai' && settings.hasOpenaiKey) {
        return await _callOpenAi(settings, prompt, systemPrompt, history);
      } else if (provider == 'anthropic' && settings.hasAnthropicKey) {
        return await _callAnthropic(settings, prompt, systemPrompt, history);
      } else if (settings.hasGeminiKey) {
        return await _callGemini(settings, prompt, systemPrompt, history);
      } else {
        throw Exception('Kein gültiger API-Key für Provider "$provider" gefunden.');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _callGemini(
    AppSettings settings,
    String prompt,
    String? systemPrompt,
    List<Map<String, String>>? history,
  ) async {
    // 1. Dynamically fetch or use cached models to prevent 404s and rate-limits
    String targetModel = settings.aiModel.startsWith('gemini') ? settings.aiModel : 'gemini-1.5-flash';
    
    bool shouldFetch = _cachedModels == null || 
                      _lastModelFetch == null || 
                      DateTime.now().difference(_lastModelFetch!).inHours > 1;

    if (shouldFetch) {
      final modelsUrl = 'https://generativelanguage.googleapis.com/v1beta/models?key=${settings.geminiApiKey}';
      try {
        final modelsRes = await http.get(Uri.parse(modelsUrl)).timeout(const Duration(seconds: 10));
        if (modelsRes.statusCode == 200) {
          final data = jsonDecode(modelsRes.body);
          final List<dynamic> models = data['models'] ?? [];
          _cachedModels = models.map((m) => m['name'] as String).where((n) => n.contains('gemini')).toList();
          _lastModelFetch = DateTime.now();
        }
      } catch (_) {}
    }

    if (_cachedModels != null && _cachedModels!.isNotEmpty) {
      final available = _cachedModels!;
      // If the user's selected model is not available, find a fallback
      if (!available.contains('models/$targetModel')) {
        if (available.any((m) => m.contains('1.5-flash'))) {
          targetModel = available.firstWhere((m) => m.contains('1.5-flash')).replaceFirst('models/', '');
        } else if (available.any((m) => m.contains('2.0-flash'))) {
          targetModel = available.firstWhere((m) => m.contains('2.0-flash')).replaceFirst('models/', '');
        } else if (available.isNotEmpty) {
          targetModel = available.first.replaceFirst('models/', '');
        }
      }
    }

    final url = 'https://generativelanguage.googleapis.com/v1beta/models/$targetModel:generateContent?key=${settings.geminiApiKey}';

    final contents = <Map<String, dynamic>>[];
    if (history != null) {
      for (final msg in history) {
        contents.add({
          'role': msg['role'] == 'user' ? 'user' : 'model',
          'parts': [{'text': msg['content']}]
        });
      }
    }
    contents.add({'role': 'user', 'parts': [{'text': prompt}]});

    final Map<String, dynamic> body = {
      'contents': contents,
    };
    if (systemPrompt != null) {
      body['system_instruction'] = {
        'parts': [
          {'text': systemPrompt}
        ]
      };
    }

    // Attempt with retry for 429
    for (int attempt = 0; attempt < 3; attempt++) {
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 90));

      if (res.statusCode == 429 && attempt < 2) {
        // Increase delay on each attempt
        final delay = (attempt + 1) * 10; 
        await Future.delayed(Duration(seconds: delay));
        continue;
      }

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final result = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (result != null) return result;
        throw Exception('Gemini hat keine Antwort geliefert.');
      }

      final errorMsg = _parseError(res.body, 'Gemini');
      if (res.statusCode == 429) {
        throw Exception('API-Limit erreicht: $errorMsg');
      }
      throw Exception('Gemini Fehler ${res.statusCode}: $errorMsg');
    }
    throw Exception('Gemini Fehler: Rate-Limit konnte auch nach mehreren Versuchen nicht umgangen werden.');
  }

  Future<String> _callOpenAi(
    AppSettings settings,
    String prompt,
    String? systemPrompt,
    List<Map<String, String>>? history,
  ) async {
    final model = settings.aiModel.startsWith('gpt') || settings.aiModel.startsWith('o') 
        ? settings.aiModel 
        : 'gpt-4o-mini';
    
    final messages = <Map<String, String>>[];
    if (systemPrompt != null) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    if (history != null) {
      for (final msg in history) {
        messages.add({'role': msg['role'] == 'user' ? 'user' : 'assistant', 'content': msg['content']!});
      }
    }
    messages.add({'role': 'user', 'content': prompt});

    final res = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${settings.openaiApiKey}',
      },
      body: jsonEncode({
        'model': model,
        'messages': messages,
        'temperature': 0.7,
      }),
    ).timeout(const Duration(seconds: 90));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['choices']?[0]?['message']?['content'] ?? 'Keine Antwort von OpenAI.';
    }

    final errorMsg = _parseError(res.body, 'OpenAI');
    throw Exception('OpenAI Fehler ${res.statusCode}: $errorMsg');
  }

  Future<String> _callAnthropic(
    AppSettings settings,
    String prompt,
    String? systemPrompt,
    List<Map<String, String>>? history,
  ) async {
    final model = settings.aiModel.startsWith('claude') 
        ? settings.aiModel 
        : 'claude-3-5-sonnet-latest';

    final messages = <Map<String, String>>[];
    if (history != null) {
      for (final msg in history) {
        messages.add({'role': msg['role'] == 'user' ? 'user' : 'assistant', 'content': msg['content']!});
      }
    }
    messages.add({'role': 'user', 'content': prompt});

    final body = {
      'model': model,
      'max_tokens': 4096,
      'messages': messages,
    };
    if (systemPrompt != null) {
      body['system'] = systemPrompt;
    }

    final res = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': settings.anthropicApiKey,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 90));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final content = data['content'] as List?;
      if (content != null && content.isNotEmpty) {
        return content[0]['text'] ?? '';
      }
      return 'Keine Antwort von Anthropic.';
    }

    final errorMsg = _parseError(res.body, 'Anthropic');
    throw Exception('Anthropic Fehler ${res.statusCode}: $errorMsg');
  }

  Future<String> _callOllama(
    AppSettings settings,
    String prompt,
    String? systemPrompt,
    List<Map<String, String>>? history,
  ) async {
    final url = '${settings.effectiveBackendUrl}/api/ai/query';
    
    final Map<String, dynamic> body = {
      'prompt': prompt,
      'model': settings.selectedOllamaModel,
    };
    if (systemPrompt != null) body['system_prompt'] = systemPrompt;
    if (history != null) body['history'] = history;

    final res = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 120));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['response'] ?? 'Keine Antwort von Ollama.';
    }

    final errorMsg = _parseError(res.body, 'Ollama');
    throw Exception('Ollama Fehler ${res.statusCode}: $errorMsg');
  }

  String _parseError(String body, String provider) {
    try {
      final data = jsonDecode(body);
      return data['error']?['message'] ?? data['message'] ?? body;
    } catch (_) {
      return body;
    }
  }
}
