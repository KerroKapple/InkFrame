// 第三批细化画板：选择与批量编辑 · 状态与流程（1280×H，静态）
// 原板 b2_selection.js（Selection.dc.html）；每个功能 = 状态条 / 逐步流程 / 边界三行。
//
// 决定：Selection-Q6 → C（折叠落库：style_lanes 新列 collapsed，一条前向迁移，编号按合入顺序取下一个空号，计划表记 v12；阻塞项，按建议取）
// 决定：Selection-Q1 → A（框选碰到就算选中）
// 决定：Selection-Q2 → B（已定：整组只看抓住的那张，沿用 resolveCardDrop）
// 决定：Selection-Q3 → B（单选配置节点出精简条，不放生成）
// 决定：Selection-Q4 → 已定（并入 TakesCost 运行对话框，≥2 个确认，单次上限 50）
// 决定：Selection-Q5 → B（Ctrl G / ⌘G 的新泳道插在选区所在那条道之后，不在道里就放末尾）
// 决定：Selection-Q7 → A（点卡修饰键不改：Shift / Ctrl / ⌘ 点卡都是切换）
const { T, IMG, SANS, MONO, page, ic, caret } = require('./common.js');

const W = 1280;
const CW = W - 64;          // 内容宽
const LABEL = 40;           // 行标签列
const FA = CW - LABEL - 10; // 帧区宽
const GAP = 10;
const CAP = 32;             // 说明两行 × 16

// ---------- 小件（照 b2 本地复制 + 缩小版）----------
const kbd = (k) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}">${k}</span>`;
const key = (k, x, y) => `<div style="position: absolute; left: ${x}px; top: ${y}px; height: 15px; padding: 0 4px; border-radius: 3px; background: ${T.s3}; border: 1px solid ${T.control}; font-family: ${MONO}; font-size: 9px; color: ${T.fg2}; display: flex; align-items: center">${k}</div>`;
const stageBg = `background-color: ${T.s1}; background-image: linear-gradient(${T.grid} 1px, transparent 1px), linear-gradient(90deg, ${T.grid} 1px, transparent 1px); background-size: 12px 12px; outline: 1px solid ${T.bSubtle}`;
const plainBg = `background: ${T.s1}; outline: 1px solid ${T.bSubtle}`;
const panelBg = `background: ${T.s3}; outline: 1px solid ${T.bStrong}`;

// 迷你卡：sel 选中 / pre 框中命中 / hov 悬停 / ghost 原位虚线 / dim 不参与
const tc = (x, y, o = {}) => {
  const w = o.w || 36, h = o.h || 22;
  if (o.ghost) return `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: ${h}px; box-sizing: border-box; border-radius: 2px; border: 1px dashed ${T.controlStrong}"></div>`;
  const ol = o.sel ? `1.5px solid ${T.accent}` : o.pre ? `1px solid ${T.accent}` : o.hov ? `1px solid ${T.controlStrong}` : `1px solid ${T.outline}`;
  const inner = o.img ? `<img src="${o.img}" alt="" style="width: 100%; height: 100%; object-fit: cover; display: block">`
    : `<div style="padding: 2px 3px; font-size: 8px; line-height: 1.3; color: ${o.sel ? T.fg2 : T.fg5}; white-space: nowrap; overflow: hidden">${o.t || ''}</div>`;
  return `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: ${h}px; border-radius: 2px; background: ${T.thumb}; outline: ${ol}; overflow: hidden; ${o.dim ? 'opacity: .45;' : ''}">${inner}</div>`;
};
const marq = (x, y, w, h, dashed = false) => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: ${h}px; box-sizing: border-box; border: 1px ${dashed ? 'dashed' : 'solid'} ${T.accent}; background: rgba(201,168,91,0.08); border-radius: 1px; ${dashed ? 'opacity: .55;' : ''}"></div>`;
const chip = (x, y, label) => `<div style="position: absolute; left: ${x}px; top: ${y}px; height: 15px; padding: 0 6px; border-radius: 8px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; color: ${T.fg2}; font-family: ${MONO}; font-size: 9px; display: flex; align-items: center; white-space: nowrap">${label}</div>`;
const cur = (x, y, id = 'select', color = T.fg1) => `<div style="position: absolute; left: ${x}px; top: ${y}px; color: ${color}; display: flex">${ic(id, 13)}</div>`;
const tip = (x, y, label) => `<div style="position: absolute; left: ${x}px; top: ${y}px; height: 16px; padding: 0 6px; border-radius: 3px; background: ${T.s5}; border: 1px solid ${T.overlayBorder}; color: ${T.fg2}; font-size: 9px; display: flex; align-items: center; gap: 4px; white-space: nowrap">${label}</div>`;
const statusStrip = (label) => `<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 13px; background: ${T.s3}; border-top: 1px solid ${T.bStrong}; font-size: 8px; color: ${T.fg4}; display: flex; align-items: center; padding: 0 6px">${label}</div>`;
const ring = (x, y) => `<div style="position: absolute; left: ${x - 6}px; top: ${y - 6}px; width: 12px; height: 12px; box-sizing: border-box; border-radius: 6px; border: 1.5px solid ${T.accent}"></div>`;
const vline = (x, dashed = false) => `<div style="position: absolute; left: ${x}px; top: 0; bottom: 0; width: 0; border-left: 1px ${dashed ? 'dashed' : 'solid'} ${T.accent}; ${dashed ? 'opacity: .5;' : ''}"></div>`;

// 泳道带：横向，tint 用 b2 已有的两种半透明底
const LANE_BG = { sky: 'rgba(124,184,232,0.035)', warm: 'rgba(232,168,124,0.035)' };
const LANE_DOT = { sky: T.sky, warm: T.accent };
const band = (y, h, tint = 'sky', hot = false) => `<div style="position: absolute; left: 0; right: 0; top: ${y}px; height: ${h}px; box-sizing: border-box; border-top: 1px solid ${hot ? T.accent : T.laneDivider}; border-bottom: 1px solid ${hot ? T.accent : T.laneDivider}; background: ${hot ? T.wash : LANE_BG[tint]}"></div>`;
const laneChip = (x, y, label, count, tint = 'sky', extra = '') => `<div style="position: absolute; left: ${x}px; top: ${y}px; height: 15px; display: flex; align-items: center; gap: 4px; padding: 0 5px; border-radius: 3px; background: rgba(38,38,38,0.82); border: 1px solid ${T.outline}; font-size: 9px; white-space: nowrap">
  <div style="width: 6px; height: 6px; border-radius: 2px; background: ${LANE_DOT[tint]}"></div><div style="color: ${T.fg1}; font-weight: 500">${label}</div><div style="font-family: ${MONO}; color: ${T.fg6}">${count}</div>${extra}</div>`;
const collapsedRail = (y, label, count, tint = 'warm') => `<div style="position: absolute; left: 0; right: 0; top: ${y}px; height: 18px; background: ${LANE_BG[tint]}; border-top: 1px solid ${T.laneDivider}; border-bottom: 1px solid ${T.laneDivider}"></div>
  ${laneChip(4, y + 1, label, count, tint, `<div style="color: ${T.fg6}">已折叠</div>`)}`;

