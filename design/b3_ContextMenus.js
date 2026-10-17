// 第三批细化画板：右键菜单补全与连线操作 · 状态与流程（对 b2_wires.js 的七个功能逐个画状态 / 流程 / 边界）。
// 1280 宽，静态。b2 的「需要你定」全部按建议：
// 决定：W1 → A（删链中间的镜默认接上；菜单另给「删除（不接上）」）
// 决定：W2 → A（停用只在批量运行时跳过；单独生成、序列、导出照常）
// 决定：W3 → A（切线 = Alt + 左键拖空白，mac 上是 ⌥）
// 决定：W4 → B（只有未入链的卡能拖到线上插入；已在链上的不触发）
// 决定：W5 → A（多选时 Ctrl ↵ = 生成全部能生成的，确认规则归 TakesCost 运行对话框）
// 决定：KM-Q1 → GC-N3 的 A（锚点已有下一镜时开分叉，排在已有分叉之后，与 nextNarrativeSortOrder 一致；要插中间就拖到线上插入）
const { T, IMG, SANS, MONO, page, ic, caret } = require('./common.js');

const W = 1280, H = 2400;

// ---- 与 b2_wires.js 同一套小件（本地复制）----
const kbd = (k) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}; white-space: nowrap">${k}</span>`;
const key = (k) => `<span style="height: 16px; padding: 0 5px; border-radius: 3px; border: 1px solid ${T.outline}; background: ${T.s3}; font-family: ${MONO}; font-size: 10px; color: ${T.fg3}; display: inline-flex; align-items: center; white-space: nowrap">${k}</span>`;
const menuSep = `<div style="height: 1px; background: ${T.bStrong}; margin: 4px 0"></div>`;
const menu = (inner, width = 200, extra = '') => `<div style="width: ${width}px; box-sizing: border-box; padding: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6); ${extra}">${inner}</div>`;
const newTag = `<span style="height: 14px; padding: 0 4px; border-radius: 3px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 9px; line-height: 14px; flex: none">新</span>`;
const need = `<span style="color: ${T.accent}">需：</span>`;
const code = (t) => `<span style="font-family: ${MONO}; font-size: 9.5px; color: ${T.fg3}">${t}</span>`;
const lineSwatch = (color, dash = '', width = 1.75) => `<svg width="16" height="10" viewBox="0 0 16 10" aria-hidden="true" style="display: block; flex: none"><path d="M1 5H15" fill="none" stroke="${color}" stroke-width="${width}" ${dash ? `stroke-dasharray="${dash}"` : ''} stroke-linecap="round"></path></svg>`;

// 菜单一行：与 create_node_menu.dart 的 _MenuRow 同构——前导 | 文字 | 原因 | 键位 | 打勾 | ›；
// 高亮（悬停 = ↑↓ 键盘高亮，同一个态）= s5 底；置灰整行 0.5、不隐藏；打勾的行照常亮着（点不动）。
const mi = (label, o = {}) => {
  const lead = o.lead !== undefined ? o.lead
    : o.icon ? `<div style="color: ${T.fg4}; display: flex">${ic(o.icon, 16)}</div>` : '<div style="width: 16px; flex: none"></div>';
  const op = o.disabled && !o.checked ? 'opacity: 0.5;' : '';
  return `
  <div style="height: 28px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border-radius: 3px; ${o.hl ? `background: ${T.s5};` : ''} ${op}">
    ${lead}
    <div style="flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: ${o.danger ? T.danger : T.fg2}">${label}</div>
    ${o.isNew ? newTag : ''}
    ${o.note ? `<span style="font-size: 10px; color: ${T.fg6}; white-space: nowrap">${o.note}</span>` : ''}
    ${o.key ? kbd(o.key) : ''}
    ${o.checked ? `<div style="color: ${T.accent}; display: flex">${ic('success', 14)}</div>` : ''}
    ${o.sub ? `<span style="color: ${T.fg5}">›</span>` : ''}
  </div>`;
};
const at = (x, y, inner, extra = '') => `<div style="position: absolute; left: ${x}px; top: ${y}px; ${extra}">${inner}</div>`;

// ---- 画板骨架：功能区块 = 标题行 → 状态行 → 流程 + 边界行 ----
const SH = 72;                // 样稿高
const RW = 1216 - 36;         // 一行里给样稿的宽（左侧 28 行标 + 8 间距）
const fw = (n, seps) => Math.floor((RW - (n - 1) * 8 - seps * 17) / n);
const stage = (w, h, inner, extra = '') => `<div style="position: relative; width: ${w}px; height: ${h}px; box-sizing: border-box; border-radius: 6px; background: ${T.s1}; border: 1px solid ${T.outline}; background-image: radial-gradient(${T.grid} 1px, transparent 1px); background-size: 16px 16px; overflow: hidden; ${extra}">${inner}</div>`;
const numBadge = (n) => `<span style="width: 16px; height: 16px; flex: none; box-sizing: border-box; border-radius: 8px; border: 1px solid ${T.accent}; color: ${T.accent}; font-family: ${MONO}; font-size: 10px; display: inline-flex; align-items: center; justify-content: center">${n}</span>`;
const stateTag = (tone) => {
  const c = tone === 'err' ? T.danger : tone === 'ok' ? T.success : tone === 'off' ? T.fg6 : T.fg4;
  return `<span style="width: 6px; height: 6px; flex: none; border-radius: 3px; background: ${c}"></span>`;
};
const edgeTag = `<span style="height: 14px; padding: 0 4px; flex: none; border-radius: 3px; border: 1px dashed ${T.control}; color: ${T.fg5}; font-size: 9px; line-height: 12px">边界</span>`;

// 一帧：标头（编号圆 / 状态点 / 边界标）+ 样稿 + 至多三行说明
const fr = (s, w) => {
  const head = s.num ? numBadge(s.num) : s.edge ? edgeTag : stateTag(s.tone);
  const inner = typeof s.inner === 'function' ? s.inner(w - 2) : s.inner;
  return `
  <div style="width: ${w}px; flex: none; display: flex; flex-direction: column; gap: 4px">
    <div style="height: 16px; display: flex; align-items: center; gap: 6px; font-size: 11px; color: ${s.tone === 'err' ? T.danger : T.fg2}; white-space: nowrap; overflow: hidden">${head}<span style="overflow: hidden; text-overflow: ellipsis">${s.label}</span>${s.isNew ? newTag : ''}</div>
    ${stage(w, SH, inner, s.bg || '')}
    <div style="height: 42px; font-size: 10px; line-height: 1.4; color: ${T.fg4}; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden">${s.cap}</div>
  </div>`;
};
const rowLabel = (t) => `<div style="width: 28px; flex: none; padding-top: 1px; font-size: 10px; color: ${T.fg6}">${t}</div>`;
const vsep = `<div style="width: 1px; flex: none; align-self: stretch; margin: 0 8px; background: ${T.outline}"></div>`;
// specs 里放 'SEP' = 流程与边界之间的竖线
const row = (label, specs) => {
  const frames = specs.filter((s) => s !== 'SEP');
  const w = fw(frames.length, specs.length - frames.length);
  return `<div style="display: flex; gap: 8px; align-items: flex-start">${rowLabel(label)}${specs.map((s) => s === 'SEP' ? vsep : fr(s, w)).join('')}</div>`;
};
const block = (title, prio, now, states, flow) => `
  <div style="padding: 8px 0; border-top: 1px solid ${T.outline}; display: flex; flex-direction: column; gap: 6px">
    <div style="height: 18px; display: flex; align-items: baseline; gap: 8px; white-space: nowrap; overflow: hidden">
      <div style="font-weight: 500; color: ${T.fg1}">${title}</div>
      <div style="font-family: ${MONO}; font-size: 10px; color: ${T.accent}">${prio}</div>
      <div style="font-size: 11px; color: ${T.fg5}; overflow: hidden; text-overflow: ellipsis">现状：${now}</div>
    </div>
    ${row('状态', states)}
    ${row('流程', flow)}
  </div>`;

