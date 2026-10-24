import 'dart:convert';
import 'dart:io';
import 'PbDecoder.dart';

/// Shared repository schema; each manager selects its own APK family.
class ExtensionMetadata {
  final String name, packageName, apkUrl, language, version, iconUrl;
  final num libVersion;
  final int versionCode;
  final bool nsfw;
  const ExtensionMetadata(
      {required this.name,
      required this.packageName,
      required this.apkUrl,
      required this.language,
      required this.version,
      required this.iconUrl,
      required this.libVersion,
      required this.versionCode,
      required this.nsfw});
  static String requiredString(Map m, String key) {
    final value = m[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing or invalid required field: $key');
    }
    return value;
  }

  static List<ExtensionMetadata> parse(List<int> input, Uri index,
      {void Function(String)? log, bool manga = false}) {
    var bytes = input;
    if (bytes.length > 1 && bytes[0] == 31 && bytes[1] == 139) {
      bytes = gzip.decode(bytes);
    }
    if (bytes.isEmpty) throw const FormatException('Repository index is empty');
    final first =
        bytes.firstWhere((b) => ![9, 10, 13, 32].contains(b), orElse: () => 0);
    final dynamic data = first == 91 || first == 123
        ? jsonDecode(utf8.decode(bytes))
        : PbDecoder.decodeIndex(bytes, manga: manga);
    final dynamic entries = data is List
        ? data
        : data['extensionList']?['extensions'] ?? data['extensions'];
    if (entries is! List) {
      throw const FormatException(
          'Missing required field: extensionList.extensions');
    }
    final seen = <String>{};
    final output = <ExtensionMetadata>[];
    for (final entry in entries) {
      if (entry is! Map) {
        throw const FormatException('Extension entry must be an object');
      }
      final modern = entry.containsKey('packageName');
      final pkg = requiredString(entry, modern ? 'packageName' : 'pkg');
      if (!seen.add(pkg)) throw FormatException('Duplicate package name: $pkg');
      if (!pkg.startsWith(manga
          ? 'eu.kanade.tachiyomi.extension.'
          : 'eu.kanade.tachiyomi.animeextension.')) {
        continue;
      }
      final name = requiredString(entry, 'name');
      final version = requiredString(entry, modern ? 'versionName' : 'version');
      final lib = num.tryParse(modern
          ? requiredString(entry, 'extensionLib')
          : version.contains('.')
              ? version.substring(0, version.lastIndexOf('.'))
              : '');
      if (lib == null) throw FormatException('$pkg: invalid lib version');
      final code = entry[modern ? 'versionCode' : 'code'];
      final parsedCode = code is int ? code : int.tryParse('$code');
      if (parsedCode == null || parsedCode < 1) {
        throw FormatException('$pkg: missing or invalid version code');
      }
      final resources = modern ? entry['resources'] : entry;
      if (resources is! Map) throw FormatException('$pkg: missing resources');
      final raw = requiredString(resources, modern ? 'apkUrl' : 'apk');
      final apk = Uri.tryParse(raw);
      final url = apk?.hasScheme == true
          ? apk!
          : index.resolve(modern ? raw : 'apk/$raw');
      if (url.scheme != 'https') {
        throw FormatException('$pkg: APK URL must use HTTPS');
      }
      final sources = entry['sources'];
      final lang = modern
          ? (sources is List && sources.isNotEmpty
              ? requiredString(sources.first as Map, 'language')
              : 'all')
          : requiredString(entry, 'lang');
      final warning = entry['contentWarning'];
      final nsfw = modern
          ? ![1, 'SAFE', 'CONTENT_WARNING_SAFE'].contains(warning)
          : entry['nsfw'] == 1 || entry['isNsfw'] == true;
      const known = {
        'name',
        'pkg',
        'packageName',
        'apk',
        'apkUrl',
        'iconUrl',
        'lang',
        'code',
        'version',
        'nsfw',
        'isNsfw',
        'sources',
        'resources',
        'extensionLib',
        'versionCode',
        'versionName',
        'contentWarning',
        'isTorrent'
      };
      for (final key in entry.keys.where((key) => !known.contains(key))) {
        log?.call('$pkg: unknown optional field $key');
      }
      output.add(ExtensionMetadata(
          name: name.replaceFirst(RegExp(r'^(Aniyomi|Tachiyomi|Mihon): '), ''),
          packageName: pkg,
          apkUrl: url.toString(),
          language: lang,
          version: version,
          libVersion: lib,
          versionCode: parsedCode,
          iconUrl: modern
              ? resources['iconUrl'] as String? ?? ''
              : index.resolve('icon/$pkg.png').toString(),
          nsfw: nsfw));
    }
    return output;
  }

  static String fingerprint(Map data) {
    final value = data['meta']?['signingKeyFingerprint'] ?? data['signingKey'];
    if (value is! String || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value)) {
      throw const FormatException(
          'Repository signing key fingerprint is missing or invalid');
    }
    return value.toLowerCase();
  }

  static Uri? deepLink(Uri uri) {
    if (uri.scheme != 'aniyomi' ||
        !{'add-repo', 'extension-store'}.contains(uri.host)) {
      return null;
    }
    final url = Uri.tryParse(uri.queryParameters['url'] ?? '');
    if (url == null || url.scheme != 'https' || url.host.isEmpty) {
      throw const FormatException('Repository URL must use HTTPS');
    }
    return url;
  }
}
