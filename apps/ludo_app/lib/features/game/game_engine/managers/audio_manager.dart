import 'dart:async';
import 'dart:developer' as developer;

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

typedef GameAudioPoolFactory = Future<AudioPool> Function({
  required String path,
  required int maxPlayers,
  required AudioContext? audioContext,
});

class AudioManager {
  static final _dice = _SoundChannel('dice', 'audio/dice.mp3', 3);
  static final _move = _SoundChannel('move', 'audio/move.mp3', 4);
  static final _rocket = _SoundChannel('rocket', 'audio/rocket.mp3', 2);
  static final _channels = [_dice, _move, _rocket];
  static Future<void>? _initializing;
  static Future<void>? _disposing;
  static bool _running = false;

  @visibleForTesting
  static GameAudioPoolFactory poolFactory = _defaultPoolFactory;

  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  static Future<AudioPool> _defaultPoolFactory({
    required String path,
    required int maxPlayers,
    required AudioContext? audioContext,
  }) => AudioPool.create(
    source: AssetSource(path),
    maxPlayers: maxPlayers,
    audioContext: audioContext,
  );

  // The raw createFromAsset helper does NOT use FlameAudio's mixing context.
  // Each Android media player otherwise requests GAIN, and another SFX can
  // pause it before onPlayerComplete returns it to its pool. Do not change
  // audio-session policy on platforms for which no issue was reported.
  static AudioContext? get _audioContext =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? AudioContext(
              android: const AudioContextAndroid(
                audioFocus: AndroidAudioFocus.none,
              ),
            )
          : null;

  static const _diagnostics = bool.fromEnvironment('AUDIO_DIAGNOSTICS');
  static const _retryDelay = Duration(seconds: 1);
  static const _maxSetupFailures = 3;
  static const _initializationBudget = Duration(seconds: 3);
  static int _nextRequest = 0;

  static bool get _enabled =>
      !Hive.isBoxOpen('settings') ||
      (Hive.box<dynamic>('settings').get('sound', defaultValue: true) as bool);

  static Future<void> initialize() {
    final disposing = _disposing;
    if (disposing != null) return _initializeAfter(disposal: disposing);
    if (!_enabled) return Future<void>.value();
    _running = true;
    return _initializing ??= _initializeChannels().whenComplete(() {
      _initializing = null;
    });
  }

  static Future<void> _initializeAfter({required Future<void> disposal}) async {
    await disposal;
    await initialize();
  }

  static Future<void> _initializeChannels() async {
    for (final channel in _channels) { channel.open(); }
    await Future.wait(_channels.map((channel) => channel.prepare())).timeout(
      _initializationBudget,
      onTimeout: () {
        _trace('initialize_timed_out');
        // Timeout does NOT cancel a platform operation. Channels keep their
        // single-flight loading futures; later requests never spawn replacements
        // on top of unresolved native creation/disposal. Gameplay can continue.
        return [];
      },
    );
  }

  static Future<void> playDiceSound({double volume = 1.0}) async {
    _play(_dice, volume);
  }

  static Future<void> playMoveSound() async {
    _play(_move, 1.0);
  }

  static Future<void> playRocketSound({double volume = 1.0}) async {
    _play(_rocket, volume);
  }

  static void _play(_SoundChannel channel, double volume) {
    if (!_enabled || !_running || _disposing != null) {
      if (_diagnostics) _trace('play_skipped sound=${channel.name} reason=inactive');
      return;
    }
    channel.play(volume);
  }

