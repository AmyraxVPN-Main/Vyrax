// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import { validatePreferences } from './preferences.mjs';
const isIP = value => { try { const host = new URL('http://' + (value.includes(':') ? '[' + value + ']' : value)).hostname; return host.startsWith('[') || /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/.test(host); } catch { return false; } };

export const PROBE_URL = 'https://www.gstatic.com/generate_204';
export function preferences(raw = {}) {
  const input = { ...raw };
  if (!(input.preferencesVersion >= 1)) for (const key of ['autoConnect','autoReconnect','splitTunneling','bypassSites','proxyShare']) input[key] = false;
  const settings = validatePreferences({ mode:'tun', mtu:1280, ...input });
  if (!['proxy','tun'].includes(settings.mode)) throw Error('err.mode');
  if (!Number.isInteger(settings.mtu) || settings.mtu < 1280 || settings.mtu > 1500) throw Error('err.config');
  return settings;
}
export function validate(p) {
  if (!p || !['vless','vmess','trojan','shadowsocks'].includes(p.protocol)) throw Error('err.protocol');
  if (!['tcp','ws','grpc','httpupgrade','xhttp'].includes(p.transport || 'tcp')) throw Error('err.transport');
  if (typeof p.host !== 'string' || !p.host.length || p.host.length > 253 || /[\s/\\@?#\x00-\x1f]/.test(p.host)) throw Error('err.host');
  if (!Number.isInteger(p.port) || p.port < 1 || p.port > 65535) throw Error('err.port');
  if (['vless','vmess'].includes(p.protocol) && !/^[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12}$/i.test(p.uuid || '')) throw Error('err.uuid');
  if (['trojan','shadowsocks'].includes(p.protocol) && !p.password) throw Error('err.password');
  if (p.reality && (!p.publicKey || !p.sni)) throw Error('err.reality');
  for (const key of ['name','password','uuid','path','wsHost','serviceName','sni','publicKey','shortId','flow','fingerprint']) if (String(p[key] || '').length > 4096) throw Error('err.tooLong');
}
export function outbound(p) {
  validate(p);
  const { protocol, host, port } = p;
  let settings;
  if (['vless','vmess'].includes(protocol)) {
    const user = { id:p.uuid, ...(protocol === 'vless' ? { encryption:'none', ...(p.flow ? { flow:p.flow } : {}) } : { security:p.cipher || 'auto', alterId:p.alterId || 0 }) };
    settings = { vnext:[{ address:host, port, users:[user] }] };
  } else settings = { servers:[{ address:host, port, password:p.password, ...(protocol === 'shadowsocks' ? { method:p.method || 'aes-256-gcm' } : {}) }] };
  const network = p.transport || 'tcp';
  const streamSettings = { network, security:p.reality ? 'reality' : p.tls ? 'tls' : 'none', sockopt:{ domainStrategy:'ForceIPv4v6' } };
  if (p.tls) streamSettings.tlsSettings = { serverName:p.sni || host, allowInsecure:!!p.insecure, ...(p.alpn ? { alpn:p.alpn.split(',') } : {}), ...(p.fingerprint ? { fingerprint:p.fingerprint } : {}) };
  if (p.reality) streamSettings.realitySettings = { serverName:p.sni, fingerprint:p.fingerprint || 'chrome', publicKey:p.publicKey, password:p.publicKey, shortId:p.shortId || '' };
  if (network === 'ws') streamSettings.wsSettings = { path:p.path || '/', headers:p.wsHost ? { Host:p.wsHost } : {} };
  if (network === 'grpc') streamSettings.grpcSettings = { serviceName:p.serviceName || '', multiMode:false };
  if (network === 'httpupgrade') streamSettings.httpupgradeSettings = { path:p.path || '/', host:p.wsHost || '' };
  if (network === 'xhttp') streamSettings.xhttpSettings = { path:p.path || '/', host:p.wsHost || '', mode:p.mode || 'auto' };
  return { tag:'proxy', protocol, settings, streamSettings };
}
export const nodeTag = p => 'node-' + Array.from(new TextEncoder().encode(p.id), b => b.toString(16).padStart(2,'0')).join('');
export function catalog(profiles) {
  if (!Array.isArray(profiles) || !profiles.length || profiles.length > 512 || new Set(profiles.map(p => p.id)).size !== profiles.length) throw Error('err.catalog');
  for (const p of profiles) { validate(p);if (typeof p.id !== 'string' || !p.id || p.id.length > 256) throw Error('err.catalog'); }
  return profiles;
}
export function routing(profiles, selectedId, mode, source, settings, revision = 0) {
  catalog(profiles);
  if (!['manual','fastest','balance'].includes(mode)) throw Error('err.selection');
  const scoped = profiles.filter(p => (p.sourceId || '') === source);
  if (!scoped.length) throw Error('err.noSourceServers');
  const selected = scoped.find(p => p.id === selectedId) || [...scoped].sort((a,b) => (a.latency ?? Infinity)-(b.latency ?? Infinity))[0];
  const balancer = `${mode === 'balance' ? 'balance' : 'fast'}-${revision}`;
  const target = mode === 'manual' ? { outboundTag:nodeTag(selected) } : { balancerTag:balancer };
  const rule = fields => ({ type:'field', ...fields });
  const rules = [rule({ inboundTag:['subscription'],outboundTag:'direct' }), rule({ inboundTag:['dns-bootstrap'],outboundTag:'direct' }), rule({ inboundTag:['probe'], ...target }), rule({ port:'53', ...target }), rule({ ip:['127.0.0.0/8','10.0.0.0/8','172.16.0.0/12','192.168.0.0/16','::1/128','fc00::/7'], outboundTag:'direct' })];
  const split = settings.splitTunneling, bypass = settings.bypassSites;
  if (split || bypass) {
    const entries = settings[split ? 'splitAddresses' : 'bypassAddresses'];
    const ip = entries.filter(v => isIP(v.split('/')[0]));
    const domain = entries.filter(v => !isIP(v.split('/')[0])).map(v => 'domain:' + v);
    const choice = split ? target : { outboundTag:'direct' };
    if (ip.length) rules.push(rule({ ip, ...choice }));
    if (domain.length) rules.push(rule({ domain, ...choice }));
  }
  rules.push(rule({ network:'tcp,udp', ...(split ? { outboundTag:'direct' } : target) }));
  return { selected, balancer, config:{ domainStrategy:'AsIs', rules, balancers:[{ tag:balancer, selector:scoped.map(nodeTag), fallbackTag:nodeTag(selected), strategy:{ type:mode === 'balance' ? 'leastLoad' : 'leastPing', ...(mode === 'balance' ? { settings:{ expected:2 } } : {}) } }] } };
}

// One active source is loaded in the memory-limited Packet Tunnel extension.
export function iosRequest(action, args) {
  if (['delay','ping'].includes(action)) return { ...args, outbound:outbound(args.profile) };
  const raw = args.settings || {}, settings = preferences(raw);
  settings.mode = 'tun';settings.proxyShare = false;
  const source = action === 'select' ? args.activeSourceId : raw._source;
  const profiles = (action === 'select' ? args.profiles : raw._catalog || [args.profile]).filter(p => (p.sourceId || '') === (source || ''));
  const selectedId = action === 'select' ? args.selectedId : args.profile.id;
  const mode = (action === 'select' ? args.selectionMode : raw._selection) || 'manual';
  const selected = routing(profiles, selectedId, mode, source || '', settings);
  const config = {
    log:{loglevel:'none'},
    inbounds:[{ tag:'socks', listen:'127.0.0.1', port:10808, protocol:'socks', settings:{auth:'noauth',udp:true}, sniffing:{enabled:true,destOverride:['http','tls','quic'],routeOnly:true}}],
    outbounds:[...profiles.map(p=>({...outbound(p),tag:nodeTag(p)})),{tag:'direct',protocol:'freedom'}],
    routing:selected.config,
    dns:{tag:'dns-bootstrap',queryStrategy:'UseIP',servers:[{address:'https://1.1.1.1/dns-query',timeoutMs:4000},{address:'https://8.8.8.8/dns-query',timeoutMs:4000}]},
    observatory:{subjectSelector:['node-'],probeURL:PROBE_URL,probeInterval:'45s',enableConcurrency:false}
  };
  return { config, settings, profileId:selected.selected.id, selectionMode:mode, activeSourceId:source || '' };
}
