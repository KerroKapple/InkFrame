// 第二批画板：左栏第二批——剧本 · 节点库 · 模板 · 帮助（1280×H，静态）
// 与 interactions.js 同一套语汇：menu / menuItem / kbd / h3 本地复制；面板件照 main.js 的 panelHeader / filter / groupHead。
const { T, IMG, SANS, MONO, page, ic, caret } = require('./common.js');

const W = 1280, H = 1340;
const PANEL_H = 396;
const COL = 293;

// ---- 共用小件（从 interactions.js / main.js 复制）----
const h3 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 8px; margin-bottom: 10px; height: 18px"><div style="font-weight: 500; color: ${T.fg1}">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const kbd = (k) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}">${k}</span>`;
const prio = (p) => `<span style="height: 16px; padding: 0 5px; border-radius: 3px; border: 1px solid ${p === 'P1' ? T.washBorder : T.control}; color: ${p === 'P1' ? T.accent : T.fg4}; font-family: ${MONO}; font-size: 10px; display: inline-flex; align-items: center">${p}</span>`;
const menuItem = (icon, label, key = '', extra = '') => `
  <div style="height: 28px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border-radius: 3px; color: ${T.fg2}; ${extra}">
    ${icon ? `<div style="color: ${T.fg4}; display: flex">${ic(icon, 16)}</div>` : '<div style="width: 16px"></div>'}
    <div style="flex: 1; white-space: nowrap">${label}</div>${key ? kbd(key) : ''}
  </div>`;
const menuSep = `<div style="height: 1px; background: ${T.bStrong}; margin: 4px 0"></div>`;
const menu = (inner, width = 240) => `<div style="width: ${width}px; box-sizing: border-box; padding: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6)">${inner}</div>`;
const panelHeader = (title, right = '') => `
  <div style="height: 36px; display: flex; align-items: center; padding: 0 12px; gap: 8px; border-bottom: 1px solid ${T.bSubtle}">
    <div style="font-weight: 500; color: ${T.fg1}">${title}</div>
    <div style="flex: 1"></div>${right}
  </div>`;
const filter = (hint) => `
  <div style="margin: 10px 12px 6px; height: 24px; border-radius: 3px; background: ${T.s2}; border: 1px solid ${T.outline}; display: flex; align-items: center; gap: 6px; padding: 0 8px; color: ${T.fg6}">${ic('search', 13)}<span style="font-size: 11px">${hint}</span></div>`;
const groupHead = (label, count = '') => `
  <div style="height: 24px; display: flex; align-items: center; gap: 6px; padding: 0 12px; margin-top: 4px; color: ${T.fg5}; font-size: 11px"><span>${label}</span><span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">${count}</span></div>`;
