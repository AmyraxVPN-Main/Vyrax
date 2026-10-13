#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Amyrax
set -eu
base=${0%/*}
exec /usr/bin/python3 -I "$base/tun-helper.py" "$@"
