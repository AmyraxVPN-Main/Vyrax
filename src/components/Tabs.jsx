import React from 'react';
import { Home, Globe, Sun, User } from 'lucide-react';
import { MotionSurface as Liquid } from './Surface.jsx';
import { useI18n } from '../i18n.jsx';
import Surface from './Surface.jsx';

const TABS = [
  { id: 'home', Icon: Home },
  { id: 'locations', Icon: Globe },
  { id: 'settings', Icon: Sun },
  { id: 'account', Icon: User }
];

export default function Tabs({ page, onPick, connected }) {
  const { t } = useI18n();
  const index = TABS.findIndex((tab) => tab.id === page);
  return (
    <nav className="tabs" aria-label={t('nav.label')}>
      <Surface className="tabs-liquid" aria-hidden="true">
        <Surface.Item><div className="tabs-track" /></Surface.Item>
      </Surface>
      <Liquid blur={6} contrast={20} fill="var(--accent-fill)" className="tabs-thumb-layer" aria-hidden="true">
        <Liquid.Item effect="move" move={{ springiness: .55, trail: .5, wobble: .55 }}>
          <div className="tabs-thumb" style={{ transform: `translateX(${index * 100}%)` }} />
        </Liquid.Item>
      </Liquid>
      <div className="tabs-row">
        {TABS.map(({ id, Icon }) => (
          <button key={id} type="button" className={`tab ${page === id ? 'on' : ''}`}
            onClick={() => onPick(id)} aria-current={page === id ? 'page' : undefined}>
            <Icon size={19} strokeWidth={1.8} />
            <span>{t(`nav.${id}`)}</span>
            {id === 'home' && connected && <i className="tab-live" />}
          </button>
        ))}
      </div>
    </nav>
  );
}
