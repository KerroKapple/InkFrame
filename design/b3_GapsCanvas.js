// 第三批细化画板：画布补漏 · 状态与流程（1280×H，静态）
// 对应第二批画板 b2_gaps_canvas.js（GapsCanvas，原标题「画布补漏」）：把新建下一镜、新建菜单补项、节点右键补项、
// 「更多」下拉、命名统一与空画布、便签字号、画布轻提示胶囊与缩放 / 适应，逐个拆成 状态条 / 逐步流程 / 边界帧。
//
// 按建议走的决定：KM-Q1 与 GC-N3 冲突，选 GC-N3 的 A——锚点已有下一镜时 Ctrl → 开分叉，新叙事边排在已有分叉之后
// （sortOrder 走现有 nextNarrativeSortOrder = 已有最大值 + 1，与新建菜单「下一镜」一致）；要插到中间就拖到线上插入。
// 原画板「需要你定」里未拍板的一律按建议画：N1 A（继承角色与负面提示词）、N2 A（复用出端口拖线）、N4 A（角色组建图像
// 配置并挂上）、N5 A（加入叙事链末尾不挪位置）、N6 A（便签两档字号）、N7 A（泳道风格留空即分组）。IS-Q5（便签怎么存）
// 仍未定，便签一节按它的建议 A（文本节点 variant = note）画。
//
// 现状核对：lib/features/canvas/widgets/（canvas_screen、canvas_view、node_card、canvas_toolbar、canvas_zoom_bar、
// create_node_menu、canvas_empty_state）与 canvas/util/（create_menu_model、canvas_tool_actions、viewport_fit、
// drop_placement、edge_style）。每节标题下一行写「现状」，每帧说明里新增的写「新增」。
const { T, IMG, SANS, MONO, page, ic } = require('./common.js');

const W = 1280, PAD = 24, CW = W - 2 * PAD, GAP = 8;
const SH_S = 58, SH_F = 78; // 状态帧 / 流程与边界帧的样稿高
// 高度估算：页头 ~118；每节 = 上距 14 + 标题 22 + 现状行 15 + 6 + 状态行（12 + 58 + 5 + 16 + 两行说明 29 = 120）+ 8
// + 流程行（12 + 78 + 5 + 16 + 29 = 140）≈ 325；六节双行 1950 + 单行一节（命名统一）~197 ≈ 2265；底部余量约 60。
const H = 2400;

const fw = (n) => Math.floor((CW - GAP * (n - 1)) / n);

// ---- 小件 ----
const code = (t) => `<span style="font-family: ${MONO}; font-size: 9.5px; color: ${T.fg3}">${t}</span>`;
const prio = (p) => `<span style="height: 16px; padding: 0 5px; border-radius: 3px; border: 1px solid ${p === 'P1' ? T.washBorder : T.control}; color: ${p === 'P1' ? T.accent : T.fg4}; font-family: ${MONO}; font-size: 10px; display: inline-flex; align-items: center">${p}</span>`;
const badgeNum = (n) => `<span style="width: 16px; height: 16px; border-radius: 8px; background: ${T.accent}; color: ${T.onAccent}; font-family: ${MONO}; font-size: 10px; font-weight: 500; display: inline-flex; align-items: center; justify-content: center; flex: none">${n}</span>`;
const badgeEdge = `<span style="height: 15px; padding: 0 4px; border-radius: 3px; border: 1px dashed ${T.washBorder}; color: ${T.accent}; font-size: 9px; display: inline-flex; align-items: center; flex: none">边界</span>`;
const headTxt = (t) => `<span style="font-size: 11px; font-weight: 500; color: ${T.fg1}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${t}</span>`;
const GRID = `background-color: ${T.s1}; background-image: linear-gradient(${T.grid} 1px, transparent 1px), linear-gradient(90deg, ${T.grid} 1px, transparent 1px); background-size: 12px 12px;`;

const frame = (w, sh, head, desc, inner) => `
  <div style="width: ${w}px; flex: none; box-sizing: border-box; border-radius: 4px; background: ${T.s3}; border: 1px solid ${T.bSubtle}; padding: 6px">
    <div style="position: relative; height: ${sh}px; border-radius: 3px; overflow: hidden; ${GRID} outline: 1px solid ${T.bSubtle}">${inner}</div>
    <div style="margin-top: 5px; display: flex; align-items: center; gap: 5px; height: 16px; min-width: 0">${head}</div>
    <div style="margin-top: 1px; font-size: 10px; line-height: 1.45; color: ${T.fg4}">${desc}</div>
  </div>`;
// 帧描述：{ k: 's' | 'f' | 'e', n, t, d, x }
const S = (t, d, x) => ({ k: 's', t, d, x });
const F = (n, t, d, x) => ({ k: 'f', n, t, d, x });
const E = (t, d, x) => ({ k: 'e', t, d, x });
const row = (list, sh) => {
  const w = fw(list.length);
  return `<div style="display: flex; gap: ${GAP}px; align-items: stretch">${list.map((it) => frame(w, sh,
    it.k === 'f' ? badgeNum(it.n) + headTxt(it.t) : it.k === 'e' ? badgeEdge + headTxt(it.t) : headTxt(it.t),
    it.d, it.x)).join('')}</div>`;
};
const section = (title, p, slice, now, rows) => `
  <div style="margin-top: 14px">
    <div style="display: flex; align-items: center; gap: 8px; height: 22px">
      <div style="font-size: 13px; font-weight: 500; color: ${T.fg1}">${title}</div>${prio(p)}<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">${slice}</span>
    </div>
    <div style="height: 15px; margin-bottom: 6px; font-size: 10px; color: ${T.fg5}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis"><span style="color: ${T.fg4}">现状</span>　${now}</div>
    ${rows.map((r, i) => (i ? `<div style="height: 8px"></div>` : '') + r).join('')}
  </div>`;

