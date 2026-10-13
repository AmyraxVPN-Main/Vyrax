#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Amyrax
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tarfile
import tempfile
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
version = json.loads((root / 'package.json').read_text())['version']
out = root / 'release' / f'linux-{version}'
manifest = {'version': version, 'packages': [], 'licenses': True}
for arch, machine, debarch in [('x64', 62, 'amd64'), ('arm64', 183, 'arm64')]:
    stage = root / 'linux/build' / arch
    app = stage / 'opt/Vyrax'
    deb = out / f'Vyrax-{version}-linux-{arch}.deb'
    archive = out / f'Vyrax-{version}-linux-{arch}.tar.gz'
    assert subprocess.check_output(['dpkg-deb', '-f', str(deb), 'Architecture'], text=True).strip() == debarch
    assert subprocess.check_output(['dpkg-deb', '-f', str(deb), 'Version'], text=True).strip() == version
    for file in [app / 'vyrax-bin', app / 'chrome-sandbox', *list((app / 'resources/native/cores').iterdir())]:
        with file.open('rb') as stream:
            header = stream.read(20)
        assert header[:4] == b'\x7fELF' and struct.unpack('<H', header[18:20])[0] == machine, file
        assert file.stat().st_mode & 0o111, file
    for file in ['LICENSE', 'Electron-LICENSE.txt', 'LICENSES.chromium.html', 'sing-box-LICENSE.txt', 'Xray-LICENSE.txt', 'GPL-3.0.txt', 'linux-versions.json', 'npm/dependencies.json']:
        assert (app / 'licenses' / file).stat().st_size > 0, file
    package = json.loads((app / 'resources/app/package.json').read_text())
    assert package['version'] == version and package['main'] == 'linux/main.cjs'
    policy = ET.parse(stage / 'usr/share/polkit-1/actions/com.amyrax.vyrax.tun.policy')
    assert policy.find('.//allow_active').text == 'auth_admin'
    assert policy.find('.//annotate').text == '/opt/Vyrax/resources/native/vyrax-tun'
    assert (app / 'resources/native/vyrax-tun').stat().st_mode & 0o111
    with tarfile.open(archive) as files:
        names = files.getnames()
        assert not any('/node_modules/' in name or 'store.enc' in name or name.endswith('.log') or '/tests/' in name for name in names)
        for name in names:
            if name.startswith('Vyrax/resources/') and files.getmember(name).isfile():
                packaged = files.extractfile(name).read()
                assert hashlib.sha256(packaged).digest() == hashlib.sha256((stage / 'opt' / name).read_bytes()).digest(), name
    with tempfile.TemporaryDirectory(prefix='vyrax-package-verify-') as extracted:
        subprocess.run(['dpkg-deb', '-x', str(deb), extracted], check=True)
        for file in (app / 'resources').rglob('*'):
            if file.is_file():
                other = Path(extracted) / file.relative_to(stage)
                assert hashlib.sha256(file.read_bytes()).digest() == hashlib.sha256(other.read_bytes()).digest(), file
    for file in [deb, archive]:
        manifest['packages'].append({'file': file.name, 'architecture': arch, 'bytes': file.stat().st_size, 'sha256': hashlib.file_digest(file.open('rb'), 'sha256').hexdigest()})
    print(f'{arch}: package/version, ELF cores, permissions, licenses, Polkit, portable payload verified')
(out / 'package-verification.json').write_text(json.dumps(manifest, indent=2) + '\n')
