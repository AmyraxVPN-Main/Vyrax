#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
testconfig=$(mktemp -d /tmp/vyrax-proxy-test-XXXXXX)
trap 'rm -rf -- "$testconfig"' EXIT
XDG_CONFIG_HOME="$testconfig" XDG_CURRENT_DESKTOP=GNOME dbus-run-session -- node linux/tests/proxy.mjs
