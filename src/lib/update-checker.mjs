// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
const interval = 12 * 60 * 60 * 1000;
const retryDelays = [15000, 60000, 300000, 900000];
const resumeCooldown = 60000;

export function createUpdateChecker({ request, onRelease, onStatus,
  events = globalThis.window, page = globalThis.document,
  now = Date.now, setTimer = setTimeout, clearTimer = clearTimeout }) {
  let active = false, pending = null, timer = null, failures = 0, lastAttempt = -Infinity;
  const visible = () => page?.visibilityState !== 'hidden';
  function cancelTimer() { if (timer !== null) clearTimer(timer);timer = null; }
  function schedule(delay) {
    cancelTimer();
    if (!active) return;
    timer = setTimer(() => {
      timer = null;
      if (visible()) void check();else schedule(interval);
    }, delay);
  }
  function check() {
    if (!active) return Promise.resolve(null);
    if (pending) return pending;
    cancelTimer();lastAttempt = now();onStatus('checking');
    pending = Promise.resolve().then(request).then(release => {
      failures = 0;
      if (active) { onRelease(release);onStatus(release ? 'available' : 'current'); }
      return release;
    }).catch(() => {
      failures++;
      if (active) onStatus('unavailable');
      return null;
    }).finally(() => {
      pending = null;
      schedule(failures ? retryDelays[Math.min(failures - 1, retryDelays.length - 1)] : interval);
    });
    return pending;
  }
  function resume() {
    if (active && visible() && now() - lastAttempt >= resumeCooldown) void check();
  }
  function online() {
    if (active && visible() && failures) void check();else resume();
  }
  function start() {
    if (active) return;
    active = true;
    events?.addEventListener('online', online);
    events?.addEventListener('focus', resume);
    page?.addEventListener('visibilitychange', resume);
    // The bridge is ready before the UI mounts; profile loading is unrelated.
    void check();
  }
  function stop() {
    active = false;cancelTimer();
    events?.removeEventListener('online', online);
    events?.removeEventListener('focus', resume);
    page?.removeEventListener('visibilitychange', resume);
  }
  return { start, stop, check };
}
