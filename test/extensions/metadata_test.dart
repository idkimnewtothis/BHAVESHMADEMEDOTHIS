import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:anymex_extension_runtime_bridge/Services/Aniyomi/PbDecoder.dart';
import 'package:anymex_extension_runtime_bridge/Services/Aniyomi/ExtensionMetadata.dart';

void main() {
  final url = Uri.parse('https://example.test/repo/index.min.json');
  final entry = {
    'name': 'Aniyomi: Example',
    'pkg': 'eu.kanade.tachiyomi.animeextension.en.example',
    'apk': 'example.apk',
    'lang': 'en',
    'code': 1,
    'version': '16.1',
    'nsfw': 0,
  };
  List<ExtensionMetadata> parse(Object v) =>
      ExtensionMetadata.parse(utf8.encode(jsonEncode(v)), url);
  test('valid index resolves APK relative to repository', () {
    expect(
      parse([entry]).single.apkUrl,
      'https://example.test/repo/apk/example.apk',
    );
  });
  test('malformed index fails', () {
    expect(
      () => ExtensionMetadata.parse(utf8.encode('{broken'), url),
      throwsFormatException,
    );
  });
  test('required fields fail clearly', () {
    final broken = Map.of(entry)..remove('version');
    expect(() => parse([broken]), throwsFormatException);
  });
  test('duplicate packages fail', () {
    expect(() => parse([entry, entry]), throwsFormatException);
  });
  test('manga-only index supplies no installs', () {
    expect(
      parse([
        {...entry, 'pkg': 'eu.kanade.tachiyomi.extension.en.example'},
      ]),
      isEmpty,
    );
  });
  test('invalid fingerprint fails', () {
    expect(
      () => ExtensionMetadata.fingerprint({
        'meta': {'signingKeyFingerprint': 'bad'},
      }),
      throwsFormatException,
    );
  });
  for (final host in ['add-repo', 'extension-store']) {
    test('deep link $host', () {
      expect(
        ExtensionMetadata.deepLink(
          Uri.parse(
            'aniyomi://$host?url=https%3A%2F%2Fexample.test%2Findex.pb',
          ),
        ),
        Uri.parse('https://example.test/index.pb'),
      );
    });
  }
  test('manga deep link rejected', () {
    expect(
      ExtensionMetadata.deepLink(
        Uri.parse('tachiyomi://add-repo?url=https://example.test'),
      ),
      isNull,
    );
  });
  test('modern external JSON list uses declared lib and resource URL', () {
    final item = parse({
      'extensions': [
        {
          'name': 'Example',
          'packageName': entry['pkg'],
          'extensionLib': '17',
          'versionCode': '2',
          'versionName': '1.2',
          'contentWarning': 'CONTENT_WARNING_SAFE',
          'resources': {'apkUrl': 'https://cdn.example.test/example.apk'},
          'sources': [
            {'language': 'ja'},
          ],
        },
      ],
    }).single;
    expect(item.libVersion, 17);
    expect(item.language, 'ja');
    expect(item.nsfw, false);
    expect(item.apkUrl, 'https://cdn.example.test/example.apk');
  });
  test('protobuf truncation fails instead of returning an empty store', () {
    expect(() => PbDecoder.decodeStore([10, 5, 1]), throwsFormatException);
    expect(() => PbDecoder.decodeStore([128]), throwsFormatException);
  });
  test('legacy invalid version fails with FormatException', () {
    expect(
      () => parse([
        {...entry, 'version': 'bad'},
      ]),
      throwsFormatException,
    );
  });
  test('unknown optional fields are reported', () {
    final messages = <String>[];
    ExtensionMetadata.parse(
      utf8.encode(
        jsonEncode([
          {...entry, 'future': true},
        ]),
      ),
      url,
      log: messages.add,
    );
    expect(messages.single, contains('future'));
  });
  test('pinned real yuzono index parses the four selected APKs', () {
    final items = ExtensionMetadata.parse(
      File('test/fixtures/repository/index.min.json').readAsBytesSync(),
      Uri.parse(
        'https://raw.githubusercontent.com/yuzono/anime-repo/repo/index.min.json',
      ),
    );
    for (final suffix in [
      'kotokai',
      'animepahe',
      'kickassanime',
      'wcostream',
    ]) {
      final item = items.singleWhere(
        (e) => e.packageName == 'eu.kanade.tachiyomi.animeextension.en.$suffix',
      );
      expect(item.apkUrl, startsWith('https://'));
      expect([14, 16, 17], contains(item.libVersion));
    }
  });
}
