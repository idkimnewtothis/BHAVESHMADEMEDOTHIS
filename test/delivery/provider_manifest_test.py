"""Regression for the real 2.0 provider-authority merge collision."""
import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('verify_apk', Path(__file__).resolve().parents[2] / 'scripts/verify_apk.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class ProviderManifestTest(unittest.TestCase):
    def manifest(self, name='com.ryan.runtimebridge.ExtensionApkProvider', authority='app.test.anime-apks', exported='0x0'):
        return f'''    E: provider (line=1)
      A: android:name(0x01010003)="{name}" (Raw: "{name}")
      A: android:authorities(0x01010018)="{authority}" (Raw: "{authority}")
      A: android:exported(0x01010010)=(type 0x12){exported}
      A: android:grantUriPermissions(0x0101001b)=(type 0x12)0xffffffff
      E: meta-data (line=2)
'''
    def test_distinct_provider_passes(self):
        module.verify_extension_provider(self.manifest(), 'app.test')
    def test_actual_previous_merge_pattern_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'authority missing'):
            module.verify_extension_provider(self.manifest('androidx.core.content.FileProvider','app.test.fileProvider'), 'app.test')
    def test_duplicate_or_exported_provider_is_rejected(self):
        with self.assertRaises(ValueError):
            module.verify_extension_provider(self.manifest()*2, 'app.test')
        with self.assertRaises(ValueError):
            module.verify_extension_provider(self.manifest(exported='0xffffffff'), 'app.test')

if __name__ == '__main__': unittest.main()
