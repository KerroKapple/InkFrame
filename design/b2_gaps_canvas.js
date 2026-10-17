// 第二批画板：画布补漏——新建下一镜 / 新建菜单补项 / 节点右键补项 / 「更多」下拉 / 便签字号 / 画布轻提示胶囊 / 分组与评论（1280×1400，静态）
const { T, IMG, SANS, MONO, page, ic } = require('./common.js');

const W = 1280, H = 1400;

// ---- 小件（与其他 b2 板同构，本地拷贝）----
const h3 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 8px; margin-bottom: 8px"><div style="font-weight: 500; color: ${T.fg1}">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const kbd = (k, c = T.fg5) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${c}; white-space: nowrap">${k}</span>`;
const mono = (t) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${t}</span>`;
// 规则行：以「需：」开头的是要补的底座
const rules = (list, extra = '') => `
  <div style="font-size: 11px; color: ${T.fg4}; line-height: 1.55; ${extra}">
    ${list.map((r) => r.startsWith('需：')
      ? `<div><span style="color: ${T.accent}">需</span>　${r.slice(2)}</div>`
      : `<div>· ${r}</div>`).join('')}
  </div>`;

// 菜单：20px 行（比右键实物紧一点，样稿用）
const tagNew = `<span style="height: 14px; padding: 0 4px; border-radius: 3px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 9px; display: inline-flex; align-items: center; margin-left: 6px">新</span>`;
const tagFrom = (b) => `<span style="font-size: 9px; color: ${T.fg6}; margin-left: 6px; white-space: nowrap">${b}</span>`;
const tagWarn = (t) => `<span style="height: 14px; padding: 0 4px; border-radius: 3px; border: 1px solid ${T.controlStrong}; color: ${T.fg5}; font-size: 9px; display: inline-flex; align-items: center; margin-left: 6px; white-space: nowrap">${t}</span>`;
const mi = (icon, label, { key = '', tag = '', hi = false, dis = false, danger = false, sub = false, check = false, thumb = '', meta = '' } = {}) => `
  <div style="height: 20px; display: flex; align-items: center; gap: 8px; padding: 0 8px; border-radius: 3px; ${hi ? `background: ${T.s5};` : ''} color: ${danger ? T.danger : dis ? T.fg6 : T.fg2}; font-size: 11px">
    ${thumb ? `<img src="${thumb}" alt="" style="width: 16px; height: 16px; object-fit: cover; border-radius: 3px; flex: none">`
      : icon ? `<div style="color: ${dis ? T.fg6 : T.fg4}; display: flex">${ic(icon, 15)}</div>` : '<div style="width: 15px; flex: none"></div>'}
    <div style="flex: 1; min-width: 0; display: flex; align-items: center; white-space: nowrap; overflow: hidden">${label}${tag}</div>
    ${meta ? `<span style="font-size: 10px; color: ${T.fg5}; white-space: nowrap">${meta}</span>` : ''}
    ${check ? `<div style="color: ${T.accent}; display: flex">${ic('success', 13)}</div>` : ''}
    ${key ? kbd(key) : ''}${sub ? `<span style="color: ${T.fg5}; font-size: 11px">›</span>` : ''}
  </div>`;
const sep = `<div style="height: 1px; background: ${T.bStrong}; margin: 3px 0"></div>`;
const grpHead = (t) => `<div style="height: 15px; padding: 0 8px; font-size: 10px; color: ${T.fg5}; display: flex; align-items: center">${t}</div>`;
const search = (t, typed = false) => `<div style="height: 24px; margin-bottom: 2px; display: flex; align-items: center; gap: 6px; padding: 0 8px; border-bottom: 1px solid ${T.bStrong}; color: ${typed ? T.fg1 : T.fg6}; font-size: 11px">${ic('search', 13)}<span>${t}</span>${typed ? `<span style="display: inline-block; width: 1px; height: 12px; background: ${T.fg1}; margin-left: -4px"></span>` : ''}</div>`;
const menu = (inner, width) => `<div style="width: ${width}px; flex: none; box-sizing: border-box; padding: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6)">${inner}</div>`;

