import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'models/dice_game_models.dart';
import 'providers/dice_game_providers.dart';
import 'repositories/dice_game_repository.dart';
import 'widgets/dice_cup_widget.dart';
import 'widgets/dice_bet_area.dart';
import 'widgets/dice_chip_selector.dart';
import 'widgets/dice_result_overlay.dart';
import 'widgets/dice_history_dialog.dart';
import 'widgets/dice_rules_dialog.dart';
import 'widgets/dice_top_players.dart';
import 'widgets/dice_face_painter.dart';

class DiceGamePanel extends ConsumerStatefulWidget {
  const DiceGamePanel({super.key, required this.roomId, required this.onClose});
  final String       roomId;
  final VoidCallback onClose;

  @override
  ConsumerState<DiceGamePanel> createState() => _DiceGamePanelState();
}

class _DiceGamePanelState extends ConsumerState<DiceGamePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<Offset>   _slideAnim;
  final _repo = DiceGameRepository();

  int? _prevRoundId;
  int  _myWin = 0;
  int? _claimedForRound;  // prevent double-claiming payout
  final List<_FlyingBetData> _flyingBets = [];

  // Local countdown — driven by a simple Timer.periodic + setState so the
  // display is guaranteed to tick every second regardless of Riverpod state
  // equality checks or notifier lifecycle edge cases.
  int    _countdown = 0;
  Timer? _cdTimer;

  ProviderSubscription<AsyncValue<DiceRound?>>? _roundSub;
  Timer? _watchdog;  // periodic self-heal

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();

    // Heal stuck states on open
    _repo.ensureRound(widget.roomId);

    // Listen for round changes (payout + UI reset only)
    _roundSub = ref.listenManual(
      diceRoundProvider(widget.roomId),
      (_, next) => _onRoundChanged(next.valueOrNull),
      fireImmediately: true,
    );

    // Local countdown ticker — reads bettingStartedAt every second and calls
    // setState so the display updates even if Riverpod misses the tick.
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final round = ref.read(diceRoundProvider(widget.roomId)).valueOrNull;
      final rem   = round?.phase == DiceRoundPhase.betting
          ? round!.secsRemaining()
          : 0;
      if (_countdown != rem) setState(() => _countdown = rem);
    });

    // Periodic watchdog: if a phase is stuck, ensureRound heals it
    _watchdog = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) _repo.ensureRound(widget.roomId);
    });
  }

  Future<void> _onRoundChanged(DiceRound? r) async {
    if (r == null || !mounted) return;

    // Update countdown immediately so there's no 1-second delay on first data
    final rem = r.phase == DiceRoundPhase.betting ? r.secsRemaining() : 0;
    if (_countdown != rem) setState(() => _countdown = rem);

    // New round — save bet for repeat, reset win display
    if (_prevRoundId != null && r.roundId != _prevRoundId) {
      final prev = ref.read(diceMyBetProvider(widget.roomId)).valueOrNull;
      if (prev != null && prev.total > 0) {
        ref.read(dicePreviousBetProvider.notifier).state = prev;
      }
      if (mounted) setState(() => _myWin = 0);
    }
    _prevRoundId = r.roundId;

    // Claim payout once when result arrives
    if (r.phase == DiceRoundPhase.result &&
        r.winner != null &&
        _claimedForRound != r.roundId) {
      _claimedForRound = r.roundId;
      final won = await _repo.claimPayout(widget.roomId, r.winner!);
      if (mounted && won > 0) setState(() => _myWin = won);
    }
  }

  @override
  void dispose() {
    _cdTimer?.cancel();
    _watchdog?.cancel();
    _roundSub?.close();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _slideCtrl.reverse();
    widget.onClose();
  }

  Future<void> _placeBet(DiceBetType type) async {
    final chip = ref.read(diceChipProvider);
    final err  = await _repo.placeBet(
      roomId: widget.roomId, type: type, amount: chip);
    if (err != null && mounted) { _showToast(err); return; }
    if (mounted) {
      setState(() => _flyingBets.add(
          _FlyingBetData(key: UniqueKey(), amount: chip, type: type)));
    }
  }

  Future<void> _repeatBet() async {
    final prev = ref.read(dicePreviousBetProvider);
    if (prev == null) { _showToast('لا يوجد رهان سابق'); return; }

    final round = ref.read(diceRoundProvider(widget.roomId)).valueOrNull;
    if (round?.phase != DiceRoundPhase.betting) {
      _showToast('انتهى وقت الرهان'); return;
    }

    final total = prev.total;
    if (total <= 0) { _showToast('الرهان السابق فارغ'); return; }

    // Place each type
    if (prev.small > 0) {
      final e = await _repo.placeBet(roomId: widget.roomId, type: DiceBetType.small, amount: prev.small);
      if (e != null && mounted) { _showToast(e); return; }
    }
    if (prev.big > 0) {
      final e = await _repo.placeBet(roomId: widget.roomId, type: DiceBetType.big, amount: prev.big);
      if (e != null && mounted) { _showToast(e); return; }
    }
    if (prev.triple > 0) {
      final e = await _repo.placeBet(roomId: widget.roomId, type: DiceBetType.triple, amount: prev.triple);
      if (e != null && mounted) { _showToast(e); return; }
    }
    _showToast('تم تكرار الرهان ✓');
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DiceHistoryDialog(roomId: widget.roomId),
    );
  }

  void _showRules() {
    showDialog(
      context: context,
      builder: (_) => const DiceRulesDialog(),
    );
  }

  String _fmtCoins(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}ك';
    return '$v';
  }

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Cairo')),
      backgroundColor: const Color(0xFF1B5E20),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final roundAsync = ref.watch(diceRoundProvider(widget.roomId));
    final myBetAsync = ref.watch(diceMyBetProvider(widget.roomId));
    // Keep watching diceCountdownProvider to keep the phase-transition orchestrator alive
    ref.watch(diceCountdownProvider(widget.roomId));
    final round  = roundAsync.valueOrNull;
    final coins  = ref.watch(diceUserCoinsProvider).valueOrNull ?? 0;

    // Filter stale bets from previous rounds — only show bet if its roundId matches current round
    final rawBet = myBetAsync.valueOrNull;
    final myBet  = (rawBet != null && rawBet.roundId == round?.roundId)
        ? rawBet
        : const DiceBet();

    // Use local _countdown (driven by _cdTimer + setState) for the display
    final canBet = round?.phase == DiceRoundPhase.betting && _countdown > 0;
    final isResult = round?.phase == DiceRoundPhase.result;
    final dice     = round?.dice ?? [];
    final winner   = round?.winner;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: SlideTransition(
      position: _slideAnim,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top:   BorderSide(color: Color(0xFF00BCD4), width: 3),
            left:  BorderSide(color: Color(0xFF00BCD4), width: 1),
            right: BorderSide(color: Color(0xFF00BCD4), width: 1),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
          // ── Casino table background ─────────────────────────────────────
          SvgPicture.asset(
            'assets/game-assets/ui/table-bg.svg',
            fit: BoxFit.cover,
          ),

          Column(
          children: [
            // ── Gold decorative strip ─────────────────────────────────────
            Container(
              height: 6,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6D4C00), Color(0xFFFFD700), Color(0xFFB8860B),
                           Color(0xFFFFD700), Color(0xFF6D4C00)],
                ),
              ),
            ),

            // ── Top row: history | timer+label | cup | controls ──────────
            SizedBox(
              height: 88,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // History button + last dice
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _IconBtn(
                          icon: Icons.history_rounded,
                          label: 'سجل',
                          onTap: _showHistory,
                        ),
                        if (round != null && round.lastResults.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          _LastResultDice(round.lastResults.first.dice),
                        ],
                      ],
                    ),
                    const SizedBox(width: 6),

                    // Phase label only (countdown moved to _CountdownBar above betting areas)
                    Text(
                      round?.phase == DiceRoundPhase.betting
                          ? 'ابدأ\nالرهان'
                          : round?.phase == DiceRoundPhase.rolling
                              ? 'قريباً'
                              : 'النتيجة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: round?.phase == DiceRoundPhase.betting
                            ? const Color(0xFFFFD700)
                            : Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Cairo',
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Cup — centered, takes remaining space
                    Expanded(
                      child: Center(
                        child: DiceCupWidget(
                          phase: round?.phase ?? DiceRoundPhase.betting,
                          dice:  dice,
                        ),
                      ),
                    ),

                    // Close + rules (right side)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _IconBtn(
                          icon: Icons.close_rounded,
                          label: '',
                          onTap: _close,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 6),
                        _IconBtn(
                          icon: Icons.help_outline_rounded,
                          label: 'قواعد',
                          onTap: _showRules,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Betting zones + top players ───────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 2, 6, 0),
                child: Row(
                  children: [
                    // Betting table
                    Expanded(
                      child: Column(
                        children: [
                          // ── Large countdown bar ─────────────────────────
                          _CountdownBar(
                              countdown: _countdown,
                              phase: round?.phase ?? DiceRoundPhase.betting),

                          // SMALL + BIG row
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: DiceBetArea(
                                    type:      DiceBetType.small,
                                    totalBets: round?.smallBets ?? 0,
                                    myBet:     myBet.small,
                                    canBet:    canBet,
                                    isWinner:  isResult && winner == DiceBetType.small,
                                    onTap:     () => _placeBet(DiceBetType.small),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: DiceBetArea(
                                    type:      DiceBetType.big,
                                    totalBets: round?.bigBets ?? 0,
                                    myBet:     myBet.big,
                                    canBet:    canBet,
                                    isWinner:  isResult && winner == DiceBetType.big,
                                    onTap:     () => _placeBet(DiceBetType.big),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 4),

                          // TRIPLE — centered square button
                          Center(
                            child: SizedBox.square(
                              dimension: 90,
                              child: _TripleButton(
                                totalBets: round?.tripleBets ?? 0,
                                myBet:     myBet.triple,
                                canBet:    canBet,
                                isWinner:  isResult && winner == DiceBetType.triple,
                                onTap:     () => _placeBet(DiceBetType.triple),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 6),

                    // Top 5 sidebar
                    DiceTopPlayers(roomId: widget.roomId),
                  ],
                ),
              ),
            ),

            // ── Balance + Chips + كرر ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(8, 3, 8, 6),
              decoration: const BoxDecoration(
                color: Color(0xFF154A15),
                border: Border(top: BorderSide(color: Colors.white10)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Balance row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 3),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          _fmtCoins(coins),
                          key: ValueKey(coins),
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Chips + كرر row
                  Row(
                    children: [
                      const Expanded(child: DiceChipSelector()),
                      const SizedBox(width: 8),
                      _TextBtn(label: 'كرر', icon: Icons.replay_rounded,
                          onTap: canBet ? _repeatBet : null),
                    ],
                  ),
                ],
              ),
            ),

          ],
          ),

          // ── Flying bet animations ──────────────────────────────────────
          ..._flyingBets.map((fb) => _FlyingBetWidget(
            key: fb.key,
            amount: fb.amount,
            type: fb.type,
            onDone: () { if (mounted) setState(() => _flyingBets.remove(fb)); },
          )),

          // ── Result overlay (centered on panel) ─────────────────────────
          if (isResult && dice.length == 3 && winner != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: DiceResultOverlay(
                    dice:   dice,
                    total:  round!.total ?? 0,
                    winner: winner,
                    myWin:  _myWin,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )); // Directionality
  }
}

