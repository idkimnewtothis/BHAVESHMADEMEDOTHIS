import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shonenx/features/discovery/presentation/widgets/tabs/episodes_tab.dart';
import 'package:shonenx/features/downloads/domain/models/download_task.dart';
import 'package:shonenx/features/downloads/providers/download_provider.dart';
import 'package:shonenx/shared/models/unified_media.dart';
import 'package:shonenx/source_engine/models/source_info.dart';
import 'package:shonenx/source_engine/source_registry.dart';

void main() {
  for (final manga in [true, false]) {
    testWidgets(
      '${manga ? 'manga' : 'anime'} offline toggle works while source discovery never returns',
      (tester) async {
        final pendingSources = Completer<List<SourceInfo>>();
        DownloadTask task(String mediaId, bool isManga, String title) =>
            DownloadTask()
              ..mediaId = mediaId
              ..isManga = isManga
              ..episodeTitle = title
              ..episodeNumber = 1
              ..sourceName = 'Unavailable source'
              ..status = DownloadStatus.completed;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              availableMangaSourcesProvider.overrideWith(
                (ref) => pendingSources.future,
              ),
              availableAnimeSourcesProvider.overrideWith(
                (ref) => pendingSources.future,
              ),
              downloadTasksProvider.overrideWith(
                (ref) => Stream.value([
                  task('saved-title', manga, 'Saved item'),
                  task('different-title', manga, 'Other title'),
                  task('saved-title', !manga, 'Other media type'),
                ]),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: EpisodesTabWidget(
                  media: UnifiedMedia(
                    id: 'saved-title',
                    type: manga ? MediaType.MANGA : MediaType.ANIME,
                    title: const MediaTitle(english: 'Saved title'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(
          find.text(manga ? 'Offline chapters' : 'Offline episodes'),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Saved item'), findsOneWidget);
        expect(find.textContaining('Other title'), findsNothing);
        expect(find.textContaining('Other media type'), findsNothing);
        expect(find.textContaining('Offline'), findsWidgets);
        expect(pendingSources.isCompleted, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
