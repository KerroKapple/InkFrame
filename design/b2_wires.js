// 第二批画板：右键菜单补全与连线操作（连线 / 泳道 / 多选三套菜单 + 空白处补项 + 中点工具条 +
// 拖到叙事线上插入 + 删除并接上 + 停用 / 切线）。1280×1280，静态。
const { T, IMG, SANS, MONO, page, ic, caret } = require('./common.js');

const W = 1280, H = 1280;

// ---- 与 interactions.js 同一套小件（本地复制）----
const h3 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 8px; margin-bottom: 10px; flex-wrap: wrap"><div style="font-weight: 500; color: ${T.fg1}">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const kbd = (k) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}; white-space: nowrap">${k}</span>`;
const menuSep = `<div style="height: 1px; background: ${T.bStrong}; margin: 4px 0"></div>`;
const menu = (inner, width = 200, extra = '') => `<div style="width: ${width}px; box-sizing: border-box; padding: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6); ${extra}">${inner}</div>`;
const newTag = `<span style="height: 14px; padding: 0 4px; border-radius: 3px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 9px; line-height: 14px">新</span>`;
// 连线语义的小样（菜单行的前导，替代图标）
const lineSwatch = (color, dash = '', width = 1.75) => `<svg width="16" height="10" viewBox="0 0 16 10" aria-hidden="true" style="display: block; flex: none"><path d="M1 5H15" fill="none" stroke="${color}" stroke-width="${width}" ${dash ? `stroke-dasharray="${dash}"` : ''} stroke-linecap="round"></path></svg>`;
const sq = (color) => `<div style="width: 16px; display: flex; justify-content: center"><div style="width: 8px; height: 8px; border-radius: 2px; background: ${color}"></div></div>`;

// 菜单一行：与 create_node_menu.dart 的 _MenuRow 同构——前导 | 文字 | 原因 | 键位 | 打勾 | ›；置灰整行 0.5、不隐藏
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

const rules = (lines) => `<div style="font-size: 11px; color: ${T.fg4}; line-height: 1.5; margin-top: 8px">${lines.map((l) => `<div style="padding-left: 10px; text-indent: -10px">· ${l}</div>`).join('')}</div>`;
const code = (t) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${t}</span>`;
const stage = (h, inner, extra = '') => `<div style="position: relative; height: ${h}px; border-radius: 6px; background: ${T.s1}; border: 1px solid ${T.outline}; background-image: radial-gradient(${T.grid} 1px, transparent 1px); background-size: 16px 16px; overflow: hidden; ${extra}">${inner}</div>`;

