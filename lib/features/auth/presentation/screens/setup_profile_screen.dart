import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/routes.dart';
import '../../data/models/user_model.dart';
import '../providers/auth_provider.dart';
import '../../../../features/wallet/data/repositories/wallet_repository.dart';

// ── قائمة الدول ────────────────────────────────────────────────────────────────
const _kCountries = [
  ('🇸🇦', 'السعودية'),  ('🇮🇶', 'العراق'),    ('🇦🇪', 'الإمارات'),
  ('🇰🇼', 'الكويت'),   ('🇶🇦', 'قطر'),        ('🇧🇭', 'البحرين'),
  ('🇴🇲', 'عُمان'),    ('🇾🇪', 'اليمن'),       ('🇯🇴', 'الأردن'),
  ('🇸🇾', 'سوريا'),    ('🇱🇧', 'لبنان'),       ('🇵🇸', 'فلسطين'),
  ('🇪🇬', 'مصر'),      ('🇱🇾', 'ليبيا'),        ('🇹🇳', 'تونس'),
  ('🇩🇿', 'الجزائر'),  ('🇲🇦', 'المغرب'),       ('🇸🇩', 'السودان'),
  ('🇹🇷', 'تركيا'),    ('🇮🇷', 'إيران'),         ('🇵🇰', 'باكستان'),
  ('🇮🇳', 'الهند'),    ('🇮🇩', 'إندونيسيا'),    ('🇲🇾', 'ماليزيا'),
  ('🇬🇧', 'بريطانيا'), ('🇺🇸', 'أمريكا'),       ('🇩🇪', 'ألمانيا'),
  ('🇫🇷', 'فرنسا'),    ('🇸🇪', 'السويد'),        ('🇨🇦', 'كندا'),
  ('🇦🇺', 'أستراليا'),
];

// ── ألوان الاسم ────────────────────────────────────────────────────────────────
const _kNameColors = [
  Color(0xFFFFFFFF), Color(0xFFFFD700), Color(0xFFFF6B6B),
  Color(0xFF4FC3F7), Color(0xFF81C784), Color(0xFFCE93D8),
  Color(0xFFFF8A65), Color(0xFF4DB6AC), Color(0xFFF06292),
  Color(0xFFAED581),
];

