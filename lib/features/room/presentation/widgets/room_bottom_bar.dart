import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

const _kTextColors = [
  ('ذهبي',    Color(0xFFFFD700)),
  ('أبيض',    Color(0xFFFFFFFF)),
  ('سماوي',   Color(0xFF4CF0FF)),
  ('وردي',    Color(0xFFFF4D6D)),
  ('أخضر',    Color(0xFF2ECC71)),
  ('برتقالي', Color(0xFFFF9500)),
  ('بنفسجي',  Color(0xFFBF5FFF)),
];

const _kEffects = [
  ('👏', 'تصفيق'), ('😂', 'ضحك'),    ('🎉', 'احتفال'), ('🔥', 'نار'),
  ('❤️', 'قلب'),  ('👍', 'رائع'),    ('😮', 'مفاجأة'), ('😢', 'حزن'),
  ('💯', 'مئة'),  ('🎵', 'موسيقى'), ('⚡', 'برق'),     ('🌹', 'وردة'),
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

  void _showCombinedEffects() {
    final me = FirebaseAuth.instance.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CombinedSheet(
        roomId: widget.roomId,
        displayName: me?.displayName ?? 'مستخدم',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMuted      = ref.watch(isMicMutedProvider);
    final chatMuteKey  = '${widget.roomId}::${widget.currentUserId}';
    final isChatMuted  = ref.watch(chatMutedProvider(chatMuteKey)).valueOrNull == true;

    return SafeArea(
      top: false,
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.fromLTRB(12, 6, 12, MediaQuery.of(context).viewInsets.bottom + 6),
        child: _showInput ? _inputRow(isChatMuted) : _actionRow(isMuted, isChatMuted),
      ),
    );
  }

  Widget _actionRow(bool isMuted, bool isChatMuted) {
    final isOnSeat     = ref.watch(myCurrentSeatProvider) >= 0;
    final isAudioMuted = ref.watch(isRoomAudioMutedProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── ميكروفون ─────────────────────────────────────────────────
        Opacity(
          opacity: isOnSeat ? 1.0 : 0.4,
          child: _ActionBtn(
            icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            color: isMuted ? AppColors.error : AppColors.primary,
            onTap: () async {
              if (!isOnSeat) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('صعّد على مقعد لاستخدام الميكروفون',
                      style: TextStyle(fontFamily: 'Cairo')),
                  duration: Duration(seconds: 2),
                ));
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
        // ── سماعة ─────────────────────────────────────────────────────
        _ActionBtn(
          icon: isAudioMuted ? Icons.volume_off_rounded : Icons.headphones_rounded,
          color: isAudioMuted ? AppColors.error : AppColors.textSecondary,
          onTap: () async {
            final newMuted = !isAudioMuted;
            ref.read(isRoomAudioMutedProvider.notifier).state = newMuted;
            await ZegoService().muteAllAudio(newMuted);
          },
          filled: isAudioMuted,
        ),
        const SizedBox(width: 8),
        // ── حقل الدردشة ───────────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (isChatMuted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('تم تقييدك من الكتابة في هذه الغرفة',
                      style: TextStyle(fontFamily: 'Cairo')),
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
                color: isChatMuted
                    ? Colors.red.withAlpha(20)
                    : Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: isChatMuted
                    ? Border.all(color: Colors.red.withAlpha(80))
                    : null,
              ),
              alignment: Alignment.centerRight,
              child: Text(
                isChatMuted ? '🚫 مقيّد من الكتابة' : 'اكتب رسالة...',
                style: TextStyle(
                  color: isChatMuted
                      ? Colors.red.shade300
                      : AppColors.textHint,
                  fontSize: 13,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // ── إيموجي + تأثيرات صوت (مدمجان) ───────────────────────────
        _ActionBtn(
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFFFFB800),
          onTap: _showCombinedEffects,
        ),
        const SizedBox(width: 6),
        // ── صندوق الهدايا — مربع صغير في الزاوية اليمنى ─────────────
        _AnimatedGiftBox(onTap: widget.onGift),
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

// ═══════════════════════════════════════════════════════════════════════
//  شيت التأثيرات المدمج (إيموجي + تأثيرات صوت)
// ═══════════════════════════════════════════════════════════════════════
class _CombinedSheet extends ConsumerStatefulWidget {
  const _CombinedSheet({required this.roomId, required this.displayName});
  final String roomId;
  final String displayName;

  @override
  ConsumerState<_CombinedSheet> createState() => _CombinedSheetState();
}

class _CombinedSheetState extends ConsumerState<_CombinedSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(icon: Icon(Icons.emoji_emotions_rounded, size: 20), text: 'إيموجي'),
            Tab(icon: Icon(Icons.spatial_audio_rounded, size: 20), text: 'صوت'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        ),
        SizedBox(
          height: 300,
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              // ── تفاعلات إيموجي ──────────────────────────────────────
              GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: _kEffects.length,
                itemBuilder: (ctx, i) {
                  final (emoji, label) = _kEffects[i];
                  return GestureDetector(
                    onTap: () async {
                      await ref.read(chatWriterProvider(widget.roomId))
                          .sendSystem('$emoji ${widget.displayName} أرسل $label');
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(emoji, style: const TextStyle(fontSize: 26)),
                          const SizedBox(height: 4),
                          Text(label, style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontFamily: 'Cairo',
                          )),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // ── تأثيرات الصوت ────────────────────────────────────────
              const SingleChildScrollView(child: VoiceEffectsSheet()),
            ],
          ),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  صندوق الهدايا المتحرك 100×100
// ═══════════════════════════════════════════════════════════════════════
class _AnimatedGiftBox extends StatefulWidget {
  const _AnimatedGiftBox({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_AnimatedGiftBox> createState() => _AnimatedGiftBoxState();
}

class _AnimatedGiftBoxState extends State<_AnimatedGiftBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bellCtrl;
  late final Animation<double> _bellAnim;

  @override
  void initState() {
    super.initState();
    _bellCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    // حركة الجرس: تأرجح خفيف حول المحور العلوي ثم وقفة
    _bellAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0,   end:  0.10), weight: 1),
      TweenSequenceItem(tween: Tween(begin:  0.10, end: -0.10), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.10, end:  0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin:  0.08, end: -0.05), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.05, end:  0.0),  weight: 1),
      TweenSequenceItem(tween: ConstantTween(0.0),               weight: 5),
    ]).animate(_bellCtrl);
  }

  @override
  void dispose() {
    _bellCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bellAnim,
      builder: (_, __) => Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.rotationZ(_bellAnim.value),
        child: GestureDetector(
          onTap: widget.onTap,
          child: const Text('🎁', style: TextStyle(fontSize: 40)),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  زر الإجراء العام (دائري)
// ═══════════════════════════════════════════════════════════════════════
class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

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
