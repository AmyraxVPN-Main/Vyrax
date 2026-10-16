# macOS core sources and replacement

Vyrax is MIT licensed, Copyright (c) 2026 Amyrax. Xray-core v26.3.27 remains
MPL-2.0; sing-box v1.14.3 remains GPL-3.0-or-later. Electron is MIT licensed,
with its included Chromium notices. These separate executables are not
relicensed under the application's license. Exact upstream source archives
are provided here; `vendor/macos-versions.json` pins source and binary releases.

The macfix1 packages rebuild Xray with the included literal HTTP-header patch.
Internal observatory probes can send static proxy authorization headers without
an inbound socket; dynamic header templates retain their original validation.
The exact modified source archive and regression test accompany the binaries.
Run `scripts/build-xray-macos.sh arm64` (or `x64`) after preparing the pinned
archives to reproduce the core. `scripts/build-macos.sh` calls this automatically
and signs the cores, native helpers and app in the required order.

Use the Go version required by each source's go.mod and its included upstream
release scripts/build tags. A basic native rebuild is:

```sh
# Xray source:
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags='-s -w' -o xray ./main
# sing-box source (check the included official release tags):
CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath \
  -tags 'with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_tailscale' \
  -ldflags='-s -w' -o sing-box ./cmd/sing-box
```

Use GOARCH=amd64 for Intel. To substitute your cores, modify the pins and
preparation inputs in your source checkout and run `scripts/build-macos.sh`.
The helper's `core-pins.h` is generated from the **final signed sing-box bytes**.
That check protects the administrator boundary from an executable swapped in
after installation. Compile the helper again after replacing sing-box, sign
the helpers and outer bundle again, and keep the license/source obligations.
All of this can use ad-hoc signing: no private publisher key or relinking secret
is required to run a modified build. Simply dropping a different sing-box into
a signed release bundle will invalidate both the bundle and helper hash.
