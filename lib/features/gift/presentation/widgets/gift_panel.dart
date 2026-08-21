import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/gift_model.dart';
import '../providers/gift_provider.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../../../room/presentation/providers/room_provider.dart';

// ── ألوان TikTok الداكنة ──────────────────────────────────────────────────
const _kBg         = Color(0xFF161625);
const _kCard       = Color(0xFF222238);
const _kCardSel    = Color(0xFFFF4D6D);   // وردي TikTok
const _kQtyChip    = Color(0xFF2A2A44);
const _kPriceClr   = Color(0xFF4CF0FF);  // أزرق فاتح للسعر

// ── مساعد تنسيق الأرقام ──────────────────────────────────────────────────
String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
  return '$n';
}

// ═══════════════════════════════════════════════════════════════════════════
//  GiftPanel
// ═══════════════════════════════════════════════════════════════════════════

class GiftPanel extends ConsumerStatefulWidget {
  const GiftPanel({super.key, this.targetUserId, this.targetUserName});
  final String? targetUserId;
  final String? targetUserName;

  @override
  ConsumerState<GiftPanel> createState() => _GiftPanelState();
}

class _GiftPanelState extends ConsumerState<GiftPanel> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final gifts       = ref.watch(giftsProvider);
    final selected    = ref.watch(selectedGiftProvider);
    final category    = ref.watch(selectedGiftCategoryProvider);
    final coins       = ref.watch(coinsProvider);
    final sending     = ref.watch(sendingGiftProvider);
    final totalCost   = (selected?.coinPrice ?? 0) * _quantity;
    final canAfford   = coins >= totalCost;

    return Container(
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── مقبض ─────────────────────────────────────────────
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── رأس: عنوان + رصيد ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                const Text(
                  'الهدايا',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                  ),
                ),
                const Spacer(),
                _BalanceChip(coins: coins),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── تبويبات الفئات ────────────────────────────────────
          _CategoryTabs(onChanged: () {
            ref.read(selectedGiftProvider.notifier).state = null;
            setState(() => _quantity = 1);
          }),

          const SizedBox(height: 10),

          // ── شبكة الهدايا ──────────────────────────────────────
          SizedBox(
            height: 280,
            child: gifts.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _kCardSel, strokeWidth: 2),
              ),
              error: (_, __) => const Center(
                child: Text(
                  'خطأ في التحميل',
                  style: TextStyle(color: Colors.white38, fontFamily: 'Cairo'),
                ),
              ),
              data: (list) {
                final filtered = category == GiftCategory.popular
                    ? list
                    : list.where((g) => g.category == category).toList();
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final g = filtered[i];
                    return _GiftCard(
                      gift: g,
                      isSelected: selected?.id == g.id,
                      onTap: () {
                        ref.read(selectedGiftProvider.notifier).state = g;
                        setState(() => _quantity = 1);
                        HapticFeedback.selectionClick();
                      },
                    );
                  },
                );
              },
            ),
          ),

          // ── شريط الكمية + زر الإرسال (يظهر عند اختيار هدية) ──
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: selected != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _QuantityStrip(
                        quantity: _quantity,
                        onPick: (q) => setState(() => _quantity = q),
                        onCustom: _openCustomQty,
                      ),
                      Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 8,
                          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: (sending || !canAfford)
                                ? null
                                : () => _doSend(selected),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canAfford
                                  ? _kCardSel
                                  : const Color(0xFF444455),
                              disabledBackgroundColor: const Color(0xFF333344),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: canAfford ? 6 : 0,
                              shadowColor: _kCardSel.withAlpha(120),
                            ),
                            child: sending
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    canAfford
                                        ? 'إرسال ${selected.emoji}  💎 ${_fmt(totalCost)}'
                                        : 'رصيدك غير كافٍ',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    height: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
          ),
        ],
      ),
    );
  }

  // ── إدخال كمية مخصصة ─────────────────────────────────────────────────────
  Future<void> _openCustomQty() async {
    final ctrl = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF222238),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'عدد الهدايا',
          style: TextStyle(
            color: Colors.white, fontFamily: 'Cairo', fontSize: 15,
          ),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(
            color: Colors.white, fontFamily: 'Cairo', fontSize: 18,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            hintText: 'مثال: 50',
            hintStyle: TextStyle(color: Colors.white30, fontFamily: 'Cairo'),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _kCardSel, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Colors.white38, fontFamily: 'Cairo'),
            ),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text) ?? 0;
              if (v > 0) Navigator.pop(context, v);
            },
            child: const Text(
              'تأكيد',
              style: TextStyle(
                color: _kCardSel, fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _quantity = result.clamp(1, 9999));
    }
  }

  // ── إرسال الهدية ─────────────────────────────────────────────────────────
  Future<void> _doSend(GiftModel gift) async {
    final me   = FirebaseAuth.instance.currentUser;
    final room = ref.read(currentRoomProvider);
    if (me == null || room == null) return;

    ref.read(sendingGiftProvider.notifier).state = true;
    try {
      final ok = await ref.read(giftRepositoryProvider).sendGift(
        roomId: room.roomId,
        senderId: me.uid,
        senderName: me.displayName ?? 'مستخدم',
        senderAvatar: me.photoURL,
        receiverId: widget.targetUserId,
        receiverName: widget.targetUserName,
        gift: gift,
        quantity: _quantity,
      );

      if (ok && mounted) {
        final suffix = _quantity > 1 ? ' x$_quantity' : '';
        await ref.read(chatWriterProvider(room.roomId)).sendGift(
          senderId: me.uid,
          senderName: me.displayName ?? 'مستخدم',
          senderAvatar: me.photoURL,
          receiverName: widget.targetUserName,
          giftEmoji: gift.emoji,
          giftName: '${gift.name}$suffix',
        );
        if (mounted) Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'رصيدك غير كافٍ أو فشل الإرسال',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) ref.read(sendingGiftProvider.notifier).state = false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _BalanceChip — رصيد الماسات
// ═══════════════════════════════════════════════════════════════════════════

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('💎', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 5),
          Text(
            _fmt(coins),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontFamily: 'Cairo',
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: _kCardSel.withAlpha(40),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'شحن',
              style: TextStyle(
                color: _kCardSel, fontSize: 10,
                fontFamily: 'Cairo', fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _CategoryTabs
// ═══════════════════════════════════════════════════════════════════════════

class _CategoryTabs extends ConsumerWidget {
  const _CategoryTabs({required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedGiftCategoryProvider);
    const cats = [
      (GiftCategory.popular, '🎁 الكل'),
      (GiftCategory.love,    '💕 حب'),
      (GiftCategory.special, '✨ مميز'),
      (GiftCategory.luxury,  '👑 فاخر'),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (cat, label) = cats[i];
          final active = selected == cat;
          return GestureDetector(
            onTap: () {
              ref.read(selectedGiftCategoryProvider.notifier).state = cat;
              onChanged();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: active ? _kCardSel : const Color(0xFF252542),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: active ? _kCardSel : Colors.white12,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _GiftCard — بطاقة هدية واحدة
// ═══════════════════════════════════════════════════════════════════════════

class _GiftCard extends StatelessWidget {
  const _GiftCard({
    required this.gift,
    required this.isSelected,
    required this.onTap,
  });
  final GiftModel gift;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? _kCardSel.withAlpha(28) : _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _kCardSel : Colors.white12,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _kCardSel.withAlpha(70), blurRadius: 10)]
              : null,
        ),
        child: Stack(
          children: [
            // SPECIAL badge — أعلى اليسار
            if (gift.isSpecial)
              Positioned(
                top: 4, left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF7B00), Color(0xFFFFD000)],
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'SPECIAL',
                    style: TextStyle(
                      color: Colors.white, fontSize: 6,
                      fontWeight: FontWeight.w800, letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            // المحتوى الرئيسي
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // الإيموجي
                  Text(
                    gift.emoji,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: gift.isSpecial ? 32 : 30,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // الاسم
                  Text(
                    gift.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // السعر بالماسات
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 9)),
                      const SizedBox(width: 2),
                      Text(
                        _fmt(gift.coinPrice),
                        style: const TextStyle(
                          color: _kPriceClr,
                          fontSize: 10,
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
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _QuantityStrip — شريط الكمية x1 … x9 … ···
// ═══════════════════════════════════════════════════════════════════════════

class _QuantityStrip extends StatelessWidget {
  const _QuantityStrip({
    required this.quantity,
    required this.onPick,
    required this.onCustom,
  });
  final int quantity;
  final void Function(int) onPick;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final isCustom = quantity > 9;
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white10),
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          // أرقام x1 - x9
          ...List.generate(9, (i) {
            final q = i + 1;
            final sel = quantity == q;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  onPick(q);
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? _kCardSel : _kQtyChip,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'x$q',
                    style: TextStyle(
                      color: sel ? Colors.white : Colors.white54,
                      fontSize: 10,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),

          // زر ··· (مخصص)
          Expanded(
            child: GestureDetector(
              onTap: onCustom,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 9),
                decoration: BoxDecoration(
                  color: isCustom ? _kCardSel : _kQtyChip,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  isCustom ? 'x$quantity' : '···',
                  style: TextStyle(
                    color: isCustom ? Colors.white : Colors.white54,
                    fontSize: isCustom ? 9 : 12,
                    fontWeight: isCustom ? FontWeight.w700 : FontWeight.normal,
                    letterSpacing: isCustom ? 0 : 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
