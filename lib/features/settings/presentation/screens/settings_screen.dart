import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/chat_colors.dart';
import '../../../../app/routes.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

// ── Countries list ────────────────────────────────────────────────────────────
const _kCountries = [
  ('🇸🇦', 'السعودية'),  ('🇮🇶', 'العراق'),    ('🇦🇪', 'الإمارات'),
  ('🇰🇼', 'الكويت'),   ('🇶🇦', 'قطر'),        ('🇧🇭', 'البحرين'),
  ('🇴🇲', 'عُمان'),    ('🇾🇪', 'اليمن'),       ('🇯🇴', 'الأردن'),
  ('🇸🇾', 'سوريا'),    ('🇱🇧', 'لبنان'),       ('🇵🇸', 'فلسطين'),
  ('🇪🇬', 'مصر'),      ('🇱🇾', 'ليبيا'),        ('🇹🇳', 'تونس'),
  ('🇩🇿', 'الجزائر'),  ('🇲🇦', 'المغرب'),       ('🇸🇩', 'السودان'),
  ('🇹🇷', 'تركيا'),    ('🇮🇷', 'إيران'),         ('🇵🇰', 'باكستان'),
  ('🇮🇳', 'الهند'),    ('🇬🇧', 'بريطانيا'),     ('🇺🇸', 'أمريكا'),
  ('🇩🇪', 'ألمانيا'),  ('🇫🇷', 'فرنسا'),        ('🇸🇪', 'السويد'),
  ('🇨🇦', 'كندا'),     ('🇦🇺', 'أستراليا'),
];

