import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/routes.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _googleLoading = false;
  bool _guestLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phoneController.text.trim();
    final fullPhone = phone.startsWith('+') ? phone : '+964$phone';
    await ref.read(otpProvider.notifier).sendOtp(fullPhone);

    final state = ref.read(otpProvider);
    if (!mounted) return;
    if (state.codeSent) {
      context.push(AppRoutes.otp);
    } else if (state.error != null) {
      _showError(state.error!);
    }
  }

  Future<void> _googleLogin() async {
    if (_googleLoading) return;
    setState(() => _googleLoading = true);
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      if (!mounted) return;
      if (user != null) {
        context.go(AppRoutes.home);
      } else {
        context.push(AppRoutes.register);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('فشل تسجيل الدخول بجوجل، يرجى المحاولة مجدداً');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _guestLogin() async {
    if (_guestLoading) return;
    setState(() => _guestLoading = true);
    try {
      await ref.read(authRepositoryProvider).signInAnonymously();
      if (!mounted) return;
      context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      _showError('فشل الدخول كضيف، يرجى المحاولة مجدداً');
    } finally {
      if (mounted) setState(() => _guestLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otpState = ref.watch(otpProvider);

    return Scaffold(
      body: Stack(
        children: [
          // خلفية متدرجة
          Container(decoration: const BoxDecoration(gradient: AppColors.darkGradient)),
          Positioned(
            top: -80, left: -50,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withAlpha(40),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // شعار
                    Container(
                      width: 90, height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.primaryGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(80),
                            blurRadius: 24, spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.celebration_rounded, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Party Hub',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'سجّل دخولك وابدأ الحفلة',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 48),

                    // حقل رقم الهاتف
                    _PhoneField(controller: _phoneController),
                    const SizedBox(height: 16),

                    // زر إرسال OTP
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ElevatedButton(
                          onPressed: otpState.isLoading ? null : _sendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: otpState.isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('إرسال رمز التحقق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // فاصل
                    const Row(
                      children: [
                        Expanded(child: Divider(color: AppColors.divider)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('أو', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo')),
                        ),
                        Expanded(child: Divider(color: AppColors.divider)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Google
                    _SocialButton(
                      label: 'المتابعة بـ Google',
                      icon: Icons.g_mobiledata_rounded,
                      color: const Color(0xFF4285F4),
                      onTap: _googleLoading ? null : _googleLogin,
                      isLoading: _googleLoading,
                    ),
                    const SizedBox(height: 12),

                    // ضيف
                    _SocialButton(
                      label: 'الدخول كضيف',
                      icon: Icons.person_outline_rounded,
                      color: AppColors.surfaceLight,
                      onTap: _guestLoading ? null : _guestLogin,
                      isLoading: _guestLoading,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
      decoration: const InputDecoration(
        hintText: '+964 7XX XXX XXXX',
        hintStyle: TextStyle(color: AppColors.textHint),
        prefixIcon: Icon(Icons.phone_rounded, color: AppColors.primary),
        filled: true,
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'أدخل رقم الهاتف';
        if (v.trim().length < 9) return 'رقم الهاتف غير صحيح';
        return null;
      },
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.textPrimary, strokeWidth: 2))
            : Icon(icon, color: color),
        label: Text(label, style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo')),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
