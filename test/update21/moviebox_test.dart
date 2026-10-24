import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shonenx/shared/models/unified_media.dart';
import 'package:shonenx/source_engine/moviebox/moviebox_source.dart';

void main() {
  test(
    'MovieBox catalog sections deduplicate title IDs and retain media types',
    () async {
      final source = MovieBoxSource(
        'https://catalog.example/api',
        client: MockClient((request) async {
          expect(request.url.path, '/api/home');
          expect(request.url.queryParameters['page'], '2');
          return http.Response(
            jsonEncode({
              'code': 0,
              'data': {
                'list': [
                  {
                    'title': 'Featured',
                    'items': [
                      {
                        'subjectId': '12',
                        'title': 'Movie',
                        'subjectType': 1,
                        'cover': {'url': 'https://img.example/m.jpg'},
                      },
                      {'subjectId': '13', 'title': 'Series', 'subjectType': 2},
                    ],
                  },
                  {
                    'items': [
                      {'subjectId': '12', 'title': 'Movie', 'subjectType': 1},
                    ],
                  },
                ],
              },
            }),
            200,
          );
        }),
      );
      addTearDown(source.close);
      final items = await source.catalog('home', page: 2);
      expect(items.length, 2);
      expect(items[0].type, MediaType.MOVIE);
      expect(items[1].type, MediaType.TV);
      expect(items[0].id, startsWith('${source.sourceInfo.id}:'));
    },
  );
  test(
    'search page, details and season-separated episodes preserve identity',
    () async {
      final seen = <String>[];
      final source = MovieBoxSource(
        'https://catalog.example',
        client: MockClient((request) async {
          seen.add(request.url.path);
          if (request.url.path == '/search') {
            expect(request.url.queryParameters, {
              'q': 'Title 日本語',
              'page': '3',
              'subject_type': '2',
            });
            return http.Response(
              '{"code":0,"data":{"items":[{"subjectId":"99","title":"Title 日本語","subjectType":2}]}}',
              200,
              headers: {
                'set-cookie': 'session_id=synthetic; HttpOnly',
                'content-type': 'application/json; charset=utf-8',
              },
            );
          }
          expect(request.headers['Cookie'], 'session_id=synthetic');
          if (request.url.path == '/detail/99') {
            return http.Response(
              '{"code":0,"data":{"subjectId":"99","title":"Title 日本語","subjectType":2,"description":"Details"}}',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (request.url.path == '/episodes/99') {
            return http.Response(
              '{"code":0,"data":{"seasons":[{"seasonNumber":1,"episodes":[{"episodeNumber":"1","title":"Opening"}]},{"seasonNumber":2,"episodes":[{"episodeNumber":"1","title":"Return"}]}]}}',
              200,
            );
          }
          fail('Unexpected route ${request.url}');
        }),
      );
      addTearDown(source.close);
      final title = (await source.search(
        'Title 日本語',
        MediaType.ANIME,
        page: 3,
      )).single;
      expect(
        (await source.getDetails(title.id, title.type)).description,
        'Details',
      );
      final episodes = await source.getEpisodes(title.id);
      expect(episodes.map((e) => e.season), [1, 2]);
      expect(episodes[0].id, isNot(episodes[1].id));
      expect(seen, isNot(contains('/stream/99')));
    },
  );
  test('Featured search includes both movies and series', () async {
    final source = MovieBoxSource(
      'https://catalog.example',
      client: MockClient((r) async {
        expect(r.url.queryParameters['subject_type'], '0');
        return http.Response(
          '{"code":0,"data":{"items":[{"subjectId":"1","title":"Movie","subjectType":1},{"subjectId":"2","title":"Series","subjectType":2}]}}',
          200,
        );
      }),
    );
    addTearDown(source.close);
    final results = await source.searchCatalog('Title');
    expect(results.map((m) => m.type), [MediaType.MOVIE, MediaType.TV]);
  });
  test(
    'MovieBox errors stay errors and server identity cannot cross endpoints',
    () async {
      final source = MovieBoxSource(
        'https://catalog.example',
        client: MockClient(
          (_) async => http.Response(
            '{"code":500,"message":"upstream unavailable","data":{"list":[]}}',
            200,
          ),
        ),
      );
      addTearDown(source.close);
      await expectLater(source.catalog('home'), throwsStateError);
      await expectLater(
        source.getDetails('moviebox:wrong:10', MediaType.ANIME),
        throwsFormatException,
      );
      expect(
        () => MovieBoxSource.validateEndpoint('http://public.example'),
        throwsFormatException,
      );
      expect(
        () =>
            MovieBoxSource.validateEndpoint('https://user:secret@example.com'),
        throwsFormatException,
      );
      expect(
        () => MovieBoxSource.validateEndpoint('http://192.168.1.5:8000'),
        throwsFormatException,
      );
    },
  );
  test('MovieBox authorization failures are explicit', () async {
    final source = MovieBoxSource(
      'https://catalog.example',
      client: MockClient((_) async => http.Response('Forbidden', 403)),
    );
    addTearDown(source.close);
    await expectLater(
      source.catalog('movies'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'reason',
          contains('authorization'),
        ),
      ),
    );
  });
}
