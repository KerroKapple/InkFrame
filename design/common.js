// 设计稿共用片段：配色（取自 lib/theme/tokens.dart 的 dark 变体）、字体、样式、提示音合成、通知引擎。
const { svg } = require('./icons.js');

const T = {
  s0: '#141414', s1: '#1A1A1A', s2: '#1D1D1D', s3: '#232323', s4: '#262626', s5: '#2E2E2E',
  bStrong: '#0F0F0F', bSubtle: '#1F1F1F', outline: '#2C2C2C', control: '#3A3A3A', controlStrong: '#3F3F3F', overlayBorder: '#4A4A4A',
  fg1: '#E8E8E8', fg2: '#D6D6D6', fg3: '#C8C8C8', fg4: '#9E9E9E', fg5: '#8A8A8A', fg6: '#6B6B6B',
  accent: '#C9A85B', accentHover: '#D8B96C', onAccent: '#1D1D1D', wash: '#2A2318', washBorder: '#6B5A38',
  success: '#7FB069', danger: '#D25A4A', grid: '#222222', laneDivider: '#2A2A2A', thumb: '#202020',
  sky: '#7CB8E8', teal: '#8FD694', peach: '#E87C9E',
};

const IMG = {
  mountain: '/_blob/46f7f8c86d8097a6645b77161c9a789b',
  wide: '/_blob/c244dcfc60aa58a6c4ed3629b34b2d75',
  thumbMountain: '/_blob/0f59ca087c899ad45ec20cf62645907b',
  thumbWide: '/_blob/7bc119e45191cbc8a4a4e49a9e40097f',
};

const SANS = `'Noto Sans SC', 'Microsoft YaHei UI', 'PingFang SC', sans-serif`;
const MONO = `'JetBrains Mono', Consolas, Menlo, monospace`;

const HELMET = (extra = '') => `<helmet>
<link href="https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;500;700&amp;family=JetBrains+Mono:wght@400;500&amp;display=swap" rel="stylesheet">
<style>
body{margin:0;background:${T.s0}}
a{color:${T.accent}}a:hover{color:${T.accentHover}}
button{font:inherit;color:inherit;background:none;border:0;padding:0;margin:0;cursor:pointer;text-align:left}
button:focus-visible{outline:2px solid ${T.accent};outline-offset:1px}
.hov:hover{background:${T.s5}}
.hovfg:hover{color:${T.fg1}}
.amber:hover{background:${T.accentHover}}
.toast{transition:transform 200ms cubic-bezier(.215,.61,.355,1)}
.toast-in{animation:toastIn 200ms cubic-bezier(.215,.61,.355,1) both}
.toast-out{animation:toastOut 150ms ease-in both}
@keyframes toastIn{from{opacity:0;transform:translateY(16px)}to{opacity:1;transform:none}}
@keyframes toastOut{from{opacity:1;transform:none}to{opacity:0;transform:translateY(8px)}}
.toast .x{opacity:0;transition:opacity 120ms}
.toast:hover .x,.toast:focus-within .x{opacity:1}
.spin{animation:spin 900ms linear infinite;transform-origin:50% 50%}
@keyframes spin{to{transform:rotate(360deg)}}
.pop{animation:popIn 150ms cubic-bezier(.215,.61,.355,1) both}
@keyframes popIn{from{opacity:0;transform:translateY(4px) scale(.98)}to{opacity:1;transform:none}}
@media (prefers-reduced-motion: reduce){.toast-in,.toast-out,.pop{animation-duration:120ms}.toast-in{animation-name:fadeIn}.spin{animation:none}}
@keyframes fadeIn{from{opacity:0}to{opacity:1}}
${extra}
</style>
</helmet>`;

const page = (title, w, h, body, logic, props = {}) => `<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>${title}</title>
<script src="./support.js"></script>
</head>
<body>
<x-dc>
${HELMET()}
${body}
</x-dc>
<script type="text/x-dc" data-dc-script data-props='${JSON.stringify(Object.assign({}, props, { $preview: { width: w, height: h } }))}'>
${logic}
</script>
</body>
</html>
`;

const ic = (id, size = 20, style = '') => svg(id, size, style);

// 下拉小三角（不是图标集成员，只在控件里当装饰）
const caret = (color = T.fg5) => `<svg width="10" height="10" viewBox="0 0 10 10" aria-hidden="true" style="display: block; flex: none"><path d="M2.5 4l2.5 2.5L7.5 4" fill="none" stroke="${color}" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"></path></svg>`;

