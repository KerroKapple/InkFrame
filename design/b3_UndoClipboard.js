// 第三批细化画板：撤销与剪贴板 · 状态与流程（1280×H，静态）
// 原板 b2_history.js（UndoClipboard.dc.html）的六个功能栏，每栏：状态条一行 + 流程 / 边界一行。
// 决定：TC-Q1 → A（改写边）——「设为当前」的撤销令牌 = 旧 pinned_result_id + 被改写的 data 边旧上游；revert 按两端找边，不按边 id
// 决定：UC-1 → A（卡上写哪步撤哪步，undoSpecific 从栈里抽掉）
// 决定：UC-2 → A（撤销「新建」时节点在生成：照删，任务跑完落成未入链结果，胶囊补「任务仍在运行」）
// 决定：UC-3 → A（撤销批量 slot 的设为当前：主图、promoted slot、当前 take、改写过的线全回）
// 决定：UC-4 → A（粘贴产物而源配置没跟来：断开溯源，成未入链独立图）
// 决定：UC-5 → A（粘贴分段文字：一个文本节点 + 胶囊「按剧本拆镜…」）
// 决定：IS-Q1 → A（读剪贴板图片用 pasteboard，与拖入共用一套）
const { T, IMG, SANS, MONO, page, ic } = require('./common.js');

const W = 1280, H = 2400;
const MH = 80; // 样稿高

// ---- 小件（照 b2_history.js 本地拷贝，按样稿缩小）----
const h3 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 8px; margin-bottom: 4px"><div style="font-weight: 500; color: ${T.fg1}; white-space: nowrap">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const kbd = (k, color = T.fg5) => `<span style="font-family: ${MONO}; font-size: 9px; color: ${color}; white-space: nowrap">${k}</span>`;
const code = (t) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${t}</span>`;
const iconBox = (html, color = T.fg4) => `<div style="color: ${color}; display: flex">${html}</div>`;
const redoIcon = (size = 12) => `<div style="display: flex; transform: scaleX(-1)">${ic('undo', size)}</div>`;
const spinIcon = (size = 12, color = T.accent) => `<div class="spin" style="display: flex; color: ${color}">${ic('progress', size)}</div>`;
const newTag = `<span style="height: 13px; padding: 0 4px; border-radius: 3px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 9px; line-height: 13px; display: inline-block; margin-right: 4px">新</span>`;
const nowTag = `<span style="height: 13px; padding: 0 4px; border-radius: 3px; border: 1px solid ${T.outline}; background: ${T.s3}; color: ${T.fg4}; font-size: 9px; line-height: 13px; display: inline-block; margin-right: 4px">现状</span>`;
const need = (t) => `<span style="color: ${T.accent}">需：</span>${t}`;
const keycap = (k, big = false) => `<span style="display: inline-flex; align-items: center; justify-content: center; min-width: ${big ? 28 : 18}px; height: ${big ? 26 : 18}px; padding: 0 ${big ? 7 : 4}px; box-sizing: border-box; border-radius: 4px; border: 1px solid ${T.controlStrong}; border-bottom-width: 2px; background: ${T.s4}; color: ${T.fg2}; font-family: ${MONO}; font-size: ${big ? 12 : 10}px; white-space: nowrap">${k}</span>`;

// 菜单（样稿行高 20）
const mItem = (iconHtml, label, key = '', { hover = false, dim = false, danger = false } = {}) => `
  <button type="button" style="width: 100%; height: 20px; display: flex; align-items: center; gap: 6px; padding: 0 6px; box-sizing: border-box; border-radius: 3px; font-size: 10px; color: ${dim ? T.fg6 : danger ? T.danger : T.fg2}; ${hover ? `background: ${T.s5};` : ''}">
    ${iconHtml ? iconBox(iconHtml, dim ? T.fg6 : T.fg4) : '<div style="width: 12px; flex: none"></div>'}
    <span style="flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${label}</span>${key ? kbd(key, dim ? T.fg6 : T.fg5) : ''}
  </button>`;
const mSep = `<div style="height: 1px; background: ${T.bStrong}; margin: 2px 0"></div>`;
const mMenu = (inner, w = 150, pos = '') => `<div style="${pos ? `position: absolute; ${pos};` : ''} width: ${w}px; box-sizing: border-box; padding: 3px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 5px; box-shadow: 0 24px 64px rgba(0,0,0,0.6)">${inner}</div>`;

// 画布胶囊（轻提示）
const mCap = (iconHtml, text, right = '', iconColor = T.fg3) => `
  <div style="display: inline-flex; align-items: center; gap: 6px; height: 22px; padding: 0 9px; border-radius: 999px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; box-shadow: 0 8px 24px rgba(0,0,0,0.45); color: ${T.fg2}; font-size: 10px; max-width: 100%; box-sizing: border-box">
    ${iconHtml ? iconBox(iconHtml, iconColor) : ''}<span style="min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${text}</span>${right ? `<span style="width: 1px; height: 10px; background: ${T.control}; flex: none"></span>${right}` : ''}
  </div>`;

// 通知卡（缩小版，与 TOAST_CARD 同构：图标块 + 标题 / 正文 + 按钮 + 倒计时条）
const mToast = ({ kind = 'undo', title, body = '', btn = '', bar = '', hover = false, dimBtn = false }) => {
  const color = { undo: T.fg3, error: T.danger, warning: T.accent, success: T.success, info: T.fg4 }[kind];
  return `
  <div style="position: relative; width: 100%; box-sizing: border-box; display: flex; gap: 7px; padding: 7px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 5px; box-shadow: 0 24px 64px rgba(0,0,0,0.45), 0 2px 6px rgba(0,0,0,0.35); overflow: hidden">
    <div style="width: 22px; height: 22px; flex: none; border-radius: 3px; background: ${T.s5}; display: flex; align-items: center; justify-content: center; color: ${color}">${ic(kind, 13)}</div>
    <div style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 1px; padding-right: 10px">
      <div style="font-size: 10px; font-weight: 500; line-height: 1.35; color: ${T.fg1}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</div>
      ${body ? `<div style="font-size: 9px; line-height: 1.35; color: ${T.fg4}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${body}</div>` : ''}
      ${btn ? `<div style="display: flex; justify-content: flex-end; margin-top: 3px"><button class="amber" type="button" style="height: 17px; padding: 0 7px; border-radius: 3px; background: ${dimBtn ? T.control : T.accent}; color: ${dimBtn ? T.fg5 : T.onAccent}; font-size: 9px; font-weight: 500">${btn}</button></div>` : ''}
    </div>
    ${(hover || kind === 'error') ? `<button type="button" aria-label="关闭通知" style="position: absolute; top: 4px; right: 4px; width: 14px; height: 14px; display: flex; align-items: center; justify-content: center; color: ${T.fg4}">${ic('close', 10)}</button>` : ''}
    ${bar ? `<div style="position: absolute; left: 0; bottom: 0; height: 2px; width: ${bar}; background: ${T.controlStrong}"></div>` : ''}
  </div>`;
};

// 迷你节点卡
const mCard = ({ x, y, w = 46, h = 28, label = '', img = '', text = '', sel = false, dim = false, ghost = false, badge = '' }) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; ${dim ? 'opacity: .4;' : ''}">
    <div style="height: 11px; font-size: 8px; line-height: 11px; color: ${sel ? T.fg1 : T.fg4}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${label}</div>
    <div style="position: relative; width: ${w}px; height: ${h}px; box-sizing: border-box; border-radius: 3px; background: ${ghost ? 'transparent' : T.thumb}; ${ghost ? `border: 1px dashed ${T.fg6};` : `outline: 1px solid ${sel ? T.accent : T.outline};`} overflow: hidden">
      ${img ? `<img src="${img}" alt="" style="width: 100%; height: 100%; object-fit: cover; display: block">` : ''}
      ${text ? `<div style="padding: 3px 4px; font-size: 7px; line-height: 1.4; color: ${T.fg3}; overflow: hidden; height: 100%; box-sizing: border-box">${text}</div>` : ''}
      ${badge ? `<div style="position: absolute; right: 2px; top: 2px; color: ${T.accent}; display: flex">${badge}</div>` : ''}
    </div>
  </div>`;
