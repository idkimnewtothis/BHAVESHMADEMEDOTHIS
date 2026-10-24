import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:anymex_extension_runtime_bridge/Services/Aniyomi/RepositoryClient.dart';
import 'package:shonenx/features/updates/models/github_release.dart';
import 'package:shonenx/features/updates/services/apk_update_download.dart';

void main() {
  test(
    'app update rejects HTTP errors, wrong sizes and unsafe filenames',
    () async {
      final dir = await Directory.systemTemp.createTemp('update-apk-');
      addTearDown(() => dir.delete(recursive: true));
      const asset = ReleaseAsset(
        name: 'shonenxplus-2.1.0.apk',
        downloadUrl: 'https://download.example/app.apk',
        size: 8,
      );
      final client = RepositoryClient(
        createClient: () =>
            MockClient((_) async => http.Response('Not found', 404)),
      );
      await expectLater(
        downloadUpdateApk(asset, dir, client: client),
        throwsA(isA<HttpException>()),
      );
      expect(await dir.list().isEmpty, isTrue);
      final short = RepositoryClient(
        createClient: () => MockClient(
          (_) async => http.Response.bytes([80, 75, 3, 4, 1], 200),
        ),
      );
      await expectLater(
        downloadUpdateApk(asset, dir, client: short),
        throwsFormatException,
      );
      expect(await dir.list().isEmpty, isTrue);
      await expectLater(
        downloadUpdateApk(
          const ReleaseAsset(
            name: '../app.apk',
            downloadUrl: 'https://download.example/app.apk',
            size: 1,
          ),
          dir,
          client: short,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'valid APK bytes are retained in app cache and progress completes',
    () async {
      final dir = await Directory.systemTemp.createTemp('update-apk-');
      addTearDown(() => dir.delete(recursive: true));
      final bytes = [80, 75, 3, 4, 1, 2, 3, 4];
      final client = RepositoryClient(
        createClient: () =>
            MockClient((_) async => http.Response.bytes(bytes, 200)),
      );
      var received = 0;
      final file = await downloadUpdateApk(
        const ReleaseAsset(
          name: 'shonenxplus-2.1.0.apk',
          downloadUrl: 'https://download.example/app.apk',
          size: 8,
        ),
        dir,
        client: client,
        onProgress: (n, _) => received = n,
      );
      expect(await file.readAsBytes(), bytes);
      expect(received, 8);
      expect(await dir.list().length, 1);
    },
  );
}
