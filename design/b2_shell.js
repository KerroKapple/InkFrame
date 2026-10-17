// 第二批画板：外壳菜单、系统通知与导出（1280×1400，静态）
// 依据：shell_chrome.dart（六个菜单标签目前是纯文字）/ command_actions.dart / shortcut_catalog.dart /
// canvas_shortcuts.dart（CanvasToolKeys）/ canvas_tool_actions.dart / toast_center.dart（setWindowActive）/
// shell_task_popover.dart / jobs 表 submitted_at · completed_at / features/export（delivery_panel 页签只画标签、
// DeliveryWriterRegistry 出厂只有 EDL）/ app_zh.arb canvasToolShotNode（现为「分镜节点」）
// 第二轮按 critic 改：12 重做键位 · 13 不写迁移号 · 15 帮助一套动作 · 16 新建节点列表含便签、统一叫「镜头」·
// 20 耗时共用一个格式函数 · 21 单独按 Alt 才聚焦菜单栏
// 布局：左列 604 = 菜单 + 菜单规则 + 需要你定；右列 580 = 系统通知 / F6 / 任务耗时 / 导出第二批
const { T, IMG, SANS, MONO, page, ic } = require('./common.js');

const W = 1280, H = 1400;

const h3 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 8px; margin-bottom: 10px"><div style="font-weight: 500; color: ${T.fg1}">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const kbd = (k, c = T.fg5) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${c}; white-space: nowrap">${k}</span>`;
const cap = (t) => `<div style="font-size: 11px; color: ${T.fg5}; margin-bottom: 6px">${t}</div>`;
const rules = (lines, extra = '') => `<div style="font-size: 10.5px; color: ${T.fg4}; line-height: 1.5; ${extra}">${lines.map((l) => `<div style="display: flex; gap: 5px"><span style="color: ${T.fg6}">·</span><span>${l}</span></div>`).join('')}</div>`;
const code = (t) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${t}</span>`;
const newTag = `<span style="font-size: 9px; height: 14px; line-height: 14px; padding: 0 4px; border-radius: 7px; border: 1px solid ${T.washBorder}; background: ${T.wash}; color: ${T.accent}; flex: none">新</span>`;
const soonTag = `<span style="font-size: 9px; height: 14px; line-height: 14px; padding: 0 5px; border-radius: 7px; border: 1px solid ${T.outline}; color: ${T.fg5}; flex: none">待支持</span>`;
const ext = `<span style="font-size: 10px; color: ${T.fg5}">↗</span>`;
// 重做图标 = 撤销镜像（与 UndoClipboard 同）
const redoIcon = `<div style="display: flex; transform: scaleX(-1)">${ic('undo', 14)}</div>`;

// ---- 菜单（照 interactions.js 的 menu / menuItem，行高压到 22 当原生菜单栏用）----
const menuSep = `<div style="height: 1px; background: ${T.bStrong}; margin: 4px 0"></div>`;
const menu = (inner, width = 196) => `<div style="width: ${width}px; box-sizing: border-box; padding: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6)">${inner}</div>`;
const mi = (icon, label, key = '', o = {}) => {
  const fg = o.dis ? T.fg6 : (o.danger ? T.danger : T.fg2);
  const lead = icon ? (icon.startsWith('<') ? icon : ic(icon, 14)) : (o.cur ? `<div style="width: 5px; height: 5px; border-radius: 3px; background: ${T.accent}; margin-left: 4px"></div>` : '');
  return `<div style="height: 21px; display: flex; align-items: center; gap: 8px; padding: 0 8px; border-radius: 3px; color: ${fg}; ${o.hot ? `background: ${T.s5};` : ''}">
    <div style="width: 14px; display: flex; align-items: center; color: ${o.dis ? T.fg6 : T.fg4}">${lead}</div>
    <div style="flex: 1; white-space: nowrap">${label}</div>
    ${o.neu ? newTag : ''}${o.note ? `<span style="font-size: 10px; color: ${T.fg6}; white-space: nowrap">${o.note}</span>` : ''}${key ? kbd(key, o.dis ? T.fg6 : T.fg5) : ''}${o.sub ? `<span style="color: ${T.fg5}; font-size: 11px">›</span>` : ''}
  </div>`;
};
const menuCol = (name, inner, after = '') => `<div style="width: 196px; flex: none">${cap(name)}${menu(inner)}${after}</div>`;
const subBlock = (name, inner) => `<div style="margin-top: 10px">${cap(name)}${menu(inner)}</div>`;