// ── Unified Profile Screen ────────────────────────────────────────────────────

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  bool _initialized = false;
  String? _nameColorHex;
  String? _textColorHex;
  String? _country;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _initFromProfile(Map<String, dynamic> profile) {
    if (_initialized) return;
    _initialized = true;
    _nameCtrl.text = profile['displayName'] as String? ?? '';
    _nameColorHex = profile['nameColor'] as String?;
    _textColorHex = profile['textColor'] as String?;
    _country      = profile['country']   as String?;
  }

  Future<void> _pickCountry(Map<String, dynamic> profile) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CountrySheet(
        selected: _country,
        onSelect: (c) => Navigator.pop(context, c),
      ),
    );
    if (result != null && mounted) setState(() => _country = result);
  }

  Future<void> _save(String uid, Map<String, dynamic> profile) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      final updates = <String, dynamic>{};

      if (name != (profile['displayName'] ?? '')) {
        updates['displayName'] = name;
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      }
      if (_nameColorHex != null) updates['nameColor'] = _nameColorHex;
      if (_textColorHex != null) updates['textColor'] = _textColorHex;
      if (_country != null)      updates['country']   = _country;

      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(updates, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم الحفظ ✅', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.black87,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red.shade800,
        ));
        return;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => sheet,
    );
  }

  void _showTextPage(BuildContext context, String title, String content) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => _TextPage(title: title, content: content)));
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تسجيل الخروج',
            style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo')),
        content: const Text('هل تريد تسجيل الخروج؟',
            style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
            child: const Text('خروج',
                style: TextStyle(color: AppColors.error, fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale      = ref.watch(localeProvider);
    final isArabic    = locale.languageCode == 'ar';
    final profileAsync = ref.watch(userProfileStreamProvider);
    final profile     = profileAsync.valueOrNull ?? {};
    final uid         = FirebaseAuth.instance.currentUser?.uid ?? '';

    _initFromProfile(profile);


    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: const Text('الملف الشخصي',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          // ── تعديل الملف الشخصي ─────────────────────────────────────
          _sectionHeader('تعديل الملف الشخصي'),

          // الاسم
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _nameCtrl,
              maxLength: 30,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 15),
              decoration: InputDecoration(
                labelText: 'الاسم الظاهر',
                labelStyle: const TextStyle(
                    color: AppColors.textSecondary, fontFamily: 'Cairo'),
                prefixIcon:
                    const Icon(Icons.person_rounded, color: AppColors.primary),
                filled: true,
                fillColor: AppColors.surface,
                counterStyle:
                    const TextStyle(color: AppColors.textHint, fontSize: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),

          // الدولة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الدولة',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontFamily: 'Cairo',
                        fontSize: 13)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _pickCountry(profile),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _country != null
                            ? AppColors.primary
                            : AppColors.divider,
                        width: _country != null ? 1.5 : 1,
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
                            fontFamily: 'Cairo',
                            fontSize: 15,
                            color: _country != null
                                ? AppColors.textPrimary
                                : AppColors.textHint,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          color: _country != null
                              ? AppColors.primary
                              : AppColors.textHint),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          // لون الاسم
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _ColorPicker(
              label: 'لون الاسم',
              selectedHex: _nameColorHex,
              onSelect: (h) => setState(() => _nameColorHex = h),
            ),
          ),
          const SizedBox(height: 12),

          // لون الكتابة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _ColorPicker(
              label: 'لون الكتابة',
              selectedHex: _textColorHex,
              onSelect: (h) => setState(() => _textColorHex = h),
            ),
          ),
          const SizedBox(height: 16),

          // زر الحفظ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _loading ? null : () => _save(uid, profile),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('حفظ ✅',
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w900,
                            fontSize: 16)),
              ),
            ),
          ),

          // ── الحساب ─────────────────────────────────────────────────
          const Divider(color: AppColors.divider, height: 1),
          _sectionHeader('الحساب'),
          _tile(
            icon: Icons.lock_outline_rounded,
            title: 'الخصوصية والأمان',
            onTap: () => _showSheet(context, const _PrivacySheet()),
          ),
          _tile(icon: Icons.block_rounded, title: 'قائمة الحظر', onTap: () {}),

          // ── المكافآت ────────────────────────────────────────────────
          const Divider(color: AppColors.divider, height: 1),
          _sectionHeader('المكافآت'),
          _tile(
            icon: Icons.card_giftcard_rounded,
            title: 'المكافأة اليومية',
            onTap: () => context.push('/daily-reward'),
          ),

          // ── التطبيق ─────────────────────────────────────────────────
          const Divider(color: AppColors.divider, height: 1),
          _sectionHeader('التطبيق'),
          _tile(
            icon: Icons.language_rounded,
            title: 'اللغة',
            trailing: Text(
              isArabic ? 'العربية' : 'English',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontFamily: 'Cairo'),
            ),
            onTap: () => _showSheet(context, const _LanguageSheet()),
          ),
          _tile(
            icon: Icons.notifications_outlined,
            title: 'الإشعارات',
            onTap: () => _showSheet(context, const _NotifSheet()),
          ),
          _tile(
              icon: Icons.volume_up_outlined,
              title: 'الصوت والمؤثرات',
              onTap: () {}),

          // ── المعلومات ───────────────────────────────────────────────
          const Divider(color: AppColors.divider, height: 1),
          _sectionHeader('المعلومات'),
          _tile(
            icon: Icons.privacy_tip_outlined,
            title: 'سياسة الخصوصية',
            onTap: () =>
                _showTextPage(context, 'سياسة الخصوصية', _kPrivacy),
          ),
          _tile(
            icon: Icons.article_outlined,
            title: 'شروط الاستخدام',
            onTap: () =>
                _showTextPage(context, 'شروط الاستخدام', _kTerms),
          ),
          _tile(
            icon: Icons.info_outline_rounded,
            title: 'عن التطبيق',
            trailing: const Text('1.0.0',
                style: TextStyle(
                    color: AppColors.textSecondary, fontFamily: 'Cairo')),
            onTap: () {},
          ),

          // ── تسجيل الخروج ────────────────────────────────────────────
          const Divider(color: AppColors.divider, height: 1),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _confirmLogout(context),
              child: const Text('تسجيل الخروج',
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title,
            style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'Cairo')),
      );

  Widget _tile(
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      Widget? trailing}) {
    return ListTile(
      tileColor: AppColors.surface,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontFamily: 'Cairo',
              fontSize: 14)),
      trailing: trailing ??
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textHint, size: 20),
      onTap: onTap,
    );
  }
}

