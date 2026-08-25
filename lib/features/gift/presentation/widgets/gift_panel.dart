import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/gift_model.dart';
import '../providers/gift_provider.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../../../room/presentation/providers/room_provider.dart';
import '../../../room/data/models/seat_model.dart';
import '../../../room/data/models/room_message_model.dart';

// ── ألوان TikTok الداكنة ──────────────────────────────────────────────────
const _kBg       = Color(0xFF161625);
const _kCard     = Color(0xFF222238);
const _kCardSel  = Color(0xFFFF4D6D);
const _kQtyChip  = Color(0xFF2A2A44);
const _kPriceClr = Color(0xFF4CF0FF);

String _fmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
  return '$n';
}

// ═══════════════════════════════════════════════════════════════════════════
//  GiftPanel
// ═══════════════════════════════════════════════════════════════════════════

class GiftPanel extends ConsumerStatefulWidget {
  const GiftPanel({
    super.key,
    this.targetUserId,
    this.targetUserName,
    this.targetUserAvatar,
    this.roomId,
  });
  final String? targetUserId;
  final String? targetUserName;
  final String? targetUserAvatar;
  final String? roomId;

  @override
  ConsumerState<GiftPanel> createState() => _GiftPanelState();
}

class _GiftPanelState extends ConsumerState<GiftPanel>
    with TickerProviderStateMixin {
  int _quantity = 1;

  // المستلم المختار (null = الكل)
  String? _selectedUserId;
  String? _selectedUserName;

  @override
  void initState() {
    super.initState();
    _selectedUserId   = widget.targetUserId;
    _selectedUserName = widget.targetUserName;
    // إذا ما في هدف محدد مسبقاً، حاول تحديد آخر شخص رسل هدية وهو على المايك
    if (widget.targetUserId == null && widget.roomId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoSelectLastGifter());
    }
  }

  // يحدد تلقائياً آخر شخص رسل هدية في الغرفة إذا هو على المايك حالياً
  void _autoSelectLastGifter() {
    if (!mounted || widget.roomId == null) return;
    final me   = FirebaseAuth.instance.currentUser?.uid;
    final msgs = ref.read(roomChatStreamProvider(widget.roomId!)).valueOrNull ?? [];
    final giftMsgs = msgs
        .where((m) => m.type == MessageType.gift && m.senderId != null && m.senderId != me)
        .toList();
    if (giftMsgs.isEmpty) return;
    final last  = giftMsgs.last;
    final seats = ref.read(seatsProvider(widget.roomId!));
    if (!seats.any((s) => s.userId == last.senderId)) return; // مو على المايك
    setState(() {
      _selectedUserId   = last.senderId;
      _selectedUserName = last.senderName ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final gifts    = ref.watch(giftsProvider);
    final selected = ref.watch(selectedGiftProvider);
    final category = ref.watch(selectedGiftCategoryProvider);
    final coins    = ref.watch(coinsProvider);
    final sending  = ref.watch(sendingGiftProvider);
    final total    = (selected?.coinPrice ?? 0) * _quantity;
    final canAfford = coins >= total;

    // مقاعد المايك لاختيار المستلم
    final seats = widget.roomId != null
        ? ref.watch(seatsProvider(widget.roomId!))
              .where((s) => !s.isEmpty && s.userId != null)
              .toList()
        : <SeatModel>[];

    final showSelector = widget.roomId != null || widget.targetUserId != null;

    return Container(
      decoration: const BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── مقبض ────────────────────────────────────────────────
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

          // ── رأس: عنوان + رصيد ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [
                const Text(
                  '🎁 الهدايا',
                  style: TextStyle(
                    color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w700, fontFamily: 'Cairo',
                  ),
                ),
                const Spacer(),
                _BalanceChip(coins: coins),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── اختيار المستلم ───────────────────────────────────────
          if (showSelector)
            _TargetSelector(
              seats: seats,
              selectedUserId: _selectedUserId,
              targetUserId: widget.targetUserId,
              targetUserName: widget.targetUserName,
              targetUserAvatar: widget.targetUserAvatar,
              onSelect: (id, name, _) => setState(() {
                _selectedUserId   = id;
                _selectedUserName = name;
              }),
            ),

          // ── شبكة الهدايا مباشرة ──────────────────────────────────
          _GiftGrid(
            gifts: gifts,
            selected: selected,
            category: category,
            onCategoryChanged: () {
              ref.read(selectedGiftProvider.notifier).state = null;
              setState(() => _quantity = 1);
            },
            onGiftSelected: (g) {
              ref.read(selectedGiftProvider.notifier).state = g;
              setState(() => _quantity = 1);
              HapticFeedback.selectionClick();
            },
            onSend: (g) {
              final needTarget = widget.roomId != null || widget.targetUserId != null;
              if (needTarget && _selectedUserId == null) {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('اختر شخصاً أولاً 👆',
                      style: TextStyle(fontFamily: 'Cairo')),
                  backgroundColor: Colors.redAccent,
                  duration: Duration(seconds: 2),
                ));
                return;
              }
              setState(() => _quantity = 1);
              ref.read(selectedGiftProvider.notifier).state = g;
              _doSend(g);
            },
          ),

          // ── شريط الكمية + زر الإرسال ────────────────────────────
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
                          left: 16, right: 16, top: 8,
                          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: Builder(builder: (_) {
                            final noTarget = showSelector && _selectedUserId == null;
                            final blocked  = sending || !canAfford || noTarget;
                            return ElevatedButton(
                              onPressed: blocked ? null : () => _doSend(selected),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: noTarget
                                    ? const Color(0xFF333344)
                                    : canAfford
                                        ? _kCardSel
                                        : const Color(0xFF444455),
                                disabledBackgroundColor: const Color(0xFF2A2A3A),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: blocked ? 0 : 6,
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
                                      noTarget
                                          ? '👆 اختر شخصاً أولاً'
                                          : canAfford
                                              ? 'إرسال ${selected.emoji}  💎 ${_fmt(total)}'
                                              : 'رصيدك غير كافٍ',
                                      style: const TextStyle(
                                        color: Colors.white, fontFamily: 'Cairo',
                                        fontWeight: FontWeight.w700, fontSize: 15,
                                      ),
                                    ),
                            );
                          }),
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

  Future<void> _openCustomQty() async {
    final ctrl = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF222238),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('عدد الهدايا',
            style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 15)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          cursorColor: Colors.white,
          style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 18),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            filled: false,
            hintText: 'مثال: 50',
            hintStyle: TextStyle(color: Colors.white30, fontFamily: 'Cairo'),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _kCardSel, width: 2)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.white38, fontFamily: 'Cairo')),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text) ?? 0;
              if (v > 0) Navigator.pop(context, v);
            },
            child: const Text('تأكيد',
                style: TextStyle(
                    color: _kCardSel, fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() => _quantity = result.clamp(1, 9999));
    }
  }

  Future<void> _doSend(GiftModel gift) async {
    final me   = FirebaseAuth.instance.currentUser;
    final room = ref.read(currentRoomProvider);
    if (me == null || room == null) return;

    // تحديد فريق PK للمستلم إذا كانت معركة PK نشطة
    String? pkTeam;
    if (widget.roomId != null && _selectedUserId != null) {
      final pk = ref.read(pkStateProvider(widget.roomId!)).valueOrNull;
      if (pk != null && pk.active && !pk.timeUp) {
        final allSeats = ref.read(seatsProvider(widget.roomId!));
        final maxSeats = ref.read(roomMaxSeatsProvider(widget.roomId!)).valueOrNull ?? allSeats.length;
        final recvSeat = allSeats.firstWhere(
          (s) => s.userId == _selectedUserId,
          orElse: () => const SeatModel(index: -1),
        );
        if (recvSeat.index >= 0) {
          pkTeam = recvSeat.index < maxSeats ~/ 2 ? 'A' : 'B';
        }
      }
    }

    ref.read(sendingGiftProvider.notifier).state = true;
    try {
      final ok = await ref.read(giftRepositoryProvider).sendGift(
        roomId: room.roomId,
        senderId: me.uid,
        senderName: me.displayName ?? 'مستخدم',
        senderAvatar: me.photoURL,
        receiverId: _selectedUserId,
        receiverName: _selectedUserName,
        gift: gift,
        quantity: _quantity,
        pkTeam: pkTeam,
      );

      if (ok && mounted) {
        final suffix = _quantity > 1 ? ' x$_quantity' : '';
        await ref.read(chatWriterProvider(room.roomId)).sendGift(
          senderId: me.uid,
          senderName: me.displayName ?? 'مستخدم',
          senderAvatar: me.photoURL,
          receiverName: _selectedUserName,
          giftEmoji: gift.emoji,
          giftName: '${gift.name}$suffix',
        );
        if (mounted) Navigator.of(context).pop();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('رصيدك غير كافٍ أو فشل الإرسال',
                style: TextStyle(fontFamily: 'Cairo')),
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
//  _GiftGrid — تبويبات الفئات + شبكة الهدايا
// ═══════════════════════════════════════════════════════════════════════════

class _GiftGrid extends StatelessWidget {
  const _GiftGrid({
    required this.gifts,
    required this.selected,
    required this.category,
    required this.onCategoryChanged,
    required this.onGiftSelected,
    required this.onSend,
  });
  final AsyncValue<List<GiftModel>> gifts;
  final GiftModel? selected;
  final GiftCategory category;
  final VoidCallback onCategoryChanged;
  final void Function(GiftModel) onGiftSelected;
  final void Function(GiftModel) onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CategoryTabs(onChanged: onCategoryChanged),
        const SizedBox(height: 10),
        SizedBox(
          height: 280,
          child: gifts.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: _kCardSel, strokeWidth: 2),
            ),
            error: (_, __) => const Center(
              child: Text('خطأ في التحميل',
                  style: TextStyle(color: Colors.white38, fontFamily: 'Cairo')),
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
                  childAspectRatio: 0.72,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final g = filtered[i];
                  return _GiftCard(
                    gift: g,
                    isSelected: selected?.id == g.id,
                    onTap: () => onGiftSelected(g),
                    onSend: () => onSend(g),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _TargetSelector — اختيار المستلم (الكل / مستخدم محدد)
// ═══════════════════════════════════════════════════════════════════════════

class _TargetSelector extends StatelessWidget {
  const _TargetSelector({
    required this.seats,
    required this.selectedUserId,
    required this.targetUserId,
    required this.targetUserName,
    required this.targetUserAvatar,
    required this.onSelect,
  });
  final List<SeatModel> seats;
  final String? selectedUserId;
  final String? targetUserId;
  final String? targetUserName;
  final String? targetUserAvatar;
  final void Function(String? id, String? name, String? avatar) onSelect;

  @override
  Widget build(BuildContext context) {
    // بناء قائمة المستخدمين من المقاعد
    final users = seats
        .map((s) => (id: s.userId!, name: s.userName ?? '', avatar: s.userAvatar))
        .toList();

    // إضافة الهدف المحدد مسبقاً إن لم يكن في قائمة المقاعد
    if (targetUserId != null && !users.any((u) => u.id == targetUserId)) {
      users.insert(0, (
        id: targetUserId!,
        name: targetUserName ?? '',
        avatar: targetUserAvatar,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 5),
          child: Text(
            'إرسال إلى:',
            style: TextStyle(
              color: Colors.white.withAlpha(130),
              fontFamily: 'Cairo',
              fontSize: 11,
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: users.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.mic_off_rounded, color: Colors.white38, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'لا يوجد أحد على المايك حالياً',
                        style: TextStyle(color: Colors.white.withAlpha(100), fontFamily: 'Cairo', fontSize: 12),
                      ),
                    ],
                  ),
                )
              : ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: users.map((u) => _UserChip(
                    id: u.id,
                    name: u.name,
                    avatar: u.avatar,
                    isSelected: selectedUserId == u.id,
                    onTap: () => onSelect(u.id, u.name, u.avatar),
                  )).toList(),
                ),
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: Colors.white.withAlpha(18)),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _UserChip extends StatelessWidget {
  const _UserChip({
    required this.id,
    required this.name,
    required this.avatar,
    required this.isSelected,
    required this.onTap,
  });
  final String? id;
  final String name;
  final String? avatar;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _kCardSel.withAlpha(40) : const Color(0xFF252542),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _kCardSel : Colors.white.withAlpha(20),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatar != null && avatar!.isNotEmpty)
              ClipOval(
                child: Image.network(
                  avatar!,
                  width: 22, height: 22,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _avatarFallback(),
                ),
              )
            else
              _avatarFallback(),
            const SizedBox(width: 5),
            Text(
              name.length > 8 ? '${name.substring(0, 7)}…' : name,
              style: TextStyle(
                color: isSelected ? _kCardSel : Colors.white70,
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 22, height: 22,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _kCard,
      ),
      child: const Icon(Icons.person_rounded, size: 14, color: Colors.white38),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _BalanceChip — رصيد العملات
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
              color: Colors.white, fontWeight: FontWeight.w700,
              fontFamily: 'Cairo', fontSize: 13,
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
//  _CategoryTabs — تبويبات فئات الهدايا
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
                border: Border.all(color: active ? _kCardSel : Colors.white12),
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
    required this.onSend,
  });
  final GiftModel gift;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? _kCardSel.withAlpha(50) : const Color(0xFF1A1A30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _kCardSel : const Color(0xFFFFD700).withAlpha(40),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _kCardSel.withAlpha(80), blurRadius: 10)]
              : null,
        ),
        child: Stack(
          children: [
            if (gift.isSpecial)
              Positioned(
                top: 3, left: 3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFF7B00), Color(0xFFFFD000)]),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text('SPECIAL',
                      style: TextStyle(
                          color: Colors.white, fontSize: 6,
                          fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 6),
                Text(
                  gift.emoji,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: gift.isSpecial ? 28 : 26, height: 1.1),
                ),
                const SizedBox(height: 2),
                Text(
                  gift.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 9,
                      fontFamily: 'Cairo', fontWeight: FontWeight.w500),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 8)),
                    const SizedBox(width: 2),
                    Text(
                      _fmt(gift.coinPrice),
                      style: const TextStyle(
                          color: _kPriceClr, fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // ── زر الإرسال المباشر ──────────────────────────────
                GestureDetector(
                  onTap: onSend,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                    height: 22,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? [_kCardSel, const Color(0xFFFF2D55)]
                            : [const Color(0xFFFF4D6D), const Color(0xFFCC003D)],
                      ),
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: _kCardSel.withAlpha(100),
                          blurRadius: 4, offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'إرسال',
                      style: TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontFamily: 'Cairo', fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
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

// ═══════════════════════════════════════════════════════════════════════════
