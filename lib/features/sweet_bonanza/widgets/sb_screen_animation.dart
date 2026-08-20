import 'package:flutter/material.dart';

class SbAnimatedBackgroundOverlay extends StatefulWidget {
  final bool showClouds;
  final bool showFruits;

  const SbAnimatedBackgroundOverlay({
    super.key,
    this.showClouds = false,
    this.showFruits = false,
  });

  @override
  State<SbAnimatedBackgroundOverlay> createState() =>
      _SbAnimatedBackgroundOverlayState();
}

class _SbAnimatedBackgroundOverlayState
    extends State<SbAnimatedBackgroundOverlay> with TickerProviderStateMixin {
  late final AnimationController _cloudController;
  late final Animation<Offset> _cloudOffset;
  late final AnimationController _fallingImageController;
  late final Animation<Offset> _fallingImageOffset;

  @override
  void initState() {
    super.initState();
    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
    _cloudOffset = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: const Offset(1.0, 0.0),
    ).animate(CurvedAnimation(parent: _cloudController, curve: Curves.linear));

    _fallingImageController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    _fallingImageOffset = Tween<Offset>(
      begin: const Offset(0.0, -1.2),
      end: const Offset(0.0, 1.2),
    ).animate(CurvedAnimation(
        parent: _fallingImageController, curve: Curves.linear));
  }

  @override
  void dispose() {
    _cloudController.dispose();
    _fallingImageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.showFruits)
          Positioned.fill(
            child: SlideTransition(
              position: _fallingImageOffset,
              child: Align(
                alignment: Alignment.topCenter,
                child: Image.asset(
                  'assets/sweet_bonanza/images/falling_fruits.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        if (widget.showClouds)
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 120,
              child: SlideTransition(
                position: _cloudOffset,
                child: Image.asset(
                  'assets/sweet_bonanza/images/clouds_layer.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
