import 'package:anymex_extension_runtime_bridge/anymex_extension_runtime_bridge.dart'
    as bridge;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get/get.dart';
import 'package:shonenx/shared/widgets/app_bottom_sheet.dart';
import 'package:shonenx/source_engine/utils/source_invalidation.dart';
import 'package:url_launcher/url_launcher.dart';

class BundledRuntimeSetupSheet extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  const BundledRuntimeSetupSheet({super.key, this.onComplete});
  @override
  ConsumerState<BundledRuntimeSetupSheet> createState() =>
      _BundledRuntimeSetupSheetState();
}

class _BundledRuntimeSetupSheetState
    extends ConsumerState<BundledRuntimeSetupSheet> {
  bool _busy = false;
  String? _error;
  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await bridge.AnymeXRuntimeBridge.checkAndInitialize();
      if (!bridge.AnymeXRuntimeBridge.controller.isReady.value) {
        throw StateError(
          'The bundled runtime could not start. Restart ShonenX+ or reinstall the signed update.',
        );
      }
      await Get.find<bridge.ExtensionManager>().refreshExtensions(
        refreshAvailableSource: true,
      );
      if (!mounted) return;
      ref.invalidateAllSources();
      widget.onComplete?.call();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppBottomSheet(
    title: 'Mihon & Aniyomi support',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ListTile(
          leading: Icon(Icons.extension),
          title: Text('Included in ShonenX+'),
          subtitle: Text(
            'Mihon v0.21.2 · manga libraries 1.4 / 1.6\nAniyomi · anime libraries 14 / 16 / 17',
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Add a repository to download extensions. Runtime compatibility updates arrive through signed ShonenX+ app updates. No separate AnymeX APK is required.',
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton.icon(
          onPressed: _busy ? null : _refresh,
          icon: const Icon(Icons.refresh),
          label: Text(_busy ? 'Refreshing…' : 'Refresh installed extensions'),
        ),
        TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(
              'https://github.com/idkimnewtothis/BHAVESHMADEMEDOTHIS/releases',
            ),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.system_update),
          label: const Text('Get runtime and app updates'),
        ),
      ],
    ),
  );
}
