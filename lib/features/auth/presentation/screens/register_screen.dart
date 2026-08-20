import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/routes.dart';
import '../../data/models/user_model.dart';
import '../providers/auth_provider.dart';
import '../../../../features/wallet/data/repositories/wallet_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedGender;
  DateTime? _birthday;
  File? _avatarFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<String?> _uploadAvatar(String uid) async {
    if (_avatarFile == null) return null;
    final ref = FirebaseStorage.instance.ref('avatars/$uid.jpg');
    await ref.putFile(_avatarFile!);
    return ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      _showError('اختر الجنس');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final firebaseUser = FirebaseAuth.instance.currentUser!;
      final avatarUrl = await _uploadAvatar(firebaseUser.uid);

      final user = UserModel(
        uid: firebaseUser.uid,
        displayName: _nameController.text.trim(),
        avatar: avatarUrl,
        gender: _selectedGender,
        birthday: _birthday,
        phoneNumber: firebaseUser.phoneNumber ?? '',
        createdAt: DateTime.now(),
      );

      await ref.read(authRepositoryProvider).saveNewUser(user);

      // هدية الترحيب — 500,000 عملة لكل مستخدم جديد
      await WalletRepository().addCoins(
        firebaseUser.uid,
        500000,
        'هدية الترحيب 🎁',
      );

      if (!mounted) return;
      context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      _showError('حدث خطأ، حاول مجدداً');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: const BoxDecoration(gradient: AppColors.darkGradient)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    const Text(
                      'أكمل ملفك الشخصي',
                      style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary, fontFamily: 'Cairo',
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'أضف معلوماتك لتبدأ الحفلة',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontFamily: 'Cairo'),
                    ),
                    const SizedBox(height: 32),

                    // صورة الملف الشخصي
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: AppColors.surfaceLight,
                            backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
                            child: _avatarFile == null
                                ? const Icon(Icons.person_rounded, size: 52, color: AppColors.textHint)
                                : null,
                          ),
                          Positioned(
                            bottom: 0, left: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // الاسم
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
                      decoration: const InputDecoration(
                        hintText: 'الاسم المعروض',
                        prefixIcon: Icon(Icons.badge_rounded, color: AppColors.primary),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'أدخل اسمك';
                        if (v.trim().length < 2) return 'الاسم قصير جداً';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // الجنس
                    Row(
                      children: [
                        _GenderCard(
                          label: 'ذكر',
                          icon: Icons.male_rounded,
                          selected: _selectedGender == 'male',
                          onTap: () => setState(() => _selectedGender = 'male'),
                        ),
                        const SizedBox(width: 12),
                        _GenderCard(
                          label: 'أنثى',
                          icon: Icons.female_rounded,
                          selected: _selectedGender == 'female',
                          onTap: () => setState(() => _selectedGender = 'female'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // تاريخ الميلاد
                    GestureDetector(
                      onTap: _pickBirthday,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.cake_rounded, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Text(
                              _birthday == null
                                  ? 'تاريخ الميلاد (اختياري)'
                                  : '${_birthday!.year}/${_birthday!.month}/${_birthday!.day}',
                              style: TextStyle(
                                color: _birthday == null ? AppColors.textHint : AppColors.textPrimary,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // زر الإنشاء
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22, height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'ابدأ الحفلة 🎉',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Cairo'),
                                ),
                        ),
                      ),
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

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withAlpha(40) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? AppColors.primary : AppColors.textHint, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  fontFamily: 'Cairo',
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