// ---- 样稿里的小件 ----
const sv = (w, h, inner) => `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" aria-hidden="true" style="position: absolute; left: 0; top: 0">${inner}</svg>`;
// 一段带箭头的水平线（终点开口箭头，与 edge_style 同构）
const hline = (x1, x2, y, color = T.fg4, sw = 2, dash = '', arrow = true) => `
  <path d="M${x1} ${y}H${x2}" fill="none" stroke="${color}" stroke-width="${sw}" ${dash ? `stroke-dasharray="${dash}"` : ''} stroke-linecap="round"></path>
  ${arrow ? `<path d="M${x2 - 6} ${y - 3}L${x2} ${y}l-6 3" fill="none" stroke="${color}" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"></path>` : ''}`;
const box = (x, y, w, h, label, extra = '') => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: ${h}px; box-sizing: border-box; border-radius: 4px; background: ${T.s3}; border: 1px solid ${T.outline}; font-size: 10px; color: ${T.fg2}; display: flex; align-items: center; justify-content: center; white-space: nowrap; overflow: hidden; ${extra}">${label}</div>`;
const selBox = `border-color: ${T.accent}; color: ${T.fg1}`;
const ghostBox = `border: 1px dashed ${T.control}; background: transparent; color: ${T.fg6}`;
const tile = (x, y, w, h, src, sel = true, extra = '') => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: ${h}px; border-radius: 3px; overflow: hidden; outline: 1px solid ${sel ? T.accent : T.outline}; ${extra}"><img src="${src}" alt="" style="width: 100%; height: 100%; object-fit: cover; display: block"></div>`;
const pill = (x, y, text, extra = '') => `<div style="position: absolute; left: ${x}px; top: ${y}px; height: 18px; padding: 0 7px; border-radius: 9px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 10px; display: flex; align-items: center; white-space: nowrap; ${extra}">${text}</div>`;
const chip = (x, y, text, extra = '') => `<div style="position: absolute; left: ${x}px; top: ${y}px; height: 18px; padding: 0 7px; border-radius: 9px; background: ${T.s3}; border: 1px solid ${T.control}; color: ${T.fg2}; font-size: 10px; display: flex; align-items: center; gap: 4px; white-space: nowrap; ${extra}">${text}</div>`;
const note = (x, y, text, color = T.fg6) => `<div style="position: absolute; left: ${x}px; top: ${y}px; font-size: 10px; color: ${color}; white-space: nowrap">${text}</div>`;
// 指针（箭头光标）与按下点的圈
const ptr = (x, y) => `<svg width="11" height="15" viewBox="0 0 11 15" aria-hidden="true" style="position: absolute; left: ${x}px; top: ${y}px"><path d="M1 1V12l3-2.6 2.2 4.6 1.8-.8-2.2-4.5H10z" fill="${T.fg1}" stroke="${T.s0}" stroke-width="1" stroke-linejoin="round"></path></svg>`;
const ring = (x, y, color = T.accent) => `<div style="position: absolute; left: ${x - 7}px; top: ${y - 7}px; width: 14px; height: 14px; box-sizing: border-box; border-radius: 7px; border: 1.5px solid ${color}; opacity: 0.8"></div>`;
// 迷你通知卡（撤销 / 错误 / 进度），与 TOAST_CARD 同口径缩小
const toast = (x, y, w, o) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: ${o.h || 40}px; box-sizing: border-box; display: flex; align-items: center; gap: 6px; padding: 0 6px 0 8px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 8px 20px rgba(0,0,0,0.5)">
    <div style="color: ${o.color || T.fg3}; display: flex; flex: none" ${o.spin ? 'class="spin"' : ''}>${ic(o.icon || 'undo', 14)}</div>
    <div style="flex: 1; min-width: 0">
      <div style="font-size: 10px; color: ${T.fg1}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${o.title}</div>
      ${o.sub ? `<div style="font-size: 9px; color: ${T.fg5}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${o.sub}</div>` : ''}
      ${o.progress ? `<div style="height: 3px; margin-top: 3px; border-radius: 2px; background: ${T.control}; overflow: hidden"><div style="height: 3px; width: ${o.progress}%; background: ${T.accent}"></div></div>` : ''}
    </div>
    ${o.btn ? `<button class="amber" type="button" style="height: 20px; flex: none; padding: 0 6px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 10px; font-weight: 500">${o.btn}</button>` : ''}
  </div>`;
const undoToast = (w, title, sub, y = 28) => toast(5, y, w - 10, { title, sub, btn: '撤销' });
const errToast = (w, title, sub, y = 16) => toast(5, y, w - 10, { icon: 'error', color: T.danger, title, sub });

// ================= 1 · 连线：右键 + 中点工具条 =================
// 两张卡 A → B，一条线；toolbar 是中点工具条（替换现有红色叉号圆钮）
const edgePair = (w, o = {}) => {
  const y = o.y || 34, bw = 40;
  const x2 = w - 6 - bw;
  const color = o.color || T.fg4;
  return `
    ${box(6, y - 13, bw, 26, o.a || '成片', o.selA || '')}
    ${box(x2, y - 13, bw, 26, o.b || '镜头 02', o.selB || '')}
    ${sv(w, SH, hline(6 + bw, x2, y, color, o.sw || 2, o.dash || '') + (o.extraSvg || ''))}
    ${o.label ? `<div style="position: absolute; left: ${(6 + bw + x2) / 2 - 15}px; top: ${y - 8}px; height: 16px; padding: 0 5px; border-radius: 8px; background: ${T.s1}; border: 1px solid ${color}; color: ${color}; font-size: 9px; display: flex; align-items: center">${o.label}</div>` : ''}`;
};
const toolbar = (cx, cy, hoverFirst = false) => `
  <div style="position: absolute; left: ${cx - 41}px; top: ${cy - 12}px; height: 24px; display: flex; align-items: center; padding: 0 2px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 12px; box-shadow: 0 8px 20px rgba(0,0,0,0.5)">
    <button class="hov" type="button" aria-label="改语义" style="height: 20px; padding: 0 4px 0 6px; border-radius: 10px; display: flex; align-items: center; gap: 3px; font-size: 10px; color: ${T.teal}; ${hoverFirst ? `background: ${T.s5}` : ''}">${lineSwatch(T.teal)}首帧${caret()}</button>
    <div style="width: 1px; height: 12px; background: ${T.control}"></div>
    <button class="hov" type="button" aria-label="删除连线" style="width: 20px; height: 20px; border-radius: 10px; display: flex; align-items: center; justify-content: center; color: ${T.fg4}">${ic('trash', 12)}</button>
  </div>`;

const edgeStates = [
  { label: '选中', tone: 'ok', isNew: true, inner: (w) => edgePair(w, { color: T.accent, y: 26 }) + toolbar(w / 2, 52),
    cap: `点线 / 右键线都先选中：线换 accent（现有 onChain），中点出工具条，替换红色叉号圆钮` },
  { label: '悬停', inner: (w) => edgePair(w, { color: T.accent, y: 26 }) + toolbar(w / 2, 52, true) + ptr(w / 2 - 14, 54),
    cap: '工具条按钮悬停 s5 底，与菜单行高亮同一个色；tooltip 写「改语义」「删除连线」' },
  { label: '高亮 · 危险', inner: (w) => at(3, 3, menu(mi('改语义', { sub: true, hl: true }) + mi('删除', { danger: true, key: 'Del' }), w - 8)),
    cap: '悬停与 ↑↓ 键盘高亮同一个态：行底 s5（_MenuRow）；删除用 danger 字色、排最后一组' },
  { label: '置灰', inner: (w) => at(3, 3, menu(mi('插入节点…', { disabled: true, note: '仅叙事线' }) + mi('尾帧', { lead: lineSwatch(T.peach), disabled: true, note: '模型不支持' }), w - 8)),
    cap: `整行 0.5、不隐藏，↑↓ 跳过；${need}行尾原因列——_MenuRow 现在只有键位位` },
  { label: '子菜单展开', inner: (w) => at(3, 8, menu(mi('改语义', { sub: true, hl: true }), 74)) + at(w - 98, 3, menu(mi('首帧', { lead: lineSwatch(T.teal), checked: true }) + mi('参考', { lead: lineSwatch(T.sky, '3 2.5', 1.5) }), 96)),
    cap: '贴在父行旁（右边放不下翻左）；打勾 = 当前语义，亮着但点不动；→ 开 ← 收' },
  { label: '出错', tone: 'err', inner: (w) => errToast(w, '连线删除失败', '线已回到原处'),
    cap: `删 / 改写库失败：内存回滚、线冒回来，出错误卡（现有 ${code('edgeDeleteFailed')}）` },
  { label: '禁用 · 产出线', tone: 'off', inner: (w) => edgePair(w, { a: '镜头 01', b: '成片', color: T.fg6, sw: 1.25, dash: '1.5 3.5' }) + ptr(w / 2 - 2, 36),
    cap: '产出线点不中（lineage_edges 不进 hitTest），右键落到空白处菜单' },
];
const edgeFlow = [
  { num: 1, label: '右键按下', inner: (w) => edgePair(w, { y: 30 }) + ring(w / 2, 30) + ptr(w / 2, 32),
    cap: '在线上按下次键；按住挪出点击容差 = 拖画布，不开菜单（现有判据）' },
  { num: 2, label: '抬起 → 菜单', inner: (w) => edgePair(w, { y: 14, color: T.accent }) + at(w / 2 - 50, 22, menu(mi('改语义', { sub: true, hl: true }) + mi('插入节点…'), 104)),
    cap: '抬起时先选中这条线，再在按下点开菜单（与节点菜单同一套）' },
  { num: 3, label: '选「首帧」', inner: (w) => at(3, 3, menu(mi('首帧', { lead: lineSwatch(T.teal), hl: true }) + mi('参考', { lead: lineSwatch(T.sky, '3 2.5', 1.5), checked: true }), w - 8)),
    cap: `目标已有首帧线：同一事务把它降为参考（${code('updateRole')} 现成）` },
  { num: 4, label: '结果', inner: (w) => edgePair(w, { y: 18, color: T.teal, sw: 1.75, label: '首帧' }) + toast(5, 38, w - 10, { h: 30, title: '已改为首帧', btn: '撤销' }),
    cap: '线换首帧线型 + 标签；撤销栈记一步「改为首帧」' },
  'SEP',
  { edge: true, label: 'Del 删线', inner: (w) => edgePair(w, { color: T.accent, y: 26 }) + at(w / 2 - 12, 46, key('Del')),
    cap: `${need}选中线时 Del 删线优先（现在只删节点）；撤销卡「连线已删除」` },
  { edge: true, label: 'mac · Ctrl + 点', inner: (w) => edgePair(w, { y: 18 }) + at(w / 2 - 34, 44, `<div style="display: flex; align-items: center; gap: 4px">${key('⌃')}<span style="font-size: 10px; color: ${T.fg5}">+ 点 = 右键</span></div>`) + ptr(w / 2 + 4, 20),
    cap: `${need}mac 上 ⌃ + 主键当次键；现在 ⌃ 走 ${code('isControlPressed')} 切多选（canvas_view.dart）` },
  { edge: true, label: '触控板双指点', inner: (w) => edgePair(w, { y: 18 }) + ring(w / 2 - 5, 22, T.fg3) + ring(w / 2 + 7, 22, T.fg3) + note(w / 2 - 38, 44, '双指轻点 = 次键', T.fg5),
    cap: '双指轻点上报次键，照常抬起开菜单；双指拖是平移，不开菜单' },
];

// ================= 2 · 泳道标题栏右键 =================
const laneBand = (top = 4, h = 64) => `<div style="position: absolute; left: 0; right: 0; top: ${top}px; height: ${h}px; border-top: 1px solid ${T.laneDivider}; border-bottom: 1px solid ${T.laneDivider}"></div>`;
const titleBar = (x, y, w, o = {}) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; height: 26px; box-sizing: border-box; display: flex; align-items: center; gap: 6px; padding: 0 8px; border-radius: 3px; background: rgba(38,38,38,0.82); ${o.sel ? `outline: 1px solid ${T.accent}` : ''}">
    <div style="width: 8px; height: 8px; border-radius: 2px; background: ${T.peach}; flex: none"></div>
    ${o.edit
      ? `<div style="flex: 1; min-width: 0; height: 18px; box-sizing: border-box; padding: 0 4px; border-radius: 3px; background: ${T.s1}; border: 1px solid ${T.accent}; font-size: 11px; color: ${T.fg1}; display: flex; align-items: center">水墨风格<span style="width: 1px; height: 11px; background: ${T.accent}; margin-left: 1px"></span></div>`
      : `<div style="font-weight: 500; color: ${o.collapsed ? T.fg4 : T.fg1}; font-size: 11px; white-space: nowrap">水墨风格</div>
         <div style="flex: 1; min-width: 0; font-size: 9px; color: ${T.fg5}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${o.collapsed ? '已折叠' : '柔和笔触，雾气留白'}</div>`}
    <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">${o.count !== undefined ? o.count : 3}</div>
  </div>`;
const laneStates = [
  { label: '默认', inner: (w) => laneBand() + titleBar(6, 10, w - 12) + tile(12, 44, 36, 20, IMG.thumbMountain, false) + tile(56, 44, 36, 20, IMG.thumbWide, false),
    cap: '标题栏：色点 | 名称 | 风格摘要 | 节点数；现有折叠 / 编辑 / 删除三键照留' },
  { label: '右键 · 高亮', isNew: true, inner: (w) => laneBand() + titleBar(6, 4, w - 12, { sel: true }) + at(22, 34, menu(mi('改名', { hl: true }), w - 40)),
    cap: '只认标题栏右键：标题栏 accent 描边，菜单锚在按下点，首项高亮' },
  { label: '改名中', isNew: true, inner: (w) => laneBand() + titleBar(6, 10, w - 12, { edit: true }) + note(10, 44, '↵ 存 · Esc 退', T.fg5),
    cap: `原地变输入框（${code('updateLane')}）；清空后存 = 回落「未命名泳道」` },
  { label: '置灰', tone: 'off', inner: (w) => laneBand() + titleBar(6, 4, w - 12, { count: 0, sel: true }) + at(22, 34, menu(mi('选中内容', { icon: 'select', disabled: true, note: '0 个' }), w - 40)),
    cap: '空道：「选中内容」置灰，原因写「0 个」' },
  { label: '折叠态', inner: (w) => titleBar(6, 4, w - 12, { collapsed: true, sel: true }) + at(22, 34, menu(mi('展开', { key: '双击标题' }), w - 40)),
    cap: '折叠的道：「折叠」换成「展开」，键位提示照旧' },
  { label: '危险', inner: (w) => at(3, 3, menu(mi('解散（节点留下）') + mi('删除泳道和内容', { danger: true, hl: true }), w - 8)),
    cap: '只有「删除泳道和内容」是危险色；「解散」普通色' },
  { label: '出错', tone: 'err', inner: (w) => errToast(w, '删除泳道失败', '道、节点、边都没动'),
    cap: `一个事务；失败整体回滚，出错误卡（现有 ${code('laneDeleteFailed')}）` },
];
const laneFlow = [
  { num: 1, label: '右键标题栏', inner: (w) => laneBand() + titleBar(6, 10, w - 12, { sel: true }) + ring(64, 23) + ptr(64, 25) + tile(12, 44, 36, 20, IMG.thumbMountain, false),
    cap: '按下 → 抬起没挪出容差才开；按住拖仍是拖画布' },
  { num: 2, label: '选「解散」', inner: (w) => at(3, 3, menu(mi('解散（节点留下）', { hl: true }) + mi('删除泳道和内容', { danger: true }), w - 8)),
    cap: '解散 = 现有「删除泳道」去掉确认框，补清节点 lane_id' },
  { num: 3, label: '结果', inner: () => tile(12, 22, 44, 26, IMG.thumbMountain, false) + tile(64, 22, 44, 26, IMG.thumbWide, false) + note(12, 54, '道没了，卡片原地不动'),
    cap: '屏幕位置不变、lane_id 清空（现在软删后节点还指着已删的道）' },
  { num: 4, label: '撤销卡', inner: (w) => undoToast(w, '已解散泳道 水墨风格', '节点留在原处', 16),
    cap: '不弹确认、走撤销卡；撤销 = 道回来、节点重新归道' },
  'SEP',
  { edge: true, label: '有生成中的任务', inner: (w) => `
      <div style="position: absolute; left: 5px; top: 5px; right: 5px; bottom: 5px; box-sizing: border-box; padding: 6px 8px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px">
        <div style="font-size: 10px; color: ${T.fg1}">道内 1 个任务在生成</div>
        <div style="display: flex; justify-content: flex-end; gap: 4px; margin-top: 10px">
          <button class="hov" type="button" style="height: 20px; padding: 0 6px; border-radius: 3px; border: 1px solid ${T.controlStrong}; color: ${T.fg2}; font-size: 10px">取消</button>
          <button type="button" style="height: 20px; padding: 0 6px; border-radius: 3px; background: ${T.danger}; color: ${T.fg1}; font-size: 10px">删除并取消任务</button>
        </div>
      </div>`,
    cap: '「删除泳道和内容」唯一要确认的情况：取消任务撤不回来' },
  { edge: true, label: '带内空白处右键', inner: (w) => laneBand() + titleBar(6, 8, 70) + ring(108, 22) + at(70, 32, menu(mi('新建…', { icon: 'nodeLibrary', key: 'Tab', hl: true }), w - 76)),
    cap: '带内空白处右键仍出空白处菜单，不是泳道菜单' },
  { edge: true, label: '撤销栈两步', inner: () => `
      <div style="position: absolute; left: 8px; top: 8px; right: 8px; display: flex; flex-direction: column; gap: 4px; font-size: 10px">
        <div style="height: 22px; padding: 0 6px; border-radius: 3px; background: ${T.s3}; display: flex; align-items: center; gap: 4px; color: ${T.fg2}">${ic('undo', 12)}删除泳道和内容</div>
        <div style="height: 22px; padding: 0 6px; border-radius: 3px; background: ${T.s3}; display: flex; align-items: center; gap: 4px; color: ${T.fg4}">${ic('undo', 12)}解散泳道</div>
      </div>`,
    cap: '解散 / 删除各进一步、分开命名，互不合并' },
];

// ================= 3 · 多选右键 =================
const trio = (y = 26, dy = [0, 0, 0], w) => {
  const x0 = Math.round(w / 2 - 70);
  return tile(x0, y + dy[0], 40, 24, IMG.thumbMountain) + tile(x0 + 50, y + dy[1], 40, 24, IMG.thumbWide) + tile(x0 + 100, y + dy[2], 40, 24, IMG.thumbMountain);
};
const spinner = (x, y) => `<div class="spin" style="position: absolute; left: ${x}px; top: ${y}px; display: flex; color: ${T.accent}">${ic('progress', 14)}</div>`;
const multiStates = [
  { label: '默认', inner: (w) => chip(w / 2 - 54, 4, `已选 3<span style="color: ${T.fg6}">·</span><span style="font-family: ${MONO}; color: ${T.accent}">约 $0.42</span>`) + trio(30, [0, 0, 0], w) + ring(w / 2, 44),
    cap: `右键选中集里任一张（≥ 2）：选中不变，出多选菜单（${code('nodeMenuTargets')} 现成）` },
  { label: '高亮', isNew: true, inner: (w) => at(3, 3, menu(mi('生成 3 个 · 约 $0.42', { icon: 'run', hl: true }) + mi('复制一份', { key: 'Ctrl D' }), w - 8)),
    cap: `只算 ${code('isGenerableNode')} 且没停用的；价格 = 各节点 estimateCostUsd 之和` },
  { label: '部分价格未知', inner: (w) => at(3, 3, menu(mi('生成 3 个 · 约 $0.30', { icon: 'run' }) + mi('另 1 个价格未知', { disabled: true }), w - 8)),
    cap: '无计费模型的不计价，另起一行写「另 N 个价格未知」（文案全板统一）' },
  { label: '置灰', tone: 'off', inner: (w) => at(3, 3, menu(mi('生成', { icon: 'run', disabled: true, note: '无可生成' }) + mi('分布', { sub: true, disabled: true, note: '需 ≥ 3' }), w - 8)),
    cap: '没有能生成的 / 分布不足 3 张：置灰写原因，不隐藏' },
  { label: '子菜单展开', inner: (w) => at(3, 8, menu(mi('对齐', { sub: true, hl: true }), 66)) + at(w - 98, 3, menu(mi('左对齐', { hl: true }) + mi('顶对齐', { disabled: true, note: '跨道' }), 96)),
    cap: '横截轴对齐只在目标同属一条道时可点（位置决定泳道归属）' },
  { label: '进行中', inner: (w) => trio(22, [0, 0, 0], w) + spinner(w / 2 - 63, 26) + spinner(w / 2 - 13, 26) + note(w / 2 - 70, 54, '排队 1 · 生成中 2', T.fg5),
    cap: '已入队：各卡出生成中；入队顺序按 data 边依赖（TakesCost）' },
  { label: '出错', tone: 'err', inner: (w) => errToast(w, '对齐失败', '3 个节点都已还原'),
    cap: `对齐 / 分布整批一个事务（${need}${code('moveNodes')}）：一张失败全部回滚` },
];
const multiFlow = [
  { num: 1, label: '框选 3 张', inner: (w) => `<div style="position: absolute; left: ${w / 2 - 76}px; top: 10px; width: 152px; height: 50px; border: 1px dashed ${T.accent}; border-radius: 4px; opacity: 0.6"></div>` + trio(16, [0, 12, 4], w),
    cap: '框选或 Shift 点选；高低不齐' },
  { num: 2, label: '右键其中一张', inner: (w) => at(3, 3, menu(mi('生成 3 个 · 约 $0.42', { icon: 'run' }) + mi('对齐', { sub: true, hl: true }), w - 8)),
    cap: '菜单顺序：动作 | 编排 | 删除；选中保持' },
  { num: 3, label: '选「顶对齐」', inner: (w) => at(3, 8, menu(mi('对齐', { sub: true, hl: true }), 66)) + at(w - 98, 3, menu(mi('顶对齐', { hl: true }) + mi('垂直居中'), 96)),
    cap: '按选区包围盒对齐；同一条道里才可点' },
  { num: 4, label: '结果', inner: (w) => trio(6, [0, 0, 0], w) + toast(5, 36, w - 10, { h: 30, title: '已对齐 3 个节点', btn: '撤销' }),
    cap: '一个事务移动；撤销栈一步「对齐」' },
  'SEP',
  { edge: true, label: '右键选中集外', inner: (w) => tile(10, 22, 40, 24, IMG.thumbMountain) + tile(58, 22, 40, 24, IMG.thumbWide) + tile(w - 50, 22, 40, 24, IMG.thumbMountain, false) + ring(w - 30, 34),
    cap: '右键集外的卡：选中换成它，出单张节点菜单（现有行为）' },
  { edge: true, label: '生成 ≥ 2 张', inner: (w) => `
      <div style="position: absolute; left: 5px; top: 8px; right: 5px; box-sizing: border-box; padding: 6px 8px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px">
        <div style="font-size: 10px; color: ${T.fg1}">运行 3 个 · 约 $0.42</div>
        <div style="display: flex; justify-content: flex-end; margin-top: 8px"><button class="amber" type="button" style="height: 20px; padding: 0 8px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 10px; font-weight: 500">运行</button></div>
      </div>`,
    cap: '确认、单次上限、顺序都归 TakesCost 运行对话框，这里不另定' },
  { edge: true, label: '多选 Ctrl ↵', inner: (w) => trio(10, [0, 0, 0], w) + at(w / 2 - 50, 44, `<div style="display: flex; align-items: center; gap: 4px">${key('Ctrl ↵')}<span style="font-size: 10px; color: ${T.fg5}">= 生成 3 个</span></div>`),
    cap: '按建议 W5-A：多选时 Ctrl ↵ 生成全部能生成的；文本框里归文本框' },
];

// ================= 4 · 空白处补三项 =================
const blankStates = [
  { label: '默认', inner: (w) => at(3, 3, menu(mi('新建…', { icon: 'nodeLibrary', key: 'Tab' }) + mi('粘贴', { key: 'Ctrl V', isNew: true }), w - 8)),
    cap: '新建… | 粘贴 · 导入媒体… · 导入剧本… | 全选 · 适应视图 | 网格吸附' },
  { label: '高亮', inner: (w) => at(3, 3, menu(mi('粘贴', { key: 'Ctrl V', hl: true }) + mi('导入媒体…', { icon: 'upload', key: 'Ctrl U', isNew: true }), w - 8)),
    cap: `悬停 = 键盘高亮；键位从快捷键表取（${code('canvasShortcutLabel')}）` },
  { label: '置灰', tone: 'off', inner: (w) => at(3, 3, menu(mi('粘贴', { disabled: true, note: '剪贴板为空' }) + mi('导入剧本…', { icon: 'script' }), w - 8)),
    cap: '剪贴板没有节点、图、字：粘贴置灰写原因' },
  { label: '开关打勾', isNew: true, inner: (w) => at(3, 3, menu(mi('适应视图', { icon: 'fit', key: 'Shift 1' }) + mi('网格吸附', { checked: true, hl: true }), w - 8)),
    cap: `${need}开关型打勾——现有打勾 = 当前所在、点不动；这一行打勾仍可点` },
  { label: '进行中', inner: (w) => toast(5, 16, w - 10, { icon: 'progress', spin: true, color: T.accent, title: '正在导入 3 个文件', progress: 60 }),
    cap: `复制进 ${code('canvases/&lt;id&gt;/imports/')}，先写 .partial 再改名` },
  { label: '出错', tone: 'err', inner: (w) => errToast(w, '1 个文件未导入', 'clip.webm · 格式不支持'),
    cap: '跳过的文件在卡片里点名；失败零残留' },
];
const blankFlow = [
  { num: 1, label: '空白处右键', inner: (w) => ring(w / 2, 36) + ptr(w / 2, 38),
    cap: '抬起时开、锚在按下点（现有）' },
  { num: 2, label: '选「粘贴」', inner: (w) => at(3, 3, menu(mi('新建…', { icon: 'nodeLibrary', key: 'Tab' }) + mi('粘贴', { key: 'Ctrl V', hl: true }), w - 8)),
    cap: '剪贴板里是节点：连同彼此的边' },
  { num: 3, label: '落在锚点', inner: (w) => ring(28, 24) + box(20, 12, 44, 24, '镜头 01', selBox) + box(w - 64, 12, 44, 24, '镜头 02', selBox) + sv(w, SH, hline(64, w - 64, 24, T.accent)),
    cap: '包围盒左上角对准锚点；新节点整批选中' },
  { num: 4, label: '撤销卡', inner: (w) => undoToast(w, '已粘贴 2 个节点', '含 1 条连线', 16),
    cap: '撤销栈一步「粘贴」' },
  'SEP',
  { edge: true, label: '跨项目粘贴', inner: () => `
      <div style="position: absolute; left: 8px; top: 8px; right: 8px; font-size: 10px; line-height: 1.5; color: ${T.fg3}">
        <div style="font-family: ${MONO}; color: ${T.fg6}; text-decoration: line-through">@{c_7f2a…} 撑船</div>
        <div><span style="color: ${T.accent}">@渔夫</span> 撑船</div>
        <div style="color: ${T.fg5}">gen_inputs 源 id 重映射</div>
      </div>`,
    cap: '@{角色 id} 对不上 → 换成「@名字」，并从 character_ids 删掉' },
  { edge: true, label: '吸附 · 按住 Ctrl(⌘)', inner: (w) => box(16, 18, 44, 24, '镜头 01', selBox) + box(w - 62, 22, 44, 24, '镜头 02', ghostBox + '; top: 23px') + at(w / 2 - 22, 50, key('Ctrl')),
    cap: '开吸附时松手取整；按住 Ctrl(⌘) 拖 = 原样放下' },
  { edge: true, label: '系统剪贴板', inner: (w) => tile(10, 12, 50, 30, IMG.thumbWide, false) + note(10, 48, '图 → 图像产物') + box(w - 70, 12, 60, 30, '文本节点') + note(w - 70, 48, '字 → 文本'),
    cap: '依赖按 IS-Q1-A（desktop_drop + pasteboard）' },
];

// ================= 5 · 拖到叙事线上插一镜 =================
// A ─ B 叙事线 + 被拖的卡（hit = 命中）
const insertScene = (w, o = {}) => {
  const y = 50, bw = 34;
  const x2 = w - 6 - bw;
  const hit = !!o.hit;
  const lineSvg = hit
    ? `<path d="M${6 + bw} ${y}H${x2}" fill="none" stroke="${T.accent}" stroke-width="4" stroke-opacity="0.25"></path>` + hline(6 + bw, x2, y, T.accent, 2.5)
    : hline(6 + bw, x2, y, T.fg4, 2);
  return `
    ${tile(6, y - 10, bw, 20, IMG.thumbMountain, false)}
    ${o.ghostB ? box(x2, y - 10, bw, 20, '', ghostBox) + tile(x2 + 0, y - 10, bw, 20, IMG.thumbWide, false, 'opacity: 0.35; transform: translateX(-30px)') : tile(x2, y - 10, bw, 20, IMG.thumbWide, false)}
    ${sv(w, SH, lineSvg)}
    ${box(w / 2 - 20, o.cardY !== undefined ? o.cardY : 18, 40, 22, o.card || '镜头 02', `${selBox}; transform: rotate(-2deg); box-shadow: 0 10px 18px rgba(0,0,0,0.6)`)}
    ${hit ? pill(w / 2 - 48, 3, '插入到 01 与 03 之间') : ''}`;
};
const insertStates = [
  { label: '拖动中', inner: (w) => insertScene(w, { cardY: 6 }),
    cap: '单张未入链的镜头 / 图像配置 / 视频配置；卡心离线 > 12px 不命中' },
  { label: '命中', isNew: true, inner: (w) => insertScene(w, { hit: true, cardY: 26 }),
    cap: '卡心离叙事线 ≤ 12px：线加粗变琥珀，顶上出提示' },
  { label: '让位预览', inner: (w) => insertScene(w, { hit: true, cardY: 26, ghostB: true }),
    cap: 'A、B 之间放不下一张卡：B 及链上其后整体后移一格' },
  { label: '禁用', tone: 'off', inner: (w) => insertScene(w, { cardY: 32, card: '文本' }),
    cap: '文本 / 便签 / 产物 / 已入链的卡（W4-B）：线不亮，照常落位' },
  { label: '按住 Ctrl(⌘)', inner: (w) => insertScene(w, { cardY: 32 }) + at(6, 6, key('Ctrl')),
    cap: '原样放下：不插入、不吸附；Shift 只锁轴，照常可插' },
  { label: '出错', tone: 'err', inner: (w) => errToast(w, '插入失败', '镜头 02 已放回原位'),
    cap: '事务失败：卡回原位，A→B 不动' },
];
const insertFlow = [
  { num: 1, label: '按下未入链的卡', inner: (w) => insertScene(w, { cardY: 4 }) + ptr(w / 2 + 6, 14),
    cap: `拖过 18px 才算拖（现有 ${code('resolveCardDrop')}）` },
  { num: 2, label: '拖近线 → 命中', inner: (w) => insertScene(w, { hit: true, cardY: 28 }),
    cap: '命中跟着卡心实时判，离开就熄灭' },
  { num: 3, label: '松手', inner: (w) => tile(6, 40, 30, 20, IMG.thumbMountain, false) + box(w / 2 - 18, 39, 36, 22, '02', selBox) + tile(w - 36, 40, 30, 20, IMG.thumbWide, false) + sv(w, SH, hline(36, w / 2 - 18, 50, T.accent) + hline(w / 2 + 18, w - 36, 50, T.accent)) + note(6, 8, '软删 A→B · 建 A→新 · 新→B'),
    cap: 'A→新 沿用原 sortOrder；一个事务' },
  { num: 4, label: '撤销卡', inner: (w) => undoToast(w, '已插入 镜头 02', '在 01 与 03 之间', 16),
    cap: '插入 + 让位 + 换道合计一步' },
  'SEP',
  { edge: true, label: 'Esc 取消', inner: (w) => insertScene(w, { cardY: 8 }) + at(6, 6, key('Esc')),
    cap: '拖动中 Esc：卡回原位，线熄灭，不建任何边' },
  { edge: true, label: '换道 + 插入', inner: (w) => `<div style="position: absolute; left: 0; right: 0; top: 30px; height: 40px; border-top: 1px solid ${T.laneDivider}; background: rgba(201,168,91,0.08)"></div>` + insertScene(w, { hit: true, cardY: 26 }),
    cap: '泳道归属照 resolveCardDrop 判；换道与插入算同一步撤销' },
  { edge: true, label: '锚点已有分叉', inner: (w) => tile(6, 8, 30, 20, IMG.thumbMountain, false) + sv(w, SH, `<path d="M36 18C70 18 80 52 ${w - 40} 52" fill="none" stroke="${T.fg4}" stroke-width="2"></path>` + hline(36, w - 40, 18, T.accent, 2.5)) + tile(w - 40, 8, 34, 20, IMG.thumbWide, false) + tile(w - 40, 42, 34, 20, IMG.thumbWide, false),
    cap: '按建议 KM-Q1-A：Ctrl → 开分叉排在最后；要插中间就拖到那条线上' },
];

// ================= 6 · 删链中间的镜 → 前后接上 =================
const chain3 = (w, o = {}) => {
  const bw = 38, gap = Math.floor((w - 12 - 3 * bw) / 2);
  const x = [6, 6 + bw + gap, 6 + 2 * (bw + gap)];
  const y = o.y || 20;
  const mid = o.gone ? box(x[1], y, bw, 24, '', ghostBox) : box(x[1], y, bw, 24, '镜头 02', o.sel ? `border-color: ${T.danger}; color: ${T.danger}` : '');
  const lines = o.gone
    ? hline(x[0] + bw, x[2], y + 12, T.accent)
    : (o.noIn ? '' : hline(x[0] + bw, x[1], y + 12)) + hline(x[1] + bw, x[2], y + 12);
  return (o.noIn ? '' : box(x[0], y, bw, 24, '镜头 01')) + mid + box(x[2], y, bw, 24, '镜头 03') + sv(w, SH, lines + (o.extraSvg ? o.extraSvg(x, bw, y) : ''));
};
const stitchStates = [
  { label: '可接', inner: (w) => chain3(w, { sel: true }) + note(6, 52, '一条入边 + 一条出边'),
    cap: '恰好一条叙事入边、一条叙事出边：删除时接上' },
  { label: '不接 · 分叉', tone: 'off', inner: (w) => chain3(w, { sel: true, y: 10, extraSvg: (x, bw, y) => `<path d="M${x[1] + bw} ${y + 12}C${x[1] + bw + 16} ${y + 12} ${x[2] - 16} ${y + 42} ${x[2]} ${y + 42}" fill="none" stroke="${T.fg4}" stroke-width="2"></path>` }) + box(w - 44, 40, 38, 24, '镜头 04'),
    cap: '有分叉 / 汇合：照常删，不接' },
  { label: '链首 / 链尾', tone: 'off', inner: (w) => chain3(w, { sel: true, noIn: true }) + note(6, 52, '只有一侧有边'),
    cap: '只有一侧有叙事边：照常删，没得接' },
  { label: '完成', tone: 'ok', inner: (w) => undoToast(w, '已删除 镜头 02', '镜头 01 与 03 已接上', 16),
    cap: '新边沿用入边的 sortOrder' },
  { label: '完成 · 未接', tone: 'ok', inner: (w) => undoToast(w, '已删除 镜头 02', '前后有分叉，未接上', 16),
    cap: '分叉时卡片说明为什么没接' },
  { label: '出错', tone: 'err', inner: (w) => errToast(w, '节点删除失败', '节点和连线都没动'),
    cap: `一个事务；失败整笔回滚（现有 ${code('nodeDeleteFailed')}）` },
];
const stitchFlow = [
  { num: 1, label: '选中 02', inner: (w) => chain3(w, { sel: true }),
    cap: '单选或多选都走同一条删除路径' },
  { num: 2, label: 'Del 或菜单删除', inner: (w) => at(3, 3, menu(mi('删除', { danger: true, key: 'Del', hl: true }) + mi('删除（不接上）', { danger: true, isNew: true }), w - 8)),
    cap: '按建议 W1-A：默认接上，菜单另给「删除（不接上）」' },
  { num: 3, label: '一个事务', inner: (w) => chain3(w, { gone: true }) + note(6, 52, '软删 02 + 两条边 · 建 01→03'),
    cap: `${need}${code('NodeDeletion')} 记下新建边 id` },
  { num: 4, label: '撤销', inner: (w) => chain3(w, {}) + toast(5, 48, w - 10, { h: 22, title: '已撤销删除' }),
    cap: '复原 02 及其边，软删接上的那条' },
  'SEP',
  { edge: true, label: '多选连续一段', inner: (w) => box(4, 12, 30, 22, '01') + box(42, 12, 30, 22, '02', `border-color: ${T.danger}; color: ${T.danger}`) + box(80, 12, 30, 22, '03', `border-color: ${T.danger}; color: ${T.danger}`) + box(w - 34, 12, 30, 22, '04') + sv(w, SH, hline(34, 42, 23) + hline(72, 80, 23) + hline(110, w - 34, 23) + `<path d="M19 34V50H${w - 19}V36" fill="none" stroke="${T.accent}" stroke-width="2"></path>`),
    cap: '按「连续被删的一段」算：段前一镜接段后一镜' },
  { edge: true, label: '删产物 · 文本', tone: 'off', inner: (w) => chain3(w, {}) + note(6, 52, '不在叙事链上，不涉及接线'),
    cap: '只有叙事链上的配置节点才判接不接' },
  { edge: true, label: 'Windows Del · mac ⌫', inner: (w) => at(w / 2 - 40, 26, `<div style="display: flex; align-items: center; gap: 6px">${key('Del')}<span style="font-size: 10px; color: ${T.fg6}">·</span>${key('⌫')}</div>`),
    cap: 'Delete / Backspace 同一条删除路径（现有），接不接判据相同' },
];

// ================= 7 · 停用 · 切线 =================
const stripes = 'background-image: repeating-linear-gradient(135deg, rgba(255,255,255,0.06) 0 6px, transparent 6px 12px)';
const xMark = (x, y) => `<path d="M${x - 3} ${y - 3}l6 6M${x + 3} ${y - 3}l-6 6" fill="none" stroke="${T.danger}" stroke-width="1.6" stroke-linecap="round"></path>`;
// 两条线 + 一道切线；cut = 划中
const knife = (w, o = {}) => {
  const c1 = o.cut ? T.danger : T.fg4;
  const c2 = o.lineage ? T.fg6 : (o.cut ? T.danger : T.teal);
  return sv(w, SH, `
    ${hline(8, w - 8, 22, c1, 2)}
    ${o.lineage ? `<path d="M8 50H${w - 8}" fill="none" stroke="${T.fg6}" stroke-width="1.25" stroke-dasharray="1.5 3.5" stroke-linecap="round"></path>` : hline(8, w - 8, 50, c2, 1.75)}
    ${o.knife !== false ? `<path d="M${w / 2 - 22} 6L${w / 2 + (o.short ? 0 : 18)} ${o.short ? 34 : 66}" fill="none" stroke="${T.danger}" stroke-width="1.5" stroke-dasharray="3 3" stroke-linecap="round"></path><circle cx="${w / 2 - 22}" cy="6" r="2.5" fill="${T.danger}"></circle>` : ''}
    ${o.cut ? xMark(w / 2 - 14, 22) + (o.lineage ? '' : xMark(w / 2 + 6, 50)) : ''}`);
};
const disabledCard = (x, y, w) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px">
    <div style="position: relative; height: 40px; border-radius: 4px; background: ${T.thumb}; outline: 1px dashed ${T.control}; overflow: hidden">
      <div style="opacity: 0.4; padding: 4px 6px; font-size: 9px; line-height: 1.5; color: ${T.fg3}">夜色里渔火一点点亮起，镜头缓慢拉远。</div>
      <div style="position: absolute; inset: 0; ${stripes}"></div>
    </div>
    <div style="height: 16px; display: flex; align-items: center; font-size: 10px; color: ${T.fg5}">已停用</div>
  </div>`;
