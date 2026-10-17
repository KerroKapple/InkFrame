// 第三批细化画板：左栏第二批 · 状态与流程（1280×H，静态）
// 对应 b2 画板 b2_rail.js（RailScript.dc.html，原标题「左栏第二批：剧本 · 节点库 · 模板 · 帮助」）。
// 每个功能一节：状态条 → 逐步流程（数字徽标编号）→ 边界帧；导航条、帮助两节把流程与边界并成一行。
// 按建议走的决定：RailScript-R5 选 A（「我的模板」应用级，新表 canvas_templates 不带 project_id、不进项目包）。
// 原画板「需要你定」其余未拍板项一律按建议画：R1 B、R2 B、R3 B、R4 A、R6 A、R7 B、R8 A。
// 现状核对：left_rail_state.dart、canvas_left_rail.dart、left_panel_parts.dart、create_menu_model.dart、
// canvas_tool_actions.dart（addNodeFromMenu / addLaneViaDialog）、canvas_snackbars.dart（错误卡 / 撤销卡）、
// canvas_shortcuts.dart（Ctrl \ / ⌘\ 对文本编辑让位）、script_import_dialog.dart、script_import_controller.dart、
// canvas_bootstrap_controller.dart、about_section.dart + update_check_controller.dart、process_url_opener_service.dart。
const { T, IMG, SANS, MONO, page, ic } = require('./common.js');

const W = 1280;
const PAD = 24;
const INNER = W - 2 * PAD;
const GAP = 10;
const TOP = 78;

// ---- 小件（从 b2_rail.js 本地复制并缩小）----
const code = (t) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${t}</span>`;
const kbd = (k) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}">${k}</span>`;
const prio = (p) => `<span style="height: 16px; padding: 0 5px; border-radius: 3px; border: 1px solid ${p === 'P1' ? T.washBorder : T.control}; color: ${p === 'P1' ? T.accent : T.fg4}; font-family: ${MONO}; font-size: 10px; display: inline-flex; align-items: center">${p}</span>`;
const badge = (n) => `<span style="flex: none; width: 16px; height: 16px; border-radius: 8px; background: ${T.accent}; color: ${T.onAccent}; font-family: ${MONO}; font-size: 10px; font-weight: 500; display: inline-flex; align-items: center; justify-content: center">${n}</span>`;
const edgeTag = `<span style="flex: none; height: 15px; padding: 0 4px; border-radius: 3px; border: 1px solid ${T.control}; color: ${T.fg5}; font-size: 10px; display: inline-flex; align-items: center">边界</span>`;
const stateTag = `<span style="flex: none; width: 6px; height: 6px; border-radius: 3px; background: ${T.fg6}"></span>`;
const cursor = (x, y) => `<svg width="12" height="14" viewBox="0 0 12 14" aria-hidden="true" style="position: absolute; left: ${x}px; top: ${y}px; z-index: 5"><path d="M1 1l9 6.2-4 .6 2.3 4.6-1.6.8-2.3-4.6L1 11.5z" fill="${T.fg1}" stroke="${T.bStrong}" stroke-width="0.8" stroke-linejoin="round"></path></svg>`;
const spin = (size = 12, color = T.accent) => `<span class="spin" style="display: inline-flex; color: ${color}">${ic('progress', size)}</span>`;
const btn = (label, kind = 'secondary', extra = '') => {
  const st = {
    primary: `background: ${T.accent}; color: ${T.onAccent}; font-weight: 500`,
    secondary: `border: 1px solid ${T.controlStrong}; color: ${T.fg2}`,
    disabled: `border: 1px solid ${T.control}; color: ${T.fg6}; cursor: default`,
    primaryDisabled: `background: ${T.control}; color: ${T.fg5}; cursor: default`,
  }[kind];
  return `<button type="button" style="height: 20px; padding: 0 8px; border-radius: 3px; font-size: 10px; display: inline-flex; align-items: center; justify-content: center; gap: 4px; white-space: nowrap; box-sizing: border-box; ${st}; ${extra}">${label}</button>`;
};
const lines = (n, w = [90, 70, 80, 60]) => Array.from({ length: n }, (_, i) => `<div style="height: 4px; width: ${w[i % w.length]}%; border-radius: 2px; background: ${T.control}; margin: 5px 0"></div>`).join('');

// ---- 版式：帧 / 行 / 节 ----
// 帧 = 1px 边 + 6 内边距 + 标题 16 + 4 + 样稿 mockH + 4 + 说明 capLines×15 + 6 + 1px 边
const TITLE_H = 16;
const CAP_LH = 15;
const frameH = (mockH, capLines) => 2 + 12 + TITLE_H + 4 + mockH + 4 + capLines * CAP_LH;
const frame = (fw, mockH, capLines, f) => {
  const head = f.k === 'flow' ? badge(f.n) : f.k === 'edge' ? edgeTag : stateTag;
  return `
  <div style="width: ${fw}px; height: ${frameH(mockH, capLines)}px; flex: none; box-sizing: border-box; padding: 6px; border-radius: 6px; background: ${T.s3}; border: 1px solid ${T.bStrong}; display: flex; flex-direction: column; gap: 4px; overflow: hidden">
    <div style="height: ${TITLE_H}px; display: flex; align-items: center; gap: 6px; font-size: 11px; font-weight: 500; color: ${T.fg1}; white-space: nowrap; overflow: hidden">${head}<span style="overflow: hidden; text-overflow: ellipsis">${f.t}</span></div>
    <div style="position: relative; height: ${mockH}px; flex: none; border-radius: 4px; background: ${T.s1}; overflow: hidden">${f.m}</div>
    <div style="font-size: 10.5px; line-height: ${CAP_LH}px; height: ${capLines * CAP_LH}px; color: ${T.fg4}; overflow: hidden">${f.c}</div>
  </div>`;
};
const row = (mockH, capLines, frames) => {
  const n = frames.length;
  const fw = Math.floor((INNER - GAP * (n - 1)) / n);
  return {
    h: frameH(mockH, capLines),
    html: `<div style="display: flex; gap: ${GAP}px">${frames.map((f) => frame(fw, mockH, capLines, f)).join('')}</div>`,
    mw: fw - 14,
  };
};
const SEC_HEAD = 22;
const SEC_GAP = 14;
const ROW_GAP = 8;
const section = (title, p, note, rows) => {
  const h = SEC_HEAD + 8 + rows.reduce((a, r) => a + r.h, 0) + ROW_GAP * (rows.length - 1);
  return {
    h,
    html: `
  <div style="height: ${h}px; margin-bottom: ${SEC_GAP}px">
    <div style="height: ${SEC_HEAD}px; display: flex; align-items: center; gap: 8px; margin-bottom: 8px">
      <div style="font-size: 14px; font-weight: 500; color: ${T.fg1}; white-space: nowrap">${title}</div>${prio(p)}
      <div style="flex: 1; min-width: 0; font-size: 11px; color: ${T.fg5}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; text-align: right">${note}</div>
    </div>
    <div style="display: flex; flex-direction: column; gap: ${ROW_GAP}px">${rows.map((r) => r.html).join('')}</div>
  </div>`,
  };
};

