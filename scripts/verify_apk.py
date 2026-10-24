#!/usr/bin/env python3
"""Verify signed app identity, ARM64 native ELF page alignment and APK structure."""
import argparse
import os
import re
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


def verify_extension_provider(manifest, app_id):
    """Validate the merged APK, where duplicate provider classes can disappear."""
    blocks = re.findall(r'E: provider[^\n]*\n((?:[ \t]+A:[^\n]*\n)*)', manifest)
    expected = f'{app_id}.anime-apks'
    matched = []
    for block in blocks:
        attrs = dict(re.findall(r'android:(\w+)(?:\([^)]*\))?="([^"]*)"', block))
        if attrs.get('authorities') == expected:
            matched.append((attrs, block))
    if len(matched) != 1:
        raise ValueError('Extension APK FileProvider authority missing or duplicated in merged manifest')
    attrs, block = matched[0]
    if attrs.get('name') != 'com.ryan.runtimebridge.ExtensionApkProvider':
        raise ValueError('Extension APK provider must have a distinct class to avoid manifest merging')
    if not re.search(r'android:exported[^\n]*\(type 0x12\)0x0(?:\s|$)', block):
        raise ValueError('Extension APK provider must be explicitly non-exported')
    if not re.search(r'android:grantUriPermissions[^\n]*\(type 0x12\)0xffffffff(?:\s|$)', block):
        raise ValueError('Extension APK provider must grant installer URI access')


def verify(path, app_id, version, tools, certificate, version_code=3):
    cert = subprocess.check_output([str(tools / 'apksigner'), 'verify', '--verbose', '--print-certs', str(path)], text=True)
    if 'CN=Android Debug' in cert:
        raise ValueError('Debug signing key is not a release key')
    actual = [line.split(': ', 1)[1].strip().lower() for line in cert.splitlines() if 'certificate SHA-256 digest:' in line]
    if actual != [certificate.lower()]:
        raise ValueError('APK certificate differs from this app release key')
    info = subprocess.check_output([str(tools / 'aapt'), 'dump', 'badging', str(path)], text=True)
    if f"name='{app_id}'" not in info.splitlines()[0] or f"versionName='{version}'" not in info.splitlines()[0]:
        raise ValueError('Unexpected app identity or version')
    if f"versionCode='{version_code}'" not in info.splitlines()[0]:
        raise ValueError('Unexpected version code; update history must advance')
    if 'application-debuggable' in info:
        raise ValueError('Release APK must not be debuggable')
    manifest = subprocess.check_output([str(tools / 'aapt'), 'dump', 'xmltree', str(path), 'AndroidManifest.xml'], text=True)
    verify_extension_provider(manifest, app_id)
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
    p.add_argument('--application-id', default='io.github.idkimnewtothis.shonenxplus')
    p.add_argument('--version', default='2.1.0')
    p.add_argument('--version-code', type=int, default=3)
    p.add_argument('--certificate', default='1e1c683fa4cbee119b96bea3f0a2c7a04a75b38679791cc3cf8a946e6bef5124', help='Expected public signing certificate SHA-256')
    p.add_argument('--build-tools', type=Path, default=Path(os.environ.get('ANDROID_HOME', '')) / 'build-tools/36.0.0')
    a = p.parse_args()
    verify(a.apk, a.application_id, a.version, a.build_tools, a.certificate, a.version_code)
