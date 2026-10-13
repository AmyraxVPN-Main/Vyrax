#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo 'Build with Xcode on macOS' >&2; exit 1; }
export VYRAX_VERSION=$(node -p 'require("./package.json").version')
export VYRAX_APPLE_TEAM="${VYRAX_APPLE_TEAM:-}"
out="$PWD/release/ios-$VYRAX_VERSION"
mkdir -p "$out"
npm ci --no-audit --no-fund
npm run build
node .tools/gen-geo.mjs
node scripts/collect-licenses.mjs
python3 scripts/prepare-ios.py
bash scripts/build-ios-cores.sh
xcodegen generate --spec ios/project.yml
xcodebuild -project ios/Vyrax.xcodeproj -scheme Vyrax -configuration Release -destination 'generic/platform=iOS' -archivePath "$PWD/ios/build/Vyrax-unsigned.xcarchive" CODE_SIGNING_ALLOWED=NO archive > "$out/device-build.log" 2>&1 || { tail -100 "$out/device-build.log"; exit 1; }
ditto -c -k --keepParent ios/build/Vyrax-unsigned.xcarchive "$out/Vyrax-$VYRAX_VERSION-ios-arm64-UNSIGNED.xcarchive.zip"
xcodebuild -project ios/Vyrax.xcodeproj -scheme Vyrax -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath "$PWD/ios/build/DerivedData" ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build-for-testing > "$out/simulator-build.log" 2>&1 || { tail -100 "$out/simulator-build.log"; exit 1; }
ditto -c -k --keepParent ios/build/DerivedData/Build/Products/Debug-iphonesimulator/Vyrax.app "$out/Vyrax-$VYRAX_VERSION-ios-simulator.app.zip"
cp ios/Engine/go.mod ios/Engine/go.sum "$out/"
node --test ios/Tests/config.test.mjs > "$out/config-tests.txt"
python3 scripts/verify-ios.py