const mFile = menuCol('文件', `
  ${mi('projects', '新建项目…')}
  ${mi('', '打开示例项目')}
  ${menuSep}
  ${mi('upload', '导入项目包…')}
  ${mi('', '导出项目包…')}
  ${mi('', '导入媒体…', 'Ctrl U', { neu: true, dis: true })}
  ${menuSep}
  ${mi('export', '导出视频…')}
  ${mi('sequence', '交付到剪辑软件…')}
  ${menuSep}
  ${mi('settings', '设置…')}
  ${mi('trash', '回收站…')}
  ${menuSep}
  ${mi('', '退出', 'Alt F4')}
`);
const mEdit = menuCol('编辑', `
  ${mi('undo', '撤销', 'Ctrl Z', { neu: true, dis: true })}
  ${mi(redoIcon, '重做', 'Ctrl Y', { neu: true, dis: true })}
  ${menuSep}
  ${mi('', '剪切', 'Ctrl X', { neu: true, dis: true })}
  ${mi('', '复制', 'Ctrl C', { neu: true, dis: true })}
  ${mi('', '粘贴', 'Ctrl V', { neu: true, dis: true })}
  ${menuSep}
  ${mi('', '复制一份', 'Ctrl D', { hot: true })}
  ${mi('', '删除', 'Del')}
  ${menuSep}
  ${mi('', '全选', 'Ctrl A')}
  ${mi('', '查找…', 'Ctrl F', { neu: true, dis: true })}
  ${mi('search', '命令面板…', 'Ctrl K')}
`);
const mCanvas = menuCol('画布', `
  ${mi('nodeLibrary', '新建…', 'Tab')}
  ${mi('', '新建节点', '', { sub: true, hot: true })}
  ${mi('link', '连线', 'L')}
  ${mi('script', '导入脚本…')}
  ${menuSep}
  ${mi('select', '选择', 'V')}
  ${mi('pan', '平移', 'H')}
  ${menuSep}
  ${mi('zoomIn', '缩放', '', { sub: true })}
  ${mi('fit', '适应全部', 'Shift 1')}
  ${mi('', '适应选中', 'Shift 2')}
  ${menuSep}
  ${mi('panelToggle', '收起左栏', 'Ctrl \\')}
`);
// 子菜单单独画在下面一行（实际贴在父行右侧弹出）
const subNewNode = subBlock('画布 › 新建节点 ›', `
  ${mi('imageConfig', '图像配置', 'I')}
  ${mi('videoConfig', '视频配置', 'G')}
  ${mi('text', '文本', 'T')}
  ${mi('shot', '镜头')}
  ${mi('note', '便签', 'N', { neu: true, dis: true })}
  ${menuSep}
  ${mi('lane', '泳道…', 'F')}
`);
const subZoom = subBlock('画布 › 缩放 ›', `
  ${mi('zoomIn', '放大', 'Ctrl +')}
  ${mi('zoomOut', '缩小', 'Ctrl −')}
  ${mi('', '复位 100%', 'Ctrl 0')}
`);
const mNode = menuCol('节点（选中 1 个图像配置）', `
  ${mi('run', '生成', 'Ctrl ↵')}
  ${menuSep}
  ${mi('characters', '存为角色', '', { dis: true })}
  ${mi('lane', '加入泳道', '', { sub: true })}
  ${mi('', '包成泳道', 'Ctrl G', { neu: true, dis: true })}
  ${mi('', '移出泳道', '', { dis: true })}
  ${mi('sequence', '在序列中定位')}
  ${menuSep}
  ${mi('', '删除', 'Del', { danger: true })}
`, subNewNode);
const mWindow = menuCol('窗口', `
  ${mi('', '工作室')}
  ${mi('', '画布', '', { cur: true })}
  ${mi('', '序列')}
  ${mi('', '画廊')}
  ${mi('', '导出')}
  ${menuSep}
  ${mi('queue', '任务')}
  ${mi('bell', '通知', 'F6', { neu: true })}
`, subZoom);
// 帮助 = 左栏帮助弹层的同一组动作 + 快捷键（RailScript 帮助）
const mHelp = menuCol('帮助', `
  ${mi('shortcuts', '快捷键')}
  ${menuSep}
  ${mi('info', '新手引导')}
  ${mi('projects', '打开示例项目')}
  ${menuSep}
  ${mi('', `版本说明 ${ext}`)}
  ${mi('', `反馈问题 ${ext}`)}
  ${mi('', `用户手册 ${ext}`, '', { dis: true, note: '缺 URL' })}
  ${menuSep}
  ${mi('export', '导出诊断包…')}
  ${mi('', '打开日志目录')}
  ${menuSep}
  ${mi('', '检查更新…')}
  ${mi('', '关于 InkFrame')}
`);

