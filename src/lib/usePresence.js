// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import { useEffect, useState } from 'react';

// Keep a dismissed sheet mounted only for its exit animation. Reopening cancels
// the pending removal; no timers or animation loops remain after unmount.
export default function usePresence(open, duration = 320) {
  const [mounted, setMounted] = useState(open);
  useEffect(() => {
    if (open) { setMounted(true);return undefined; }
    const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    const timer = setTimeout(() => setMounted(false), reduced ? 0 : duration);
    return () => clearTimeout(timer);
  }, [open, duration]);
  return open || mounted;
}