// 迷你通知卡：undo / error
const toastMini = (x, y, w, text, kind = 'undo', action = '撤销') => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; box-sizing: border-box; display: flex; align-items: center; gap: 5px; padding: 4px 6px; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; box-shadow: 0 10px 30px rgba(0,0,0,0.5); font-size: 9px">
  <div style="color: ${kind === 'error' ? T.danger : T.fg3}; display: flex">${ic(kind === 'error' ? 'error' : 'undo', 11)}</div>
  <div style="flex: 1; min-width: 0; color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${text}</div>
  ${action ? `<button type="button" style="color: ${T.accent}; font-size: 9px; flex: none">${action}</button>` : ''}</div>`;

// 迷你浮动工具条
const mb = (icon, label = '', primary = false, hov = false) => primary
  ? `<button type="button" style="height: 17px; padding: 0 5px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-weight: 500; display: flex; align-items: center; gap: 3px; white-space: nowrap">${icon ? ic(icon, 10) : ''}<span>${label}</span></button>`
  : `<button type="button" style="height: 17px; padding: 0 4px; border-radius: 3px; ${hov ? `background: ${T.s5};` : ''} color: ${T.fg3}; display: flex; align-items: center; gap: 3px; white-space: nowrap">${icon ? ic(icon, 10) : ''}${label ? `<span>${label}</span>` : ''}</button>`;
const msep = `<div style="width: 1px; height: 10px; background: ${T.control}; margin: 0 1px"></div>`;
const mbar = (x, y, inner, extra = '') => `<div style="position: absolute; left: ${x}px; top: ${y}px; display: inline-flex; align-items: center; gap: 1px; padding: 2px; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 4px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); font-size: 9px; ${extra}">${inner}</div>`;

// 迷你菜单 / 面板
const mmenu = (x, y, w, inner) => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; box-sizing: border-box; padding: 2px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 24px 64px rgba(0,0,0,0.6); font-size: 9px">${inner}</div>`;
const mi = (label, o = {}) => `<button type="button" style="width: 100%; height: 15px; display: flex; align-items: center; gap: 4px; padding: 0 5px; border-radius: 2px; box-sizing: border-box; ${o.hov ? `background: ${T.s5};` : ''} color: ${o.dis ? T.fg6 : T.fg2}"><span style="flex: 1; white-space: nowrap">${label}</span>${o.right ? `<span style="font-family: ${MONO}; font-size: 8px; color: ${T.fg6}">${o.right}</span>` : ''}${o.check ? `<span style="color: ${T.accent}; display: flex">${ic('success', 9)}</span>` : ''}</button>`;
const seg = (label, o = {}) => `<button type="button" style="height: 14px; padding: 0 4px; border-radius: 2px; background: ${o.hov ? T.s5 : T.s3}; border: 1px solid ${o.hov ? T.controlStrong : T.outline}; color: ${o.dis ? T.fg6 : T.fg2}; font-size: 8px; display: flex; align-items: center; white-space: nowrap">${label}</button>`;

// 迷你检查器（多选）
const insHead = (title, sub = '') => `<div style="padding: 5px 7px; border-bottom: 1px solid ${T.bSubtle}"><div style="display: flex; align-items: center; gap: 4px"><div style="font-size: 10px; font-weight: 500; color: ${T.fg1}; white-space: nowrap">${title}</div><div style="flex: 1"></div>${sub ? `<div style="height: 12px; padding: 0 4px; border-radius: 6px; border: 1px solid ${T.outline}; color: ${T.fg4}; font-size: 8px; display: flex; align-items: center; white-space: nowrap">${sub}</div>` : ''}</div></div>`;
const insRow = (label, value, o = {}) => `<div style="display: flex; align-items: center; gap: 5px; padding: 0 7px; margin-top: 4px"><div style="width: 22px; font-size: 8px; color: ${T.fg4}">${label}</div>
  <button type="button" style="flex: 1; height: 14px; border-radius: 2px; background: ${T.s2}; border: 1px solid ${o.focus ? T.accent : o.multi ? T.controlStrong : T.outline}; display: flex; align-items: center; padding: 0 4px; color: ${o.multi ? T.fg6 : T.fg2}; font-size: 8px"><span style="flex: 1">${value}</span>${caret()}</button></div>`;
const insLine = (text, color = T.fg4, extra = '') => `<div style="padding: 3px 7px 0; font-size: 8px; color: ${color}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; ${extra}">${text}</div>`;
const insList = (name, cost) => `<div style="height: 12px; display: flex; align-items: center; gap: 4px; padding: 0 7px; font-size: 8px"><div style="width: 14px; height: 8px; border-radius: 1px; background: ${T.thumb}; outline: 1px solid ${T.outline}"></div><div style="flex: 1; color: ${T.fg3}; white-space: nowrap; overflow: hidden">${name}</div><div style="font-family: ${MONO}; color: ${T.fg5}">${cost}</div></div>`;
const insRun = (label) => `<div style="position: absolute; left: 0; right: 0; bottom: 0; padding: 4px 7px; border-top: 1px solid ${T.bSubtle}; background: ${T.s3}"><button type="button" style="width: 100%; height: 15px; border-radius: 2px; background: ${T.accent}; color: ${T.onAccent}; font-weight: 500; font-size: 8px; display: flex; align-items: center; justify-content: center; gap: 3px">${ic('run', 9)}<span>${label}</span></button></div>`;

// ---------- 帧 / 行 / 区块 ----------
const strip = (s) => s.replace(/<[^>]+>/g, '');
const textW = (s) => [...strip(s)].reduce((a, ch) => a + (/[　-鿿＀-￯]/.test(ch) ? 11 : 6.4), 0);
const warns = [];