const menusCol = `
  <div>
    ${h3('顶部菜单栏', '六个菜单同时展开只是示意，实际一次开一个')}
    <div style="display: flex; gap: 8px; align-items: flex-start">${mFile}${mEdit}${mCanvas}</div>
    <div style="display: flex; gap: 8px; align-items: flex-start; margin-top: 14px">${mNode}${mWindow}${mHelp}</div>
    ${rules([
      `菜单 / 右键菜单 / Ctrl K / 快捷键页共用一张动作表（id · 文案 · 键位 · 可用判据），改一处处处变`,
      '不可用的灰着不藏，悬停说原因；「新」= 第二批的动作，接上之前一直灰着，不挂死交互',
      '点标签开，开着时划到相邻标签直接换开；←→ ↑↓ ↵ Esc。Esc 先关菜单——全局顺序：菜单 > @ 弹层 > 查找条 > 框选进行中 > 工具锁 > 清空选中',
      'Windows：只有单独按下再松开 Alt、期间没有别的键或指针动作，才聚焦菜单栏；不做 Alt+字母助记键——Alt A/D/W/S/H/V 对齐、Alt Shift H/V 分布、Alt+拖切线都归画布',
      `标签移出 ${code('DragToMoveArea')}：它的双击判定会让每次单击等 300ms（shell_chrome 头注）`,
      '重做：动作表只有一个主键，Windows 显示 Ctrl Y，macOS 显示 ⇧⌘Z；菜单、快捷键页、撤销卡显示同一个',
      `新建节点 › 列全部可建类型，叫法与工具条 / 新建菜单 / 节点库同一份：图像配置 · 视频配置 · 文本 · 镜头 · 便签 · 泳道；工具条的 ${code('canvasToolShotNode')}「分镜节点」改叫「镜头节点」`,
      '泳道… F 永远开新建泳道对话框，不看选中；把选中包成泳道走节点菜单「包成泳道」Ctrl G',
      '画布 / 节点两组只在画布标签可用；节点菜单的对象 = 当前选中集，与节点右键菜单同一判据；多选时「生成」= 批量生成，确认与上限只按 TakesCost 的规则',
      '帮助 = 左栏帮助弹层同一组动作 + 快捷键；有新版本时「检查更新…」换成「有新版本 x.y.z · 下载」，帮助键同时挂琥珀点',
      `macOS 用系统菜单栏 ${code('PlatformMenuBar')}（同一张表），chrome 不画这六个标签；关于 / 设置 / 退出进「InkFrame」应用菜单，键位显示 ⌘ ⌥ ⇧`,
    ], 'margin-top: 12px')}
  </div>`;

