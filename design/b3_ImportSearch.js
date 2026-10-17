// 第三批细化画板：导入、拖放与查找 · 状态与流程（1280×H，静态）
// 对 b2_import.js 的六个功能逐个画：状态条 / 主流程分帧 / 边界帧。
// 决定：IS-Q1 → A（desktop_drop + pasteboard 两个小插件；全部画板的拖放 / 粘贴图片以此为准）
// 决定：IS-Q3 → A（插入即挂载：文字里存 @{角色 id}，同时追加 character_ids；删标签不卸载，character_ids 仍是唯一来源）
// 决定：IS-Q5 → A（便签仍是 text 节点，type_config.variant = note，不迁移；提示词拼装、大纲排除便签，检查器沿用文本正文框）
// 决定：IS-Q4 → A（工具锁做：Q + 双击工具按钮进点放模式，排 P2 / W19）
// 其余按 b2 建议：IS-Q2 → A（别的画布拖来的素材复制进本画布 imports/）；IS-Q6 → A（导入的视频不入叙事链）
const { T, IMG, SANS, MONO, page, ic } = require('./common.js');

const W = 1280, H = 2400;
const FW = 156, FH = 60; // 每帧样稿尺寸

// ---------- 小件（照搬 b2 写法，本地复制） ----------
const code = (t) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${t}</span>`;
const kbd = (k) => `<span style="font-family: ${MONO}; font-size: 8px; color: ${T.fg5}">${k}</span>`;
const hl = (t) => `<span style="background: ${T.wash}; color: ${T.accent}; border-radius: 2px; padding: 0 1px">${t}</span>`;
const need = (t) => `<span style="color: ${T.accent}">需：</span>${t}`;
const neu = `<span style="color: ${T.accent}">新</span> `;
const h3 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 8px"><div style="font-weight: 500; color: ${T.fg1}">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const now = (t) => `<div style="font-size: 11px; color: ${T.fg4}; line-height: 1.4; margin: 2px 0 4px"><span style="color: ${T.fg5}">现状：</span>${t}</div>`;

// 画布小样稿（网格底）与界面小样稿（平底）
const grid = (extra = '') => `position: relative; width: ${FW}px; height: ${FH}px; box-sizing: border-box; border-radius: 4px; border: 1px solid ${T.outline}; background-color: ${T.s1}; background-image: linear-gradient(${T.grid} 1px, transparent 1px), linear-gradient(90deg, ${T.grid} 1px, transparent 1px); background-size: 12px 12px; overflow: hidden; ${extra}`;
const st = (inner, extra = '') => `<div style="${grid(extra)}">${inner}</div>`;
const ui = (inner, extra = '') => `<div style="position: relative; width: ${FW}px; height: ${FH}px; box-sizing: border-box; border-radius: 4px; border: 1px solid ${T.outline}; background: ${T.s2}; overflow: hidden; ${extra}">${inner}</div>`;
const at = (x, y, inner, extra = '') => `<div style="position: absolute; left: ${x}px; top: ${y}px; ${extra}">${inner}</div>`;

// 缩小的节点卡：标题行 + 16:9 图区
const mc = (x, y, w, title, box = '', o = {}) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; ${o.extra || ''}">
    <div style="height: 10px; display: flex; align-items: center; gap: 3px; font-size: 7px; color: ${T.fg3}; white-space: nowrap; overflow: hidden"><span style="overflow: hidden; text-overflow: ellipsis">${title}</span><span style="flex: 1"></span><span style="color: ${T.fg6}">${o.type || ''}</span></div>
    <div style="position: relative; width: ${w}px; height: ${Math.round(w * 9 / 16)}px; box-sizing: border-box; border-radius: 2px; background: ${o.bg || T.thumb}; outline: ${o.outline || `1px solid ${T.outline}`}; overflow: hidden">${box}</div>
    ${o.status ? `<div style="height: 9px; font-size: 7px; color: ${o.statusColor || T.fg5}; white-space: nowrap; overflow: hidden">${o.status}</div>` : ''}
  </div>`;
const img = (src, extra = '') => `<img src="${src}" alt="" style="width: 100%; height: 100%; object-fit: cover; display: block; ${extra}">`;
const txt = (t, fs = 7) => `<div style="position: absolute; inset: 0; padding: 2px 4px; font-size: ${fs}px; line-height: 1.4; color: ${T.fg2}; overflow: hidden">${t}</div>`;
const badge = `<div style="position: absolute; left: 2px; top: 2px; height: 10px; padding: 0 3px; border-radius: 2px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; color: ${T.fg3}; font-size: 6px; display: flex; align-items: center; gap: 2px">${ic('upload', 7)}<span>导入</span></div>`;
const prog = (pct) => `<div style="position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; gap: 3px; color: ${T.accent}"><div class="spin" style="display: flex">${ic('progress', 10)}</div><span style="font-family: ${MONO}; font-size: 7px">${pct}%</span></div><div style="position: absolute; left: 0; bottom: 0; height: 2px; width: ${pct}%; background: ${T.accent}"></div>`;

// 光标（CSS 三角，装饰）与拖动跟手缩略
const ptr = (x, y, color = T.fg1) => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: 0; height: 0; border-left: 4px solid transparent; border-right: 4px solid transparent; border-bottom: 9px solid ${color}; transform: rotate(-28deg); filter: drop-shadow(0 1px 1px rgba(0,0,0,0.6))"></div>`;
const ghost = (x, y, w = 34, src = IMG.wide) => `<img src="${src}" alt="" style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: ${Math.round(w * 9 / 16)}px; object-fit: cover; border-radius: 2px; outline: 1px solid ${T.accent}; box-shadow: 0 6px 14px rgba(0,0,0,0.6); opacity: .9">`;

// 迷你通知卡
const mtoast = (x, y, w, icon, color, title, sub = '', act = '') => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; box-sizing: border-box; padding: 4px 6px; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; box-shadow: 0 6px 14px rgba(0,0,0,0.35); display: flex; gap: 4px; align-items: flex-start">
    <div style="color: ${color}; display: flex; flex: none; margin-top: 1px">${ic(icon, 9)}</div>
    <div style="flex: 1; min-width: 0"><div style="font-size: 8px; color: ${T.fg1}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</div>${sub ? `<div style="font-size: 7px; color: ${T.fg5}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${sub}</div>` : ''}</div>
    ${act ? `<button type="button" style="font-size: 8px; color: ${T.accent}; flex: none">${act}</button>` : ''}
  </div>`;

