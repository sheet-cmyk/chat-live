import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../sb_game_model.dart';
import '../widgets/sb_bet_setting.dart';
import '../widgets/sb_game_control_button.dart';
import '../widgets/sb_game_symbol_tile.dart';
import '../widgets/sb_screen_animation.dart';
import 'sb_game_rules_screen.dart';
import 'sb_settings_screen.dart';

class SbPlayScreen extends StatefulWidget {
  const SbPlayScreen({super.key});

  @override
  State<SbPlayScreen> createState() => _SbPlayScreenState();
}

class _SbPlayScreenState extends State<SbPlayScreen>
    with TickerProviderStateMixin {
  static const int rows = 5;
  static const int cols = 6;
  static const int total = rows * cols;

  final Random _random = Random();
  late List<String?> _currentGridSymbols;
  late List<bool> _matchedTiles;
  late List<bool> _gravityTiles;
  late List<bool> _refillTiles;
  late List<int> _fallDistance;
  late List<VoidCallback?> _tileCompletionCallbacks;
  late List<SbSymbolAnimationType> _tileAnimations;

  bool _isSpinning = false;

  late AnimationController _titleController;
  late Animation<double> _titleAnimation;

  @override
  void initState() {
    super.initState();
    final symbols =
        Provider.of<SbShopData>(context, listen: false).gameSymbols;
    _currentGridSymbols = _generateRandomGrid(symbols, total);

    _matchedTiles = List.filled(total, false);
    _gravityTiles = List.filled(total, false);
    _refillTiles = List.filled(total, false);
    _fallDistance = List.filled(total, 0);
    _tileCompletionCallbacks = List.filled(total, null);
    _tileAnimations =
        List.filled(total, SbSymbolAnimationType.gravityEnter);

    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _titleAnimation = _buildTitleAnimation();
    _titleController.forward();

    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        final idx = r * cols + c;
        _fallDistance[idx] = rows - r;
      }
    }
  }

  Animation<double> _buildTitleAnimation() {
    return TweenSequence([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 0.9)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 20,
      ),
    ]).animate(_titleController);
  }

  List<String?> _generateRandomGrid(List<String> symbols, int count) {
    return List.generate(
        count, (_) => symbols[_random.nextInt(symbols.length)]);
  }

  Future<void> _waitForAllTilesComplete([List<int>? indices]) {
    final completer = Completer<void>();
    final List<int> animating =
        indices ?? List.generate(total, (i) => i);

    if (animating.isEmpty) {
      completer.complete();
      return completer.future;
    }

    int remaining = animating.length;

    void onTileComplete() {
      remaining--;
      if (remaining <= 0 && !completer.isCompleted) {
        completer.complete();
      }
    }

    for (final i in animating) {
      _tileCompletionCallbacks[i] = onTileComplete;
    }

    completer.future.whenComplete(() {
      for (final i in animating) {
        _tileCompletionCallbacks[i] = null;
      }
    });

    return completer.future;
  }

  void _setAnimationFor(List<int> indices, SbSymbolAnimationType type) {
    bool changed = false;
    for (final i in indices) {
      if (_tileAnimations[i] != type) {
        _tileAnimations[i] = type;
        changed = true;
      }
    }
    if (changed) setState(() {});
  }

  Future<void> _onSpin() async {
    final shopData = Provider.of<SbShopData>(context, listen: false);
    if (_isSpinning || shopData.credits < shopData.bet) return;

    shopData.spinGame();
    setState(() => _isSpinning = true);

    if (shopData.ambientMusicOn && shopData.soundFxOn) {
      shopData.playSymbolSound();
    }

    _matchedTiles.fillRange(0, total, false);
    _gravityTiles.fillRange(0, total, false);
    _refillTiles.fillRange(0, total, false);
    _fallDistance.fillRange(0, total, 0);

    final allTiles = List.generate(total, (i) => i);
    _setAnimationFor(allTiles, SbSymbolAnimationType.gravityExit);
    await _waitForAllTilesComplete(allTiles);

    await Future.delayed(const Duration(milliseconds: 120));

    _currentGridSymbols =
        _generateRandomGrid(shopData.gameSymbols, total);
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows; r++) {
        final idx = r * cols + c;
        _fallDistance[idx] = rows - r;
      }
    }

    _setAnimationFor(allTiles, SbSymbolAnimationType.gravityEnter);
    await _waitForAllTilesComplete(allTiles);

    int totalWin = 0;
    bool continueCascade = true;

    while (continueCascade) {
      if (!_checkAndMarkMatches()) {
        continueCascade = false;
        break;
      }

      final matched = <int>[];
      for (int i = 0; i < total; i++) {
        if (_matchedTiles[i]) matched.add(i);
      }

      if (matched.isEmpty) {
        continueCascade = false;
        break;
      }

      _setAnimationFor(matched, SbSymbolAnimationType.explode);
      await _waitForAllTilesComplete(matched);

      totalWin += matched.length * shopData.bet;

      _gravityRefill(shopData.gameSymbols);
      final falling = <int>[];
      for (int i = 0; i < total; i++) {
        if (_gravityTiles[i] || _refillTiles[i]) falling.add(i);
      }

      _setAnimationFor(falling, SbSymbolAnimationType.gravityFall);
      await _waitForAllTilesComplete(falling);

      await Future.delayed(const Duration(milliseconds: 120));
    }

    if (totalWin > 0) shopData.winCredits(totalWin.toDouble());

    setState(() => _isSpinning = false);
  }

  bool _checkAndMarkMatches() {
    bool foundMatch = false;
    _matchedTiles.fillRange(0, total, false);

    for (int r = 0; r < rows; r++) {
      int c = 0;
      while (c < cols) {
        final idx = r * cols + c;
        final sym = _currentGridSymbols[idx];
        if (sym == null) {
          c++;
          continue;
        }
        int run = 1;
        int cc = c + 1;
        while (cc < cols && _currentGridSymbols[r * cols + cc] == sym) {
          run++;
          cc++;
        }
        if (run >= 3) {
          foundMatch = true;
          for (int k = 0; k < run; k++) {
            _matchedTiles[r * cols + (c + k)] = true;
          }
        }
        c = cc;
      }
    }

    for (int c = 0; c < cols; c++) {
      int r = 0;
      while (r < rows) {
        final idx = r * cols + c;
        final sym = _currentGridSymbols[idx];
        if (sym == null) {
          r++;
          continue;
        }
        int run = 1;
        int rr = r + 1;
        while (rr < rows && _currentGridSymbols[rr * cols + c] == sym) {
          run++;
          rr++;
        }
        if (run >= 3) {
          foundMatch = true;
          for (int k = 0; k < run; k++) {
            _matchedTiles[(r + k) * cols + c] = true;
          }
        }
        r = rr;
      }
    }
    return foundMatch;
  }

  void _gravityRefill(List<String> symbols) {
    List<int> fallDistance = List.filled(total, 0);
    List<bool> newTiles = List.filled(total, false);

    for (int c = 0; c < cols; c++) {
      int writeRow = rows - 1;
      for (int r = rows - 1; r >= 0; r--) {
        final idx = r * cols + c;
        if (_matchedTiles[idx] || _currentGridSymbols[idx] == null) {
          _currentGridSymbols[idx] = null;
        } else {
          if (writeRow != r) {
            final newIdx = writeRow * cols + c;
            _currentGridSymbols[newIdx] = _currentGridSymbols[idx];
            _currentGridSymbols[idx] = null;
            fallDistance[newIdx] = writeRow - r;
          }
          writeRow--;
        }
      }
      int fillCount = writeRow + 1;
      for (int r = 0; r < fillCount; r++) {
        final idx = r * cols + c;
        _currentGridSymbols[idx] =
            symbols[_random.nextInt(symbols.length)];
        newTiles[idx] = true;
        fallDistance[idx] = fillCount - r;
      }
    }
    _fallDistance = fallDistance;
    _refillTiles = newTiles;
    _gravityTiles =
        List.generate(total, (i) => fallDistance[i] > 0);
    _matchedTiles.fillRange(0, total, false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
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
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0, top: 16.0),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Center(
                      child: ScaleTransition(
                        scale: _titleAnimation,
                        child: Image.asset(
                          'assets/sweet_bonanza/images/sweet_label.gif',
                          height: 100,
                          width: constraints.maxWidth,
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                height: screenHeight * 0.5,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter:
                          ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                      child: Container(
                        color: Colors.white.withAlpha(13),
                        child: GridView.builder(
                          padding: const EdgeInsets.all(4),
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            crossAxisSpacing: 2,
                            mainAxisSpacing: 2,
                            childAspectRatio: 1,
                          ),
                          itemCount: _currentGridSymbols.length,
                          itemBuilder: (context, index) {
                            final key = ValueKey(
                                '$index-${_currentGridSymbols[index]}');
                            return SbGameSymbolTile(
                              key: key,
                              imagePath:
                                  _currentGridSymbols[index] ?? '',
                              animationType: _tileAnimations[index],
                              fallDistance: _fallDistance[index],
                              rowIndex: index ~/ cols,
                              colIndex: index % cols,
                              totalRows: rows,
                              onAnimationComplete:
                                  _tileCompletionCallbacks[index],
                              delay: Duration(
                                  milliseconds:
                                      ((index ~/ cols) * 10) +
                                          ((index % cols) * 20)),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Consumer<SbShopData>(
                builder: (context, shopData, child) {
                  return Padding(
                    padding: const EdgeInsets.only(
                        bottom: 12.0, top: 12.0),
                    child: Column(
                      children: [
                        Text(
                          _isSpinning
                              ? 'SPINNING...'
                              : (shopData.lastWin > 0
                                  ? 'YOU WON ${shopData.lastWin.toStringAsFixed(0)}'
                                  : (shopData.credits < shopData.bet
                                      ? 'NOT ENOUGH CREDIT!'
                                      : 'PLACE YOUR BET!')),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SbGameControlButton(
                              assetPath:
                                  'assets/sweet_bonanza/images/button_spin.webp',
                              onPressed:
                                  _isSpinning ? null : _onSpin,
                              height: 90,
                              width: 90,
                            ),
                            const SizedBox(width: 12),
                            SbGameControlButton(
                              assetPath:
                                  'assets/sweet_bonanza/images/button_bet.webp',
                              onPressed: _isSpinning
                                  ? null
                                  : () {
                                      Provider.of<SbShopData>(context,
                                              listen: false)
                                          .playTapSound();
                                      showDialog(
                                        context: context,
                                        useRootNavigator: false,
                                        builder: (_) =>
                                            const SbBetSettingsDialog(),
                                      );
                                    },
                              width: 64,
                              height: 64,
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.settings,
                                    color: Colors.white, size: 22),
                                onPressed: () {
                                  Provider.of<SbShopData>(context,
                                          listen: false)
                                      .playTapSound();
                                  showDialog(
                                    context: context,
                                    useRootNavigator: false,
                                    builder: (_) =>
                                        const SbSettingsDialog(),
                                  );
                                },
                              ),
                              Flexible(
                                child: Text(
                                  'CREDIT: ${shopData.credits.toStringAsFixed(0)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'BET: ${shopData.bet}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.info_outline,
                                    color: Colors.white, size: 22),
                                onPressed: () {
                                  Provider.of<SbShopData>(context,
                                          listen: false)
                                      .playTapSound();
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