// ---- 样稿件 ----
const center = (inner, extra = '') => `<div style="position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; gap: 8px; ${extra}">${inner}</div>`;
const railKey = (id, mode = 'idle', size = 28, dot = false) => {
  const st = {
    idle: `color: ${T.fg4}`,
    hover: `background: ${T.s5}; color: ${T.fg4}`,
    focus: `color: ${T.fg4}; outline: 2px solid ${T.accent}; outline-offset: 1px`,
    active: `background: ${T.wash}; color: ${T.accent}`,
    open: `background: ${T.s5}; color: ${T.fg2}`,
  }[mode];
  return `<div style="position: relative; width: ${size}px; height: ${size}px; flex: none; border-radius: 4px; display: flex; align-items: center; justify-content: center; ${st}">${ic(id, size >= 28 ? 18 : size >= 20 ? 14 : 12)}${dot ? `<div style="position: absolute; right: 4px; top: 4px; width: 6px; height: 6px; border-radius: 3px; background: ${T.accent}"></div>` : ''}</div>`;
};
const keyCap = (label) => `<div style="font-size: 9px; color: ${T.fg6}; text-align: center; margin-top: 3px">${label}</div>`;
const stageBg = `background-color: ${T.s1}; background-image: linear-gradient(${T.grid} 1px, transparent 1px), linear-gradient(90deg, ${T.grid} 1px, transparent 1px); background-size: 14px 14px`;
// 左栏迷你：竖条（键 22）+ 可选面板 + 舞台
const miniRail = ({ active = '', panel = '', panelTitle = '', bottom = false, help = 'idle', helpDot = false, size = 16 }) => {
  const k = (id) => railKey(id, active === id ? 'active' : 'idle', size);
  const top = ['outline', 'script', 'templates'];
  return `
  <div style="position: absolute; inset: 0; display: flex">
    <div style="width: ${size + 8}px; flex: none; box-sizing: border-box; background: ${T.s4}; border-right: 1px solid ${T.bStrong}; display: flex; flex-direction: column; align-items: center; padding: 4px 0; gap: 2px">
      ${top.map(k).join('')}
      <div style="flex: 1"></div>
      ${bottom ? railKey('help', help, size, helpDot) : ''}${railKey('panelToggle', 'idle', size)}
    </div>
    ${panel ? `<div style="width: 64px; flex: none; box-sizing: border-box; background: ${T.s3}; border-right: 1px solid ${T.bStrong}; padding: 0 6px">
      <div style="height: 18px; display: flex; align-items: center; font-size: 10px; color: ${T.fg1}; border-bottom: 1px solid ${T.bSubtle}; margin: 0 -6px 4px; padding: 0 6px">${panelTitle}</div>${panel}
    </div>` : ''}
    <div style="flex: 1; ${stageBg}"></div>
  </div>`;
};
const node = (x, y, w, h, label, o = {}) => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: ${h}px; box-sizing: border-box; border-radius: 3px; background: ${T.s4}; border: 1px ${o.dashed ? 'dashed' : 'solid'} ${o.sel ? T.accent : T.outline}; ${o.ghost ? `opacity: 0.85; box-shadow: 0 6px 18px rgba(0,0,0,0.5)` : ''}; ${o.dim ? 'opacity: 0.35' : ''}; display: flex; align-items: center; gap: 3px; padding: 0 4px; font-size: 9px; color: ${T.fg2}; white-space: nowrap; overflow: hidden">${o.icon ? `<span style="display: flex; color: ${o.sel ? T.accent : T.fg4}">${ic(o.icon, 10)}</span>` : ''}${label}</div>`;
const lane = (y, h, color, label, hi = false) => `<div style="position: absolute; left: 0; right: 0; top: ${y}px; height: ${h}px; background: ${color}; opacity: ${hi ? 0.28 : 0.12}; ${hi ? `outline: 1px solid ${T.accent}` : ''}"></div><div style="position: absolute; left: 4px; top: ${y + 2}px; font-size: 9px; color: ${hi ? T.accent : T.fg5}">${label}</div>`;
const stage = (inner) => `<div style="position: absolute; inset: 0; ${stageBg}">${inner}</div>`;
const toast = (kind, title, action = '', extra = '') => {
  const icon = { success: 'success', error: 'error', undo: 'undo', info: 'info', warning: 'warning' }[kind];
  const color = { success: T.success, error: T.danger, undo: T.fg3, info: T.fg4, warning: T.accent }[kind];
  return `<div style="position: absolute; ${extra || 'left: 6px; right: 6px; bottom: 6px'}; box-sizing: border-box; display: flex; gap: 6px; align-items: center; padding: 5px 6px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 5px; box-shadow: 0 8px 24px rgba(0,0,0,0.45); z-index: 4">
    <div style="width: 20px; height: 20px; flex: none; border-radius: 3px; background: ${T.s5}; color: ${color}; display: flex; align-items: center; justify-content: center">${ic(icon, 13)}</div>
    <div style="flex: 1; min-width: 0; font-size: 10px; line-height: 1.3; color: ${T.fg1}">${title}</div>
    ${action ? `<button type="button" style="flex: none; height: 18px; padding: 0 6px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 10px; font-weight: 500">${action}</button>` : ''}
  </div>`;
};
const mItem = (icon, label, o = {}) => {
  const color = o.disabled ? T.fg6 : o.danger ? T.danger : T.fg2;
  return `<div style="height: 22px; display: flex; align-items: center; gap: 6px; padding: 0 6px; border-radius: 3px; font-size: 10.5px; color: ${color}; ${o.hover ? `background: ${T.s5}` : ''}; white-space: nowrap">
    ${icon ? `<span style="display: flex; color: ${o.disabled ? T.fg6 : o.iconColor || T.fg4}">${icon === 'spin' ? spin(12) : ic(icon, 12)}</span>` : '<span style="width: 12px; flex: none"></span>'}
    <span style="flex: 1; overflow: hidden; text-overflow: ellipsis">${label}</span>${o.right || ''}
  </div>`;
};
const mSep = `<div style="height: 1px; background: ${T.bStrong}; margin: 3px 0"></div>`;
const menu = (inner, pos = 'left: 6px; top: 6px', width = 150) => `<div style="position: absolute; ${pos}; width: ${width}px; box-sizing: border-box; padding: 3px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 5px; box-shadow: 0 12px 32px rgba(0,0,0,0.55); z-index: 3">${inner}</div>`;
const dialog = (title, inner, foot, pos = 'left: 8px; right: 8px; top: 6px; bottom: 6px') => `<div style="position: absolute; ${pos}; box-sizing: border-box; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 5px; box-shadow: 0 12px 32px rgba(0,0,0,0.55); display: flex; flex-direction: column; z-index: 3">
  <div style="height: 20px; flex: none; display: flex; align-items: center; padding: 0 7px; font-size: 10.5px; font-weight: 500; color: ${T.fg1}; border-bottom: 1px solid ${T.bSubtle}">${title}</div>
  <div style="flex: 1; min-height: 0; padding: 4px 7px; overflow: hidden">${inner}</div>
  <div style="height: 26px; flex: none; display: flex; align-items: center; justify-content: flex-end; gap: 5px; padding: 0 7px">${foot}</div>
</div>`;
const field = (text, o = {}) => `<div style="height: 18px; box-sizing: border-box; border-radius: 3px; background: ${T.s2}; border: 1px solid ${o.focus ? T.accent : T.outline}; display: flex; align-items: center; gap: 4px; padding: 0 5px; font-size: 10px; color: ${o.hint ? T.fg6 : T.fg2}; white-space: nowrap; overflow: hidden">${o.icon ? `<span style="display: flex; color: ${T.fg6}">${ic(o.icon, 10)}</span>` : ''}${text}${o.focus ? `<span style="width: 1px; height: 11px; background: ${T.accent}"></span>` : ''}</div>`;
const seg = (a, b, second = false) => `<div style="height: 18px; box-sizing: border-box; border-radius: 3px; background: ${T.s2}; border: 1px solid ${T.outline}; display: flex; padding: 1px; gap: 1px">
  <div style="flex: 1; border-radius: 2px; ${second ? `color: ${T.fg4}` : `background: ${T.s5}; color: ${T.fg1}`}; display: flex; align-items: center; justify-content: center; font-size: 9.5px">${a}</div>
  <div style="flex: 1; border-radius: 2px; ${second ? `background: ${T.s5}; color: ${T.fg1}` : `color: ${T.fg4}`}; display: flex; align-items: center; justify-content: center; font-size: 9.5px">${b}</div>
</div>`;

