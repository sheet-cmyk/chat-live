import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/chat_colors.dart';
import '../../../../app/routes.dart';
import '../providers/auth_provider.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../../../levels/presentation/providers/level_provider.dart';
import '../../../admin/presentation/providers/admin_provider.dart';

// ── Upload helper ─────────────────────────────────────────────────────────────

Future<String?> _uploadToStorage(String path, String localPath) async {
  final bytes = await File(localPath).readAsBytes();
  final ref = FirebaseStorage.instance.ref(path);
  await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
  return await ref.getDownloadURL();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: Colors.black87, duration: const Duration(seconds: 3)));
  }

  Future<void> _pickAvatar(String uid) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, imageQuality: 85, maxWidth: 500,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final url = await _uploadToStorage('users/$uid/avatar.jpg', picked.path);
      await FirebaseAuth.instance.currentUser?.updatePhotoURL(url);
      await FirebaseFirestore.instance.collection('users').doc(uid)
          .set({'avatar': url}, SetOptions(merge: true));
      _toast('تم تحديث الصورة ✅');
    } catch (e) {
      _toast('فشل رفع الصورة: $e');
    }
    if (mounted) setState(() => _uploadingAvatar = false);
  }

  Future<void> _pickCover(String uid) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, imageQuality: 70, maxWidth: 900,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingCover = true);
    try {
      final url = await _uploadToStorage('users/$uid/cover.jpg', picked.path);
      await FirebaseFirestore.instance.collection('users').doc(uid)
          .set({'coverImage': url}, SetOptions(merge: true));
      _toast('تم تحديث الغلاف ✅');
    } catch (e) {
      _toast('فشل رفع الصورة: $e');
    }
    if (mounted) setState(() => _uploadingCover = false);
  }

  void _openEditSheet(String uid, Map<String, dynamic> profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(uid: uid, profile: profile),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(userProfileStreamProvider);
    final balance = ref.watch(balanceStreamProvider);
    final coins = balance.valueOrNull?['coins'] ?? 0;
    final diamonds = balance.valueOrNull?['diamonds'] ?? 0;
    final level = ref.watch(userLevelProvider);
    final progress = ref.watch(levelProgressProvider);
    final isAdmin = ref.watch(isAdminProvider).valueOrNull == true;

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('خطأ', style: TextStyle(color: AppColors.textSecondary)))),
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final profile = profileAsync.valueOrNull ?? {};
        final uid = user.uid;
        final name = (profile['displayName'] as String?)?.isNotEmpty == true
            ? profile['displayName'] as String
            : user.displayName ?? 'مستخدم';
        final avatar = profile['avatar'] as String? ?? user.photoURL;
        final cover = profile['coverImage'] as String?;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(slivers: [
            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Stack(clipBehavior: Clip.none, children: [
                // Cover image
                GestureDetector(
                  onTap: () => _pickCover(uid),
                  child: Stack(children: [
                    SizedBox(
                      height: 200, width: double.infinity,
                      child: cover != null
                          ? CachedNetworkImage(imageUrl: cover, fit: BoxFit.cover)
                          : Container(decoration: const BoxDecoration(gradient: AppColors.primaryGradient)),
                    ),
                    if (_uploadingCover)
                      Positioned.fill(child: Container(
                        color: Colors.black45,
                        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                      )),
                    Positioned(bottom: 10, right: 12,
                      child: _CamBadge(size: 32, iconSize: 16)),
                  ]),
                ),
                // Settings icon
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: IconButton(
                        icon: const Icon(Icons.settings_rounded, color: Colors.white),
                        onPressed: () => context.push(AppRoutes.settings),
                      ),
                    ),
                  ),
                ),
                // Avatar
                Positioned(bottom: -54, left: 0, right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: () => _pickAvatar(uid),
                      child: Stack(clipBehavior: Clip.none, children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.background, width: 4),
                            boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 16)],
                          ),
                          child: _uploadingAvatar
                              ? const CircleAvatar(radius: 50, backgroundColor: Colors.grey,
                                  child: CircularProgressIndicator(color: Colors.white))
                              : CircleAvatar(
                                  radius: 50,
                                  backgroundColor: AppColors.primary,
                                  backgroundImage: avatar != null
                                      ? CachedNetworkImageProvider(avatar) : null,
                                  child: avatar == null
                                      ? Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : '؟',
                                          style: const TextStyle(fontSize: 38, color: Colors.white, fontWeight: FontWeight.bold))
                                      : null,
                                ),
                        ),
                        Positioned(bottom: 2, right: 2,
                          child: _CamBadge(size: 26, iconSize: 13, color: AppColors.primary)),
                      ]),
                    ),
                  )),
              ]),
            ),

            // ── Body ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 64),
                child: Column(children: [
                  // Name + edit
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(name, style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 22,
                      fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _openEditSheet(uid, profile),
                      child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20)),
                  ]),
                  const SizedBox(height: 10),
                  // Level badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14)),
                    child: Text('${level.badge} المستوى ${level.level} · ${level.title}',
                      style: const TextStyle(color: Colors.white, fontFamily: 'Cairo',
                        fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  // Progress
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress, minHeight: 6,
                        backgroundColor: AppColors.surfaceLight,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stats
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.card, borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      _StatItem(icon: '🪙', value: '$coins', label: 'عملة'),
                      Container(width: 1, height: 36, color: AppColors.divider),
                      _StatItem(icon: '💎', value: '$diamonds', label: 'ماسة'),
                      Container(width: 1, height: 36, color: AppColors.divider),
                      _StatItem(icon: '⭐', value: 'Lv.${level.level}', label: 'المستوى'),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  // Gift Level Bar
                  _GiftLevelBar(profile: profile),
                  const SizedBox(height: 20),
                  // Buttons
                  _PBtn(icon: Icons.account_balance_wallet_rounded, label: 'محفظتي', color: AppColors.gold, onTap: () => context.push(AppRoutes.wallet)),
                  _PBtn(icon: Icons.workspace_premium_rounded, label: 'عضوية VIP', color: const Color(0xFFE040FB), onTap: () => context.push(AppRoutes.vip)),
                  _PBtn(icon: Icons.casino_rounded, label: 'عجلة الحظ 🎡', color: AppColors.accent, onTap: () => context.push(AppRoutes.game)),
                  _PBtn(icon: Icons.calendar_today_rounded, label: 'المكافأة اليومية 🎁', color: AppColors.gold, onTap: () => context.push('/daily-reward')),
                  _PBtn(icon: Icons.history_rounded, label: 'الغرف المزارة', color: AppColors.accent, onTap: () => context.push('/room-history')),
                  _PBtn(icon: Icons.people_rounded, label: 'الأصدقاء', color: AppColors.success, onTap: () => context.push('/friends')),
                  _PBtn(icon: Icons.edit_rounded, label: 'تعديل الملف الشخصي', color: AppColors.primary, onTap: () => _openEditSheet(uid, profile)),
                  if (isAdmin)
                    _PBtn(icon: Icons.admin_panel_settings_rounded, label: 'لوحة الإدارة ⚙️', color: Colors.amber, onTap: () => context.push(AppRoutes.admin)),
                  _PBtn(
                    icon: Icons.logout_rounded, label: 'تسجيل الخروج', color: AppColors.error,
                    onTap: () async {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go(AppRoutes.login);
                    },
                  ),
                  const SizedBox(height: 36),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Camera badge ──────────────────────────────────────────────────────────────

class _CamBadge extends StatelessWidget {
  const _CamBadge({required this.size, required this.iconSize, this.color});
  final double size, iconSize;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      color: color ?? Colors.black54,
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.background, width: 1.5),
    ),
    child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: iconSize),
  );
}