// ---- 画布小样 ----
const pos = (x, y, inner, extra = '') => `<div style="position: absolute; left: ${x}px; top: ${y}px; ${extra}">${inner}</div>`;
const card = ({ x, y, w = 46, t, ty = '', body = '', thumb = '', sel = false, ghost = false, anchor = false, dim = false, hint = '' }) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; opacity: ${dim ? 0.45 : 1}">
    <div style="height: 11px; display: flex; gap: 3px; font-size: 8px; line-height: 11px">
      <span style="color: ${sel || ghost ? T.fg1 : T.fg3}; font-weight: 500; white-space: nowrap; overflow: hidden">${t}</span><span style="flex: 1"></span><span style="color: ${T.fg6}; white-space: nowrap">${ty}</span>
    </div>
    <div style="position: relative; height: 24px; box-sizing: border-box; border-radius: 2px; overflow: hidden; background: ${ghost ? T.wash : T.thumb}; ${ghost || anchor ? `border: 1px dashed ${T.accent}` : `outline: ${sel ? `1.5px solid ${T.accent}` : `1px solid ${T.outline}`}`}">
      ${thumb ? `<img src="${thumb}" alt="" style="width: 100%; height: 100%; object-fit: cover; display: block">` : `<div style="padding: 2px 3px; font-size: 7px; line-height: 1.35; color: ${T.fg4}; overflow: hidden; height: 20px">${body}</div>`}
      ${hint}
    </div>
  </div>`;
const CY = 11 + 12; // 卡片中线（相对卡片顶）
const svgL = (inner) => `<svg width="200" height="${SH_F}" viewBox="0 0 200 ${SH_F}" aria-hidden="true" style="position: absolute; left: 0; top: 0; overflow: visible">${inner}</svg>`;
const arrowHead = (x, y, c) => `<path d="M${x - 4} ${y - 3}L${x} ${y}L${x - 4} ${y + 3}" fill="none" stroke="${c}" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"></path>`;
// 叙事线：实线 2.0 fg4（edge_style 现状）；产出线：点线 fg6；dip = 中段下沉（绕过中间的卡）
const narr = (x1, y1, x2, y2, { c = T.fg4, dip = 0, arrow = true, dash = '' } = {}) => `<path d="M${x1} ${y1}C${x1 + 14} ${y1 + dip} ${x2 - 14} ${y2 + dip} ${x2} ${y2}" fill="none" stroke="${c}" stroke-width="2" ${dash ? `stroke-dasharray="${dash}"` : ''}></path>${arrow ? arrowHead(x2, y2, c) : ''}`;
const lineage = (x1, y, x2) => `<path d="M${x1} ${y}L${x2} ${y}" fill="none" stroke="${T.fg6}" stroke-width="1.25" stroke-dasharray="1.5 3" stroke-linecap="round"></path>`;
const kchip = (k, { dim = false, hot = false } = {}) => `<span style="height: 16px; padding: 0 5px; border-radius: 3px; background: ${hot ? T.wash : T.s4}; border: 1px solid ${hot ? T.washBorder : T.overlayBorder}; font-family: ${MONO}; font-size: 9px; color: ${dim ? T.fg6 : hot ? T.accent : T.fg2}; display: inline-flex; align-items: center; white-space: nowrap${dim ? '; text-decoration: line-through' : ''}">${k}</span>`;
const ptr = (x, y) => pos(x, y, ic('select', 12), `color: ${T.fg1}`);
const spin = (size = 12) => `<div class="spin" style="display: flex; color: ${T.accent}">${ic('progress', size)}</div>`;
const center = (inner, extra = '') => `<div style="position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 5px; ${extra}">${inner}</div>`;
const lane = (top, h) => `<div style="position: absolute; left: 0; right: 0; top: ${top}px; height: ${h}px; background: ${T.s2}; border-top: 1px solid ${T.laneDivider}; border-bottom: 1px solid ${T.laneDivider}"></div>`;
const laneTag = (x, y, label) => pos(x, y, `<div style="height: 12px; display: flex; align-items: center; gap: 3px; padding: 0 4px; border-radius: 2px; background: ${T.s4}; border: 1px solid ${T.outline}; font-size: 7px; color: ${T.fg3}"><span style="width: 5px; height: 5px; border-radius: 1px; background: ${T.peach}"></span>${label}</div>`);

// 迷你菜单：行高 12、字号 8.5（样稿比实物紧，实物见 create_node_menu 的 CanvasMenuPanel）
const mrow = (label, { icon = '', key = '', hi = false, dis = false, danger = false, sub = false, tag = '', thumb = '', meta = '' } = {}) => `
  <div style="height: 12px; display: flex; align-items: center; gap: 4px; padding: 0 4px; border-radius: 2px; ${hi ? `background: ${T.s5};` : ''} color: ${danger ? T.danger : dis ? T.fg6 : T.fg2}; font-size: 8.5px; white-space: nowrap">
    ${thumb ? `<img src="${thumb}" alt="" style="width: 9px; height: 9px; object-fit: cover; border-radius: 2px; flex: none">`
      : icon ? `<span style="display: flex; color: ${dis ? T.fg6 : T.fg4}">${ic(icon, 9)}</span>` : '<span style="width: 9px; flex: none"></span>'}
    <span style="flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis">${label}</span>${tag}
    ${meta ? `<span style="font-size: 7.5px; color: ${T.fg5}">${meta}</span>` : ''}${key ? `<span style="font-family: ${MONO}; font-size: 7.5px; color: ${T.fg5}">${key}</span>` : ''}${sub ? `<span style="color: ${T.fg5}">›</span>` : ''}
  </div>`;
const msep = `<div style="height: 1px; background: ${T.bStrong}; margin: 1px 0"></div>`;
const mgrp = (t) => `<div style="height: 10px; padding: 0 4px; font-size: 7.5px; color: ${T.fg5}; display: flex; align-items: center">${t}</div>`;
const msearch = (t, typed = false) => `<div style="height: 13px; display: flex; align-items: center; gap: 3px; padding: 0 4px; border-bottom: 1px solid ${T.bStrong}; margin-bottom: 1px; color: ${typed ? T.fg1 : T.fg6}; font-size: 8.5px">${ic('search', 8)}<span>${t}</span>${typed ? `<span style="width: 1px; height: 8px; background: ${T.fg1}"></span>` : ''}</div>`;
const mmenu = (inner, w = 120) => `<div style="width: ${w}px; box-sizing: border-box; padding: 2px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 10px 24px rgba(0,0,0,0.55)">${inner}</div>`;
const tagNew = `<span style="height: 9px; padding: 0 2px; border-radius: 2px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 6.5px; display: inline-flex; align-items: center">新</span>`;
const tagWarn = (t) => `<span style="height: 9px; padding: 0 2px; border-radius: 2px; border: 1px solid ${T.controlStrong}; color: ${T.fg5}; font-size: 6.5px; display: inline-flex; align-items: center">${t}</span>`;
const tip = (t) => `<div style="height: 14px; padding: 0 5px; border-radius: 3px; background: ${T.s5}; border: 1px solid ${T.overlayBorder}; color: ${T.fg2}; font-size: 8px; display: inline-flex; align-items: center; white-space: nowrap; box-shadow: 0 4px 10px rgba(0,0,0,0.4)">${t}</div>`;
// 轻提示胶囊（canvas-capsule，新增；与 b2 同一个样子按比例缩）
const cap = (text, { icon = '', right = '', dim = false } = {}) => `
  <div style="display: inline-flex; align-items: center; gap: 5px; height: 18px; padding: 0 8px; border-radius: 999px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; box-shadow: 0 6px 14px rgba(0,0,0,0.45); color: ${T.fg2}; font-size: 8.5px; white-space: nowrap; box-sizing: border-box; opacity: ${dim ? 0.4 : 1}">
    ${icon ? `<span style="display: flex; color: ${T.fg3}">${ic(icon, 9)}</span>` : ''}<span>${text}</span>${right ? `<span style="width: 1px; height: 8px; background: ${T.control}"></span>${right}` : ''}
  </div>`;
const capKey = (k) => `<span style="font-family: ${MONO}; font-size: 7.5px; color: ${T.fg4}">${k}</span>`;
// 迷你通知卡（ToastCenter 的 error：不自动消失）
const errCard = (t) => `
  <div style="width: 138px; box-sizing: border-box; display: flex; gap: 5px; align-items: center; padding: 5px 6px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 8px 20px rgba(0,0,0,0.45)">
    <div style="width: 16px; height: 16px; flex: none; border-radius: 3px; background: ${T.s5}; color: ${T.danger}; display: flex; align-items: center; justify-content: center">${ic('error', 10)}</div>
    <div style="flex: 1; min-width: 0; font-size: 8.5px; color: ${T.fg1}; line-height: 1.35">${t}</div>
    <span style="display: flex; color: ${T.fg5}">${ic('close', 9)}</span>
  </div>`;
const okCard = (t) => `
  <div style="width: 138px; box-sizing: border-box; display: flex; gap: 5px; align-items: center; padding: 5px 6px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 8px 20px rgba(0,0,0,0.45)">
    <div style="width: 16px; height: 16px; flex: none; border-radius: 3px; background: ${T.s5}; color: ${T.success}; display: flex; align-items: center; justify-content: center">${ic('success', 10)}</div>
    <div style="flex: 1; min-width: 0; font-size: 8.5px; color: ${T.fg1}; line-height: 1.35">${t}</div>
  </div>`;
