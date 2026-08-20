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
    required this.roomId,
    required this.currentUserId,
    this.onSoundEffects,
  });

  final void Function(String) onSendMessage;
  final VoidCallback onGift;
  final VoidCallback onSettings;
  final bool isHost;
  final String roomId;
  final String currentUserId;
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
    final chatMuteKey = '${widget.roomId}::${widget.currentUserId}';
    final isChatMuted = ref.watch(chatMutedProvider(chatMuteKey)).valueOrNull == true;

    return Container(
      color: Colors.black.withAlpha(160),
      padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
      child: _showInput ? _inputRow(isChatMuted) : _actionRow(isMuted, isChatMuted),
    );
  }

  Widget _actionRow(bool isMuted, bool isChatMuted) {
    final isOnSeat = ref.watch(myCurrentSeatProvider) >= 0;
    return Row(
      children: [
        // ميكروفون — يعمل فقط عند الجلوس على مقعد
        Opacity(
          opacity: isOnSeat ? 1.0 : 0.4,
          child: _ActionBtn(
            icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            color: isMuted ? AppColors.error : AppColors.primary,
            onTap: () async {
              if (!isOnSeat) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('صعّد على مقعد لاستخدام الميكروفون',
                        style: TextStyle(fontFamily: 'Cairo')),
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              final newMuted = !isMuted;
              ref.read(isMicMutedProvider.notifier).state = newMuted;
              await ZegoService().setMicMuted(newMuted);
            },
            filled: true,
          ),
        ),
        const SizedBox(width: 8),
        // الدردشة
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (isChatMuted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('تم تقييدك من الكتابة في هذه الغرفة', style: TextStyle(fontFamily: 'Cairo')),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ));
                return;
              }
              setState(() => _showInput = true);
            },
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isChatMuted ? Colors.red.withAlpha(20) : Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: isChatMuted ? Border.all(color: Colors.red.withAlpha(80)) : null,
              ),
              alignment: Alignment.centerRight,
              child: Text(
                isChatMuted ? '🚫 مقيّد من الكتابة' : 'اكتب رسالة...',
                style: TextStyle(color: isChatMuted ? Colors.red.shade300 : AppColors.textHint, fontSize: 13, fontFamily: 'Cairo'),
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

  Widget _inputRow(bool isChatMuted) {
    if (isChatMuted) {
      // Double safety: close input if user got muted while typing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showInput = false);
      });
    }
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
