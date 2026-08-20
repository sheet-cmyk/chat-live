import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/repositories/admin_repository.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _search = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A0A2E),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text('لوحة الإدارة', style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          indicatorColor: Colors.amber,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700),
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded, size: 18), text: 'المستخدمون'),
            Tab(icon: Icon(Icons.meeting_room_rounded, size: 18), text: 'الغرف'),
          ],
        ),
      ),
      body: Column(
        children: [
          const _MyBalanceSection(),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _UsersTab(search: _searchText, searchCtrl: _search, onSearch: (v) => setState(() => _searchText = v)),
                const _RoomsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── رصيد الإدارة الخاص ────────────────────────────────────────────────────────
class _MyBalanceSection extends ConsumerWidget {
  const _MyBalanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(balanceStreamProvider);
    final coins = (balance.valueOrNull?['coins'] as num?)?.toInt() ?? 0;
    final diamonds = (balance.valueOrNull?['diamonds'] as num?)?.toInt() ?? 0;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary.withAlpha(60), AppColors.accent.withAlpha(40)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(80)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💼 رصيدك الشخصي', style: TextStyle(color: Colors.amber, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _BalanceTile(
                  icon: Icons.monetization_on_rounded,
                  color: Colors.amber,
                  label: 'عملات ذهبية',
                  value: coins,
                  onAdd: (amount) async {
                    await AdminRepository().giveCoins(uid, amount);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('✅ تم إضافة $amount عملة لرصيدك', style: const TextStyle(fontFamily: 'Cairo')),
                        backgroundColor: Colors.green,
                      ));
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BalanceTile(
                  icon: Icons.diamond_rounded,
                  color: Colors.cyanAccent,
                  label: 'ماس',
                  value: diamonds,
                  onAdd: (amount) async {
                    await AdminRepository().giveDiamonds(uid, amount);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('✅ تم إضافة $amount ماسة لرصيدك', style: const TextStyle(fontFamily: 'Cairo')),
                        backgroundColor: Colors.green,
                      ));
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.icon, required this.color, required this.label, required this.value, required this.onAdd});
  final IconData icon;
  final Color color;
  final String label;
  final int value;
  final Future<void> Function(int amount) onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text('$value', style: TextStyle(color: color, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 10)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _MiniBtn(label: '+1K', color: color, onTap: () => onAdd(1000))),
            const SizedBox(width: 4),
            Expanded(child: _MiniBtn(label: '+10K', color: color, onTap: () => onAdd(10000))),
            const SizedBox(width: 4),
            Expanded(child: _MiniBtn(label: '+100K', color: color, onTap: () => onAdd(100000))),
          ],
        ),
      ],
    );
  }
}

class _MiniBtn extends StatelessWidget {
  const _MiniBtn({required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: color.withAlpha(25), border: Border.all(color: color.withAlpha(80)), borderRadius: BorderRadius.circular(6)),
        child: Center(child: Text(label, style: TextStyle(color: color, fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.bold))),
      ),
    );
  }
}

// ── Users Tab ─────────────────────────────────────────────────────────────────

class _UsersTab extends StatelessWidget {
  const _UsersTab({required this.search, required this.searchCtrl, required this.onSearch});
  final String search;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: searchCtrl,
            style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
            decoration: InputDecoration(
              hintText: 'بحث بالاسم أو رقم الهاتف...',
              hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'Cairo'),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
              suffixIcon: search.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear, color: Colors.white38), onPressed: () { searchCtrl.clear(); onSearch(''); })
                  : null,
              filled: true,
              fillColor: Colors.white10,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: onSearch,
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: AdminRepository().watchUsers(search: search),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.amber));
              }
              final users = snap.data ?? [];
              if (users.isEmpty) {
                return const Center(child: Text('لا يوجد مستخدمون', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo')));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, i) => _UserTile(user: users[i]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final name = user['displayName'] as String? ?? 'مستخدم';
    final avatar = user['photoURL'] as String?;
    final coins = (user['coins'] as num?)?.toInt() ?? 0;
    final diamonds = (user['diamonds'] as num?)?.toInt() ?? 0;
    final isBanned = user['isBanned'] == true;
    final uid = user['uid'] as String;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primary.withAlpha(60),
        backgroundImage: avatar != null ? NetworkImage(avatar) : null,
        child: avatar == null ? Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
      ),
      title: Row(
        children: [
          Flexible(child: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
          if (isBanned) ...[
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red.withAlpha(40), borderRadius: BorderRadius.circular(8)), child: const Text('محظور', style: TextStyle(color: Colors.red, fontSize: 10, fontFamily: 'Cairo'))),
          ],
        ],
      ),
      subtitle: Row(
        children: [
          const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 13),
          Text(' $coins  ', style: const TextStyle(color: Colors.amber, fontSize: 11, fontFamily: 'Cairo')),
          const Icon(Icons.diamond_rounded, color: Colors.cyanAccent, size: 13),
          Text(' $diamonds', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontFamily: 'Cairo')),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert_rounded, color: Colors.white54),
        onPressed: () => _showUserActions(context, uid, name, isBanned, coins, diamonds),
      ),
      onTap: () => _showUserActions(context, uid, name, isBanned, coins, diamonds),
    );
  }

  void _showUserActions(BuildContext context, String uid, String name, bool isBanned, int currentCoins, int currentDiamonds) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A0A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _UserActionsSheet(uid: uid, name: name, isBanned: isBanned, currentCoins: currentCoins, currentDiamonds: currentDiamonds),
    );
  }
}

