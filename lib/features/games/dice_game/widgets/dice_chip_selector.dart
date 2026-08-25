import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../providers/dice_game_providers.dart';

const _kChips = [
  (10000, 'assets/game-assets/chips/chip-10k.svg'),
  (1000,  'assets/game-assets/chips/chip-1k.svg'),
  (100,   'assets/game-assets/chips/chip-100.svg'),
  (10,    'assets/game-assets/chips/chip-10.svg'),
];

class DiceChipSelector extends ConsumerWidget {
  const DiceChipSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(diceChipProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _kChips.map((chip) {
        final (value, asset) = chip;
        final isSel = selected == value;
        return GestureDetector(
          onTap: () => ref.read(diceChipProvider.notifier).state = value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width:  isSel ? 50 : 40,
            height: isSel ? 50 : 40,
            decoration: isSel
                ? const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x80FFFFFF),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: SvgPicture.asset(asset, fit: BoxFit.contain),
          ),
        );
      }).toList(),
    );
  }
}
