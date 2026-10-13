#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Amyrax
set -euo pipefail
cd "$(dirname "$0")/.."
arch="${1:-x64}"
case "$arch" in x64) debarch=amd64;; arm64) debarch=arm64;; *) echo 'Choose x64 or arm64' >&2; exit 1;; esac
version=$(node -p 'JSON.parse(require("fs").readFileSync("package.json","utf8")).version')
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
npm ci
npm run build
node .tools/gen-geo.mjs
node scripts/collect-licenses.mjs
python3 scripts/prepare-linux.py "$arch"
out="$PWD/release/linux-$version"
stage="$PWD/linux/build/$arch"
[[ "$stage" == "$PWD/linux/build/"* ]] || exit 1
rm -rf -- "$stage"
mkdir -p "$stage/opt/Vyrax" "$stage/usr/bin" "$stage/usr/share/applications" "$stage/usr/share/icons/hicolor/512x512/apps" "$stage/usr/share/polkit-1/actions" "$stage/DEBIAN" "$out/sources"
appdir="$stage/opt/Vyrax"
cp -a "vendor/linux/$arch/electron/." "$appdir/"
mv "$appdir/electron" "$appdir/vyrax-bin"
mkdir -p "$appdir/resources/app/linux" "$appdir/resources/app/src/lib" "$appdir/resources/native/cores" "$appdir/licenses/npm"
cp linux/*.cjs linux/*.mjs "$appdir/resources/app/linux/"
cp src/lib/preferences.mjs src/lib/releases.mjs "$appdir/resources/app/src/lib/"
cp package.json project.json "$appdir/resources/app/"
# The packaged entry is deliberately separate from the frontend/build package.
node -e 'let fs=require("fs"),p=JSON.parse(fs.readFileSync("package.json"));p.main="linux/main.cjs";p.dependencies={};p.devDependencies={};fs.writeFileSync(process.argv[1],JSON.stringify(p,null,2))' "$appdir/resources/app/package.json"
cp -a dist "$appdir/resources/app/ui"
cp linux/*.py "$appdir/resources/native/"
cp linux/vyrax-tun.sh "$appdir/resources/native/vyrax-tun"
cp linux/com.amyrax.vyrax.tun.policy "$stage/usr/share/polkit-1/actions/"
cp native/geo.bin "$appdir/resources/native/"
cp "vendor/linux/$arch/xray/xray" "$appdir/resources/native/cores/"
cp "$(find "vendor/linux/$arch/sing-box" -name sing-box -type f -print -quit)" "$appdir/resources/native/cores/"
cp LICENSE THIRD_PARTY_NOTICES.md vendor/linux-versions.json "$appdir/licenses/"
cp -a vendor/npm-licenses/. "$appdir/licenses/npm/"
cp -a third_party/flag-icons-MIT.txt third_party/GPL-3.0.txt "$appdir/licenses/"
find "vendor/linux/$arch/xray" -maxdepth 1 -iname '*license*' -exec cp {} "$appdir/licenses/Xray-LICENSE.txt" \;
find "vendor/linux/$arch/sing-box" -iname '*license*' -exec cp {} "$appdir/licenses/sing-box-LICENSE.txt" \;
cp "$appdir/LICENSE" "$appdir/licenses/Electron-LICENSE.txt"
cp "$appdir/LICENSES.chromium.html" "$appdir/licenses/"
cp docs/linux.md "$appdir/README.md"
chmod 755 "$appdir/vyrax-bin" "$appdir/chrome-sandbox" "$appdir/resources/native/cores/"* "$appdir/resources/native/"*.py
chmod 755 "$appdir/resources/native/vyrax-tun"
cat > "$appdir/vyrax" <<'LAUNCHER'
#!/bin/sh
set -eu
base=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$base/vyrax-bin" "$@"
LAUNCHER
chmod 755 "$appdir/vyrax"
ln -s /opt/Vyrax/vyrax "$stage/usr/bin/vyrax"
cp public/vyrax-icon.png "$stage/usr/share/icons/hicolor/512x512/apps/vyrax.png"
cat > "$stage/usr/share/applications/vyrax.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Vyrax
Comment=Free and open-source VPN client by Amyrax
Exec=vyrax
Icon=vyrax
Categories=Network;Security;
Terminal=false
StartupWMClass=Vyrax
DESKTOP
desktop-file-validate "$stage/usr/share/applications/vyrax.desktop"
cat > "$stage/DEBIAN/control" <<CONTROL
Package: vyrax
Version: $version
Architecture: $debarch
Maintainer: Amyrax <177610028+AmyraxVPN-Main@users.noreply.github.com>
Installed-Size: $(du -sk "$stage/opt" | cut -f1)
Depends: python3 (>= 3.8), curl, pkexec, libglib2.0-bin, dconf-gsettings-backend, libgtk-3-0, libnss3, libnspr4, libatk1.0-0, libatk-bridge2.0-0, libdrm2, libx11-6, libxcb1, libxcomposite1, libxdamage1, libxext6, libxfixes3, libxrandr2, libgbm1, libpango-1.0-0, libcairo2, libasound2
Recommends: gsettings-desktop-schemas
Section: net
Priority: optional
Homepage: https://github.com/AmyraxVPN-Main/Vyrax
Description: Free and open-source VPN client by Amyrax
 Shared React desktop interface, Xray proxy transports and a privileged
 sing-box TUN lease, with subscriptions, URL delay tests and automatic routing.
CONTROL
cat > "$stage/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
# Chromium's supported setuid sandbox is required on desktops that restrict
# unprivileged user namespaces (including Ubuntu 24.04).
chown root:root /opt/Vyrax/chrome-sandbox
chmod 4755 /opt/Vyrax/chrome-sandbox
POSTINST
chmod 755 "$stage/DEBIAN/postinst"
dpkg-deb --root-owner-group --build "$stage" "$out/Vyrax-$version-linux-$arch.deb"
tar -czf "$out/Vyrax-$version-linux-$arch.tar.gz" -C "$stage/opt" Vyrax
cp vendor/linux/sources/* "$out/sources/"
cp docs/linux-sources.md "$out/sources/BUILDING.md"
(cd "$out"; sha256sum "Vyrax-$version-linux-$arch.deb" "Vyrax-$version-linux-$arch.tar.gz" > "SHA256SUMS-$arch.txt")
echo "Linux $arch packages: $out"