// 画布小片
const stage = (w, h, inner, extra = '') => `<div style="position: relative; width: ${w}px; height: ${h}px; flex: none; border-radius: 4px; overflow: hidden; background-color: ${T.s1}; background-image: linear-gradient(${T.grid} 1px, transparent 1px), linear-gradient(90deg, ${T.grid} 1px, transparent 1px); background-size: 19.2px 19.2px; outline: 1px solid ${T.bSubtle}; ${extra}">${inner}</div>`;
const MW = 80, MB = 45;
const mini = ({ x, y, title, type, box, sel = false, ghost = false }) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${MW}px">
    <div style="height: 14px; display: flex; align-items: center; gap: 4px; font-size: 9px">
      <div style="font-weight: 500; color: ${sel || ghost ? T.fg1 : T.fg3}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</div><div style="flex: 1"></div><div style="color: ${T.fg6}; white-space: nowrap">${type}</div>
    </div>
    <div style="position: relative; width: ${MW}px; height: ${MB}px; box-sizing: border-box; border-radius: 3px; background: ${ghost ? T.wash : T.thumb}; ${ghost ? `border: 1px dashed ${T.accent}` : `outline: ${sel ? `1.5px solid ${T.accent}` : `1px solid ${T.outline}`}`}; overflow: hidden">${box}</div>
  </div>`;
const txt = (s, c = T.fg3) => `<div style="padding: 4px 5px; font-size: 8px; line-height: 1.45; color: ${c}; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden">${s}</div>`;
const pic = (src) => `<img src="${src}" alt="" style="width: 100%; height: 100%; object-fit: cover; display: block">`;
const laneBand = (top, h, tint = 'rgba(232,168,124,0.035)') => `<div style="position: absolute; left: 0; right: 0; top: ${top}px; height: ${h}px; border-top: 1px solid ${T.laneDivider}; border-bottom: 1px solid ${T.laneDivider}; background: ${tint}"></div>`;
const laneTitle = (x, y, label, tint = '#E8A87C') => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; height: 18px; display: flex; align-items: center; gap: 5px; padding: 0 6px; border-radius: 3px; background: rgba(38,38,38,0.82); border: 1px solid ${T.outline}; font-size: 9px">
    <div style="width: 7px; height: 7px; border-radius: 2px; background: ${tint}"></div><div style="font-weight: 500; color: ${T.fg2}">${label}</div>
  </div>`;
const keyChip = (x, y, k) => `<div style="position: absolute; left: ${x}px; top: ${y}px; height: 18px; padding: 0 6px; border-radius: 3px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; font-family: ${MONO}; font-size: 10px; color: ${T.fg2}; display: flex; align-items: center">${k}</div>`;
const svgLayer = (w, h, inner) => `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" aria-hidden="true" style="position: absolute; left: 0; top: 0">${inner}</svg>`;
const arrowHead = (x, y, c) => `<path d="M${x - 5} ${y - 3.5}L${x} ${y}L${x - 5} ${y + 3.5}" fill="none" stroke="${c}" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"></path>`;

// 画布底部轻提示胶囊（与 UndoClipboard 板同一个样子）
const capsule = (icon, text, right = '', extra = '') => `
  <div style="display: inline-flex; align-items: center; gap: 8px; height: 28px; padding: 0 12px; border-radius: 999px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; box-shadow: 0 8px 24px rgba(0,0,0,0.45); color: ${T.fg2}; font-size: 11px; box-sizing: border-box; ${extra}">
    ${icon ? `<div style="color: ${T.fg3}; display: flex">${ic(icon, 14)}</div>` : ''}<span style="white-space: nowrap">${text}</span>${right ? `<span style="width: 1px; height: 12px; background: ${T.control}"></span>${right}` : ''}
  </div>`;

