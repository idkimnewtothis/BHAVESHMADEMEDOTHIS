import 'package:flutter_test/flutter_test.dart';
import 'package:shonenx/features/extensions/providers/extension_service_provider.dart';

void main() {
  test('user Keiyoushi raw URL resolves to actual index', () {
    expect(
      ExtensionAdapter.normalizeRepoUrl(
        'https://github.com/keiyoushi/extensions/raw/repo/index.pb',
        'mihon',
      ),
      'https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.pb',
    );
  });
  test('GitHub refs heads URL and query preserve index format', () {
    expect(
      ExtensionAdapter.normalizeRepoUrl(
        'https://github.com/keiyoushi/extensions/raw/refs/heads/repo/index.pb?raw=1',
        'mihon',
      ),
      'https://raw.githubusercontent.com/keiyoushi/extensions/refs/heads/repo/index.pb?raw=1',
    );
  });
  test('raw anime index stays intact', () {
    const url =
        'https://raw.githubusercontent.com/yuzono/anime-repo/repo/index.min.json';
    expect(ExtensionAdapter.normalizeRepoUrl(url, 'aniyomi'), url);
  });
}
