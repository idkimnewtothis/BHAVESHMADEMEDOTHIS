import 'package:isar_community/isar.dart';
import 'package:shonenx/features/downloads/domain/models/download_task.dart';

class DownloadRepository {
  final Isar _isar;

  DownloadRepository(this._isar);

  Future<void> putTask(DownloadTask task) async {
    task.updatedAt = DateTime.now();
    await _isar.writeTxn(() async {
      await _isar.downloadTasks.put(task);
    });
  }

  Future<void> updateProgress(DownloadTask incoming) async {
    await _isar.writeTxn(() async {
      final current = await _isar.downloadTasks.get(incoming.id);
      if (current == null || current.status != DownloadStatus.downloading) {
        return;
      }
      current.progress = incoming.progress;
      current.downloadedBytes = incoming.downloadedBytes;
      current.totalBytes = incoming.totalBytes;
      current.updatedAt = DateTime.now();
      await _isar.downloadTasks.put(current);
    });
  }

  /// Ignore a scan result if the task changed while Android copied its files.
  Future<void> updateExternalResult(DownloadTask incoming) async {
    await _isar.writeTxn(() async {
      final current = await _isar.downloadTasks.get(incoming.id);
      if (current == null ||
          !current.external ||
          current.updatedAt != incoming.updatedAt ||
          current.status == DownloadStatus.canceled ||
          current.status == DownloadStatus.downloading ||
          current.status == DownloadStatus.pending) {
        return;
      }
      incoming.updatedAt = DateTime.now();
      await _isar.downloadTasks.put(incoming);
    });
  }

  Future<void> deleteTask(Id id) async {
    await _isar.writeTxn(() async {
      await _isar.downloadTasks.delete(id);
    });
  }

  Future<DownloadTask?> getTaskByUrl(String url) async {
    return await _isar.downloadTasks.getByUrl(url);
  }

  Future<DownloadTask?> getTaskById(Id id) async {
    return await _isar.downloadTasks.get(id);
  }

  Future<List<DownloadTask>> getPendingOrPausedTasks() async {
    return await _isar.downloadTasks
        .filter()
        .statusBetween(DownloadStatus.pending, DownloadStatus.paused)
        .sortByCreatedAtDesc()
        .findAll();
  }

  Future<List<DownloadTask>> getUnfinishedTasks() async {
    return await _isar.downloadTasks
        .filter()
        .not()
        .statusEqualTo(DownloadStatus.completed)
        .findAll();
  }

  Future<DownloadTask?> findEpisode(
    String media,
    String source,
    String episode,
  ) => _isar.downloadTasks
      .filter()
      .mediaIdEqualTo(media)
      .sourceIdEqualTo(source)
      .episodeIdEqualTo(episode)
      .findFirst();

  Future<List<DownloadTask>> getExternalTasks() =>
      _isar.downloadTasks.filter().externalEqualTo(true).findAll();

  Stream<List<DownloadTask>> watchAllTasks() {
    return _isar.downloadTasks.where().sortByCreatedAtDesc().watch(
      fireImmediately: true,
    );
  }
}
