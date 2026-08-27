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

enum _AuthMode { register, login }
enum _AuthStep  { form, otp }

class PhoneAuthScreen extends ConsumerStatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  ConsumerState<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends ConsumerState<PhoneAuthScreen> {
  final _phoneCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _otpCtrl     = TextEditingController();

  (String, String, String) _dial = _kDialCodes[1]; // العراق افتراضياً
  _AuthMode _mode = _AuthMode.register;
  _AuthStep _step = _AuthStep.form;

  String? _verificationId;
  bool _passVisible    = false;
  bool _confirmVisible = false;
  bool _sendLoading    = false;
  bool _verLoading     = false;

  bool get _busy => _sendLoading || _verLoading;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  String get _fullPhone {
    var num = _phoneCtrl.text.trim();
    if (num.startsWith('0')) num = num.substring(1);
    return '${_dial.$3}$num';
  }

  // ── التحقق من الحقول ──────────────────────────────────────────────────────
  bool _validateForm() {
    if (_phoneCtrl.text.trim().length < 6) {
      _toast('أدخل رقم الهاتف أولاً', isError: true);
      return false;
    }
    if (_passCtrl.text.length < 6) {
      _toast('كلمة المرور يجب أن تكون 6 أحرف على الأقل', isError: true);
      return false;
    }
    if (_mode == _AuthMode.register && _passCtrl.text != _confirmCtrl.text) {
      _toast('كلمات المرور غير متطابقة', isError: true);
      return false;
    }
    return true;
  }

