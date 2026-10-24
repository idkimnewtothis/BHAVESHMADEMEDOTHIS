import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shonenx/shared/providers/storage_provider.dart';
import 'package:shonenx/source_engine/moviebox/moviebox_source.dart';

final movieBoxEndpointProvider = NotifierProvider<MovieBoxEndpoint, String>(
  MovieBoxEndpoint.new,
);

class MovieBoxEndpoint extends Notifier<String> {
  @override
  String build() =>
      ref.read(sharedPreferencesProvider).getString('movieboxEndpoint') ?? '';
  Future<void> save(String endpoint) async {
    final value = endpoint.trim().isEmpty
        ? ''
        : MovieBoxSource.validateEndpoint(endpoint).toString();
    final saved = await ref
        .read(sharedPreferencesProvider)
        .setString('movieboxEndpoint', value);
    if (!saved) throw StateError('Could not save MovieBox connection. Retry.');
    state = value;
  }
}

final movieBoxSourceProvider = Provider<MovieBoxSource?>((ref) {
  final endpoint = ref.watch(movieBoxEndpointProvider);
  if (endpoint.isEmpty) return null;
  final source = MovieBoxSource(endpoint);
  ref.onDispose(source.close);
  return source;
});
