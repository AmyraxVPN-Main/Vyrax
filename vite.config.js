import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  base: './',
  server: { host: '127.0.0.1', port: 5273, strictPort: false },
  build: {
    target: ['chrome83', 'safari16'],
    cssTarget: 'chrome80',
    sourcemap: false,
    outDir: 'dist',
    emptyOutDir: true,
    chunkSizeWarningLimit: 700,
    rollupOptions: {
      output: {
        /* پارسر YAML جدا بسته‌بندی می‌شود؛ فقط هنگام افزودن کانفیگ Clash لازم است */
        manualChunks: { yaml: ['yaml'] }
      }
    }
  }
});