// 迷你菜单：rows = [{ t, k, on, off, sub, danger, check }] 或 'sep' 或 { head }
const mmenu = (x, y, w, rows) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; box-sizing: border-box; padding: 2px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 10px 24px rgba(0,0,0,0.6)">
    ${rows.map((r) => r === 'sep' ? `<div style="height: 1px; background: ${T.bStrong}; margin: 2px 0"></div>`
      : r.head ? `<div style="height: 11px; padding: 0 4px; font-size: 7px; color: ${T.fg5}; display: flex; align-items: center">${r.head}</div>`
      : `<button type="button" style="width: 100%; min-height: 12px; display: flex; align-items: center; gap: 4px; padding: 1px 4px; box-sizing: border-box; border-radius: 2px; font-size: 8px; color: ${r.danger ? T.danger : T.fg2}; ${r.on ? `background: ${T.s5};` : ''} ${r.off ? 'opacity: .45;' : ''}">${r.dot ? `<span style="width: 5px; height: 5px; border-radius: 3px; background: ${r.dot}; flex: none"></span>` : ''}<span style="flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${r.t}${r.sub ? `<span style="color: ${T.fg6}"> · ${r.sub}</span>` : ''}</span>${r.k ? kbd(r.k) : ''}</button>`).join('')}
  </div>`;

// 迷你提示词条
const pbar = (x, y, w, inner, extra = '') => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: 18px; box-sizing: border-box; padding: 0 3px 0 6px; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 4px; display: flex; align-items: center; gap: 4px; ${extra}"><div style="flex: 1; min-width: 0; font-size: 8px; color: ${T.fg1}; white-space: nowrap; overflow: hidden">${inner}</div><div style="height: 12px; padding: 0 4px; border-radius: 2px; background: ${T.accent}; color: ${T.onAccent}; font-size: 7px; display: flex; align-items: center; gap: 2px">${ic('run', 7)}<span>生成</span></div></div>`;
const caretBar = `<span style="display: inline-block; width: 1px; height: 9px; background: ${T.fg1}; vertical-align: -1px"></span>`;
const mention = (name, gone = false, sel = false) => `<span style="display: inline-flex; align-items: center; gap: 2px; height: 11px; padding: 0 4px 0 1px; margin: 0 1px; border-radius: 6px; background: ${gone ? T.s5 : T.wash}; border: 1px solid ${sel ? T.accent : gone ? T.control : T.washBorder}; color: ${gone ? T.fg5 : T.accent}; font-size: 7px; vertical-align: 0"><img src="${IMG.thumbMountain}" alt="" style="width: 8px; height: 8px; border-radius: 4px; object-fit: cover; ${gone ? 'filter: grayscale(1); opacity: .5' : ''}">${name}</span>`;
const pick = (name, meta, on = false, tag = '', src = IMG.thumbMountain) => `
  <div style="height: 14px; display: flex; align-items: center; gap: 4px; padding: 0 4px; border-radius: 2px; ${on ? `background: ${T.s5}` : ''}">
    <img src="${src}" alt="" style="width: 10px; height: 10px; border-radius: 5px; object-fit: cover">
    <div style="flex: 1; min-width: 0; font-size: 8px; color: ${T.fg1}; white-space: nowrap">${name} <span style="color: ${T.fg6}; font-size: 7px">${meta}</span></div>
    ${tag ? `<span style="height: 9px; padding: 0 3px; border-radius: 5px; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 6px; display: flex; align-items: center">${tag}</span>` : ''}
  </div>`;
const pop = (x, y, w, inner) => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; box-sizing: border-box; padding: 2px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 10px 24px rgba(0,0,0,0.6)">${inner}</div>`;

// 迷你查找条
const fbtn = (t, off = false) => `<button type="button" style="width: 12px; height: 12px; border-radius: 2px; display: flex; align-items: center; justify-content: center; color: ${T.fg3}; font-family: ${MONO}; font-size: 8px; ${off ? 'opacity: .4;' : ''}">${t}</button>`;
const findbar = (x, y, w, q, count, o = {}) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: 18px; box-sizing: border-box; padding: 0 2px 0 5px; background: ${T.s4}; border: 1px solid ${o.border || T.control}; border-radius: 4px; box-shadow: 0 6px 14px rgba(0,0,0,0.5); display: flex; align-items: center; gap: 3px">
    <div style="color: ${T.fg5}; display: flex">${ic('search', 9)}</div>
    <div style="flex: 1; min-width: 0; font-size: 8px; color: ${q ? T.fg1 : T.fg6}; white-space: nowrap; overflow: hidden">${q || '在本画布查找'}${o.caret === false ? '' : caretBar}</div>
    ${count ? `<div style="font-family: ${MONO}; font-size: 7px; color: ${o.countColor || T.fg4}; white-space: nowrap">${count}</div>` : ''}
    ${fbtn('↑', o.off)}${fbtn('↓', o.off)}
    <button type="button" aria-label="关闭查找" style="width: 12px; height: 12px; display: flex; align-items: center; justify-content: center; color: ${T.fg4}">${ic('close', 8)}</button>
  </div>`;

// 迷你缩放条（末格 = 小地图）与小地图
const zc = (inner, w = 14, extra = '') => `<div style="width: ${w}px; height: 14px; display: flex; align-items: center; justify-content: center; ${extra}">${inner}</div>`;
const zbar = (x, y, mm = 'off') => `<div style="position: absolute; left: ${x}px; top: ${y}px; display: flex; align-items: center; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 4px; color: ${T.fg3}">${zc(ic('zoomOut', 8))}${zc(`<span style="font-family: ${MONO}; font-size: 7px">80%</span>`, 20)}${zc(ic('zoomIn', 8))}${zc('<span style="font-size: 7px">适应</span>', 20, `border-left: 1px solid ${T.control}`)}${mm === 'none' ? '' : zc(ic('minimap', 8), 16, `border-left: 1px solid ${T.control}; ${mm === 'on' ? `background: ${T.wash}; color: ${T.accent};` : mm === 'hover' ? `background: ${T.s5}; color: ${T.fg1};` : mm === 'dis' ? 'opacity: .4;' : ''}`)}</div>`;
const mmap = (x, y, vx = 52, vy = 12, o = {}) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: 92px; height: 30px; box-sizing: border-box; border-radius: 3px; background: ${T.s3}; border: 1px solid ${T.control}; overflow: hidden">
    <div style="position: absolute; left: 0; right: 0; top: 5px; height: 11px; background: ${T.s5}"></div>
    <div style="position: absolute; left: 6px; top: 7px; width: 9px; height: 7px; border-radius: 1px; background: ${T.fg5}"></div>
    <div style="position: absolute; left: 18px; top: 7px; width: 9px; height: 7px; border-radius: 1px; background: ${T.fg4}"></div>
    <div style="position: absolute; left: 30px; top: 7px; width: 9px; height: 7px; border-radius: 1px; background: ${T.fg5}"></div>
    <div style="position: absolute; left: 12px; top: 19px; width: 9px; height: 7px; border-radius: 1px; background: ${T.fg6}"></div>
    <div style="position: absolute; left: ${vx}px; top: ${vy}px; width: ${o.vw || 26}px; height: ${o.vh || 14}px; box-sizing: border-box; border: 1px solid ${T.accent}; border-radius: 1px; background: ${o.drag ? T.wash : 'transparent'}"></div>
  </div>`;
const chipFit = (x, y, hov = false) => `<div style="position: absolute; left: ${x}px; top: ${y}px; height: 15px; padding: 0 6px; border-radius: 8px; background: ${hov ? T.s5 : T.s4}; border: 1px solid ${T.overlayBorder}; box-shadow: 0 6px 14px rgba(0,0,0,0.5); display: flex; align-items: center; gap: 3px; color: ${hov ? T.fg1 : T.fg2}; font-size: 8px; white-space: nowrap">${ic('fit', 8)}<span>回到内容</span>${kbd('Shift 1')}</div>`;

