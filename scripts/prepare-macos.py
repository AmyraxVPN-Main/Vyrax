#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Amyrax
"""Verify pinned macOS archives before extraction; retain Mach-O symlinks/modes."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import zipfile

root = Path(__file__).resolve().parent.parent
pins = json.loads((root / 'vendor/macos-versions.json').read_text(encoding='utf-8-sig'))
target = root / 'vendor/macos'
target.mkdir(parents=True, exist_ok=True)
arches = sys.argv[1:] or ['arm64', 'x64']
for arch in arches:
    if arch not in ('x64', 'arm64'):
        raise ValueError('Supported macOS architectures: arm64, x64')
    for pin in [p for p in pins if p['arch'] == arch]:
        archive = target / pin['url'].rsplit('/', 1)[1]
        if not archive.exists():
            subprocess.run(['curl', '--fail', '--location', '--connect-timeout', '20', '--max-time', '600', '--retry', '3', '--output', str(archive), pin['url']], check=True)
        with archive.open('rb') as stream:
            if hashlib.file_digest(stream, 'sha256').hexdigest() != pin['sha256']:
                raise ValueError(f"SHA256 mismatch: {pin['name']} {arch}")
        component = target / arch / pin['name']
        if component.exists():
            continue
        component.mkdir(parents=True)
        if archive.suffix == '.zip':
            with zipfile.ZipFile(archive) as source:
                for item in source.infolist():
                    if not (component / item.filename).resolve().is_relative_to(component.resolve()):
                        raise ValueError('Archive path escapes extraction folder')
            # ditto preserves the Electron framework symlinks and executable bits.
            subprocess.run(['/usr/bin/ditto', '-x', '-k', str(archive), str(component)], check=True)
        else:
            with tarfile.open(archive) as source:
                source.extractall(component, filter='data')
        print(f"Verified {pin['name']} {pin['version']} {arch}")
sources = target / 'sources'
sources.mkdir(exist_ok=True)
for pin in [p for p in pins if p['arch'] == 'source']:
    file = sources / pin['file']
    if not file.exists():
        subprocess.run(['curl', '--fail', '--location', '--retry', '3', '--max-time', '600', '--output', str(file), pin['url']], check=True)
    with file.open('rb') as stream:
        if hashlib.file_digest(stream, 'sha256').hexdigest() != pin['sha256']:
            raise ValueError(f"Source SHA256 mismatch: {pin['name']}")
print('macOS runtimes and exact core sources prepared')
