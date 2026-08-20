import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/room_model.dart';
import '../providers/home_provider.dart';

void showEditRoomSheet(BuildContext context, RoomModel room) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditRoomSheet(room: room),
  );
}

void showCreateRoomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CreateRoomSheet(),
  );
}

class CreateRoomSheet extends ConsumerStatefulWidget {
  const CreateRoomSheet({super.key});

  @override
  ConsumerState<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends ConsumerState<CreateRoomSheet> {
  final _nameController = TextEditingController();
  RoomType _selectedType = RoomType.chat;
  bool _isLocked = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final room = RoomModel(
        roomId: '',
        name: _nameController.text.trim(),
        type: _selectedType,
        hostUid: user.uid,
        hostName: user.displayName ?? 'مضيف',
        hostAvatar: user.photoURL,
        isLocked: _isLocked,
        createdAt: DateTime.now(),
      );
      await ref.read(roomRepositoryProvider).createRoom(room);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل إنشاء الغرفة'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // مقبض السحب
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('إنشاء غرفة جديدة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Cairo')),
          const SizedBox(height: 20),

          // اسم الغرفة
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
            decoration: const InputDecoration(
              hintText: 'اسم الغرفة',
              prefixIcon: Icon(Icons.meeting_room_rounded, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),

          // نوع الغرفة
          const Text('نوع الغرفة', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Cairo')),
          const SizedBox(height: 8),
          Row(
            children: RoomType.values.map((type) {
              final labels = {RoomType.chat: 'دردشة', RoomType.music: 'موسيقى', RoomType.game: 'ألعاب', RoomType.dating: 'تعارف'};
              final icons = {RoomType.chat: Icons.chat_bubble_rounded, RoomType.music: Icons.music_note_rounded,
                             RoomType.game: Icons.sports_esports_rounded, RoomType.dating: Icons.favorite_rounded};
              final isSelected = _selectedType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withAlpha(40) : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        Icon(icons[type], size: 20, color: isSelected ? AppColors.primary : AppColors.textHint),
                        const SizedBox(height: 4),
                        Text(labels[type]!, style: TextStyle(
                          fontSize: 10, fontFamily: 'Cairo',
                          color: isSelected ? AppColors.primary : AppColors.textHint,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                        )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // قفل الغرفة
          Row(
            children: [
              const Icon(Icons.lock_rounded, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              const Text('غرفة مقفلة', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
              const Spacer(),
              Switch(value: _isLocked, onChanged: (v) => setState(() => _isLocked = v), activeThumbColor: AppColors.primary, activeTrackColor: AppColors.primary.withAlpha(120)),
            ],
          ),
          const SizedBox(height: 20),

          // زر الإنشاء
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('إنشاء الغرفة 🎉', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── تعديل غرفة موجودة ─────────────────────────────────────────────────
class EditRoomSheet extends ConsumerStatefulWidget {
  const EditRoomSheet({super.key, required this.room});
  final RoomModel room;

  @override
  ConsumerState<EditRoomSheet> createState() => _EditRoomSheetState();
}

class _EditRoomSheetState extends ConsumerState<EditRoomSheet> {
  late final TextEditingController _nameCtrl;
  late RoomType _selectedType;
  late bool _isLocked;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.room.name);
    _selectedType = widget.room.type;
    _isLocked = widget.room.isLocked;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(roomRepositoryProvider).updateRoom(
        widget.room.roomId,
        name: _nameCtrl.text.trim(),
        type: _selectedType,
        isLocked: _isLocked,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فشل حفظ التعديلات'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('تعديل الغرفة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontFamily: 'Cairo')),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
            decoration: const InputDecoration(
              hintText: 'اسم الغرفة',
              prefixIcon: Icon(Icons.meeting_room_rounded, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          const Text('نوع الغرفة', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontFamily: 'Cairo')),
          const SizedBox(height: 8),
          Row(
            children: RoomType.values.map((type) {
              final labels = {RoomType.chat: 'دردشة', RoomType.music: 'موسيقى', RoomType.game: 'ألعاب', RoomType.dating: 'تعارف'};
              final icons = {RoomType.chat: Icons.chat_bubble_rounded, RoomType.music: Icons.music_note_rounded,
                             RoomType.game: Icons.sports_esports_rounded, RoomType.dating: Icons.favorite_rounded};
              final isSelected = _selectedType == type;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary.withAlpha(40) : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        Icon(icons[type], size: 20, color: isSelected ? AppColors.primary : AppColors.textHint),
                        const SizedBox(height: 4),
                        Text(labels[type]!, style: TextStyle(
                          fontSize: 10, fontFamily: 'Cairo',
                          color: isSelected ? AppColors.primary : AppColors.textHint,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                        )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.lock_rounded, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              const Text('غرفة مقفلة', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo')),
              const Spacer(),
              Switch(
                value: _isLocked,
                onChanged: (v) => setState(() => _isLocked = v),
                activeThumbColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withAlpha(120),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('حفظ التعديلات ✅', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Cairo')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
