// 第二批画板：选择与批量编辑——框选 / 多选拖动 / 浮动工具条 / 多选检查器 / 对齐分布吸附 / 包成泳道（1280×1400，静态）
const { T, IMG, SANS, MONO, page, ic, caret } = require('./common.js');

const W = 1280, H = 1400;

// ---- 与 interactions.js 同一套小件（本地复制）----
const h3 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 8px; margin-bottom: 10px"><div style="font-weight: 500; color: ${T.fg1}">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const kbd = (k) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}">${k}</span>`;
const menuItem = (icon, label, key = '', extra = '') => `
  <div style="height: 26px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border-radius: 3px; color: ${T.fg2}; ${extra}">
    ${icon ? `<div style="color: ${T.fg4}; display: flex">${ic(icon, 16)}</div>` : '<div style="width: 16px"></div>'}
    <div style="flex: 1">${label}</div>${key ? kbd(key) : ''}
  </div>`;
const menu = (inner, width = 240) => `<div style="width: ${width}px; box-sizing: border-box; padding: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6)">${inner}</div>`;

// 规则行：以「需：」开头的是后端 / 数据缺口，前缀标琥珀
const rules = (list, extra = '') => `
  <div style="font-size: 11px; color: ${T.fg4}; line-height: 1.6; ${extra}">
    ${list.map((r) => r.startsWith('需：')
      ? `<div><span style="color: ${T.accent}">需</span>　${r.slice(2)}</div>`
      : `<div>· ${r}</div>`).join('')}
  </div>`;

// 画布小片：网格底，与 main.js 画布同色
const stage = (w, h, inner, extra = '') => `<div style="position: relative; width: ${w}px; height: ${h}px; border-radius: 4px; overflow: hidden; background-color: ${T.s1}; background-image: linear-gradient(${T.grid} 1px, transparent 1px), linear-gradient(90deg, ${T.grid} 1px, transparent 1px); background-size: 19.2px 19.2px; outline: 1px solid ${T.bSubtle}; ${extra}">${inner}</div>`;

// 迷你节点卡（main.js nodeCard 的缩小版：标题行 + 内容框）
const MW = 104, MB = 58;
const mini = ({ x, y, title, type, box, selected = false }) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${MW}px">
    <div style="height: 14px; display: flex; align-items: center; gap: 4px; font-size: 9px">
      <div style="font-weight: 500; color: ${selected ? T.fg1 : T.fg3}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</div><div style="flex: 1"></div><div style="color: ${T.fg6}">${type}</div>
    </div>
    <div style="position: relative; width: ${MW}px; height: ${MB}px; border-radius: 3px; background: ${T.thumb}; outline: ${selected ? `1.5px solid ${T.accent}` : `1px solid ${T.outline}`}; overflow: hidden">${box}</div>
  </div>`;