// 迷你工具条
const tbtn = (id, s = '') => `<div style="position: relative; width: 14px; height: 14px; border-radius: 2px; display: flex; align-items: center; justify-content: center; color: ${T.fg3}; ${s === 'on' ? `background: ${T.s5}; color: ${T.fg1};` : s === 'lock' ? `background: ${T.wash}; outline: 1px solid ${T.washBorder}; color: ${T.accent};` : s === 'hov' ? `background: ${T.s5};` : ''}">${ic(id, 9)}${s === 'lock' ? `<div style="position: absolute; right: -2px; bottom: -2px; width: 7px; height: 7px; border-radius: 4px; background: ${T.s4}; display: flex; align-items: center; justify-content: center; color: ${T.accent}">${ic('pin', 6)}</div>` : ''}</div>`;
const tsep = `<div style="width: 1px; height: 9px; background: ${T.control}; margin: 0 1px"></div>`;
const tbar = (x, y, img = '', sel = 'on') => `<div style="position: absolute; left: ${x}px; top: ${y}px; display: flex; align-items: center; gap: 1px; padding: 1px; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 4px">${tbtn('select', sel)}${tbtn('pan')}${tsep}${tbtn('imageConfig', img)}${tbtn('videoConfig')}${tbtn('text')}${tbtn('shot')}${tbtn('note')}${tbtn('lane')}${tbtn('link')}</div>`;
const tag = (x, y, t, extra = '') => `<div style="position: absolute; left: ${x}px; top: ${y}px; height: 12px; padding: 0 4px; border-radius: 2px; background: ${T.s5}; color: ${T.fg2}; font-size: 7px; display: flex; align-items: center; gap: 3px; white-space: nowrap; ${extra}">${t}</div>`;
const tip = (x, y, t) => `<div style="position: absolute; left: ${x}px; top: ${y}px; height: 13px; padding: 0 5px; border-radius: 3px; background: ${T.s5}; border: 1px solid ${T.overlayBorder}; color: ${T.fg2}; font-size: 7px; display: flex; align-items: center; gap: 4px; white-space: nowrap">${t}</div>`;
const note = (x, y, w, h, t, o = {}) => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: ${h}px; box-sizing: border-box; padding: 3px 4px; border-radius: 2px; background: ${o.bg || T.wash}; border: 1px solid ${o.border || T.washBorder}; box-shadow: 0 4px 10px rgba(0,0,0,0.35); font-size: 7px; line-height: 1.4; color: ${o.color || T.fg1}; overflow: hidden; ${o.extra || ''}">${t}</div>`;
const dash = (x, y, w, h, t = '', color = T.accent) => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: ${h}px; box-sizing: border-box; border: 1px dashed ${color}; border-radius: 3px; display: flex; align-items: center; justify-content: center; gap: 3px; color: ${color}; font-size: 7px; text-align: center">${t}</div>`;
const lbl = (x, y, t, color = T.fg5) => `<div style="position: absolute; left: ${x}px; top: ${y}px; font-size: 7px; color: ${color}; white-space: nowrap">${t}</div>`;

// 帧：s = 状态名（状态条），n = 步骤号（流程），e = 边界名（边界）
const capLen = (s) => [...s.replace(/<[^>]+>/g, '').replace(/&[a-z]+;/g, '·')].reduce((a, c) => a + (c.charCodeAt(0) > 255 ? 1 : 0.6), 0);
const fr = (o, mock, cap) => {
  const head = o.n ? `<span style="display: inline-flex; width: 12px; height: 12px; border-radius: 6px; border: 1px solid ${T.accent}; color: ${T.accent}; font-size: 8px; font-family: ${MONO}; align-items: center; justify-content: center; vertical-align: 0; margin-right: 3px">${o.n}</span>`
    : `<span style="color: ${o.e ? T.fg1 : T.fg1}; font-weight: 500; margin-right: 4px">${o.s || o.e}</span>`;
  const full = (o.s || o.e || '') + cap;
  if (capLen(full) > 31) console.warn('caption too long:', capLen(full).toFixed(1), full.replace(/<[^>]+>/g, ''));
  return `<div style="width: ${FW}px; flex: none">${mock}<div style="margin-top: 4px; font-size: 10px; line-height: 14px; height: 28px; overflow: hidden; color: ${T.fg4}">${head}${cap}</div></div>`;
};
const row = (label, frames) => `<div style="display: flex; gap: 12px; align-items: flex-start"><div style="width: 32px; flex: none; padding-top: 22px; font-size: 10px; color: ${T.fg5}">${label}</div>${frames.join('')}</div>`;
const block = (title, note, nowText, rows) => `
  <section style="display: flex; flex-direction: column">
    ${h3(title, note)}
    ${now(nowText)}
    <div style="display: flex; flex-direction: column; gap: 6px">${rows.join('')}</div>
  </section>`;
const divider = `<div style="height: 1px; background: ${T.bSubtle}"></div>`;

