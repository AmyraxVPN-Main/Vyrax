// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { xray } from '../config.mjs';
const exec=promisify(execFile),root=await fs.mkdtemp(path.join(os.tmpdir(),'vyrax-core-configs-'));
const core=process.argv[2];if (!core) throw Error('Pass the Linux Xray path');
let count=0;
try {
  for (const protocol of ['vless','vmess','trojan','shadowsocks']) for (const transport of ['tcp','ws','grpc','httpupgrade','xhttp']) {
    const p={ id:'fixture',sourceId:'group',protocol,transport,host:'example.test',port:443,uuid:'00000000-0000-4000-8000-000000000001',password:'synthetic-only',method:'aes-256-gcm',tls:true,sni:'example.test',path:'/fixture',serviceName:'fixture',wsHost:'example.test' };
    const built=xray([p],p.id,'manual','group',{ preferencesVersion:1 },{ socks:19000,http:19001,probe:19002,api:19003,metrics:19004 });
    const file=path.join(root,'fixture.json');await fs.writeFile(file,JSON.stringify(built.config));
    await exec(core,['run','-test','-config',file],{ timeout:8000 });count++;
  }
  const p={ id:'reality',sourceId:'group',protocol:'vless',host:'example.test',port:443,uuid:'00000000-0000-4000-8000-000000000001',reality:true,sni:'example.test',publicKey:'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',shortId:'0123456789abcdef',flow:'xtls-rprx-vision' };
  const file=path.join(root,'reality.json');await fs.writeFile(file,JSON.stringify(xray([p],p.id,'fastest','group',{ preferencesVersion:1 },{ socks:19000,http:19001,probe:19002,api:19003,metrics:19004 }).config));
  await exec(core,['run','-test','-config',file],{ timeout:8000 });count++;
  console.log(`${count} protocol/transport/TLS/Reality configs accepted by the packaged Xray core`);
} finally { await fs.rm(root,{ recursive:true,force:true }); }
