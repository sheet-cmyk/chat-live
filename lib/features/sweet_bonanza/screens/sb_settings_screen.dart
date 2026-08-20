import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../sb_game_model.dart';
import 'sb_privacy_policy.dart';
import 'sb_support_screen.dart';

class SbSettingsDialog extends StatelessWidget {
  const SbSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(217),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Consumer<SbShopData>(
                  builder: (context, shopData, child) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            const Center(
                              child: Text(
                                'SETTINGS',
                                style: TextStyle(
                                    fontSize: 26,
                                    color: Colors.cyanAccent,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Align(
                              alignment: Alignment.topRight,
                              child: IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white, size: 28),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('Ambient Music',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Switch(
                                  activeThumbColor: Colors.orange,
                                  value: shopData.ambientMusicOn,
                                  onChanged: (_) =>
                                      shopData.toggleAmbientMusic(),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('Sound FX',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                                Switch(
                                  activeThumbColor: Colors.orange,
                                  value: shopData.soundFxOn,
                                  onChanged: (_) => shopData.toggleSoundFx(),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SbPrivacyPolicyScreen()),
                          ),
                          child: const Text('Privacy Policy',
                              style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SbSupportScreen()),
                          ),
                          child: const Text('Support',
                              style: TextStyle(
                                  color: Colors.cyanAccent,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
