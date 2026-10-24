import 'package:shonenx/core/network/http_client.dart';
import 'package:shonenx/core/utils/http_x.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:byte_me/byte_me.dart' as bm;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:shonenx/shared/providers/database_provider.dart';
import 'package:shonenx/core/services/notification_service.dart';
import 'package:shonenx/core/services/one_dm_service.dart';
import 'package:shonenx/features/downloads/domain/download_repository.dart';
import 'package:shonenx/features/downloads/domain/models/download_task.dart';
import 'package:shonenx/features/downloads/domain/work_queue.dart';
import 'package:shonenx/features/downloads/providers/download_prefs_provider.dart';
import 'package:shonenx/features/downloads/utils/download_url_helper.dart';
import 'package:shonenx/shared/models/unified_media.dart';
import 'package:shonenx/shared/models/unified_episode.dart';
import 'package:shonenx/source_engine/models/source_info.dart';
import 'package:shonenx/source_engine/source_engine_provider.dart';
import 'package:shonenx/core/utils/app_logger.dart';

final downloadNoticeProvider =
    Provider<Future<void> Function(int, String, bool)>(
      (ref) =>
          (id, title, success) => success
          ? NotificationService.instance.showDownloadComplete(
              id: id,
              title: title,
            )
          : NotificationService.instance.showDownloadFailed(
              id: id,
              title: title,
            ),
    );

final downloadRepositoryProvider = Provider<DownloadRepository>(
  (ref) => DownloadRepository(ref.watch(databaseProvider)),
);
final downloadTasksProvider = StreamProvider<List<DownloadTask>>(
  (ref) => ref.watch(downloadRepositoryProvider).watchAllTasks(),
);
final downloadManagerProvider =
    AsyncNotifierProvider<DownloadManagerNotifier, DownloadManagerNotifier>(
      DownloadManagerNotifier.new,
    );

class DownloadManagerNotifier extends AsyncNotifier<DownloadManagerNotifier> {
  late WorkQueue _queue;
  final _jobs = <int, bm.DownloadTask>{};
  final _engines = <int, bm.ByteMe>{};
  final _stopped = <int>{};
  final _running = <int>{};
  bool _syncing = false;
  final _finished = <int, Completer<void>>{};
  static const _platform = MethodChannel('shonenxplus/downloads');
  DownloadRepository get repo => ref.read(downloadRepositoryProvider);
  final _log = AppLogger.scope(DownloadManagerNotifier);