// kind: 'stage' | 'plain' | 'panel'；badge: 流程号；title: 状态名 / 边界名
const frame = (fw, mh, f) => {
  const bg = f.kind === 'panel' ? panelBg : f.kind === 'plain' ? plainBg : stageBg;
  const badge = f.n ? `<div style="position: absolute; left: 4px; top: 4px; width: 15px; height: 15px; border-radius: 8px; background: ${T.accent}; color: ${T.onAccent}; font-family: ${MONO}; font-size: 9px; font-weight: 500; display: flex; align-items: center; justify-content: center; z-index: 5">${f.n}</div>` : '';
  const need = f.cap.startsWith('需：');
  const capHtml = need ? `<span style="color: ${T.accent}">需</span>　${f.cap.slice(2)}` : f.cap;
  const head = f.title ? `<span style="color: ${f.newTag ? T.accent : T.fg1}; font-weight: 500">${f.title}</span>　` : '';
  const full = (f.title ? f.title + '　' : '') + f.cap;
  if (textW(full) > fw * 2 - 4) warns.push(`${Math.round(textW(full))}>${fw * 2}: ${full}`);
  return `<div style="width: ${fw}px; flex: none">
    <div style="position: relative; width: ${fw}px; height: ${mh}px; border-radius: 4px; overflow: hidden; ${bg}">${badge}${f.html}</div>
    <div style="margin-top: 4px; height: ${CAP}px; overflow: hidden; font-size: 11px; line-height: 16px; color: ${T.fg4}">${head}${capHtml}</div>
  </div>`;
};
const rowLabel = (t) => `<div style="width: ${LABEL}px; flex: none; padding-top: 2px; font-size: 11px; color: ${T.fg5}">${t}</div>`;
const row = (label, mh, frames) => {
  const n = frames.length;
  const fw = Math.floor((FA - GAP * (n - 1)) / n);
  return `<div style="display: flex; gap: 10px; height: ${mh + 4 + CAP}px">${rowLabel(label)}<div style="display: flex; gap: ${GAP}px">${frames.map((f) => frame(fw, typeof f.mh === 'number' ? f.mh : mh, f)).join('')}</div></div>`;
};
const H3 = 20, H3MB = 6, BLOCKPAD = 10, ROWGAP = 8;
const pill = (s) => {
  const c = s === '新' ? T.accent : s === '部分' ? T.fg3 : T.success;
  return `<span style="height: 16px; padding: 0 6px; border-radius: 8px; border: 1px solid ${s === '新' ? T.washBorder : T.outline}; color: ${c}; font-size: 10px; display: inline-flex; align-items: center">${s}</span>`;
};
const block = (b) => {
  const mh = b.mh;
  const html = `<div style="padding: ${BLOCKPAD}px 0; border-top: 1px solid ${T.bSubtle}">
    <div style="height: ${H3}px; display: flex; align-items: center; gap: 8px; margin-bottom: ${H3MB}px; white-space: nowrap; overflow: hidden">
      <div style="font-weight: 500; color: ${T.fg1}">${b.title}</div>${pill(b.status)}
      <div style="font-size: 11px; color: ${T.fg5}; overflow: hidden; text-overflow: ellipsis">${b.note}</div>
    </div>
    <div style="display: flex; flex-direction: column; gap: ${ROWGAP}px">
      ${row('状态', mh, b.states)}
      ${row('流程', mh, b.flow)}
      ${row('边界', mh, b.edges)}
    </div>
  </div>`;
  const h = BLOCKPAD * 2 + 1 + H3 + H3MB + 3 * (mh + 4 + CAP) + 2 * ROWGAP;
  return { html, h };
};

// ================= A 框选与加减选 =================
const A = block({
  title: '框选与加减选', status: '新', mh: 58,
  note: '现状：canvas_selection_controller.dart 只有 select(toggle) / selectAll / clear；尚无框选，左键拖空白现是平移；canvas_view.dart 点卡 Shift / Ctrl / ⌘ 都是切换',
  states: [
    { title: '默认', cap: '选择工具、无选中；拖空白将改为起框', html: `${tc(10, 10, { t: '镜头01' })}${tc(56, 28, { t: '镜头02' })}${tc(102, 10, { img: IMG.thumbWide })}${cur(84, 36)}` },
    { title: '拖框中', cap: '碰到框即命中（Q1-A），实时描琥珀', html: `${tc(10, 10, { t: '镜头01' })}${tc(56, 28, { t: '镜头02', pre: true })}${tc(102, 10, { img: IMG.thumbWide, pre: true })}${marq(50, 4, 96, 50)}${chip(110, 40, '2')}` },
    { title: 'Shift 加选', cap: '原选中保留，框内的并进来', html: `${tc(10, 10, { t: '镜头01', sel: true })}${tc(56, 28, { t: '镜头02', pre: true })}${tc(102, 10, { img: IMG.thumbWide, pre: true })}${marq(50, 4, 96, 50)}${key('Shift', 6, 38)}` },
    { title: '反选', cap: '⌘ / Ctrl 拖：框内已选的取消、未选的选上', html: `${tc(10, 10, { t: '镜头01' })}${tc(56, 28, { t: '镜头02' })}${tc(102, 10, { img: IMG.thumbWide, pre: true })}${marq(50, 4, 96, 50)}${key('⌘ / Ctrl', 6, 38)}` },
    { title: '完成', cap: '松手定格；状态栏「选中 2」（已有）', html: `${tc(10, 8, { t: '镜头01' })}${tc(56, 22, { t: '镜头02', sel: true })}${tc(102, 8, { img: IMG.thumbWide, sel: true })}${statusStrip('选中 2')}` },
    { title: '空态', cap: '框里没卡：松手 = 清空选中，同点空白', html: `${tc(10, 10, { t: '镜头01' })}${tc(102, 30, { t: '镜头03' })}${marq(48, 8, 46, 40)}` },
    { title: '禁用', cap: '平移工具 / 按住空格 / 连线中不起框', html: `${tc(10, 10, { t: '镜头01' })}${tc(56, 28, { t: '镜头02' })}${cur(96, 20, 'pan')}${chip(6, 40, 'H · 平移')}` },
  ],
  flow: [
    { n: 1, title: '按下', cap: '按在空白：不在卡上、不在泳道标题栏', html: `${tc(14, 10, { t: '镜头01' })}${tc(120, 26, { t: '镜头02' })}${ring(70, 24)}${cur(70, 24)}` },
    { n: 2, title: '起框', cap: '移动 ≥ 4px 才起框；不到 4px 算点空白', html: `${tc(14, 10, { t: '镜头01' })}${tc(120, 26, { t: '镜头02' })}${marq(70, 24, 14, 10)}${cur(82, 32)}${chip(96, 6, '4px')}` },
    { n: 3, title: '拖', cap: '碰到即命中，计数 chip 跟在框右下', html: `${tc(14, 10, { t: '镜头01' })}${tc(120, 26, { t: '镜头02', pre: true })}${tc(160, 6, { img: IMG.thumbMountain, pre: true })}${marq(70, 2, 136, 50)}${chip(168, 36, '已选 2')}` },
    { n: 4, title: '贴边', cap: '拖到舞台边 16px 内自动平移，框跟着长', html: `${tc(14, 10, { t: '镜头01' })}${tc(120, 26, { t: '镜头02', pre: true })}${marq(70, 2, 160, 50)}<div style="position: absolute; right: 0; top: 0; bottom: 0; width: 16px; background: rgba(201,168,91,0.08)"></div>${cur(200, 40)}` },
    { n: 5, title: '松手', cap: '替换原选中；检查器换成多选检查器', html: `${tc(14, 10, { t: '镜头01' })}${tc(120, 26, { t: '镜头02', sel: true })}${tc(160, 6, { img: IMG.thumbMountain, sel: true })}${statusStrip('选中 2')}` },
  ],
  edges: [
    { title: 'Esc 取消', cap: '撤掉框，回到拖之前的选中', html: `${tc(10, 10, { t: '镜头01', sel: true })}${tc(70, 26, { t: '镜头02' })}${marq(60, 4, 70, 46, true)}${key('Esc', 140, 6)}` },
    { title: '折叠道', cap: '框掠过折叠的泳道：里面的卡不参与', html: `${collapsedRail(20, '水墨风格', 2)}${tc(120, 2, { t: '镜头04', pre: true })}${marq(90, 0, 80, 54)}` },
    { title: '泳道标题栏', cap: '标题栏起拖仍是重排泳道（已上线）', html: `${band(10, 40, 'sky')}${laneChip(6, 14, '冷色调', 2, 'sky')}${cur(48, 20)}${tc(110, 24, { t: '镜头05' })}` },
    { title: '点卡修饰键', cap: 'Q7-A 不改：Shift / Ctrl / ⌘ 点卡都切换', html: `${tc(14, 14, { t: '镜头01', sel: true })}${tc(70, 14, { t: '镜头02', sel: true })}${cur(90, 30)}${key('Shift', 120, 10)}${key('⌘', 120, 30)}` },
    { title: 'mac', cap: '⌘ 拖框反选；Ctrl+点卡 = 右键开菜单', html: `${tc(10, 10, { t: '镜头01', sel: true })}${key('Ctrl+点', 8, 38)}${mmenu(64, 6, 96, `${mi('生成', { right: '⌘↵' })}${mi('复制一份', { right: '⌘D', hov: true })}`)}` },
    { title: 'Windows', cap: 'Ctrl 拖框反选；右键拖 = 平移（现状）', html: `${tc(10, 10, { t: '镜头01' })}${tc(56, 28, { t: '镜头02', pre: true })}${marq(48, 20, 60, 34)}${key('Ctrl', 6, 38)}${cur(140, 18, 'pan', T.fg4)}` },
  ],
});