// 迷你节点卡：标题行 + 内容框（与 main.js nodeCard 同构，缩小）
const mini = ({ x, y, w, bh, title, type = '', box = '', sel = false, extra = '', boxExtra = '' }) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; ${extra}">
    <div style="height: 15px; display: flex; align-items: center; gap: 4px; font-size: 10px; white-space: nowrap; overflow: hidden">
      <div style="font-weight: 500; color: ${sel ? T.fg1 : T.fg2}; overflow: hidden; text-overflow: ellipsis">${title}</div><div style="flex: 1"></div><div style="font-size: 9px; color: ${T.fg5}">${type}</div>
    </div>
    <div style="position: relative; width: ${w}px; height: ${bh}px; border-radius: 4px; background: ${T.thumb}; outline: 1px solid ${sel ? T.accent : T.outline}; overflow: hidden; ${boxExtra}">${box}</div>
  </div>`;
const thumb = (src) => `<img src="${src}" alt="" style="width: 100%; height: 100%; object-fit: cover; display: block">`;
const promptLines = (t) => `<div style="padding: 5px 6px; font-size: 9px; line-height: 1.5; color: ${T.fg3}; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden">${t}</div>`;
const port = (x, y, color = T.fg5, filled = true) => `<div style="position: absolute; left: ${x - 4}px; top: ${y - 4}px; width: 8px; height: 8px; border-radius: 4px; box-sizing: border-box; ${filled ? `background: ${color}` : `background: ${T.s1}; border: 1.5px solid ${color}`}"></div>`;

// ================= 1 · 连线 =================
const EA = { x: 10, y: 14, w: 104, bh: 58 }, EB = { x: 214, y: 14, w: 104, bh: 58 };
const EY = EA.y + 15 + EA.bh / 2;
const edgeStage = stage(270, `
  ${mini({ ...EA, title: '成片', type: '图像', box: thumb(IMG.thumbMountain) })}
  ${mini({ ...EB, title: '镜头 02', type: '视频配置', box: promptLines('江面雾气渐散，渔夫撑船缓缓驶出画面，镜头缓推。') })}
  <svg width="330" height="120" viewBox="0 0 330 120" aria-hidden="true" style="position: absolute; left: 0; top: 0">
    <path d="M${EA.x + EA.w} ${EY}H${EB.x}" fill="none" stroke="${T.accent}" stroke-width="1.75"></path>
    <path d="M${EB.x - 7} ${EY - 3.5}L${EB.x} ${EY}l-7 3.5" fill="none" stroke="${T.accent}" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"></path>
  </svg>
  ${port(EA.x + EA.w, EY, T.accent)}${port(EB.x, EY, T.accent, false)}
  <div style="position: absolute; left: ${(EA.x + EA.w + EB.x) / 2 - 47}px; top: ${EY - 13}px; height: 26px; display: flex; align-items: center; padding: 0 2px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 13px; box-shadow: 0 8px 20px rgba(0,0,0,0.5)">
    <button class="hov" type="button" aria-label="改语义" style="height: 22px; padding: 0 6px 0 8px; border-radius: 11px; display: flex; align-items: center; gap: 4px; font-size: 11px; color: ${T.teal}">${lineSwatch(T.teal)}首帧${caret()}</button>
    <div style="width: 1px; height: 14px; background: ${T.control}"></div>
    <button class="hov" type="button" aria-label="删除连线" style="width: 24px; height: 22px; border-radius: 11px; display: flex; align-items: center; justify-content: center; color: ${T.fg4}">${ic('trash', 14)}</button>
  </div>
  <div style="position: absolute; left: 10px; top: 104px; font-size: 10px; color: ${T.fg6}">右键这条线</div>
  <div style="position: absolute; left: 6px; top: 122px">
    ${menu(`
      ${mi('改语义', { sub: true, hl: true })}
      ${mi('插入节点…', { disabled: true, note: '仅叙事线' })}
      ${menuSep}
      ${mi('删除', { danger: true, key: 'Del' })}
    `, 168)}
  </div>
  <div style="position: absolute; left: 168px; top: 122px">
    ${menu(`
      ${mi('叙事', { lead: lineSwatch(T.fg4, '', 2), disabled: true, note: '源是产物' })}
      ${mi('首帧', { lead: lineSwatch(T.teal), checked: true })}
      ${mi('尾帧', { lead: lineSwatch(T.peach), disabled: true, note: '模型不支持' })}
      ${mi('参考', { lead: lineSwatch(T.sky, '3 2.5', 1.5) })}
    `, 156)}
  </div>
