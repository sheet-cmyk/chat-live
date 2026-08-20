import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../sb_game_model.dart';

class SbBetSettingsDialog extends StatelessWidget {
  const SbBetSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final shopData = Provider.of<SbShopData>(context);

    return Dialog(
      backgroundColor: Colors.black.withAlpha(204),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'BET SETTINGS',
                  style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                const Text('TOTAL BET',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CircleIconButton(
                      icon: Icons.remove,
                      color: Colors.brown,
                      onPressed: shopData.decreaseBet,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${shopData.bet}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    _CircleIconButton(
                      icon: Icons.add,
                      color: Colors.amber,
                      onPressed: shopData.increaseBet,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.cyanAccent),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, color: Colors.white),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