const cursor = (x, y) => `<svg width="11" height="14" viewBox="0 0 14 18" aria-hidden="true" style="position: absolute; left: ${x}px; top: ${y}px"><path d="M1 1v14l4-3.5 2.6 5.5 2.2-1-2.6-5.4H13z" fill="${T.fg1}" stroke="${T.s0}" stroke-width="1" stroke-linejoin="round"></path></svg>`;
const wires = (paths, w = 190, h = MH) => `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" aria-hidden="true" style="position: absolute; left: 0; top: 0">${paths}</svg>`;
const pth = (d, color = T.sky, dash = '5 4', op = 1) => `<path d="${d}" fill="none" stroke="${color}" stroke-width="1.25" ${dash ? `stroke-dasharray="${dash}"` : ''} stroke-linecap="round" opacity="${op}"></path>`;
const lineage = (d) => pth(d, T.fg6, '1.5 3.5');
const tiny = (x, y, t, color = T.fg5) => `<div style="position: absolute; left: ${x}px; top: ${y}px; font-size: 8px; color: ${color}; white-space: nowrap">${t}</div>`;

// 栈示意：自下而上，顶在上
const stackRow = (t, { top = false, dim = false, strike = false, fail = false, redo = false } = {}) => `
  <div style="height: 16px; display: flex; align-items: center; gap: 5px; padding: 0 6px; border-radius: 3px; font-size: 9px; white-space: nowrap; overflow: hidden;
    background: ${top ? T.wash : T.s3}; border: 1px ${redo ? 'dashed' : 'solid'} ${fail ? T.danger : top ? T.washBorder : T.outline};
    color: ${dim ? T.fg6 : top ? T.accent : T.fg3}; ${strike ? 'text-decoration: line-through;' : ''}">${t}</div>`;
const mStack = (rows, w = 132) => `<div style="width: ${w}px; display: flex; flex-direction: column; gap: 3px">${rows.join('')}</div>`;

// 输入框（有焦点）
const mInput = (t, focus = true) => `<div style="width: 100%; box-sizing: border-box; height: 34px; padding: 4px 6px; border-radius: 3px; background: ${T.s3}; border: 1px solid ${focus ? T.accent : T.control}; font-size: 9px; line-height: 1.4; color: ${T.fg2}; overflow: hidden">${t}<span style="display: inline-block; width: 1px; height: 10px; background: ${T.fg1}; vertical-align: -1px; margin-left: 1px"></span></div>`;

// ---- 帧 ----
const badge = (t, kind) => {
  const flow = kind === 'flow';
  return `<span style="flex: none; display: inline-flex; align-items: center; justify-content: center; min-width: 15px; height: 15px; padding: 0 3px; box-sizing: border-box; border-radius: ${flow ? 8 : 3}px; border: 1px ${flow ? 'solid' : 'dashed'} ${flow ? T.accent : T.fg5}; color: ${flow ? T.accent : T.fg4}; font-family: ${MONO}; font-size: 9px; margin-right: 5px; vertical-align: 1px">${t}</span>`;
};
const frame = (mock, cap, { tag = '', kind = 'state', center = true } = {}) => `
  <div style="flex: 1 1 0; min-width: 0">
    <div style="position: relative; height: ${MH}px; box-sizing: border-box; border-radius: 4px; background: ${T.s1}; border: 1px solid ${T.outline}; overflow: hidden; ${center ? 'display: flex; align-items: center; justify-content: center; padding: 6px;' : ''}">${mock}</div>
    <div style="margin-top: 5px; font-size: 10px; line-height: 1.5; color: ${T.fg4}">${kind === 'state' ? `<span style="color: ${T.fg2}; font-weight: 500; margin-right: 4px">${tag}</span>` : badge(tag, kind)}${cap}</div>
  </div>`;
