// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import test from 'node:test';
import assert from 'node:assert/strict';
import { createUpdateChecker } from '../src/lib/update-checker.mjs';
import { availableRelease, shouldNotify } from '../src/lib/releases.mjs';

const flush = async () => { for (let i = 0; i < 10; i++) await Promise.resolve(); };
const newer = { version:'0.1.27',tag:'v0.1.27' };
function setup(request = async () => newer) {
  let time = 0, sequence = 0, calls = 0;
  const timers = new Map(), events = new EventTarget();
  const page = Object.assign(new EventTarget(), { visibilityState:'visible' });
  const releases = [], statuses = [];
  const checker = createUpdateChecker({
    request:() => { calls++;return request(calls); },
    onRelease:value => releases.push(value), onStatus:value => statuses.push(value),
    events, page, now:() => time,
    setTimer:(fn, delay) => { const id = ++sequence;timers.set(id, { fn, due:time + delay });return id; },
    clearTimer:id => timers.delete(id)
  });
  async function advance(ms) {
    const target = time + ms;
    for (;;) {
      const next = [...timers].sort((a, b) => a[1].due - b[1].due)[0];
      if (!next || next[1].due > target) break;
      time = next[1].due;timers.delete(next[0]);next[1].fn();await flush();
    }
    time = target;
  }
  return { checker, events, page, releases, statuses, timers, advance, get calls() { return calls; } };
}

test('opening starts an immediate check without a manual action or profile-load gate', async () => {
  const s = setup();s.checker.start();s.checker.start();await flush();
  assert.equal(s.calls, 1);assert.deepEqual(s.releases, [newer]);
  assert.deepEqual(s.statuses, ['checking', 'available']);s.checker.stop();
});

test('a failed startup check retries after 15 seconds and finds the update', async () => {
  const s = setup(async calls => { if (calls === 1) throw Error('offline');return newer; });
  s.checker.start();await flush();assert.equal(s.statuses.at(-1), 'unavailable');
  await s.advance(14999);assert.equal(s.calls, 1);
  await s.advance(1);assert.equal(s.calls, 2);assert.deepEqual(s.releases, [newer]);
  await s.advance(900000);assert.equal(s.calls, 2);s.checker.stop();
});

test('repeated network failures back off to at most one retry per 15 minutes', async () => {
  const s = setup(async () => { throw Error('unreachable'); });s.checker.start();await flush();
  for (const [i, delay] of [15000, 60000, 300000, 900000, 900000].entries()) {
    await s.advance(delay - 1);assert.equal(s.calls, i + 1);
    await s.advance(1);assert.equal(s.calls, i + 2);
  }
  assert.deepEqual(s.releases, []);s.checker.stop();
});

test('network recovery retries a failure immediately and merges duplicate online events', async () => {
  const s = setup(async calls => { if (calls === 1) throw Error('offline');return newer; });
  s.checker.start();await flush();
  s.events.dispatchEvent(new Event('online'));s.events.dispatchEvent(new Event('online'));await flush();
  assert.equal(s.calls, 2);assert.equal(s.statuses.at(-1), 'available');
  s.events.dispatchEvent(new Event('online'));await flush();assert.equal(s.calls, 2);s.checker.stop();
});

test('returning to the app checks again with a cooldown and ignores hidden focus events', async () => {
  const s = setup();s.checker.start();await flush();
  s.events.dispatchEvent(new Event('focus'));await flush();assert.equal(s.calls, 1);
  s.page.visibilityState = 'hidden';await s.advance(60000);
  s.events.dispatchEvent(new Event('focus'));await flush();assert.equal(s.calls, 1);
  s.page.visibilityState = 'visible';s.page.dispatchEvent(new Event('visibilitychange'));
  s.events.dispatchEvent(new Event('focus'));await flush();assert.equal(s.calls, 2);s.checker.stop();
});

test('manual checks stay available and share an automatic request already in progress', async () => {
  let finish;
  const s = setup(() => new Promise(resolve => { finish = resolve; }));
  s.checker.start();await flush();
  const first = s.checker.check(), second = s.checker.check();
  assert.equal(first, second);assert.equal(s.calls, 1);
  finish(newer);assert.deepEqual(await first, newer);
  const next = s.checker.check();await flush();assert.equal(s.calls, 2);
  finish(null);assert.equal(await next, null);assert.equal(s.statuses.at(-1), 'current');s.checker.stop();
});

test('stopping removes retries and event listeners, and ignores late results', async () => {
  let finish;
  const s = setup(() => new Promise(resolve => { finish = resolve; }));
  s.checker.start();await flush();s.checker.stop();finish(newer);await flush();
  assert.deepEqual(s.releases, []);assert.equal(s.timers.size, 0);
  await s.advance(12 * 60 * 60 * 1000);
  s.events.dispatchEvent(new Event('online'));s.events.dispatchEvent(new Event('focus'));
  s.page.dispatchEvent(new Event('visibilitychange'));await flush();assert.equal(s.calls, 1);
});

test('strict-mode stop and restart preserves one in-flight startup request', async () => {
  let finish;
  const s = setup(() => new Promise(resolve => { finish = resolve; }));
  s.checker.start();s.checker.stop();s.checker.start();await flush();assert.equal(s.calls, 1);
  finish(newer);await flush();assert.deepEqual(s.releases, [newer]);
  assert.equal(s.timers.size, 1);s.checker.stop();
});

test('a dismissed version stays quiet and a later published release can notify automatically', async () => {
  const repository = 'AmyraxVPN-Main/Vyrax';
  const data = { draft:false,prerelease:false,published_at:'2026-10-13T00:00:00Z' };
  const s = setup(async calls => {
    const tag = calls === 1 ? 'v0.1.27' : 'v0.1.28';
    return availableRelease({ ...data,tag_name:tag,html_url:`https://github.com/${repository}/releases/tag/${tag}` }, '0.1.26', repository);
  });
  s.checker.start();await flush();assert.equal(shouldNotify(s.releases.at(-1), '0.1.27'), false);
  await s.advance(12 * 60 * 60 * 1000);
  assert.equal(shouldNotify(s.releases.at(-1), '0.1.27'), true);s.checker.stop();
});
