#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Amyrax
import hashlib
import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys

app, arch = Path(sys.argv[1]), sys.argv[2]
machine = {'arm64':'arm64', 'x64':'x86_64'}[arch]
res = app / 'Contents/Resources'
metadata = json.loads((res / 'app/package.json').read_text())
with (app / 'Contents/Info.plist').open('rb') as stream:
    info = plistlib.load(stream)
assert info['CFBundleIdentifier'] == 'com.amyrax.vyrax'
assert info['CFBundleShortVersionString'] == metadata['version']
assert info['CFBundleExecutable'] == 'Vyrax'
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
mach_o_files = 0
magic = {b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf',
         b'\xfe\xed\xfa\xce', b'\xca\xfe\xba\xbe', b'\xca\xfe\xba\xbf'}
for file in app.rglob('*'):
    if file.is_symlink() or not file.is_file():
        continue
    with file.open('rb') as stream:
        header = stream.read(4)
    if header in magic:
        assert subprocess.check_output(['lipo', '-archs', str(file)], text=True).strip() == machine, str(file)
        mach_o_files += 1
required = ['app/ui/index.html', 'app/ui/trayTemplate.png', 'app/ui/trayTemplate@2x.png',
            'app/linux/main.cjs', 'app/linux/preload.cjs', 'app/macos/backend.mjs',
            'native/geo.bin', 'Vyrax.icns', 'licenses/GPL-3.0.txt', 'licenses/LICENSES.chromium.html']
for relative in required:
    assert (res / relative).is_file(), relative
for relative in ['cores/xray', 'cores/sing-box', 'vyrax-authorize', 'vyrax-core-lease', 'vyrax-network']:
    file = res / 'native' / relative
    output = subprocess.check_output(['lipo', '-archs', str(file)], text=True).strip()
    assert output == machine, (relative, output, machine)
    subprocess.run(['codesign', '--verify', '--strict', str(file)], check=True)
    assert file.stat().st_mode & 0o111
subprocess.run([str(res / 'native/cores/xray'), 'version'], check=True)
subprocess.run([str(res / 'native/cores/sing-box'), 'version'], check=True)
original = os.environ.get('VYRAX_APP_OVERLAY')
preserved = []
if original:
    original = Path(original)
    allowed = {'linux/config.mjs', 'linux/firefox-tls.mjs', 'linux/firefox-roots.pem'}
    for file in (original / 'app').rglob('*'):
        if not file.is_file():
            continue
        relative = file.relative_to(original / 'app').as_posix()
        if relative not in allowed:
            assert file.read_bytes() == (res / 'app' / relative).read_bytes(), relative
            preserved.append(relative)
result = {'version':metadata['version'], 'architecture':arch, 'bundleId':info['CFBundleIdentifier'],
          'minimumMacOS':info['LSMinimumSystemVersion'], 'bundleSignatureVerified':True,
          'notarized':False, 'singBoxSignedSHA256':hashlib.sha256((res / 'native/cores/sing-box').read_bytes()).hexdigest(),
          'preservedAppFiles':len(preserved), 'suppliedUIAndAccountModulesPreserved':bool(original),
          'nativeMachOFilesVerified':mach_o_files}
out = Path('release') / ('macos-' + metadata['version'])
out.mkdir(parents=True, exist_ok=True)
(out / ('bundle-verification-' + arch + '.json')).write_text(json.dumps(result, indent=2))
print('macOS bundle, cores, architecture, signatures and version verified')
