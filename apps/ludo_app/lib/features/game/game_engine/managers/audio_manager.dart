import 'package:flame_audio/flame_audio.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AudioManager {
  static AudioPool? _diceSoundPool;
  static bool get _enabled => !Hive.isBoxOpen('settings') || (Hive.box<dynamic>('settings').get('sound', defaultValue: true) as bool);

  static Future<void> initialize() async {
    if (!_enabled) return;
    _diceSoundPool ??= await AudioPool.createFromAsset(path: 'audio/dice.mp3', maxPlayers: 3);
  }

  static Future<void> playDiceSound({double volume = 1.0}) async {
    if (!_enabled) return;
    _diceSoundPool ??= await AudioPool.createFromAsset(path: 'audio/dice.mp3', maxPlayers: 3);
    await _diceSoundPool!.start(volume: volume);
  }

  static Future<void> playMoveSound() async {
    if (_enabled) await FlameAudio.play('move.mp3');
  }

  static Future<void> dispose() async {
    await _diceSoundPool?.dispose();
    _diceSoundPool = null;
  }
}
