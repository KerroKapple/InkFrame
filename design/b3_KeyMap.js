// 第三批细化画板：快捷键总表 · 状态与流程（1280×H，静态）
// 对应第二批画板 b2_keys.js（KeyMap.dc.html，原标题「快捷键总表与冲突规则」）。
// 每个功能一节：状态条 / 流程帧（①②③④）/ 边界帧；mac（⌘）/ Windows（Ctrl）差异单独一节。
// 现状核对：lib/features/canvas/widgets/canvas_shortcuts.dart（kCanvasShortcuts、CanvasToolKeys、_escape、
// _EditingAwareAction、_CanvasFocusedAction、_onTopRoute、按住空格 onKeyEvent）、
// lib/features/settings/util/shortcut_catalog.dart（buildShortcutRows、formatShortcutActivator、kOverlayDismissActivator——
// 这个常量在 settings/util 里，不在 theme 层）、lib/features/settings/widgets/shortcuts_section.dart、
// lib/features/command_palette/palette_activators.dart + widgets/command_palette_dialog.dart、
// lib/features/canvas/widgets/canvas_prompt_bar.dart（⌘↵ / Ctrl+↵ 的 CallbackShortcuts）、
// lib/features/canvas/util/create_menu_model.dart（nextNarrativeSortOrder）。
//
// 按建议走的决定：KM-Q1 与 GC-N3 冲突（锚点已有下一镜时按 Ctrl →）选 GC-N3 的 A——开分叉，
// 排在已有分叉之后，与 nextNarrativeSortOrder 和新建菜单「下一镜」一致；要插中间就拖到线上插入。
// 原画板「需要你定」其余各项按建议画：Q1 A（继承范围）、Q2 A、Q3 A、Q4 B、Q5 B、Q6 A。
const { T, SANS, MONO, page, ic } = require('./common.js');

// ---------- 版式常量（所有块都是定高，H 由此精确累加）----------
const W = 1280;
const PAD = 24;
const CW = W - PAD * 2; // 1232
const GAP = 8; // 帧之间
const FH = 112; // 帧高
const MOCK_H = 46; // 帧内样稿高
const SEC_HEAD = 24;
const SEC_GAP = 16;
const HEADER_H = 100;
// 各节的行数（左右半宽的那一节按一节算）
const SECTION_ROWS = [2, 3, 2, 3, 2, 2, 2];
const sectionH = (rows) => SEC_HEAD + 8 + rows * FH + (rows - 1) * GAP;
const H = PAD + HEADER_H + SECTION_ROWS.reduce((s, r) => s + SEC_GAP + sectionH(r), 0) + PAD + 40;

const fw = (n, total = CW) => Math.floor((total - GAP * (n - 1)) / n);

// ---------- 小件 ----------
const code = (t) => `<span style="font-family: ${MONO}; font-size: 9px; color: ${T.fg3}">${t}</span>`;
const cap = (t, dim = false) => `<span style="display: inline-flex; align-items: center; justify-content: center; height: 15px; min-width: 9px; padding: 0 4px; box-sizing: border-box; border-radius: 3px; background: ${T.s3}; border: 1px solid ${dim ? T.outline : T.control}; border-bottom-color: ${dim ? T.outline : T.controlStrong}; font-family: ${MONO}; font-size: 9px; line-height: 1; color: ${dim ? T.fg6 : T.fg2}; white-space: nowrap">${t}</span>`;
const capDash = (t) => `<span style="display: inline-flex; align-items: center; justify-content: center; height: 15px; padding: 0 4px; box-sizing: border-box; border-radius: 3px; border: 1px dashed ${T.fg6}; font-family: ${MONO}; font-size: 9px; color: ${T.fg5}; white-space: nowrap">${t}</span>`;
const keys = (s, dim = false) => s.split(' ').map((k) => cap(k, dim)).join('');
const arrow = `<span style="color: ${T.fg6}; font-size: 10px">→</span>`;
const txt = (t, color = T.fg3) => `<span style="font-size: 10px; color: ${color}; white-space: nowrap">${t}</span>`;
const kline = (k, result, color = T.fg3) => `<div style="display: flex; align-items: center; gap: 4px; height: 16px">${k}${arrow}${txt(result, color)}</div>`;

const prio = (p) => `<span style="height: 16px; padding: 0 5px; border-radius: 3px; border: 1px solid ${p === 'P1' ? T.washBorder : T.control}; color: ${p === 'P1' ? T.accent : T.fg4}; font-family: ${MONO}; font-size: 10px; display: inline-flex; align-items: center; flex: none">${p}</span>`;
const origin = (s) => s === '现状'
  ? `<span style="height: 14px; padding: 0 4px; border-radius: 3px; border: 1px solid ${T.control}; color: ${T.success}; font-size: 9px; display: inline-flex; align-items: center; flex: none">现状</span>`
  : `<span style="height: 14px; padding: 0 4px; border-radius: 3px; border: 1px solid ${T.washBorder}; background: ${T.wash}; color: ${T.accent}; font-size: 9px; display: inline-flex; align-items: center; flex: none">${s}</span>`;

const STATE_COLOR = {
  默认: T.fg3, 聚焦: T.sky, 进行中: T.accent, 完成: T.success, 出错: T.danger, 禁用: T.fg5, 空态: T.fg5, 让位: T.teal, 无反应: T.fg5,
};
const stateBadge = (s) => `<span style="height: 15px; padding: 0 5px; border-radius: 3px; background: ${T.s5}; color: ${STATE_COLOR[s] || T.fg3}; font-size: 9px; display: inline-flex; align-items: center; flex: none; white-space: nowrap">${s}</span>`;
const numBadge = (n) => `<span style="width: 15px; height: 15px; border-radius: 8px; background: ${T.accent}; color: ${T.onAccent}; font-family: ${MONO}; font-size: 9px; font-weight: 500; display: inline-flex; align-items: center; justify-content: center; flex: none">${n}</span>`;
const edgeBadge = (t = '边界') => `<span style="height: 15px; padding: 0 5px; border-radius: 3px; border: 1px dashed ${T.fg6}; color: ${T.fg4}; font-size: 9px; display: inline-flex; align-items: center; flex: none; white-space: nowrap">${t}</span>`;

