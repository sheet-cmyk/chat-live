import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../sb_game_model.dart';
import '../widgets/sb_bet_setting.dart';
import '../widgets/sb_game_control_button.dart';
import '../widgets/sb_screen_animation.dart';
import 'sb_game_rules_screen.dart';
import 'sb_settings_screen.dart';

class SbFortuneWheelScreen extends StatefulWidget {
  const SbFortuneWheelScreen({super.key});

  @override
  State<SbFortuneWheelScreen> createState() => _SbFortuneWheelScreenState();
}

class _SbFortuneWheelScreenState extends State<SbFortuneWheelScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _wheelRotationAnimation;
  late AnimationController _titleController;
  late Animation<double> _titleAnimation;
  final Random _random = Random();
  double _currentWheelAngle = 0.0;
  bool _isSpinning = false;
  String? _lastMultiplierText;

  final List<Map<String, dynamic>> _wheelSegments = [
    {'value': 0.5, 'color': const Color(0xFF4AA4EE)},
    {'value': 1.5, 'color': const Color(0xFF9F59F5)},
    {'value': 1.0, 'color': const Color(0xFF3A6DFF)},
    {'value': 0.5, 'color': const Color(0xFFF79447)},
    {'value': 1.2, 'color': const Color(0xFF57DFD8)},
    {'value': 1.2, 'color': const Color(0xFF79CF5E)},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _wheelRotationAnimation = Tween<double>(
      begin: _currentWheelAngle,
      end: _currentWheelAngle,
    ).animate(_animationController);

    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _titleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 50),
    ]).animate(
        CurvedAnimation(parent: _titleController, curve: Curves.easeInOut));
  }

  void _onSpin(BuildContext context) async {
    final shopData = Provider.of<SbShopData>(context, listen: false);
    if (_isSpinning || shopData.credits < shopData.bet) return;
    setState(() {
      _isSpinning = true;
      _lastMultiplierText = null;
    });

    shopData.spinGame();
    if (shopData.ambientMusicOn && shopData.soundFxOn) {
      shopData.playWheelSpinSound();
    }

    final int sliceCount = _wheelSegments.length;
    final double segmentAngle = 2 * pi / sliceCount;
    final int targetSegment = _random.nextInt(sliceCount);
    final double targetAngleRad =
        -targetSegment * segmentAngle - segmentAngle / 2;
    const double fullSpins = 5;
    final double totalRotationRad =
        _currentWheelAngle + fullSpins * 2 * pi + targetAngleRad;

    _wheelRotationAnimation = Tween<double>(
      begin: _currentWheelAngle,
      end: totalRotationRad,
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart));

    _animationController.reset();
    await _animationController.forward();

    _currentWheelAngle = _wheelRotationAnimation.value % (2 * pi);
    int landedSegment =
        ((_currentWheelAngle + segmentAngle / 2) ~/ segmentAngle) %
            sliceCount;
    landedSegment = (sliceCount - landedSegment) % sliceCount;

    final double multiplier = _wheelSegments[landedSegment]['value'];
    shopData.playWheelStopSound();
    final double winAmount =
        double.parse((shopData.bet * multiplier).toStringAsFixed(1));
    shopData.winCredits(winAmount);
    setState(() {
      _isSpinning = false;
      _lastMultiplierText = '${multiplier}x';
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopData = Provider.of<SbShopData>(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(shopData.selectedBackgroundImage,
                fit: BoxFit.cover),
          ),
          SbAnimatedBackgroundOverlay(
            showClouds: shopData.showClouds,
            showFruits: shopData.showFruits,
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33A8D4F5),
                    Color(0x801565C0),
                    Color(0xB24527A0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.only(right: 16.0, top: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 30),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: ScaleTransition(
                  scale: _titleAnimation,
                  child: Image.asset(
                    'assets/sweet_bonanza/images/sweet_label.gif',
                    height: 100,
                    width: MediaQuery.of(context).size.width,
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double size =
                        constraints.maxWidth < constraints.maxHeight
                            ? constraints.maxWidth * 1.0
                            : constraints.maxHeight * 1.0;
                    return Center(
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _wheelRotationAnimation,
                              builder: (context, child) {
                                final double angle = _isSpinning
                                    ? _wheelRotationAnimation.value
                                    : _currentWheelAngle;
                                return Transform.rotate(
                                  angle: angle,
                                  child: Image.asset(
                                    'assets/sweet_bonanza/images/wheel.webp',
                                    width: size,
                                    height: size,
                                    fit: BoxFit.contain,
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              top: 0,
                              child: Image.asset(
                                'assets/sweet_bonanza/images/pointer.webp',
                                width: size * 0.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_lastMultiplierText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 5),
                  child: Text(
                    'WIN MULTIPLIER: $_lastMultiplierText',
                    style: const TextStyle(
                        color: Colors.yellow,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              Consumer<SbShopData>(
                builder: (context, shopData, child) {
                  return Text(
                    _isSpinning
                        ? 'SPINNING...'
                        : (shopData.lastWin > 0
                            ? 'YOU WON ${shopData.lastWin.toStringAsFixed(0)}'
                            : (shopData.credits < shopData.bet
                                ? 'NOT ENOUGH CREDIT!'
                                : 'SPIN THE WHEEL!')),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  );
                },
              ),
              const SizedBox(height: 20),
              Consumer<SbShopData>(
                builder: (context, shopData, child) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0, top: 20.0),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SbGameControlButton(
                              assetPath:
                                  'assets/sweet_bonanza/images/button_spin.webp',
                              onPressed: _isSpinning
                                  ? null
                                  : () => _onSpin(context),
                              width: 90,
                              height: 90,
                            ),
                            const SizedBox(width: 20),
                            SbGameControlButton(
                              assetPath:
                                  'assets/sweet_bonanza/images/button_bet.webp',
                              onPressed: _isSpinning
                                  ? null
                                  : () {
                                      shopData.playTapSound();
                                      showDialog(
                                        context: context,
                                        useRootNavigator: false,
                                        builder: (_) =>
                                            const SbBetSettingsDialog(),
                                      );
                                    },
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.settings,
                                    color: Colors.white, size: 28),
                                onPressed: () {
                                  shopData.playTapSound();
                                  showDialog(
                                    context: context,
                                    useRootNavigator: false,
                                    builder: (_) => const SbSettingsDialog(),
                                  );
                                },
                              ),
                              Text(
                                'CREDIT: ${shopData.credits.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'BET: ${shopData.bet}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline,
                                    color: Colors.white, size: 28),
                                onPressed: () {
                                  shopData.playTapSound();
                                  showDialog(
                                    context: context,
                                    useRootNavigator: false,
                                    builder: (_) =>
                                        const SbGameRulesScreen(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
