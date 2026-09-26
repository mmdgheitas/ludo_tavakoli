import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final sound in ['dice', 'move', 'rocket']) {
    test('$sound is bundled at the exact AudioCache asset path', () async {
      // AudioPool.createFromAsset uses AudioCache.instance's `assets/` prefix,
      // NOT FlameAudio.audioCache's `assets/audio/` prefix.
      final path = 'assets/audio/$sound.mp3';
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      expect(manifest.listAssets(), contains(path));
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(0));
      expect(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        orderedEquals(await File(path).readAsBytes()),
      );
    });
  }
}
