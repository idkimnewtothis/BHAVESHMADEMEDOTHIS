import 'dart:ffi';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';
import 'package:shonenx/features/downloads/domain/models/download_task.dart';
import 'package:shonenx/features/downloads/domain/work_queue.dart';
import 'package:shonenx/features/downloads/providers/download_prefs_provider.dart';
import 'package:shonenx/features/downloads/providers/download_provider.dart';
import 'package:shonenx/shared/providers/database_provider.dart';
import 'package:shonenx/shared/models/unified_media.dart';
import 'package:shonenx/shared/models/unified_episode.dart';
import 'package:shonenx/source_engine/providers/manga_source.dart';
import 'package:shonenx/source_engine/source_engine_provider.dart';
import 'package:shonenx/source_engine/models/source_info.dart';
import 'package:shonenx/source_engine/models/chapter_page.dart';

const sourceInfo = SourceInfo(
  id: 'fake',
  name: 'Fake pages',
  type: SourceType.extension,
  mediaType: MediaType.MANGA,
);

class FakeSource extends Fake implements MangaSource {
  final String base;
  FakeSource(this.base);
  @override
  Future<List<ChapterPage>> getPages(String id) async => [
    ChapterPage(url: '$base/$id/1'),
    ChapterPage(url: '$base/$id/2'),
  ];
}

class TestPrefs extends DownloadPrefsNotifier {
  final String path;
  TestPrefs(this.path);
  @override
  Future<DownloadPrefs> build() async => DownloadPrefs(
    downloadPath: path,
    fileNameFormat: FileNameFormat.titleAndEpisode,
  );
}

