// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
const nonnegative = value => typeof value === 'number' && Number.isFinite(value) && value >= 0;
export const TRAFFIC_CAPACITY = 60;

export function normalizeConnection(previous, next, now = Date.now()) {
  const phase = next.connecting ? (next.stage === 'stage.retry' ? 'retrying' : 'connecting')
    : next.disconnecting ? 'disconnecting' : next.connected ? 'connected' : 'idle';
  const result = { ...next, phase, trafficHistory:next.trafficHistory || [] };
  if (next.connected) {
    result.startedAt = next.startedAt ?? (previous.connected ? previous.startedAt : null) ?? now - (next.uptime || 0) * 1000;
    result.uptime = Math.max(0, Math.floor((now - result.startedAt) / 1000));
  } else if (!next.disconnecting) {
    result.startedAt = null;result.uptime = 0;result.upRate = 0;result.downRate = 0;
    if (!next.connecting) { result.exit = null;result.share = null; }
  }
  return result;
}

export function connectionReducer(state, action) {
  const now = action.now ?? Date.now();
  if (action.type === 'patch') {
    const next = typeof action.update === 'function' ? action.update(state) : { ...state, ...action.update };
    return next === state ? state : normalizeConnection(state, next, now);
  }
  if (action.type === 'begin') return normalizeConnection(state, { ...state, connected:false,connecting:true,
    disconnecting:false,stage:'stage.start',exit:null,share:null,up:0,down:0,upRate:0,downRate:0,
    startedAt:null,trafficHistory:[] }, now);
  if (action.type === 'stopping') return normalizeConnection(state, { ...state,connecting:false,disconnecting:true,stage:'' }, now);
  if (action.type === 'snapshot') {
    const data = action.data;
    if (!['connected','connecting','disconnected'].includes(data.status)) return state;
    const connected = data.status === 'connected';
    const since = Date.parse(data.since);
    return normalizeConnection(state, { ...state, connected,connecting:data.status === 'connecting',disconnecting:false,
      stage:data.stage || '', startedAt:connected && Number.isFinite(since) ? since : state.startedAt,
      activeTargets:connected ? data.activeTargets || state.activeTargets || [] : [],
      exit:connected ? Object.hasOwn(data,'exit') ? data.exit : state.exit : null,
      share:connected ? Object.hasOwn(data,'share') ? data.share : state.share : null }, now);
  }
  if (action.type === 'tick') {
    if (!state.connected) return state;
    const uptime = Math.max(0, Math.floor((now - state.startedAt) / 1000));
    return uptime === state.uptime ? state : { ...state,uptime };
  }
  if (action.type === 'stats') {
    if (!state.connected) return state;
    const next = { ...state };
    for (const key of ['up','down','upRate','downRate']) if (nonnegative(action.data[key])) next[key] = action.data[key];
    const history = state.trafficHistory || [], point = { at:now,up:next.upRate,down:next.downRate };
    // Coalesce bursts into one sample per second, keeping a fixed memory budget.
    const replace = history.length && now - history.at(-1).at < 1000;
    next.trafficHistory = [...(replace ? history.slice(0, -1) : history), point].slice(-TRAFFIC_CAPACITY);
    return next;
  }
  return state;
}
