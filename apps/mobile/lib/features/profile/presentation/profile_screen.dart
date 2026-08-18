import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manche_irani/core/providers.dart';
import 'package:manche_irani/core/theme/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('پروفایل من', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Card(child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            CircleAvatar(radius: 36, backgroundColor: AppColors.turquoise, child: Text((user?.username ?? 'م').characters.first, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.username ?? 'بازیکن', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              Text(user?.isVip == true ? 'بازیکن ویژه' : 'بازیکن عادی', style: const TextStyle(color: AppColors.muted)),
            ])),
            IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined)),
          ]),
        )),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _Stat(label: 'سکه', value: '${user?.coinBalance ?? 0}', icon: Icons.monetization_on_rounded, color: AppColors.gold)),
          const SizedBox(width: 10),
          Expanded(child: _Stat(label: 'فتاح', value: '${user?.fattahBalance ?? 0}', icon: Icons.rocket_launch_rounded, color: AppColors.coral)),
        ]),
        const SizedBox(height: 24),
        Card(child: Column(children: [
          _Tile(icon: Icons.inventory_2_outlined, title: 'دارایی‌های من', onTap: () {}),
          const Divider(height: 1),
          _Tile(icon: Icons.receipt_long_outlined, title: 'تاریخچه تراکنش‌ها', onTap: () {}),
          const Divider(height: 1),
          _Tile(icon: Icons.settings_outlined, title: 'تنظیمات', onTap: () {}),
          const Divider(height: 1),
          _Tile(icon: Icons.support_agent_rounded, title: 'پشتیبانی', onTap: () {}),
        ])),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () => ref.read(currentUserProvider.notifier).logout(),
          icon: const Icon(Icons.logout_rounded, color: AppColors.coral),
          label: const Text('خروج از حساب', style: TextStyle(color: AppColors.coral)),
        ),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.icon, required this.color});
  final String label, value; final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Icon(icon, color: color), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 11))])])));
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.onTap});
  final IconData icon; final String title; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon, color: AppColors.turquoise), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), trailing: const Icon(Icons.chevron_left_rounded), onTap: onTap);
}
