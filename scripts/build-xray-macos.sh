#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Amyrax
set -euo pipefail
cd "$(dirname "$0")/.."
arch="${1:-arm64}"
case "$arch" in x64) goarch=amd64;; arm64) goarch=arm64;; *) exit 1;; esac
work="$PWD/macos/build/xray-source"
python3 - "$work" <<'PY'
import hashlib
from pathlib import Path
import sys, tarfile
archive=Path('vendor/macos/sources/Xray-core-v26.3.27-source.tar.gz')
assert hashlib.file_digest(archive.open('rb'),'sha256').hexdigest()=='992a4997e6bb846d11469435d687f99ef812fcde1e0a009bb8e95189ea20331d'
destination=Path(sys.argv[1]);destination.mkdir(parents=True,exist_ok=True)
with tarfile.open(archive) as source:source.extractall(destination,filter='data')
PY
python3 scripts/patch-xray-linux-headers.py "$work/Xray-core-26.3.27" --diff "$work/vyrax-literal-headers.patch"
cp linux/tests/xray_headers_test.go "$work/Xray-core-26.3.27/proxy/http/vyrax_headers_test.go"
repo="$PWD"
(
  cd "$work/Xray-core-26.3.27"
  go test -run TestVyrax ./proxy/http
  CGO_ENABLED=0 GOOS=darwin GOARCH="$goarch" go build -trimpath -buildvcs=false -ldflags='-s -w -buildid= -X github.com/xtls/xray-core/core.build=vyrax-macfix1' -o "$repo/vendor/macos/$arch/xray/xray" ./main
)
cp "$work/vyrax-literal-headers.patch" "vendor/macos/$arch/xray/"
tar -czf vendor/macos/sources/Xray-core-v26.3.27-vyrax-macfix1-source.tar.gz -C "$work" Xray-core-26.3.27