// ── Country Sheet ─────────────────────────────────────────────────────────────

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.selected, required this.onSelect});
  final String? selected;
  final void Function(String) onSelect;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  final _searchCtrl = TextEditingController();
  List<(String, String)> _filtered = _kCountries;

  void _onSearch(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? _kCountries
          : _kCountries
              .where((c) => c.$2.contains(q) || c.$1.contains(q))
              .toList();
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
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Text('اختر دولتك',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                  color: AppColors.textPrimary)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearch,
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'ابحث عن دولة...',
              hintStyle: const TextStyle(
                  fontFamily: 'Cairo', color: AppColors.textHint),
              prefixIcon: const Icon(Icons.search_rounded,
                  color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: ListView.builder(
            itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final (flag, name) = _filtered[i];
              final value = '$flag $name';
              final isSelected = widget.selected == value;
              return InkWell(
                onTap: () => widget.onSelect(value),
                child: Container(
                  color: isSelected
                      ? AppColors.primary.withAlpha(18)
                      : null,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_circle_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(flag, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(name,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 15,
                              fontFamily: 'Cairo',
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary)),
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

// ── Color Picker ──────────────────────────────────────────────────────────────

class _ColorPicker extends StatelessWidget {
  const _ColorPicker(
      {required this.label,
      required this.selectedHex,
      required this.onSelect});
  final String label;
  final String? selectedHex;
  final void Function(String hex) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Cairo',
                fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: kChatColors.map((c) {
            final isSelected = selectedHex == c.$1;
            final clr = hexColor(c.$1);
            return GestureDetector(
              onTap: () => onSelect(c.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: clr,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.divider,
                    width: isSelected ? 2.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: clr.withAlpha(100), blurRadius: 8)
                        ]
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: clr.computeLuminance() > 0.5
                            ? Colors.black87
                            : Colors.white,
                        size: 16,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Language Sheet ────────────────────────────────────────────────────────────

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
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('اختر اللغة',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo')),
          const SizedBox(height: 16),
          _langTile(context, ref,
              flag: '🇸🇦',
              name: 'العربية',
              code: 'ar',
              current: locale.languageCode),
          const SizedBox(height: 8),
          _langTile(context, ref,
              flag: '🇬🇧',
              name: 'English',
              code: 'en',
              current: locale.languageCode),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _langTile(BuildContext context, WidgetRef ref,
      {required String flag,
      required String name,
      required String code,
      required String current}) {
    final isSelected = current == code;
    return GestureDetector(
      onTap: () {
        ref.read(localeProvider.notifier).setLocale(Locale(code));
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(30)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent),
        ),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Text(name,
              style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          if (isSelected)
            const Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 20),
        ]),
      ),
    );
  }
}

// ── Notification Sheet ────────────────────────────────────────────────────────

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
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('إشعارات التطبيق',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo')),
          const SizedBox(height: 8),
          _switchTile('رسائل جديدة', _messages,
              (v) => setState(() => _messages = v)),
          _switchTile(
              'هدايا واردة', _gifts, (v) => setState(() => _gifts = v)),
          _switchTile('متابعون جدد', _follows,
              (v) => setState(() => _follows = v)),
          _switchTile(
              'دعوات الغرف', _rooms, (v) => setState(() => _rooms = v)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _switchTile(String title, bool value, void Function(bool) onChanged) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary, fontFamily: 'Cairo')),
        trailing: Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary),
      );
}

// ── Privacy Sheet ─────────────────────────────────────────────────────────────

class _PrivacySheet extends StatelessWidget {
  const _PrivacySheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('الخصوصية',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo')),
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
        title: Text(title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Cairo',
                fontSize: 13)),
        trailing: Text(value,
            style: const TextStyle(
                color: AppColors.primary,
                fontFamily: 'Cairo',
                fontSize: 12)),
      );
}

// ── Text Page ─────────────────────────────────────────────────────────────────

class _TextPage extends StatelessWidget {
  const _TextPage({required this.title, required this.content});
  final String title, content;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(title,
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(content,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Cairo',
                fontSize: 14,
                height: 1.8)),
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
