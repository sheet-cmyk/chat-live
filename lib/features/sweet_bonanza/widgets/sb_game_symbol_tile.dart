import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum SbSymbolAnimationType {
  explode,
  gravityFall,
  refill,
  gravityExit,
  gravityEnter,
  idle,
}

class SbGameSymbolTile extends StatefulWidget {
  final String imagePath;
  final SbSymbolAnimationType animationType;
  final VoidCallback? onAnimationComplete;
  final int rowIndex;
  final int colIndex;
  final Duration delay;
  final int fallDistance;
  final int totalRows;

  const SbGameSymbolTile({
    super.key,
    required this.imagePath,
    required this.animationType,
    this.onAnimationComplete,
    required this.rowIndex,
    required this.colIndex,
    required this.totalRows,
    this.delay = Duration.zero,
    this.fallDistance = 0,
  });

  @override
  State<SbGameSymbolTile> createState() => _SbGameSymbolTileState();
}

class _SbGameSymbolTileState extends State<SbGameSymbolTile>
    with AutomaticKeepAliveClientMixin {
  late String _lastImagePath;
  late SbSymbolAnimationType _lastAnimType;
  late int _lastFallDistance;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _lastImagePath = widget.imagePath;
    _lastAnimType = widget.animationType;
    _lastFallDistance = widget.fallDistance;
  }

  @override
  void didUpdateWidget(SbGameSymbolTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.animationType != widget.animationType ||
        oldWidget.fallDistance != widget.fallDistance) {
      setState(() {
        _lastImagePath = widget.imagePath;
        _lastAnimType = widget.animationType;
        _lastFallDistance = widget.fallDistance;
      });
    }
  }

  Widget _buildImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Image.asset(_lastImagePath, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildAnimation() {
    super.build(context);
    final randomOffset = Random().nextInt(20);
    final int reverseRow = widget.totalRows - 1 - widget.rowIndex;
    final imageWidget = _buildImage();

    switch (_lastAnimType) {
      case SbSymbolAnimationType.idle:
        return imageWidget;

      case SbSymbolAnimationType.explode:
        return imageWidget
            .animate(
              key: ValueKey(
                  'explode-${widget.rowIndex}-${widget.colIndex}'),
              delay: Duration(
                milliseconds: widget.rowIndex * 10 +
                    widget.colIndex * 8 +
                    randomOffset,
              ),
              onComplete: (_) => widget.onAnimationComplete?.call(),
            )
            .scaleXY(
                begin: 1.0, end: 0.0, duration: 120.ms, curve: Curves.easeIn)
            .fadeOut(duration: 120.ms);

      case SbSymbolAnimationType.gravityFall:
        final double fallOffset = -_lastFallDistance.toDouble();
        final totalDelay = Duration(
          milliseconds:
              (widget.colIndex * 20) + (reverseRow * 10) + randomOffset,
        );
        return imageWidget
            .animate(
              key: ValueKey('fall-${widget.rowIndex}-${widget.colIndex}'),
              delay: totalDelay,
              onComplete: (_) => widget.onAnimationComplete?.call(),
            )
            .slide(
              begin: Offset(0, fallOffset),
              end: const Offset(0, 0),
              duration: (280 + _lastFallDistance * 65).ms,
              curve: Curves.easeOutCubic,
            )
            .then()
            .scaleXY(begin: 1.02, end: 0.96, duration: 110.ms)
            .then()
            .scaleXY(begin: 0.96, end: 1.02, duration: 100.ms)
            .then()
            .scaleXY(begin: 1.02, end: 1.0, duration: 90.ms);

      case SbSymbolAnimationType.refill:
        final totalDelay =
            Duration(milliseconds: (widget.colIndex * 22) + randomOffset);
        return imageWidget
            .animate(
              key: ValueKey('refill-${widget.rowIndex}-${widget.colIndex}'),
              delay: totalDelay,
              onComplete: (_) => widget.onAnimationComplete?.call(),
            )
            .slideY(
              begin: -4.0,
              end: 0,
              duration: (360 + _lastFallDistance * 55).ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: 220.ms)
            .scaleXY(begin: 0.70, end: 1.08, duration: 260.ms)
            .then()
            .scaleXY(begin: 1.08, end: 1.0, duration: 140.ms);

      case SbSymbolAnimationType.gravityExit:
        final totalDelay = Duration(
          milliseconds:
              widget.rowIndex * 80 + widget.colIndex * 60 + randomOffset,
        );
        return imageWidget
            .animate(
              key: ValueKey('exit-${widget.rowIndex}-${widget.colIndex}'),
              delay: totalDelay,
              onComplete: (_) => widget.onAnimationComplete?.call(),
            )
            .slideY(begin: 0, end: 3.0, duration: 500.ms, curve: Curves.easeInCubic)
            .fadeOut(duration: 400.ms);

      case SbSymbolAnimationType.gravityEnter:
        final totalDelay = Duration(
          milliseconds:
              widget.rowIndex * 70 + widget.colIndex * 50 + randomOffset,
        );
        return imageWidget
            .animate(
              key: ValueKey('enter-${widget.rowIndex}-${widget.colIndex}'),
              delay: totalDelay,
              onComplete: (_) => widget.onAnimationComplete?.call(),
            )
            .slideY(begin: -2, end: 0, duration: 500.ms, curve: Curves.easeOutBack)
            .fadeIn(duration: 300.ms)
            .then()
            .scaleXY(begin: 0.8, end: 1.0, duration: 300.ms, curve: Curves.easeOutBack);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withAlpha(20),
      ),
      child: _buildAnimation(),
    );
  }
}