// ── Small icon button ────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.label, required this.onTap,
      this.color = const Color(0xFFFFD700)});
  final IconData      icon;
  final String        label;
  final VoidCallback  onTap;
  final Color         color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(50),
            shape: BoxShape.circle,
            border: Border.all(color: color.withAlpha(80), width: 1),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        if (label.isNotEmpty)
          Text(label, style: TextStyle(
              color: color.withAlpha(200), fontSize: 8, fontFamily: 'Cairo')),
      ]),
    );
  }
}

// ── Last result dice (mini) ──────────────────────────────────────────────────
class _LastResultDice extends StatelessWidget {
  const _LastResultDice(this.dice);
  final List<int> dice;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: dice.map((v) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: DiceWidget(value: v, size: 18,
            borderColor: Colors.white24, borderWidth: 1,
            dotColor: Colors.white70, faceColor: const Color(0xFF2E7D32)),
      )).toList(),
    );
  }
}

// ── Text button ──────────────────────────────────────────────────────────────
class _TextBtn extends StatelessWidget {
  const _TextBtn({required this.label, required this.icon, required this.onTap});
  final String        label;
  final IconData      icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(60),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(
                color: Colors.white70, fontSize: 12, fontFamily: 'Cairo')),
          ]),
        ),
      ),
    );
  }
}

