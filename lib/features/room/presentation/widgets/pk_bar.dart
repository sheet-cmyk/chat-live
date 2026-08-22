import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/room_provider.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/repositories/room_state_repository.dart';

const _kTeamA = Color(0xFFFF6B35);
const _kTeamB = Color(0xFF4FC3F7);

// ── PKBar: يراقب Provider فقط، بدون Timer ────────────────────────────────────
class PKBar extends ConsumerWidget {
  const PKBar({super.key, required this.roomId, this.isHost = false});
  final String roomId;
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pk = ref.watch(pkStateProvider(roomId)).valueOrNull;
    if (pk == null || !pk.active) return const SizedBox.shrink();
    return _PKBarContent(pk: pk, roomId: roomId, isHost: isHost);
  }
}

// ── _PKBarContent: يحسب المؤقت العكسي بـ Timer، بدون ref.watch ──────────────
class _PKBarContent extends StatefulWidget {
  const _PKBarContent({
    required this.pk,
    required this.roomId,
    required this.isHost,
  });
  final PKState pk;
  final String roomId;
  final bool isHost;

  @override
  State<_PKBarContent> createState() => _PKBarContentState();
}

class _PKBarContentState extends State<_PKBarContent> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.pk.endTime != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.0', '')}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '')}K';
    return '$n';
  }

  String _fmtTime(DateTime endTime) {
    final diff = endTime.difference(DateTime.now());
    if (diff.isNegative) return 'انتهى';
    final h = diff.inHours;
    final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final pk = widget.pk;
    final timeUp = pk.timeUp;
    final aFrac = pk.teamAFraction;
    final timeStr = pk.endTime != null ? _fmtTime(pk.endTime!) : '';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kTeamA.withAlpha(30),
            Colors.black.withAlpha(180),
            _kTeamB.withAlpha(30),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Row(
            children: [
              _TeamBadge(label: '🔥 أ', color: _kTeamA),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⚔️ ', style: TextStyle(fontSize: 12)),
                  Text(
                    timeUp ? '⏰ انتهى' : timeStr,
                    style: TextStyle(
                      color: timeUp ? AppColors.error : Colors.white70,
                      fontSize: 11,
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.isHost && timeUp) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => RoomStateRepository().stopPK(widget.roomId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withAlpha(80)),
                        ),
                        child: const Text('إغلاق', style: TextStyle(
                          color: AppColors.error, fontSize: 9,
                          fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                        )),
                      ),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              _TeamBadge(label: 'ب 💙', color: _kTeamB),
            ],
          ),

          const SizedBox(height: 6),

          // ── Score + Bar ─────────────────────────────────────────────────
          Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(_fmt(pk.teamA),
                    style: const TextStyle(color: _kTeamA, fontSize: 13,
                        fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Container(height: 11, color: _kTeamB.withAlpha(90)),
                      FractionallySizedBox(
                        widthFactor: aFrac,
                        child: Container(height: 11, color: _kTeamA.withAlpha(200)),
                      ),
                      Positioned.fill(
                        child: Center(
                          child: Container(width: 1.5, color: Colors.white.withAlpha(60)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 40,
                child: Text(_fmt(pk.teamB),
                    style: const TextStyle(color: _kTeamB, fontSize: 13,
                        fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
                    textAlign: TextAlign.center),
              ),
            ],
          ),

          if (timeUp) ...[
            const SizedBox(height: 4),
            Text(
              pk.teamA > pk.teamB ? '🏆 فاز فريق أ!' :
              pk.teamB > pk.teamA ? '🏆 فاز فريق ب!' : '🤝 تعادل!',
              style: const TextStyle(color: Color(0xFFFFD700),
                  fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'Cairo'),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label, style: TextStyle(
        color: color, fontSize: 11,
        fontWeight: FontWeight.w800, fontFamily: 'Cairo',
      )),
    );
  }
}
