import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/gift_model.dart';
import '../providers/gift_provider.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../../../room/presentation/providers/room_provider.dart';

class GiftPanel extends ConsumerStatefulWidget {
  const GiftPanel({super.key, this.targetUserId, this.targetUserName});
  final String? targetUserId;
  final String? targetUserName;

  @override
  ConsumerState<GiftPanel> createState() => _GiftPanelState();
}

class _GiftPanelState extends ConsumerState<GiftPanel> {
  @override
  Widget build(BuildContext context) {
    final gifts = ref.watch(giftsProvider);
    final selectedGift = ref.watch(selectedGiftProvider);
    final category = ref.watch(selectedGiftCategoryProvider);
    final coins = ref.watch(coinsProvider);
    final sending = ref.watch(sendingGiftProvider);

    return SizedBox(
      height: 420,
      child: Column(
        children: [
          // مقبض السحب
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // الترويسة: عنوان + رصيد
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('الهدايا', style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                )),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 4),
                      Text('$coins', style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cairo',
                        fontSize: 13,
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // تبويبات الفئات
          const SizedBox(height: 8),
          _CategoryTabs(),
          const SizedBox(height: 8),

          // شبكة الهدايا
          Expanded(
            child: gifts.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (_, __) => const Center(child: Text('خطأ في تحميل الهدايا', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'))),
              data: (list) {
                final filtered = category == GiftCategory.popular
                    ? list
                    : list.where((g) => g.category == category).toList();
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _GiftItem(
                    gift: filtered[i],
                    isSelected: selectedGift?.id == filtered[i].id,
                    onTap: () => ref.read(selectedGiftProvider.notifier).state = filtered[i],
                  ),
                );
              },
            ),
          ),

          // زر الإرسال
          if (selectedGift != null)
            Padding(
              padding: EdgeInsets.only(
                left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: sending ? null : () => _sendGift(selectedGift),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          'إرسال ${selectedGift.emoji} · ${selectedGift.coinPrice} 🪙',
                          style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _sendGift(GiftModel gift) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    final room = ref.read(currentRoomProvider);
    if (room == null) return;

    final coins = ref.read(coinsProvider);
    if (coins < gift.coinPrice) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رصيدك غير كافٍ! اشحن محفظتك', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    ref.read(sendingGiftProvider.notifier).state = true;
    try {
      final repo = ref.read(giftRepositoryProvider);
      final ok = await repo.sendGift(
        roomId: room.roomId,
        senderId: me.uid,
        senderName: me.displayName ?? 'مستخدم',
        senderAvatar: me.photoURL,
        receiverId: widget.targetUserId,
        receiverName: widget.targetUserName,
        gift: gift,
      );

      if (ok && mounted) {
        // أرسل رسالة الهدية للدردشة — يراها جميع الأعضاء ويُفعّل الأنيميشن لديهم
        await ref.read(chatWriterProvider(room.roomId)).sendGift(
          senderId: me.uid,
          senderName: me.displayName ?? 'مستخدم',
          senderAvatar: me.photoURL,
          receiverName: widget.targetUserName,
          giftEmoji: gift.emoji,
          giftName: gift.name,
        );

        if (mounted) Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل إرسال الهدية', style: TextStyle(fontFamily: 'Cairo')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) ref.read(sendingGiftProvider.notifier).state = false;
    }
  }
}

// تبويبات الفئات
class _CategoryTabs extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedGiftCategoryProvider);
    final categories = [
      (GiftCategory.popular, 'الكل'),
      (GiftCategory.love, 'حب 💕'),
      (GiftCategory.special, 'مميز ✨'),
      (GiftCategory.luxury, 'فاخر 💎'),
    ];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (cat, label) = categories[i];
          final isActive = selected == cat;
          return GestureDetector(
            onTap: () => ref.read(selectedGiftCategoryProvider.notifier).state = cat,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(label, style: TextStyle(
                color: isActive ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                fontFamily: 'Cairo',
              )),
            ),
          );
        },
      ),
    );
  }
}

// بطاقة هدية واحدة
class _GiftItem extends StatelessWidget {
  const _GiftItem({required this.gift, required this.isSelected, required this.onTap});
  final GiftModel gift;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(40) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(gift.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(gift.name, style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontFamily: 'Cairo',
            )),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 2),
                Text('${gift.coinPrice}', style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
