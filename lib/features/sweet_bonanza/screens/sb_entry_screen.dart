import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as prov;
import '../../../features/wallet/data/repositories/wallet_repository.dart';
import '../sb_game_model.dart';
import 'sb_home_screen.dart';

/// Entry point for Sweet Bonanza from the party_hub app.
///
/// Architecture note:
/// ChangeNotifierProvider<SbShopData>
///   └─ Navigator  ← owns ALL Sweet Bonanza routes & dialogs
///       └─ SbMainAppScreen → SbPlayScreen / SbFortuneWheelScreen / SbShopScreen
///
/// Because the inner Navigator sits INSIDE the ChangeNotifierProvider, every
/// route and dialog pushed by that navigator can find SbShopData via
/// Provider.of<SbShopData>(context) without extra wrapper boilerplate.
class SbEntryScreen extends ConsumerStatefulWidget {
  const SbEntryScreen({super.key});

  @override
  ConsumerState<SbEntryScreen> createState() => _SbEntryScreenState();
}

class _SbEntryScreenState extends ConsumerState<SbEntryScreen> {
  SbShopData? _shopData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  Future<void> _loadCoins() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    try {
      double coins = 1000;
      if (uid != null) {
        final balance = await WalletRepository().getBalance(uid);
        coins = (balance['coins'] ?? 1000).toDouble();
      }
      _shopData = SbShopData(initialCoins: coins);
      await _shopData!.loadAudioSettings();
      await _shopData!.loadEconomy();
      _shopData!
          .playBackgroundMusic('assets/sweet_bonanza/sound/sweet_music.mp3');
    } catch (_) {
      _shopData = SbShopData(initialCoins: 1000);
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _syncCoinsOnExit() async {
    final shopData = _shopData;
    if (shopData == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final delta = shopData.netChange;
    if (delta == 0) return;

    try {
      if (delta > 0) {
        await WalletRepository().addCoins(uid, delta, 'Sweet Bonanza win');
      } else {
        await WalletRepository()
            .deductCoins(uid, -delta, 'Sweet Bonanza bet');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _shopData?.audioManager.stopMusic();
    _syncCoinsOnExit();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.orange),
              SizedBox(height: 16),
              Text(
                'Loading game...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return prov.ChangeNotifierProvider<SbShopData>.value(
      value: _shopData!,
      // Inner Navigator sits INSIDE the provider ─ so all routes and dialogs
      // pushed onto it can resolve Provider<SbShopData> from their context.
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) await _syncCoinsOnExit();
        },
        child: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            builder: (_) => const SbMainAppScreen(),
          ),
        ),
      ),
    );
  }
}
