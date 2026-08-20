import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/routes.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isArabic = locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('الإعدادات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          _sectionHeader('الحساب'),
          _tile(icon: Icons.person_outline_rounded, title: 'تعديل الملف الشخصي', onTap: () {}),
          _tile(
            icon: Icons.lock_outline_rounded,
            title: 'الخصوصية والأمان',
            onTap: () => _showSheet(context, const _PrivacySheet()),
          ),
          _tile(icon: Icons.block_rounded, title: 'قائمة الحظر', onTap: () {}),
          const Divider(color: AppColors.divider, height: 1),
          _sectionHeader('التطبيق'),
          _tile(
            icon: Icons.language_rounded,
            title: 'اللغة',
            trailing: Text(
              isArabic ? 'العربية' : 'English',
              style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'),
            ),
            onTap: () => _showSheet(context, const _LanguageSheet()),
          ),
          _tile(
            icon: Icons.notifications_outlined,
            title: 'الإشعارات',
            onTap: () => _showSheet(context, const _NotifSheet()),
          ),
          _tile(icon: Icons.volume_up_outlined, title: 'الصوت والمؤثرات', onTap: () {}),
          const Divider(color: AppColors.divider, height: 1),
          _sectionHeader('المعلومات'),
          _tile(
            icon: Icons.privacy_tip_outlined,
            title: 'سياسة الخصوصية',
            onTap: () => _showTextPage(context, 'سياسة الخصوصية', _kPrivacy),
          ),
          _tile(
            icon: Icons.article_outlined,
            title: 'شروط الاستخدام',
            onTap: () => _showTextPage(context, 'شروط الاستخدام', _kTerms),
          ),
          _tile(
            icon: Icons.info_outline_rounded,
            title: 'عن التطبيق',
            trailing: const Text('1.0.0', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
            onTap: () {},
          ),
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _confirmLogout(context, ref),
              child: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title, style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
      );

  Widget _tile({required IconData icon, required String title, required VoidCallback onTap, Widget? trailing}) {
    return ListTile(
      tileColor: AppColors.surface,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 14)),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.textHint, size: 20),
      onTap: onTap,
    );
  }

  void _showSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => sheet,
    );
  }

  void _showTextPage(BuildContext context, String title, String content) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _TextPage(title: title, content: content)));
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo')),
        content: const Text('هل تريد تسجيل الخروج؟', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            child: const Text('خروج', style: TextStyle(color: AppColors.error, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }
}

// ── Language Sheet ────────────────────────────────────────────────
class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('اختر اللغة', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
          const SizedBox(height: 16),
          _langTile(context, ref, flag: '🇸🇦', name: 'العربية', code: 'ar', current: locale.languageCode),
          const SizedBox(height: 8),
          _langTile(context, ref, flag: '🇬🇧', name: 'English', code: 'en', current: locale.languageCode),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _langTile(BuildContext context, WidgetRef ref, {required String flag, required String name, required String code, required String current}) {
    final isSelected = current == code;
    return GestureDetector(
      onTap: () {
        ref.read(localeProvider.notifier).setLocale(Locale(code));
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(30) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
        ),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Text(name, style: TextStyle(color: isSelected ? AppColors.primary : AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (isSelected) const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
        ]),
      ),
    );
  }
}

// ── Notification Settings Sheet ───────────────────────────────────
class _NotifSheet extends StatefulWidget {
  const _NotifSheet();

  @override
  State<_NotifSheet> createState() => _NotifSheetState();
}

class _NotifSheetState extends State<_NotifSheet> {
  bool _messages = true, _gifts = true, _follows = true, _rooms = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('إشعارات التطبيق', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
          const SizedBox(height: 8),
          _switchTile('رسائل جديدة', _messages, (v) => setState(() => _messages = v)),
          _switchTile('هدايا واردة', _gifts, (v) => setState(() => _gifts = v)),
          _switchTile('متابعون جدد', _follows, (v) => setState(() => _follows = v)),
          _switchTile('دعوات الغرف', _rooms, (v) => setState(() => _rooms = v)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _switchTile(String title, bool value, void Function(bool) onChanged) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo')),
        trailing: Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
      );
}

// ── Privacy Sheet ─────────────────────────────────────────────────
class _PrivacySheet extends StatelessWidget {
  const _PrivacySheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('الخصوصية', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
          const SizedBox(height: 8),
          _privacyRow('من يستطيع إرسال رسائل لي', 'الجميع'),
          _privacyRow('من يستطيع رؤية ملفي', 'الجميع'),
          _privacyRow('عرض آخر ظهور', 'الجميع'),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _privacyRow(String title, String value) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 13)),
        trailing: Text(value, style: const TextStyle(color: AppColors.primary, fontFamily: 'Cairo', fontSize: 12)),
      );
}

// ── Text Page ─────────────────────────────────────────────────────
class _TextPage extends StatelessWidget {
  const _TextPage({required this.title, required this.content});
  final String title, content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(content, style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 14, height: 1.8)),
      ),
    );
  }
}

const _kPrivacy = '''
سياسة الخصوصية — Party Hub

نحن في Party Hub نلتزم بحماية خصوصيتك.

البيانات التي نجمعها:
• معلومات الحساب (الاسم، رقم الهاتف، الصورة الشخصية)
• بيانات الاستخدام والتفاعلات داخل التطبيق
• بيانات الجهاز ومعرّف الإشعارات

كيف نستخدم البيانات:
• تقديم خدمات التطبيق وتحسينها
• إرسال الإشعارات المتعلقة بحسابك

حماية البيانات:
نستخدم تشفيراً متقدماً ولا نبيع بياناتك لأطراف ثالثة.

للتواصل: privacy@partyhub.app
''';

const _kTerms = '''
شروط الاستخدام — Party Hub

بالاستخدام هذا التطبيق توافق على:

1. الاستخدام المقبول:
• يجب أن يكون عمرك 18 سنة أو أكثر
• يُحظر نشر محتوى مسيء أو مخالف للقانون
• يُحظر انتحال شخصية الآخرين

2. العملات الافتراضية:
الكوينز والألماس ليس لها قيمة نقدية حقيقية وغير قابلة للاسترداد.

3. إنهاء الحساب:
نحتفظ بحق إيقاف أي حساب يخالف الشروط.
''';
