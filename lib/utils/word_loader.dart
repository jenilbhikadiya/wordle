import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WordLoader {
  // Load all words (for validation)
  static Future<List<String>> loadWords(int length) async {
    final path = length == 4
        ? 'assets/all_english_words/four_name_word.json'
        : length == 5
        ? 'assets/all_english_words/five_name_word.json'
        : 'assets/all_english_words/six_name_word.json';
    final raw = await rootBundle.loadString(path);
    final List<dynamic> arr = json.decode(raw);
    return arr.map((e) => e.toString().toLowerCase()).toList();
  }

  // Daily puzzle schedule: 2000 mixed-length words, each with its day number
  // and date. Returned in day order, so index 0 is day 1.
  static Future<List<String>> loadDailyWords() async {
    final raw = await rootBundle.loadString('assets/daily_words.json');
    final List<dynamic> arr = json.decode(raw);
    final entries = arr.cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));
    return entries.map((e) => e['word'].toString().toLowerCase()).toList();
  }

  // Load easy words (for target selection)
  static Future<List<String>> loadEasyWords(int length) async {
    final path = length == 4
        ? 'assets/easy_words_json/four_name_word.json'
        : length == 5
        ? 'assets/easy_words_json/five_name_word.json'
        : 'assets/easy_words_json/six_name_word.json';
    final raw = await rootBundle.loadString(path);
    final List<dynamic> arr = json.decode(raw);
    return arr.map((e) => e.toString().toLowerCase()).toList();
  }
}

class PointsService {
  static const String _pointsKey = 'points_total';

  static Future<int> getPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pointsKey) ?? 0;
  }

  static Future<int> addPoints(int delta) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_pointsKey) ?? 0;
    final updated = current + delta;
    await prefs.setInt(_pointsKey, updated);
    return updated;
  }

  static int pointsForLength(int length) {
    switch (length) {
      case 4:
        return 5;
      case 5:
        return 6;
      case 6:
        return 7;
      default:
        return 5;
    }
  }
}
