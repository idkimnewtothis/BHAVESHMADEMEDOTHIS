import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../anymex_extension_runtime_bridge.dart';
import '../../Settings/KvStore.dart';
import 'AniyomiSourceMethods.dart';
import 'Models/Source.dart';
import 'ExtensionMetadata.dart';
import 'PbDecoder.dart';

class AniyomiExtensions extends Extension {
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
      (getVal<List<String>>('animeRepositories', defaultValue: []) ?? [])
          .map((s) => Repo(url: s, managerId: id))
          .toList();
  @override
  Future<void> fetchInstalledAnimeExtensions() async {
    final result = await platform
            .invokeListMethod<dynamic>('getInstalledAnimeExtensions') ??
        [];
    getInstalledRx(ItemType.anime).value = result
        .map((m) => ASource.fromJson(Map<String, dynamic>.from(m as Map))
          ..managerId = id)
        .toList();
    final errors =
        await platform.invokeListMethod<dynamic>('getLoadFailures') ?? [];
    loadFailures
      ..clear()
      ..addAll(errors.map((e) => Map<String, String>.from(e as Map)));
  }

  Future<List<Source>> getInstalledAnimeExtensions() async {
    await fetchInstalledAnimeExtensions();
    return getInstalledRx(ItemType.anime).value;
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
  Future<http.Response> _get(Uri uri) async {
    if (uri.scheme != 'https')
      throw const FormatException('Repository and APK URLs must use HTTPS');
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200)
      throw HttpException('${uri.host}: HTTP ${response.statusCode}', uri: uri);
    return response;
  }

  Future<List<ExtensionMetadata>> _read(Uri uri, [int depth = 0]) async {
    if (depth > 4)
      throw const FormatException('Repository redirect limit exceeded');
    final response = await _get(uri);
    var bytes = response.bodyBytes.toList();
    if (bytes.length > 1 && bytes[0] == 31 && bytes[1] == 139)
      bytes = gzip.decode(bytes);
    final text = utf8.decode(bytes, allowMalformed: true).trimLeft();
    if (!text.startsWith('[')) {
      final map = text.startsWith('{')
          ? jsonDecode(text) as Map
          : PbDecoder.decodeStore(bytes);
      if (map['index_v2'] is String)
        return _read(uri.resolve(map['index_v2']), depth + 1);
      if (map['meta'] != null)
        return _read(uri.resolve('index.min.json'), depth + 1);
      if (map['extensionListUrl'] is String)
        return _read(uri.resolve(map['extensionListUrl']), depth + 1);
    }
    return ExtensionMetadata.parse(bytes, uri);
  }

  @override
  Future<void> fetchAnimeExtensions() async {
    final repos = _repos();
    getReposRx(ItemType.anime).value = repos;
    final available = <Source>[];
    _metadata.clear();
    _repoByPackage.clear();
    repositoryErrors.clear();
    for (final repo in repos) {
      try {
        for (final e in await _read(Uri.parse(repo.url))) {
          _metadata[e.packageName] = e;
          _repoByPackage[e.packageName] = repo.url;
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
              itemType: ItemType.anime)
            ..managerId = id);
        }
      } catch (e) {
        repositoryErrors[repo.url] = e.toString();
      }
    }
    for (final source
        in getInstalledRx(ItemType.anime).value.whereType<ASource>()) {
      final e = _metadata[source.pkgName];
      source.hasUpdate = e != null && e.version != source.version;
      source.versionLast = e?.version;
      source.repo = _repoByPackage[source.pkgName];
      if (e != null) source.isNsfw = e.nsfw;
    }
    getRawAvailableRx(ItemType.anime).value = available;
    getAvailableRx(ItemType.anime).value = available;
    if (repositoryErrors.isNotEmpty && available.isEmpty)
      throw StateError(repositoryErrors.entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\n'));
  }

  @override
  Future<void> addRepo(String url, ItemType type) async {
    if (type != ItemType.anime)
      throw UnsupportedError('No manga sources in this build');
    final uri = Uri.parse(url);
    await _read(uri);
    final repos = _repos().map((r) => r.url).toSet()..add(url);
    setVal('animeRepositories', repos.toList());
    await fetchAnimeExtensions();
  }

  @override
  Future<void> removeRepo(String url, ItemType type) async {
    setVal('animeRepositories',
        _repos().map((r) => r.url).where((r) => r != url).toList());
    await fetchAnimeExtensions();
  }

  Future<String> repositoryFingerprint(Source source) async {
    final uri = Uri.parse(source.repo ??
        (throw StateError('Repository missing for ${source.name}')));
    final response = await _get(uri);
    var bytes = response.bodyBytes.toList();
    if (bytes.length > 1 && bytes[0] == 31 && bytes[1] == 139)
      bytes = gzip.decode(bytes);
    final text = utf8.decode(bytes, allowMalformed: true).trimLeft();
    if (!text.startsWith('[')) {
      final data = text.startsWith('{')
          ? jsonDecode(text) as Map
          : PbDecoder.decodeStore(bytes);
      if (data['signingKey'] != null || data['meta'] != null)
        return ExtensionMetadata.fingerprint(data);
    }
    return ExtensionMetadata.fingerprint(
        jsonDecode((await _get(uri.resolve('repo.json'))).body) as Map);
  }

  bool isTrusted(Source source, String fingerprint) =>
      getVal<String>('repoTrust:${source.repo}') == fingerprint;
  void trustRepository(Source source, String fingerprint) =>
      setVal('repoTrust:${source.repo}', fingerprint);
  @override
  Future<void> installSource(Source source, {String? customPath}) async {
    if (source is! ASource ||
        source.itemType != ItemType.anime ||
        !(source.pkgName?.startsWith('eu.kanade.tachiyomi.animeextension.') ??
            false))
      throw UnsupportedError('Only Aniyomi anime APKs are supported');
    final fingerprint = await repositoryFingerprint(source);
    if (!isTrusted(source, fingerprint))
      throw StateError(
          'Trust this repository and its signing fingerprint before installing');
    final metadata = _metadata[source.pkgName];
    final url = metadata?.apkUrl ??
        source.apkUrl ??
        (throw StateError('APK URL missing'));
    final dir = Directory('${(await getTemporaryDirectory()).path}/anime-apks');
    await dir.create(recursive: true);
    final file = File('${dir.path}/${source.pkgName}.apk');
    await file.writeAsBytes((await _get(Uri.parse(url))).bodyBytes,
        flush: true);
    await platform.invokeMethod('installVerifiedApk', {
      'path': file.path,
      'package': source.pkgName,
      'fingerprint': fingerprint
    });
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