// ---- 系统通知 ----
const sysToast = `
  <div style="width: 290px; box-sizing: border-box; padding: 12px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 8px; box-shadow: 0 16px 40px rgba(0,0,0,0.5)">
    <div style="display: flex; align-items: center; gap: 6px">
      <div style="width: 14px; height: 14px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 8px; font-weight: 700; display: flex; align-items: center; justify-content: center">If</div>
      <div style="font-size: 11px; color: ${T.fg4}; flex: 1">InkFrame</div>
      <div style="font-size: 10px; color: ${T.fg6}">现在</div>
      <div style="color: ${T.fg5}; display: flex">${ic('close', 14)}</div>
    </div>
    <div style="display: flex; gap: 10px; margin-top: 10px">
      <img src="${IMG.thumbWide}" alt="" style="width: 48px; height: 48px; flex: none; object-fit: cover; border-radius: 4px">
      <div style="min-width: 0">
        <div style="font-weight: 500; color: ${T.fg1}">镜头 02 · 视频已生成</div>
        <div style="font-size: 11px; color: ${T.fg4}">万相 2.2 · 图生视频 · 用时 1:12</div>
        <div style="font-size: 10px; color: ${T.fg5}">示例项目 · 画布 1</div>
      </div>
    </div>
    <div style="margin-top: 10px; height: 26px; border-radius: 4px; background: ${T.s5}; display: flex; align-items: center; justify-content: center; font-size: 11px; color: ${T.fg2}">查看</div>
  </div>`;
const toggleOn = `<div style="width: 28px; height: 16px; border-radius: 8px; background: ${T.accent}; position: relative; flex: none"><div style="position: absolute; right: 2px; top: 2px; width: 12px; height: 12px; border-radius: 6px; background: ${T.onAccent}"></div></div>`;
const sysSetting = `
  <div style="width: 290px; box-sizing: border-box; border: 1px solid ${T.outline}; border-radius: 4px; background: ${T.s3}; padding: 9px 12px">
    <div style="display: flex; align-items: center; gap: 8px"><div style="flex: 1; color: ${T.fg2}">系统通知 <span style="font-size: 10px; color: ${T.fg6}">设置 › 常规 › 通知</span></div>${toggleOn}</div>
    <div style="font-size: 10.5px; color: ${T.fg5}; line-height: 1.5; margin-top: 4px">窗口不在前台时，跑了 10 秒以上的生成或导出做完，发一条系统通知。</div>
  </div>`;
const sysSec = `
  <div>
    ${h3('系统通知', '窗口在后台或最小化时提醒；左为 Windows 通知中心，macOS 横幅同内容')}
    <div style="display: flex; gap: 16px; align-items: flex-start">
      <div style="width: 290px; flex: none">
        ${sysToast}
        <div style="height: 8px"></div>
        ${sysSetting}
      </div>
      ${rules([
        '三个条件同时满足才发：卡片带 chime（后台事件）· 窗口不在前台 · 任务用时 ≥ 10 秒；失败也发',
        `前台判据复用 ${code('ToastCenter.setWindowActive')}`,
        '点通知 = 窗口还原并聚焦 + 执行卡片主按钮（查看 → 定位节点，导出 → 打开文件夹）',
        '窗口里的卡照出、照进铃铛；2 秒内连着完成的合成一条',
        '「用时」与任务弹层同一个格式函数（见下）',
        `需新依赖 ${code('local_notifier')}（window_manager 同作者）；Windows 要开始菜单快捷方式带 AppUserModelID，macOS 首次开启时请求权限，被拒就在开关下写「系统里已关闭」`,
      ], 'flex: 1; min-width: 0')}
    </div>
  </div>`;

// ---- F6 跳进通知区 ----
const miniCard = (thumb, title, body, btn, focused) => `
  <div style="position: relative; width: 290px; box-sizing: border-box; display: flex; gap: 10px; padding: 9px 10px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; ${focused ? `outline: 2px solid ${T.accent}; outline-offset: 1px;` : ''}">
    ${thumb ? `<img src="${thumb}" alt="" style="width: 32px; height: 32px; flex: none; object-fit: cover; border-radius: 3px">` : `<div style="width: 32px; height: 32px; flex: none; border-radius: 3px; background: ${T.s5}; color: ${T.danger}; display: flex; align-items: center; justify-content: center">${ic('error', 16)}</div>`}
    <div style="flex: 1; min-width: 0">
      <div style="font-size: 11.5px; font-weight: 500; color: ${T.fg1}">${title}</div>
      <div style="font-size: 10.5px; color: ${T.fg4}">${body}</div>
    </div>
    <div style="align-self: flex-end; height: 20px; padding: 0 8px; border-radius: 3px; background: ${focused ? T.accent : 'transparent'}; border: 1px solid ${focused ? T.accent : T.controlStrong}; color: ${focused ? T.onAccent : T.fg3}; font-size: 10.5px; display: flex; align-items: center">${btn}</div>
  </div>`;