// 一帧：badge + 标题 + 来源 | 样稿 | 两行说明
const frame = (w, { badge, title, tag = '', mock, cap: caption, hot = false }) => `
  <div style="width: ${w}px; height: ${FH}px; flex: none; box-sizing: border-box; padding: 6px 8px; border-radius: 4px; background: ${T.s3}; border: 1px solid ${hot ? T.washBorder : T.outline}; display: flex; flex-direction: column; gap: 4px; overflow: hidden">
    <div style="height: 16px; display: flex; align-items: center; gap: 5px; overflow: hidden">
      ${badge}
      <span style="flex: 1; min-width: 0; font-size: 11px; font-weight: 500; color: ${T.fg1}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</span>
      ${tag ? origin(tag) : ''}
    </div>
    <div style="height: ${MOCK_H}px; flex: none; position: relative; overflow: hidden">${mock}</div>
    <div style="font-size: 10px; line-height: 14px; height: 28px; color: ${T.fg4}; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden">${caption}</div>
  </div>`;
const row = (frames, total = CW) => {
  const w = fw(frames.length, total);
  return `<div style="display: flex; gap: ${GAP}px; height: ${FH}px">${frames.map((f) => frame(w, f)).join('')}</div>`;
};
const S = (s, title, tag, o) => Object.assign({ badge: stateBadge(s), title, tag }, o);
const F = (n, title, tag, o) => Object.assign({ badge: numBadge(n), title, tag }, o);
const E = (title, tag, o, label) => Object.assign({ badge: edgeBadge(label), title, tag }, o);

const secHead = (title, p, note) => `
  <div style="height: ${SEC_HEAD}px; display: flex; align-items: center; gap: 8px; overflow: hidden">
    <div style="font-size: 13px; font-weight: 500; color: ${T.fg1}; white-space: nowrap">${title}</div>
    ${prio(p)}
    <div style="flex: 1; min-width: 0; font-size: 10px; color: ${T.fg5}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${note}</div>
  </div>`;
const section = (title, p, note, rows) => `
  <div style="height: ${sectionH(rows.length)}px; flex: none; display: flex; flex-direction: column; gap: 8px">
    ${secHead(title, p, note)}
    <div style="display: flex; flex-direction: column; gap: ${GAP}px">${rows.join('')}</div>
  </div>`;

// ---------- 样稿零件 ----------
const box = (inner, extra = '') => `<div style="position: absolute; inset: 0; box-sizing: border-box; border-radius: 3px; background: ${T.s1}; border: 1px solid ${T.bSubtle}; padding: 5px 6px; ${extra}">${inner}</div>`;
const stack = (lines) => box(`<div style="display: flex; flex-direction: column; gap: 0">${lines.join('')}</div>`);
const stage = (inner) => `<div style="position: absolute; inset: 0; border-radius: 3px; background: ${T.s1}; border: 1px solid ${T.bSubtle}; overflow: hidden">${inner}</div>`;
// 节点卡：mode = '' | sel | new | ghost | dim
const nc = (x, y, label, mode = '', w = 34) => {
  const st = {
    '': `background: ${T.s4}; border: 1px solid ${T.control}; color: ${T.fg3}`,
    sel: `background: ${T.s4}; border: 1px solid ${T.accent}; color: ${T.fg1}`,
    new: `background: ${T.wash}; border: 1px solid ${T.accent}; color: ${T.accent}`,
    ghost: `background: transparent; border: 1px dashed ${T.fg6}; color: ${T.fg6}`,
    dim: `background: ${T.s3}; border: 1px solid ${T.outline}; color: ${T.fg6}`,
    err: `background: transparent; border: 1px dashed ${T.danger}; color: ${T.danger}`,
  }[mode];
  return `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: 16px; box-sizing: border-box; border-radius: 3px; ${st}; font-family: ${MONO}; font-size: 8px; display: flex; align-items: center; justify-content: center; white-space: nowrap">${label}</div>`;
};
const hl = (x, y, w, color = T.fg5, dashed = false) => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: 0; border-top: 1px ${dashed ? 'dashed' : 'solid'} ${color}"></div>`;
const vl = (x, y, h, color = T.fg5) => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: 0; height: ${h}px; border-left: 1px solid ${color}"></div>`;
const capsule = (t, bottom = 3) => `<div style="position: absolute; left: 50%; bottom: ${bottom}px; transform: translateX(-50%); height: 14px; padding: 0 7px; border-radius: 7px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; color: ${T.fg2}; font-size: 8px; display: flex; align-items: center; white-space: nowrap">${t}</div>`;
const field = (t, focused = true, w = '100%') => `<div style="width: ${w}; height: 18px; box-sizing: border-box; border-radius: 3px; background: ${T.s2}; border: 1px solid ${focused ? T.accent : T.control}; display: flex; align-items: center; padding: 0 5px; font-size: 9px; color: ${T.fg2}; white-space: nowrap; overflow: hidden">${t}${focused ? `<span style="color: ${T.accent}; margin-left: 1px">|</span>` : ''}</div>`;
const abs = (x, y, inner) => `<div style="position: absolute; left: ${x}px; top: ${y}px">${inner}</div>`;
const miniMenu = (rows, hi = 0, w = 86) => `<div style="width: ${w}px; box-sizing: border-box; padding: 2px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 8px 20px rgba(0,0,0,0.5)">${rows.map((r, i) => `<div style="height: 12px; padding: 0 4px; border-radius: 2px; font-size: 8px; display: flex; align-items: center; justify-content: space-between; white-space: nowrap; ${i === hi ? `background: ${T.s5}; color: ${T.fg1}` : `color: ${r.startsWith('~') ? T.fg6 : T.fg3}`}">${r.replace(/^~/, '')}</div>`).join('')}</div>`;
const scrim = (inner) => `<div style="position: absolute; inset: 0; background: rgba(0,0,0,0.45); display: flex; align-items: center; justify-content: center">${inner}</div>`;
const dlg = (t, w = 84) => `<div style="width: ${w}px; height: 28px; box-sizing: border-box; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; box-shadow: 0 8px 20px rgba(0,0,0,0.5); font-size: 8px; color: ${T.fg2}; padding: 3px 5px">${t}</div>`;
const miniToast = (kind, t) => {
  const color = { error: T.danger, success: T.success, info: T.fg4, undo: T.fg3 }[kind];
  return `<div style="display: flex; align-items: center; gap: 4px; height: 18px; padding: 0 6px; box-sizing: border-box; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; font-size: 8px; color: ${T.fg2}; white-space: nowrap"><span style="color: ${color}; display: flex">${ic(kind, 11)}</span>${t}</div>`;
};
const tbBtn = (id, on = false, focus = false) => `<span style="width: 16px; height: 16px; border-radius: 3px; display: inline-flex; align-items: center; justify-content: center; ${on ? `background: ${T.wash}; color: ${T.accent}` : `color: ${T.fg4}`}; ${focus ? `outline: 1px solid ${T.accent}` : ''}">${ic(id, 12)}</span>`;
const toolbar = (active, focusIdx = -1) => `<div style="display: inline-flex; gap: 2px; padding: 2px; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}">${['select', 'pan', 'imageConfig', 'videoConfig', 'text', 'lane', 'link'].map((id, i) => tbBtn(id, id === active, i === focusIdx)).join('')}</div>`;
const pill = (n, on) => `<span style="width: 11px; height: 11px; border-radius: 6px; font-family: ${MONO}; font-size: 7px; display: inline-flex; align-items: center; justify-content: center; ${on ? `background: ${T.accent}; color: ${T.onAccent}` : `background: ${T.s5}; color: ${T.fg6}`}">${n}</span>`;
const ladderStage = (on, inner) => `<div style="position: absolute; left: 0; top: 0; height: 11px; display: flex; gap: 2px">${[1, 2, 3, 4, 5, 6, 7].map((i) => pill(i, i === on)).join('')}</div><div style="position: absolute; left: 0; right: 0; top: 14px; bottom: 0">${stage(inner)}</div>`;
const tabsBar = (active) => `<div style="display: flex; gap: 2px; height: 14px">${['工作室', '画布', '序列', '画廊', '导出'].map((t) => `<span style="padding: 0 5px; border-radius: 3px; font-size: 8px; display: flex; align-items: center; ${t === active ? `background: ${T.s5}; color: ${T.fg1}` : `color: ${T.fg5}`}">${t}</span>`).join('')}</div>`;
const setRow = (a, k, head = false) => `<div style="height: 11px; display: flex; align-items: center; justify-content: space-between; font-size: 8px; color: ${head ? T.fg6 : T.fg3}; border-bottom: 1px solid ${T.bSubtle}; white-space: nowrap"><span>${a}</span><span style="font-family: ${MONO}; color: ${head ? T.fg6 : T.fg1}">${k}</span></div>`;
const groupRow = (g) => `<div style="height: 10px; font-size: 7px; color: ${T.accent}; display: flex; align-items: center">${g}</div>`;
const menubar = (on, open = false) => `<div style="display: flex; gap: 2px; height: 13px; align-items: center">${['文件', '编辑', '画布', '节点', '窗口', '帮助'].map((t, i) => `<span style="height: 12px; padding: 0 4px; border-radius: 2px; font-size: 8px; display: inline-flex; align-items: center; ${i === 0 && on ? `outline: 1px solid ${T.accent}; color: ${T.fg1}; background: ${open ? T.s5 : 'transparent'}` : `color: ${T.fg5}`}">${t}</span>`).join('')}</div>`;
const pair = (l, r) => box(`<div style="display: flex; flex-direction: column; gap: 3px">
  <div style="display: flex; align-items: center; gap: 4px; height: 16px"><span style="width: 44px; font-size: 9px; color: ${T.fg5}">Windows</span>${l}</div>
  <div style="display: flex; align-items: center; gap: 4px; height: 16px"><span style="width: 44px; font-size: 9px; color: ${T.fg5}">macOS</span>${r}</div>
</div>`);

