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
import '../../../../app/routes.dart';
import '../providers/auth_provider.dart';
import '../../../gift/presentation/widgets/gift_panel.dart';
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(userProfileStreamProvider);
    final balance = ref.watch(balanceStreamProvider);
    final coins = balance.valueOrNull?['coins'] ?? 0;
    final diamonds = balance.valueOrNull?['diamonds'] ?? 0;
    final level = ref.watch(userLevelProvider);
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
                  // Name + edit icon → opens unified Profile screen
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(name, style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 22,
                      fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => context.push(AppRoutes.settings),
                      child: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20)),
                  ]),

                  // الجنس + الدولة
                  if (profile['gender'] != null || profile['country'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (profile['gender'] != null) ...[
                            _GenderBadge(gender: profile['gender'] as String),
                            if (profile['country'] != null)
                              const SizedBox(width: 8),
                          ],
                          if (profile['country'] != null)
                            _CountryBadge(country: profile['country'] as String),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),
                  _SocialStats(uid: uid, profile: profile),
                  const SizedBox(height: 12),
                  _SupportLevelCard(
                    diamonds: (profile['totalGiftDiamonds'] as num?)?.toInt()
                        ?? (profile['diamonds'] as num?)?.toInt()
                        ?? 0,
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
                  const SizedBox(height: 20),
                  // Buttons
                  _PBtn(icon: Icons.account_balance_wallet_rounded, label: 'محفظتي', color: AppColors.gold, onTap: () => context.push(AppRoutes.wallet)),
                  _PBtn(icon: Icons.workspace_premium_rounded, label: 'عضوية VIP', color: const Color(0xFFE040FB), onTap: () => context.push(AppRoutes.vip)),
                  _PBtn(icon: Icons.casino_rounded, label: 'عجلة الحظ 🎡', color: AppColors.accent, onTap: () => context.push(AppRoutes.game)),
                  _PBtn(icon: Icons.calendar_today_rounded, label: 'المكافأة اليومية 🎁', color: AppColors.gold, onTap: () => context.push('/daily-reward')),
                  _PBtn(icon: Icons.history_rounded, label: 'الغرف المزارة', color: AppColors.accent, onTap: () => context.push('/room-history')),
                  _PBtn(icon: Icons.people_rounded, label: 'الأصدقاء', color: AppColors.success, onTap: () => context.push('/friends')),
                  _PBtn(icon: Icons.settings_rounded, label: 'الإعدادات', color: AppColors.primary, onTap: () => context.push(AppRoutes.settings)),
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

// ── Widgets ───────────────────────────────────────────────────────────────────

class _GenderBadge extends StatelessWidget {
  const _GenderBadge({required this.gender});
  final String gender;

  @override
  Widget build(BuildContext context) {
    final isFemale = gender == 'female';
    final color = isFemale ? const Color(0xFFF48FB1) : const Color(0xFF90CAF9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        isFemale ? '♀ أنثى' : '♂ ذكر',
        style: TextStyle(
          fontSize: 13, fontFamily: 'Cairo',
          fontWeight: FontWeight.w600, color: color,
        ),
      ),
    );
  }
}

class _CountryBadge extends StatelessWidget {
  const _CountryBadge({required this.country});
  final String country;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(
        country,
        style: const TextStyle(fontSize: 14, fontFamily: 'Cairo', color: AppColors.textPrimary),
      ),
    );
  }
}

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

// ── Support Level (مستوى الدعم) ───────────────────────────────────────────────

({int level, int current, int needed}) _calcSupportLevel(int diamonds) {
  const ranges = [
    (1,   10,  20000),    (10,  15,  50000),   (15,  30,  120000),
    (30,  50,  300000),   (50,  70,  500000),   (70,  90,  1500000),
    (90,  120, 3000000),  (120, 150, 6000000),  (150, 200, 12000000),
    (200, 300, 25000000), (300, 400, 50000000), (400, 500, 100000000),
  ];
  int cum = 0;
  for (final (s, e, p) in ranges) {
    final total = (e - s) * p;
    if (diamonds < cum + total) {
      final inn = diamonds - cum;
      final off = inn ~/ p;
      return (level: s + off, current: inn - off * p, needed: p);
    }
    cum += total;
  }
  return (level: 500, current: 0, needed: 0);
}

Color _suppColor(int level) {
  if (level <  10) return const Color(0xFF9E9E9E);
  if (level <  30) return const Color(0xFF42A5F5);
  if (level <  50) return const Color(0xFF66BB6A);
  if (level <  70) return const Color(0xFFAB47BC);
  if (level <  90) return const Color(0xFFFFD700);
  if (level < 150) return const Color(0xFFFF9800);
  if (level < 300) return const Color(0xFFE91E63);
  return const Color(0xFFFF5252);
}

String _suppFmt(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000)    return '${(n / 1000).toStringAsFixed(0)}K';
  return '$n';
}

class _SupportLevelCard extends StatelessWidget {
  const _SupportLevelCard({required this.diamonds});
  final int diamonds;

