#!/usr/bin/python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Amyrax
"""Unprivileged child lease: cores cannot survive a killed desktop process."""
import os
import ctypes
import signal
import subprocess
import sys
import time

def identity(pid):
    return open(f'/proc/{pid}/stat').read().rsplit(')', 1)[1].split()[19]

parent = int(sys.argv[1])
started = identity(parent)
libc = ctypes.CDLL(None)
child = subprocess.Popen(sys.argv[2:], preexec_fn=lambda: libc.prctl(1, signal.SIGTERM))
def stop(*_args):
    if child.poll() is None:
        child.terminate()
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            child.kill()
    sys.exit(0)
signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
try:
    while child.poll() is None:
        if identity(parent) != started:
            stop()
        time.sleep(.2)
except (FileNotFoundError, ProcessLookupError):
    stop()
sys.exit(child.returncode)
