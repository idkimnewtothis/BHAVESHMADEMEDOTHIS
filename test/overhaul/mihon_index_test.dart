import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:anymex_extension_runtime_bridge/Services/Aniyomi/ExtensionMetadata.dart';
import 'package:anymex_extension_runtime_bridge/Services/Aniyomi/AniyomiExtensions.dart';
import 'package:anymex_extension_runtime_bridge/anymex_extension_runtime_bridge.dart';
import 'package:shonenx/features/extensions/providers/extension_service_provider.dart';

void main() {
  test(
    'current real Keiyoushi protobuf retains manga libraries and language',
    () {
      final bytes = File('test/fixtures/keiyoushi/index.pb').readAsBytesSync();
      final uri = Uri.parse(
        'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.pb',
      );
      final entries = ExtensionMetadata.parse(bytes, uri, manga: true);
      expect(entries.length, 1426);
      final mangaDex = entries.singleWhere((e) => e.name == 'MangaDex');
      expect(mangaDex.libVersion, 1.6);
      expect(mangaDex.language, isNotEmpty);
      expect(mangaDex.apkUrl, contains('/releases/download/'));
      expect(ExtensionMetadata.parse(bytes, uri), isEmpty);
    },
  );
  test('repository metadata supplies fingerprint and newer index URL', () {
    final repo =
        jsonDecode(File('test/fixtures/keiyoushi/repo.json').readAsStringSync())
            as Map;
    expect(repo['index_v2'], endsWith('/index.pb'));
    expect(
      ExtensionMetadata.fingerprint(repo),
      '9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2',
    );
  });
  test('manga manager is separate from anime installs', () {
    final manager = MihonExtensions();
    expect(manager.supportsManga, isTrue);
    expect(manager.supportsAnime, isFalse);
    expect(manager.mediaType, ItemType.manga);
    expect(manager.schemes, containsAll(['mihon', 'tachiyomi']));
  });
  test('repository roots select metadata instead of obsolete legacy index', () {
    expect(
      ExtensionAdapter.normalizeRepoUrl('https://example.test/repo', 'mihon'),
      'https://example.test/repo/repo.json',
    );
  });
}
