// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
// Synthetic, isolated Linux namespace fixture. No real credentials or Internet.
import fs from 'node:fs';
import https from 'node:https';
import http2 from 'node:http2';
import net from 'node:net';
import { spawn } from 'node:child_process';
import path from 'node:path';
import { gzipSync } from 'node:zlib';
const [folder,core]=process.argv.slice(2);
const tls=https.createServer({ key:fs.readFileSync(path.join(folder,'key.pem')),cert:fs.readFileSync(path.join(folder,'cert.pem')) },(request,response) => {
  if (request.url.startsWith('/dns-query')) {
    const chunks=[];request.on('data',c => chunks.push(c));request.on('end',() => {
      const query=request.method==='GET' ? Buffer.from(new URL(request.url,'https://fixture').searchParams.get('dns'),'base64url') : Buffer.concat(chunks);
      let at=12;const labels=[];while (query[at] && at<query.length) { labels.push(query.subarray(at+1,at+1+query[at]).toString());at+=query[at]+1; }at++;
      const type=query.readUInt16BE(at),question=query.subarray(12,at+4);
      const header=Buffer.from(query.subarray(0,12));header.writeUInt16BE(0x8180,2);header.writeUInt16BE(1,6);header.writeUInt16BE(0,8);header.writeUInt16BE(0,10);
      const transport=labels.join('.')==='transport.fixture';
      const value=type===28 ? Buffer.from(transport ? '20010db8000100000000000000000001' : '20010db8000000000000000000000010','hex') : Buffer.from(transport ? [198,18,0,1] : [203,0,113,10]);
      const answer=Buffer.alloc(12);answer.writeUInt16BE(0xc00c,0);answer.writeUInt16BE(type,2);answer.writeUInt16BE(1,4);answer.writeUInt32BE(60,6);answer.writeUInt16BE(value.length,10);
      response.writeHead(200,{ 'Content-Type':'application/dns-message' });response.end(Buffer.concat([header,question,answer,value]));
    });return;
  }
  if (request.url==='/stream') { response.writeHead(200);let count=0;const timer=setInterval(() => { response.write('packet\n');if (++count>=30) { clearInterval(timer);response.end(); } },100);response.on('close',() => clearInterval(timer));return; }
  if (request.url.startsWith('/subscription-')) {
    const fromProxy=request.socket.remoteAddress==='127.0.0.1';
    if (fromProxy!==(request.url==='/subscription-proxy')) { response.writeHead(403);response.end();return; }
    response.writeHead(200,{ 'Content-Encoding':'gzip','Profile-Title':'Fixture remote subscription' });
    response.end(gzipSync(Buffer.from('synthetic compressed subscription')));return;
  }
  setTimeout(() => { response.writeHead(204);response.end(); },20);
});
tls.listen(24443,'0.0.0.0');
const doh=http2.createSecureServer({ allowHTTP1:true,key:fs.readFileSync(path.join(folder,'key.pem')),cert:fs.readFileSync(path.join(folder,'cert.pem')) },tls.listeners('request')[0]);doh.listen(443,'0.0.0.0');
const stalled=net.createServer(socket => socket.on('error',() => {}));stalled.listen(22541,'0.0.0.0');
const config=path.join(folder,'server.json');
fs.writeFileSync(config,JSON.stringify({ log:{ loglevel:'none' },inbounds:[{ listen:'0.0.0.0',port:22539,protocol:'vless',settings:{ clients:[{ id:'00000000-0000-4000-8000-000000000001' }],decryption:'none' } }],outbounds:[{ protocol:'freedom',settings:{ redirect:'127.0.0.1:24443' } }] }));
const child=spawn(core,['run','-config',config],{ stdio:'ignore' });
fs.writeFileSync(path.join(folder,'server.pid'),String(process.pid));
const stop=() => { child.kill();tls.close();doh.close();stalled.close();process.exit(); };
process.on('SIGTERM',stop);process.on('SIGINT',stop);
child.once('exit',() => process.exit(1));
