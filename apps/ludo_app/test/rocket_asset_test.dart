import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Fattah strike is silent if this asset is missing or undeclared:
/// `AudioManager` swallows load failures so audio can never break gameplay.
/// These assertions make a lost or corrupt binary fail the build instead.
void main() {
  test('ships a valid rocket sound and declares it as an asset', () {
    final file = File('assets/audio/rocket.mp3');
    expect(file.existsSync(), isTrue, reason: 'assets/audio/rocket.mp3 must be committed');
    final bytes = file.readAsBytesSync();
    expect(bytes.length, greaterThan(4096));

    // Walk the MPEG-1 Layer III frame chain; a truncated or corrupt file cannot
    // be parsed end to end.
    const bitrates = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320];
    const rates = [44100, 48000, 32000];
    var offset = 0;
    var frames = 0;
    var sampleRate = 0;
    while (offset + 4 <= bytes.length) {
      final header = (bytes[offset] << 24) |
          (bytes[offset + 1] << 16) |
          (bytes[offset + 2] << 8) |
          bytes[offset + 3];
      expect((header >> 21) & 0x7FF, 0x7FF, reason: 'frame sync at byte $offset');
      expect((header >> 19) & 3, 3, reason: 'MPEG-1 at byte $offset');
      expect((header >> 17) & 3, 1, reason: 'Layer III at byte $offset');
      final bitrateIndex = (header >> 12) & 0xF;
      final rateIndex = (header >> 10) & 3;
      final padded = (header >> 9) & 1;
      expect(bitrateIndex, inInclusiveRange(1, 14), reason: 'bitrate index at byte $offset');
      expect(rateIndex, lessThan(3), reason: 'sample rate index at byte $offset');
      sampleRate = rates[rateIndex];
      offset += (144 * bitrates[bitrateIndex] * 1000) ~/ sampleRate + padded;
      frames += 1;
    }
    expect(offset, bytes.length, reason: 'no trailing garbage after the last frame');
    expect(frames, greaterThan(20));

    final seconds = frames * 1152 / sampleRate;
    // Timed to RocketComponent.flightSeconds (0.55) + blastSeconds (0.32).
    expect(seconds, greaterThan(0.8));
    expect(seconds, lessThan(1.5));

    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('assets/audio/rocket.mp3'),
      reason: 'the asset must be declared or AudioPool.createFromAsset fails at runtime',
    );
  });
}
