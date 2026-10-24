import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'ExtensionMetadata.dart';
import 'PbDecoder.dart';
import 'RepositoryUrl.dart';

/// HTTP transport shared by both APK families. No source website behavior here.
class RepositoryClient {
  final http.Client Function() createClient;
  RepositoryClient({http.Client Function()? createClient})
      : createClient = createClient ?? http.Client.new;

  Future<http.StreamedResponse> _send(http.Client client, Uri uri) async {
    for (var hop = 0; hop <= 5; hop++) {
      if (uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('Repository and APK URLs must use HTTPS');
      }
      final request = http.Request('GET', uri)..followRedirects = false;
      request.headers['User-Agent'] = 'ShonenXPlus/2.1.0';
      final response =
          await client.send(request).timeout(const Duration(seconds: 30));
      if ({301, 302, 303, 307, 308}.contains(response.statusCode)) {
        final location = response.headers['location'];
        await response.stream.drain<void>();
        if (location == null) {
          throw HttpException('Redirect has no location', uri: uri);
        }
        uri = uri.resolve(location);
        continue;
      }
      if (response.statusCode != 200) {
        await response.stream.drain<void>();
        throw HttpException('${uri.host}: HTTP ${response.statusCode}',
            uri: uri);
      }
      return response;
    }
    throw const FormatException('Repository redirect limit exceeded');
  }

  Future<List<int>> bytes(Uri uri) async {
    final client = createClient();
    try {
      return await (() async {
        final response = await _send(client, uri);
        final output = <int>[];
        await for (final chunk in response.stream) {
          output.addAll(chunk);
          if (output.length > 32 * 1024 * 1024) {
            throw const FormatException('Repository index exceeds 32 MB');
          }
        }
        return output;
      })()
          .timeout(const Duration(seconds: 60));
    } finally {
      client.close();
    }
  }

  List<int> _decode(List<int> bytes) =>
      bytes.length > 1 && bytes[0] == 31 && bytes[1] == 139
          ? gzip.decode(bytes)
          : bytes;
  dynamic _document(List<int> input, bool manga) {
    final bytes = _decode(input);
    final first =
        bytes.firstWhere((b) => ![9, 10, 13, 32].contains(b), orElse: () => 0);
    if (first == 60) {
      throw const FormatException(
          'Repository returned a webpage instead of an index');
    }
    if (first == 91 || first == 123) return jsonDecode(utf8.decode(bytes));
    return PbDecoder.decodeStore(bytes, manga: manga);
  }

  Future<List<ExtensionMetadata>> read(Uri uri,
      {required bool manga, Set<String>? visited}) async {
    uri = RepositoryUrl.normalize(uri.toString());
    visited ??= <String>{};
    if (visited.length >= 5 || !visited.add(uri.toString())) {
      throw const FormatException('Repository index redirect loop');
    }
    final input = await bytes(uri);
    final data = _document(input, manga);
    if (data is Map) {
      final next = data['index_v2'] ??
          data['extensionListUrl'] ??
          (data['meta'] != null ? 'index.min.json' : null);
      if (next is String) {
        return read(uri.resolve(next), manga: manga, visited: visited);
      }
    }
    return ExtensionMetadata.parse(input, uri, manga: manga);
  }

  Future<String> fingerprint(Uri uri, {required bool manga}) async {
    uri = RepositoryUrl.normalize(uri.toString());
    final data = _document(await bytes(uri), manga);
    if (data is Map && (data['meta'] != null || data['signingKey'] != null)) {
      return ExtensionMetadata.fingerprint(data);
    }
    final metadata = _document(await bytes(uri.resolve('repo.json')), manga);
    if (metadata is! Map) {
      throw const FormatException('Repository metadata must be an object');
    }
    return ExtensionMetadata.fingerprint(metadata);
  }

  Future<void> download(Uri uri, File file,
      {void Function(int, int?)? onProgress}) async {
    final client = createClient();
    final partial = File('${file.path}.part');
    IOSink? sink;
    try {
      await (() async {
        final response = await _send(client, uri);
        sink = partial.openWrite();
        var received = 0;
        final magic = <int>[];
        await for (final chunk
            in response.stream.timeout(const Duration(seconds: 30))) {
          if (magic.length < 4) magic.addAll(chunk.take(4 - magic.length));
          received += chunk.length;
          sink!.add(chunk);
          onProgress?.call(received, response.contentLength);
        }
        await sink!.flush();
        await sink!.close();
        sink = null;
        if (magic.length < 4 ||
            magic[0] != 80 ||
            magic[1] != 75 ||
            magic[2] != 3 ||
            magic[3] != 4) {
          throw const FormatException(
              'Download is not an APK; the server returned an error page');
        }
        if (response.contentLength != null &&
            response.contentLength != received) {
          throw const FormatException(
              'APK download was interrupted. Retry installation.');
        }
        await partial.rename(file.path);
      })()
          .timeout(const Duration(minutes: 3));
    } finally {
      client.close();
      await sink?.close();
      if (await partial.exists()) await partial.delete();
    }
  }
}
