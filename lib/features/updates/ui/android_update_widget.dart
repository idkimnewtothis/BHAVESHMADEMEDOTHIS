import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:anymex_extension_runtime_bridge/Services/Aniyomi/RepositoryClient.dart';
import 'package:flutter/material.dart';
import 'package:shonenx/features/updates/services/apk_update_download.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shonenx/features/updates/models/github_release.dart';
import 'package:shonenx/shared/widgets/app_bottom_sheet.dart';

class AndroidUpdateWidget extends StatefulWidget {
  final GitHubRelease release;
  final VoidCallback? onDownloadStarted;

  const AndroidUpdateWidget({
    super.key,
    required this.release,
    this.onDownloadStarted,
  });

  static Future<void> show(
    BuildContext context, {
    required GitHubRelease release,
    VoidCallback? onDownloadStarted,
  }) async {
    await AppBottomSheet.show(
      context: context,
      title: 'Android App Installer',
      useRootNavigator: true,
      child: AndroidUpdateWidget(
        release: release,
        onDownloadStarted: onDownloadStarted,
      ),
    );
  }

  @override
  State<AndroidUpdateWidget> createState() => _AndroidUpdateWidgetState();
}

class _AndroidUpdateWidgetState extends State<AndroidUpdateWidget> {
  ReleaseAsset? _bestAsset;
  bool _isLoadingAsset = true;
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = 'Matching device architecture...';
  File? _downloadedFile;
  http.Client? _downloadClient;

  @override
  void dispose() {
    _downloadClient?.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _detectBestAsset();
  }

  Future<void> _detectBestAsset() async {
    final asset = await widget.release.getBestAsset();
    if (mounted) {
      setState(() {
        _bestAsset = asset;
        _isLoadingAsset = false;
        if (asset != null) {
          _statusMessage = 'Ready to download ${asset.name}';
        } else {
          _statusMessage = 'No compatible APK found in this release.';
        }
      });
    }
  }

  Future<void> _startDownloadAndInstall() async {
    if (_bestAsset == null || _isDownloading) return;
    widget.onDownloadStarted?.call();
    if (!mounted) return;

    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _statusMessage = 'Starting download...';
    });

    final client = http.Client();
    _downloadClient = client;
    try {
      final dir = Directory(
        '${(await getTemporaryDirectory()).path}/app-updates',
      );
      if (!mounted) return;
      final watch = Stopwatch()..start();
      var lastUpdate = -100;
      final file = await downloadUpdateApk(
        _bestAsset!,
        dir,
        client: RepositoryClient(createClient: () => client),
        onProgress: (received, total) {
          if (!mounted || watch.elapsedMilliseconds - lastUpdate < 100) return;
          lastUpdate = watch.elapsedMilliseconds;
          setState(() {
            _progress = total != null && total > 0
                ? (received / total).clamp(0, 1)
                : 0;
            _statusMessage =
                'Downloading: ${(received / (1024 * 1024)).toStringAsFixed(1)} MB';
          });
        },
      );
      if (!mounted) return;

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _progress = 1.0;
          _statusMessage = 'Download complete! Launching installer...';
          _downloadedFile = file;
        });
      }

      await _triggerInstall(file);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'Download failed: $e';
        });
      }
    } finally {
      client.close();
      if (identical(_downloadClient, client)) _downloadClient = null;
    }
  }

  Future<void> _triggerInstall(File file) async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.status;
        if (!status.isGranted) {
          final res = await Permission.requestInstallPackages.request();
          if (!res.isGranted) {
            if (mounted) {
              setState(() {
                _statusMessage =
                    'Permission to install unknown apps is required to install updates.';
              });
            }
            return;
          }
        }
      }
      if (!mounted) return;
      final result = await OpenFile.open(file.path);
      if (mounted && result.type != ResultType.done) {
        setState(() {
          _statusMessage = 'Please open file directly: ${result.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Installer error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_isLoadingAsset) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.android_rounded, size: 32, color: cs.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _bestAsset?.name ?? 'Unknown APK',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _bestAsset != null
                          ? '${(_bestAsset!.size / (1024 * 1024)).toStringAsFixed(1)} MB • Detected Variant'
                          : 'No compatible APK found',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_isDownloading) ...[
          LinearProgressIndicator(
            value: _progress,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          _statusMessage,
          style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_downloadedFile != null) ...[
          FilledButton.icon(
            onPressed: () => _triggerInstall(_downloadedFile!),
            icon: const Icon(Icons.install_mobile_rounded),
            label: const Text('Install APK Now'),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: _bestAsset == null || _isDownloading
                ? null
                : _startDownloadAndInstall,
            icon: _isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(
              _isDownloading ? 'Downloading...' : 'In-App Download & Install',
            ),
          ),
        ],
      ],
    );
  }
}
