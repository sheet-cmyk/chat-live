import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/dice_game_models.dart';

class DiceBetArea extends StatelessWidget {
  const DiceBetArea({
    super.key,
    required this.type,
    required this.totalBets,
    required this.myBet,
    required this.canBet,
    required this.isWinner,
    required this.onTap,
  });

  final DiceBetType  type;
  final int          totalBets;
  final int          myBet;
  final bool         canBet;
  final bool         isWinner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent;
    switch (type) {
      case DiceBetType.small:
        accent = const Color(0xFF42A5F5);
      case DiceBetType.big:
        accent = const Color(0xFFEF5350);
      case DiceBetType.triple:
        accent = const Color(0xFFFFD700);
    }

    return GestureDetector(
      onTap: canBet ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isWinner ? const Color(0xFFFFD700) : accent.withAlpha(70),
            width: isWinner ? 2.0 : 1.2,
          ),
          boxShadow: isWinner
              ? [BoxShadow(
                  color: const Color(0xFFFFD700).withAlpha(90),
                  blurRadius: 12, spreadRadius: 1)]
              : [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4)],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── SVG felt panel background ────────────────────────────────
              SvgPicture.asset(
                'assets/game-assets/ui/panel-bg.svg',
                fit: BoxFit.fill,
              ),

              // ── Winner highlight tint ────────────────────────────────────
              if (isWinner)
                ColoredBox(color: const Color(0xFF1A5C1A).withAlpha(120)),

              // ── Content ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Coin icon
                    const Text('🪙', style: TextStyle(fontSize: 13)),

                    // Total + multiplier
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _fmt(totalBets),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: accent.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: accent.withAlpha(90), width: 1),
                          ),
                          child: Text(
                            '×${type.multiplier}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // SVG chip pile
                    _ChipStack(type: type),

                    // Label
                    Text(
                      type.label,
                      style: TextStyle(
                        color: isWinner ? const Color(0xFFFFD700) : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'Cairo',
                      ),
                    ),

                    // "باستثناء الثلاثي" — small/big only
                    if (type != DiceBetType.triple)
                      Text(
                        'باستثناء الثلاثي',
                        style: TextStyle(
                          color: Colors.white.withAlpha(110),
                          fontSize: 8,
                          fontFamily: 'Cairo',
                        ),
                      ),

                    // My bet amount
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: myBet > 0
                            ? const Color(0xFFFFD700).withAlpha(28)
                            : Colors.black.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        myBet > 0 ? _fmt(myBet) : '0',
                        style: TextStyle(
                          color: myBet > 0
                              ? const Color(0xFFFFD700)
                              : Colors.white.withAlpha(120),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000) { return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}ك'; }
    return '$v';
  }
}

// ── SVG chip pile (overlapping chips) ────────────────────────────────────────
class _ChipStack extends StatelessWidget {
  const _ChipStack({required this.type});
  final DiceBetType type;

  static const _assets = [
    'assets/game-assets/chips/chip-10k.svg',
    'assets/game-assets/chips/chip-1k.svg',
    'assets/game-assets/chips/chip-100.svg',
    'assets/game-assets/chips/chip-10.svg',
  ];

  @override
  Widget build(BuildContext context) {
    final count = type == DiceBetType.triple ? 7 : 5;
    const chipW = 15.0;
    const step  = 9.0;
    final totalW = chipW + (count - 1) * step;

    return SizedBox(
      width: totalW,
      height: chipW + 4,
      child: Stack(
        children: List.generate(count, (i) => Positioned(
          left: i * step,
          top:  i.isOdd ? 0.0 : 3.0,
          child: SvgPicture.asset(
            _assets[i % _assets.length],
            width: chipW, height: chipW,
          ),
        )),
      ),
    );
  }
}
