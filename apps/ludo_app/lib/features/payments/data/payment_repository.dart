import 'package:flutter/services.dart';
import 'package:ludo_app/core/network/api_client.dart';

/// Store SDKs are isolated behind this adapter. Android product flavors provide
/// Bazaar and Myket implementations for the same MethodChannel contract.
class PaymentRepository {
  PaymentRepository(this._api, {MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('ir.manche.game/billing');

  final ApiClient _api;
  final MethodChannel _channel;

  Future<void> purchase({required String provider, required String sku}) async {
    final receipt = await _channel.invokeMapMethod<String, dynamic>('purchase', {
      'provider': provider,
      'sku': sku,
    });
    if (receipt == null || receipt['purchaseToken'] == null || receipt['transactionId'] == null) {
      throw PlatformException(code: 'invalid_receipt', message: 'فروشگاه رسید معتبری برنگرداند.');
    }
    // Entitlements are not granted on-device. The backend verifies the receipt,
    // applies idempotency, and only then updates the player's account.
    await _api.dio.post<void>('/payments/verify', data: {
      'provider': provider,
      'productSku': sku,
      'purchaseToken': receipt['purchaseToken'],
      'providerTransactionId': receipt['transactionId'],
    });
  }

  Future<List<Map<String, dynamic>>> history() async {
    final response = await _api.dio.get<List<dynamic>>('/payments');
    return (response.data ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
