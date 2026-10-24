// Explicit long-running validation: flutter test test/endurance/download_queue_soak.dart
// Synthetic image bytes only; no external sites or video requests.
import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:shonenx/features/downloads/domain/models/download_task.dart';
import 'package:shonenx/features/downloads/providers/download_provider.dart';
import 'package:shonenx/features/downloads/providers/download_prefs_provider.dart';
import 'package:shonenx/shared/providers/database_provider.dart';
import 'package:shonenx/source_engine/source_engine_provider.dart';
import 'package:shonenx/shared/models/unified_media.dart';
import 'package:shonenx/shared/models/unified_episode.dart';
import '../overhaul/download_queue_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    '120 slow chapters across two database sessions retain all pages and bounded concurrency',
    () async {
      HttpOverrides.global = null;
      await Isar.initializeIsarCore(
        libraries: {
          Abi.linuxX64:
              '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/isar_community_flutter_libs-3.3.2/linux/libisar.so',
        },
        download: false,
      );
      final dir = await Directory.systemTemp.createTemp('sx21-endurance-');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var active = 0, peak = 0;
      final visits = <String, int>{};
      server.listen((request) async {
        active++;
        if (active > peak) peak = active;
        final path = request.uri.path;
        visits[path] = (visits[path] ?? 0) + 1;
        try {
          if (path.endsWith('/retry/1') && visits[path] == 1) {
            request.response.statusCode = 503;
            return;
          }
          request.response.headers.contentType = ContentType('image', 'png');
          for (var i = 0; i < 4; i++) {
            request.response.write('synthetic page $path chunk$i\n');
            await request.response.flush();
            await Future<void>.delayed(const Duration(seconds: 7));
          }
        } finally {
          await request.response.close();
          active--;
        }
      });
      final started = DateTime.now();
      try {
        for (var batch = 0; batch < 2; batch++) {
          final db = await Isar.open(
            [DownloadTaskSchema],
            directory: dir.path,
            name: 'endurance',
            inspector: false,
          );
          final c = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              downloadNoticeProvider.overrideWithValue(
                (id, title, success) async {},
              ),
              downloadPrefsProvider.overrideWith(
                () => fixture.TestPrefs(dir.path),
              ),
              mangaSourceProvider.overrideWith(
                (ref, arg) =>
                    fixture.FakeSource('http://127.0.0.1:${server.port}'),
              ),
            ],
          );
          try {
            await c.read(downloadManagerProvider.future);
            final manager = c.read(downloadManagerProvider.notifier);
            final media = UnifiedMedia(
              id: 'endurance',
              type: MediaType.MANGA,
              title: const MediaTitle(english: 'Synthetic endurance'),
            );
            for (var i = 0; i < 60; i++) {
              final id = batch == 0 && i == 0
                  ? 'retry'
                  : 'batch$batch-chapter$i';
              await manager.queueChapter(
                media,
                UnifiedEpisode(
                  id: id,
                  number: (batch * 60 + i).toDouble(),
                  title: id,
                ),
                fixture.sourceInfo,
              );
            }
            var last = -1;
            while (true) {
              final tasks = await db.downloadTasks.where().findAll();
              final failures = tasks
                  .where((t) => t.status == DownloadStatus.failed)
                  .toList();
              expect(failures.map((t) => t.error), isEmpty);
              final complete = tasks
                  .where((t) => t.status == DownloadStatus.completed)
                  .length;
              if (complete != last) {
                debugPrint(
                  'ENDURANCE elapsed=${DateTime.now().difference(started).inSeconds}s completed=$complete/${(batch + 1) * 60} active=$active peak=$peak rss=${ProcessInfo.currentRss}',
                );
                last = complete;
              }
              expect(peak, lessThanOrEqualTo(2));
              if (complete == (batch + 1) * 60) break;
              await Future<void>.delayed(const Duration(seconds: 10));
            }
            for (final task in await db.downloadTasks.where().findAll()) {
              expect(task.mediaId, 'endurance');
              expect(task.pagePaths.length, 2);
              for (var i = 0; i < 2; i++) {
                expect(
                  await File(task.pagePaths[i]).readAsString(),
                  List.generate(
                    4,
                    (n) =>
                        'synthetic page /${task.episodeId}/${i + 1} chunk$n\n',
                  ).join(),
                );
              }
            }
          } finally {
            c.dispose();
            await Future<void>.delayed(const Duration(milliseconds: 200));
            await db.close();
          }
        }
        expect(visits['/retry/1'], greaterThanOrEqualTo(2));
        debugPrint(
          'ENDURANCE PASS elapsed=${DateTime.now().difference(started).inSeconds}s peak=$peak pages=240 databaseReopens=1',
        );
      } finally {
        await server.close(force: true);
        await dir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 70)),
  );
}