// ================= B 整组拖动 =================
const B = block({
  title: '整组拖动', status: '部分', mh: 64,
  note: '现状：node_card.dart 拖动只挪自己（nodeDragDeltaProvider 只广播一个 id）；drop_placement.dart 的 resolveCardDrop（18 / 12）、cardDropTargetLane 高亮、单张换道撤销卡已上线',
  states: [
    { title: '默认', cap: '已选 2 张；卡上是抓手光标（现状）', html: `${tc(16, 18, { t: '镜头03', sel: true })}${tc(64, 24, { t: '镜头04', sel: true })}${cur(80, 34, 'pan')}` },
    { title: '拖动中', cap: '整组跟手，原位留虚线；连线跟着重画', html: `${tc(10, 30, { ghost: true })}${tc(56, 36, { ghost: true })}${tc(34, 10, { t: '镜头03', sel: true })}${tc(80, 16, { t: '镜头04', sel: true })}` },
    { title: '目标道高亮', cap: '跨进新道：目标道描琥珀（已有判定）', html: `${band(0, 40, 'warm', true)}${laneChip(4, 3, '水墨风格', 2, 'warm')}${tc(30, 16, { t: '镜头03', sel: true })}${tc(78, 20, { t: '镜头04', sel: true })}${tc(30, 44, { ghost: true })}` },
    { title: '完成', cap: '落位；换了道弹撤销卡（8 秒）', html: `${band(0, 40, 'warm')}${tc(30, 14, { t: '镜头03', sel: true })}${tc(78, 18, { t: '镜头04', sel: true })}${toastMini(4, 44, 138, '已移入泳道「水墨风格」')}` },
    { title: '出错', cap: '写库失败：整组回原位 +「节点移动失败」', html: `${tc(16, 8, { t: '镜头03', sel: true })}${tc(64, 14, { t: '镜头04', sel: true })}${toastMini(4, 42, 138, '节点移动失败', 'error', '')}` },
    { title: '禁用', cap: '平移工具下卡不收指针（_PanGate）', html: `${tc(16, 18, { t: '镜头03', sel: true })}${tc(64, 24, { t: '镜头04', sel: true })}${cur(84, 32, 'pan')}${chip(6, 46, '空格 · 平移')}` },
  ],
  flow: [
    { n: 1, title: '按住', cap: '按住选区里任一张；没选中的先单选再拖', html: `${band(0, 30, 'sky')}${tc(24, 4, { t: '镜头03', sel: true })}${tc(74, 6, { t: '镜头04', sel: true })}${ring(90, 18)}${band(34, 30, 'warm')}${laneChip(4, 37, '水墨风格', 2, 'warm')}` },
    { n: 2, title: '拖过 18px', cap: '屏幕 18px 以内只挪不换道', html: `${band(0, 30, 'sky')}${tc(24, 4, { ghost: true })}${tc(74, 6, { ghost: true })}${tc(30, 10, { t: '镜头03', sel: true })}${tc(80, 12, { t: '镜头04', sel: true })}${chip(130, 6, '12px')}${band(34, 30, 'warm')}` },
    { n: 3, title: '跨界', cap: '抓住那张卡心进新道 ≥ 12：全组同道（Q2-B）', html: `${band(0, 30, 'sky')}${band(34, 30, 'warm', true)}${laneChip(4, 37, '水墨风格', 2, 'warm')}${tc(70, 30, { t: '镜头03', sel: true })}${tc(120, 34, { t: '镜头04', sel: true })}` },
    { n: 4, title: '松手', cap: '一个事务 moveNodes；弹撤销卡', html: `${band(0, 30, 'sky')}${band(34, 30, 'warm')}${tc(70, 38, { t: '镜头03', sel: true })}${tc(120, 40, { t: '镜头04', sel: true })}${toastMini(60, 4, 156, '已移入泳道「水墨风格」')}` },
    { n: 5, title: '撤销', cap: '整组回原位、原道；已被删的跳过', html: `${band(0, 30, 'sky')}${tc(24, 4, { t: '镜头03', sel: true })}${tc(74, 6, { t: '镜头04', sel: true })}${band(34, 30, 'warm')}${chip(130, 44, '已撤销')}` },
  ],
  edges: [
    { title: '误拖', cap: '不到 18px：只挪位置，不改 laneId（已上线）', html: `${band(0, 36, 'sky')}${tc(30, 8, { ghost: true })}${tc(34, 12, { t: '镜头03', sel: true })}${band(40, 24, 'warm')}${chip(100, 14, '6px')}` },
    { title: '部分失败', cap: '需：第 3 张写失败整批回滚（moveNodes）', html: `${tc(10, 8, { t: '镜头01', sel: true })}${tc(54, 8, { t: '镜头02', sel: true })}${tc(98, 8, { t: '镜头03', sel: true })}${toastMini(4, 40, 160, '节点移动失败', 'error', '')}` },
    { title: '拖中被删', cap: 'Delete 删掉一张：其余照拖，广播去掉它', html: `${tc(16, 10, { t: '镜头03', sel: true })}${tc(64, 16, { t: '镜头04', dim: true })}${key('Delete', 110, 10)}` },
    { title: 'Shift 锁轴', cap: '只沿起拖方向走（并入 KM 轴锁）', html: `${tc(10, 20, { ghost: true })}${tc(80, 20, { t: '镜头03', sel: true })}<div style="position: absolute; left: 10px; right: 10px; top: 31px; border-top: 1px dashed ${T.accent}; opacity: .5"></div>${key('Shift', 10, 46)}` },
    { title: 'mac', cap: '按住 ⌘ 松手 = 原样放下：不吸、不插线', html: `${tc(30, 14, { t: '镜头03', sel: true })}${key('⌘', 10, 44)}${chip(80, 20, '不吸附')}` },
    { title: 'Windows', cap: '按住 Ctrl 同上；Alt 已给切线，不复用', html: `${tc(30, 14, { t: '镜头03', sel: true })}${key('Ctrl', 10, 44)}${chip(80, 20, '不吸附')}` },
  ],
});

