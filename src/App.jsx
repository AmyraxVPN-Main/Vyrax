import React, { useEffect, useMemo, useRef, useState } from 'react';
import Bar from './components/Bar.jsx';
import Tabs from './components/Tabs.jsx';
import AddSheet from './components/AddSheet.jsx';
import SubscriptionSheet from './components/SubscriptionSheet.jsx';
import AboutSheet from './components/AboutSheet.jsx';
import UpdateNotice from './components/UpdateNotice.jsx';
import useUpdates from './lib/useUpdates.js';
import { openProjectLink } from './lib/project.js';
import Home from './screens/Home.jsx';
import Locations from './screens/Locations.jsx';
import Settings from './screens/Settings.jsx';
import Account from './screens/Account.jsx';
import { INITIAL_STATE, DEMO_PROFILES } from './data.js';
import { native, call, subscribe, platform } from './bridge.js';
import { useI18n } from './i18n.jsx';
import { parseImport, mergeProfiles } from './lib/profiles.mjs';
import { needsGeo, countryOf, protoLabel, cleanName } from './lib/geo.js';
import { DEFAULT_THEME } from './lib/themes.js';
import { SurfaceTheme } from './components/Surface.jsx';
import { validatePreferences } from './lib/preferences.mjs';
import { migrateSubscriptions, scopedProfiles, subscriptionUrl, subscriptionName, subscriptionUsage, subscriptionMetadata, needsSubscriptionName, importLocalSubscription, isLocalSubscription, subscriptionContent } from './lib/subscriptions.mjs';