// ============ A 新建下一镜 ============
// A1：Ctrl → —— 锚点 02 + 它的 take 那一列，新镜落在产物列后面
const PY = 14 + MB / 2;
const stageNext = stage(300, 136, `
  ${laneBand(6, 124)}
  ${laneTitle(8, 12, '水墨风格')}
  ${svgLayer(300, 136, `
    <path d="M${8 + MW} ${40 + PY}C${8 + MW + 12} ${40 + PY} ${100 - 12} ${40 + PY} 100 ${40 + PY}" fill="none" stroke="${T.fg6}" stroke-width="1.25" stroke-dasharray="1.5 3.5" stroke-linecap="round"></path>
    <path d="M${8 + MW} ${40 + PY}C${8 + MW + 30} ${40 + PY + 52} ${206 - 40} ${40 + PY + 52} 206 ${40 + PY}" fill="none" stroke="${T.fg4}" stroke-width="2"></path>
    ${arrowHead(206, 40 + PY, T.fg4)}
  `)}
  ${mini({ x: 8, y: 40, title: '镜头 02', type: '视频配置', box: txt('江面雾气渐散，孤舟驶出画面。'), sel: false })}
  ${mini({ x: 100, y: 40, title: '成片', type: '视频', box: pic(IMG.thumbWide) })}
  ${mini({ x: 208, y: 40, title: '镜头 03', type: '视频配置', box: txt('（提示词留空）', T.fg5), ghost: true })}
  <div style="position: absolute; left: 132px; top: 110px; font-size: 9px; color: ${T.fg4}">叙事</div>
  ${keyChip(232, 12, 'Ctrl →')}
  <div style="position: absolute; left: 208px; top: 104px; width: 88px; font-size: 9px; line-height: 1.4; color: ${T.accent}">万相 i2v · 5 秒 · 720p · 推镜</div>
`);
// A2：从出端口拖线 —— 源是配置节点时「下一镜」排第一并高亮
const stageDrag = stage(300, 136, `
  ${svgLayer(300, 136, `
    <path d="M${8 + MW + 4} ${36 + PY}C${8 + MW + 24} ${36 + PY} 112 34 126 34" fill="none" stroke="${T.accent}" stroke-width="1.75" stroke-dasharray="4 3"></path>
  `)}
  ${mini({ x: 8, y: 36, title: '镜头 01', type: '图像配置', box: txt('拂晓，雾江上一叶孤舟，渔夫收网。'), sel: true })}
  <div style="position: absolute; left: ${8 + MW}px; top: ${36 + PY - 4}px; width: 8px; height: 8px; border-radius: 4px; background: ${T.accent}"></div>
  <div style="position: absolute; left: 128px; top: 10px">${menu(`
    ${search('直接打字搜索…')}
    ${mi('', '下一镜（叙事）', { key: '↵', hi: true })}
    ${sep}
    ${mi('videoConfig', '当首帧 · 新建视频配置')}
    ${mi('videoConfig', '当尾帧 · 新建视频配置')}
    ${mi('imageConfig', '当参考 · 新建图像配置')}
  `, 166)}</div>
`);
const chipRow = (label, items, on) => `
  <div style="display: flex; flex-wrap: wrap; gap: 3px 4px; align-items: center; margin-top: 5px">
    <div style="width: 42px; font-size: 10px; color: ${on ? T.accent : T.fg5}">${label}</div>
    ${items.map((t) => `<span style="height: 16px; padding: 0 5px; border-radius: 3px; font-size: 10px; display: inline-flex; align-items: center; white-space: nowrap; ${on ? `background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.fg2}` : `border: 1px solid ${T.outline}; color: ${T.fg5}`}">${t}</span>`).join('')}
  </div>`;
