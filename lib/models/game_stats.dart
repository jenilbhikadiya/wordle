/// Results for one word length: wins, streaks and guess distribution.
class GameStats {
  int played;
  int wins;
  int currentStreak;
  int maxStreak;
  // distribution[i] is the number of wins that took i + 1 guesses.
  List<int> distribution;

  GameStats({
    this.played = 0,
    this.wins = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    List<int>? distribution,
  }) : distribution = distribution ?? List<int>.filled(6, 0);

  int get winPercent => played == 0 ? 0 : (wins * 100 / played).round();

  void record({required bool won, required int attempts}) {
    played++;
    if (won) {
      wins++;
      currentStreak++;
      if (currentStreak > maxStreak) maxStreak = currentStreak;
      if (attempts >= 1 && attempts <= distribution.length) {
        distribution[attempts - 1]++;
      }
    } else {
      currentStreak = 0;
    }
  }

  Map<String, dynamic> toJson() => {
    'played': played,
    'wins': wins,
    'currentStreak': currentStreak,
    'maxStreak': maxStreak,
    'distribution': distribution,
  };

  factory GameStats.fromJson(Map<String, dynamic> json) {
    final dist =
        (json['distribution'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        <int>[];
    return GameStats(
      played: json['played'] ?? 0,
      wins: json['wins'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      maxStreak: json['maxStreak'] ?? 0,
      distribution: List<int>.generate(6, (i) => i < dist.length ? dist[i] : 0),
    );
  }
}
