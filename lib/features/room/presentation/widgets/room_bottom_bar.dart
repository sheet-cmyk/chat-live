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
    this.isAdmin = false,
    required this.roomId,
    required this.currentUserId,
    this.onSoundEffects,
  });

  final void Function(String text, String? textColor) onSendMessage;
  final VoidCallback onGift;
  final VoidCallback onSettings;
  final bool isHost;
  final bool isAdmin;
  final String roomId;
  final String currentUserId;
  final VoidCallback? onSoundEffects;

  @override
  ConsumerState<RoomBottomBar> createState() => _RoomBottomBarState();
}

// ألوان اختيار نص التعليق
const _kTextColors = [
  ('ذهبي',  Color(0xFFFFD700)),
  ('أبيض',  Color(0xFFFFFFFF)),
  ('سماوي', Color(0xFF4CF0FF)),
  ('وردي',  Color(0xFFFF4D6D)),
  ('أخضر',  Color(0xFF2ECC71)),
  ('برتقالي', Color(0xFFFF9500)),
  ('بنفسجي', Color(0xFFBF5FFF)),
];

class _RoomBottomBarState extends ConsumerState<RoomBottomBar> {
  final _textCtrl = TextEditingController();
  bool _showInput = false;
  Color _selectedTextColor = const Color(0xFFFFD700);

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  String _colorHex(Color c) {
    final r = (c.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (c.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (c.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage(text, _colorHex(_selectedTextColor));
    _textCtrl.clear();
    setState(() => _showInput = false);
  }

  @override
  Widget build(BuildContext context) {
    final isMuted = ref.watch(isMicMutedProvider);
    final chatMuteKey = '${widget.roomId}::${widget.currentUserId}';
    final isChatMuted = ref.watch(chatMutedProvider(chatMuteKey)).valueOrNull == true;

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.black.withAlpha(160),
        padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
        child: _showInput ? _inputRow(isChatMuted) : _actionRow(isMuted, isChatMuted),
      ),
    );
  }

  Widget _actionRow(bool isMuted, bool isChatMuted) {
    final isOnSeat       = ref.watch(myCurrentSeatProvider) >= 0;
    final isAudioMuted   = ref.watch(isRoomAudioMutedProvider);
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
        const SizedBox(width: 6),
        // سماعة الغرفة — كتم الصوت الوارد
        _ActionBtn(
          icon: isAudioMuted
              ? Icons.volume_off_rounded
              : Icons.headphones_rounded,
          color: isAudioMuted ? AppColors.error : AppColors.textSecondary,
          onTap: () async {
            final newMuted = !isAudioMuted;
            ref.read(isRoomAudioMutedProvider.notifier).state = newMuted;
            await ZegoService().muteAllAudio(newMuted);
          },
          filled: isAudioMuted,
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
        _ActionBtn(icon: Icons.redeem_rounded, color: const Color(0xFFFFD700), onTap: widget.onGift),
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
        if (widget.isHost || widget.isAdmin) ...[
          const SizedBox(width: 8),
          _ActionBtn(icon: Icons.settings_rounded, color: AppColors.textSecondary, onTap: widget.onSettings),
        ],
      ],
    );
  }

  Widget _inputRow(bool isChatMuted) {
    if (isChatMuted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _showInput = false);
      });
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // شريط اختيار لون النص
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _kTextColors.map((entry) {
              final (label, color) = entry;
              final isSel = _selectedTextColor == color;
              return GestureDetector(
                onTap: () => setState(() => _selectedTextColor = color),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha(isSel ? 60 : 25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? color : color.withAlpha(60),
                      width: isSel ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(label, style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontFamily: 'Cairo',
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.normal,
                      )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        // صف الإدخال
        Row(
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
                style: TextStyle(
                  color: _selectedTextColor,
                  fontFamily: 'Cairo',
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك...',
                  hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF00C853).withAlpha(25),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: const Color(0xFF00C853).withAlpha(60), width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: const Color(0xFF00C853).withAlpha(60), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: const Color(0xFF00C853).withAlpha(130), width: 1.5),
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