const keyChip = (k, v) => `<span style="display: inline-flex; align-items: center; gap: 4px; margin-right: 10px"><span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg2}; padding: 0 4px; border: 1px solid ${T.controlStrong}; border-radius: 3px">${k}</span><span style="font-size: 10.5px; color: ${T.fg4}">${v}</span></span>`;
const f6Sec = `
  <div>
    ${h3('F6 跳到通知区', '键盘也能处理通知，不抢焦点')}
    <div style="display: flex; gap: 16px; align-items: flex-start">
      <div style="width: 290px; flex: none; display: flex; flex-direction: column; gap: 6px">
        ${miniCard('', '镜头 04 生成失败', '可灵 · 余额不足', '重试', false)}
        ${miniCard(IMG.thumbMountain, '镜头 01 已生成', 'Gemini · 图像 · 用时 18 秒', '查看', true)}
        <div style="margin-top: 4px; line-height: 2">${keyChip('↑↓', '切换')}${keyChip('↵', '主按钮')}${keyChip('Tab', '卡内按钮')}${keyChip('Del', '关掉')}${keyChip('Esc', '离开')}</div>
      </div>
      ${rules([
        '应用级快捷键，与 Ctrl K 同层；输入框里也有效',
        '进来聚焦最新一张，全部停表（同悬停）；离开后接着走',
        '「还有 N 条」也是一站，↵ 打开铃铛；没有卡时 F6 直接开铃铛、聚焦第一条',
        'Esc 或再按 F6：焦点回到进来前的位置',
        '读屏：进来播报「通知，2 条」，每张读「类型 · 标题 · 正文」',
      ], 'flex: 1; min-width: 0')}
    </div>
  </div>`;

// ---- 任务弹层：耗时 ----
const taskRow = (title, meta, timeTxt, act, pct, metaColor = T.fg5) => `
  <div style="padding: 8px 12px; border-bottom: 1px solid ${T.bSubtle}">
    <div style="display: flex; align-items: center; gap: 8px"><div style="flex: 1; color: ${T.fg2}">${title}</div><span style="font-size: 11px; color: ${act === '定位' ? T.accent : T.fg4}">${act}</span></div>
    <div style="display: flex; gap: 6px; font-size: 10px; color: ${metaColor}; margin-top: 1px"><span>${meta}</span><span style="font-family: ${MONO}; color: ${T.fg3}">${timeTxt}</span></div>
    ${pct != null ? `<div style="height: 3px; border-radius: 2px; background: ${T.control}; margin-top: 6px; overflow: hidden"><div style="height: 3px; width: ${pct}%; background: ${T.accent}"></div></div>` : ''}
  </div>`;
const taskSec = `
  <div>
    ${h3('任务弹层显示耗时', '状态栏胶囊点开的那一层')}
    <div style="display: flex; gap: 16px; align-items: flex-start">
      <div style="width: 290px; flex: none; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6)">
        <div style="height: 30px; display: flex; align-items: center; padding: 0 12px; border-bottom: 1px solid ${T.bStrong}"><div style="font-weight: 500; color: ${T.fg1}">任务</div><div style="flex: 1"></div><div style="font-size: 11px; color: ${T.fg5}">并发 2</div></div>
        ${taskRow('镜头 02 · 视频', '万相 2.2 · 已用', '1:12', '取消', 62)}
        ${taskRow('镜头 03 · 图像', 'Gemini · 排队', '8 秒', '取消', null)}
        ${taskRow('镜头 04 · 视频', '可灵 · 失败 · 用时', '2:03', '定位', null, T.danger)}
      </div>
      ${rules([
        '进行中：已用 = 现在 − 提交；排队：现在 − 入队。弹层开着才每秒刷新',
        '终态：用时 = 完成 − 提交（不算排队）',
        `一个格式函数（${code('formatElapsed')}，纯函数）：不到 60 秒写「N 秒」，满 60 秒写 m:ss；任务弹层、通知卡、系统通知都用它`,
        `JobQueueService 在写 ${code('submitted_at')} / ${code('completed_at')} 处同时记时刻，进 jobId → JobTiming 旁表；不改 JobState（freezed 生成件，build_runner 卡点）`,
        '系统通知的 ≥ 10 秒读同一张表',
      ], 'flex: 1; min-width: 0')}
    </div>
  </div>`;

