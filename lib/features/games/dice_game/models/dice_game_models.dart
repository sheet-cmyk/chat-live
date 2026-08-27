import 'package:cloud_firestore/cloud_firestore.dart';

// ── Phase enum ───────────────────────────────────────────────────────────────
enum DiceRoundPhase { betting, rolling, result }

DiceRoundPhase _parsePhase(String? s) {
  switch (s) {
    case 'rolling': return DiceRoundPhase.rolling;
    case 'result':  return DiceRoundPhase.result;
    default:        return DiceRoundPhase.betting;
  }
}

// ── Bet type ─────────────────────────────────────────────────────────────────
enum DiceBetType { small, big, triple }

extension DiceBetTypeX on DiceBetType {
  String get key {
    switch (this) {
      case DiceBetType.small:  return 'small';
      case DiceBetType.big:    return 'big';
      case DiceBetType.triple: return 'triple';
    }
  }

  String get label {
    switch (this) {
      case DiceBetType.small:  return 'صغير';
      case DiceBetType.big:    return 'كبير';
      case DiceBetType.triple: return 'ثلاثية';
    }
  }

  int get multiplier {
    switch (this) {
      case DiceBetType.small:  return 2;
      case DiceBetType.big:    return 2;
      case DiceBetType.triple: return 30;
    }
  }
}

DiceBetType? parseBetType(String? s) {
  switch (s) {
    case 'small':  return DiceBetType.small;
    case 'big':    return DiceBetType.big;
    case 'triple': return DiceBetType.triple;
    default:       return null;
  }
}

// ── Dice result calculation (mirrors server logic) ────────────────────────────
DiceBetType calcWinner(int d1, int d2, int d3) {
  if (d1 == d2 && d2 == d3) return DiceBetType.triple;
  final t = d1 + d2 + d3;
  return t <= 10 ? DiceBetType.small : DiceBetType.big;
}

// ── Current round ─────────────────────────────────────────────────────────────
class DiceRound {
  final String    roomId;
  final int       roundId;
  final DiceRoundPhase phase;
  final DateTime  bettingStartedAt;
  final DateTime  bettingEndsAt;
  final DateTime? rollingStartedAt;
  final DateTime? resultAt;
  final List<int> dice;
  final int?      total;
  final DiceBetType? winner;
  final int       smallBets;
  final int       bigBets;
  final int       tripleBets;
  final List<DiceHistoryEntry> lastResults;

  const DiceRound({
    required this.roomId,
    required this.roundId,
    required this.phase,
    required this.bettingStartedAt,
    required this.bettingEndsAt,
    this.rollingStartedAt,
    this.resultAt,
    required this.dice,
    this.total,
    this.winner,
    required this.smallBets,
    required this.bigBets,
    required this.tripleBets,
    required this.lastResults,
  });

  int secsRemaining() {
    final endsAt = bettingStartedAt.add(const Duration(seconds: 16));
    final rem    = endsAt.difference(DateTime.now()).inSeconds;
    return rem.clamp(0, 16);
  }

  factory DiceRound.fromMap(String roomId, Map<String, dynamic> d) {
    DateTime? parseOptTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }
    DateTime parseTs(dynamic v) {
      if (v is Timestamp) return v.toDate();
      return DateTime.now();
    }

    final rawDice    = (d['dice'] as List<dynamic>?) ?? [];
    final dice       = rawDice.map((e) => (e as num).toInt()).toList();
    final rawResults = (d['lastResults'] as List<dynamic>?) ?? [];
    final results    = rawResults
        .map((e) => DiceHistoryEntry.fromMap(e as Map<String, dynamic>))
        .toList();

    return DiceRound(
      roomId:           roomId,
      roundId:          (d['roundId'] as num?)?.toInt() ?? 1,
      phase:            _parsePhase(d['phase'] as String?),
      bettingStartedAt: parseTs(d['bettingStartedAt']),
      bettingEndsAt:    parseTs(d['bettingEndsAt']),
      rollingStartedAt: parseOptTs(d['rollingStartedAt']),
      resultAt:         parseOptTs(d['resultAt']),
      dice:             dice,
      total:            (d['total'] as num?)?.toInt(),
      winner:           parseBetType(d['winner'] as String?),
      smallBets:        (d['smallBets'] as num?)?.toInt() ?? 0,
      bigBets:          (d['bigBets'] as num?)?.toInt() ?? 0,
      tripleBets:       (d['tripleBets'] as num?)?.toInt() ?? 0,
      lastResults:      results,
    );
  }
}

// ── User's bet for the current round ─────────────────────────────────────────
class DiceBet {
  final int  small;
  final int  big;
  final int  triple;
  final bool paid;
  final int  winAmount;
  final int? roundId;   // which round this bet belongs to

  const DiceBet({
    this.small     = 0,
    this.big       = 0,
    this.triple    = 0,
    this.paid      = false,
    this.winAmount = 0,
    this.roundId,
  });

  int get total => small + big + triple;
  int amountFor(DiceBetType t) {
    switch (t) {
      case DiceBetType.small:  return small;
      case DiceBetType.big:    return big;
      case DiceBetType.triple: return triple;
    }
  }

  factory DiceBet.fromMap(Map<String, dynamic> d) => DiceBet(
    small:     (d['small']    as num?)?.toInt() ?? 0,
    big:       (d['big']      as num?)?.toInt() ?? 0,
    triple:    (d['triple']   as num?)?.toInt() ?? 0,
    paid:      d['paid']      as bool? ?? false,
    winAmount: (d['winAmount'] as num?)?.toInt() ?? 0,
    roundId:   (d['roundId']  as num?)?.toInt(),
  );
}

// ── History entry ─────────────────────────────────────────────────────────────
class DiceHistoryEntry {
  final int roundId;
  final List<int> dice;
  final int total;
  final DiceBetType winner;

  const DiceHistoryEntry({
    required this.roundId,
    required this.dice,
    required this.total,
    required this.winner,
  });

  factory DiceHistoryEntry.fromMap(Map<String, dynamic> d) {
    final rawDice = (d['dice'] as List<dynamic>?) ?? [1, 1, 1];
    return DiceHistoryEntry(
      roundId: (d['roundId'] as num?)?.toInt() ?? 0,
      dice:    rawDice.map((e) => (e as num).toInt()).toList(),
      total:   (d['total'] as num?)?.toInt() ?? 3,
      winner:  parseBetType(d['winner'] as String?) ?? DiceBetType.small,
    );
  }

  Map<String, dynamic> toMap() => {
    'roundId': roundId,
    'dice':    dice,
    'total':   total,
    'winner':  winner.key,
  };
}

// ── Top player ────────────────────────────────────────────────────────────────
class DiceTopPlayer {
  final String  userId;
  final String  userName;
  final String? avatar;
  final int     totalWagered;

  const DiceTopPlayer({
    required this.userId,
    required this.userName,
    this.avatar,
    required this.totalWagered,
  });

  factory DiceTopPlayer.fromMap(Map<String, dynamic> d) => DiceTopPlayer(
    userId:       d['userId'] as String? ?? '',
    userName:     d['userName'] as String? ?? 'مستخدم',
    avatar:       d['avatar'] as String?,
    totalWagered: (d['totalWagered'] as num?)?.toInt() ?? 0,
  );
}