  @override
  Widget build(BuildContext context) {
    final info     = _calcSupportLevel(diamonds);
    final color    = _suppColor(info.level);
    final progress = info.needed > 0 ? (info.current / info.needed).clamp(0.0, 1.0) : 1.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'مستوى الدعم',
                style: TextStyle(color: color, fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'Lv. ${info.level}',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.surfaceLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            info.needed > 0
                ? '💎 ${_suppFmt(info.current)} / ${_suppFmt(info.needed)}'
                : '💎 MAX',
            style: TextStyle(color: color.withAlpha(180), fontFamily: 'Cairo', fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ── Social Stats (متابعين / معجبين / زوار) ───────────────────────────────────

// ── Social Stats (متابَعون / معجبون / زوار) ──────────────────────────────────

class _SocialStats extends StatelessWidget {
  const _SocialStats({required this.uid, required this.profile});
  final String uid;
  final Map<String, dynamic> profile;

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}K';
    return '$n';
  }

  void _showList(BuildContext context, String collection, String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _UserListSheet(uid: uid, collection: collection, title: title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final following = (profile['followingCount'] as num?)?.toInt() ?? 0;
    final followers = (profile['followersCount'] as num?)?.toInt() ?? 0;
    final visitors  = (profile['visitorsCount']  as num?)?.toInt() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        _card(_fmt(following), 'متابَعون',
            () => _showList(context, 'following', 'المتابَعون')),
        const SizedBox(width: 10),
        _card(_fmt(followers), 'معجبون',
            () => _showList(context, 'followers', 'المعجبون')),
        const SizedBox(width: 10),
        _card(_fmt(visitors), 'زوار',
            () => _showList(context, 'visitors', 'الزوار')),
      ]),
    );
  }

