import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:anymex_extension_runtime_bridge/Services/Aniyomi/RepositoryClient.dart';

void main() {
  const manga = 'https://raw.githubusercontent.com/keiyoushi/extensions/repo/';
  const anime = 'https://raw.githubusercontent.com/yuzono/anime-repo/repo/';
  RepositoryClient client(
    Map<String, http.Response> responses,
    List<Uri> requests,
  ) => RepositoryClient(
    createClient: () => MockClient((request) async {
      requests.add(request.url);
      return responses[request.url.toString()] ??
          http.Response('Not found', 404);
    }),
  );
  test(
    'exact user manga URL reads protobuf and embedded signing fingerprint',
    () async {
      final requests = <Uri>[];
      final c = client({
        '${manga}index.pb': http.Response.bytes(
          File('test/fixtures/keiyoushi/index.pb').readAsBytesSync(),
          200,
        ),
        '${manga}repo.json': http.Response(
          File('test/fixtures/keiyoushi/repo.json').readAsStringSync(),
          200,
        ),
      }, requests);
      final url = Uri.parse(
        'https://github.com/keiyoushi/extensions/raw/repo/index.pb',
      );
      expect((await c.read(url, manga: true)).length, 1426);
      expect(
        await c.fingerprint(url, manga: true),
        '9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2',
      );
      expect(requests.map((r) => r.toString()), [
        '${manga}index.pb',
        '${manga}index.pb',
      ]);
    },
  );
  test(
    'legacy anime APK URL and fingerprint stay rooted in repository',
    () async {
      final entries = [
        {
          'name': 'Aniyomi: Fixture',
          'pkg': 'eu.kanade.tachiyomi.animeextension.en.fixture',
          'apk': 'fixture.apk',
          'lang': 'en',
          'code': 9,
          'version': '16.9',
          'nsfw': 0,
        },
      ];
      final c = client({
        '${anime}index.min.json': http.Response(jsonEncode(entries), 200),
        '${anime}repo.json': http.Response(
          jsonEncode({
            'meta': {'signingKeyFingerprint': 'a' * 64},
          }),
          200,
        ),
      }, []);
      final url = Uri.parse('${anime}index.min.json');
      expect(
        (await c.read(url, manga: false)).single.apkUrl,
        '${anime}apk/fixture.apk',
      );
      expect(await c.fingerprint(url, manga: false), 'a' * 64);
    },
  );
  test(
    'metadata redirects normalize GitHub raw form and retain family',
    () async {
      final c = client({
        '${manga}repo.json': http.Response(
          File('test/fixtures/keiyoushi/repo.json').readAsStringSync(),
          200,
        ),
        '${manga}index.pb': http.Response.bytes(
          File('test/fixtures/keiyoushi/index.pb').readAsBytesSync(),
          200,
        ),
      }, []);
      expect(
        (await c.read(Uri.parse('${manga}repo.json'), manga: true)).length,
        1426,
      );
    },
  );
  test('redirect cycle and HTML response fail explicitly', () async {
    final uri = Uri.parse('${manga}repo.json');
    final c = client({
      uri.toString(): http.Response('{"index_v2":"repo.json"}', 200),
    }, []);
    await expectLater(c.read(uri, manga: true), throwsFormatException);
    final html = client({
      uri.toString(): http.Response('<html>error</html>', 200),
    }, []);
    await expectLater(html.read(uri, manga: true), throwsFormatException);
  });
  test(
    'APK streams through HTTPS redirect; failed HTML never becomes APK',
    () async {
      final dir = await Directory.systemTemp.createTemp('sx21-download');
      addTearDown(() => dir.delete(recursive: true));
      final url = Uri.parse('${anime}apk/test.apk');
      final c = client({
        url.toString(): http.Response(
          '',
          302,
          headers: {'location': 'https://cdn.example/test.apk'},
        ),
        'https://cdn.example/test.apk': http.Response.bytes([
          80,
          75,
          3,
          4,
          1,
          2,
          3,
        ], 200),
      }, []);
      final file = File('${dir.path}/test.apk');
      await c.download(url, file);
      expect(await file.readAsBytes(), [80, 75, 3, 4, 1, 2, 3]);
      expect(await File('${file.path}.part').exists(), false);
      await file.delete();
      final bad = client({
        url.toString(): http.Response('<html>denied</html>', 200),
      }, []);
      await expectLater(bad.download(url, file), throwsFormatException);
      expect(await file.exists(), false);
      expect(await File('${file.path}.part').exists(), false);
    },
  );
  test('transport rejects redirect to cleartext and HTTP failures', () async {
    final uri = Uri.parse('${manga}repo.json');
    final c = client({
      uri.toString(): http.Response(
        '',
        302,
        headers: {'location': 'http://example.test/index.pb'},
      ),
    }, []);
    await expectLater(c.read(uri, manga: true), throwsFormatException);
    final error = client({
      uri.toString(): http.Response('unavailable', 503),
    }, []);
    await expectLater(
      error.read(uri, manga: true),
      throwsA(isA<HttpException>()),
    );
  });
}