// ── Large countdown bar (above betting areas) ────────────────────────────────
class _CountdownBar extends StatelessWidget {
  const _CountdownBar({required this.countdown, required this.phase});
  final int            countdown;
  final DiceRoundPhase phase;

  @override
  Widget build(BuildContext context) {
    final isBetting = phase == DiceRoundPhase.betting;
    final urgent    = isBetting && countdown <= 5;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 40,
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(urgent ? 90 : 50),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: urgent
              ? const Color(0xFFFF5252).withAlpha(160)
              : const Color(0xFFFFD700).withAlpha(60),
          width: 1.2,
        ),
      ),
      child: Center(
        child: isBetting
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  '$countdown',
                  key: ValueKey(countdown),
                  style: TextStyle(
                    color: urgent ? const Color(0xFFFF5252) : Colors.white,
                    fontSize: urgent ? 26 : 24,
                    fontWeight: FontWeight.w900,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 6,
                          offset: Offset(0, 2)),
                    ],
                  ),
                ),
              )
            : Text(
                phase == DiceRoundPhase.rolling ? '🎲  تدحرج...' : '🏆  النتيجة',
                style: const TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                ),
              ),
      ),
    );
  }
}

// ── Triple square button ─────────────────────────────────────────────────────
class _TripleButton extends StatelessWidget {
  const _TripleButton({
    required this.totalBets,
    required this.myBet,
    required this.canBet,
    required this.isWinner,
    required this.onTap,
  });
  final int          totalBets;
  final int          myBet;
  final bool         canBet;
  final bool         isWinner;
  final VoidCallback onTap;

