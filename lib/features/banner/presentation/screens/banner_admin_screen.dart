import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/banner_model.dart';
import '../../data/repositories/banner_repository.dart';
import '../providers/banner_provider.dart';

class BannerAdminScreen extends ConsumerWidget {
  const BannerAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bannersAsync = ref.watch(allBannersAdminProvider);

    return bannersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.amber)),
      error: (e, _) => Center(child: Text('خطأ: $e', style: const TextStyle(color: Colors.red, fontFamily: 'Cairo'))),
      data: (banners) => _BannerList(banners: banners),
    );
  }
}

// ── Reorderable banner list ────────────────────────────────────────────────

class _BannerList extends StatelessWidget {
  const _BannerList({required this.banners});
  final List<BannerModel> banners;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        banners.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_rounded, size: 56, color: Colors.white24),
                    SizedBox(height: 12),
                    Text('لا توجد بنرات بعد', style: TextStyle(color: Colors.white38, fontFamily: 'Cairo', fontSize: 15)),
                    SizedBox(height: 6),
                    Text('اضغط + لإضافة أول بنر', style: TextStyle(color: Colors.white24, fontFamily: 'Cairo', fontSize: 13)),
                  ],
                ),
              )
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                itemCount: banners.length,
                onReorderItem: (oldIdx, newIdx) {
                  final reordered = List<BannerModel>.from(banners);
                  reordered.insert(newIdx, reordered.removeAt(oldIdx));
                  BannerRepository().reorderBanners(reordered.map((b) => b.id).toList());
                },
                itemBuilder: (ctx, i) {
                  final b = banners[i];
                  return _BannerTile(key: ValueKey(b.id), banner: b);
                },
              ),

        // FAB – add new banner
        Positioned(
          bottom: 24,
          left: 24,
          child: FloatingActionButton.extended(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            icon: const Icon(Icons.add_rounded),
            label: const Text('إضافة بنر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            onPressed: () => _showEditSheet(context, null),
          ),
        ),
      ],
    );
  }
}

// ── Single banner tile ─────────────────────────────────────────────────────

class _BannerTile extends StatelessWidget {
  const _BannerTile({super.key, required this.banner});
  final BannerModel banner;

  @override
  Widget build(BuildContext context) {
    final isYoutube = banner.type == 'youtube';

    return Card(
      color: const Color(0xFF1A0A2E),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: banner.isActive ? Colors.amber.withAlpha(80) : Colors.white12,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: _TilePreview(banner: banner),
        title: Text(
          isYoutube
              ? 'يوتيوب · ${banner.youtubeVideoId ?? ''}'
              : 'صورة',
          style: TextStyle(
            color: isYoutube ? Colors.redAccent : Colors.lightBlueAccent,
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            const Icon(Icons.timer_rounded, color: Colors.white38, size: 13),
            Text(
              ' ${banner.durationSeconds}ث',
              style: const TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 11),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: banner.isActive ? Colors.green.withAlpha(40) : Colors.grey.withAlpha(40),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: banner.isActive ? Colors.green : Colors.grey),
              ),
              child: Text(
                banner.isActive ? 'نشط' : 'مخفي',
                style: TextStyle(
                  color: banner.isActive ? Colors.green : Colors.grey,
                  fontSize: 10,
                  fontFamily: 'Cairo',
                ),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle (reorder)
            const Icon(Icons.drag_handle_rounded, color: Colors.white38, size: 22),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
              color: const Color(0xFF1A0A2E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (action) => _handleAction(context, action),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_rounded, color: Colors.amber, size: 18),
                    SizedBox(width: 8),
                    Text('تعديل', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
                  ]),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(
                      banner.isActive ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      color: banner.isActive ? Colors.orange : Colors.green,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      banner.isActive ? 'إخفاء' : 'تفعيل',
                      style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
                    ),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('حذف', style: TextStyle(color: Colors.red, fontFamily: 'Cairo')),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action) async {
    final repo = BannerRepository();
    switch (action) {
      case 'edit':
        _showEditSheet(context, banner);
      case 'toggle':
        await repo.toggleActive(banner.id, !banner.isActive);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              banner.isActive ? '🙈 تم إخفاء البنر' : '✅ تم تفعيل البنر',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: banner.isActive ? Colors.orange : Colors.green,
          ));
        }
      case 'delete':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF1A0A2E),
            title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
            content: const Text('هل تريد حذف هذا البنر نهائياً؟', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo'))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          await repo.deleteBanner(banner.id, imageUrl: banner.imageUrl);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ تم حذف البنر', style: TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.green,
            ));
          }
        }
    }
  }
}

