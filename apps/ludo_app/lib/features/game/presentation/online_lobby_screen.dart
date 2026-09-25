import 'dart:async';

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
  Timer? _countdownTimer;
  int _secondsLeft = 15;
  bool _preparing = false;

  void _enterMatch(MatchmakingState state) {
    if (_entered || state.gameId == null || !mounted) return;
    _entered = true;
    _countdownTimer?.cancel();
    final count = state.playerCount ?? widget.playerCount;
    ref.read(matchmakingProvider.notifier).cancel(resetState: false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => OnlineMatchScreen(gameId: state.gameId!, playerCount: count)),
    );
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsLeft = 15;
      _preparing = false;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        // After 15s, show preparing state while server creates bot match
        if (!_preparing) {
          setState(() => _preparing = true);
        }
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(matchmakingProvider.notifier).join(mode: mode));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(matchmakingProvider);
    ref.listen<MatchmakingState>(matchmakingProvider, (_, next) {
      if (next.status == MatchmakingStatus.searching) {
        // Restart countdown when searching starts
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _countdownTimer == null) _startCountdown();
        });
      } else if (next.status == MatchmakingStatus.found && next.gameId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _enterMatch(next));
      } else if (next.status == MatchmakingStatus.idle || next.status == MatchmakingStatus.error) {
        _stopCountdown();
      }
    });

    final isSearching = state.status == MatchmakingStatus.searching;
    final displayMessage = _preparing && isSearching
        ? 'حریفان پیدا شدند، در حال آماده‌سازی بازی…'
        : state.message;

    final waitingText = _preparing && isSearching
        ? 'در حال ورود به مسابقه...'
        : 'در انتظار ${widget.playerCount - 1} بازیکن دیگر • $_secondsLeft ثانیه';

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
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.casino_rounded, size: 72, color: AppColors.turquoise),
                  if (isSearching && !_preparing)
                    Positioned(
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(99)),
                        child: Text('$_secondsLeft', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 34),
            Text(displayMessage, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(waitingText, style: const TextStyle(color: AppColors.muted), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            if (isSearching) ...[
              SizedBox(width: 180, child: LinearProgressIndicator(value: _preparing ? null : (15 - _secondsLeft) / 15)),
              if (_preparing) ...[
                const SizedBox(height: 16),
                const Text('بازی به زودی شروع می‌شود', style: TextStyle(color: AppColors.turquoise, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ],
            if (state.status == MatchmakingStatus.error) FilledButton.tonal(onPressed: () { _startCountdown(); ref.read(matchmakingProvider.notifier).join(mode: mode); }, child: const Text('تلاش دوباره')),
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
