import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shonenx/features/player/engine/video_engine.dart';
import 'package:shonenx/features/player/engine/playback_actions.dart';

class FakeEngine extends Fake implements VideoEngine {
  @override
  final ValueNotifier<PlayerStatus> statusNotifier;
  final calls = <String>[];
  FakeEngine(PlayerStatus status) : statusNotifier = ValueNotifier(status);
  @override
  Future<void> pause() async {
    calls.add('pause');
  }

  @override
  Future<void> play() async {
    calls.add('play');
  }

  @override
  Future<void> seekTo(Duration position) async {
    calls.add('seek:${position.inMilliseconds}');
  }
}

void main() {
  for (final status in [PlayerStatus.playing, PlayerStatus.buffering]) {
    test('$status pauses without attempting to start a stream', () async {
      final fake = FakeEngine(status);
      addTearDown(fake.statusNotifier.dispose);
      await togglePlayback(fake);
      expect(fake.calls, ['pause']);
    });
  }
  test('paused resumes', () async {
    final fake = FakeEngine(PlayerStatus.paused);
    addTearDown(fake.statusNotifier.dispose);
    await togglePlayback(fake);
    expect(fake.calls, ['play']);
  });
  test('ended seeks to beginning before replay', () async {
    final fake = FakeEngine(PlayerStatus.ended);
    addTearDown(fake.statusNotifier.dispose);
    await togglePlayback(fake);
    expect(fake.calls, ['seek:0', 'play']);
  });
}