const panelFrame = (inner) => `<div style="position: relative; width: 241px; height: ${PANEL_H}px; box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.bStrong}; overflow: hidden">${inner}</div>`;
const rules = (lines) => `<div style="margin-top: 12px; font-size: 11px; color: ${T.fg4}; line-height: 1.6">${lines.map((l) => `<div style="display: flex; gap: 5px; margin-bottom: 3px"><span style="color: ${T.fg6}">·</span><span>${l}</span></div>`).join('')}</div>`;
const code = (t) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${t}</span>`;
const need = (t) => `<span style="color: ${T.accent}">${t}</span>`;

// ---- 导航条（第二批之后的完整键位，横排示意；实物仍是 43 宽竖条）----
const railKey = (id, active, dashed = false) => `<div style="width: 32px; height: 32px; box-sizing: border-box; border-radius: 4px; display: flex; align-items: center; justify-content: center; ${active ? `background: ${T.wash}; color: ${T.accent}` : `color: ${T.fg4}`}; ${dashed ? `border: 1px dashed ${T.control}` : ''}">${ic(id, 20)}</div>`;
const railItem = (id, label, tag = '', dashed = false, active = false) => `<div style="display: flex; align-items: center; gap: 6px; height: 32px; padding: 0 8px 0 0">${railKey(id, active, dashed)}<span style="color: ${T.fg2}; white-space: nowrap">${label}</span>${tag}</div>`;
const railStrip = `
  <div style="display: flex; align-items: center; gap: 4px; height: 32px">
    <div style="font-size: 11px; color: ${T.fg5}; width: 52px">导航条</div>
    ${railItem('outline', '大纲')}${railItem('assets', '素材')}${railItem('characters', '角色')}
    ${railItem('script', '剧本', prio('P1'), false, true)}${railItem('templates', '模板', prio('P2') + `<span style="font-size: 10px; color: ${T.fg6}">顶部含节点库（R7）</span>`)}
    <div style="width: 1px; height: 20px; background: ${T.control}; margin: 0 10px"></div>
    <div style="font-size: 11px; color: ${T.fg5}; margin-right: 4px">底部</div>
    ${railItem('shortcuts', '快捷键')}${railItem('help', '帮助', `<span style="font-size: 10px; color: ${T.fg6}">菜单</span>`)}${railItem('panelToggle', '收起', kbd('Ctrl \\'))}
  </div>
  <div style="font-size: 11px; color: ${T.fg4}; margin-top: 4px; padding-left: 56px">${code('LeftRailPage')} 加 script / templates，声明序 = 从上到下；节点库照 R7 建议 B 并进模板页顶部、不加键（R7 改选 A 才加 nodeLibrary）；没做完的页不画键；点当前页收起、Ctrl \\ 开合、记住停在哪页都不变；帮助是动作键，不点亮、不开面板</div>`;

// ---- 剧本 ----
const numChip = (t, kind) => {
  const st = {
    done: `background: ${T.s5}; color: ${T.success}`,
    live: `background: ${T.wash}; color: ${T.accent}`,
    todo: `border: 1px dashed ${T.control}; color: ${T.fg5}`,
    gone: `border: 1px dashed ${T.control}; color: ${T.fg6}; font-family: ${SANS}`,
  }[kind];
  return `<div style="flex: none; min-width: 22px; height: 18px; box-sizing: border-box; padding: 0 5px; border-radius: 3px; font-family: ${MONO}; font-size: 10px; display: flex; align-items: center; justify-content: center; ${st}">${t}</div>`;
};
const para = ({ chip, kind, text, meta, sub = '', selected = false, textColor = T.fg2 }) => `
  <div style="position: relative; display: flex; gap: 8px; padding: 7px 12px; align-items: flex-start; ${selected ? `background: ${T.s5}` : ''}">
    ${selected ? `<div style="position: absolute; left: 0; top: 0; bottom: 0; width: 2px; background: ${T.accent}"></div>` : ''}
    ${numChip(chip, kind)}
    <div style="flex: 1; min-width: 0">
      <div style="color: ${textColor}; line-height: 1.55; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden">${text}</div>
      ${sub}
    </div>
    <div style="flex: none; font-family: ${MONO}; font-size: 10px; color: ${T.fg5}; line-height: 18px; display: flex; align-items: center; gap: 4px">${meta}</div>
  </div>`;
const subTag = (icon, label, color = T.fg5) => `<div style="display: flex; align-items: center; gap: 4px; margin-top: 2px; font-size: 10px; color: ${color}">${icon ? ic(icon, 12) : ''}<span>${label}</span></div>`;
const castChip = (name, n, linked) => linked
  ? `<div style="height: 22px; display: flex; align-items: center; gap: 4px; padding: 0 7px 0 3px; border-radius: 11px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 11px"><img src="${IMG.thumbMountain}" alt="" style="width: 16px; height: 16px; border-radius: 8px; object-fit: cover">${name}<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}">${n}</span></div>`
  : `<div style="height: 22px; box-sizing: border-box; display: flex; align-items: center; gap: 4px; padding: 0 7px; border-radius: 11px; border: 1px dashed ${T.control}; color: ${T.fg4}; font-size: 11px">${name}<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">${n}</span><span style="color: ${T.fg3}">+</span></div>`;