// ================= 头部 =================
const header = `
  <div style="height: ${HEADER_H}px; flex: none; display: flex; flex-direction: column; gap: 8px; overflow: hidden">
    <div style="display: flex; align-items: center; gap: 10px; height: 24px">
      <div style="color: ${T.fg3}; display: flex">${ic('shortcuts', 20)}</div>
      <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}; white-space: nowrap">快捷键总表与冲突规则 · 状态与流程</div>
      <div style="color: ${T.fg4}; font-size: 11px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">第三批细化，对应第二批画板「快捷键总表」（${code('KeyMap.dc.html')}）；每个功能一节：状态条、流程帧、边界帧，mac / Windows 差异单独一节</div>
    </div>
    <div style="display: flex; align-items: center; gap: 8px; font-size: 10px; color: ${T.fg5}; height: 16px; white-space: nowrap">
      ${stateBadge('默认')}${stateBadge('聚焦')}${stateBadge('让位')}${stateBadge('进行中')}${stateBadge('完成')}${stateBadge('出错')}${stateBadge('禁用')}<span>状态（只画真有的）</span>
      <span style="width: 8px"></span>${numBadge(1)}<span>流程分步</span>
      <span style="width: 8px"></span>${edgeBadge()}<span>原画板一行规则的边界</span>
      <span style="width: 8px"></span>${origin('现状')}<span>main 已有，照实现画</span>${origin('新增')}<span>照 b2 画板与 plan.md</span>
    </div>
    <div style="height: 44px; box-sizing: border-box; border-radius: 6px; background: ${T.wash}; border: 1px solid ${T.washBorder}; padding: 6px 12px; display: flex; flex-direction: column; justify-content: center; gap: 2px">
      <div style="font-size: 11px; color: ${T.accent}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis"><span style="font-weight: 500">按建议走的决定：KM-Q1 与 GC-N3 冲突选 GC-N3 的 A</span> —— 锚点已有下一镜时按 Ctrl → / ⌘→ 开分叉，排在已有分叉之后（${code('nextNarrativeSortOrder')}，与新建菜单「下一镜」一致）；要插中间就拖到线上插入</div>
      <div style="font-size: 10px; color: ${T.fg4}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">原画板「需要你定」其余按建议画：Q1 A 继承白名单 · Q2 A C 留给评论 · Q3 A P 设为当前 · Q4 B Shift D 停用 · Q5 B Ctrl 0 = 100% · Q6 A 镜头不给单键。待定键在拍板的切片登记前不注册、不上快捷键页。</div>
    </div>
  </div>`;