const field = (before, after = '') => `<div style="width: 128px; height: 18px; box-sizing: border-box; padding: 0 6px; border-radius: 3px; background: ${T.s2}; border: 1px solid ${T.accent}; display: flex; align-items: center; font-size: 8.5px; color: ${T.fg2}; white-space: nowrap; overflow: hidden">${before}<span style="width: 1px; height: 10px; background: ${T.fg1}; margin: 0 1px"></span>${after}</div>`;
// 迷你按钮（InkAmberButton / InkGhostButton 的样子）
const btn = (label, { amber = false, hover = false, focus = false, dis = false } = {}) => `<button type="button" style="height: 15px; padding: 0 6px; border-radius: 3px; font-size: 8px; white-space: nowrap; ${amber
  ? `background: ${dis ? T.s5 : hover ? T.accentHover : T.accent}; color: ${dis ? T.fg6 : T.onAccent}; font-weight: 500`
  : `border: 1px solid ${T.controlStrong}; color: ${dis ? T.fg6 : T.fg2}; ${hover ? `background: ${T.s5}` : ''}`}; ${focus ? `outline: 1.5px solid ${T.accent}; outline-offset: 1px` : ''}">${label}</button>`;

// ============ 1 新建下一镜 ============
const cfg02 = (o = {}) => card(Object.assign({ x: 6, y: 18, t: '镜头 02', ty: '视频', body: '江面雾气渐散，孤舟驶出' }, o));
const take02 = (o = {}) => card(Object.assign({ x: 58, y: 18, t: '成片', ty: '视频', thumb: IMG.thumbWide }, o));
const secNext = section('新建下一镜', 'P1', 'next-shot-core',
  `新建菜单「下一镜（叙事）」已有（${code('create_menu_model.dart')} nextShot → ${code('addNodeFromMenu')}：先建节点再连线、失败手工回滚，只建空节点）；Ctrl → / ⌘→、继承参数、一个事务、右键入口为新增`,
  [
    row([
      S('可用', '恰好选中一张镜头 / 图像 / 视频配置；右键项可点', `${cfg02({ y: 12, sel: true })}${pos(64, 20, kchip('Ctrl →', { hot: true }))}`),
      S('选中的是产物', '锚点取它的来源配置（现状 narrativeAnchorOf）', `${svgL(lineage(52, 12 + CY, 58))}${cfg02({ y: 12, anchor: true })}${take02({ y: 12, sel: true })}${pos(108, 22, `<span style="font-size: 8px; color: ${T.accent}">锚点</span>`)}`),
      S('不响应', '文本 / 便签 / 多选 / 没选中：按键无反应，菜单项置灰', `${card({ x: 6, y: 12, t: '文本', ty: '文本', body: '旁白：天将亮', sel: true })}${card({ x: 56, y: 12, t: '镜头 05', ty: '图像', body: '渔夫收网', sel: true })}${pos(108, 20, kchip('Ctrl →', { dim: true }))}`),
      S('焦点在文字里', 'Ctrl → 归光标跳词（mac ⌘→ 到行尾），不建节点', center(`${field('江面雾气', '渐散')}<div style="font-size: 8px; color: ${T.fg5}">提示词条 · 检查器</div>`)),
      S('写入中', '节点和边一个事务；这时再按忽略，不排队', `${svgL(narr(52, 12 + CY, 92, 12 + CY, { c: T.fg6, dash: '3 3' }))}${cfg02({ y: 12 })}${card({ x: 94, y: 12, t: '镜头 03', ty: '视频', ghost: true, hint: center(spin(11)) })}`),
      S('完成', '新镜单选，焦点留画布；↵ 进提示词条（新键）', `${svgL(narr(52, 12 + CY, 92, 12 + CY))}${cfg02({ y: 12 })}${card({ x: 94, y: 12, t: '镜头 03', ty: '视频', body: '（提示词留空）', sel: true })}`),
      S('出错', '事务回滚，不留节点也不留线；错误卡等用户关', center(errCard('添加节点失败'))),
    ], SH_S),
    row([
      F(1, '选中镜头 02', '锚点 + 它名下产物那一列（take）', `${lane(6, 66)}${laneTag(4, 9, '水墨风格')}${svgL(lineage(52, 24 + CY, 58))}${cfg02({ y: 24, sel: true })}${take02({ y: 24 })}`),
      F(2, '按 Ctrl →', 'Windows Ctrl →，mac ⌘→；画布本身持焦才接管', `${lane(6, 66)}${laneTag(4, 9, '水墨风格')}${svgL(lineage(52, 24 + CY, 58))}${cfg02({ y: 24, sel: true })}${take02({ y: 24 })}${pos(108, 30, `<div style="display: flex; flex-direction: column; gap: 3px">${kchip('Ctrl →', { hot: true })}${kchip('⌘→', { hot: true })}</div>`)}`),
      F(3, '新镜接上', '落在产物列后空 64；继承模型 · 画幅 · 时长 · 运镜 · 角色', `${lane(6, 66)}${laneTag(4, 9, '水墨风格')}${svgL(`${lineage(52, 24 + CY, 58)}${narr(52, 24 + CY, 108, 24 + CY, { dip: 30 })}`)}${cfg02({ y: 24 })}${take02({ y: 24 })}${card({ x: 108, y: 24, t: '镜头 03', ty: '视频', body: '万相 i2v · 5 秒 · 推镜', sel: true })}`),
      E('已有下一镜：开分叉', 'KM-Q1 / GC-N3 选 A：排在已有分叉后；插中间就拖到线上', `${svgL(`${narr(48, 6 + CY, 58, 6 + CY)}${narr(48, 6 + CY, 110, 6 + CY, { dip: 34, c: T.accent })}`)}${card({ x: 4, y: 6, w: 44, t: '02', ty: '视频', body: '江面' })}${card({ x: 58, y: 6, w: 44, t: '03', ty: '视频', body: '已有' })}${card({ x: 110, y: 6, w: 44, t: '03′', ty: '视频', body: '新分叉', sel: true })}${pos(10, 54, cap('已新开分叉 · 在 02 之后', { icon: 'sequence' }))}`),
      E('落点被占', '沿主轴再后挪一格；不换横截位置、不出泳道；竖向泳道向下', `${lane(6, 66)}${svgL(narr(52, 24 + CY, 108, 24 + CY, { dip: 30 }))}${cfg02({ y: 24 })}<div style="position: absolute; left: 58px; top: 35px; width: 46px; height: 24px; box-sizing: border-box; border: 1px dashed ${T.fg6}; border-radius: 2px; font-size: 7px; color: ${T.fg5}; display: flex; align-items: center; justify-content: center">已被便签占</div>${card({ x: 108, y: 24, t: '镜头 03', ty: '视频', body: '（留空）', sel: true })}`),
      E('拖线入口', '出端口拖到空白：「下一镜」置顶高亮，落在松手处（N2 A）', `${svgL(`<path d="M52 ${16 + CY}C66 ${16 + CY} 62 14 72 14" fill="none" stroke="${T.accent}" stroke-width="1.5" stroke-dasharray="3 2"></path>`)}${card({ x: 6, y: 16, t: '镜头 01', ty: '图像', body: '拂晓雾江', sel: true })}${pos(49, 13 + CY, `<div style="width: 6px; height: 6px; border-radius: 3px; background: ${T.accent}"></div>`)}${pos(72, 6, mmenu(`${mrow('下一镜（叙事）', { key: '↵', hi: true })}${msep}${mrow('当首帧 · 视频配置', { icon: 'videoConfig' })}${mrow('当参考 · 图像配置', { icon: 'imageConfig' })}`, 82))}`),
      E('撤销', 'Ctrl Z / ⌘Z 一步撤掉节点 + 边；undo-stack 未合前不登记', center(`${cap('已撤销 · 新建下一镜', { icon: 'undo', right: capKey('重做 Ctrl Y') })}<div style="font-size: 8px; color: ${T.fg5}">mac 重做 ⌘⇧Z</div>`)),
    ], SH_F),
  ]);