// ================= C 浮动上下文工具条 =================
const selPair = `${tc(40, 34, { t: '镜头02', sel: true })}${tc(86, 34, { t: '镜头03', sel: true })}`;
const C = block({
  title: '浮动上下文工具条', status: '新', mh: 58,
  note: '现状：尚无——canvas_toolbar.dart 是舞台顶部固定工具条；条上动作已在 node_menu_model.dart（生成 / 复制一份 / 存为角色 / 加入泳道 / 序列定位 / 删除）',
  states: [
    { title: '空态', cap: '没选中不出条', html: `${tc(30, 20, { t: '镜头02' })}${tc(76, 20, { t: '镜头03' })}` },
    { title: '单选配置', cap: 'Q3-B 精简条：不放生成', html: `${mbar(4, 6, `${mb('lane', '泳道')}${msep}${mb('', '复制')}${mb('sequence')}${mb('more')}`)}${tc(56, 34, { t: '镜头02', sel: true })}` },
    { title: '单选产物', cap: '存为角色 · 当首帧 · 序列定位', html: `${mbar(4, 6, `${mb('characters', '存角色')}${mb('videoConfig')}${mb('sequence')}${mb('more')}`)}${tc(56, 34, { img: IMG.thumbMountain, sel: true })}` },
    { title: '多选', cap: '计数 + 总价；生成只数配置节点', html: `${mbar(4, 6, `<span style="font-family: ${MONO}; color: ${T.fg4}; padding: 0 3px">2 · $1.40</span>${mb('run', '生成 2', true)}${mb('more')}`)}${selPair}` },
    { title: '悬停', cap: 'tooltip 带键位，与右键菜单同源', html: `${mbar(4, 6, `${mb('lane', '泳道', false, true)}${msep}${mb('', '复制')}${mb('more')}`)}${tip(8, 28, '包成泳道 ⌘G')}${tc(100, 34, { t: '镜头02', sel: true })}` },
    { title: '拖动中', cap: '拖 / 平移 / 缩放 / 连线中隐藏', html: `${mbar(4, 6, `${mb('lane', '泳道')}${mb('more')}`, 'opacity: .25')}${tc(30, 34, { ghost: true })}${tc(70, 26, { t: '镜头02', sel: true })}` },
    { title: '禁用', cap: '多选全是产物：「生成」不出，不置灰', html: `${mbar(4, 6, `<span style="font-family: ${MONO}; color: ${T.fg4}; padding: 0 3px">2 个</span>${mb('', '对齐')}${mb('more')}`)}${tc(40, 34, { img: IMG.thumbMountain, sel: true })}${tc(86, 34, { img: IMG.thumbWide, sel: true })}` },
  ],
  flow: [
    { n: 1, title: '选中', cap: '框选或点卡得到选区', html: `${tc(60, 30, { t: '镜头02', sel: true })}${tc(110, 30, { t: '镜头03', sel: true })}${tc(160, 30, { img: IMG.thumbWide })}` },
    { n: 2, title: '淡入', cap: '手停 150ms，选区上方 8 居中淡入', html: `${mbar(46, 6, `<span style="font-family: ${MONO}; color: ${T.fg4}; padding: 0 3px">2 · $1.40</span>${mb('run', '生成 2', true)}${mb('', '对齐')}${mb('more')}`, 'opacity: .7')}${tc(60, 30, { t: '镜头02', sel: true })}${tc(110, 30, { t: '镜头03', sel: true })}` },
    { n: 3, title: '点生成', cap: '「生成 2 个」与多选 ⌘↵ / Ctrl ↵ 同一条路', html: `${mbar(46, 6, `<span style="font-family: ${MONO}; color: ${T.fg4}; padding: 0 3px">2 · $1.40</span>${mb('run', '生成 2', true)}${mb('', '对齐')}${mb('more')}`)}${cur(110, 16)}${tc(60, 30, { t: '镜头02', sel: true })}${tc(110, 30, { t: '镜头03', sel: true })}` },
    { n: 4, title: '确认', cap: 'TakesCost 运行对话框：清单 + 总价，上限 50', kind: 'plain', html: `${mmenu(30, 4, 164, `<div style="padding: 2px 5px; font-weight: 500; color: ${T.fg1}">生成 2 个 · 约 $1.40</div>${mi('镜头 02 · 江上孤舟', { right: '$0.70' })}${mi('镜头 03 · 回望', { right: '$0.70' })}`)}` },
    { n: 5, title: '反馈', cap: '状态栏胶囊「生成中 2」，条仍在', html: `${mbar(46, 6, `<span style="font-family: ${MONO}; color: ${T.fg4}; padding: 0 3px">2 · $1.40</span>${mb('run', '生成 2', true)}${mb('more')}`)}${tc(60, 26, { t: '镜头02', sel: true })}${statusStrip(`<span style="color: ${T.accent}">生成中 2</span>`)}` },
  ],
  edges: [
    { title: '顶到工具条', cap: '选区贴舞台顶：条翻到选区下方', html: `<div style="position: absolute; left: 40px; top: 0; width: 100px; height: 10px; background: ${T.s4}; border: 1px solid ${T.control}; border-top: 0; border-radius: 0 0 3px 3px"></div>${tc(56, 12, { t: '镜头02', sel: true })}${mbar(40, 38, `${mb('lane', '泳道')}${mb('', '复制')}${mb('more')}`)}` },
    { title: '出视口', cap: '选区一半出视口：条夹在舞台内', html: `${tc(150, 30, { t: '镜头02', sel: true, w: 46 })}${mbar(86, 6, `${mb('lane', '泳道')}${mb('', '复制')}${mb('more')}`)}` },
    { title: '焦点', cap: '不进 Tab 序；打字时不抢焦点', html: `${mbar(4, 6, `${mb('lane', '泳道')}${mb('more')}`)}<div style="position: absolute; left: 6px; right: 6px; bottom: 6px; height: 16px; border-radius: 3px; background: ${T.s3}; border: 1px solid ${T.accent}; font-size: 8px; color: ${T.fg2}; padding: 0 5px; display: flex; align-items: center">江面雾气渐散<span style="display: inline-block; width: 1px; height: 9px; background: ${T.accent}"></span></div>` },
    { title: '含停用', cap: '「生成 N 个」不数停用的；对话框列跳过', html: `${mbar(4, 6, `${mb('run', '生成 1', true)}${mb('more')}`)}${tc(40, 34, { t: '镜头02', sel: true })}${tc(86, 34, { t: '已停用', sel: true, dim: true })}` },
    { title: '关掉', cap: '需：设置 › 节点布局开关，默认开', kind: 'plain', html: `${mmenu(8, 8, 160, `${mi('选中时显示浮动工具条', { check: true })}${mi('吸附到网格', { check: true })}`)}` },
    { title: 'mac / Win', cap: 'tooltip 按平台写 ⌘G / Ctrl G', html: `${tip(6, 8, '包成泳道 ⌘G')}${tip(6, 32, '包成泳道 Ctrl G')}` },
  ],
});

