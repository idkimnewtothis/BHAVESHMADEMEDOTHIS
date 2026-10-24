import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../anymex_extension_runtime_bridge.dart';
import '../../Settings/KvStore.dart';
import 'AniyomiSourceMethods.dart';
import 'Models/Source.dart';
import 'ExtensionMetadata.dart';
import 'RepositoryClient.dart';
import 'RepositoryUrl.dart';

class AniyomiExtensions extends Extension {
  final RepositoryClient repositoryClient;
  AniyomiExtensions({RepositoryClient? repositoryClient})
      : repositoryClient = repositoryClient ?? RepositoryClient();
  ItemType get mediaType => ItemType.anime;
  String get repositoryKey => 'animeRepositories';
  String get packagePrefix => 'eu.kanade.tachiyomi.animeextension.';
  static const platform = MethodChannel('aniyomiExtensionBridge');
  @override
  String get id => 'aniyomi';
  @override
  String get name => 'Aniyomi';
  @override
  String get icon => '';
  @override
  bool get supportsManga => false;
  @override
  bool get supportsNovel => false;
  @override
  bool get requiresPlugin => false;
  @override
  SourceMethods createSourceMethods(Source source) =>
      AniyomiSourceMethods(source);
  final loadFailures = <Map<String, String>>[];
  final repositoryErrors = <String, String>{};
  final _metadata = <String, ExtensionMetadata>{};
  final _repoByPackage = <String, String>{};
  List<Repo> _repos() =>
      (getVal<List<String>>(repositoryKey, defaultValue: []) ?? [])
          .map((s) => Repo(url: s, managerId: id))
          .toList();
  @override
  Future<void> fetchInstalledAnimeExtensions() async {
    final result = await platform.invokeListMethod<dynamic>(
            mediaType == ItemType.anime
                ? 'getInstalledAnimeExtensions'
                : 'getInstalledMangaExtensions') ??
        [];
    getInstalledRx(mediaType).value = result
        .map((m) => ASource.fromJson(Map<String, dynamic>.from(m as Map))
          ..managerId = id)
        .toList();
    _decorateInstalled();
    final errors =
        await platform.invokeListMethod<dynamic>('getLoadFailures') ?? [];
    loadFailures
      ..clear()
      ..addAll(errors.map((e) => Map<String, String>.from(e as Map)));
  }

  Future<List<Source>> getInstalledAnimeExtensions() async {
    await fetchInstalledAnimeExtensions();
    return getInstalledRx(mediaType).value;
  }

  Future<List<Source>> getInstalledMangaExtensions() async => [];
  @override
  Future<void> fetchInstalledMangaExtensions() async {}
  @override
  Future<void> fetchInstalledNovelExtensions() async {}
  @override
  Future<void> fetchMangaExtensions() async {}
  @override
  Future<void> fetchNovelExtensions() async {}
  Future<List<ExtensionMetadata>> _read(Uri uri) =>
      repositoryClient.read(uri, manga: mediaType == ItemType.manga);

  Future<void>? _refresh;
  @override
  Future<void> fetchAnimeExtensions() =>
      _refresh ??= _fetchAnimeExtensions().whenComplete(() => _refresh = null);