const rowLabel = (t) => `<div style="width: 40px; flex: none; padding-top: 2px; font-size: 10px; color: ${T.fg6}; line-height: 1.5">${t}</div>`;
const stateRow = (frames) => `<div style="display: flex; gap: 10px">${rowLabel('状态')}<div style="flex: 1; min-width: 0; display: flex; gap: 10px">${frames.join('')}</div></div>`;
const flowRow = (flows, edges) => `
  <div style="display: flex; gap: 10px">${rowLabel('流程<br>边界')}
    <div style="flex: 1; min-width: 0; display: flex; gap: 10px">
      ${flows.join('')}
      <div style="width: 1px; flex: none; background: ${T.control}; margin: 0 3px"></div>
      ${edges.join('')}
    </div>
  </div>`;
const section = (title, note, now, states, flows, edges) => `
  <section style="display: flex; flex-direction: column; gap: 10px">
    <div>
      ${h3(title, note)}
      <div style="font-size: 11px; color: ${T.fg5}; line-height: 1.5">${now}</div>
    </div>
    ${stateRow(states)}
    ${flowRow(flows, edges)}
  </section>`;
const divider = `<div style="height: 1px; background: ${T.control}"></div>`;
const col = (inner, gap = 6) => `<div style="display: flex; flex-direction: column; align-items: center; gap: ${gap}px; width: 100%">${inner}</div>`;

const CFG = '拂晓雾江，渔夫收网';

// ================= 1 撤销 / 重做入口 =================
const undoMenu = (hover) => mMenu(`
  ${mItem(ic('undo', 12), '撤销 移动 3 个节点', 'Ctrl Z', { hover })}
  ${mItem(redoIcon(12), '重做 新建 文本', 'Ctrl Y')}
  ${mSep}
  ${mItem(ic('nodeLibrary', 12), '新建…', 'Tab')}`, 160);
const moveScene = (atOrigin, sel) => `
  ${atOrigin ? '' : [0, 1, 2].map((i) => mCard({ x: 14 + i * 20, y: 8 + i * 8, w: 34, h: 20, ghost: true })).join('')}
  ${[0, 1, 2].map((i) => mCard({ x: (atOrigin ? 14 : 70) + i * 20, y: (atOrigin ? 8 : 26) + i * 8, w: 34, h: 20, label: `镜头 0${i + 1}`, text: CFG, sel })).join('')}`;
const s1 = section('撤销 / 重做', 'Windows Ctrl Z · Ctrl Y；macOS ⌘Z · ⇧⌘Z',
  `${nowTag}尚无：${code('canvas_shortcuts.dart')} 的 kCanvasShortcuts 没有 Z / Y；空白处右键只有 新建… / 导入脚本… / 全选 / 适应视图；${code('canvas_snackbars.dart')} 注释写明「画布没有撤销快捷键」。下面全部是${newTag}`,
  [
    frame(undoMenu(false), '空白处右键前两项带步名；⌘K 动作组、快捷键页同名同键', { tag: '默认' }),
    frame(undoMenu(true), '行底 s5；名字 =「撤销 / 重做」+ 这一步', { tag: '悬停' }),
    frame(mMenu(`${mItem(ic('undo', 12), '撤销', 'Ctrl Z', { dim: true })}${mItem(redoIcon(12), '重做', 'Ctrl Y', { dim: true })}`, 120), '栈空：两项置灰不隐藏、不带步名；快捷键按了什么也不做', { tag: '禁用' }),
    frame(mCap(spinIcon(12), '正在撤销…'), 'revert 在写库；期间再按排队顺序执行，不并发、不跳步', { tag: '进行中' }),
    frame(mCap(ic('undo', 12), '已撤销 · 移动 3 个节点', kbd('重做 Ctrl Y', T.fg4)), '画布底部胶囊，贴提示词条上方 8，一次只一条（需：canvas-capsule）', { tag: '完成' }),
    frame(mToast({ kind: 'error', title: '撤销失败' }), '走现有 undoFailed 错误卡、不自动收；整步回滚，这一步留在栈顶可再试', { tag: '出错' }),
  ],
  [
    frame(moveScene(false, true), '拖 3 张松手 → 进栈「移动 3 个节点」，重做栈清空', { tag: '1', kind: 'flow', center: false }),
    frame(`<div style="display: flex; gap: 4px; align-items: center">${keycap('Ctrl', true)}<span style="color: ${T.fg5}">+</span>${keycap('Z', true)}</div>`, '先冲掉检查器 500ms 防抖 patch，再 revert，一个 UnitOfWork', { tag: '2', kind: 'flow' }),
    frame(moveScene(true, true), '回到原位并选中这 3 张；不在视口里就平移过去，缩放不变', { tag: '3', kind: 'flow', center: false }),
    frame(mCap(ic('undo', 12), '已撤销 · 移动 3 个节点'), '胶囊报步名；Ctrl Y 重做同一步，在两栈之间来回挪', { tag: '4', kind: 'flow' }),
  ],
  [
    frame(`<div style="display: grid; grid-template-columns: auto auto auto; gap: 5px 6px; align-items: center; font-size: 9px; color: ${T.fg5}">
      <span>macOS</span>${keycap('⌘Z')}${keycap('⇧⌘Z')}
      <span>Windows</span>${keycap('Ctrl Z')}${keycap('Ctrl Y')}
    </div>`, '两套都注册（同现有 kCanvasShortcuts）；菜单、⌘K 只显示本平台主键', { tag: 'A', kind: 'edge' }),
    frame(col(`${mInput('拂晓雾江，渔夫站在船头收网')}<div style="display: flex; gap: 3px; align-self: flex-end">${keycap('Ctrl Z')}</div>`, 4), '文本框有焦点：Ctrl Z 撤框里的字（isEditingText 让位）；失焦后整段算一步', { tag: 'B', kind: 'edge' }),
    frame(col(`${mCap(ic('undo', 12), '已撤销 · 新建 文本', kbd('×3', T.fg4))}<div style="font-size: 8px; color: ${T.fg6}">对话框 / ⌘K 开着：不接管</div>`, 6), '连按 3 次依次撤 3 步，胶囊原地换字；上面压着对话框或 ⌘K 时不抢', { tag: 'C', kind: 'edge' }),
  ]);

