import 'package:shonenx/shared/models/unified_media.dart';
import 'package:shonenx/source_engine/providers/media_source.dart';
import 'anime_matcher.dart';

class MediaMatchService {
  final MediaSource _mediaSource;
  final MediaType _type;
  MediaMatchService(this._mediaSource, this._type);

  Future<UnifiedMedia?> findBestMatch(MediaTitle mediaTitle) async {
    final aliases = [
      mediaTitle.romaji,
      mediaTitle.english,
      mediaTitle.native,
      mediaTitle.getPreferedTitle,
    ].whereType<String>().where((s) => s.isNotEmpty).toSet().toList();
    final candidates = <String, UnifiedMedia>{};
    for (final alias in aliases) {
      for (final result
          in await _mediaSource
              .search(alias, _type)
              .timeout(const Duration(seconds: 8))) {
        candidates[result.id] = result;
      }
      if (candidates.isNotEmpty) break;
    }
    final scored =
        candidates.values
            .map(
              (m) => (
                media: m,
                match: AnimeMatcher.compare(aliases, m.title.getPreferedTitle),
              ),
            )
            .toList()
          ..sort((a, b) => b.match.confidence.compareTo(a.match.confidence));
    if (scored.isEmpty || !scored.first.match.autoAccept) return null;
    if (scored.length > 1 &&
        scored.first.match.confidence - scored[1].match.confidence < .05) {
      return null;
    }
    return scored.first.media;
  }
}
