import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shonenx/source_engine/source_registry.dart';
import 'package:shonenx/features/extensions/providers/extension_service_provider.dart';
import 'package:anymex_extension_runtime_bridge/anymex_extension_runtime_bridge.dart'
    as bridge;

void main() {
  test(
    'manga sources are empty without starting an extension runtime',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        await container.read(availableMangaSourcesProvider.future),
        isEmpty,
      );
    },
  );
  test(
    'manga repository is rejected before accessing runtime or network',
    () async {
      await expectLater(
        ExtensionAdapter().addRepo(
          'https://example.test/index.min.json',
          'aniyomi',
          bridge.ItemType.manga,
        ),
        throwsUnsupportedError,
      );
    },
  );
  test(
    'non-APK engine is rejected before accessing runtime or network',
    () async {
      await expectLater(
        ExtensionAdapter().addRepo(
          'https://example.test/index.json',
          'mangayomi',
          bridge.ItemType.anime,
        ),
        throwsUnsupportedError,
      );
    },
  );
}
