import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routes.dart';
import '../providers/auth_provider.dart';
import 'otp_screen.dart';
import 'phone_auth_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _googleLoading = false;
  bool _yahooLoading  = false;

  // ── Google ────────────────────────────────────────────────────────────────
  Future<void> _googleLogin() async {
    if (_googleLoading) return;
    setState(() => _googleLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (!mounted) return;
      // Check displayName — _listenAuth() creates a bare Firestore doc the moment
      // auth fires, so user != null is true even for brand-new accounts.
      (user != null && user.displayName.isNotEmpty)
          ? context.go(AppRoutes.home)
          : context.go(AppRoutes.setupProfile);
    } catch (_) {
      if (mounted) _showError('فشل تسجيل الدخول بـ Google');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  // ── Yahoo ─────────────────────────────────────────────────────────────────
  Future<void> _yahooLogin() async {
    if (_yahooLoading) return;
    setState(() => _yahooLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInWithYahoo();
      if (!mounted) return;
      (user != null && user.displayName.isNotEmpty)
          ? context.go(AppRoutes.home)
          : context.go(AppRoutes.setupProfile);
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      if (msg.contains('canceled') || msg.contains('cancelled') || msg.contains('sign_in_canceled')) {
        // المستخدم ألغى — لا نُظهر خطأ
      } else if (msg.contains('operation-not-allowed') || msg.contains('auth/operation-not-allowed')) {
        _showError('Yahoo غير مُفعَّل في Firebase Console — فعّله أولاً');
      } else if (msg.contains('network')) {
        _showError('تحقق من اتصالك بالإنترنت');
      } else {
        _showError('فشل تسجيل الدخول بـ Yahoo، حاول مرة أخرى');
      }
    } finally {
      if (mounted) setState(() => _yahooLoading = false);
    }
  }

  // ── Phone — فتح شاشة تسجيل الهاتف ──────────────────────────────────────────
  void _openPhoneScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: const Color(0xFFEA4335),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── زخارف دوائر ألوان Google ───────────────────────────────────
          Positioned(top: -55,  left: -55,   child: _Blob(190, const Color(0xFF4285F4))),
          Positioned(top: 50,   right: -35,  child: _Blob(110, const Color(0xFF34A853))),
          Positioned(bottom: -65, right: -45, child: _Blob(210, const Color(0xFFEA4335))),
          Positioned(bottom: 30,  left: -35, child: _Blob(130, const Color(0xFFFBBC05))),
          Positioned(top: size.height * 0.36, left: 22,  child: _Blob(18, const Color(0xFF4285F4))),
          Positioned(top: size.height * 0.42, right: 26, child: _Blob(13, const Color(0xFFEA4335))),
          Positioned(top: size.height * 0.58, right: 20, child: _Blob(22, const Color(0xFF34A853))),
          Positioned(top: size.height * 0.63, left: 16,  child: _Blob(15, const Color(0xFFFBBC05))),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.10),

                  // ── أيقونة التطبيق ───────────────────────────────────
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(22), blurRadius: 24, offset: const Offset(0, 6))],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: ClipOval(child: Image.asset('assets/icon/icon.a1.png', fit: BoxFit.contain)),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'LivChat',
                    style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A), letterSpacing: -1.0),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'تواصل، استمتع، وكن جزء من المجتمع',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF5F6368), fontFamily: 'Cairo', height: 1.6),
                  ),

                  const Spacer(),

                  // ── Google ────────────────────────────────────────────
                  _LoginButton(
                    onTap: _googleLoading ? null : _googleLogin,
                    isLoading: _googleLoading,
                    icon: SizedBox(width: 22, height: 22, child: CustomPaint(painter: _GoogleGPainter())),
                    label: 'المتابعة بـ Google',
                    borderColor: const Color(0xFFDEDEDE),
                    textColor: const Color(0xFF3C4043),
                    bgColor: Colors.white,
                  ),

                  const SizedBox(height: 12),

                  // ── Yahoo ─────────────────────────────────────────────
                  _LoginButton(
                    onTap: _yahooLoading ? null : _yahooLogin,
                    isLoading: _yahooLoading,
                    icon: const _YahooIcon(),
                    label: 'المتابعة بـ Yahoo',
                    borderColor: const Color(0xFF6001D2),
                    textColor: Colors.white,
                    bgColor: const Color(0xFF6001D2),
                  ),

                  const SizedBox(height: 12),

                  // ── رقم الهاتف ────────────────────────────────────────
                  _LoginButton(
                    onTap: _openPhoneScreen,
                    icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
                    label: 'المتابعة برقم الهاتف',
                    borderColor: const Color(0xFF1565C0),
                    textColor: Colors.white,
                    bgColor: const Color(0xFF1565C0),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'بتسجيل دخولك توافق على شروط الاستخدام وسياسة الخصوصية',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey[400], fontFamily: 'Cairo'),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── زر تسجيل الدخول ──────────────────────────────────────────────────────────
class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.borderColor,
    required this.textColor,
    required this.bgColor,
    this.isLoading = false,
  });

  final VoidCallback? onTap;
  final Widget icon;
  final String label;
  final Color borderColor, textColor, bgColor;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(14), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: isLoading
              ? Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: textColor)))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    icon,
                    const SizedBox(width: 10),
                    Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor, fontFamily: 'Cairo')),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── أرقام الدول ───────────────────────────────────────────────────────────────
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

