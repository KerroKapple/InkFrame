// 第二批补漏画板：面板与通知（舞台以外的 MISSING 项，1280×H，静态）
// 依据：settings/widgets/notifications_section.dart + notifications/models/notification_prefs.dart（现有只有提示音 / 停留时长）·
// core/interfaces/toast_service.dart（ToastKind 六种，无「生成 / 导出」之分）· notifications/widgets/toast_layer.dart（right: md, bottom: 状态栏高）·
// core/models/app_preferences.dart（preferences.json 字符串字段）· canvas/providers/left_rail_state.dart（LeftRailPanel.width = 241 常量）·
// canvas_inspector_panel.dart（width 301，不可收）· left_rail/outline_panel.dart（行只有 onTap）· util/narrative_order.dart（链序 = 边，sortOrder 只排兄弟）·
// canvas/models/character.dart（无 kind 列）· character_edit_dialog.dart（被引用 chip 不可点）· left_rail/assets_model.dart（chip 只有 全部 / 图片 / 视频）·
// sequence/widgets/sequence_screen.dart（行只有 selectShot）· storyboard/widgets/script_import_dialog.dart（ShotDraft = label + notes）·
// export/widgets/export_video_dialog.dart · fix/demo-inspectors 的 result_inspector_parts.dart / image_ / video_result_inspector.dart（as-built）。
const { T, IMG, SANS, MONO, page, ic, caret } = require('./common.js');

const W = 1280, H = 1400;
const TOP = 60;
const C1 = 270, C2 = 270, C3 = 316, C4 = 312;

// ---- 高度估算（只在构建时打到控制台，不进画板）：CJK 记 1 em、ASCII 记 0.56 em，再加 6% 余量 ----
const strip = (s) => s.replace(/<[^>]+>/g, '').replace(/&[a-z]+;/g, 'x');
const ems = (s) => { let e = 0; for (const ch of strip(s)) e += ch.charCodeAt(0) > 0x2e7f ? 1 : 0.56; return e; };
const nLines = (s, w, f) => Math.max(1, Math.ceil((ems(s) * 1.06) / (w / f)));
const RF = 10.5, RLH = 15.75;
const rulesH = (lines, w) => 8 + lines.reduce((a, l) => a + nLines(l, w - 11, RF) * RLH, 0);

// ---- 共用小件（与 b2_shell.js 同一套语汇）----
const kbd = (k, c = T.fg5) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${c}; white-space: nowrap">${k}</span>`;
const code = (t) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${t}</span>`;
const newTag = `<span style="font-size: 9px; height: 14px; line-height: 14px; padding: 0 4px; border-radius: 7px; border: 1px solid ${T.washBorder}; background: ${T.wash}; color: ${T.accent}; flex: none">新</span>`;
const builtTag = `<span style="font-size: 9px; height: 14px; line-height: 14px; padding: 0 5px; border-radius: 7px; border: 1px solid ${T.outline}; color: ${T.fg4}; flex: none">已实现</span>`;
const mark = (n) => `<span style="display: inline-flex; align-items: center; justify-content: center; width: 13px; height: 13px; border-radius: 7px; background: ${T.danger}; color: ${T.fg1}; font-size: 8.5px; font-weight: 700; flex: none; vertical-align: middle">${n}</span>`;
const rules = (lines) => `<div style="margin-top: 8px; font-size: ${RF}px; color: ${T.fg4}; line-height: 1.5">${lines.map((l) => `<div style="display: flex; gap: 5px"><span style="color: ${T.fg6}">·</span><span>${l}</span></div>`).join('')}</div>`;
const toggle = (on) => `<div style="width: 24px; height: 14px; border-radius: 7px; background: ${on ? T.accent : T.control}; position: relative; flex: none"><div style="position: absolute; ${on ? 'right' : 'left'}: 2px; top: 2px; width: 10px; height: 10px; border-radius: 5px; background: ${on ? T.onAccent : T.fg5}"></div></div>`;
const chip = (label, on = false) => `<span style="display: inline-flex; align-items: center; height: 20px; padding: 0 7px; border-radius: 3px; font-size: 10.5px; white-space: nowrap; ${on ? `background: ${T.accent}; color: ${T.onAccent}; font-weight: 500` : `border: 1px solid ${T.controlStrong}; color: ${T.fg3}; box-sizing: border-box`}">${label}</span>`;
const pillChip = (label, on = false) => `<span style="display: inline-flex; align-items: center; height: 18px; padding: 0 7px; border-radius: 9px; font-size: 10.5px; white-space: nowrap; ${on ? `background: ${T.s5}; color: ${T.fg1}` : `color: ${T.fg4}`}">${label}</span>`;
const menuSep = `<div style="height: 1px; background: ${T.bStrong}; margin: 4px 0"></div>`;
const menu = (inner, width) => `<div style="width: ${width}px; box-sizing: border-box; padding: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6)">${inner}</div>`;
const mi = (icon, label, right = '', o = {}) => `
  <div style="height: 21px; display: flex; align-items: center; gap: 8px; padding: 0 8px; border-radius: 3px; color: ${o.dis ? T.fg6 : T.fg2}; ${o.hot ? `background: ${T.s5};` : ''}">
    <div style="width: 14px; display: flex; color: ${o.dis ? T.fg6 : T.fg4}">${icon ? ic(icon, 14) : ''}</div>
    <div style="flex: 1; white-space: nowrap">${label}</div>${right}
  </div>`;
const thumb = (src, w, h, extra = '') => src
  ? `<img src="${src}" alt="" style="width: ${w}px; height: ${h}px; flex: none; object-fit: cover; border-radius: 2px; outline: 1px solid ${T.outline}; ${extra}">`
  : `<div style="width: ${w}px; height: ${h}px; flex: none; box-sizing: border-box; border-radius: 2px; background: ${T.thumb}; border: 1px solid ${T.outline}; display: flex; align-items: center; justify-content: center; color: ${T.fg6}; ${extra}">${ic('characters', 14)}</div>`;
const panelHead = (title, right = '') => `<div style="height: 28px; display: flex; align-items: center; gap: 8px; padding: 0 12px; border-bottom: 1px solid ${T.bSubtle}"><div style="font-weight: 500; color: ${T.fg1}">${title}</div><div style="flex: 1"></div>${right}</div>`;
const groupHead = (label, count, tint = '') => `<div style="height: 22px; display: flex; align-items: center; gap: 6px; padding: 0 12px; color: ${T.fg5}; font-size: 11px">${tint ? `<span style="width: 8px; height: 8px; border-radius: 2px; background: ${tint}"></span>` : ''}<span>${label}</span><span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">${count}</span></div>`;