const secA = `
  <div>
    ${h3('新建下一镜', 'Ctrl → · ⌘→ · 拖线菜单「下一镜」· 节点右键，三个入口一条路')}
    <div style="display: flex; gap: 24px">
      <div style="width: 612px; flex: none">
        <div style="display: flex; gap: 12px">${stageNext}${stageDrag}</div>
        ${chipRow('继承', ['泳道', '模型', '画幅', '分辨率', '时长', '运镜', '景别', '机位角度', '运镜幅度', '焦段', '不跟泳道风格', '角色 N1', '负面提示词 N1'], true)}
        ${chipRow('不继承', ['提示词', '种子', '张数（回到 1）', '生成模式（按入边推断）', '首尾帧 / 参考连线', '当前 take', '生成快照', '停用', '镜头备注', '名称'], false)}
      </div>
      ${rules([
        `锚点 = 恰好选中的那一张：镜头 / 图像配置 / 视频配置；选中的是产物就用它的来源配置（${mono('narrativeAnchorOf')}）；文本、便签不响应`,
        `建同类型配置节点 + 锚点 → 新节点的叙事边，sortOrder 走 ${mono('nextNarrativeSortOrder')}；节点和边一个事务，撤销一步「新建下一镜」`,
        `落点沿泳道主轴：越过锚点和它名下产物那一列，再空 64（${mono('kResultColumnGap')}）；被占就沿主轴再往后挪一格（不换横截位置，不出锚点的泳道）`,
        '竖向泳道也按 Ctrl →，方向随主轴；Ctrl ← ↑ ↓ 不分配；在文字里 Ctrl → 归光标',
        '新节点单选；跑出视口才平移，缩放不变；焦点留在画布，可连按；↵ = 光标进提示词条（新键），Esc 回画布',
        `继承就是从锚点 type_config 拷这些键：${mono('provider_id aspect_ratio resolution duration_ms camera shot_size camera_angle camera_motion_strength focal_length_mm ignore_lane_style')}`,
        '需：createNextShot 一个函数给三个入口；现有菜单「下一镜」只建空节点，改成同样继承',
      ], 'flex: 1; min-width: 0')}
    </div>
  </div>`;

// ============ C 新建菜单补项 ============
const createMenu = menu(`
  ${search('直接打字搜索…')}
  ${mi('imageConfig', '图像配置', { key: 'I', hi: true })}
  ${mi('videoConfig', '视频配置', { key: 'G' })}
  ${mi('text', '文本', { key: 'T' })}
  ${mi('note', '便签', { key: 'N', tag: tagNew })}
  ${mi('shot', '镜头')}
  ${mi('lane', '泳道', { key: 'F' })}
  ${sep}${grpHead('最近用过')}
  ${mi('videoConfig', '万相 图生视频', { meta: '5 秒 · 720p' })}
  ${mi('imageConfig', 'Gemini 图像', { meta: '16:9', tag: tagWarn('无 Key') })}
  ${sep}${grpHead('角色 · 建图像配置并挂上')}
  ${mi('', '老渔夫', { thumb: IMG.thumbMountain, meta: '3 张参考图' })}
  ${mi('', '孤舟', { thumb: IMG.thumbWide, meta: '1 张参考图' })}
`, 232);
const createTyped = menu(`
  ${search('万相', true)}
  ${grpHead('模型 · 打字时才出')}
  ${mi('imageConfig', '图像配置 · 万相 图像')}
  ${mi('videoConfig', '视频配置 · 万相 图生视频', { hi: true })}
`, 232);
const secC = `
  <div>
    ${h3('新建菜单补项', '双击空白 / Tab / 右键「新建…」，不带连线上下文时')}
    <div style="display: flex; gap: 14px; align-items: flex-start">
      ${createMenu}
      <div style="flex: 1; min-width: 0">
        ${createTyped}
        ${rules([
          '建节点组加便签、统一叫「镜头」；带连线上下文的菜单不加新组',
          '最近用过：本项目 jobs 里最近 3 种 provider_id + 参数（不含提示词、种子），去重；点了建节点写这些参数；没 Key 照建',
          '模型组只在打字时出，按 Provider 名和 id 匹配；角色组列最近改过的 3 个，点了见 N4',
          `需：与左栏节点库共用 recentPresetsProvider；${mono('CreateMenuAction')} 改成带载荷的 CreateMenuPick`,
        ], 'margin-top: 10px')}
      </div>
    </div>
  </div>`;

