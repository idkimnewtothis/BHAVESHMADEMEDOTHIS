import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shonenx/core/router/app_navigator.dart';
import 'package:shonenx/features/downloads/providers/download_provider.dart';
import 'package:shonenx/features/downloads/domain/models/download_task.dart';
import 'package:shonenx/features/player/domain/player_mode.dart';
import 'package:shonenx/features/reader/domain/reader_mode.dart';
import 'package:shonenx/features/history/providers/history_provider.dart';
import 'package:shonenx/shared/models/unified_media.dart';
import 'package:shonenx/shared/models/unified_episode.dart';
import 'package:shonenx/shared/models/video_stream.dart';
import 'package:shonenx/source_engine/models/source_info.dart';
import 'package:shonenx/source_engine/models/chapter_page.dart';

/// Available before source discovery, so it also works without an extension or network.
class TitleDownloads extends ConsumerWidget {
  final UnifiedMedia media;
  const TitleDownloads({super.key, required this.media});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(downloadTasksProvider);
    return all.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not read downloads: $e')),
      data: (tasks) {
        final matches =
            tasks
                .where(
                  (t) =>
                      t.mediaId == media.id &&
                      t.isManga == (media.type == MediaType.MANGA),
                )
                .toList()
              ..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
        if (matches.isEmpty) {
          return const Center(
            child: Text(
              'No offline chapters or episodes yet.\nUse Batch Download in the online list.',
              textAlign: TextAlign.center,
            ),
          );
        }
        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete title downloads'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete downloads for this title?'),
                      content: Text(
                        '${matches.length} saved or queued chapters/episodes will be removed from ShonenX+.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Keep'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await ref.read(downloadManagerProvider.future);
                  final manager = ref.read(downloadManagerProvider.notifier);
                  for (final task in matches) {
                    await manager.deleteDownload(task.id);
                  }
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final task = matches[index];
                  final ready = task.status == DownloadStatus.completed;
                  return ListTile(
                    leading: Icon(
                      ready ? Icons.offline_pin : Icons.downloading,
                    ),
                    title: Text(
                      '${task.isManga ? 'Chapter' : 'Episode'} ${task.episodeNumber} · ${task.episodeTitle}',
                    ),
                    subtitle: Text(
                      '${task.sourceName}${task.scanlator.isEmpty ? '' : ' · ${task.scanlator}'}\n${ready ? '${(task.totalBytes / 1048576).toStringAsFixed(1)} MB · Offline' : '${task.status.name} · ${(task.progress * 100).round()}%'}${task.error.isEmpty ? '' : '\n${task.error}'}',
                    ),
                    onTap: ready ? () => _open(context, ref, task) : null,
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Download actions',
                      onSelected: (action) async {
                        await ref.read(downloadManagerProvider.future);
                        final manager = ref.read(
                          downloadManagerProvider.notifier,
                        );
                        if (action == 'delete') {
                          await manager.deleteDownload(task.id);
                        } else if (action == 'pause') {
                          await manager.pauseDownload(task.id);
                        } else {
                          await manager.startDownload(task);
                        }
                      },
                      itemBuilder: (_) => [
                        if (!ready && task.status != DownloadStatus.downloading)
                          const PopupMenuItem(
                            value: 'resume',
                            child: Text('Resume / Retry'),
                          ),
                        if (task.status == DownloadStatus.downloading ||
                            task.status == DownloadStatus.pending)
                          const PopupMenuItem(
                            value: 'pause',
                            child: Text('Pause'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete download'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    DownloadTask task,
  ) async {
    final paths = task.isManga ? task.pagePaths : [task.savePath];
    for (final path in paths) {
      if (!await File(path).exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'A downloaded file is missing. Delete this entry and download it again.',
              ),
            ),
          );
        }
        return;
      }
    }
    if (!context.mounted) return;
    final episode = UnifiedEpisode(
      id: task.episodeId,
      number: task.episodeNumber,
      title: task.episodeTitle,
      scanlator: task.scanlator,
    );
    final source = SourceInfo(
      id: task.sourceId,
      name: task.sourceName,
      type: SourceType.extension,
      mediaType: media.type,
    );
    final history = ref
        .read(historyForMediaProvider(media.id))
        .value
        ?.where((h) => h.itemNumber == task.episodeNumber)
        .firstOrNull;
    if (task.isManga) {
      context.pushReader(
        ReaderModeOnline(
          media: media,
          episode: episode,
          sourceInfo: source,
          startPosition: history?.progress.toInt() ?? 1,
          localPages: paths.map((path) => ChapterPage(url: path)).toList(),
        ),
      );
    } else {
      context.pushPlayer(
        PlayerModeOffline(
          filePath: task.savePath,
          title: media.title.getPreferedTitle,
          media: media,
          episode: episode,
          sourceInfo: source,
          startPosition: Duration(milliseconds: history?.progress.toInt() ?? 0),
          subtitles: task.subtitles
              .where((s) => s.url.startsWith('/') && File(s.url).existsSync())
              .map(
                (s) => SubtitleTrack(
                  url: s.url,
                  language: s.language,
                  label: s.label,
                ),
              )
              .toList(),
        ),
      );
    }
  }
}