// ================= 2 什么进栈 =================
const setCurScene = (take, menu = false) => {
  const fromY = take === 2 ? 32 : 64;
  return `
  ${wires(`${lineage('M42 46C47 46 47 32 52 32')}${lineage('M42 46C47 46 47 64 52 64')}${pth(`M92 ${fromY}C100 ${fromY} 100 48 108 48`, T.sky, '', 1)}`)}
  ${mCard({ x: 4, y: 22, w: 38, h: 26, label: '镜头 01', text: CFG })}
  ${mCard({ x: 52, y: 10, w: 40, h: 22, label: take === 2 ? 'take 2 · 当前' : 'take 2', img: IMG.thumbWide, badge: take === 2 ? ic('pin', 9) : '' })}
  ${mCard({ x: 52, y: 42, w: 40, h: 22, label: take === 3 ? 'take 3 · 当前' : 'take 3', img: IMG.thumbMountain, sel: menu, badge: take === 3 ? ic('pin', 9) : '' })}
  ${mCard({ x: 108, y: 24, w: 40, h: 26, label: '镜头 02', text: '首帧接上一镜' })}
  ${tiny(108, 62, '首帧', T.sky)}
  ${menu ? mMenu(mItem(ic('pin', 12), '设为当前', '', { hover: true }), 80, 'left: 66px; top: 54px') : ''}`;
};
const s2 = section('什么进栈', '一次用户编辑 = 一步；系统和任务做的不算',
  `${nowTag}没有栈，只有 3 处一次性回调：${code('canvas_node_delete.dart')}（删节点 / 多选删除，NodeDeletion 令牌）、${code('canvas_view.dart')} _handleEdgeDelete（删线）、换道卡（同文件 moveNode 回原位）。栈、合并、失效判定都是${newTag}`,
  [
    frame(mStack([stackRow('移动 3 个节点', { top: true }), stackRow('新建 文本'), stackRow('连线 首帧')]), '栈顶是最近一步，菜单里的名字取它', { tag: '可撤' }),
    frame(mStack([stackRow('重做：移动 3 个节点', { redo: true, dim: true }), stackRow('新建 文本', { top: true }), stackRow('连线 首帧')]), '撤过的挪进重做栈（虚框）；有新操作就清空', { tag: '可重做' }),
    frame(col(`${mInput('比例 16:9 → 21:9')}<div style="font-size: 8px; color: ${T.accent}">合并中 · 未进栈</div>`, 4), '一次聚焦编辑没结束不进栈；失焦 / 换节点时合成一步', { tag: '合并中' }),
    frame(mStack([stackRow('新建 图像配置（已不在）', { strike: true, dim: true }), stackRow('连线 参考', { top: true })]), '对象已不在（任务失败清掉的占位）：丢掉这一步，胶囊「这一步已无法撤销」，不连带撤下一步', { tag: '失效' }),
    frame(mStack([stackRow('修改泳道「水墨」风格', { top: true, fail: true }), stackRow('移动 1 个节点')]), 'revert 失败整步回滚，留在栈顶（左框 danger）', { tag: '失败' }),
    frame(`<div style="font-size: 10px; color: ${T.fg6}">栈空</div>`, '新开画布 / 重启后；每个画布一栈，最多 100 步，超了丢最旧', { tag: '空' }),
  ],
  [
    frame(setCurScene(2), 'take 2 是当前，镜头 02 的首帧线从它出', { tag: '1', kind: 'flow', center: false }),
    frame(setCurScene(2, true), '在 take 3 上「设为当前」（TC-Q1 → A：改写边）', { tag: '2', kind: 'flow', center: false }),
    frame(setCurScene(3), '一个事务：pinned 改成 take 3、首帧线上游跟着改；进栈一步「设为当前 · take 3」', { tag: '3', kind: 'flow', center: false }),
    frame(setCurScene(2), 'Ctrl Z：pinned 回 take 2；线按两端（下游 + 端口 + 上游配置）找到再改回', { tag: '4', kind: 'flow', center: false }),
  ],
  [
    frame(col(`${mStack([stackRow('设为当前 · take 3', { top: true })], 120)}<div style="font-size: 8px; color: ${T.fg5}">take 4 到达 · 系统挪线（不进栈）</div>`, 5), '期间系统因新 take 改写了线（不进栈）：再撤仍按两端找，找不到只回 pinned', { tag: 'A', kind: 'edge' }),
    frame(`${wires(`${pth('M50 38C76 38 76 44 100 44', T.sky, '', 1)}${pth('M50 68C76 68 76 54 100 54', T.fg5, '2 3', 1)}`)}${mCard({ x: 6, y: 14, w: 44, h: 26, label: 'take 3', img: IMG.thumbMountain })}${mCard({ x: 6, y: 46, w: 44, h: 22, label: 'take 2', img: IMG.thumbWide })}${mCard({ x: 100, y: 26, w: 46, h: 30, label: '镜头 02', text: CFG })}${tiny(60, 26, '首帧', T.sky)}${tiny(54, 70, '首帧 → 参考', T.fg5)}`, '改成首帧时原首帧降成参考，同一事务；撤销两条一起回', { tag: 'B', kind: 'edge', center: false }),
    frame(col(`${mCard({ x: 0, y: 0, w: 60, h: 28, label: '图像配置', text: CFG, badge: spinIcon(9) }).replace('position: absolute; left: 0px; top: 0px;', 'position: relative;')}${mCap(ic('info', 12), '已撤销 · 任务仍在运行')}`, 6), 'UC-2 → A：撤销「新建」时它在生成也照删；任务跑完落成未入链结果', { tag: 'C', kind: 'edge' }),
  ]);

