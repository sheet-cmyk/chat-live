class PKState {
  final bool active;
  final DateTime? endTime;
  final int teamA;
  final int teamB;

  const PKState({
    required this.active,
    this.endTime,
    this.teamA = 0,
    this.teamB = 0,
  });

  bool get timeUp => endTime != null && DateTime.now().isAfter(endTime!);

  /// 0.0–1.0 fraction for Team A in the progress bar
  double get teamAFraction {
    final total = teamA + teamB;
    if (total == 0) return 0.5;
    return (teamA / total).clamp(0.0, 1.0);
  }
}
