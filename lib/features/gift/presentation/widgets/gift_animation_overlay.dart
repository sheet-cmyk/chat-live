import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/gift_model.dart';
import '../providers/gift_provider.dart';

// تحديد ما إذا كانت الهدية فاخرة (≥ 1000 ماسة) حسب coinPrice
bool _isLuxury(GiftSentRecord r) => r.coinPrice >= 1000 || r.isSpecial;

class GiftAnimationOverlay extends ConsumerStatefulWidget {
  const GiftAnimationOverlay({super.key});

  @override
  ConsumerState<GiftAnimationOverlay> createState() =>
      _GiftAnimationOverlayState();
}

class _GiftAnimationOverlayState extends ConsumerState<GiftAnimationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  GiftSentRecord? _current;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.35)),
    );
    _slide = Tween<Offset>(
      begin: const Offset(-0.4, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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

      // هدايا فاخرة تبقى أطول
      final holdMs = _isLuxury(next) ? 3000 : 2000;
      await Future.delayed(Duration(milliseconds: holdMs));

      if (mounted) {
        await _ctrl.reverse();
        ref.read(activeGiftAnimProvider.notifier).state = null;
        _current = null;
        if (mounted) setState(() {});
      }
    });

    final record = _current;
    if (record == null) return const SizedBox.shrink();

    final luxury = _isLuxury(record);

    return Positioned(
      bottom: luxury ? 140 : 120,
      left: 12,
      right: luxury ? 12 : null,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: ScaleTransition(
            scale: _scale,
            child: luxury
                ? _LuxuryBanner(record: record)
                : _RegularBanner(record: record),
          ),
        ),
      ),
    );
  }
}

// ── بانر هدية عادية (صغير — يسار الشاشة) ────────────────────────────────

class _RegularBanner extends StatelessWidget {
  const _RegularBanner({required this.record});
  final GiftSentRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C3EFF), Color(0xFFFF4D6D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4D6D).withAlpha(90),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(record.giftEmoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 8),
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
                    fontSize: 12,
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
                    fontSize: 10,
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

// ── بانر هدية فاخرة (عريض + متوهج + إيموجي كبير) ───────────────────────

class _LuxuryBanner extends StatefulWidget {
  const _LuxuryBanner({required this.record});
  final GiftSentRecord record;

  @override
  State<_LuxuryBanner> createState() => _LuxuryBannerState();
}

class _LuxuryBannerState extends State<_LuxuryBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.4, end: 1.0).animate(_glowCtrl);
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final qtyLabel = r.quantity > 1 ? ' ×${r.quantity}' : '';
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A0533), Color(0xFF3A0080), Color(0xFF1A0533)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFD700).withAlpha(
              (180 * _glow.value).round(),
            ),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withAlpha(
                (100 * _glow.value).round(),
              ),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
      child: Row(
        children: [
          // إيموجي كبير متوهج
          Text(r.giftEmoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // تسمية LUXURY
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7B00), Color(0xFFFFD000)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'هدية فاخرة ✨',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  r.senderName,
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
                  r.receiverName != null
                      ? 'أرسل ${r.giftName}$qtyLabel لـ ${r.receiverName}'
                      : 'أرسل ${r.giftName}$qtyLabel',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontFamily: 'Cairo',
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 3),
                    Text(
                      _fmt(r.coinPrice * r.quantity),
                      style: const TextStyle(
                        color: Color(0xFF4CF0FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
  return '$n';
}
