import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/network/api_client.dart';
import 'package:ludo_app/core/providers.dart';

class QuickChatOption {
  const QuickChatOption({required this.id, required this.text, this.emoji});
  final String id;
  final String text;
  final String? emoji;

  factory QuickChatOption.fromJson(Map<String, dynamic> json) => QuickChatOption(
        id: json['id'] as String,
        text: json['textFa'] as String,
        emoji: json['emoji'] as String?,
      );
}

final quickChatRepositoryProvider = Provider((ref) => QuickChatRepository(ref.watch(apiClientProvider)));
final quickChatOptionsProvider = FutureProvider<List<QuickChatOption>>((ref) => ref.watch(quickChatRepositoryProvider).list());

class QuickChatRepository {
  QuickChatRepository(this._client);
  final ApiClient _client;

  Future<List<QuickChatOption>> list() async {
    final response = await _client.dio.get<List<dynamic>>('/chat/messages');
    return (response.data ?? const [])
        .map((item) => QuickChatOption.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