// ====================================================================
// A：导入媒体
// ====================================================================
const dropOverlay = (t, sub, color = T.accent, bg = T.wash) => `<div style="position: absolute; inset: 4px; box-sizing: border-box; border: 1px dashed ${color}; border-radius: 4px; background: ${bg}; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; color: ${color}">${ic('upload', 11)}<div style="font-size: 8px; font-weight: 500">${t}</div><div style="font-size: 7px; color: ${T.fg4}">${sub}</div></div>`;
const blankMenuImport = (on = false, off = false) => mmenu(30, 6, 96, [
  { t: '新建…', k: 'Tab' }, { t: '导入媒体…', k: 'Ctrl U', on, off, sub: off ? '未打开画布' : '' }, { t: '导入脚本…' }, 'sep', { t: '全选', k: 'Ctrl A' },
]);
const osDialog = (x, y, rows, foot = '') => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: 120px; box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 10px 24px rgba(0,0,0,0.6); overflow: hidden"><div style="height: 10px; padding: 0 4px; font-size: 7px; color: ${T.fg5}; background: ${T.s4}; display: flex; align-items: center">系统选择框 · 图片 / 视频</div>${rows.map((r) => `<div style="height: 9px; padding: 0 4px; font-size: 7px; display: flex; align-items: center; ${r[1] ? `background: ${T.s5}; color: ${T.fg1}` : `color: ${T.fg4}`}">${r[0]}</div>`).join('')}${foot}</div>`;
const A_states = [
  fr({ s: '默认' }, st(blankMenuImport()), '空白处右键 / 更多菜单里一项，带 Ctrl U'),
  fr({ s: '拖入悬停' }, st(dropOverlay('松手导入 3 个文件', '图片 2 · 视频 1 · 落在松手处')), '系统拖进舞台：琥珀虚线覆盖，点数'),
  fr({ s: '拖入不可接' }, st(dropOverlay('没有可导入的文件', '只收 png / jpg / webp / mp4 / mov / webm', T.fg5, T.s3)), '全是不支持的：灰覆盖，松手无事'),
  fr({ s: '进行中' }, st(mc(36, 6, 84, '船桨.mp4', `${img(IMG.mountain, 'opacity: .3')}${prog(48)}`, { status: '复制中', statusColor: T.accent })), '节点即建，status = uploading'),
  fr({ s: '完成' }, st(mc(36, 6, 84, '雾江.jpg', `${img(IMG.wide)}${badge}`, { status: '导入 · 1920×1080' })), '产物节点带「导入」徽标，无来源配置'),
  fr({ s: '出错' }, st(mc(36, 6, 84, '雾江.jpg', `<div style="position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; color: ${T.danger}">${ic('error', 10)}<span style="font-size: 7px">复制失败</span></div>`, { status: `<span style="color: ${T.danger}">出错</span> · <span style="color: ${T.accent}">重试</span>`, outline: `1px solid ${T.danger}` })), '卡上原地报错，可重试 / 删除'),
  fr({ s: '禁用' }, st(blankMenuImport(false, true)), '没打开画布时 ⌘K 里置灰写原因'),
];
const A_flow = [
  fr({ n: 1 }, st(blankMenuImport(true)), 'Ctrl/⌘ U，或右键「导入媒体…」'),
  fr({ n: 2 }, st(osDialog(18, 6, [['雾江.jpg', 1], ['远山.png', 1], ['船桨.mp4', 1], ['notes.pdf', 0]])), 'file_selector openFiles 多选，两组扩展名'),
  fr({ n: 3 }, st(`${mc(8, 8, 42, '雾江.jpg', prog(30))}${mc(56, 14, 42, '远山.png', prog(64))}${mc(104, 8, 42, '船桨.mp4', prog(12))}`), '视口中心散布建 uploading 节点'),
  fr({ n: 4 }, st(mc(36, 6, 84, '船桨.mp4', `${img(IMG.mountain)}${badge}<div style="position: absolute; right: 2px; bottom: 2px; font-family: ${MONO}; font-size: 6px; color: ${T.fg1}; background: ${T.s4}; padding: 0 2px; border-radius: 2px">00:06</div>`, { status: '导入 · 首帧 · 6.0s' })), `复制进 ${code('imports/')}；视频抽首帧、写 duration_ms`),
  fr({ n: 5 }, st(mtoast(8, 16, 140, 'success', T.success, '已导入 3 个文件', '图片 2 · 视频 1', '撤销')), '一次导入一张通知，带撤销'),
  fr({ n: '6' }, st(`${dropOverlay('松手导入 1 个文件', '落在松手处')}${ptr(96, 34)}`), '另一入口：系统拖入，节点落在松手处'),
  fr({ n: '7' }, st(`${mc(52, 8, 70, '粘贴的图片', `${img(IMG.wide)}${badge}`, { status: '导入 · 1280×720' })}${ptr(118, 40)}`), 'Ctrl/⌘ V 剪贴板图片：鼠标在舞台则落鼠标处'),
];
const A_edge = [
  fr({ e: '格式不支持' }, st(mtoast(8, 16, 140, 'warning', T.accent, '已导入 2 个文件', '跳过 notes.pdf：不是图片或视频', '撤销')), '点名跳过，不建节点'),
  fr({ e: '文件过大' }, st(mtoast(8, 16, 140, 'warning', T.accent, '跳过 1 个文件', '素材.mov 超过大小上限', '')), need('上限值待定；超限点名跳过')),
  fr({ e: '落盘失败' }, st(mtoast(8, 12, 140, 'error', T.danger, '导入失败：磁盘空间不足', '雾江.jpg · 已删掉半截文件', '重试')), '先写 .partial 再改名；失败卡不自动消失'),
  fr({ e: '部分失败' }, st(`${mc(8, 6, 40, '雾江.jpg', `${img(IMG.wide)}${badge}`)}${mtoast(54, 18, 96, 'warning', T.accent, '导入 2 个 · 1 个失败', '', '查看')}`), '成功的留下；「查看」列失败原因'),
  fr({ e: '取消' }, st(`${mc(36, 4, 84, '船桨.mp4', `${img(IMG.mountain, 'opacity: .3')}${prog(48)}`, { status: '复制中 · Esc / 删除 = 中止', statusColor: T.accent })}`), '选择框取消无事；复制中删节点即中止'),
  fr({ e: '撤销' }, st(mtoast(8, 16, 140, 'undo', T.fg3, '已撤销导入 3 个文件', '文件留给孤儿扫描（只记日志）', '')), '撤销删节点，不删 imports/ 文件'),
  fr({ e: 'mac / Win' }, ui(`${lbl(6, 5, 'macOS', T.fg2)}${lbl(6, 15, 'Finder 拖入 · ⌘V · 截图 ⌃⇧⌘4 = PNG')}${lbl(6, 31, 'Windows', T.fg2)}${lbl(6, 41, '管理员运行时系统拦拖入 → 提示 Ctrl U')}`), '剪贴板里是文件时按导入文件走'),
];

// ====================================================================
// B：从左栏拖进画布
// ====================================================================
const railStrip = (o = {}) => `
  <div style="position: absolute; left: 0; top: 0; bottom: 0; width: 52px; background: ${T.s4}; border-right: 1px solid ${T.bStrong}">
    <div style="height: 11px; padding: 0 4px; font-size: 7px; font-weight: 500; color: ${T.fg1}; display: flex; align-items: center">素材</div>
    <div style="margin: 0 4px; width: 44px; height: 25px; border-radius: 2px; overflow: hidden; ${o.drag ? `outline: 1px dashed ${T.control}; opacity: .35` : o.hov ? `outline: 1px solid ${T.fg5}` : `outline: 1px solid ${T.outline}`}">${img(IMG.wide)}</div>
    <div style="font-size: 6px; color: ${T.fg6}; padding: 1px 4px 0">远山参考</div>
    <div style="height: 14px; margin-top: 2px; display: flex; align-items: center; gap: 3px; padding: 0 4px; ${o.charDrag ? 'opacity: .35' : ''}"><img src="${IMG.thumbMountain}" alt="" style="width: 9px; height: 9px; border-radius: 5px; object-fit: cover"><span style="font-size: 7px; color: ${T.fg2}">渔夫</span></div>
  </div>`;
