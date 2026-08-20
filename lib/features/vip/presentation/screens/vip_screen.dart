import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/models/vip_model.dart';

class VipScreen extends StatelessWidget {
  const VipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('عضوية VIP', style: TextStyle(
          color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w700,
        )),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ترويسة
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                Text('👑', style: TextStyle(fontSize: 48)),
                SizedBox(height: 8),
                Text('عضوية VIP', style: TextStyle(
                  color: Colors.white, fontFamily: 'Cairo', fontSize: 20, fontWeight: FontWeight.w800,
                )),
                SizedBox(height: 4),
                Text('مزايا حصرية لتجربة لا تُنسى', style: TextStyle(
                  color: Colors.white70, fontFamily: 'Cairo', fontSize: 13,
                )),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...VipLevel.levels.map((vip) => _VipCard(vip: vip)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.textHint, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الاشتراك عبر متجر التطبيقات — الدفع الآمن مضمون',
                    style: TextStyle(color: AppColors.textHint, fontFamily: 'Cairo', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VipCard extends StatelessWidget {
  const _VipCard({required this.vip});
  final VipLevel vip;

  @override
  Widget build(BuildContext context) {
    final isTop = vip.level >= 4;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTop ? AppColors.gold : AppColors.divider,
          width: isTop ? 1.5 : 1,
        ),
        boxShadow: isTop
            ? [BoxShadow(color: AppColors.gold.withAlpha(40), blurRadius: 12)]
            : null,
      ),
      child: ExpansionTile(
        leading: Text(vip.badge, style: const TextStyle(fontSize: 28)),
        title: Row(
          children: [
            Text(vip.name, style: const TextStyle(
              color: AppColors.textPrimary, fontFamily: 'Cairo', fontWeight: FontWeight.w700,
            )),
            if (isTop) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(6)),
                child: const Text('الأفضل', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
        subtitle: Text('${vip.priceUsd}\$ / شهر', style: const TextStyle(
          color: AppColors.primary, fontFamily: 'Cairo', fontWeight: FontWeight.w600,
        )),
        iconColor: AppColors.textHint,
        collapsedIconColor: AppColors.textHint,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: AppColors.divider),
                const SizedBox(height: 8),
                ...vip.perks.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                      const SizedBox(width: 8),
                      Text(p, style: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo', fontSize: 13)),
                    ],
                  ),
                )),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('قريباً — الدفع عبر المتجر', style: TextStyle(fontFamily: 'Cairo'))),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isTop ? AppColors.gold : AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('اشترك الآن — ${vip.priceUsd}\$', style: const TextStyle(
                      color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w700,
                    )),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
