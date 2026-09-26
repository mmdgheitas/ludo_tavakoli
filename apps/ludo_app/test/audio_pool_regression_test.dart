import 'dart:typed_data';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uses the actual pinned AudioPool/AudioPlayer Dart implementation, NOT a
/// mocked AudioPool. Only platform messages are faked. Focus loss is explicitly
/// simulated, so these tests do not claim to reproduce Android OS/OEM behavior.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _NativeAudio native;
  late List<AudioPool> pools;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    native = _NativeAudio()..install();
    pools = [];
  });

  tearDown(() async {
    for (final pool in pools) { await pool.dispose(); }
    native.uninstall();
    debugDefaultTargetPlatformOverride = null;
  });

  Future<AudioPool> makePool({AudioContext? context, int max = 3}) async {
    final pool = await AudioPool.create(
      // No real decoding: the fake platform sends a prepared event.
      source: BytesSource(Uint8List(1)),
      audioContext: context,
      maxPlayers: max,
    );
    pools.add(pool);
    return pool;
  }

  test('GAIN interruption strands voices: maxPlayers is not an active limit', () async {
    final pool = await makePool(max: 1);
    for (var burst = 0; burst < 10; burst++) {
      await pool.start();
      await pool.start(); // Simulated GAIN pauses the first without completion.
      await native.completeAudiblePlayers();
    }
    expect(native.focusLosses, 10);
    expect(pool.currentPlayers, hasLength(10));
    expect(pool.availablePlayers, hasLength(1));
    expect(native.created, 11);
  });

  test('mixing completes/reuses voices across 200 rapid bursts', () async {
    final pool = await makePool(context: AudioContext(
      android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
    ));
    for (var burst = 0; burst < 200; burst++) {
      await Future.wait(List.generate(3, (_) => pool.start()));
      expect(pool.currentPlayers, hasLength(3));
      expect(native.playing, hasLength(3));
      await native.completeAudiblePlayers();
      expect(pool.currentPlayers, isEmpty);
      expect(pool.availablePlayers, hasLength(3));
    }
    expect(native.focusLosses, 0);
    expect(native.created, 3);
  });

  test('resume failures leave reserved players until the whole pool is disposed', () async {
    final pool = await makePool(max: 1);
    native.failResume = true;
    await expectLater(pool.start(), throwsA(isA<PlatformException>()));
    expect(pool.currentPlayers, hasLength(1));
    expect(pool.availablePlayers, isEmpty);
    await expectLater(pool.start(), throwsA(isA<PlatformException>()));
    expect(pool.currentPlayers, hasLength(2));
    expect(native.created, 2);
    await pool.dispose();
    expect(pool.currentPlayers, isEmpty);
    expect(native.focusByPlayer, isEmpty);
    pools.remove(pool);
  });
}

class _NativeAudio {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final focusByPlayer = <String, int>{};
  final playing = <String>{};
  final eventChannels = <String>{};
  var created = 0;
  var focusLosses = 0;
  var failResume = false;

  void install() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'), (_) async => null,
    );
    _events('xyz.luan/audioplayers.global/events');
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'), _handle,
    );
  }

  void _events(String name) {
    eventChannels.add(name);
    messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }

  Future<Object?> _handle(MethodCall call) async {
    final args = call.arguments as Map;
    final id = args['playerId'] as String;
    switch (call.method) {
      case 'create':
        created++;
        focusByPlayer[id] = 1; // Android native default: AUDIOFOCUS_GAIN.
        _events('xyz.luan/audioplayers/events/$id');
        break;
      case 'setAudioContext':
        focusByPlayer[id] = args['audioFocus'] as int;
        break;
      case 'setSourceBytes':
        await _emit(id, {'event': 'audio.onPrepared', 'value': true});
        break;
      case 'resume':
        if (failResume) throw PlatformException(code: 'resume_failed');
        if (focusByPlayer[id] != 0) {
          // Model WrappedPlayer.onLoss: pause, with no completion event.
          focusLosses += playing.where((other) => other != id).length;
          playing.clear();
        }
        playing.add(id);
        break;
      case 'pause':
      case 'stop':
      case 'release':
        playing.remove(id);
        break;
      case 'dispose':
        playing.remove(id);
        focusByPlayer.remove(id);
        break;
      case 'getCurrentPosition':
        return 0;
      case 'getDuration':
        return 792;
    }
    return null;
  }

  Future<void> _emit(String id, Map<String, Object> event) async {
    // Same platform-message injection used by audioplayers' own pinned tests.
    // ignore: deprecated_member_use
    await messenger.handlePlatformMessage(
      'xyz.luan/audioplayers/events/$id',
      const StandardMethodCodec().encodeSuccessEnvelope(event),
      (_) {},
    );
  }

  Future<void> completeAudiblePlayers() async {
    final audible = playing.toList();
    playing.clear();
    for (final id in audible) {
      await _emit(id, {'event': 'audio.onComplete'});
    }
    // Drain stream listeners and the AudioPool's async stop/recycle lock.
    await Future<void>.delayed(Duration.zero);
  }

  void uninstall() {
    messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), null);
    messenger.setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), null);
    for (final name in eventChannels) {
      messenger.setMockMethodCallHandler(MethodChannel(name), null);
    }
  }
}
