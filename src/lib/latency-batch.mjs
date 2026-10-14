// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
const metadata = new Set(['name','latency','tested','favorite','cc','country','geoIp','sourceId']);
export function probeIdentity(profile) {
  return JSON.stringify(Object.entries(profile).filter(([key]) => !metadata.has(key)).sort(([a],[b]) => a.localeCompare(b)));
}
export async function testLatencyBatch(profiles, { probe, onResult, concurrency = 3, signal }) {
  const queue = [...new Map(profiles.map(p => [p.id, p])).values()], results = [];
  const worker = async () => {
    while (queue.length && !signal?.aborted) {
      const profile = queue.shift();let latency = null;
      try { const result = await probe(profile);if (Number.isFinite(result?.latency) && result.latency > 0) latency = result.latency; }
      catch { /* A failed HTTP probe is unavailable, not zero milliseconds. */ }
      if (signal?.aborted) return;
      results.push([profile.id,latency]);onResult?.(profile,latency);
      // Give input, sheet dismissal and paint a turn between completed probes.
      await new Promise(resolve => setTimeout(resolve, 0));
    }
  };
  await Promise.all(Array.from({ length:Math.min(queue.length,Math.max(1,Math.min(8,concurrency))) }, worker));
  return results;
}
