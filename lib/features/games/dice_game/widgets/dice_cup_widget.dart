import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/dice_game_models.dart';

/// Betting  → cup-closed.svg (closed bell, shake animation)
/// Rolling  → cup-dome.svg  + rapidly-randomising SVG dice overlaid
/// Result   → cup-dome.svg  + final SVG dice overlaid
class DiceCupWidget extends StatefulWidget {
  const DiceCupWidget({
    super.key,
    required this.phase,
    required this.dice,
  });

  final DiceRoundPhase phase;
  final List<int>      dice;

  @override
  State<DiceCupWidget> createState() => _DiceCupWidgetState();
}

class _DiceCupWidgetState extends State<DiceCupWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _shake;
  final _rng = Random();
  List<int> _rollingDice = [1, 1, 1];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -9.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -9.0, end: 9.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 9.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.linear));
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed &&
          widget.phase == DiceRoundPhase.rolling) {
        _ctrl.forward(from: 0.0);
      }
    });
    _syncPhase();
  }

  @override
  void didUpdateWidget(DiceCupWidget old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase) _syncPhase();
  }

  void _syncPhase() {
    switch (widget.phase) {
      case DiceRoundPhase.betting:
        _ctrl.stop();
        setState(() => _rollingDice = [1, 1, 1]);
      case DiceRoundPhase.rolling:
        _ctrl.forward(from: 0.0);
        _startRoll();
      case DiceRoundPhase.result:
        _ctrl.stop();
        setState(() =>
            _rollingDice = widget.dice.isNotEmpty ? widget.dice : [1, 1, 1]);
    }
  }

  void _startRoll() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted || widget.phase != DiceRoundPhase.rolling) return false;
      setState(() => _rollingDice = [
            _rng.nextInt(6) + 1,
            _rng.nextInt(6) + 1,
            _rng.nextInt(6) + 1,
          ]);
      return true;
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBetting = widget.phase == DiceRoundPhase.betting;
    final isRolling = widget.phase == DiceRoundPhase.rolling;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(
        offset: isRolling ? Offset(_shake.value, 0) : Offset.zero,
        child: child,
      ),
      child: SizedBox(
        width: 94,
        height: 94,
        child: isBetting
            // ── Closed cup ──────────────────────────────────────────────
            ? SvgPicture.asset(
                'assets/game-assets/ui/cup-closed.svg',
                width: 94, height: 94, fit: BoxFit.contain)
            // ── Glass dome + live SVG dice ───────────────────────────────
            : Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  SvgPicture.asset(
                    'assets/game-assets/ui/cup-dome.svg',
                    width: 94, height: 94, fit: BoxFit.contain,
                  ),
                  // SVG dice overlaid on the dome's felt area
                  Positioned(
                    bottom: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _rollingDice.map((v) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: SvgPicture.asset(
                          'assets/game-assets/dice/dice-$v.svg',
                          width: 20, height: 20,
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