// ---- 剧本段（照 b2 的 numChip / para 缩小）----
const numChip = (t, kind) => {
  const st = {
    done: `background: ${T.s5}; color: ${T.success}`,
    live: `background: ${T.wash}; color: ${T.accent}`,
    todo: `border: 1px dashed ${T.control}; color: ${T.fg5}`,
    gone: `border: 1px dashed ${T.control}; color: ${T.fg6}; font-family: ${SANS}`,
    fresh: `background: ${T.wash}; color: ${T.accent}; border: 1px solid ${T.washBorder}`,
  }[kind];
  return `<div style="flex: none; min-width: 20px; height: 16px; box-sizing: border-box; padding: 0 4px; border-radius: 3px; font-family: ${MONO}; font-size: 9.5px; display: flex; align-items: center; justify-content: center; ${st}">${t}</div>`;
};
const para = ({ chip, kind, text, meta = '', sub = '', sel = false, hover = false, color = T.fg2, clamp = 2 }) => `
  <div style="position: relative; display: flex; gap: 6px; padding: 5px 7px; align-items: flex-start; ${sel || hover ? `background: ${T.s5}` : ''}">
    ${sel ? `<div style="position: absolute; left: 0; top: 0; bottom: 0; width: 2px; background: ${T.accent}"></div>` : ''}
    ${numChip(chip, kind)}
    <div style="flex: 1; min-width: 0">
      <div style="font-size: 10.5px; color: ${color}; line-height: 1.45; display: -webkit-box; -webkit-line-clamp: ${clamp}; -webkit-box-orient: vertical; overflow: hidden">${text}</div>${sub}
    </div>
    <div style="flex: none; font-family: ${MONO}; font-size: 9.5px; color: ${T.fg5}; line-height: 16px; display: flex; align-items: center; gap: 3px">${meta}</div>
  </div>`;
const subTag = (icon, label, color = T.fg5) => `<div style="display: flex; align-items: center; gap: 3px; margin-top: 1px; font-size: 9.5px; color: ${color}">${icon ? ic(icon, 10) : ''}<span>${label}</span></div>`;
const castChip = (name, n, linked, hi = false) => linked
  ? `<div style="height: 18px; display: inline-flex; align-items: center; gap: 3px; padding: 0 6px 0 2px; border-radius: 9px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 10px"><img src="${IMG.thumbMountain}" alt="" style="width: 14px; height: 14px; border-radius: 7px; object-fit: cover">${name}<span style="font-family: ${MONO}; font-size: 9px; color: ${T.fg5}">${n}</span></div>`
  : `<div style="height: 18px; box-sizing: border-box; display: inline-flex; align-items: center; gap: 3px; padding: 0 6px; border-radius: 9px; border: 1px dashed ${hi ? T.accent : T.control}; color: ${T.fg4}; font-size: 10px; ${hi ? `background: ${T.s5}` : ''}">${name}<span style="font-family: ${MONO}; font-size: 9px; color: ${T.fg6}">${n}</span><span style="color: ${T.fg3}">+</span></div>`;
const panelHead = (title, right = '') => `<div style="height: 22px; display: flex; align-items: center; gap: 6px; padding: 0 7px; border-bottom: 1px solid ${T.bSubtle}; font-size: 10.5px"><span style="color: ${T.fg1}; font-weight: 500">${title}</span><span style="flex: 1"></span>${right}</div>`;
const panel = (inner, bg = T.s3) => `<div style="position: absolute; inset: 0; background: ${bg}">${inner}</div>`;

// ---- 节点库行 ----
const libRow = (icon, label, key = '', o = {}) => `
  <div style="height: 22px; display: flex; align-items: center; gap: 6px; padding: 0 7px; font-size: 10.5px; color: ${T.fg2}; ${o.hover ? `background: ${T.s5}` : ''}; ${o.focus ? `outline: 2px solid ${T.accent}; outline-offset: -2px; border-radius: 3px` : ''}; ${o.dim ? 'opacity: 0.4' : ''}">
    <span style="display: flex; color: ${T.fg4}">${ic(icon, 12)}</span><span style="flex: 1; white-space: nowrap">${label}</span>${key ? kbd(key) : ''}
  </div>`;
const presetRow = (title, meta, warn = '') => `
  <div style="height: 28px; display: flex; align-items: center; gap: 6px; padding: 0 7px">
    <span style="display: flex; color: ${T.fg4}">${ic('videoConfig', 12)}</span>
    <div style="flex: 1; min-width: 0"><div style="font-size: 10.5px; color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</div><div style="font-size: 9px; color: ${T.fg6}">${meta}</div></div>
    ${warn ? `<span style="font-size: 9.5px; color: ${T.accent}; white-space: nowrap">${warn}</span>` : ''}
  </div>`;
const groupHead = (label, count = '') => `<div style="height: 18px; display: flex; align-items: center; gap: 5px; padding: 0 7px; font-size: 9.5px; color: ${T.fg5}"><span>${label}</span><span style="font-family: ${MONO}; color: ${T.fg6}">${count}</span></div>`;
const ghost = (x, y, icon, label) => `<div style="position: absolute; left: ${x}px; top: ${y}px; height: 20px; box-sizing: border-box; border-radius: 3px; background: ${T.s4}; border: 1px solid ${T.accent}; box-shadow: 0 6px 18px rgba(0,0,0,0.5); display: flex; align-items: center; gap: 4px; padding: 0 6px; color: ${T.fg1}; font-size: 9.5px; opacity: 0.92; white-space: nowrap; z-index: 4"><span style="display: flex; color: ${T.accent}">${ic(icon, 11)}</span>${label}</div>`;