Future<void> waitUntil(Future<bool> Function() condition) async {
  final limit = DateTime.now().add(const Duration(seconds: 20));
  while (!await condition()) {
    if (DateTime.now().isAfter(limit)) {
      throw StateError('Timed out waiting for queue');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'whole-job queue limits concurrency, deduplicates and isolates errors',
    () async {
      var active = 0, peak = 0;
      final ran = <int>[], errors = <int>[];
      final gates = List.generate(4, (_) => Completer<void>());
      final queue = WorkQueue(
        run: (id) async {
          ran.add(id);
          active++;
          if (active > peak) peak = active;
          await gates[id].future;
          active--;
          if (id == 0) throw StateError('fake source failure');
        },
        onError: (id, _, _) => errors.add(id),
      );
      addTearDown(queue.close);
      for (final id in [0, 0, 1, 2, 3]) {
        queue.add(id);
      }
      await Future<void>.delayed(Duration.zero);
      expect(ran, [0, 1]);
      gates[0].complete();
      gates[1].complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(ran, [0, 1, 2, 3]);
      gates[2].complete();
      gates[3].complete();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(peak, 2);
      expect(errors, [0]);
    },
  );

  test(
    'chapter batch persists, resumes after reopen, keeps page order and title identity',
    () async {
      HttpOverrides.global = null;
      final library =
          '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/isar_community_flutter_libs-3.3.2/linux/libisar.so';
      await Isar.initializeIsarCore(
        libraries: {Abi.linuxX64: library},
        download: false,
      );
      final dir = await Directory.systemTemp.createTemp('shonenxplus-queue-');
      addTearDown(() => dir.delete(recursive: true));
      // Real loopback HTTP, synthetic page bytes only. Never video or a live source.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var active = 0, peak = 0;
      final counts = <String, int>{};
      server.listen((request) async {
        active++;
        if (active > peak) peak = active;
        final path = request.uri.path;
        counts[path] = (counts[path] ?? 0) + 1;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        if (path.endsWith('/retry/1') && counts[path] == 1) {
          request.response.statusCode = 503;
        } else {
          request.response.headers.contentType = ContentType('image', 'png');
          request.response.write('synthetic page $path');
        }
        await request.response.close();
        active--;
      });
      var db = await Isar.open(
        [DownloadTaskSchema],
        directory: dir.path,
        name: 'queue',
        inspector: false,
      );
      ProviderContainer container() => ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          downloadNoticeProvider.overrideWithValue(
            (id, title, success) async {},
          ),
          downloadPrefsProvider.overrideWith(() => TestPrefs(dir.path)),
          mangaSourceProvider.overrideWith(
            (ref, arg) => FakeSource('http://127.0.0.1:${server.port}'),
          ),
        ],
      );
      var c = container();
      await c.read(downloadManagerProvider.future);
      final manager = c.read(downloadManagerProvider.notifier);
      final media = UnifiedMedia(
        id: 'title-1',
        type: MediaType.MANGA,
        title: const MediaTitle(english: 'Fixture'),
      );
      for (final id in ['one', 'retry', 'three']) {
        await manager.queueChapter(
          media,
          UnifiedEpisode(id: id, number: 1, title: id),
          sourceInfo,
        );
      }
      await waitUntil(
        () async => (await db.downloadTasks.where().findAll()).every(
          (t) => t.status == DownloadStatus.completed,
        ),
      );
      final complete = await db.downloadTasks.where().findAll();
      expect(complete.length, 3);
      expect(peak, lessThanOrEqualTo(2));
      expect(counts['/retry/1'], greaterThanOrEqualTo(2));
      for (final t in complete) {
        expect(t.mediaId, 'title-1');
        expect(t.pagePaths.length, 2);
        expect(
          await File(t.pagePaths[0]).readAsString(),
          'synthetic page /${t.episodeId}/1',
        );
        expect(
          await File(t.pagePaths[1]).readAsString(),
          'synthetic page /${t.episodeId}/2',
        );
      }
      // Repeated queue request cannot duplicate or redownload a completed chapter.
      await manager.queueChapter(
        media,
        const UnifiedEpisode(id: 'one', number: 1),
        sourceInfo,
      );
      expect(await db.downloadTasks.count(), 3);
      // Persist an interrupted job exactly as an abruptly stopped process leaves it.
      final interrupted = DownloadTask()
        ..url = 'chapter://restart'
        ..mediaId = 'title-1'
        ..sourceId = 'fake'
        ..sourceName = 'Fake pages'
        ..episodeId = 'restart'
        ..isManga = true
        ..savePath = '${dir.path}/restart'
        ..status = DownloadStatus.downloading;
      await c.read(downloadRepositoryProvider).putTask(interrupted);
      c.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await db.close();
      db = await Isar.open(
        [DownloadTaskSchema],
        directory: dir.path,
        name: 'queue',
        inspector: false,
      );
      c = container();
      await c.read(downloadManagerProvider.future);
      await waitUntil(
        () async =>
            (await db.downloadTasks.get(interrupted.id))?.status ==
            DownloadStatus.completed,
      );
      expect(await db.downloadTasks.count(), 4);
      final repository = c.read(downloadRepositoryProvider);
      final external = DownloadTask()
        ..url = 'external://race'
        ..external = true
        ..status = DownloadStatus.paused;
      await repository.putTask(external);
      final stale = (await repository.getTaskById(external.id))!;
      stale.status = DownloadStatus.completed;
      external.status = DownloadStatus.canceled;
      await repository.putTask(external);
      await repository.updateExternalResult(stale);
      expect(
        (await repository.getTaskById(external.id))!.status,
        DownloadStatus.canceled,
      );
      await repository.deleteTask(external.id);
      await repository.updateExternalResult(stale);
      expect(await repository.getTaskById(external.id), isNull);
      external.id = Isar.autoIncrement;
      external.status = DownloadStatus.paused;
      await repository.putTask(external);
      final imported = (await repository.getTaskById(external.id))!;
      imported.status = DownloadStatus.completed;
      await repository.updateExternalResult(imported);
      expect(
        (await repository.getTaskById(external.id))!.status,
        DownloadStatus.completed,
      );
      c.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await db.close();
    },
  );
}