// ============ 2 新建菜单补项 ============
const plainTop = (hi = 0) => `${msearch('直接打字搜索…')}${mrow('图像配置', { icon: 'imageConfig', key: 'I', hi: hi === 0 })}${mrow('视频配置', { icon: 'videoConfig', key: 'G', hi: hi === 1 })}${mrow('文本', { icon: 'text', key: 'T', hi: hi === 2 })}${mrow('便签', { icon: 'note', key: 'N', tag: tagNew })}`;
const secCreate = section('新建菜单补项', 'P2', 'create-menu-pick-recent · create-menu-notes-characters',
  `${code('create_node_menu.dart')} 不带上下文五项：图像配置 I · 视频配置 G · 文本 T · 镜头 · 泳道 F；搜索按文字包含匹配，无匹配写「没有匹配的操作」；便签、最近用过、模型、角色四组为新增`,
  [
    row([
      S('默认', '建节点组 + 便签 + 最近用过 + 角色；首项高亮', pos(18, 4, mmenu(plainTop(0)))),
      S('悬停 / ↑↓', '悬停与方向键同一道高亮；置灰项跳过（现状）', `${pos(18, 4, mmenu(plainTop(2)))}${ptr(92, 44)}`),
      S('打字过滤', '打字才出「模型」组，按 Provider 名和 id 匹配', pos(18, 4, mmenu(`${msearch('万相', true)}${mgrp('模型')}${mrow('图像配置 · 万相 图像', { icon: 'imageConfig', hi: true })}${mrow('视频配置 · 万相 图生视频', { icon: 'videoConfig' })}`))),
      S('无匹配', '空态一行，↵ 无动作（现状 canvasCreateMenuNoMatch）', pos(18, 4, mmenu(`${msearch('xyz', true)}<div style="height: 14px; padding: 0 4px; font-size: 8.5px; color: ${T.fg5}; display: flex; align-items: center">没有匹配的操作</div>`))),
      S('最近用过为空', '本项目还没有 job：整组不出，不留空标题', pos(18, 4, mmenu(`${mrow('泳道', { icon: 'lane', key: 'F' })}${msep}${mgrp('角色 · 建图像配置并挂上')}${mrow('老渔夫', { thumb: IMG.thumbMountain, meta: '3 张' })}`))),
      S('无 Key', '标「无 Key」照样能建；生成时再提示配 Key', pos(18, 4, mmenu(`${mgrp('最近用过')}${mrow('万相 图生视频', { icon: 'videoConfig', meta: '5 秒' })}${mrow('Gemini 图像', { icon: 'imageConfig', tag: tagWarn('无 Key'), hi: true })}`))),
      S('加载中', '最近用过还没查回：先不出组，回来再插入，高亮不跳', pos(18, 4, mmenu(`${mrow('镜头', { icon: 'shot' })}${mrow('泳道', { icon: 'lane', key: 'F' })}${msep}<div style="height: 12px; padding: 0 4px; display: flex; align-items: center; gap: 4px; font-size: 7.5px; color: ${T.fg6}">${spin(8)}最近用过</div>`))),
    ], SH_S),
    row([
      F(1, '双击空白', '或 Tab / 空白右键「新建…」，同一个菜单开在锚点', `${ptr(20, 30)}${pos(32, 8, mmenu(plainTop(0), 112))}`),
      F(2, '打字「万相」', '建节点组同样过滤；模型组接在后面', pos(32, 8, mmenu(`${msearch('万相', true)}${mgrp('模型')}${mrow('图像配置 · 万相 图像', { icon: 'imageConfig', hi: true })}${mrow('视频配置 · 万相 图生视频', { icon: 'videoConfig' })}`, 112))),
      F(3, '↓ 再 ↵', '↑↓ 移动、↵ 确认；Esc 关，焦点当场回画布', pos(32, 8, mmenu(`${msearch('万相', true)}${mgrp('模型')}${mrow('图像配置 · 万相 图像', { icon: 'imageConfig' })}${mrow('视频配置 · 万相 图生视频', { icon: 'videoConfig', hi: true, key: '↵' })}`, 112))),
      F(4, '节点落在锚点', '写入 provider_id + 参数（不含提示词、种子），单选不挪相机', `${card({ x: 26, y: 18, w: 60, t: '新节点', ty: '视频', body: '万相 i2v · 5 秒 · 720p', sel: true })}${pos(16, 54, `<span style="font-size: 7.5px; color: ${T.fg5}">双击点 = 卡片左上</span>`)}`),
      E('点角色', '建图像配置并挂上该角色（N4 A），参考图计入配额', `${pos(8, 8, mmenu(`${mgrp('角色')}${mrow('老渔夫', { thumb: IMG.thumbMountain, meta: '3 张', hi: true })}${mrow('孤舟', { thumb: IMG.thumbWide, meta: '1 张' })}`, 80))}${card({ x: 96, y: 30, w: 54, t: '新节点', ty: '图像', body: '@老渔夫', sel: true })}`),
      E('带连线上下文', '从端口拖出时不加新组：首帧 / 尾帧 / 参考 | 下一镜（现状）', pos(30, 6, mmenu(`${msearch('直接打字搜索…')}${mrow('下一镜（叙事）', { hi: true })}${msep}${mrow('当首帧 · 视频配置', { icon: 'videoConfig' })}${mrow('当尾帧 · 视频配置', { icon: 'videoConfig' })}`, 112))),
      E('建节点失败', '不留节点；「最近用过」不因失败变化', center(errCard('添加节点失败'))),
    ], SH_F),
  ]);