const p2States = [
  { label: '已停用', isNew: true, inner: (w) => note(8, 4, '镜头 04 · 视频配置', T.fg5) + disabledCard(8, 18, w - 16),
    cap: `type_config.disabled（${code('patchTypeConfig')}，不迁移）；条纹 + 内容降透明度` },
  { label: '菜单行', inner: (w) => at(3, 3, menu(mi('停用', { hl: true }) + mi('启用', { disabled: true, note: '已启用' }), w - 8)),
    cap: '节点菜单「停用 / 启用」按当前状态只出一个；这里两态并排示意' },
  { label: '运行对话框', inner: () => `
      <div style="position: absolute; left: 6px; right: 6px; top: 24px; height: 22px; box-sizing: border-box; display: flex; align-items: center; gap: 4px; padding: 0 6px; border-radius: 3px; background: ${T.s3}; border: 1px solid ${T.outline}; font-size: 10px; opacity: 0.7">
        <span style="color: ${T.fg3}; flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">夜色渔火</span><span style="color: ${T.fg5}; white-space: nowrap">跳过 · 已停用</span>
      </div>`,
    cap: '按建议 W2-A：只在批量运行里跳过，不计价、不占单次上限' },
  { label: '切线中', isNew: true, inner: (w) => knife(w, { short: true }),
    cap: 'Alt + 左键在空白处按下拖：红色虚线' },
  { label: '划中', inner: (w) => knife(w, { cut: true }),
    cap: '划过的叙事 / 数据线变红并打叉，松手才断' },
  { label: '禁用 · 产出线', tone: 'off', inner: (w) => knife(w, { cut: true, lineage: true }),
    cap: '产出线划不断；平移工具下 Alt 拖不生效' },
  { label: '出错', tone: 'err', inner: (w) => errToast(w, '切线失败', '连线都没改动'),
    cap: '多条边一个事务：一条失败全部回滚' },
];
const p2Flow = [
  { num: 1, label: '按住 Alt', inner: (w) => knife(w, { knife: false }) + at(w / 2 - 14, 28, key('Alt')),
    cap: '先按 Alt 再在空白处按下左键；落在卡上不算' },
  { num: 2, label: '拖', inner: (w) => knife(w, { short: true }),
    cap: '虚线跟手；还没碰到线' },
  { num: 3, label: '划过两条', inner: (w) => knife(w, { cut: true }),
    cap: '命中的线实时变红' },
  { num: 4, label: '松手', inner: (w) => undoToast(w, '已切断 2 条连线', '', 16),
    cap: '全部断开，一张撤销卡、一步撤销' },
  'SEP',
  { edge: true, label: 'Esc 取消', inner: (w) => knife(w, { cut: true }) + at(6, 28, key('Esc')),
    cap: 'Esc 与「框选进行中」同一级；线恢复原色，什么都不断' },
  { edge: true, label: 'Windows Alt · mac ⌥', inner: (w) => at(8, 10, `<div style="display: flex; flex-direction: column; gap: 6px; font-size: 10px; color: ${T.fg5}"><div style="display: flex; align-items: center; gap: 4px">${key('Alt')}单按单放 → 菜单栏</div><div style="display: flex; align-items: center; gap: 4px">${key('⌥')}+ 拖 = 切线</div></div>`),
    cap: 'Alt 期间有指针动作就不聚焦菜单栏；右键拖仍是平移' },
  { edge: true, label: '停用后单独生成', inner: (w) => disabledCard(8, 6, w - 70) + at(w - 56, 14, `<button class="amber" type="button" style="height: 22px; padding: 0 8px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 10px; font-weight: 500">生成</button>`),
    cap: '按建议 W2-A：单独生成、序列、导出照常' },
];