// ================= 3 复制 / 粘贴节点 =================
const copyScene = (stage) => {
  // stage: 1 选中复制 / 2 指针移动 / 3 粘贴 / 4 选中新节点
  const srcSel = stage <= 2;
  const showNew = stage >= 3;
  return `
  ${wires(`${lineage('M46 32H52')}${showNew ? lineage('M102 64H108') : ''}`)}
  ${srcSel ? `<div style="position: absolute; left: 2px; top: 4px; width: 94px; height: 42px; box-sizing: border-box; border: 1px dashed ${T.accent}; border-radius: 4px"></div>` : ''}
  ${mCard({ x: 6, y: 6, w: 40, h: 28, label: '镜头 01', text: CFG, sel: srcSel })}
  ${mCard({ x: 52, y: 6, w: 40, h: 28, label: '成片', img: IMG.thumbMountain, sel: srcSel })}
  ${showNew ? `${mCard({ x: 62, y: 38, w: 40, h: 28, label: '镜头 01', text: CFG, sel: stage === 4, ghost: stage === 3 })}${mCard({ x: 108, y: 38, w: 40, h: 28, label: '成片', img: stage === 4 ? IMG.thumbMountain : '', sel: stage === 4, ghost: stage === 3 })}` : ''}
  ${stage === 1 ? tiny(104, 20, 'Ctrl C', T.accent) : ''}
  ${stage >= 2 ? cursor(stage === 2 ? 112 : 102, 50) : ''}`;
};
const s3 = section('复制 / 粘贴节点', 'Ctrl C · Ctrl X · Ctrl V（macOS ⌘C · ⌘X · ⌘V）',
  `${nowTag}尚无节点剪贴板：全库 Clipboard 只有 3 处 setData 复制路径（${code('export_video_dialog.dart')} / ${code('delivery_panel.dart')} / ${code('storage_path_section.dart')}）。已有「复制一份」：${code('canvas_tool_actions.dart')} duplicateNodes（Ctrl D / ⌘D，只复制配置卡、标签加「副本」、偏 lg、不带边与产物）`,
  [
    frame(mMenu(`${mItem('', '生成', 'Ctrl ↵')}${mItem('', `复制`, 'Ctrl C', { hover: true })}${mItem('', '剪切', 'Ctrl X')}${mItem('', '复制一份', 'Ctrl D')}${mSep}${mItem('', '删除', 'Del', { danger: true })}`, 150), '节点右键多「复制」「剪切」（新），「复制一份」照旧', { tag: '默认' }),
    frame(mMenu(`${mItem(ic('nodeLibrary', 12), '新建…', 'Tab')}${mItem('', '粘贴', 'Ctrl V', { dim: true })}${mItem('', '全选', 'Ctrl A')}`, 140), '空白处右键「粘贴」（新）：剪贴板空时置灰；没选中时 Ctrl C / X 什么也不做', { tag: '禁用' }),
    frame(mCap(spinIcon(12), '正在粘贴 2 个节点…'), '只在跨画布要复制文件时出现；同画布直接完成', { tag: '进行中' }),
    frame(mCap(ic('success', 12), '已复制 2 个节点', '', T.success), '复制只出胶囊不弹卡（自己刚做的操作不响铃）', { tag: '完成' }),
    frame(mToast({ kind: 'error', title: '粘贴失败', body: '没有写入任何节点' }), '文件或写库失败整批回滚、零残留；错误卡不自动收', { tag: '出错' }),
  ],
  [
    frame(copyScene(1), '选中 2 张按 Ctrl C：快照进应用内剪贴板，系统剪贴板另写一份纯文字', { tag: '1', kind: 'flow', center: false }),
    frame(copyScene(2), '指针移到空白处（不按键不预览）', { tag: '2', kind: 'flow', center: false }),
    frame(copyScene(3), 'Ctrl V：包围盒中心对准指针；内部线和溯源换新 id，选区外的线不跟', { tag: '3', kind: 'flow', center: false }),
    frame(copyScene(4), '新节点成为选中；进栈「粘贴 2 个节点」，Ctrl Z 一次全撤', { tag: '4', kind: 'flow', center: false }),
  ],
  [
    frame(mToast({ kind: 'undo', title: '已剪切 2 个节点', btn: '撤销', bar: '70%' }), 'Ctrl X = 复制 + 删除，一步；弹撤销卡，撤回来后剪贴板仍能再粘', { tag: 'A', kind: 'edge' }),
    frame(`${mCard({ x: 24, y: 12, w: 50, h: 30, label: '镜头 01', text: CFG })}${mCard({ x: 48, y: 36, w: 50, h: 30, label: '镜头 01 副本', text: CFG, sel: true })}${tiny(108, 44, '不带线和产物')}`, 'Ctrl D 不变（现状）：只复制配置卡，加「副本」，偏 lg，不碰剪贴板', { tag: 'B', kind: 'edge', center: false }),
    frame(`${wires(lineage('M52 39C70 39 70 64 92 64'), 190)}${mCard({ x: 6, y: 14, w: 46, h: 28, label: '镜头 01', text: CFG, dim: true })}${mCard({ x: 92, y: 38, w: 54, h: 30, label: '成片 · 未入链', img: IMG.thumbMountain, sel: true })}${tiny(58, 34, '断开', T.danger)}`, 'UC-4 → A：选区只有产物，断开溯源成未入链独立图，不多算 take', { tag: 'C', kind: 'edge', center: false }),
  ]);

