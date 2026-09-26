import 'dart:async';
import 'dart:io';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:ludo_app/features/game/game_engine/managers/audio_manager.dart';
import 'package:mocktail/mocktail.dart';

class _MockPool extends Mock implements AudioPool {}

_MockPool _pool() {
  final pool = _MockPool();
  when(() => pool.start(volume: any(named: 'volume')))
      .thenAnswer((_) async => () async {});
  when(pool.dispose).thenAnswer((_) async {});
  return pool;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalFactory = AudioManager.poolFactory;
  final originalNow = AudioManager.now;
  late Directory settingsDirectory;
  late Box<dynamic> settings;
  late Map<String, _MockPool> pools;
  late List<(String, int)> creations;
  late List<AudioContext?> contexts;
  late DateTime clock;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    settingsDirectory = await Directory.systemTemp.createTemp('ludo-audio-test');
    Hive.init(settingsDirectory.path);
    settings = await Hive.openBox<dynamic>('settings');
    clock = DateTime.utc(2026);
    AudioManager.now = () => clock;
    pools = {
      'audio/dice.mp3': _pool(),
      'audio/move.mp3': _pool(),
      'audio/rocket.mp3': _pool(),
    };
    creations = [];
    contexts = [];
    AudioManager.poolFactory = ({required path, required maxPlayers, required audioContext}) async {
      creations.add((path, maxPlayers));
      contexts.add(audioContext);
      return pools[path]!;
    };
  });

  tearDown(() async {
    await AudioManager.dispose();
    AudioManager.poolFactory = originalFactory;
    AudioManager.now = originalNow;
    debugDefaultTargetPlatformOverride = null;
    await Hive.close();
    await settingsDirectory.delete(recursive: true);
  });

  test('Android SFX mix without independent audio focus requests', () async {
    await AudioManager.initialize();
    expect(creations, [
      ('audio/dice.mp3', 3),
      ('audio/move.mp3', 4),
      ('audio/rocket.mp3', 2),
    ]);
    for (final context in contexts) {
      expect(context!.android.audioFocus, AndroidAudioFocus.none);
      expect(context.android.contentType, AndroidContentType.music);
      expect(context.android.usageType, AndroidUsageType.media);
    }
    await AudioManager.initialize();
    expect(creations, hasLength(3));
  });

  test('does not change audio context on iOS', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await AudioManager.initialize();
    expect(contexts, [null, null, null]);
  });

  test('normal sequential requests preserve routing and volume', () async {
    await AudioManager.initialize();
    await AudioManager.playDiceSound(volume: 0.6);
    await AudioManager.playMoveSound();
    await AudioManager.playRocketSound(volume: 0.8);
    verify(() => pools['audio/dice.mp3']!.start(volume: 0.6)).called(1);
    verify(() => pools['audio/move.mp3']!.start(volume: 1.0)).called(1);
    verify(() => pools['audio/rocket.mp3']!.start(volume: 0.8)).called(1);
  });

  test('a burst cannot enqueue unlimited starts or block gameplay', () async {
    await AudioManager.initialize();
    final starts = <Completer<StopFunction>>[];
    for (final pool in pools.values) {
      when(() => pool.start(volume: any(named: 'volume'))).thenAnswer((_) {
        final started = Completer<StopFunction>();
        starts.add(started);
        return started.future;
      });
    }
    await Future.wait([
      for (var i = 0; i < 1000; i++) ...[
        AudioManager.playDiceSound(),
        AudioManager.playMoveSound(),
        AudioManager.playRocketSound(),
      ],
    ]).timeout(const Duration(seconds: 1));
    expect(starts, hasLength(9)); // 3 + 4 + 2 pending starts, not playing voices.
    expect(starts.every((start) => !start.isCompleted), isTrue);
    expect(creations, hasLength(3));
    verify(() => pools['audio/dice.mp3']!.start(volume: 1.0)).called(3);
    verify(() => pools['audio/move.mp3']!.start(volume: 1.0)).called(4);
    verify(() => pools['audio/rocket.mp3']!.start(volume: 1.0)).called(2);

    var stopCalls = 0;
    for (final start in starts) {
      start.complete(() async { stopCalls++; });
    }
    await _flush();
    expect(stopCalls, 0, reason: 'A stale StopFunction can stop a reused player');
    final dice = pools['audio/dice.mp3']!;
    when(() => dice.start(volume: any(named: 'volume')))
        .thenAnswer((_) async => () async {});
    await AudioManager.playDiceSound();
    verify(() => dice.start(volume: 1.0)).called(1);
  });

  test('failed start disposes only the damaged pool and later recovers it', () async {
    await AudioManager.initialize();
    final broken = pools['audio/move.mp3']!;
    when(() => broken.start(volume: 1.0))
        .thenAnswer((_) async => throw StateError('native resume failed'));
    await AudioManager.playMoveSound();
    await _flush();
    verify(broken.dispose).called(1);
    verifyNever(pools['audio/dice.mp3']!.dispose);
    verifyNever(pools['audio/rocket.mp3']!.dispose);

    for (var i = 0; i < 100; i++) { await AudioManager.playMoveSound(); }
    expect(creations, hasLength(3), reason: 'Failure cooldown prevents recreation storms');
    pools['audio/move.mp3'] = _pool();
    clock = clock.add(const Duration(seconds: 2));
    await AudioManager.playMoveSound(); // Trigger recovery, not a delayed stale sound.
    await _flush();
    expect(creations.where((entry) => entry.$1 == 'audio/move.mp3'), hasLength(2));
    await AudioManager.playMoveSound();
    verify(() => pools['audio/move.mp3']!.start(volume: 1.0)).called(1);
    await AudioManager.playDiceSound();
    verify(() => pools['audio/dice.mp3']!.start(volume: 1.0)).called(1);
  });

  test('synchronous start failure is contained and retires the pool', () async {
    await AudioManager.initialize();
    when(() => pools['audio/rocket.mp3']!.start(volume: 1.0))
        .thenThrow(StateError('synchronous start failure'));
    await AudioManager.playRocketSound();
    await _flush();
    verify(pools['audio/rocket.mp3']!.dispose).called(1);
  });

  test('recovery waits for other starts before disposing their native pool', () async {
    await AudioManager.initialize();
    final dice = pools['audio/dice.mp3']!;
    final starts = <Completer<StopFunction>>[];
    when(() => dice.start(volume: 1.0)).thenAnswer((_) {
      final pending = Completer<StopFunction>();
      starts.add(pending);
      return pending.future;
    });
    await AudioManager.playDiceSound();
    await AudioManager.playDiceSound();
    starts.first.completeError(StateError('resume failed'));
    await _flush();
    verifyNever(dice.dispose);
    await AudioManager.playDiceSound(); // Must not use the faulted pool.
    expect(starts, hasLength(2));
    starts.last.complete(() async {});
    await _flush();
    verify(dice.dispose).called(1);
  });

  test('failed disposal is quarantined instead of allocating over leaked resources', () async {
    await AudioManager.initialize();
    final dice = pools['audio/dice.mp3']!;
    when(() => dice.start(volume: 1.0))
        .thenAnswer((_) async => throw StateError('resume failed'));
    when(dice.dispose).thenAnswer((_) async => throw StateError('dispose failed'));
    await AudioManager.playDiceSound();
    await _flush();
    clock = clock.add(const Duration(seconds: 2));
    await AudioManager.playDiceSound();
    await _flush();
    expect(creations, hasLength(3));
    when(dice.dispose).thenAnswer((_) async {});
  });

  test('simultaneous initialization creates only one pool per sound', () async {
    final loaded = Completer<AudioPool>();
    AudioManager.poolFactory = ({required path, required maxPlayers, required audioContext}) async {
      creations.add((path, maxPlayers));
      if (path == 'audio/dice.mp3') return await loaded.future;
      return pools[path]!;
    };
    final first = AudioManager.initialize();
    final second = AudioManager.initialize();
    expect(identical(first, second), isTrue);
    await AudioManager.playDiceSound();
    verifyNever(() => pools['audio/dice.mp3']!.start(volume: any(named: 'volume')));
    loaded.complete(pools['audio/dice.mp3']!);
    await Future.wait([first, second]);
    expect(creations, hasLength(3));
  });

  test('a hung audio load cannot block game initialization forever', () async {
    final loaded = Completer<AudioPool>();
    AudioManager.poolFactory = ({required path, required maxPlayers, required audioContext}) async {
      creations.add((path, maxPlayers));
      if (path == 'audio/dice.mp3') return await loaded.future;
      return pools[path]!;
    };
    // Exercise the production three-second budget, not a cancelled mock task.
    await AudioManager.initialize().timeout(const Duration(seconds: 5));
    expect(loaded.isCompleted, isFalse);
    for (var i = 0; i < 100; i++) { await AudioManager.playDiceSound(); }
    expect(creations.where((entry) => entry.$1 == 'audio/dice.mp3'), hasLength(1));
    await AudioManager.playMoveSound();
    verify(() => pools['audio/move.mp3']!.start(volume: 1.0)).called(1);
    loaded.complete(pools['audio/dice.mp3']!);
    await _flush();
    await AudioManager.playDiceSound();
    verify(() => pools['audio/dice.mp3']!.start(volume: 1.0)).called(1);
  });

  test('one bad asset does not disable other sounds and can be retried', () async {
    var failMove = true;
    AudioManager.poolFactory = ({required path, required maxPlayers, required audioContext}) async {
      creations.add((path, maxPlayers));
      if (path == 'audio/move.mp3' && failMove) throw StateError('asset load failed');
      return pools[path]!;
    };
    await AudioManager.initialize();
    await AudioManager.playDiceSound();
    await AudioManager.playRocketSound();
    verify(() => pools['audio/dice.mp3']!.start(volume: 1.0)).called(1);
    verify(() => pools['audio/rocket.mp3']!.start(volume: 1.0)).called(1);
    failMove = false;
    clock = clock.add(const Duration(seconds: 2));
    await AudioManager.initialize();
    expect(creations.where((entry) => entry.$1 == 'audio/dice.mp3'), hasLength(1));
    await AudioManager.playMoveSound();
    verify(() => pools['audio/move.mp3']!.start(volume: 1.0)).called(1);
  });

  test('persistent native setup failure does not recreate players forever', () async {
    AudioManager.poolFactory = ({required path, required maxPlayers, required audioContext}) async {
      creations.add((path, maxPlayers));
      if (path == 'audio/dice.mp3') throw StateError('native setup exhausted');
      return pools[path]!;
    };
    await AudioManager.initialize();
    for (var attempt = 0; attempt < 20; attempt++) {
      clock = clock.add(const Duration(seconds: 2));
      await AudioManager.playDiceSound();
      await _flush();
    }
    expect(creations.where((entry) => entry.$1 == 'audio/dice.mp3'), hasLength(3));
    await AudioManager.playMoveSound();
    verify(() => pools['audio/move.mp3']!.start(volume: 1.0)).called(1);
  });

  test('dispose during startup and immediate restart do not leak duplicate pools', () async {
    final loaded = Completer<AudioPool>();
    var firstDice = true;
    AudioManager.poolFactory = ({required path, required maxPlayers, required audioContext}) async {
      creations.add((path, maxPlayers));
      if (path == 'audio/dice.mp3' && firstDice) {
        firstDice = false;
        return await loaded.future;
      }
      return pools[path]!;
    };
    final startup = AudioManager.initialize();
    final disposing = AudioManager.dispose();
    final restart = AudioManager.initialize();
    loaded.complete(pools['audio/dice.mp3']!);
    await Future.wait([startup, disposing, restart]);
    expect(creations, hasLength(6));
    for (final pool in pools.values) { verify(pool.dispose).called(1); }
    await AudioManager.playDiceSound();
    verify(() => pools['audio/dice.mp3']!.start(volume: 1.0)).called(1);
  });

  test('mute and explicit dispose never start or recreate audio accidentally', () async {
    await settings.put('sound', false);
    await AudioManager.initialize();
    expect(creations, isEmpty);
    await settings.put('sound', true);
    await AudioManager.initialize();
    await settings.put('sound', false);
    await AudioManager.playDiceSound();
    await AudioManager.playMoveSound();
    await AudioManager.playRocketSound();
    for (final pool in pools.values) {
      verifyNever(() => pool.start(volume: any(named: 'volume')));
    }
    await AudioManager.dispose();
    await settings.put('sound', true);
    await AudioManager.playDiceSound();
    expect(creations, hasLength(3));
    await AudioManager.initialize();
    expect(creations, hasLength(6));
  });
}
