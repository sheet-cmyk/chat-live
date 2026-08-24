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

// ── الدول ──────────────────────────────────────────────────────────────────────
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
  Color(0xFF9C27B0), Color(0xFF4CAF50), Color(0xFF2196F3),
  Color(0xFF9E9E9E), Color(0xFFFFEB3B), Color(0xFFF44336),
  Color(0xFFFFFFFF), Color(0xFF00BCD4), Color(0xFFFF9800),
  Color(0xFF212121),
];

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  String?  _gender;
  String?  _country;
  File?    _avatarFile;
  bool     _saving     = false;
  Color    _nameColor  = Colors.white;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── اختيار الصورة ──────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFDEDEDE),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 4),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF9C27B0)),
            title: const Text('اختر من المعرض', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF9C27B0)),
            title: const Text('التقط صورة', style: TextStyle(fontFamily: 'Cairo')),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (src == null) return;
    final picked = await ImagePicker().pickImage(source: src, imageQuality: 80);
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
  Future<String?> _uploadAvatar(String uid) async {
    if (_avatarFile == null) return null;
    final ref = FirebaseStorage.instance.ref('avatars/$uid.jpg');
    await ref.putFile(_avatarFile!);
    return ref.getDownloadURL();
  }

  // ── حفظ البيانات ───────────────────────────────────────────────────────────
  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty)    { _toast('الرجاء كتابة لقبك'); return; }
    if (name.length < 2) { _toast('اللقب قصير جداً'); return; }
    if (_gender == null) { _toast('يرجى اختيار الجنس'); return; }

    setState(() => _saving = true);
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser!;
      final avatarUrl    = await _uploadAvatar(firebaseUser.uid);

      final user = UserModel(
        uid:         firebaseUser.uid,
        displayName: name,
        avatar:      avatarUrl ?? firebaseUser.photoURL,
        gender:      _gender,
        country:     _country,
        phoneNumber: firebaseUser.phoneNumber ?? '',
        createdAt:   DateTime.now(),
      );

      await ref.read(authRepositoryProvider).saveNewUser(user);

      // حفظ لون الاسم
      final argb = _nameColor.toARGB32();
      final hex  = '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .set({'nameColor': hex}, SetOptions(merge: true));

      await WalletRepository().ensureWelcomeBonus(firebaseUser.uid);

      if (!mounted) return;
      await _showWelcomeDialog();
      if (!mounted) return;
      context.go(AppRoutes.home);
    } catch (_) {
      if (mounted) _toast('حدث خطأ، حاول مجدداً');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
            const Text('🎁', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text('مرحباً بك في LivChat!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  fontFamily: 'Cairo', color: Color(0xFF2D2D2D))),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(fontFamily: 'Cairo', fontSize: 15,
                    color: Color(0xFF5F6368), height: 1.6),
                children: [
                  TextSpan(text: 'حصلت على '),
                  TextSpan(text: '500,000 عملة',
                    style: TextStyle(fontWeight: FontWeight.w800,
                        color: Color(0xFF9C27B0), fontSize: 17)),
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      // خلفية شفافة داكنة خلف الـ sheet
      backgroundColor: Colors.black54,
      body: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: size.height * 0.93,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // ── مقبض ────────────────────────────────────────────────────
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDEDEDE),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── العنوان + زر تخطّي ─────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      'أكمل ملفك الشخصي',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        fontFamily: 'Cairo', color: Color(0xFF1A1A1A),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => context.go(AppRoutes.home),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text('تخطّي',
                            style: TextStyle(fontSize: 13, fontFamily: 'Cairo',
                                color: Color(0xFF9E9E9E))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── المحتوى القابل للتمرير ──────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // ── صورة دائرية ─────────────────────────────────────
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Stack(clipBehavior: Clip.none, children: [
                            CircleAvatar(
                              radius: 52,
                              backgroundColor: const Color(0xFFEEEEEE),
                              backgroundImage: _avatarFile != null
                                  ? FileImage(_avatarFile!) : null,
                              child: _avatarFile == null
                                  ? const Icon(Icons.person_rounded,
                                      size: 50, color: Color(0xFFBDBDBD))
                                  : null,
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF9C27B0),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [BoxShadow(
                                    color: const Color(0xFF9C27B0).withAlpha(80),
                                    blurRadius: 8, offset: const Offset(0, 3))],
                                ),
                                child: const Icon(Icons.camera_alt_rounded,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── حقل الاسم الظاهر ─────────────────────────────────
                      TextField(
                        controller: _nameCtrl,
                        textAlign: TextAlign.right,
                        maxLength: 30,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 15, fontFamily: 'Cairo', color: Color(0xFF1A1A1A)),
                        decoration: InputDecoration(
                          labelText: 'الاسم الظاهر',
                          labelStyle: const TextStyle(
                            fontFamily: 'Cairo', color: Color(0xFF9E9E9E)),
                          prefixIcon: const Icon(Icons.person_rounded,
                              color: Color(0xFF9C27B0)),
                          counterStyle: const TextStyle(
                            color: Color(0xFFBDBDBD), fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFFF8F8F8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFF9C27B0), width: 1.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── الدولة (اختياري) ──────────────────────────────────
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text('الدولة',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo', color: Color(0xFF5F6368))),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _pickCountry,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8F8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _country != null
                                  ? const Color(0xFF9C27B0)
                                  : const Color(0xFFE0E0E0),
                              width: _country != null ? 1.5 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Icon(Icons.keyboard_arrow_down_rounded,
                              color: _country != null
                                  ? const Color(0xFF9C27B0)
                                  : const Color(0xFFBDBDBD)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _country != null
                                    ? _country!.split(' ').sublist(1).join(' ')
                                    : 'اختر دولتك',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontFamily: 'Cairo', fontSize: 15,
                                  color: _country != null
                                      ? const Color(0xFF1A1A1A)
                                      : const Color(0xFFBDBDBD),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_country?.split(' ').first ?? '🌍',
                              style: const TextStyle(fontSize: 22)),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── الجنس (إجباري) ────────────────────────────────────
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text('الجنس',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo', color: Color(0xFF5F6368))),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _GenderBtn(
                            icon: Icons.male_rounded,
                            label: 'ذكر',
                            selected: _gender == 'male',
                            activeColor: const Color(0xFF5C6BC0),
                            onTap: () => setState(() => _gender = 'male'),
                          ),
                          _GenderBtn(
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
                          style: TextStyle(fontSize: 11, color: Color(0xFFEF5350),
                              fontFamily: 'Cairo')),
                      ),

                      const SizedBox(height: 16),

                      // ── لون الاسم (اختياري) ───────────────────────────────
                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text('لون الاسم',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              fontFamily: 'Cairo', color: Color(0xFF5F6368))),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _kNameColors.map((c) {
                            final isSel = _nameColor == c;
                            return GestureDetector(
                              onTap: () => setState(() => _nameColor = c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.only(left: 8),
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: c,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel
                                        ? const Color(0xFF9C27B0)
                                        : const Color(0xFFE0E0E0),
                                    width: isSel ? 2.5 : 1.5,
                                  ),
                                  boxShadow: isSel
                                      ? [BoxShadow(color: c.withAlpha(120),
                                          blurRadius: 8)]
                                      : null,
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

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // ── زر التالي (ثابت في الأسفل) ─────────────────────────────
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
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                          color: const Color(0xFF9C27B0).withAlpha(80),
                          blurRadius: 12, offset: const Offset(0, 4),
                        )],
                      ),
                      child: Center(
                        child: _saving
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : const Text('التالي ✓',
                                style: TextStyle(fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white, fontFamily: 'Cairo')),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── زر الجنس ──────────────────────────────────────────────────────────────────
class _GenderBtn extends StatelessWidget {
  const _GenderBtn({
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
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? activeColor : const Color(0xFFF5F5F5),
              boxShadow: selected
                  ? [BoxShadow(color: activeColor.withAlpha(120),
                      blurRadius: 14, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Icon(icon,
              color: selected ? Colors.white : const Color(0xFFBDBDBD),
              size: 42),
          ),
          const SizedBox(height: 6),
          Text(label,
            style: TextStyle(
              fontFamily: 'Cairo', fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              color: selected ? activeColor : const Color(0xFF9E9E9E),
            )),
        ],
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
          : _kCountries.where((c) => c.$2.contains(q) || c.$1.contains(q)).toList();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFDEDEDE),
                borderRadius: BorderRadius.circular(2))),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text('اختر دولتك',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                fontFamily: 'Cairo', color: Color(0xFF1A1A1A))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: TextField(
            controller: _ctrl,
            onChanged: _search,
            textAlign: TextAlign.right,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
            decoration: InputDecoration(
              hintText: 'ابحث عن دولة...',
              hintStyle: const TextStyle(fontFamily: 'Cairo', color: Color(0xFFBDBDBD)),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9AA0A6)),
              filled: true, fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final (flag, name) = _filtered[i];
              final value      = '$flag $name';
              final isSel      = widget.selected == value;
              return InkWell(
                onTap: () => widget.onSelect(value),
                child: Container(
                  color: isSel ? const Color(0xFF9C27B0).withAlpha(14) : null,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(children: [
                    if (isSel) ...[
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF9C27B0), size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(flag, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name, textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 15, fontFamily: 'Cairo',
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.normal,
                          color: isSel ? const Color(0xFF9C27B0) : const Color(0xFF1A1A1A))),
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