// ---- 导出第二批（右列，宽 580）----
const fmtRow = (icon, name, sub, o = {}) => `
  <div style="display: flex; align-items: center; gap: 8px; height: 32px; padding: 0 8px; border-radius: 4px; ${o.on ? `background: ${T.s5};` : ''} color: ${o.dis ? T.fg6 : T.fg2}">
    <div style="display: flex; color: ${o.dis ? T.fg6 : T.fg4}">${ic(icon, 16)}</div>
    <div style="flex: 1; min-width: 0"><div style="font-size: 11.5px; white-space: nowrap">${name}</div><div style="font-size: 9.5px; color: ${T.fg6}; white-space: nowrap">${sub}</div></div>
    ${o.neu ? newTag : ''}${o.soon ? soonTag : ''}
  </div>`;
const histRow = (icon, file, sub, when, act, o = {}) => `
  <div style="display: flex; align-items: center; gap: 8px; height: 32px; padding: 0 10px; border-bottom: 1px solid ${T.bSubtle}">
    <div style="display: flex; color: ${o.err ? T.danger : T.fg4}">${ic(icon, 14)}</div>
    <div style="flex: 1; min-width: 0"><div style="font-family: ${MONO}; font-size: 10.5px; color: ${o.gone ? T.fg6 : T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; ${o.gone ? 'text-decoration: line-through;' : ''}">${file}</div><div style="font-size: 9.5px; color: ${o.err ? T.danger : T.fg5}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${sub}</div></div>
    <div style="font-size: 10px; color: ${T.fg5}; width: 58px; text-align: right">${when}</div>
    <div style="font-size: 10.5px; color: ${T.accent}; width: 56px; text-align: right">${act}</div>
  </div>`;
const exportTab = `
  <div style="width: 580px; height: 190px; box-sizing: border-box; display: flex; background: ${T.s1}; border: 1px solid ${T.outline}; border-radius: 4px; overflow: hidden">
    <div style="width: 170px; flex: none; box-sizing: border-box; padding: 6px 6px; border-right: 1px solid ${T.bStrong}; background: ${T.s3}">
      <div style="font-size: 10px; color: ${T.fg5}; padding: 0 8px 4px">新导出</div>
      ${fmtRow('export', '拼接视频', 'mp4 · 现有对话框', { on: true })}
      ${fmtRow('sequence', '交付包', 'EDL + 媒体 · 序列标签')}
      ${fmtRow('script', '分镜 PDF', '每页 6 镜', { neu: true })}
      ${fmtRow('imageConfig', '图片 ZIP', '每镜选定产物', { neu: true })}
      ${fmtRow('more', '剪映草稿', 'FCPXML 同', { soon: true, dis: true })}
    </div>
    <div style="flex: 1; min-width: 0">
      <div style="height: 30px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border-bottom: 1px solid ${T.bStrong}">
        <div style="font-weight: 500; color: ${T.fg1}">导出历史</div><div style="flex: 1"></div>
        <span style="font-size: 10.5px; color: ${T.fg1}; padding: 0 7px; height: 18px; line-height: 18px; border-radius: 9px; background: ${T.s5}">全部</span><span style="font-size: 10.5px; color: ${T.fg4}">本画布</span>
      </div>
      ${histRow('export', '示例项目_画布1.mp4', '画布 1 · 8 镜 · 00:42 · 38.2 MB', '今天 14:20', '打开文件夹')}
      ${histRow('sequence', '示例项目.edl + 8 mp4', '交付 · Resolve · 1 处占位', '今天 11:05', '打开文件夹')}
      ${histRow('script', '分镜_画布1.pdf', '文件不在了', '昨天', '重新导出', { gone: true })}
      ${histRow('error', '示例项目_画布2.mp4', '失败 · 找不到 ffmpeg', '昨天', '重试', { err: true })}
      <div style="height: 26px; display: flex; align-items: center; padding: 0 10px; font-size: 10px; color: ${T.fg6}">右键一行：打开文件 · 复制路径 · 从历史移除（不删文件）</div>
    </div>
  </div>`;
