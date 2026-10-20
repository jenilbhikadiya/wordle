import 'dart:convert';

import 'package:flutter/services.dart';

/// Loads the bundled word lists once and keeps them in memory.
class WordRepository {
  WordRepository._();
  static final instance = WordRepository._();

  static const _names = {4: 'four', 5: 'five', 6: 'six'};

  final Map<int, Set<String>> _dictionaries = {};
  final Map<int, List<String>> _answers = {};
  List<String>? _daily;

  static const supportedLengths = [4, 5, 6];

  Future<List<String>> _loadList(String path) async {
    final raw = await rootBundle.loadString(path);
    final List<dynamic> arr = json.decode(raw);
    return arr.map((e) => e.toString().toLowerCase()).toList();
  }

  /// Common words that make good answers for unlimited play.
  Future<List<String>> answers(int length) async {
    return _answers[length] ??= await _loadList(
      'assets/easy_words_json/${_names[length]}_name_word.json',
    );
  }

  /// Every word accepted as a guess.
  Future<Set<String>> dictionary(int length) async {
    final cached = _dictionaries[length];
    if (cached != null) return cached;
    final all = await _loadList(
      'assets/all_english_words/${_names[length]}_name_word.json',
    );
    final daily = (await dailySchedule()).where((w) => w.length == length);
    return _dictionaries[length] = {...all, ...await answers(length), ...daily};
  }

  /// The daily schedule in day order, so index 0 is day 1. Each entry in the
  /// asset also records its date, so every player sees the same word.
  Future<List<String>> dailySchedule() async {
    final cached = _daily;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/daily_words.json');
    final entries = (json.decode(raw) as List).cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['day'] as int).compareTo(b['day'] as int));
    return _daily = entries
        .map((e) => e['word'].toString().toLowerCase())
        .toList();
  }
}