// ============ D 节点右键补项 ============
const nodeMenu = menu(`
  ${mi('run', '生成', { key: 'Ctrl ↵' })}
  ${mi('shot', '新建下一镜', { key: 'Ctrl →', tag: tagNew })}
  ${mi('', '复制一份', { key: 'Ctrl D' })}
  ${sep}
  ${mi('pin', '设为当前', { tag: tagFrom('TakesCost'), dis: true })}
  ${mi('videoConfig', '当下一镜的首帧', { tag: tagFrom('TakesCost'), sub: true, dis: true })}
  ${sep}
  ${mi('characters', '存为角色', { dis: true })}
  ${mi('lane', '加入泳道', { sub: true })}
  ${mi('sequence', '加入叙事链末尾', { tag: tagNew, hi: true })}
  ${sep}
  ${mi('sequence', '在序列中定位', { dis: true })}
  ${mi('assets', '在画廊中定位', { tag: tagNew })}
  ${sep}
  ${mi('', '停用', { tag: tagFrom('ContextMenus') })}
  ${mi('trash', '删除', { key: 'Del', danger: true })}
`, 262);
const secD = `
  <div>
    ${h3('节点右键补项', '右键一张不在链上的图像配置')}
    <div style="display: flex; gap: 14px; align-items: flex-start">
      ${nodeMenu}
      ${rules([
        '分组：做 | take | 归类 | 定位 | 停用 · 删除；不可用的置灰不隐藏，悬停说原因',
        `加入叙事链末尾：目标里不在链上的镜头 / 图像 / 视频配置（产物取来源配置）；末尾 = ${mono('orderByNarrativeChain')} 只留链上节点后的最后一个`,
        '多选按位置（先主轴再横截轴）依次接上：末尾 → a → b；一个事务、撤销一步；不挪位置（N5）',
        '画布还没有链：单选置灰「还没有叙事链」，多选就按位置连成一条新链；胶囊「已接到第 7 镜之后」',
        `在画廊中定位：产物 = 它自己，配置节点 = 当前 take（${mono('currentResultFor')}）；没产物置灰`,
        '切到画廊标签，单选那一格并滚到它；被筛选挡住就清掉筛选，筛选条上说「已清除筛选」',
      ], 'flex: 1; min-width: 0')}
    </div>
  </div>`;

// ============ E 「更多」下拉 ============
const moreMenu = menu(`
  ${mi('script', '导入剧本…')}
  ${mi('upload', '导入媒体…', { key: 'Ctrl U' })}
  ${sep}
  ${mi('sequence', '整理叙事链')}
  ${mi('run', '运行叙事链…')}
  ${sep}
  ${mi('templates', '从模板插入…')}
  ${sep}
  ${mi('link', '切线', { key: 'Alt 拖' })}
  ${sep}
  ${mi('search', '查找', { key: 'Ctrl F' })}
  ${mi('minimap', '小地图', { key: 'M', check: true })}
`, 220);
const secE = `
  <div>
    ${h3('「更多」下拉', '工具条最右，一份清单')}
    <div style="display: flex; gap: 14px; align-items: flex-start">
      ${moreMenu}
      ${rules([
        '顺序固定：导入 | 叙事链 | 模板 | 切线 | 视图；每项也进 ⌘K 动作表和菜单栏',
        '改用画布菜单组件 CanvasMenuPanel（键位、置灰说原因、↑↓ ↵ Esc，与右键同一套），不再用 Material showMenu',
        '「导入脚本」改叫「导入剧本」，与左栏「剧本」页同名，相关 ARB 一起改',
        '整理叙事链见 Selection，运行叙事链开 TakesCost 的运行对话框，从模板插入见 RailScript；画布没有链时前两项置灰',
        '切线：点了进一次性切线模式（剪刀光标，拖过的线高亮，松手剪掉，Esc 退出）；平时 Alt 拖空白同效（W3）',
      ], 'flex: 1; min-width: 0')}
    </div>
  </div>`;

