import 'dart:io';
import 'package:anymex_extension_runtime_bridge/Services/Aniyomi/RepositoryClient.dart';
import 'package:shonenx/features/updates/models/github_release.dart';

/// Download only complete APK assets; Android verifies the app's update signer.
Future<File> downloadUpdateApk(
  ReleaseAsset asset,
  Directory directory, {
  RepositoryClient? client,
  void Function(int received, int? total)? onProgress,
}) async {
  if (!RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._+ -]*\.apk$',
    caseSensitive: false,
  ).hasMatch(asset.name)) {
    throw const FormatException(
      'This release does not contain a valid APK filename.',
    );
  }
  await directory.create(recursive: true);
  final attempt = await directory.createTemp('release-');
  final file = File('${attempt.path}/${asset.name}');
  try {
    await (client ?? RepositoryClient()).download(
      Uri.parse(asset.downloadUrl),
      file,
      totalTimeout: const Duration(minutes: 20),
      onProgress: onProgress,
    );
    if (asset.size > 0 && await file.length() != asset.size) {
      throw const FormatException(
        'App update size does not match the release. Retry the download.',
      );
    }
    return file;
  } catch (_) {
    if (await attempt.exists()) await attempt.delete(recursive: true);
    rethrow;
  }
}