// ================= 4 粘贴到哪 · 带什么 =================
const viewport = (inner) => `<div style="position: absolute; left: 10px; top: 8px; right: 10px; bottom: 8px; border: 1px solid ${T.control}; border-radius: 3px">${inner}</div>`;
const s4 = section('粘贴到哪 · 带什么', '落点四种；同画布 / 同项目别的画布 / 别的项目带的东西不同',
  `${nowTag}落点判据已有：${code('drop_placement.dart')} resolveLaneDrop（泳道归属）、视口点 → 世界坐标；${code('kDuplicateOffset')} = 右下各 lg（24）。跨画布复制媒体尚无（${need('media-import-service 的 imports/ 写入')}）`,
  [
    frame(`${mCard({ x: 66, y: 22, w: 46, h: 28, ghost: true, label: '' })}${mCard({ x: 116, y: 22, w: 46, h: 28, ghost: true, label: '' })}<div style="position: absolute; left: 66px; top: 32px; width: 96px; height: 29px; border: 1px dashed ${T.accent}; border-radius: 3px"></div>${cursor(112, 44)}`, '指针在画布上：选区包围盒的中心对准指针', { tag: '指针处', center: false }),
    frame(`${mMenu(`${mItem('', '粘贴', 'Ctrl V', { hover: true })}`, 92, 'left: 64px; top: 30px')}<div style="position: absolute; left: 58px; top: 24px; width: 6px; height: 6px; border-radius: 3px; background: ${T.accent}"></div>`, '右键「粘贴」：右键按下的那一点，与新建菜单同一锚点', { tag: '右键', center: false }),
    frame(`${[0, 1, 2].map((i) => mCard({ x: 40 + i * 24, y: 4 + i * 16, w: 46, h: 26, label: i ? `第 ${i} 次` : '原', text: CFG, sel: i === 2, dim: i === 0 })).join('')}`, '指针不在画布 · 同画布：原位右下偏 lg，连按每次再偏一格', { tag: '原位偏移', center: false }),
    frame(viewport(`${mCard({ x: 52, y: 14, w: 46, h: 28, label: '镜头 01', text: CFG, sel: true })}<div style="position: absolute; left: 50%; top: 50%; width: 5px; height: 5px; margin: -2px; border-radius: 3px; background: ${T.fg6}"></div>`), '指针不在画布 · 别的画布：视口中心', { tag: '视口中心', center: false }),
    frame(`<div style="position: absolute; left: 8px; right: 8px; top: 18px; height: 50px; border-radius: 3px; background: rgba(201,168,91,0.08); border: 1px solid ${T.washBorder}"></div>${tiny(14, 6, '泳道「水墨」', T.accent)}${mCard({ x: 60, y: 26, w: 46, h: 28, label: '镜头 01', text: CFG, sel: true })}`, '落在泳道里：resolveLaneDrop 重新判、写 laneId，不带原泳道 id', { tag: '进泳道', center: false }),
    frame(col(`<div style="display: flex; gap: 4px; align-items: center"><span style="height: 16px; padding: 0 6px; border-radius: 8px; border: 1px solid ${T.outline}; font-size: 9px; line-height: 16px; color: ${T.fg6}; text-decoration: line-through">@老渔夫</span><span style="font-size: 9px; color: ${T.fg5}">→</span><span style="font-size: 9px; color: ${T.fg3}">「@老渔夫」纯文字</span></div>${mCap(ic('info', 12), '已去掉 1 个角色引用')}`, 8), '别的项目：挂载和 @{角色 id} 都去掉，提示词里换成「@名字」，胶囊点名', { tag: '跨项目' }),
  ],
  [
    frame(`${mCard({ x: 14, y: 22, w: 46, h: 30, label: '镜头 01', text: CFG, sel: true })}${mCard({ x: 70, y: 22, w: 46, h: 30, label: '成片', img: IMG.thumbMountain, sel: true })}${tiny(10, 6, '项目 A · 画布 1')}${tiny(108, 6, 'Ctrl C', T.accent)}`, '项目 A：选中镜头 01 + 成片，Ctrl C', { tag: '1', kind: 'flow', center: false }),
    frame(col(`<div style="font-size: 10px; color: ${T.fg3}">项目 B <span style="color: ${T.fg6}">›</span> 画布 1</div><div style="font-size: 8px; color: ${T.fg5}">剪贴板 app 级 · 还在</div>`, 5), '切到项目 B 的画布；canvasClipboardProvider 是 app 级', { tag: '2', kind: 'flow' }),
    frame(col(`<div style="font-family: ${MONO}; font-size: 8px; color: ${T.fg4}; line-height: 1.7">imports/a1.png.partial<br><span style="color: ${T.success}">→ imports/a1.png</span></div>${mCap(spinIcon(12), '正在粘贴 2 个节点…')}`, 4), 'Ctrl V：先复制文件进本画布 imports/（.partial 再改名），再一个事务写库', { tag: '3', kind: 'flow' }),
    frame(col(`${mCap(ic('success', 12), '已粘贴 2 个节点', '', T.success)}<div style="font-size: 8px; color: ${T.fg5}">· 去掉 1 个角色引用</div>`, 4), '新节点选中；溯源选区内换新 id；provider / 比例 / seed 原样', { tag: '4', kind: 'flow' }),
  ],
  [
    frame(mToast({ kind: 'error', title: '粘贴失败', body: '图像文件没能复制到本画布' }), '复制到一半失败：删掉复制件和 .partial，不写库，零残留', { tag: 'A', kind: 'edge' }),
    frame(mToast({ kind: 'warning', title: '已粘贴 1 个节点', body: '1 张成片的文件已不在，没有粘贴' }), '源文件已被清掉：跳过那张产物、卡上点名，其余照粘', { tag: 'B', kind: 'edge' }),
    frame(`${wires(`${pth('M37 50L72 24', T.fg6, '2 3')}${pth('M119 50L84 24', T.fg6, '2 3')}`)}${mCard({ x: 10, y: 40, w: 46, h: 26, label: '成片', img: IMG.thumbMountain })}${mCard({ x: 96, y: 40, w: 46, h: 26, label: '成片', img: IMG.thumbMountain, sel: true })}${tiny(60, 10, 'a1.png')}`, '同画布：两张引用同一个文件、不复制；回收器只读，删一张不影响另一张', { tag: 'C', kind: 'edge', center: false }),
  ]);

