import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../sb_game_model.dart';

class SbShopScreen extends StatelessWidget {
  const SbShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shopData = Provider.of<SbShopData>(context);
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(shopData.selectedBackgroundImage,
                  fit: BoxFit.cover),
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(204),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Consumer<SbShopData>(
                  builder: (context, shopData, child) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'SHOP',
                          style: TextStyle(
                              fontSize: 24,
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Credits: ${shopData.credits.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Divider(color: Colors.white24),
                        Flexible(
                          child: GridView.builder(
                            shrinkWrap: true,
                            itemCount: shopData.items.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.75,
                            ),
                            itemBuilder: (context, index) {
                              final item = shopData.items[index];
                              final bool owned = item['owned'] as bool;
                              final bool selected =
                                  (item['selected'] as bool?) ?? false;

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(12),
                                  border: selected
                                      ? Border.all(
                                          color: Colors.cyanAccent, width: 3)
                                      : null,
                                ),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: Image.asset(
                                          item['image'],
                                          fit: BoxFit.cover,
                                          color: owned
                                              ? null
                                              : Colors.black.withAlpha(128),
                                          colorBlendMode: owned
                                              ? null
                                              : BlendMode.darken,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.broken_image,
                                                  color: Colors.grey,
                                                  size: 48),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4.0),
                                      child: Text(
                                        item['name'],
                                        style: const TextStyle(
                                            color: Colors.white),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 8.0),
                                      child: owned
                                          ? ElevatedButton(
                                              onPressed: () =>
                                                  shopData.selectItem(index),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: selected
                                                    ? Colors.black54
                                                    : Colors.green,
                                              ),
                                              child: Text(
                                                selected
                                                    ? 'SELECTED'
                                                    : 'SELECT',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                            )
                                          : ElevatedButton(
                                              onPressed: () =>
                                                  shopData.buyItem(index),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.amber[800],
                                              ),
                                              child: Text(
                                                'BUY: ${item['price']}',
                                                style: const TextStyle(
                                                    color: Colors.white),
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
