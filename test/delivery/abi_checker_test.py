import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest

spec = importlib.util.spec_from_file_location('abi', Path(__file__).parents[2] / 'tools/verify-extension-abi.py')
abi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(abi)

class AbiGateTest(unittest.TestCase):
    def test_missing_method_fails_and_inherited_method_resolves(self):
        base = 'Leu/kanade/tachiyomi/animesource/AnimeSource;'
        child = 'Leu/kanade/tachiyomi/animesource/online/AnimeHttpSource;'
        symbol = (child, 'getName', '()Ljava/lang/String;')
        extension = SimpleNamespace(methods=[symbol], fields=[], defined_methods=set(), defined_fields=set(), parents={})
        host = SimpleNamespace(defined_methods={(base, *symbol[1:])}, defined_fields=set(), parents={child:[base],base:[]})
        self.assertEqual(abi.verify([host], [extension])['status'], 'PASS')
        host.defined_methods.clear()
        failed = abi.verify([host], [extension])
        self.assertEqual(failed['status'], 'FAIL')
        self.assertIn('getName', failed['missingMembers'][0])

    def test_wrong_override_descriptor_fails(self):
        base = 'Leu/kanade/tachiyomi/animesource/AnimeSource;'
        child = 'Lexample/Test;'
        host = SimpleNamespace(defined_methods={(base,'getName','()Ljava/lang/String;')},defined_fields=set(),parents={base:[]})
        extension = SimpleNamespace(methods=[],fields=[],defined_methods={(child,'getName','()I')},defined_fields=set(),parents={child:[base]})
        self.assertEqual(abi.verify([host],[extension])['status'], 'FAIL')

    def test_minified_static_helpers_are_not_virtual_overrides(self):
        base = 'Leu/kanade/tachiyomi/animesource/AnimeSource;'
        child = 'Lexample/Test;'
        host = SimpleNamespace(defined_methods={(base,'a','()I')},virtual_methods=set(),defined_fields=set(),parents={base:[]})
        extension = SimpleNamespace(methods=[],fields=[],defined_methods={(child,'a','()Z')},virtual_methods=set(),defined_fields=set(),parents={child:[base]})
        self.assertEqual(abi.verify([host],[extension])['status'], 'PASS')

if __name__ == '__main__':
    unittest.main()