// ================= D 多选检查器 =================
const D = block({
  title: '多选检查器', status: '新', mh: 92,
  note: '现状：canvas_inspector_panel.dart 只认 selected.length == 1；多选时落「选中一个节点以编辑参数」（inspectorNoSelection），与没选中同一句',
  states: [
    { title: '空态', cap: '没选中：沿用 inspectorNoSelection', kind: 'panel', html: `<div style="position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; font-size: 9px; color: ${T.fg6}">选中一个节点以编辑参数</div>` },
    { title: '现状多选', cap: '多选也落这句，要改', kind: 'panel', html: `<div style="position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; font-size: 9px; color: ${T.fg6}">选中一个节点以编辑参数</div>${chip(6, 6, '选中 3')}` },
    { title: '同类型', cap: '列共有参数，改一处写全部', kind: 'panel', html: `${insHead('已选 3 个节点', '视频配置 ×3')}${insRow('模型', '万相 2.2')}${insRow('时长', '多个值', { multi: true })}${insRow('画幅', '16:9')}${insRun('生成 3 个 · 约 $2.10')}` },
    { title: '混选', cap: '只列数量、总价、清单', kind: 'panel', html: `${insHead('已选 4 个节点', '混选')}${insLine('总预估 约 $1.40')}${insList('镜头 02 · 江上孤舟', '$0.70')}${insList('镜头 03 · 回望', '$0.70')}${insList('成片 · take 2', '—')}` },
    { title: '价格未知', cap: '不报 $0，写「另 N 个价格未知」', kind: 'panel', html: `${insHead('已选 3 个节点', '图像配置 ×3')}${insLine(`总预估 <span style="font-family: ${MONO}; color: ${T.fg2}">约 $0.08</span>`)}${insLine('另 1 个价格未知', T.fg5)}${insRow('模型', '多个值', { multi: true })}` },
    { title: '出错', cap: '批量写失败：整批回滚 + 底部错误行', kind: 'panel', html: `${insHead('已选 3 个节点', '视频配置 ×3')}${insRow('时长', '多个值', { multi: true })}<div style="position: absolute; left: 0; right: 0; bottom: 0; padding: 4px 7px; border-top: 1px solid ${T.bSubtle}; display: flex; align-items: center; gap: 4px; font-size: 8px"><span style="color: ${T.danger}; display: flex">${ic('error', 10)}</span><span style="flex: 1; color: ${T.fg2}">更改未保存：数据库写入失败</span><button type="button" style="color: ${T.accent}; font-size: 8px">重试</button></div>` },
  ],
  flow: [
    { n: 1, title: '选 3 个', cap: '三个视频配置；时长不一样', kind: 'panel', html: `${insHead('已选 3 个节点', '视频配置 ×3')}${insRow('模型', '万相 2.2')}${insRow('时长', '多个值', { multi: true })}${insRow('种子', '多个值', { multi: true })}` },
    { n: 2, title: '打开', cap: '点「时长 · 多个值」开下拉', kind: 'panel', html: `${insHead('已选 3 个节点', '视频配置 ×3')}${insRow('时长', '多个值', { multi: true, focus: true })}${mmenu(36, 44, 110, `${mi('4 秒')}${mi('5 秒', { hov: true })}${mi('8 秒')}`)}` },
    { n: 3, title: '确认', cap: '需：选 5 秒 = 一个事务写 3 个', kind: 'panel', html: `${insHead('已选 3 个节点', '视频配置 ×3')}${insRow('时长', '5 秒', { focus: true })}${insLine('写入中…', T.fg5, 'margin-top: 4px')}` },
    { n: 4, title: '反馈', cap: '字段统一为「5 秒」，总价重算', kind: 'panel', html: `${insHead('已选 3 个节点', '视频配置 ×3')}${insLine(`总预估 <span style="font-family: ${MONO}; color: ${T.fg2}">约 $2.10</span>`)}${insRow('时长', '5 秒')}${insRun('生成 3 个 · 约 $2.10')}` },
    { n: 5, title: '撤销', cap: '⌘Z / Ctrl Z 一步回到各自原值', kind: 'panel', html: `${insHead('已选 3 个节点', '视频配置 ×3')}${insRow('时长', '多个值', { multi: true })}${chip(8, 64, '已撤销')}` },
  ],
  edges: [
    { title: '换模型', cap: '不支持的字段清掉，并点名几个', kind: 'panel', html: `${insHead('已选 3 个节点', '视频配置 ×3')}${insRow('模型', '可灵 3')}${insLine('2 个节点的种子已清掉', T.accent, 'margin-top: 4px')}` },
    { title: '防抖未落', cap: '先冲掉挂起的 patch 再批量写', kind: 'panel', html: `${insHead('已选 3 个节点', '视频配置 ×3')}${insRow('时长', '5 秒')}${insLine('先保存 镜头 02 的改动', T.fg5, 'margin-top: 4px')}` },
    { title: '中途换选', cap: '写入照旧落完，检查器跟新选区', kind: 'panel', html: `${insHead('已选 2 个节点', '视频配置 ×2')}${insRow('时长', '5 秒')}` },
    { title: '历史页签', cap: '多选时：选中一个节点查看历史', kind: 'panel', html: `<div style="height: 14px; display: flex; gap: 8px; padding: 0 7px; font-size: 8px; border-bottom: 1px solid ${T.bSubtle}; align-items: center"><span style="color: ${T.fg4}">属性</span><span style="color: ${T.fg1}">历史</span></div><div style="position: absolute; inset: 14px 0 0; display: flex; align-items: center; justify-content: center; font-size: 9px; color: ${T.fg6}">选中一个节点查看历史</div>` },
    { title: '只计数', cap: '文本、便签、产物不出参数', kind: 'panel', html: `${insHead('已选 2 个节点', '文本 ×2')}${insList('开场旁白', '—')}${insList('转场说明', '—')}` },
  ],
});

// ================= E 对齐 · 分布 · 排布 · 吸附 =================
const alignPanel = (o = {}) => mmenu(4, 4, 150, `<div style="padding: 1px 3px 3px">
  <div style="font-size: 8px; color: ${T.fg5}; margin: 1px 0 2px">对齐</div>
  <div style="display: flex; gap: 2px; flex-wrap: wrap">${seg('左', { hov: o.hovLeft })}${seg('居中')}${seg('右')}${seg('顶')}${seg('底')}</div>
  <div style="font-size: 8px; color: ${T.fg5}; margin: 3px 0 2px">分布${o.disDist ? ' · 至少 3 个' : ''}</div>
  <div style="display: flex; gap: 2px">${seg('水平等距', { dis: o.disDist })}${seg('垂直等距', { dis: o.disDist })}</div></div>`);