class SetupProfileScreen extends ConsumerStatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  ConsumerState<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends ConsumerState<SetupProfileScreen>
    with SingleTickerProviderStateMixin {
  final _nickCtrl = TextEditingController();
  String? _gender;
  String? _country;
  File?   _avatarFile;
  bool    _saving    = false;
  Color   _nameColor = const Color(0xFFFFFFFF);

  late final AnimationController _anim;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _anim   = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  // ── اختيار الصورة ──────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ImageSourceSheet(),
    );
    if (src == null) return;
    final picked = await ImagePicker().pickImage(source: src, imageQuality: 85);
    if (picked != null && mounted) setState(() => _avatarFile = File(picked.path));
  }

  // ── اختيار الدولة ──────────────────────────────────────────────────────────
  Future<void> _pickCountry() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CountryPicker(
        selected: _country,
        onSelect: (c) => Navigator.pop(context, c),
      ),
    );
    if (result != null && mounted) setState(() => _country = result);
  }

  // ── رفع الصورة إلى Storage ─────────────────────────────────────────────────
  // Uses putData(bytes) — more reliable than putFile on Android 10+ scoped storage.
  // Same path convention as profile_screen: users/{uid}/avatar.jpg
  Future<String> _uploadAvatar(String uid) async {
    final bytes = await _avatarFile!.readAsBytes();
    final storageRef = FirebaseStorage.instance.ref('users/$uid/avatar.jpg');
    await storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return storageRef.getDownloadURL();
  }

  // ── حفظ الملف الشخصي ───────────────────────────────────────────────────────
  Future<void> _save() async {
    final nick = _nickCtrl.text.trim();

    if (_avatarFile == null) { _toast('يرجى إضافة صورة شخصية'); return; }
    if (nick.isEmpty)        { _toast('الرجاء كتابة لقبك'); return; }
    if (nick.length < 2)     { _toast('اللقب قصير جداً'); return; }
    if (_gender == null)     { _toast('يرجى اختيار الجنس'); return; }

    setState(() => _saving = true);
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _toast('انتهت الجلسة، سجّل الدخول مجدداً');
        setState(() => _saving = false);
        return;
      }

      // رفع الصورة — مطلوب، نوقف في حال الفشل
      String? avatarUrl;
      try {
        avatarUrl = await _uploadAvatar(firebaseUser.uid);
      } catch (e) {
        // Show a dialog so the user clearly sees the failure and can retry
        if (!mounted) return;
        setState(() => _saving = false);
        await _showUploadErrorDialog(e.toString());
        return;
      }

      final user = UserModel(
        uid:         firebaseUser.uid,
        displayName: nick,
        avatar:      avatarUrl,
        gender:      _gender,
        country:     _country,
        phoneNumber: firebaseUser.phoneNumber ?? '',
        createdAt:   DateTime.now(),
      );

      // حفظ المستخدم في Firestore
      await ref.read(authRepositoryProvider).saveNewUser(user);

      // حفظ لون الاسم
      final colorHex = '#${_nameColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .set({'nameColor': colorHex}, SetOptions(merge: true));

      await WalletRepository().ensureWelcomeBonus(firebaseUser.uid);

      if (!mounted) return;
      await _showWelcomeDialog();
      if (!mounted) return;
      context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) _toast('خطأ: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showUploadErrorDialog(String error) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Text('⚠️', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Text('فشل رفع الصورة',
              style: TextStyle(fontFamily: 'Cairo', color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'تعذّر رفع الصورة إلى Firebase Storage.\n\nتأكد من:',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'Cairo', color: Color(0xFFB0B0C8),
                    fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: 8),
              const Text('• قواعد Storage تسمح بالكتابة\n• اتصالك بالإنترنت يعمل',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontFamily: 'Cairo', color: Color(0xFFB0B0C8), fontSize: 12)),
              const SizedBox(height: 10),
              Text(error.length > 120 ? error.substring(0, 120) : error,
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 10, color: Colors.red)),
            ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً — أحاول مجدداً',
                style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF9C4DCC),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _showWelcomeDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎁', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            const Text('مرحباً بك في LivChat!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  fontFamily: 'Cairo', color: Colors.white)),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontFamily: 'Cairo', fontSize: 15,
                    color: Color(0xFFB0B0C8), height: 1.6),
                children: [
                  TextSpan(text: 'حصلت على '),
                  TextSpan(text: '500,000 عملة',
                    style: TextStyle(fontWeight: FontWeight.w800,
                        color: Color(0xFFCE93D8), fontSize: 17)),
                  TextSpan(text: '\nكهدية ترحيب! 🎉'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity, height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: Text('ابدأ الاستمتاع!',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w700, fontFamily: 'Cairo'))),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: const Color(0xFF9C27B0),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A15),
      body: FadeTransition(
        opacity: _fadeIn,
        child: Stack(
          children: [
            // ── خلفية متدرجة ─────────────────────────────────────────────────
            Positioned(
              top: -80, right: -80,
              child: _GlowBlob(200, const Color(0xFF6A1B9A)),
            ),
            Positioned(
              bottom: -60, left: -60,
              child: _GlowBlob(180, const Color(0xFF4A148C)),
            ),

            SafeArea(
              child: Column(
                children: [
                  // ── رأس الصفحة ───────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(children: [
                          const Text(
                            'إعداد الملف الشخصي',
                            style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800,
                              fontFamily: 'Cairo', color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 40, height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)]),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),

                  // ── المحتوى ───────────────────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                          // ── الصورة الشخصية ─────────────────────────────────
                          Center(
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Stack(clipBehavior: Clip.none, children: [
                                Container(
                                  width: 120, height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF2D2D4A), Color(0xFF1A1A2E)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: _avatarFile != null
                                          ? const Color(0xFF9C27B0)
                                          : const Color(0xFF3D3D5C),
                                      width: _avatarFile != null ? 3 : 2,
                                    ),
                                    boxShadow: _avatarFile != null
                                        ? [BoxShadow(
                                            color: const Color(0xFF9C27B0).withAlpha(80),
                                            blurRadius: 20, spreadRadius: 2)]
                                        : null,
                                  ),
                                  child: ClipOval(
                                    child: _avatarFile != null
                                        ? Image.file(_avatarFile!, fit: BoxFit.cover,
                                            width: 120, height: 120)
                                        : const Icon(Icons.person_rounded,
                                            size: 56, color: Color(0xFF5A5A7A)),
                                  ),
                                ),
                                Positioned(
                                  bottom: 2, right: 2,
                                  child: Container(
                                    width: 36, height: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                          colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)]),
                                      border: Border.all(
                                          color: const Color(0xFF0A0A15), width: 2.5),
                                      boxShadow: [BoxShadow(
                                        color: const Color(0xFF9C27B0).withAlpha(100),
                                        blurRadius: 10)],
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              ]),
                            ),
                          ),

                          // إشارة الإجبارية
                          if (_avatarFile == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Center(
                                child: Text('* الصورة الشخصية إجبارية',
                                  style: TextStyle(
                                    fontSize: 11, fontFamily: 'Cairo',
                                    color: Colors.red.shade300)),
                              ),
                            ),

                          const SizedBox(height: 28),

                          // ── حقل اللقب ─────────────────────────────────────
                          const _DarkLabel('اللقب *'),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nickCtrl,
                            textAlign: TextAlign.right,
                            maxLength: 30,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                                fontSize: 15, fontFamily: 'Cairo',
                                color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'أدخل لقبك...',
                              hintStyle: const TextStyle(
                                  fontFamily: 'Cairo', color: Color(0xFF5A5A7A)),
                              prefixIcon: const Icon(Icons.person_rounded,
                                  color: Color(0xFF9C27B0)),
                              counterStyle: const TextStyle(
                                  color: Color(0xFF5A5A7A), fontSize: 11),
                              filled: true,
                              fillColor: const Color(0xFF1A1A2E),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFF2D2D4A)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFF2D2D4A)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                    color: Color(0xFF9C27B0), width: 1.5),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // ── الجنس (إجباري) ────────────────────────────────
                          const _DarkLabel('الجنس *'),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _GenderCard(
                                icon: Icons.male_rounded,
                                label: 'ذكر',
                                selected: _gender == 'male',
                                activeColor: const Color(0xFF5C6BC0),
                                onTap: () => setState(() => _gender = 'male'),
                              ),
                              _GenderCard(
                                icon: Icons.female_rounded,
                                label: 'أنثى',
                                selected: _gender == 'female',
                                activeColor: const Color(0xFFE91E63),
                                onTap: () => setState(() => _gender = 'female'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Center(
                            child: Text('* بعد تحديد الجنس لا يمكن تغييره',
                              style: TextStyle(fontSize: 11, color: Color(0xFFEF9A9A),
                                  fontFamily: 'Cairo')),
                          ),

                          const SizedBox(height: 20),

                          // ── الدولة (اختياري) ──────────────────────────────
                          const _DarkLabel('الدولة'),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _pickCountry,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 15),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A2E),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _country != null
                                      ? const Color(0xFF9C27B0)
                                      : const Color(0xFF2D2D4A),
                                  width: _country != null ? 1.5 : 1,
                                ),
                              ),
                              child: Row(children: [
                                Icon(Icons.keyboard_arrow_down_rounded,
                                  color: _country != null
                                      ? const Color(0xFF9C27B0)
                                      : const Color(0xFF5A5A7A)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _country != null
                                        ? _country!.split(' ').sublist(1).join(' ')
                                        : 'اختر دولتك (اختياري)',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontFamily: 'Cairo', fontSize: 15,
                                      color: _country != null
                                          ? Colors.white
                                          : const Color(0xFF5A5A7A),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(_country?.split(' ').first ?? '🌍',
                                  style: const TextStyle(fontSize: 22)),
                              ]),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── لون الاسم ──────────────────────────────────────
                          const _DarkLabel('لون الاسم'),
                          const SizedBox(height: 10),

                          // معاينة الاسم بالنص
                          if (_nickCtrl.text.isNotEmpty)
                            Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _nameColor,
                                  shadows: [Shadow(
                                    color: _nameColor.withAlpha(120),
                                    blurRadius: 8,
                                  )],
                                ),
                                child: Text(_nickCtrl.text),
                              ),
                            ),

                          const SizedBox(height: 10),

                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _kNameColors.map((c) {
                                final isSel = _nameColor == c;
                                return GestureDetector(
                                  onTap: () => setState(() => _nameColor = c),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    margin: const EdgeInsets.only(left: 10),
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSel
                                            ? Colors.white
                                            : const Color(0xFF2D2D4A),
                                        width: isSel ? 3 : 1.5,
                                      ),
                                      boxShadow: isSel
                                          ? [BoxShadow(color: c.withAlpha(160),
                                              blurRadius: 12)]
                                          : null,
                                    ),
                                    child: isSel
                                        ? Icon(Icons.check_rounded,
                                            color: c.computeLuminance() > 0.5
                                                ? Colors.black87 : Colors.white,
                                            size: 20)
                                        : null,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // ── زر الحفظ (ثابت في الأسفل) ─────────────────────────────
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20, 8, 20,
                      MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                    child: GestureDetector(
                      onTap: _saving ? null : _save,
                      child: AnimatedOpacity(
                        opacity: _saving ? 0.7 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [BoxShadow(
                              color: const Color(0xFF9C27B0).withAlpha(100),
                              blurRadius: 16, offset: const Offset(0, 6),
                            )],
                          ),
                          child: Center(
                            child: _saving
                                ? const SizedBox(width: 24, height: 24,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5))
                                : const Text('حفظ وابدأ',
                                    style: TextStyle(fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        fontFamily: 'Cairo')),
                          ),
                        ),
                      ),
                    ),
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

