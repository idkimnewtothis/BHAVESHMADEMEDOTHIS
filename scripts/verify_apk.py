#!/usr/bin/env python3
"""Verify signed app identity, ARM64 native ELF page alignment and APK structure."""
import argparse
import os
from pathlib import Path
import struct
import subprocess
import zipfile


def verify_elf(data, name):
    if data[:4] != b'\x7fELF' or data[5] != 1 or data[4] not in (1, 2):
        raise ValueError(f'{name}: expected little-endian ELF32 or ELF64')
    is64 = data[4] == 2
    phoff = struct.unpack_from('<Q' if is64 else '<I', data, 32 if is64 else 28)[0]
    entsize, count = struct.unpack_from('<HH', data, 54 if is64 else 42)
    loads = 0
    for index in range(count):
        offset = phoff + index * entsize
        if is64:
            kind, _, file_offset, address, _, _, _, alignment = struct.unpack_from('<IIQQQQQQ', data, offset)
        else:
            kind, file_offset, address, _, _, _, _, alignment = struct.unpack_from('<8I', data, offset)
        if kind == 1:
            loads += 1
            if alignment < 16384 or (address - file_offset) % 16384:
                raise ValueError(f'{name}: PT_LOAD is not 16 KB page aligned (alignment={alignment})')
    if not loads:
        raise ValueError(f'{name}: no loadable ELF segments')


def verify(path, app_id, version, tools, certificate):
    cert = subprocess.check_output([str(tools / 'apksigner'), 'verify', '--verbose', '--print-certs', str(path)], text=True)
    if 'CN=Android Debug' in cert:
        raise ValueError('Debug signing key is not a release key')
    actual = [line.split(': ', 1)[1].strip().lower() for line in cert.splitlines() if 'certificate SHA-256 digest:' in line]
    if actual != [certificate.lower()]:
        raise ValueError('APK certificate differs from this app release key')
    info = subprocess.check_output([str(tools / 'aapt'), 'dump', 'badging', str(path)], text=True)
    if f"name='{app_id}'" not in info.splitlines()[0] or f"versionName='{version}'" not in info.splitlines()[0]:
        raise ValueError('Unexpected app identity or version')
    if 'application-debuggable' in info:
        raise ValueError('Release APK must not be debuggable')
    checked = []
    with zipfile.ZipFile(path) as apk:
        if apk.testzip():
            raise ValueError('Corrupt APK zip entry')
        names = apk.namelist()
        native = [n for n in names if n.startswith('lib/') and n.endswith('.so')]
        if not any(n.startswith('lib/arm64-v8a/') for n in native):
            raise ValueError('ARM64 native libraries missing')
        for name in native:
            data = apk.read(name)
            verify_elf(data, name)
            entry = apk.getinfo(name)
            if entry.compress_type == zipfile.ZIP_STORED:
                with path.open('rb') as stream:
                    stream.seek(entry.header_offset)
                    header = stream.read(30)
                name_len, extra_len = struct.unpack_from('<HH', header, 26)
                if (entry.header_offset + 30 + name_len + extra_len) % 16384:
                    raise ValueError(f'{name}: uncompressed ZIP data is not 16 KB aligned')
            checked.append(name)
    print(f'PASS: {app_id} {version}; release signature; {len(checked)} native libraries aligned to 16 KB')
    for name in checked:
        print(name)

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('apk', type=Path)
    p.add_argument('--application-id', default='io.github.idkimnewtothis.bhavesh')
    p.add_argument('--version', default='1.0.0')
    p.add_argument('--certificate', default='9810883286bbefb30a6899b2c24da116273b383ee4a22db613303647a8929b0c', help='Expected public signing certificate SHA-256')
    p.add_argument('--build-tools', type=Path, default=Path(os.environ.get('ANDROID_HOME', '')) / 'build-tools/36.0.0')
    a = p.parse_args()
    verify(a.apk, a.application_id, a.version, a.build_tools, a.certificate)
