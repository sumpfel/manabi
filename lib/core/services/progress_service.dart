import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

final progressProvider = NotifierProvider<ProgressNotifier, ProgressState>(ProgressNotifier.new);

class ProgressState {
  final List<String> completedLessons;
  final Map<String, double> lessonAccuracies;
  final bool isLoaded;

  ProgressState({this.completedLessons = const [], this.lessonAccuracies = const {}, this.isLoaded = false});

  bool isCompleted(String lessonId) => completedLessons.contains(lessonId);
  double? getAccuracy(String lessonId) => lessonAccuracies[lessonId];
}

class ProgressNotifier extends Notifier<ProgressState> {
  static const _completedKey = 'completed_lessons';
  static const _accuracyKey = 'lesson_accuracies';

  @override
  ProgressState build() {
    _loadProgress();
    return ProgressState(isLoaded: false);
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList(_completedKey) ?? [];
    final accuracyJson = prefs.getString(_accuracyKey) ?? '{}';
    final accuracyMap = Map<String, double>.from(
      (json.decode(accuracyJson) as Map).map((k, v) => MapEntry(k, (v as num).toDouble())),
    );
    state = ProgressState(completedLessons: completed, lessonAccuracies: accuracyMap, isLoaded: true);
  }

  Future<void> markLessonCompleted(String lessonId, {double? accuracy}) async {
    final prefs = await SharedPreferences.getInstance();
    
    final newCompleted = [...state.completedLessons];
    if (!newCompleted.contains(lessonId)) {
      newCompleted.add(lessonId);
    }
    
    final newAccuracies = Map<String, double>.from(state.lessonAccuracies);
    if (accuracy != null) {
      newAccuracies[lessonId] = accuracy;
    }
    
    await prefs.setStringList(_completedKey, newCompleted);
    await prefs.setString(_accuracyKey, json.encode(newAccuracies));
    state = ProgressState(completedLessons: newCompleted, lessonAccuracies: newAccuracies, isLoaded: true);
  }

  Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_completedKey);
    await prefs.remove(_accuracyKey);
    state = ProgressState(isLoaded: true);
  }
}