`);
const edgeCol = `
  <div>
    ${h3('连线：右键 + 中点工具条', '两处打开同一张「改语义」表')}
    ${edgeStage}
    ${rules([
      '右键线 = 先选中再开菜单；产出线点不中，没有菜单',
      '置灰写原因。叙事：两端都是非文本配置节点、不成环；首 / 尾帧：源带图、目标是视频配置且模型支持；参考：源带图',
      `改成首 / 尾帧时，目标原有的同角色线同一事务降为参考（${code('updateRole')} 现成）`,
      `数据 ↔ 叙事 = 换 edge_type：一个事务软删旧边 + 建新边；需新增 ${code('changeEdgeType')}`,
      '插入节点… 只对叙事线：锚点在线中点，A → 新 → B 一次接好',
      '工具条替换现在的红色 ✕ 圆钮；选中线时 Del 删线（现在只删节点）',
    ])}
  </div>`;

// ================= 2 · 泳道 =================
const laneStage = stage(270, `
  <div style="position: absolute; left: 0; right: 0; top: 10px; height: 170px; border-top: 1px solid ${T.laneDivider}; border-bottom: 1px solid ${T.laneDivider}; background: rgba(232,168,124,0.03)"></div>
  <div style="position: absolute; left: 8px; top: 18px; width: 200px; height: 26px; box-sizing: border-box; display: flex; align-items: center; gap: 6px; padding: 0 8px; border-radius: 3px; background: rgba(38,38,38,0.82); outline: 1px solid ${T.accent}">
    <div style="width: 8px; height: 8px; border-radius: 2px; background: #E8A87C; flex: none"></div>
    <div style="font-weight: 500; color: ${T.fg1}; font-size: 12px">水墨风格</div>
    <div style="flex: 1; min-width: 0; font-size: 10px; color: ${T.fg5}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">柔和笔触，雾气留白</div>
    <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">3</div>
  </div>
  ${mini({ x: 16, y: 104, w: 92, bh: 50, title: '镜头 01', type: '图像', box: thumb(IMG.thumbMountain) })}
  ${mini({ x: 150, y: 104, w: 92, bh: 50, title: '镜头 02', type: '视频', box: thumb(IMG.thumbWide) })}
  <div style="position: absolute; left: 40px; top: 34px">
    ${menu(`
      ${mi('改名', { hl: true })}
      ${mi('改风格…', { icon: 'lane' })}
      ${menuSep}
      ${mi('选中内容', { icon: 'select', note: '3 个' })}
      ${mi('折叠', { key: '双击标题' })}
      ${menuSep}
      ${mi('解散（节点留下）')}
      ${menuSep}
      ${mi('删除泳道和内容', { danger: true })}
    `, 208)}
  </div>
`);
const laneCol = `
  <div>
    ${h3('泳道', '标题栏右键')}
    ${laneStage}
    ${rules([
      '只认标题栏右键；带内空白处右键仍出空白处菜单',
      `改名：标题栏原地变输入框，↵ 存 Esc 退（${code('updateLane')}）；改风格… 开现有编辑框`,
      '选中内容：lane_id 是这条道的全部节点',
      '解散（节点留下）= 现有「删除泳道」，补清节点 lane_id、屏幕位置不动——现在软删后节点还指着已删的道',
      '删除泳道和内容：一个事务软删道 + 道内节点及其边',
      '两项分开进撤销栈、分开命名：「解散泳道」「删除泳道和内容」，各算一步、互不合并',
      '都不弹确认，走撤销卡；唯一例外：道内有生成中的任务——取消任务撤不回来，先确认',
    ])}
  </div>`;

// ================= 3 · 多选 =================
const tiny = (x, src) => `<div style="position: absolute; left: ${x}px; top: 34px; width: 44px; height: 28px; border-radius: 3px; overflow: hidden; outline: 1px solid ${T.accent}">${thumb(src)}</div>`;
const multiStage = stage(270, `
  <div style="position: absolute; left: 196px; top: 6px; height: 20px; padding: 0 8px; border-radius: 10px; background: ${T.s3}; border: 1px solid ${T.control}; display: flex; align-items: center; gap: 6px; font-size: 11px; color: ${T.fg2}">已选 3<span style="color: ${T.fg6}">·</span><span style="font-family: ${MONO}; font-size: 10px; color: ${T.accent}">约 $0.42</span></div>
  <div style="position: absolute; left: 192px; top: 30px; width: 150px; height: 34px; border: 1px dashed ${T.accent}; border-radius: 4px; opacity: 0.6"></div>
  ${tiny(196, IMG.thumbMountain)}${tiny(246, IMG.thumbWide)}${tiny(296, IMG.thumbMountain)}
  <div style="position: absolute; left: 6px; top: 6px">
    ${menu(`
      ${mi('生成 3 个 · 约 $0.42', { icon: 'run', key: 'Ctrl ↵' })}
      ${mi('复制一份', { key: 'Ctrl D' })}
      ${menuSep}
      ${mi('对齐', { sub: true, hl: true })}
      ${mi('分布', { sub: true })}
      ${mi('包成泳道', { icon: 'lane', key: 'Ctrl G' })}
      ${mi('加入泳道', { sub: true })}
      ${menuSep}
      ${mi('删除', { danger: true, key: 'Del' })}
    `, 190)}
  </div>
  <div style="position: absolute; left: 190px; top: 75px">
    ${menu(`
      ${mi('左对齐')}${mi('水平居中')}${mi('右对齐')}
      ${menuSep}
      ${mi('顶对齐', { disabled: true, note: '跨泳道' })}${mi('垂直居中', { disabled: true })}${mi('底对齐', { disabled: true })}
    `, 154)}
  </div>
