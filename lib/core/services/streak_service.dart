import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final streakProvider = StateNotifierProvider<StreakNotifier, int>((ref) => StreakNotifier());

class StreakNotifier extends StateNotifier<int> {
  StreakNotifier() : super(0) {
    _init();
  }

  Future<void> _init() async {
    state = await StreakService.getStreak();
  }

  Future<void> recordStudyActivity() async {
    final newStreak = await StreakService.recordActivity();
    state = newStreak;
  }
}


class StreakService {
  static const String _keyLastStudy = 'lastStudyDate';
  static const String _keyStreak = 'currentStreak';

  static Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastStudyIso = prefs.getString(_keyLastStudy);
    int currentStreak = prefs.getInt(_keyStreak) ?? 0;

    if (lastStudyIso != null) {
      final lastDate = DateTime.parse(lastStudyIso);
      final today = DateTime.now();
      final diff = DateTime(today.year, today.month, today.day)
          .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
          .inDays;

      if (diff > 1) {
        currentStreak = 0;
        await prefs.setInt(_keyStreak, 0);
      }
    }
    return currentStreak;
  }

  static Future<int> recordActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final lastStudyIso = prefs.getString(_keyLastStudy);
    int currentStreak = prefs.getInt(_keyStreak) ?? 0;

    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);

    if (lastStudyIso != null) {
      final lastDate = DateTime.parse(lastStudyIso);
      final lastMidnight = DateTime(lastDate.year, lastDate.month, lastDate.day);
      final diff = todayMidnight.difference(lastMidnight).inDays;

      if (diff == 1) {
        currentStreak++;
      } else if (diff > 1) {
        currentStreak = 1;
      }
    } else {
      currentStreak = 1;
    }

    await prefs.setString(_keyLastStudy, today.toIso8601String());
    await prefs.setInt(_keyStreak, currentStreak);
    return currentStreak;
  }
}

// Recently Studied Service to track "Continue" points
class RecentActivity {
  final String id; // Unique ID (e.g., deckId, mangaTitle)
  final String type; // 'manga', 'lesson', 'deck'
  final String title;
  final String subtitle;
  final String? imageUrl;
  final Map<String, dynamic> metadata;
  final int timestamp;

  RecentActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.metadata,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'subtitle': subtitle,
    'imageUrl': imageUrl,
    'metadata': metadata,
    'timestamp': timestamp,
  };

  factory RecentActivity.fromJson(Map<String, dynamic> json) => RecentActivity(
    id: json['id']?.toString() ?? '',
    type: json['type'] ?? '',
    title: json['title'] ?? '',
    subtitle: json['subtitle'] ?? '',
    imageUrl: json['imageUrl'],
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    timestamp: json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
  );
}

final recentActivityProvider = StateNotifierProvider<RecentActivityNotifier, List<RecentActivity>>((ref) => RecentActivityNotifier());

class RecentActivityNotifier extends StateNotifier<List<RecentActivity>> {
  RecentActivityNotifier() : super([]) {
    _load();
  }

  static const String _key = 'recent_activities_v2';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_key) ?? [];
    try {
      state = list.map((e) {
        return RecentActivity.fromJson(jsonDecode(e));
      }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      state = [];
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = state.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, list);
  }

  Future<void> record(RecentActivity activity) async {
    // Keep only the most recent per unique ID
    final filtered = state.where((a) => a.id != activity.id).toList();
    final newList = [activity, ...filtered].take(10).toList();
    state = newList;
    await _save();
  }

  Future<void> clear() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