// ================= 1. 单键 / 组合键触发 =================
const s1 = section('单键 / 组合键触发', 'P1', `现状：${code('canvas_shortcuts.dart')} 的 ${code('kCanvasShortcuts')} + ${code('CanvasToolKeys')}；esc-ladder 把它改成注册表（新键 = 新文件追加一行），${code('shortcut_catalog')} 从注册表取文案`, [
  row([
    S('默认', '画布持焦：键直达', '现状', { mock: stage(`${abs(6, 6, keys('I'))}${hl(28, 14, 20, T.fg6)}${nc(60, 6, '图像', 'new')}${nc(100, 26, '视频', '')}${capsule('视口中心 + 散布')}`), cap: '按 I / G / T 在视口中心建节点并单选，相机不动；V H F L 切工具' }),
    S('聚焦', '工具条按钮持焦', '现状', { mock: box(`<div style="margin-bottom: 4px">${toolbar('select', 2)}</div>${kline(keys('Tab'), '下一个按钮，不开新建菜单')}`), cap: 'Tab、空格只在画布本身持主焦点时接管；落在按钮上就放行给焦点遍历 / 激活' }),
    S('让位', '文本框持焦', '现状', { mock: box(`${field('雾江上一叶孤舟 v')}<div style="margin-top: 4px">${kline(keys('V'), '字进框，工具不变', T.teal)}</div>`), cap: `${code('_EditingAwareAction')}：焦点在文字里就不接，按键冒泡给框` }),
    S('禁用', '画布标签不可见', '现状', { mock: box(`${tabsBar('序列')}<div style="margin-top: 5px">${kline(keys('Del', true), '不吞键：画布已交焦', T.fg5)}</div>`), cap: 'isActive = false：本层交出焦点、不再可聚焦；回到画布标签帧后要回焦点' }),
    S('禁用', '对话框压着', '现状', { mock: stage(`${nc(8, 8, '镜 02', 'sel')}${nc(54, 24, '镜 03')}${scrim(dlg(`新建泳道<div style="margin-top: 4px">${field('白天', true)}</div>`))}`), cap: '路由不在最上层时不抢焦点（_onTopRoute）；Backspace 只删框里的字' }),
    S('无反应', '待定键未注册', '新增', { mock: box(`<div style="display: flex; gap: 3px; margin-bottom: 4px">${capDash('P')}${capDash('Shift D')}${capDash('C')}</div>${kline(capDash('P'), '什么都不发生，不出提示', T.fg5)}`), cap: '待定行拍板后由各自切片登记；登记前按了没反应，快捷键页也不列' }),
  ]),
  row([
    F(1, '按下 I', '现状', { mock: box(`<div style="display: flex; align-items: center; gap: 6px">${keys('I')}${txt('includeRepeats: false', T.fg5)}</div><div style="margin-top: 6px">${txt('画布持主焦点 · 不在文字里', T.fg4)}</div>`), cap: '单键全部 includeRepeats: false；按住不连发' }),
    F(2, '查表命中 Intent', '现状', { mock: stack([kline(cap('I'), 'CanvasAddNodeIntent(image)'), kline(cap('G'), 'CanvasAddNodeIntent(video)', T.fg5), kline(cap('T'), 'CanvasAddNodeIntent(text)', T.fg5)]), cap: '键 → Intent → Action；动作本体在 canvas_tool_actions，与工具条共用' }),
    F(3, 'Action 判能不能动', '现状', { mock: stack([kline(txt('isEditingText()'), 'false → 执行', T.success), kline(txt('isEditingText()'), 'true → 冒泡给文字', T.teal), kline(txt('viewport 未上报'), '不开新建菜单', T.fg5)]), cap: '让位判据只有一个：主焦点在 EditableText 里' }),
    F(4, '结果：新卡单选', '现状', { mock: stage(`${nc(18, 6, '镜 02')}${nc(62, 18, '图像', 'new')}${nc(104, 6, '镜 03')}`), cap: '落在视口中心 + 散布；判泳道写 laneId；只单选不挪相机' }),
    E('按住 I 不放', '现状', { mock: stage(`${abs(6, 6, `${cap('I')}${txt(' 按住 1 秒', T.fg5)}`)}${nc(62, 22, '图像', 'new')}${nc(70, 26, '', 'ghost', 26)}`), cap: '只建一张；自动重复事件被 includeRepeats: false 吃掉' }),
    E('建节点写库失败', '现状', { mock: box(`${miniToast('error', '没能新建节点 · 重试')}<div style="margin-top: 4px">${txt('画布上不留虚卡', T.fg5)}</div>`), cap: 'addNodeAtViewportCenter 自带错误卡；节点表不变' }, '失败'),
  ]),
]);

// ================= 2. Esc 阶梯 =================
const s2 = section('Esc 阶梯', 'P1', `现状：${code('_escape')} 按 拖线 → 菜单 → 平移 → 连线 → 清选中 逐层判；新增 ${code('escape_ladder.dart')} 层表（每层 active() / dismiss()），@ 补全 / 查找条 / 框选 / 工具锁留登记口`, [
  row([
    S('默认', '① 菜单开着', '现状', { mock: ladderStage(1, `${abs(10, 2, miniMenu(['新建…', '全选'], 0, 64))}${nc(100, 8, '镜 02', 'sel')}`), cap: '关菜单；子菜单开着先收子菜单，焦点当场还给画布' }),
    S('默认', '② @ 补全开着', '新增', { mock: ladderStage(2, `${abs(6, 6, field('@渔', true, '60px'))}${abs(72, 1, miniMenu(['渔夫', '渔船'], 0, 50))}`), cap: '收起弹层，已打的「@渔」留在框里' }),
    S('默认', '③ 查找条开着', '新增', { mock: ladderStage(3, `${abs(6, 6, field('镜 0', true, '60px'))}${nc(76, 7, '镜 03', 'sel')}`), cap: '关查找条，选中停在当前命中项' }),
    S('让位', '④ 输入框持焦', '新增', { mock: ladderStage(4, `${abs(6, 6, field('拂晓', true, '62px'))}${nc(76, 7, '镜 02', 'sel')}`), cap: '只失焦，焦点回画布；选中还在（修现存 bug）' }),
    S('进行中', '⑤ 拖线 / 框选中', '现状', { mock: ladderStage(5, `${nc(4, 8, '镜 02', 'sel')}${hl(38, 16, 30, T.accent, true)}<div style="position: absolute; left: 80px; top: 6px; width: 40px; height: 20px; border: 1px dashed ${T.sky}"></div>`), cap: '拖线取消不连线（现状）；框选恢复按下前的选中（新增）' }),
    S('默认', '⑥ 工具非选择', '现状', { mock: ladderStage(6, `${abs(4, 6, toolbar('pan'))}`), cap: '平移 / 连线（现状）、工具锁（新增）→ 回选择工具' }),
    S('完成', '⑦ 有选中', '现状', { mock: ladderStage(7, `${nc(6, 8, '镜 02', 'sel')}${nc(50, 8, '镜 03', 'sel')}${abs(92, 10, txt('→ 全不选', T.fg5))}`), cap: '清空节点与连线选中；再按一次什么都不发生' }),
  ]),
  row([
    F(1, '起点', '现状', { mock: stage(`${nc(8, 4, '镜 02', 'sel')}${nc(8, 26, '镜 03', 'sel')}${abs(50, 4, toolbar('link'))}${abs(120, 18, miniMenu(['新建…', '全选'], 0, 56))}`), cap: '空白处右键菜单开着 + 连线模式 + 选中 2 张' }),
    F(2, '第 1 下 Esc', '现状', { mock: stage(`${nc(8, 4, '镜 02', 'sel')}${nc(8, 26, '镜 03', 'sel')}${abs(50, 4, toolbar('link'))}${capsule('菜单关了，其余不动')}`), cap: '只剥最上一层：关菜单；连线与选中保持' }),
    F(3, '第 2 下 Esc', '现状', { mock: stage(`${nc(8, 4, '镜 02', 'sel')}${nc(8, 26, '镜 03', 'sel')}${abs(50, 4, toolbar('select'))}`), cap: '退出连线，工具回到选择；选中还在' }),
    F(4, '第 3 / 4 下 Esc', '现状', { mock: stage(`${nc(8, 4, '镜 02')}${nc(8, 26, '镜 03')}${abs(50, 4, toolbar('select'))}${capsule('第 4 下：无事，不出提示')}`), cap: '第 3 下清空选中；阶梯到底后再按不做任何事' }),
  ]),
  row([
    E('提示词条里按 Esc', '新增', { hot: true, mock: box(`<div style="display: flex; gap: 6px"><div style="flex: 1">${txt('现在', T.danger)}${field('拂晓', true)}${txt('选中被清空', T.danger)}</div><div style="flex: 1">${txt('改后', T.success)}${field('拂晓', false)}${txt('只失焦，选中在', T.success)}</div></div>`, 'padding: 2px 6px'), cap: `现存 bug：${code('CanvasEscapeIntent')} 绑的是普通 CallbackAction，不对文字让位；改为第 4 层失焦并消费这次按键` }, '修复'),
    E('上面压着对话框 / 浮层', '现状', { mock: stage(`${nc(8, 8, '镜 02', 'sel')}${scrim(dlg('命令面板 ⌘K<div style="margin-top: 3px; color: ' + T.fg5 + '">Esc 关面板</div>', 90))}`), cap: '对话框、⌘K、设置、任务弹层、铃铛不在阶梯上：开着时 Esc 归它们，画布选中不动' }),
    E('设置浮层里的编辑框', '现状', { mock: box(`${kline(cap('Esc'), '① 关 Key 编辑框')}${kline(cap('Esc'), '② 关设置浮层')}`), cap: `编辑框是另一条路由，第一下由它的 DismissIntent 收；焦点回浮层后第二下走 ${code('kOverlayDismissActivator')}` }),
    E('框选拖到一半按 Esc', '新增', { mock: stage(`${nc(8, 6, '镜 01', 'sel')}${nc(60, 6, '镜 02', '')}${nc(60, 26, '镜 03', '')}<div style="position: absolute; left: 52px; top: 2px; width: 50px; height: 40px; border: 1px dashed ${T.sky}; opacity: 0.5"></div>${capsule('回到只选镜 01')}`), cap: '恢复按下前的选中（镜 01），不是清空；框消失，不记撤销步' }),
  ]),
]);