`);
const multiCol = `
  <div>
    ${h3('多选', '右键选中集里任一张，且选中 ≥ 2')}
    ${multiStage}
    ${rules([
      `取代节点菜单（${code('nodeMenuTargets')} 已给出选中集）；单张仍出节点菜单`,
      `生成 N 个：只算 ${code('isGenerableNode')} 且没停用的；花费 = 各节点 ${code('estimateCostUsd')} 之和，无计费模型记「另 N 个价格未知」`,
      '何时确认、单次上限、入队顺序（按 data 边依赖）都以 TakesCost 的运行对话框为准，这里不另定',
      '对齐按选区包围盒；横截轴对齐只在目标同属一条道时可点（位置决定泳道归属）',
      `分布：等距要 ≥ 3 张；对齐 / 分布整批一个事务，需新增 ${code('moveNodes')}`,
      '包成泳道（Ctrl G）：整批移入，标题栏进改名；新道插在哪见 Selection Q5，这里不另定',
    ])}
  </div>`;

// ================= 4 · 空白处（补项）=================
const blankStage = stage(270, `
  <div style="position: absolute; left: 8px; top: 8px">
    ${menu(`
      ${mi('新建…', { icon: 'nodeLibrary', key: 'Tab' })}
      ${mi('粘贴', { key: 'Ctrl V', isNew: true, hl: true })}
      ${mi('导入媒体…', { icon: 'upload', key: 'Ctrl U', isNew: true })}
      ${mi('导入剧本…', { icon: 'script' })}
      ${menuSep}
      ${mi('全选', { key: 'Ctrl A' })}
      ${mi('适应视图', { icon: 'fit', key: 'Shift 1' })}
      ${menuSep}
      ${mi('网格吸附', { isNew: true, checked: true })}
    `, 210)}
  </div>
`, `background-image: none`);
const blankCol = `
  <div>
    ${h3('空白处 · 补三项', '标「新」的')}
    ${blankStage}
    ${rules([
      '粘贴：节点连同彼此的边落在右键点；系统剪贴板有图建图像产物节点、有字建文本节点',
      '跨项目粘贴：提示词里的 @{角色 id}、gen_inputs 的源节点 id 重映射，对不上的剥掉',
      '读剪贴板图片用哪个依赖见 ImportSearch 需定 1；节点菜单同批补剪切 / 复制',
      `导入媒体 / 粘贴的图：复制进 ${code('canvases/&lt;id&gt;/imports/')}，建无来源的产物节点`,
      '网格吸附存 preferences.json，松手时取整；按住 Ctrl（⌘）拖 = 原样放下，不吸附',
    ])}
  </div>`;

// ================= 5 · 拖到叙事线上插入 =================
const IA = { x: 8, y: 66, w: 68, bh: 40 }, IB = { x: 204, y: 66, w: 68, bh: 40 };
const IY = IA.y + 15 + IA.bh / 2;
const insertStage = stage(178, `
  <div style="position: absolute; left: 50%; top: 10px; transform: translateX(-50%); height: 20px; padding: 0 8px; border-radius: 10px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 10px; display: flex; align-items: center; white-space: nowrap">插入到 镜头 01 与 03 之间</div>
  ${mini({ ...IA, title: '镜头 01', box: thumb(IMG.thumbMountain) })}
  ${mini({ ...IB, title: '镜头 03', box: thumb(IMG.thumbWide) })}
  <svg width="282" height="178" viewBox="0 0 282 178" aria-hidden="true" style="position: absolute; left: 0; top: 0">
    <path d="M${IA.x + IA.w} ${IY}H${IB.x}" fill="none" stroke="${T.accent}" stroke-width="4" stroke-opacity="0.25"></path>
    <path d="M${IA.x + IA.w} ${IY}H${IB.x}" fill="none" stroke="${T.accent}" stroke-width="2.5"></path>
  </svg>
  ${mini({ x: 106, y: 52, w: 68, bh: 40, title: '镜头 02', type: '新', box: promptLines('渔夫回望远山'), sel: true, extra: 'transform: rotate(-2deg); filter: drop-shadow(0 10px 18px rgba(0,0,0,0.6))' })}
  <div style="position: absolute; left: ${IB.x - 2}px; top: 132px; display: flex; align-items: center; gap: 4px; font-size: 10px; color: ${T.fg5}">让位 <svg width="22" height="8" viewBox="0 0 22 8" aria-hidden="true"><path d="M1 4H20M16 1l4 3-4 3" fill="none" stroke="${T.fg5}" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"></path></svg></div>