// ── Edit Sheet ────────────────────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.uid, required this.profile});
  final String uid;
  final Map<String, dynamic> profile;
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _nameCtrl;
  XFile? _roomFile;
  bool _loading = false;
  String? _nameColorHex;
  String? _textColorHex;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.profile['displayName'] as String? ?? '');
    _nameColorHex = widget.profile['nameColor'] as String?;
    _textColorHex = widget.profile['textColor'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickRoom() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery, imageQuality: 75, maxWidth: 700);
    if (picked != null && mounted) setState(() => _roomFile = picked);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      final updates = <String, dynamic>{};

      if (name != (widget.profile['displayName'] ?? '')) {
        updates['displayName'] = name;
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      }

      if (_roomFile != null) {
        final url = await _uploadToStorage(
          'users/${widget.uid}/room.jpg', _roomFile!.path);
        updates['roomPhoto'] = url;
      }

      if (_nameColorHex != null) updates['nameColor'] = _nameColorHex;
      if (_textColorHex != null) updates['textColor'] = _textColorHex;

      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .set(updates, SetOptions(merge: true));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red.shade800));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomPhoto = widget.profile['roomPhoto'] as String?;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 38, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          const Text('تعديل الملف الشخصي',
            style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo',
              fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 20),

          // Name field
          TextField(
            controller: _nameCtrl,
            autofocus: false,
            maxLength: 30,
            style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 15),
            decoration: InputDecoration(
              labelText: 'الاسم الظاهر',
              labelStyle: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'),
              prefixIcon: const Icon(Icons.person_rounded, color: AppColors.primary),
              filled: true, fillColor: AppColors.background,
              counterStyle: const TextStyle(color: AppColors.textHint, fontSize: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          const SizedBox(height: 14),

          // Room photo picker
          Align(alignment: Alignment.centerRight,
            child: const Text('صورة الروم',
              style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 13))),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickRoom,
            child: Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              clipBehavior: Clip.antiAlias,
              child: _roomFile != null
                  ? Image.file(File(_roomFile!.path), fit: BoxFit.cover)
                  : roomPhoto != null
                      ? CachedNetworkImage(imageUrl: roomPhoto, fit: BoxFit.cover)
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.meeting_room_rounded, color: AppColors.textHint, size: 36),
                          const SizedBox(height: 6),
                          const Text('اضغط لاختيار صورة الروم',
                            style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 12)),
                        ]),
            ),
          ),
          const SizedBox(height: 16),

          // Color pickers
          _ColorPicker(
            label: 'لون الاسم',
            selectedHex: _nameColorHex,
            onSelect: (h) => setState(() => _nameColorHex = h),
          ),
          const SizedBox(height: 14),
          _ColorPicker(
            label: 'لون الكتابة',
            selectedHex: _textColorHex,
            onSelect: (h) => setState(() => _textColorHex = h),
          ),
          const SizedBox(height: 20),

          // Save
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('حفظ ✅',
                      style: TextStyle(color: Colors.white, fontFamily: 'Cairo',
                        fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  const _StatItem({required this.icon, required this.value, required this.label});
  final String icon, value, label;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(icon, style: const TextStyle(fontSize: 20)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
    Text(label, style: const TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 11)),
  ]);
}

