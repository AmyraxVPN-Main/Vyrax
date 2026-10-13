#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Amyrax
"""Sign leaf code before enclosing frameworks/helpers; leave outer app for last."""
from pathlib import Path
import plistlib
import subprocess
import sys

app, identity = Path(sys.argv[1]), sys.argv[2]
bundles = [p for p in (app / 'Contents/Frameworks').rglob('*')
           if p.is_dir() and not p.is_symlink() and p.suffix in ('.app', '.framework')]
executables = {(app / 'Contents/MacOS/Vyrax').resolve()}
for bundle in bundles:
    metadata = bundle / ('Contents/Info.plist' if bundle.suffix == '.app' else 'Resources/Info.plist')
    with metadata.open('rb') as stream:
        info = plistlib.load(stream)
    name = info.get('CFBundleExecutable', bundle.stem)
    executables.add((bundle / ('Contents/MacOS' if bundle.suffix == '.app' else '') / name).resolve())

def sign(file):
    subprocess.run(['codesign', '--force', '--sign', identity, '--options', 'runtime',
                    '--entitlements', 'macos/entitlements.plist', str(file)], check=True)

magic = {b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf',
         b'\xfe\xed\xfa\xce', b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'}
for file in app.rglob('*'):
    if file.is_symlink() or not file.is_file() or file.resolve() in executables:
        continue
    with file.open('rb') as stream:
        if stream.read(4) in magic:
            sign(file)
for bundle in sorted(bundles, key=lambda p: len(p.parts), reverse=True):
    sign(bundle)