// ============ F 便签字号 · 标题 ============
const stageNote = stage(296, 200, `
  <div style="position: absolute; left: 12px; top: 12px; font-size: 9px; color: ${T.fg5}">100%</div>
  <div style="position: absolute; left: 12px; top: 28px; width: 116px; height: 70px; box-sizing: border-box; padding: 6px 8px; border-radius: 3px; background: ${T.wash}; border: 1px solid ${T.washBorder}; box-shadow: 0 6px 14px rgba(0,0,0,0.35); font-size: 11px; line-height: 1.55; color: ${T.fg1}">第二场改成黄昏？问导演</div>
  <div style="position: absolute; left: 12px; top: 102px; font-size: 9px; color: ${T.fg5}">正文 · 12</div>
  <div style="position: absolute; left: 144px; top: 34px; font-size: 18px; font-weight: 500; line-height: 1.3; color: ${T.fg1}; white-space: nowrap">第一场 · 拂晓出港</div>
  <div style="position: absolute; left: 144px; top: 60px; width: 140px; height: 1px; background: ${T.accent}; opacity: .5"></div>
  <div style="position: absolute; left: 144px; top: 66px; font-size: 9px; color: ${T.fg5}">标题 · 20 / 500 · 无底色</div>
  <div style="position: absolute; left: 0; right: 0; top: 122px; height: 1px; background: ${T.bSubtle}"></div>
  <div style="position: absolute; left: 12px; top: 130px; font-size: 9px; color: ${T.fg5}">缩到 40%</div>
  <div style="position: absolute; left: 12px; top: 148px; font-size: 12px; font-weight: 500; color: ${T.fg1}; white-space: nowrap">第一场 · 拂晓出港</div>
  <div style="position: absolute; left: 12px; top: 170px; width: 22px; height: 18px; border-radius: 2px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; display: flex; align-items: center; justify-content: center">${ic('note', 12)}</div>
  <div style="position: absolute; left: 42px; top: 172px; width: 34px; height: 14px; border-radius: 2px; background: ${T.s4}"></div>
  <div style="position: absolute; left: 82px; top: 172px; width: 34px; height: 14px; border-radius: 2px; background: ${T.s4}"></div>
  <div style="position: absolute; left: 132px; top: 170px; width: 156px; font-size: 9px; line-height: 1.45; color: ${T.fg5}">标题照样能读；正文便签收成图标</div>
`);
const secF = `
  <div>
    ${h3('便签字号 · 标题', '便签 = 文本节点 variant=note（ImportSearch Q5）')}
    <div style="display: flex; gap: 14px; align-items: flex-start">
      ${stageNote}
      ${rules([
        `两档（N6）：正文 12 / 1.55，标题 20 / 500；存 ${mono('type_config.note_style')} = body | heading，JSONB 不迁移`,
        '标题便签无底色无边框，宽度跟字走，最宽 480 换行；三种底色只给正文便签',
        '缩放 &lt; 0.6 时正文便签收成图标（同卡片），标题不收，屏幕字号不小于 12：缩远了当章节路标',
        '需：字号进 InkTypography（noteBody / noteHeading），检查器正文框上方加「正文 | 标题」切换',
        '标题便签不进大纲、不进提示词，查找能搜到',
      ], 'flex: 1; min-width: 0')}
    </div>
  </div>`;