// ============ 3 节点右键补项 ============
const nodeMenuTop = (hi = '') => `${mrow('生成', { icon: 'run', key: 'Ctrl ↵' })}${mrow('新建下一镜', { icon: 'shot', key: 'Ctrl →', tag: tagNew, hi: hi === 'next' })}${mrow('复制一份', { key: 'Ctrl D' })}${msep}${mrow('设为当前', { icon: 'pin', dis: true })}`;
const secNodeMenu = section('节点右键补项', 'P1', 'node-menu-next-shot-append-chain · locate-in-gallery',
  `${code('create_node_menu.dart')} 三组：生成 · 复制一份 | 存为角色 · 加入泳道 › · 在序列中定位 | 删除；置灰不隐藏但不说原因。新建下一镜、加入叙事链末尾、在画廊中定位、悬停说原因为新增`,
  [
    row([
      S('默认', '分组：做 | take | 归类 | 定位 | 停用 · 删除', pos(20, 4, mmenu(nodeMenuTop()))),
      S('置灰说原因', '置灰不隐藏，悬停 400ms 出原因（新增）', `${pos(8, 6, mmenu(`${mrow('加入泳道', { icon: 'lane', sub: true })}${mrow('加入叙事链末尾', { icon: 'sequence', dis: true, hi: true })}${mrow('在序列中定位', { icon: 'sequence', dis: true })}`, 110))}${pos(64, 38, tip('还没有叙事链'))}`),
      S('多选目标', '右键在选中集里 = 整个选中集；不在就先单选它（现状）', `${card({ x: 6, y: 8, t: '镜头 08', ty: '图像', body: '收网', sel: true })}${card({ x: 56, y: 8, t: '镜头 09', ty: '图像', body: '归航', sel: true })}${ptr(90, 22)}${pos(106, 24, `<span style="font-size: 8px; color: ${T.accent}">2 个</span>`)}`),
      S('已在链上', '目标全在链上置灰；部分在链上只接其余', `${pos(8, 6, mmenu(`${mrow('加入叙事链末尾', { icon: 'sequence', dis: true, hi: true })}${mrow('在序列中定位', { icon: 'sequence' })}`, 110))}${pos(64, 26, tip('已在叙事链上'))}`),
      S('画廊定位置灰', '配置节点还没有产物：置灰，原因「还没有产物」', `${pos(8, 6, mmenu(`${mrow('在序列中定位', { icon: 'sequence' })}${mrow('在画廊中定位', { icon: 'assets', dis: true, hi: true, tag: tagNew })}`, 110))}${pos(64, 26, tip('还没有产物'))}`),
      S('完成', '一个事务、撤销一步；只连线不挪位置（N5 A）', center(cap('已接到第 7 镜之后', { icon: 'sequence' }))),
      S('出错', '整批回滚，一条线都不留；错误卡（新文案）', center(errCard('加入叙事链失败'))),
    ], SH_S),
    row([
      F(1, '右键镜头 09', '抬起时开、没挪出点击容差才开；按住拖是拖画布（现状）', `${svgL(narr(52, 8 + CY, 60, 8 + CY, { arrow: false }))}${card({ x: 6, y: 8, t: '第 7 镜', ty: '图像', body: '链尾' })}${card({ x: 96, y: 40, t: '镜头 09', ty: '图像', body: '不在链上', sel: true })}${ptr(122, 54)}`),
      F(2, '选「加入叙事链末尾」', '末尾 = orderByNarrativeChain 只留链上节点后的最后一个', pos(20, 6, mmenu(`${mrow('存为角色', { icon: 'characters' })}${mrow('加入泳道', { icon: 'lane', sub: true })}${mrow('加入叙事链末尾', { icon: 'sequence', tag: tagNew, hi: true })}${msep}${mrow('在画廊中定位', { icon: 'assets', tag: tagNew })}`, 116))),
      F(3, '接上 + 胶囊', '连「第 7 镜 → 09」，位置不动；胶囊点名镜号', `${svgL(narr(52, 8 + CY, 96, 40 + CY, { c: T.accent }))}${card({ x: 6, y: 8, t: '第 7 镜', ty: '图像', body: '链尾' })}${card({ x: 96, y: 40, t: '镜头 09', ty: '图像', body: '第 8 镜', sel: true })}${pos(4, 52, cap('已接到第 7 镜之后'))}`),
      F(4, '选「在画廊中定位」', '产物 = 它自己；配置节点 = 当前 take（current-take 前用最新）', pos(20, 6, mmenu(`${mrow('加入叙事链末尾', { icon: 'sequence' })}${msep}${mrow('在序列中定位', { icon: 'sequence' })}${mrow('在画廊中定位', { icon: 'assets', tag: tagNew, hi: true })}`, 116))),
      F(5, '切到画廊标签', '单选并滚到那一格；被筛选挡住就清筛选并说一句', `<div style="position: absolute; left: 6px; right: 6px; top: 6px; height: 14px; border-radius: 2px; background: ${T.s3}; border: 1px solid ${T.outline}; display: flex; align-items: center; gap: 4px; padding: 0 5px; font-size: 7.5px; color: ${T.accent}">${ic('info', 8)}已清除筛选</div>
        ${[0, 1, 2, 3].map((i) => `<div style="position: absolute; left: ${6 + i * 37}px; top: 26px; width: 33px; height: 22px; border-radius: 2px; overflow: hidden; outline: ${i === 2 ? `1.5px solid ${T.accent}` : `1px solid ${T.outline}`}"><img src="${i % 2 ? IMG.thumbWide : IMG.thumbMountain}" alt="" style="width: 100%; height: 100%; object-fit: cover; display: block; opacity: ${i === 2 ? 1 : 0.55}"></div>`).join('')}
        ${[0, 1, 2, 3].map((i) => `<div style="position: absolute; left: ${6 + i * 37}px; top: 52px; width: 33px; height: 22px; border-radius: 2px; background: ${T.thumb}; outline: 1px solid ${T.outline}"></div>`).join('')}`),
      E('还没有链 · 多选', '单选置灰；多选按位置（先主轴后横截）连成新链', `${svgL(`${narr(48, 10 + CY, 56, 10 + CY)}${narr(98, 10 + CY, 106, 10 + CY)}`)}${card({ x: 4, y: 10, w: 44, t: '1', ty: '图像', body: '左', sel: true })}${card({ x: 56, y: 10, w: 42, t: '2', ty: '图像', body: '中', sel: true })}${card({ x: 106, y: 10, w: 44, t: '3', ty: '视频', body: '右', sel: true })}${pos(8, 54, `<span style="font-size: 7.5px; color: ${T.fg5}">胶囊「已连成 3 镜」</span>`)}`),
      E('目标里有产物', '产物换成来源配置，同一配置只接一次（去重）', `${svgL(`${lineage(52, 10 + CY, 96)}`)}${card({ x: 6, y: 10, t: '镜头 09', ty: '图像', body: '来源', anchor: true })}${card({ x: 96, y: 10, t: 'take 2', ty: '图像', thumb: IMG.thumbMountain, sel: true })}${card({ x: 96, y: 46, t: 'take 1', ty: '图像', thumb: IMG.thumbWide, sel: true })}${pos(6, 54, `<span style="font-size: 7.5px; color: ${T.accent}">只接 09 一次</span>`)}`),
    ], SH_F),
  ]);

// ============ 4 「更多」下拉 ============
const tb = (moreState = '') => {
  const k = (id, on = false) => `<span style="width: 16px; height: 16px; border-radius: 3px; display: inline-flex; align-items: center; justify-content: center; color: ${on ? T.accent : T.fg3}; ${on ? `background: ${T.wash}` : ''}">${ic(id, 10)}</span>`;
  const sepV = `<span style="width: 1px; height: 10px; background: ${T.control}"></span>`;
  const more = `<span style="width: 16px; height: 16px; border-radius: 3px; display: inline-flex; align-items: center; justify-content: center; color: ${moreState === 'open' || moreState === 'mode' ? T.accent : moreState === 'hover' ? T.fg1 : T.fg3}; ${moreState === 'hover' ? `background: ${T.s5};` : ''}${moreState === 'open' || moreState === 'mode' ? `background: ${T.wash};` : ''}${moreState === 'focus' ? `outline: 1.5px solid ${T.accent}; outline-offset: 1px;` : ''}">${ic('more', 10)}</span>`;
  return `<div style="display: inline-flex; align-items: center; gap: 2px; padding: 2px; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.control}">${k('select', moreState !== 'mode')}${k('pan')}${sepV}${k('imageConfig')}${k('videoConfig')}${k('text')}${k('shot')}${k('lane')}${k('link')}${sepV}${more}</div>`;
};
const moreRows = (hi = '') => `${mrow('导入剧本…', { icon: 'script', hi: hi === 'script' })}${mrow('导入媒体…', { icon: 'upload', key: 'Ctrl U' })}${msep}${mrow('整理叙事链', { icon: 'sequence' })}${mrow('运行叙事链…', { icon: 'run' })}${msep}${mrow('切线', { icon: 'link', key: 'Alt 拖', hi: hi === 'cut' })}`;
const tbAt = (s) => pos(6, 6, tb(s));
const wires3 = (cut = 0) => `${svgL(`
    ${narr(30, 30, 120, 30, { c: cut >= 1 ? T.accent : T.fg4 })}
    ${narr(30, 50, 120, 50, { c: cut >= 2 ? T.accent : T.fg4 })}
    ${lineage(30, 66, 120)}
  `)}`;