const E = block({
  title: '对齐 · 分布 · 排布 · 吸附', status: '新', mh: 64,
  note: '现状：尚无对齐 / 分布 / 吸附；网格底 canvas_grid_painter.dart 已有，只画不吸；多选位移只能逐张 moveNode（canvas_nodes_controller.dart）',
  states: [
    { title: '默认', cap: '多选 ≥ 3：对齐、分布都可点', kind: 'plain', html: alignPanel() },
    { title: '禁用', cap: '只选 2 个：分布置灰写「至少 3 个」', kind: 'plain', html: alignPanel({ disDist: true }) },
    { title: '悬停预览', cap: '悬停「左」：虚线预览落点，不写库', html: `${tc(10, 6, { t: '镜头01', sel: true })}${tc(60, 22, { t: '镜头02', sel: true })}${tc(10, 22, { ghost: true })}${tc(110, 38, { t: '镜头03', sel: true })}${tc(10, 38, { ghost: true })}${vline(10)}` },
    { title: '参考线', cap: '拖动中 6 屏幕 px 内吸附，出参考线', html: `${tc(14, 6, { img: IMG.thumbMountain })}${tc(14, 36, { t: '镜头02', sel: true })}${vline(14)}${vline(50, true)}<div style="position: absolute; left: 60px; top: 38px; font-family: ${MONO}; font-size: 8px; color: ${T.accent}">左缘</div>` },
    { title: '网格吸附', cap: '松手落到最近的 24 格点', html: `${tc(24, 24, { t: '镜头02', sel: true })}${tc(30, 28, { ghost: true })}${ring(24, 24)}` },
    { title: '开关', cap: '需：空白处右键打勾，存 AppPreferences', kind: 'plain', html: `${mmenu(8, 8, 150, `${mi('吸附到网格', { check: true })}${mi('吸附到对象', { check: true })}${mi('适应视图', { right: 'Shift 1' })}`)}` },
  ],
  flow: [
    { n: 1, title: '选 3 张', cap: '散着的三张配置', html: `${tc(30, 8, { t: '镜头01', sel: true })}${tc(90, 24, { t: '镜头02', sel: true })}${tc(150, 38, { t: '镜头03', sel: true })}` },
    { n: 2, title: '打开', cap: '浮动条「对齐 ▾」或右键「对齐 ›」', html: `${mbar(60, 4, `${mb('', '对齐')}${caret()}${mb('lane', '包成泳道')}`)}${cur(84, 14)}${tc(30, 30, { t: '镜头01', sel: true })}${tc(150, 38, { t: '镜头03', sel: true })}` },
    { n: 3, title: '点「左」', cap: '按选区包围盒；一次 moveNodes', kind: 'plain', html: alignPanel({ hovLeft: true }) },
    { n: 4, title: '结果', cap: '一步撤销；跨道的夹在各自带里', html: `${tc(30, 4, { t: '镜头01', sel: true })}${tc(30, 22, { t: '镜头02', sel: true })}${tc(30, 40, { t: '镜头03', sel: true })}${vline(30)}${chip(100, 22, '⌘Z 撤销')}` },
    { n: 5, title: '排布', cap: '网格：列 ⌈√n⌉、间距 48、先叙事序', html: `${tc(20, 6, { t: '镜头01', sel: true })}${tc(70, 6, { t: '镜头02', sel: true })}${tc(20, 34, { t: '镜头03', sel: true })}${tc(70, 34, { t: '镜头04', sel: true })}` },
  ],
  edges: [
    { title: '跨道对齐', cap: '顶对齐不把卡挤出原道', html: `${band(0, 30, 'sky')}${band(34, 30, 'warm')}${tc(20, 4, { t: '镜头01', sel: true })}${tc(70, 4, { t: '镜头02', sel: true })}${tc(120, 38, { t: '镜头03', sel: true })}` },
    { title: '失败', cap: 'moveNodes 失败：全部回原位 + 错误卡', html: `${tc(10, 6, { t: '镜头01', sel: true })}${tc(60, 16, { t: '镜头02', sel: true })}${toastMini(4, 42, 160, '节点移动失败', 'error', '')}` },
    { title: '整理叙事链', cap: '沿链一行，产物按 result_placement', html: `${tc(8, 8, { t: '镜头01' })}${tc(56, 8, { t: '镜头02' })}${tc(104, 8, { t: '镜头03' })}${tc(104, 36, { img: IMG.thumbWide })}` },
    { title: '原样放下', cap: '拖动中按住 ⌘ / Ctrl：不吸、不插线', html: `${tc(30, 18, { t: '镜头02', sel: true })}${vline(14, true)}${key('⌘ / Ctrl', 90, 22)}` },
    { title: 'mac', cap: '⌥A 左对齐；⌥⇧H 水平等距', html: `${key('⌥ A', 10, 10)}${key('⌥ ⇧ H', 10, 32)}${chip(70, 10, '左对齐')}${chip(70, 32, '水平等距')}` },
    { title: 'Windows', cap: 'Alt A：单按松开 Alt 才开菜单栏，不冲突', html: `${key('Alt A', 10, 10)}${key('Alt Shift H', 10, 32)}${chip(90, 10, '左对齐')}` },
  ],
});

// ================= F 包成泳道（含折叠）=================
const renameChip = (x, y) => `<div style="position: absolute; left: ${x}px; top: ${y}px; height: 15px; display: flex; align-items: center; gap: 4px; padding: 0 3px 0 5px; border-radius: 3px; background: rgba(38,38,38,0.82); border: 1px solid ${T.outline}">
  <div style="width: 6px; height: 6px; border-radius: 2px; background: ${T.sky}"></div>
  <div style="width: 54px; height: 11px; border-radius: 2px; background: ${T.s2}; border: 1px solid ${T.accent}; display: flex; align-items: center; padding: 0 3px; font-size: 8px; color: ${T.fg1}">新泳道<span style="display: inline-block; width: 1px; height: 8px; background: ${T.accent}"></span></div></div>`;
