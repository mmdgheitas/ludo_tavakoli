import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:manche_irani/core/providers.dart';
import 'package:manche_irani/core/theme/app_theme.dart';
import 'package:manche_irani/features/auth/presentation/welcome_screen.dart';
import 'package:manche_irani/features/home/presentation/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox<String>('offline_games'),
    Hive.openBox<dynamic>('settings'),
  ]);
  runApp(const ProviderScope(child: MancheIraniApp()));
}

class MancheIraniApp extends ConsumerWidget {
  const MancheIraniApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'منچ ایرانی',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('fa', 'IR'),
      supportedLocales: const [Locale('fa', 'IR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: ref.watch(currentUserProvider).when(
        loading: () => const _SplashScreen(),
        error: (_, __) => const WelcomeScreen(),
        data: (user) => user == null ? const WelcomeScreen() : const HomeShell(),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('مــنــچ', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900, color: AppColors.gold)),
          SizedBox(height: 18),
          SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
        ],
      ),
    ),
  );
}
