import 'package:cloud_firestore/cloud_firestore.dart';

enum PkStatus { idle, waiting, active, finished }

class PkModel {
  const PkModel({
    this.status = PkStatus.idle,
    this.hostPlayerId,
    this.hostPlayerName,
    this.hostPlayerAvatar,
    this.redPlayerId,
    this.redPlayerName,
    this.redPlayerAvatar,
    this.bluePlayerId,
    this.bluePlayerName,
    this.bluePlayerAvatar,
    this.redScore = 0,
    this.blueScore = 0,
    this.endsAt,
    this.winnerId,
    this.durationSecs = 300,
  });

  final PkStatus status;

  final String? hostPlayerId;
  final String? hostPlayerName;
  final String? hostPlayerAvatar;

  final String? redPlayerId;
  final String? redPlayerName;
  final String? redPlayerAvatar;

  final String? bluePlayerId;
  final String? bluePlayerName;
  final String? bluePlayerAvatar;

  final int      redScore;
  final int      blueScore;
  final DateTime? endsAt;
  final String?  winnerId;    // 'red' | 'blue' | 'draw'
  final int      durationSecs;

  bool get isIdle     => status == PkStatus.idle;
  bool get isWaiting  => status == PkStatus.waiting;
  bool get isActive   => status == PkStatus.active;
  bool get isFinished => status == PkStatus.finished;
  bool get isVisible  => !isIdle;

  int    get total   => redScore + blueScore;
  double get redPct  => total == 0 ? 0.5 : redScore / total;
  double get bluePct => total == 0 ? 0.5 : blueScore / total;

  /// Returns 'host' | 'red' | 'blue' | null for this userId
  String? seatFor(String userId) {
    if (hostPlayerId == userId) return 'host';
    if (redPlayerId  == userId) return 'red';
    if (bluePlayerId == userId) return 'blue';
    return null;
  }

  factory PkModel.fromDoc(Map<String, dynamic> d) {
    final statusStr = d['pkStatus'] as String? ?? 'idle';
    return PkModel(
      status: PkStatus.values.firstWhere(
        (e) => e.name == statusStr,
        orElse: () => PkStatus.idle,
      ),
      hostPlayerId:     d['pkHostPlayerId']     as String?,
      hostPlayerName:   d['pkHostPlayerName']   as String?,
      hostPlayerAvatar: d['pkHostPlayerAvatar'] as String?,
      redPlayerId:      d['pkRedPlayerId']      as String?,
      redPlayerName:    d['pkRedPlayerName']    as String?,
      redPlayerAvatar:  d['pkRedPlayerAvatar']  as String?,
      bluePlayerId:     d['pkBluePlayerId']     as String?,
      bluePlayerName:   d['pkBluePlayerName']   as String?,
      bluePlayerAvatar: d['pkBluePlayerAvatar'] as String?,
      redScore:     (d['pkRedScore']     as num?)?.toInt() ?? 0,
      blueScore:    (d['pkBlueScore']    as num?)?.toInt() ?? 0,
      endsAt:       (d['pkEndsAt']       as Timestamp?)?.toDate(),
      winnerId:      d['pkWinnerId']      as String?,
      durationSecs: (d['pkDurationSecs'] as num?)?.toInt() ?? 300,
    );
  }

  static const idle = PkModel();
}