const txt = (s) => `<div style="padding: 5px 6px; font-size: 8px; line-height: 1.5; color: ${T.fg3}; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden">${s}</div>`;
const pic = (src) => `<img src="${src}" alt="" style="width: 100%; height: 100%; object-fit: cover; display: block">`;
const ghost = (x, y) => `<div style="position: absolute; left: ${x}px; top: ${y + 14}px; width: ${MW}px; height: ${MB}px; box-sizing: border-box; border-radius: 3px; border: 1px dashed ${T.controlStrong}"></div>`;
const countChip = (x, y, label) => `<div style="position: absolute; left: ${x}px; top: ${y}px; height: 18px; padding: 0 7px; border-radius: 9px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; color: ${T.fg2}; font-family: ${MONO}; font-size: 10px; display: flex; align-items: center">${label}</div>`;
const laneTitle = (x, y, label, count, tint = '#E8A87C', extra = '') => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; height: 24px; display: flex; align-items: center; gap: 6px; padding: 0 8px; border-radius: 3px; background: rgba(38,38,38,0.82); border: 1px solid ${T.outline}; font-size: 11px; ${extra}">
    <div style="width: 8px; height: 8px; border-radius: 2px; background: ${tint}"></div>
    <div style="font-weight: 500; color: ${T.fg1}">${label}</div>
    <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">${count}</div>
  </div>`;

// ---------- A 框选与加减选 ----------
const colMarquee = `
  <div>
    ${h3('框选与加减选', '选择工具下在空白处拖')}
    ${stage(360, 140, `
      ${mini({ x: 14, y: 28, title: '镜头 01', type: '图像配置', box: txt('拂晓，雾江上一叶孤舟，渔夫收网。') })}
      ${mini({ x: 136, y: 12, title: '成片', type: '图像', box: pic(IMG.thumbMountain), selected: true })}
      ${mini({ x: 168, y: 72, title: '镜头 02', type: '视频配置', box: txt('江面雾气渐散，孤舟驶出画面。'), selected: true })}
      ${mini({ x: 282, y: 30, title: '远山参考', type: '图像', box: pic(IMG.thumbWide), selected: true })}
      <div style="position: absolute; left: 124px; top: 6px; width: 206px; height: 122px; box-sizing: border-box; border: 1px solid ${T.accent}; background: rgba(201,168,91,0.08); border-radius: 1px"></div>
      ${countChip(262, 116, '已选 3')}
    `)}
    ${rules([
      '左键拖空白 = 框选（现在是拖画布，要改）；平移走 H / 空格 / 右键拖 / 中键拖',
      '拖框：不按键替换；Shift 加选；Ctrl（mac 用 ⌘，因为 Ctrl+点在 mac 上是右键）反选',
      '点卡：Shift / Ctrl / ⌘ 都是切换选中（canvas_view 现状）；改不改见 Q7',
      '碰到框就算选中（Q1）；折叠泳道里的卡不参与；便签、文本照常可选',
      '移动不到 4px 算点空白 = 清空；贴边自动平移',
      'Esc 取消框选并恢复原选中。Esc 顺序：菜单 > @ 弹层 > 查找条 > 框选中 > 工具锁 > 清空选中',
      '泳道底色算空白，标题栏起拖仍是拖泳道；连线模式不起框',
      '需：选中控制器补 replace / addAll / toggleAll',
    ], 'margin-top: 10px')}
  </div>`;

// ---------- B 多选拖动（PL-5）----------
const colGroupDrag = `
  <div>
    ${h3('整组拖动', 'PL-5 · 换道沿用 resolveCardDrop')}
    ${stage(380, 140, `
      <div style="position: absolute; left: 0; right: 0; top: 0; height: 80px; box-sizing: border-box; border: 1px solid ${T.accent}; background: ${T.wash}"></div>
      ${laneTitle(8, 8, '水墨风格', '2 镜')}
      ${ghost(30, 66)}${ghost(150, 70)}
      ${mini({ x: 104, y: 24, title: '镜头 03', type: '视频配置', box: txt('回望远山的侧脸，镜头缓推。'), selected: true })}
      ${mini({ x: 224, y: 30, title: '镜头 04', type: '视频配置', box: txt('雾散，远山一层层浮出。'), selected: true })}
      <div style="position: absolute; right: 8px; top: 8px; height: 22px; display: flex; align-items: center; gap: 6px; padding: 0 8px; border-radius: 3px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 10px">${ic('lane', 13)}<span>移入「水墨风格」· 2 张改继承风格</span></div>
    `)}
    ${rules([
      '拖选中的任一张 = 整组走；拖没选中的卡 = 先单选再拖（同右键）',
      '换道沿用已上线的 resolveCardDrop：屏幕拖动 > 18px、中心这一趟跨过带边界、进新带 ≥ 12px，三条都满足才换',
      '整组只看抓住的那张卡判（Q2 已定 B），全组进同一条道；拖动中高亮目标道（cardDropTargetLane，与松手同一判定），卡组上方挂提示',
      '起拖阈值只分「点」和「拖」，不参与判泳道',
      '换了道弹撤销卡「已移入泳道「X」」，撤销 = 整组回原位、原道',
      'Shift = 只锁轴；Ctrl（⌘）= 原样放下：不吸附、不插进叙事线',
      '需：moveNodes 整组一个事务，失败整组回滚 + 错误卡；nodeDragDeltaProvider 改成带一组 id',
      '需：Ctrl Z 要画布撤销栈（见 UndoClipboard）',
    ], 'margin-top: 10px')}
  </div>`;

// ---------- C 浮动上下文工具条 ----------
const tbBtn = (icon, label, key = '', primary = false) => primary
  ? `<div style="height: 26px; padding: 0 9px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-weight: 500; display: flex; align-items: center; gap: 5px">${ic(icon, 14)}<span>${label}</span>${key ? `<span style="font-family: ${MONO}; font-size: 9px; opacity: .7">${key}</span>` : ''}</div>`
  : `<div style="height: 26px; padding: 0 7px; border-radius: 3px; color: ${T.fg3}; display: flex; align-items: center; gap: 5px">${icon ? ic(icon, 14) : ''}${label ? `<span>${label}</span>` : ''}${key ? kbd(key) : ''}</div>`;
const tbSep = `<div style="width: 1px; height: 16px; background: ${T.control}; margin: 0 2px"></div>`;
const tbBar = (inner) => `<div style="display: inline-flex; align-items: center; gap: 1px; padding: 3px; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 6px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); font-size: 11px">${inner}</div>`;
const tbRow = (label, bar) => `
  <div style="margin-bottom: 8px">
    <div style="font-size: 11px; color: ${T.fg5}; margin-bottom: 4px">${label}</div>${bar}
  </div>`;
const colToolbar = `
  <div>
    ${h3('选中后浮出的工具条', '跟着选区类型变')}
    <div style="padding: 12px 12px 2px; border-radius: 4px; background: ${T.s1}; outline: 1px solid ${T.bSubtle}">
      ${tbRow('单选 · 配置节点（生成在提示词条上，这里不重复）', tbBar(`
        ${tbBtn('lane', '加入泳道')}${caret()}${tbSep}${tbBtn('', '复制一份')}${tbBtn('sequence', '')}${tbSep}${tbBtn('more', '')}${tbBtn('trash', '')}`))}
      ${tbRow('单选 · 产物', tbBar(`
        ${tbBtn('characters', '存为角色')}${tbBtn('videoConfig', '当下一镜的首帧')}${tbBtn('sequence', '')}${tbSep}${tbBtn('more', '')}${tbBtn('trash', '')}`))}
      ${tbRow('多选', tbBar(`
        <div style="padding: 0 8px; font-family: ${MONO}; font-size: 10px; color: ${T.fg4}">4 个 · 约 $2.10</div>${tbSep}
        ${tbBtn('run', '生成 3 个', '', true)}${tbBtn('', '对齐')}${caret()}${tbBtn('lane', '包成泳道')}${tbSep}${tbBtn('more', '')}${tbBtn('trash', '')}`))}
    </div>
    ${rules([
      '有选中、且不在拖动 / 平移 / 缩放 / 连线中才出；手停 150ms 后淡入',
      '选区上方居中隔 8，顶到舞台顶部工具条就翻到下方；不进 Tab 序',
      '按钮取自动作表、与右键同源；⋯ = 这一选区的右键菜单',
      '「生成 N 个」只数配置节点（停用的不算），一个都没有就不出；不放颜色（节点无此字段）',
      '「生成 N 个」与多选 Ctrl ↵ 都打开 TakesCost 的运行对话框：确认、清单 + 总价、单次上限 50、按 data 边依赖排队、停用的列「跳过 · 已停用」，规则只在那张板',
      '需：设置 › 节点布局「选中时显示浮动工具条」默认开，AppPreferences 新字段',
    ], 'margin-top: 10px')}
  </div>`;

// ---------- D 多选检查器 ----------
const insRow = (label, value, multi = false) => `
  <div style="display: flex; align-items: center; gap: 8px; padding: 0 12px; margin-top: 6px">
    <div style="width: 34px; font-size: 11px; color: ${T.fg4}">${label}</div>
    <div style="flex: 1; height: 24px; border-radius: 3px; background: ${T.s2}; border: 1px solid ${multi ? T.controlStrong : T.outline}; display: flex; align-items: center; padding: 0 8px; gap: 6px; color: ${multi ? T.fg6 : T.fg2}; font-size: 11px"><div style="flex: 1">${value}</div>${caret()}</div>
  </div>`;
const insNode = (img, name, cost) => `
  <div style="height: 24px; display: flex; align-items: center; gap: 8px; padding: 0 12px; font-size: 11px">
    ${img ? `<img src="${img}" alt="" style="width: 28px; height: 16px; object-fit: cover; border-radius: 2px">` : `<div style="width: 28px; height: 16px; border-radius: 2px; background: ${T.thumb}; display: flex; align-items: center; justify-content: center; color: ${T.fg6}">${ic('videoConfig', 11)}</div>`}
    <div style="flex: 1; color: ${T.fg3}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${name}</div>
    <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}">${cost}</div>
  </div>`;
const inspectorMock = `
  <div style="position: relative; width: 236px; flex: none; height: 338px; background: ${T.s3}; border: 1px solid ${T.bStrong}; border-radius: 4px; overflow: hidden">
    <div style="padding: 10px 12px; border-bottom: 1px solid ${T.bSubtle}">
      <div style="display: flex; align-items: center; gap: 8px"><div style="font-weight: 500; color: ${T.fg1}">已选 3 个节点</div><div style="flex: 1"></div><div style="height: 18px; padding: 0 6px; border-radius: 9px; border: 1px solid ${T.outline}; color: ${T.fg4}; font-size: 10px; display: flex; align-items: center">视频配置 ×3</div></div>
      <div style="font-size: 11px; color: ${T.fg4}; margin-top: 4px">总预估 <span style="font-family: ${MONO}; color: ${T.fg2}">约 $2.10</span></div>
    </div>
    <div style="font-size: 10px; color: ${T.fg5}; padding: 8px 12px 0">共有参数 · 改一处写全部</div>
    ${insRow('模型', '万相 2.2 · 图生视频')}
    ${insRow('时长', '多个值', true)}
    ${insRow('画幅', '16:9')}
    ${insRow('种子', '多个值', true)}
    <div style="font-size: 10px; color: ${T.fg6}; padding: 8px 12px 0; line-height: 1.5">提示词、首尾帧、参考图、角色各自单独改</div>
    <div style="height: 1px; background: ${T.bSubtle}; margin: 8px 0 4px"></div>
    ${insNode(null, '镜头 02 · 江上孤舟', '$0.70')}
    ${insNode(null, '镜头 03 · 回望', '$0.70')}
    ${insNode(null, '镜头 04 · 远山', '$0.70')}
    <div style="position: absolute; left: 0; right: 0; bottom: 0; padding: 8px 12px; border-top: 1px solid ${T.bSubtle}; background: ${T.s3}">
      <div style="height: 26px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-weight: 500; display: flex; align-items: center; justify-content: center; gap: 6px; font-size: 11px">${ic('run', 13)}<span>生成 3 个 · 约 $2.10</span></div>
    </div>
  </div>`;
const colInspector = `
  <div>
    ${h3('多选检查器', '数量 + 总价 + 共有参数')}
    <div style="display: flex; gap: 14px; align-items: flex-start">
      ${inspectorMock}
      ${rules([
        '同类型配置节点（图像 / 视频 / 镜头）才列共有参数；混选只列数量、总价、清单',
        '值不一样写「多个值」；不碰不写，改一次写全部',
        '换成同一模型后按它的能力位重算其余字段，不支持的清掉并提示',
        '总价 = 各节点 estimateCostUsd 相加（USD，formatCostUsd）；算不出写「另 N 个价格未知」',
        '生成按钮同浮动条，走 TakesCost 运行对话框',
        '文本、便签、产物只计数',
        '需：typeConfig 批量 patch 一个事务',
        '需：generationTarget 改成收一组节点',
      ])}
    </div>
  </div>`;

// ---------- E 对齐 / 分布 / 排布 + 吸附 ----------
const seg = (label) => `<div style="height: 24px; padding: 0 8px; border-radius: 3px; background: ${T.s3}; border: 1px solid ${T.outline}; color: ${T.fg2}; font-size: 11px; display: flex; align-items: center">${label}</div>`;
const segLabel = (t, k = '') => `<div style="display: flex; align-items: center; margin: 6px 0 4px"><div style="flex: 1; font-size: 10px; color: ${T.fg5}">${t}</div>${k ? kbd(k) : ''}</div>`;
const alignPanel = menu(`
  <div style="padding: 2px 6px 6px">
    ${segLabel('对齐', 'Alt A D W S H V')}
    <div style="display: flex; gap: 4px; flex-wrap: wrap">${['左', '水平居中', '右', '顶', '垂直居中', '底'].map(seg).join('')}</div>
    ${segLabel('分布 · 至少 3 个', 'Alt Shift H V')}
    <div style="display: flex; gap: 4px">${['水平等距', '垂直等距'].map(seg).join('')}</div>
    ${segLabel('排布')}
    <div style="display: flex; gap: 4px">${['一行', '一列', '网格'].map(seg).join('')}</div>
  </div>
  <div style="height: 1px; background: ${T.bStrong}; margin: 2px 0 4px"></div>
  ${menuItem('sequence', '整理叙事链')}
