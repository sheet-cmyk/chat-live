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
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة الغرفة
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    room.coverImage != null
                        ? CachedNetworkImage(
                            imageUrl: room.coverImage!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => _placeholder(),
                            errorWidget: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                    if (isOwner)
                      Positioned(
                        top: 6, right: 6,
                        child: GestureDetector(
                          onTap: () => showEditRoomSheet(context, room),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(140),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم الغرفة + نوعها
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                      _TypeBadge(room.typeLabel),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // المضيف + عدد المتصلين
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.surfaceLight,
                        backgroundImage: room.hostAvatar != null
                            ? CachedNetworkImageProvider(room.hostAvatar!)
                            : null,
                        child: room.hostAvatar == null
                            ? const Icon(Icons.person, size: 12, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          room.hostName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.people_rounded, size: 11, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Text(
                              '${room.onlineCount}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (room.isLocked) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.lock_rounded, size: 12, color: AppColors.textHint),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return ClipRRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // dark purple/black gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D0018), Color(0xFF1A0033), Color(0xFF2D0060)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // decorative pattern painter
          const Positioned.fill(child: _PlaceholderPainterWidget()),
          // centered mic icon with glow
          Center(
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF7C3AED).withAlpha(140), blurRadius: 16, spreadRadius: 2),
                  BoxShadow(color: const Color(0xFFEC4899).withAlpha(80), blurRadius: 8),
                ],
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Decorative placeholder painter ────────────────────────────────────
class _PlaceholderPainterWidget extends StatelessWidget {
  const _PlaceholderPainterWidget();
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PlaceholderPainter());
}

class _PlaceholderPainter extends CustomPainter {
  static const _google = [
    Color(0xFF4285F4), // blue
    Color(0xFFEA4335), // red
    Color(0xFFFBBC05), // yellow
    Color(0xFF34A853), // green
    Color(0xFFEC4899), // pink
    Color(0xFF7C3AED), // purple
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    void dot(double x, double y, double r, int ci, {double a = 0.55}) {
      canvas.drawCircle(
        Offset(x, y), r,
        Paint()..color = _google[ci % 6].withAlpha((a * 255).round()),
      );
    }

    void ring(double x, double y, double r, int ci, {double a = 0.30, double sw = 1.5}) {
      canvas.drawCircle(
        Offset(x, y), r,
        Paint()
          ..color = _google[ci % 6].withAlpha((a * 255).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw,
      );
    }

    // Corner accents
    dot(-4, -4, 14, 0, a: 0.40);
    dot(w + 4, -4, 12, 1, a: 0.40);
    dot(-4, h + 4, 11, 2, a: 0.40);
    dot(w + 4, h + 4, 13, 3, a: 0.40);

    // Rings
    ring(w * 0.15, h * 0.25, 10, 0, a: 0.35, sw: 1.5);
    ring(w * 0.82, h * 0.70, 12, 1, a: 0.35, sw: 1.5);
    ring(w * 0.70, h * 0.18, 8, 3, a: 0.35, sw: 1.2);

    // Small dots scattered
    final pts = [
      [0.08, 0.60], [0.88, 0.30], [0.22, 0.85],
      [0.75, 0.88], [0.92, 0.55], [0.12, 0.12],
      [0.55, 0.08], [0.45, 0.92],
    ];
    for (int i = 0; i < pts.length; i++) {
      dot(w * pts[i][0], h * pts[i][1], 3 + (i % 2), i, a: 0.50);
    }

    // Geometric star dots (8-point arrangement around center)
    final cx = w / 2;
    final cy = h / 2;
    for (int i = 0; i < 8; i++) {
      final a = -pi / 2 + i * pi / 4;
      const dist = 26.0;
      dot(cx + dist * cos(a), cy + dist * sin(a), 2.5, i, a: 0.30);
    }

    // Purple glow behind mic
    canvas.drawCircle(
      Offset(cx, cy), 28,
      Paint()
        ..color = const Color(0xFF7C3AED).withAlpha(35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );

    // Subtle grid lines (very faint)
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(10)
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

// ── Type badge ─────────────────────────────────────────────────────────
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

  Color get _bg {
    switch (label) {
      case 'دردشة':  return const Color(0xFFFFEBEA);
      case 'موسيقى': return const Color(0xFFFFF8E1);
      case 'ألعاب':  return const Color(0xFFE8F5E9);
      case 'تعارف':  return const Color(0xFFFCE4EC);
      default:        return const Color(0xFFEDE9FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
}