const knife = (x1, y1, x2, y2) => `<svg width="200" height="${SH_F}" viewBox="0 0 200 ${SH_F}" aria-hidden="true" style="position: absolute; left: 0; top: 0"><path d="M${x1} ${y1}L${x2} ${y2}" fill="none" stroke="${T.danger}" stroke-width="1.25" stroke-dasharray="3 2"></path></svg>`;
const secMore = section('「更多」下拉', 'P2', 'more-dropdown-panel',
  `${code('canvas_toolbar.dart')} 的 ${code('_MoreAction')} 只有「导入脚本…」，用 Material showMenu 贴键下沿弹；键走 InkActivatable（Tab 可达、焦点环），tooltip 只有名称。菜单面板、分组、切线模式为新增`,
  [
    row([
      S('默认', '工具条最右，fg3 图标', tbAt('')),
      S('悬停', 'surface5 底 + tooltip「更多」（无键位）', `${tbAt('hover')}${pos(130, 28, tip('更多'))}`),
      S('键盘聚焦', 'Tab 到达出焦点环；Enter / Space 打开', tbAt('focus')),
      S('打开', '改用 CanvasMenuPanel 往下弹，键位 / ↑↓ ↵ Esc 与右键同一套', `${tbAt('open')}${pos(72, 24, mmenu(moreRows('script'), 96))}`),
      S('项置灰', '画布没有叙事链：整理 / 运行两项置灰并说原因', `${pos(8, 4, mmenu(`${mrow('整理叙事链', { icon: 'sequence', dis: true, hi: true })}${mrow('运行叙事链…', { icon: 'run', dis: true })}`, 100))}${pos(56, 32, tip('还没有叙事链'))}`),
      S('切线模式中', '「更多」键亮；光标是剪刀，选择键不亮', `${tbAt('mode')}${pos(10, 32, `<span style="font-size: 8px; color: ${T.accent}">切线 · 拖过要剪的线 · Esc 退出</span>`)}`),
    ], SH_S),
    row([
      F(1, '点「更多」', '菜单贴键下沿；焦点进菜单，首个可用项高亮', `${tbAt('open')}${pos(72, 24, mmenu(moreRows('script'), 96))}`),
      F(2, '↓ 到「切线」↵', '进一次性切线模式；平时 Alt 拖空白同效', `${tbAt('open')}${pos(72, 24, mmenu(moreRows('cut'), 96))}`),
      F(3, '拖过线', '经过的线变 accent，松手前都能拖回', `${wires3(2)}${knife(70, 18, 82, 60)}${ptr(82, 58)}`),
      F(4, '松手剪掉', '一步撤销；胶囊带撤销；回到选择工具', `${svgL(`${narr(30, 30, 64, 30, { arrow: false, c: T.fg6 })}${narr(90, 30, 120, 30, { c: T.fg6 })}${lineage(30, 66, 120)}`)}${pos(18, 42, cap('已剪断 2 条线', { icon: 'undo', right: capKey('撤销 Ctrl Z') }))}`),
      E('中途 Esc', '高亮清掉，一条都不剪，退出模式', `${wires3(0)}${pos(60, 10, kchip('Esc', { hot: true }))}`),
      E('产出线剪不动', '产出线由 source_node_id 推导，拖过不高亮不剪', `${wires3(0)}${knife(70, 54, 78, 76)}${pos(126, 60, `<span style="font-size: 7.5px; color: ${T.fg5}">产出</span>`)}`),
      E('mac / Windows', 'Windows Alt 拖、mac Option 拖；菜单键位按平台写', center(`<div style="display: flex; gap: 6px">${kchip('Alt 拖')}${kchip('⌥ 拖')}</div><div style="display: flex; gap: 6px">${kchip('Ctrl U')}${kchip('⌘U')}</div>`)),
    ], SH_F),
  ]);

// ============ 5 命名统一 · 空画布（单行）============
const emptyMini = (o = {}) => center(`
  <div style="width: 16px; height: 16px; border-radius: 8px; background: ${T.s4}; color: ${T.fg5}; display: flex; align-items: center; justify-content: center">${ic('imageConfig', 9)}</div>
  <div style="font-size: 8.5px; color: ${T.fg2}">当前画布为空</div>
  <div style="display: flex; flex-wrap: wrap; gap: 3px; justify-content: center; padding: 0 4px">${btn('添加图片节点', { amber: true })}${btn('添加视频节点')}${btn('添加镜头节点', { hover: !!o.hoverShot })}${btn('导入剧本', { focus: !!o.focusScript, hover: !!o.hoverScript })}</div>`, 'gap: 3px');
const dlg = (inner) => `<div style="position: absolute; left: 10px; right: 10px; top: 6px; bottom: 6px; box-sizing: border-box; padding: 5px 6px; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; box-shadow: 0 10px 24px rgba(0,0,0,0.55); display: flex; flex-direction: column; gap: 3px">${inner}</div>`;
const dlgHead = `<div style="font-size: 8.5px; font-weight: 500; color: ${T.fg1}">导入剧本</div>`;
const secNaming = section('命名统一 · 空画布', 'P2', 'naming-shot-unify',
  `${code('app_zh.arb')} 约 14 处「分镜」（canvasEmptyAddShot「添加分镜节点」、canvasToolShotNode、scriptImportConfirm「创建分镜」…）；「导入脚本…」；空画布 ${code('canvas_empty_state.dart')} 一琥珀三幽灵按钮`,
  [
    row([
      S('空画布 · 改后', '「添加分镜节点」→「添加镜头节点」，「导入脚本」→「导入剧本」', emptyMini({ hoverShot: true })),
      S('叫法对照', '只改 ARB（zh + en），断言中文的测试跟着改', center(`<div style="font-size: 8.5px; line-height: 1.6; color: ${T.fg3}">
        <div><span style="color: ${T.fg6}; text-decoration: line-through">分镜</span> → 镜头　×14</div>
        <div><span style="color: ${T.fg6}; text-decoration: line-through">导入脚本</span> → 导入剧本</div>
        <div><span style="color: ${T.fg6}; text-decoration: line-through">创建分镜</span> → 创建 N 个镜头</div></div>`)),
      F(1, '点「导入剧本」', '空画布或「更多」进；对话框标题同改名', emptyMini({ focusScript: true, hoverScript: true })),
      F(2, '粘贴 → 预览', '确认按钮带计数（scriptImportConfirm 加占位符）', dlg(`${dlgHead}<div style="flex: 1; border-radius: 2px; background: ${T.s2}; border: 1px solid ${T.outline}; padding: 2px 4px; font-size: 7px; line-height: 1.4; color: ${T.fg4}">拂晓，雾江…<br>渔夫收网…<br>孤舟归航…</div><div style="display: flex; align-items: center; gap: 3px"><span style="font-size: 7.5px; color: ${T.fg5}; flex: 1">预览 · 4 镜</span>${btn('取消')}${btn('创建 4 个镜头', { amber: true })}</div>`)),
      F(3, '链从视口中心铺开', '空态让位给舞台；通知卡「已添加 4 镜到画布」（现状）', `${svgL(`${narr(40, 14 + CY, 44, 14 + CY)}${narr(78, 14 + CY, 82, 14 + CY)}${narr(116, 14 + CY, 120, 14 + CY)}`)}${[0, 1, 2, 3].map((i) => card({ x: 6 + i * 38, y: 14, w: 34, t: `0${i + 1}`, ty: '镜头', body: '…', sel: i === 0 })).join('')}`),
      E('0 镜 · 导入中', '没有内容时确认置灰；导入中取消也置灰（现状）', dlg(`${dlgHead}<div style="flex: 1; border-radius: 2px; background: ${T.s2}; border: 1px solid ${T.outline}; font-size: 7px; color: ${T.fg6}; display: flex; align-items: center; justify-content: center">还没有可导入的内容。</div><div style="display: flex; justify-content: flex-end; gap: 3px">${btn('取消')}${btn('创建 0 个镜头', { amber: true, dis: true })}</div>`)),
      E('导入失败', '一个事务零残留（现状），文案跟着改「剧本」', center(errCard('剧本导入失败，画布未做改动。'))),
    ], SH_F),
  ]);

