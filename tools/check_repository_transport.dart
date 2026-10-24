// Explicit live metadata/APK transport check. Never calls a source or a video URL.
import 'dart:io';
import 'dart:convert';
import 'package:anymex_extension_runtime_bridge/Services/Aniyomi/RepositoryClient.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    throw ArgumentError(
      'Usage: dart run tools/check_repository_transport.dart <download-directory>',
    );
  }
  final directory = Directory(args.single);
  await directory.create(recursive: true);
  final client = RepositoryClient();
  final report = <Map<String, Object>>[];
  for (final entry in [
    (
      Uri.parse('https://github.com/keiyoushi/extensions/raw/repo/index.pb'),
      true,
      ['MangaDex', 'MANGA Plus', 'Webtoons.com'],
    ),
    (
      Uri.parse(
        'https://raw.githubusercontent.com/yuzono/anime-repo/repo/index.min.json',
      ),
      false,
      ['AnimeKai', 'AnimePahe', 'KickAssAnime', 'WCOStream'],
    ),
  ]) {
    final extensions = await client.read(entry.$1, manga: entry.$2);
    final fingerprint = await client.fingerprint(entry.$1, manga: entry.$2);
    stdout.writeln(
      '${entry.$2 ? 'Manga' : 'Anime'}: ${extensions.length} entries, fingerprint $fingerprint',
    );
    for (final name in entry.$3) {
      final extension = extensions.firstWhere(
        (e) => e.name == name || e.name.startsWith('$name '),
      );
      final file = File('${directory.path}/${extension.packageName}.apk');
      await client.download(Uri.parse(extension.apkUrl), file);
      report.add({
        'name': extension.name,
        'package': extension.packageName,
        'version': extension.version,
        'lib': extension.libVersion,
        'url': extension.apkUrl,
        'bytes': await file.length(),
        'fingerprint': fingerprint,
      });
      stdout.writeln(
        'Downloaded ${extension.name} ${extension.version}: ${await file.length()} bytes',
      );
    }
  }
  await File(
    '${directory.path}/report.json',
  ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
}
