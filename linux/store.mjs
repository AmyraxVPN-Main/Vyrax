// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import fs from 'node:fs/promises';
import path from 'node:path';
import { randomBytes, createCipheriv, createDecipheriv } from 'node:crypto';
import { preferences } from './config.mjs';

export class Store {
  constructor(root, secretStorage) { this.root = root;this.secretStorage = secretStorage;this.queue = Promise.resolve(); }
  async init() {
    await fs.mkdir(this.root, { recursive:true, mode:0o700 });await fs.chmod(this.root,0o700);
    if(this.requireEncryption)return;
    const file = path.join(this.root,'store-key');
    try { this.key = await fs.readFile(file); }
    catch (e) { if (e.code !== 'ENOENT') throw e;this.key = randomBytes(32);await fs.writeFile(file,this.key,{ flag:'wx', mode:0o600 }); }
    if (this.key.length !== 32) throw Error('err.storeRead');
  }
  async load() {
    let bytes;
    try { bytes = await fs.readFile(path.join(this.root,'store.enc')); }
    catch (e) { if (e.code === 'ENOENT') return { profiles:[], subscriptions:[], selectedId:'', activeSourceId:'', selectionMode:'manual', settings:preferences({ theme:'dark', preferencesVersion:1 }) };throw Error('err.storeRead'); }
    try {
      let text;
      if(this.requireEncryption&&bytes[0]!==1)throw Error();
      if (bytes[0] === 1) text = this.secretStorage.decryptString(bytes.subarray(1));
      else if (bytes[0] === 2) { const cipher = createDecipheriv('aes-256-gcm',this.key,bytes.subarray(1,13));cipher.setAuthTag(bytes.subarray(13,29));text = Buffer.concat([cipher.update(bytes.subarray(29)),cipher.final()]).toString(); }
      else throw Error();
      const data = JSON.parse(text);data.settings = preferences(data.settings);return data;
    } catch { throw Error('err.storeRead'); }
  }
  save(data) {
    data = structuredClone(data);data.settings = preferences(data.settings);
    for(const p of data.profiles || [])delete p.proxyPass;
    const text = JSON.stringify(data);if (Buffer.byteLength(text) > 8*1024*1024) throw Error('err.tooBig');
    const write = async () => {
      let bytes;
      const secure=this.secretStorage?.isEncryptionAvailable() && (process.platform!=='linux' || this.secretStorage.getSelectedStorageBackend()!=='basic_text');
      if(this.requireEncryption && !secure)throw Error('err.storeRead');
      if (secure) bytes = Buffer.concat([Buffer.from([1]),this.secretStorage.encryptString(text)]);
      else { const iv = randomBytes(12), cipher = createCipheriv('aes-256-gcm',this.key,iv);const body = Buffer.concat([cipher.update(text),cipher.final()]);bytes = Buffer.concat([Buffer.from([2]),iv,cipher.getAuthTag(),body]); }
      const temporary = path.join(this.root,'store.new');await fs.writeFile(temporary,bytes,{ mode:0o600 });await fs.chmod(temporary,0o600);await fs.rename(temporary,path.join(this.root,'store.enc'));return true;
    };
    const job = this.queue.then(write);this.queue = job.catch(() => {});return job;
  }
}
