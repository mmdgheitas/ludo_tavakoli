import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ludo_app/core/providers.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});
  @override ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}
class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  late Future<List<Map<String, dynamic>>> future;
  @override void initState() { super.initState(); future = ref.read(authRepositoryProvider).sessions(); }
  Future<void> revoke(String id) async { await ref.read(authRepositoryProvider).revokeSession(id); setState(() => future = ref.read(authRepositoryProvider).sessions()); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('نشست‌های فعال')),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: future, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      final sessions = snapshot.data ?? const [];
      if (sessions.isEmpty) return const Center(child: Text('نشست فعالی وجود ندارد.'));
      return ListView.separated(padding: const EdgeInsets.all(16), itemCount: sessions.length, separatorBuilder: (_, __) => const Divider(), itemBuilder: (context, index) {
        final session = sessions[index]; final lastUsed = DateTime.tryParse(session['lastUsedAt']?.toString() ?? '');
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.devices)),
          title: Text(session['userAgent']?.toString() ?? 'دستگاه ناشناس', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${session['ipAddress'] ?? 'IP ناشناس'}${lastUsed == null ? '' : ' • ${DateFormat('yyyy/MM/dd HH:mm').format(lastUsed.toLocal())}'}'),
          trailing: IconButton(tooltip: 'خروج این دستگاه', onPressed: () => revoke(session['id'] as String), icon: const Icon(Icons.logout)),
        );
      });
    }),
  );
}