  Future<void> _fetchAnimeExtensions() async {
    final repos = _repos();
    getReposRx(mediaType).value = repos;
    final available = <Source>[];
    final metadata = <String, ExtensionMetadata>{};
    final repoByPackage = <String, String>{};
    final errors = <String, String>{};
    for (final repo in repos) {
      try {
        for (final e in await _read(Uri.parse(repo.url))) {
          if (metadata.containsKey(e.packageName)) {
            errors[repo.url] =
                'Duplicate package ${e.packageName}; using ${repoByPackage[e.packageName]}';
            continue;
          }
          metadata[e.packageName] = e;
          repoByPackage[e.packageName] = repo.url;
          available.add(ASource(
              id: e.packageName,
              name: e.name,
              pkgName: e.packageName,
              apkName: e.apkUrl,
              iconUrl: e.iconUrl,
              lang: e.language,
              isNsfw: e.nsfw,
              version: e.version,
              repo: repo.url,
              itemType: mediaType)
            ..managerId = id);
        }
      } catch (e) {
        errors[repo.url] = e.toString();
      }
    }
    _metadata
      ..clear()
      ..addAll(metadata);
    _repoByPackage
      ..clear()
      ..addAll(repoByPackage);
    repositoryErrors
      ..clear()
      ..addAll(errors);
    _decorateInstalled();
    getRawAvailableRx(mediaType).value = available;
    getAvailableRx(mediaType).value = available;
    if (repositoryErrors.isNotEmpty && available.isEmpty) {
      throw StateError(repositoryErrors.entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\n'));
    }
  }

  void _decorateInstalled() {
    for (final source in getInstalledRx(mediaType).value.whereType<ASource>()) {
      final e = _metadata[source.pkgName];
      source.hasUpdate =
          e != null && compareVersions(e.version, source.version ?? '0') > 0;
      source.versionLast = e?.version;
      source.repo = _repoByPackage[source.pkgName];
      if (e != null) {
        source.isNsfw = e.nsfw;
        source.apkName = e.apkUrl;
      }
    }
  }

  @override
  Future<void> addRepo(String url, ItemType type) async {
    if (type != mediaType) {
      throw UnsupportedError('Repository type does not match this engine');
    }
    final uri = RepositoryUrl.normalize(url);
    url = uri.toString();
    final entries = await _read(uri);
    if (entries.isEmpty) {
      throw FormatException(
          'No ${mediaType.name} extensions in this repository. Check the selected engine.');
    }
    final repos = _repos().map((r) => r.url).toSet()..add(url);
    KvStore.setSync(repositoryKey, repos.toList());
    await fetchAnimeExtensions();
  }

  @override
  Future<void> removeRepo(String url, ItemType type) async {
    setVal(repositoryKey,
        _repos().map((r) => r.url).where((r) => r != url).toList());
    await fetchAnimeExtensions();
  }

  Future<String> repositoryFingerprint(Source source) =>
      repositoryClient.fingerprint(
          Uri.parse(source.repo ??
              (throw StateError('Repository missing for ${source.name}'))),
          manga: mediaType == ItemType.manga);

  bool isTrusted(Source source, String fingerprint) =>
      getVal<String>('repoTrust:${source.repo}') == fingerprint;
  void trustRepository(Source source, String fingerprint) =>
      KvStore.setSync('repoTrust:${source.repo}', fingerprint);
  @override
  Future<void> installSource(Source source, {String? customPath}) async {
    if (source is! ASource ||
        source.itemType != mediaType ||
        !(source.pkgName?.startsWith(packagePrefix) ?? false)) {
      throw UnsupportedError('Extension APK family does not match this engine');
    }
    final fingerprint = await repositoryFingerprint(source);
    if (!isTrusted(source, fingerprint)) {
      throw StateError(
          'Trust this repository and its signing fingerprint before installing');
    }
    final metadata = _repoByPackage[source.pkgName] == source.repo
        ? _metadata[source.pkgName]
        : null;
    final url = metadata?.apkUrl ??
        source.apkUrl ??
        (throw StateError('APK URL missing'));
    final dir = Directory('${(await getTemporaryDirectory()).path}/anime-apks');
    await dir.create(recursive: true);
    final attempt = await dir.createTemp('install-');
    final file = File('${attempt.path}/${source.pkgName}.apk');
    try {
      await repositoryClient.download(Uri.parse(url), file);
      final installed = await platform.invokeMethod<bool>(
          'installVerifiedApk', {
        'path': file.path,
        'package': source.pkgName,
        'fingerprint': fingerprint
      });
      if (installed != true) {
        throw StateError('Android did not confirm installation');
      }
    } finally {
      if (await attempt.exists()) await attempt.delete(recursive: true);
    }
  }

  @override
  Future<void> updateSource(Source source) => installSource(source);
  @override
  Future<void> uninstallSource(Source source) async {
    if (source is! ASource) throw UnsupportedError('Not an anime APK');
    await platform
        .invokeMethod('uninstallAnimeExtension', {'package': source.pkgName});
  }

  @override
  Set<String> get schemes => {'aniyomi'};
  @override
  void handleSchemes(Uri uri) {
    final url = ExtensionMetadata.deepLink(uri);
    if (url != null) unawaited(addRepo(url.toString(), ItemType.anime));
  }
}

/// Mihon manga runtime, sharing the verified repository/install workflow.
class MihonExtensions extends AniyomiExtensions {
  MihonExtensions({super.repositoryClient});
  @override
  String get id => 'mihon';
  @override
  String get name => 'Mihon';
  @override
  ItemType get mediaType => ItemType.manga;
  @override
  String get repositoryKey => 'mangaRepositories';
  @override
  String get packagePrefix => 'eu.kanade.tachiyomi.extension.';
  @override
  bool get supportsAnime => false;
  @override
  bool get supportsManga => true;
  @override
  Future<void> fetchInstalledMangaExtensions() =>
      super.fetchInstalledAnimeExtensions();
  @override
  Future<void> fetchInstalledAnimeExtensions() async {}
  @override
  Future<void> fetchMangaExtensions() => super.fetchAnimeExtensions();
  @override
  Future<void> fetchAnimeExtensions() async {}
  @override
  Future<void> addRepo(String url, ItemType type) async {
    if (type != mediaType) {
      throw ArgumentError('Select Manga for Mihon repositories');
    }
    final uri = RepositoryUrl.normalize(url);
    url = uri.toString();
    final entries = await _read(uri);
    if (entries.isEmpty) {
      throw FormatException(
          'No ${mediaType.name} extensions in this repository. Check the selected engine.');
    }
    KvStore.setSync(
        repositoryKey, {..._repos().map((r) => r.url), url}.toList());
    await fetchMangaExtensions();
  }

  @override
  Future<void> removeRepo(String url, ItemType type) async {
    setVal(repositoryKey,
        _repos().map((r) => r.url).where((r) => r != url).toList());
    await fetchMangaExtensions();
  }

  @override
  Set<String> get schemes => {'mihon', 'tachiyomi'};
  @override
  void handleSchemes(Uri uri) {
    if (schemes.contains(uri.scheme) && uri.host == 'add-repo') {
      final url = uri.queryParameters['url'];
      if (url != null) unawaited(addRepo(url, ItemType.manga));
    }
  }
}
