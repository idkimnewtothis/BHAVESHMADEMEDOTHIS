// Android-only diagnostic entry point. Never calls getVideoList or starts playback.
// flutter build apk --debug --target-platform android-x64 -t tools/device_metadata_smoke.dart
// Stage signed fixtures in cache/anime-apks/smoke/ using adb run-as; inspect and
// confirm Android installer prompts. This harness is not the release entry point.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

const _channel = MethodChannel('aniyomiExtensionBridge');
final _messages = ValueNotifier<List<String>>([]);
void report(String text) {
  debugPrint('SX21_SMOKE $text');
  _messages.value = [..._messages.value, text];
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        appBar: AppBar(title: const Text('Metadata diagnostics')),
        body: ValueListenableBuilder<List<String>>(
          valueListenable: _messages,
          builder: (_, values, _) => ListView(
            children: values
                .map(
                  (s) =>
                      Padding(padding: const EdgeInsets.all(8), child: Text(s)),
                )
                .toList(),
          ),
        ),
      ),
    ),
  );
  final dir = Directory(
    '${(await getTemporaryDirectory()).path}/anime-apks/smoke',
  );
  final results = <Map<String, dynamic>>[];
  try {
    report(
      'Runtime ${await const MethodChannel('anymeXBridge').invokeMethod('runtimeInfo')}',
    );
    final files = await dir
        .list()
        .where((f) => f.path.endsWith('.apk'))
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      try {
        final info = Map<String, dynamic>.from(
          await _channel.invokeMethod('inspectApk', {'path': file.path}) as Map,
        );
        final pkg = info['package'] as String;
        final fingerprint = pkg.contains('.animeextension.')
            ? 'cbec121aa82ebb02aaa73806992e0368a97d47b5451ed6524816d03084c45905'
            : '9add655a78e96c4ec7a53ef89dccb557cb5d767489fac5e785d671a5a75d4da2';
        if (info['fingerprint'] != fingerprint) {
          throw StateError('Fixture signer mismatch: $pkg');
        }
        report('INSTALL $pkg lib=${info['lib']}');
        final installed = await _channel.invokeMethod('installVerifiedApk', {
          'path': file.path,
          'package': pkg,
          'fingerprint': fingerprint,
        });
        results.add({
          'operation': 'install',
          'package': pkg,
          'result': installed,
        });
        report('INSTALLED $pkg $installed');
      } catch (e) {
        results.add({
          'operation': 'install',
          'file': file.path.split('/').last,
          'error': '$e',
        });
        report('INSTALL ERROR $e');
      }
    }
    for (final anime in [false, true]) {
      final loaded =
          await _channel.invokeListMethod<dynamic>(
            anime
                ? 'getInstalledAnimeExtensions'
                : 'getInstalledMangaExtensions',
          ) ??
          [];
      report('LOADED ${anime ? 'anime' : 'manga'} ${loaded.length}');
      results.add({
        'operation': 'load',
        'anime': anime,
        'sources': loaded,
        'failures': await _channel.invokeMethod('getLoadFailures'),
      });
      final seen = <String>{};
      for (final item in loaded) {
        final s = Map<String, dynamic>.from(item as Map);
        if (s['lang'] != 'en' || !seen.add(s['pkgName'] as String)) continue;
        final args = {'sourceId': s['id'], 'isAnime': anime};
        try {
          final prefs = await _channel.invokeMethod('getPreference', args);
          results.add({
            'operation': 'preferences',
            'source': s['name'],
            'count': (prefs as List).length,
          });
          report('PREFERENCES ${s['name']} ${prefs.length}');
        } catch (e) {
          results.add({
            'operation': 'preferences',
            'source': s['name'],
            'error': '$e',
          });
          report('PREFERENCE ERROR ${s['name']} $e');
        }
        for (final query
            in anime
                ? ['One Piece', 'Attack on Titan', 'Attack on Titan Final Season Part 2']
                : ['One Piece', 'Tower of God', 'Solo Leveling']) {
          final row = <String, dynamic>{
            'source': s['name'],
            'package': s['pkgName'],
            'query': query,
            'anime': anime,
          };
          try {
            final search = Map<String, dynamic>.from(
              await _channel.invokeMethod('search', {
                    ...args,
                    'page': 1,
                    'query': query,
                  })
                  as Map,
            );
            final titles = search['list'] as List;
            row['searchCount'] = titles.length;
            row['hasNextPage'] = search['hasNextPage'];
            if (titles.isEmpty) {
              row['status'] = 'EMPTY';
            } else {
              final selected = titles.first as Map;
              final detail = Map<String, dynamic>.from(
                await _channel.invokeMethod('getDetail', {
                      ...args,
                      'media': selected,
                    })
                    as Map,
              );
              final episodes = detail['episodes'] as List? ?? [];
              row.addAll({
                'title': detail['title'],
                'url': detail['url'],
                'cover': detail['thumbnail_url'] != null,
                'description': detail['description'] != null,
                'genres': detail['genre'],
                'statusText': detail['status'],
                'episodeCount': episodes.length,
                'numbered': episodes
                    .where((e) => (e['episodeNumber'] as num? ?? -1) >= 0)
                    .length,
                'dated': episodes
                    .where((e) => (e['dateUpload'] as num? ?? 0) > 0)
                    .length,
                'thumbnails': episodes
                    .where((e) => e['thumbnail'] != null)
                    .length,
                'sample': episodes.take(3).toList(),
                'status': episodes.isEmpty ? 'EMPTY' : 'PASS',
              });
            }
          } catch (e) {
            row['status'] = 'FAIL';
            row['error'] = '$e';
          }
          results.add(row);
          report(jsonEncode(row));
        }
      }
    }
  } catch (e) {
    report('HARNESS ERROR $e');
    results.add({'operation': 'harness', 'error': '$e'});
  }
  final out = File(
    '${(await getApplicationDocumentsDirectory()).path}/sx21-device-results.json',
  );
  await out.writeAsString(const JsonEncoder.withIndent('  ').convert(results));
  report('DONE ${out.path}');
}