const scriptPanel = panelFrame(`
  ${panelHeader('剧本', `<div class="hovfg" style="font-size: 11px; color: ${T.fg4}">追加…</div><div style="color: ${T.fg5}; display: flex">${ic('more', 16)}</div>`)}
  <div style="padding: 8px 12px; border-bottom: 1px solid ${T.bSubtle}">
    <div style="font-size: 10px; color: ${T.fg5}; margin-bottom: 6px">剧中角色</div>
    <div style="display: flex; gap: 6px; flex-wrap: wrap">${castChip('渔夫', '2', true)}${castChip('老人', '1', false)}</div>
  </div>
  ${para({ chip: '01', kind: 'done', text: '拂晓。雾江上一叶孤舟，远山隐入雾霭。', meta: '4 秒', sub: subTag('dirty', '备注已改') })}
  ${para({ chip: '02', kind: 'live', selected: true, textColor: T.fg1, text: '江面雾气渐散，渔夫撑船缓缓驶出画面。', meta: `<span class="spin" style="display: flex; color: ${T.accent}">${ic('progress', 12)}</span>~5 秒` })}
  ${para({ chip: '已删', kind: 'gone', text: '一只白鹭掠过水面。', textColor: T.fg5, meta: '~2 秒', sub: `<div style="margin-top: 2px; font-size: 10px; color: ${T.accent}">重建这一镜</div>` })}
  ${para({ chip: '03', kind: 'todo', text: `<span style="border-bottom: 1px dashed ${T.fg4}">老人</span>立于岸边，向舟中招手，渔夫回望。`, textColor: T.fg3, meta: '~3 秒', sub: subTag('', '未生成') })}
  <div style="position: absolute; left: 0; right: 0; bottom: 0; height: 32px; box-sizing: border-box; border-top: 1px solid ${T.bSubtle}; display: flex; align-items: center; gap: 6px; padding: 0 12px; font-size: 11px; color: ${T.fg5}; background: ${T.s3}">
    <span>4 段 · 已生成 1 镜 · 未生成 1</span><div style="flex: 1"></div><span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg4}">~14 秒</span>
  </div>`);
const scriptCol = `
  <div style="width: ${COL}px; flex: none">
    ${h3(`剧本 ${prio('P1')}`, '原文逐段对到镜头')}
    ${scriptPanel}
    ${rules([
      `${need('需新表')} ${code('script_documents')} + ${code('script_paragraphs')}（含 node_id）；新增一条前向迁移；项目包白名单同步，导入时 node_id 随 ${code('import_remapper')} 改写`,
      '导入 / 追加走现有导入对话框，同一事务写段落；新镜接链尾',
      `编号 = ${code('sequenceShotNumbers')}，与大纲 / 序列同号；镜里有产物 = 已生成`,
      '点段 = 单选镜头并居中；画布上选中镜头，段跟着高亮',
      '右键段：定位 · 用本镜备注生成 · 复制原文',
      `原文只读；改过 ${code('shot_notes')} 的段标「备注已改」；镜头删了标「已删」，可重建`,
      `时长：有 ${code('duration_ms')} 用实数，否则按字数估（中文 4 字/秒，英文 2.5 词/秒，最少 2 秒）；显示走统一时长格式：不满 60 秒「N 秒」，满 60 秒 m:ss`,
      '角色：已有角色名匹配 = 实心；虚线候选可新建 / 关联 / 忽略',
      '空态：「导入剧本…」；已有镜头时另给「用镜头备注拼出剧本」',
    ])}
  </div>`;

// ---- 节点库 ----
const libRow = (icon, label, key, extra = '') => `
  <div style="height: 30px; display: flex; align-items: center; gap: 8px; padding: 0 12px; color: ${T.fg2}; ${extra}">
    <div style="color: ${T.fg4}; display: flex">${ic(icon, 16)}</div>
    <div style="flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${label}</div>${key ? kbd(key) : ''}
  </div>`;