// ---- 模板卡 ----
const schematic = (lanes, nodes, w = 48, h = 30) => `
  <div style="position: relative; width: ${w}px; height: ${h}px; flex: none; border-radius: 3px; background: ${T.s1}; outline: 1px solid ${T.outline}; overflow: hidden">
    ${lanes.map(([y, hh, c]) => `<div style="position: absolute; left: 0; right: 0; top: ${y}px; height: ${hh}px; background: ${c}; opacity: 0.16"></div>`).join('')}
    ${nodes.map(([x, y]) => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: 6px; height: 4px; border-radius: 1px; background: ${T.fg5}"></div>`).join('')}
  </div>`;
const L3 = [[0, 10, T.peach], [10, 10, T.sky], [20, 10, T.teal]];
const SCH3 = schematic(L3, [[3, 3], [12, 3], [21, 3], [8, 13], [17, 13], [26, 13], [35, 13], [10, 23], [20, 23]]);
const SCH1 = schematic([], [[8, 13], [21, 13], [34, 13]]);
const tplCard = (name, meta, sch, o = {}) => `
  <div style="margin: 4px 5px; padding: 5px; border-radius: 4px; ${o.hover ? `background: ${T.s5}; outline: 1px solid ${T.control}` : ''}; ${o.focus ? `outline: 2px solid ${T.accent}` : ''}; ${o.fresh ? `outline: 1px solid ${T.washBorder}; background: ${T.wash}` : ''}">
    <div style="display: flex; gap: 7px; align-items: center">
      ${sch}
      <div style="flex: 1; min-width: 0">
        ${o.rename ? field(name, { focus: true }) : `<div style="font-size: 10.5px; color: ${o.hover || o.focus ? T.fg1 : T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${name}</div>`}
        <div style="font-size: 9px; color: ${T.fg5}">${meta}</div>
      </div>
    </div>
    ${o.hover || o.focus ? `<div style="display: flex; gap: 4px; margin-top: 5px">
      ${o.busy ? btn(`${spin(10, T.fg5)}插入中`, 'primaryDisabled', 'flex: 1') : btn('插入当前画布', 'primary', 'flex: 1')}
      ${btn('用它新建画布', o.busy ? 'disabled' : 'secondary', 'flex: 1')}
    </div>
    <div style="font-size: 9px; color: ${T.fg6}; margin-top: 3px">12 节点 · 9 镜 · 3 泳道 · 不含产物</div>` : ''}
  </div>`;

// ==================== 1 导航条键位 ====================
const S1 = section('导航条键位', 'P1', `现状：大纲 / 素材 / 角色三页键 + 快捷键 + 收起（${code('canvas_left_rail.dart')}、${code('left_rail_state.dart')}）；新增 ${code('LeftRailPage.script')} / ${code('templates')} 两键，声明序 = 从上到下`, [
  row(84, 3, [
    { k: 'state', t: '默认 · 悬停 · 聚焦', m: center(`<div>${railKey('script', 'idle')}${keyCap('默认')}</div><div>${railKey('script', 'hover')}${keyCap('悬停')}</div><div>${railKey('script', 'focus')}${keyCap('聚焦')}</div>`), c: '默认 fg4；悬停 s5 底；Tab 聚焦出焦点环，↵ / 空格 = 点一下' },
    { k: 'state', t: '点亮', m: center(`<div>${railKey('script', 'active')}${keyCap('剧本')}</div><div>${railKey('templates', 'active')}${keyCap('模板')}</div>`), c: `面板展开且停在这一页才点亮（${code('isActive')}）：accent 图标 + wash 底` },
    { k: 'state', t: '收起', m: miniRail({}), c: '收起后五个页键都不亮，面板 0 宽；停在哪页照记着，再展开回原页' },
    { k: 'state', t: '没做完的页', m: center(`<div>${railKey('templates', 'idle')}${keyCap('有后端才画')}</div>`), c: '页没有后端就不画键、不画假键；节点库并进模板页顶部（R7 B），不加键' },
    { k: 'flow', n: 1, t: '点「剧本」', m: miniRail({ active: 'script', panelTitle: '剧本', panel: lines(4) }) + cursor(16, 60), c: `停在大纲时点剧本键 = 展开并切到剧本页（${code('tapPage')}）` },
    { k: 'flow', n: 2, t: '再点「剧本」', m: miniRail({}) + cursor(16, 60), c: '点的正是展开着的当前页 = 收起；页仍记作剧本' },
    { k: 'flow', n: 3, t: `Ctrl \\ / ⌘\\`, m: miniRail({ active: 'script', panelTitle: '剧本', panel: lines(4) }) + `<div style="position: absolute; right: 6px; bottom: 6px; height: 16px; padding: 0 5px; border-radius: 3px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; display: flex; align-items: center">${kbd('Ctrl \\')}</div>`, c: `只动开合不换页，展开回到剧本页；与底部收起键同一动作（${code('toggle')}）` },
    { k: 'edge', t: '文本框 · 平台', m: panel(`${panelHead('大纲')}<div style="padding: 6px 7px">${field('雾江', { focus: true, icon: 'search' })}<div style="margin-top: 8px; font-size: 9.5px; color: ${T.fg5}; line-height: 1.5">收起键 tooltip<br>mac「收起  ⌘\\」<br>Windows「收起  Ctrl+\\」</div></div>`), c: '筛选框里打字时 Ctrl \\ 让给文本、不收左栏；tooltip 按平台出键位' },
  ]),
]);

// ==================== 2 剧本面板 ====================
const P01 = { chip: '01', kind: 'done', text: '拂晓。雾江上一叶孤舟，远山隐入雾霭。', meta: '4 秒' };
const P02 = { chip: '02', kind: 'live', text: '江面雾气渐散，渔夫撑船缓缓驶出画面。', meta: `${spin(10)}~5 秒` };
const P03 = { chip: '03', kind: 'todo', text: '老人立于岸边，向舟中招手，渔夫回望。', meta: '~3 秒', color: T.fg3 };
const PDEL = { chip: '已删', kind: 'gone', text: '一只白鹭掠过水面。', meta: '~2 秒', color: T.fg5 };
const S2 = section('剧本面板', 'P1', `新增：${code('script_documents')} + ${code('script_paragraphs')}（v10 迁移）；现状：导入只建镜头链、不落原文（${code('script_import_controller.dart')}），对话框照 ${code('script_import_dialog.dart')}`, [
  row(84, 2, [
    { k: 'state', t: '已生成', m: panel(para(Object.assign({}, P01, { sub: subTag('dirty', '备注已改') }))), c: `镜里有产物；编号走 ${code('sequenceShotNumbers')}，与大纲 / 序列同号` },
    { k: 'state', t: '生成中', m: panel(para(P02)), c: '镜下有运行中的 job：编号琥珀、时长前转圈；~ 表示按字数估' },
    { k: 'state', t: '已删', m: panel(para(Object.assign({}, PDEL, { sub: subTag('', '重建这一镜', T.accent) }))), c: '镜头已软删（nodes.deleted_at）：原文保留，编号换成「已删」' },
    { k: 'state', t: '未生成', m: panel(para(Object.assign({}, P03, { sub: subTag('', '未生成') }))), c: '有镜无产物：虚线编号；时长按中文 4 字/秒、最少 2 秒估' },
    { k: 'state', t: '选中 · 悬停', m: panel(para(Object.assign({}, P01, { sel: true, color: T.fg1 })) + para(Object.assign({}, P03, { hover: true }))), c: '选中 = s5 底 + 左侧 2px 琥珀条；悬停只换 s5 底' },
    { k: 'state', t: '空态', m: panel(`${panelHead('剧本')}<div style="display: flex; flex-direction: column; align-items: center; gap: 5px; padding-top: 8px"><div style="font-size: 9.5px; color: ${T.fg5}">这张画布还没有剧本</div>${btn('导入剧本…', 'primary')}${btn('用镜头备注拼出剧本')}</div>`), c: '画布已有镜头时才出第二个按钮；拼出的段直接对上镜头' },
  ]),
  row(104, 2, [
    { k: 'flow', n: 1, t: '点「导入剧本…」', m: panel(`${panelHead('剧本', `<span style="font-size: 9.5px; color: ${T.fg4}">追加…</span>`)}<div style="display: flex; flex-direction: column; align-items: center; gap: 6px; padding-top: 18px"><div style="font-size: 9.5px; color: ${T.fg5}">这张画布还没有剧本</div>${btn('导入剧本…', 'primary')}</div>`) + cursor(110, 66), c: '空态按钮与头部「追加…」打开同一个导入对话框' },
    { k: 'flow', n: 2, t: '粘贴 · 预览', m: dialog('导入脚本', `<div style="height: 26px; border-radius: 3px; background: ${T.s2}; border: 1px solid ${T.accent}; padding: 2px 4px; box-sizing: border-box">${lines(2)}</div><div style="margin-top: 4px">${seg('空行分段', '每行一镜')}</div><div style="margin-top: 3px; font-size: 9.5px; color: ${T.fg4}">预览 · 4 镜 · ~14 秒</div>`, `${btn('取消')}${btn('创建分镜', 'primary')}`), c: '预览实时重算；切拆分方式立即重拆，空内容时「创建分镜」禁用' },
    { k: 'flow', n: 3, t: '创建中', m: dialog('导入脚本', `<div style="height: 26px; border-radius: 3px; background: ${T.s2}; border: 1px solid ${T.outline}; padding: 2px 4px; box-sizing: border-box; opacity: 0.6">${lines(2)}</div><div style="margin-top: 4px; opacity: 0.6">${seg('空行分段', '每行一镜')}</div><div style="margin-top: 3px; font-size: 9.5px; color: ${T.fg4}">预览 · 4 镜 · ~14 秒</div>`, `${btn('取消', 'disabled')}${btn(`${spin(10, T.fg5)}创建分镜`, 'primaryDisabled')}`), c: '一个事务写镜头 + 段落 + 估时长；期间两个按钮都禁用' },
    { k: 'flow', n: 4, t: '完成', m: panel(`${panelHead('剧本')}${para(Object.assign({}, P01, { chip: '01', kind: 'todo', meta: '~4 秒', clamp: 1 }))}${para(Object.assign({}, P02, { kind: 'todo', meta: '~5 秒', clamp: 1 }))}`) + toast('success', '已添加 4 镜到画布'), c: '关对话框再出成功卡（不响）；新镜接到现有链尾之后' },
    { k: 'flow', n: 5, t: '点段定位', m: `<div style="position: absolute; left: 0; top: 0; bottom: 0; width: 50%">${panel(para(Object.assign({}, P03, { sel: true, color: T.fg1, clamp: 3 })))}</div><div style="position: absolute; right: 0; top: 0; bottom: 0; width: 50%; ${stageBg}">${node(14, 44, 60, 18, '镜头 03', { sel: true, icon: 'shot' })}</div>` + cursor(40, 22), c: `点段 = 单选这一镜并移到视口中心（${code('focusNodeOnCanvas')}）` },
    { k: 'flow', n: 6, t: '画布选中 → 段跟随', m: `<div style="position: absolute; left: 0; top: 0; bottom: 0; width: 50%">${panel(para(Object.assign({}, P01, { clamp: 1 })) + para(Object.assign({}, P02, { sel: true, color: T.fg1, clamp: 2 })))}</div><div style="position: absolute; right: 0; top: 0; bottom: 0; width: 50%; ${stageBg}">${node(8, 20, 50, 18, '镜头 01', { icon: 'shot' })}${node(20, 56, 50, 18, '镜头 02', { sel: true, icon: 'shot' })}</div>` + cursor(150, 62), c: '画布上选中镜头，对应段高亮并滚进视野；多选时各段都亮' },
  ]),
  row(100, 2, [
    { k: 'edge', t: '导入失败', m: dialog('导入脚本', `<div style="height: 26px; border-radius: 3px; background: ${T.s2}; border: 1px solid ${T.outline}; padding: 2px 4px; box-sizing: border-box">${lines(2)}</div>`, `${btn('取消')}${btn('创建分镜', 'primary')}`, 'left: 8px; right: 8px; top: 4px; height: 66px') + toast('error', '脚本导入失败，画布未做改动。'), c: '事务回滚、零残留；对话框留着，粘贴的内容不丢，可再点' },
    { k: 'edge', t: '追加', m: panel(`${para(Object.assign({}, P03, { clamp: 1 }))}${para({ chip: '05', kind: 'fresh', text: '暮色里两人并肩上岸。', meta: '~3 秒', clamp: 1 })}${para({ chip: '06', kind: 'fresh', text: '远景：孤舟系在柳下。', meta: '~2 秒', clamp: 1 })}`), c: '追加的段续编号，新镜接链尾；新段先描一下琥珀边再淡去' },
    { k: 'edge', t: '右键段', m: panel(para(Object.assign({}, P02, { sel: true, clamp: 1 }))) + menu(`${mItem('fit', '定位')}${mItem('run', '用本镜备注生成', { disabled: true, right: `<span style="font-size: 9px; color: ${T.fg6}">生成中</span>` })}${mSep}${mItem('text', '复制原文', { hover: true })}`, 'left: 18px; top: 14px'), c: '走 CanvasMenuPanel；不可用的置灰不隐藏，↑↓ 跳过' },
    { k: 'edge', t: '已删段 · 重建', m: panel(para(Object.assign({}, PDEL, { sel: true, clamp: 1 }))) + menu(`${mItem('fit', '定位', { disabled: true })}${mItem('shot', '重建这一镜', { hover: true })}${mSep}${mItem('text', '复制原文')}`, 'left: 18px; top: 14px'), c: '重建 = 插回原段在链里的位置、前后都接上，单事务' },
    { k: 'edge', t: '角色候选', m: panel(`<div style="padding: 6px 7px"><div style="font-size: 9px; color: ${T.fg5}; margin-bottom: 4px">剧中角色</div><div style="display: flex; gap: 4px">${castChip('渔夫', '2', true)}${castChip('老人', '1', false, true)}</div></div>`) + menu(`${mItem('characters', '新建角色「老人」', { hover: true })}${mItem('link', '关联到已有角色…')}${mItem('close', '忽略')}`, 'left: 40px; top: 24px', 128), c: '实心 = 匹配已有角色名；虚线候选：新建 / 关联 / 忽略（R1 B）' },
    { k: 'edge', t: '复制原文 · 只读', m: panel(para(Object.assign({}, P01, { sub: subTag('dirty', '备注已改') }))) + toast('info', '已复制原文'), c: '走 Flutter 自带 Clipboard；原文只读（R4 A），备注去检查器改' },
  ]),
]);

// ==================== 3 节点库 ====================
const LIB = (o = {}) => `${libRow('imageConfig', '图像配置', 'I', o.a || {})}${libRow('videoConfig', '视频配置', 'G', o.b || {})}${libRow('text', '文本', 'T')}`;
const S3 = section('节点库', 'P2', `新增，在模板页顶部（R7 B）；条目 = ${code('create_menu_model')} 不带上下文的项 + 便签，点击走 ${code('addNodeFromMenu')}；现状：画布上没有拖放，舞台要加 DragTarget`, [
  row(76, 2, [
    { k: 'state', t: '默认', m: panel(LIB()), c: '图标 + 名称 + 单键（CanvasToolKeys）；类型一律叫「镜头」' },
    { k: 'state', t: '悬停 · 聚焦', m: panel(LIB({ a: { hover: true }, b: { focus: true } })), c: '悬停 s5 底；键盘聚焦出焦点环，↵ = 点一下' },
    { k: 'state', t: '拖动中', m: panel(LIB({ a: { dim: true } })) + ghost(70, 30, 'imageConfig', '图像配置'), c: '按下挪过 4px 才算拖；源行变淡，幽灵卡跟手' },
    { k: 'state', t: '搜索无结果', m: panel(`<div style="padding: 6px 7px">${field('便当', { focus: true, icon: 'search' })}</div><div style="text-align: center; font-size: 9.5px; color: ${T.fg5}; margin-top: 8px">没有匹配的节点或预设</div>`), c: '筛选同时作用于节点与「最近用过」两组' },
    { k: 'state', t: '最近用过 · 空', m: panel(`${groupHead('最近用过 · 本项目', '0')}<div style="padding: 4px 7px; font-size: 9.5px; color: ${T.fg6}">本项目还没有生成记录</div>`), c: '组头留着，给一句说明；有记录后最多 5 条' },
    { k: 'state', t: '无 Key 预设', m: panel(`${groupHead('最近用过 · 本项目', '2')}${presetRow('Kling v3 · 16:9 · 5 秒', '2 小时前')}${presetRow('万相 图生视频 · 720P', '3 天前', '无 Key')}`), c: '照列并标「无 Key」；能点能拖，提交时由生成闸拦' },
  ]),
  row(100, 2, [
    { k: 'flow', n: 1, t: '点「图像配置」', m: panel(LIB({ a: { hover: true } })) + cursor(60, 12), c: `点一下 = 工具条 / I 同一条路（${code('addNodeFromMenu')}）` },
    { k: 'flow', n: 2, t: '视口中心建出', m: stage(`${node(52, 38, 76, 22, '图像配置', { sel: true, icon: 'imageConfig' })}<div style="position: absolute; left: 50%; top: 50%; width: 6px; height: 6px; margin: -3px; border-radius: 3px; border: 1px dashed ${T.fg6}"></div>`), c: '视口中心 + 散布；判泳道写 laneId，只单选、不挪相机' },
    { k: 'flow', n: 3, t: '按住拖出', m: `<div style="position: absolute; left: 0; top: 0; bottom: 0; width: 46%">${panel(LIB({ a: { dim: true } }))}</div><div style="position: absolute; right: 0; top: 0; bottom: 0; width: 54%; ${stageBg}"></div>` + ghost(78, 40, 'imageConfig', '图像配置'), c: '按住行拖出面板；幽灵卡带类型图标，越过面板沿进舞台' },
    { k: 'flow', n: 4, t: '拖过泳道', m: stage(`${lane(10, 38, T.peach, '泳道 · 雨夜')}${lane(52, 38, T.sky, '泳道 · 日景', true)}`) + ghost(60, 62, 'imageConfig', '图像配置'), c: `进道 12px 以上目标道高亮（${code('resolveLaneDrop')}，与拖卡片同判据）` },
    { k: 'flow', n: 5, t: '松手', m: stage(`${lane(10, 38, T.peach, '泳道 · 雨夜')}${lane(52, 38, T.sky, '泳道 · 日景')}${node(60, 62, 76, 22, '图像配置', { sel: true, icon: 'imageConfig' })}`), c: '落在松手点，laneId = 该道；新节点单选' },
    { k: 'flow', n: 6, t: '最近用过拖出', m: stage(`${node(30, 34, 120, 32, `<div style="line-height: 1.3"><div>视频配置</div><div style="color: ${T.fg5}">Kling v3 · 16:9 · 5 秒</div></div>`, { sel: true, icon: 'videoConfig' })}`), c: '建配置节点并预填 provider / 比例 / 时长 / 分辨率' },
  ]),
  row(92, 2, [
    { k: 'edge', t: '泳道 · 无选中', m: stage('') + dialog('新建泳道', `${field('泳道 1', { focus: true })}<div style="margin-top: 4px">${field('风格提示词…', { hint: true })}</div>`, `${btn('取消')}${btn('创建', 'primary')}`), c: `没选中时点「泳道」= 开新建泳道框（同 F，${code('addLaneViaDialog')}）` },
    { k: 'edge', t: '泳道 · 有选中', m: stage(`<div style="position: absolute; left: 14px; right: 14px; top: 22px; height: 48px; border-radius: 3px; background: ${T.teal}; opacity: 0.14; outline: 1px dashed ${T.accent}"></div>${node(24, 36, 54, 18, '镜头 01', { sel: true, icon: 'shot' })}${node(92, 36, 54, 18, '镜头 02', { sel: true, icon: 'shot' })}`), c: '有选中 = 包成泳道（同 Ctrl G）；Selection 未落地前只开框' },
    { k: 'edge', t: '泳道 · 拖出', m: stage(`<div style="position: absolute; left: 30px; top: 20px; width: 10px; height: 10px; border-radius: 5px; border: 1px solid ${T.accent}"></div>`) + dialog('新建泳道', `${field('泳道 1', { focus: true })}`, `${btn('取消')}${btn('创建', 'primary')}`, 'left: 42px; right: 8px; top: 26px; bottom: 6px'), c: '拖出泳道 = 在松手点开框，泳道上沿对齐松手点；取消什么都不留' },
    { k: 'edge', t: '取消拖动', m: `<div style="position: absolute; left: 0; top: 0; bottom: 0; width: 46%">${panel(LIB())}</div><div style="position: absolute; right: 0; top: 0; bottom: 0; width: 54%; ${stageBg}"></div>` + ghost(18, 26, 'imageConfig', '图像配置').replace('opacity: 0.92', 'opacity: 0.4') + `<div style="position: absolute; right: 6px; bottom: 6px; height: 16px; padding: 0 5px; border-radius: 3px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; display: flex; align-items: center">${kbd('Esc')}</div>`, c: 'Esc 或拖回面板松手 = 取消，幽灵卡缩回源行，不建节点' },
    { k: 'edge', t: '写库失败', m: stage(node(52, 14, 76, 22, '图像配置', { dashed: true, dim: true, icon: 'imageConfig' })) + toast('error', '添加节点失败'), c: '错误卡不自动消失、等用户关（现状 showCanvasSnack）' },
    { k: 'edge', t: '无 Key 提交', m: stage(`<div style="position: absolute; left: 14px; right: 14px; top: 14px; padding: 6px; box-sizing: border-box; border-radius: 3px; background: ${T.s4}; border: 1px solid ${T.accent}"><div style="font-size: 9.5px; color: ${T.fg2}; margin-bottom: 5px">视频配置 · 万相 图生视频</div><div style="display: flex; gap: 4px; align-items: center">${btn(`${ic('run', 10)}生成`, 'primaryDisabled')}<span style="font-size: 9px; color: ${T.accent}">缺 Key · 去设置</span></div></div>`), c: `没 Key 的预设照建节点，生成按钮由 ${code('generate_gate')} 置灰` },
  ]),
]);

// ==================== 4 模板 ====================
const TPL_HEAD = panelHead('模板', `<span style="font-size: 9.5px; color: ${T.fg4}">存为模板…</span>`);
const S4 = section('模板', 'P2', `新增；内置 = 代码常量，与短剧示例同一套建法（${code('canvas_bootstrap_controller.dart')}，单事务）；我的 = ${code('canvas_templates')}（R5 A 应用级，不进项目包）`, [
  row(92, 2, [
    { k: 'state', t: '默认', m: panel(`${tplCard('三幕短片', '9 镜 · 3 泳道', SCH3)}${tplCard('单镜试拍 · 图生视频', '1 镜 · 图像 → 视频', SCH1)}`), c: '示意图按节点位置缩略、泳道画淡色带，不截图' },
    { k: 'state', t: '悬停展开', m: panel(tplCard('三幕短片', '9 镜 · 3 泳道', SCH3, { hover: true })), c: '悬停展开两个按钮和计数；移开收回' },
    { k: 'state', t: '键盘聚焦', m: panel(tplCard('三幕短片', '9 镜 · 3 泳道', SCH3, { focus: true })), c: 'Tab 聚焦等同悬停展开；↵ = 插入当前画布' },
    { k: 'state', t: '插入中', m: panel(tplCard('三幕短片', '9 镜 · 3 泳道', SCH3, { hover: true, busy: true })), c: '单事务写入；期间两个按钮禁用，别的卡照常可悬停' },
    { k: 'state', t: '我的 · 空态', m: panel(`<div style="padding: 5px 7px">${seg('内置 3', '我的 0', true)}</div><div style="display: flex; flex-direction: column; align-items: center; gap: 5px; margin-top: 8px"><div style="font-size: 9.5px; color: ${T.fg5}">还没有自己的模板</div>${btn('把当前画布存为模板')}</div>`), c: '画布上没有节点时按钮置灰，tooltip「画布上还没有节点」' },
    { k: 'state', t: '改名中', m: panel(`<div style="padding: 5px 7px">${seg('内置 3', '我的 1', true)}</div>${tplCard('雨夜追逐', '4 镜 · 1 泳道', SCH1, { rename: true })}`), c: '右键「改名」就地编辑：↵ 存、Esc 放弃、失焦存；空名不收' },
  ]),
  row(104, 2, [
    { k: 'flow', n: 1, t: '悬停 → 点插入', m: panel(tplCard('三幕短片', '9 镜 · 3 泳道', SCH3, { hover: true })) + cursor(48, 54), c: '「从模板插入…」（Tab 新建菜单 / 工具条更多）也开这一页' },
    { k: 'flow', n: 2, t: '插入完成', m: stage(`${lane(16, 22, T.peach, '')}${lane(38, 22, T.sky, '')}${lane(60, 22, T.teal, '')}${[[20, 20], [56, 20], [92, 20], [36, 42], [72, 42], [108, 42], [144, 42], [44, 64], [80, 64]].map(([x, y]) => node(x, y, 28, 14, '', { sel: true })).join('')}`), c: `新 UUID（照 ${code('import_remapper')}），移到视口中心，选中全部` },
    { k: 'flow', n: 3, t: '撤销卡', m: stage(`${[[20, 14], [56, 14], [92, 14], [36, 34]].map(([x, y]) => node(x, y, 28, 14, '', { sel: true })).join('')}`) + toast('undo', '已插入「三幕短片」· 12 个节点', '撤销'), c: '撤销卡停 8 秒（现状 undo 卡）；undo-stack 落地后 Ctrl Z 同效' },
    { k: 'flow', n: 4, t: '点「存为模板…」', m: stage('') + dialog('存为模板', `${field('雨夜追逐', { focus: true })}<div style="margin-top: 4px">${seg('整张画布', '选中的 4', true)}</div><div style="margin-top: 3px; font-size: 9px; color: ${T.fg6}">存节点、边、泳道与风格词</div>`, `${btn('取消')}${btn('保存', 'primary')}`), c: '有选中时默认「选中的」；不存产物、媒体、角色（R6 A）' },
    { k: 'flow', n: 5, t: '保存 → 我的', m: panel(`<div style="padding: 5px 7px">${seg('内置 3', '我的 2', true)}</div>${tplCard('雨夜追逐', '4 镜 · 1 泳道', SCH1, { fresh: true })}`) + toast('success', '已存为模板「雨夜追逐」'), c: '保存后切到「我的」，新卡排第一并描一下琥珀边' },
    { k: 'flow', n: 6, t: '用它新建画布', m: stage(`<div style="position: absolute; left: 8px; top: 6px; height: 18px; padding: 0 7px; border-radius: 9px; background: ${T.s4}; border: 1px solid ${T.control}; display: flex; align-items: center; gap: 4px; font-size: 9.5px; color: ${T.fg2}">三幕短片 ${ic('more', 10)}</div>${[[30, 40], [66, 40], [102, 40], [48, 62]].map(([x, y]) => node(x, y, 28, 14, '')).join('')}`), c: '建画布 + 插入 + 打开，同一事务；画布名取模板名' },
  ]),
  row(92, 2, [
    { k: 'edge', t: '插入失败', m: panel(tplCard('三幕短片', '9 镜 · 3 泳道', SCH3)) + toast('error', '插入模板失败，画布未做改动。'), c: '事务回滚、零残留；卡片恢复可点' },
    { k: 'edge', t: '撤销之后', m: stage(`${[[20, 14], [56, 14], [92, 14], [36, 34], [72, 34]].map(([x, y]) => node(x, y, 28, 14, '', { dashed: true, dim: true })).join('')}`) + toast('info', '已撤销插入'), c: '撤销 = 软删这批节点 / 边 / 泳道，一步复原；选中清空' },
    { k: 'edge', t: '右键「我的」', m: panel(tplCard('雨夜追逐', '4 镜 · 1 泳道', SCH1)) + menu(`${mItem('text', '改名', { hover: true })}${mSep}${mItem('trash', '删除', { danger: true })}`, 'left: 40px; top: 30px', 110), c: '只有「我的」有右键；内置模板不可改名、不可删' },
    { k: 'edge', t: '删除 → 撤销', m: panel(`<div style="padding: 5px 7px">${seg('内置 3', '我的 1', true)}</div>`) + toast('undo', '已删除模板「雨夜追逐」', '撤销'), c: '软删 + 撤销卡；8 秒内点撤销卡片回到原位' },
    { k: 'edge', t: '换项目仍在（R5 A）', m: panel(`<div style="padding: 5px 7px; font-size: 9.5px; color: ${T.fg5}">项目「江上」→ 项目「雨城」</div><div style="padding: 0 7px">${seg('内置 3', '我的 2', true)}</div>${tplCard('雨夜追逐', '4 镜 · 1 泳道', SCH1)}`), c: '应用级：任何项目都看得到；不进项目包，要分享以后加导出 .json' },
    { k: 'edge', t: '角色记号剥离', m: panel(`<div style="padding: 6px 7px; font-size: 9.5px; line-height: 1.5"><div style="color: ${T.fg5}">存时</div><div style="font-family: ${MONO}; color: ${T.fg3}">@{c_8f2a} 回头望</div><div style="color: ${T.fg5}; margin-top: 3px">插入后</div><div style="font-family: ${MONO}; color: ${T.fg1}">渔夫 回头望</div></div>`), c: `模板不带角色：记号剥成名字；${code('gen_inputs')} 指向模板外的源剥掉` },
  ]),
]);

// ==================== 5 帮助菜单 ====================
const updRow = (inner) => `<div style="position: absolute; left: 4px; right: 4px; top: 50%; transform: translateY(-50%); padding: 3px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 5px">${inner}</div>`;
const HELP_MENU = (hl = '') => `${mItem('info', '新手引导', { hover: hl === 'onb' })}${mItem('projects', '打开示例项目')}${mSep}${mItem('', '用户手册 ↗', { disabled: true, right: `<span style="font-size: 9px; color: ${T.fg6}">缺 URL</span>` })}${mItem('info', '关于 InkFrame')}`; // 样稿只画四项，全表见 b2 画板
const S5 = section('帮助菜单', 'P2', `新增，动作键不开面板（R8 A）；检查更新共用 ${code('UpdateCheckController')}（${code('about_section.dart')}），外链走 ${code('UrlOpenerService')}；各项同时进 ⌘K 动作表`, [
  row(84, 3, [
    { k: 'state', t: '帮助键', m: center(`<div>${railKey('help', 'idle')}${keyCap('默认')}</div><div>${railKey('help', 'hover')}${keyCap('悬停')}</div><div>${railKey('help', 'open')}${keyCap('菜单开')}</div>`), c: '动作键从不点亮（不动 LeftRailState）；菜单开着时 s5 底' },
    { k: 'state', t: '有新版本', m: center(`<div>${railKey('help', 'idle', 28, true)}${keyCap('琥珀点')}</div>`), c: '检查结果有新版本时挂琥珀点；打开菜单看过后仍留着，直到升级' },
    { k: 'state', t: '项 · 悬停 / 置灰', m: updRow(`${mItem('info', '新手引导', { hover: true })}${mItem('', '用户手册 ↗', { disabled: true, right: `<span style="font-size: 9px; color: ${T.fg6}">缺 URL</span>` })}`), c: '没有文档站 URL 的外链灰着、↑↓ 跳过；tooltip 说明缺什么' },
    { k: 'state', t: '检查更新 · 空闲', m: updRow(mItem('', '检查更新…')), c: '还没查过（或启动静默检查被节流跳过）' },
    { k: 'state', t: '正在检查', m: updRow(mItem('spin', '正在检查更新…', { disabled: true })), c: '整行禁用；与关于页按钮同一个 isLoading' },
    { k: 'state', t: '已是最新', m: updRow(mItem('success', '已是最新版本', { iconColor: T.success })), c: '结果共用：关于页手动查过，这里同步显示' },
    { k: 'state', t: '有新版本', m: updRow(mItem('success', '发现新版本 0.9.4', { iconColor: T.accent, hover: true, right: `<span style="font-size: 10px; color: ${T.accent}">下载</span>` })), c: '下载 = 打开发布页（同「查看发布页」）' },
    { k: 'state', t: '检查失败', m: updRow(mItem('error', '检查更新失败', { iconColor: T.danger, right: `<span style="font-size: 10px; color: ${T.accent}">重试</span>` })), c: '手动查失败行内给重试、不弹卡；启动静默检查失败只记日志' },
  ]),
  row(116, 3, [
    { k: 'flow', n: 1, t: '点帮助键', m: miniRail({ size: 18, bottom: true, help: 'open' }) + menu(HELP_MENU(), 'left: 30px; bottom: 4px', 118), c: '菜单锚在帮助键右侧、底边对齐，自下而上展开；点亮的页键不变' },
    { k: 'flow', n: 2, t: '↑↓ 选择', m: miniRail({ size: 18, bottom: true, help: 'open' }) + menu(HELP_MENU('onb'), 'left: 30px; bottom: 4px', 118), c: '↑↓ 移动高亮、跳过置灰项；↵ 或点击执行' },
    { k: 'flow', n: 3, t: '执行 · 新手引导', m: miniRail({ size: 18, bottom: true, help: 'focus' }) + dialog('欢迎使用 InkFrame', `${lines(3)}`, `${btn('下一步', 'primary')}`, 'left: 40px; right: 6px; top: 14px; bottom: 14px'), c: `菜单关、焦点回帮助键；${code('showOnboardingDialog')} 不改 onboardingCompleted` },
    { k: 'flow', n: 4, t: '执行 · 关于', m: `<div style="position: absolute; inset: 6px; display: flex; border-radius: 4px; background: ${T.s3}; border: 1px solid ${T.overlayBorder}; overflow: hidden"><div style="width: 46px; background: ${T.s4}; padding: 4px 3px; font-size: 9px; color: ${T.fg5}; line-height: 1.9">常规<br>API 密钥<br>快捷键<br><span style="color: ${T.accent}">关于</span></div><div style="flex: 1; padding: 5px 6px; font-size: 9px; color: ${T.fg4}; line-height: 1.6">版本 0.9.3<br>${btn('检查更新')}<br>发现新版本 0.9.4</div></div>`, c: '关于 InkFrame = 先置 settingsPageProvider，再开设置浮层的关于页' },
    { k: 'edge', t: 'Esc / 点外面', m: miniRail({ size: 18, bottom: true, help: 'focus' }) + `<div style="position: absolute; right: 6px; bottom: 6px; height: 16px; padding: 0 5px; border-radius: 3px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; display: flex; align-items: center">${kbd('Esc')}</div>`, c: 'Esc / 点外面 / 失焦关菜单；焦点回帮助键，什么都不执行' },
    { k: 'edge', t: '外链打不开', m: stage('') + toast('error', '无法打开发布页', '', 'left: 6px; right: 6px; top: 40px'), c: '错误卡不自动消失；按 dedupeKey 连点几下只留一张' },
    { k: 'edge', t: 'mac / Windows', m: `<div style="padding: 8px; font-size: 9.5px; line-height: 1.7; color: ${T.fg3}"><div><span style="color: ${T.fg5}">macOS</span>  open &lt;url&gt;</div><div><span style="color: ${T.fg5}">Windows</span>  rundll32 url.dll</div><div style="color: ${T.fg5}; margin-top: 4px">诊断包 · 日志目录</div><div>与设置 / 启动失败页同一动作</div></div>`, c: `外链按平台起进程（${code('process_url_opener_service')}）；诊断包 = 设置底部同一动作` },
  ]),
]);

const SECTIONS = [S1, S2, S3, S4, S5];
const CONTENT_H = SECTIONS.reduce((a, s) => a + s.h + SEC_GAP, 0);
const H = TOP + CONTENT_H + 48;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="position: absolute; left: ${PAD}px; top: 20px; right: ${PAD}px">
    <div style="display: flex; align-items: baseline; gap: 14px">
      <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">左栏第二批：剧本 · 节点库 · 模板 · 帮助 · 状态与流程</div>
      <div style="color: ${T.fg4}">每个功能：状态条 → 逐步流程（编号）→ 边界帧</div>
    </div>
    <div style="margin-top: 8px; display: flex; gap: 8px; align-items: center; font-size: 11px; color: ${T.fg4}">
      <span style="height: 18px; padding: 0 6px; border-radius: 3px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; display: inline-flex; align-items: center">按建议走的决定：RailScript-R5 选 A</span>
      <span>「我的模板」应用级，新表 ${code('canvas_templates')} 不带 project_id、不进项目包；其余按原画板建议：R1 B · R2 B · R3 B · R4 A · R6 A · R7 B · R8 A</span>
    </div>
  </div>
  <div style="position: absolute; left: ${PAD}px; right: ${PAD}px; top: ${TOP}px">
    ${SECTIONS.map((s) => s.html).join('')}
  </div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'RailScriptDetail.dc.html', html: page('左栏第二批 · 状态与流程', W, H, body, logic) };