// ── Bottom sheet إدخال رقم الهاتف ────────────────────────────────────────────
class _PhoneSheet extends ConsumerStatefulWidget {
  const _PhoneSheet({required this.onCodeSent});
  final void Function(String verificationId, String phone) onCodeSent;

  @override
  ConsumerState<_PhoneSheet> createState() => _PhoneSheetState();
}

class _PhoneSheetState extends ConsumerState<_PhoneSheet> {
  final _numCtrl = TextEditingController();
  (String, String, String) _selected = _kDialCodes[1]; // العراق افتراضياً
  bool _loading = false;

  @override
  void dispose() {
    _numCtrl.dispose();
    super.dispose();
  }

  // رقم كامل مع رمز الدولة
  String get _fullPhone => '${_selected.$3}${_numCtrl.text.trim()}';

  Future<void> _pickDialCode() async {
    final result = await showModalBottomSheet<(String, String, String)>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DialCodeSheet(
        selected: _selected,
        onSelect: (v) => Navigator.pop(context, v),
      ),
    );
    if (result != null && mounted) setState(() => _selected = result);
  }

  Future<void> _send() async {
    final number = _numCtrl.text.trim();
    if (number.length < 6) {
      _showErr('أدخل رقم الهاتف بدون رمز الدولة');
      return;
    }
    setState(() => _loading = true);

    await ref.read(authRepositoryProvider).sendOtp(
      phoneNumber: _fullPhone,
      onCodeSent: (verId, _) {
        if (mounted) widget.onCodeSent(verId, _fullPhone);
      },
      onError: (e) {
        if (mounted) {
          setState(() => _loading = false);
          final msg = switch (e.code) {
            'invalid-phone-number' => 'رقم الهاتف غير صحيح',
            'too-many-requests'    => 'طلبات كثيرة، حاول لاحقاً',
            _                      => e.message ?? 'خطأ في الإرسال',
          };
          _showErr(msg);
        }
      },
      onAutoVerified: (_) {},
    );
  }

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: const Color(0xFFEA4335),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFDEDEDE), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('أدخل رقم هاتفك',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Cairo', color: Color(0xFF1A1A1A))),
            const SizedBox(height: 6),
            const Text('سنرسل لك رمز التحقق عبر SMS',
                style: TextStyle(fontSize: 13, color: Color(0xFF5F6368), fontFamily: 'Cairo')),
            const SizedBox(height: 20),

            // ── صف رمز الدولة + رقم الهاتف ─────────────────────────────────
            Row(
              children: [
                // منتقي رمز الدولة
                GestureDetector(
                  onTap: _pickDialCode,
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF1565C0).withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_selected.$1, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 4),
                        Text(_selected.$3,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                color: Color(0xFF1565C0), letterSpacing: 0.5)),
                        const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF1565C0), size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // حقل رقم الهاتف
                Expanded(
                  child: TextField(
                    controller: _numCtrl,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 17, letterSpacing: 1.5),
                    decoration: InputDecoration(
                      hintText: '7XXXXXXXX',
                      hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 16),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FA),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── زر الإرسال ────────────────────────────────────────────────────
            GestureDetector(
              onTap: _loading ? null : _send,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('إرسال الرمز',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, fontFamily: 'Cairo')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── شاشة اختيار رمز الدولة ───────────────────────────────────────────────────
class _DialCodeSheet extends StatefulWidget {
  const _DialCodeSheet({required this.selected, required this.onSelect});
  final (String, String, String) selected;
  final void Function((String, String, String)) onSelect;

  @override
  State<_DialCodeSheet> createState() => _DialCodeSheetState();
}

class _DialCodeSheetState extends State<_DialCodeSheet> {
  final _searchCtrl = TextEditingController();
  List<(String, String, String)> _filtered = _kDialCodes;

  void _onSearch(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? _kDialCodes
          : _kDialCodes.where((c) => c.$2.contains(q) || c.$3.contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Cairo', color: Color(0xFF1A1A1A))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
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
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final entry = _filtered[i];
                final isSelected = widget.selected.$3 == entry.$3 && widget.selected.$2 == entry.$2;
                return InkWell(
                  onTap: () => widget.onSelect(entry),
                  child: Container(
                    color: isSelected ? const Color(0xFF1565C0).withAlpha(14) : null,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                    child: Row(
                      children: [
                        Text(entry.$1, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(entry.$2,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 15, fontFamily: 'Cairo',
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                color: isSelected ? const Color(0xFF1565C0) : const Color(0xFF2D2D2D),
                              )),
                        ),
                        const SizedBox(width: 8),
                        Text(entry.$3,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600,
                                color: Color(0xFF1565C0), letterSpacing: 0.5)),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_rounded, color: Color(0xFF1565C0), size: 18),
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

// ── دائرة زخرفية ─────────────────────────────────────────────────────────────
class _Blob extends StatelessWidget {
  const _Blob(this.size, this.color);
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withAlpha(28)),
      );
}

// ── أيقونة Yahoo ──────────────────────────────────────────────────────────────
class _YahooIcon extends StatelessWidget {
  const _YahooIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: Center(
        child: Text(
          'Y!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }
}

// ── رسم حرف G ─────────────────────────────────────────────────────────────────
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final sw = r * 0.34;
    final ar = r - sw / 2;
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = sw..strokeCap = StrokeCap.butt;

    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), -1.57, 1.57, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), 0.0, 1.57, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), 1.57, 1.57, false, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: c, radius: ar), 3.14, 1.14, false, paint);
    canvas.drawRect(Rect.fromLTWH(c.dx, c.dy - sw / 2, ar, sw),
        Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
