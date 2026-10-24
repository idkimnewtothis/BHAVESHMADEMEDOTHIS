import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shonenx/core/router/app_navigator.dart';
import 'package:shonenx/shared/models/unified_media.dart';
import 'package:shonenx/shared/widgets/app_scaffold.dart';
import 'moviebox_provider.dart';

class MovieBoxScreen extends ConsumerStatefulWidget {
  const MovieBoxScreen({super.key});
  @override
  ConsumerState<MovieBoxScreen> createState() => _MovieBoxScreenState();
}

class _MovieBoxScreenState extends ConsumerState<MovieBoxScreen> {
  final _search = TextEditingController();
  List<UnifiedMedia> _items = [];
  String _category = 'home';
  String? _error;
  bool _busy = false, _more = true;
  int _page = 0, _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool next = false}) async {
    if (next && _busy) return;
    final source = ref.read(movieBoxSourceProvider);
    if (source == null) return;
    final generation = ++_generation;
    final page = next ? _page + 1 : 1;
    setState(() {
      _busy = true;
      _error = null;
      if (!next) _items = [];
    });
    try {
      final query = _search.text.trim();
      final result = query.isEmpty
          ? await source.catalog(_category, page: page)
          : await source.searchCatalog(query, category: _category, page: page);
      if (!mounted || generation != _generation) return;
      final oldIds = _items.map((e) => e.id).toSet();
      setState(() {
        _items = {
          for (final m in [..._items, ...result]) m.id: m,
        }.values.toList();
        _page = page;
        _more = result.any((e) => !oldIds.contains(e.id));
      });
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _settings() async {
    var endpoint = ref.read(movieBoxEndpointProvider);
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Connect MovieBox'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter the URL of your moviebox-internal-api server. Use an HTTPS server URL. The GitHub repository is source code, not a server address.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: endpoint,
                onChanged: (value) => endpoint = value,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'https://your-server.example',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ref
                      .read(movieBoxEndpointProvider.notifier)
                      .save(endpoint);
                  if (context.mounted) Navigator.pop(context, true);
                } catch (e) {
                  if (context.mounted) update(() => error = e.toString());
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        _items = [];
        _error = null;
        _page = 0;
      });
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(movieBoxEndpointProvider).isNotEmpty;
    return AppScaffold(
      title: 'MovieBox UI',
      actions: [
        IconButton(
          onPressed: _settings,
          tooltip: 'MovieBox connection',
          icon: const Icon(Icons.settings_ethernet),
        ),
      ],
      body: SafeArea(
        child: !configured
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.movie_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Connect your MovieBox server to browse anime, movies, and series.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _settings,
                        child: const Text('Connect server'),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _search,
                      onSubmitted: (_) => _load(),
                      decoration: InputDecoration(
                        labelText: 'Search MovieBox',
                        suffixIcon: IconButton(
                          onPressed: () => _load(),
                          tooltip: 'Search',
                          icon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final entry in {
                          'home': 'Featured',
                          'anime': 'Anime',
                          'movies': 'Movies',
                          'series': 'Series',
                        }.entries)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: Text(entry.value),
                              selected: _category == entry.key,
                              onSelected: (_) {
                                setState(() => _category = entry.key);
                                _load();
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_busy)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Loading MovieBox',
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'MovieBox: $_error',
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          TextButton(
                            onPressed: () => _load(next: _items.isNotEmpty),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  if (!_busy && _error == null && _items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'MovieBox returned no titles. Try another category or search.',
                      ),
                    ),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisExtent: 292,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final media = _items[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => context.pushDetails(
                              media: media,
                              mediaType: media.type,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: media.cover == null
                                      ? const Icon(Icons.movie_outlined)
                                      : Image.network(
                                          media.cover!,
                                          fit: BoxFit.cover,
                                          cacheWidth: 360,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                Icons.broken_image_outlined,
                                              ),
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    media.title.getPreferedTitle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    media.type.displayName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_items.isNotEmpty && _more)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _load(next: true),
                        child: const Text('Load more'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