// ============ G 画布轻提示胶囊 ============
const stageCapsule = stage(340, 180, `
  <div style="position: absolute; left: 50%; top: 8px; transform: translateX(-50%); width: 150px; height: 20px; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.control}; display: flex; align-items: center; justify-content: center; font-size: 9px; color: ${T.fg5}">工具条</div>
  <div style="position: absolute; left: 50%; top: 34px; transform: translateX(-50%); width: 180px; height: 20px; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; display: flex; align-items: center; gap: 4px; padding: 0 6px; box-sizing: border-box; font-size: 9px; color: ${T.fg4}">${ic('search', 11)}<span>查找条（顶部，不避让）</span></div>
  <div style="position: absolute; left: 8px; bottom: 8px; width: 74px; height: 18px; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.control}; font-size: 9px; color: ${T.fg5}; display: flex; align-items: center; justify-content: center">缩放条</div>
  <div style="position: absolute; left: 8px; bottom: 30px; width: 74px; height: 32px; border-radius: 4px; background: ${T.s3}; border: 1px solid ${T.control}; font-size: 9px; color: ${T.fg6}; display: flex; align-items: center; justify-content: center">小地图</div>
  <div style="position: absolute; left: 90px; right: 90px; bottom: 34px; height: 0; border-top: 1px dashed ${T.fg6}"></div>
  <div style="position: absolute; left: 50%; bottom: 8px; transform: translateX(-50%); width: 160px; height: 34px; border-radius: 6px; background: ${T.s3}; border: 1px solid ${T.control}; font-size: 9px; color: ${T.fg5}; display: flex; align-items: center; justify-content: center">提示词条</div>
  <div style="position: absolute; left: 50%; bottom: 50px; transform: translateX(-50%)">${capsule('', '已复制 2 个节点', '', 'height: 24px; padding: 0 10px; font-size: 10px')}</div>
  <div style="position: absolute; left: 252px; bottom: 42px; font-family: ${MONO}; font-size: 9px; color: ${T.accent}">↕ 8</div>
  <div style="position: absolute; left: 92px; bottom: 82px; font-size: 9px; color: ${T.fg6}">不越过这两条竖线：两侧各让出缩放条 + 16</div>
  <div style="position: absolute; left: 90px; top: 62px; bottom: 0; width: 0; border-left: 1px dashed ${T.fg6}"></div>
  <div style="position: absolute; right: 90px; top: 62px; bottom: 0; width: 0; border-left: 1px dashed ${T.fg6}"></div>
`);
const variants = `
  <div style="display: flex; flex-direction: column; align-items: flex-start; gap: 8px; width: 214px; flex: none">
    <div style="font-size: 10px; color: ${T.fg5}">几种内容（同一个组件）</div>
    ${capsule('undo', '已撤销 · 移动 3 个节点', kbd('重做 Ctrl Y', T.fg4))}
    ${capsule('', '缩放 80%')}
    ${capsule('sequence', '已新开分叉 · 在 02 之后')}
    ${capsule('sequence', '已接到第 7 镜之后')}
  </div>`;
const secG = `
  <div>
    ${h3('画布轻提示胶囊', '「我刚做了什么」，只在本画布，不进铃铛')}
    <div style="display: flex; gap: 20px; align-items: flex-start">
      ${stageCapsule}${variants}
      ${rules([
        '需：theme 层 InkCanvasCapsule（纯展示）+ CanvasCapsuleHost + canvasCapsuleProvider(canvasId)；高 28、全圆角、s4 底、overlayBorder 描边',
        `位置：舞台水平居中；提示词条显示时底边 = 条高（${mono('canvasPromptBarHeight')}）+ 8，收起时离舞台底 16；两侧让出缩放条 + 16，超出省略号；查找条在顶部，互不避让`,
        '最多 1 条：新的立刻顶掉旧的（交叉淡入 120ms）；同 dedupeKey（如缩放）原地改字、重新计时',
        '停留：纯文字 2 秒、带动作 4 秒、缩放 1.2 秒（最后一次变化后）；悬停停表；不跟通知的停留设置',
        '缩放比例只在键盘缩放和「适应」时出，滚轮捏合不出（缩放条一直在显示）',
        '不用于错误（通知卡）和删除撤销（8 秒撤销卡）；不出声，读屏 polite 播一次；换标签、关画布即收；不进 Esc 链和 Tab 序',
      ], 'flex: 1; min-width: 0')}
    </div>
  </div>`;

