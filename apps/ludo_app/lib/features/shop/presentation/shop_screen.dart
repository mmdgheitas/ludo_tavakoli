import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/providers.dart';
import 'package:ludo_app/core/theme/app_theme.dart';
import 'package:ludo_app/features/shop/data/shop_repository.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(shopItemsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('فروشگاه', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(shopItemsProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF513877), Color(0xFF31234C)]),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Row(children: [
                CircleAvatar(
                  radius: 29,
                  backgroundColor: Color(0x33F4B844),
                  child: Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 30),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('عضویت ویژه', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      Text('پاداش دو برابر و نشان اختصاصی', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left_rounded),
              ]),
            ),
            const SizedBox(height: 26),
            const Text('پیشنهادهای امروز', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            ...items.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (_, __) => [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(children: [
                      const Text('فهرست فروشگاه دریافت نشد.'),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => ref.invalidate(shopItemsProvider),
                        child: const Text('تلاش دوباره'),
                      ),
                    ]),
                  ),
                ),
              ],
              data: (products) => products
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ProductCard(
                        item: item,
                        onPurchase: item.coinPrice == null
                            ? null
                            : () async {
                                try {
                                  await ref.read(shopRepositoryProvider).purchase(item.id);
                                  await ref.read(currentUserProvider.notifier).restore();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('خرید با موفقیت انجام شد.')),
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('خرید انجام نشد؛ موجودی سکه را بررسی کنید.')),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item, required this.onPurchase});
  final ShopItem item;
  final VoidCallback? onPurchase;

  @override
  Widget build(BuildContext context) {
    final color = switch (item.type) {
      'FATTAH' => AppColors.coral,
      'AVATAR' => AppColors.gold,
      _ => AppColors.turquoise,
    };
    final icon = switch (item.type) {
      'FATTAH' => Icons.rocket_launch_rounded,
      'AVATAR' => Icons.face_6_rounded,
      _ => Icons.extension_rounded,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: color, size: 31),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(item.description ?? item.type, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: onPurchase,
            icon: const Icon(Icons.monetization_on_rounded, size: 17),
            label: Text(item.coinPrice?.toString() ?? '—'),
          ),
        ]),
      ),
    );
  }
}
