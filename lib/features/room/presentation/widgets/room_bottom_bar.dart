import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../providers/room_provider.dart';
import '../../../../core/services/zego_service.dart';
import 'voice_effects_sheet.dart';

class RoomBottomBar extends ConsumerStatefulWidget {
  const RoomBottomBar({
    super.key,
    required this.onSendMessage,
    required this.onGift,
    required this.onSettings,
    required this.isHost,
    this.onSoundEffects,
  });

  final void Function(String) onSendMessage;
  final VoidCallback onGift;
  final VoidCallback onSettings;
  final bool isHost;
  final VoidCallback? onSoundEffects;

  @override
  ConsumerState<RoomBottomBar> createState() => _RoomBottomBarState();
}

class _RoomBottomBarState extends ConsumerState<RoomBottomBar> {
  final _textCtrl = TextEditingController();
  bool _showInput = false;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage(text);
    _textCtrl.clear();
    setState(() => _showInput = false);
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = ref.watch(isMicMutedProvider);

    return Container(
      color: Colors.black.withAlpha(160),
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
      child: _showInput ? _inputRow() : _actionRow(isMuted),
    );
  }

  Widget _actionRow(bool isMuted) {
    return Row(
      children: [
        // ميكروفون
        _ActionBtn(
          icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          color: isMuted ? AppColors.error : AppColors.primary,
          onTap: () async {
            final newMuted = !isMuted;
            ref.read(isMicMutedProvider.notifier).state = newMuted;
            await ZegoService().setMicMuted(newMuted);
          },
          filled: true,
        ),
        const SizedBox(width: 8),
        // الدردشة
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _showInput = true),
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.centerRight,
              child: const Text(
                'اكتب رسالة...',
                style: TextStyle(color: AppColors.textHint, fontSize: 13, fontFamily: 'Cairo'),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // هدايا
        _ActionBtn(icon: Icons.card_giftcard_rounded, color: AppColors.accent, onTap: widget.onGift),
        const SizedBox(width: 8),
        // مؤثرات الإيموجي
        if (widget.onSoundEffects != null) ...[
          _ActionBtn(icon: Icons.emoji_emotions_rounded, color: const Color(0xFFFFB800), onTap: widget.onSoundEffects!),
          const SizedBox(width: 8),
        ],
        // تأثيرات الصوت
        _ActionBtn(
          icon: Icons.spatial_audio_rounded,
          color: AppColors.accent,
          onTap: () => showModalBottomSheet(
            context: context,
            backgroundColor: AppColors.surface,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            builder: (_) => const VoiceEffectsSheet(),
          ),
        ),
        if (widget.isHost) ...[
          const SizedBox(width: 8),
          _ActionBtn(icon: Icons.settings_rounded, color: AppColors.textSecondary, onTap: widget.onSettings),
        ],
      ],
    );
  }

  Widget _inputRow() {
    return Row(
      children: [
        IconButton(
          onPressed: () => setState(() => _showInput = false),
          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _textCtrl,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontSize: 14),
            decoration: InputDecoration(
              hintText: 'اكتب رسالتك...',
              hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
              filled: true,
              fillColor: Colors.white.withAlpha(20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _send,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.primaryGradient),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.color, required this.onTap, this.filled = false});

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color.withAlpha(40) : Colors.white.withAlpha(20),
          border: filled ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Icon(icon, color: filled ? color : Colors.white, size: 20),
      ),
    );
  }
}
