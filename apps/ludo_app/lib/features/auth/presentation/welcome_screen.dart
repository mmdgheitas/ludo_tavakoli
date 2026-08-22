import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/config/app_config.dart';
import 'package:ludo_app/core/providers.dart';
import 'package:ludo_app/core/theme/app_theme.dart';
import 'package:ludo_app/features/auth/presentation/password_recovery_screen.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});
  @override ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final formKey = GlobalKey<FormState>();
  final username = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool registerMode = false;
  bool obscure = true;

  @override void dispose() { username.dispose(); email.dispose(); password.dispose(); super.dispose(); }

  String errorMessage(Object? error) {
    if (error is DioException && error.type == DioExceptionType.connectionError) {
      return 'سرور در دسترس نیست. آدرس فعلی: ${AppConfig.apiBaseUrl}';
    }
    return registerMode
        ? 'نام کاربری یا ایمیل قبلاً استفاده شده، یا اطلاعات معتبر نیست.'
        : 'نام کاربری/ایمیل یا رمز عبور صحیح نیست.';
  }

  Future<void> submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (registerMode) {
      await ref.read(currentUserProvider.notifier).register(username: username.text, email: email.text, password: password.text);
    } else {
      await ref.read(currentUserProvider.notifier).login(identifier: username.text, password: password.text);
    }
  }

  @override Widget build(BuildContext context) {
    final auth = ref.watch(currentUserProvider);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment.topRight, radius: 1.3, colors: [Color(0xFF3B2854), AppColors.ink])),
        child: SafeArea(
          child: AutofillGroup(
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                children: [
                  const _LudoMark(), const SizedBox(height: 20),
                  const Text('منچ ایرانی', textAlign: TextAlign.center, style: TextStyle(fontSize: 35, fontWeight: FontWeight.w900)),
                  const Text('بازی کن، رقابت کن، قهرمان شو!', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 28),
                  SegmentedButton<bool>(
                    segments: const [ButtonSegment(value: false, label: Text('ورود')), ButtonSegment(value: true, label: Text('ثبت‌نام'))],
                    selected: {registerMode},
                    onSelectionChanged: auth.isLoading ? null : (value) => setState(() => registerMode = value.first),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: username,
                    enabled: !auth.isLoading,
                    autofillHints: registerMode ? const [AutofillHints.newUsername] : const [AutofillHints.username],
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(labelText: registerMode ? 'نام کاربری' : 'نام کاربری یا ایمیل', prefixIcon: const Icon(Icons.person_outline), filled: true, fillColor: AppColors.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                    validator: (value) => (value?.trim().length ?? 0) < 3 ? 'حداقل ۳ کاراکتر وارد کنید' : null,
                  ),
                  if (registerMode) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: email,
                      enabled: !auth.isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(labelText: 'ایمیل بازیابی', prefixIcon: const Icon(Icons.email_outlined), filled: true, fillColor: AppColors.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                      validator: (value) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value?.trim() ?? '') ? null : 'ایمیل معتبر وارد کنید',
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: password,
                    enabled: !auth.isLoading,
                    obscureText: obscure,
                    textDirection: TextDirection.ltr,
                    autofillHints: registerMode ? const [AutofillHints.newPassword] : const [AutofillHints.password],
                    decoration: InputDecoration(labelText: 'رمز عبور', helperText: registerMode ? 'حداقل ۱۰ کاراکتر؛ حرف بزرگ، کوچک و عدد' : null, prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility : Icons.visibility_off)), filled: true, fillColor: AppColors.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
                    validator: (value) {
                      final text = value ?? '';
                      if (text.length < 10) return 'رمز عبور باید حداقل ۱۰ کاراکتر باشد';
                      if (registerMode && !RegExp(r'(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(text)) return 'حرف بزرگ، حرف کوچک و عدد الزامی است';
                      return null;
                    },
                    onFieldSubmitted: (_) => submit(),
                  ),
                  if (!registerMode) Align(alignment: AlignmentDirectional.centerEnd, child: TextButton(onPressed: auth.isLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordRecoveryScreen())), child: const Text('رمز عبور را فراموش کرده‌اید؟'))),
                  if (auth.hasError) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(errorMessage(auth.error), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.coral, fontSize: 12))),
                  FilledButton(
                    onPressed: auth.isLoading ? null : submit,
                    child: auth.isLoading ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2)) : Text(registerMode ? 'ساخت حساب و ورود' : 'ورود به حساب'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: auth.isLoading ? null : () => ref.read(currentUserProvider.notifier).enter(), child: const Text('ادامه به‌صورت مهمان')),
                  const Text('با ادامه، قوانین بازی و حریم خصوصی را می‌پذیرید.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LudoMark extends StatelessWidget {
  const _LudoMark();
  @override Widget build(BuildContext context) => Center(child: Container(
    width: 112, height: 112, padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Color(0x55F4B844), blurRadius: 30)]),
    child: GridView.count(physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, children: const [_Dot(AppColors.coral), _Dot(AppColors.turquoise), _Dot(AppColors.gold), _Dot(Color(0xFF5B8DEF))]),
  ));
}
class _Dot extends StatelessWidget {
  const _Dot(this.color); final Color color;
  @override Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)));
}