`, 196);
const snapMock = stage(168, 196, `
  ${mini({ x: 12, y: 18, title: '镜头 01', type: '图像', box: pic(IMG.thumbMountain) })}
  ${mini({ x: 52, y: 112, title: '镜头 02', type: '视频配置', box: txt('孤舟驶出画面。'), selected: true })}
  <div style="position: absolute; left: 12px; top: 0; bottom: 0; width: 0; border-left: 1px solid ${T.accent}"></div>
  <div style="position: absolute; left: 116px; top: 0; bottom: 0; width: 0; border-left: 1px dashed ${T.accent}; opacity: .5"></div>
  <div style="position: absolute; left: 12px; top: 92px; width: 40px; height: 0; border-top: 1px solid ${T.accent}"></div>
  <div style="position: absolute; left: 20px; top: 94px; font-family: ${MONO}; font-size: 9px; color: ${T.accent}">左缘</div>
  <div style="position: absolute; left: 8px; bottom: 6px; font-size: 9px; color: ${T.fg5}">按住 Ctrl：不吸不插</div>
`, 'flex: none');
const colAlign = `
  <div>
    ${h3('对齐 · 分布 · 排布 · 吸附', '多选右键「对齐 ›」与浮动条同一块')}
    <div style="display: flex; gap: 12px; align-items: flex-start">${alignPanel}${snapMock}</div>
    ${rules([
      '对齐按选区包围盒，分布按卡片中心；一次操作 = 一次 moveNodes',
      '网格列数 ⌈√n⌉、间距 48，先叙事序再位置；整理叙事链 = 沿链一行，产物按 result_placement',
      '跨轴对齐不把卡挤出原道：夹在各自的带里',
      '网格吸附 24（同网格底、复制偏移）；对象吸附 6 屏幕像素内出参考线',
      '拖动中按住 Ctrl（⌘）= 原样放下：不吸、不插线。空格已是临时平移，Alt 已给切线',
      'Alt 字母对齐键保留：Windows 菜单栏只认单独按下再松开的 Alt，不做 Alt+字母助记键，不冲突',
      '需：吸附两个开关（空白处右键打勾 + 设置 › 节点布局），存 AppPreferences',
    ], 'margin-top: 10px')}
  </div>`;

// ---------- F Ctrl+G 包成泳道 + 折叠 ----------
const wrapMock = stage(336, 112, `
  <div style="position: absolute; left: 0; right: 0; top: 6px; height: 100px; border-top: 1px solid ${T.laneDivider}; border-bottom: 1px solid ${T.laneDivider}; background: rgba(124,184,232,0.035)"></div>
  <div style="position: absolute; left: 8px; top: 12px; height: 24px; display: flex; align-items: center; gap: 6px; padding: 0 4px 0 8px; border-radius: 3px; background: rgba(38,38,38,0.82); border: 1px solid ${T.outline}">
    <div style="width: 8px; height: 8px; border-radius: 2px; background: ${T.sky}"></div>
    <div style="width: 96px; height: 18px; border-radius: 2px; background: ${T.s2}; border: 1px solid ${T.accent}; display: flex; align-items: center; padding: 0 5px; font-size: 11px; color: ${T.fg1}">新泳道<span style="display: inline-block; width: 1px; height: 12px; background: ${T.accent}; margin-left: 1px"></span></div>
    <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">3</div>
  </div>
  ${mini({ x: 120, y: 30, title: '镜头 02', type: '视频配置', box: txt('孤舟驶出画面。'), selected: true })}
  ${mini({ x: 228, y: 34, title: '成片', type: '视频', box: pic(IMG.thumbWide), selected: true })}
  ${mini({ x: 12, y: 42, title: '镜头 03', type: '视频配置', box: txt('回望远山。'), selected: true })}
