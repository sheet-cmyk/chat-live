import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class GameBalanceBar extends StatelessWidget {
  const GameBalanceBar({super.key, required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🪙', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text('${_fmt(coins)} عملة', style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  static String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}ك';
    return '$v';
  }
}

class GameChoiceBtn extends StatelessWidget {
  const GameChoiceBtn({super.key, required this.label, required this.emoji, required this.selected, required this.onTap});
  final String label, emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withAlpha(40) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: selected ? AppColors.primary : AppColors.textSecondary, fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

class GameBetSelector extends StatelessWidget {
  const GameBetSelector({super.key, required this.bets, required this.selected, required this.onSelect});
  final List<int> bets;
  final int selected;
  final void Function(int) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      alignment: WrapAlignment.center,
      children: bets.map((b) {
        final isSel = b == selected;
        return GestureDetector(
          onTap: () => onSelect(b),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSel ? AppColors.primary : AppColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isSel ? AppColors.primary : AppColors.divider),
            ),
            child: Text(_label(b), style: TextStyle(
              color: isSel ? Colors.white : AppColors.textSecondary,
              fontFamily: 'Cairo', fontWeight: isSel ? FontWeight.w700 : FontWeight.normal, fontSize: 13,
            )),
          ),
        );
      }).toList(),
    );
  }

  static String _label(int v) {
    if (v >= 1000) return '${v ~/ 1000}ك 🪙';
    return '$v 🪙';
  }
}

class GamePlayButton extends StatelessWidget {
  const GamePlayButton({super.key, required this.loading, required this.bet, required this.onTap});
  final bool loading;
  final int bet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: loading ? null : AppColors.primaryGradient,
          color: loading ? AppColors.surfaceLight : null,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text('العب الآن — رهان $bet 🪙', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Cairo')),
        ),
      ),
    );
  }
}

class GameResultBanner extends StatelessWidget {
  const GameResultBanner({super.key, required this.message, required this.won});
  final String message;
  final bool won;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: (won ? AppColors.success : AppColors.error).withAlpha(30),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: won ? AppColors.success : AppColors.error),
      ),
      child: Text(message, style: TextStyle(
        color: won ? AppColors.success : AppColors.error,
        fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 16,
      )),
    );
  }
}