const presetRow = (icon, title, meta, warn = '') => `
  <div style="height: 36px; display: flex; align-items: center; gap: 8px; padding: 0 12px">
    <div style="color: ${T.fg4}; display: flex">${ic(icon, 16)}</div>
    <div style="flex: 1; min-width: 0"><div style="color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</div><div style="font-size: 10px; color: ${T.fg6}">${meta}</div></div>
    ${warn ? `<div style="font-size: 10px; color: ${T.accent}">${warn}</div>` : ''}
  </div>`;
const nodeLibPanel = `
  <div style="position: relative; width: 262px; height: ${PANEL_H}px">
    ${panelFrame(`
      ${panelHeader('节点库')}
      ${filter('搜索节点、预设…')}
      ${groupHead('节点', '6')}
      ${libRow('imageConfig', '图像配置', 'I', `background: ${T.s5}`)}
      ${libRow('videoConfig', '视频配置', 'G')}
      ${libRow('text', '文本', 'T')}
      ${libRow('shot', '镜头', '')}
      ${libRow('note', '便签', 'N')}
      ${libRow('lane', '泳道', 'F')}
      ${groupHead('最近用过 · 本项目', '2')}
      ${presetRow('videoConfig', 'Kling v3 · 16:9 · 5 秒', '2 小时前')}
      ${presetRow('videoConfig', '万相 图生视频 · 720P', '3 天前', '无 Key')}
    `)}
    <div style="position: absolute; left: 156px; top: 120px; width: 104px; height: 28px; box-sizing: border-box; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.accent}; box-shadow: 0 8px 24px rgba(0,0,0,0.5); display: flex; align-items: center; gap: 6px; padding: 0 8px; color: ${T.fg1}; font-size: 11px; opacity: 0.92">
      <div style="color: ${T.accent}; display: flex">${ic('imageConfig', 14)}</div>图像配置
    </div>
  </div>`;
const nodeLibCol = `
  <div style="width: ${COL}px; flex: none">
    ${h3(`节点库 ${prio('P2')}`, '新建菜单常驻版 · R7 B 时在模板页顶部')}
    ${nodeLibPanel}
    ${rules([
      `「节点」= 新建菜单不带上下文的六项：图像配置 · 视频配置 · 文本 · 镜头 · 便签 · 泳道（${code('create_menu_model')}；便签 N 见 ImportSearch），同一个搜索过滤，键位取 ${code('CanvasToolKeys')}；类型一律叫「镜头」，不叫分镜`,
      `点一下 = 工具条同一条路（${code('addNodeFromMenu')}，视口中心 + 散布）；拖进画布 = 落在松手点，泳道归属走 ${code('resolveLaneDrop')}`,
      '泳道：没选中时点它 = 开「新建泳道」框（同 F，F 不看选中）；有选中时点它 = 包成泳道（同 Ctrl G，见 Selection）；拖出 = 在落点开框',
      `最近用过：jobs 按 ${code('provider_id')} + 比例 / 时长 / 分辨率去重，本项目最近 5 条；拖出 = 建配置节点并预填`,
      `${code('prompt_presets')}（已有表）可作第三组：拖到配置节点上 = 套用，与检查器预设同一写入`,
      `${need('需要')}舞台加 DragTarget（画布上现在没有拖放）；没 Key 的预设照列并标出，提交时由现有闸拦`,
    ])}
  </div>`;