const cfg = (x, y, o = {}) => mc(x, y, o.w || 74, '镜头 02 · 江上孤舟', txt('江面雾气渐散，渔夫撑船缓缓驶出画面。'), Object.assign({ type: '视频' }, o));
const dropMenu = (x, y, onIdx = 0) => mmenu(x, y, 82, [
  { head: '放到「镜头 02」' }, { t: '当参考', dot: T.sky, on: onIdx === 0 }, { t: '替换首帧', dot: T.teal, on: onIdx === 1 }, { t: '当尾帧', dot: T.peach, off: true, sub: '不支持' },
]);
const B_states = [
  fr({ s: '默认' }, st(railStrip()), '素材格 / 角色行，点 = 定位（现有）'),
  fr({ s: '悬停' }, st(`${railStrip({ hov: true })}${tip(58, 10, '拖进画布 · 点击定位')}`), '格子描边提亮，光标变抓手'),
  fr({ s: '拖动中' }, st(`${railStrip({ drag: true })}${ghost(80, 22)}${ptr(110, 36)}`), '原位 35% 虚线，缩略跟手'),
  fr({ s: '落空白' }, st(`${railStrip({ drag: true })}${dash(66, 12, 70, 36, '建导入节点')}${ghost(84, 22)}`), '舞台空白处虚线占位'),
  fr({ s: '落配置' }, st(`${railStrip({ drag: true })}${cfg(62, 4, { outline: `1px dashed ${T.accent}` })}${ghost(96, 24)}`), '配置卡琥珀虚线描边'),
  fr({ s: '不可放' }, st(`${railStrip({ drag: true })}${mc(62, 4, 74, 'take 2', img(IMG.mountain))}${ghost(96, 24)}`), '产物卡不高亮，松手按空白处理'),
];
const B_flow = [
  fr({ n: 1 }, st(`${railStrip({ hov: true })}${ptr(30, 20)}`), '按下素材格'),
  fr({ n: 2 }, st(`${railStrip({ drag: true })}${ghost(66, 20)}${ptr(96, 34)}`), '拖过 4px 才起拖，缩略跟手'),
  fr({ n: 3 }, st(`${railStrip({ drag: true })}${cfg(62, 4, { outline: `1px dashed ${T.accent}` })}${ghost(96, 24)}`), '悬在「镜头 02」上，卡高亮'),
  fr({ n: 4 }, st(`${cfg(4, 4)}${dropMenu(66, 4, 1)}`), '松手弹菜单，只列合法项，不支持的置灰'),
  fr({ n: 5 }, st(`${cfg(40, 4, { status: '万相 2.2 · 首帧已替换' })}${lbl(6, 50, '首帧边 replaceRoleEdge', T.teal)}`), '选「替换首帧」：旧首帧边换掉'),
  fr({ n: 6 }, st(mtoast(8, 16, 140, 'undo', T.fg3, '已替换「镜头 02」的首帧', '', '撤销')), '一次撤销复原旧首帧'),
  fr({ n: 7 }, st(`${railStrip({ charDrag: true })}${cfg(62, 4, { status: '角色 渔夫 · 已挂载', statusColor: T.accent })}`), '角色行拖到配置：直接追加 character_ids'),
];
const B_edge = [
  fr({ e: 'Esc 取消' }, st(`${railStrip()}${lbl(62, 26, '缩略回弹，什么都不建', T.fg4)}`), '拖动中 Esc / 拖回左栏松手'),
  fr({ e: '跨画布' }, st(`${mc(36, 6, 84, '远山参考', `${img(IMG.wide, 'opacity: .3')}${prog(40)}`, { status: '从「第二场」复制中', statusColor: T.accent })}`), '项目全部里别画布的：先复制进 imports/'),
  fr({ e: '同画布' }, st(`${mc(8, 8, 62, '远山参考', img(IMG.wide), { status: '原节点' })}${mc(86, 8, 62, '远山参考', `${img(IMG.wide)}${badge}`, { status: '新 · 同一文件' })}`), '新节点指向同一文件，不复制'),
  fr({ e: '视频素材' }, st(`${cfg(40, 4)}${ghost(70, 22, 34, IMG.mountain)}${lbl(6, 50, '视频素材 · 菜单不弹', T.fg4)}`), '视频没有合法项：菜单不弹，按落空白处理'),
  fr({ e: '超配额' }, st(mtoast(8, 14, 140, 'warning', T.accent, '已挂载「渔夫」', '参考图超出 4 张：截掉渔夫 2 张', '')), 'ref_image_budget 点名截掉几张'),
  fr({ e: '已挂载' }, st(`${cfg(40, 4, { status: '渔夫 已在这个节点上' })}`), '同一角色再拖：不重复，状态行点一句'),
  fr({ e: '落进泳道' }, st(`<div style="position: absolute; left: 0; right: 0; top: 10px; height: 40px; background: ${T.s4}; border-top: 1px solid ${T.laneDivider}; border-bottom: 1px solid ${T.laneDivider}"></div>${lbl(4, 12, '泳道 · 黄昏')}${mc(60, 14, 50, '远山参考', `${img(IMG.wide)}${badge}`)}`), '新节点写 laneId，同 resolveLaneDrop'),
];

// ====================================================================
// C：提示词里 @角色
// ====================================================================
const C_states = [
  fr({ s: '默认' }, st(pbar(6, 36, 144, `雾江上一叶孤舟，${mention('渔夫')} 站在船头`)), '标签 = 头像 + 名，琥珀浅底'),
  fr({ s: '弹层' }, st(`${pop(36, 2, 112, `${pick('渔夫', '3 张', true, '已挂载')}${pick('老渔翁', '1 张', false, '', IMG.thumbWide)}`)}${pbar(6, 36, 144, `孤舟，<span style="color: ${T.accent}">@</span>${caretBar}`)}`), '输入 @ 弹出；已挂载的排前面'),
  fr({ s: '筛选' }, st(`${pop(36, 10, 112, `${pick(`${hl('渔')}夫`, '3 张', true, '已挂载')}${pick(`老${hl('渔')}翁`, '1 张', false, '', IMG.thumbWide)}`)}${pbar(6, 40, 144, `孤舟，<span style="color: ${T.accent}">@渔</span>${caretBar}`)}`), '打字筛选，命中字高亮'),
  fr({ s: '无匹配' }, st(`${pop(36, 6, 112, `<div style="height: 12px; padding: 0 4px; font-size: 7px; color: ${T.fg5}; display: flex; align-items: center">没有叫「渔x」的角色</div><button type="button" style="height: 12px; padding: 0 4px; font-size: 8px; color: ${T.fg3}; display: flex; align-items: center; gap: 3px">${ic('characters', 8)}从图片新建角色…</button>`)}${pbar(6, 40, 144, `<span style="color: ${T.accent}">@渔x</span>${caretBar}`)}`), '空态带新建入口'),
  fr({ s: '项目无角色' }, st(`${pop(36, 6, 112, `<div style="height: 12px; padding: 0 4px; font-size: 7px; color: ${T.fg5}; display: flex; align-items: center">项目里还没有角色</div><button type="button" style="height: 12px; padding: 0 4px; font-size: 8px; color: ${T.fg3}; display: flex; align-items: center; gap: 3px">${ic('characters', 8)}从图片新建角色…</button>`)}${pbar(6, 40, 144, `<span style="color: ${T.accent}">@</span>${caretBar}`)}`), '同一新建路（createCharacterFromFile）'),
  fr({ s: '光标贴标签' }, st(pbar(6, 36, 144, `孤舟，${mention('渔夫', false, true)}${caretBar} 站在`)), '退格前整块描实，提示会整块删'),
  fr({ s: '角色已删' }, st(pbar(6, 36, 144, `孤舟，${mention('渔夫', true)} 站在船头`)), '标签变灰，发出时去掉'),
];
const C_flow = [
  fr({ n: 1 }, st(pbar(6, 36, 144, `雾江上一叶孤舟，<span style="color: ${T.accent}">@</span>${caretBar}`)), '提示词条 / 检查器提示词框里打 @'),
  fr({ n: 2 }, st(`${pop(36, 10, 112, `${pick(`${hl('渔')}夫`, '3 张', true, '已挂载')}${pick(`老${hl('渔')}翁`, '1 张', false, '', IMG.thumbWide)}`)}${pbar(6, 40, 144, `<span style="color: ${T.accent}">@渔</span>${caretBar}`)}`), '打字筛选；↑↓ 换行'),
  fr({ n: 3 }, st(`${pop(36, 10, 112, `${pick(`${hl('渔')}夫`, '3 张')}${pick(`老${hl('渔')}翁`, '1 张', true, '', IMG.thumbWide)}`)}${pbar(6, 40, 144, `<span style="color: ${T.accent}">@渔</span>${caretBar}`)}`), '↵ / Tab 插入；Esc 收起'),
  fr({ n: 4 }, st(`${pbar(6, 6, 144, `孤舟，${mention('老渔翁')}${caretBar}`)}${lbl(8, 32, '检查器 · 角色', T.fg5)}${lbl(8, 42, '渔夫 · 老渔翁 <span style="color: ' + T.accent + '">新挂载</span>', T.fg2)}`), `存 ${code('@{角色 id}')}，同时追加 character_ids`),
  fr({ n: 5 }, ui(`${lbl(6, 6, '发给模型的提示词', T.fg5)}<div style="position: absolute; left: 6px; right: 6px; top: 17px; font-family: ${MONO}; font-size: 7px; line-height: 1.4; color: ${T.fg3}">…a lone boat, 老渔翁 stands…<br>Character 老渔翁: weathered…</div>`), '记号换成角色名；描述按 character_ids 注入'),
];
const C_edge = [
  fr({ e: 'Esc' }, st(pbar(6, 36, 144, `孤舟，<span style="color: ${T.fg1}">@渔</span>${caretBar}`)), '收起弹层，文字留作纯文字「@渔」'),
  fr({ e: '退格删' }, st(`${pbar(6, 6, 144, `孤舟，${caretBar} 站在船头`)}${lbl(8, 32, '检查器 · 角色', T.fg5)}${lbl(8, 42, '渔夫 · 老渔翁（仍挂载）', T.fg2)}`), '整块删，不卸载（IS-Q3 → A）'),
  fr({ e: '跨项目粘贴' }, st(pbar(6, 36, 144, '孤舟，@渔夫 站在船头')), '角色没跟过来：降纯文字，剔出 character_ids'),
  fr({ e: '项目包导入' }, ui(`<div style="position: absolute; left: 6px; right: 6px; top: 10px; font-family: ${MONO}; font-size: 7px; line-height: 1.6; color: ${T.fg4}">@{c_81f2…}<br><span style="color: ${T.accent}">→ @{c_3a07…}</span></div>${lbl(6, 44, 'import_remapper · characterMap')}`), '记号与 character_ids 同一张表换新 id'),
  fr({ e: '输入法组字' }, st(`${pbar(6, 36, 144, `<span style="color: ${T.accent}">@</span><span style="text-decoration: underline; color: ${T.fg2}">yu</span>${caretBar}`)}${lbl(8, 14, '组字中 ↵ = 上屏，不插入')}`), 'mac / Win 拼音组字结束才筛选'),
  fr({ e: '超配额' }, st(mtoast(8, 14, 140, 'warning', T.accent, '已挂载「老渔翁」', '参考图超出：截掉 1 张', '')), '插入即挂载，配额照 ref_image_budget'),
];