// ---- 提示音合成：与 tool/sounds 的 Dart 生成器同一套参数（a = 默认双音上行）----
const CHIME_JS = `
  chimeDefs() {
    return {
      a: { len: 760, notes: [[0, 698.46, 0.78, 150, 0, 0], [82, 1046.5, 1.0, 270, 0, 0]] },
      b: { len: 620, notes: [[0, 987.77, 1.0, 175, 740, 28]] },
      c: { len: 820, notes: [[0, 783.99, 0.72, 160, 0, 0], [58, 987.77, 0.82, 180, 0, 0], [116, 1174.66, 1.0, 290, 0, 0]] },
    };
  }
  chimeSamples(name) {
    if (!this.chimeCache) this.chimeCache = {};
    if (this.chimeCache[name]) return this.chimeCache[name];
    const rate = 48000;
    const def = this.chimeDefs()[name];
    const n = Math.round(def.len / 1000 * rate);
    const s = new Float32Array(n);
    const TAU = Math.PI * 2;
    for (const note of def.notes) {
      const start = note[0] / 1000, f = note[1], amp = note[2], decay = note[3] / 1000, g = note[4], gms = note[5] / 1000;
      for (let i = 0; i < n; i++) {
        const t = i / rate - start;
        if (t < 0) continue;
        const env = t < 0.003 ? Math.pow(Math.sin(Math.PI / 2 * t / 0.003), 2) : Math.exp(-(t - 0.003) / decay);
        let ph;
        if (g > 0 && gms > 0) {
          if (t < gms) { const k = (f - g) / gms; ph = TAU * (g * t + 0.5 * k * t * t); }
          else { ph = TAU * (g * gms + 0.5 * (f - g) * gms) + TAU * f * (t - gms); }
        } else { ph = TAU * f * t; }
        const idx = 1.35 * Math.exp(-t / 0.028);
        const body = Math.sin(ph + idx * Math.sin(ph));
        const ping = 0.07 * Math.exp(-t / 0.035) * Math.sin(ph * 2.76);
        s[i] += amp * env * (body + ping);
      }
    }
    const wet = new Float32Array(n);
    const combs = [1427, 1781, 1973, 2099];
    for (const d of combs) {
      const buf = new Float32Array(d); let k = 0, lp = 0;
      for (let i = 0; i < n; i++) { const y = buf[k]; lp = y * 0.65 + lp * 0.35; buf[k] = s[i] + lp * 0.62; k = (k + 1) % d; wet[i] += y / combs.length; }
    }
    for (const d of [241, 83]) {
      const buf = new Float32Array(d); let k = 0;
      for (let i = 0; i < n; i++) { const bo = buf[k]; const x = wet[i]; buf[k] = x + bo * 0.5; k = (k + 1) % d; wet[i] = -x + bo; }
    }
    for (let i = 0; i < n; i++) s[i] += 0.14 * wet[i];
    const fade = Math.round(0.06 * rate);
    for (let i = 0; i < fade; i++) s[n - fade + i] *= 0.5 * (1 + Math.cos(Math.PI * i / fade));
    let peak = 0; for (let i = 0; i < n; i++) peak = Math.max(peak, Math.abs(s[i]));
    for (let i = 0; i < n; i++) s[i] = s[i] / peak * 0.5;
    this.chimeCache[name] = s;
    return s;
  }
  playChime(name) {
    if (!name || name === 'off' || name === 'system' || name === 'custom') return;
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return;
    if (!this.audio) this.audio = new Ctx();
    if (this.audio.state === 'suspended') this.audio.resume();
    const data = this.chimeSamples(name);
    const buf = this.audio.createBuffer(1, data.length, 48000);
    buf.getChannelData(0).set(data);
    const src = this.audio.createBufferSource();
    src.buffer = buf;
    src.connect(this.audio.destination);
    src.start();
  }
`;