  // ── إرسال OTP (إنشاء حساب فقط) ───────────────────────────────────────────
  Future<void> _sendOtp() async {
    if (!_validateForm()) return;
    setState(() => _sendLoading = true);

    final repo = ref.read(authRepositoryProvider);
    await repo.sendOtp(
      phoneNumber: _fullPhone,
      onCodeSent: (verId, _) {
        if (!mounted) return;
        setState(() {
          _verificationId = verId;
          _sendLoading    = false;
          _step           = _AuthStep.otp;
        });
        _toast('تم إرسال رمز التحقق');
      },
      onError: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _sendLoading = false);
        final msg = _otpSendErrorMsg(e);
        if (msg.isNotEmpty) _toast(msg, isError: true);
      },
      onAutoVerified: (PhoneAuthCredential cred) async {
        // Android: تحقق تلقائي — نكمل إنشاء الحساب مباشرةً
        if (!mounted) return;
        setState(() {
          _sendLoading = false; // أوقف spinner الإرسال
          _verLoading  = true;
        });
        try {
          await FirebaseAuth.instance.signInWithCredential(cred);
          await repo.linkPasswordAfterOtp(
            fullPhone: _fullPhone,
            password: _passCtrl.text,
          );
          final user = await repo.fetchCurrentUser();
          if (!mounted) return;
          (user != null && user.displayName.isNotEmpty)
              ? context.go(AppRoutes.home)
              : context.go(AppRoutes.setupProfile);
        } catch (e) {
          if (mounted) {
            setState(() => _verLoading = false);
            _toast(_authErrorMsg(e), isError: true);
          }
        }
      },
    );
  }

  // ── التحقق من رمز OTP المُدخل ─────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().length != 6) {
      _toast('الرمز يجب أن يكون 6 أرقام', isError: true);
      return;
    }
    if (_verLoading) return;
    setState(() => _verLoading = true);

    final repo = ref.read(authRepositoryProvider);
    try {
      // 1. التحقق من OTP → يُنشئ أو يُسجّل دخول مستخدم الهاتف
      await repo.verifyOtpAndLogin(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
      );
      // 2. ربط البريد الوهمي وكلمة المرور بالحساب
      await repo.linkPasswordAfterOtp(
        fullPhone: _fullPhone,
        password: _passCtrl.text,
      );
      // 3. جلب بيانات المستخدم
      final user = await repo.fetchCurrentUser();
      if (!mounted) return;
      (user != null && user.displayName.isNotEmpty)
          ? context.go(AppRoutes.home)
          : context.go(AppRoutes.setupProfile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _verLoading = false);
      _toast(_authErrorMsg(e), isError: true);
    }
  }

  // ── تسجيل الدخول بكلمة المرور (بدون OTP) ────────────────────────────────
  Future<void> _login() async {
    if (!_validateForm()) return;
    setState(() => _verLoading = true);

    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signInWithPhonePassword(
        fullPhone: _fullPhone,
        password: _passCtrl.text,
      );
      if (!mounted) return;
      (user != null && user.displayName.isNotEmpty)
          ? context.go(AppRoutes.home)
          : context.go(AppRoutes.setupProfile);
    } catch (e) {
      if (!mounted) return;
      setState(() => _verLoading = false);
      _toast(_authErrorMsg(e), isError: true);
    }
  }

  // ── رسائل خطأ إرسال OTP ──────────────────────────────────────────────────
  String _otpSendErrorMsg(FirebaseAuthException e) {
    final raw = e.message ?? '';
    if (e.code == 'invalid-phone-number')    return 'رقم الهاتف غير صحيح';
    if (e.code == 'too-many-requests')        return 'طلبات كثيرة، انتظر قليلاً';
    if (e.code == 'operation-not-allowed')    return 'تسجيل الهاتف غير مُفعَّل في Firebase';
    if (e.code == 'network-request-failed')   return 'تحقق من اتصالك بالإنترنت';
    if (raw.contains('region') || raw.contains('SMS unable')) {
      _showRegionDialog();
      return '';
    }
    return 'خطأ: ${e.code}';
  }

  // ── رسائل خطأ عامة بالعربية ──────────────────────────────────────────────
  String _authErrorMsg(Object e) {
    final s = e.toString();
    if (s.contains('user-not-found'))               return 'رقم الهاتف غير مسجل، أنشئ حساباً أولاً';
    if (s.contains('wrong-password'))               return 'كلمة المرور غير صحيحة';
    if (s.contains('invalid-credential'))           return 'كلمة المرور غير صحيحة';
    if (s.contains('invalid-verification-code'))    return 'رمز التحقق غير صحيح، حاول مجدداً';
    if (s.contains('session-expired'))              return 'انتهت صلاحية الرمز، اضغط رجوع وأعد الإرسال';
    if (s.contains('email-already-in-use'))         return 'رقم الهاتف مسجل بالفعل، استخدم تسجيل الدخول';
    if (s.contains('too-many-requests'))            return 'محاولات كثيرة، انتظر قليلاً';
    if (s.contains('network-request-failed'))       return 'تحقق من اتصالك بالإنترنت';
    return 'حدث خطأ، حاول مجدداً';
  }

  // ── حوار إعداد Firebase SMS ──────────────────────────────────────────────
  void _showRegionDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('⚙️', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text('إعداد مطلوب',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 18)),
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
            _Step(n: '4', text: 'اختر "Allow" ثم أضف دولتك أو "All regions"'),
            _Step(n: '5', text: 'احفظ التغييرات'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً',
                style: TextStyle(fontFamily: 'Cairo', color: Color(0xFF7B1FA2),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _toast(String msg, {bool isError = false}) {
    if (msg.isEmpty) return;
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
      builder: (_) => _DialSheet(
          selected: _dial, onSelect: (v) => Navigator.pop(context, v)),
    );
    if (result != null && mounted) setState(() => _dial = result);
  }

  void _backFromOtp() {
    setState(() {
      _step = _AuthStep.form;
      _otpCtrl.clear();
    });
  }

  // ── بناء الواجهة ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: _step == _AuthStep.form,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step == _AuthStep.otp) _backFromOtp();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // ── خلفية بنفسجية متدرجة ─────────────────────────────────────
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
                  // ── شريط العنوان ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _step == _AuthStep.otp
                              ? _backFromOtp
                              : () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back_ios_rounded,
                              size: 22, color: Color(0xFF5C35A0)),
                        ),
                        const Text(
                          'LivChat',
                          style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            fontFamily: 'Cairo', color: Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(width: 26),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _step == _AuthStep.otp
                            ? _buildOtpStep()
                            : _buildFormStep(),
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

  // ── خطوة النموذج (إنشاء حساب / دخول) ────────────────────────────────────
  Widget _buildFormStep() {
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(height: 20),

        // ── مبدّل النمط ──────────────────────────────────────────────────
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F0FA),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              _ModeTab(
                label: 'إنشاء حساب',
                active: _mode == _AuthMode.register,
                onTap: () {
                  if (_mode == _AuthMode.register) return;
                  setState(() { _mode = _AuthMode.register; });
                },
              ),
              _ModeTab(
                label: 'تسجيل الدخول',
                active: _mode == _AuthMode.login,
                onTap: () {
                  if (_mode == _AuthMode.login) return;
                  setState(() {
                    _mode = _AuthMode.login;
                    _confirmCtrl.clear();
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── رقم الهاتف ───────────────────────────────────────────────────
        const Text('رقم الهاتف',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                fontFamily: 'Cairo', color: Color(0xFF5C35A0))),
        const SizedBox(height: 8),
        _buildPhoneField(),

        const SizedBox(height: 18),

        // ── كلمة المرور ──────────────────────────────────────────────────
        const Text('كلمة المرور',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                fontFamily: 'Cairo', color: Color(0xFF5C35A0))),
        const SizedBox(height: 8),
        _buildPasswordField(
          ctrl: _passCtrl,
          hint: 'أدخل كلمة المرور (6 أحرف على الأقل)',
          visible: _passVisible,
          onToggle: () => setState(() => _passVisible = !_passVisible),
        ),

        // ── تأكيد كلمة المرور (إنشاء حساب فقط) ──────────────────────────
        if (_mode == _AuthMode.register) ...[
          const SizedBox(height: 18),
          const Text('تأكيد كلمة المرور',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  fontFamily: 'Cairo', color: Color(0xFF5C35A0))),
          const SizedBox(height: 8),
          _buildPasswordField(
            ctrl: _confirmCtrl,
            hint: 'أعد كتابة كلمة المرور',
            visible: _confirmVisible,
            onToggle: () => setState(() => _confirmVisible = !_confirmVisible),
          ),
        ],

        const SizedBox(height: 32),

        // ── زر الإجراء ───────────────────────────────────────────────────
        _buildActionButton(
          label: _mode == _AuthMode.register ? 'إنشاء حساب' : 'دخول',
          loading: _busy,
          onTap: _mode == _AuthMode.register ? _sendOtp : _login,
        ),

        const SizedBox(height: 16),

        if (_mode == _AuthMode.register)
          Center(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13,
                    color: Color(0xFF9AA0A6)),
                children: [
                  TextSpan(text: 'سيتم إرسال رمز تحقق عبر '),
                  TextSpan(
                    text: 'SMS',
                    style: TextStyle(
                        color: Color(0xFF7B1FA2), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ── خطوة رمز التحقق OTP ──────────────────────────────────────────────────
  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 32),

        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFAB7AE0), Color(0xFF7B1FA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF9C4DCC).withAlpha(60),
                blurRadius: 16, offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.sms_rounded, color: Colors.white, size: 34),
        ),

        const SizedBox(height: 20),

        const Text(
          'رمز التحقق',
          style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800,
            fontFamily: 'Cairo', color: Color(0xFF2D2D2D),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'أُرسل إلى $_fullPhone',
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            fontSize: 14, fontFamily: 'Cairo', color: Color(0xFF9AA0A6),
          ),
        ),

        const SizedBox(height: 32),

        // ── حقل OTP ────────────────────────────────────────────────────
        Container(
          height: 62,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F0FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF9C4DCC).withAlpha(60), width: 1.2),
          ),
          child: TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              setState(() {});
              if (v.length == 6) _verifyOtp();
            },
            style: const TextStyle(
              fontSize: 24, letterSpacing: 10,
              fontWeight: FontWeight.w800, color: Color(0xFF2D2D2D),
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              counterText: '',
              hintText: '— — — — — —',
              hintStyle: TextStyle(
                color: Color(0xFFBDBDBD), fontSize: 18,
                letterSpacing: 8, fontWeight: FontWeight.normal,
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),

        const SizedBox(height: 28),

        _buildActionButton(
          label: 'تأكيد',
          loading: _verLoading,
          onTap: _verifyOtp,
        ),

        const SizedBox(height: 16),

        TextButton(
          onPressed: _busy ? null : _backFromOtp,
          child: const Text(
            'لم يصلك الرمز؟ اضغط هنا للرجوع',
            style: TextStyle(
              fontSize: 13, fontFamily: 'Cairo',
              color: Color(0xFF7B1FA2), fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ── حقل رقم الهاتف ───────────────────────────────────────────────────────
  Widget _buildPhoneField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FA),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          if (_phoneCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _phoneCtrl.clear()),
              child: Container(
                margin: const EdgeInsets.only(left: 10),
                width: 28, height: 28,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.withAlpha(60)),
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
              ),
            )
          else
            const SizedBox(width: 14),

          Expanded(
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                  fontSize: 16, letterSpacing: 1, color: Color(0xFF2D2D2D)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '07XXXXXXXXX',
                hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          Container(
            height: 22, width: 1,
            color: const Color(0xFFD0D0D0),
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

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
    );
  }

  // ── حقل كلمة المرور ──────────────────────────────────────────────────────
  Widget _buildPasswordField({
    required TextEditingController ctrl,
    required String hint,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FA),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Icon(
                visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 20, color: const Color(0xFF9C4DCC),
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: ctrl,
              obscureText: !visible,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, color: Color(0xFF2D2D2D)),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: const TextStyle(
                    color: Color(0xFFBDBDBD), fontFamily: 'Cairo', fontSize: 13),
                contentPadding: const EdgeInsets.only(right: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── زر الإجراء الرئيسي ───────────────────────────────────────────────────
  Widget _buildActionButton({
    required String label,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: AnimatedOpacity(
          opacity: loading ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
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
                  blurRadius: 14, offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: Colors.white, fontFamily: 'Cairo',
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── تبويب وضع الشاشة (إنشاء / دخول) ─────────────────────────────────────────
class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFFAB7AE0), Color(0xFF7B1FA2)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                fontFamily: 'Cairo',
                color: active ? Colors.white : const Color(0xFF9C4DCC),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── خطوة صغيرة في الـ dialog ─────────────────────────────────────────────────
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
            child: Text(text,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontFamily: 'Cairo', fontSize: 13, color: Color(0xFF424242))),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 10,
            backgroundColor: const Color(0xFF7B1FA2),
            child: Text(n,
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
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
          : _kDialCodes
              .where((c) => c.$2.contains(q) || c.$3.contains(q))
              .toList();
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
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFDEDEDE),
                borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('اختر رمز الدولة',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo')),
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
                hintStyle: const TextStyle(
                    fontFamily: 'Cairo', color: Color(0xFFBDBDBD)),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Color(0xFF9AA0A6)),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
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
                    color: sel
                        ? const Color(0xFF9C4DCC).withAlpha(14)
                        : null,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 13),
                    child: Row(
                      children: [
                        Text(e.$1, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(e.$2,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontFamily: 'Cairo',
                                  fontWeight: sel
                                      ? FontWeight.w700
                                      : FontWeight.normal,
                                  color: sel
                                      ? const Color(0xFF9C4DCC)
                                      : const Color(0xFF2D2D2D))),
                        ),
                        const SizedBox(width: 8),
                        Text(e.$3,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF9C4DCC))),
                        if (sel) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_rounded,
                              color: Color(0xFF9C4DCC), size: 18),
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
