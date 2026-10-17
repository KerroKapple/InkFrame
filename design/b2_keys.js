// 第二批画板：快捷键总表与冲突规则（1280×1400，静态）
// 第一批已上线 + 第二批已设计的键合成一张表：单键 / 组合键 / 指针 / 弹层内部；Esc 阶梯；单独 Alt；文字让位；未分配的键在「需要你定」。
// 已上线行的来源：kCanvasShortcuts / CanvasToolKeys（canvas_shortcuts.dart）、kCommandPaletteActivators、
// shortcut_catalog.dart，以及各弹层自己的键表（create_node_menu / command_palette_dialog / batch_compare_overlay / gallery_grid）。
const { T, SANS, MONO, page, ic } = require('./common.js');

const W = 1280, H = 1400;

const h3 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 8px; margin-bottom: 6px"><div style="font-weight: 500; color: ${T.fg1}">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const rules = (lines) => `<div style="font-size: 11px; color: ${T.fg4}; line-height: 1.5; margin-top: 8px">${lines.map((l) => `<div style="display: flex; gap: 6px"><span style="color: ${T.fg6}; flex: none">·</span><span>${l}</span></div>`).join('')}</div>`;
const code = (t) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${t}</span>`;

// 键帽：一段 token 串，空格分隔；~ 开头的是说明文字，不画成键帽
const cap = (t) => `<span style="display: inline-flex; align-items: center; justify-content: center; height: 15px; min-width: 9px; padding: 0 4px; box-sizing: border-box; border-radius: 3px; background: ${T.s3}; border: 1px solid ${T.control}; border-bottom-color: ${T.controlStrong}; font-family: ${MONO}; font-size: 9px; line-height: 1; color: ${T.fg2}; white-space: nowrap">${t}</span>`;
const keys = (s) => {
  if (s === '同') return `<span style="font-size: 10px; color: ${T.fg6}">同左</span>`;
  if (s === '—') return `<span style="font-size: 10px; color: ${T.fg6}">—</span>`;
  return s.split(' ').map((tok) => tok.startsWith('~')
    ? `<span style="font-size: 10px; color: ${T.fg4}; white-space: nowrap">${tok.slice(1)}</span>`
    : cap(tok)).join('');
};

// 范围 / 状态小标
const SCOPE = {
  画布: T.fg3, 应用: T.sky, 弹层: T.teal, 序列: T.peach,
};
const scopeTag = (s) => `<span style="display: inline-flex; align-items: center; justify-content: center; height: 15px; padding: 0 4px; border-radius: 3px; background: ${T.s5}; color: ${SCOPE[s]}; font-size: 9px; white-space: nowrap">${s}</span>`;
const statusTag = (s) => {
  if (s === '已上线') return `<span style="display: inline-flex; align-items: center; justify-content: center; height: 15px; padding: 0 4px; border-radius: 3px; border: 1px solid ${T.control}; color: ${T.success}; font-size: 9px; white-space: nowrap">已上线</span>`;
  if (s === '第二批') return `<span style="display: inline-flex; align-items: center; justify-content: center; height: 15px; padding: 0 4px; border-radius: 3px; border: 1px solid ${T.washBorder}; background: ${T.wash}; color: ${T.accent}; font-size: 9px; white-space: nowrap">第二批</span>`;
  return `<span style="display: inline-flex; align-items: center; justify-content: center; height: 15px; padding: 0 4px; border-radius: 3px; border: 1px dashed ${T.fg6}; color: ${T.fg4}; font-size: 9px; white-space: nowrap">${s}</span>`;
};

const COLS = '100px 64px minmax(0, 1fr) 30px 46px';
const thead = (a = 'Windows', b = 'macOS') => `
  <div style="display: grid; grid-template-columns: ${COLS}; column-gap: 6px; height: 18px; align-items: center; font-size: 10px; color: ${T.fg6}; border-bottom: 1px solid ${T.control}">
    <div>${a}</div><div>${b}</div><div>动作</div><div>范围</div><div>状态</div>
  </div>`;
const row = ([win, mac, action, scope, status]) => {
  const pending = !(status === '已上线' || status === '第二批');
  return `
  <div style="display: grid; grid-template-columns: ${COLS}; column-gap: 6px; height: 19px; align-items: center; border-bottom: 1px solid ${T.bSubtle}">
    <div style="display: flex; gap: 2px; align-items: center; overflow: hidden">${keys(win)}</div>
    <div style="display: flex; gap: 2px; align-items: center; overflow: hidden">${keys(mac)}</div>
    <div style="font-size: 11px; color: ${pending ? T.fg4 : T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${action}</div>
    <div>${scopeTag(scope)}</div>
    <div>${statusTag(status)}</div>
  </div>`;
};
const table = (title, note, rows, lines, head) => `
  <div>
    ${h3(title, note)}
    ${head || thead()}
    ${rows.map(row).join('')}
    ${rules(lines)}
  </div>`;

// ================= 单键 =================
const singleRows = [
  ['V', '同', '选择工具', '画布', '已上线'],
  ['H', '同', '平移工具 开 / 关', '画布', '已上线'],
  ['~按住 Space', '同', '临时平移，松开即回', '画布', '已上线'],
  ['I', '同', '新建图像配置', '画布', '已上线'],
  ['G', '同', '新建视频配置', '画布', '已上线'],
  ['T', '同', '新建文本', '画布', '已上线'],
  ['F', '同', '新建泳道（开对话框）', '画布', '已上线'],
  ['L', '同', '连线 开 / 退', '画布', '已上线'],
  ['Tab', '同', '新建… 菜单', '画布', '已上线'],
  ['Del ~/ Backspace', '⌫', '删除选中节点', '画布', '已上线'],
  ['Del ~/ Backspace', '⌫', '删除选中连线', '画布', '第二批'],
  ['Esc', '同', '剥一层（见阶梯）', '画布', '已上线'],
  ['Shift 1', '⇧1', '适应全部', '画布', '已上线'],
  ['Shift 2', '⇧2', '适应选中', '画布', '已上线'],
  ['N', '同', '新建便签', '画布', '第二批'],
  ['M', '同', '小地图 开 / 关', '画布', '第二批'],
  ['Q', '同', '工具锁', '画布', '第二批'],
  ['F6', '同', '跳到通知区', '应用', '第二批'],
  ['P', '同', '设为当前', '画布', '待定 Q3'],
  ['Shift D', '⇧D', '停用 / 启用', '画布', '待定 Q4'],
  ['C', '同', '评论（预留 P2）', '画布', '待定 Q2'],
  ['~（不给）', '同', '新建镜头', '画布', '待定 Q6'],
];
const colSingle = table('单键', '画布持焦、不在文字里', singleRows, [
  `全走 ${code('_EditingAwareAction')}：焦点在文字里就让位`,
  'Tab、空格更严：只在画布本身持主焦点时接管',
  `新键进 ${code('CanvasToolKeys')}，${code('shortcutActionOf')} 和 ${code('_keyLabels')} 认领`,
  `${code('includeRepeats: false')}，按住不连发；待定行定了才注册`,
]);

// ================= 组合键 =================
const comboRows = [
  ['Ctrl K', '⌘K', '命令面板', '应用', '已上线'],
  ['Ctrl A', '⌘A', '全选节点', '画布', '已上线'],
  ['Ctrl =/-', '⌘ =/-', '放大 / 缩小', '画布', '已上线'],
  ['Ctrl 0', '⌘0', '缩放复位（见 Q5）', '画布', '已上线'],
  ['Ctrl \\', '⌘\\', '收起 / 展开左栏', '画布', '已上线'],
  ['Ctrl Enter', '⌘↵', '生成选中的一张', '画布', '已上线'],
  ['Ctrl Enter', '⌘↵', '多选时批量生成', '画布', '第二批'],
  ['Ctrl D', '⌘D', '复制一份', '画布', '已上线'],
  ['Ctrl Z', '⌘Z', '撤销', '画布', '第二批'],
  ['Ctrl Y', '⇧⌘Z', '重做', '画布', '第二批'],
  ['Ctrl C/X/V', '⌘ C/X/V', '复制 / 剪切 / 粘贴', '画布', '第二批'],
  ['Ctrl U', '⌘U', '导入媒体', '画布', '第二批'],
  ['Ctrl F', '⌘F', '画布内查找', '画布', '第二批'],
  ['Ctrl G', '⌘G', '包成泳道', '画布', '第二批'],
  ['Ctrl Shift G', '⇧⌘G', '移出泳道', '画布', '第二批'],
  ['Alt A/D/W/S', '⌥ A/D/W/S', '左 / 右 / 上 / 下对齐', '画布', '第二批'],
  ['Alt H/V', '⌥ H/V', '水平 / 垂直居中', '画布', '第二批'],
  ['Alt Shift H/V', '⌥⇧ H/V', '水平 / 垂直分布', '画布', '第二批'],
  ['Ctrl →', '⌘→', '新建下一镜', '画布', '待定 Q1'],
  ['Alt F4', '⌘Q', '退出', '应用', '第二批'],
  ['~单独 Alt', '—', '聚焦菜单栏', '应用', '第二批'],
];
const colCombo = table('组合键', '⌘ / Ctrl 同时注册，清单按平台只显示一套', comboRows, [
  '重做每平台只注册一个，菜单、⌘K、右键、快捷键页同一串',
  'mac 不绑 ⌘H ⌘M ⌘Tab ⌃←→（所以下一镜用 ⌘→）',
  `⌥ 字母按 ${code('logicalKey')} 匹配；多选 Ctrl Enter 的确认见 TakesCost`,
]);

// ================= 指针 =================
const pointerRows = [
  ['~点卡', '同', '单选', '画布', '已上线'],
  ['Shift/Ctrl ~点卡', '⇧/⌘ ~点卡', '切换选中', '画布', '已上线'],
  ['~点可播视频产物', '同', '选中并开播放框', '画布', '已上线'],
  ['~左键拖空白', '同', '框选（现在是平移）', '画布', '第二批'],
  ['Shift ~拖框', '⇧ ~拖框', '加选', '画布', '第二批'],
  ['Ctrl ~拖框', '⌘ ~拖框', '反选', '画布', '第二批'],
  ['~右键拖', '同', '平移', '画布', '已上线'],
  ['~中键拖', '同', '平移', '画布', '第二批'],
  ['~右键点', '同', '松开时开右键菜单', '画布', '已上线'],
  ['~滚轮', '同', '以指针为中心缩放', '画布', '已上线'],
  ['~双指/捏合', '同', '平移 / 缩放', '画布', '已上线'],
  ['~双击空白', '同', '新建… 菜单', '画布', '已上线'],
  ['~双击泳道标题', '同', '折叠 / 展开', '画布', '已上线'],
  ['~双击文本/便签', '同', '就地编辑', '画布', '第二批'],
  ['~双击工具按钮', '同', '工具锁', '画布', '第二批'],
  ['~端口拖到空白', '同', '新建菜单，建好连线', '画布', '已上线'],
  ['~端口拖到卡上', '同', '连线', '画布', '已上线'],
  ['~拖卡', '同', '移动；跨带够深才换道', '画布', '已上线'],
  ['~拖卡+ Shift', '~拖卡+ ⇧', '锁轴', '画布', '第二批'],
  ['~拖卡+ Ctrl', '~拖卡+ ⌘', '原样放下', '画布', '第二批'],
  ['Alt ~拖空白', '⌥ ~拖空白', '切线', '画布', '第二批'],
  ['~拖素材/文件进来', '同', '导入或挂到节点', '画布', '第二批'],
  ['Ctrl ~滚轮', '⌘ ~滚轮', '时间轴缩放', '序列', '已上线'],
];
const colPointer = table('指针', '修饰键各管一件', pointerRows, [
  `4px 内松开算点；换道走 ${code('resolveCardDrop')}，整组看抓住的那张`,
  '拖到一半按修饰键即时生效：Shift 只锁轴，Ctrl(⌘) 只原样放下',
  '原样放下 = 不吸附、不插进叙事线；Alt(⌥) 只给切线',
  'mac 只写 ⇧ / ⌘ 点：Ctrl 点在 mac 是右键习惯（代码现也当切换）',
], thead('Windows', 'macOS'));

// ================= Esc 阶梯 =================
const rung = (i, label, sub, status) => `
  <div style="margin-left: ${i * 12}px; height: 26px; display: flex; align-items: center; gap: 8px; padding: 0 8px; box-sizing: border-box; border-radius: 4px; background: ${T.s3}; border: 1px solid ${T.outline}; margin-bottom: 4px">
    <div style="width: 16px; height: 16px; border-radius: 8px; background: ${T.s5}; color: ${T.fg2}; font-family: ${MONO}; font-size: 9px; display: flex; align-items: center; justify-content: center; flex: none">${i + 1}</div>
    <div style="flex: 1; min-width: 0; font-size: 11px; color: ${T.fg1}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${label}<span style="color: ${T.fg5}; font-size: 10px; margin-left: 6px">${sub}</span></div>
    ${status}
  </div>`;
const both = `<span style="display: flex; gap: 3px">${statusTag('已上线')}${statusTag('第二批')}</span>`;
const colEsc = `
  <div>
    ${h3('Esc 阶梯', '按一次剥一层，从上往下找')}
    <div style="height: 24px; display: flex; align-items: center; gap: 6px; padding: 0 8px; margin-bottom: 6px; border-radius: 4px; border: 1px dashed ${T.control}; font-size: 10px; color: ${T.fg5}; white-space: nowrap; overflow: hidden">不在阶梯上：对话框 · ⌘K · 设置 · 任务弹层 · 铃铛盖着时，Esc 归它们</div>
    ${rung(0, '菜单', '新建 / 右键；子菜单先关', statusTag('已上线'))}
    ${rung(1, '@ 补全弹层', '收起，字留着', statusTag('第二批'))}
    ${rung(2, '查找条', '关掉，选中留在当前', statusTag('第二批'))}
    ${rung(3, '文字输入框', '失焦，焦点回画布', statusTag('第二批'))}
    ${rung(4, '进行中的手势', '拖线 · 框选', both)}
    ${rung(5, '工具回到选择', '工具锁 · 平移 · 连线', both)}
    ${rung(6, '清空选中', '节点和连线', statusTag('已上线'))}
    ${rules([
      `${code('_escape')} 照这张表逐层判，现有拖线 / 菜单 / 平移 / 连线并进来`,
      `第 4 层是改动：现在 ${code('CanvasEscapeIntent')} 不对文字让位`,
      '框选中 Esc 恢复按下前的选中；F6 区里 Esc 回到进来前的位置',
    ])}
  </div>`;

// ================= 单独 Alt · 文字让位 =================
const evt = (seq, result, ok) => `
  <div style="height: 20px; display: flex; align-items: center; gap: 6px; font-size: 10px; color: ${T.fg4}; white-space: nowrap">
    <div style="display: flex; gap: 2px; align-items: center; width: 132px">${seq}</div>
    <span style="color: ${T.fg6}">→</span>
    <span style="color: ${ok ? T.accent : T.fg3}">${result}</span>
  </div>`;
const down = (k) => `${cap(k)}<span style="font-size: 9px; color: ${T.fg6}">↓</span>`;
const up = (k) => `${cap(k)}<span style="font-size: 9px; color: ${T.fg6}">↑</span>`;
const mb = (t, on = false) => `<span style="height: 18px; padding: 0 7px; border-radius: 3px; display: inline-flex; align-items: center; font-size: 10px; ${on ? `outline: 1px solid ${T.accent}; color: ${T.fg1}; background: ${T.s5}` : `color: ${T.fg4}`}">${t}</span>`;
const altBox = `
  <div style="border-radius: 4px; border: 1px solid ${T.outline}; background: ${T.s1}; padding: 6px 8px">
    <div style="display: flex; gap: 2px; align-items: center; margin-bottom: 4px">${mb('文件', true)}${mb('编辑')}${mb('画布')}${mb('节点')}${mb('窗口')}${mb('帮助')}<span style="margin-left: auto; font-size: 9px; color: ${T.fg6}">仅 Windows</span></div>
    ${evt(`${down('Alt')}${up('Alt')}`, '聚焦「文件」，不展开', true)}
    ${evt(`${down('Alt')}${down('A')}`, '左对齐，菜单栏不动')}
    ${evt(`${down('Alt')}<span>指针拖空白</span>`, '切线，菜单栏不动')}
  </div>`;
const tagRow = (label, items, color) => `
  <div style="display: flex; gap: 6px; align-items: center; min-height: 20px">
    <div style="width: 52px; flex: none; font-size: 10px; color: ${color}">${label}</div>
    <div style="display: flex; flex-wrap: wrap; gap: 3px">${items}</div>
  </div>`;
const yieldBox = `
  <div style="border-radius: 4px; border: 1px solid ${T.outline}; background: ${T.s1}; padding: 6px 8px">
    ${tagRow('交给框', `${cap('单键')}${cap('Space')}${cap('Tab')}${cap('Del')}${cap('Ctrl A/C/X/V')}${cap('Ctrl Z/Y')}${cap('Ctrl D')}${cap('Ctrl →')}${cap('Alt 字母')}`, T.fg3)}
    ${tagRow('照常生效', `${cap('Ctrl K')}${cap('Ctrl F')}${cap('F6')}${cap('单独 Alt')}`, T.sky)}
    ${tagRow('另有去处', `${cap('Ctrl Enter')}<span style="font-size: 10px; color: ${T.fg4}">提示词框里生成本节点</span>${cap('Esc')}<span style="font-size: 10px; color: ${T.fg4}">先失焦</span>`, T.accent)}
  </div>`;
const colAlt = `
  <div>
    ${h3('单独按 Alt', 'Windows 菜单栏的唯一入口')}
    ${altBox}
    ${rules([
      '松开 Alt 时判：按下后没有别的键、指针按下或滚轮才聚焦',
      '↓ / Enter 展开，←→ 换菜单，Esc 或再按 Alt 回原处',
      '窗口失焦清标记（Alt Tab 回来不误触）；带 Ctrl 的 AltGr 不算',
      '不做 Alt+字母助记键；mac 不画，菜单在系统菜单栏',
    ])}
    <div style="height: 12px"></div>
    ${h3('文字让位', '焦点在输入框里时')}
    ${yieldBox}
    ${rules([
      `判据只有一个：主焦点在 EditableText 里（${code('isEditingText')}）`,
      'Ctrl Z 是框自己的撤销；失焦后整段改动算画布一步',
    ])}
  </div>`;

// ================= 弹层内部 =================
const pop = (name, status, line) => `
  <div style="padding: 2px 0 2px; border-bottom: 1px solid ${T.bSubtle}">
    <div style="display: flex; align-items: center; gap: 6px; height: 15px"><span style="font-size: 11px; font-weight: 500; color: ${T.fg2}">${name}</span>${statusTag(status)}</div>
    <div style="font-size: 10px; color: ${T.fg4}; line-height: 1.4; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${line}</div>
  </div>`;
const colPop = `
  <div>
    ${h3('弹层内部', '作用域隔开，和画布键不冲突')}
    ${pop('新建菜单 / 右键菜单', '已上线', '↑↓ 移 · Enter 选 · → 开子菜单 · ← / Esc 关子菜单 · 打字即搜索')}
    ${pop('⌘K 命令面板', '已上线', '↑↓ · Enter 打开 · Ctrl Enter / ⌘↵ 在画布中定位 · Esc 关')}
    ${pop('批量对比', '已上线', '←→ 切格 · Enter 设为当前（原「转正」）· Esc 关')}
    ${pop('画廊网格（画廊标签）', '已上线', '↑↓←→ 移锚点 · Space 预览')}
    ${pop('查找条', '第二批', 'Enter 下一个 · Shift Enter 上一个 · Esc 关')}
    ${pop('@ 补全', '第二批', '↑↓ · Enter / Tab 插入 · Esc 收起 · 退格整块删')}
    ${pop('F6 通知区', '第二批', '↑↓ 切卡 · Enter 主按钮 · Tab 卡内按钮 · Del 关卡 · Esc 回原处')}
    ${pop('菜单栏（Windows）', '第二批', '←→ 切菜单 · ↑↓ · Enter · Esc 退出')}
  </div>`;

// ================= 需要你定 =================
const q = (id, title, opts, rec) => `
  <div>
    <div style="color: ${T.fg1}; font-weight: 500; margin-bottom: 3px">${id} ${title}</div>
    ${opts.map((o) => `<div style="font-size: 11px; color: ${T.fg3}; line-height: 1.5">${o}</div>`).join('')}
    <div style="font-size: 11px; color: ${T.accent}; line-height: 1.5; margin-top: 2px">建议 ${rec}</div>
  </div>`;
const decide = `
  <div style="background: ${T.wash}; border: 1px solid ${T.washBorder}; border-radius: 6px; padding: 12px 18px 14px">
    <div style="font-weight: 500; color: ${T.accent}; margin-bottom: 8px">需要你定</div>
    <div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0 32px; align-items: start">
      <div style="display: flex; flex-direction: column; gap: 12px">
        ${q('Q1', '新建下一镜的键和「继承配置」', [
          'A. Ctrl → / ⌘→：同类型配置节点 + 叙事边；继承模型、画幅、分辨率、时长、批量数、角色、负面词、跟不跟泳道风格',
          'B. 键同 A，什么都不继承（= 新建菜单「下一镜」）',
          'C. 全部继承（= Ctrl D 再连叙事线）',
        ], 'A：不继承提示词、种子、镜头语言、备注、产物、首尾帧。落在锚点右侧同泳道；锚点已有下一镜就插进中间；焦点留在画布，可连按。mac 用 ⌘→，因为 ⌃→ 是系统切桌面')}
        ${q('Q6', '镜头节点要不要单键', ['A. 不给：工具条、Tab、下一镜已够', 'B. 给 S'], 'A：字母单键已有 12 个，少一个误触面')}
      </div>
      <div style="display: flex; flex-direction: column; gap: 12px">
        ${q('Q2', 'C 键给不给评论', ['A. 预留给评论，评论上线前不注册', 'B. 不预留，到时再定', 'C. 现在给连线做别名'], 'A：连线已是 L，C 留给评论（调研 Q12）')}
        ${q('Q4', '停用用哪个键（Ctrl D 已是复制一份）', ['A. D', 'B. Shift D', 'C. Ctrl M（mac 的 ⌘M 是系统最小化）'], 'B：D 紧挨 Ctrl D，Ctrl 松早了就停用一片。多选时有启用的就全停，否则全启，一步撤销')}
      </div>
      <div style="display: flex; flex-direction: column; gap: 12px">
        ${q('Q3', 'P = 设为当前，管到哪', ['A. take 卡：设为当前；配置卡：固定 / 取消固定它的当前 take', 'B. 只认 take 卡', 'C. 不给单键，只走右键和历史页'], 'A：两种都只写 pinned_result_id，连同改写的边算一步撤销；多选时不生效')}
        ${q('Q5', 'Shift 0 和现有的 Ctrl 0', ['A. Ctrl 0 仍复位到初始相机，另加 Shift 0 = 100%、保持视口中心', 'B. Ctrl 0 改成 100%、保持视口中心，不加 Shift 0', 'C. 两个键都做 100%（Shift 0 照 tldraw）'], 'B：复位到原点常落在空处，回内容有 Shift 1 和「回到内容」；一件事一个键')}
      </div>
    </div>
  </div>`;

// ================= 页面 =================
const legend = `
  <div style="display: flex; align-items: center; gap: 8px; font-size: 10px; color: ${T.fg5}; flex-wrap: wrap">
    ${statusTag('已上线')}<span>main 或本地修复分支已有</span>
    ${statusTag('第二批')}<span>第二批板上已设计</span>
    ${statusTag('待定 Qn')}<span>见底部</span>
    <span style="width: 10px"></span>
    ${scopeTag('画布')}<span>画布持焦、不在文字里</span>
    ${scopeTag('应用')}<span>任何标签，文字里也生效</span>
    ${scopeTag('弹层')}<span>只在那个弹层里</span>
    ${scopeTag('序列')}<span>序列标签</span>
  </div>`;
const sources = `<div style="font-size: 10px; color: ${T.fg6}; line-height: 1.5">已上线行取自 ${code('kCanvasShortcuts')} / ${code('CanvasToolKeys')} / ${code('kCommandPaletteActivators')} / ${code('shortcut_catalog')} 和各弹层自己的键表。第二批出处：N M Q Ctrl U Ctrl F 双击 → ImportSearch · 撤销 / 复制粘贴 → UndoClipboard · 框选 对齐 Ctrl G → Selection · 删线 切线 批量 → ContextMenus · F6 菜单栏 Alt F4 → ShellExport</div>`;
const strip = `<div style="font-size: 11px; color: ${T.fg4}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis"><span style="color: ${T.fg2}">刻意不绑：</span>Ctrl S（自动保存）· Alt+字母菜单助记键 · K 剪线（W3 选 A）· Ctrl Del（W1 选 A，菜单给「删除（不接上）」）<span style="color: ${T.fg2}; margin-left: 16px">还没有板：</span>Ctrl 1–5 切标签 · Ctrl Shift \\ 收起全部面板 · 大纲行双击改名</div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45; padding: 28px 32px; box-sizing: border-box; display: flex; flex-direction: column; gap: 14px">
  <div style="display: flex; flex-direction: column; gap: 8px">
    <div style="display: flex; align-items: center; gap: 12px">
      <div style="color: ${T.fg3}; display: flex">${ic('shortcuts', 20)}</div>
      <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">快捷键总表与冲突规则</div>
      <div style="color: ${T.fg4}">第一批已上线 + 第二批已设计，合成一张；冲突按统一规则消掉，剩下没分配的在底部</div>
    </div>
    ${legend}
    ${sources}
  </div>
  <div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0 24px; align-items: start">
    <div style="display: flex; flex-direction: column; gap: 18px">${colSingle}${colEsc}</div>
    <div style="display: flex; flex-direction: column; gap: 18px">${colCombo}${colAlt}</div>
    <div style="display: flex; flex-direction: column; gap: 18px">${colPointer}${colPop}</div>
  </div>
  ${strip}
  ${decide}
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'KeyMap.dc.html', html: page('快捷键总表', W, H, body, logic) };
