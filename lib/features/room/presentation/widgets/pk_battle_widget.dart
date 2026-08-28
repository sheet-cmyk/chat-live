import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/pk_model.dart';
import '../../data/repositories/room_state_repository.dart';
import '../providers/room_provider.dart';

// ── ألوان الفريقين ─────────────────────────────────────────────────────────
const _kRedGlow  = Color(0xFFCC0000);
const _kRedText  = Color(0xFFFF5555);
const _kBlueGlow = Color(0xFF0022CC);
const _kBlueText = Color(0xFF5599FF);

// ═══════════════════════════════════════════════════════════════════════════
//  PkBattleWidget — يظهر فوق شبكة المقاعد عند تفعيل PK
// ═══════════════════════════════════════════════════════════════════════════
class PkBattleWidget extends ConsumerStatefulWidget {
  const PkBattleWidget({
    super.key,
    required this.roomId,
    required this.isHost,
    this.currentUserId,
    this.currentUserName,
    this.currentUserAvatar,
    this.hostName,
    this.hostAvatar,
  });

  final String  roomId;
  final bool    isHost;
  final String? currentUserId;
  final String? currentUserName;
  final String? currentUserAvatar;
  final String? hostName;
  final String? hostAvatar;

  @override
  ConsumerState<PkBattleWidget> createState() => _PkBattleWidgetState();
}