  static const _gold = Color(0xFFFFD700);

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}ك';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: canBet ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isWinner ? const Color(0xFF1A5C1A) : const Color(0xFF174E17),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isWinner ? _gold : _gold.withAlpha(80),
            width: isWinner ? 2.0 : 1.2,
          ),
          boxShadow: isWinner
              ? [BoxShadow(color: _gold.withAlpha(90), blurRadius: 12, spreadRadius: 1)]
              : [BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 4)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🪙', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_fmt(totalBets),
                    style: const TextStyle(
                      color: Colors.white60, fontSize: 9, fontFamily: 'Cairo')),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: _gold.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _gold.withAlpha(90), width: 1),
                  ),
                  child: const Text('×30',
                      style: TextStyle(
                          color: _gold, fontSize: 9, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text('ثلاثية',
                style: TextStyle(
                  color: isWinner ? _gold : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'Cairo',
                )),
            if (myBet > 0) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: _gold.withAlpha(28),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_fmt(myBet),
                    style: const TextStyle(
                        color: _gold,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cairo')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Flying bet data ──────────────────────────────────────────────────────────
class _FlyingBetData {
  final Key         key;
  final int         amount;
  final DiceBetType type;
  _FlyingBetData({required this.key, required this.amount, required this.type});
}

// ── Flying bet animation ("+100" rises from chip area to bet area) ────────────
class _FlyingBetWidget extends StatefulWidget {
  const _FlyingBetWidget({
    super.key,
    required this.amount,
    required this.type,
    required this.onDone,
  });
  final int          amount;
  final DiceBetType  type;
  final VoidCallback onDone;

  @override
  State<_FlyingBetWidget> createState() => _FlyingBetWidgetState();
}

class _FlyingBetWidgetState extends State<_FlyingBetWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _rise;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _rise = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 68),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_ctrl);
    _ctrl.forward().whenComplete(() { if (mounted) widget.onDone(); });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}م';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}ك';
    return '$v';
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final double xFrac = switch (widget.type) {
      DiceBetType.small  => 0.20,
      DiceBetType.big    => 0.62,
      DiceBetType.triple => 0.44,
    };
    final Color chipColor = switch (widget.type) {
      DiceBetType.small  => const Color(0xFF42A5F5),
      DiceBetType.big    => const Color(0xFFEF5350),
      DiceBetType.triple => const Color(0xFFFFD700),
    };

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Positioned(
        left: screenW * xFrac - 22,
        bottom: 55 + _rise.value * 180,
        child: IgnorePointer(
          child: Opacity(
            opacity: _fade.value.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.75 + 0.25 * _rise.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withAlpha(230),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(color: chipColor.withAlpha(130), blurRadius: 8),
                  ],
                ),
                child: Text(
                  '+${_fmt(widget.amount)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
