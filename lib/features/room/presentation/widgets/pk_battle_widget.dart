import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/pk_model.dart';
import '../../data/repositories/room_state_repository.dart';
import '../providers/room_provider.dart';
import '../../../../core/services/zego_service.dart';

class PkBattleWidget extends ConsumerStatefulWidget {
  const PkBattleWidget({
    super.key,
    required this.roomId,
    required this.isHost,
    this.currentUserId,
    this.currentUserName,
    this.currentUserAvatar,
  });

  final String roomId;
  final bool isHost;
  final String? currentUserId;
  final String? currentUserName;
  final String? currentUserAvatar;

  @override
  ConsumerState<PkBattleWidget> createState() => _PkBattleWidgetState();
}

class _PkBattleWidgetState extends ConsumerState<PkBattleWidget>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startCountdown(DateTime endsAt) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final rem = endsAt.difference(DateTime.now());
      if (rem.isNegative) {
        _timer?.cancel();
        setState(() => _remaining = Duration.zero);
        if (widget.isHost) {
          final pk =
              ref.read(pkProvider(widget.roomId)).valueOrNull ?? PkModel.idle;
          if (pk.isActive) {
            RoomStateRepository().finishPk(
              widget.roomId,
              redScore: pk.redScore,
              blueScore: pk.blueScore,
            );
          }
        }
      } else {
        setState(() => _remaining = rem);
      }
    });
  }

  Future<void> _joinSeat(String side) async {
    final uid = widget.currentUserId;
    if (uid == null) return;
    final name = widget.currentUserName ?? 'مستخدم';
    final avatar = widget.currentUserAvatar;
    final repo = RoomStateRepository();
    bool joined = false;
    if (side == 'host') {
      joined = await repo.joinPkHost(
          widget.roomId, userId: uid, userName: name, userAvatar: avatar);
    } else if (side == 'red') {
      joined = await repo.joinPkRed(
          widget.roomId, userId: uid, userName: name, userAvatar: avatar);
    } else {
      joined = await repo.joinPkBlue(
          widget.roomId, userId: uid, userName: name, userAvatar: avatar);
    }
    if (joined) {
      await ZegoService().startPublishing(widget.roomId, uid);
    }
  }

  Future<void> _leaveSeat() async {
    final uid = widget.currentUserId;
    if (uid == null) return;
    await RoomStateRepository().leavePkSeat(widget.roomId, uid);
    await ZegoService().stopPublishing();
  }

  Future<void> _startBattle(int durationSecs) async {
    await RoomStateRepository().activatePk(widget.roomId, durationSecs);
  }

  Future<void> _resetBattle() async {
    await RoomStateRepository().resetPk(widget.roomId);
  }

  @override
  Widget build(BuildContext context) {
    final pk =
        ref.watch(pkProvider(widget.roomId)).valueOrNull ?? PkModel.idle;
    if (pk.isIdle) return const SizedBox.shrink();

    ref.listen(pkProvider(widget.roomId), (_, next) {
      final m = next.valueOrNull;
      if (m == null) return;
      if (m.isActive && m.endsAt != null) {
        _startCountdown(m.endsAt!);
      } else if (!m.isActive) {
        _timer?.cancel();
      }
    });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Timer pill
          if (pk.isActive) _buildTimerPill(),
          if (pk.isActive) const SizedBox(height: 6),

          // Host seat — top, centered
          Align(
            alignment: Alignment.center,
            child: _buildSeat(
              pk: pk,
              side: 'host',
              chairAsset: 'assets/pk/large_purple_gold_chair_host.png',
              chairSize: 120,
              glowColor: const Color(0xFFFFD700),
              textColor: const Color(0xFFFFD700),
              occupantId: pk.hostPlayerId,
              occupantName: pk.hostPlayerName,
              occupantAvatar: pk.hostPlayerAvatar,
            ),
          ),

          const SizedBox(height: 6),

          // Player row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSeat(
                pk: pk,
                side: 'red',
                chairAsset: 'assets/pk/small_red_chair_player1.png',
                chairSize: 96,
                glowColor: const Color(0xFFFF4444),
                textColor: Colors.white,
                occupantId: pk.redPlayerId,
                occupantName: pk.redPlayerName,
                occupantAvatar: pk.redPlayerAvatar,
                score: pk.isActive || pk.isFinished ? pk.redScore : null,
              ),
              _buildCenter(pk),
              _buildSeat(
                pk: pk,
                side: 'blue',
                chairAsset: 'assets/pk/small_blue_chair_player2.png',
                chairSize: 96,
                glowColor: const Color(0xFF4488FF),
                textColor: Colors.white,
                occupantId: pk.bluePlayerId,
                occupantName: pk.bluePlayerName,
                occupantAvatar: pk.bluePlayerAvatar,
                score: pk.isActive || pk.isFinished ? pk.blueScore : null,
              ),
            ],
          ),

          // Score bar — below all chairs, spanning full width
          if (pk.isActive || pk.isFinished) ...[
            const SizedBox(height: 8),
            _buildScoreBar(pk),
          ],

          // Winner banner
          if (pk.isFinished) _buildWinnerBanner(pk),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Timer pill ───────────────────────────────────────────────────────
  Widget _buildTimerPill() {
    final mins =
        _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs =
        _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        '⏱ $mins:$secs',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }

  // ── Individual PK seat ───────────────────────────────────────────────
  Widget _buildSeat({
    required PkModel pk,
    required String side,
    required String chairAsset,
    required double chairSize,
    required Color glowColor,
    required Color textColor,
    String? occupantId,
    String? occupantName,
    String? occupantAvatar,
    int? score,
  }) {
    final myId = widget.currentUserId;
    final isEmpty = occupantId == null;
    final isMe = myId != null && myId == occupantId;
    final canJoin = pk.isWaiting && isEmpty && myId != null;
    final canLeave = pk.isWaiting && isMe;

    final isLeading = (pk.isActive || pk.isFinished) &&
        ((side == 'red' && pk.redScore > pk.blueScore) ||
            (side == 'blue' && pk.blueScore > pk.redScore));

    // Avatar position: overlaid on the person figure in the chair image.
    // The person figure is drawn in the upper-center area of the chair.
    final avatarSize = chairSize * 0.42;
    final avatarTop = chairSize * 0.08;
    final avatarLeft = (chairSize - avatarSize) / 2;

    return GestureDetector(
      onTap: () {
        if (canJoin) {
          _joinSeat(side);
        } else if (canLeave) {
          _leaveSeat();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: chairSize,
            height: chairSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Glow behind leading player
                if (isLeading)
                  AnimatedBuilder(
                    animation: _pulseCtrl,
                    builder: (_, __) => Positioned(
                      top: chairSize * 0.22,
                      left: chairSize * 0.12,
                      right: chairSize * 0.12,
                      bottom: chairSize * 0.05,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(chairSize * 0.38),
                          boxShadow: [
                            BoxShadow(
                              color: glowColor.withAlpha(
                                  (65 + 95 * _pulseCtrl.value).toInt()),
                              blurRadius: 28,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Chair image
                Positioned.fill(
                  child: Image.asset(chairAsset, fit: BoxFit.contain),
                ),

                // Avatar / join indicator — on the person figure position
                Positioned(
                  top: avatarTop,
                  left: avatarLeft,
                  width: avatarSize,
                  height: avatarSize,
                  child: isEmpty
                      ? _emptyIndicator(canJoin, glowColor)
                      : _avatarCircle(
                          imageUrl: occupantAvatar,
                          name: occupantName,
                          size: avatarSize,
                          borderColor: isMe ? Colors.white : glowColor,
                          glowColor: glowColor,
                        ),
                ),

                // Tap-to-leave label
                if (canLeave)
                  Positioned(
                    bottom: 2,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'اضغط للخروج',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 7,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 3),

          // Name label
          SizedBox(
            width: chairSize,
            child: Text(
              isEmpty ? '' : (occupantName ?? ''),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
                shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            ),
          ),

          // Score (player seats only, when active/finished)
          if (score != null)
            Text(
              '💎 $score',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
              ),
            ),
        ],
      ),
    );
  }

  // ── Empty seat indicator ──────────────────────────────────────────────
  Widget _emptyIndicator(bool canJoin, Color glowColor) {
    if (!canJoin) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: glowColor.withAlpha(160), width: 1.5),
        color: Colors.white.withAlpha(12),
      ),
      child: Icon(Icons.add_rounded, color: glowColor.withAlpha(220)),
    );
  }

  // ── Avatar circle ─────────────────────────────────────────────────────
  Widget _avatarCircle({
    String? imageUrl,
    String? name,
    required double size,
    required Color borderColor,
    required Color glowColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: ClipOval(
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: glowColor.withAlpha(50)),
                errorWidget: (_, __, ___) =>
                    _defaultAvatar(name, glowColor, size),
              )
            : _defaultAvatar(name, glowColor, size),
      ),
    );
  }

  Widget _defaultAvatar(String? name, Color color, double size) {
    final letter =
        (name != null && name.isNotEmpty) ? name[0].toUpperCase() : '?';
    return Container(
      color: color.withAlpha(55),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: color,
            fontSize: size * 0.38,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ── Score bar ─────────────────────────────────────────────────────────
  Widget _buildScoreBar(PkModel pk) {
    final redFlex = (pk.redPct * 100).round().clamp(1, 99);
    final blueFlex = 100 - redFlex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          height: 14,
          child: Row(
            children: [
              Expanded(
                flex: redFlex,
                child: Container(
                  color: const Color(0xFFFF4444),
                  alignment: Alignment.center,
                  child: Text(
                    '$redFlex%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: blueFlex,
                child: Container(
                  color: const Color(0xFF4488FF),
                  alignment: Alignment.center,
                  child: Text(
                    '$blueFlex%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Center section ────────────────────────────────────────────────────
  Widget _buildCenter(PkModel pk) {
    if (pk.isFinished) return const SizedBox(width: 44);

    if (pk.isActive) {
      return SizedBox(
        width: 50,
        child: AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, __) => ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFFFF4444), Color(0xFFFFDD00), Color(0xFF4488FF)],
            ).createShader(r),
            child: Text(
              'VS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20 + 4 * _pulseCtrl.value,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      );
    }

    // Waiting — any user can start once both player seats are filled
    final canStart = pk.redPlayerId != null && pk.bluePlayerId != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          '⚔️',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22),
        ),
        if (canStart) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _startBattle(pk.durationSecs),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x9922C55E),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Text(
                'ابدأ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ] else ...[
          const Text(
            'PK',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ],
    );
  }

  // ── Winner banner ─────────────────────────────────────────────────────
  Widget _buildWinnerBanner(PkModel pk) {
    final String label;
    final Color color;
    if (pk.winnerId == 'red') {
      label = '🏆 الفائز: ${pk.redPlayerName ?? 'الفريق الأحمر'}';
      color = const Color(0xFFFF4444);
    } else if (pk.winnerId == 'blue') {
      label = '🏆 الفائز: ${pk.bluePlayerName ?? 'الفريق الأزرق'}';
      color = const Color(0xFF4488FF);
    } else {
      label = '🤝 تعادل!';
      color = const Color(0xFFFFD700);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withAlpha(200), width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              fontFamily: 'Cairo',
              shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
        ),
        if (widget.isHost) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _resetBattle,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white30),
              ),
              child: const Text(
                'إعادة المباراة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
