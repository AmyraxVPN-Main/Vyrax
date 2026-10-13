// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
import fs from 'node:fs/promises';
import { DesktopProxy } from './desktop-proxy.mjs';
const [pid,root]=process.argv.slice(2);
const identity=async () => (await fs.readFile(`/proc/${Number(pid)}/stat`,'utf8')).split(/\) /)[1].split(' ')[19];
let original;try { original=await identity(); } catch { process.exit(0); }
while (true) {
  await new Promise(resolve => setTimeout(resolve,500));
  try { if (await identity()===original) continue; } catch { /* Owner died. */ }
  try { await new DesktopProxy(root).recover(); } catch { /* Startup also recovers the journal. */ }
  break;
}
