import 'video_engine.dart';

/// Buffering is an active playback intent; Pause remains available during it.
Future<void> togglePlayback(VideoEngine engine) async {
  final status = engine.statusNotifier.value;
  if (status == PlayerStatus.playing || status == PlayerStatus.buffering) {
    await engine.pause();
  } else {
    if (status == PlayerStatus.ended) await engine.seekTo(Duration.zero);
    await engine.play();
  }
}
