# Linux desktop

Vyrax 0.1.20 ships an Electron desktop host with the same React interface,
Persian/English translations, themes and animations as Windows. Packages are
available for x86-64 (`x64`, most Intel/AMD PCs) and ARM64 (`arm64`).

## Install and run

On Ubuntu 22.04+/Debian 12+ with a graphical desktop, install the matching `.deb`:

```sh
sudo apt install ./Vyrax-0.1.20-linux-x64.deb
vyrax
```

TUN requests permission through the desktop's Polkit agent when connecting.
Only its tunnel helper runs as root. Run the app itself as your ordinary user.
GNOME and KDE desktop proxy settings are supported. Applications that ignore
desktop proxy settings need TUN. Other desktops can use TUN directly.
The helper requires `/dev/net/tun` and Linux network administration support.
LAN sharing listens only on private IPv4 interfaces; the host's existing firewall
still controls access from other devices. Sharing is disabled by default.

The portable `.tar.gz` contains the same app and cores. Extract it and run
`Vyrax/vyrax`. Install the runtime dependencies listed in `scripts/build-linux.sh`.
If the desktop restricts user namespaces, set up Chromium's packaged sandbox:

```sh
sudo chown root:root Vyrax/chrome-sandbox
sudo chmod 4755 Vyrax/chrome-sandbox
```

Keep the whole portable folder together and in a trusted location. The `.deb`
performs the sandbox setup and installs root-owned application files for you.
Do not use `--no-sandbox` or run the graphical app as root.

## Behavior and local data

Single/batch config imports become subscription groups. Selection stays within
the current group. Xray's least-ping/least-load routing changes new connections
without terminating established streams. Manual selection stops automatic routing.
Changing subscription or manual target also updates routing without restarting
the running core. Delay tests use two HTTPS HEAD requests through each config;
the warm request is measured, with an eight-second overall budget and four workers.
Subscription fetching, copying and closing panels remain independent of that work.

TUN includes IPv4 and IPv6, remote DNS, private-LAN bypass and explicit Xray-process
loop protection. A connection succeeds only after a verified request through the
proxy and, for TUN, a verified request bound to the tunnel address. The tunnel lease
ends on disconnect, application exit, parent death or loss of its heartbeat.
System proxy settings are journaled and restored on disconnect/exit; a separate
unprivileged watcher also restores them after a desktop crash. Settings subsequently
changed by another app or the user are preserved.

Data resides under `~/.config/Vyrax/data` (respecting `XDG_CONFIG_HOME`).
The store uses the desktop secret service/KWallet when Electron can access it.
Without a keyring, it uses AES-256-GCM with a separate local key file. Data and key
files have mode 0600; their directory has mode 0700. That fallback protects other
local accounts, not a process already running as the same user. Private temporary
configs are removed after use. Diagnostics stay local in `last-tunnel.log`.
The app checks only public GitHub release metadata for update notifications.

## Build from source

Use Linux with Node 22.12+, npm, Python 3.12+, curl, tar, dpkg-deb and
desktop-file-utils. The Python preparation script uses safe archive extraction.

```sh
bash scripts/build-linux.sh x64
bash scripts/build-linux.sh arm64
```

Upstream runtime downloads are pinned by SHA-256 in `vendor/linux-versions.json`.
The script verifies them before extraction, builds the shared interface, includes
licenses/offline country data and outputs packages and exact core sources in
`release/linux-0.1.20`. Building ARM64 packages does not require executing ARM code.

Subscription refresh during a connection uses a dedicated local core inbound to
reach the ordinary uplink first, then falls back through the selected proxy when
needed. This keeps panels that reject datacenter exits accessible without changing
user traffic routing or stopping the VPN. Downloads retain gzip, safe redirects,
title/usage headers and a four-MiB limit.

## Verification limits

The x64 desktop and isolated real Proxy/TUN traffic are tested on Ubuntu 24.04
under WSL2. This does not replace testing native GNOME/KDE/Wayland sessions or
physical ARM64 machines. ARM64 packages contain verified upstream ARM64 binaries;
they are not runtime-tested on ARM hardware. Package prerequisites target Ubuntu
22.04+ and Debian 12+; the binary host is not an Alpine/musl build.

Re-run the included checks on Linux with `node --test linux/tests/config.test.mjs`,
`bash linux/tests/proxy.sh`, and `dbus-run-session -- xvfb-run -a node linux/tests/desktop.mjs`
after installing the x64 package and running `ELECTRON_SKIP_BINARY_DOWNLOAD=1 npm ci
--ignore-scripts --prefix linux`. Network integration tests require a fresh isolated
mount/network namespace; see the guard in `linux/tests/network.sh`. Never run those
route tests in a normal host namespace.
