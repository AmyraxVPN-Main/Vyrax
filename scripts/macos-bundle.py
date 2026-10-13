#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Amyrax
import plistlib
from pathlib import Path
import sys

app, version = Path(sys.argv[1]), sys.argv[2]
file = app / 'Contents/Info.plist'
with file.open('rb') as stream:
    data = plistlib.load(stream)
data.update(CFBundleIdentifier='com.amyrax.vyrax', CFBundleName='Vyrax', CFBundleDisplayName='Vyrax',
            CFBundleExecutable='Vyrax', CFBundleIconFile='Vyrax.icns', CFBundleShortVersionString=version,
            CFBundleVersion=version, NSHumanReadableCopyright='Copyright (c) 2026 Amyrax — MIT',
            LSMinimumSystemVersion='13.0', LSApplicationCategoryType='public.app-category.utilities',
            NSHighResolutionCapable=True, NSSupportsAutomaticGraphicsSwitching=True,
            NSRequiresAquaSystemAppearance=False,
            NSLocalNetworkUsageDescription='Vyrax can share your connection with devices on the same trusted network when you enable Proxy Sharing.')
with file.open('wb') as stream:
    plistlib.dump(data, stream)
for helper in (app / 'Contents/Frameworks').glob('Electron Helper*.app'):
    old_name = helper.stem
    name = old_name.replace('Electron', 'Vyrax', 1)
    with (helper / 'Contents/Info.plist').open('rb') as stream:
        data = plistlib.load(stream)
    executable = helper / 'Contents/MacOS' / data.get('CFBundleExecutable', old_name)
    executable.rename(executable.with_name(name))
    suffix = old_name.removeprefix('Electron Helper').strip(' ()').lower()
    data.update(CFBundleExecutable=name, CFBundleName=name, CFBundleDisplayName=name,
                CFBundleIdentifier='com.amyrax.vyrax.helper' + ('.' + suffix if suffix else ''))
    with (helper / 'Contents/Info.plist').open('wb') as stream:
        plistlib.dump(data, stream)
    helper.rename(helper.with_name(name + '.app'))
