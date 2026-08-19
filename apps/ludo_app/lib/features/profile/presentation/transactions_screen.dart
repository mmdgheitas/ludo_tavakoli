import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ludo_app/core/providers.dart';
import 'package:ludo_app/core/theme/app_theme.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});
  Future<List<dynamic>> _load(WidgetRef ref) async => (await ref.read(apiClientProvider).dio.get<List<dynamic>>('/wallet/transactions')).data ?? const [];
  @override Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('تاریخچه تراکنش‌ها')),
    body: FutureBuilder<List<dynamic>>(future: _load(ref), builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      final items = snapshot.data ?? const [];
      if (items.isEmpty) return const Center(child: Text('تراکنشی ثبت نشده است.'));
      return ListView.separated(padding: const EdgeInsets.all(18), itemCount: items.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (context, index) {
        final item = Map<String, dynamic>.from(items[index] as Map); final amount = (item['amount'] as num?)?.toInt() ?? 0;
        return ListTile(leading: CircleAvatar(backgroundColor: (amount >= 0 ? AppColors.turquoise : AppColors.coral).withValues(alpha: .15), child: Icon(amount >= 0 ? Icons.add : Icons.remove, color: amount >= 0 ? AppColors.turquoise : AppColors.coral)), title: Text(item['type']?.toString() ?? 'تراکنش'), subtitle: Text(DateFormat('yyyy/MM/dd – HH:mm').format(DateTime.parse(item['createdAt'] as String).toLocal())), trailing: Text('${amount > 0 ? '+' : ''}$amount', style: TextStyle(fontWeight: FontWeight.w900, color: amount >= 0 ? AppColors.turquoise : AppColors.coral)));
      });
    }),
  );
}