// ============ 6 便签字号 · 标题 ============
const noteBody = (t, o = {}) => `<div style="width: 92px; box-sizing: border-box; padding: 4px 6px; border-radius: 2px; background: ${T.wash}; border: 1px solid ${T.washBorder}; ${o.sel ? `outline: 1.5px solid ${T.accent}; outline-offset: 1px;` : ''} box-shadow: 0 4px 10px rgba(0,0,0,0.35); font-size: 8.5px; line-height: 1.55; color: ${o.ph ? T.fg6 : T.fg1}">${t}</div>`;
const noteHead = (t, o = {}) => `<div style="font-size: 14px; font-weight: 500; line-height: 1.3; color: ${T.fg1}; white-space: nowrap; ${o.sel ? `outline: 1.5px solid ${T.accent}; outline-offset: 2px; border-radius: 2px;` : ''}">${t}${o.caret ? `<span style="display: inline-block; width: 1px; height: 13px; background: ${T.fg1}; vertical-align: middle"></span>` : ''}</div>`;
const seg = (on) => `<div style="display: inline-flex; border-radius: 3px; border: 1px solid ${T.controlStrong}; overflow: hidden; font-size: 8.5px">
  <span style="padding: 1px 8px; ${on === 'body' ? `background: ${T.s5}; color: ${T.fg1}` : `color: ${T.fg4}`}">正文</span><span style="padding: 1px 8px; border-left: 1px solid ${T.controlStrong}; ${on === 'heading' ? `background: ${T.wash}; color: ${T.accent}` : `color: ${T.fg4}`}">标题</span></div>`;
const secNote = section('便签字号 · 标题', 'P3', 'note-heading-style（挂 IS-Q5）',
  `还没有便签：画布只有文本节点（${code('text_node_inspector.dart')}）；缩放 &lt; 0.6 时卡片收成类型图标（${code('canvas_compact_cards.dart')} kCompactCardScale）。两档字号整节为新增，按 IS-Q5 建议 A（variant = note）画`,
  [
    row([
      S('正文', '12 / 1.55，wash 底；三种底色只给正文', center(noteBody('第二场改成黄昏？问导演'))),
      S('标题', '20 / 500，无底色无边框，宽度跟字走', center(noteHead('第一场 · 拂晓出港'))),
      S('选中', 'accent 描边；拖动、删除与卡片同一套', center(noteHead('第一场 · 拂晓出港', { sel: true }))),
      S('编辑中', '双击进编辑；Esc 或点外面落盘', center(noteHead('第一场 · 拂晓', { caret: true }))),
      S('空便签', '占位「写点什么…」fg6；空着失焦照样保留', center(noteBody('写点什么…', { ph: true }))),
      S('缩远 &lt; 0.6', '正文收成图标；标题不收，屏幕字号不小于 12', `${pos(10, 10, `<div style="font-size: 12px; font-weight: 500; color: ${T.fg1}; white-space: nowrap">第一场 · 拂晓出港</div>`)}${pos(10, 34, `<div style="width: 20px; height: 16px; border-radius: 2px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; display: flex; align-items: center; justify-content: center">${ic('note', 10)}</div>`)}${pos(40, 37, `<span style="font-size: 7.5px; color: ${T.fg5}">40%</span>`)}`),
    ], SH_S),
    row([
      F(1, '选中便签', '检查器正文框上方出「正文 | 标题」', `${pos(8, 12, noteBody('第一场 · 拂晓出港', { sel: true }))}${pos(110, 14, `<span style="font-size: 7.5px; color: ${T.fg5}">检查器</span>`)}${pos(108, 30, `<div style="transform: scale(0.82); transform-origin: left top">${seg('body')}</div>`)}`),
      F(2, '点「标题」', '写 type_config.note_style = heading（JSONB，不迁移）', `${center(seg('heading'))}${ptr(118, 44)}`),
      F(3, '卡片变标题', '底色去掉、字号变大，宽度跟字，连线锚点跟着矩形', pos(10, 24, noteHead('第一场 · 拂晓出港', { sel: true }))),
      F(4, 'Ctrl Z 回正文', '一步撤销；undo-stack 未合前不登记', center(cap('已撤销 · 便签改为标题', { icon: 'undo', right: capKey('重做 Ctrl Y') }))),
      E('超过 480', '最宽 480 后换行，矩形按节点算（nodeStageRect 要改）', `${pos(8, 8, `<div style="width: 140px; font-size: 12px; font-weight: 500; line-height: 1.3; color: ${T.fg1}">第三场 · 黄昏归航，渔火渐次亮起</div>`)}<div style="position: absolute; left: 148px; top: 6px; bottom: 6px; border-left: 1px dashed ${T.fg6}"></div>`),
      E('不进大纲 · 提示词', '标题便签不进大纲、不并进提示词；查找能搜到', center(`<div style="display: flex; gap: 6px; font-size: 8px; color: ${T.fg5}"><span style="display: flex; align-items: center; gap: 2px">${ic('outline', 9)}大纲 不进</span><span style="display: flex; align-items: center; gap: 2px">${ic('text', 9)}提示词 不进</span><span style="display: flex; align-items: center; gap: 2px; color: ${T.accent}">${ic('search', 9)}查找 能搜</span></div>`)),
      E('IS-Q5 未定', '若选 B（新类型）要加前向迁移，本节外观不变', center(`<div style="font-size: 8px; line-height: 1.5; color: ${T.fg4}; text-align: center">A 文本节点 variant = note<br><span style="color: ${T.fg6}">B 新节点类型 + 迁移</span></div>`)),
    ], SH_F),
  ]);

// ============ 7 画布轻提示胶囊 · 缩放 / 适应 ============
const zbar = ({ hover = '', focus = '', pct = '100%' } = {}) => {
  const cell = (id, inner, w) => `<span style="width: ${w}px; height: 15px; display: inline-flex; align-items: center; justify-content: center; ${hover === id ? `background: ${T.s5};` : ''} ${focus === id ? `outline: 1.5px solid ${T.accent}; outline-offset: -1px;` : ''}">${inner}</span>`;
  const bar = `<span style="width: 1px; height: 15px; background: ${T.control}"></span>`;
  return `<div style="display: inline-flex; align-items: center; border-radius: 3px; background: ${T.s4}; border: 1px solid ${T.control}; overflow: hidden; color: ${T.fg3}">${cell('out', ic('zoomOut', 9), 17)}${bar}<span style="padding: 0 6px; font-family: ${MONO}; font-size: 8px">${pct}</span>${bar}${cell('in', ic('zoomIn', 9), 17)}${bar}${cell('fit', `<span style="font-size: 8px">适应</span>`, 26)}</div>`;
};
const stageBottom = (capHtml, { bar = true, zoom = true } = {}) => `
  ${zoom ? pos(4, SH_F - 22, zbar()) : ''}
  ${bar ? `<div style="position: absolute; left: 50%; bottom: 4px; transform: translateX(-50%); width: 72px; height: 14px; border-radius: 4px; background: ${T.s3}; border: 1px solid ${T.control}; font-size: 7px; color: ${T.fg5}; display: flex; align-items: center; justify-content: center">提示词条</div>` : ''}
  <div style="position: absolute; left: 50%; bottom: ${bar ? 22 : 10}px; transform: translateX(-50%)">${capHtml}</div>`;
