#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Amyrax
"""Prepare checksummed upstream Linux runtimes without executing downloaded code."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import zipfile

root = Path(__file__).resolve().parent.parent
pins = json.loads((root / 'vendor/linux-versions.json').read_text(encoding='utf-8-sig'))
target = root / 'vendor/linux'
target.mkdir(parents=True, exist_ok=True)
arches = sys.argv[1:] or ['x64', 'arm64']
for arch in arches:
    if arch not in ('x64', 'arm64'):
        raise ValueError('Supported Linux architectures: x64, arm64')
    folder = target / arch
    folder.mkdir(exist_ok=True)
    for pin in [p for p in pins if p['arch'] == arch]:
        archive = target / pin['url'].rsplit('/', 1)[1]
        if not archive.exists():
            subprocess.run(['curl', '--fail', '--location', '--connect-timeout', '20', '--max-time', '600', '--retry', '3', '--output', str(archive), pin['url']], check=True)
        if hashlib.file_digest(archive.open('rb'), 'sha256').hexdigest() != pin['sha256']:
            raise ValueError(f"SHA256 mismatch: {pin['name']} {arch}")
        component = folder / pin['name']
        if component.exists():
            continue
        component.mkdir()
        if archive.suffix == '.zip':
            with zipfile.ZipFile(archive) as source:
                source.extractall(component)
                for entry in source.infolist():
                    mode = entry.external_attr >> 16
                    if mode:
                        (component / entry.filename).chmod(mode & 0o777)
        else:
            with tarfile.open(archive) as source:
                source.extractall(component, filter='data')
        print(f"Verified {pin['name']} {pin['version']} {arch}")

# Exact upstream source for the separately executed GPL/MPL cores accompanies
# the binary artifacts. Never substitute the application's MIT license for it.
sources = target / 'sources'
sources.mkdir(exist_ok=True)
for pin in [p for p in pins if p['arch'] == 'source']:
    file = sources / pin['file']
    if not file.exists():
        subprocess.run(['curl', '--fail', '--location', '--connect-timeout', '20', '--max-time', '600', '--retry', '3', '--output', str(file), pin['url']], check=True)
    if hashlib.file_digest(file.open('rb'), 'sha256').hexdigest() != pin['sha256']:
        raise ValueError(f"Source SHA256 mismatch: {pin['name']}")
print('Linux runtimes and core sources prepared')
