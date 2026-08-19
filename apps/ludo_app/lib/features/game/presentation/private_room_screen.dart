import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/providers.dart';
import 'package:ludo_app/core/theme/app_theme.dart';
import 'package:ludo_app/features/game/presentation/online_match_screen.dart';

class PrivateRoomScreen extends ConsumerStatefulWidget {
  const PrivateRoomScreen({super.key});
  @override
  ConsumerState<PrivateRoomScreen> createState() => _PrivateRoomScreenState();
}

class _PrivateRoomScreenState extends ConsumerState<PrivateRoomScreen> {
  final _codeController = TextEditingController();
  int _playerCount = 2;
  bool _loading = false;
  String? _createdCode;
  String? _createdGameId;

  @override
  void dispose() { _codeController.dispose(); super.dispose(); }

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      final response = await ref.read(apiClientProvider).dio.post<Map<String, dynamic>>('/games/rooms', data: {'mode': _playerCount == 4 ? 'ONLINE_4P' : 'ONLINE_2P'});
      setState(() {
        _createdCode = response.data?['roomCode'] as String?;
        _createdGameId = response.data?['id'] as String?;
      });
    } catch (_) { _error('ساخت اتاق انجام نشد.'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _join() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length < 6) return _error('کد اتاق را کامل وارد کنید.');
    setState(() => _loading = true);
    try {
      final response = await ref.read(apiClientProvider).dio.post<Map<String, dynamic>>('/games/rooms/join', data: {'roomCode': code});
      final data = response.data!;
      final mode = data['mode'] as String;
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OnlineMatchScreen(gameId: data['gameId'] as String, playerCount: mode == 'ONLINE_4P' ? 4 : 2)));
    } catch (_) { _error('اتاق پیدا نشد یا ظرفیت آن کامل است.'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  void _error(String message) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('اتاق خصوصی')),
    body: ListView(padding: const EdgeInsets.all(22), children: [
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('ساخت اتاق', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        SegmentedButton<int>(segments: const [ButtonSegment(value: 2, label: Text('۲ نفره'), icon: Icon(Icons.people)), ButtonSegment(value: 4, label: Text('۴ نفره'), icon: Icon(Icons.groups))], selected: {_playerCount}, onSelectionChanged: (value) => setState(() => _playerCount = value.first)),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: _loading ? null : _create, icon: const Icon(Icons.add_circle_outline), label: const Text('ساخت کد دعوت')),
        if (_createdCode != null) ...[
          const SizedBox(height: 18),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(16)), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('کد دعوت', style: TextStyle(color: AppColors.muted, fontSize: 11)), Text(_createdCode!, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 5))])),
            IconButton(onPressed: () { Clipboard.setData(ClipboardData(text: _createdCode!)); _error('کد دعوت کپی شد.'); }, icon: const Icon(Icons.copy_rounded)),
          ])),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: _createdGameId == null ? null : () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => OnlineMatchScreen(gameId: _createdGameId!, playerCount: _playerCount))), child: const Text('ورود و انتظار برای دوستان')),
        ],
      ]))),
      const SizedBox(height: 18),
      Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('پیوستن با کد', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        TextField(controller: _codeController, textCapitalization: TextCapitalization.characters, maxLength: 8, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, letterSpacing: 4), decoration: const InputDecoration(labelText: 'کد دعوت', counterText: '', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: _loading ? null : _join, icon: const Icon(Icons.login_rounded), label: const Text('پیوستن به اتاق')),
      ]))),
    ]),
  );
}
