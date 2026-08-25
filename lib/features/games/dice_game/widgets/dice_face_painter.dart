import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Legacy CustomPainter — kept for any direct call-sites; DiceWidget now uses SVG.
class DiceFacePainter extends CustomPainter {
  const DiceFacePainter(this.value, {this.dotColor = Colors.black, this.faceColor = Colors.white});

  final int   value;
  final Color dotColor;
  final Color faceColor;

  static const _dots = <int, List<Offset>>{
    1: [Offset(0.5, 0.5)],
    2: [Offset(0.25, 0.25), Offset(0.75, 0.75)],
    3: [Offset(0.25, 0.25), Offset(0.5, 0.5), Offset(0.75, 0.75)],
    4: [Offset(0.25, 0.25), Offset(0.75, 0.25), Offset(0.25, 0.75), Offset(0.75, 0.75)],
    5: [Offset(0.25, 0.25), Offset(0.75, 0.25), Offset(0.5, 0.5), Offset(0.25, 0.75), Offset(0.75, 0.75)],
    6: [Offset(0.25, 0.22), Offset(0.75, 0.22), Offset(0.25, 0.5), Offset(0.75, 0.5), Offset(0.25, 0.78), Offset(0.75, 0.78)],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final r  = size.width * 0.14;
    final bg = Paint()..color = faceColor;
    final dot = Paint()..color = dotColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(size.width * 0.18)), bg);
    final positions = _dots[value.clamp(1, 6)] ?? _dots[1]!;
    for (final pos in positions) {
      canvas.drawCircle(Offset(size.width * pos.dx, size.height * pos.dy), r, dot);
    }
  }

  @override
  bool shouldRepaint(DiceFacePainter old) => old.value != value || old.dotColor != dotColor;
}

/// SVG die face widget. Renders assets/game-assets/dice/dice-N.svg.
/// Legacy colour params are accepted but ignored.
class DiceWidget extends StatelessWidget {
  const DiceWidget({
    super.key,
    required this.value,
    this.size = 52,
    this.faceColor = Colors.white,
    this.dotColor = const Color(0xFF1A1A1A),
    this.borderColor = const Color(0xFFFFD700),
    this.borderWidth = 2.5,
  });

  final int    value;
  final double size;
  final Color  faceColor;
  final Color  dotColor;
  final Color  borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(1, 6);
    return SvgPicture.asset(
      'assets/game-assets/dice/dice-$v.svg',
      width:  size,
      height: size,
      fit:    BoxFit.contain,
    );
  }
}
