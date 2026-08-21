import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/models/gift_model.dart';
import '../providers/gift_provider.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../../../room/presentation/providers/room_provider.dart';
import '../../../room/data/models/seat_model.dart';

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
  bool _isBoxOpen = false;

  // المستلم المختار (null = الكل)
  String? _selectedUserId;
  String? _selectedUserName;

  late AnimationController _floatCtrl;
  late AnimationController _openCtrl;
  late Animation<double> _floatY;
  late Animation<double> _openScale;
  late Animation<double> _openOpacity;

  @override
  void initState() {
    super.initState();
    _selectedUserId   = widget.targetUserId;
    _selectedUserName = widget.targetUserName;

    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _floatY = Tween<double>(begin: 0, end: -12).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _openCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _openScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.6), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.6, end: 0.0), weight: 45),
    ]).animate(_openCtrl);
    _openOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _openCtrl, curve: const Interval(0.55, 1.0)),
    );
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _openCtrl.dispose();
    super.dispose();
  }

  Future<void> _openBox() async {
    HapticFeedback.heavyImpact();
    _floatCtrl.stop();
    await _openCtrl.forward();
    if (mounted) setState(() => _isBoxOpen = true);
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
                  'الهدايا',
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

          // ── صندوق مغلق ↔ شبكة هدايا ────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _isBoxOpen
                ? _GiftGrid(
                    key: const ValueKey('grid'),
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
                  )
                : _GiftBoxView(
                    key: const ValueKey('box'),
                    floatY: _floatY,
                    openScale: _openScale,
                    openOpacity: _openOpacity,
                    isOpening: _openCtrl.isAnimating,
                    onTap: _openCtrl.isAnimating ? null : _openBox,
                    listenables: Listenable.merge([_floatCtrl, _openCtrl]),
                  ),
          ),

          // ── شريط الكمية + زر الإرسال (بعد فتح الصندوق) ──────────
          if (_isBoxOpen)
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
                            child: ElevatedButton(
                              onPressed: (sending || !canAfford) ? null : () => _doSend(selected),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: canAfford
                                    ? _kCardSel
                                    : const Color(0xFF444455),
                                disabledBackgroundColor: const Color(0xFF333344),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
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
                                          ? 'إرسال ${selected.emoji}  💎 ${_fmt(total)}'
                                          : 'رصيدك غير كافٍ',
                                      style: const TextStyle(
                                        color: Colors.white, fontFamily: 'Cairo',
                                        fontWeight: FontWeight.w700, fontSize: 15,
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
          style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 18),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
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
//  _GiftBoxView — صندوق الهدايا المغلق مع أنيميشن
// ═══════════════════════════════════════════════════════════════════════════

class _GiftBoxView extends StatelessWidget {
  const _GiftBoxView({
    super.key,
    required this.floatY,
    required this.openScale,
    required this.openOpacity,
    required this.isOpening,
    required this.onTap,
    required this.listenables,
  });
  final Animation<double> floatY;
  final Animation<double> openScale;
  final Animation<double> openOpacity;
  final bool isOpening;
  final VoidCallback? onTap;
  final Listenable listenables;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 260,
        child: Center(
          child: AnimatedBuilder(
            animation: listenables,
            builder: (_, __) => Opacity(
              opacity: isOpening ? openOpacity.value : 1.0,
              child: Transform.scale(
                scale: isOpening ? openScale.value : 1.0,
                child: Transform.translate(
                  offset: Offset(0, isOpening ? 0 : floatY.value),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // الصندوق مع الوهج
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // وهج داخلي
                          Container(
                            width: 130, height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _kCardSel.withAlpha(80),
                                  _kCardSel.withAlpha(20),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                          // بريق (4 خطوط متقاطعة)
                          ...List.generate(4, (i) => Transform.rotate(
                            angle: i * 0.785398,  // 45 درجة
                            child: Container(
                              width: 90, height: 1.5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  Colors.transparent,
                                  _kCardSel.withAlpha(80),
                                  Colors.transparent,
                                ]),
                              ),
                            ),
                          )),
                          // الصندوق
                          const Text('🎁', style: TextStyle(fontSize: 88)),
                          // نجوم صغيرة
                          const Positioned(
                            top: 4, right: 8,
                            child: Text('✨', style: TextStyle(fontSize: 18)),
                          ),
                          const Positioned(
                            bottom: 8, left: 6,
                            child: Text('⭐', style: TextStyle(fontSize: 13)),
                          ),
                          const Positioned(
                            top: 12, left: 14,
                            child: Text('✨', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // زر الفتح
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 9),
                        decoration: BoxDecoration(
                          color: _kCardSel.withAlpha(35),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: _kCardSel.withAlpha(100), width: 1.5),
                        ),
                        child: const Text(
                          '✨ اضغط لفتح الهدايا ✨',
                          style: TextStyle(
                            color: Colors.white, fontFamily: 'Cairo',
                            fontSize: 14, fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _GiftGrid — تبويبات الفئات + شبكة الهدايا
// ═══════════════════════════════════════════════════════════════════════════

class _GiftGrid extends StatelessWidget {
  const _GiftGrid({
    super.key,
    required this.gifts,
    required this.selected,
    required this.category,
    required this.onCategoryChanged,
    required this.onGiftSelected,
  });
  final AsyncValue<List<GiftModel>> gifts;
  final GiftModel? selected;
  final GiftCategory category;
  final VoidCallback onCategoryChanged;
  final void Function(GiftModel) onGiftSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CategoryTabs(onChanged: onCategoryChanged),
        const SizedBox(height: 10),
        SizedBox(
          height: 260,
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
                  childAspectRatio: 0.8,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final g = filtered[i];
                  return _GiftCard(
                    gift: g,
                    isSelected: selected?.id == g.id,
                    onTap: () => onGiftSelected(g),
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
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              // الكل
              _UserChip(
                id: null,
                name: 'الكل',
                avatar: null,
                isSelected: selectedUserId == null,
                onTap: () => onSelect(null, null, null),
                isAll: true,
              ),
              ...users.map((u) => _UserChip(
                id: u.id,
                name: u.name,
                avatar: u.avatar,
                isSelected: selectedUserId == u.id,
                onTap: () => onSelect(u.id, u.name, u.avatar),
              )),
            ],
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
    this.isAll = false,
  });
  final String? id;
  final String name;
  final String? avatar;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isAll;

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
            if (isAll)
              const Icon(Icons.group_rounded, color: Colors.white70, size: 16)
            else if (avatar != null && avatar!.isNotEmpty)
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
            if (gift.isSpecial)
              Positioned(
                top: 4, left: 4,
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
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    gift.emoji,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: gift.isSpecial ? 32 : 30, height: 1.1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    gift.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontFamily: 'Cairo', fontWeight: FontWeight.w500),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('💎', style: TextStyle(fontSize: 9)),
                      const SizedBox(width: 2),
                      Text(
                        _fmt(gift.coinPrice),
                        style: const TextStyle(
                            color: _kPriceClr, fontSize: 10,
                            fontWeight: FontWeight.w700),
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