export default function App() {
  const { t } = useI18n();

  const [page, setPage] = useState('home');
  const [profiles, setProfiles] = useState([]);
  const [selectedId, setSelectedId] = useState('');
  const [subscriptions, setSubscriptions] = useState([]);
  const [activeSourceId, setActiveSourceId] = useState('');
  const [selectionMode, setSelectionMode] = useState('manual');
  const [selectionBusy, setSelectionBusy] = useState(false);
  const [subscriptionsOpen, setSubscriptionsOpen] = useState(false);
  const [refreshingId, setRefreshingId] = useState('');
  const [state, setState] = useState(INITIAL_STATE);

  const [adding, setAdding] = useState(false);
  const [loaded, setLoaded] = useState(!native);
  const [aboutOpen, setAboutOpen] = useState(false);
  const updates = useUpdates(loaded);
  const [addError, setAddError] = useState('');
  const [busy, setBusy] = useState(false);
  const [checking, setChecking] = useState(false);
  const [testingIds, setTestingIds] = useState(new Set());
  const [settingsSaving, setSettingsSaving] = useState(false);
  const [toast, setToast] = useState(null);
  /* null یعنی هنوز نپرسیده‌ایم؛ تا آن موقع حالت VPN را «نامعلوم» نشان می‌دهیم
     نه «غیرفعال»، وگرنه ممکن است اشتباه هشدار بدهیم. */
  const [elevated, setElevated] = useState(null);

  const toastTimer = useRef();
  const connectTimer = useRef();
  const watchdog = useRef();
  const pinging = useRef(false);
  const started = useRef(false);
  const attempt = useRef(0);
  const metadataAsked = useRef(new Set());
  const subscriptionRequests = useRef(new Map());

  useEffect(() => {
    if (platform !== 'android') return undefined;
    function back() {
      if (adding) setAdding(false);
      else if (subscriptionsOpen) setSubscriptionsOpen(false);
      else if (aboutOpen) setAboutOpen(false);
      else if (page !== 'home') setPage('home');
      else call('minimize').catch(() => {});
    }
    window.addEventListener('vyrax-back', back);
    return () => window.removeEventListener('vyrax-back', back);
  }, [adding, subscriptionsOpen, aboutOpen, page]);

  function fetchSubscriptionResponse(url) {
    const pending = subscriptionRequests.current.get(url);
    if (pending) return pending;
    const request = (async () => {
      if (native) return await call('subscription', { url });
      const response = await fetch(url);
      if (!response.ok) throw new Error('err.subFailed');
      return { text:await response.text(), userInfo:response.headers.get('subscription-userinfo'), title:response.headers.get('profile-title'), disposition:response.headers.get('content-disposition') };
    })().finally(() => subscriptionRequests.current.delete(url));
    subscriptionRequests.current.set(url, request);
    return request;
  }

  /* کانفیگ‌ها در نسخهٔ بومی از میزبان می‌آیند */
  useEffect(() => {
    if (!native) {
      const migrated = migrateSubscriptions({ profiles:DEMO_PROFILES, selectedId:DEMO_PROFILES[0].id }, t('sub.manual'));
      setProfiles(migrated.profiles);setSubscriptions(migrated.subscriptions);setActiveSourceId(migrated.activeSourceId);
      setSelectedId(DEMO_PROFILES[0].id);
      return undefined;
    }
    let alive = true;
    call('load')
      .then(async (saved) => {
        if (!alive || !saved) return;
        const migrated = migrateSubscriptions(saved, t('sub.manual'));
        // Startup auto-connect reads the native store. Save new source IDs before
        // ready so its selection uses exactly the same groups as the UI.
        if (JSON.stringify(migrated) !== JSON.stringify({ profiles:saved.profiles, subscriptions:saved.subscriptions, activeSourceId:saved.activeSourceId }))
          await call('save', { ...saved, ...migrated });
        if (!alive) return;
        setProfiles(migrated.profiles);setSubscriptions(migrated.subscriptions);setActiveSourceId(migrated.activeSourceId);
        if (['fastest', 'balance'].includes(saved.selectionMode)) setSelectionMode(saved.selectionMode);
        if (saved.selectedId) setSelectedId(saved.selectedId);
        if (saved.settings) setState((s) => ({ ...s, settings: { ...s.settings, ...saved.settings } }));
        setLoaded(true);
        if (!started.current) {
          started.current = true;
          call('ready', {}, { timeout: 240000 }).then(snapshot => {
            if (!alive || !snapshot || platform !== 'android') return;
            if (snapshot.profileId) setSelectedId(snapshot.profileId);
            if (snapshot.selectionMode) setSelectionMode(snapshot.selectionMode);
            const since = Date.parse(snapshot.since);
            setState(current => ({ ...current, connected:snapshot.status === 'connected', connecting:snapshot.status === 'connecting',
              uptime:Number.isFinite(since) ? Math.max(0,Math.floor((Date.now()-since)/1000)) : 0,
              exit:snapshot.exit || null, share:snapshot.share || null }));
          }).catch((e) => flash(t('home.notConnected'), hostError(e)));
        }
      })
      .catch(e => flash(t('sub.error'), hostError(e)));
    /* آیا این پروسه با دسترسی مدیر اجرا شده؟ حالت VPN به آن نیاز دارد. */
    call('status')
      .then((s) => {
        if (alive && s) setElevated(!!s.elevated);
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, []);

  useEffect(() => {
    if (!native || !loaded) return;
    const timer = setTimeout(() => {
      call('save', { profiles, selectedId, subscriptions, activeSourceId, selectionMode, settings: state.settings }).catch(() => {});
    }, 400);
    return () => clearTimeout(timer);
  }, [profiles, selectedId, subscriptions, activeSourceId, selectionMode, state.settings, loaded]);

  // Old releases saved only the hostname. Resolve its title in the background;
  // this updates labels/usage without replacing profiles or changing live routing.
  useEffect(() => {
    if (!native || !loaded) return;
    const pending = subscriptions.filter(sub => {
      const key = `${sub.id}:${sub.url}`;
      if (metadataAsked.current.has(key) || !needsSubscriptionName(sub)) return false;
      metadataAsked.current.add(key);return true;
    });
    if (!pending.length) return;
    const worker = async () => {
      while (pending.length) {
        const sub = pending.shift();
        try {
          const response = await fetchSubscriptionResponse(sub.url);
          const metadata = subscriptionMetadata(response, sub.url, sub.name);
          const usage = subscriptionUsage(response?.userInfo);
          setSubscriptions(current => current.map(item => item.id === sub.id && item.url === sub.url &&
            item.name === sub.name && item.updatedAt === sub.updatedAt ? { ...item, ...metadata, usage:usage || item.usage } : item));
        } catch { /* Keep the saved title and servers when metadata is unavailable. */ }
      }
    };
    void Promise.all(Array.from({ length:Math.min(2, pending.length) }, worker));
  }, [native, loaded, subscriptions]);

  /* کشور دقیق سرورها کارِ میزبان است: دامنه را resolve می‌کند و کشورِ IP را
     از پایگاه دادهٔ آفلاین در می‌آورد. هر میزبان فقط یک بار پرسیده می‌شود. */
  const geoAsked = useRef(new Set());
  useEffect(() => {
    if (!native) return;
    const hosts = [...new Set(profiles.filter(needsGeo).map((p) => p.host))].filter(
      (h) => h && !geoAsked.current.has(h)
    );
    if (!hosts.length) return;
    hosts.forEach((h) => geoAsked.current.add(h));

    let alive = true;
    call('geo', { hosts })
      .then((map) => {
        if (!alive || !map) return;
        setProfiles((old) =>
          old.map((p) => (map[p.host] && map[p.host] !== p.cc ? { ...p, cc: map[p.host] } : p))
        );
      })
      .catch(() => {});
    return () => {
      alive = false;
    };
  }, [profiles]);

  /* تم روی <html> می‌نشیند تا همهٔ متغیرهای CSS عوض شوند */
  useEffect(() => {
    document.documentElement.dataset.theme = state.settings.theme || DEFAULT_THEME;
  }, [state.settings.theme]);

  /* میزبان در هر مرحله و هر تغییر وضعیت خبر می‌دهد؛ وضعیت رابط را از همین
     رویدادها می‌گیریم، نه از فرض خودمان. */
  useEffect(() => {
    if (!native) return undefined;
    return subscribe((data) => {
      if (data.event === 'state') {
        if (data.stage) setState((s) => ({ ...s, stage: data.stage }));
        if (data.status === 'connecting') {
          setState((s) => ({ ...s, connected: false, connecting: true, stage: data.stage || 'stage.start', share: null }));
        }
        if (data.status === 'connected') {
          clearTimeout(watchdog.current);
          if (data.profileId) setSelectedId(data.profileId);
          if (data.selectionMode) setSelectionMode(data.selectionMode);
          setState((s) => ({ ...s, connected: true, connecting: false, stage: '', uptime: data.switched ? s.uptime : 0, activeTargets: data.activeTargets || [], exit: data.exit ?? s.exit, share: data.share || null }));
        } else if (data.status === 'disconnected') {
          clearTimeout(watchdog.current);
          setState((s) => ({ ...s, connected: false, connecting: false, stage: '', share: null }));
          if (data.message) flash(t('home.notConnected'), hostError({ message: data.message }));
        }
      } else if (data.event === 'stats') {
        setState((s) => ({
          ...s,
          up: data.up ?? s.up,
          down: data.down ?? s.down,
          upRate: data.upRate ?? s.upRate,
          downRate: data.downRate ?? s.downRate
        }));
      }
    });
  }, [t]);

  useEffect(
    () => () => {
      clearTimeout(toastTimer.current);
      clearTimeout(connectTimer.current);
      clearTimeout(watchdog.current);
    },
    []
  );

  useEffect(() => {
    if (!state.connected) return;
    const timer = setInterval(() => setState((s) => ({ ...s, uptime: s.uptime + 1 })), 1000);
    return () => clearInterval(timer);
  }, [state.connected]);

  const availableProfiles = useMemo(() => scopedProfiles(profiles, activeSourceId), [profiles, activeSourceId]);
  const server = useMemo(
    () => availableProfiles.find((p) => p.id === selectedId) || availableProfiles[0] || null,
    [availableProfiles, selectedId]
  );

  function flash(title, sub) {
    setToast({ title, sub });
    clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 4200);
  }

  async function openLink(target) {
    try { await openProjectLink(target); }
    catch { flash(t('about.linkError'), ''); }
  }

  /* خطاهای میزبان با کلید می‌آیند (err.*) تا ترجمه شوند */
  const hostError = (e) => {
    const message = String(e?.message || '');
    if (message.startsWith('err.')) return t(message);
    if (message === 'TIMEOUT') return t('err.timeout');
    if (message === 'NO_NATIVE') return t('err.unknown');
    return message || t('err.unknown');
  };

  /* ---------- افزودن کانفیگ ---------- */

  async function absorb(text, name) {
    const result = importLocalSubscription(text, profiles, subscriptions, name, t);
    if (!(await selectRoute(selectionMode, null, result.subscription.id, result.catalog))) return false;
    setProfiles(result.catalog);
    setSubscriptions(old => [...old, result.subscription]);
    if (result.errors.length) {
      flash(
        t('toast.addedSome', { n: result.profiles.length, e: result.errors.length }),
        result.errors[0].message
      );
    } else {
      flash(t('toast.added', { n: result.profiles.length }), '');
    }
    return true;
  }

  async function add(text, name = '') {
    const value = String(text || '').trim();
    setAddError('');
    setBusy(true);
    try {
      /* یک آدرس http تنها یعنی اشتراک */
      if (/^https?:\/\/\S+$/i.test(value)) {
        const url = subscriptionUrl(value);
        const existing = subscriptions.find(s => s.url === url);
        if (!(await loadSubscription(existing || { id: crypto.randomUUID(), url, name: subscriptionName('', url) }, true))) return;
      } else {
        if (!(await absorb(value, name))) return;
      }
      setAdding(false);
    } catch (e) {
      setAddError(hostError(e));
    } finally {
      setBusy(false);
    }
  }

  async function fromClipboard(name) {
    setAddError('');
    try {
      const text = native
        ? await call('clipboard')
        : await navigator.clipboard.readText();
      if (!text) {
        setAddError(t('err.needInput'));
        return;
      }
      setBusy(true);
      await add(text, name);
    } catch (e) {
      setAddError(hostError(e));
      setBusy(false);
    }
  }

  async function fromFile(name) {
    setAddError('');
    if (!native) {
      setAddError(t('err.needInput'));
      return;
    }
    try {
      const text = await call('file');
      if (!text) return;
      setBusy(true);
      await add(text, name);
    } catch (e) {
      setAddError(hostError(e));
      setBusy(false);
    }
  }

  async function remove(profile) {
    if (state.connecting || selectionBusy) return;
    const catalog = profiles.filter(p => p.id !== profile.id);
    const remaining = scopedProfiles(catalog, activeSourceId);
    if (state.connected && (selectionMode !== 'manual' || server?.id === profile.id)) {
      if (remaining.length) { if (!(await selectRoute(selectionMode, remaining.find(p => p.id === selectedId), activeSourceId, catalog))) return; }
      else { if (native) await call('disconnect');setState(s => ({ ...s, connected: false, connecting: false, uptime: 0, share: null })); }
    }
    setProfiles(catalog);if (selectedId === profile.id) setSelectedId(remaining[0]?.id || '');
    flash(t('toast.removed'), cleanName(profile.name));
  }

  function clearAll() {
    attempt.current++;
    clearTimeout(watchdog.current);
    clearTimeout(connectTimer.current);
    if (native) call('disconnect').catch(() => {});
    setProfiles([]);
    setSubscriptions([]);setActiveSourceId('');setSelectionMode('manual');
    setSelectedId('');
    setState((s) => ({ ...s, connected: false, connecting: false, uptime: 0, starIp: false }));
    flash(t('toast.cleared'), '');
  }

  /* ---------- اتصال ---------- */

  function power(nextServer = null) {
    const chosen = nextServer || (selectionMode === 'manual' ? server : [...availableProfiles].sort((a,b)=>(a.latency ?? Infinity)-(b.latency ?? Infinity))[0]) || server;
    if (nextServer && (state.connecting || (state.connected && nextServer.id === server?.id))) return;
    const currentAttempt = ++attempt.current;
    /* لغو: هم دکمه به حالت قبل برگردد، هم میزبان واقعاً متوقف شود */
    if (!nextServer && state.connecting) {
      clearTimeout(watchdog.current);
      clearTimeout(connectTimer.current);
      setState((s) => ({ ...s, connecting: false, stage: '' }));
      if (native) call('disconnect').catch(() => {});
      return;
    }
    if (!nextServer && state.connected) {
      if (native) call('disconnect').catch(() => {});
      setState((s) => ({ ...s, connected: false, uptime: 0 }));
      return;
    }
    if (!chosen) {
      flash(t('toast.needServers'), '');
      setAdding(true);
      return;
    }
    if (nextServer) setSelectedId(nextServer.id);
    if (native) {
      const mode = state.settings.mode || 'proxy';
      setState((s) => ({ ...s, connected: false, connecting: true, stage: 'stage.start', exit:null, up: 0, down: 0, upRate: 0, downRate: 0 }));
      /* اگر میزبان به هر دلیلی پاسخ نداد، رابط نباید روی «در حال اتصال» بماند.
         ولی در حالت VPN کاربر باید با خیال راحت پنجرهٔ UAC را بخواند و تأیید کند:
         مهلتِ کوتاه همان لحظه اتصال را قطع می‌کرد و به نظر می‌رسید «VPN کار
         نمی‌کند». پس آنجا بلندتر است، و مهلتِ لایهٔ گفت‌وگو هم از آن بلندتر. */
      clearTimeout(watchdog.current);
      watchdog.current = setTimeout(
        () => {
          setState((s) => (s.connecting ? { ...s, connecting: false, stage: '' } : s));
          flash(t('home.notConnected'), t('err.timeout'));
          call('disconnect').catch(() => {});
        },
        mode === 'tun' ? 200000 : 45000
      );

      call(
        'connect',
        { profile: chosen, mode, mtu: state.settings.mtu || 1280, settings: { ...state.settings, _catalog: profiles, _selection: selectionMode, _source: activeSourceId } },
        { timeout: mode === 'tun' ? 240000 : 60000 }
      )
        .then((r) => {
          if (currentAttempt !== attempt.current) return;
          clearTimeout(watchdog.current);
          const on = r?.status === 'connected';
          setState((s) => ({
            ...s,
            connected: on,
            connecting: r?.status === 'connecting',
            stage: r?.stage || '',
            uptime: 0,
            exit: r?.exit ?? s.exit,
            share: r?.share || null
          }));
          if (on) flash(t('home.protected'), cleanName(chosen.name));
          /* status === 'disconnected' یعنی خودمان لغو کردیم — بی‌صدا */
        })
        .catch((e) => {
          if (currentAttempt !== attempt.current) return;
          clearTimeout(watchdog.current);
          setState((s) => ({ ...s, connected: false, connecting: false, stage: '' }));
          flash(t('home.notConnected'), hostError(e));
        });
      return;
    }
    setState((s) => ({ ...s, connected: false, connecting: true }));
    connectTimer.current = setTimeout(
      () => setState((s) => ({ ...s, connecting: false, connected: true, uptime: 0 })),
      1500
    );
  }

  /* ---------- تست «تأخیر واقعی» ----------
     URLTest شبیه FlClash: درخواست HEAD و تأخیرِ اتصال گرم از داخل هر سرور.
     هر تست هستهٔ مستقلی دارد؛ سه تست همزمان، با نمایشِ نتیجه به‌محض رسیدن. */

  const DELAY_WORKERS = 3;

  async function pingList(list) {
    if (pinging.current || !list.length) return;
    if (!native) {
      setProfiles((old) =>
        old.map((p) => (list.some((x) => x.id === p.id) ? { ...p, latency: 40 + Math.floor(Math.random() * 120) } : p))
      );
      return;
    }
    pinging.current = true;
    setChecking(true);
    setTestingIds(new Set(list.map((p) => p.id)));
    try {
      const queue = list.slice();
      const answers = [];
      const worker = async () => {
        while (queue.length) {
          const p = queue.shift();
          let latency = null;
          try {
            const r = await call('delay', { profile: p }, { timeout: 20000 });
            if (Number.isFinite(r?.latency) && r.latency > 0) latency = r.latency;
          } catch { /* Failed tests display Timeout. */ }
          answers.push([p.id, latency]);
          setProfiles((old) => old.map((item) => item.id === p.id ? { ...item, latency, tested: true } : item));
          setTestingIds((old) => { const next = new Set(old); next.delete(p.id); return next; });
        }
      };
      await Promise.all(Array.from({ length: DELAY_WORKERS }, worker));

      const reachable = answers.filter(([, v]) => typeof v === 'number').length;
      flash(
        t('loc.checkDone', { n: answers.length }),
        reachable ? '' : t('loc.checkNone')
      );
    } finally {
      pinging.current = false;
      setChecking(false);
      setTestingIds(new Set());
    }
  }

  const pingAll = () => pingList(availableProfiles);
  const pingOne = (profile) => pingList([profile]);

  function star() {
    setState((s) => {
      const next = !s.starIp;
      if (next) flash(t('toast.favSaved'), t('toast.favSavedSub'));
      return { ...s, starIp: next };
    });
  }

  async function changeSettings(patch) {
    setSettingsSaving(true);
    try {
      const next = validatePreferences({ ...state.settings, ...patch });
      if (native) {
        const lists = await call('validateSettings', next);
        Object.assign(next, lists);
        await call('save', { profiles, selectedId, subscriptions, activeSourceId, selectionMode, settings: next });
      }
      const applied = Object.fromEntries(Object.keys(patch).map(key => [key, next[key]]));
      setState((s) => ({ ...s, settings: { ...s.settings, ...applied, preferencesVersion: 1 } }));
    } finally {
      setSettingsSaving(false);
    }
  }

  async function toggleSetting(key) {
    try { await changeSettings({ [key]: !state.settings[key] }); }
    catch (e) { flash(t('set.title'), hostError(e)); }
  }

  const setTheme = (id) => setState((s) => ({ ...s, settings: { ...s.settings, theme: id } }));

  /* حالت اتصال هم داخل همان settings ذخیره می‌شود، پس بار بعد یادش می‌ماند. */
  const setMode = (id) => setState((s) => ({ ...s, settings: { ...s.settings, mode: id } }));

  async function selectRoute(mode, profile, source = activeSourceId, catalog = profiles) {
    if (state.connecting || selectionBusy) return false;
    const list = scopedProfiles(catalog, source);
    const chosen = profile && list.some(p => p.id === profile.id) ? profile : [...list].sort((a, b) => (a.latency ?? Infinity) - (b.latency ?? Infinity))[0];
    if (!chosen) { flash(t('toast.needServers'), ''); return false; }
    setSelectionBusy(true);
    try {
      if (native && state.connected) await call('select', { profiles: catalog, selectedId: chosen.id, selectionMode: mode, activeSourceId: source }, { timeout: 20000 });
      setSelectionMode(mode);setActiveSourceId(source);setSelectedId(chosen.id);
      return true;
    } catch (e) { flash(t('sub.error'), hostError(e)); return false; }
    finally { setSelectionBusy(false); }
  }

  async function pick(profile) {
    if (await selectRoute('manual', profile)) { flash(t('toast.serverPicked'), cleanName(profile.name));setPage('home'); }
  }

  async function loadSubscription(sub, activate = false) {
    const response = await fetchSubscriptionResponse(sub.url);
    const result = parseImport(response?.text ?? response, t);
    if (!result.profiles.length) throw new Error('err.noneFound');
    const catalog = mergeProfiles(profiles, result.profiles, sub.id);
    const updated = { ...sub, ...subscriptionMetadata(response, sub.url, sub.name), usage: subscriptionUsage(response?.userInfo), updatedAt: new Date().toISOString() };
    const shouldActivate = activate || activeSourceId === sub.id;
    if (shouldActivate && !(await selectRoute(selectionMode, catalog.find(p => p.id === selectedId), sub.id, catalog))) return false;
    setProfiles(catalog);setSubscriptions(old => old.some(s => s.id === sub.id) ? old.map(s => s.id === sub.id ? updated : s) : [...old, updated]);
    flash(activate ? t('toast.added', { n:result.profiles.length }) : t('sub.refreshed'), result.errors[0]?.message || (activate ? '' : updated.name));
    return true;
  }

  async function refreshSubscription(sub) {
    if (isLocalSubscription(sub)) return;
    setBusy(true);
    setRefreshingId(sub.id);
    try { await loadSubscription(sub); } catch (e) { flash(t('sub.error'), hostError(e)); }
    finally { setBusy(false);setRefreshingId(''); }
  }

  async function deleteSubscription(sub) {
    setBusy(true);
    try {
      const catalog = profiles.filter(p => p.sourceId !== sub.id);
      if (activeSourceId === sub.id) {
        if (catalog.length) { const next = catalog[0];if (!(await selectRoute(selectionMode, next, next.sourceId || '', catalog))) return; }
        else { if (native) await call('disconnect');setState(s => ({ ...s, connected: false, connecting: false, uptime: 0 }));setSelectedId('');setActiveSourceId('');setSelectionMode('manual'); }
      }
      setProfiles(catalog);setSubscriptions(old => old.filter(s => s.id !== sub.id));
      flash(t('sub.deleted'), sub.name);
    } catch (e) { flash(t('sub.error'), hostError(e)); }
    finally { setBusy(false); }
  }

  async function copySubscription(sub) {
    try { const text = subscriptionContent(sub, profiles);if (native) await call('copy', { text });else await navigator.clipboard.writeText(text);flash(t(isLocalSubscription(sub) ? 'sub.configsCopied' : 'sub.copied'), sub.name); }
    catch (e) { flash(t('sub.error'), hostError(e)); }
  }

  function toggleFavorite(profile) {
    setProfiles((old) =>
      old.map((p) => (p.id === profile.id ? { ...p, favorite: !p.favorite } : p))
    );
  }

  const favorites = profiles.filter((p) => p.favorite).length;
  const savedIp =
    state.starIp && server ? { name: server.name, ip: state.exit || server.host, exit: state.exit } : null;

  /* پرچم‌های شناور دور شماره‌گیر = چند سرور واقعیِ کاربر */
  const orbit = useMemo(
    () => [...availableProfiles].sort((a, b) => Number(!!b.favorite) - Number(!!a.favorite) || (a.latency ?? Infinity) - (b.latency ?? Infinity))
      .slice(0, 4).map((p) => ({ id: p.id, name: cleanName(p.name), cc: countryOf(p), label: protoLabel(p), ms: p.latency })),
    [availableProfiles]
  );

  return (
    <SurfaceTheme.Provider value={state.settings.theme || DEFAULT_THEME}>
    <div className="frame">
      <div className={`shell${updates.notice ? ' has-update' : ''}`}>
        <Bar live={state.connected} />
        <UpdateNotice release={updates.notice} onOpen={() => openLink('release')} onDismiss={updates.dismiss} />

        <main className="screen">
          {page === 'home' && (
            <Home
              state={state}
              server={server}
              orbit={orbit}
              selectionMode={selectionMode}
              onPower={() => power()}
              onQuickPick={(id) => { const profile = availableProfiles.find((p) => p.id === id); if (profile) pick(profile); }}
              onStar={star}
              onPickServer={() => setPage('locations')}
              onAdd={() => setAdding(true)}
            />
          )}

          {page === 'locations' && (
            <Locations
              profiles={availableProfiles}
              selectionMode={selectionMode}
              selectionBusy={selectionBusy || state.connecting}
              onAuto={(mode) => selectRoute(mode, server)}
              sourceName={subscriptions.find(s => s.id === activeSourceId)?.name || t('sub.manual')}
              onSubscriptions={() => setSubscriptionsOpen(true)}
              selectedId={server?.id || ''}
              connectedId={state.connected ? server?.id : ''}
              checking={checking}
              onPick={pick}
              onAdd={() => setAdding(true)}
              onRemove={remove}
              onFavorite={toggleFavorite}
              onCheck={pingAll}
              onPing={pingOne}
              testingIds={testingIds}
              onBack={() => setPage('home')}
            />
          )}

          {page === 'settings' && (
            <Settings
              settings={state.settings}
              favoriteIps={savedIp ? 1 : 0}
              saved={savedIp}
              elevated={elevated}
              onToggle={toggleSetting}
              onChange={changeSettings}
              share={state.connected ? state.share : null}
              connected={state.connected || state.connecting}
              saving={settingsSaving}
              onMode={setMode}
              onUnsave={() => setState((s) => ({ ...s, starIp: false }))}
            />
          )}

          {page === 'account' && (
            <Account
              theme={state.settings.theme || DEFAULT_THEME}
              onTheme={setTheme}
              servers={profiles.length}
              favourites={favorites}
              onClear={clearAll}
              onAbout={() => setAboutOpen(true)}
            />
          )}
        </main>

        <Tabs page={page} onPick={setPage} connected={state.connected} />

        {aboutOpen && <AboutSheet onClose={() => setAboutOpen(false)} onLink={openLink} updates={updates} />}

        {subscriptionsOpen && <SubscriptionSheet subscriptions={subscriptions} profiles={profiles} activeId={activeSourceId}
          onSelect={id => selectRoute(selectionMode, null, id)} onRefresh={refreshSubscription} onDelete={deleteSubscription} onCopy={copySubscription}
          onAdd={() => {setSubscriptionsOpen(false);setAdding(true);}} onClose={() => setSubscriptionsOpen(false)} refreshingId={refreshingId} busy={busy || selectionBusy || state.connecting} />}

        {adding && (
          <AddSheet
            onClose={() => {
              setAdding(false);
              setAddError('');
            }}
            onAdd={add}
            onClipboard={fromClipboard}
            onFile={fromFile}
            busy={busy}
            error={addError}
          />
        )}

        {toast && (
          <div className={`toast${subscriptionsOpen || adding || aboutOpen ? ' over-sheet' : ''}`} role="status">
            <b>{toast.title}</b>
            {toast.sub && <span>{toast.sub}</span>}
          </div>
        )}
      </div>
    </div>
    </SurfaceTheme.Provider>
  );
}
