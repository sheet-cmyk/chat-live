import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/repositories/room_state_repository.dart';
import '../providers/room_provider.dart';
import '../../../admin/data/repositories/admin_repository.dart';
import '../../../gift/presentation/widgets/gift_panel.dart';

class UserProfileSheet extends ConsumerStatefulWidget {
  const UserProfileSheet({
    super.key,
    required this.roomId,
    required this.targetUserId,
    required this.targetUserName,
    this.targetUserAvatar,
    this.seatIndex,
    this.isSeatMuted = false,
    required this.isAdmin,
    required this.isHost,
  });

  final String roomId;
  final String targetUserId;
  final String targetUserName;
  final String? targetUserAvatar;
  final int? seatIndex;
  final bool isSeatMuted;
  final bool isAdmin;
  final bool isHost;

  @override
  ConsumerState<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends ConsumerState<UserProfileSheet> {
  bool _loading = false;

  bool get _canControl => widget.isAdmin || widget.isHost;

  Future<void> _run(Future<void> Function() action, {String? successMsg}) async {
    setState(() => _loading = true);
    try {
      await action();
      if (mounted) {
        if (successMsg != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(successMsg, style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.green,
          ));
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('❌ خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatMuteKey = '${widget.roomId}::${widget.targetUserId}';
    final isChatMuted = ref.watch(chatMutedProvider(chatMuteKey)).valueOrNull == true;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A0A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: _loading
          ? const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: Colors.amber)))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // مقبض التمرير
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),

                // معلومات المستخدم
                Row(
                  children: [
                    _avatar(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.targetUserName,
                              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (isChatMuted) _badge('🚫 مكتوم', Colors.red),
                              if (widget.isSeatMuted) ...[
                                if (isChatMuted) const SizedBox(width: 6),
                                _badge('🎙 مكتوم الصوت', Colors.orange),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // أزرار التفاعل الأساسية
                Row(
                  children: [
                    _ActionBtn(icon: Icons.person_add_rounded, label: 'متابعة', color: AppColors.primary, onTap: () => Navigator.pop(context)),
                    const SizedBox(width: 10),
                    _ActionBtn(
                      icon: Icons.card_giftcard_rounded,
                      label: 'هدية',
                      color: AppColors.accent,
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (_) => GiftPanel(
                            targetUserId: widget.targetUserId,
                            targetUserName: widget.targetUserName,
                            targetUserAvatar: widget.targetUserAvatar,
                            roomId: widget.roomId,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 10),
                    _ActionBtn(icon: Icons.chat_bubble_outline_rounded, label: 'رسالة', color: AppColors.textSecondary, onTap: () => Navigator.pop(context)),
                  ],
                ),

                // ── قسم التحكم (مضيف / إدارة) ────────────────────────
                if (_canControl) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      widget.isAdmin ? '⚙️ صلاحيات الإدارة' : '👑 صلاحيات المضيف',
                      style: const TextStyle(color: Colors.amber, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // كتم الصوت + طرد من المقعد
                  Row(
                    children: [
                      if (widget.seatIndex != null) ...[
                        Expanded(
                          child: _ControlBtn(
                            icon: widget.isSeatMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                            label: widget.isSeatMuted ? 'فتح الصوت' : 'كتم الصوت',
                            color: widget.isSeatMuted ? Colors.green : Colors.orange,
                            onTap: () => _run(() => RoomStateRepository().setSeatMuted(
                              widget.roomId, widget.seatIndex!, !widget.isSeatMuted,
                            ), successMsg: widget.isSeatMuted ? '✅ تم فتح الصوت' : '✅ تم كتم الصوت'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ControlBtn(
                            icon: Icons.logout_rounded,
                            label: 'طرد من المقعد',
                            color: Colors.deepOrange,
                            onTap: () => _run(() async {
                              await RoomStateRepository().leaveSeat(widget.roomId, widget.seatIndex!);
                            }, successMsg: '✅ تم الطرد من المقعد'),
                          ),
                        ),
                      ] else
                        const Expanded(child: SizedBox()),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // كتم الدردشة + طرد من الغرفة
                  Row(
                    children: [
                      Expanded(
                        child: _ControlBtn(
                          icon: isChatMuted ? Icons.chat_rounded : Icons.speaker_notes_off_rounded,
                          label: isChatMuted ? 'السماح بالكتابة' : 'منع الكتابة',
                          color: isChatMuted ? Colors.green : Colors.purple,
                          onTap: () => _run(() => RoomStateRepository().muteChatUser(
                            widget.roomId, widget.targetUserId, !isChatMuted,
                          ), successMsg: isChatMuted ? '✅ تم السماح بالكتابة' : '✅ تم منع الكتابة'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ControlBtn(
                          icon: Icons.exit_to_app_rounded,
                          label: 'طرد من الغرفة',
                          color: Colors.red,
                          onTap: () => _confirmKickFromRoom(),
                        ),
                      ),
                    ],
                  ),

                  // حظر + إعطاء عملات (إدارة فقط)
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ControlBtn(
                            icon: Icons.block_rounded,
                            label: 'حظر من التطبيق',
                            color: Colors.red.shade900,
                            onTap: () => _confirmBan(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ControlBtn(
                            icon: Icons.monetization_on_rounded,
                            label: 'منح عملات',
                            color: Colors.amber,
                            onTap: () => _showGiveCoins(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],

                const SizedBox(height: 4),
              ],
            ),
    );
  }

  Widget _avatar() {
    final url = widget.targetUserAvatar;
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2)),
      child: ClipOval(
        child: url != null
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : Container(color: AppColors.surfaceLight, child: Center(child: Text(widget.targetUserName[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)))),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withAlpha(80))),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
    );
  }

  void _confirmKickFromRoom() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A2E),
        title: const Text('تأكيد الطرد', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
        content: Text('هل تريد طرد "${widget.targetUserName}" من الغرفة؟', style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo'))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('طرد', style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
    if (ok == true) {
      _run(() async {
        // طرد من المقعد إذا كان جالساً
        if (widget.seatIndex != null) {
          await RoomStateRepository().leaveSeat(widget.roomId, widget.seatIndex!);
        }
        // تسجيل الطرد في Firestore
        await RoomStateRepository().kickFromRoom(widget.roomId, widget.targetUserId);
      }, successMsg: '✅ تم طرده من الغرفة');
    }
  }

  void _confirmBan() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A2E),
        title: const Text('حظر المستخدم', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('حظر "${widget.targetUserName}" من التطبيق؟', style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
          const SizedBox(height: 10),
          TextField(controller: ctrl, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'), decoration: const InputDecoration(hintText: 'سبب الحظر...', hintStyle: TextStyle(color: Colors.white38), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo'))),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context, true), child: const Text('حظر', style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
    if (ok == true) {
      _run(() => AdminRepository().banUser(widget.targetUserId, ctrl.text.trim()), successMsg: '✅ تم الحظر');
    }
  }

  void _showGiveCoins() async {
    final ctrl = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A2E),
        title: Text('منح عملات لـ ${widget.targetUserName}', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 14)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // أزرار سريعة
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [1000, 5000, 10000, 50000].map((v) => GestureDetector(
              onTap: () => Navigator.pop(context, v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.amber.withAlpha(30), border: Border.all(color: Colors.amber.withAlpha(100)), borderRadius: BorderRadius.circular(8)),
                child: Text('+$v', style: const TextStyle(color: Colors.amber, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'أو أدخل مبلغاً محدداً',
              hintStyle: TextStyle(color: Colors.white38),
              prefixIcon: Icon(Icons.monetization_on_rounded, color: Colors.amber),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.amber)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)),
            child: const Text('منح', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      _run(() => AdminRepository().giveCoins(widget.targetUserId, result), successMsg: '✅ تم منح $result عملة');
    }
  }
}

// ── ويدجيت زر التحكم ──────────────────────────────────────────────
class _ControlBtn extends StatelessWidget {
  const _ControlBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          border: Border.all(color: color.withAlpha(100)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Flexible(child: Text(label, style: TextStyle(color: color, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

// ── ملف الشخصي للمستخدم الحالي (داخل الغرفة) ───────────────────
class MyProfileSheet extends ConsumerStatefulWidget {
  const MyProfileSheet({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.onLeaveSeat,
    required this.onSendEmoji,
  });

  final String userId;
  final String userName;
  final String? userAvatar;
  final VoidCallback onLeaveSeat;
  final void Function(String emoji) onSendEmoji;

  @override
  ConsumerState<MyProfileSheet> createState() => _MyProfileSheetState();
}

class _MyProfileSheetState extends ConsumerState<MyProfileSheet> {
  int _followersCount = 0;
  int _friendsCount = 0;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (!mounted) return;
      final data = doc.data() ?? {};
      setState(() {
        _followersCount = data['followersCount'] ?? 0;
        _friendsCount = data['friendsCount'] ?? 0;
        _loadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A0A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),

          // صورة + اسم
          _buildAvatar(),
          const SizedBox(height: 10),
          Text(
            widget.userName,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Cairo'),
          ),

          const SizedBox(height: 20),

          // ايموجيات التفاعل (صف واحد × 4 + صف ثاني × 4)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _EmojiRow(
                  emojis: const ['😂', '😢', '😠', '😊'],
                  onSend: widget.onSendEmoji,
                ),
                const SizedBox(height: 10),
                _EmojiRow(
                  emojis: const ['😍', '😮', '😘', '😘←'],
                  onSend: widget.onSendEmoji,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // متابعون + أصدقاء
          if (_loadingStats)
            const SizedBox(height: 36, child: Center(child: CircularProgressIndicator(color: Colors.white38, strokeWidth: 2)))
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ProfileStat('متابعون', _followersCount),
                Container(width: 1, height: 40, color: Colors.white12),
                _ProfileStat('أصدقاء', _friendsCount),
              ],
            ),

          const SizedBox(height: 24),

          // زر النزول من المايك
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () {
                Navigator.pop(context);
                widget.onLeaveSeat();
              },
              icon: const Icon(Icons.mic_off_rounded, color: Colors.white, size: 18),
              label: const Text('نزول من المايك', style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final url = widget.userAvatar;
    return Container(
      width: 84, height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: 2.5),
      ),
      child: ClipOval(
        child: url != null
            ? CachedNetworkImage(imageUrl: url, fit: BoxFit.cover)
            : Container(
                color: AppColors.primary.withAlpha(60),
                child: Center(
                  child: Text(
                    widget.userName.isNotEmpty ? widget.userName[0].toUpperCase() : '؟',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
      ),
    );
  }
}

class _EmojiRow extends StatelessWidget {
  const _EmojiRow({required this.emojis, required this.onSend});
  final List<String> emojis;
  final void Function(String) onSend;

  Widget _emojiWidget(String e) {
    final isFlipped = e.endsWith('←');
    final raw = isFlipped ? e.replaceAll('←', '') : e;
    final text = Text(raw, style: const TextStyle(fontSize: 30));
    if (isFlipped) {
      return Transform.scale(scaleX: -1.0, child: text);
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: emojis.map((e) =>
        GestureDetector(
          onTap: () {
            onSend(e);
            HapticFeedback.lightImpact();
          },
          child: _emojiWidget(e),
        ),
      ).toList(),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'Cairo')),
      ],
    );
  }
}

// ── زر الإجراء الأساسي ────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withAlpha(80))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
