import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class RoomAnnouncementBanner extends StatelessWidget {
  const RoomAnnouncementBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sheet لتعديل الإعلان (للمضيف فقط) ────────────────────────────
class EditAnnouncementSheet extends StatefulWidget {
  const EditAnnouncementSheet({super.key, required this.current, required this.onSave});
  final String current;
  final void Function(String) onSave;

  @override
  State<EditAnnouncementSheet> createState() => _EditAnnouncementSheetState();
}

class _EditAnnouncementSheetState extends State<EditAnnouncementSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          const Text('تعديل الإعلان', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            maxLength: 120,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo'),
            decoration: InputDecoration(
              hintText: 'اكتب إعلان الغرفة...',
              hintStyle: const TextStyle(color: AppColors.textHint, fontFamily: 'Cairo'),
              filled: true,
              fillColor: AppColors.surfaceLight,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              counterStyle: const TextStyle(color: AppColors.textHint),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                widget.onSave(_ctrl.text.trim());
                Navigator.pop(context);
              },
              child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