class _PBtn extends StatelessWidget {
  const _PBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
    clipBehavior: Clip.antiAlias,
    child: Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(label, style: TextStyle(color: color, fontFamily: 'Cairo', fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.textHint),
      ),
    ),
  );
}

// ── Gift Level Bar ────────────────────────────────────────────────────────────

class _GiftLevelBar extends StatelessWidget {
  const _GiftLevelBar({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final totalSent = (profile['totalGiftsSent'] as num?)?.toInt() ?? 0;
    if (totalSent == 0) return const SizedBox.shrink();

    final lvlIdx = giftSendLevelIndex(totalSent);
    final lvl = kGiftSendLevels[lvlIdx];
    final isMax = lvlIdx >= kGiftSendLevels.length - 1;
    final nextMin = isMax ? lvl.$1 : kGiftSendLevels[lvlIdx + 1].$1;
    final progress = isMax
        ? 1.0
        : ((totalSent - lvl.$1) / (nextMin - lvl.$1)).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${lvl.$3} راسل الهدايا',
                  style: TextStyle(
                    color: lvl.$4,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  'Lv.${lvlIdx + 1} · ${lvl.$2}',
                  style: TextStyle(
                    color: lvl.$4,
                    fontSize: 11,
                    fontFamily: 'Cairo',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceLight,
                valueColor: AlwaysStoppedAnimation<Color>(lvl.$4),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '💎 ${fmtDiamonds(totalSent)} أرسلت للناس',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Cairo',
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Color Picker ──────────────────────────────────────────────────────────────

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.label,
    required this.selectedHex,
    required this.onSelect,
  });
  final String label;
  final String? selectedHex;
  final void Function(String hex) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontFamily: 'Cairo',
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: kChatColors.map((c) {
            final isSelected = selectedHex == c.$1;
            final clr = hexColor(c.$1);
            return GestureDetector(
              onTap: () => onSelect(c.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: clr,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: clr.withAlpha(100), blurRadius: 8)]
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: clr.computeLuminance() > 0.5
                            ? Colors.black87
                            : Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
