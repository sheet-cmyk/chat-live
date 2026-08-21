import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/chat_colors.dart';
import '../../data/models/seat_model.dart';
import '../providers/room_provider.dart';

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
  });

  final SeatModel seat;
  final bool isHost;
  final bool isMe;
  final VoidCallback? onTap;
  final EmojiTrigger? emojiTrigger;
  final bool challengeActive;

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

  @override
  Widget build(BuildContext context) {
    final seat = widget.seat;
    final avatarSize = widget.isHost ? 76.0 : 62.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // الأفاتار + الاسم
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                        width: widget.isHost ? 84 : 70,
                        height: widget.isHost ? 84 : 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 2.5),
                          color: AppColors.primary.withAlpha(30),
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
              const SizedBox(height: 5),
              SizedBox(
                width: widget.isHost ? 84 : 70,
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
                    fontWeight: widget.isHost ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (!seat.isEmpty && seat.userId != null)
                _DiamondBar(
                  userId: seat.userId!,
                  isHost: widget.isHost,
                  challengeActive: widget.challengeActive,
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
          color: widget.isHost ? AppColors.seatHost : AppColors.seatEmpty,
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(Icons.add_rounded, color: AppColors.textHint, size: widget.isHost ? 36 : 28),
      );
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.seatOccupied,
        border: Border.all(
          color: widget.isMe ? AppColors.primary : Colors.transparent,
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
//  _DiamondBar — شريط ماسات الهدايا تحت اسم المستخدم على المايك
// ═══════════════════════════════════════════════════════════════════════════

class _DiamondBar extends ConsumerWidget {
  const _DiamondBar({
    required this.userId,
    this.isHost = false,
    this.challengeActive = false,
  });
  final String userId;
  final bool isHost;
  final bool challengeActive;

  static const _tiers = [
    (5000000, Color(0xFFFF2D55)),   // أحمر — 5M+
    (1000000, Color(0xFF9B59B6)),   // بنفسجي — 1M+
    (500000,  Color(0xFF3498DB)),   // أزرق — 500K+
    (50000,   Color(0xFF2ECC71)),   // أخضر — 50K+
  ];

  static String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    if (n >= 1000)    return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diamonds = ref.watch(userGiftDiamondsProvider(userId)).valueOrNull ?? 0;
    if (diamonds == 0) return const SizedBox.shrink();

    Color? color;
    for (final (threshold, c) in _tiers) {
      if (diamonds >= threshold) { color = c; break; }
    }

    final fontSize = isHost ? 10.0 : 9.0;

    // بدون تحدٍّ نشط: يُظهر الشريط الملون فقط (بدون رقم)
    if (!challengeActive) {
      if (color == null) return const SizedBox.shrink();
      return Container(
        height: 3,
        width: isHost ? 52.0 : 42.0,
        margin: const EdgeInsets.only(top: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [BoxShadow(color: color.withAlpha(160), blurRadius: 5)],
        ),
      );
    }

    // تحدٍّ نشط: شريط + رقم
    final label = _fmt(diamonds);

    if (color == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Text(
          '💎 $label',
          style: TextStyle(
            color: Colors.white54,
            fontSize: fontSize,
            fontFamily: 'Cairo',
            height: 1.1,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 3,
          width: isHost ? 52.0 : 42.0,
          margin: const EdgeInsets.only(top: 3, bottom: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [BoxShadow(color: color.withAlpha(160), blurRadius: 5)],
          ),
        ),
        Text(
          '💎 $label',
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            fontFamily: 'Cairo',
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
