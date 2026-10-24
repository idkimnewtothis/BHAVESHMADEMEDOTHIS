import 'package:shonenx/features/moviebox/moviebox_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shonenx/source_engine/providers/anime_source.dart';
import 'package:shonenx/source_engine/providers/manga_source.dart';

final inbuiltAnimeSourcesProvider = Provider<List<AnimeSource>>((ref) {
  final moviebox = ref.watch(movieBoxSourceProvider);
  return [if (moviebox != null) moviebox];
}, name: 'inbuiltAnimeSourcesProvider');

final inbuiltMangaSourcesProvider = Provider<List<MangaSource>>((ref) {
  return [];
}, name: 'inbuiltMangaSourcesProvider');
