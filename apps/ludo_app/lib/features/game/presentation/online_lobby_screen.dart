import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/theme/app_theme.dart';
import 'package:ludo_app/features/game/data/online_game_repository.dart';
import 'package:ludo_app/features/game/presentation/online_match_screen.dart';

class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key, required this.playerCount});
  final int playerCount;

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
  bool _entered = false;
  String get mode => widget.playerCount == 4 ? 'ONLINE_4P' : 'ONLINE_2P';

  void _enterMatch(MatchmakingState state) {
    if (_entered || state.gameId == null || !mounted) return;
    _entered = true;
    final count = state.playerCount ?? widget.playerCount;
    ref.read(matchmakingProvider.notifier).cancel(resetState: false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OnlineMatchScreen(gameId: state.gameId!, playerCount: count)),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(matchmakingProvider.notifier).join(mode: mode));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchmakingProvider);
    ref.listen<MatchmakingState>(matchmakingProvider, (_, next) {
      if (next.status == MatchmakingStatus.found && next.gameId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _enterMatch(next));
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Text('بازی آنلاین ${widget.playerCount} نفره'),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () { ref.read(matchmakingProvider.notifier).cancel(); Navigator.pop(context); }),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(children: [
            const Spacer(),
            Container(
              width: 150, height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.turquoise.withValues(alpha: .12), border: Border.all(color: AppColors.turquoise.withValues(alpha: .5), width: 2)),
              child: const Icon(Icons.casino_rounded, size: 72, color: AppColors.turquoise),
            ),
            const SizedBox(height: 34),
            Text(state.message, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('در انتظار ${widget.playerCount - 1} بازیکن دیگر', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 28),
            if (state.status == MatchmakingStatus.searching) const SizedBox(width: 180, child: LinearProgressIndicator()),
            if (state.status == MatchmakingStatus.error) FilledButton.tonal(onPressed: () => ref.read(matchmakingProvider.notifier).join(mode: mode), child: const Text('تلاش دوباره')),
            if (state.status == MatchmakingStatus.found && state.gameId != null)
              FilledButton.icon(
                onPressed: () => _enterMatch(state),
                icon: const Icon(Icons.play_arrow_rounded), label: const Text('ورود به مسابقه'),
              ),
            const Spacer(),
            const Text('تاس، نوبت و حرکت‌ها توسط سرور کنترل می‌شوند', style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
        ),
      ),
    );
  }
}