// ---- 通知引擎：时长 / 悬停暂停 / 进度原地变完成 / 去重 / 最多露 3 张 ----
const TOAST_ENGINE_JS = `
  toastDuration(kind) {
    const base = { info: 4000, success: 4000, export: 4000, warning: 6000, undo: 8000, error: 0, progress: 0 }[kind];
    const mul = (this.state && this.state.dwell === 'long') ? 2 : 1;
    if (this.state && this.state.dwell === 'never') return 0;
    return base * mul;
  }
  pushToast(t) {
    const seq = (this.state.seq || 0) + 1;
    const total = this.toastDuration(t.kind);
    const item = Object.assign({ id: seq, remaining: total, total: total, progress: 0, leaving: false, leaveMs: 0 }, t);
    let list = this.state.toasts.filter((x) => !(t.dedupe && x.dedupe === t.dedupe));
    list = list.concat([item]);
    const unread = (this.state.unread || 0) + 1;
    const hist = [{ id: seq, kind: t.kind === 'progress' ? 'info' : t.kind, title: t.title, body: t.body, when: '刚刚', thumb: t.thumb || '' }].concat(this.state.history || []).slice(0, 100);
    this.setState({ toasts: list, seq: seq, unread: unread, history: hist });
    if (t.chime) this.chimeNow();
  }
  closeToast(id) {
    this.setState({ toasts: this.state.toasts.map((x) => x.id === id ? Object.assign({}, x, { leaving: true, leaveMs: 160 }) : x) });
  }
  tickToasts() {
    let changed = false, chime = false;
    const next = [];
    for (const t of this.state.toasts) {
      if (t.leaving) { changed = true; const ms = t.leaveMs - 100; if (ms > 0) next.push(Object.assign({}, t, { leaveMs: ms })); continue; }
      if (t.kind === 'progress') {
        const p = Math.min(100, t.progress + t.rate);
        changed = true;
        if (p >= 100) {
          const total = this.toastDuration('success');
          next.push(Object.assign({}, t, t.done, { kind: 'success', progress: 100, remaining: total, total: total }));
          if (t.done && t.done.chime) chime = true;
        } else { next.push(Object.assign({}, t, { progress: p })); }
        continue;
      }
      if (this.state.hover || t.sticky || !(t.total > 0)) { next.push(t); continue; }
      const r = t.remaining - 100;
      changed = true;
      next.push(r <= 0 ? Object.assign({}, t, { leaving: true, leaveMs: 160 }) : Object.assign({}, t, { remaining: r }));
    }
    if (changed) this.setState({ toasts: next });
    if (chime) this.chimeNow();
  }
  toastView() {
    const all = this.state.toasts;
    const live = all.filter((t) => !t.leaving);
    const keep = new Set(live.slice(-3).map((t) => t.id));
    const shown = all.filter((t) => t.leaving || keep.has(t.id));
    const hidden = live.length - Math.min(3, live.length);
    const kindColor = { success: '${T.success}', export: '${T.fg3}', error: '${T.danger}', warning: '${T.accent}', info: '${T.fg4}', progress: '${T.accent}', undo: '${T.fg3}' };
    const items = shown.map((t) => {
      const hasThumb = !!t.thumb;
      const pct = Math.round(t.progress);
      return {
        id: t.id,
        cls: t.leaving ? 'toast toast-out' : 'toast toast-in',
        title: t.title, body: t.body || '', meta: t.meta || '',
        hasBody: !!t.body, hasMeta: !!t.meta,
        hasThumb: hasThumb, noThumb: !hasThumb, thumb: t.thumb || '',
        tileStyle: 'color: ' + kindColor[t.kind],
        isSuccess: t.kind === 'success', isExport: t.kind === 'export', isError: t.kind === 'error',
        isWarning: t.kind === 'warning', isInfo: t.kind === 'info', isProgress: t.kind === 'progress', isUndo: t.kind === 'undo',
        progressBar: 'width: ' + pct + '%',
        progressLabel: pct + '%',
        hasA1: !!t.a1, hasA2: !!t.a2, a1: t.a1 || '', a2: t.a2 || '',
        countdown: (t.total > 0 && !t.sticky && !t.leaving) ? 'width: ' + Math.max(0, Math.round(t.remaining / t.total * 100)) + '%' : 'width: 0',
        showCountdown: t.total > 0 && !t.sticky && !t.leaving && t.kind !== 'progress',
        onA1: () => this.toastAction(t, 1),
        onA2: () => this.toastAction(t, 2),
        onClose: () => this.closeToast(t.id),
      };
    });
    return { items: items, hidden: hidden, hasHidden: hidden > 0, hiddenLabel: '还有 ' + hidden + ' 条 · 查看全部' };
  }
`;

