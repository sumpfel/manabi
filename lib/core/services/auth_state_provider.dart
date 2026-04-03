import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/services/settings_service.dart';

class User {
  final int userId;
  final String username;
  final String email;
  final String? token;
  final String motherTongue;
  final int motherTongueLangId;

  User({
    required this.userId,
    required this.username,
    required this.email,
    this.token,
    this.motherTongue = 'de',
    this.motherTongueLangId = 1,
  });
}

final userProvider = StateProvider<User?>((ref) => null);
final authStateProvider = Provider<bool>((ref) => ref.watch(userProvider) != null);
final usernameProvider = Provider<String?>((ref) => ref.watch(userProvider)?.username);

Future<void> checkAuthStatus(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');
  if (token != null && token.isNotEmpty) {
    // Fetch real user data from backend
    final settings = ref.read(settingsProvider);
    if (settings.hasBackend) {
      try {
        final res = await http.get(
          Uri.parse('${settings.effectiveBackendUrl}/api/auth/me'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          ref.read(userProvider.notifier).state = User(
            userId: data['user_id'] ?? 0,
            username: data['username'] ?? 'Nutzer',
            email: data['email'] ?? '',
            token: token,
            motherTongue: data['mother_tongue'] ?? 'de',
            motherTongueLangId: data['mother_tongue_lang_id'] ?? 1,
          );
          return;
        }
      } catch (_) {
        // If backend is unreachable, still set user from token (offline mode)
      }
    }
    
    // Fallback: Set user from stored info if backend is down
    ref.read(userProvider.notifier).state = User(
      userId: prefs.getInt('user_id') ?? 0,
      username: prefs.getString('username') ?? 'Angemeldeter Nutzer',
      email: prefs.getString('email') ?? '',
      token: token,
    );
  } else {
    ref.read(userProvider.notifier).state = null;
  }
}

Future<void> logout(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('jwt_token');
  await prefs.remove('user_id');
  await prefs.remove('username');
  await prefs.remove('email');
  ref.read(userProvider.notifier).state = null;
}
