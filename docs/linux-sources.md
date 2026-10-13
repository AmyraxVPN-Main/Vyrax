# Linux core source and build instructions

Vyrax's MIT source is available in the same release's source archive and at
https://github.com/AmyraxVPN-Main/Vyrax . Application changes and the Linux host
remain Copyright (c) 2026 Amyrax. Electron retains its MIT license and Chromium
dependency notices, shipped in the package's `licenses` directory.

The separate Xray executable is built from Xray-core v26.3.27 (MPL-2.0); the
separate sing-box executable is built from sing-box v1.14.3 (GPL-3.0-or-later).
Exact upstream source archives accompany the binaries in this directory.
The `vendor/linux-versions.json` manifest identifies the matching original
upstream releases and checksums. These components are unmodified and run as
separate processes; no proprietary wrapper replaces or relicenses them.

To rebuild, extract the matching archive, install the Go version stated in its
`go.mod`, and follow the included upstream build scripts and build tags. With
the upstream Go dependencies available:

```sh
# Xray-core source
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags='-s -w' -o xray ./main
# sing-box source; official release feature tags are in its included scripts
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath \
  -tags 'with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_tailscale' \
  -ldflags='-s -w' -o sing-box ./cmd/sing-box
```

Use GOARCH=arm64 for ARM64. Place rebuilt executables under
`resources/native/cores` in the extracted portable package. They can be replaced
independently; no signing key or relinking secret is required. Retain their license
texts and source obligations when redistributing modified or original packages.
