import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/providers.dart';
import 'package:ludo_app/core/theme/app_theme.dart';
import 'package:ludo_app/features/game/data/offline_game_repository.dart';
import 'package:ludo_app/features/game/presentation/game_screen.dart';
import 'package:ludo_app/features/game/presentation/online_lobby_screen.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final unfinished = OfflineGameRepository().unfinished();
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              sliver: SliverList.list(children: [
                Row(children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppColors.turquoise,
                    child: Text((user?.username ?? 'م').characters.first, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('سلام، ${user?.username ?? 'بازیکن'}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    const Text('برای یک رقابت تازه آماده‌ای؟', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ])),
                  _Balance(icon: Icons.monetization_on_rounded, value: '${user?.coinBalance ?? 0}', color: AppColors.gold),
                ]),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF137D75), Color(0xFF2FC8B3)]),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
                      child: const Text('مسابقه آنلاین', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 18),
                    const Text('حریف آماده‌ست! 🎲', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('با بازیکنان سراسر ایران رقابت کن', style: TextStyle(color: Color(0xDDFFFFFF))),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.cream, foregroundColor: AppColors.ink, minimumSize: const Size(190, 50)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnlineLobbyScreen())),
                      icon: const Icon(Icons.bolt_rounded),
                      label: const Text('بازی سریع'),
                    ),
                  ]),
                ),
                if (unfinished.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GameScreen(
                            playerCount: unfinished.first.teams.length,
                            snapshot: unfinished.first,
                          ),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(17),
                        child: Row(children: [
                          CircleAvatar(
                            backgroundColor: Color(0x332FC8B3),
                            child: Icon(Icons.play_arrow_rounded, color: AppColors.turquoise),
                          ),
                          SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ادامه بازی قبلی', style: TextStyle(fontWeight: FontWeight.w900)),
                                Text('آخرین بازی آفلاین ذخیره‌شده', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_left_rounded),
                        ]),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('بازی آفلاین', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  Text('بدون نیاز به اینترنت', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _ModeCard(
                    title: 'دو نفره', subtitle: 'رو در رو', icon: Icons.people_alt_rounded, color: AppColors.coral,
                    onTap: () => _openGame(context, 2),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _ModeCard(
                    title: 'چهار نفره', subtitle: 'دورهمی', icon: Icons.groups_rounded, color: AppColors.gold,
                    onTap: () => _openGame(context, 4),
                  )),
                ]),
                const SizedBox(height: 26),
                Card(child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    const CircleAvatar(radius: 25, backgroundColor: Color(0x33F4B844), child: Icon(Icons.card_giftcard_rounded, color: AppColors.gold)),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('جایزه روزانه', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('هر روز سر بزن و سکه بگیر', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ])),
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref.read(apiClientProvider).dio.post<void>('/wallet/daily-reward');
                          await ref.read(currentUserProvider.notifier).restore();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('جایزه روزانه به کیف پول اضافه شد.')),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('جایزه امروز قبلاً دریافت شده است.')),
                            );
                          }
                        }
                      },
                      child: const Text('دریافت'),
                    ),
                  ]),
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _openGame(BuildContext context, int players) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => GameScreen(playerCount: players)),
  );
}

class _Balance extends StatelessWidget {
  const _Balance({required this.icon, required this.value, required this.color});
  final IconData icon; final String value; final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(99)),
    child: Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 5), Text(value, style: const TextStyle(fontWeight: FontWeight.w800))]),
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
  final String title; final String subtitle; final IconData icon; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: .16), child: Icon(icon, color: color)),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
      ),
    ),
  );
}