const dvTabs = (active) => `<div style="height: 26px; display: flex; border-bottom: 1px solid ${T.bStrong}">${['交付', '片段', '历史'].map((t) => `<div style="width: 64px; display: flex; align-items: center; justify-content: center; font-size: 11px; color: ${t === active ? T.fg1 : T.fg5}; ${t === active ? `box-shadow: inset 0 -2px 0 ${T.accent};` : ''}">${t}</div>`).join('')}</div>`;
const clipRow = (idx, thumb, name, file, tc, warn = '') => `
  <div style="display: flex; align-items: center; gap: 8px; height: 30px; padding: 0 10px; border-bottom: 1px solid ${T.bSubtle}">
    <span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}; width: 22px">${idx}</span>
    ${thumb ? `<img src="${thumb}" alt="" style="width: 36px; height: 20px; object-fit: cover; border-radius: 2px; flex: none">` : `<div style="width: 34px; height: 18px; flex: none; border-radius: 2px; border: 1px dashed ${T.washBorder}"></div>`}
    <div style="flex: 1; min-width: 0"><div style="font-size: 11px; color: ${T.fg2}; white-space: nowrap">${name}</div><div style="font-family: ${MONO}; font-size: 9px; color: ${warn ? T.accent : T.fg6}; white-space: nowrap">${warn || file}</div></div>
    <span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg4}">${tc}</span>
  </div>`;
const panelBox = (inner) => `<div style="width: 320px; box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.outline}; border-radius: 4px; overflow: hidden">${inner}</div>`;
const clipsPanel = panelBox(`${dvTabs('片段')}
  ${clipRow('001', IMG.thumbMountain, '镜头 01 山脊远景', '001_镜头01.mp4', '00:05:00')}
  ${clipRow('002', IMG.thumbWide, '镜头 02 推近', '002_镜头02.mp4', '00:04:12')}
  ${clipRow('003', '', '镜头 03', '', '00:03:00', '无产物 → 空隙 + 标记')}`);
const histPanel = panelBox(`${dvTabs('历史')}
  <div style="display: flex; align-items: center; gap: 8px; height: 30px; padding: 0 10px; border-bottom: 1px solid ${T.bSubtle}"><div style="flex: 1; font-size: 11px; color: ${T.fg2}">今天 11:05 · Resolve · 8 镜</div><span style="font-size: 10.5px; color: ${T.accent}">打开文件夹</span></div>
  <div style="display: flex; align-items: center; gap: 8px; height: 30px; padding: 0 10px; border-bottom: 1px solid ${T.bSubtle}"><div style="flex: 1; font-size: 11px; color: ${T.fg2}">昨天 18:40 · Premiere · 7 镜</div><span style="font-size: 10.5px; color: ${T.accent}">打开文件夹</span></div>
  <div style="height: 24px; display: flex; align-items: center; padding: 0 10px; font-size: 10px; color: ${T.fg4}">全部导出历史 → 导出标签</div>`);
