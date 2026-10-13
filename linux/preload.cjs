// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Amyrax
const { contextBridge, ipcRenderer } = require('electron');
contextBridge.exposeInMainWorld(process.platform==='darwin' ? 'VyraxMac' : 'VyraxLinux', {
  call:(action, args = {}) => ipcRenderer.invoke('vyrax:call', action, args).catch(error => {
    throw new Error(/\berr\.[A-Za-z0-9]+\b/.exec(error.message)?.[0] || 'err.unknown');
  }),
  subscribe:callback => {
    const listener = (_event, data) => callback(data);
    ipcRenderer.on('vyrax:event', listener);
    return () => ipcRenderer.removeListener('vyrax:event', listener);
  }
});
