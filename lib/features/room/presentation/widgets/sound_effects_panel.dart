import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

typedef OnSendEffect = Future<void> Function(String emoji, String label);

class SoundEffectsPanel extends StatelessWidget {
  const SoundEffectsPanel({super.key, required this.onSend});
  final OnSendEffect onSend;

  static const _effects = [
    ('👏', 'تصفيق'),
    ('😂', 'ضحك'),
    ('🎉', 'احتفال'),
    ('🔥', 'نار'),
    ('❤️', 'قلب'),
    ('👍', 'رائع'),
    ('😮', 'مفاجأة'),
    ('😢', 'حزن'),
    ('💯', 'مئة'),
    ('🎵', 'موسيقى'),
    ('⚡', 'برق'),
    ('🌹', 'وردة'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          const Text('المؤثرات الصوتية', style: TextStyle(
            color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Cairo',
          )),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1,
            ),
            itemCount: _effects.length,
            itemBuilder: (_, i) {
              final (emoji, label) = _effects[i];
              return _EffectButton(emoji: emoji, label: label, onTap: () async {
                await onSend(emoji, label);
              });
            },
          ),
        ],
      ),
    );
  }
}

class _EffectButton extends StatefulWidget {
  const _EffectButton({required this.emoji, required this.label, required this.onTap});
  final String emoji, label;
  final VoidCallback onTap;

  @override
  State<_EffectButton> createState() => _EffectButtonState();
}

class _EffectButtonState extends State<_EffectButton> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween(begin: 1.0, end: 0.85).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tap() async {
    await _ctrl.forward();
    await _ctrl.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _tap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 4),
              Text(widget.label, style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 10, fontFamily: 'Cairo',
              )),
            ],
          ),
        ),
      ),
    );
  }
}
