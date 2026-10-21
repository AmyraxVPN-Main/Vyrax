<div align="center">
<img src="assets/images/icon.png" alt="Vyrax" width="88">

# Vyrax

A proxy client by Amyrax, based on FLClash and Mihomo.

[Releases](https://github.com/AmyraxVPN-Main/Vyrax/releases) · [Issues](https://github.com/AmyraxVPN-Main/Vyrax/issues) · [Telegram](https://t.me/AmyraxVPN) · [简体中文](README_zh_CN.md)
</div>

## Releases

Version 0.2.0 provides an installer and ZIP for Windows x64. The installer recognizes
an existing Vyrax installation. Automatic update checks use this project's latest
stable GitHub release, on startup and every 12 hours while visible.

Paste subscription URLs or proxy links with Ctrl+V, or use clipboard import.
Supported imports include Clash YAML, V2Ray links, Base64 subscriptions and
supported Xray/sing-box JSON configurations. Imported configurations run through
the bundled compatible core; this does not bundle separate Xray or sing-box engines.
Manual server selection, Fastest selection and the free-server view are included.

Windows x64 and Linux x64 releases are built and checked. Linux packages target
Ubuntu 24.04 or compatible systems. macOS branding is included in source; its
build requires a Mac with Xcode and remains unverified. There is no iOS target. See [branding and compatibility](docs/vyrax-branding.md) for data and
installer behavior.

## Build from source

Use Flutter 3.47.6, Go 1.27 and Rust through rustup. Windows packaging also needs
Visual Studio C++ Build Tools and Inno Setup 6.

```bash
git clone --recursive https://github.com/AmyraxVPN-Main/Vyrax.git
cd Vyrax
flutter pub get
dart setup.dart windows
```

Packages are written to `dist/`. Preserve the modified Mihomo sources in
`core/Clash.Meta` when distributing this fork. Icon sources and their generation
command are documented in `.agents/commands.md`.

## License and attribution

Vyrax is licensed under [GPL-3.0](LICENSE). It is derived from
[FLClash](https://github.com/chen08209/FlClash) and uses the
[Mihomo fork](https://github.com/chen08209/Clash.Meta/tree/FlClash).
Upstream copyright and third-party license notices are retained.
