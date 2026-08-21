import 'dart:math' show pi, cos, sin;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/routes.dart';
import '../../data/models/room_model.dart';
import '../screens/create_room_sheet.dart';

class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.room, this.onTap, this.isOwner = false});

  final RoomModel room;
  final VoidCallback? onTap;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => context.push(AppRoutes.room, extra: room),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── صورة الغرفة تملأ البطاقة كاملاً ────────────────────
            room.coverImage != null
                ? CachedNetworkImage(
                    imageUrl: room.coverImage!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _Placeholder(),
                    errorWidget: (_, __, ___) => _Placeholder(),
                  )
                : _Placeholder(),

            // ── تدرج داكن أعلى (لقراءة الشارة) ──────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xCC000000), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.40],
                ),
              ),
            ),

            // ── تدرج داكن أسفل (لقراءة الاسم) ───────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Color(0xEE000000)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.45, 1.0],
                ),
              ),
            ),

            // ── عداد المستخدمين المباشرين (أعلى اليسار، واضح) ────
            Positioned(
              top: 10,
              left: 10,
              child: _LiveCountBadge(count: room.onlineCount),
            ),

            // ── زر تعديل الغرفة (أعلى اليمين — للمالك فقط) ─────
            if (isOwner)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => showEditRoomSheet(context, room),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(160),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ),

            // ── قفل (إن كانت الغرفة مقفلة) ──────────────────────
            if (room.isLocked)
              Positioned(
                top: 10,
                right: isOwner ? 42 : 10,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(140),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, size: 12, color: Colors.white70),
                ),
              ),

            // ── معلومات الغرفة أسفل البطاقة ─────────────────────
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // نوع الغرفة
                    _TypeBadge(room.typeLabel),
                    const SizedBox(height: 4),

                    // اسم الغرفة — كبير وواضح
                    Text(
                      room.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        fontFamily: 'Cairo',
                        height: 1.2,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 6),
                          Shadow(color: Colors.black54, blurRadius: 12),
                        ],
                      ),
                    ),

                    const SizedBox(height: 5),

                    // المضيف
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 9,
                          backgroundColor: AppColors.primary,
                          backgroundImage: room.hostAvatar != null
                              ? CachedNetworkImageProvider(room.hostAvatar!)
                              : null,
                          child: room.hostAvatar == null
                              ? const Icon(Icons.person, size: 10, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            room.hostName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _LiveCountBadge — عداد المستخدمين المباشرين (واضح وكبير)
// ═══════════════════════════════════════════════════════════════════════════

class _LiveCountBadge extends StatelessWidget {
  const _LiveCountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(170),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // نقطة حمراء متوهجة — مباشر
          Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.red, blurRadius: 4, spreadRadius: 1),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
              height: 1,
            ),
          ),
          const SizedBox(width: 3),
          const Text(
            'مباشر',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 9,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _Placeholder — خلفية تصميمية عند غياب الصورة
// ═══════════════════════════════════════════════════════════════════════════

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D0018), Color(0xFF1A0033), Color(0xFF2D0060)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        const Positioned.fill(child: _PlaceholderPainterWidget()),
        Center(
          child: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: const Color(0xFF7C3AED).withAlpha(140), blurRadius: 18, spreadRadius: 2),
              ],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
          ),
        ),
      ],
    );
  }
}

// ── Decorative placeholder painter ────────────────────────────────────────

class _PlaceholderPainterWidget extends StatelessWidget {
  const _PlaceholderPainterWidget();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PlaceholderPainter());
}

class _PlaceholderPainter extends CustomPainter {
  static const _google = [
    Color(0xFF4285F4),
    Color(0xFFEA4335),
    Color(0xFFFBBC05),
    Color(0xFF34A853),
    Color(0xFFEC4899),
    Color(0xFF7C3AED),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void dot(double x, double y, double r, int ci, {double a = 0.55}) {
      canvas.drawCircle(Offset(x, y), r,
          Paint()..color = _google[ci % 6].withAlpha((a * 255).round()));
    }

    void ring(double x, double y, double r, int ci, {double a = 0.30, double sw = 1.5}) {
      canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..color = _google[ci % 6].withAlpha((a * 255).round())
            ..style = PaintingStyle.stroke
            ..strokeWidth = sw);
    }

    dot(-4, -4, 14, 0, a: 0.35);
    dot(w + 4, -4, 12, 1, a: 0.35);
    dot(-4, h + 4, 11, 2, a: 0.35);
    dot(w + 4, h + 4, 13, 3, a: 0.35);
    ring(w * 0.15, h * 0.25, 10, 0);
    ring(w * 0.82, h * 0.70, 12, 1);
    ring(w * 0.70, h * 0.18, 8, 3);

    final pts = [
      [0.08, 0.60], [0.88, 0.30], [0.22, 0.85],
      [0.75, 0.88], [0.92, 0.55], [0.12, 0.12],
    ];
    for (int i = 0; i < pts.length; i++) {
      dot(w * pts[i][0], h * pts[i][1], 3 + (i % 2), i, a: 0.45);
    }

    final cx = w / 2;
    final cy = h / 2;
    for (int i = 0; i < 8; i++) {
      final a = -pi / 2 + i * pi / 4;
      const dist = 30.0;
      dot(cx + dist * cos(a), cy + dist * sin(a), 2.5, i, a: 0.25);
    }

    canvas.drawCircle(
      Offset(cx, cy), 32,
      Paint()
        ..color = const Color(0xFF7C3AED).withAlpha(30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(8)
      ..strokeWidth = 0.5;
    for (double x = 0; x < w; x += w / 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y < h; y += h / 4) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
//  _TypeBadge — شارة نوع الغرفة
// ═══════════════════════════════════════════════════════════════════════════

class _TypeBadge extends StatelessWidget {
  const _TypeBadge(this.label);
  final String label;

  Color get _color {
    switch (label) {
      case 'دردشة':  return AppColors.red;
      case 'موسيقى': return AppColors.yellow;
      case 'ألعاب':  return AppColors.green;
      case 'تعارف':  return AppColors.accent;
      default:        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withAlpha(60),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
}