// 一张通知卡（sc-for 里的 t），两块画板共用同一份标记
const TOAST_CARD = `
<div class="{{ t.cls }}" role="status" style="position: relative; width: 360px; box-sizing: border-box; display: flex; gap: 12px; padding: 12px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.45), 0 2px 6px rgba(0,0,0,0.35); overflow: hidden">
  <sc-if value="{{ t.hasThumb }}" hint-placeholder-val="{{ true }}">
    <img src="{{ t.thumb }}" alt="" style="width: 40px; height: 40px; flex: none; object-fit: cover; border-radius: 4px; outline: 1px solid ${T.outline}">
  </sc-if>
  <sc-if value="{{ t.noThumb }}" hint-placeholder-val="{{ false }}">
    <div style="width: 40px; height: 40px; flex: none; border-radius: 4px; background: ${T.s5}; display: flex; align-items: center; justify-content: center; {{ t.tileStyle }}">
      <sc-if value="{{ t.isSuccess }}" hint-placeholder-val="{{ false }}">${ic('success', 20)}</sc-if>
      <sc-if value="{{ t.isExport }}" hint-placeholder-val="{{ false }}">${ic('export', 20)}</sc-if>
      <sc-if value="{{ t.isError }}" hint-placeholder-val="{{ false }}">${ic('error', 20)}</sc-if>
      <sc-if value="{{ t.isWarning }}" hint-placeholder-val="{{ false }}">${ic('warning', 20)}</sc-if>
      <sc-if value="{{ t.isInfo }}" hint-placeholder-val="{{ false }}">${ic('info', 20)}</sc-if>
      <sc-if value="{{ t.isUndo }}" hint-placeholder-val="{{ false }}">${ic('undo', 20)}</sc-if>
      <sc-if value="{{ t.isProgress }}" hint-placeholder-val="{{ false }}"><div class="spin" style="display: flex">${ic('progress', 20)}</div></sc-if>
    </div>
  </sc-if>
  <div style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; padding-right: 16px">
    <div style="font-size: 12px; font-weight: 500; line-height: 1.45; color: ${T.fg1}; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden">{{ t.title }}</div>
    <sc-if value="{{ t.hasBody }}" hint-placeholder-val="{{ true }}">
      <div style="font-size: 11px; line-height: 1.45; color: ${T.fg4}; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden">{{ t.body }}</div>
    </sc-if>
    <sc-if value="{{ t.isProgress }}" hint-placeholder-val="{{ false }}">
      <div style="display: flex; align-items: center; gap: 8px; margin-top: 6px">
        <div style="flex: 1; height: 4px; border-radius: 2px; background: ${T.control}; overflow: hidden"><div style="height: 4px; background: ${T.accent}; {{ t.progressBar }}"></div></div>
        <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg4}; width: 28px; text-align: right">{{ t.progressLabel }}</div>
      </div>
    </sc-if>
    <sc-if value="{{ t.hasMeta }}" hint-placeholder-val="{{ true }}">
      <div style="font-size: 10px; line-height: 1.3; color: ${T.fg5}; margin-top: 2px">{{ t.meta }}</div>
    </sc-if>
    <sc-if value="{{ t.hasA1 }}" hint-placeholder-val="{{ true }}">
      <div style="display: flex; justify-content: flex-end; gap: 8px; margin-top: 8px">
        <sc-if value="{{ t.hasA2 }}" hint-placeholder-val="{{ false }}">
          <button class="hov" type="button" onClick="{{ t.onA2 }}" style="height: 24px; padding: 0 10px; border-radius: 3px; border: 1px solid ${T.controlStrong}; color: ${T.fg2}; font-size: 11px">{{ t.a2 }}</button>
        </sc-if>
        <button class="amber" type="button" onClick="{{ t.onA1 }}" style="height: 24px; padding: 0 10px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 11px; font-weight: 500">{{ t.a1 }}</button>
      </div>
    </sc-if>
  </div>
  <button class="x hov" type="button" aria-label="关闭通知" onClick="{{ t.onClose }}" style="position: absolute; top: 8px; right: 8px; width: 24px; height: 24px; border-radius: 4px; display: flex; align-items: center; justify-content: center; color: ${T.fg4}">${ic('close', 16)}</button>
  <sc-if value="{{ t.showCountdown }}" hint-placeholder-val="{{ false }}">
    <div style="position: absolute; left: 0; right: 0; bottom: 0; height: 2px; background: transparent"><div style="height: 2px; background: ${T.controlStrong}; {{ t.countdown }}"></div></div>
  </sc-if>
</div>`;

// 通知区：右下角，最新的贴角，最多露 3 张；更多的收成一条「还有 N 条」
const TOAST_STACK = (pos) => `
<div onMouseEnter="{{ stackEnter }}" onMouseLeave="{{ stackLeave }}" aria-live="polite" aria-label="通知" style="position: absolute; ${pos}; width: 360px; display: flex; flex-direction: column; justify-content: flex-end; gap: 8px; z-index: 40">
  <sc-if value="{{ tv.hasHidden }}" hint-placeholder-val="{{ false }}">
    <button class="hov" type="button" onClick="{{ openBell }}" style="align-self: flex-end; height: 24px; padding: 0 10px; border-radius: 999px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; color: ${T.fg3}; font-size: 11px">{{ tv.hiddenLabel }}</button>
  </sc-if>
  <sc-for list="{{ tv.items }}" as="t" hint-placeholder-count="2">${TOAST_CARD}
  </sc-for>
</div>`;

module.exports = { T, IMG, SANS, MONO, page, ic, caret, CHIME_JS, TOAST_ENGINE_JS, TOAST_CARD, TOAST_STACK };