// ================= 3. 文字让位 =================
const s3 = section('文字让位', 'P1', `现状：${code('isEditingText()')} + ${code('_EditingAwareAction')}；Tab 走 ${code('_CanvasFocusedAction')}，按住空格走 ${code('onKeyEvent')}，都只在画布本身持主焦点时接管`, [
  row([
    S('默认', '画布持主焦点', '现状', { mock: stack([kline(keys('V I G T F L'), '工具 / 建节点'), kline(keys('Tab'), '新建…'), kline(keys('Space'), '按住临时平移')]), cap: '画布键全部生效' }),
    S('让位', '文本框持焦：交给框', '现状', { mock: box(`<div style="display: flex; flex-wrap: wrap; gap: 2px">${keys('单键 Space Tab Del Ctrl+A Ctrl+D Ctrl+Z Ctrl+→ Alt+字母')}</div>`), cap: '这些键归文字：打字、删字、全选字、光标跳词；画布不动' }),
    S('聚焦', '文本框持焦：照常生效', '现状', { mock: box(`<div style="display: flex; flex-wrap: wrap; gap: 2px">${keys('Ctrl+K')}${capDash('Ctrl+F')}${capDash('F6')}${capDash('单独 Alt')}</div><div style="margin-top: 4px">${txt('应用级：在框里也接管', T.sky)}</div>`), cap: 'Ctrl K 现状已在框里生效；Ctrl F / F6 / 单独 Alt 为第二批新增，同样不让位' }),
    E('提示词条里 Ctrl ↵', '现状', { mock: box(`${field('雾江上一叶孤舟', true)}<div style="margin-top: 4px">${kline(keys('Ctrl+Enter'), '提示词条接住，只提交一次', T.success)}</div>`), cap: '提示词条的 CallbackShortcuts 先接，画布层又让位，只提交一次' }),
    E('空格按下后焦点进了框', '现状', { mock: stack([kline(txt('Space ↓ 画布'), '开始临时平移'), kline(txt('点进检查器文本框'), '焦点移走', T.fg5), kline(txt('Space ↑'), '照样收平移', T.success)]), cap: '松开不论焦点在哪都收；焦点整个离开画布时 onFocusChange 兜底收掉' }),
    E('框里的 Ctrl Z', '新增', { mock: stack([kline(txt('框内 Ctrl Z'), '框自己的撤销', T.teal), kline(txt('失焦'), '整段改动记成一步'), kline(txt('画布 Ctrl Z'), '撤掉整段')]), cap: '撤销栈（undo-stack）落地后：文字里不碰画布栈；失焦才合成一步' }),
  ]),
  row([
    F(1, '在提示词条里打 v', '现状', { mock: box(`${field('孤舟 v', true)}<div style="margin-top: 4px">${toolbar('select')}</div>`), cap: '字母进框，工具条仍是「选择」' }),
    F(2, '按 Esc', '新增', { mock: box(`${field('孤舟 v', false)}<div style="margin-top: 4px">${txt('焦点回画布 · 选中镜 02 还在', T.success)}</div>`), cap: '阶梯第 4 层：失焦、消费按键，不再往下清选中' }),
    F(3, '按 H', '现状', { mock: box(`${field('孤舟 v', false)}<div style="margin-top: 4px">${toolbar('pan')}</div>`), cap: '画布持主焦点，单键恢复：切到平移工具' }),
    F(4, '或者：点画布舞台', '现状', { mock: stage(`${nc(16, 14, '镜 02', 'sel')}${abs(70, 12, `<span style="color: ${T.fg2}; display: flex">${ic('select', 14)}</span>`)}${capsule('reclaimFocus')}`), cap: '舞台按下指针时把焦点要回画布；上面压着对话框时不要' }),
  ]),
]);