const F = block({
  title: '包成泳道（含折叠）', status: '部分', mh: 64,
  note: '现状：lane_title_bar.dart 折叠已上线（双击 / 折叠钮，36px 轨），lane_collapse_controller.dart 不持久化；createLane 只追加、不收 size；moveNodesToLane 已有',
  states: [
    { title: '可用', cap: '有选中：⌘G / Ctrl G 包成泳道', html: `${tc(14, 14, { t: '镜头02', sel: true })}${tc(60, 20, { t: '镜头03', sel: true })}${key('⌘G', 110, 18)}` },
    { title: '禁用', cap: '无选中：⌘G 不响应；F 照旧开对话框', html: `${tc(14, 14, { t: '镜头02' })}${tc(60, 20, { t: '镜头03' })}${key('⌘G', 110, 18)}` },
    { title: '改名中', cap: '建好即进改名，回车定名', html: `${band(4, 56, 'sky')}${renameChip(4, 8)}${tc(30, 30, { t: '镜头02', sel: true })}${tc(76, 32, { t: '镜头03', sel: true })}` },
    { title: '换风格', cap: '有卡原在别的道：弹撤销卡（8 秒）', html: `${band(4, 30, 'sky')}${tc(30, 8, { t: '镜头02', sel: true })}${toastMini(4, 40, 146, '1 张换到新泳道，风格变了')}` },
    { title: '已折叠', cap: '36px 轨 +「已折叠」（已上线）', html: `${collapsedRail(22, '水墨风格', 2)}` },
    { title: '悬停', cap: '折叠钮 tooltip「展开泳道」（已上线）', html: `${collapsedRail(10, '水墨风格', 2)}${cur(110, 12)}${tip(70, 34, '展开泳道')}` },
    { title: '出错', cap: '「创建泳道失败」：道和移动都不落', html: `${tc(14, 8, { t: '镜头02', sel: true })}${tc(60, 12, { t: '镜头03', sel: true })}${toastMini(4, 40, 146, '创建泳道失败', 'error', '')}` },
  ],
  flow: [
    { n: 1, title: '选中 + ⌘G', cap: '多选 3 张，按 ⌘G / Ctrl G', html: `${band(0, 30, 'warm')}${laneChip(4, 3, '水墨风格', 3, 'warm')}${tc(60, 36, { t: '镜头02', sel: true })}${tc(104, 36, { t: '镜头03', sel: true })}${key('⌘G', 150, 40)}` },
    { n: 2, title: '建道', cap: 'Q5-B 插在选区所在道之后；厚 = 跨轴 + 48', html: `${band(0, 24, 'warm')}${band(28, 36, 'sky', true)}${tc(60, 36, { t: '镜头02', sel: true })}${tc(104, 36, { t: '镜头03', sel: true })}` },
    { n: 3, title: '移入 + 改名', cap: '相对位置不变；建道 + 移入算一步撤销', html: `${band(0, 24, 'warm')}${band(28, 36, 'sky')}${renameChip(4, 31)}${tc(80, 36, { t: '镜头02', sel: true })}${tc(124, 36, { t: '镜头03', sel: true })}` },
    { n: 4, title: '折叠', cap: '双击标题栏（已上线）', html: `${band(0, 24, 'warm')}${collapsedRail(28, '冷色调', 2, 'sky')}${cur(50, 30)}` },
    { n: 5, title: '写库', cap: '需：Q6-C 写 style_lanes.collapsed（迁移）', html: `${collapsedRail(10, '冷色调', 2, 'sky')}${chip(8, 38, 'collapsed = true')}` },
    { n: 6, title: '重开', cap: '重开项目 / 导入项目包后仍折叠', html: `${collapsedRail(10, '冷色调', 2, 'sky')}${chip(8, 38, '项目包带这一列')}` },
  ],
  edges: [
    { title: '改名 Esc', cap: 'Esc：保留默认名「新泳道」，道照建', html: `${band(4, 56, 'sky')}${laneChip(4, 8, '新泳道', 2, 'sky')}${key('Esc', 110, 10)}` },
    { title: '移出', cap: '⌘⇧G / Ctrl Shift G 移出，屏幕位置不变', html: `${band(0, 28, 'sky')}${laneChip(4, 3, '冷色调', 1, 'sky')}${tc(60, 36, { t: '镜头02', sel: true })}${key('⌘⇧G', 120, 40)}` },
    { title: '折叠写失败', cap: '回到展开 + 错误卡「更新泳道失败」', html: `${band(0, 30, 'sky')}${laneChip(4, 3, '冷色调', 2, 'sky')}${toastMini(4, 40, 160, '更新泳道失败', 'error', '')}` },
    { title: '老库迁移', cap: '迁移后已有泳道全展开，与现状一致', kind: 'plain', html: `<div style="position: absolute; left: 8px; top: 10px; font-family: ${MONO}; font-size: 9px; line-height: 1.5; color: ${T.fg3}">ALTER TABLE style_lanes<br>ADD collapsed BOOLEAN<br>NOT NULL DEFAULT false</div>` },
    { title: 'mac', cap: '⌘G；文字框里 ⌘G 归文本，不包道', html: `${key('⌘G', 10, 10)}<div style="position: absolute; left: 8px; right: 8px; bottom: 8px; height: 16px; border-radius: 3px; background: ${T.s3}; border: 1px solid ${T.accent}; font-size: 8px; color: ${T.fg2}; padding: 0 5px; display: flex; align-items: center">提示词…</div>` },
    { title: 'Windows', cap: 'Ctrl G；同样在文字框里让位', html: `${key('Ctrl G', 10, 10)}<div style="position: absolute; left: 8px; right: 8px; bottom: 8px; height: 16px; border-radius: 3px; background: ${T.s3}; border: 1px solid ${T.accent}; font-size: 8px; color: ${T.fg2}; padding: 0 5px; display: flex; align-items: center">提示词…</div>` },
  ],
});

// ---------- 顶部 ----------
const dec = (id, v) => `<div style="height: 22px; display: flex; align-items: center; gap: 6px; padding: 0 8px; border-radius: 3px; background: ${T.wash}; border: 1px solid ${T.washBorder}; font-size: 11px; white-space: nowrap"><span style="color: ${T.fg1}; font-weight: 500">${id}</span><span style="color: ${T.accent}">${v}</span></div>`;
const HEAD = 26 + 24 + 8 + 22 + 14;
const header = `
  <div style="height: 24px; display: flex; align-items: baseline; gap: 14px">
    <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">选择与批量编辑 · 状态与流程</div>
    <div style="color: ${T.fg4}">按建议：框选碰到就算 · 单选配置出精简条 · ⌘G 新道插在选区道之后 · 折叠落库（style_lanes 新列，一条前向迁移）· 点卡修饰键不改</div>
  </div>
  <div style="margin-top: 8px; height: 22px; display: flex; gap: 8px; align-items: center">
    <div style="font-size: 11px; color: ${T.fg5}; margin-right: 2px">本板取的决定</div>
    ${dec('Q1', 'A 碰到就算')}${dec('Q2', 'B 已定')}${dec('Q3', 'B 精简条')}${dec('Q4', '已定 · 运行对话框')}${dec('Q5', 'B 选区道之后')}${dec('Q6', 'C 落库 · 阻塞')}${dec('Q7', 'A 不改')}
    <div style="flex: 1"></div>
    <div style="font-size: 11px; color: ${T.fg5}">${pill('新')} 尚无　${pill('部分')} 部分已上线</div>
  </div>`;

const blocks = [A, B, C, D, E, F];
const H = Math.min(2400, Math.ceil(HEAD + blocks.reduce((a, b) => a + b.h, 0) + 40));
if (HEAD + blocks.reduce((a, b) => a + b.h, 0) + 24 > 2400) warns.push('高度超出 2400');
if (warns.length && process.env.SEL_WARN) console.error(warns.join('\n'));

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="padding: 26px 32px 0">
    ${header}
    <div style="margin-top: 14px">${blocks.map((b) => b.html).join('')}</div>
  </div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'SelectionDetail.dc.html', html: page('选择与批量编辑 · 状态与流程', W, H, body, logic), W, H, warns };
