import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
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
  });

  final SeatModel seat;
  final bool isHost;
  final bool isMe;
  final VoidCallback? onTap;
  final EmojiTrigger? emojiTrigger;

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
    final avatarSize = widget.isHost ? 56.0 : 46.0;

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
                        width: widget.isHost ? 62 : 52,
                        height: widget.isHost ? 62 : 52,
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
                width: widget.isHost ? 64 : 54,
                child: Text(
                  seat.isEmpty
                      ? (seat.isLocked ? '🔒' : '+')
                      : (seat.userName ?? ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: seat.isEmpty ? AppColors.textHint : AppColors.textPrimary,
                    fontSize: widget.isHost ? 12 : 10,
                    fontFamily: 'Cairo',
                    fontWeight: widget.isHost ? FontWeight.w600 : FontWeight.normal,
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
    final size = widget.isHost ? 56.0 : 46.0;
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
        child: Icon(Icons.add_rounded, color: AppColors.textHint, size: widget.isHost ? 28 : 22),
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