// 一节 = 标题 + 样稿（固定高）+ 规则；返回 html 与估计高度
const sec = (w, title, note, mockH, mock, lines) => {
  const noteLines = note ? nLines(note, w, 11) : 0;
  const headH = 18 + noteLines * 16 + 8;
  const html = `
  <div style="width: ${w}px">
    <div style="margin-bottom: 8px"><div style="display: flex; align-items: center; gap: 6px; height: 18px"><div style="font-weight: 500; color: ${T.fg1}">${title}</div></div>${note ? `<div style="font-size: 11px; color: ${T.fg5}; line-height: 16px">${note}</div>` : ''}</div>
    <div style="position: relative; height: ${mockH}px">${mock}</div>
    ${rules(lines)}
  </div>`;
  return { html, h: headH + mockH + rulesH(lines, w), title };
};

// ======================= 1 通知：按类型开关 + 位置 =======================

const notifRow = (label, desc, on) => `<div style="height: 24px; display: flex; align-items: center; gap: 8px"><div style="color: ${T.fg2}; flex: none">${label}</div><div style="flex: 1; min-width: 0; font-size: 10px; color: ${T.fg6}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${desc}</div>${toggle(on)}</div>`;
const cornerGlyph = `
  <div style="position: relative; width: 56px; height: 38px; flex: none; box-sizing: border-box; border: 1px solid ${T.controlStrong}; border-radius: 3px; background: ${T.s1}">
    <div style="position: absolute; left: 0; right: 0; top: 0; height: 5px; background: ${T.s4}; border-radius: 2px 2px 0 0"></div>
    <div style="position: absolute; left: 3px; top: 8px; width: 12px; height: 6px; border-radius: 1px; background: ${T.control}"></div>
    <div style="position: absolute; right: 3px; top: 8px; width: 12px; height: 6px; border-radius: 1px; background: ${T.control}"></div>
    <div style="position: absolute; left: 3px; bottom: 3px; width: 12px; height: 6px; border-radius: 1px; background: ${T.control}"></div>
    <div style="position: absolute; right: 3px; bottom: 3px; width: 12px; height: 6px; border-radius: 1px; background: ${T.accent}"></div>
  </div>`;
const notifMock = `
  <div style="font-weight: 500; color: ${T.fg1}; height: 18px">通知 <span style="font-size: 10px; font-weight: 400; color: ${T.fg6}">设置 › 常规</span></div>
  <div style="margin-top: 4px; box-sizing: border-box; padding: 10px 12px; background: ${T.s3}; border: 1px solid ${T.control}; border-radius: 4px">
    <div style="height: 18px; display: flex; align-items: center; gap: 6px; color: ${T.fg5}; font-size: 11px">提示音 · 停留时长<span style="font-size: 10px; color: ${T.fg6}">现有，不变</span></div>
    <div style="height: 1px; background: ${T.bSubtle}; margin: 8px 0"></div>
    <div style="height: 18px; display: flex; align-items: center; gap: 6px; color: ${T.fg4}">显示哪些通知 ${newTag}</div>
    <div style="margin-top: 2px">
      ${notifRow('生成完成', '缩略图 + 查看', true)}
      ${notifRow('导出完成', '打开文件夹', true)}
      ${notifRow('失败', '只管后台任务', true)}
      ${notifRow('撤销', '关了 Ctrl Z 照样能撤', true)}
      ${notifRow('一般提示', '已复制 · 已保存', false)}
    </div>
    <div style="height: 18px; display: flex; align-items: center; gap: 6px; color: ${T.fg4}; margin-top: 8px">位置 ${newTag}</div>
    <div style="display: flex; gap: 10px; align-items: flex-start; margin-top: 4px; height: 44px">
      ${cornerGlyph}
      <div style="display: flex; flex-wrap: wrap; gap: 4px">${chip('跟随系统', true)}${chip('右下')}${chip('右上')}${chip('左下')}${chip('左上')}</div>
    </div>
    <div style="font-size: 10px; color: ${T.fg6}; height: 16px">跟随系统 = Windows 右下 · macOS 右上（N2）</div>
    <div style="font-size: 10px; color: ${T.fg6}; height: 16px">下面接「系统通知」开关（ShellExport），不变</div>
  </div>`;
const s1 = sec(C1, '通知：按类型开关 · 位置', '设置 › 常规 › 通知，接在提示音 / 停留时长下面', 330, notifMock, [
  `新增 ${code('ToastCategory')}，调用处标，不从 ToastKind 推（同是 success，「已生成」与「已复制」要分开管）`,
  '任务监听标生成完成 / 失败；导出、交付标导出完成 / 失败；undo 卡归撤销；其余一般',
  '关掉 = 不出卡、不响、不发系统通知（铃铛见 N1）；进度卡带「取消」，不受开关管',
  `存 preferences.json：${code('toastMuted')} + ${code('toastCorner')}，同 toastDwell 的字符串 → 枚举，不动库`,
  '上角：最新贴角向下长，让开 40 标题栏、43 导航条；改了在场的卡当场平移过去，不重计时',
]);