const secCapsule = section('画布轻提示胶囊 · 缩放 / 适应', 'P2', 'canvas-capsule',
  `没有胶囊组件，画布提示全走右下通知卡（${code('canvas_snackbars.dart')} showCanvasSnack）；缩放条 ${code('canvas_zoom_bar.dart')}：缩小 / % / 放大 / 适应，每档 ×1.2，夹在 10%–300%；适应 = fitAllNodes，只缩小不放大；⌘0 复位`,
  [
    row([
      S('纯文字', '停 2 秒；不进铃铛、不出声', center(cap('已复制 2 个节点'))),
      S('带动作', '停 4 秒；动作是胶囊里唯一可点的地方', center(cap('已撤销 · 移动 3 个节点', { icon: 'undo', right: capKey('重做 Ctrl Y') }))),
      S('缩放（同 key）', '连按原地改字、重新计时；最后一次后 1.2 秒', center(`${cap('缩放 120%')}<div style="font-size: 7.5px; color: ${T.fg5}">dedupeKey = zoom</div>`)),
      S('悬停停表', '指针在胶囊上不计时，移开接着走', `${center(cap('已接到第 7 镜之后', { icon: 'sequence' }))}${ptr(100, 30)}`),
      S('被顶替', '最多 1 条：新的立刻顶掉旧的，交叉淡入 120ms', center(`<div style="position: relative; height: 26px; width: 140px">${pos(4, 0, cap('缩放 80%', { dim: true }))}${pos(24, 8, cap('已新开分叉 · 在 02 之后', { icon: 'sequence' }))}</div>`)),
      S('缩放条悬停 · 聚焦', '图标格悬停 surface5；Tab 焦点环；tooltip 说名字（现状）', center(`${zbar({ hover: 'in' })}${zbar({ focus: 'fit' })}`)),
      S('到边界', '10% / 300% 时按钮不置灰，再按无变化，胶囊照写比例', center(`${zbar({ pct: '10%', hover: 'out' })}${cap('缩放 10%')}`)),
    ], SH_S),
    row([
      F(1, '按 Shift 1', '或缩放条「适应」、空白右键「适应视图」；Shift 2 = 适应选中', `${pos(8, 8, `<div style="display: flex; gap: 4px">${kchip('Shift 1', { hot: true })}${kchip('Shift 2')}</div>`)}${stageBottom('', { bar: false })}`),
      F(2, '框住全部卡', '只缩小不放大；底部让出缩放条或提示词条（取大的）', `${[0, 1, 2].map((i) => card({ x: 18 + i * 42, y: 2, w: 36, t: `0${i + 1}`, ty: '', body: '…' })).join('')}<div style="position: absolute; left: 12px; right: 12px; top: 0; height: 39px; border: 1px dashed ${T.accent}; border-radius: 2px"></div>${stageBottom('', { zoom: false })}`),
      F(3, '胶囊出比例', '提示词条在时贴条子上方 8；不在时离舞台底 16', `${[0, 1, 2].map((i) => card({ x: 18 + i * 42, y: 2, w: 36, t: `0${i + 1}`, ty: '', body: '…' })).join('')}${stageBottom(cap('缩放 64%'), { zoom: false })}`),
      F(4, '1.2 秒后淡出', '淡出 120ms；换标签、关画布当场收', `${[0, 1, 2].map((i) => card({ x: 18 + i * 42, y: 2, w: 36, t: `0${i + 1}`, ty: '', body: '…' })).join('')}${stageBottom(cap('缩放 64%', { dim: true }), { zoom: false })}`),
      E('空画布 · 未载入', '没有卡片：回到初始相机；节点还没载入：不动（现状）', center(`<div style="font-size: 8px; color: ${T.fg4}; text-align: center; line-height: 1.5">适应 → 初始相机 100%<br><span style="color: ${T.fg6}">载入中 → 不动、不出胶囊</span></div>`)),
      E('窄舞台', '两侧各让出缩放条宽 + 16，超出省略号；查找条在顶部不避让', `${pos(4, SH_F - 22, zbar())}<div style="position: absolute; left: 104px; top: 6px; bottom: 0; border-left: 1px dashed ${T.fg6}"></div><div style="position: absolute; left: 108px; right: 4px; bottom: 6px; overflow: hidden"><div style="display: flex; align-items: center; height: 18px; padding: 0 6px; border-radius: 999px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; font-size: 8.5px; color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; box-sizing: border-box"><span style="overflow: hidden; text-overflow: ellipsis">已撤销 · 移动 3 个节点</span></div></div>${pos(108, 30, `<span style="font-size: 7.5px; color: ${T.fg5}">让出缩放条 + 16</span>`)}`),
      E('不出胶囊的场合', '滚轮 / 捏合缩放不出；错误走通知卡；删除走 8 秒撤销卡', center(`<div style="display: flex; flex-direction: column; gap: 4px; align-items: center">${cap('缩放 90%', { dim: true })}<span style="font-size: 7.5px; color: ${T.fg5}">滚轮 · 捏合：缩放条已在显示</span></div>`)),
    ], SH_F),
  ]);

// ============ 页 ============
const legend = `
  <div style="display: flex; align-items: center; gap: 14px; font-size: 10px; color: ${T.fg5}; margin-top: 8px">
    <span style="display: inline-flex; align-items: center; gap: 5px"><span style="width: 14px; height: 10px; border-radius: 2px; border: 1px solid ${T.bSubtle}; background: ${T.s3}"></span>上一行：状态条</span>
    <span style="display: inline-flex; align-items: center; gap: 5px">${badgeNum(1)}逐步流程</span>
    <span style="display: inline-flex; align-items: center; gap: 5px">${badgeEdge}原画板只写了一行的边界情况</span>
    <span>画布小样按比例缩小；键位写 Windows，mac 把 Ctrl 换成 ⌘、Alt 换成 ⌥</span>
  </div>`;
const decisionNote = `
  <div style="margin-top: 10px; padding: 7px 10px; border-radius: 4px; background: ${T.wash}; border: 1px solid ${T.washBorder}; font-size: 11px; line-height: 1.5; color: ${T.fg2}">
    <span style="color: ${T.accent}; font-weight: 500">按建议走的决定</span>　KM-Q1 与 GC-N3 冲突 → 选 GC-N3 的 A：锚点已有下一镜时 Ctrl → 开分叉，新边排在已有分叉之后（${code('nextNarrativeSortOrder')}，与新建菜单「下一镜」一致）；要插到中间就拖到线上插入。
    其余按原画板建议：N1 A · N2 A · N4 A · N5 A · N6 A · N7 A；IS-Q5 未定，便签按 A 画。
  </div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="padding: 20px ${PAD}px 0">
    <div style="display: flex; align-items: baseline; gap: 14px">
      <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">画布补漏 · 状态与流程</div>
      <div style="color: ${T.fg4}">第三批细化：原画板每个功能的状态、逐步流程和边界情况；每节第二行核对现状</div>
    </div>
    ${decisionNote}
    ${legend}
    ${secNext}
    ${secCreate}
    ${secNodeMenu}
    ${secMore}
    ${secNaming}
    ${secNote}
    ${secCapsule}
  </div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'GapsCanvasDetail.dc.html', html: page('画布补漏 · 状态与流程', W, H, body, logic) };