// ---- 模板 ----
// 示意缩略：按节点位置画小方块，泳道画成淡色带（不截图）
const schematic = (lanes, nodes, w = 64, h = 40) => `
  <div style="position: relative; width: ${w}px; height: ${h}px; flex: none; border-radius: 3px; background: ${T.s1}; outline: 1px solid ${T.outline}; overflow: hidden">
    ${lanes.map(([y, hh, c]) => `<div style="position: absolute; left: 0; right: 0; top: ${y}px; height: ${hh}px; background: ${c}; opacity: 0.16"></div>`).join('')}
    ${nodes.map(([x, y]) => `<div style="position: absolute; left: ${x}px; top: ${y}px; width: 8px; height: 6px; border-radius: 1px; background: ${T.fg5}"></div>`).join('')}
  </div>`;
const tplCard = (name, meta, sch, hovered = false) => `
  <div style="margin: 0 8px 6px; padding: 8px; border-radius: 4px; ${hovered ? `background: ${T.s5}; outline: 1px solid ${T.control}` : ''}">
    <div style="display: flex; gap: 10px; align-items: center">
      ${sch}
      <div style="flex: 1; min-width: 0">
        <div style="color: ${hovered ? T.fg1 : T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${name}</div>
        <div style="font-size: 10px; color: ${T.fg5}">${meta}</div>
      </div>
    </div>
    ${hovered ? `<div style="display: flex; gap: 6px; margin-top: 8px">
      <button class="amber" type="button" style="flex: 1; height: 24px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 11px; font-weight: 500; text-align: center">插入当前画布</button>
      <button class="hov" type="button" style="flex: 1; height: 24px; border-radius: 3px; border: 1px solid ${T.controlStrong}; color: ${T.fg2}; font-size: 11px; text-align: center">用它新建画布</button>
    </div>
    <div style="font-size: 10px; color: ${T.fg6}; margin-top: 6px">12 节点 · 9 镜 · 3 泳道 · 11 条线 · 不含产物</div>` : ''}
  </div>`;
const seg = (a, b) => `
  <div style="margin: 10px 12px 8px; height: 26px; border-radius: 4px; background: ${T.s2}; border: 1px solid ${T.outline}; display: flex; padding: 2px; gap: 2px; box-sizing: border-box">
    <div style="flex: 1; border-radius: 3px; background: ${T.s5}; color: ${T.fg1}; display: flex; align-items: center; justify-content: center; font-size: 11px">${a}</div>
    <div style="flex: 1; border-radius: 3px; color: ${T.fg4}; display: flex; align-items: center; justify-content: center; font-size: 11px">${b}</div>
  </div>`;
const L3 = [[0, 13, T.peach], [13, 14, T.sky], [27, 13, T.teal]];
const tplPanel = panelFrame(`
  ${panelHeader('模板', `<div class="hovfg" style="font-size: 11px; color: ${T.fg4}">存为模板…</div>`)}
  ${seg('内置 3', '我的 1')}
  ${tplCard('三幕短片', '9 镜 · 3 泳道', schematic(L3, [[4, 3], [16, 3], [28, 3], [10, 17], [22, 17], [34, 17], [46, 17], [14, 30], [26, 30]]), true)}
  ${tplCard('单镜试拍 · 图生视频', '1 镜 · 图像 → 视频', schematic([], [[10, 17], [28, 17], [46, 17]]))}
  ${tplCard('短剧示例', '4 镜 · 1 泳道', schematic([[8, 24, T.peach]], [[6, 17], [20, 17], [34, 17], [48, 17]]))}
`);
const tplCol = `
  <div style="width: ${COL}px; flex: none">
    ${h3(`模板 ${prio('P2')}`, '开局用的镜头链')}
    ${tplPanel}
    ${rules([
      `内置 = 代码常量，与短剧示例同一套建法（${code('canvas_bootstrap_controller')}）；我的 = ${need('需新表')} ${code('canvas_templates')}（name, payload JSONB, 计数），新增一条前向迁移`,
      '存为模板：整张画布或选中的；存节点、叙事 / 数据边、泳道与风格词；不存产物、媒体、角色',
      `插入：新 UUID（照 ${code('import_remapper')} 重映射），整体移到视口中心，单事务；插完选中全部 + 撤销通知`,
      `插入时一并改写：提示词里的 ${code('@{角色 id}')} 剥成纯名字（模板不带角色），${code('gen_inputs')} 的源节点 id 换成新 id、指向模板外的剥掉`,
      '用它新建画布 = 建画布 + 插入 + 打开',
      '悬停：卡片展开两个按钮和计数；示意图按节点位置缩略画，不截图',
      '「我的」右键：改名 / 删除（软删 + 撤销）；为空时给「把当前画布存为模板」',
      'Tab 新建菜单和工具条「更多」里加「从模板插入…」，打开这一页',
    ])}
  </div>`;

