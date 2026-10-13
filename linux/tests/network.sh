#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Amyrax
set -euo pipefail
# Must be launched INSIDE a new mount+network namespace. Never touches host routes.
[[ "${VYRAX_ISOLATED_TEST:-}" == 1 && "$EUID" == 0 ]] || { echo 'Run using unshare --mount --net with VYRAX_ISOLATED_TEST=1'; exit 1; }
cd "$(dirname "$0")/../.."
native="${1:?Pass the packaged resources/native directory}"
folder=$(mktemp -d /tmp/vyrax-linux-network.XXXXXX)
server=''
cleanup() { if [[ -n "$server" ]]; then kill "$server" 2>/dev/null || true;wait "$server" 2>/dev/null || true;fi; }
trap cleanup EXIT
ip link set lo up
mount -t sysfs sysfs /sys
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$folder/key.pem" -out "$folder/cert.pem" -days 2 -subj '/CN=Vyrax Linux synthetic test' -addext 'subjectAltName=DNS:www.gstatic.com,IP:1.1.1.1,IP:8.8.8.8,IP:203.0.113.10,IP:2001:db8::10' > /dev/null 2>&1
cp /etc/hosts "$folder/hosts"
printf '\n203.0.113.10 www.gstatic.com\n' >> "$folder/hosts"
mount --bind "$folder/hosts" /etc/hosts
export CURL_CA_BUNDLE="$folder/cert.pem" SSL_CERT_FILE="$folder/cert.pem"
unshare --net node linux/tests/fixture.mjs "$folder" "$native/cores/xray" > "$folder/server.log" 2>&1 &
server=$!
for attempt in {1..60}; do [[ -f "$folder/server.pid" ]] && break;sleep .1;done
peer=$(cat "$folder/server.pid")
ip link add eth0 type veth peer name fixture0
ip link set dev eth0 addrgenmode none
ip link set fixture0 netns "$peer"
ip addr add 198.18.0.2/24 dev eth0
ip -6 addr add 2001:db8:1::2/64 dev eth0 nodad
ip link set eth0 up
ip route add default via 198.18.0.1
ip -6 route add default via 2001:db8:1::1
nsenter -t "$peer" -n ip link set lo up
nsenter -t "$peer" -n ip link set dev fixture0 addrgenmode none
nsenter -t "$peer" -n ip addr add 198.18.0.1/24 dev fixture0
nsenter -t "$peer" -n ip -6 addr add 2001:db8:1::1/64 dev fixture0 nodad
nsenter -t "$peer" -n ip link set fixture0 up
nsenter -t "$peer" -n ip addr add 203.0.113.10/32 dev lo
nsenter -t "$peer" -n ip addr add 1.1.1.1/32 dev lo
nsenter -t "$peer" -n ip addr add 8.8.8.8/32 dev lo
nsenter -t "$peer" -n ip -6 addr add 2001:db8::10/128 dev lo nodad
node linux/tests/network.mjs "$folder" "$native"
cat "$folder/network-results.json"
cp "$folder/network-results.json" release/linux-0.1.19/network-verification.json
