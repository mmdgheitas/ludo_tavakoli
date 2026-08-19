import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  late final Box<dynamic> box = Hive.box<dynamic>('settings');
  bool get sound => box.get('sound', defaultValue: true) as bool;
  bool get vibration => box.get('vibration', defaultValue: true) as bool;
  bool get notifications => box.get('notifications', defaultValue: true) as bool;
  Future<void> set(String key, bool value) async { await box.put(key, value); setState(() {}); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تنظیمات')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      SwitchListTile(value: sound, onChanged: (value) => set('sound', value), secondary: const Icon(Icons.volume_up_outlined), title: const Text('صدای بازی'), subtitle: const Text('صدای تاس و حرکت مهره‌ها')),
      SwitchListTile(value: vibration, onChanged: (value) => set('vibration', value), secondary: const Icon(Icons.vibration), title: const Text('لرزش'), subtitle: const Text('بازخورد لمسی هنگام بازی')),
      SwitchListTile(value: notifications, onChanged: (value) => set('notifications', value), secondary: const Icon(Icons.notifications_outlined), title: const Text('اعلان‌ها'), subtitle: const Text('پاداش روزانه و دعوت دوستان')),
      const Divider(),
      const ListTile(leading: Icon(Icons.language), title: Text('زبان'), trailing: Text('فارسی')),
      const ListTile(leading: Icon(Icons.info_outline), title: Text('نسخه برنامه'), trailing: Text('1.0.0')),
    ]),
  );
}
