import http from 'node:http';
import net from 'node:net';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { gzipSync } from 'node:zlib';

// Synthetic emulator fixture only. All host listeners bind to loopback;
// no real profiles, subscription links or OS proxy/VPN settings are used.
const root = fileURLToPath(new URL('../../', import.meta.url));
const corePath = process.env.VYRAX_TEST_XRAY || join(root, 'vendor/xray/xray.exe');
const output = mkdtempSync(join(tmpdir(), 'vyrax-android-fixture-'));
const configPath = join(output, 'xray.json');
writeFileSync(configPath, JSON.stringify({
  log: { loglevel: 'none' },
  inbounds: [{ listen: '127.0.0.1', port: 22539, protocol: 'vless', settings: {
    clients: [{ id: '00000000-0000-4000-8000-000000000001' }], decryption: 'none'
  } }],
  outbounds: [
    { tag: 'fixture', protocol: 'freedom', settings: { redirect: '127.0.0.1:23040' } },
    { tag: 'direct', protocol: 'freedom' }
  ],
  routing: { rules: [
    { type: 'field', domain: ['full:vyrax-fixture.example'], outboundTag: 'fixture' },
    { type: 'field', ip: ['203.0.113.1/32'], outboundTag: 'fixture' },
    { type: 'field', network: 'tcp,udp', outboundTag: 'direct' }
  ] }
}));
const sockets = new Set();
const stalled = net.createServer(socket => {
  sockets.add(socket); socket.on('close', () => sockets.delete(socket)); socket.on('error', () => {});
});
const seen = new WeakSet();
const server = http.createServer((request, response) => {
  if (request.url==='/redirect') { response.writeHead(302,{ Location:'/subscription' });response.end();return; }
  if (request.url==='/subscription') {
    const body=gzipSync(Buffer.from('vless://00000000-0000-4000-8000-000000000001@127.0.0.1:22539#Fixture'));
    response.writeHead(200,{ 'Content-Encoding':'gzip','Content-Length':body.length,'Profile-Title':'base64:VGVzdCBTdWJzY3JpcHRpb24=','Subscription-Userinfo':'upload=1; download=2; total=100' });response.end(body);return;
  }
  if (request.url==='/error') { response.writeHead(503);response.end();return; }
  if (request.url==='/too-big') { response.writeHead(200,{ 'Content-Length':5*1024*1024 });response.end();return; }
  if (request.url==='/warm') {
    const warm=seen.has(request.socket);seen.add(request.socket);
    setTimeout(() => { response.writeHead(204);response.end(); },warm?20:300);return;
  }
  response.writeHead(204);response.end();
});
stalled.listen(22541, '127.0.0.1');
server.listen(23040, '127.0.0.1', () => {
  const core = spawn(corePath, ['run', '-c', configPath], { stdio: 'ignore', windowsHide: true });
  const stop = () => { core.kill(); server.close(); for (const socket of sockets) socket.destroy(); stalled.close(); };
  core.on('error', error => { console.error(`Fixture core failed: ${error.code}`); stop(); process.exitCode = 1; });
  core.on('exit', code => { stop(); process.exitCode = code; });
  process.on('SIGINT', stop); process.on('SIGTERM', stop);
  console.log('Synthetic Android fixture ready on loopback ports 22539, 23040 and 22541.');
});
