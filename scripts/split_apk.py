#!/usr/bin/env python3
"""Split a signed release APK, or verify/reassemble its manifest and parts."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify(manifest, original=None, output=None):
    manifest = Path(manifest)
    data = json.loads(manifest.read_text())
    if not data['parts'] or data['size'] <= 0:
        raise ValueError('Empty APK manifest')
    total = hashlib.sha256()
    count = 0
    names = set()
    with tempfile.TemporaryFile() as joined:
        for index, part in enumerate(data['parts'], 1):
            name = part['name']
            if part['index'] != index or Path(name).name != name or name in names:
                raise ValueError(f'Invalid or duplicate part: {name}')
            names.add(name)
            path = manifest.parent / name
            if not path.is_file():
                raise ValueError(f'Missing part: {name}')
            if path.stat().st_size != part['size']:
                raise ValueError(f'Wrong size: {name}')
            if digest(path) != part['sha256']:
                raise ValueError(f'Wrong SHA-256: {name}')
            with path.open('rb') as stream:
                while block := stream.read(1024 * 1024):
                    total.update(block)
                    count += len(block)
                    joined.write(block)
        if count != data['size'] or total.hexdigest() != data['sha256']:
            raise ValueError('Whole APK size or SHA-256 mismatch')
        if original and (digest(original) != total.hexdigest() or Path(original).stat().st_size != count):
            raise ValueError('Parts differ from original APK')
        if output:
            joined.seek(0)
            with Path(output).open('wb') as destination:
                shutil.copyfileobj(joined, destination)
    return total.hexdigest()


def split(apk, destination, app, slug, version, part_size, apksigner):
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]*', slug) or not re.fullmatch(r'[A-Za-z0-9.+_-]+', version):
        raise ValueError('Invalid app slug or version')
    if part_size <= 0:
        raise ValueError('Part size must be positive')
    cert = subprocess.run([apksigner, 'verify', '--verbose', '--print-certs', str(apk)], check=True, text=True, capture_output=True)
    if 'CN=Android Debug' in cert.stdout:
        raise ValueError('Refusing to split a debug-signed APK')
    destination.mkdir(parents=True, exist_ok=True)
    data = {'app': app, 'version': version, 'file': f'{slug}-{version}.apk',
            'size': apk.stat().st_size, 'sha256': digest(apk), 'part_size': part_size, 'parts': []}
    if not data['size']:
        raise ValueError('Empty APK')
    with apk.open('rb') as stream:
        index = 1
        while block := stream.read(part_size):
            name = f'{slug}-{version}.part-{index:03d}.bin'
            (destination / name).write_bytes(block)
            data['parts'].append({'index': index, 'name': name, 'size': len(block), 'sha256': hashlib.sha256(block).hexdigest()})
            index += 1
    manifest = destination / f'{slug}-{version}.manifest.json'
    manifest.write_text(json.dumps(data, indent=2) + '\n')
    verify(manifest, apk)
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, help='APK to split, or manifest with --verify')
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--original', type=Path)
    parser.add_argument('--output', type=Path, help='Parts directory, or reassembled APK in verify mode')
    parser.add_argument('--app', default='ShonenX+')
    parser.add_argument('--slug', default='shonenxplus')
    parser.add_argument('--version', default='2.1.0')
    parser.add_argument('--part-size', type=int, default=20_000_000)
    parser.add_argument('--apksigner', default=os.environ.get('APKSIGNER', 'apksigner'))
    args = parser.parse_args()
    if args.verify:
        print(verify(args.input, args.original, args.output))
    else:
        if not args.output:
            parser.error('--output directory is required')
        print(split(args.input, args.output, args.app, args.slug, args.version, args.part_size, args.apksigner))

if __name__ == '__main__':
    main()
