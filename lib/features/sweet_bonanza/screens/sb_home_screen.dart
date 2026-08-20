import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../sb_game_model.dart';
import '../widgets/sb_home_action_button.dart';
import '../widgets/sb_screen_animation.dart';
import 'sb_play_screen.dart';
import 'sb_shop_screen.dart';
import 'sb_fortune_wheel_screen.dart';
import 'sb_settings_screen.dart';


class SbMainAppScreen extends StatefulWidget {
  const SbMainAppScreen({super.key});

  @override
  State<SbMainAppScreen> createState() => _SbMainAppScreenState();
}

class _SbMainAppScreenState extends State<SbMainAppScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late SbShopData _shopData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
          parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _shopData = Provider.of<SbShopData>(context, listen: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _shopData.audioManager.pauseBackgroundMusic();
    } else if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _shopData.ambientMusicOn) {
          _shopData.audioManager.resumeBackgroundMusic();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopData = Provider.of<SbShopData>(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Consumer<SbShopData>(
              builder: (context, shopData, _) {
                return Image.asset(
                  shopData.selectedBackgroundImage,
                  fit: BoxFit.cover,
                );
              },
            ),
          ),
          SbAnimatedBackgroundOverlay(
            showClouds: shopData.showClouds,
            showFruits: shopData.showFruits,
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(26),
                    Colors.black.withAlpha(128),
                    Colors.black.withAlpha(178),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Image.asset(
                        'assets/sweet_bonanza/images/sweet_label.webp',
                        width: 250,
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 50),
                SbHomeActionButton(
                  text: 'PLAY',
                  onPressed: () {
                    shopData.playTapSound();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SbPlayScreen()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                SbHomeActionButton(
                  text: 'FORTUNE WHEEL',
                  onPressed: () {
                    shopData.playTapSound();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SbFortuneWheelScreen()),
                    );
                  },
                ),
                const SizedBox(height: 20),
                SbHomeActionButton(
                  text: 'SHOP',
                  onPressed: () {
                    shopData.playTapSound();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SbShopScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            left: 30,
            child: IconButton(
              icon:
                  const Icon(Icons.settings, color: Colors.white, size: 30),
              onPressed: () {
                shopData.playTapSound();
                showDialog(
                  context: context,
                  useRootNavigator: false,
                  builder: (_) => const SbSettingsDialog(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