// ================= 4. 新建下一镜 =================
const chain = (extra = '', sel = 'sel') => `${nc(4, 6, '镜 02')}${hl(38, 14, 12)}${nc(50, 6, '镜 03', sel)}${extra}`;
const s4 = section('新建下一镜 Ctrl → / ⌘→', 'P1', `新增：next-shot（并掉 KM next-shot-key 与 GC next-shot-core），${code('createNextShot')} 一个函数给 Ctrl →、拖线菜单「下一镜」、节点右键三个入口；节点 + 叙事边一个事务`, [
  row([
    S('默认', '可用：选中一个配置', '新增', { mock: stage(chain()), cap: '恰好选中一个图像 / 视频 / 镜头配置；右键「新建下一镜」行尾写 Ctrl →' }),
    S('默认', '选中产物', '新增', { mock: stage(`${nc(4, 6, '镜 03')}${hl(38, 14, 12, T.fg6, true)}${nc(50, 6, 'take 2', 'sel')}${capsule('锚点 = 它的源配置 镜 03')}`), cap: '以产物的源配置为锚点（narrativeAnchorOf），与新建菜单同一判据' }),
    S('无反应', '没选中 / 多选 / 文本', '新增', { mock: stage(`${nc(4, 6, '镜 02', 'sel')}${nc(50, 6, '镜 03', 'sel')}${abs(8, 28, txt('Ctrl → 无事，不出提示', T.fg5))}`), cap: '锚点不唯一或不是可接镜的节点：不建、不报错（与 Ctrl ↵ 同口径）' }),
    S('进行中', '写库中', '新增', { mock: stage(chain(`${hl(84, 14, 12, T.accent, true)}${nc(96, 6, '镜 04', 'ghost')}`)), cap: '一个事务写节点 + 叙事边；落地前不画实卡，期间再按排在它之后' }),
    S('完成', '新镜单选', '新增', { mock: stage(chain(`${hl(84, 14, 12)}${nc(96, 6, '镜 04', 'new')}`, '')), cap: '新节点单选、焦点留在画布可连按；跑出视口才平移，缩放不变；一步撤销' }),
    S('出错', '事务失败', '新增', { mock: stage(`${chain()}${abs(20, 26, miniToast('error', '没能新建下一镜 · 重试'))}`), cap: '整笔回滚，画布零残留；选中仍是锚点，可重试' }),
  ]),
  row([
    F(1, '选中镜 03', '新增', { mock: stage(chain()), cap: '锚点：同泳道「白天」里的镜 03' }),
    F(2, '按 Ctrl → / ⌘→', '新增', { mock: box(`<div style="display: flex; gap: 8px; align-items: center">${keys('Ctrl+→')}${txt('/', T.fg6)}${keys('⌘→')}</div><div style="margin-top: 5px">${txt('includeRepeats: false · 文字里让位', T.fg5)}</div>`), cap: 'mac 用 ⌘→：⌃→ 是系统切桌面' }),
    F(3, '镜 04 落在右侧', '新增', { mock: stage(`${nc(4, 6, '镜 03')}${nc(4, 26, 'take', 'dim', 28)}${hl(38, 14, 24)}${nc(64, 6, '镜 04', 'new')}${capsule('越过产物列 + kResultColumnGap')}`), cap: '同类型、同泳道；沿主轴越过锚点和它名下产物那一列再空一格；叙事边连上' }),
    F(4, '再按：连出镜 05', '新增', { mock: stage(`${nc(2, 6, '镜 03')}${hl(36, 14, 8)}${nc(46, 6, '镜 04')}${hl(80, 14, 8)}${nc(90, 6, '镜 05', 'new')}${abs(4, 28, txt('↵ = 焦点进提示词条', T.fg4))}`), cap: '锚点跟着走到新镜，可连按；按 ↵ 焦点进提示词条直接写这一镜' }),
  ]),
  row([
    E('锚点已有下一镜', '决定', { hot: true, mock: stage(`${nc(4, 14, '镜 03')}${hl(38, 9, 10)}${vl(48, 9, 20)}${hl(48, 9, 12)}${nc(62, 2, '镜 04')}${hl(48, 29, 12)}${nc(62, 22, '镜 04′', 'new')}${capsule('已新开分叉', 2).replace('left: 50%', 'left: 75%')}`), cap: '按决定 GC-N3 A：开分叉，sortOrder = 已有最大值 + 1，排在已有分叉之后；胶囊「已新开分叉」' }, '决定'),
    E('要插在 03 与 04 中间', '新增', { mock: stage(`${nc(4, 6, '镜 03')}${hl(38, 14, 54, T.accent)}${nc(92, 6, '镜 04')}${nc(48, 24, '新镜', 'new')}${vl(64, 15, 9, T.accent)}`), cap: 'Ctrl → 不插中间；把卡拖到 03→04 的线上插入（drag-insert，12px 命中）' }),
    E('右侧位置被占', '新增', { mock: stage(`${nc(4, 6, '镜 03', 'sel')}${nc(48, 6, '文本', 'dim')}${hl(38, 26, 56, T.fg5)}${nc(94, 6, '镜 04', 'new')}`), cap: '沿泳道主轴继续往后找空位；不换横截位置、不出锚点的泳道，竖向泳道同一套' }),
    E('继承什么', '新增', { mock: stack([kline(txt('继承', T.success), '模型 画幅 分辨率 时长 批量数 角色 负面词'), kline(txt('不继承', T.danger), '提示词 种子 镜头语言 备注 产物 首尾帧')]), cap: `Q1 A，纯函数 ${code('next_shot_config')}；测试变异：多继承一个 seed 就红` }),
  ]),
]);

