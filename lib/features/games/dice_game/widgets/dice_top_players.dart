import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dice_game_models.dart';
import '../providers/dice_game_providers.dart';

class DiceTopPlayers extends ConsumerWidget {
  const DiceTopPlayers({super.key, required this.roomId});
  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncPlayers = ref.watch(diceTopPlayersProvider(roomId));
    final players = asyncPlayers.valueOrNull ?? [];

    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(60),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const Text('Top5',
            style: TextStyle(
              color: Color(0xFFFFD700), fontSize: 9,
              fontWeight: FontWeight.w900, letterSpacing: 0.5,
            )),
          const SizedBox(height: 4),
          ...List.generate(5, (i) {
            final player = i < players.length ? players[i] : null;
            return _PlayerSlot(rank: i + 1, player: player);
          }),
        ],
      ),
    );
  }
}

class _PlayerSlot extends StatelessWidget {
  const _PlayerSlot({required this.rank, required this.player});
  final int              rank;
  final DiceTopPlayer?   player;

  @override
  Widget build(BuildContext context) {
    if (player == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withAlpha(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Center(
            child: Text('$rank',
              style: const TextStyle(color: Colors.white24, fontSize: 10)),
          ),
        ),
      );
    }

    final Color rankColor = switch (rank) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFB0BEC5),
      3 => const Color(0xFFBF8970),
      _ => Colors.white38,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: rankColor, width: 1.5),
              ),
              child: ClipOval(
                child: player!.avatar != null
                    ? CachedNetworkImage(
                        imageUrl: player!.avatar!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _DefaultAvatar(player!.userName),
                      )
                    : _DefaultAvatar(player!.userName),
              ),
            ),
            Positioned(
              bottom: -2, right: -2,
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rankColor,
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Center(
                  child: Text('$rank',
                    style: const TextStyle(
                      color: Colors.black, fontSize: 7,
                      fontWeight: FontWeight.w900,
                    )),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _fmt(player!.totalWagered),
            key: ValueKey(player!.totalWagered),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 7),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}ك';
    return '$v';
  }
}

class _DefaultAvatar extends StatelessWidget {
  const _DefaultAvatar(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2E7D32),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '؟',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }
}