// ================= 5 和撤销卡的关系 =================
const s5 = section('和撤销卡的关系', '卡片是提醒，栈才是本体',
  `${nowTag}已有：ToastKind.undo 停 8 秒（${code('toast_center.dart')} toastDwellFor；设置停留时长「长」翻倍、「从不」不收），主按钮「撤销」（commonUndo），失败出「撤销失败」。文案「节点已删除」「已删除 N 个节点」「连线已删除」「已移入泳道「水墨」」。卡收起后就撤不回（${code('canvas_snackbars.dart')}）`,
  [
    frame(mToast({ title: '已删除 3 个节点', btn: '撤销', bar: '58%' }), '底部倒计时条 8 秒（现状）；新：进栈之外再弹卡', { tag: '默认' }),
    frame(mToast({ title: '已删除 3 个节点', btn: '撤销', bar: '58%', hover: true }), '悬停 / 窗口失焦停表，关闭钮露出（现状）', { tag: '悬停' }),
    frame(mCap(ic('undo', 12), '已撤销 · 删除 3 个节点', kbd('Ctrl Y', T.fg4)), '点「撤销」：卡收起、节点和线复原（现状）；新：胶囊报步名，可 Ctrl Y', { tag: '完成' }),
    frame(mToast({ kind: 'error', title: '撤销失败' }), '现有 undoFailed 错误卡；新：这一步仍留在栈里', { tag: '出错' }),
    frame(`<div style="opacity: .4; width: 100%">${mToast({ title: '已删除 3 个节点', btn: '撤销', dimBtn: true })}</div>`, '关闭画布 / 项目：新——收起它的卡、丢掉它的栈；现状卡还能点，restore 什么也不做', { tag: '失效' }),
  ],
  [
    frame(mToast({ title: '已删除 3 个节点', btn: '撤销', bar: '86%' }), 'Delete 删 3 张：弹卡 + 进栈「删除 3 个节点」，一个 removeNodes 事务', { tag: '1', kind: 'flow' }),
    frame(mStack([stackRow('移动 1 个节点', { top: true }), stackRow('删除 3 个节点')]), '8 秒内又拖了一张：栈顶变成「移动 1 个节点」', { tag: '2', kind: 'flow' }),
    frame(mToast({ title: '已删除 3 个节点', btn: '撤销', bar: '40%', hover: true }), 'UC-1 → A：点卡上「撤销」= undoSpecific，只撤删除这一步', { tag: '3', kind: 'flow' }),
    frame(mStack([stackRow('移动 1 个节点', { top: true }), stackRow('删除 3 个节点', { strike: true, dim: true })]), '删除从栈里抽掉，移动保留；下次 Ctrl Z 撤的是移动', { tag: '4', kind: 'flow' }),
  ],
  [
    frame(`<div style="width: 100%"><div style="display: flex; height: 5px; border-radius: 3px; overflow: hidden"><div style="width: 40%; background: ${T.accent}"></div><div style="flex: 1; background: repeating-linear-gradient(90deg, ${T.controlStrong} 0 6px, transparent 6px 10px)"></div></div><div style="display: flex; justify-content: space-between; font-size: 8px; color: ${T.fg5}; margin-top: 4px"><span>卡 8 秒</span><span>收起 · 栈里还在</span></div><div style="margin-top: 8px; text-align: center">${keycap('Ctrl Z')}</div></div>`, '卡收起后 Ctrl Z 照样撤（现状收起即撤不回）', { tag: 'A', kind: 'edge' }),
    frame(mToast({ title: '已移入泳道「水墨」', btn: '撤销', bar: '62%' }), '拖动换道卡（现状已有）并进栈：撤销 = 回原位 + 原泳道，一步', { tag: 'B', kind: 'edge' }),
    frame(mToast({ title: '已解散泳道「水墨」', body: '4 个节点留在原处', btn: '撤销', bar: '75%' }), '解散不确认，直接解散 + 卡；删除泳道和内容只在有生成中任务时先确认', { tag: 'C', kind: 'edge' }),
  ]);

