import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/providers.dart';
import 'package:ludo_app/core/theme/app_theme.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});
  @override ConsumerState<SupportScreen> createState() => _SupportScreenState();
}
class _SupportScreenState extends ConsumerState<SupportScreen> {
  final subject = TextEditingController(); final message = TextEditingController();
  late Future<List<dynamic>> future; bool sending = false;
  @override void initState() { super.initState(); future = load(); }
  Future<List<dynamic>> load() async => (await ref.read(apiClientProvider).dio.get<List<dynamic>>('/support/tickets')).data ?? const [];
  Future<void> send() async {
    if (subject.text.trim().length < 3 || message.text.trim().length < 10) return;
    setState(() => sending = true);
    try { await ref.read(apiClientProvider).dio.post<void>('/support/tickets', data: {'subject': subject.text.trim(), 'message': message.text.trim()}); subject.clear(); message.clear(); setState(() => future = load()); }
    finally { if (mounted) setState(() => sending = false); }
  }
  @override void dispose() { subject.dispose(); message.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('پشتیبانی')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('درخواست جدید', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 14),
        TextField(controller: subject, maxLength: 120, decoration: const InputDecoration(labelText: 'موضوع', border: OutlineInputBorder())), const SizedBox(height: 10),
        TextField(controller: message, minLines: 4, maxLines: 7, maxLength: 2000, decoration: const InputDecoration(labelText: 'شرح درخواست', border: OutlineInputBorder())),
        FilledButton.icon(onPressed: sending ? null : send, icon: const Icon(Icons.send), label: const Text('ارسال به پشتیبانی')),
      ]))),
      const SizedBox(height: 20), const Text('درخواست‌های من', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 10),
      FutureBuilder<List<dynamic>>(future: future, builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        return Column(children: (snapshot.data ?? const []).map((raw) { final item = Map<String, dynamic>.from(raw as Map); return Card(child: ExpansionTile(title: Text(item['subject'] as String), subtitle: Text(item['status'] as String, style: const TextStyle(color: AppColors.turquoise)), children: [Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(item['message'] as String), if (item['response'] != null) ...[const Divider(), const Text('پاسخ پشتیبانی', style: TextStyle(fontWeight: FontWeight.w900)), Text(item['response'] as String)] ]))])); }).toList());
      }),
    ]),
  );
}