// ── Small preview thumbnail ────────────────────────────────────────────────

class _TilePreview extends StatelessWidget {
  const _TilePreview({required this.banner});
  final BannerModel banner;

  @override
  Widget build(BuildContext context) {
    final isYoutube = banner.type == 'youtube';
    final hasImage = !isYoutube && (banner.imageUrl?.isNotEmpty ?? false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 40,
        child: isYoutube
            ? Container(
                color: Colors.red.withAlpha(30),
                child: const Icon(Icons.play_circle_fill_rounded, color: Colors.red, size: 28),
              )
            : hasImage
                ? Image.network(banner.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imgPlaceholder())
                : _imgPlaceholder(),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        color: const Color(0xFF2A1A4E),
        child: const Icon(Icons.image_rounded, color: Colors.white24, size: 22),
      );
}

// ── Add / Edit sheet ───────────────────────────────────────────────────────

void _showEditSheet(BuildContext context, BannerModel? existing) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1A0A2E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _BannerEditSheet(existing: existing),
  );
}

class _BannerEditSheet extends StatefulWidget {
  const _BannerEditSheet({this.existing});
  final BannerModel? existing;

  @override
  State<_BannerEditSheet> createState() => _BannerEditSheetState();
}

class _BannerEditSheetState extends State<_BannerEditSheet> {
  late String _type;
  final _ytUrlCtrl = TextEditingController();
  String? _extractedVideoId;
  String? _pickedImageUrl; // after upload
  File? _pickedFile;
  late int _duration;
  late bool _isActive;
  bool _uploading = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? 'image';
    _ytUrlCtrl.text = e?.youtubeUrl ?? '';
    _extractedVideoId = e?.youtubeVideoId;
    _pickedImageUrl = e?.imageUrl;
    _duration = e?.durationSeconds ?? 10;
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _ytUrlCtrl.dispose();
    super.dispose();
  }

  void _onYtUrlChanged(String url) {
    final id = BannerRepository.extractVideoId(url);
    setState(() => _extractedVideoId = id);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() { _pickedFile = File(picked.path); _uploading = true; _error = null; });
    try {
      final url = await BannerRepository().uploadBannerImage(_pickedFile!);
      setState(() { _pickedImageUrl = url; _uploading = false; });
    } catch (e) {
      setState(() { _uploading = false; _error = 'فشل رفع الصورة: $e'; });
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      if (_type == 'image' && (_pickedImageUrl == null || _pickedImageUrl!.isEmpty)) {
        setState(() { _error = 'الرجاء اختيار صورة أولاً'; _saving = false; });
        return;
      }
      if (_type == 'youtube' && (_extractedVideoId == null || _extractedVideoId!.isEmpty)) {
        setState(() { _error = 'رابط يوتيوب غير صحيح أو معرف الفيديو غير موجود'; _saving = false; });
        return;
      }

      final repo = BannerRepository();
      final existing = widget.existing;

      if (existing == null) {
        // New banner – order = current count + 1 (Firestore will receive it)
        final banner = BannerModel(
          id: '',
          type: _type,
          imageUrl: _type == 'image' ? _pickedImageUrl : null,
          youtubeUrl: _type == 'youtube' ? _ytUrlCtrl.text.trim() : null,
          youtubeVideoId: _type == 'youtube' ? _extractedVideoId : null,
          durationSeconds: _duration,
          order: 9999,
          isActive: _isActive,
        );
        await repo.createBanner(banner);
      } else {
        final updated = existing.copyWith(
          type: _type,
          imageUrl: _type == 'image' ? _pickedImageUrl : null,
          youtubeUrl: _type == 'youtube' ? _ytUrlCtrl.text.trim() : null,
          youtubeVideoId: _type == 'youtube' ? _extractedVideoId : null,
          durationSeconds: _duration,
          isActive: _isActive,
        );
        await repo.updateBanner(updated);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = 'خطأ: $e'; _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16, left: 20, right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),

            // Title
            Text(
              widget.existing == null ? '➕ إضافة بنر جديد' : '✏️ تعديل البنر',
              style: const TextStyle(color: Colors.amber, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),

            // Type selector
            const Text('نوع البنر', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 12)),
            const SizedBox(height: 6),
            Row(
              children: [
                _TypeBtn(label: '🖼️ صورة', selected: _type == 'image', onTap: () => setState(() => _type = 'image')),
                const SizedBox(width: 10),
                _TypeBtn(label: '▶️ يوتيوب', selected: _type == 'youtube', onTap: () => setState(() => _type = 'youtube')),
              ],
            ),
            const SizedBox(height: 20),

            // Image section
            if (_type == 'image') ...[
              const Text('الصورة', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 12)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _uploading ? null : _pickImage,
                child: Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: _uploading
                      ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                      : _pickedImageUrl != null && _pickedImageUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.network(_pickedImageUrl!, fit: BoxFit.cover, width: double.infinity),
                            )
                          : _pickedFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.file(_pickedFile!, fit: BoxFit.cover, width: double.infinity),
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_rounded, color: Colors.white38, size: 36),
                                    SizedBox(height: 6),
                                    Text('اضغط لاختيار صورة', style: TextStyle(color: Colors.white38, fontFamily: 'Cairo', fontSize: 12)),
                                  ],
                                ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // YouTube section
            if (_type == 'youtube') ...[
              const Text('رابط يوتيوب', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: _ytUrlCtrl,
                style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'https://youtu.be/...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.link_rounded, color: Colors.white38),
                  suffixIcon: _ytUrlCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                          onPressed: () { _ytUrlCtrl.clear(); setState(() => _extractedVideoId = null); },
                        )
                      : null,
                ),
                onChanged: _onYtUrlChanged,
              ),
              if (_extractedVideoId != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                    const SizedBox(width: 6),
                    Text('معرف الفيديو: $_extractedVideoId', style: const TextStyle(color: Colors.green, fontFamily: 'Cairo', fontSize: 12)),
                  ],
                ),
              ] else if (_ytUrlCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.error_rounded, color: Colors.orange, size: 16),
                    SizedBox(width: 6),
                    Text('لم يُعثر على معرف الفيديو في الرابط', style: TextStyle(color: Colors.orange, fontFamily: 'Cairo', fontSize: 12)),
                  ],
                ),
              ],
              const SizedBox(height: 20),
            ],

            // Duration slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('مدة العرض', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 12)),
                Text('$_duration ثانية', style: const TextStyle(color: Colors.amber, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            Slider(
              value: _duration.toDouble(),
              min: 1,
              max: 120,
              divisions: 119,
              activeColor: Colors.amber,
              inactiveColor: Colors.white12,
              label: '$_duration ث',
              onChanged: (v) => setState(() => _duration = v.round()),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1ث', style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Cairo')),
                  Text('120ث', style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'Cairo')),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Active toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('نشط (مرئي للمستخدمين)', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 13)),
                Switch(
                  value: _isActive,
                  activeThumbColor: Colors.amber,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Error
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red, fontFamily: 'Cairo', fontSize: 12)),
              const SizedBox(height: 8),
            ],

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (_saving || _uploading) ? null : _save,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : Text(
                        widget.existing == null ? 'إضافة البنر' : 'حفظ التعديلات',
                        style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TypeBtn extends StatelessWidget {
  const _TypeBtn({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.amber.withAlpha(40) : Colors.white10,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? Colors.amber : Colors.white24, width: selected ? 2 : 1),
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: selected ? Colors.amber : Colors.white54,
              fontFamily: 'Cairo', fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            )),
          ),
        ),
      ),
    );
  }
}
