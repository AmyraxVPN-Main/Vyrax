import { parse as parseYaml } from 'yaml';

/* پارسر کانفیگ‌های v2ray: لینک اشتراک، base64، Clash YAML و JSON خروجی sing-box/Xray.
   پیام‌های خطا با کلید برمی‌گردند تا رابط بتواند ترجمه‌شان کند. */

const protocols = new Set(['vless', 'vmess', 'trojan', 'shadowsocks']);
const transports = new Set(['tcp', 'ws', 'grpc', 'httpupgrade', 'xhttp']);
// Only connection fields travel with a shared local subscription.
const PROFILE_FIELDS = ['protocol', 'name', 'host', 'port', 'uuid', 'password', 'method',
  'cipher', 'alterId', 'transport', 'path', 'wsHost', 'serviceName', 'tls', 'sni',
  'alpn', 'insecure', 'fingerprint', 'reality', 'publicKey', 'shortId', 'flow', 'mode'];
const connectionFields = p => Object.fromEntries(PROFILE_FIELDS.filter(key => p[key] !== undefined).map(key => [key, p[key]]));

export const exportProfiles = profiles => JSON.stringify(profiles.map(connectionFields));

const METHODS = [
  'aes-128-gcm',
  'aes-256-gcm',
  'chacha20-ietf-poly1305',
  '2022-blake3-aes-128-gcm',
  '2022-blake3-aes-256-gcm',
  '2022-blake3-chacha20-poly1305',
  'none'
];

const passthrough = (key) => key;
let T = passthrough;
const fail = (key) => {
  throw new Error(T(key));
};

function decode64(text) {
  const normal = text.trim().replace(/-/g, '+').replace(/_/g, '/');
  return new TextDecoder('utf-8', { fatal: true }).decode(
    Uint8Array.from(atob(normal.padEnd(Math.ceil(normal.length / 4) * 4, '=')), (c) =>
      c.charCodeAt(0)
    )
  );
}

const bool = (value) => value === true || value === 1 || value === '1' || value === 'true';
const decode = (s) => {
  try {
    return decodeURIComponent(s || '');
  } catch {
    return s || '';
  }
};
const uuid = (value) => /^[a-f\d]{8}-[a-f\d]{4}-[a-f\d]{4}-[a-f\d]{4}-[a-f\d]{12}$/i.test(value);

