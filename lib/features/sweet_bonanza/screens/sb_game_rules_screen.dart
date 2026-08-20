import 'dart:ui';
import 'package:flutter/material.dart';

class SbGameRulesScreen extends StatelessWidget {
  const SbGameRulesScreen({super.key});

  static const List<SbSymbolData> symbols = [
    SbSymbolData('assets/sweet_bonanza/images/symbols/symbol1', '7: x0.5\n8-10: x1.2\n11+: x1.4'),
    SbSymbolData('assets/sweet_bonanza/images/symbols/symbol2', '7: x0.5\n8-10: x1.2\n11+: x1.4'),
    SbSymbolData('assets/sweet_bonanza/images/symbols/symbol3', '7: x0.5\n8-10: x1.2\n11+: x1.4'),
    SbSymbolData('assets/sweet_bonanza/images/symbols/symbol4', '7: x0.7\n8-10: x1.3\n11+: x1.5'),
    SbSymbolData('assets/sweet_bonanza/images/symbols/symbol5', '7: x0.7\n8-10: x1.3\n11+: x1.5'),
    SbSymbolData('assets/sweet_bonanza/images/symbols/symbol6', '7: x0.7\n8-10: x1.3\n11+: x1.5'),
    SbSymbolData('assets/sweet_bonanza/images/symbols/symbol7', '7: x1.0\n8-10: x1.4\n11+: x1.8'),
    SbSymbolData('assets/sweet_bonanza/images/symbols/symbol8', '7: x1.0\n8-10: x1.4\n11+: x1.8'),
    SbSymbolData('assets/sweet_bonanza/images/symbols/symbol9', '7: x1.2\n8-10: x1.6\n11+: x2.2'),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxDialogWidth = constraints.maxWidth * 0.7;
          final double maxDialogHeight = constraints.maxHeight * 0.85;

          return Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  width: maxDialogWidth,
                  height: maxDialogHeight,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(217),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Spacer(),
                          const Text(
                            'GAME RULES',
                            style: TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 24,
                                fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.cyanAccent),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: GridView.builder(
                          itemCount: symbols.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                          itemBuilder: (context, index) {
                            final symbol = symbols[index];
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset('${symbol.imagePath}.png',
                                    height: 40),
                                const SizedBox(height: 4),
                                Flexible(
                                  child: Text(
                                    symbol.text,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        height: 1.2),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Symbols pay anywhere on the screen.\nTotal count of same symbol determines win.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SbSymbolData {
  final String imagePath;
  final String text;
  const SbSymbolData(this.imagePath, this.text);
}
