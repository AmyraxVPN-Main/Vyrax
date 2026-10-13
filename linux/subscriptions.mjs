// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import { spawn } from 'node:child_process';

// curl already ships with the Linux runtime requirements. Its proxy transport
// keeps DNS and HTTPS CONNECT in the core, outside the app's captured TUN path.
export async function subscriptionThroughCore(address,port,seconds=12) {
  const url=new URL(address);
  if (!['http:','https:'].includes(url.protocol) || url.username || url.password) throw Error('err.subUrl');
  const output=await new Promise((resolve,reject) => {
    const child=spawn('curl',['--config','-','--silent','--show-error','--compressed','--location','--max-redirs','4',
      '--max-time',String(seconds),'--connect-timeout',String(Math.min(4,seconds)),
      '--proto','=http,https','--proto-redir',url.protocol==='https:' ? '=https' : '=http,https',
      '--proxy',`http://127.0.0.1:${port}`,'--noproxy','','--suppress-connect-headers','--dump-header','-','--output','-',
      '--user-agent','Vyrax (Linux; v2ray)'],{ stdio:['pipe','pipe','ignore'] });
    let size=0;const chunks=[];
    const timer=setTimeout(() => { child.kill();reject(Error('err.subFailed')); },(seconds+1)*1000);
    child.stdout.on('data',chunk => {
      size+=chunk.length;
      if (size>4*1024*1024+65536) { child.kill();reject(Error('err.tooBig')); }
      else chunks.push(chunk);
    });
    child.once('error',() => { clearTimeout(timer);reject(Error('err.subFailed')); });
    child.once('close',code => { clearTimeout(timer);code===0 ? resolve(Buffer.concat(chunks)) : reject(Error('err.subFailed')); });
    child.stdin.on('error',() => {});
    // Keep private subscription tokens out of process command lines.
    child.stdin.end(`url = ${JSON.stringify(url.href)}\n`);
  });
  let offset=0,status=0,headers;
  while (output.toString('ascii',offset,offset+5)==='HTTP/') {
    const end=output.indexOf('\r\n\r\n',offset);if (end<0 || end-offset>16384) throw Error('err.subFailed');
    const lines=output.toString('utf8',offset,end).split('\r\n');
    status=Number(lines.shift().split(' ')[1]);headers=new Headers();
    for (const line of lines) { const colon=line.indexOf(':');if (colon>0) headers.append(line.slice(0,colon),line.slice(colon+1).trim()); }
    offset=end+4;if (status>=200 && (status<300 || status>=400)) break;
  }
  if (status!==200) throw Error('err.subFailed');
  if (output.length-offset>4*1024*1024) throw Error('err.tooBig');
  return { text:output.toString('utf8',offset),title:headers.get('profile-title'),userInfo:headers.get('subscription-userinfo'),disposition:headers.get('content-disposition') };
}
