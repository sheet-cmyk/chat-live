import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../app/routes.dart';
import '../providers/auth_provider.dart';
import '../../../../features/wallet/data/repositories/wallet_repository.dart';

// ── ألوان Google الأصلية ───────────────────────────────────────────────────────
const _kBlue   = Color(0xFF1a73e8);
const _kRed    = Color(0xFFEA4335);
const _kGreen  = Color(0xFF34A853);
const _kYellow = Color(0xFFFBBC04);
const _kGrey   = Color(0xFF5F6368);
const _kBg     = Color(0xFFF8F9FA);

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
  Color(0xFF1a73e8), Color(0xFFEA4335), Color(0xFF34A853), Color(0xFFFBBC04),
  Color(0xFF9C27B0), Color(0xFFFF6B6B), Color(0xFF00BCD4), Color(0xFFFF9800),
  Color(0xFF607D8B), Color(0xFF1A1A1A),
];

class SetupProfileScreen extends ConsumerStatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  ConsumerState<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends ConsumerState<SetupProfileScreen> {
  final _nickCtrl    = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _nickFocus   = FocusNode();

  String? _gender;
  String? _country;
  File?   _avatarFile;
  bool    _saving    = false;
  Color   _nameColor = const Color(0xFF1a73e8);

  @override
  void initState() {
    super.initState();
    _nickFocus.addListener(() {
      if (_nickFocus.hasFocus) {
        // تأخير قصير ثم scroll للأسفل حتى يظهر حقل الإدخال فوق الكيبورد
        Future.delayed(const Duration(milliseconds: 350), () {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl.animateTo(
              _scrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _nickCtrl.dispose();
    _scrollCtrl.dispose();
    _nickFocus.dispose();
    super.dispose();
  }

  // ── رجوع: يُسجّل الخروج ثم يعود لشاشة الدخول ──────────────────────────────
  Future<void> _goBack() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) context.go(AppRoutes.login);
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

  // ── رفع الصورة ─────────────────────────────────────────────────────────────
  Future<String> _uploadAvatar(String uid) async {
    final bytes = await _avatarFile!.readAsBytes();
    final ref   = FirebaseStorage.instance.ref('users/$uid/avatar.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }

  // ── حفظ الملف الشخصي ───────────────────────────────────────────────────────
  Future<void> _save() async {
    final nick = _nickCtrl.text.trim();

    if (_avatarFile == null) { _toast('يرجى إضافة صورة شخصية'); return; }
    if (nick.isEmpty)        { _toast('الرجاء كتابة لقبك'); return; }
    if (nick.length < 2)     { _toast('اللقب قصير جداً'); return; }
    if (_gender == null)     { _toast('يرجى اختيار الجنس'); return; }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        _toast('انتهت الجلسة، سجّل الدخول مجدداً');
        setState(() => _saving = false);
        return;
      }

      // 1) رفع الصورة
      String avatarUrl;
      try {
        avatarUrl = await _uploadAvatar(firebaseUser.uid);
      } catch (e) {
        if (!mounted) return;
        setState(() => _saving = false);
        await _showUploadErrorDialog(e.toString());
        return;
      }

      // 2) لون الاسم
      final argb     = _nameColor.toARGB32();
      final colorHex = '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

      // 3) كتابة حقول البروفايل فقط (بدون مسّ الرصيد)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .set({
            'displayName': nick,
            'avatar':      avatarUrl,
            'gender':      _gender,
            'country':     _country ?? '',
            'phoneNumber': firebaseUser.phoneNumber ?? '',
            'nameColor':   colorHex,
            'createdAt':   FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // 4) تحديث Firebase Auth profile
      await firebaseUser.updateDisplayName(nick);
      await firebaseUser.updatePhotoURL(avatarUrl);

      // 5) إبطال cache
      ref.invalidate(currentUserProvider);

      // 6) هدية الترحيب
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.error_outline_rounded, color: _kRed),
          SizedBox(width: 8),
          Text('فشل رفع الصورة',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('تعذّر رفع الصورة. تأكد من:\n• اتصالك بالإنترنت\n• إعدادات Firebase Storage',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.6)),
              const SizedBox(height: 8),
              Text(error.length > 100 ? error.substring(0, 100) : error,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _kRed)),
            ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo', color: _kBlue, fontWeight: FontWeight.w700)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Google-colors dots
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _GDot(_kBlue), _GDot(_kRed), _GDot(_kYellow), _GDot(_kGreen),
            ]),
            const SizedBox(height: 20),
            const Text('مرحباً بك!', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                  fontFamily: 'Cairo', color: Color(0xFF1A1A1A))),
            const SizedBox(height: 10),
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontFamily: 'Cairo', fontSize: 15, color: _kGrey, height: 1.6),
                children: [
                  TextSpan(text: 'حصلت على '),
                  TextSpan(text: '500,000 عملة',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _kBlue, fontSize: 16)),
                  TextSpan(text: '\nكهدية ترحيب! 🎉'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('ابدأ الاستمتاع!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
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
      backgroundColor: _kRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final nick = _nickCtrl.text;
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // ── رأس Google-style ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(children: [
                // شريط علوي: زر رجوع + نقاط Google + فراغ موازن
                Row(
                  children: [
                    GestureDetector(
                      onTap: _goBack,
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: _kBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFDADCE0)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_rounded,
                            size: 16, color: _kBlue),
                      ),
                    ),
                    const Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _GDot(_kBlue), _GDot(_kRed),
                          _GDot(_kYellow), _GDot(_kGreen),
                        ],
                      ),
                    ),
                    const SizedBox(width: 38), // موازن للزر
                  ],
                ),
                const SizedBox(height: 14),
                const Text('إعداد ملفك الشخصي',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo', color: Color(0xFF1A1A1A))),
                const SizedBox(height: 4),
                const Text('أضف صورتك ولقبك للمتابعة',
                  style: TextStyle(fontSize: 13, fontFamily: 'Cairo', color: _kGrey)),
              ]),
            ),

            // ── المحتوى القابل للتمرير ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── الصورة الشخصية ──────────────────────────────────────
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(clipBehavior: Clip.none, children: [
                          Container(
                            width: 110, height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _kBg,
                              border: Border.all(
                                color: _avatarFile != null ? _kBlue : const Color(0xFFDADCE0),
                                width: _avatarFile != null ? 3 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(15),
                                  blurRadius: 12, offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _avatarFile != null
                                  ? Image.file(_avatarFile!, fit: BoxFit.cover,
                                      width: 110, height: 110)
                                  : const Icon(Icons.person_rounded,
                                      size: 52, color: Color(0xFFBDC1C6)),
                            ),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _kBlue,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [BoxShadow(
                                  color: _kBlue.withAlpha(80), blurRadius: 8)],
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  color: Colors.white, size: 17),
                            ),
                          ),
                        ]),
                      ),
                    ),

                    // إشارة الإجبارية
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        _avatarFile != null ? 'الصورة محددة ✓' : '* يرجى إضافة صورة شخصية',
                        style: TextStyle(
                          fontSize: 12, fontFamily: 'Cairo',
                          color: _avatarFile != null ? _kGreen : _kRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── اللقب ─────────────────────────────────────────────────
                    const _Label('اللقب *'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nickCtrl,
                      focusNode: _nickFocus,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      maxLength: 30,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                        fontSize: 15, fontFamily: 'Cairo',
                        color: Color(0xFF1A1A1A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'أدخل لقبك...',
                        hintStyle: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF9AA0A6)),
                        counterStyle: const TextStyle(color: _kGrey, fontSize: 11),
                        filled: true,
                        fillColor: _kBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFDADCE0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFDADCE0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _kBlue, width: 2),
                        ),
                      ),
                    ),

                    // معاينة الاسم — ارتفاع ثابت لمنع الـ layout jump
                    SizedBox(
                      height: 28,
                      child: Center(
                        child: nick.isNotEmpty
                            ? Text(
                                nick,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _nameColor,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── الجنس ────────────────────────────────────────────────
                    const _Label('الجنس *'),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _GenderTile(
                          icon: Icons.male_rounded,
                          label: 'ذكر',
                          selected: _gender == 'male',
                          color: _kBlue,
                          onTap: () => setState(() => _gender = 'male'),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _GenderTile(
                          icon: Icons.female_rounded,
                          label: 'أنثى',
                          selected: _gender == 'female',
                          color: _kRed,
                          onTap: () => setState(() => _gender = 'female'),
                        )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text('* لا يمكن تغيير الجنس بعد التسجيل',
                        style: TextStyle(fontSize: 11, color: _kGrey, fontFamily: 'Cairo')),
                    ),

                    const SizedBox(height: 20),

                    // ── الدولة ───────────────────────────────────────────────
                    const _Label('الدولة (اختياري)'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickCountry,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: _kBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _country != null ? _kBlue : const Color(0xFFDADCE0),
                            width: _country != null ? 2 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Text(_country?.split(' ').first ?? '🌍',
                              style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _country != null
                                  ? _country!.split(' ').sublist(1).join(' ')
                                  : 'اختر دولتك',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontFamily: 'Cairo', fontSize: 15,
                                color: _country != null ? const Color(0xFF1A1A1A) : const Color(0xFF9AA0A6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.keyboard_arrow_down_rounded, color: _kGrey),
                        ]),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── لون الاسم ────────────────────────────────────────────
                    const _Label('لون الاسم'),
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
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel ? Colors.white : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSel ? c.withAlpha(160) : Colors.black.withAlpha(20),
                                    blurRadius: isSel ? 10 : 4,
                                  ),
                                ],
                              ),
                              child: isSel
                                  ? Icon(Icons.check_rounded,
                                      color: c.computeLuminance() > 0.5
                                          ? Colors.black87 : Colors.white,
                                      size: 18)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── زر الحفظ ثابت في الأسفل ──────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                20, 12, 20,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE8EAED), width: 1)),
              ),
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kBlue.withAlpha(120),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  shadowColor: _kBlue.withAlpha(80),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('حفظ وابدأ',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                            fontFamily: 'Cairo')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── نقطة لون Google ────────────────────────────────────────────────────────────
class _GDot extends StatelessWidget {
  const _GDot(this.color);
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10, height: 10,
    margin: const EdgeInsets.symmetric(horizontal: 3),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

// ── تسمية حقل ─────────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          fontFamily: 'Cairo', color: Color(0xFF3C4043))),
  );
}

