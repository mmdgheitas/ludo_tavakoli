import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manche_irani/core/network/api_client.dart';
import 'package:manche_irani/core/providers.dart';
import 'package:uuid/uuid.dart';

class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.coinPrice,
  });

  final String id;
  final String name;
  final String type;
  final String? description;
  final int? coinPrice;

  factory ShopItem.fromJson(Map<String, dynamic> json) => ShopItem(
        id: json['id'] as String,
        name: json['nameFa'] as String,
        type: json['type'] as String,
        description: json['descriptionFa'] as String?,
        coinPrice: (json['coinPrice'] as num?)?.toInt(),
      );
}

final shopRepositoryProvider = Provider(
  (ref) => ShopRepository(ref.watch(apiClientProvider)),
);

final shopItemsProvider = FutureProvider<List<ShopItem>>(
  (ref) => ref.watch(shopRepositoryProvider).items(),
);

class ShopRepository {
  ShopRepository(this._client);
  final ApiClient _client;

  Future<List<ShopItem>> items() async {
    final response = await _client.dio.get<List<dynamic>>('/shop/items');
    return (response.data ?? const [])
        .map((item) => ShopItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> purchase(String itemId) => _client.dio.post<void>(
        '/shop/purchase',
        data: {'itemId': itemId, 'idempotencyKey': const Uuid().v4()},
      );
}