// ---- 帮助 ----
const ext = `<span style="font-size: 10px; color: ${T.fg5}">↗</span>`;
const helpMock = `
  <div style="position: relative; width: ${COL}px; height: ${PANEL_H}px; box-sizing: border-box; background: ${T.s1}; border: 1px solid ${T.bStrong}; overflow: hidden">
    <div style="position: absolute; left: 0; top: 0; bottom: 0; width: 43px; box-sizing: border-box; background: ${T.s4}; border-right: 1px solid ${T.bStrong}; display: flex; flex-direction: column; align-items: center; justify-content: flex-end; padding: 8px 0; gap: 4px">
      ${railKey('shortcuts', false)}
      <div style="position: relative; width: 32px; height: 32px; border-radius: 4px; background: ${T.s5}; color: ${T.fg2}; display: flex; align-items: center; justify-content: center">${ic('help', 20)}<div style="position: absolute; right: 5px; top: 5px; width: 6px; height: 6px; border-radius: 3px; background: ${T.accent}"></div></div>
      ${railKey('panelToggle', false)}
    </div>
    <div class="pop" style="position: absolute; left: 49px; bottom: 8px">
      ${menu(`
        ${menuItem('info', '新手引导')}
        ${menuItem('projects', '打开示例项目')}
        ${menuSep}
        ${menuItem('', `版本说明 ${ext}`)}
        ${menuItem('', `反馈问题 ${ext}`)}
        <div style="height: 28px; display: flex; align-items: center; gap: 8px; padding: 0 10px; color: ${T.fg6}"><div style="width: 16px"></div><div style="flex: 1; white-space: nowrap">用户手册 ${ext}</div><span style="font-size: 10px">缺 URL</span></div>
        ${menuSep}
        ${menuItem('export', '导出诊断包…')}
        ${menuItem('', '打开日志目录')}
        ${menuSep}
        <div style="height: 28px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border-radius: 3px; color: ${T.fg2}; background: ${T.s5}">
          <div style="color: ${T.accent}; display: flex">${ic('success', 16)}</div><div style="flex: 1; white-space: nowrap">有新版本 0.9.4</div><span style="font-size: 11px; color: ${T.accent}">下载</span>
        </div>
        <div style="padding: 0 10px 4px 34px; font-size: 10px; color: ${T.fg6}">没有新版本时这一行是「检查更新…」</div>
        ${menuItem('info', '关于 InkFrame', '0.9.3')}
      `, 220)}
    </div>
  </div>`;
const helpCol = `
  <div style="width: ${COL}px; flex: none">
    ${h3('帮助', '弹出菜单，不占面板')}
    ${helpMock}
    ${rules([
      '锚在帮助键右侧；点外面 / Esc 关，焦点回帮助键；不动 LeftRailState',
      `同一组动作：菜单栏「帮助」= 快捷键 + 这里各项，同序同名（ShellExport 照此）；文案共用现有 ARB（如 ${code('settingsOpenLogDir')}）`,
      '只放有后端的项：用户手册要先有文档站 URL（现在没有），没有就灰着或不画',
      `外链走 ${code('UrlOpenerService')}；版本说明 / 反馈问题用更新检查的 repo slug 拼 releases / issues 地址`,
      `新手引导 = ${code('showOnboardingDialog')}，不改 onboardingCompleted；示例项目 = ${code('createStudioSampleProject')}`,
      '导出诊断包 = 设置底部条同一动作；打开日志目录 = 启动失败页同一动作',
      '检查更新 = 关于页同一次检查（结果共用）；有新版本时这一行换成「有新版本 · 下载」、帮助键挂琥珀点；关于 InkFrame = 打开设置 · 关于页',
      `各项同时进 ⌘K 动作表（${code('command_actions')}）`,
    ])}
  </div>`;

