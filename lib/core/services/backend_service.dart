import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_service.dart';

final backendServiceProvider = Provider<BackendService>((ref) {
  final settings = ref.watch(settingsProvider);
  return BackendService(settings);
});

/// Service for communicating with the Python backend.
/// Works offline by default — only calls backend when URL is configured.
class BackendService {
  final AppSettings _settings;

  BackendService(this._settings);

  bool get isAvailable => _settings.hasBackend;
  String get _baseUrl => _settings.effectiveBackendUrl;

  /// Check if backend is reachable at the root status endpoint
  Future<bool> healthCheck() async {
    if (!isAvailable) return false;
    try {
      final resp = await http.get(Uri.parse(_baseUrl)).timeout(const Duration(seconds: 3));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Register a new user on the FastAPI backend
  Future<bool> registerUser(String username, String password, String email) async {
    if (!isAvailable) return false;
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'email': email,
          'mother_tongue_lang_id': _settings.isGerman ? 1 : 2,
        }),
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Login and store JWT token locally
  Future<bool> loginUser(String username, String password) async {
    if (!isAvailable) return false;
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': username, 'password': password},
      ).timeout(const Duration(seconds: 10));
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['access_token']);
        // Save user info for offline fallback
        if (data['user_id'] != null) await prefs.setInt('user_id', data['user_id']);
        if (data['username'] != null) await prefs.setString('username', data['username']);
        if (data['email'] != null) await prefs.setString('email', data['email']);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Generate contextual vocabulary via local Ollama
  Future<Map<String, dynamic>?> generateVocabWithAI(String prompt) async {
    if (!isAvailable) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/ai/generate_vocab'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'prompt': prompt,
          'model': _settings.selectedOllamaModel,
          'learning_lang': 'ja',
          'mother_tongue': _settings.motherTongue,
          'cefr_level': _settings.aiLanguageLevel,
        }),
      ).timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) return jsonDecode(resp.body);
    } catch (_) {}
    return null;
  }

  /// Sync decks with the cloud DB (Push/Pull)
  Future<bool> syncDecks() async {
    if (!isAvailable) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/decks/'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (_) {}
    return false;
  }

  /// Get unit thumbnail URL. Returns null if offline.
  String? getUnitThumbnailUrl(String unitId) {
    if (!isAvailable) return null;
    return '$_baseUrl/unit-thumbnails/$unitId';
  }

  /// Remote Sessions
  Future<bool> saveRemoteSession(Map<String, dynamic> sessionData) async {
    if (!isAvailable) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/session/deck'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(sessionData),
      );
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getRemoteSession(int deckId, String method) async {
    if (!isAvailable) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token') ?? '';
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/session/deck/$deckId/$method'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data;
      }
    } catch (_) {}
    return null;
  }
}
