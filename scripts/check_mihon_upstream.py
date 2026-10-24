#!/usr/bin/env python3
"""Audit the vendored manga API and alert CI when Mihon's stable release changes.

Never imports unaudited code into the runtime. Updating the pin requires a new
ABI check, fixture tests, signed build and device compatibility report.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]

def check(local_only=False):
    pin = json.loads((ROOT / 'docs/mihon-api-pin.json').read_text())
    for name, digest in pin['hostFiles'].items():
        path = ROOT / name
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError(f'Vendored API changed without updating the audit: {name}')
    if not local_only:
        headers = {'User-Agent': 'ShonenXPlus-upstream-audit'}
        if token := os.environ.get('GH_TOKEN'):
            headers['Authorization'] = f'Bearer {token}'
        request = urllib.request.Request('https://api.github.com/repos/mihonapp/mihon/releases/latest', headers=headers)
        with urllib.request.urlopen(request, timeout=30) as response:
            latest = json.load(response)
        if latest['tag_name'] != pin['tag']:
            raise ValueError(f"Upstream changed to {latest['tag_name']}; host pin is {pin['tag']}. Follow docs/upstream-maintenance.md.")
    print(f"PASS: Mihon {pin['tag']}, {len(pin['hostFiles'])} audited API files")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--local-only', action='store_true')
    args = parser.parse_args()
    check(args.local_only)