  static void _trace(String message, [Object? error, StackTrace? stackTrace]) {
    if (!_diagnostics) return;
    developer.log(
      message,
      name: 'ludo.audio',
      level: error == null ? 800 : 1000,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static Future<void> dispose() {
    _running = false;
    return _disposing ??= _disposeChannels().whenComplete(() {
      _disposing = null;
    });
  }

  static Future<void> _disposeChannels() async {
    // Do not dispose native players while initialization/start is using them.
    await _initializing;
    await Future.wait(_channels.map((channel) => channel.close()));
  }
}

/// Owns one existing Flame AudioPool, not a replacement audio backend.
/// maxPlayers still limits cached players in audioplayers. Separately limit
/// outstanding native start requests so a stalled channel cannot queue forever.
class _SoundChannel {
  _SoundChannel(this.name, this.path, this.maxPlayers);

  final String name;
  final String path;
  final int maxPlayers;
  AudioPool? _pool;
  Future<void>? _loading;
  Future<void>? _retiring;
  Completer<void>? _idle;
  DateTime? _retryAfter;
  int _pendingStarts = 0;
  int _setupFailures = 0;
  bool _faulted = false;
  bool _closed = false;

  void open() => _closed = false;

  Future<void> prepare() {
    if (_closed || (_pool != null && !_faulted)) return Future<void>.value();
    if (_setupFailures >= AudioManager._maxSetupFailures) {
      AudioManager._trace('pool_setup_quarantined sound=$name');
      return Future<void>.value();
    }
    return _loading ??= _prepare().whenComplete(() { _loading = null; });
  }

  Future<void> _prepare() async {
    final retryAfter = _retryAfter;
    if (retryAfter != null && AudioManager.now().isBefore(retryAfter)) return;
    await _retiring;
    if (_closed) return;
    final updatedRetryAfter = _retryAfter;
    if (updatedRetryAfter != null && AudioManager.now().isBefore(updatedRetryAfter)) return;
    if (_faulted) {
      await _retire();
      // Disposal failed: retain/quarantine the old pool, never allocate over it.
      if (_pool != null || _closed) return;
    }
    try {
      final context = AudioManager._audioContext;
      AudioManager._trace('pool_create sound=$name path=$path maxCached=$maxPlayers '
          'androidFocus=${context?.android.audioFocus.name ?? 'platform-default'}');
      _pool = await AudioManager.poolFactory(
        path: path,
        maxPlayers: maxPlayers,
        audioContext: context,
      );
      _retryAfter = null;
      _setupFailures = 0;
      AudioManager._trace('pool_ready sound=$name');
      // If close() raced the load, it awaits _loading and disposes this pool.
    } catch (error, stackTrace) {
      // A constructor can fail before AudioPool exposes the new native player.
      // Do not retry forever against an exhausted/unsupported backend.
      _setupFailures++;
      _retryAfter = AudioManager.now().add(AudioManager._retryDelay);
      AudioManager._trace('pool_failed sound=$name', error, stackTrace);
    }
  }

  void play(double volume) {
    if (_closed) return;
    final pool = _pool;
    if (pool == null || _faulted) {
      // Single-flight, rate-limited recovery on demand. Never replay stale SFX
      // after loading; gameplay and the public play* Futures remain non-blocking.
      unawaited(prepare());
      AudioManager._trace('play_skipped sound=$name reason=pool_not_ready');
      return;
    }
    if (_pendingStarts >= maxPlayers) {
      AudioManager._trace('play_skipped sound=$name reason=start_backpressure');
      return;
    }
    _pendingStarts++;
    unawaited(_start(pool, volume));
  }

  Future<void> _start(AudioPool pool, double volume) async {
    final request = AudioManager._diagnostics ? ++AudioManager._nextRequest : 0;
    final watch = AudioManager._diagnostics ? (Stopwatch()..start()) : null;
    if (AudioManager._diagnostics) {
      AudioManager._trace('start_requested sound=$name request=$request '
          'pendingStarts=$_pendingStarts volume=$volume');
    }
    try {
      await pool.start(volume: volume);
      if (AudioManager._diagnostics) {
        AudioManager._trace('start_returned sound=$name request=$request '
            'elapsedMs=${watch?.elapsedMilliseconds}');
      }
      // Do not schedule the returned StopFunction on a timer: AudioPool can
      // reuse this player after natural completion, and a late stop could cut
      // off a DIFFERENT playback on that same playerId (audioplayers 6.7.1).
    } catch (error, stackTrace) {
      // AudioPool.start reserves currentPlayers before setVolume/resume, but
      // does not roll back that reservation on error in audioplayers 6.7.1.
      // Catching the Future alone leaves the native player stranded.
      _faulted = true;
      _retryAfter = AudioManager.now().add(AudioManager._retryDelay);
      AudioManager._trace('start_failed sound=$name request=$request', error, stackTrace);
    } finally {
      watch?.stop();
      _pendingStarts--;
      if (_pendingStarts == 0) {
        _idle?.complete();
        _idle = null;
        if (_faulted) unawaited(_retire());
      }
    }
  }

  Future<void> _waitForIdle() => _pendingStarts == 0
      ? Future<void>.value()
      : (_idle ??= Completer<void>()).future;

  Future<void> _retire() =>
      _retiring ??= _retireWhenIdle().whenComplete(() { _retiring = null; });

  Future<void> _retireWhenIdle() async {
    await _waitForIdle();
    final pool = _pool;
    if (pool == null) return;
    try {
      await pool.dispose();
      _pool = null;
      _faulted = false;
      AudioManager._trace('pool_disposed sound=$name');
    } catch (error, stackTrace) {
      _faulted = true;
      _retryAfter = AudioManager.now().add(AudioManager._retryDelay);
      AudioManager._trace('pool_dispose_failed sound=$name', error, stackTrace);
    }
  }

  Future<void> close() async {
    _closed = true;
    await _loading;
    await _retire();
    if (_pool == null) {
      _retryAfter = null;
      _setupFailures = 0;
    }
  }
}