// ============ 需要你定 ============
const q = (id, title, opts, rec) => `
  <div>
    <div style="color: ${T.fg1}; font-weight: 500">${id} ${title}</div>
    <div style="color: ${T.fg3}; margin-top: 2px">${opts}</div>
    <div style="color: ${T.accent}; margin-top: 2px">建议 ${rec}</div>
  </div>`;
const memo = `
  <div style="padding: 8px 10px; border-radius: 4px; border: 1px dashed ${T.washBorder}">
    <div style="color: ${T.fg1}; font-weight: 500">评论 · P2，先不做（备忘）</div>
    <div style="color: ${T.fg3}; margin-top: 2px">单机单人，意见先写便签。真做要：node_comments 表 + 新增一条前向迁移、项目包白名单与 import_remapper、卡片角标、检查器页签；C 键先空着</div>
  </div>`;
const decide = `
  <div style="padding: 12px 16px 14px; border-radius: 6px; background: ${T.wash}; border: 1px solid ${T.washBorder}">
    <div style="font-weight: 500; color: ${T.fg1}; margin-bottom: 8px">需要你定</div>
    <div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px 22px; font-size: 11px; line-height: 1.5">
      ${q('N1', '下一镜继承角色和负面提示词吗', 'A 都继承 · B 都不继承 · C 只继承角色', 'A：两样都是设定，不是这一镜的内容；删掉比重挂省事')}
      ${q('N2', '「从卡片边缘拖出」用哪个手势', 'A 复用出端口拖线，松手菜单「下一镜」置顶高亮 · B 卡片右缘另加「+」把手：点 = Ctrl →，拖 = 放在松手处不弹菜单', 'A：不加新把手，不和端口抢命中区')}
      ${q('N3', '锚点已有下一镜时 Ctrl → 怎么办', 'A 新开分叉，排在已有分叉后 + 胶囊提示 · B 插到本镜和下一镜之间 · C 只选中已有的下一镜，链尾才新建', 'A：与菜单「下一镜」同一条规则；插入走 ContextMenus 的拖到线上')}
      ${q('N4', '新建菜单「角色」组点了建什么', 'A 图像配置 + 挂上该角色 · B 视频配置 + 挂上 · C 不建节点，只挂到当前选中', 'A：先出图再当首帧，是角色最常走的路')}
      ${q('N5', '加入叙事链末尾要不要挪位置', 'A 不挪，只连线 · B 挪到链尾那一镜后面（同 Ctrl → 落点）', 'A：位置决定泳道，一挪可能换道换风格；要整齐用「整理叙事链」')}
      ${q('N6', '便签字号几档', 'A 两档：正文 12 / 标题 20 · B 三档：小 / 中 / 大 · C 自由字号', 'A：标题就是拿来当章节的，多一档就要多一套缩放规则')}
      ${q('N7', '泳道和不注入风格的纯分组（调研 Q11）', 'A 合成一种，风格留空即分组 · B 另加自由分组框 · C 不做分组，只用标题便签', 'A：现在就能用，Ctrl G 也只有一个去处；真要框住任意几张再做 B')}
      ${memo}
    </div>
  </div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="padding: 20px 32px 0">
    <div style="display: flex; align-items: baseline; gap: 14px; margin-bottom: 14px">
      <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">画布补漏</div>
      <div style="color: ${T.fg4}">审查列出的画布侧缺口：一镜接一镜、新建和右键还缺的项、「更多」收拢、便签标题、底部轻提示</div>
    </div>
    ${secA}
    <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 24px; margin-top: 12px">
      ${secC}
      ${secD}
    </div>
    <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 24px; margin-top: 12px">
      ${secE}
      ${secF}
    </div>
    <div style="margin-top: 12px">${secG}</div>
    <div style="margin-top: 14px">${decide}</div>
  </div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'GapsCanvas.dc.html', html: page('画布补漏', W, H, body, logic) };