// ================= 5. 冲突规则与弹层作用域 =================
const s5 = section('冲突规则与弹层作用域', 'P2', '弹层开着时键归弹层（作用域隔开，不与画布键冲突）；同一个键两种意思时按下面的优先级消掉', [
  row([
    S('聚焦', '新建 / 右键菜单', '现状', { mock: box(`${abs(6, 4, miniMenu(['图像配置', '视频配置', '泳道 ›'], 2, 64))}${abs(76, 6, `<div style="display: flex; flex-direction: column; gap: 2px">${keys('↑↓ ↵')}${keys('→ ← Esc')}</div>`)}`), cap: '↑↓ 跳过置灰项 · → 开子菜单 · ←/Esc 收回 · 打字即搜索（create_node_menu）' }),
    S('聚焦', '⌘K 命令面板', '现状', { mock: stack([kline(keys('↑↓ ↵'), '打开'), kline(keys('Ctrl+↵'), '在画布中定位'), kline(keys('Esc'), '关面板')]), cap: '面板是另一条路由，开着时 ⌘K 不重触发（command_palette_dialog）' }),
    S('聚焦', '批量对比', '现状', { mock: stack([kline(keys('← →'), '切格'), kline(keys('↵'), '设为当前'), kline(keys('Esc'), '关对比')]), cap: '全屏覆盖层自持焦点（batch_compare_overlay）' }),
    S('聚焦', '画廊网格', '现状', { mock: stack([kline(keys('↑ ↓ ← →'), '移锚点'), kline(keys('Space'), '预览')]), cap: '只在画廊标签的网格持焦时（gallery_grid）' }),
    S('聚焦', '查找条 / @ 补全', '新增', { mock: stack([kline(keys('↵ Shift+↵'), '下一个 / 上一个'), kline(keys('↵ Tab'), '插入 @ 记号'), kline(keys('Esc'), '各回阶梯一层')]), cap: '退格整块删 @ 记号；Esc 档位见上方阶梯 ②③' }),
    S('聚焦', 'F6 通知区', '新增', { mock: stack([kline(keys('↑↓'), '切卡'), kline(keys('↵ Tab'), '主按钮 / 卡内按钮'), kline(keys('Del Esc'), '关卡 / 回原处')]), cap: 'Esc 回到按 F6 之前的焦点位置' }),
  ]),
  row([
    E('Del：线和卡都选着', '新增', { mock: stage(`${nc(4, 6, '镜 02', 'sel')}${hl(38, 14, 24, T.accent)}${nc(62, 6, '镜 03')}${capsule('先删线，卡留着')}`), cap: '选中连线时 Del 优先删线；产出线点不中、删不掉（cm-edge-menu）' }, '冲突'),
    E('Ctrl ↵ 单张 / 多选', '新增', { mock: stack([kline(txt('选中 1 张'), '直接生成（现状）', T.success), kline(txt('选中 ≥ 2 张'), '开批量确认，上限 50'), kline(txt('选中 0 张'), '无事', T.fg5)]), cap: '多选确认框在 TakesCost 板；提示词条里的 Ctrl ↵ 只管本节点' }, '冲突'),
    E('Ctrl D 与 Shift D', '新增', { mock: stack([kline(keys('Ctrl+D'), '复制一份（现状）'), kline(keys('Shift+D'), '停用 / 启用（Q4 B）'), kline(capDash('D'), '不绑：紧挨 Ctrl D', T.fg5)]), cap: '多选时有启用的就全停，否则全启，一步撤销' }, '冲突'),
    E('重做只注册一个', '新增', { mock: pair(keys('Ctrl+Y'), keys('⇧⌘Z')), cap: '每平台一个键；菜单、⌘K、右键、快捷键页显示同一串' }, '冲突'),
    E('Ctrl 0 改成 100%', '新增', { mock: stack([kline(txt('现在'), '复位到初始相机', T.fg5), kline(txt('改后'), '缩放 = 100%，视口中心不动', T.success), kline(txt('胶囊'), '「100%」1.2 秒')]), cap: 'Q5 B，不加 Shift 0；文案「复位 100%」（zoom-reset-100，P3）' }),
    E('刻意不绑', '新增', { mock: box(`<div style="display: flex; flex-wrap: wrap; gap: 3px">${capDash('Ctrl S')}${capDash('K')}${capDash('Ctrl Del')}${capDash('Alt 助记')}${capDash('C')}${capDash('S')}</div>`), cap: '自动保存；K 剪线（W3 A）；C 留给评论（Q2 A）；镜头不给 S（Q6 A）' }),
  ]),
]);

// ================= 6/7. 设置快捷键页 | 单独 Alt =================
const HALF = Math.floor((CW - 24) / 2);
const halfSection = (title, p, note, rows) => `
  <div style="width: ${HALF}px; display: flex; flex-direction: column; gap: 8px">
    ${secHead(title, p, note)}
    <div style="display: flex; flex-direction: column; gap: ${GAP}px">${rows.map((r) => row(r, HALF)).join('')}</div>
  </div>`;
const s6 = halfSection('设置 · 快捷键页', 'P2', `现状：${code('shortcuts_section.dart')} 一张平表；shortcuts-page-v2 分组`, [
  [
    S('默认', '现状：平表', '现状', { mock: box(`${setRow('动作', '快捷键', true)}${setRow('命令面板', 'Ctrl+K')}${setRow('关闭浮层', 'Esc')}${setRow('删除选中节点', 'Delete · Backspace')}`, 'padding: 2px 6px'), cap: '从注册表反推、只读；Esc 行文案「取消连线 / 清空选择」改成阶梯' }),
    S('默认', '分组后', '新增', { mock: box(`${groupRow('单键 · 画布')}${setRow('新建图像配置', 'I')}${groupRow('组合键 · 应用')}${setRow('命令面板', 'Ctrl+K')}`, 'padding: 1px 6px'), cap: '单键 / 组合键 / 指针 / 弹层内部 / Esc 阶梯，每行带范围' }),
    S('空态', '没有空态', '现状', { mock: box(`${txt('至少有 ⌘K 与 Esc 两行', T.fg5)}<div style="margin-top: 4px">${txt('待定键不上屏', T.fg6)}</div>`), cap: '表永远非空；未登记的键不出现，不画「待定」行' }),
  ],
  [
    F(1, '设置 → 快捷键', '现状', { mock: box(`<div style="display: flex; gap: 4px; align-items: center">${ic('settings', 12)}${arrow}${txt('左导航第 3 项「快捷键」', T.fg2)}</div><div style="margin-top: 4px">${txt('设置是浮层，不写路由', T.fg5)}</div>`), cap: '也可从左栏导航条底部「快捷键」键直接开到这一页' }),
    F(2, '读表', '新增', { mock: box(`${groupRow('指针 · 画布')}${setRow('框选', '左键拖空白')}${setRow('平移', '右键拖 · 中键拖')}`, 'padding: 1px 6px'), cap: `指针手势无法反推，单写 ${code('pointer_gesture_catalog')}` }),
    F(3, 'Esc 关浮层', '现状', { mock: box(`${kline(keys('Esc'), '关设置（kOverlayDismissActivator）')}${kline(txt('编辑框开着'), '先关框，再按一次关浮层', T.fg5)}`), cap: '设置自持焦，晚于兜底夺焦；关了焦点回原标签' }),
  ],
]);
const s7 = halfSection('单独按 Alt（仅 Windows）', 'P2', '新增：lone-alt-menubar，依赖 win-menubar；mac 菜单在系统菜单栏，不画', [
  [
    F(1, '按下 Alt', '新增', { mock: box(`${menubar(false)}<div style="margin-top: 5px">${kline(`${cap('Alt')}${txt('↓', T.fg6)}`, '记一个标记，先不动', T.fg5)}</div>`), cap: '按下只记标记；菜单栏不亮' }),
    F(2, '松开 Alt', '新增', { mock: box(`${menubar(true)}<div style="margin-top: 5px">${kline(`${cap('Alt')}${txt('↑', T.fg6)}`, '聚焦「文件」，不展开', T.accent)}</div>`), cap: '期间没有别的键、指针按下或滚轮才聚焦' }),
    F(3, '↓ / ↵ 展开，Esc 回', '新增', { mock: box(`${menubar(true, true)}${abs(6, 18, miniMenu(['新建项目', '导入项目包', '退出  Alt+F4'], 0, 90))}`), cap: '←→ 换菜单；Esc 或再按 Alt 回到原来的焦点' }),
  ],
  [
    E('Alt + A', '新增', { mock: box(`${menubar(false)}<div style="margin-top: 5px">${kline(keys('Alt+A'), '左对齐，菜单栏不动')}</div>`), cap: '按下后有别的键 ⇒ 清标记；Alt 字母只做对齐，不做助记键' }),
    E('Alt + 拖空白', '新增', { mock: stage(`${abs(4, 2, menubar(false))}${hl(20, 30, 90, T.danger, true)}${capsule('切线')}`), cap: '指针按下 ⇒ 清标记；Alt 期间指针动作不冒泡出去' }),
    E('Alt Tab 回来 / AltGr', '新增', { mock: stack([kline(keys('Alt+Tab'), '窗口失焦清标记'), kline(keys('Ctrl+Alt'), 'AltGr 不算单独 Alt', T.fg5)]), cap: '切回窗口时不误聚焦菜单栏；欧洲键盘的 AltGr 打字不受影响' }),
  ],
]);
const s67 = `<div style="height: ${sectionH(2)}px; flex: none; display: flex; gap: 24px">${s6}${s7}</div>`;