`);
const insertCol = `
  <div>
    ${h3('拖到叙事线上 = 插一镜', 'P1')}
    ${insertStage}
    ${rules([
      '拖动单张、未入链的镜头 / 图像配置 / 视频配置（文本、便签、产物不可插）；卡片中心离叙事线 ≤ 12px 即命中：线加粗变琥珀、顶上出提示',
      '松手：一个事务软删 A→B，建 A→新（沿用原 sortOrder）和 新→B',
      '让位：A、B 沿主轴放不下一张卡时，B 及链上其后的节点整体后移一格',
      '按住 Ctrl（⌘）= 原样放下：不插入、也不吸附；Shift 只锁轴，照常可插',
      `泳道归属沿用已上线的 ${code('resolveCardDrop')}（拖过 18px、跨带边界、进新带 ≥ 12px）`,
      '插入 + 让位 + 换道算撤销栈里的一步',
    ])}
  </div>`;

// ================= 6 · 删除并接上 =================
const box = (x, y, label, extra = '') => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: 58px; height: 26px; box-sizing: border-box; border-radius: 4px; background: ${T.s3}; border: 1px solid ${T.outline}; font-size: 10px; color: ${T.fg2}; display: flex; align-items: center; justify-content: center; ${extra}">${label}</div>`;
const arrow = (x1, x2, y, color = T.fg4, dash = '') => `<svg width="${x2 - x1 + 2}" height="10" viewBox="0 0 ${x2 - x1 + 2} 10" aria-hidden="true" style="position: absolute; left: ${x1}px; top: ${y - 5}px"><path d="M0 5H${x2 - x1}" fill="none" stroke="${color}" stroke-width="2" ${dash ? `stroke-dasharray="${dash}"` : ''}></path><path d="M${x2 - x1 - 6} 2L${x2 - x1} 5l-6 3" fill="none" stroke="${color}" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"></path></svg>`;
const stitchStage = stage(178, `
  <div style="position: absolute; left: 10px; top: 8px; font-size: 10px; color: ${T.fg6}">删前</div>
  ${box(10, 24, '镜头 01')}${arrow(68, 112, 37)}${box(112, 24, '镜头 02', `border-color: ${T.danger}; color: ${T.danger}`)}${arrow(170, 214, 37)}${box(214, 24, '镜头 03')}
  <div style="position: absolute; left: 10px; top: 60px; font-size: 10px; color: ${T.fg6}">删后</div>
  ${box(10, 76, '镜头 01')}${arrow(68, 214, 89, T.accent)}${box(112, 76, '', `border: 1px dashed ${T.control}; background: transparent`)}${box(214, 76, '镜头 03')}
  <div style="position: absolute; left: 8px; right: 8px; top: 118px; height: 48px; box-sizing: border-box; display: flex; align-items: center; gap: 8px; padding: 0 10px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px">
    <div style="color: ${T.fg3}; display: flex">${ic('undo', 16)}</div>
    <div style="flex: 1; min-width: 0"><div style="font-size: 11px; color: ${T.fg1}">已删除 镜头 02</div><div style="font-size: 10px; color: ${T.fg5}">镜头 01 与 03 已接上</div></div>
    <button class="amber" type="button" style="height: 22px; padding: 0 8px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 11px; font-weight: 500">撤销</button>
  </div>
`);
const stitchCol = `
  <div>
    ${h3('删链中间的镜 → 前后接上', 'P1')}
    ${stitchStage}
    ${rules([
      '被删的节点恰好一条叙事入边、一条叙事出边：删除时把前后两镜接上，新边沿用入边的 sortOrder',
      '多选删除按「连续被删的一段」算：段前一镜接段后一镜',
      '有分叉 / 汇合不接，撤销卡写「前后有分叉，未接上」',
      `同一事务完成；撤销 = 复原节点及其边并软删接上的那条（${code('NodeDeletion')} 需记下新建边 id）`,
    ])}
  </div>`;