const exportSec = `
  <div>
    ${h3('导出第二批', '导出标签 = 新导出 + 历史；序列标签的交付面板补上「片段」「历史」')}
    ${exportTab}
    ${rules([
      `需新表 ${code('export_records')}（新增一条前向迁移，落地时按合入顺序编号）：kind（mp4 / delivery / pdf / zip）· 文件 · 镜数 · 时长 · 大小 · status · 设置快照 · created_at`,
      '三条路径（导出对话框 / 交付 / PDF·ZIP）完成或失败各记一行，取消不记；文件不在了就划掉，只给「重新导出」',
      `分镜 PDF：每页 6 镜（缩略图 · 镜号 · 景别运镜 · 时长 · 提示词摘要），需新依赖 ${code('pdf')} + 中文字体；图片 ZIP：每镜选定产物 + metadata.json，用现成 ${code('archive')}`,
      `剪映草稿 / FCPXML 灰着写「待支持」：可选性只问 ${code('DeliveryWriterRegistry')}，接上写出器当场可选；EDL 已有`,
    ], 'margin-top: 8px')}
    <div style="display: flex; gap: 16px; align-items: flex-start; margin-top: 12px">
      <div style="width: 320px; flex: none; display: flex; flex-direction: column; gap: 8px">
        ${clipsPanel}
        ${histPanel}
      </div>
      ${rules([
        `片段 = ${code('deliveryPlanProvider')} 的镜头表，与主按钮同源、只读；占位 / 尺寸不一致取自交付前检查`,
        '点一行 = 播放头跳到那一镜',
        '历史 = export_records 里本画布的交付行；结果条仍只回执最近一次',
      ], 'flex: 1; min-width: 0')}
    </div>
  </div>`;

// ---- 需要你定（左列底部，2×2）----
const q = (title, opts, rec) => `
  <div style="padding: 5px 0; border-top: 1px solid ${T.washBorder}">
    <div style="font-size: 11.5px; font-weight: 500; color: ${T.fg1}">${title}</div>
    <div style="font-size: 10.5px; color: ${T.fg3}; line-height: 1.5; margin-top: 2px">${opts}</div>
    <div style="font-size: 10.5px; color: ${T.accent}; line-height: 1.5">${rec}</div>
  </div>`;
const decide = `
  <div style="box-sizing: border-box; padding: 10px 12px 6px; background: ${T.wash}; border: 1px solid ${T.washBorder}; border-radius: 6px">
    <div style="font-weight: 500; color: ${T.accent}; margin-bottom: 4px">需要你定</div>
    <div style="display: grid; grid-template-columns: 1fr 1fr; column-gap: 16px">
      ${q('Q1 系统通知要不要出声？', 'A 系统通知静音，照常响 InkFrame 提示音 · B 只响系统的 · C 两个都响', '建议 A：声音只听「提示音」设置，不会一次响两声')}
      ${q('Q2 导出 / 交付进不进任务弹层？', 'A 进，作为另一类行，只在内存不落 jobs 表 · B 不进，只看进度卡', '建议 A：长任务都在一处看、一处取消')}
      ${q('Q3 导出历史留多久？', 'A 一直留，用户手动移除 · B 只留最近 50 条 · C 跟 jobs 一样按天数清', '建议 A：一行很小，清掉就没法「重新导出」')}
      ${q('Q4 分镜 PDF 的中文字体？', 'A 打包 Noto Sans SC（安装包 +10 MB 量级）· B 运行时嵌入系统字体（雅黑 / 苹方，授权要查）· C 首版只出图和英文字段', '建议 A：两个平台排版一致，授权清楚')}
    </div>
  </div>`;

const leftCol = `<div style="width: 604px; flex: none; display: flex; flex-direction: column; gap: 18px">${menusCol}${decide}</div>`;
const rightCol = `<div style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 14px">${sysSec}${f6Sec}${taskSec}${exportSec}</div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="position: absolute; left: 32px; top: 24px; display: flex; align-items: baseline; gap: 14px">
    <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">外壳菜单、系统通知与导出 · 第二批</div>
    <div style="color: ${T.fg4}">菜单栏真能点；后台做完会叫你；导出有历史、有更多格式</div>
  </div>
  <div style="position: absolute; left: 32px; right: 32px; top: 64px; display: flex; gap: 32px; align-items: flex-start">
    ${leftCol}
    ${rightCol}
  </div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'ShellExport.dc.html', html: page('外壳菜单与导出', W, H, body, logic) };
