import React from 'react';
import './lib/compat.mjs';
import { createRoot } from 'react-dom/client';
import './fonts.css';
import '@fontsource/roboto/latin-400.css';
import '@fontsource/roboto/latin-500.css';
import '@fontsource/roboto/latin-700.css';
import './themes.css';
import './styles.css';
import './screens.css';
import './screens2.css';
import './liquid.css';
import './mobile.css';
import { I18nProvider } from './i18n.jsx';
import { platform } from './bridge.js';
import App from './App.jsx';

document.documentElement.dataset.platform = platform;

createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <I18nProvider>
      <App />
    </I18nProvider>
  </React.StrictMode>
);