function normalize(p) {
  p.protocol = p.protocol === 'ss' ? 'shadowsocks' : p.protocol;
  p.transport = p.transport || 'tcp';
  p.host = String(p.host || '').replace(/^\[|\]$/g, '');
  p.port = Number(p.port);

  if (!protocols.has(p.protocol)) fail('err.protocol');
  if (!transports.has(p.transport)) fail('err.transport');
  if (!p.host || /[\s/\\@?#\x00-\x1f]/.test(p.host) || p.host.length > 253) fail('err.host');
  if (!Number.isInteger(p.port) || p.port < 1 || p.port > 65535) fail('err.port');
  if (['vless', 'vmess'].includes(p.protocol) && !uuid(p.uuid)) fail('err.uuid');
  if (['trojan', 'shadowsocks'].includes(p.protocol) && !p.password) fail('err.password');
  if (p.protocol === 'shadowsocks' && !METHODS.includes(p.method)) fail('err.method');
  if (p.reality && (!p.publicKey || !p.sni)) fail('err.reality');

  p.name = String(p.name || `${p.protocol.toUpperCase()} · ${p.host}`)
    .replace(/[\x00-\x1f]/g, '')
    .slice(0, 160);
  p.tls = bool(p.tls);
  p.insecure = bool(p.insecure);
  p.id = crypto.randomUUID();
  p.favorite = false;
  p.latency = null;
  return p;
}

/* هر خط نامعتبر باید پیام خودمان را بدهد، نه خطای خام URL یا base64. */
function uriProfile(uri) {
  try {
    return uriProfileInner(uri);
  } catch (e) {
    if (String(e?.message || '').startsWith('err.')) throw e;
    fail('err.badLink');
  }
}

function uriProfileInner(uri) {
  if (uri.startsWith('vmess://')) {
    const v = JSON.parse(decode64(uri.slice(8).split('#')[0]));
    return normalize({
      protocol: 'vmess',
      name: v.ps,
      host: v.add,
      port: v.port,
      uuid: v.id,
      alterId: Number(v.aid || 0),
      cipher: v.scy || 'auto',
      transport: v.net || 'tcp',
      path: v.net === 'grpc' ? '' : v.path,
      serviceName: v.net === 'grpc' ? v.path : '',
      wsHost: v.host,
      tls: v.tls === 'tls',
      sni: v.sni || v.host || v.add,
      alpn: v.alpn,
      fingerprint: v.fp,
      insecure: bool(v.insecure)
    });
  }

  if (uri.startsWith('ss://')) {
    const hash = uri.indexOf('#');
    const name = hash < 0 ? '' : decode(uri.slice(hash + 1));
    let address = uri.slice(5, hash < 0 ? undefined : hash);
    let query = '';
    if (address.includes('?')) {
      const i = address.indexOf('?');
      query = address.slice(i + 1);
      address = address.slice(0, i);
    }
    if (!address.includes('@')) address = decode64(address);
    const i = address.lastIndexOf('@');
    let auth = address.slice(0, i);
    if (!auth.includes(':')) auth = decode64(auth);
    auth = decode(auth);
    const u = new URL('http://' + address.slice(i + 1));
    const colon = auth.indexOf(':');
    const plugin = new URLSearchParams(query).get('plugin');
    const p = {
      protocol: 'shadowsocks',
      name,
      host: u.hostname,
      port: u.port,
      method: auth.slice(0, colon),
      password: auth.slice(colon + 1)
    };
    if (plugin) {
      const parts = plugin.split(';');
      if (parts[0] !== 'v2ray-plugin') fail('err.plugin');
      const opts = Object.fromEntries(
        parts.slice(1).map((s) => {
          const i = s.indexOf('=');
          return i < 0 ? [s, true] : [s.slice(0, i), s.slice(i + 1)];
        })
      );
      if (opts.mode && opts.mode !== 'websocket') fail('err.pluginMode');
      if (opts.mux && opts.mux !== '0' && opts.mux !== 'false') fail('err.pluginMux');
      Object.assign(p, {
        transport: 'ws',
        wsHost: opts.host,
        path: opts.path || '/',
        tls: bool(opts.tls),
        sni: opts.host
      });
    }
    return normalize(p);
  }

  const u = new URL(uri);
  const q = u.searchParams;
  const protocol = u.protocol.slice(0, -1);
  return normalize({
    protocol,
    name: decode(u.hash.slice(1)),
    host: u.hostname,
    port: u.port,
    uuid: decode(u.username),
    password: decode(u.username),
    transport: q.get('type') || 'tcp',
    path: q.get('path') || '/',
    wsHost: q.get('host') || '',
    serviceName: q.get('serviceName') || '',
    tls: q.get('security') === 'tls',
    reality: q.get('security') === 'reality',
    sni: q.get('sni') || '',
    fingerprint: q.get('fp') || '',
    publicKey: q.get('pbk') || '',
    shortId: q.get('sid') || '',
    flow: q.get('flow') || '',
    alpn: q.get('alpn') || '',
    mode: q.get('mode') || 'auto',
    insecure: bool(q.get('insecure')) || bool(q.get('allowInsecure'))
  });
}

function jsonProfile(v) {
  if (v.protocol && v.host) return normalize(connectionFields(v));
  if (v.server_port) {
    const p = {
      protocol: v.type,
      name: v.tag,
      host: v.server,
      port: v.server_port,
      uuid: v.uuid,
      password: v.password,
      method: v.method,
      cipher: v.security,
      alterId: v.alter_id || 0,
      transport: v.transport?.type || 'tcp',
      path: v.transport?.path,
      wsHost: v.transport?.headers?.Host || v.transport?.host,
      serviceName: v.transport?.service_name,
      tls: v.tls?.enabled,
      sni: v.tls?.server_name,
      alpn: v.tls?.alpn?.join(','),
      insecure: v.tls?.insecure,
      fingerprint: v.tls?.utls?.fingerprint,
      reality: v.tls?.reality?.enabled,
      publicKey: v.tls?.reality?.public_key,
      shortId: v.tls?.reality?.short_id,
      flow: v.flow
    };
    if (v.plugin) {
      if (v.plugin !== 'v2ray-plugin') fail('err.plugin');
      const options = Object.fromEntries(
        String(v.plugin_opts || '')
          .split(';')
          .map((s) => {
            const i = s.indexOf('=');
            return i < 0 ? [s, true] : [s.slice(0, i), s.slice(i + 1)];
          })
      );
      if (options.mode && options.mode !== 'websocket') fail('err.pluginMode');
      if (options.mux && options.mux !== '0' && options.mux !== 'false') fail('err.pluginMux');
      Object.assign(p, {
        transport: 'ws',
        path: options.path || '/',
        wsHost: options.host,
        tls: bool(options.tls),
        sni: options.host
      });
    }
    return normalize(p);
  }

  const net = v.network || 'tcp';
  const opts = v['ws-opts'] || {};
  let transport = net;
  let wsHost = opts.headers?.Host;
  let path = opts.path;
  if (v.plugin) {
    if (v.plugin !== 'v2ray-plugin') fail('err.plugin');
    const opt = v['plugin-opts'] || {};
    if (opt.mode && opt.mode !== 'websocket') fail('err.pluginMode');
    if (opt.mux !== undefined && bool(opt.mux)) fail('err.pluginMux');
    transport = 'ws';
    wsHost = opt.host;
    path = opt.path;
  }
  return normalize({
    protocol: v.type,
    name: v.name,
    host: v.server,
    port: v.port,
    uuid: v.uuid,
    password: v.password,
    method: v.cipher,
    cipher: v.cipher,
    alterId: v.alterId || 0,
    transport,
    path,
    wsHost,
    serviceName: v['grpc-opts']?.['grpc-service-name'],
    tls: v.tls || v['plugin-opts']?.tls,
    sni: v.servername || v.sni,
    alpn: v.alpn?.join(','),
    fingerprint: v['client-fingerprint'],
    insecure: v['skip-cert-verify'],
    reality: !!v['reality-opts'],
    publicKey: v['reality-opts']?.['public-key'],
    shortId: v['reality-opts']?.['short-id'],
    flow: v.flow
  });
}

export function parseImport(input, translate) {
  T = typeof translate === 'function' ? translate : passthrough;

  let text = String(input || '')
    .trim()
    .replace(/^﻿/, '');
  if (!text) fail('err.needInput');
  if (text.length > 4 * 1024 * 1024) fail('err.tooBig');

  if (
    !text.startsWith('{') &&
    !text.startsWith('[') &&
    !/^\s*proxies\s*:/m.test(text) &&
    !/^(vless|vmess|trojan|ss):\/\//m.test(text)
  ) {
    try {
      text = decode64(text);
    } catch {
      fail('err.unknownFormat');
    }
  }

  let list;
  if (text.startsWith('{') || text.startsWith('[')) {
    let data;
    try {
      data = JSON.parse(text);
    } catch {
      fail('err.badJson');
    }
    list = (Array.isArray(data) ? data : data.outbounds || data.proxies || [data]).filter(
      (v) => !['selector', 'urltest', 'direct', 'block', 'dns', 'freedom', 'blackhole'].includes(v.type)
    );
  } else if (/^\s*proxies\s*:/m.test(text)) {
    let data;
    try {
      data = parseYaml(text, { maxAliasCount: 25 });
    } catch {
      fail('err.badYaml');
    }
    list = data.proxies;
  }

  const errors = [];
  const profiles = [];
  const add = (v, i, fn) => {
    try {
      profiles.push(fn(v));
    } catch (e) {
      errors.push({ line: i + 1, message: e.message });
    }
  };

  if (list) list.forEach((v, i) => add(v, i, jsonProfile));
  else {
    text
      .split(/\r?\n/)
      .filter((s) => s.trim() && !s.trim().startsWith('#'))
      .forEach((s, i) => add(s.trim(), i, uriProfile));
  }

  if (!profiles.length) {
    const first = errors[0]?.message;
    if (first) throw new Error(first);
    fail('err.noneFound');
  }

  const seen = new Set();
  return {
    profiles: profiles.filter((p) => {
      const key = profileKey(p);
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    }),
    errors
  };
}

export function profileKey(p) {
  return JSON.stringify([
    p.protocol, p.host, p.port, p.uuid, p.password, p.method, p.transport, p.path,
    p.wsHost, p.serviceName, p.tls, p.reality, p.sni, p.publicKey, p.shortId, p.flow,
    p.alpn, p.fingerprint, p.insecure, p.mode, p.cipher, p.alterId
  ]);
}

export function mergeProfiles(old, fresh, sourceId = '') {
  const indexed = new Map(old.filter((p) => (p.sourceId || '') === sourceId).map((p) => [profileKey(p), p]));
  const next = fresh.map((p) => ({
    ...p,
    sourceId,
    ...(indexed.has(profileKey(p))
      ? {
          id: indexed.get(profileKey(p)).id,
          favorite: indexed.get(profileKey(p)).favorite,
          latency: indexed.get(profileKey(p)).latency
        }
      : {})
  }));
  if (sourceId) return [...old.filter((p) => p.sourceId !== sourceId), ...next];
  return [...old, ...next.filter((p) => !indexed.has(profileKey(p)))];
}
