import 'package:flutter/material.dart';

class DiceRulesDialog extends StatelessWidget {
  const DiceRulesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: const Color(0xFF1A3A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x60FFD700), blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: const Center(
                child: Text('Rules',
                  style: TextStyle(
                    color: Color(0xFFFFD700), fontSize: 20,
                    fontWeight: FontWeight.w900, letterSpacing: 1,
                  )),
              ),
            ),

            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _RuleCard(
                    title: '١. صغير',
                    color: Color(0xFF42A5F5),
                    lines: [
                      'الاحتمالات ×2.',
                      'يكون مجموع النقاط من 4 إلى 10 شاملًا،',
                      'باستثناء الثلاثيات.',
                    ],
                  ),
                  SizedBox(height: 12),
                  _RuleCard(
                    title: '٢. كبير',
                    color: Color(0xFFEF5350),
                    lines: [
                      'الاحتمالات ×2.',
                      'يكون مجموع النقاط من 11 إلى 17 شاملًا،',
                      'باستثناء الثلاثيات.',
                    ],
                  ),
                  SizedBox(height: 12),
                  _RuleCard(
                    title: '٣. ثلاثية',
                    color: Color(0xFFFFD700),
                    lines: [
                      'الاحتمالات ×30.',
                      'تظهر عندما تكون النردات الثلاثة متطابقة.',
                    ],
                  ),
                ],
              ),
            ),

            // Close button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('حسناً',
                      style: TextStyle(
                        color: Colors.black87, fontSize: 15,
                        fontWeight: FontWeight.w900, fontFamily: 'Cairo',
                      )),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.title, required this.color, required this.lines});
  final String       title;
  final Color        color;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(title, style: TextStyle(color: color, fontFamily: 'Cairo',
              fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          ...lines.map((l) => Text(l,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white70, fontFamily: 'Cairo',
              fontSize: 13, height: 1.6,
            ))),
        ],
      ),
    );
  }
}