// ======================= 2 面板调宽 · 收起全部 =======================
const schematic = (withPanels) => `
  <div style="position: relative; width: 128px; height: 70px; box-sizing: border-box; display: flex; border: 1px solid ${T.outline}; border-radius: 3px; overflow: hidden; background: ${T.s1}">
    <div style="width: 8px; flex: none; background: ${T.s4}; border-right: 1px solid ${T.bStrong}"></div>
    ${withPanels ? `<div style="position: relative; width: 38px; flex: none; background: ${T.s3}">
      <div style="margin: 6px 4px 0; height: 3px; background: ${T.control}; border-radius: 1px"></div>
      <div style="margin: 4px 4px 0; height: 3px; width: 20px; background: ${T.control}; border-radius: 1px"></div>
      <div style="margin: 4px 4px 0; height: 3px; width: 24px; background: ${T.control}; border-radius: 1px"></div>
      <div style="position: absolute; right: 0; top: 0; bottom: 0; width: 2px; background: ${T.accent}"></div>
    </div>` : ''}
    <div style="flex: 1; background-image: radial-gradient(${T.grid} 1px, transparent 1px); background-size: 8px 8px"></div>
    ${withPanels ? `<div style="width: 28px; flex: none; background: ${T.s3}; border-left: 1px solid ${T.bStrong}"></div>` : ''}
    ${withPanels ? `<div style="position: absolute; left: 34px; top: 28px; height: 14px; padding: 0 4px; border-radius: 3px; background: ${T.s5}; border: 1px solid ${T.overlayBorder}; font-family: ${MONO}; font-size: 9px; color: ${T.fg1}; display: flex; align-items: center">↔ 280</div>` : ''}
  </div>`;
const panelsMock = `
  <div style="display: flex; gap: 14px">
    <div>${schematic(true)}<div style="font-size: 10px; color: ${T.fg5}; margin-top: 3px">拖左面板右沿</div></div>
    <div>${schematic(false)}<div style="font-size: 10px; color: ${T.fg5}; margin-top: 3px">${kbd('Ctrl Shift \\', T.fg4)} 收起全部</div></div>
  </div>`;
const s2 = sec(C3, '面板调宽 · 收起全部面板', '', 92, panelsMock, [
  `左面板右沿 6px 热区（看上去仍是 1px 线），悬停变 2px accent；内容宽 200–420，默认 240，双击回默认；松手才落盘，全局记一个 ${code('leftPanelWidth')}（preferences.json）`,
  '舞台至少留 480：窗口变窄先压检查器、再压左面板，仍不够自动收起左面板（记住的宽度不动）',
  `${kbd('Ctrl Shift \\', T.fg3)} / ${kbd('⌘⇧\\', T.fg3)}：左面板 + 检查器一起收，43 导航条留着；再按恢复收起前各自的开合。检查器要新增 ${code('inspectorExpanded')}（同 leftRailProvider 不 autoDispose）；${kbd('Ctrl \\', T.fg3)} 仍只管左面板`,
]);

// ======================= 3 大纲行：改名 · 右键 · 拖动排序 =======================

