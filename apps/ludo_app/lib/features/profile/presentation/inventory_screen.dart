import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/providers.dart';
import 'package:ludo_app/core/theme/app_theme.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});
  @override ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  @override void initState() { super.initState(); _future = _load(); }
  Future<List<Map<String, dynamic>>> _load() async {
    final response = await ref.read(apiClientProvider).dio.get<List<dynamic>>('/shop/inventory');
    return (response.data ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
  Future<void> _equip(String itemId) async {
    await ref.read(apiClientProvider).dio.post<void>('/shop/equip', data: {'itemId': itemId});
    setState(() => _future = _load());
  }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('دارایی‌های من')),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: _future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: FilledButton.tonal(onPressed: () => setState(() => _future = _load()), child: const Text('تلاش دوباره')));
      final items = snapshot.data ?? const [];
      if (items.isEmpty) return const Center(child: Text('هنوز آیتمی خریداری نکرده‌اید.'));
      return ListView.separated(padding: const EdgeInsets.all(18), itemCount: items.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, index) {
        final inventory = items[index]; final item = Map<String, dynamic>.from(inventory['item'] as Map);
        final equipped = inventory['equipped'] == true;
        return Card(child: ListTile(leading: CircleAvatar(backgroundColor: AppColors.turquoise.withValues(alpha: .15), child: Icon(item['type'] == 'AVATAR' ? Icons.face : Icons.extension, color: AppColors.turquoise)), title: Text(item['nameFa']?.toString() ?? 'آیتم'), subtitle: Text('تعداد: ${inventory['quantity']}'), trailing: FilledButton.tonal(onPressed: equipped ? null : () => _equip(item['id'] as String), child: Text(equipped ? 'فعال' : 'انتخاب'))));
      });
    }),
  );
}