// ── تسمية حقل داكنة ───────────────────────────────────────────────────────────
class _DarkLabel extends StatelessWidget {
  const _DarkLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            fontFamily: 'Cairo', color: Color(0xFFB0B0C8))),
    );
  }
}

// ── بطاقة الجنس ───────────────────────────────────────────────────────────────
class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 140, height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? activeColor.withAlpha(30)
              : const Color(0xFF1A1A2E),
          border: Border.all(
            color: selected ? activeColor : const Color(0xFF2D2D4A),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: activeColor.withAlpha(80),
                  blurRadius: 16, offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
              color: selected ? activeColor : const Color(0xFF5A5A7A),
              size: 38),
            const SizedBox(height: 6),
            Text(label,
              style: TextStyle(
                fontFamily: 'Cairo', fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                color: selected ? activeColor : const Color(0xFF7A7A9A),
              )),
          ],
        ),
      ),
    );
  }
}

// ── بقعة توهج خلفية ───────────────────────────────────────────────────────────
class _GlowBlob extends StatelessWidget {
  const _GlowBlob(this.size, this.color);
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(35),
        ),
      );
}

// ── منتقي مصدر الصورة ────────────────────────────────────────────────────────
class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A2E),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF3D3D5C),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded,
                color: Color(0xFF9C27B0)),
            title: const Text('اختر من المعرض',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded,
                color: Color(0xFF9C27B0)),
            title: const Text('التقط صورة',
                style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ── منتقي الدولة ──────────────────────────────────────────────────────────────
class _CountryPicker extends StatefulWidget {
  const _CountryPicker({required this.selected, required this.onSelect});
  final String? selected;
  final void Function(String) onSelect;

  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  final _ctrl = TextEditingController();
  List<(String, String)> _filtered = _kCountries;

  void _search(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? _kCountries
          : _kCountries
              .where((c) => c.$2.contains(q) || c.$1.contains(q))
              .toList();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFF3D3D5C),
                borderRadius: BorderRadius.circular(2))),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text('اختر دولتك',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                fontFamily: 'Cairo', color: Colors.white)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: TextField(
            controller: _ctrl,
            onChanged: _search,
            textAlign: TextAlign.right,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14,
                color: Colors.white),
            decoration: InputDecoration(
              hintText: 'ابحث عن دولة...',
              hintStyle: const TextStyle(
                  fontFamily: 'Cairo', color: Color(0xFF5A5A7A)),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: Color(0xFF5A5A7A)),
              filled: true,
              fillColor: const Color(0xFF0A0A15),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFF2D2D4A)),
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final (flag, name) = _filtered[i];
              final value        = '$flag $name';
              final isSel        = widget.selected == value;
              return InkWell(
                onTap: () => widget.onSelect(value),
                child: Container(
                  color: isSel
                      ? const Color(0xFF9C27B0).withAlpha(30)
                      : null,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(children: [
                    if (isSel) ...[
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF9C27B0), size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(flag,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name, textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 15, fontFamily: 'Cairo',
                          fontWeight: isSel
                              ? FontWeight.w700 : FontWeight.normal,
                          color: isSel
                              ? const Color(0xFF9C27B0) : Colors.white,
                        )),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}
