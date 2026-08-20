import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/gift_model.dart';
import '../providers/gift_provider.dart';

class GiftAnimationOverlay extends ConsumerStatefulWidget {
  const GiftAnimationOverlay({super.key});

  @override
  ConsumerState<GiftAnimationOverlay> createState() => _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends ConsumerState<GiftAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  GiftSentRecord? _current;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.4)),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeGiftAnimProvider, (_, next) async {
      if (next == null) return;
      _current = next;
      if (mounted) setState(() {});
      await _ctrl.forward(from: 0);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        await _ctrl.reverse();
        ref.read(activeGiftAnimProvider.notifier).state = null;
        _current = null;
        if (mounted) setState(() {});
      }
    });

    final record = _current;
    if (record == null) return const SizedBox.shrink();

    return Positioned(
      bottom: 120,
      left: 16,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: _GiftBanner(record: record),
          ),
        ),
      ),
    );
  }
}

class _GiftBanner extends StatelessWidget {
  const _GiftBanner({required this.record});
  final GiftSentRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(100),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(record.giftEmoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  record.senderName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  record.receiverName != null
                      ? 'أرسل ${record.giftName} لـ ${record.receiverName}'
                      : 'أرسل ${record.giftName}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Cairo',
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
