import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/zego_service.dart';

final _selectedEffectProvider = StateProvider<ZegoVoiceChangerPreset?>((ref) => null);
final _selectedReverbProvider  = StateProvider<ZegoReverbPreset?>((ref) => null);

// (preset, emoji, label)
final _voiceEffects = [
  (ZegoVoiceChangerPreset.None,         '😐', 'طبيعي'),
  (ZegoVoiceChangerPreset.OptimusPrime, '🤖', 'روبوت'),
  (ZegoVoiceChangerPreset.MenToWomen,   '👩', 'أنثوي'),
  (ZegoVoiceChangerPreset.WomenToMen,   '🧔', 'ذكوري'),
  (ZegoVoiceChangerPreset.MenToChild,   '👦', 'طفل'),
  (ZegoVoiceChangerPreset.MaleMagnetic, '🎸', 'مغناطيسي'),
  (ZegoVoiceChangerPreset.Ethereal,     '🌸', 'ملائكي'),
  (ZegoVoiceChangerPreset.FemaleFresh,  '🎤', 'ناصع'),
];

final _reverbs = [
  (ZegoReverbPreset.None,        '🚫', 'لا شيء'),
  (ZegoReverbPreset.SoftRoom,    '🏠', 'غرفة'),
  (ZegoReverbPreset.LargeRoom,   '🏛️', 'قاعة'),
  (ZegoReverbPreset.ConcertHall, '🎭', 'مسرح'),
];

class VoiceEffectsSheet extends ConsumerWidget {
  const VoiceEffectsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedEffect = ref.watch(_selectedEffectProvider);
    final selectedReverb = ref.watch(_selectedReverbProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          const Text('تأثيرات الصوت', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
          const SizedBox(height: 20),

          // شبكة تأثيرات الصوت
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.85,
            ),
            itemCount: _voiceEffects.length,
            itemBuilder: (_, i) {
              final (preset, emoji, label) = _voiceEffects[i];
              final isSelected = selectedEffect == preset;
              return GestureDetector(
                onTap: () async {
                  ref.read(_selectedEffectProvider.notifier).state = preset;
                  await ZegoService().setVoiceEffect(preset);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withAlpha(40) : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(label, style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        fontSize: 11, fontFamily: 'Cairo',
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                      ), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('الصدى', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),

          // صف الريفيرب
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _reverbs.map((r) {
              final (preset, emoji, label) = r;
              final isSelected = selectedReverb == preset;
              return GestureDetector(
                onTap: () async {
                  ref.read(_selectedReverbProvider.notifier).state = preset;
                  await ZegoExpressEngine.instance.setReverbPreset(preset);
                },
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accent.withAlpha(40) : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSelected ? AppColors.accent : Colors.transparent, width: 2),
                      ),
                      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
                    ),
                    const SizedBox(height: 4),
                    Text(label, style: TextStyle(
                      color: isSelected ? AppColors.accent : AppColors.textSecondary,
                      fontSize: 10, fontFamily: 'Cairo',
                    )),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