// ====================================================================
// D：画布内查找
// ====================================================================
const hitCards = (cur = 1, dim = true) => `
  ${mc(4, 22, 46, '镜头 01', txt(`拂晓，${hl('雾江')}上一叶孤舟`, 6), { outline: `1px solid ${cur === 0 ? T.accent : T.washBorder}` })}
  ${mc(55, 22, 46, `${hl('雾江')}.jpg`, img(IMG.wide), { outline: cur === 1 ? `2px solid ${T.accent}` : `1px solid ${T.washBorder}` })}
  ${mc(106, 22, 46, '镜头 03', txt('远山一层层浮出来', 6), { extra: dim ? 'opacity: .35' : '' })}`;
const D_states = [
  fr({ s: '打开' }, st(findbar(20, 3, 116, '', '')), '空输入只有占位，不出计数'),
  fr({ s: '有结果' }, st(`${findbar(20, 3, 116, '雾江', '2 / 2')}${hitCards(1)}`), '命中淡琥珀描边，当前实色'),
  fr({ s: '其余降暗' }, st(`${findbar(20, 3, 116, '雾江', '2 / 2', { caret: false })}${hitCards(1)}`), '未命中降到 35%'),
  fr({ s: '无结果' }, st(`${findbar(20, 3, 116, '雾江x', '无结果', { countColor: T.danger, off: true })}${mc(30, 22, 46, '镜头 01', txt('拂晓，雾江上', 6))}${mc(82, 22, 46, '镜头 03', txt('远山一层层', 6))}`), '计数写「无结果」，↑↓ 置灰，卡不降暗'),
  fr({ s: '聚焦' }, st(findbar(20, 3, 116, '雾江', '2 / 2', { border: T.accent })), '输入框持焦，焦点环琥珀'),
  fr({ s: '禁用' }, ui(`${lbl(6, 6, '空画布 · Ctrl F', T.fg2)}${lbl(6, 18, '不弹查找条（空画布引导在场）')}${lbl(6, 34, '⌘K 对话框开着', T.fg2)}${lbl(6, 46, '不响应：对话框在上层')}`), '这两处不接管'),
];
const D_flow = [
  fr({ n: 1 }, st(`${findbar(20, 3, 116, '', '')}${lbl(36, 30, '浮在工具条下方居中')}`), 'Ctrl/⌘ F 打开，焦点进输入框'),
  fr({ n: 2 }, st(`${findbar(20, 3, 116, '雾江', '1 / 2')}${hitCards(0)}`), '输入即搜，跳到第一个'),
  fr({ n: 3 }, st(`${findbar(20, 3, 116, '雾江', '2 / 2')}${hitCards(1)}`), '↵ 下一个：单选 + 保持缩放居中'),
  fr({ n: 4 }, st(`${findbar(20, 3, 116, '雾江', '1 / 2')}${hitCards(0)}`), 'Shift ↵ 上一个，首尾循环'),
  fr({ n: 5 }, st(`${mc(55, 10, 46, '雾江.jpg', img(IMG.wide), { outline: `1px solid ${T.accent}` })}${lbl(6, 46, '查找条已关 · 选中留在当前')}`), 'Esc 关闭，降暗撤掉'),
];
const D_edge = [
  fr({ e: '编辑文字时' }, st(`${pbar(6, 40, 144, '雾江上一叶')}${findbar(20, 3, 116, '', '')}`), '提示词条里按 ⌘F 也接管，文字框失焦'),
  fr({ e: '命中被删' }, st(`${findbar(20, 3, 116, '雾江', '1 / 1')}${mc(55, 22, 46, '镜头 01', txt(`${hl('雾江')}上一叶`, 6), { outline: `2px solid ${T.accent}` })}`), '计数重算，当前顺到下一个'),
  fr({ e: '折叠泳道' }, st(`${findbar(20, 3, 116, '雾江', '2 / 3')}${lbl(6, 28, '泳道 · 黄昏（已折叠）', T.fg4)}`), need('命中在折叠道：先展开再居中')),
  fr({ e: '与 ⌘K' }, ui(`${lbl(6, 6, 'Ctrl K', T.fg2)}${lbl(40, 6, '跨实体 · 选一个就关')}${lbl(6, 22, 'Ctrl F', T.fg2)}${lbl(40, 22, '只看本画布 · 开着逐个过')}${lbl(6, 40, 'F 单键', T.fg2)}${lbl(40, 40, '仍是泳道，不受影响')}`), '分工不重叠，键不撞'),
  fr({ e: 'mac / Win' }, ui(`${lbl(6, 8, 'macOS', T.fg2)}${lbl(46, 8, '⌘F · ↵ / ⇧↵')}${lbl(6, 26, 'Windows', T.fg2)}${lbl(46, 26, 'Ctrl F · ↵ / Shift ↵')}${lbl(46, 38, need('另认 F3 / Shift F3'))}`), '修饰键随平台，显示同 tooltip'),
  fr({ e: 'Esc 层级' }, ui(`<div style="position: absolute; left: 6px; right: 6px; top: 8px; font-size: 7px; line-height: 1.6; color: ${T.fg4}">菜单 › @ 弹层 › <span style="color: ${T.accent}">查找条</span> › 框选中 › 工具锁 › 清空选中</div>`), '一次只收一层'),
];