  @override
  Future<DownloadManagerNotifier> build() async {
    final prefs = await ref.read(downloadPrefsProvider.future);
    _queue = WorkQueue(
      concurrency: prefs.concurrentDownloads.clamp(1, 4),
      run: _run,
      onError: (id, e, st) => _log.e('Queue $id failed', e, st),
    );
    final lifecycle = AppLifecycleListener(
      onResume: () => unawaited(syncExternal()),
    );
    final poll = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(syncExternal()),
    );
    ref.onDispose(() {
      lifecycle.dispose();
      poll.cancel();
      _queue.close();
      _stopped.addAll(_running);
      for (final engine in _engines.values) {
        engine.dispose();
      }
    });
    for (final task in await repo.getUnfinishedTasks()) {
      if (task.external) continue;
      if (task.status == DownloadStatus.downloading) {
        task.status = DownloadStatus.pending;
        await repo.putTask(task);
      }
      if (task.status == DownloadStatus.pending) _queue.add(task.id);
    }
    unawaited(syncExternal());
    return this;
  }

  Future<void> chooseExternalFolder() async {
    if (await _platform.invokeMethod<bool>('chooseFolder') == true) {
      await syncExternal(reportErrors: true);
    }
  }

  Future<void> syncExternal({bool reportErrors = false}) async {
    if (!Platform.isAndroid || _syncing || !ref.mounted) return;
    _syncing = true;
    try {
      final tasks = await repo.getExternalTasks();
      final requests = <Map<String, String>>[];
      for (final task in tasks) {
        if (_running.contains(task.id) ||
            task.status == DownloadStatus.canceled) {
          continue;
        }
        for (final path in task.isManga ? task.pagePaths : [task.savePath]) {
          if (!await File(path).exists()) {
            requests.add({'name': p.basename(path), 'path': path});
          }
        }
        for (final sub in task.subtitles) {
          if (sub.url.startsWith('/')) continue;
          final name = DownloadUrlHelper.formatSubtitleFileName(
            videoFileName: task.fileName,
            language: sub.language,
            label: sub.label,
            subtitleUrl: sub.url,
          );
          requests.add({
            'name': name,
            'path': p.join(p.dirname(task.savePath), name),
          });
        }
      }
      if (requests.isNotEmpty) await _platform.invokeMethod('sync', requests);
      if (!ref.mounted) return;
      for (final task in tasks) {
        if (_running.contains(task.id) ||
            task.status == DownloadStatus.canceled) {
          continue;
        }
        final paths = task.isManga ? task.pagePaths : [task.savePath];
        var complete = paths.isNotEmpty;
        var size = 0;
        for (final path in paths) {
          final file = File(path);
          if (!await file.exists()) {
            complete = false;
            break;
          }
          size += await file.length();
        }
        for (final sub in task.subtitles) {
          if (sub.url.startsWith('/')) continue;
          final name = DownloadUrlHelper.formatSubtitleFileName(
            videoFileName: task.fileName,
            language: sub.language,
            label: sub.label,
            subtitleUrl: sub.url,
          );
          final local = p.join(p.dirname(task.savePath), name);
          if (await File(local).exists()) sub.url = local;
        }
        if (complete) {
          task.status = DownloadStatus.completed;
          task.progress = 1;
          task.totalBytes = size;
          task.downloadedBytes = size;
          task.error = '';
        }
        await repo.updateExternalResult(task);
      }
    } catch (e, st) {
      _log.e('1DM folder sync failed', e, st);
      if (reportErrors) rethrow;
    } finally {
      _syncing = false;
    }
  }

  Future<void> startDownload(DownloadTask task) async {
    if (task.status == DownloadStatus.completed) return;
    if (_running.contains(task.id)) {
      if (!_stopped.contains(task.id)) return;
      await _finished[task.id]?.future;
    }
    // Persist before any network, source lookup, or external-app handoff.
    task.headersMap = DownloadUrlHelper.extractHeadersFromUrl(
      task.url,
      task.headersMap,
    );
    task.url = DownloadUrlHelper.extractUrl(task.url);
    if (!task.isManga &&
        task.sourceId.isNotEmpty &&
        task.episodeId.isNotEmpty) {
      final existing = await repo.findEpisode(
        task.mediaId,
        task.sourceId,
        task.episodeId,
      );
      if (existing != null && existing.id != task.id) {
        if (existing.status != DownloadStatus.failed &&
            existing.status != DownloadStatus.canceled) {
          return;
        }
        task.id = existing.id;
      }
      final prefs = await ref.read(downloadPrefsProvider.future);
      final identity = sha256
          .convert(
            utf8.encode('${task.mediaId}\n${task.sourceId}\n${task.episodeId}'),
          )
          .toString()
          .substring(0, 16);
      if (!task.fileName.contains(identity)) {
        task.fileName =
            '${p.basenameWithoutExtension(task.fileName)}-$identity${p.extension(task.fileName)}';
      }
      task.savePath = p.join(
        prefs.downloadPath,
        'episodes',
        identity,
        task.fileName,
      );
    }
    task.status = DownloadStatus.pending;
    task.error = '';
    task.attempts = 0;
    _stopped.remove(task.id);
    await repo.putTask(task);
    _queue.add(task.id);
  }

  Future<void> queueChapter(
    UnifiedMedia media,
    UnifiedEpisode chapter,
    SourceInfo source, {
    bool external = false,
  }) async {
    final prefs = await ref.read(downloadPrefsProvider.future);
    final key = sha256
        .convert(utf8.encode('${media.id}\n${source.id}\n${chapter.id}'))
        .toString();
    final url = 'chapter://$key';
    final previous = await repo.getTaskByUrl(url);
    if (previous != null &&
        previous.status != DownloadStatus.failed &&
        previous.status != DownloadStatus.canceled) {
      return;
    }
    final task = previous ?? DownloadTask();
    task
      ..url = url
      ..isManga = true
      ..external = external
      ..mediaId = media.id
      ..mediaTitle = media.title.getPreferedTitle
      ..sourceId = source.id
      ..sourceName = source.name
      ..episodeId = chapter.id
      ..episodeTitle = chapter.title ?? ''
      ..episodeNumber = chapter.number
      ..scanlator = chapter.scanlator ?? ''
      ..fileName = '${media.title.getPreferedTitle} — Chapter ${chapter.number}'
      ..savePath = p.join(prefs.downloadPath, 'chapters', key);
    await startDownload(task);
  }

  void _check(int id) {
    if (!ref.mounted || _stopped.contains(id)) throw const _Stopped();
  }

  Future<void> _service(bool start) async {
    if (!Platform.isAndroid) return;
    try {
      await _platform.invokeMethod(start ? 'start' : 'stop');
    } catch (e, st) {
      _log.e('Download foreground service failed', e, st);
    }
  }

  Future<void> _waitForWifi(DownloadTask task) async {
    if (!Platform.isAndroid ||
        !(await ref.read(downloadPrefsProvider.future)).wifiOnly) {
      return;
    }
    while (await _platform.invokeMethod<bool>('wifiAvailable') != true) {
      _check(task.id);
      task.error = 'Waiting for Wi-Fi';
      await repo.putTask(task);
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    _check(task.id);
    task.error = '';
  }

  Future<void> _run(int id) async {
    final task = await repo.getTaskById(id);
    if (task == null || task.status != DownloadStatus.pending) return;
    _running.add(id);
    _finished[id] = Completer<void>();
    await _service(true);
    final engine = bm.ByteMe(maxConcurrentDownloads: 1);
    _engines[id] = engine;
    try {
      while (true) {
        _check(id);
        task.status = DownloadStatus.downloading;
        task.attempts++;
        await repo.putTask(task);
        try {
          await _waitForWifi(task);
          if (task.isManga) {
            await _chapter(task, engine);
          } else {
            await _video(task, engine);
          }
          _check(id);
          if (!task.external) {
            task.status = DownloadStatus.completed;
            task.progress = 1;
            task.error = '';
            await repo.putTask(task);
            await ref.read(downloadNoticeProvider)(id, task.fileName, true);
          }
          break;
        } on _Stopped {
          rethrow;
        } catch (e) {
          _check(id);
          task.error = '${task.sourceName}: $e';
          task.status = task.external || task.attempts >= 3
              ? DownloadStatus.failed
              : DownloadStatus.pending;
          await repo.putTask(task);
          if (task.status == DownloadStatus.failed) {
            await ref.read(downloadNoticeProvider)(id, task.fileName, false);
            break;
          }
          await Future<void>.delayed(Duration(seconds: 1 << task.attempts));
        }
      }
    } on _Stopped {
      // Pause/cancel owns the persisted state; a late network result cannot undo it.
    } finally {
      engine.dispose();
      _jobs.remove(id);
      _engines.remove(id);
      _running.remove(id);
      _finished.remove(id)?.complete();
      if (_running.isEmpty) await _service(false);
    }
  }

  Future<void> _file(
    DownloadTask task,
    bm.DownloadTask job, {
    double base = 0,
    double weight = 1,
  }) async {
    _jobs[task.id] = job;
    final done = Completer<void>();
    var last = DateTime.fromMillisecondsSinceEpoch(0);
    Future<void> writes = Future.value();
    final progress = job.progressStream.listen((value) {
      final now = DateTime.now();
      if (now.difference(last).inMilliseconds < 750 && value.percent < 1) {
        return;
      }
      last = now;
      writes = writes
          .then((_) async {
            _check(task.id);
            task.progress = base + weight * value.percent;
            task.downloadedBytes = value.receivedBytes;
            task.totalBytes = value.totalBytes ?? 0;
            await repo.updateProgress(task);
            if (Platform.isAndroid) {
              await _platform.invokeMethod('progress', {
                'title': task.fileName,
                'progress': (task.progress * 100).round(),
              });
            }
          })
          .catchError((Object e, StackTrace st) {
            if (e is! _Stopped) _log.e('Progress persistence failed', e, st);
          });
    });
    void status(bm.DownloadStatus status) {
      if (done.isCompleted) return;
      if (status == bm.DownloadStatus.completed) {
        done.complete();
      } else if (status == bm.DownloadStatus.failed) {
        done.completeError(
          StateError('Transfer failed; retry or refresh the source URL.'),
        );
      } else if (status == bm.DownloadStatus.paused ||
          status == bm.DownloadStatus.cancelled) {
        done.completeError(const _Stopped());
      }
    }

    final subscription = job.statusStream.listen(
      status,
      onError: (Object error) {
        if (!done.isCompleted) done.completeError(error);
      },
    );
    status(job.status);
    try {
      await done.future;
    } finally {
      await progress.cancel();
      await subscription.cancel();
      await writes;
    }
    _check(task.id);
  }

  Future<void> _chapter(DownloadTask task, bm.ByteMe engine) async {
    final source = ref.read(
      mangaSourceProvider(
        SourceInfo(
          id: task.sourceId,
          name: task.sourceName,
          type: SourceType.extension,
          mediaType: MediaType.MANGA,
        ),
      ),
    );
    final pages = await source.getPages(task.episodeId);
    _check(task.id);
    if (pages.isEmpty) throw StateError('Chapter returned no pages');
    await Directory(task.savePath).create(recursive: true);
    if (task.external) {
      final prefix = sha256
          .convert(utf8.encode(task.url))
          .toString()
          .substring(0, 16);
      task.pagePaths = List.generate(
        pages.length,
        (i) => p.join(
          task.savePath,
          '$prefix-${(i + 1).toString().padLeft(5, '0')}.jpg',
        ),
      );
      await repo.putTask(task);
      final groups = <String, List<int>>{};
      for (var i = 0; i < pages.length; i++) {
        final headers = (pages[i].headers ?? {}).entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        final key = jsonEncode(Map.fromEntries(headers));
        groups.putIfAbsent(key, () => []).add(i);
      }
      for (final indices in groups.values) {
        _check(task.id);
        final sent = await OneDMService.instance.downloadBatch(
          urls: indices.map((i) => pages[i].url).toList(),
          fileNames: indices.map((i) => p.basename(task.pagePaths[i])).toList(),
          headers: pages[indices.first].headers,
        );
        if (!sent) {
          throw StateError(
            '1DM is not installed or rejected the chapter batch',
          );
        }
      }
      task.status = DownloadStatus.paused;
      task.error =
          'Sent to 1DM. Select its download folder in Downloads to sync completed files.';
      await repo.putTask(task);
      return;
    }
    final paths = <String>[];
    for (var i = 0; i < pages.length; i++) {
      _check(task.id);
      await _waitForWifi(task);
      final name =
          '${sha256.convert(utf8.encode(task.url)).toString().substring(0, 16)}-${(i + 1).toString().padLeft(5, '0')}.jpg';
      final path = p.join(task.savePath, name);
      paths.add(path);
      if (!task.pagePaths.contains(path) || !await File(path).exists()) {
        await _file(
          task,
          engine.download(
            id: '${task.id}:$i:${task.attempts}',
            url: Uri.parse(pages[i].url),
            savePath: '$path.part',
            headers: pages[i].headers,
          ),
          base: i / pages.length,
          weight: 1 / pages.length,
        );
        _check(task.id);
        await File('$path.part').rename(path);
        task.pagePaths = [...paths];
        await repo.putTask(task);
      }
    }
    task.pagePaths = paths;
    if (!task.external) {
      var bytes = 0;
      for (final path in paths) {
        bytes += await File(path).length();
      }
      task.totalBytes = bytes;
      task.downloadedBytes = bytes;
    }
  }

  Future<void> _video(DownloadTask task, bm.ByteMe engine) async {
    final prefs = await ref.read(downloadPrefsProvider.future);
    _check(task.id);
    if (prefs.useOneDM || task.external) {
      final success = await OneDMService.instance.download(
        url: task.url,
        fileName: task.fileName,
        headers: task.headersMap,
        subtitleUrls: task.subtitles.map((s) => s.url).toList(),
        subtitleFileNames: task.subtitles
            .map(
              (s) => DownloadUrlHelper.formatSubtitleFileName(
                videoFileName: task.fileName,
                language: s.language,
                label: s.label,
                subtitleUrl: s.url,
              ),
            )
            .toList(),
      );
      if (!success) throw StateError('1DM is not installed');
      task.external = true;
      task.status = DownloadStatus.paused;
      task.error =
          'Sent to 1DM. Select its download folder in Downloads to sync completed files.';
      await repo.putTask(task);
      return;
    }
    if (DownloadUrlHelper.isTorrent(task.url)) {
      throw StateError('Torrent downloads are unsupported');
    }
    await File(task.savePath).parent.create(recursive: true);
    // Retain original URLs in persistent state; temporary proxy URLs never survive restart.
    final isHls =
        task.isM3u8 ||
        Uri.parse(task.url).path.toLowerCase().endsWith('.m3u8') ||
        await ref
            .read(httpClientProvider)
            .isHLS(task.url, headers: task.headersMap)
            .timeout(const Duration(seconds: 20));
    _check(task.id);
    task.isM3u8 = isHls;
    if (isHls) {
      task.fileName = p.setExtension(task.fileName, '.mkv');
      task.savePath = p.setExtension(task.savePath, '.mkv');
      await repo.putTask(task);
    }
    // FFmpeg infers its container from the final suffix, including partial output.
    final temp = '${task.savePath}.part${p.extension(task.savePath)}';
    final subs = task.subtitles
        .map(
          (s) => bm.SubtitleTrack(
            url: s.url,
            language: s.language,
            title: s.label,
            headers: task.headersMap,
          ),
        )
        .toList();
    final job = isHls
        ? engine.downloadHls(
            id: '${task.id}:${task.attempts}',
            url: Uri.parse(task.url),
            savePath: temp,
            headers: task.headersMap,
            maxConcurrentSegments: prefs.concurrentSegments,
            remuxer: prefs.remuxerPreference == RemuxerPreference.builtin
                ? bm.MkvRemuxer(subtitles: subs)
                : bm.FfmpegRemuxer(subtitles: subs),
          )
        : engine.download(
            id: '${task.id}:${task.attempts}',
            url: Uri.parse(task.url),
            savePath: temp,
            headers: task.headersMap,
          );
    await _file(task, job);
    _check(task.id);
    if (!await File(temp).exists() || await File(temp).length() == 0) {
      throw StateError('Downloaded file is empty');
    }
    await File(temp).rename(task.savePath);
    if (!isHls) {
      for (var i = 0; i < task.subtitles.length; i++) {
        final sub = task.subtitles[i];
        final path = p.join(
          p.dirname(task.savePath),
          DownloadUrlHelper.formatSubtitleFileName(
            videoFileName: task.fileName,
            language: sub.language,
            label: sub.label,
            subtitleUrl: sub.url,
          ),
        );
        await _file(
          task,
          engine.download(
            id: '${task.id}:sub:$i',
            url: Uri.parse(sub.url),
            savePath: path,
            headers: task.headersMap,
          ),
        );
        sub.url = path;
      }
    }
    task.downloadedBytes = await File(task.savePath).length();
    task.totalBytes = task.downloadedBytes;
  }

  Future<void> pauseDownload(int id) async {
    _stopped.add(id);
    _queue.remove(id);
    _jobs[id]?.pause();
    final task = await repo.getTaskById(id);
    if (task != null) {
      task.status = DownloadStatus.paused;
      await repo.putTask(task);
    }
  }

  Future<void> cancelDownload(int id) async {
    _stopped.add(id);
    _queue.remove(id);
    _jobs[id]?.cancel();
    final task = await repo.getTaskById(id);
    if (task != null) {
      task.status = DownloadStatus.canceled;
      await repo.putTask(task);
    }
  }

  Future<void> deleteDownload(int id) async {
    await cancelDownload(id);
    await _finished[id]?.future;
    final task = await repo.getTaskById(id);
    if (task == null) return;
    if (task.isManga) {
      final dir = Directory(task.savePath);
      if (await dir.exists()) await dir.delete(recursive: true);
    } else {
      final file = File(task.savePath);
      if (await file.exists()) await file.delete();
      for (final sub in task.subtitles) {
        if (sub.url.startsWith('/') &&
            p.dirname(sub.url) == p.dirname(task.savePath)) {
          final subtitle = File(sub.url);
          if (await subtitle.exists()) await subtitle.delete();
        }
      }
      final partial = File(
        '${task.savePath}.part${p.extension(task.savePath)}',
      );
      if (await partial.exists()) await partial.delete();
    }
    await repo.deleteTask(id);
  }
}

class _Stopped implements Exception {
  const _Stopped();
}
