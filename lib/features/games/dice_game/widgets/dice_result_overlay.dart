import 'package:flutter/material.dart';
import '../models/dice_game_models.dart';
import 'dice_face_painter.dart';

class DiceResultOverlay extends StatefulWidget {
  const DiceResultOverlay({
    super.key,
    required this.dice,
    required this.total,
    required this.winner,
    required this.myWin,
  });

  final List<int>    dice;
  final int          total;
  final DiceBetType  winner;
  final int          myWin;  // 0 = didn't win

  @override
  State<DiceResultOverlay> createState() => _DiceResultOverlayState();
}

class _DiceResultOverlayState extends State<DiceResultOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;
  late Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _scale = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTriple = widget.winner == DiceBetType.triple;
    final winColor = isTriple ? const Color(0xFFFFD700) : Colors.white;
    final hasWin   = widget.myWin > 0;

    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(210),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasWin ? const Color(0xFFFFD700) : Colors.white24,
              width: hasWin ? 2.5 : 1,
            ),
            boxShadow: hasWin
                ? [const BoxShadow(
                    color: Color(0x80FFD700), blurRadius: 24, spreadRadius: 4)]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Winner label
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${widget.total}',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 28,
                      fontWeight: FontWeight.w900, letterSpacing: 1,
                    )),
                  const SizedBox(width: 10),
                  Text(widget.winner.label,
                    style: TextStyle(
                      color: winColor, fontSize: 26,
                      fontWeight: FontWeight.w900, fontFamily: 'Cairo',
                    )),
                  if (isTriple)
                    const Text(' 🎲', style: TextStyle(fontSize: 22)),
                ],
              ),

              const SizedBox(height: 12),

              // Dice row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.dice.map((v) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: DiceWidget(value: v, size: 48),
                )).toList(),
              ),

              // Win amount
              if (hasWin) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('+ ${_fmt(widget.myWin)} 🪙',
                    style: const TextStyle(
                      color: Colors.black87, fontSize: 16,
                      fontWeight: FontWeight.w900, fontFamily: 'Cairo',
                    )),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}ك';
    return '$v';
  }
}
