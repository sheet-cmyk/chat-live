import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../providers/wallet_provider.dart';
import '../../data/models/transaction_model.dart';
import 'package:intl/intl.dart';

class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(balanceStreamProvider);
    final transactions = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('محفظتي', style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: balance.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('خطأ في تحميل المحفظة', style: TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'))),
        data: (bal) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _BalanceCard(coins: bal['coins'] ?? 0, diamonds: bal['diamonds'] ?? 0)),
            const SliverToBoxAdapter(child: _TopupSection()),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('سجل المعاملات', style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                )),
              ),
            ),
            transactions.when(
              loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )),
              ),
              error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              data: (list) => list.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: Text('لا توجد معاملات بعد', style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo')),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _TransactionTile(tx: list[i]),
                        childCount: list.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.coins, required this.diamonds});
  final int coins;
  final int diamonds;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(80), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          const Text('رصيدك', style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _BalanceItem(icon: '🪙', value: coins, label: 'عملة'),
              Container(width: 1, height: 50, color: Colors.white30),
              _BalanceItem(icon: '💎', value: diamonds, label: 'ماسة'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  const _BalanceItem({required this.icon, required this.value, required this.label});
  final String icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(NumberFormat('#,###').format(value), style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        )),
        Text(label, style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 11)),
      ],
    );
  }
}

class _TopupSection extends StatelessWidget {
  final List<_TopupPackage> packages = const [
    _TopupPackage(coins: 100, price: '0.99\$', emoji: '🪙'),
    _TopupPackage(coins: 500, price: '3.99\$', emoji: '🪙🪙'),
    _TopupPackage(coins: 1000, price: '6.99\$', emoji: '💰', isBest: true),
    _TopupPackage(coins: 5000, price: '29.99\$', emoji: '💎'),
  ];

  const _TopupSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('شحن العملات', style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFamily: 'Cairo',
          )),
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: packages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) => _TopupCard(pkg: packages[i]),
          ),
        ),
      ],
    );
  }
}

class _TopupPackage {
  final int coins;
  final String price;
  final String emoji;
  final bool isBest;
  const _TopupPackage({required this.coins, required this.price, required this.emoji, this.isBest = false});
}

class _TopupCard extends StatelessWidget {
  const _TopupCard({required this.pkg});
  final _TopupPackage pkg;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('قريباً — الشحن عبر متجر التطبيقات', style: TextStyle(fontFamily: 'Cairo'))),
      ),
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pkg.isBest ? AppColors.gold : AppColors.divider),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(pkg.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(height: 4),
                Text('${pkg.coins} 🪙', style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Cairo',
                )),
                const SizedBox(height: 2),
                Text(pkg.price, style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontFamily: 'Cairo',
                )),
              ],
            ),
            if (pkg.isBest)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('الأفضل', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.tx});
  final TransactionModel tx;

  @override
  Widget build(BuildContext context) {
    final isPositive = tx.isIncome;
    final sign = isPositive ? '+' : '-';
    final color = isPositive ? AppColors.success : AppColors.error;
    final icons = {
      TransactionType.topup: '💳',
      TransactionType.giftSent: '🎁',
      TransactionType.giftReceived: '🎁',
      TransactionType.reward: '🏆',
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(icons[tx.type] ?? '💫', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.description, style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 13, fontFamily: 'Cairo',
                ), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  DateFormat('d MMM · hh:mm a', 'ar').format(tx.createdAt),
                  style: const TextStyle(color: AppColors.textHint, fontSize: 11, fontFamily: 'Cairo'),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (tx.coinsChange != 0)
                Text('$sign${tx.coinsChange.abs()} 🪙', style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 13,
                )),
              if (tx.diamondsChange != 0)
                Text('$sign${tx.diamondsChange.abs()} 💎', style: TextStyle(
                  color: color, fontWeight: FontWeight.w700, fontFamily: 'Cairo', fontSize: 13,
                )),
            ],
          ),
        ],
      ),
    );
  }
}
