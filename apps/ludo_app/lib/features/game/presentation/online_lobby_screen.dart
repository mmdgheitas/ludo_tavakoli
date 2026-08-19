import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/theme/app_theme.dart';
import 'package:ludo_app/features/game/data/online_game_repository.dart';
import 'package:ludo_app/features/game/presentation/online_match_screen.dart';

class OnlineLobbyScreen extends ConsumerStatefulWidget {
  const OnlineLobbyScreen({super.key});
  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(matchmakingProvider.notifier).join());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchmakingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('بازی آنلاین'), leading: IconButton(icon: const Icon(Icons.close), onPressed: () { ref.read(matchmakingProvider.notifier).cancel(); Navigator.pop(context); })),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: .8, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeInOut,
            builder: (_, value, child) => Transform.scale(scale: value, child: child),
            onEnd: () {},
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.turquoise.withValues(alpha: .12), border: Border.all(color: AppColors.turquoise.withValues(alpha: .5), width: 2)),
              child: const Icon(Icons.casino_rounded, size: 72, color: AppColors.turquoise),
            ),
          ),
          const SizedBox(height: 34),
          Text(state.message, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(state.status == MatchmakingStatus.found ? 'اتاق بازی با ارتباط امن ساخته شد' : 'معمولاً کمتر از یک دقیقه طول می‌کشد', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 28),
          if (state.status == MatchmakingStatus.searching)
            const SizedBox(width: 180, child: LinearProgressIndicator()),
          if (state.status == MatchmakingStatus.error)
            FilledButton.tonal(
              onPressed: () => ref.read(matchmakingProvider.notifier).join(),
              child: const Text('تلاش دوباره'),
            ),
          if (state.status == MatchmakingStatus.found && state.gameId != null)
            FilledButton.icon(
              onPressed: () {
                final gameId = state.gameId!;
                ref.read(matchmakingProvider.notifier).cancel();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => OnlineMatchScreen(gameId: gameId)),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('ورود به مسابقه'),
            ),
          const Spacer(),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shield_outlined, size: 18, color: AppColors.muted), SizedBox(width: 6), Text('نتیجه تاس و حرکت‌ها توسط سرور کنترل می‌شود', style: TextStyle(fontSize: 11, color: AppColors.muted))]),
        ]),
      ),
    );
  }
}