// ====================================================================
// E：小地图 · 回到内容
// ====================================================================
const E_states = [
  fr({ s: '收起' }, st(zbar(6, 40)), '默认收起，末格未亮'),
  fr({ s: '悬停' }, st(`${zbar(6, 40, 'hover')}${tip(52, 22, '小地图 M')}`), 'tooltip「小地图  M」'),
  fr({ s: '展开' }, st(`${mmap(6, 6)}${zbar(6, 40, 'on')}`), '贴缩放条正上方同宽，末格亮'),
  fr({ s: '拖框中' }, st(`${mmap(6, 6, 30, 14, { drag: true })}${zbar(6, 40, 'on')}`), '视口框浅琥珀底跟手'),
  fr({ s: '空画布' }, st(`${zbar(6, 40, 'dis')}${lbl(40, 14, '空画布引导在场', T.fg4)}`), '末格置灰，「回到内容」不出'),
  fr({ s: '回到内容' }, st(`${chipFit(38, 6)}${zbar(6, 40, 'off')}`), '视口里没节点、平移停 300ms 后出现'),
  fr({ s: '胶囊悬停' }, st(`${chipFit(38, 6, true)}${zbar(6, 40, 'off')}`), '底色提亮；点 = 适应全部'),
];
const E_flow = [
  fr({ n: 1 }, st(`${zbar(6, 40, 'hover')}${ptr(70, 46)}`), '按 M 或点缩放条末格'),
  fr({ n: 2 }, st(`${mmap(6, 6)}${zbar(6, 40, 'on')}`), '展开；开合记在 preferences.json'),
  fr({ n: 3 }, st(`${mmap(6, 6, 8, 4)}${ptr(20, 14)}${zbar(6, 40, 'on')}`), '点地图某处：视口跳过去'),
  fr({ n: 4 }, st(`${mmap(6, 6, 30, 14, { drag: true })}${ptr(44, 22)}${zbar(6, 40, 'on')}`), '拖视口框 = 平移；滚轮不缩放'),
  fr({ n: 5 }, st(`${chipFit(38, 6)}${zbar(6, 40)}`), '平移到空处，停 300ms 胶囊出现'),
  fr({ n: 6 }, st(`${mc(30, 4, 44, '镜头 01', txt('拂晓', 6))}${mc(80, 4, 44, '镜头 02', txt('孤舟', 6))}${zbar(6, 40)}`), '点胶囊 = 适应全部（同 Shift 1），胶囊消失'),
];
const E_edge = [
  fr({ e: '查找条开着' }, st(`${findbar(20, 3, 116, '雾江', '无结果', { countColor: T.danger, off: true })}${zbar(6, 40)}`), '「回到内容」让位不出'),
  fr({ e: '提示词条' }, st(`${mmap(6, 6)}${zbar(6, 40, 'on')}${pbar(104, 40, 48, '')}`), '小地图只贴缩放条，现有避让不改'),
  fr({ e: '窄画布' }, st(`${zbar(6, 40, 'on')}${pbar(6, 20, 144, '画布窄于 512')}`), need('提示词条贴边时自动收起小地图')),
  fr({ e: '滚轮' }, st(`${mmap(6, 6)}${ptr(30, 16)}${zbar(6, 40, 'on')}${lbl(104, 12, '吞掉，不穿透', T.fg4)}`), '在小地图上滚轮不缩放、不平移'),
  fr({ e: '超大画布' }, st(`${mmap(6, 6, 70, 18, { vw: 6, vh: 6 })}${zbar(6, 40, 'on')}`), '视口框最小画 6px，仍可拖'),
  fr({ e: '换画布' }, ui(`${lbl(6, 8, '画布 A 展开小地图', T.fg2)}${lbl(6, 22, '→ 打开画布 B')}${lbl(6, 36, '仍展开（全局开关，不按画布）', T.fg4)}`), '开合是全局偏好'),
];

// ====================================================================
// F：工具锁 · 便签
// ====================================================================
const F_states = [
  fr({ s: '默认' }, st(tbar(4, 6)), `工具条现有键 + ${neu}便签 N`),
  fr({ s: '悬停' }, st(`${tbar(4, 6, 'hov')}${tip(20, 26, '图像节点  I · 双击锁定')}`), 'tooltip 多一句「双击锁定」'),
  fr({ s: '已锁定' }, st(`${tbar(4, 6, 'lock', '')}${tag(4, 26, `图像节点 · 已锁定 ${kbd('Q 解锁')}`)}`), '琥珀底 + 角标钉；舞台左上提示'),
  fr({ s: '点放预览' }, st(`${tbar(4, 6, 'lock', '')}${dash(40, 26, 54, 30, `${ic('imageConfig', 9)}点一下放一个`)}`), '光标处虚线框跟手'),
  fr({ s: '便签' }, st(`${note(10, 8, 60, 44, '第二场改成黄昏？问导演')}${note(86, 8, 60, 44, '空镜备用', { bg: T.s4, border: T.control })}`), '三种底色；无端口'),
  fr({ s: '就地编辑' }, st(note(30, 8, 96, 44, `雨夜的城市，霓虹倒影${caretBar}`, { extra: `outline: 1px solid ${T.accent}; outline-offset: -3px` })), '双击卡进入；检查器正文只读跟随'),
  fr({ s: '空便签' }, st(note(30, 8, 96, 44, '写点什么…', { color: T.fg6 })), '占位字，不占提示词'),
];
const F_flow = [
  fr({ n: 1 }, st(`${tbar(4, 6, 'lock', '')}${ptr(42, 18)}`), '双击「图像」或选中后按 Q：锁定'),
  fr({ n: 2 }, st(`${tbar(4, 6, 'lock', '')}${mc(36, 26, 40, '图像 1', '')}`), '点空白处：在点处建一个'),
  fr({ n: 3 }, st(`${tbar(4, 6, 'lock', '')}${mc(36, 26, 40, '图像 1', '')}${mc(96, 26, 40, '图像 2', '')}`), '再点再建，仍锁定'),
  fr({ n: 4 }, st(`${tbar(4, 6)}${mc(36, 26, 40, '图像 1', '')}${mc(96, 26, 40, '图像 2', '')}`), 'V / Esc / 换工具：解锁回选择'),
  fr({ n: 5 }, st(`${note(48, 10, 60, 40, '')}${lbl(52, 52, '视口中心', T.fg5)}`), 'N 建便签（锁定时改为点放）'),
  fr({ n: 6 }, st(note(30, 8, 96, 44, `第二场改成黄昏${caretBar}`, { extra: `outline: 1px solid ${T.accent}; outline-offset: -3px` })), '双击就地编辑，防抖写 type_config.text'),
  fr({ n: 7 }, st(`${note(30, 8, 96, 32, '第二场改成黄昏？问导演')}${lbl(30, 46, '已保存 · 画布已重载', T.success)}`), '失焦再写一笔并重载，与检查器同链'),
];
const F_edge = [
  fr({ e: '点到卡上' }, st(`${tbar(4, 6, 'lock', '')}${mc(40, 26, 50, '镜头 01', '', { outline: `1px solid ${T.accent}` })}`), '锁定中点已有卡：选中它，不建'),
  fr({ e: '按住空格' }, st(`${tbar(4, 6, 'lock', '')}${tag(4, 28, '平移中 · 松开仍锁定')}`), '空格临时平移，与 canvasSpacePan 同'),
  fr({ e: '右键 / Tab' }, st(`${tbar(4, 6, 'lock', '')}${mmenu(40, 22, 76, [{ t: '新建…', k: 'Tab' }, { t: '全选' }])}`), '菜单优先；关菜单回到锁定'),
  fr({ e: '连线' }, st(`${note(10, 8, 54, 40, '问导演')}${mc(96, 8, 50, '镜头 01', '')}<div style="position: absolute; left: 66px; top: 28px; width: 28px; height: 0; border-top: 1px dashed ${T.fg6}"></div>${lbl(66, 40, '不可接', T.danger)}`), '便签无端口；不进提示词和大纲'),
  fr({ e: '写入失败' }, ui(`${lbl(6, 8, '检查器底部', T.fg5)}<div style="position: absolute; left: 6px; right: 6px; top: 22px; height: 14px; display: flex; align-items: center; gap: 4px; font-size: 8px; color: ${T.danger}">${ic('error', 9)}<span>未保存</span><span style="flex: 1"></span><button type="button" style="font-size: 8px; color: ${T.accent}">重试</button></div>`), '沿用 InspectorAutoSaveRow，退出前冲刷'),
  fr({ e: '撤销' }, st(note(30, 8, 96, 44, `第二场改成${caretBar}`, { extra: `outline: 1px solid ${T.accent}; outline-offset: -3px` })), '就地编辑中 Ctrl/⌘ Z 归文本框'),
  fr({ e: 'mac / Win' }, ui(`${lbl(6, 8, '双击间隔跟系统设置', T.fg2)}${lbl(6, 22, 'macOS 触控板轻点两下 = 双击')}${lbl(6, 38, '单键只在画布持焦、不在文字里', T.fg4)}`), '双击锁定 / 就地编辑同一判定'),
];

