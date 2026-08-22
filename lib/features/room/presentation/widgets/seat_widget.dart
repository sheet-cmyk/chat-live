import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/chat_colors.dart';
import '../../data/models/seat_model.dart';

// حامل لتفعيل إيموجي جديد حتى عند تكرار نفس الإيموجي
class EmojiTrigger {
  EmojiTrigger(this.emoji);
  final String emoji;
  final int _id = _counter++;
  static int _counter = 0;
  int get id => _id;
}

class SeatWidget extends StatefulWidget {
  const SeatWidget({
    super.key,
    required this.seat,
    required this.isHost,
    this.isMe = false,
    this.onTap,
    this.emojiTrigger,
    this.challengeActive = false,
    this.pkTeam = 0, // 0=none  1=Team A (orange)  2=Team B (blue)
  });

  final SeatModel seat;
  final bool isHost;
  final bool isMe;
  final VoidCallback? onTap;
  final EmojiTrigger? emojiTrigger;
  final bool challengeActive;
  final int pkTeam;

  @override
  State<SeatWidget> createState() => _SeatWidgetState();
}

class _SeatWidgetState extends State<SeatWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  AnimationController? _emojiCtrl;
  Animation<double>? _emojiSlide;
  Animation<double>? _emojiFade;
  String? _currentEmoji;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant SeatWidget old) {
    super.didUpdateWidget(old);
    final trigger = widget.emojiTrigger;
    if (trigger != null && trigger.id != old.emojiTrigger?.id) {
      _triggerEmoji(trigger.emoji);
    }
  }

  void _triggerEmoji(String emoji) {
    _emojiCtrl?.dispose();
    _emojiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _emojiSlide = Tween<double>(begin: 0.0, end: -60.0).animate(
      CurvedAnimation(parent: _emojiCtrl!, curve: Curves.easeOut),
    );
    _emojiFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _emojiCtrl!, curve: const Interval(0.5, 1.0)),
    );
    setState(() => _currentEmoji = emoji);
    _emojiCtrl!.forward().then((_) {
      if (mounted) setState(() => _currentEmoji = null);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _emojiCtrl?.dispose();
    super.dispose();
  }

  static const _kTeamA = Color(0xFFFF6B35);
  static const _kTeamB = Color(0xFF4FC3F7);

  Color get _pkColor => widget.pkTeam == 1 ? _kTeamA : _kTeamB;
  bool get _hasPk => widget.pkTeam != 0;

  @override
  Widget build(BuildContext context) {
    final seat       = widget.seat;
    final avatarSize = widget.isHost ? 76.0 : 62.0;
    final ringSize   = widget.isHost ? 84.0 : 70.0;
    final hasBar     = !seat.isEmpty && seat.userId != null && seat.sessionDiamonds > 0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── صورة + شريط الهدايا يتداخل مع أسفل الدائرة ────────
              SizedBox(
                width: ringSize,
                height: ringSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // الأفاتار مع نبضة الكلام
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, child) => Transform.scale(
                        scale: seat.isSpeaking ? _pulseAnim.value : 1.0,
                        child: child,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (seat.isSpeaking)
                            Container(
                              width: ringSize,
                              height: ringSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _hasPk ? _pkColor : AppColors.primary,
                                  width: 2.5,
                                ),
                                color: (_hasPk ? _pkColor : AppColors.primary).withAlpha(30),
                              ),
                            ),
                          _buildAvatar(seat),
                          if (!seat.isEmpty && seat.isMuted)
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.mic_off_rounded, size: 9, color: Colors.white),
                              ),
                            ),
                          if (widget.isHost)
                            Positioned(
                              top: -4, left: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: AppColors.goldGradient,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('👑', style: TextStyle(fontSize: 9)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // شريط الهدايا — يتداخل مع أسفل حافة الدائرة
                    if (hasBar)
                      Positioned(
                        bottom: -9,
                        child: _DiamondBar(
                          userId: seat.userId!,
                          isHost: widget.isHost,
                          sessionDiamonds: seat.sessionDiamonds,
                        ),
                      ),
                  ],
                ),
              ),

              // مسافة تحسب فيض الشريط
              SizedBox(height: hasBar ? 13 : 4),

              // ── اسم المستخدم — عريض وقريب من الشريط ────────────────
              SizedBox(
                width: widget.isHost ? 92 : 80,
                child: Text(
                  seat.isEmpty
                      ? (seat.isLocked ? '🔒' : '+')
                      : (seat.userName ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: (!seat.isEmpty && seat.nameColor != null)
                        ? hexColor(seat.nameColor)
                        : (seat.isEmpty ? AppColors.textHint : AppColors.textPrimary),
                    fontSize: widget.isHost ? 13 : 11,
                    fontFamily: 'Cairo',
                    fontWeight: widget.isHost ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // الإيموجي الطائر فوق الصورة
          if (_currentEmoji != null && _emojiCtrl != null)
            Positioned(
              top: -(avatarSize * 0.55 + 4),
              child: AnimatedBuilder(
                animation: _emojiCtrl!,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, _emojiSlide!.value),
                  child: Opacity(
                    opacity: _emojiFade!.value,
                    child: _renderEmoji(_currentEmoji!),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _renderEmoji(String emoji) {
    // '😘←' = بوسة يسار (مرآة أفقية)
    final isFlipped = emoji.endsWith('←');
    final raw = isFlipped ? emoji.replaceAll('←', '') : emoji;
    final text = Text(raw, style: const TextStyle(fontSize: 26));
    if (isFlipped) {
      return Transform.scale(scaleX: -1.0, child: text);
    }
    return text;
  }

  Widget _buildAvatar(SeatModel seat) {
    final size = widget.isHost ? 76.0 : 62.0;
    if (seat.isLocked && seat.isEmpty) {
      return Container(
        width: size, height: size,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.seatLocked),
        child: const Icon(Icons.lock_rounded, color: AppColors.textHint, size: 20),
      );
    }
    if (seat.isEmpty) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _hasPk ? _pkColor.withAlpha(18) : Colors.transparent,
          border: Border.all(
            color: _hasPk ? _pkColor.withAlpha(120) : AppColors.divider.withAlpha(80),
          ),
        ),
        child: Icon(Icons.add_rounded, color: AppColors.textHint.withAlpha(120), size: widget.isHost ? 36 : 28),
      );
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.seatOccupied,
        border: Border.all(
          color: widget.isMe
              ? AppColors.primary
              : _hasPk
                  ? _pkColor
                  : Colors.transparent,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: seat.userAvatar != null
            ? CachedNetworkImage(imageUrl: seat.userAvatar!, fit: BoxFit.cover)
            : Center(
                child: Text(
                  (seat.userName ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _DiamondBar — شريط تقدم الهدايا (أخضر→أزرق→بنفسجي→أحمر)
// ═══════════════════════════════════════════════════════════════════════════

class _DiamondBar extends StatelessWidget {
  const _DiamondBar({
    required this.userId,
    required this.sessionDiamonds,
    this.isHost = false,
  });
  final String userId;
  final int sessionDiamonds;
  final bool isHost;

  // (الحد الأدنى، الحد الأعلى، اللون)  —  -1 يعني لا يوجد حد أعلى
  static const _levels = <(int, int, Color)>[
    (0,      10000,  Color(0xFF2ECC71)),  // أخضر
    (10000,  50000,  Color(0xFF3498DB)),  // أزرق
    (50000,  500000, Color(0xFF9B59B6)), // بنفسجي
    (500000, -1,     Color(0xFFFF2D55)), // أحمر
  ];

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    return '$n';
  }

  (Color, double) _levelAndProgress(int diamonds) {
    for (int i = _levels.length - 1; i >= 0; i--) {
      final (min, max, color) = _levels[i];
      if (diamonds >= min) {
        final progress = max == -1
            ? 1.0
            : ((diamonds - min) / (max - min)).clamp(0.0, 1.0);
        return (color, progress);
      }
    }
    return (_levels[0].$3, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    if (sessionDiamonds == 0) return const SizedBox.shrink();

    final barW = isHost ? 72.0 : 62.0;
    final fs   = isHost ? 9.0  : 8.0;
    final (color, progress) = _levelAndProgress(sessionDiamonds);

    return Container(
      height: 17,
      width: barW,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withAlpha(90), width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            // شريط التقدم
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(color: color.withAlpha(160)),
            ),
            // الرقم في المنتصف
            Center(
              child: Text(
                _fmt(sessionDiamonds),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fs,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                  height: 1.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