// ================= 7 · P2：停用 / 切线 =================
const stripes = 'background-image: repeating-linear-gradient(135deg, rgba(255,255,255,0.06) 0 6px, transparent 6px 12px)';
const xMark = (x, y) => `<svg width="10" height="10" viewBox="0 0 10 10" aria-hidden="true" style="position: absolute; left: ${x - 5}px; top: ${y - 5}px"><path d="M2 2l6 6M8 2l-6 6" fill="none" stroke="${T.danger}" stroke-width="1.6" stroke-linecap="round"></path></svg>`;
const p2Stage = stage(178, `
  <div style="position: absolute; left: 10px; top: 8px; width: 116px">
    <div style="height: 15px; display: flex; align-items: center; font-size: 10px; color: ${T.fg5}">镜头 04<div style="flex: 1"></div><span style="font-size: 9px">视频配置</span></div>
    <div style="position: relative; height: 54px; border-radius: 4px; background: ${T.thumb}; outline: 1px dashed ${T.control}; overflow: hidden">
      <div style="opacity: 0.4">${promptLines('夜色里渔火一点点亮起，镜头缓慢拉远。')}</div>
      <div style="position: absolute; inset: 0; ${stripes}"></div>
    </div>
    <div style="height: 18px; display: flex; align-items: center; gap: 4px; font-size: 10px; color: ${T.fg5}">已停用</div>
  </div>
  <div style="position: absolute; left: 136px; top: 8px; width: 122px">
    <div style="font-size: 9px; color: ${T.fg6}; margin-bottom: 3px">运行对话框里这一行</div>
    <div style="height: 22px; box-sizing: border-box; display: flex; align-items: center; gap: 4px; padding: 0 6px; border-radius: 3px; background: ${T.s3}; border: 1px solid ${T.outline}; font-size: 10px; opacity: 0.7">
      <span style="color: ${T.fg3}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; flex: 1; min-width: 0">夜色渔火</span><span style="color: ${T.fg5}; white-space: nowrap">跳过 · 已停用</span>
    </div>
    <div style="font-size: 10px; line-height: 1.45; color: ${T.fg5}; margin-top: 6px">节点右键「停用 / 启用」；连线保留</div>
  </div>
  <div style="position: absolute; left: 10px; top: 102px; height: 18px; padding: 0 6px; border-radius: 3px; border: 1px solid ${T.outline}; background: ${T.s3}; font-family: ${MONO}; font-size: 10px; color: ${T.fg3}; display: flex; align-items: center">Alt + 拖</div>
  <svg width="282" height="178" viewBox="0 0 282 178" aria-hidden="true" style="position: absolute; left: 0; top: 0">
    <path d="M90 124C140 124 170 132 272 132" fill="none" stroke="${T.danger}" stroke-width="2" stroke-opacity="0.85"></path>
    <path d="M90 156C150 156 190 150 272 150" fill="none" stroke="${T.danger}" stroke-width="1.5" stroke-dasharray="5 4" stroke-opacity="0.85"></path>
    <path d="M10 166C40 166 80 166 140 166" fill="none" stroke="${T.fg4}" stroke-width="2"></path>
    <path d="M168 106L196 172" fill="none" stroke="${T.danger}" stroke-width="1.5" stroke-dasharray="3 3" stroke-linecap="round"></path>
    <circle cx="168" cy="106" r="2.5" fill="${T.danger}"></circle>
  </svg>
  ${xMark(178, 129)}${xMark(186, 151)}
`);
const p2Col = `
  <div>
    ${h3('停用 · 切线', 'P2')}
    ${p2Stage}
    ${rules([
      '停用：type_config.disabled = true（JSONB，不用迁移）；卡片条纹 + 内容降透明度，状态行「已停用」',
      'TakesCost 的运行对话框照列这一行，状态「跳过 · 已停用」，不计价、不占单次上限',
      'Alt + 左键在空白处拖出红色虚线，划过的叙事 / 数据线变红；松手全部断开、一张撤销卡',
      'Esc 取消切线，与「框选进行中」同一级（菜单 > @ 弹层 > 查找条 > 框选 / 切线进行中 > 工具锁 > 清空选中）',
      'Alt 期间有指针动作就不聚焦菜单栏——只认单独按下再松开的 Alt；不做 Alt+字母助记键',
      '右键拖已是平移，所以不用 Blender 的 Ctrl + 右键；产出线划不断；平移工具下不生效',
    ])}
  </div>`;

