import importlib.util
from pathlib import Path
import struct
import unittest

spec = importlib.util.spec_from_file_location('verifier', Path(__file__).parents[2] / 'scripts/verify_apk.py')
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)

class ElfAlignmentTest(unittest.TestCase):
    def test_32_and_64_bit_load_segments(self):
        for bits in (32, 64):
            with self.subTest(bits=bits):
                data=bytearray(256)
                data[:6]=b'\x7fELF'+bytes([2 if bits==64 else 1,1])
                if bits==64:
                    struct.pack_into('<Q',data,32,64)
                    struct.pack_into('<HH',data,54,56,1)
                    struct.pack_into('<IIQQQQQQ',data,64,1,5,0,0,0,128,128,16384)
                    align_offset=112
                else:
                    struct.pack_into('<I',data,28,64)
                    struct.pack_into('<HH',data,42,32,1)
                    struct.pack_into('<8I',data,64,1,0,0,0,128,128,5,16384)
                    align_offset=92
                verifier.verify_elf(data,'test.so')
                struct.pack_into('<I',data,align_offset,4096)
                with self.assertRaisesRegex(ValueError,'alignment=4096'):
                    verifier.verify_elf(data,'test.so')

if __name__ == '__main__':
    unittest.main()