// ── بطاقة الجنس ───────────────────────────────────────────────────────────────
class _GenderTile extends StatelessWidget {
  const _GenderTile({
    required this.icon, required this.label,
    required this.selected, required this.color, required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 80,
      decoration: BoxDecoration(
        color: selected ? color.withAlpha(20) : _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? color : const Color(0xFFDADCE0),
          width: selected ? 2 : 1,
        ),
        boxShadow: selected
            ? [BoxShadow(color: color.withAlpha(50), blurRadius: 10, offset: const Offset(0, 3))]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: selected ? color : const Color(0xFFBDC1C6), size: 32),
          const SizedBox(height: 4),
          Text(label,
            style: TextStyle(
              fontFamily: 'Cairo', fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              color: selected ? color : _kGrey,
            )),
        ],
      ),
    ),
  );
}

// ── منتقي مصدر الصورة ────────────────────────────────────────────────────────
class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    clipBehavior: Clip.antiAlias,
    child: SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFDADCE0),
                borderRadius: BorderRadius.circular(2))),
        ListTile(
          leading: const Icon(Icons.photo_library_rounded, color: _kBlue),
          title: const Text('اختر من المعرض',
              style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF1A1A1A))),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        ListTile(
          leading: const Icon(Icons.camera_alt_rounded, color: _kBlue),
          title: const Text('التقط صورة',
              style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF1A1A1A))),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
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
          : _kCountries.where((c) => c.$2.contains(q) || c.$1.contains(q)).toList();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.72,
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(children: [
      Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40, height: 4,
          decoration: BoxDecoration(color: const Color(0xFFDADCE0),
              borderRadius: BorderRadius.circular(2))),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text('اختر دولتك',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
              fontFamily: 'Cairo', color: Color(0xFF1A1A1A))),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: TextField(
          controller: _ctrl,
          onChanged: _search,
          textAlign: TextAlign.right,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
          decoration: InputDecoration(
            hintText: 'ابحث عن دولة...',
            hintStyle: const TextStyle(fontFamily: 'Cairo', color: Color(0xFF9AA0A6)),
            prefixIcon: const Icon(Icons.search_rounded, color: _kGrey),
            filled: true, fillColor: _kBg,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
      const Divider(height: 1, color: Color(0xFFE8EAED)),
      Expanded(
        child: ListView.builder(
          itemCount: _filtered.length,
          itemBuilder: (_, i) {
            final (flag, name) = _filtered[i];
            final value = '$flag $name';
            final isSel = widget.selected == value;
            return InkWell(
              onTap: () => widget.onSelect(value),
              child: Container(
                color: isSel ? _kBlue.withAlpha(15) : null,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(children: [
                  if (isSel) ...[
                    const Icon(Icons.check_circle_rounded, color: _kBlue, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(flag, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(name, textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 15, fontFamily: 'Cairo',
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.normal,
                        color: isSel ? _kBlue : const Color(0xFF1A1A1A),
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