class _UserActionsSheet extends StatefulWidget {
  const _UserActionsSheet({required this.uid, required this.name, required this.isBanned, required this.currentCoins, required this.currentDiamonds});
  final String uid, name;
  final bool isBanned;
  final int currentCoins, currentDiamonds;

  @override
  State<_UserActionsSheet> createState() => _UserActionsSheetState();
}

class _UserActionsSheetState extends State<_UserActionsSheet> {
  bool _loading = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم بنجاح', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 12, left: 16, right: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Text(widget.name, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('UID: ${widget.uid}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on_rounded, color: Colors.amber, size: 14),
              Text(' ${widget.currentCoins}  ', style: const TextStyle(color: Colors.amber, fontFamily: 'Cairo', fontSize: 12)),
              const Icon(Icons.diamond_rounded, color: Colors.cyanAccent, size: 14),
              Text(' ${widget.currentDiamonds}', style: const TextStyle(color: Colors.cyanAccent, fontFamily: 'Cairo', fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: Colors.amber))
          else ...[
            // ── Coins Section ──────────────────────
            const Align(alignment: Alignment.centerRight, child: Text('🪙 العملات الذهبية', style: TextStyle(color: Colors.amber, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13))),
            const SizedBox(height: 8),
            Row(
              children: [
                _QuickBtn(label: '+1,000', color: Colors.amber, onTap: () => _run(() => AdminRepository().giveCoins(widget.uid, 1000))),
                const SizedBox(width: 8),
                _QuickBtn(label: '+10,000', color: Colors.amber, onTap: () => _run(() => AdminRepository().giveCoins(widget.uid, 10000))),
                const SizedBox(width: 8),
                _QuickBtn(label: '+100,000', color: Colors.amber, onTap: () => _run(() => AdminRepository().giveCoins(widget.uid, 100000))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _QuickBtn(label: '+500,000', color: Colors.orange, onTap: () => _run(() => AdminRepository().giveCoins(widget.uid, 500000))),
                const SizedBox(width: 8),
                _QuickBtn(label: 'مبلغ محدد', color: Colors.orange.shade700, icon: Icons.edit_rounded, onTap: () => _showCustomAmount(isCoins: true)),
                const SizedBox(width: 8),
                _QuickBtn(label: 'ضبط الرصيد', color: Colors.deepOrange, icon: Icons.tune_rounded, onTap: () => _showSetAmount(isCoins: true)),
              ],
            ),
            const SizedBox(height: 14),
            // ── Diamonds Section ──────────────────────
            const Align(alignment: Alignment.centerRight, child: Text('💎 الماس', style: TextStyle(color: Colors.cyanAccent, fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13))),
            const SizedBox(height: 8),
            Row(
              children: [
                _QuickBtn(label: '+100', color: Colors.cyanAccent, onTap: () => _run(() => AdminRepository().giveDiamonds(widget.uid, 100))),
                const SizedBox(width: 8),
                _QuickBtn(label: '+500', color: Colors.cyanAccent, onTap: () => _run(() => AdminRepository().giveDiamonds(widget.uid, 500))),
                const SizedBox(width: 8),
                _QuickBtn(label: '+1,000', color: Colors.cyanAccent, onTap: () => _run(() => AdminRepository().giveDiamonds(widget.uid, 1000))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _QuickBtn(label: '+5,000', color: Colors.cyan, onTap: () => _run(() => AdminRepository().giveDiamonds(widget.uid, 5000))),
                const SizedBox(width: 8),
                _QuickBtn(label: 'مبلغ محدد', color: Colors.cyan.shade700, icon: Icons.edit_rounded, onTap: () => _showCustomAmount(isCoins: false)),
                const SizedBox(width: 8),
                _QuickBtn(label: 'ضبط الرصيد', color: Colors.teal, icon: Icons.tune_rounded, onTap: () => _showSetAmount(isCoins: false)),
              ],
            ),
            const SizedBox(height: 14),
            // ── Ban Section ──────────────────────────
            const Divider(color: Colors.white10),
            const SizedBox(height: 6),
            if (widget.isBanned)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.lock_open_rounded, size: 18),
                  label: const Text('رفع الحظر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  onPressed: () => _run(() => AdminRepository().unbanUser(widget.uid)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.block_rounded, size: 18),
                  label: const Text('حظر المستخدم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  onPressed: () => _showBanDialog(),
                ),
              ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showCustomAmount({required bool isCoins}) async {
    final ctrl = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A2E),
        title: Text(isCoins ? 'أضف عملات ذهبية' : 'أضف ماس', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo')),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'الكمية',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: Icon(isCoins ? Icons.monetization_on_rounded : Icons.diamond_rounded, color: isCoins ? Colors.amber : Colors.cyanAccent),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: isCoins ? Colors.amber : Colors.cyanAccent)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isCoins ? Colors.amber : Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)),
            child: const Text('إضافة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result != null && result > 0) {
      _run(() => isCoins ? AdminRepository().giveCoins(widget.uid, result) : AdminRepository().giveDiamonds(widget.uid, result));
    }
  }

  void _showSetAmount({required bool isCoins}) async {
    final ctrl = TextEditingController(text: isCoins ? widget.currentCoins.toString() : widget.currentDiamonds.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A2E),
        title: Text(isCoins ? 'ضبط رصيد العملات' : 'ضبط رصيد الماس', style: const TextStyle(color: Colors.white, fontFamily: 'Cairo')),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'الرصيد الجديد',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: Icon(isCoins ? Icons.monetization_on_rounded : Icons.diamond_rounded, color: isCoins ? Colors.amber : Colors.cyanAccent),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: isCoins ? Colors.amber : Colors.cyanAccent)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, int.tryParse(ctrl.text)),
            child: const Text('ضبط', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result != null) {
      _run(() => isCoins ? AdminRepository().setCoins(widget.uid, result) : AdminRepository().setDiamonds(widget.uid, result));
    }
  }

  void _showBanDialog() async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A2E),
        title: const Text('تأكيد الحظر', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('هل تريد حظر "${widget.name}"؟', style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
              decoration: const InputDecoration(
                hintText: 'سبب الحظر...',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.red)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حظر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      _run(() => AdminRepository().banUser(widget.uid, ctrl.text.trim()));
    }
  }
}

