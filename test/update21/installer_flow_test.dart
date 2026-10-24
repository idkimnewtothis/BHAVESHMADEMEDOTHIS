import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isar_community/isar.dart';
import 'package:anymex_extension_runtime_bridge/anymex_extension_runtime_bridge.dart';
import 'package:anymex_extension_runtime_bridge/Settings/KvStore.dart';
import 'package:anymex_extension_runtime_bridge/Services/Aniyomi/AniyomiExtensions.dart';
import 'package:anymex_extension_runtime_bridge/Services/Aniyomi/AniyomiSourceMethods.dart';
import 'package:anymex_extension_runtime_bridge/Services/Aniyomi/Models/Source.dart';
import 'package:anymex_extension_runtime_bridge/Services/Aniyomi/RepositoryClient.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Isar db;
  const channel = MethodChannel('aniyomiExtensionBridge');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUpAll(() async {
    await Isar.initializeIsarCore(
      libraries: {
        Abi.linuxX64:
            '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/isar_community_flutter_libs-3.3.2/linux/libisar.so',
      },
      download: false,
    );
    dir = await Directory.systemTemp.createTemp('installer-test-');
    db = await Isar.open(
      [KvEntrySchema],
      directory: dir.path,
      name: 'bridge',
      inspector: false,
    );
    await AnymeXExtensionBridge.init(
      isarInstance: db,
      getDirectory:
          ({subPath, useCustomPath = false, useSystemPath = false}) async =>
              dir,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => dir.path,
    );
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));
  tearDownAll(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  for (final manga in [false, true]) {
    test(
      '${manga ? 'manga' : 'anime'} add repo, trust, download and await Android result',
      () async {
        final pkg =
            'eu.kanade.tachiyomi.${manga ? 'extension' : 'animeextension'}.en.fixture';
        final version = manga ? '1.6.1' : '16.1';
        final calls = <String>[];
        final transport = RepositoryClient(
          createClient: () => MockClient((r) async {
            calls.add(r.url.path);
            if (r.url.path.endsWith('repo.json')) {
              return http.Response(
                jsonEncode({
                  'meta': {'signingKeyFingerprint': 'a' * 64},
                }),
                200,
              );
            }
            if (r.url.path.endsWith('.apk')) {
              return http.Response.bytes([80, 75, 3, 4, 1, 2, 3], 200);
            }
            return http.Response(
              jsonEncode([
                {
                  'name': 'Fixture',
                  'pkg': pkg,
                  'apk': 'fixture.apk',
                  'version': version,
                  'code': 1,
                  'lang': 'en',
                  'nsfw': 0,
                },
              ]),
              200,
            );
          }),
        );
        final engine = manga
            ? MihonExtensions(repositoryClient: transport)
            : AniyomiExtensions(repositoryClient: transport);
        final type = manga ? ItemType.manga : ItemType.anime;
        KvStore.setSync(engine.repositoryKey, <String>[]);
        await engine.addRepo(
          'https://github.com/example/${manga ? 'manga' : 'anime'}/raw/repo/index.min.json',
          type,
        );
        final source = engine.getAvailableRx(type).value.single;
        await expectLater(engine.installSource(source), throwsStateError);
        expect(calls.where((p) => p.endsWith('.apk')), isEmpty);
        engine.trustRepository(source, 'a' * 64);
        final result = Completer<bool>();
        final handedOff = Completer<void>();
        String? path;
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'installVerifiedApk');
          final a = call.arguments as Map;
          expect(a['package'], pkg);
          expect(a['fingerprint'], 'a' * 64);
          path = a['path'] as String;
          expect(await File(path!).readAsBytes(), [80, 75, 3, 4, 1, 2, 3]);
          handedOff.complete();
          return result.future;
        });
        var completed = false;
        final installing = engine
            .installSource(source)
            .then((_) => completed = true);
        await handedOff.future;
        expect(completed, isFalse);
        expect(await File(path!).exists(), isTrue);
        result.complete(true);
        await installing;
        expect(completed, isTrue);
        expect(await File(path!).exists(), isFalse);
        final httpCalls = calls.length;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getLoadFailures') return [];
          expect(
            call.method,
            manga
                ? 'getInstalledMangaExtensions'
                : 'getInstalledAnimeExtensions',
          );
          return [
            {
              'id': '42',
              'name': 'Fixture',
              'pkgName': pkg,
              'version': version,
              'lang': 'en',
              'itemType': type.index,
            },
          ];
        });
        if (manga) {
          await engine.fetchInstalledMangaExtensions();
        } else {
          await engine.fetchInstalledAnimeExtensions();
        }
        final installedSource =
            engine.getInstalledRx(type).value.single as ASource;
        expect(installedSource.repo, source.repo);
        expect(installedSource.apkUrl, endsWith('/apk/fixture.apk'));
        expect(installedSource.hasUpdate, isFalse);
        expect(
          calls.length,
          httpCalls,
          reason: 'Installed refresh must not refetch indexes',
        );
        final manager = ExtensionManager()..managers.add(engine);
        await manager.refreshInstalledExtensions();
        expect(
          manga
              ? manager.installedMangaExtensions
              : manager.installedAnimeExtensions,
          hasLength(1),
        );
        messenger.setMockMethodCallHandler(channel, (_) async => []);
        await manager.refreshInstalledExtensions();
        expect(
          manga
              ? manager.installedMangaExtensions
              : manager.installedAnimeExtensions,
          isEmpty,
        );
        expect(
          calls.length,
          httpCalls,
          reason:
              'Removing a package must refresh installed state without HTTP',
        );
        manager.onClose();
      },
    );
  }
  test('manga preference writes retain family and source identity', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'saveSourcePreference');
      expect(call.arguments, {
        'sourceId': '42',
        'isAnime': false,
        'key': 'language',
        'value': 'en',
      });
      return true;
    });
    final methods = AniyomiSourceMethods(
      ASource(id: '42', itemType: ItemType.manga),
    );
    expect(
      await methods.setPreference(SourcePreference(key: 'language'), 'en'),
      isTrue,
    );
  });
}