// ---------- 本板取的决定 ----------
const dItem = (k, v) => `<div style="font-size: 11px; line-height: 1.5; color: ${T.fg3}"><span style="color: ${T.accent}; font-family: ${MONO}; font-size: 10px">${k}</span> ${v}</div>`;
const decided = `
  <div style="background: ${T.wash}; border: 1px solid ${T.washBorder}; border-radius: 6px; padding: 10px 18px 12px">
    <div style="font-weight: 500; color: ${T.accent}; margin-bottom: 6px">本板取的决定</div>
    <div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 2px 32px">
      ${dItem('IS-Q1 → A', 'desktop_drop + pasteboard（阻塞，按建议）')}
      ${dItem('IS-Q3 → A', '插入即挂载，删标签不卸载（阻塞，按建议）')}
      ${dItem('IS-Q5 → A', 'variant = note，不迁移（阻塞，按建议）')}
      ${dItem('IS-Q4 → A', '工具锁做，Q + 双击工具按钮（默认）')}
      ${dItem('IS-Q2 → A', '别画布素材复制进本画布 imports/')}
      ${dItem('IS-Q6 → A', '导入的视频不入叙事链，只当首帧 / 参考')}
    </div>
  </div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45; padding: 24px 32px; box-sizing: border-box; display: flex; flex-direction: column; gap: 10px">
  <div>
    <div style="display: flex; align-items: baseline; gap: 14px">
      <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">导入、拖放与查找 · 状态与流程</div>
      <div style="color: ${T.fg4}">b2 六个功能逐个展开：状态条 / 主流程分帧 / 边界帧</div>
    </div>
    <div style="font-size: 11px; color: ${T.fg5}; margin-top: 4px">按建议：IS-Q1 → A（desktop_drop + pasteboard）、IS-Q3 → A（插入即挂载）、IS-Q5 → A（variant = note，不迁移）、IS-Q4 工具锁做。标「新」/「需：」的是没上线或待定的部分。</div>
  </div>
  ${block('导入媒体', 'Ctrl U · 拖入文件 · Ctrl V 粘贴图片',
    `尚无导入命令与拖放 / 剪贴板读图。file_selector 的 ${code('openFile')} 只在 character_library_panel.dart（createCharacterFromFile，单选 png / jpg / jpeg / webp / bmp / gif）、characters_section、character_edit_dialog、project_archive 用；nodes.status 已有 uploading 档。`,
    [row('状态', A_states), row('流程', A_flow), row('边界', A_edge)])}
  ${divider}
  ${block('从左栏拖进画布', '素材格、角色行都能拖',
    `left_rail/assets_panel.dart 的 _AssetTile 只有 onTap（定位），character_library_panel.dart 的 CharacterLibraryRow 点 = 编辑；左栏无 Draggable、舞台无 DragTarget（只 character_edit_dialog 参考图排序用过）。落点复用 drop_placement.dart 的 resolveLaneDrop。`,
    [row('状态', B_states), row('流程', B_flow), row('边界', B_edge)])}
  ${divider}
  ${block('提示词里 @角色', '提示词条和检查器的提示词框都有',
    `尚无。canvas_prompt_bar.dart 与检查器提示词框是纯文本框；挂载走 characters_section.dart 写 character_ids，generation_controller 按其顺序注入角色描述；角色行文案「N 张参考图 · M 处引用」照现有。`,
    [row('状态', C_states), row('流程', C_flow), row('边界', C_edge)])}
  ${divider}
  ${block('画布内查找', 'Ctrl/⌘ F，和 Ctrl K 分开',
    `尚无。⌘K 在 command_palette/（command_palette_dialog.dart：镜头 · 当前画布 / 产物 / 动作三组，↵ 打开、⌘↵ 定位、选一个就关）；单键 F 已是泳道（CanvasToolKeys.lane），Ctrl/⌘ F 不撞；居中复用 viewport_focus.dart。`,
    [row('状态', D_states), row('流程', D_flow), row('边界', D_edge)])}
  ${divider}
  ${block('小地图 · 回到内容', '都在画布角落，不占工具条',
    `canvas_zoom_bar.dart 现有 缩小 / 百分比 / 放大 / 适应（fitAllNodes）四格，无小地图格；InkGlyph.minimap 已在图标集；Shift 1 适应全部已有；「回到内容」胶囊尚无。`,
    [row('状态', E_states), row('流程', E_flow), row('边界', E_edge)])}
  ${divider}
  ${block('工具锁 · 便签', '两个 P2 小工具',
    `canvas_tool_mode.dart 只有 select / pan + 按住空格；canvas_toolbar.dart 一按就在视口中心建节点，无锁、无便签键；text_node_inspector.dart 正文框走 InspectorSubmitController.saveDebounced，失焦写一笔并重载——便签与就地编辑沿用这条链。`,
    [row('状态', F_states), row('流程', F_flow), row('边界', F_edge)])}
  ${decided}
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'ImportSearchDetail.dc.html', html: page('导入、拖放与查找 · 状态与流程', W, H, body, logic), W, H };
