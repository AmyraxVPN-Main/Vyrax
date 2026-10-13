#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Amyrax
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo 'Build on macOS' >&2; exit 1; }
arch="${1:-arm64}"
case "$arch" in arm64) machine=arm64;; x64) machine=x86_64;; *) exit 1;; esac
[[ "$(uname -m)" == "$machine" ]] || { echo 'Use a native runner for this architecture' >&2; exit 1; }
version=$(node -p 'require("./package.json").version')
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
npm ci
npm run build
node .tools/gen-geo.mjs
node scripts/collect-licenses.mjs
python3 scripts/prepare-macos.py "$arch"
stage="$PWD/macos/build/$arch"
[[ "$stage" == "$PWD/macos/build/"* ]] || exit 1
rm -rf -- "$stage"
mkdir -p "$stage" "$PWD/release/macos-$version/sources"
app="$stage/Vyrax.app"
ditto "vendor/macos/$arch/electron/Electron.app" "$app"
mv "$app/Contents/MacOS/Electron" "$app/Contents/MacOS/Vyrax"
res="$app/Contents/Resources"
rm -f "$res/default_app.asar"
mkdir -p "$res/app/linux" "$res/app/macos" "$res/app/src/lib" "$res/native/cores" "$res/licenses/npm"
cp linux/*.cjs linux/*.mjs "$res/app/linux/"
cp macos/backend.mjs "$res/app/macos/"
cp src/lib/preferences.mjs src/lib/releases.mjs "$res/app/src/lib/"
cp project.json "$res/app/"
node -e 'const fs=require("fs"),p=require("./package.json");p.main="linux/main.cjs";p.dependencies={};p.devDependencies={};fs.writeFileSync(process.argv[1],JSON.stringify(p,null,2))' "$res/app/package.json"
ditto dist "$res/app/ui"
cp native/geo.bin "$res/native/"
cp "vendor/macos/$arch/xray/xray" "$res/native/cores/"
cp "$(find "vendor/macos/$arch/sing-box" -name sing-box -type f -print -quit)" "$res/native/cores/"
chmod 755 "$res/native/cores/"*
cp LICENSE THIRD_PARTY_NOTICES.md vendor/macos-versions.json "$res/licenses/"
ditto vendor/npm-licenses "$res/licenses/npm"
cp third_party/flag-icons-MIT.txt third_party/GPL-3.0.txt "$res/licenses/"
cp "vendor/macos/$arch/electron/LICENSE" "$res/licenses/Electron-LICENSE.txt"
cp "vendor/macos/$arch/electron/LICENSES.chromium.html" "$res/licenses/"
find "vendor/macos/$arch/xray" -maxdepth 1 -iname '*license*' -exec cp {} "$res/licenses/Xray-LICENSE.txt" \;
find "vendor/macos/$arch/sing-box" -iname '*license*' -exec cp {} "$res/licenses/sing-box-LICENSE.txt" \;
cp docs/macos.md "$res/README.md"
mkdir -p "$stage/Vyrax.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" public/vyrax-icon.png --out "$stage/Vyrax.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" public/vyrax-icon.png --out "$stage/Vyrax.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$stage/Vyrax.iconset" -o "$res/Vyrax.icns"
python3 scripts/macos-bundle.py "$app" "$version"
# The monochrome menu-bar image is generated from our existing vector mark.
swift scripts/macos-tray.swift "$res/app/ui"
identity="${VYRAX_MAC_SIGN_IDENTITY:--}"
sign() { codesign --force --sign "$identity" --options runtime --entitlements macos/entitlements.plist "$1"; }
# Sign inner code first. The root helper pins the final signed sing-box bytes.
while IFS= read -r -d '' file; do
  if file -b "$file" | grep -q 'Mach-O'; then sign "$file"; fi
done < <(find "$app/Contents" -type f -print0)
while IFS= read -r bundle; do sign "$bundle"; done < <(find "$app/Contents/Frameworks" -depth \( -name '*.framework' -o -name '*.app' \) -type d)
hash=$(shasum -a 256 "$res/native/cores/sing-box" | cut -d ' ' -f 1)
printf '#define SINGBOX_SHA256 "%s"\n' "$hash" > "$stage/core-pins.h"
flags=(-arch "$machine" -mmacosx-version-min=13.0 -O2 -Wall -Wextra -Wno-unused-function -Wno-unused-parameter)
clang "${flags[@]}" macos/native/authorize.c -framework Security -Wno-deprecated-declarations -o "$res/native/vyrax-authorize"
clang "${flags[@]}" macos/native/core-lease.c -o "$res/native/vyrax-core-lease"
clang "${flags[@]}" -fobjc-arc -I "$stage" macos/native/network.m -framework Foundation -framework SystemConfiguration -o "$res/native/vyrax-network"
for helper in vyrax-authorize vyrax-core-lease vyrax-network; do sign "$res/native/$helper"; done
sign "$app"
codesign --verify --deep --strict "$app"
python3 scripts/verify-macos.py "$app" "$arch"
out="$PWD/release/macos-$version"
cp vendor/macos/sources/* "$out/sources/"
cp docs/macos-sources.md "$out/sources/BUILDING.md"
ditto -c -k --sequesterRsrc --keepParent "$app" "$out/Vyrax-$version-macos-$arch.zip"
image="$stage/image"
mkdir "$image"
ditto "$app" "$image/Vyrax.app"
ln -s /Applications "$image/Applications"
cp docs/macos.md "$image/READ-ME.txt"
hdiutil create -volname "Vyrax $version" -srcfolder "$image" -ov -format UDZO "$out/Vyrax-$version-macos-$arch.dmg"
(cd "$out"; shasum -a 256 "Vyrax-$version-macos-$arch.zip" "Vyrax-$version-macos-$arch.dmg" > "SHA256SUMS-$arch.txt")
echo "macOS $arch packages: $out"