class _PkBattleWidgetState extends ConsumerState<PkBattleWidget>
    with SingleTickerProviderStateMixin {
  Timer?   _timer;
  Duration _remaining = Duration.zero;
  late AnimationController _vsCtrl;

  @override
  void initState() {
    super.initState();
    _vsCtrl = AnimationController(vsync: this, duration: 900.ms)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _vsCtrl.dispose();
    super.dispose();
  }

  void _startCountdown(DateTime endsAt) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final rem = endsAt.difference(DateTime.now());
      setState(() => _remaining = rem.isNegative ? Duration.zero : rem);
      if (rem.inSeconds <= 0) {
        _timer?.cancel();
        final pk = ref.read(pkProvider(widget.roomId)).valueOrNull;
        if (pk != null && pk.isActive) {
          RoomStateRepository().finishPk(
            widget.roomId,
            redScore:  pk.redScore,
            blueScore: pk.blueScore,
          );
        }
      }
    });
  }

  String get _timerLabel {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pk = ref.watch(pkProvider(widget.roomId)).valueOrNull ?? PkModel.idle;

    // react to PK state changes for timer
    ref.listen<AsyncValue<PkModel>>(pkProvider(widget.roomId), (_, next) {
      final p = next.valueOrNull;
      if (p == null) return;
      if (p.isActive && p.endsAt != null) {
        final rem = p.endsAt!.difference(DateTime.now());
        if (rem.inSeconds != _remaining.inSeconds) {
          _startCountdown(p.endsAt!);
        }
      } else if (!p.isActive) {
        _timer?.cancel();
      }
    });

    if (pk.isIdle) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C0035), Color(0xFF0B0018)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF7B1FA2).withAlpha(70),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── شريط العنوان: PK + Timer ──────────────────────────────
          _buildHeader(pk),
          const SizedBox(height: 8),

          // ── شريط النتائج ──────────────────────────────────────────
          if (pk.isActive || pk.isFinished) ...[
            _buildScoreBar(pk),
            const SizedBox(height: 10),
          ],

          // ── مقعد المضيف الكبير (أعلى الوسط) ─────────────────────
          _buildHostChair(),
          const SizedBox(height: 8),

          // ── مقعدا اللاعبين (أسفل) ────────────────────────────────
          _buildPlayersRow(pk),

          // ── لافتة الفائز ─────────────────────────────────────────
          if (pk.isFinished && pk.winnerId != null) ...[
            const SizedBox(height: 8),
            _buildWinnerBanner(pk),
          ],
        ],
      ),
    );
  }

  // ── رأس الـ PK (شريط الوقت) ─────────────────────────────────────────────
  Widget _buildHeader(PkModel pk) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // PK label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B0000), Color(0xFF0000CD)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'PK',
            style: TextStyle(
              color: Colors.white, fontSize: 11,
              fontWeight: FontWeight.w900, letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Timer / Status
        if (pk.isActive)
          Text(
            _timerLabel,
            style: const TextStyle(
              color: Colors.white, fontSize: 14,
              fontWeight: FontWeight.w800, letterSpacing: 1.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          )
        else if (pk.isWaiting)
          const Text(
            'انتظار اللاعبين',
            style: TextStyle(
              color: Colors.white60, fontSize: 12,
              fontWeight: FontWeight.w600, fontFamily: 'Cairo',
            ),
          )
        else if (pk.isFinished)
          const Text(
            'انتهت المباراة',
            style: TextStyle(
              color: Colors.white60, fontSize: 12,
              fontWeight: FontWeight.w600, fontFamily: 'Cairo',
            ),
          ),

        // زر إنهاء (للمضيف فقط في الحالات النشطة)
        if (widget.isHost && (pk.isWaiting || pk.isActive)) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _confirmEnd(pk),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withAlpha(80)),
              ),
              child: const Text(
                'إنهاء',
                style: TextStyle(
                  color: Color(0xFFFF5C5C), fontSize: 10,
                  fontWeight: FontWeight.w700, fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── شريط النتائج ─────────────────────────────────────────────────────────
  Widget _buildScoreBar(PkModel pk) {
    return Column(
      children: [
        // الشريط
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 11,
            child: LayoutBuilder(builder: (_, c) {
              final w = c.maxWidth;
              return Stack(children: [
                // خلفية
                Container(color: const Color(0xFF0000CD)),
                // حصة الأحمر
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  width: w * pk.redPct,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B0000), Color(0xFFDD2200)],
                    ),
                  ),
                ),
                // خط الوسط
                Positioned(
                  left: w / 2 - 1,
                  child: Container(width: 2, height: 11, color: Colors.white38),
                ),
              ]);
            }),
          ),
        ),
        const SizedBox(height: 4),
        // الأرقام
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${pk.redScore} 💎',
              style: const TextStyle(
                color: _kRedText, fontSize: 11, fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '💎 ${pk.blueScore}',
              style: const TextStyle(
                color: _kBlueText, fontSize: 11, fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── مقعد المضيف الكبير ────────────────────────────────────────────────────
  Widget _buildHostChair() {
    return SizedBox(
      width: 90,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // الصورة الكبيرة
              Image.asset(
                'assets/pk/large_purple_gold_chair_host.png',
                width: 80, height: 80,
                fit: BoxFit.contain,
              ),
              // أفاتار المضيف إذا وجد
              if (widget.hostAvatar != null)
                Positioned(
                  bottom: 6,
                  child: _Avatar(
                    imageUrl: widget.hostAvatar,
                    size: 28,
                    borderColor: const Color(0xFFFFD700),
                  ),
                ),
            ],
          ),
          if (widget.hostName != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                widget.hostName!,
                style: const TextStyle(
                  color: Color(0xFFFFD700), fontSize: 10,
                  fontWeight: FontWeight.w700, fontFamily: 'Cairo',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // ── صف اللاعبين ──────────────────────────────────────────────────────────
  Widget _buildPlayersRow(PkModel pk) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // اللاعب الأحمر
        Expanded(
          child: _buildPlayerCard(
            pk: pk,
            side: 'red',
            chairAsset: 'assets/pk/small_red_chair_player1.png',
            glowColor: _kRedGlow,
            labelColor: _kRedText,
            playerId: pk.redPlayerId,
            playerName: pk.redPlayerName,
            playerAvatar: pk.redPlayerAvatar,
            score: pk.redScore,
            isLeading: pk.isActive && pk.redScore > pk.blueScore,
          ),
        ),

        // وسط: CFN / VS
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _buildVsCenter(pk),
        ),

        // اللاعب الأزرق
        Expanded(
          child: _buildPlayerCard(
            pk: pk,
            side: 'blue',
            chairAsset: 'assets/pk/small_blue_chair_player2.png',
            glowColor: _kBlueGlow,
            labelColor: _kBlueText,
            playerId: pk.bluePlayerId,
            playerName: pk.bluePlayerName,
            playerAvatar: pk.bluePlayerAvatar,
            score: pk.blueScore,
            isLeading: pk.isActive && pk.blueScore > pk.redScore,
          ),
        ),
      ],
    );
  }

  // ── بطاقة اللاعب ─────────────────────────────────────────────────────────
  Widget _buildPlayerCard({
    required PkModel pk,
    required String side,
    required String chairAsset,
    required Color glowColor,
    required Color labelColor,
    String? playerId,
    String? playerName,
    String? playerAvatar,
    required int score,
    required bool isLeading,
  }) {
    final isEmpty = playerId == null;
    final myId = widget.currentUserId;
    final otherSideId = side == 'red' ? pk.bluePlayerId : pk.redPlayerId;
    final canJoin = pk.isWaiting && isEmpty && myId != null && myId != otherSideId;
    final isMe = myId != null && myId == playerId;
    final canLeave = pk.isWaiting && isMe;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // مقعد + أفاتار + توهج
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // توهج خلف المقعد عندما يكون رائداً
            if (isLeading)
              Positioned(
                child: Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withAlpha(140),
                        blurRadius: 28,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),

            // صورة الكرسي
            Image.asset(
              chairAsset,
              width: 60, height: 60,
              fit: BoxFit.contain,
            )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(
              duration: isLeading ? 1200.ms : 3000.ms,
              color: glowColor.withAlpha(isLeading ? 120 : 30),
            ),

            // أفاتار اللاعب
            if (playerAvatar != null)
              Positioned(
                bottom: 0,
                child: _Avatar(
                  imageUrl: playerAvatar,
                  size: 26,
                  borderColor: glowColor,
                ),
              ),

            // زر الانضمام (مقعد فارغ في وضع الانتظار)
            if (canJoin)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => _joinChair(side),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(140),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, color: glowColor, size: 22),
                        Text(
                          'انضم',
                          style: TextStyle(
                            color: glowColor, fontSize: 9,
                            fontWeight: FontWeight.w800, fontFamily: 'Cairo',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 4),

        // اسم اللاعب
        Text(
          playerName ?? (isEmpty ? '─' : ''),
          style: TextStyle(
            color: isEmpty ? Colors.white24 : labelColor,
            fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Cairo',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),

        // نقاط
        if (pk.isActive || pk.isFinished) ...[
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: glowColor.withAlpha(35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$score 💎',
              style: TextStyle(
                color: labelColor, fontSize: 10, fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],

        // زر مغادرة (صاحب المقعد في وضع الانتظار)
        if (canLeave)
          GestureDetector(
            onTap: () => RoomStateRepository().leavePkChair(widget.roomId, side),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'مغادرة',
                style: TextStyle(
                  color: Colors.white30, fontSize: 9,
                  fontFamily: 'Cairo',
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white30,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── وسط VS / CFN ─────────────────────────────────────────────────────────
  Widget _buildVsCenter(PkModel pk) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // CFN — تدرج متحرك
        AnimatedBuilder(
          animation: _vsCtrl,
          builder: (_, __) {
            final t = _vsCtrl.value;
            return ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Color.lerp(const Color(0xFFFF5555), const Color(0xFFFFD700), t)!,
                  Color.lerp(const Color(0xFFFFD700), const Color(0xFF5599FF), t)!,
                ],
              ).createShader(bounds),
              child: const Text(
                'CFN',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13, fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 2),

        // VS
        Text(
          'VS',
          style: const TextStyle(
            color: Colors.white38, fontSize: 9,
            fontWeight: FontWeight.w900, letterSpacing: 2,
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .scale(duration: 700.ms, begin: const Offset(1, 1), end: const Offset(1.2, 1.2))
        .then()
        .scale(duration: 700.ms, begin: const Offset(1.2, 1.2), end: const Offset(1, 1)),

        const SizedBox(height: 8),

        // زر "ابدأ" (مضيف فقط / الحالة waiting / اللاعبان موجودان)
        if (widget.isHost && pk.isWaiting)
          GestureDetector(
            onTap: () => _activatePk(pk),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6A0DAD), Color(0xFFAB2FFF)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ابدأ',
                style: TextStyle(
                  color: Colors.white, fontSize: 10,
                  fontWeight: FontWeight.w800, fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── لافتة الفائز ──────────────────────────────────────────────────────────
  Widget _buildWinnerBanner(PkModel pk) {
    final isDraw    = pk.winnerId == 'draw';
    final isRedWin  = pk.winnerId == 'red';
    final name      = isDraw ? 'تعادل' : (isRedWin ? pk.redPlayerName : pk.bluePlayerName) ?? '─';
    final color     = isDraw ? Colors.amber : (isRedWin ? _kRedText : _kBlueText);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(45), color.withAlpha(20)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Column(
        children: [
          Text(
            isDraw ? '🤝 تعادل!' : '🏆 الفائز',
            style: const TextStyle(
              color: Colors.white60, fontSize: 11, fontFamily: 'Cairo',
            ),
          ),
          Text(
            name,
            style: TextStyle(
              color: color, fontSize: 17,
              fontWeight: FontWeight.w900, fontFamily: 'Cairo',
            ),
          ),
          if (widget.isHost) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => RoomStateRepository().resetPk(widget.roomId),
              child: const Text(
                'إعادة التعيين',
                style: TextStyle(
                  color: Colors.white30, fontSize: 10, fontFamily: 'Cairo',
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white30,
                ),
              ),
            ),
          ],
        ],
      ),
    )
    .animate()
    .fadeIn(duration: 500.ms)
    .scale(
      duration: 500.ms,
      begin: const Offset(0.9, 0.9),
      end: const Offset(1, 1),
    );
  }

  // ── تفعيل المباراة ────────────────────────────────────────────────────────
  Future<void> _activatePk(PkModel pk) async {
    if (pk.redPlayerId == null || pk.bluePlayerId == null) {
      _snack('يجب أن ينضم لاعبان أولاً');
      return;
    }
    await RoomStateRepository().activatePk(widget.roomId, pk.durationSecs);
    _startCountdown(DateTime.now().add(Duration(seconds: pk.durationSecs)));
  }

  // ── الانضمام إلى كرسي ─────────────────────────────────────────────────────
  Future<void> _joinChair(String side) async {
    if (widget.currentUserId == null) return;
    bool ok;
    if (side == 'red') {
      ok = await RoomStateRepository().joinPkRed(
        widget.roomId,
        userId:     widget.currentUserId!,
        userName:   widget.currentUserName ?? 'مستخدم',
        userAvatar: widget.currentUserAvatar,
      );
    } else {
      ok = await RoomStateRepository().joinPkBlue(
        widget.roomId,
        userId:     widget.currentUserId!,
        userName:   widget.currentUserName ?? 'مستخدم',
        userAvatar: widget.currentUserAvatar,
      );
    }
    if (mounted && !ok) _snack('المقعد مشغول');
  }

  // ── تأكيد الإنهاء ─────────────────────────────────────────────────────────
  void _confirmEnd(PkModel pk) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C0035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('إنهاء PK؟',
            style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
        content: const Text('سيتم احتساب النتيجة الحالية.',
            style: TextStyle(color: Colors.white60, fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (pk.isWaiting) {
                RoomStateRepository().resetPk(widget.roomId);
              } else {
                RoomStateRepository().finishPk(
                  widget.roomId,
                  redScore:  pk.redScore,
                  blueScore: pk.blueScore,
                );
              }
            },
            child: const Text('إنهاء', style: TextStyle(color: Color(0xFFFF5555), fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: const Color(0xFFAA0000),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── أفاتار دائري ──────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({this.imageUrl, required this.size, required this.borderColor});
  final String? imageUrl;
  final double  size;
  final Color   borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
        color: Colors.black38,
      ),
      child: ClipOval(
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.person_rounded,
                  color: Colors.white38,
                  size: 14,
                ),
              )
            : const Icon(Icons.person_rounded, color: Colors.white38, size: 14),
      ),
    );
  }
}