const oRow = (num, src, name, sub, right, o = {}) => `
  <div style="height: 38px; display: flex; align-items: center; gap: 8px; padding: 0 12px; ${o.sel ? `background: ${T.s5};` : ''} ${o.dashed ? `margin: 0 6px; padding: 0 6px; border: 1px dashed ${T.control}; border-radius: 3px; box-sizing: border-box; opacity: 0.45;` : ''}">
    <span style="width: 16px; font-family: ${MONO}; font-size: 10px; color: ${o.sel ? T.accent : T.fg5}">${num}</span>
    ${thumb(src, 40, 23)}
    <div style="flex: 1; min-width: 0">${o.edit ? `<div style="height: 20px; box-sizing: border-box; border: 1px solid ${T.accent}; border-radius: 3px; background: ${T.s1}; display: flex; align-items: center; padding: 0 5px"><span style="background: ${T.washBorder}; color: ${T.fg1}">雾中老人</span><span style="width: 1px; height: 12px; background: ${T.fg1}; margin-left: 1px"></span></div>` : `<div style="color: ${o.sel ? T.fg1 : T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${name}</div><div style="font-size: 9.5px; color: ${T.fg6}">${sub}</div>`}</div>
    ${right}
  </div>`;
const okIcon = `<div style="color: ${T.success}; display: flex">${ic('success', 14)}</div>`;
const outlineMock = `
  <div style="position: relative; width: 241px; height: 232px; box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.bStrong}; overflow: hidden">
    ${panelHead('大纲', `<span style="font-size: 10.5px; color: ${T.fg3}; display: flex; align-items: center; gap: 4px">画布 1 ${caret()}</span>`)}
    ${groupHead('水墨风格', '3 镜', T.teal)}
    ${oRow('01', IMG.thumbMountain, '山脊远景', '图像配置', okIcon)}
    <div style="position: relative; height: 2px; margin: 1px 12px; background: ${T.accent}"><div style="position: absolute; left: -3px; top: -2px; width: 6px; height: 6px; border-radius: 3px; background: ${T.accent}"></div></div>
    ${oRow('02', IMG.thumbWide, '', '', okIcon, { sel: true, edit: true })}
    ${oRow('03', '', '两人对视', '视频配置', '', { dashed: true })}
    ${groupHead('未分泳道', '1 镜')}
    ${oRow('04', '', '收尾远景', '图像配置', `<span style="font-size: 10px; color: ${T.fg6}">就绪</span>`)}
    <div style="position: absolute; left: 30px; top: 80px; width: 196px; height: 34px; box-sizing: border-box; display: flex; align-items: center; gap: 8px; padding: 0 8px; background: ${T.s5}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 10px 24px rgba(0,0,0,0.55)">
      <span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}">03</span>${thumb('', 34, 19)}<span style="color: ${T.fg1}">两人对视</span>
    </div>
  </div>`;
const s3 = sec(C2, '大纲行：改名 · 右键 · 拖动排序', '', 232, outlineMock, [
  '双击 = 就地改名（↵ / 失焦存，Esc 放弃，清空回类型名），写 nodes.label，一步撤销',
  `右键 = 节点右键菜单原样（同一份 ${code('node_menu_model')}）`,
  '拖行改叙事序（图中 02 在改名、03 正拖到 01 后）：只能在本组里放，越组禁止并回弹（O1）；未入链、产物、生成中的行不能拖',
  '落下改的是叙事边：摘出、前后接上、插进新位置——与「拖到线上插入」同一套边操作，一个事务；只有同一分叉下兄弟换序才改 sortOrder',
]);

// ======================= 4 角色：按类型分组 · 被引用可点 =======================
const cRow = (src, name, meta, hotRef = false) => `
  <div style="height: 36px; display: flex; align-items: center; gap: 8px; padding: 0 12px">
    ${thumb(src, 28, 28)}
    <div style="flex: 1; min-width: 0"><div style="color: ${T.fg3}">${name}</div><div style="font-size: 9.5px; color: ${T.fg6}">${meta.split('|')[0]}<span style="${hotRef ? `color: ${T.accent}; text-decoration: underline` : ''}">${meta.split('|')[1]}</span></div></div>
    <div style="color: ${T.fg5}; display: flex">${ic('more', 14)}</div>
  </div>`;
const refChip = (label, hot = false) => `<span style="display: inline-flex; align-items: center; gap: 4px; height: 22px; box-sizing: border-box; padding: 0 8px; border-radius: 3px; border: 1px solid ${hot ? T.washBorder : T.controlStrong}; background: ${hot ? T.wash : 'transparent'}; color: ${hot ? T.accent : T.fg3}; font-size: 10.5px; white-space: nowrap">${label}${hot ? ' ↗' : ''}</span>`;
const charMock = `
  <div style="width: 241px; box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.bStrong}">
    ${panelHead('角色', `<span style="color: ${T.fg5}; display: flex">${ic('search', 14)}</span>`)}
    ${groupHead('角色', '2')}
    ${cRow(IMG.thumbMountain, '阿青', '3 张参考图 · |4 处引用', true)}
    ${groupHead('物品', '1')}
    ${cRow('', '青铜灯', '2 张参考图 · |没有引用')}
    ${groupHead('场景', '1')}
    ${cRow(IMG.thumbWide, '雾中山脊', '1 张参考图 · |2 处引用')}
  </div>
  <div style="width: 241px; box-sizing: border-box; margin-top: 8px; padding: 6px 10px 8px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px">
    <div style="font-size: 11px; color: ${T.fg4}; height: 16px">被引用 <span style="font-size: 10px; color: ${T.fg6}">编辑框里，点了去那个节点</span></div>
    <div style="display: flex; gap: 4px; margin-top: 4px">${refChip('画布 1 · 镜头 01', true)}${refChip('画布 2 · 镜头 04')}</div>
  </div>`;
const s4 = sec(C2, '角色：按类型分组 · 被引用可点', '', 272, charMock, [
  `characters 加列 ${code('kind')}（character / prop / scene，默认 character）：新增一条前向迁移；项目包照带`,
  '按 角色 → 物品 → 场景 分组，空组不画；@ 补全同样分组；编辑框加「类型」三段；类型不进提示词（C1）',
  '「被引用」chip 可点：有未存改动先问，关框定位，跨画布先 openCanvas；行上「M 处引用」同样可点',
]);

// ======================= 5 素材：悬停预览 · 导入 =======================
const importBadge = `<span style="position: absolute; left: 4px; top: 4px; height: 14px; line-height: 14px; padding: 0 4px; border-radius: 2px; font-size: 9px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}">导入</span>`;
const tile = (src, label, o = {}) => `
  <div style="width: 105px">
    <div style="position: relative; width: 105px; height: 59px; box-sizing: border-box; border-radius: 3px; overflow: hidden; ${o.hot ? `outline: 2px solid ${T.accent}; outline-offset: 1px;` : `outline: 1px solid ${T.outline};`}">
      <img src="${src}" alt="" style="width: 105px; height: 59px; object-fit: cover; display: block">${o.imp ? importBadge : ''}
    </div>
    <div style="font-size: 9.5px; color: ${T.fg4}; margin-top: 3px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; ${o.mono ? `font-family: ${MONO}` : ''}">${label}</div>
  </div>`;
const assetsMock = `
  <div style="width: 241px; box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.bStrong}; padding-bottom: 8px">
    ${panelHead('素材')}
    <div style="display: flex; gap: 4px; padding: 6px 12px 0">${pillChip('本画布', true)}${pillChip('项目全部')}</div>
    <div style="display: flex; gap: 4px; padding: 6px 12px 0; flex-wrap: nowrap">${pillChip('全部 6', true)}${pillChip('图片 3')}${pillChip('视频 1')}${pillChip('导入 2')}</div>
    <div style="display: flex; gap: 8px; padding: 8px 12px 0">${tile(IMG.thumbMountain, '山脊远景 · take 2')}${tile(IMG.thumbWide, 'ref_山脊.jpg', { imp: true, hot: true, mono: true })}</div>
  </div>
  <div style="position: absolute; left: 96px; top: 112px; width: 174px; box-sizing: border-box; padding: 6px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6)">
    <img src="${IMG.wide}" alt="" style="width: 160px; height: 90px; object-fit: cover; display: block; border-radius: 3px">
    <div style="font-size: 10px; color: ${T.fg4}; margin-top: 5px; line-height: 1.4">导入 · <span style="font-family: ${MONO}; color: ${T.fg3}">ref_山脊.jpg</span><br>1920×1080 · 今天 14:20</div>
  </div>
  <div style="position: absolute; left: 6px; top: 180px; width: 84px; font-size: 9.5px; color: ${T.fg6}; line-height: 1.35">悬停 400ms；实际贴在面板右沿外</div>`;
const s5 = sec(C2, '素材：悬停预览 · 导入的怎么显示', '', 252, assetsMock, [
  '悬停 400ms 出大预览，贴面板右沿外；移开 / 滚动 / 按键即收；视频静音循环前 6 秒',
  '导入的：左上「导入」小标，标签 = 原文件名，没有 take 号',
  `「导入」chip 筛来源，与图片 / 视频互斥；画廊同加；判据只有 ${code('origin == import')}`,
]);

// ======================= 6 序列：在画布中定位并重生成 =======================
const qRow = (idx, src, name, dur, o = {}) => `
  <div style="position: relative; height: 32px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border-bottom: 1px solid ${T.bSubtle}; ${o.sel ? `background: ${T.s5};` : ''}">
    ${o.sel ? `<div style="position: absolute; left: 0; top: 0; bottom: 0; width: 2px; background: ${T.accent}"></div>` : ''}
    <span style="font-family: ${MONO}; font-size: 10px; color: ${o.sel ? T.accent : T.fg5}; width: 22px">${idx}</span>
    ${src ? thumb(src, 36, 20) : `<div style="width: 36px; height: 20px; flex: none; box-sizing: border-box; border-radius: 2px; border: 1px dashed ${T.washBorder}"></div>`}
    <div style="flex: 1; min-width: 0; color: ${o.sel ? T.fg1 : T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${name}</div>
    <span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg4}">${dur}</span>
  </div>`;
const seqMock = `
  <div style="width: 270px; box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.bStrong}">
    <div style="height: 26px; display: flex; align-items: center; padding: 0 10px; border-bottom: 1px solid ${T.bStrong}; font-size: 11px; color: ${T.fg1}">叙事链</div>
    ${qRow('001', IMG.thumbMountain, '镜头 01 山脊远景', '5 秒')}
    ${qRow('002', IMG.thumbWide, '镜头 02 推近', '4 秒', { sel: true })}
    ${qRow('003', '', '镜头 03 两人对视', '3 秒')}
  </div>
  <div style="position: absolute; left: 64px; top: 74px">${menu(`
    ${mi('outline', '在画布中定位')}
    ${mi('run', '在画布中定位并重生成', kbd('约 $0.75', T.fg4), { hot: true })}
    ${menuSep}
    ${mi('sequence', '从这一镜播放')}`, 206)}</div>`;
const s6 = sec(C1, '序列：回画布定位并重生成', '右键 002（叙事链行 / V1 轨片段都行）', 160, seqMock, [
  '定位 = 切到画布、单选这一镜的生成节点、居中（「在序列中定位」的反向）',
  '生成节点 = 当前 take 的来源配置；本身是配置就用它；只有镜头节点时「并重生成」灰：「还没有配置节点」',
  `并重生成 = 定位后走 ${code('submitWithPending')}，与 Ctrl ↵ 同一道闸；不过只定位，检查器写原因`,
  '单个不确认（≥2 个才确认，见 TakesCost）；新 take 按 TakesCost Q2 成为当前，播放头不动',
]);

// ======================= 7 剧本导入对话框 =======================

const castChip = (name, cand = false) => `<span style="display: inline-flex; align-items: center; gap: 4px; height: 20px; box-sizing: border-box; padding: 0 7px; border-radius: 10px; font-size: 10.5px; ${cand ? `border: 1px dashed ${T.washBorder}; color: ${T.accent}` : `background: ${T.s5}; color: ${T.fg2}`}">${ic('characters', 12)}${name}${cand ? ` <span style="font-size: 9.5px; color: ${T.fg5}">新建</span>` : ''}</span>`;
const checkbox = (on) => `<span style="width: 12px; height: 12px; box-sizing: border-box; border-radius: 2px; flex: none; display: inline-flex; align-items: center; justify-content: center; ${on ? `background: ${T.accent};` : `border: 1px solid ${T.controlStrong};`}">${on ? `<svg width="8" height="8" viewBox="0 0 8 8" aria-hidden="true"><path d="M1.5 4.2l1.6 1.6L6.5 2.4" fill="none" stroke="${T.onAccent}" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"></path></svg>` : ''}</span>`;
const pvRow = (n, title, dur, cast) => `
  <div style="height: 26px; display: flex; align-items: center; gap: 8px; border-bottom: 1px solid ${T.bSubtle}">
    <span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}; width: 16px">${n}</span>
    <div style="flex: 1; min-width: 0; color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</div>
    <span style="font-size: 10px; color: ${T.fg5}; white-space: nowrap">${cast}</span>
    <span style="font-size: 10px; color: ${T.fg3}; width: 30px; text-align: right">${dur}</span>
  </div>`;
const scriptMock = `
  <div style="width: ${C4}px; box-sizing: border-box; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6); overflow: hidden">
    <div style="height: 34px; display: flex; align-items: center; padding: 0 12px; border-bottom: 1px solid ${T.bStrong}"><div style="font-weight: 500; color: ${T.fg1}; flex: 1">导入剧本</div><div style="color: ${T.fg4}; display: flex">${ic('close', 14)}</div></div>
    <div style="padding: 10px 12px 0">
      <div style="position: relative; height: 86px; box-sizing: border-box; padding: 6px 8px; background: ${T.s1}; border: 1px solid ${T.controlStrong}; border-radius: 3px; font-size: 11px; line-height: 1.6; color: ${T.fg3}">
        <div>山脊上，阿青回头望。</div>
        <div style="height: 6px"></div>
        <div>雾里走出一个<span style="background: ${T.washBorder}; color: ${T.fg1}">老人</span>，提着一盏灯。</div>
        <div style="height: 6px"></div>
        <div>两人对视，很久没有说话。</div>
        <div style="position: absolute; left: 74px; top: 24px; height: 18px; padding: 0 6px; border-radius: 3px; background: ${T.s5}; border: 1px solid ${T.overlayBorder}; font-size: 10px; color: ${T.fg1}; display: flex; align-items: center; gap: 3px; box-shadow: 0 6px 16px rgba(0,0,0,0.5)">${ic('characters', 11)}设为角色</div>
      </div>
      <div style="display: flex; align-items: center; gap: 6px; height: 22px; margin-top: 8px"><span style="font-size: 11px; color: ${T.fg4}; width: 52px">拆分</span>${chip('空行分段', true)}${chip('每行一镜')}</div>
      <div style="display: flex; align-items: center; gap: 6px; height: 22px; margin-top: 6px"><span style="font-size: 11px; color: ${T.fg4}; width: 52px">角色 ${newTag}</span>${castChip('阿青')}${castChip('老人', true)}</div>
      <div style="display: flex; align-items: baseline; gap: 6px; margin-top: 8px; height: 16px"><span style="font-size: 11px; color: ${T.fg4}">预览</span><span style="font-size: 10.5px; color: ${T.fg3}">3 镜 · 约 9 秒 · 2 个角色（1 个新建）</span></div>
      ${pvRow('01', '山脊上，阿青回头望', '2 秒', '阿青')}
      ${pvRow('02', '雾里走出一个老人，提着一盏灯', '4 秒', '老人')}
      ${pvRow('03', '两人对视，很久没有说话', '3 秒', '')}
      <div style="display: flex; align-items: center; gap: 6px; height: 22px; margin-top: 6px; font-size: 11px; color: ${T.fg3}">${checkbox(true)}把估算时长写进镜头 ${newTag}</div>
    </div>
    <div style="height: 42px; display: flex; align-items: center; justify-content: flex-end; gap: 8px; padding: 0 12px; margin-top: 8px; border-top: 1px solid ${T.bStrong}">
      <span style="height: 24px; padding: 0 12px; border-radius: 3px; border: 1px solid ${T.controlStrong}; color: ${T.fg2}; font-size: 11px; display: flex; align-items: center">取消</span>
      <span style="height: 24px; padding: 0 12px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 11px; font-weight: 500; display: flex; align-items: center">创建 3 个镜头</span>
    </div>
  </div>`;
const s7 = sec(C4, '剧本导入对话框：识别角色 · 估时长', '实物宽 640，左原文右预览；此处按列宽改成上下', 384, scriptMock, [
  '流程不变（粘贴 → 拆分 → 实时预览 → 一个事务建链）；角色与时长都在预览里现算，纯函数，不调 LLM',
  '已有角色名出现 = 实心 chip，导入时挂到这一镜（写镜头节点 character_ids；「用本镜备注生成」要把它带到配置节点，这一步要补）。文本里选中一段 → 「设为角色」→ 虚线候选，勾着的导入时新建成没有参考图的角色（RailScript R1）',
  '估时长：中文 4 字 / 秒、英文 2.5 词 / 秒，最少 2 秒，与剧本面板同一个函数；显示走统一时长格式（不到 60 秒「N 秒」，否则 m:ss）',
  '「把估算时长写进镜头」默认勾（RailScript R3）：写 duration_ms，序列不再每镜默认 3 秒',
  '按钮改「创建 N 个镜头」（统一叫镜头，替掉「创建分镜」）；整次导入一步撤销',
]);

// ======================= 8 导出视频一键 =======================
const exportMock = `
  <div style="width: 270px; height: 30px; box-sizing: border-box; display: flex; align-items: center; justify-content: flex-end; gap: 8px; padding: 0 8px; background: ${T.s1}; border: 1px solid ${T.outline}; border-radius: 3px">
    <span style="font-size: 10.5px; color: ${T.fg4}">在序列中查看</span>
    <div style="height: 22px; display: flex; border-radius: 3px; border: 1px solid ${T.accent}; overflow: hidden">
      <span style="display: flex; align-items: center; gap: 4px; padding: 0 8px; background: ${T.accent}; color: ${T.onAccent}; font-size: 10.5px; font-weight: 500">${ic('export', 12)}导出视频</span>
      <span style="display: flex; align-items: center; padding: 0 5px; background: ${T.accentHover}">${caret(T.onAccent)}</span>
    </div>
  </div>
  <div style="position: absolute; right: 0; top: 36px">${menu(`
    <div style="height: 34px; display: flex; flex-direction: column; justify-content: center; padding: 0 8px; border-radius: 3px; background: ${T.s5}">
      <div style="color: ${T.fg1}">用上次设置导出</div>
      <div style="font-size: 9.5px; color: ${T.fg5}">每镜当前 take · 叙事链序 · 时间戳名</div>
    </div>
    ${mi('', '自定义导出…')}
    ${menuSep}
    ${mi('history', '上次：今天 14:20 · 8 镜 · 42 秒', '', { dis: true })}`, 230)}</div>`;
const s8 = sec(C1, '导出视频：按上次设置一键', '', 136, exportMock, [
  '标签栏、导出标签、⌘K 改分体按钮：主体 = 按上次设置直接导出，▾ = 现有对话框；没导出过主体也开对话框',
  '上次设置 = 本画布最近一次成功导出的规则快照（ShellExport 的 export_records）：每镜当前 take · 顺序 · 文件名规则 · 目录；不记勾选与手动排序',
  '不覆盖同名，自动加「(2)」；预检不过就开对话框、原因放顶上；完成卡归导出完成',
]);

// ======================= 9 产物检查器（已实现，照代码画） =======================

const iRow = (label, value, o = {}) => `<div style="height: 26px; display: flex; align-items: center; padding: 0 12px"><div style="width: 96px; flex: none; color: ${T.fg5}">${label}</div><div style="flex: 1; min-width: 0; display: flex; align-items: center; gap: 4px; color: ${T.fg2}; ${o.mono ? `font-family: ${MONO}; font-size: 11px;` : ''} white-space: nowrap; overflow: hidden">${value}</div></div>`;
const actBtn = (label, icon = '', dim = false) => `<span style="display: inline-flex; align-items: center; gap: 5px; height: 24px; box-sizing: border-box; padding: 0 9px; border-radius: 3px; border: 1px solid ${T.controlStrong}; color: ${T.fg2}; font-size: 11px; white-space: nowrap; ${dim ? 'opacity: 0.5;' : ''}">${icon ? ic(icon, 13) : ''}${label}</span>`;
const playOverlay = `<div style="position: absolute; left: 50%; top: 50%; width: 40px; height: 40px; margin: -20px 0 0 -20px; box-sizing: border-box; border: 2px solid ${T.fg1}; border-radius: 20px; display: flex; align-items: center; justify-content: center"><svg width="14" height="14" viewBox="0 0 14 14" aria-hidden="true"><path d="M4.5 3l6 4-6 4z" fill="${T.fg1}"></path></svg></div>`;
const imgInspector = `
  <div style="width: 301px; box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.bStrong}">
    <div style="height: 30px; display: flex; align-items: flex-end; gap: 16px; padding: 0 12px; border-bottom: 1px solid ${T.bStrong}">
      <div style="height: 28px; display: flex; align-items: center; color: ${T.fg1}; box-shadow: inset 0 -2px 0 ${T.accent}">属性</div>
      <div style="height: 28px; display: flex; align-items: center; color: ${T.fg5}">历史</div>
    </div>
    <div style="height: 48px; box-sizing: border-box; display: flex; align-items: center; gap: 10px; padding: 0 12px; border-bottom: 1px solid ${T.bStrong}">
      <div style="width: 8px; height: 8px; border-radius: 2px; background: ${T.accent}; flex: none"></div>
      <div style="min-width: 0"><div style="font-weight: 500; color: ${T.fg1}">镜头 01 · 图像</div><div style="font-size: 10.5px; color: ${T.fg5}; display: flex; align-items: center; gap: 4px"><span style="font-family: ${MONO}">image / result</span> · Gemini ${mark(1)}</div></div>
    </div>
    <div style="padding: 12px"><img src="${IMG.mountain}" alt="" style="width: 275px; height: 155px; object-fit: cover; display: block; box-sizing: border-box; border: 1px solid ${T.outline}; border-radius: 3px; background: ${T.thumb}"></div>
    <div style="border-bottom: 1px solid ${T.bStrong}">
      <div style="height: 26px; display: flex; align-items: center; gap: 6px; padding: 0 12px"><span style="font-size: 9px; color: ${T.fg5}">▼</span><span style="font-weight: 500; color: ${T.fg3}">生成参数</span></div>
      <div style="padding: 6px 0">
        ${iRow('服务商', 'Gemini 2.5 Flash Image')}
        ${iRow('分辨率', '1K', { mono: true })}
        ${iRow('宽高比', '16:9', { mono: true })}
        ${iRow('尺寸', '1920×1080', { mono: true })}
        ${iRow('种子', '4127', { mono: true })}
        <div style="display: flex; padding: 4px 12px 0"><div style="width: 96px; flex: none; color: ${T.fg5}">提示词</div><div style="flex: 1; min-width: 0; color: ${T.fg2}; line-height: 1.45">雾中山脊，远景，水墨晕染，清晨冷光（最多 6 行）</div></div>
      </div>
    </div>
    <div style="padding: 12px; display: flex; flex-wrap: wrap; gap: 8px">${actBtn('定位来源节点')}${actBtn('在序列中定位', 'sequence')}</div>
  </div>`;
const vidStrip = `
  <div style="width: 301px; box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.bStrong}; padding: 12px">
    <div style="font-size: 10px; color: ${T.fg5}; margin-bottom: 6px">视频产物：只画和图像不同的部分</div>
    <div style="display: flex; gap: 10px">
      <div style="position: relative; width: 140px; height: 79px; flex: none; box-sizing: border-box; border: 1px solid ${T.outline}; border-radius: 3px; overflow: hidden; background: ${T.thumb}">
        <img src="${IMG.thumbWide}" alt="" style="width: 140px; height: 79px; object-fit: cover; display: block">${playOverlay}
        <div style="position: absolute; right: 3px; top: 3px">${mark(3)}</div>
      </div>
      <div style="flex: 1; min-width: 0; font-size: 11px; line-height: 1.5">
        <div style="display: flex; gap: 6px"><span style="color: ${T.fg5}; width: 48px">片长</span><span style="font-family: ${MONO}; color: ${T.fg2}">00:00:05</span>${mark(2)}</div>
        <div style="display: flex; gap: 6px"><span style="color: ${T.fg5}; width: 48px">运镜方式</span><span style="color: ${T.fg2}">推近</span></div>
        <div style="font-size: 10px; color: ${T.fg6}; margin-top: 2px">首帧 = thumbnail_url；没出片「等待生成」</div>
      </div>
    </div>
    <div style="display: flex; flex-wrap: wrap; gap: 8px; margin-top: 10px">${actBtn('播放', 'run')}${actBtn('定位来源节点')}${actBtn('在序列中定位', 'sequence', true)}</div>
  </div>`;
const s9 = sec(C3, `产物检查器 ${builtTag}`, '照 fix/demo-inspectors 的代码画，设计与实现对齐用', 530 + 10 + 172, `${imgInspector}<div style="height: 10px"></div>${vidStrip}`, [
  `三段共用 ${code('result_inspector_parts')}：预览 · 生成参数 · 动作行；图像有批量 slot 换成 2×N 网格；视频点预览 = 播放（画布同一个灯箱）`,
  `参数取 ${code('util/result_params')}，与画廊信息面板同口径（来源配置 + 产物自身）；没有的行不画；不可用的动作 50% 不隐藏`,
  `要对齐：${mark(1)} 枚举名「image / result」改走 ARB；${mark(2)} 片长「00:00:05」改统一格式「5 秒」；${mark(3)} Material 图标、写死 40 换图标集 v1 与 token`,
  '预留：「设为当前」排动作行最前，过期原因放参数组顶（TakesCost）',
]);

// ======================= 需要你定 =======================
const qBlock = (title, opts, rec) => `
  <div style="padding: 5px 0; border-top: 1px solid ${T.washBorder}">
    <div style="font-size: 11.5px; font-weight: 500; color: ${T.fg1}; line-height: 1.45">${title}</div>
    <div style="font-size: 10.5px; color: ${T.fg3}; line-height: 1.5; margin-top: 1px">${opts}</div>
    <div style="font-size: 10.5px; color: ${T.accent}; line-height: 1.5">${rec}</div>
  </div>`;
const QS = [
  ['N1 关掉的类别，铃铛里还记吗？', 'A 照记，不加未读 · B 照记也加未读 · C 不记', '建议 A：想查还查得到，不被红点打扰'],
  ['N2 通知卡默认放哪（调研 Q2）？', 'A 跟随系统：Windows 右下、macOS 右上 · B 都右下 · C 都右上', '建议 A：各自贴近系统通知出现的位置'],
  ['N3 「失败」开关管多宽？', 'A 只管后台任务（生成 / 导出 / 下载），当场操作出错总提示 · B 所有失败', '建议 A：否则操作失败会没有任何反馈'],
  ['P1 检查器也能拖宽吗？', 'A 能，260–480，与左面板同一套热区和记法 · B 固定 301', '建议 A'],
  ['O1 大纲拖动能跨泳道组吗？', 'A 不能，只在组内排；换道走画布拖卡 · B 能，同时改 lane_id 和位置', '建议 A：一次拖动只改一件事'],
  ['C1 角色类型进不进提示词？', 'A 不进，只管分组 · B 注入描述时加英文类型前缀', '建议 A：先不动模型行为'],
  ['E1 一键导出遇到没有视频的镜？', 'A 照导，完成卡写「跳过 2 镜（没有视频）」· B 停下开对话框 · C 用静帧补片（P2）', '建议 A：与对话框只列有视频的镜一致'],
];
const qInnerW = C4 - 24;
const qH = 10 + 22 + QS.reduce((a, [t, o, r]) => a + 10 + 1 + nLines(t, qInnerW, 11.5) * 16.7 + nLines(o, qInnerW, 10.5) * 15.75 + nLines(r, qInnerW, 10.5) * 15.75 + 1, 0) + 4;
const decide = {
  h: qH,
  title: '需要你定',
  html: `
  <div style="width: ${C4}px; box-sizing: border-box; padding: 10px 12px 4px; background: ${T.wash}; border: 1px solid ${T.washBorder}; border-radius: 6px">
    <div style="font-weight: 500; color: ${T.accent}; height: 22px">需要你定</div>
    ${QS.map(([t, o, r]) => qBlock(t, o, r)).join('')}
  </div>`,
};

// ======================= 排版：四列 =======================
const GAP = 18;
const cols = [
  { x: 32, w: C1, items: [s1, s6, s8] },
  { x: 32 + C1 + 16, w: C2, items: [s3, s4, s5] },
  { x: 32 + C1 + 16 + C2 + 16, w: C3, items: [s9, s2] },
  { x: 32 + C1 + 16 + C2 + 16 + C3 + 16, w: C4, items: [s7, decide] },
];
for (const c of cols) {
  const total = c.items.reduce((a, s) => a + s.h, 0) + GAP * (c.items.length - 1);
  console.error(`col x=${c.x} w=${c.w} est=${Math.round(total)} bottom=${Math.round(TOP + total)} / ${H} :: ${c.items.map((s) => strip(s.title) + '=' + Math.round(s.h)).join(', ')}`);
}

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="position: absolute; left: 32px; top: 20px; display: flex; align-items: baseline; gap: 14px">
    <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">面板与通知补漏 · 第二批</div>
    <div style="color: ${T.fg4}">审查列为 MISSING、又不在舞台上的几项；产物检查器照已实现的画，设计与代码对齐</div>
  </div>
  ${cols.map((c) => `<div style="position: absolute; left: ${c.x}px; top: ${TOP}px; width: ${c.w}px; display: flex; flex-direction: column; gap: ${GAP}px">${c.items.map((s) => s.html).join('')}</div>`).join('')}
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'GapsPanels.dc.html', html: page('面板与通知补漏', W, H, body, logic) };
