import 'metrics_engine.dart';

class LeaderboardWeights {
  const LeaderboardWeights({
    this.volume = 0.5,
    this.balance = 0.2,
    this.speed = 0.3,
  });

  /// Share of the busiest chat's message count.
  final double volume;

  /// How even the sent/received split is.
  final double balance;

  /// How quickly both sides reply (30 min median scores 0.5).
  final double speed;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.stats,
    required this.score,
  });

  final int rank;
  final ContactStats stats;

  /// 0.0 to 1.0 with the default weights.
  final double score;
}

/// Ranks chats by a weighted blend of volume, balance and reply speed.
List<LeaderboardEntry> buildLeaderboard(
  List<ContactStats> all, {
  LeaderboardWeights weights = const LeaderboardWeights(),
}) {
  if (all.isEmpty) return const [];
  final maxTotal = all.map((s) => s.total).reduce((a, b) => a > b ? a : b);

  double speedScore(ContactStats s) {
    final minutes = <double>[
      if (s.myMedianResponse != null) s.myMedianResponse!.inSeconds / 60,
      if (s.theirMedianResponse != null) s.theirMedianResponse!.inSeconds / 60,
    ];
    if (minutes.isEmpty) return 0;
    final avg = minutes.reduce((a, b) => a + b) / minutes.length;
    return 1 / (1 + avg / 30);
  }

  final scored = [
    for (final s in all)
      (
        stats: s,
        score: weights.volume * (maxTotal == 0 ? 0 : s.total / maxTotal) +
            weights.balance * s.balance +
            weights.speed * speedScore(s),
      ),
  ]..sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : b.stats.total.compareTo(a.stats.total);
    });

  return [
    for (var i = 0; i < scored.length; i++)
      LeaderboardEntry(
          rank: i + 1, stats: scored[i].stats, score: scored[i].score),
  ];
}