class _QuickBtn extends StatelessWidget {
  const _QuickBtn({required this.label, required this.color, required this.onTap, this.icon});
  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            border: Border.all(color: color.withAlpha(100)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, color: color, size: 12), const SizedBox(width: 3)],
              Text(label, style: TextStyle(color: color, fontSize: 11, fontFamily: 'Cairo', fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rooms Tab ─────────────────────────────────────────────────────────────────

class _RoomsTab extends StatelessWidget {
  const _RoomsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AdminRepository().watchRooms(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.amber));
        }
        final rooms = snap.data ?? [];
        if (rooms.isEmpty) {
          return const Center(child: Text('لا توجد غرف', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo')));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rooms.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
          itemBuilder: (context, i) => _RoomTile(room: rooms[i]),
        );
      },
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room});
  final Map<String, dynamic> room;

  @override
  Widget build(BuildContext context) {
    final name = room['name'] as String? ?? 'غرفة';
    final host = room['hostName'] as String? ?? 'مجهول';
    final online = (room['onlineCount'] as num?)?.toInt() ?? 0;
    final roomId = room['roomId'] as String;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [AppColors.primary.withAlpha(200), AppColors.accent.withAlpha(200)]),
        ),
        child: const Icon(Icons.meeting_room_rounded, color: Colors.white, size: 22),
      ),
      title: Text(name, style: const TextStyle(color: Colors.white, fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis),
      subtitle: Text('المضيف: $host  |  $online متصل', style: const TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.airline_seat_recline_normal_rounded, color: Colors.orange, size: 20),
            tooltip: 'تفريغ المقاعد',
            onPressed: () => _clearSeats(context, roomId, name),
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
            tooltip: 'حذف الغرفة',
            onPressed: () => _deleteRoom(context, roomId, name),
          ),
        ],
      ),
    );
  }

  void _deleteRoom(BuildContext context, String roomId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A2E),
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white, fontFamily: 'Cairo')),
        content: Text('هل تريد حذف غرفة "$name"؟', style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      try {
        await AdminRepository().deleteRoom(roomId);
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم حذف الغرفة', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
      }
    }
  }

  void _clearSeats(BuildContext context, String roomId, String name) async {
    try {
      await AdminRepository().clearAllSeats(roomId);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم تفريغ المقاعد', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.green));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: Colors.red));
    }
  }
}
