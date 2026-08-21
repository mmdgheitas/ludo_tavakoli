import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_app/core/providers.dart';

class PasswordRecoveryScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryScreen({super.key});
  @override ConsumerState<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends ConsumerState<PasswordRecoveryScreen> {
  final identifier = TextEditingController();
  final code = TextEditingController();
  final password = TextEditingController();
  bool requested = false; bool loading = false; bool obscure = true;

  @override void dispose() { identifier.dispose(); code.dispose(); password.dispose(); super.dispose(); }

  Future<void> submit() async {
    if (identifier.text.trim().length < 3) return;
    setState(() => loading = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      if (!requested) {
        await repository.forgotPassword(identifier.text);
        if (mounted) setState(() => requested = true);
      } else {
        await repository.resetPassword(identifier: identifier.text, code: code.text, newPassword: password.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('رمز عبور تغییر کرد؛ اکنون وارد شوید.')));
          Navigator.pop(context);
        }
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اطلاعات بازیابی معتبر نیست یا کد منقضی شده است.')));
    } finally { if (mounted) setState(() => loading = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('بازیابی رمز عبور')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Icon(Icons.lock_reset_rounded, size: 72), const SizedBox(height: 18),
      Text(requested ? 'کد ارسال‌شده را وارد کنید' : 'نام کاربری یا ایمیل خود را وارد کنید', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 24),
      TextField(controller: identifier, enabled: !requested, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'نام کاربری یا ایمیل', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_search_outlined))),
      if (requested) ...[
        const SizedBox(height: 14),
        TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'کد شش‌رقمی', counterText: '', border: OutlineInputBorder(), prefixIcon: Icon(Icons.pin_outlined))),
        const SizedBox(height: 14),
        TextField(controller: password, obscureText: obscure, decoration: InputDecoration(labelText: 'رمز عبور جدید', helperText: 'حداقل ۱۰ کاراکتر؛ شامل حرف بزرگ، کوچک و عدد', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.password), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility : Icons.visibility_off)))),
      ],
      const SizedBox(height: 20),
      FilledButton(onPressed: loading ? null : submit, child: loading ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(requested ? 'تغییر رمز عبور' : 'ارسال کد بازیابی')),
      if (requested) TextButton(onPressed: loading ? null : () async { setState(() => requested = false); await submit(); }, child: const Text('ارسال دوباره کد')),
    ]),
  );
}