// ================= 6 系统剪贴板 =================
const s6 = section('系统剪贴板', '从别的软件贴进来；复制节点时也往外写一份文字',
  `${nowTag}尚无读取。文字用 Flutter 自带 Clipboard.getData；图片要新依赖 pasteboard（IS-Q1 → A，与拖入共用一套，${need('dep-drop-pasteboard')}），写进 canvases/&lt;id&gt;/imports/ 与导入媒体同一条路`,
  [
    frame(`${mCard({ x: 40, y: 12, w: 100, h: 46, label: '剪贴板图像', img: IMG.wide, sel: true })}`, '图片 → 图像产物节点，无源配置、未入链', { tag: '图片', center: false }),
    frame(`${mCard({ x: 40, y: 12, w: 100, h: 46, label: '文本', text: '第三场。夜，江边客栈。灯笼在风里晃。', sel: true })}`, '文字 → 文本节点（typeConfig.text），可连到配置当提示词', { tag: '文字', center: false }),
    frame(`${mCard({ x: 34, y: 18, w: 46, h: 30, label: '镜头 01', text: CFG, sel: true })}${mCard({ x: 90, y: 18, w: 46, h: 30, label: '成片', img: IMG.thumbMountain, sel: true })}`, '文字指纹对得上本应用复制出去的 → 按节点粘贴', { tag: '本应用节点', center: false }),
    frame(mCap(spinIcon(12), '正在写入图像…'), '大图写盘时出现；写完原地变成节点选中', { tag: '进行中' }),
    frame(mCap(ic('info', 12), '剪贴板里没有能粘贴的内容'), '空、或是文件列表 / 富文本以外的格式：只出胶囊', { tag: '空' }),
    frame(mToast({ kind: 'error', title: '图像粘贴失败', body: '没有写入任何节点' }), '写盘失败：删 .partial，零残留', { tag: '出错' }),
  ],
  [
    frame(`<div style="position: absolute; left: 14px; top: 10px; right: 14px; bottom: 10px; border: 1px solid ${T.control}; border-radius: 3px; background: ${T.s3}"><div style="height: 10px; border-bottom: 1px solid ${T.control}"></div><img src="${IMG.thumbWide}" alt="" style="position: absolute; left: 10px; top: 16px; width: 60px; height: 36px; object-fit: cover; outline: 1px solid ${T.accent}"><div style="position: absolute; right: 8px; top: 24px">${keycap('Ctrl C')}</div></div>`, '在浏览器里复制一张图', { tag: '1', kind: 'flow', center: false }),
    frame(`${cursor(90, 34)}${tiny(108, 40, 'Ctrl V', T.accent)}`, '回到画布，指针在空白处按 Ctrl V', { tag: '2', kind: 'flow', center: false }),
    frame(col(`<div style="font-family: ${MONO}; font-size: 8px; color: ${T.fg4}; line-height: 1.7">imports/clip-0917.png.partial<br><span style="color: ${T.success}">→ clip-0917.png</span></div>`), '写进本画布 imports/，先 .partial 再改名', { tag: '3', kind: 'flow' }),
    frame(`${mCard({ x: 40, y: 12, w: 100, h: 46, label: '剪贴板图像 · 未入链', img: IMG.wide, sel: true })}`, '图像节点落在指针处、选中；进栈「粘贴 图像」', { tag: '4', kind: 'flow', center: false }),
  ],
  [
    frame(col(`${mCap(ic('text', 12), '已粘贴为文本', `<button type="button" style="font-size: 10px; color: ${T.accent}; white-space: nowrap">按剧本拆镜…</button>`)}`), 'UC-5 → A：分段文字只建一个文本节点，胶囊给「按剧本拆镜…」，不弹框', { tag: 'A', kind: 'edge' }),
    frame(`<div style="width: 100%; box-sizing: border-box; padding: 5px 7px; border-radius: 3px; background: ${T.s3}; border: 1px solid ${T.control}; font-family: ${MONO}; font-size: 8px; line-height: 1.6; color: ${T.fg3}">镜头 01<br>拂晓雾江，渔夫站在船头收网…<br>成片</div>`, '复制节点时往外写纯文字（标签 + 提示词），贴到别的软件就是这段', { tag: 'B', kind: 'edge' }),
    frame(col(`${mInput('第三场。夜，江边客栈。')}<div style="align-self: flex-end">${keycap('Ctrl V')}</div>`, 4), '文本框有焦点：Ctrl V 归文本框，只粘文字、不建节点（mac ⌘V 同理）', { tag: 'C', kind: 'edge' }),
  ]);

// ================= 本板取的决定 =================
const dec = (id, t) => `<div style="display: flex; gap: 8px; font-size: 11px; line-height: 1.55"><span style="font-family: ${MONO}; font-size: 10px; color: ${T.accent}; width: 44px; flex: none">${id}</span><span style="color: ${T.fg3}">${t}</span></div>`;
const decisions = `
  <div style="background: ${T.wash}; border: 1px solid ${T.washBorder}; border-radius: 6px; padding: 12px 16px">
    <div style="font-weight: 500; color: ${T.fg1}; margin-bottom: 6px">本板取的决定</div>
    <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 2px 32px">
      ${dec('TC-Q1', 'A 改写边：设为当前的撤销令牌 = 旧 pinned_result_id + 被改写 data 边的旧上游；按两端找边')}
      ${dec('UC-1', 'A 卡上写哪步撤哪步（undoSpecific），删除的复原彼此独立')}
      ${dec('UC-2', 'A 撤销新建时在生成：照删，任务跑完落成未入链结果，胶囊补一句')}
      ${dec('UC-3', 'A 撤销批量 slot 的设为当前：主图、promoted slot、当前 take、改写的线全回')}
      ${dec('UC-4', 'A 粘贴产物而源配置没跟来：断开溯源，成未入链独立图')}
      ${dec('UC-5', 'A 分段文字：一个文本节点 + 胶囊「按剧本拆镜…」')}
      ${dec('IS-Q1', 'A 读剪贴板图片与拖入共用 pasteboard 一套')}
    </div>
  </div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="position: absolute; left: 32px; top: 24px; right: 32px">
    <div style="display: flex; align-items: baseline; gap: 14px">
      <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">撤销与剪贴板 · 状态与流程</div>
      <div style="color: ${T.fg4}">原板六栏逐个拆成状态条 + 流程（实线圆标）+ 边界（虚线方标）</div>
    </div>
    <div style="font-size: 11px; color: ${T.fg5}; margin-top: 4px">按建议：TC-Q1 → A（改写边），设为当前的撤销按两端找边；原板需要你定 1–5 全取 A；IS-Q1 → A。键位按 Windows 写，mac 换成 ⌘ / ⇧⌘Z，差异见第一栏边界 A。${newTag}= 尚无，${nowTag}= 已上线照现有组件画</div>
  </div>
  <div style="position: absolute; left: 32px; right: 32px; top: 84px; display: flex; flex-direction: column; gap: 12px">
    ${s1}
    ${divider}
    ${s2}
    ${divider}
    ${s3}
    ${divider}
    ${s4}
    ${divider}
    ${s5}
    ${divider}
    ${s6}
    ${decisions}
  </div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'UndoClipboardDetail.dc.html', html: page('撤销与剪贴板 · 状态与流程', W, H, body, logic), W, H };
