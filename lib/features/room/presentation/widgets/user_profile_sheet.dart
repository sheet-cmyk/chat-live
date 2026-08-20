import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/seat_model.dart';
import '../../../gift/presentation/widgets/gift_panel.dart';

class UserProfileSheet extends ConsumerWidget {
  const UserProfileSheet({super.key, required this.seat});
  final SeatModel seat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),

          // أفاتار + اسم
          Row(
            children: [
              _Avatar(seat.userAvatar),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seat.userName ?? 'مستخدم',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Badge('LV.${seat.userLevel}', AppColors.primary),
                        if (seat.userVip > 0) ...[
                          const SizedBox(width: 6),
                          _Badge('VIP ${seat.userVip}', AppColors.gold),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // أزرار التفاعل
          Row(
            children: [
              Expanded(
                child: _ActionBtn(
                  icon: Icons.person_add_rounded,
                  label: 'متابعة',
                  color: AppColors.primary,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionBtn(
                  icon: Icons.card_giftcard_rounded,
                  label: 'هدية',
                  color: AppColors.accent,
                  onTap: () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: AppColors.surface,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (_) => GiftPanel(
                        targetUserId: seat.userId,
                        targetUserName: seat.userName,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'رسالة',
                  color: AppColors.textSecondary,
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // أزرار ثانوية
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _TextAction(label: 'مشاركة الملف', onTap: () => Navigator.pop(context)),
              _TextAction(label: 'إبلاغ', color: AppColors.error, onTap: () => Navigator.pop(context)),
              _TextAction(label: 'حظر', color: AppColors.error, onTap: () => Navigator.pop(context)),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.url);
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64, height: 64,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2)),
      child: ClipOval(
        child: url != null
            ? CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _placeholder())
            : _placeholder(),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.surfaceLight,
        child: const Icon(Icons.person_rounded, color: AppColors.textHint, size: 32),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withAlpha(80))),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withAlpha(80))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.onTap, this.color = AppColors.textSecondary});
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(label, style: TextStyle(color: color, fontFamily: 'Cairo', fontSize: 12)),
    );
  }
}