// ================= 需要你定 =================
const q = (n, title, opts, rec) => `
  <div style="padding: 8px 0; border-top: 1px solid ${T.washBorder}">
    <div style="font-weight: 500; color: ${T.fg1}; margin-bottom: 4px"><span style="font-family: ${MONO}; font-size: 11px; color: ${T.accent}; margin-right: 6px">${n}</span>${title}</div>
    <div style="font-size: 11px; color: ${T.fg3}; line-height: 1.5">${opts.join('<span style="color: ' + T.fg6 + '">　·　</span>')}</div>
    <div style="font-size: 11px; color: ${T.accent}; line-height: 1.55; margin-top: 2px">建议 ${rec}</div>
  </div>`;
const decide = `
  <div style="background: ${T.wash}; border: 1px solid ${T.washBorder}; border-radius: 6px; padding: 12px 14px 4px">
    <div style="font-weight: 500; color: ${T.accent}; margin-bottom: 6px">需要你定</div>
    ${q('W1', '删链中间的镜，默认接上前后两镜吗？', ['A. 默认接上；菜单另给「删除（不接上）」', 'B. 默认不接，Ctrl Del 才接（Node-RED）', 'C. 每次弹框问'], 'A：撤销卡一键就能回退')}
    ${q('W2', '「停用」管到哪儿？', ['A. 只在批量生成时跳过；单独生成、序列、导出照常', 'B. 序列和导出也跳过这一镜'], 'A：停用是「先别花钱」，不是删镜')}
    ${q('W3', '切线用什么手势？', ['A. Alt + 左键拖空白', 'B. Ctrl Alt + 左键拖', 'C. 「更多 → 剪线」模式，单键 K'], 'A，并列进设置的快捷键页')}
    ${q('W4', '已在链上的节点拖到另一条叙事线上？', ['A. 当作移动：原位置接上，再插进新位置', 'B. 不触发，只有未入链的能插'], '先做 B，A 留到后面')}
    ${q('W5', '多选时 Ctrl ↵ 做什么？', ['A. 生成全部能生成的（确认规则见 TakesCost）', 'B. 仍只在恰好一张时生效，批量只走菜单'], 'A：菜单行已经写着 Ctrl ↵，与 TakesCost 入口表一致')}
  </div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; box-sizing: border-box; padding: 24px 32px; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45; display: flex; flex-direction: column; gap: 18px">
  <div style="display: flex; align-items: baseline; gap: 14px">
    <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">右键菜单补全与连线操作</div>
    <div style="color: ${T.fg4}">补齐连线 / 泳道 / 多选三套菜单；排序沿用节点菜单：动作 | 编排 | 删除。不可用的置灰不隐藏，键位都从快捷键表取</div>
  </div>
  <div style="display: grid; grid-template-columns: 330px 260px 350px 228px; gap: 16px; align-items: start">
    ${edgeCol}
    ${laneCol}
    ${multiCol}
    ${blankCol}
  </div>
  <div style="display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) minmax(0, 1fr) 380px; gap: 16px; align-items: start">
    ${insertCol}
    ${stitchCol}
    ${p2Col}
    ${decide}
  </div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'ContextMenus.dc.html', html: page('右键菜单补全与连线操作', W, H, body, logic) };
