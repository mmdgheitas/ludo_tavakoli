import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/providers.dart';
import 'package:ludo_app/core/theme/app_theme.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});
  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(currentUserProvider);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.3,
            colors: [Color(0xFF3B2854), AppColors.ink],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const _LudoMark(),
                const SizedBox(height: 34),
                const Text('منچ ایرانی', textAlign: TextAlign.center, style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('بازی کن، رقابت کن، قهرمان شو!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 16)),
                const Spacer(),
                TextField(
                  controller: _nameController,
                  maxLength: 24,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    counterText: '',
                    labelText: 'نام بازیکن (اختیاری)',
                    hintText: 'مثلاً آرش',
                    prefixIcon: const Icon(Icons.person_rounded),
                    filled: true,
                    fillColor: AppColors.card,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: auth.isLoading ? null : () => ref.read(currentUserProvider.notifier).enter(displayName: _nameController.text),
                  child: auth.isLoading
                      ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('ورود به بازی'),
                ),
                const SizedBox(height: 12),
                const Text('با ورود، قوانین بازی و حریم خصوصی را می‌پذیرید.', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LudoMark extends StatelessWidget {
  const _LudoMark();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 132,
      height: 132,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [BoxShadow(color: Color(0x55F4B844), blurRadius: 36, spreadRadius: 2)],
      ),
      child: GridView.count(
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: const [
          _Dot(AppColors.coral), _Dot(AppColors.turquoise),
          _Dot(AppColors.gold), _Dot(Color(0xFF5B8DEF)),
        ],
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5)),
  );
}
