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
  final _phoneCtrl   = TextEditingController();
  final _otpCtrl     = TextEditingController();
  final _otpFocus    = FocusNode();

  (String, String, String) _dial = _kDialCodes[1]; // العراق افتراضياً

  String? _verificationId;
  bool _sendLoading = false;
  bool _verLoading  = false;

  bool get _busy      => _sendLoading || _verLoading;
  bool get _codeSent  => _verificationId != null;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  String get _fullPhone {
    var num = _phoneCtrl.text.trim();
    if (num.startsWith('0')) num = num.substring(1);
    return '${_dial.$3}$num';
  }

  // ── إرسال OTP ────────────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final number = _phoneCtrl.text.trim();
    if (number.length < 5) {
      _toast('أدخل رقم الهاتف أولاً', isError: true);
      return;
    }
    setState(() => _sendLoading = true);

    final repo = ref.read(authRepositoryProvider);
    await repo.sendOtp(
      phoneNumber: _fullPhone,
      onCodeSent: (verId, _) {
        if (!mounted) return;
        setState(() {
          _verificationId = verId;
          _sendLoading    = false;
          _otpCtrl.clear();
        });
        _otpFocus.requestFocus();
        _toast('تم إرسال رمز التحقق');
      },
      onError: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _sendLoading = false);
        final msg = _otpSendErrorMsg(e);
        if (msg.isNotEmpty) _toast(msg, isError: true);
      },
      onAutoVerified: (PhoneAuthCredential cred) async {
        if (!mounted) return;
        setState(() { _sendLoading = false; _verLoading = true; });
        try {
          await FirebaseAuth.instance.signInWithCredential(cred);
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

  // ── التحقق من رمز OTP ─────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.trim().length != 6) {
      _toast('الرمز يجب أن يكون 6 أرقام', isError: true);
      return;
    }
    if (_verificationId == null) {
      _toast('أرسل رمز التحقق أولاً', isError: true);
      return;
    }
    if (_verLoading) return;
    setState(() => _verLoading = true);

    final repo = ref.read(authRepositoryProvider);
    try {
      final user = await repo.verifyOtpAndLogin(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
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

  // ── رسائل خطأ إرسال OTP ──────────────────────────────────────────────
  String _otpSendErrorMsg(FirebaseAuthException e) {
    final raw = e.message ?? '';
    if (e.code == 'invalid-phone-number')  return 'رقم الهاتف غير صحيح';
    if (e.code == 'too-many-requests')      return 'طلبات كثيرة، انتظر قليلاً';
    if (e.code == 'operation-not-allowed')  return 'تسجيل الهاتف غير مُفعَّل في Firebase';
    if (e.code == 'network-request-failed') return 'تحقق من اتصالك بالإنترنت';
    if (raw.contains('region') || raw.contains('SMS unable')) {
      _showRegionDialog();
      return '';
    }
    return 'خطأ: ${e.code}';
  }

  // ── رسائل خطأ التحقق ─────────────────────────────────────────────────
  String _authErrorMsg(Object e) {
    final s = e.toString();
    if (s.contains('invalid-verification-code')) return 'رمز التحقق غير صحيح';
    if (s.contains('session-expired'))            return 'انتهت صلاحية الرمز، أعد إرسال الرمز';
    if (s.contains('too-many-requests'))          return 'محاولات كثيرة، انتظر قليلاً';
    if (s.contains('network-request-failed'))     return 'تحقق من اتصالك بالإنترنت';
    return 'حدث خطأ، حاول مجدداً';
  }

  // ── حوار إعداد SMS regions ─────────────────────────────────────────────
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
            Text('يجب تفعيل SMS للمناطق في Firebase Console:',
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 14)),
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

  // ── بناء الواجهة ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // تدرج علوي
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
                // شريط العنوان
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios_rounded,
                            size: 22, color: Color(0xFF5C35A0)),
                      ),
                      const Text('LivChat',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                              fontFamily: 'Cairo', color: Color(0xFF2D2D2D))),
                      const SizedBox(width: 26),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 36),

        // أيقونة
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFAB7AE0), Color(0xFF7B1FA2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [BoxShadow(color: const Color(0xFF9C4DCC).withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: const Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(height: 20),

        const Text('أدخل رقم هاتفك',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                fontFamily: 'Cairo', color: Color(0xFF2D2D2D))),
        const SizedBox(height: 6),
        const Text('سنرسل لك رمز التحقق عبر SMS',
            style: TextStyle(fontSize: 13, fontFamily: 'Cairo', color: Color(0xFF9AA0A6))),

        const SizedBox(height: 36),

        // ── حقل رقم الهاتف ──
        const Align(
          alignment: Alignment.centerRight,
          child: Text('رقم الهاتف',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  fontFamily: 'Cairo', color: Color(0xFF5C35A0))),
        ),
        const SizedBox(height: 8),
        _buildPhoneField(),

        const SizedBox(height: 20),

        // ── حقل رمز التحقق مع زر الإرسال ──
        const Align(
          alignment: Alignment.centerRight,
          child: Text('رمز التحقق',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  fontFamily: 'Cairo', color: Color(0xFF5C35A0))),
        ),
        const SizedBox(height: 8),
        _buildOtpRow(),

        const SizedBox(height: 32),

        // زر تأكيد
        _buildActionButton(
          label: 'تحقق ودخول',
          loading: _verLoading,
          onTap: _verifyOtp,
        ),

        const SizedBox(height: 16),

        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Color(0xFF9AA0A6)),
            children: [
              TextSpan(text: 'بالمتابعة توافق على '),
              TextSpan(text: 'شروط الاستخدام',
                  style: TextStyle(color: Color(0xFF7B1FA2), fontWeight: FontWeight.w700)),
            ],
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ── مستطيل رمز التحقق مع زر إرسال على اليسار ────────────────────────
  Widget _buildOtpRow() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0FA),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _codeSent
              ? const Color(0xFF9C4DCC).withAlpha(100)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // زر إرسال الرمز — يسار المستطيل
          GestureDetector(
            onTap: _busy ? null : _sendOtp,
            child: Container(
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFAB7AE0), Color(0xFF7B1FA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: _sendLoading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _codeSent ? 'إعادة' : 'إرسال الرمز',
                        style: const TextStyle(
                          color: Colors.white, fontFamily: 'Cairo',
                          fontWeight: FontWeight.w700, fontSize: 13,
                        ),
                      ),
              ),
            ),
          ),

          // فاصل عمودي
          Container(
            height: 24, width: 1,
            color: const Color(0xFFD0D0D0),
            margin: const EdgeInsets.symmetric(horizontal: 2),
          ),

          // حقل إدخال الرمز
          Expanded(
            child: TextField(
              controller: _otpCtrl,
              focusNode: _otpFocus,
              enabled: _codeSent,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (v) {
                setState(() {});
                if (v.length == 6) _verifyOtp();
              },
              style: const TextStyle(
                fontSize: 22, letterSpacing: 10,
                fontWeight: FontWeight.w800, color: Color(0xFF2D2D2D),
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                hintText: _codeSent ? '● ● ● ● ● ●' : '— — — — — —',
                hintStyle: TextStyle(
                  color: _codeSent
                      ? const Color(0xFF9C4DCC).withAlpha(90)
                      : const Color(0xFFD0D0D0),
                  fontSize: _codeSent ? 9 : 14,
                  letterSpacing: _codeSent ? 6 : 3,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          // زر مسح إذا في نص
          if (_otpCtrl.text.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _otpCtrl.clear()),
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                width: 26, height: 26,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.withAlpha(60)),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.grey),
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }

  // ── حقل رقم الهاتف ───────────────────────────────────────────────────
  Widget _buildPhoneField() {
    return Container(
      height: 56,
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
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.withAlpha(60)),
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
              style: const TextStyle(fontSize: 16, letterSpacing: 1, color: Color(0xFF2D2D2D)),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: '07XXXXXXXXX',
                hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          Container(height: 22, width: 1, color: const Color(0xFFD0D0D0),
              margin: const EdgeInsets.symmetric(horizontal: 8)),

          GestureDetector(
            onTap: _pickDial,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Text(_dial.$3,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF5C35A0))),
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

  // ── زر الإجراء الرئيسي ───────────────────────────────────────────────
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
              boxShadow: [BoxShadow(color: const Color(0xFF9C4DCC).withAlpha(70), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Center(
              child: loading
                  ? const SizedBox(width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text(label,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                          color: Colors.white, fontFamily: 'Cairo')),
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
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFDEDEDE), borderRadius: BorderRadius.circular(2)),
          ),
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
                        Text(e.$3,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF9C4DCC))),
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
