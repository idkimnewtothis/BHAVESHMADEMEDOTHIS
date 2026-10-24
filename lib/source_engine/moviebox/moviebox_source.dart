import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shonenx/shared/models/unified_media.dart';
import 'package:shonenx/shared/models/unified_episode.dart';
import 'package:shonenx/shared/models/video_stream.dart';
import 'package:shonenx/shared/models/video_server.dart';
import 'package:shonenx/source_engine/models/source_info.dart';
import 'package:shonenx/source_engine/providers/anime_source.dart';

/// Client for the user-operated moviebox-internal-api HTTP server contract.
/// Site signing/authentication remains on that server; no credentials bundled.
class MovieBoxSource extends AnimeSource {
  final Uri endpoint;
  final http.Client client;
  String? _cookie;
  MovieBoxSource(String base, {http.Client? client})
    : endpoint = validateEndpoint(base),
      client = client ?? http.Client();

  static Uri validateEndpoint(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !{'https', 'http'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'Enter your MovieBox server URL, without credentials, query, or fragment.',
      );
    }
    if (uri.scheme != 'https') {
      throw const FormatException('Use an HTTPS MovieBox server URL.');
    }
    return uri.replace(path: '${uri.path.replaceFirst(RegExp(r'/+$'), '')}/');
  }

  void close() => client.close();
  String get sourceId =>
      'moviebox:${sha256.convert(utf8.encode(endpoint.toString())).toString().substring(0, 12)}';
  @override
  SourceInfo get sourceInfo => SourceInfo(
    id: sourceId,
    name: 'MovieBox',
    type: SourceType.inbuilt,
    mediaType: MediaType.ANIME,
    baseUrl: endpoint.toString(),
  );
  String _raw(String id) {
    if (!id.startsWith('$sourceId:')) {
      throw const FormatException(
        'This title belongs to a different MovieBox server.',
      );
    }
    return id.substring(sourceId.length + 1);
  }

  Future<Map<String, dynamic>> request(
    String path, [
    Map<String, String> query = const {},
  ]) async {
    final url = endpoint
        .resolve(path)
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await client
        .get(
          url,
          headers: {
            'Accept': 'application/json',
            if (_cookie != null) 'Cookie': _cookie!,
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw StateError(
        'MovieBox requires authorization. Configure access on your server.',
      );
    }
    if (response.statusCode != 200) {
      throw StateError(
        'MovieBox HTTP ${response.statusCode}. Check your server and retry.',
      );
    }
    final cookie = response.headers['set-cookie'];
    if (cookie != null) _cookie = cookie.split(';').first;
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('MovieBox returned an invalid response.');
    }
    if (data['code'] != null && ![0, 200].contains(data['code'])) {
      throw StateError(
        'MovieBox: ${data['message'] ?? data['msg'] ?? 'server could not load this content'}',
      );
    }
    return data;
  }

  static String? _image(dynamic value) => value is String
      ? value
      : value is Map
      ? (value['url'] ?? value['image'])?.toString()
      : null;
  UnifiedMedia media(Map value, {MediaType? type}) {
    final id = (value['subjectId'] ?? value['id'])?.toString();
    final title = (value['title'] ?? value['name'])?.toString();
    if (id == null || id.isEmpty || title == null || title.isEmpty) {
      throw const FormatException('MovieBox title is missing an ID or name.');
    }
    final kind =
        type ??
        (value['subjectType'].toString() == '1'
            ? MediaType.MOVIE
            : MediaType.TV);
    final genres = value['genre'] ?? value['genres'];
    return UnifiedMedia(
      id: '$sourceId:$id',
      providerId: id,
      sourceId: sourceId,
      sourceName: 'MovieBox',
      type: kind,
      title: MediaTitle(english: title),
      cover: _image(value['cover']),
      banner: _image(value['poster']),
      description: value['description']?.toString(),
      genres: genres is List
          ? genres.map((g) => g.toString()).toList()
          : genres is String
          ? genres.split(',').map((g) => g.trim()).toList()
          : const [],
      score: double.tryParse('${value['score']}'),
      year: int.tryParse('${value['releaseTime']}'.split('-').first),
      format: kind == MediaType.MOVIE ? 'MOVIE' : 'TV',
      status: value['status']?.toString(),
    );
  }

  List<UnifiedMedia> parseCatalog(
    Map<String, dynamic> response, {
    MediaType? type,
  }) {
    final data = response['data'] ?? response;
    final result = <UnifiedMedia>[];
    void walk(dynamic node) {
      if (node is List) {
        for (final child in node) {
          walk(child);
        }
      } else if (node is Map) {
        if (node['subjectId'] != null ||
            (node['id'] != null && node['title'] != null)) {
          result.add(media(node, type: type));
        } else {
          for (final key in [
            'list',
            'items',
            'subjects',
            'movieList',
            'subject',
          ]) {
            if (node[key] != null) walk(node[key]);
          }
        }
      }
    }

    walk(data);
    return {for (final item in result) item.id: item}.values.toList();
  }

  Future<List<UnifiedMedia>> catalog(String category, {int page = 1}) async {
    if (!{'home', 'anime', 'movies', 'series'}.contains(category)) {
      throw ArgumentError.value(category);
    }
    final data = await request(category == 'series' ? 'tab/19' : category, {
      'page': '$page',
    });
    return parseCatalog(
      data,
      type: category == 'anime'
          ? MediaType.ANIME
          : category == 'movies'
          ? MediaType.MOVIE
          : null,
    );
  }

  Future<List<UnifiedMedia>> searchCatalog(
    String query, {
    String category = 'home',
    int page = 1,
  }) async {
    if (!{'home', 'anime', 'movies', 'series'}.contains(category)) {
      throw ArgumentError.value(category);
    }
    return parseCatalog(
      await request('search', {
        'q': query,
        'page': '$page',
        'subject_type': category == 'home'
            ? '0'
            : category == 'movies'
            ? '1'
            : '2',
      }),
      type: category == 'anime' ? MediaType.ANIME : null,
    );
  }

  @override
  Future<List<UnifiedMedia>> getTrending({int page = 1}) =>
      catalog('home', page: page);
  @override
  Future<List<UnifiedMedia>> search(
    String query,
    MediaType type, {
    int page = 1,
    bool isAdult = false,
    List<String> sort = const ['SEARCH_MATCH'],
    List<String> genres = const [],
    List<String> tags = const [],
    bool forceRefresh = false,
  }) async => parseCatalog(
    await request('search', {
      'q': query,
      'page': '$page',
      'subject_type': type == MediaType.MOVIE ? '1' : '2',
    }),
    type: type,
  );
  @override
  Future<UnifiedMedia> getDetails(String providerId, MediaType type) async {
    final data = await request(
      'detail/${Uri.encodeComponent(_raw(providerId))}',
    );
    final body = data['data'];
    if (body is! Map) {
      throw const FormatException('MovieBox detail is missing data.');
    }
    return media(body, type: type);
  }

  @override
  Future<List<UnifiedEpisode>> getEpisodes(
    String animeId, {
    bool forceRefresh = false,
  }) async {
    final id = _raw(animeId);
    final detail = await request('detail/${Uri.encodeComponent(id)}');
    if ((detail['data']?['subjectType']).toString() == '1') {
      return [
        UnifiedEpisode(
          id: jsonEncode([animeId, 1, 1]),
          number: 1,
          title: 'Movie',
        ),
      ];
    }
    final response = await request('episodes/${Uri.encodeComponent(id)}');
    final seasons = response['data']?['seasons'] ?? response['seasons'];
    if (seasons is! List) {
      throw const FormatException('MovieBox response is missing seasons.');
    }
    final episodes = <UnifiedEpisode>[];
    for (final season in seasons.whereType<Map>()) {
      final number = int.tryParse('${season['seasonNumber']}');
      if (number == null) {
        throw const FormatException('MovieBox season number is missing.');
      }
      for (final ep
          in (season['episodes'] as List? ?? const []).whereType<Map>()) {
        final n = double.tryParse('${ep['episodeNumber']}');
        if (n == null) {
          throw const FormatException('MovieBox episode number is missing.');
        }
        episodes.add(
          UnifiedEpisode(
            id: jsonEncode([animeId, number, n]),
            number: n,
            season: number,
            title: ep['title']?.toString(),
            thumbnailUrl: _image(ep['thumbnail']),
            airDate: ep['airDate']?.toString(),
          ),
        );
      }
    }
    return episodes;
  }

  @override
  Future<List<VideoServer>> getServers(String episodeId) async => const [
    VideoServer(id: 'moviebox', name: 'MovieBox server'),
  ];
  @override
  Future<List<VideoStream>> getSources(
    String episodeId,
    VideoServer server,
  ) async {
    final parts = jsonDecode(episodeId) as List;
    final result = await request(
      'stream/${Uri.encodeComponent(_raw(parts[0] as String))}',
      {'season': '${parts[1]}', 'episode': '${(parts[2] as num).toInt()}'},
    );
    final url = result['url'];
    if (url is! String ||
        !{'http', 'https'}.contains(Uri.tryParse(url)?.scheme)) {
      throw const FormatException(
        'MovieBox did not return a supported stream.',
      );
    }
    return [
      VideoStream(
        url: url,
        quality: result['quality']?.toString() ?? 'Auto',
        headers: {
          if (result['cookie'] is String &&
              (result['cookie'] as String).isNotEmpty)
            'Cookie': result['cookie'] as String,
        },
        subtitles: (result['subtitles'] as List? ?? const [])
            .whereType<Map>()
            .where((s) => s['url'] is String)
            .map(
              (s) => SubtitleTrack(
                url: s['url'] as String,
                language: s['lanName']?.toString() ?? 'Unknown',
              ),
            )
            .toList(),
      ),
    ];
  }
}