  Widget _card(String value, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(value, style: const TextStyle(
                  color: AppColors.textPrimary, fontFamily: 'Cairo',
                  fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(
                  color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── User List Sheet ───────────────────────────────────────────────────────────

class _UserListSheet extends StatelessWidget {
  const _UserListSheet(
      {required this.uid, required this.collection, required this.title});
  final String uid, collection, title;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(
              color: AppColors.textPrimary, fontFamily: 'Cairo',
              fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Divider(color: AppColors.divider, height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users').doc(uid)
                  .collection(collection)
                  .orderBy('addedAt', descending: true)
                  .limit(50).snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(child: Text('لا يوجد بيانات بعد',
                      style: TextStyle(
                          color: AppColors.textHint, fontFamily: 'Cairo')));
                }
                return ListView.builder(
                  controller: ctrl,
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final docId = docs[i].id;
                    final d = docs[i].data() as Map<String, dynamic>;
                    final name = d['displayName'] as String? ??
                        d['name'] as String? ?? 'مستخدم';
                    final avatar = d['avatar'] as String?;
                    return ListTile(
                      onTap: () => showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) =>
                            _OtherUserProfileSheet(targetUid: docId),
                      ),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.surfaceLight,
                        backgroundImage:
                            avatar != null ? NetworkImage(avatar) : null,
                        child: avatar == null
                            ? Text(name.isNotEmpty ? name[0] : '؟',
                                style: const TextStyle(
                                    color: Colors.white, fontFamily: 'Cairo'))
                            : null,
                      ),
                      title: Text(name, style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                      trailing: const Icon(
                          Icons.chevron_left_rounded,
                          color: AppColors.textHint, size: 18),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Other User Profile Sheet ──────────────────────────────────────────────────

class _OtherUserProfileSheet extends ConsumerStatefulWidget {
  const _OtherUserProfileSheet({required this.targetUid});
  final String targetUid;

  @override
  ConsumerState<_OtherUserProfileSheet> createState() =>
      _OtherUserProfileSheetState();
}

class _OtherUserProfileSheetState
    extends ConsumerState<_OtherUserProfileSheet> {
  Map<String, dynamic>? _data;
  bool _isFollowing = false;
  bool _loadingFollow = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;

    final db = FirebaseFirestore.instance;

    // جلب بيانات المستخدم المستهدف
    final userDoc = await db.collection('users').doc(widget.targetUid).get();
    final data = userDoc.data() ?? {};

    // هل أنا أتابعه؟
    final followDoc = await db
        .collection('users').doc(widget.targetUid)
        .collection('followers').doc(me.uid).get();

    // تسجيل الزيارة (أول زيارة فقط تزيد العداد)
    final myProfile = ref.read(userProfileStreamProvider).valueOrNull;
    final visitorRef = db
        .collection('users').doc(widget.targetUid)
        .collection('visitors').doc(me.uid);
    final visitorDoc = await visitorRef.get();
    final isFirstVisit = !visitorDoc.exists;

    final batch = db.batch();
    batch.set(visitorRef, {
      'displayName': myProfile?['displayName'] ?? me.displayName ?? 'مستخدم',
      'avatar': myProfile?['avatar'] ?? me.photoURL,
      'addedAt': FieldValue.serverTimestamp(),
    });
    if (isFirstVisit) {
      batch.update(
        db.collection('users').doc(widget.targetUid),
        {'visitorsCount': FieldValue.increment(1)},
      );
    }
    await batch.commit();

    if (mounted) {
      setState(() {
        _data = data;
        _isFollowing = followDoc.exists;
        _loading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    setState(() => _loadingFollow = true);

    final db = FirebaseFirestore.instance;
    final myProfile = ref.read(userProfileStreamProvider).valueOrNull;
    final batch = db.batch();

    if (_isFollowing) {
      batch.delete(db.collection('users').doc(widget.targetUid)
          .collection('followers').doc(me.uid));
      batch.delete(db.collection('users').doc(me.uid)
          .collection('following').doc(widget.targetUid));
      batch.update(db.collection('users').doc(widget.targetUid),
          {'followersCount': FieldValue.increment(-1)});
      batch.update(db.collection('users').doc(me.uid),
          {'followingCount': FieldValue.increment(-1)});
    } else {
      batch.set(
        db.collection('users').doc(widget.targetUid)
            .collection('followers').doc(me.uid),
        {
          'displayName': myProfile?['displayName'] ?? me.displayName ?? 'مستخدم',
          'avatar': myProfile?['avatar'] ?? me.photoURL,
          'addedAt': FieldValue.serverTimestamp(),
        },
      );
      batch.set(
        db.collection('users').doc(me.uid)
            .collection('following').doc(widget.targetUid),
        {
          'displayName': _data?['displayName'] ?? 'مستخدم',
          'avatar': _data?['avatar'],
          'addedAt': FieldValue.serverTimestamp(),
        },
      );
      batch.update(db.collection('users').doc(widget.targetUid),
          {'followersCount': FieldValue.increment(1)});
      batch.update(db.collection('users').doc(me.uid),
          {'followingCount': FieldValue.increment(1)});
    }

    await batch.commit();
    if (mounted) {
      setState(() {
        _isFollowing = !_isFollowing;
        _loadingFollow = false;
      });
    }
  }

  void _openGift(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => GiftPanel(
        targetUserId: widget.targetUid,
        targetUserName: _data?['displayName'] as String?,
        targetUserAvatar: _data?['avatar'] as String?,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        height: 220,
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final data = _data ?? {};
    final name    = data['displayName'] as String? ?? 'مستخدم';
    final avatar  = data['avatar']      as String?;
    final gender  = data['gender']      as String?;
    final country = data['country']     as String?;
    final followers = (data['followersCount'] as num?)?.toInt() ?? 0;
    final following = (data['followingCount'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(child: Container(
              width: 38, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),

          // Avatar
          CircleAvatar(
            radius: 46,
            backgroundColor: AppColors.primary,
            backgroundImage:
                avatar != null ? CachedNetworkImageProvider(avatar) : null,
            child: avatar == null
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '؟',
                    style: const TextStyle(
                        fontSize: 34, color: Colors.white,
                        fontWeight: FontWeight.bold))
                : null,
          ),
          const SizedBox(height: 12),

          // Name
          Text(name, style: const TextStyle(
              color: AppColors.textPrimary, fontFamily: 'Cairo',
              fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),

          // Gender + Country badges
          if (gender != null || country != null)
            Wrap(spacing: 8, children: [
              if (gender != null)
                _badge(
                  gender == 'female' ? '♀ أنثى' : '♂ ذكر',
                  gender == 'female'
                      ? const Color(0xFFF48FB1)
                      : const Color(0xFF90CAF9),
                ),
              if (country != null) _badge(country, AppColors.primary),
            ]),
          const SizedBox(height: 16),

          // Stats row
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _statItem(_fmt(followers), 'معجبون'),
            Container(width: 1, height: 30,
                color: AppColors.divider, margin: const EdgeInsets.symmetric(horizontal: 20)),
            _statItem(_fmt(following), 'متابَعون'),
          ]),
          const SizedBox(height: 20),

          // Action buttons
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isFollowing
                      ? AppColors.surfaceLight
                      : AppColors.primary,
                  foregroundColor:
                      _isFollowing ? AppColors.textPrimary : Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: _loadingFollow ? null : _toggleFollow,
                icon: _loadingFollow
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        _isFollowing
                            ? Icons.person_remove_rounded
                            : Icons.person_add_rounded,
                        size: 18),
                label: Text(
                  _isFollowing ? 'إلغاء المتابعة' : 'متابعة',
                  style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 13),
              ),
              onPressed: () => _openGift(context),
              child: const Text('🎁', style: TextStyle(fontSize: 20)),
            ),
          ]),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return '$n';
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(25),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withAlpha(80)),
    ),
    child: Text(text,
        style: TextStyle(
            color: color,
            fontFamily: 'Cairo',
            fontSize: 12,
            fontWeight: FontWeight.w600)),
  );

  Widget _statItem(String value, String label) => Column(
    children: [
      Text(value, style: const TextStyle(
          color: AppColors.textPrimary, fontFamily: 'Cairo',
          fontSize: 17, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(
          color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 12)),
    ],
  );
}