// ================= 8. mac / Windows 差异 =================
const s8 = section('mac（⌘）/ Windows（Ctrl）差异', 'P1', `现状：⌘ 与 Ctrl 两套同时注册（${code('kCanvasShortcuts')}、${code('kCommandPaletteActivators')}），${code('formatShortcutActivator')} 按平台只显示一套`, [
  row([
    E('修饰键怎么写', '现状', { mock: pair(keys('Ctrl+A Shift+1 Ctrl+Enter'), keys('⌘A ⇧1 ⌘↵')), cap: 'Windows 写 Ctrl+ / Shift+ / Enter；mac 画 ⌘ ⇧ ⌥ ↵' }, '平台'),
    E('两套都注册', '现状', { mock: pair(`${keys('Ctrl+K')}${txt('列出', T.success)}${keys('⌘K', true)}${txt('不列', T.fg6)}`, `${keys('⌘K')}${txt('列出', T.success)}${keys('Ctrl+K', true)}${txt('不列', T.fg6)}`), cap: '另一平台的变体也能按，但快捷键页、菜单行尾不显示' }, '平台'),
    E('新建下一镜', '新增', { mock: pair(keys('Ctrl+→'), `${keys('⌘→')}${txt(' 不用 ⌃→', T.fg5)}`), cap: 'mac 的 ⌃←→ 是系统切桌面；文字里两边都让给光标跳词 / 行首尾' }, '平台'),
    E('重做 / 退出', '新增', { mock: pair(`${keys('Ctrl+Y')}${txt(' · ', T.fg6)}${keys('Alt+F4')}`, `${keys('⇧⌘Z')}${txt(' · ', T.fg6)}${keys('⌘Q')}`), cap: '重做每平台只注册一个；退出走各自系统习惯' }, '平台'),
    E('单独 Alt 与菜单栏', '新增', { mock: pair(`${cap('Alt')}${txt('聚焦自绘菜单栏', T.fg3)}`, txt('系统菜单栏（PlatformMenuBar），不绑', T.fg5)), cap: 'mac 不画单独 Alt；也不做 Alt+字母助记键' }, '平台'),
    E('Ctrl 点卡', '现状', { mock: pair(`${keys('Shift Ctrl')}${txt('点卡 = 切换选中', T.fg3)}`, `${keys('⇧ ⌘')}${txt('点卡；⌃点 = 右键', T.fg3)}`), cap: '代码现在 mac 上 ⌃点也当切换；文案只写 ⇧ / ⌘ 点' }, '平台'),
  ]),
  row([
    E('提示词条生成按钮尾标', '现状', { mock: pair(`<span style="height: 16px; padding: 0 6px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 9px; display: inline-flex; align-items: center">生成 Ctrl+Enter</span>`, `<span style="height: 16px; padding: 0 6px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 9px; display: inline-flex; align-items: center">生成 ⌘↵</span>`), cap: `${code('submitShortcutLabel')} 与快捷键页回车换字同一拍板` }, '平台'),
    E('右键菜单行尾键位', '现状', { mock: pair(`${txt('复制一份', T.fg2)}${txt('Ctrl+D', T.fg5)}`, `${txt('复制一份', T.fg2)}${txt('⌘D', T.fg5)}`), cap: `从 ${code('canvasShortcutLabel')} 取，改了绑定提示跟着变` }, '平台'),
    E('左栏收起 tooltip', '现状', { mock: pair(keys('Ctrl+\\'), keys('⌘\\')), cap: `${code('CanvasToolKeys.toggleLeftRail*')} 同一常量出字` }, '平台'),
    E('mac 不碰系统键', '新增', { mock: box(`<div style="display: flex; flex-wrap: wrap; gap: 3px">${capDash('⌘H')}${capDash('⌘M')}${capDash('⌘Tab')}${capDash('⌃←')}${capDash('⌃→')}</div><div style="margin-top: 4px">${txt('隐藏 / 最小化 / 切应用 / 切桌面', T.fg5)}</div>`), cap: '这些键一律不注册；停用不用 Ctrl M 也是这个原因' }, '平台'),
    E('⌥ 字母按 logicalKey', '新增', { mock: pair(`${keys('Alt+A')}${txt('左对齐', T.fg3)}`, `${keys('⌥A')}${txt('打出 å 也认', T.fg3)}`), cap: 'mac ⌥ 会改字符，按 logicalKey 匹配；文字里照样让位输入 å' }, '平台'),
    E('指针：触控板 / 滚轮', '现状', { mock: pair(txt('滚轮 = 以指针为中心缩放', T.fg3), txt('双指平移 · 捏合缩放', T.fg3)), cap: '两平台都认两种；Ctrl / ⌘ 滚轮只在序列时间轴缩放' }, '平台'),
  ]),
]);

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45; padding: ${PAD}px; box-sizing: border-box; display: flex; flex-direction: column; gap: ${SEC_GAP}px">
  ${header}
  ${s1}
  ${s2}
  ${s3}
  ${s4}
  ${s5}
  ${s67}
  ${s8}
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'KeyMapDetail.dc.html', html: page('快捷键总表 · 状态与流程', W, H, body, logic) };
