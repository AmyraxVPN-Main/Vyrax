#!/usr/bin/python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Amyrax
"""Privileged, bounded TUN lease. Accepts numbers only, never caller configs/paths."""
import argparse
import ctypes
import fcntl
import ipaddress
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile
import time

def build(port, mtu, xray):
    return {
        'log': {'level': 'warn'},
        'dns': {'servers': [{'type': 'https', 'tag': 'remote-dns', 'server': '1.1.1.1', 'server_port': 443, 'path': '/dns-query', 'detour': 'proxy'}], 'final': 'remote-dns'},
        'inbounds': [{'type': 'tun', 'tag': 'tun-in', 'interface_name': 'Vyrax', 'address': ['172.28.0.1/30', 'fdfe:dcba:9876::1/126'], 'mtu': mtu, 'auto_route': True, 'strict_route': True, 'stack': 'mixed'}],
        'outbounds': [{'type': 'socks', 'tag': 'proxy', 'server': '127.0.0.1', 'server_port': port, 'version': '5'}, {'type': 'direct', 'tag': 'direct'}],
        'route': {'auto_detect_interface': True, 'rules': [
            {'process_path': [str(xray)], 'action': 'route', 'outbound': 'direct'},
            {'action': 'sniff'},
            {'protocol': 'dns', 'action': 'hijack-dns'},
            {'ip_is_private': True, 'action': 'route', 'outbound': 'direct'}], 'final': 'proxy'}
    }

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--parent', type=int, required=True)
    parser.add_argument('--port', type=int, required=True)
    parser.add_argument('--mtu', type=int, required=True)
    args = parser.parse_args()
    if os.geteuid() != 0 or args.parent < 2 or not 1 <= args.port <= 65535 or not 1280 <= args.mtu <= 1500:
        raise ValueError('Invalid tunnel request')
    uid = int(os.environ.get('PKEXEC_UID', os.getuid()))
    proc = Path(f'/proc/{args.parent}')
    if proc.stat().st_uid != uid:
        raise ValueError('Caller mismatch')
    identity = (proc / 'stat').read_text().rsplit(')', 1)[1].split()[19]
    base = Path(__file__).resolve().parent
    core = base / 'cores' / 'sing-box'
    xray = base / 'cores' / 'xray'
    # Fixed packaged locations; no shell, credentials, arbitrary file or core arguments.
    if not core.is_file() or not xray.is_file():
        raise ValueError('Missing packaged cores')
    lock = open('/run/vyrax-tun.lock', 'w')
    os.chmod('/run/vyrax-tun.lock', 0o600)
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    child = None
    def stop(*_args):
        if child and child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=8)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
    try:
        with tempfile.TemporaryDirectory(prefix='vyrax-tun-', dir='/run') as folder:
            config = Path(folder) / 'tun.json'
            config.write_text(json.dumps(build(args.port, args.mtu, xray)))
            os.chmod(config, 0o600)
            subprocess.run([str(core), 'check', '-c', str(config)], check=True, timeout=8)
            libc = ctypes.CDLL(None)
            child = subprocess.Popen([str(core), 'run', '-c', str(config)], stdin=subprocess.DEVNULL,
                                     preexec_fn=lambda: libc.prctl(1, signal.SIGTERM))
            deadline = time.monotonic() + 10
            pending = b''
            announced = False
            while child.poll() is None:
                if (proc / 'stat').read_text().rsplit(')', 1)[1].split()[19] != identity:
                    break
                if select.select([sys.stdin.buffer], [], [], .2)[0]:
                    chunk = os.read(sys.stdin.fileno(), 4096)
                    if not chunk:
                        break
                    pending += chunk
                    if len(pending) > 8192:
                        break
                    while b'\n' in pending:
                        line, pending = pending.split(b'\n', 1)
                        if line == b'stop':
                            return
                        if line != b'alive':
                            raise ValueError('Invalid lease')
                        deadline = time.monotonic() + 10
                if time.monotonic() > deadline:
                    break
                if not announced and Path('/sys/class/net/Vyrax').exists():
                    print('VYRAX_TUN_READY', flush=True)
                    announced = True
            if child.poll() not in (None, 0):
                raise RuntimeError('Tunnel core failed')
    finally:
        stop()

if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(f'TUN: {type(error).__name__}: {error}', file=sys.stderr)
        sys.exit(1)
