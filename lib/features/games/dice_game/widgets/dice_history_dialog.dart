import 'package:flutter/material.dart';
import '../models/dice_game_models.dart';
import '../repositories/dice_game_repository.dart';
import 'dice_face_painter.dart';

class DiceHistoryDialog extends StatefulWidget {
  const DiceHistoryDialog({super.key, required this.roomId});
  final String roomId;

  @override
  State<DiceHistoryDialog> createState() => _DiceHistoryDialogState();
}

class _DiceHistoryDialogState extends State<DiceHistoryDialog> {
  final _repo = DiceGameRepository();
  List<DiceHistoryEntry>? _entries;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _repo.fetchHistory(widget.roomId);
    if (mounted) setState(() => _entries = entries);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF1A3A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF00BCD4), width: 2)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('سجلات اللعبة',
              style: TextStyle(color: Color(0xFFFFD700), fontSize: 18,
                  fontWeight: FontWeight.w800, fontFamily: 'Cairo')),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: _entries == null
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))
                : _entries!.isEmpty
                    ? const Center(
                        child: Text('لا توجد سجلات بعد',
                          style: TextStyle(color: Colors.white54, fontFamily: 'Cairo')))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _entries!.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 1),
                        itemBuilder: (_, i) => _HistoryRow(entry: _entries![i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry});
  final DiceHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final isTriple = entry.winner == DiceBetType.triple;
    final Color winColor;
    switch (entry.winner) {
      case DiceBetType.small:  winColor = const Color(0xFF42A5F5);
      case DiceBetType.big:    winColor = const Color(0xFFEF5350);
      case DiceBetType.triple: winColor = const Color(0xFFFFD700);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Round ID
          SizedBox(
            width: 36,
            child: Text('#${entry.roundId}',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
          // Dice
          Row(children: entry.dice.map((v) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: DiceWidget(value: v, size: 28,
                borderColor: Colors.white24, borderWidth: 1),
          )).toList()),
          const SizedBox(width: 10),
          // Total
          Text('${entry.total}',
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          // Winner badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: winColor.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: winColor.withAlpha(120)),
            ),
            child: Text(
              '${entry.winner.label}${isTriple ? " 🎲" : ""}',
              style: TextStyle(
                color: winColor, fontSize: 13,
                fontWeight: FontWeight.w800, fontFamily: 'Cairo',
              )),
          ),
        ],
      ),
    );
  }
}