// ---- 需要你定 ----
const q = (n, title, opts, rec) => `
  <div style="min-width: 0">
    <div style="color: ${T.fg1}; font-weight: 500; margin-bottom: 3px">${n} ${title}</div>
    ${opts.map((o) => `<div style="font-size: 11px; color: ${T.fg3}; line-height: 1.5">${o}</div>`).join('')}
    <div style="font-size: 11px; color: ${T.accent}; line-height: 1.5; margin-top: 2px">建议 ${rec}</div>
  </div>`;
const decide = `
  <div style="margin-top: 14px; padding: 12px 16px 14px; border-radius: 6px; background: ${T.wash}; border: 1px solid ${T.washBorder}">
    <div style="font-weight: 500; color: ${T.accent}; margin-bottom: 8px">需要你定</div>
    <div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px 24px">
      ${q('R1', '剧本里的角色怎么识别（Q7）', ['A. 只匹配项目里已有的角色名', 'B. A + 原文里划选「设为角色」', 'C. 调模型抽取（要 Key、花钱）'], 'B：零 LLM，与拆分器同口径，结果可测')}
      ${q('R2', '重新导入时旧镜头怎么办', ['A. 只许追加，不许重导', 'B. 逐段比对：同段沿用原镜，新段建镜，删掉的段标出', 'C. 整份替换，旧镜断开对应'], 'B：不删镜头，也不丢对应')}
      ${q('R3', '字数估出的时长写不写回', ['A. 只在面板里显示', 'B. 导入时写进新建镜头的 duration_ms', 'C. 不估'], 'B：序列不再一律 3 秒；只写新建的镜')}
      ${q('R4', '原文能不能在面板里改', ['A. 只读，改备注去检查器', 'B. 面板里改段落，同步写 shot_notes'], 'A：原文是来源，备注是工作稿')}
      ${q('R5', '「我的模板」存在哪', ['A. 应用级，跨项目可用', 'B. 跟项目走，进项目包', 'C. 文件 config/templates/*.json'], 'A；有分享需求再加导出 .json')}
      ${q('R6', '模板里带不带图', ['A. 不带，只有结构和提示词', 'B. 带参考图 / 首帧（要复制媒体）'], 'A：模板是骨架，带图要管文件复制与清理')}
      ${q('R7', '节点库要不要单独一页', ['A. 单独一键，排在模板之后', 'B. 并进模板页顶部，导航条 5 键', 'C. 不做，只靠 Tab 新建菜单'], 'B：节点只有 6 种，单开一页太空')}
      ${q('R8', '帮助做成菜单还是面板页', ['A. 弹出菜单（本稿）', 'B. 面板页，附快捷键速查'], 'A：都是一次性动作，不值得占 241 宽')}
    </div>
  </div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="position: absolute; left: 24px; top: 22px; display: flex; align-items: baseline; gap: 14px">
    <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">左栏第二批：剧本 · 节点库 · 模板 · 帮助</div>
    <div style="color: ${T.fg4}">沿用 43 导航条 + 241 面板；剧本先上（P1），其余 P2</div>
  </div>
  <div style="position: absolute; left: 24px; right: 24px; top: 56px">
    ${railStrip}
    <div style="display: flex; gap: 20px; align-items: flex-start; margin-top: 14px">
      ${scriptCol}
      ${nodeLibCol}
      ${tplCol}
      ${helpCol}
    </div>
    ${decide}
  </div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'RailScript.dc.html', html: page('左栏第二批', W, H, body, logic) };