`);
const collapsedRail = `
  <div style="position: relative; width: 336px; height: 36px; margin-top: 8px; border-radius: 4px; background: rgba(232,168,124,0.035); outline: 1px solid ${T.laneDivider}; overflow: hidden">
    <div style="position: absolute; left: 8px; top: 6px; height: 24px; display: flex; align-items: center; gap: 6px; padding: 0 8px; border-radius: 3px; background: rgba(38,38,38,0.82); border: 1px solid ${T.outline}; font-size: 11px">
      <div style="width: 8px; height: 8px; border-radius: 2px; background: #E8A87C"></div>
      <div style="color: ${T.fg4}">水墨风格</div><div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">2</div><div style="font-size: 10px; color: ${T.fg6}">已折叠</div>
    </div>
    <div style="position: absolute; right: 8px; top: 9px; font-size: 10px; color: ${T.fg5}">双击标题栏展开</div>
  </div>`;
const undoCard = `
  <div style="display: flex; align-items: center; gap: 8px; margin-top: 8px; padding: 6px 8px; width: 336px; box-sizing: border-box; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; font-size: 11px">
    <div style="color: ${T.fg3}; display: flex">${ic('undo', 14)}</div><div style="flex: 1; color: ${T.fg2}">1 张从「水墨风格」换到新泳道，风格变了</div><div style="color: ${T.accent}">撤销</div>
  </div>`;
const colWrap = `
  <div>
    ${h3('包成泳道', 'Ctrl G · 折叠已有')}
    ${wrapMock}${collapsedRail}${undoCard}
    ${rules([
      'Ctrl G：建道、整批移入、标题进改名；相对位置不变，道厚 = 选区跨轴 + 48（≥400）',
      'F 照旧只开新建泳道对话框、不看选中；包住选中只走 Ctrl G。新道插在哪见 Q5',
      '有卡原在别的道 → 风格变了，弹撤销卡（8 秒）；建道 + 移入算一步撤销；Ctrl Shift G = 移出泳道',
      '折叠已实现（36px 轨、双击标题栏），记不记住见 Q6',
      '重排泳道时卡恒跟着走（卡锚在道起始边），不加「带不带内容」开关',
      '需：建道 + 定厚 + 排位 + 移节点一个事务；createLane 现在只追加、不收 size',
    ], 'margin-top: 10px')}
  </div>`;

// ---------- 需要你定 ----------
const q = (id, title, opts, rec) => `
  <div>
    <div style="color: ${T.fg1}; font-weight: 500">${id} ${title}</div>
    <div style="color: ${T.fg3}; margin-top: 2px">${opts}</div>
    <div style="color: ${T.accent}; margin-top: 2px">建议 ${rec}</div>
  </div>`;
const decide = `
  <div style="margin-top: 18px; padding: 12px 16px 14px; border-radius: 6px; background: ${T.wash}; border: 1px solid ${T.washBorder}">
    <div style="display: flex; align-items: baseline; gap: 12px; margin-bottom: 8px"><div style="font-weight: 500; color: ${T.fg1}">需要你定</div><div style="font-size: 11px; color: ${T.fg4}">已定：Q2 → B（整组看抓住的那张，沿用 resolveCardDrop）· Q4 → 并入 TakesCost 运行对话框（≥2 个就确认，单次上限 50）</div></div>
    <div style="display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 12px 20px; font-size: 11px; line-height: 1.55">
      ${q('Q1', '框选怎么算选中', 'A 碰到就算 · B 整张框进去才算 · C 看拖的方向（左→右整张，右→左碰到）', 'A，与 tldraw / Figma 一致；卡片大，整张框住太费劲')}
      ${q('Q3', '单选配置节点时出不出浮动条', 'A 出完整条（含生成）· B 出精简条（不含生成）· C 不出，只靠提示词条', 'B，提示词条与检查器已共用同一道生成闸（S1 已修），浮动条再放一个生成只是重复')}
      ${q('Q5', 'Ctrl G 的新泳道插在哪', 'A 泳道栈末尾 · B 选区所在那条道之后（不在道里就放末尾）', 'B，卡片挪得最少，相机不用跟着跳')}
      ${q('Q6', '泳道折叠要不要记住', 'A 不记（现状，重开全展开）· B 记在本机偏好 · C 落库 style_lanes 新列，随项目包走', 'C，折叠是排版的一部分；新增一条前向迁移')}
      ${q('Q7', '点卡的修饰键要不要改', 'A 保持现状：Shift / Ctrl / ⌘ 点卡都是切换 · B Shift 点卡只加选、Ctrl（mac ⌘）切换，与拖框对齐', 'A，与 Figma / tldraw 一致、零改动；拖框的加选 / 反选另算')}
    </div>
  </div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="padding: 26px 32px 0">
    <div style="display: flex; align-items: baseline; gap: 14px; margin-bottom: 14px">
      <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">选择与批量编辑</div>
      <div style="color: ${T.fg4}">一次选很多、一起挪、一起改、一起生成；换道和花钱之前先说清楚</div>
    </div>
    <div style="display: grid; grid-template-columns: 360px 380px minmax(0, 1fr); gap: 28px">
      ${colMarquee}
      ${colGroupDrag}
      ${colToolbar}
    </div>
    <div style="display: grid; grid-template-columns: 448px 376px minmax(0, 1fr); gap: 28px; margin-top: 18px">
      ${colInspector}
      ${colAlign}
      ${colWrap}
    </div>
    ${decide}
  </div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'Selection.dc.html', html: page('选择与批量编辑', W, H, body, logic) };