const body = `
<div style="width: ${W}px; height: ${H}px; box-sizing: border-box; padding: 24px 32px; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45; display: flex; flex-direction: column">
  <div style="display: flex; flex-direction: column; gap: 4px; padding-bottom: 12px">
    <div style="display: flex; align-items: baseline; gap: 14px">
      <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">右键菜单补全与连线操作 · 状态与流程</div>
      <div style="color: ${T.fg4}">每个功能：状态 → 流程 ①–④ → 边界。菜单行照 CanvasMenuPanel：悬停 = 键盘高亮 · 置灰不隐藏 · 危险 · 打勾 · 子菜单 ›</div>
    </div>
    <div style="font-size: 11px; color: ${T.accent}">按建议：W1-A 默认接上 · W2-A 停用只在批量跳过 · W3-A Alt + 左键拖切线 · W4-B 只有未入链的能插 · W5-A 多选 Ctrl ↵ 批量 · KM-Q1-A 已有下一镜时开分叉、排在已有分叉之后</div>
    <div style="font-size: 11px; color: ${T.fg5}">右键公共规则（现有 _SecondaryClickDetector）：抬起时开、没挪出点击容差才算，锚点是按下点；按住右键拖 = 拖画布。<span style="color: ${T.accent}">需：</span>mac 上 ⌃ + 点也当右键。</div>
  </div>
  ${block('连线：右键 + 中点工具条', 'P0', 'canvas_view.dart 有点选连线 + 红色叉号圆钮删线、撤销卡「连线已删除」；edge_style.dart 五种线型；尚无连线菜单 / 工具条，Del 只删节点', edgeStates, edgeFlow)}
  ${block('泳道：标题栏右键', 'P0', 'lane_title_bar.dart 有折叠 / 编辑 / 删除三键 + 双击折叠；删除先弹确认且只软删道；尚无右键菜单', laneStates, laneFlow)}
  ${block('多选：右键', 'P0', 'node_menu_model.dart 的 nodeMenuTargets 已给选中集；多选时生成 / 存为角色置灰，复制 / 加入泳道 / 删除整批；尚无对齐 / 分布 / 批量生成', multiStates, multiFlow)}
  ${block('空白处 · 补三项', 'P1', 'create_node_menu.dart 已有 新建… / 导入脚本… | 全选 / 适应视图；粘贴、导入媒体无后端未画；尚无网格吸附', blankStates, blankFlow)}
  ${block('拖到叙事线上 = 插一镜', 'P1', 'drop_placement.dart 的 resolveCardDrop（18px / 跨带 / 进新带 12px）已有；尚无插入命中与让位', insertStates, insertFlow)}
  ${block('删链中间的镜 → 前后接上', 'P1', 'canvas_node_delete.dart 单删「节点已删除 · 撤销」、多选「已删除 N 个节点」；尚不接上前后', stitchStates, stitchFlow)}
  ${block('停用 · 切线', 'P2', '两项都尚无；停用走 patchTypeConfig，不给 NodeRepository 加方法', p2States, p2Flow)}
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'ContextMenusDetail.dc.html', html: page('右键菜单补全与连线操作 · 状态与流程', W, H, body, logic), W, H };
