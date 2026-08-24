import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/routes.dart';
import '../providers/auth_provider.dart';

// ── رموز الدول ────────────────────────────────────────────────────────────────
const _kDialCodes = [
  ('🇸🇦', 'السعودية',   '+966'),
  ('🇮🇶', 'العراق',     '+964'),
  ('🇦🇪', 'الإمارات',   '+971'),
  ('🇰🇼', 'الكويت',     '+965'),
  ('🇶🇦', 'قطر',        '+974'),
  ('🇧🇭', 'البحرين',    '+973'),
  ('🇴🇲', 'عُمان',      '+968'),
  ('🇾🇪', 'اليمن',      '+967'),
  ('🇯🇴', 'الأردن',     '+962'),
  ('🇸🇾', 'سوريا',      '+963'),
  ('🇱🇧', 'لبنان',      '+961'),
  ('🇵🇸', 'فلسطين',     '+970'),
  ('🇪🇬', 'مصر',        '+20'),
  ('🇱🇾', 'ليبيا',      '+218'),
  ('🇹🇳', 'تونس',       '+216'),
  ('🇩🇿', 'الجزائر',    '+213'),
  ('🇲🇦', 'المغرب',     '+212'),
  ('🇸🇩', 'السودان',    '+249'),
  ('🇹🇷', 'تركيا',      '+90'),
  ('🇵🇰', 'باكستان',    '+92'),
  ('🇮🇳', 'الهند',      '+91'),
  ('🇬🇧', 'بريطانيا',   '+44'),
  ('🇺🇸', 'أمريكا',     '+1'),
  ('🇩🇪', 'ألمانيا',    '+49'),
  ('🇫🇷', 'فرنسا',      '+33'),
  ('🇸🇪', 'السويد',     '+46'),
  ('🇨🇦', 'كندا',       '+1'),
  ('🇦🇺', 'أستراليا',   '+61'),
];

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  final _phoneFocus = FocusNode();
  final _otpFocus   = FocusNode();

  (String, String, String) _dial = _kDialCodes[1]; // العراق افتراضياً
  String? _verificationId;
  bool _codeSent    = false;
  bool _sendLoading = false;
  bool _verLoading  = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _phoneFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  String get _fullPhone {
    var num = _phoneCtrl.text.trim();
    // strip leading zero (0712... → 712...) for correct international format
    if (num.startsWith('0')) num = num.substring(1);
    return '${_dial.$3}$num';
  }

  // ── إرسال OTP ──────────────────────────────────────────────────────────────
  Future<void> _sendCode() async {
    if (_phoneCtrl.text.trim().length < 6) {
      _toast('أدخل رقم الهاتف أولاً');
      return;
    }
    setState(() => _sendLoading = true);

    await ref.read(authRepositoryProvider).sendOtp(
      phoneNumber: _fullPhone,
      onCodeSent: (verId, _) {
        if (!mounted) return;
        setState(() {
          _verificationId = verId;
          _codeSent       = true;
          _sendLoading    = false;
        });
        _otpFocus.requestFocus();
        _toast('تم إرسال الرمز بنجاح ✓');
      },
      onError: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _sendLoading = false);
        final raw = e.message ?? '';
        final String msg;
        if (e.code == 'invalid-phone-number') {
          msg = 'رقم الهاتف غير صحيح، تحقق من رمز الدولة والرقم';
        } else if (e.code == 'too-many-requests') {
          msg = 'طلبات كثيرة جداً، انتظر قليلاً وحاول مجدداً';
        } else if (raw.contains('region') || raw.contains('SMS unable')) {
          _showRegionDialog();
          return;
        } else if (raw.contains('operation-not-allowed') || e.code == 'operation-not-allowed') {
          msg = 'تسجيل الهاتف غير مُفعَّل في Firebase — فعّله من Console';
        } else if (raw.contains('network') || e.code == 'network-request-failed') {
          msg = 'تحقق من اتصالك بالإنترنت';
        } else {
          msg = 'خطأ: ${e.code}';
        }
        _toast(msg, isError: true);
      },
      onAutoVerified: (PhoneAuthCredential cred) async {
        // Android تحقق تلقائي
        if (!mounted) return;
        setState(() => _verLoading = true);
        try {
          final result = await ref.read(authRepositoryProvider).verifyOtpAndLogin(
            verificationId: cred.verificationId!,
            smsCode: cred.smsCode!,
          );
          if (!mounted) return;
          result != null
              ? context.go(AppRoutes.home)
              : context.go(AppRoutes.setupProfile);
        } catch (_) {
          if (mounted) setState(() => _verLoading = false);
        }
      },
    );
  }

  // ── التحقق من OTP ──────────────────────────────────────────────────────────
  Future<void> _verify() async {
    if (!_codeSent) {
      _toast('اضغط "الحصول على" أولاً لإرسال الرمز', isError: true);
      return;
    }
    if (_otpCtrl.text.trim().length != 6) {
      _toast('الرمز يجب أن يكون 6 أرقام', isError: true);
      return;
    }
    setState(() => _verLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).verifyOtpAndLogin(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
      );
      if (!mounted) return;
      user != null
          ? context.go(AppRoutes.home)
          : context.go(AppRoutes.setupProfile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _verLoading = false);
      _toast(
        e.toString().contains('invalid-verification-code')
            ? 'الرمز غير صحيح، حاول مجدداً'
            : 'فشل التحقق، أعد المحاولة',
        isError: true,
      );
    }
  }

  void _showRegionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('⚙️', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('إعداد مطلوب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'يجب تفعيل SMS للمناطق في Firebase Console:',
              textAlign: TextAlign.right,
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 14),
            ),
            SizedBox(height: 12),
            _Step(n: '1', text: 'افتح Firebase Console'),
            _Step(n: '2', text: 'Authentication → Settings'),
            _Step(n: '3', text: 'SMS region policy'),
            _Step(n: '4', text: 'اختر "Allow" ثم أضف دولتك أو اختر "All regions"'),
            _Step(n: '5', text: 'احفظ التغييرات'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF7B1FA2), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: isError ? const Color(0xFFE53935) : const Color(0xFF7B1FA2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _pickDial() async {
    final result = await showModalBottomSheet<(String, String, String)>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DialSheet(selected: _dial, onSelect: (v) => Navigator.pop(context, v)),
    );
    if (result != null && mounted) setState(() => _dial = result);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool busy = _sendLoading || _verLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── خلفية متدرجة بنفسجية ──────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: size.height * 0.30,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFCFB8F0), Color(0xFFEDE4FA), Colors.white],
                  stops: [0.0, 0.65, 1.0],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── شريط العنوان ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // زر الرجوع
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_rounded,
                            size: 22, color: Color(0xFF5C35A0)),
                      ),
                      const Text(
                        'تسجيل',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo',
                          color: Color(0xFF2D2D2D),
                        ),
                      ),
                      // زر تخطّي
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.home),
                        child: const Icon(Icons.chevron_right_rounded,
                            size: 26, color: Color(0xFF5C35A0)),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const SizedBox(height: 16),

                        // ── الترحيب ────────────────────────────────────────
                        const Text(
                          'مرحبًا، أهلاً بك في LivChat',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Cairo',
                            color: Color(0xFF2D2D2D),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── رقم الهاتف ───────────────────────────────────
                        const Text('رقم الهاتف',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                fontFamily: 'Cairo', color: Color(0xFF5C35A0))),
                        const SizedBox(height: 8),

                        // حقل الرقم مع رمز الدولة
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F0FA),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              // زر مسح
                              if (_phoneCtrl.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () => setState(() => _phoneCtrl.clear()),
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 10),
                                    width: 28, height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey.withAlpha(60),
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                                  ),
                                )
                              else
                                const SizedBox(width: 14),

                              // حقل الرقم
                              Expanded(
                                child: TextField(
                                  controller: _phoneCtrl,
                                  focusNode: _phoneFocus,
                                  keyboardType: TextInputType.phone,
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.right,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  onChanged: (_) => setState(() {}),
                                  style: const TextStyle(
                                    fontSize: 16, letterSpacing: 1,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintText: '07XXXXXXXXX',
                                    hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),

                              // فاصل
                              Container(
                                height: 22,
                                width: 1,
                                color: const Color(0xFFD0D0D0),
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                              ),

                              // منتقي رمز الدولة
                              GestureDetector(
                                onTap: _pickDial,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Row(
                                    children: [
                                      Text(_dial.$3,
                                          style: const TextStyle(
                                              fontSize: 14, fontWeight: FontWeight.w700,
                                              color: Color(0xFF5C35A0))),
                                      const SizedBox(width: 4),
                                      Text(_dial.$1, style: const TextStyle(fontSize: 18)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── رمز التحقق ─────────────────────────────────────
                        const Text('رمز التحقق',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                fontFamily: 'Cairo', color: Color(0xFF5C35A0))),
                        const SizedBox(height: 8),

                        // حقل OTP مع زر "الحصول على"
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F0FA),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            children: [
                              // زر "الحصول على"
                              GestureDetector(
                                onTap: busy ? null : _sendCode,
                                child: Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _codeSent
                                          ? [const Color(0xFF9E9E9E), const Color(0xFF757575)]
                                          : [const Color(0xFF9C4DCC), const Color(0xFF7B1FA2)],
                                    ),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: _sendLoading
                                      ? const SizedBox(
                                          width: 16, height: 16,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Text(
                                          _codeSent ? 'إعادة إرسال' : 'الحصول على',
                                          style: const TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.w700,
                                            color: Colors.white, fontFamily: 'Cairo',
                                          ),
                                        ),
                                ),
                              ),

                              // حقل الرمز
                              Expanded(
                                child: TextField(
                                  controller: _otpCtrl,
                                  focusNode: _otpFocus,
                                  keyboardType: TextInputType.number,
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.right,
                                  maxLength: 6,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  style: const TextStyle(
                                    fontSize: 18, letterSpacing: 4,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2D2D2D),
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    counterText: '',
                                    hintText: 'يرجى إدخال رمز التحقق',
                                    hintStyle: TextStyle(
                                      color: Color(0xFFBDBDBD),
                                      fontSize: 13,
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.normal,
                                      letterSpacing: 0,
                                    ),
                                    contentPadding: EdgeInsets.only(right: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ── زر التالي ──────────────────────────────────────
                        GestureDetector(
                          onTap: busy ? null : _verify,
                          child: AnimatedOpacity(
                            opacity: busy ? 0.7 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFAB7AE0), Color(0xFF7B1FA2)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF9C4DCC).withAlpha(70),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _verLoading
                                    ? const SizedBox(
                                        width: 24, height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : const Text(
                                        'التالي',
                                        style: TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.w700,
                                          color: Colors.white, fontFamily: 'Cairo',
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── نص الإرسال عبر SMS ─────────────────────────────
                        Center(
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Color(0xFF9AA0A6)),
                              children: [
                                TextSpan(text: 'إرسال رمز التحقق عبر '),
                                TextSpan(
                                  text: 'SMS',
                                  style: TextStyle(
                                    color: Color(0xFF7B1FA2),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── خطوة صغيرة في الـ dialog ────────────────────────────────────────────────
class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final String n, text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(text, textAlign: TextAlign.right,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Color(0xFF424242))),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFF7B1FA2),
            child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── شاشة اختيار رمز الدولة ───────────────────────────────────────────────────
class _DialSheet extends StatefulWidget {
  const _DialSheet({required this.selected, required this.onSelect});
  final (String, String, String) selected;
  final void Function((String, String, String)) onSelect;

  @override
  State<_DialSheet> createState() => _DialSheetState();
}

class _DialSheetState extends State<_DialSheet> {
  final _ctrl = TextEditingController();
  List<(String, String, String)> _list = _kDialCodes;

  void _search(String q) {
    setState(() {
      _list = q.isEmpty
          ? _kDialCodes
          : _kDialCodes.where((c) => c.$2.contains(q) || c.$3.contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.68,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFDEDEDE), borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('اختر رمز الدولة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
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
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: _list.length,
              itemBuilder: (_, i) {
                final e = _list[i];
                final sel = widget.selected.$2 == e.$2;
                return InkWell(
                  onTap: () => widget.onSelect(e),
                  child: Container(
                    color: sel ? const Color(0xFF9C4DCC).withAlpha(14) : null,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    child: Row(
                      children: [
                        Text(e.$1, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(e.$2, textAlign: TextAlign.right,
                              style: TextStyle(fontSize: 15, fontFamily: 'Cairo',
                                  fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                                  color: sel ? const Color(0xFF9C4DCC) : const Color(0xFF2D2D2D))),
                        ),
                        const SizedBox(width: 8),
                        Text(e.$3, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                            color: Color(0xFF9C4DCC))),
                        if (sel) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_rounded, color: Color(0xFF9C4DCC), size: 18),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
