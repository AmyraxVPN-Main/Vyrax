import React, { useEffect, useRef, useState } from 'react';
import { Power as PowerIcon, Zap, Star, Plus } from 'lucide-react';
import { MsTag, Chevron, speedClass } from '../ui.jsx';
import Flag from '../components/Flag.jsx';
import Surface from '../components/Surface.jsx';
import { useI18n } from '../i18n.jsx';
import { countryOf, protoLabel, cleanName } from '../lib/geo.js';
import { platform } from '../bridge.js';

const PICKS = [{ x: -122, y: -16 }, { x: -106, y: 60 }, { x: 106, y: 60 }, { x: 122, y: -16 }];
const isNum = (v) => typeof v === 'number' && Number.isFinite(v);
const fmtUptime = (sec) => {
  const n = Math.max(0, Math.floor(sec));
  return (n >= 3600 ? [Math.floor(n / 3600), Math.floor(n / 60) % 60, n % 60] : [Math.floor(n / 60), n % 60])
    .map((v) => String(v).padStart(2, '0')).join(':');
};
function fmtBytes(n) {
  let value = Number(n) || 0, unit = 0;
  const units = ['B', 'KB', 'MB', 'GB'];
  while (value >= 1024 && unit < units.length - 1) { value /= 1024; unit++; }
  return `${unit && value < 100 ? value.toFixed(1) : Math.round(value)} ${units[unit]}`;
}

export default function Home({ state, server, orbit, selectionMode, onPower, onStar, onPickServer, onQuickPick, onAdd }) {
  const { t } = useI18n();
  const { connected, connecting, stage, uptime, exit, starIp } = state;
  const [quick, setQuick] = useState(false);
  const stageRef = useRef(null);
  useEffect(() => {
    if (platform !== 'android' || !stageRef.current) return undefined;
    const stage = stageRef.current;
    const observer = new ResizeObserver(() => stage.style.setProperty('--hero-midpoint', `${stage.clientHeight / 2}px`));
    observer.observe(stage);return () => observer.disconnect();
  }, []);
  useEffect(() => setQuick(false), [connected, connecting, server?.id]);
  const nearby = (orbit || []).slice(0, 4);
  const shown = isNum(server?.latency) ? server.latency : '--';
  const showDetails = connected && !connecting;

  return (
    <section className={`home ${connecting ? 'state-busy' : connected ? 'state-on' : 'state-off'}`}>
      <div className="home-stage" ref={stageRef}>
      <div className="connection-hero">
      <p className="state-line" role="status">
        {t(connecting ? 'home.connecting' : connected ? 'home.protected' : 'home.notConnected')}
      </p>
      <div className="dial-zone">
        <div className="aura" />
        {/* Use the Windows renderer for this small interactive surface only.
            The tighter filter bounds still include the orbit's spring overshoot. */}
        <Surface liquidOnMobile blur={9} contrast={20} filterPadding={platform === 'android' ? 110 : 170} className="dial-liquid">
          {nearby.map((p, i) => (
            <Surface.Item key={p.id} className="drop-motion" x={47 + (quick ? PICKS[i].x : 0)} y={47 + (quick ? PICKS[i].y : 0)}
              transition="bouncy" delay={quick ? i * 45 : (nearby.length - i) * 30}>
              <button type="button" className={`drop ${quick ? 'out' : ''} ${server?.id === p.id ? 'on' : ''}`}
                tabIndex={quick ? 0 : -1} aria-hidden={!quick} disabled={connecting}
                aria-label={t('home.quickPick', { name: p.name })} title={p.name}
                onClick={() => { setQuick(false); onQuickPick(p.id); }}>
                <Flag cc={p.cc} label={p.label} />
                <i className={`drop-ms ${speedClass(p.ms)}`}>{isNum(p.ms) ? p.ms : '·'}</i>
              </button>
            </Surface.Item>
          ))}
          <Surface.Item className="dial-body" morph={platform === 'android' ? undefined : { shape: true, bounce: .45, contentBlur: 0 }}>
            <button type="button" className="dial" onClick={onPower}
              aria-label={t(connected || connecting ? 'home.disconnect' : 'home.connect')}>
              <span className="dial-ring" /><PowerIcon className="dial-ico" />
            </button>
          </Surface.Item>
          {nearby.length > 0 && (
            <Surface.Item className="quick-motion" x={53} y={158 + (quick ? 6 : 0)} transition="bouncy">
              <button type="button" className={`quick ${quick ? 'open' : ''}`} disabled={connecting} onClick={() => setQuick((v) => !v)}
                aria-expanded={quick} aria-label={t('home.quick')}><Zap size={20} /></button>
            </Surface.Item>
          )}
        </Surface>
      </div>
      <p className="connection-status" role="status">{connecting && stage ? t(stage) : ''}</p>
      </div>
      <div className="connection-details" aria-hidden={!showDetails} inert={!showDetails ? '' : undefined}>
      <div className="readout">
        <div className="ms"><b key={shown}>{shown}</b><i>ms</i></div>
        <p className="readout-sub">{cleanName(server?.name || '') || t('home.protected')}</p>
      </div>
      <div className="chips session">
        <div><b>{fmtUptime(connected ? uptime : 0)}</b><span>{t('home.uptime')}</span></div>
      </div>
        <div className="chips traffic">
          <div><b>↓ {fmtBytes(state.downRate)}/s</b><span>{t('home.download')}</span></div>
          <div><b>↑ {fmtBytes(state.upRate)}/s</b><span>{t('home.upload')}</span></div>
          <div><b>{fmtBytes(state.down + state.up)}</b><span>{t('home.used')}</span></div>
        </div>
      {exit && (
        <div className="ip-line">
          <span>{t('home.exit')} <code title={exit}>{exit}</code></span>
          <button type="button" className={`star ${starIp ? 'on' : ''}`} onClick={onStar}
            aria-pressed={starIp} aria-label={t(starIp ? 'home.starRemove' : 'home.starAdd')}><Star size={14} strokeWidth={1.8} /></button>
        </div>
      )}
      </div>
      </div>
      <Surface className="pill-liquid">
        <Surface.Item morph={{ shape: true, bounce: .35 }}>
          <button type="button" className={`pill ${connected ? 'live' : ''}`} onClick={server ? onPickServer : onAdd}>
            {server ? <>
              <Flag cc={countryOf(server)} label={protoLabel(server)} />
              <span className="pill-text"><b>{selectionMode === 'manual' ? cleanName(server.name) : t(`auto.${selectionMode}`)}</b>{showDetails && <i>{selectionMode === 'manual' ? server.host : cleanName(server.name)}</i>}</span>
              {showDetails && <MsTag value={server.latency} />}<Chevron />
            </> : <>
              <span className="pill-add" aria-hidden="true"><Plus size={15} strokeWidth={2.6} /></span>
              <span className="pill-text"><b>{t('loc.add')}</b><i>{t('loc.noneSub')}</i></span><Chevron />
            </>}
          </button>
        </Surface.Item>
      </Surface>
    </section>
  );
}
