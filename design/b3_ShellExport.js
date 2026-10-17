// 第三批细化画板：外壳菜单、系统通知与导出 · 第二批 · 状态与流程（1280×H，静态）
// 对应第二批画板 b2_shell.js（ShellExport.dc.html，page 标题「外壳菜单与导出」）。
// 每个功能一节：状态条（徽标 = 状态名）· 流程帧（①②③④ 数字徽标）· 边界帧（「边界」徽标）。
// 按建议走的决定：SE-Q4 选 A（打包 NotoSansSC-Regular.otf，约 +10 MB，OFL，登记进 core/licenses.dart，
//   按 plan.md 第 4 节）；新依赖 local_notifier 按同意画（plan.md 第 5 节「新依赖 local_notifier、SE-Q4」）；
//   板上其余「需要你定」照建议：Q1 选 A（系统通知静音）· Q2 选 A（导出 / 交付进任务弹层，只在内存）·
//   Q3 选 A（导出历史一直留）。
// 现状核对：shell_chrome.dart（六个标签纯文字、在 DragToMoveArea 里；交付在途 ⚙ 变灰）/ ink_window_chrome.dart
//   （macOS 红绿灯）/ main.dart _TeardownWindowListener + app_teardown.dart（关闭不弹确认，有序退出）/
//   toast_center.dart（类型停留、setWindowActive、historyHostReady）/ job_notification_listener.dart（完成卡
//   「查看」、失败卡按节点去重、拿不到定位就不画「查看」）/ shell_task_popover.dart（不显示耗时）/
//   open_export_dialog.dart + export_video_dialog.dart + export_controller.dart（idle/busy/success/failure）/
//   ffmpeg_video_export_service.dart（.partial→rename、kill、ffmpeg_not_found、output_replace_failed）/
//   export_tab.dart（单个「导出视频」按钮 + 两种禁用 tooltip）/ delivery_panel.dart（片段 / 历史只画标签）/
//   command_actions.dart（⌘K 写死 ≤6 个动作）/ core/licenses.dart（只登记 JetBrains Mono 一款字体）。
const { T, IMG, SANS, MONO, page, ic } = require('./common.js');

const W = 1280;
const PAD = 24;
const CW = W - 2 * PAD;
const GAP = 8;
const HEAD_H = 88;
const SEC_HEAD = 26;
const SEC_GAP = 6;
const fw = (n) => Math.floor((CW - GAP * (n - 1)) / n);

// ---- 文案长度自检（只在构建时打印，不进页面）----
const warnings = [];
const textWidth = (html) => {
  const s = html.replace(/<[^>]*>/g, '').replace(/&[a-z]+;/g, 'x');
  let w = 0;
  for (const ch of s) w += /[⺀-￿]/.test(ch) ? 10 : 5.8;
  return w;
};

// ---- 小件 ----
const code = (t) => `<span style="font-family: ${MONO}; font-size: 9.5px; color: ${T.fg3}">${t}</span>`;
const now = `<span style="color: ${T.fg5}">现状</span>`;
const neu = `<span style="color: ${T.accent}">新</span>`;
const prioB = (p) => `<span style="height: 16px; padding: 0 5px; border-radius: 3px; border: 1px solid ${p === 'P1' ? T.washBorder : T.control}; color: ${p === 'P1' ? T.accent : T.fg4}; font-family: ${MONO}; font-size: 10px; display: inline-flex; align-items: center; flex: none">${p}</span>`;
const bState = (t) => `<span style="display: inline-flex; align-items: center; height: 16px; padding: 0 6px; border-radius: 8px; background: ${T.s4}; border: 1px solid ${T.outline}; color: ${T.fg3}; font-size: 10px; white-space: nowrap">${t}</span>`;
const bStep = (n, t) => `<span style="display: inline-flex; align-items: center; gap: 5px; height: 16px; white-space: nowrap"><span style="width: 16px; height: 16px; border-radius: 8px; background: ${T.accent}; color: ${T.onAccent}; font-family: ${MONO}; font-size: 10px; font-weight: 500; display: inline-flex; align-items: center; justify-content: center">${n}</span><span style="font-size: 10.5px; color: ${T.fg2}">${t}</span></span>`;
const bEdge = (t) => `<span style="display: inline-flex; align-items: center; height: 16px; padding: 0 6px; border-radius: 8px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 10px; white-space: nowrap">边界 · ${t}</span>`;

// 一帧：上 = 样稿区（左上徽标），下 = 说明区（固定高，2–3 行）
const frame = (w, h, capH, f) => {
  const lines = Math.floor((capH - 4) / 14);
  const need = textWidth(f.cap);
  if (need > (w - 16) * lines * 0.92) warnings.push(`说明可能被裁：${need.toFixed(0)} > ${((w - 16) * lines * 0.92).toFixed(0)} · ${f.cap.replace(/<[^>]*>/g, '').slice(0, 24)}`);
  return `
  <div style="width: ${w}px; height: ${h}px; flex: none; box-sizing: border-box; display: flex; flex-direction: column; border: 1px solid ${T.outline}; border-radius: 4px; overflow: hidden; background: ${T.s1}">
    <div style="position: relative; flex: 1; min-height: 0; overflow: hidden">
      <div style="position: absolute; left: 6px; top: 5px; right: 6px; display: flex; gap: 4px; z-index: 3">${f.badge}</div>
      <div style="position: absolute; left: 8px; right: 8px; top: 26px; bottom: 6px">${f.mock}</div>
    </div>
    <div style="height: ${capH}px; flex: none; box-sizing: border-box; padding: 3px 8px 0; border-top: 1px solid ${T.bSubtle}; background: ${T.s3}; font-size: 10px; line-height: 1.4; color: ${T.fg4}; overflow: hidden">${f.cap}</div>
  </div>`;
};
const row = (h, capH, frames) => {
  const w = fw(frames.length);
  return { h, html: `<div style="display: flex; gap: ${GAP}px; height: ${h}px">${frames.map((f) => frame(w, h, capH, f)).join('')}</div>` };
};
const mockW = (n) => fw(n) - 16;

let secNo = 0;
const section = (title, prio, slices, note, rows) => {
  secNo += 1;
  const h = SEC_HEAD + rows.reduce((a, r) => a + r.h, 0) + GAP * (rows.length - 1) + SEC_GAP;
  const html = `
  <div style="height: ${h}px; box-sizing: border-box; display: flex; flex-direction: column; gap: ${GAP}px">
    <div style="height: ${SEC_HEAD - GAP}px; display: flex; align-items: center; gap: 8px; white-space: nowrap; overflow: hidden">
      <span style="font-family: ${MONO}; font-size: 11px; color: ${T.fg5}">${String(secNo).padStart(2, '0')}</span>
      <span style="font-size: 13px; font-weight: 500; color: ${T.fg1}">${title}</span>${prioB(prio)}
      <span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">${slices}</span>
      <span style="font-size: 10.5px; color: ${T.fg5}; overflow: hidden; text-overflow: ellipsis">${note}</span>
    </div>
    ${rows.map((r) => r.html).join('')}
  </div>`;
  return { h, html };
};

// ---- 菜单栏小件 ----
const LABELS = ['文件', '编辑', '画布', '节点', '窗口', '帮助'];
const LW = 27; // 每个标签的近似宽
const strip = (o = {}) => `
  <div style="height: 20px; display: flex; align-items: center; padding: 0 4px; background: ${T.s0}; border-bottom: 1px solid ${T.bStrong}; overflow: hidden">
    <div style="width: 11px; height: 11px; flex: none; border-radius: 2px; background: ${T.accent}; color: ${T.onAccent}; font-size: 6px; font-weight: 700; display: flex; align-items: center; justify-content: center; margin-right: 5px">If</div>
    ${LABELS.map((l) => {
      const open = o.open === l, hot = o.hot === l, focus = o.focus === l, dim = (o.dim || []).includes(l);
      return `<div style="position: relative; width: ${LW}px; flex: none; height: 16px; box-sizing: border-box; border-radius: 3px; display: flex; align-items: center; justify-content: center; font-size: 10px; color: ${open || hot ? T.fg1 : (dim ? T.fg6 : T.fg4)}; ${open || hot ? `background: ${T.s5};` : ''} ${focus ? `box-shadow: inset 0 0 0 1.5px ${T.accent};` : ''}">${l}${o.dot === l ? `<span style="position: absolute; right: 1px; top: 1px; width: 4px; height: 4px; border-radius: 2px; background: ${T.accent}"></span>` : ''}</div>`;
    }).join('')}
    <div style="flex: 1"></div>
    ${o.gear ? `<div style="display: flex; color: ${o.gear === 'dis' ? T.fg6 : T.fg4}">${ic('settings', 11)}</div>` : ''}
  </div>`;
const mm = (rows, width = 150) => `<div style="width: ${width}px; box-sizing: border-box; padding: 3px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 5px; box-shadow: 0 12px 32px rgba(0,0,0,0.55)">${rows}</div>`;
const mr = (label, key = '', o = {}) => {
  const fg = o.dis ? T.fg6 : (o.danger ? T.danger : (o.accent ? T.accent : T.fg2));
  return `<div style="height: 19px; display: flex; align-items: center; gap: 6px; padding: 0 6px; border-radius: 3px; font-size: 10.5px; color: ${fg}; ${o.hot ? `background: ${T.s5};` : ''} white-space: nowrap; overflow: hidden">
    <div style="flex: 1; overflow: hidden; text-overflow: ellipsis">${label}</div>
    ${o.note ? `<span style="font-size: 9px; color: ${T.fg6}">${o.note}</span>` : ''}${key ? `<span style="font-family: ${MONO}; font-size: 9px; color: ${o.dis ? T.fg6 : T.fg5}">${key}</span>` : ''}${o.sub ? `<span style="color: ${T.fg5}">›</span>` : ''}
  </div>`;
};
const msep = `<div style="height: 1px; background: ${T.bStrong}; margin: 2px 0"></div>`;
const menuAt = (label, inner, width, mw) => {
  const left = Math.max(0, Math.min(16 + LABELS.indexOf(label) * LW, mw - width));
  return `<div style="position: absolute; top: 21px; left: ${left}px">${mm(inner, width)}</div>`;
};
const tip = (t, style = '') => `<div style="position: absolute; ${style}; box-sizing: border-box; padding: 3px 6px; background: ${T.s5}; border: 1px solid ${T.overlayBorder}; border-radius: 3px; color: ${T.fg2}; font-size: 9.5px; white-space: nowrap; box-shadow: 0 6px 16px rgba(0,0,0,0.5)">${t}</div>`;
const cursor = (style) => `<div style="position: absolute; ${style}; color: ${T.fg1}; z-index: 4">${ic('select', 13)}</div>`;
const keyCap = (k, on = false) => `<span style="display: inline-flex; align-items: center; height: 15px; padding: 0 4px; border-radius: 3px; border: 1px solid ${on ? T.washBorder : T.controlStrong}; ${on ? `background: ${T.wash};` : ''} font-family: ${MONO}; font-size: 9px; color: ${on ? T.accent : T.fg2}; white-space: nowrap">${k}</span>`;
const arrow = `<span style="color: ${T.fg6}; font-size: 10px">→</span>`;
const nodeMini = (label, o = {}) => `<div style="position: absolute; ${o.pos}; width: 58px; height: 30px; box-sizing: border-box; padding: 3px 5px; border-radius: 4px; background: ${T.s3}; border: 1px solid ${o.sel ? T.accent : T.outline}; ${o.sel ? `box-shadow: 0 0 0 1px ${T.accent};` : ''}">
  <div style="display: flex; align-items: center; gap: 3px; color: ${T.fg4}">${ic(o.icon || 'imageConfig', 10)}<span style="font-size: 9px; color: ${T.fg2}; white-space: nowrap">${label}</span></div>
  <div style="margin-top: 3px; height: 3px; width: 70%; border-radius: 2px; background: ${T.control}"></div>
</div>`;
const canvasBg = (inner, h = 64) => `<div style="position: relative; height: ${h}px; background: ${T.s2}; background-image: radial-gradient(${T.grid} 1px, transparent 1px); background-size: 10px 10px; overflow: hidden">${inner}</div>`;

// ================= 01 外壳菜单栏 =================
const MW6 = mockW(6), MW4 = mockW(4);
const s1States = row(133, 32, [
  { badge: bState('默认'), mock: `${strip()}${canvasBg('', 46)}`,
    cap: `${now}：六个标签是纯文字，包在 ${code('DragToMoveArea')} 里` },
  { badge: bState('悬停'), mock: `${strip({ hot: '编辑' })}${canvasBg(cursor('left: 52px; top: -9px'), 46)}`,
    cap: '只换底色、指针变手形；不自动展开' },
  { badge: bState('展开'), mock: `${strip({ open: '文件' })}${menuAt('文件', `${mr('新建项目…')}${mr('导入项目包…')}`, 132, MW6)}`,
    cap: '点开；再点标签 / 点外面 / Esc 关' },
  { badge: bState('键盘聚焦'), mock: `${strip({ focus: '文件' })}${canvasBg(`<div style="position: absolute; left: 8px; top: 10px; display: flex; gap: 4px; align-items: center">${keyCap('Alt')}<span style="font-size: 9.5px; color: ${T.fg5}">按下再松开</span></div>`, 46)}`,
    cap: '单独按松 Alt：只聚焦「文件」，↓ / ↵ 才展开' },
  { badge: bState('项禁用'), mock: `${strip({ open: '编辑' })}${menuAt('编辑', `${mr('撤销', 'Ctrl Z', { dis: true, hot: true })}${mr('复制一份', 'Ctrl D')}`, 140, MW6)}${tip('即将推出', 'left: 96px; top: 30px')}`,
    cap: `灰着不藏，悬停写原因（${code('disabledReason')}）` },
  { badge: bState('不在画布标签'), mock: `${strip({ open: '节点', dim: ['画布'] })}${menuAt('节点', `${mr('生成', 'Ctrl ↵', { dis: true, hot: true })}${mr('删除', 'Del', { dis: true })}`, 140, MW6)}${tip('只在画布标签可用', 'left: 30px; top: 50px')}`,
    cap: '画布 / 节点两组照常能开，项全灰、说原因' },
]);
const s1Flow = row(133, 32, [
  { badge: bStep(1, '按下「文件」'), mock: `${strip({ open: '文件' })}${menuAt('文件', `${mr('新建项目…')}${mr('导出视频…')}`, 150, MW4)}${cursor('left: 26px; top: 4px')}`,
    cap: '点标签开；内容来自共用动作表（id · 文案 · 键位 · 可用判据）' },
  { badge: bStep(2, '划到「编辑」'), mock: `${strip({ open: '编辑' })}${menuAt('编辑', `${mr('撤销', 'Ctrl Z', { dis: true })}${mr('复制一份', 'Ctrl D')}`, 150, MW4)}${cursor('left: 52px; top: 4px')}`,
    cap: '开着时指针划到相邻标签直接换开，「文件」随之收起' },
  { badge: bStep(3, '↓ 到「复制一份」'), mock: `${strip({ open: '编辑' })}${menuAt('编辑', `${mr('撤销', 'Ctrl Z', { dis: true })}${mr('复制一份', 'Ctrl D', { hot: true })}`, 150, MW4)}<div style="position: absolute; left: 200px; top: 34px; display: flex; gap: 3px">${keyCap('↓', true)}${keyCap('↓', true)}${keyCap('↵')}</div>`,
    cap: '↑↓ 跳过灰项；←→ 换菜单；有子菜单的行 → 展开' },
  { badge: bStep(4, '↵ 执行'), mock: `${strip()}${canvasBg(`${nodeMini('镜头 02', { pos: 'left: 60px; top: 4px' })}${nodeMini('镜头 02', { pos: 'left: 130px; top: 12px', sel: true })}`, 46)}`,
    cap: `菜单关、焦点回画布；执行体与右键「复制一份」同一个函数（${code('duplicateNodes')}）` },
]);
const s1Edges = row(147, 46, [
  { badge: bEdge('Alt 被作废'), mock: `<div style="display: flex; flex-direction: column; gap: 6px; padding-top: 4px">
      <div style="display: flex; align-items: center; gap: 3px">${keyCap('Alt↓')}${keyCap('A')}${keyCap('Alt↑')}${arrow}<span style="font-size: 9.5px; color: ${T.fg2}">左对齐</span></div>
      <div style="display: flex; align-items: center; gap: 3px">${keyCap('Alt↓')}${keyCap('拖')}${keyCap('Alt↑')}${arrow}<span style="font-size: 9.5px; color: ${T.fg2}">切线</span></div>
      <div style="display: flex; align-items: center; gap: 3px">${keyCap('Alt↓')}${keyCap('Alt↑', true)}${arrow}<span style="font-size: 9.5px; color: ${T.accent}">聚焦「文件」</span></div></div>`,
    cap: `期间有别的键 / 指针 / 滚轮、失焦、AltGr 都作废；${code('SC_KEYMENU')} 在 ${code('flutter_window.cpp')} 吞掉` },
  { badge: bEdge('Esc 一次一层'), mock: `<div style="display: flex; flex-direction: column; gap: 1px; font-size: 9px">${['菜单', '@ 弹层', '查找条', '框选进行中', '工具锁', '清空选中'].map((t, i) => `<div style="height: 10px; display: flex; align-items: center; gap: 5px; font-size: 9px; color: ${i === 0 ? T.accent : T.fg4}"><span style="font-family: ${MONO}; font-size: 9px; color: ${T.fg6}; width: 8px">${i + 1}</span>${t}${i === 0 ? `<span style="color: ${T.fg5}">← 先关</span>` : ''}</div>`).join('')}</div>`,
    cap: '菜单开着按 Esc 只关菜单、焦点回进来前的位置；再按才轮到下一层' },
  { badge: bEdge('交付进行中'), mock: `${strip({ open: '文件', gear: 'dis' })}${menuAt('文件', `${mr('导出视频…')}${mr('设置…', '', { dis: true, hot: true, note: '交付中' })}`, 160, MW6)}`,
    cap: `${now}：交付在途 ⚙ 变灰（${code('deliveryBusyProvider')}）；菜单里「设置…」同一判据` },
  { badge: bEdge('有新版本'), mock: `${strip({ open: '帮助', dot: '帮助' })}${menuAt('帮助', `${mr('有新版本 0.9.0 · 下载', '', { accent: true, hot: true })}${mr('关于 InkFrame')}`, 160, MW6)}`,
    cap: '与关于页共用检查结果；「帮助」与左栏帮助键同时挂琥珀点' },
  { badge: bEdge('macOS'), mock: `
      <div style="height: 16px; display: flex; align-items: center; gap: 8px; padding: 0 6px; background: ${T.s4}; font-size: 9.5px; color: ${T.fg2}; white-space: nowrap; overflow: hidden"><b style="font-weight: 600; color: ${T.fg1}">InkFrame</b>${LABELS.map((l) => `<span>${l}</span>`).join('')}</div>
      <div style="position: absolute; left: 0; top: 17px">${mm(`${mr('设置…', '⌘,')}${mr('退出 InkFrame', '⌘Q')}`, 130)}</div>
      <div style="position: absolute; right: 2px; top: 22px; display: flex; gap: 3px">${[T.danger, T.accent, T.success].map((c) => `<span style="width: 7px; height: 7px; border-radius: 4px; background: ${c}"></span>`).join('')}</div>`,
    cap: `系统菜单栏 ${code('PlatformMenuBar')}，同一张表；关于 / 设置 / 退出进应用菜单；chrome 不画标签` },
  { badge: bEdge('退出时任务在跑'), mock: `<div style="display: flex; flex-direction: column; gap: 3px; font-size: 9.5px; color: ${T.fg3}">${['冲掉挂起写入', '停 JobQueue（在跑的取消）', '关连接池', '停 PG'].map((t, i) => `<div style="display: flex; align-items: center; gap: 5px"><span style="width: 12px; height: 12px; border-radius: 6px; border: 1px solid ${T.controlStrong}; font-family: ${MONO}; font-size: 8px; display: inline-flex; align-items: center; justify-content: center; color: ${T.fg4}">${i + 1}</span>${t}</div>`).join('')}</div>`,
    cap: `⌘Q 走 ${code('windowManager.close')}，与关闭键 / Alt F4 同一条路，不弹确认（${now}：main.dart）` },
]);
const S1 = section('外壳菜单栏', 'P1', 'win-menubar · lone-alt-menubar · mac-platform-menubar · app-action-table · help-actions', 'Windows 自绘六个菜单；macOS 用系统菜单栏，同一张动作表', [s1States, s1Flow, s1Edges]);

// ================= 02 系统通知 · F6 =================
const appIcon = `<div style="width: 9px; height: 9px; border-radius: 2px; background: ${T.accent}; color: ${T.onAccent}; font-size: 5px; font-weight: 700; display: flex; align-items: center; justify-content: center; flex: none">If</div>`;
const sysToast = (o) => `
  <div style="box-sizing: border-box; padding: 5px 6px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 10px 24px rgba(0,0,0,0.5)">
    <div style="display: flex; align-items: center; gap: 4px">${appIcon}<span style="font-size: 9px; color: ${T.fg5}; flex: 1">InkFrame</span><span style="font-size: 8.5px; color: ${T.fg6}">现在</span></div>
    <div style="display: flex; gap: 6px; margin-top: 4px">
      ${o.thumb ? `<img src="${o.thumb}" alt="" style="width: 26px; height: 26px; flex: none; object-fit: cover; border-radius: 3px">` : `<div style="width: 26px; height: 26px; flex: none; border-radius: 3px; background: ${T.s5}; color: ${o.err ? T.danger : T.success}; display: flex; align-items: center; justify-content: center">${ic(o.err ? 'error' : 'success', 14)}</div>`}
      <div style="min-width: 0"><div style="font-size: 10px; font-weight: 500; color: ${T.fg1}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${o.title}</div><div style="font-size: 9px; color: ${T.fg4}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${o.body}</div></div>
    </div>
  </div>`;
const toggle = (on) => `<div style="width: 22px; height: 12px; border-radius: 6px; background: ${on ? T.accent : T.control}; position: relative; flex: none"><div style="position: absolute; ${on ? 'right' : 'left'}: 2px; top: 2px; width: 8px; height: 8px; border-radius: 4px; background: ${on ? T.onAccent : T.fg4}"></div></div>`;
const settingRow = (on, note, noteColor) => `
  <div style="box-sizing: border-box; border: 1px solid ${T.outline}; border-radius: 4px; background: ${T.s3}; padding: 6px 8px">
    <div style="display: flex; align-items: center; gap: 6px"><div style="flex: 1; font-size: 10.5px; color: ${T.fg2}">系统通知</div>${toggle(on)}</div>
    <div style="font-size: 9px; color: ${noteColor}; line-height: 1.4; margin-top: 3px">${note}</div>
  </div>`;
const appCard = (o) => `
  <div style="position: relative; box-sizing: border-box; display: flex; gap: 6px; padding: 4px 6px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 5px; ${o.focused ? `outline: 2px solid ${T.accent}; outline-offset: 1px;` : ''} overflow: hidden">
    ${o.thumb ? `<img src="${o.thumb}" alt="" style="width: 22px; height: 22px; flex: none; object-fit: cover; border-radius: 3px">` : `<div style="width: 22px; height: 22px; flex: none; border-radius: 3px; background: ${T.s5}; color: ${T.danger}; display: flex; align-items: center; justify-content: center">${ic('error', 12)}</div>`}
    <div style="flex: 1; min-width: 0"><div style="font-size: 9.5px; font-weight: 500; color: ${T.fg1}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${o.title}</div><div style="font-size: 8.5px; color: ${T.fg4}; white-space: nowrap">${o.body}</div></div>
    ${o.btn ? `<button type="button" style="align-self: flex-end; height: 14px; box-sizing: border-box; padding: 0 5px; border-radius: 3px; font-size: 8.5px; display: flex; align-items: center; ${o.btnFocus ? `background: ${T.accent}; color: ${T.onAccent};` : `border: 1px solid ${T.controlStrong}; color: ${T.fg3};`}">${o.btn}</button>` : ''}
    ${o.count ? `<div style="position: absolute; left: 0; bottom: 0; height: 2px; width: ${o.count}%; background: ${T.controlStrong}"></div>` : ''}
  </div>`;
const winBox = (inner, o = {}) => `<div style="position: absolute; ${o.pos}; box-sizing: border-box; border: 1px solid ${o.front ? T.overlayBorder : T.outline}; border-radius: 4px; background: ${o.front ? T.s3 : T.s2}; overflow: hidden; ${o.front ? 'box-shadow: 0 8px 20px rgba(0,0,0,0.5);' : ''}"><div style="height: 10px; background: ${T.s0}; display: flex; align-items: center; padding: 0 4px; font-size: 7.5px; color: ${T.fg5}">${o.title || ''}</div>${inner}</div>`;
const check = (t) => `<div style="display: flex; align-items: center; gap: 4px; font-size: 9.5px; color: ${T.fg3}"><span style="display: flex; color: ${T.success}">${ic('success', 11)}</span>${t}</div>`;
const inputMini = (text, focus) => `<div style="height: 18px; box-sizing: border-box; border-radius: 3px; background: ${T.s2}; border: 1px solid ${focus ? T.accent : T.outline}; display: flex; align-items: center; padding: 0 6px; font-size: 9.5px; color: ${T.fg3}">${text}${focus ? `<span style="width: 1px; height: 10px; background: ${T.fg1}; margin-left: 1px"></span>` : ''}</div>`;

const s2States = row(124, 32, [
  { badge: bState('开关 · 开'), mock: settingRow(true, '窗口不在前台时，跑了 10 秒以上的生成或导出做完，发一条。', T.fg5),
    cap: `${neu}：设置 › 常规 › 通知，默认开` },
  { badge: bState('系统里已关闭'), mock: settingRow(true, '系统里已关闭 · 打开系统设置', T.accent),
    cap: 'macOS 首次开启时请求权限；被拒就在开关下写这句' },
  { badge: bState('生成完成'), mock: sysToast({ thumb: IMG.thumbWide, title: '镜头 02 · 视频已生成', body: '万相 2.2 · 用时 1:12' }),
    cap: '主按钮「查看」= 定位节点（同窗口里的卡）' },
  { badge: bState('生成失败'), mock: sysToast({ err: true, title: '镜头 04 生成失败', body: '可灵 · 余额不足' }),
    cap: '失败也发；正文 = 本地化错误，同失败卡' },
  { badge: bState('导出完成'), mock: sysToast({ title: '示例项目_画布1.mp4 已导出', body: '8 镜 · 00:42 · 用时 0:35' }),
    cap: '主按钮 = 打开文件夹' },
  { badge: bState('2 秒内合并'), mock: sysToast({ title: '3 个任务已完成', body: '镜头 01、02、05 · 最长 1:12' }),
    cap: '接连完成的合成一条；点了还原窗口并开铃铛' },
]);
const s2Flow = row(140, 46, [
  { badge: bStep(1, '窗口到后台'), mock: `${winBox('', { pos: 'left: 0; top: 0; width: 100px; height: 46px', title: 'InkFrame' })}${winBox(`<div style="padding: 4px; font-size: 8px; color: ${T.fg5}">别的程序</div>`, { pos: 'left: 44px; top: 14px; width: 100px; height: 44px', front: true, title: '' })}`,
    cap: `失焦 / 最小化 → ${code('setWindowActive(false)')}，卡片停表（${now}）` },
  { badge: bStep(2, '任务做完'), mock: `<div style="display: flex; flex-direction: column; gap: 3px; padding-top: 2px">${check('卡片带 chime')}${check('窗口不在前台')}${check('用时 1:12 ≥ 10 秒')}</div>`,
    cap: '三条同时满足才发；用时读 JobTiming，与任务弹层同一张表' },
  { badge: bStep(3, '系统通知弹出'), mock: sysToast({ thumb: IMG.thumbWide, title: '镜头 02 · 视频已生成', body: '万相 2.2 · 用时 1:12' }),
    cap: 'Q1 选 A：系统通知静音，只响「提示音」设置那一声' },
  { badge: bStep(4, '点通知'), mock: winBox(canvasBg(`${nodeMini('镜头 02', { pos: 'left: 44px; top: 8px', sel: true, icon: 'videoConfig' })}`, 46), { pos: 'left: 0; top: 0; width: 100%; height: 58px', front: true, title: 'InkFrame' }),
    cap: '还原并聚焦窗口 → 执行主按钮（查看 = 单选 + 居中）' },
  { badge: bStep(1, '按 F6'), mock: `<div style="display: flex; flex-direction: column; gap: 5px">${appCard({ thumb: IMG.thumbMountain, title: '镜头 01 已生成', body: '用时 18 秒', btn: '查看', focused: true, btnFocus: true })}${inputMini('雾中的渔船', false)}</div>`,
    cap: '提示词框里也有效；进来聚焦最新一张、全部停表；播报「通知，2 条」' },
  { badge: bStep(2, '↑↓ · Tab'), mock: `<div style="display: flex; flex-direction: column; gap: 5px">${appCard({ title: '镜头 04 生成失败', body: '可灵 · 余额不足', btn: '重试', focused: true, btnFocus: true })}<div style="display: flex; gap: 3px">${keyCap('↑', true)}${keyCap('Tab', true)}</div></div>`,
    cap: '↑↓ 换卡 · ↵ 主按钮 · Tab 卡内按钮 · Del 关掉' },
  { badge: bStep(3, 'Esc 离开'), mock: `<div style="display: flex; flex-direction: column; gap: 5px">${appCard({ thumb: IMG.thumbMountain, title: '镜头 01 已生成', body: '用时 18 秒', btn: '查看', count: 60 })}${inputMini('雾中的渔船', true)}</div>`,
    cap: 'Esc 或再按 F6：焦点回进来前的位置，接着计时' },
]);
const s2Edges = row(136, 46, [
  { badge: bEdge('窗口在前台'), mock: `<div style="display: flex; flex-direction: column; gap: 4px">${appCard({ thumb: IMG.thumbWide, title: '镜头 02 视频已生成', body: '用时 1:12', btn: '查看' })}<div style="font-size: 9.5px; color: ${T.fg6}; text-decoration: line-through">系统通知</div></div>`,
    cap: '只出窗口里的卡（照进铃铛），不发系统通知' },
  { badge: bEdge('不到 10 秒'), mock: `<div style="display: flex; flex-direction: column; gap: 4px; padding-top: 2px">${check('卡片带 chime')}${check('窗口不在前台')}<div style="display: flex; align-items: center; gap: 4px; font-size: 9.5px; color: ${T.fg5}"><span style="display: flex; color: ${T.danger}">${ic('error', 11)}</span>用时 8 秒</div></div>`,
    cap: '短任务不发，免得一批小图刷屏；窗口里的卡照出' },
  { badge: bEdge('节点已删'), mock: sysToast({ err: false, title: '镜头 03 · 图像已生成', body: 'Gemini · 用时 22 秒' }),
    cap: `拿不到定位时卡上本就不画「查看」（${now}）：点通知只还原窗口` },
  { badge: bEdge('Windows 快捷方式'), mock: settingRow(true, '此安装方式发不出系统通知', T.accent),
    cap: `${code('local_notifier')} 要建带 AppUserModelID 的开始菜单快捷方式；建不出就不发、记日志；zip 版实测` },
  { badge: bEdge('F6 时没有卡'), mock: `<div style="position: absolute; right: 0; top: 0; width: 150px">${mm(`${mr('镜头 01 已生成', '3 分钟前', { hot: true })}${mr('导出完成', '8 分钟前')}`, 150)}</div><div style="position: absolute; right: 4px; bottom: 0; color: ${T.accent}; display: flex">${ic('bell', 14)}</div>`,
    cap: `直接开铃铛、聚焦第一条（${code('openAndFocusFirst')}）` },
  { badge: bEdge('「还有 N 条」'), mock: `<div style="display: flex; flex-direction: column; align-items: flex-end; gap: 3px"><div style="height: 16px; padding: 0 8px; border-radius: 8px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; outline: 2px solid ${T.accent}; outline-offset: 1px; font-size: 9px; color: ${T.fg3}; display: flex; align-items: center">还有 2 条 · 查看全部</div><div style="width: 100%">${appCard({ thumb: IMG.thumbMountain, title: '镜头 01 已生成', body: '用时 18 秒', btn: '查看' })}</div></div>`,
    cap: `也是一站，↵ 开铃铛；上面压着对话框时跳过（${code('historyHostReady')}）` },
]);
const S2 = section('系统通知 · F6 跳到通知区', 'P1', 'system-notifications · f6-notification-region', '新依赖 local_notifier；系统通知 P1，F6 P2', [s2States, s2Flow, s2Edges]);

// ================= 03 任务弹层：耗时 + 导出行 =================
const trow = (o) => `
  <div style="box-sizing: border-box; padding: 4px 8px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; line-height: 1.3">
    <div style="display: flex; align-items: center; gap: 5px">${o.icon ? `<span style="display: flex; color: ${T.fg4}">${ic(o.icon, 11)}</span>` : ''}<div style="flex: 1; font-size: 10px; color: ${o.muted ? T.fg5 : T.fg2}; white-space: nowrap; overflow: hidden">${o.title}</div>${o.act ? `<button type="button" style="font-size: 9.5px; color: ${o.act === '定位' ? T.accent : T.fg4}">${o.act}</button>` : ''}</div>
    <div style="display: flex; gap: 4px; font-size: 9px; color: ${o.danger ? T.danger : T.fg5}; margin-top: 1px; white-space: nowrap"><span>${o.meta}</span><span style="font-family: ${MONO}; color: ${T.fg3}">${o.time}</span></div>
    ${o.pct != null ? `<div style="height: 3px; border-radius: 2px; background: ${T.control}; margin-top: 4px; overflow: hidden"><div style="height: 3px; width: ${o.pct}%; background: ${T.accent}"></div></div>` : ''}
  </div>`;
const s3States = row(110, 32, [
  { badge: bState('排队'), mock: trow({ title: '镜头 03 · 图像', meta: 'Gemini · 排队', time: '8 秒', act: '取消' }), cap: '排队 = 现在 − 入队' },
  { badge: bState('进行中'), mock: trow({ title: '镜头 02 · 视频', meta: '万相 2.2 · 已用', time: '1:12', act: '取消', pct: 62 }), cap: '已用 = 现在 − 提交；弹层开着才每秒刷新' },
  { badge: bState('完成'), mock: trow({ title: '镜头 01 · 图像', meta: 'Gemini · 完成 · 用时', time: '18 秒', act: '定位' }), cap: '用时 = 完成 − 提交，不算排队' },
  { badge: bState('失败'), mock: trow({ title: '镜头 04 · 视频', meta: '可灵 · 失败 · 用时', time: '2:03', act: '定位', danger: true }), cap: `悬停行 = 本地化错误（${now}）` },
  { badge: bState('已取消'), mock: trow({ title: '镜头 05 · 视频', meta: '可灵 · 已取消 · 用时', time: '41 秒', act: '', muted: true }), cap: '取消也是终态，按完成 − 提交算' },
  { badge: bState('导出行'), mock: trow({ icon: 'export', title: '导出 mp4 · 画布 1', meta: '拼接中 45% · 已用', time: '20 秒', act: '取消', pct: 45 }), cap: 'Q2 选 A：导出 / 交付也进弹层，只在内存' },
]);
const tl = (on) => {
  const pts = [['入队', 0], ['提交', 38], ['完成', 92]];
  return `<div style="position: relative; height: 40px; margin: 0 14px">
    <div style="position: absolute; left: 0; right: 0; top: 10px; height: 2px; background: ${T.control}"></div>
    ${on > 0 ? `<div style="position: absolute; left: 0; width: ${pts[Math.min(on, 2)][1]}%; top: 10px; height: 2px; background: ${T.fg5}"></div>` : ''}
    ${on > 1 ? `<div style="position: absolute; left: 38%; width: 54%; top: 10px; height: 2px; background: ${T.accent}"></div>` : ''}
    ${pts.map(([t, x], i) => `<div style="position: absolute; left: ${x}%; top: 6px; transform: translateX(-50%); display: flex; flex-direction: column; align-items: center; gap: 4px"><span style="width: 10px; height: 10px; border-radius: 5px; box-sizing: border-box; ${i <= on ? `background: ${i === on ? T.accent : T.fg5};` : `border: 1px solid ${T.controlStrong}; background: ${T.s1};`}"></span><span style="font-size: 9px; color: ${i === on ? T.fg1 : T.fg5}; white-space: nowrap">${t}</span></div>`).join('')}
  </div>`;
};
const s3Row2 = row(120, 46, [
  { badge: bStep(1, '入队'), mock: tl(0), cap: `${neu}：入队时记一笔，进 jobId → JobTiming 旁表；不改 JobState` },
  { badge: bStep(2, '提交'), mock: tl(1), cap: `写 ${code('submitted_at')} 处同时记（${code('job_queue_service.dart:257')}）` },
  { badge: bStep(3, '完成'), mock: tl(2), cap: `写 ${code('completed_at')} 处同时记（:446）；用时 = 提交 → 完成` },
  { badge: bEdge('满 60 分钟'), mock: `<div style="display: flex; flex-direction: column; gap: 4px; font-size: 10px; color: ${T.fg3}"><div><span style="font-family: ${MONO}">59 秒</span> <span style="color: ${T.fg6}">→</span> <span style="font-family: ${MONO}">1:00</span></div><div><span style="font-family: ${MONO}">72:05</span> <span style="color: ${T.fg5}">不进位到小时</span></div></div>`,
    cap: `一个纯函数 ${code('formatElapsed')}：弹层 / 通知卡 / 系统通知都用它` },
  { badge: bEdge('胶囊计数'), mock: `<div style="display: inline-flex; align-items: center; gap: 4px; height: 18px; padding: 0 8px; border-radius: 9px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 9.5px"><span class="spin" style="display: flex">${ic('progress', 11)}</span>生成中 2 · 排队 1</div><div style="font-size: 9.5px; color: ${T.fg5}; margin-top: 6px">其中 1 个是导出</div>`,
    cap: '胶囊「生成中 N」把在跑的导出 / 交付也算进去' },
  { badge: bEdge('在弹层里取消导出'), mock: trow({ icon: 'export', title: '导出 mp4 · 画布 1', meta: '已取消 · 用时', time: '23 秒', act: '', muted: true }),
    cap: `mp4 走 ${code('ExportCancelToken')}、交付走现有取消；取消不写导出历史` },
]);
const S3 = section('任务弹层：耗时 · 导出行', 'P2', 'format-elapsed-job-timing · export-in-task-popover', `${now}：弹层头注写「不显示耗时：JobState 没有起止时间」，落地时删`, [s3States, s3Row2]);

// ================= 04 导出视频对话框 =================
const cb = (on, dis) => `<span style="width: 9px; height: 9px; flex: none; box-sizing: border-box; border-radius: 2px; ${on ? `background: ${dis ? T.fg6 : T.accent};` : `border: 1px solid ${T.controlStrong};`}"></span>`;
const dRow = (thumb, name, o = {}) => `
  <div style="height: 12px; display: flex; align-items: center; gap: 4px; ${o.hot ? `background: ${T.s5}; border-radius: 2px;` : ''}">
    ${thumb ? `<img src="${thumb}" alt="" style="width: 20px; height: 11px; flex: none; object-fit: cover; border-radius: 2px; ${o.dis ? 'opacity: 0.5;' : ''}">` : `<span style="width: 20px; height: 11px; flex: none; border-radius: 2px; background: ${T.s5}"></span>`}
    ${cb(o.on, o.dis)}
    <span style="flex: 1; font-size: 9px; color: ${o.dis ? T.fg5 : T.fg2}; white-space: nowrap; overflow: hidden">${name}</span>
    ${o.older ? `<span style="font-size: 7.5px; padding: 0 3px; border-radius: 2px; background: ${T.s2}; color: ${T.fg3}">旧 take</span>` : ''}
    <span style="font-size: 8px; color: ${o.dis ? T.fg6 : T.fg4}">↑ ↓</span>
  </div>`;
const dBtns = (o = {}) => `<div style="display: flex; justify-content: flex-end; gap: 5px; margin-top: 4px">
  <button type="button" style="height: 12px; padding: 0 6px; border-radius: 3px; font-size: 8.5px; display: flex; align-items: center; color: ${o.cancelDis ? T.fg6 : T.fg3}">取消</button>
  <button type="button" style="height: 12px; padding: 0 8px; border-radius: 3px; font-size: 8.5px; display: flex; align-items: center; ${o.okDis ? `background: ${T.control}; color: ${T.fg5};` : `background: ${T.accent}; color: ${T.onAccent};`}">${o.ok || '导出'}</button></div>`;
const dInput = (text, o = {}) => `<div style="height: 12px; box-sizing: border-box; border-radius: 2px; background: ${T.s2}; border: 1px solid ${o.err ? T.danger : T.outline}; display: flex; align-items: center; padding: 0 4px; font-size: 8px; color: ${text ? T.fg2 : T.fg6}; margin-top: 3px; ${o.dis ? 'opacity: 0.55;' : ''}">${text || '留空使用时间戳默认名'}</div>`;
const dNote = (t, c) => `<div style="font-size: 8.5px; line-height: 12px; color: ${c}; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${t}</div>`;
const dProg = (pct) => `<div style="display: flex; align-items: center; gap: 4px; margin-top: 3px; line-height: 12px"><div style="flex: 1; height: 3px; border-radius: 2px; background: ${T.control}; overflow: hidden"><div style="height: 3px; width: ${pct}%; background: ${T.accent}"></div></div><span style="font-size: 8.5px; color: ${T.accent}">取消导出</span></div>`;
const dBanner = (t) => `<div style="margin-top: 4px; box-sizing: border-box; padding: 2px 4px; border-radius: 2px; border: 1px solid ${T.danger}; background: ${T.s2}; font-size: 8px; line-height: 1.35; color: ${T.fg2}; max-height: 24px; overflow: hidden">${t}</div>`;
const dlg = (inner, title = '导出视频') => `<div style="box-sizing: border-box; padding: 5px 7px; background: ${T.s3}; border: 1px solid ${T.overlayBorder}; border-radius: 5px; box-shadow: 0 10px 24px rgba(0,0,0,0.5)"><div style="font-size: 10px; line-height: 13px; font-weight: 500; color: ${T.fg1}; margin-bottom: 2px">${title}</div>${inner}</div>`;
const toastMini = (title, btn, o = {}) => `<div style="box-sizing: border-box; display: flex; gap: 6px; padding: 5px 6px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 5px; box-shadow: 0 10px 24px rgba(0,0,0,0.45)">
  <div style="width: 20px; height: 20px; flex: none; border-radius: 3px; background: ${T.s5}; color: ${o.color || T.success}; display: flex; align-items: center; justify-content: center">${ic(o.icon || 'success', 12)}</div>
  <div style="flex: 1; min-width: 0"><div style="font-size: 9.5px; color: ${T.fg1}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</div>${o.body ? `<div style="font-size: 8.5px; color: ${T.fg4}; white-space: nowrap">${o.body}</div>` : ''}
  ${btn ? `<div style="display: flex; justify-content: flex-end; margin-top: 3px"><button type="button" style="height: 14px; padding: 0 6px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 8.5px; display: flex; align-items: center">${btn}</button></div>` : ''}</div></div>`;
const ghostBtn = (label, dis) => `<button type="button" style="display: inline-flex; align-items: center; gap: 5px; height: 22px; box-sizing: border-box; padding: 0 10px; border-radius: 4px; border: 1px solid ${dis ? T.outline : T.controlStrong}; color: ${dis ? T.fg6 : T.fg2}; font-size: 10px">${ic('export', 12)}${label}</button>`;

const s4States = row(144, 32, [
  { badge: bState('默认'), mock: dlg(`${dRow(IMG.thumbWide, '镜头 02 推近', { on: true })}${dRow(IMG.thumbWide, '镜头 02 推近', { older: true })}${dBtns()}`), cap: '默认勾每镜最新 take；旧 take 照列、可勾回' },
  { badge: bState('文件名不合法'), mock: dlg(`${dInput('画布1/终版', { err: true })}${dNote('文件名不能包含 \\ / : * ? 等字符', T.danger)}${dBtns({ okDis: true })}`), cap: `${now}：下面写红字，「导出」灰` },
  { badge: bState('同名会覆盖'), mock: dlg(`${dInput('示例_画布1')}${dNote('同名文件已存在，导出将覆盖它。', T.fg3)}${dBtns()}`), cap: '提示不是错误：fg3、不挡导出' },
  { badge: bState('导出中'), mock: dlg(`${dRow(IMG.thumbMountain, '镜头 01 山脊远景', { on: true, dis: true })}${dProg(45)}${dBtns({ okDis: true, cancelDis: true })}`), cap: '全部锁住；Esc 与「取消」不关（PopScope）' },
  { badge: bState('失败 · 没有 ffmpeg'), mock: dlg(`${dBanner('未检测到 ffmpeg——安装后重试（可用 INKFRAME_FFMPEG 指定路径）')}${dBtns()}`), cap: '失败内嵌对话框，改了就能重试，不另弹卡' },
  { badge: bState('失败 · 覆盖不了'), mock: dlg(`${dBanner('无法覆盖同名视频……已保存为 示例_画布1.mp4.partial')}${dBtns()}`), cap: '成片已渲染好留在原地，只差改名' },
]);
const s4Flow = row(144, 32, [
  { badge: bStep(1, '打开'), mock: `<div style="padding-top: 4px; position: relative">${ghostBtn('导出视频')}${tip('按叙事链顺序把画布上的视频镜头拼成一个 mp4', 'left: 0; top: 34px')}${cursor('left: 60px; top: 16px')}</div>`,
    cap: `导出标签 / 序列「导出 mp4」/ Ctrl K 同一路径 ${code('openExportVideoDialogForCanvas')}` },
  { badge: bStep(2, '勾选 · 排序'), mock: dlg(`${dRow(IMG.thumbWide, '镜头 02 推近', { on: true, hot: true })}${dRow(IMG.thumbMountain, '镜头 01 山脊远景', { on: true })}${dBtns()}`),
    cap: '默认序 = 叙事链；↑↓ 手动排；输出名可选' },
  { badge: bStep(3, '导出中'), mock: dlg(`${dRow(IMG.thumbMountain, '镜头 01 山脊远景', { on: true, dis: true })}${dProg(62)}${dBtns({ okDis: true, cancelDis: true })}`),
    cap: '进度分母 = 所选镜总时长；有一镜缺时长就走不定进度' },
  { badge: bStep(4, '完成'), mock: `<div style="display: flex; flex-direction: column; gap: 6px">${toastMini('已导出到 exports/示例_画布1.mp4', '复制路径')}<div style="display: flex; align-items: center; gap: 5px; font-size: 9.5px; color: ${T.fg4}"><span style="display: flex; color: ${T.accent}">${ic('history', 12)}</span>导出历史 + 1 行（kind = mp4）</div></div>`,
    cap: `关对话框 → 完成卡（chime）；${neu}：同时写一行 ${code('export_records')}` },
]);
const s4Edges = row(130, 46, [
  { badge: bEdge('取消导出'), mock: `<div style="display: flex; flex-direction: column; gap: 4px; font-size: 9.5px; color: ${T.fg3}"><div>导出中 45% ${arrow} <span style="color: ${T.accent}">取消导出</span></div><div>${arrow} 对话框回到可编辑，勾选 / 输出名都在</div><div style="color: ${T.fg5}">导出历史不加行</div></div>`,
    cap: `kill ffmpeg、只清 ${code('.partial')}，回到可编辑；取消不写导出历史` },
  { badge: bEdge('取消迟到'), mock: `<div style="font-size: 9.5px; color: ${T.fg3}; line-height: 1.6">点「取消导出」时 ffmpeg 已 exit 0<br><span style="color: ${T.success}">→ 成片照留，按成功走</span></div>`,
    cap: `${now}：已成功不误删（${code('ffmpeg_video_export_service.dart')}）` },
  { badge: bEdge('入口灰着'), mock: `<div style="position: relative">${ghostBtn('导出视频', true)}${tip('画布上还没有视频生成结果', 'left: 0; top: 27px')}</div>`,
    cap: `${now}：tooltip 只讲第一条阻断原因；没项目时写「请从 Studio 重新打开」` },
  { badge: bEdge('按下瞬间没镜了'), mock: `<div style="padding-top: 4px">${ghostBtn('导出视频')}<div style="font-size: 9.5px; color: ${T.fg5}; margin-top: 6px">什么都不弹</div></div>`,
    cap: `${now}：节点刚被删 / 外壳没项目 → 静默不弹（${code('open_export_dialog.dart')}）` },
  { badge: bEdge('历史写失败'), mock: `<div style="display: flex; flex-direction: column; gap: 5px">${toastMini('已导出到 exports/示例_画布1.mp4', '')}<div style="font-family: ${MONO}; font-size: 8.5px; color: ${T.fg5}">export.history · write failed</div></div>`,
    cap: '写库失败只记日志，导出照样算成功、照样出完成卡' },
]);
const S4 = section('导出视频对话框（拼接 mp4）', 'P1', 'export-records-recording · 现有 export_video_dialog', '对话框本身已存在，状态照现状；新增的只有完成 / 失败时写导出历史', [s4States, s4Flow, s4Edges]);

// ================= 05 导出标签 · 导出历史 · 交付页签 =================
const newTag = `<span style="font-size: 8px; height: 12px; line-height: 12px; padding: 0 3px; border-radius: 6px; border: 1px solid ${T.washBorder}; background: ${T.wash}; color: ${T.accent}; flex: none">新</span>`;
const soonTag = `<span style="font-size: 8px; height: 12px; line-height: 12px; padding: 0 4px; border-radius: 6px; border: 1px solid ${T.outline}; color: ${T.fg5}; flex: none">待支持</span>`;
const fmt = (icon, name, sub, o = {}) => `
  <div style="display: flex; align-items: center; gap: 6px; height: 26px; padding: 0 6px; border-radius: 3px; ${o.on ? `background: ${T.s5};` : ''} color: ${o.dis ? T.fg6 : T.fg2}">
    <span style="display: flex; color: ${o.dis ? T.fg6 : T.fg4}">${ic(icon, 13)}</span>
    <div style="flex: 1; min-width: 0"><div style="font-size: 10px; white-space: nowrap">${name}</div><div style="font-size: 8.5px; color: ${T.fg6}; white-space: nowrap">${sub}</div></div>
    ${o.neu ? newTag : ''}${o.soon ? soonTag : ''}
  </div>`;
const hist = (icon, file, sub, act, o = {}) => `
  <div style="display: flex; align-items: center; gap: 5px; height: 28px; padding: 0 6px; border-bottom: 1px solid ${T.bSubtle}; ${o.hot ? `background: ${T.s5};` : ''} ${o.fresh ? `box-shadow: inset 2px 0 0 ${T.accent};` : ''}">
    <span style="display: flex; color: ${o.err ? T.danger : T.fg4}">${ic(icon, 12)}</span>
    <div style="flex: 1; min-width: 0"><div style="font-family: ${MONO}; font-size: 9px; color: ${o.gone ? T.fg6 : T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; ${o.gone ? 'text-decoration: line-through;' : ''}">${file}</div><div style="font-size: 8.5px; color: ${o.err ? T.danger : T.fg5}; white-space: nowrap; overflow: hidden">${sub}</div></div>
    <button type="button" style="font-size: 9px; color: ${T.accent}; white-space: nowrap">${act}</button>
  </div>`;
const listBox = (inner) => `<div style="box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.outline}; border-radius: 4px; overflow: hidden">${inner}</div>`;
const H1 = hist('export', '示例项目_画布1.mp4', '8 镜 · 00:42 · 38.2 MB · 今天 14:20', '打开文件夹');
const s5States = row(120, 32, [
  { badge: bState('格 · 默认 / 悬停'), mock: listBox(`${fmt('export', '拼接视频', 'mp4 · 现有对话框', { on: true })}${fmt('sequence', '交付包', 'EDL + 媒体 · 序列标签')}`), cap: '点 = 开对应对话框 / 跳到序列交付面板' },
  { badge: bState('格 · 待支持'), mock: `${listBox(`${fmt('more', '剪映草稿', 'FCPXML 同', { soon: true, dis: true })}${fmt('script', '分镜 PDF', '每页 6 镜', { neu: true })}`)}${tip('等写出器接上', 'left: 30px; top: 22px')}`, cap: `可选性只问 ${code('DeliveryWriterRegistry')}；出厂只有 EDL` },
  { badge: bState('行 · 完成'), mock: listBox(H1), cap: '右键：打开文件 · 复制路径 · 从历史移除' },
  { badge: bState('行 · 文件不在了'), mock: listBox(hist('script', '分镜_画布1.pdf', '文件不在了 · 昨天', '重新导出', { gone: true })), cap: '列表显示时查文件在不在；不在就划掉' },
  { badge: bState('行 · 失败'), mock: listBox(hist('error', '示例项目_画布2.mp4', '失败 · 找不到 ffmpeg · 昨天', '重试', { err: true })), cap: '失败只给「重试」，原因写在副行' },
  { badge: bState('空态'), mock: listBox(`<div style="height: 50px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; color: ${T.fg5}">${ic('history', 16)}<span style="font-size: 9.5px; color: ${T.fg4}">还没有导出过</span><span style="font-size: 8.5px; color: ${T.fg6}">视频、交付包、PDF 都会记在这里</span></div>`), cap: '「本画布」筛选下为空也写这句' },
]);
const s5Row2 = row(152, 46, [
  { badge: bStep(1, '右键一行'), mock: `${listBox(hist('export', '示例项目_画布1.mp4', '8 镜 · 00:42 · 今天 14:20', '打开文件夹', { hot: true }))}<div style="position: absolute; right: 0; top: 4px">${mm(`${mr('打开文件')}${mr('复制路径')}${mr('从历史移除', '', { hot: true })}`, 100)}</div>`,
    cap: `菜单走 ${code('InkMenuPanel')}（ink-menu-panel），↑↓ ↵ Esc 同画布菜单` },
  { badge: bStep(2, '从历史移除'), mock: `<div style="display: flex; flex-direction: column; gap: 6px">${listBox(hist('sequence', '示例项目.edl + 8 mp4', '交付 · Resolve · 今天 11:05', '打开文件夹'))}${toastMini('已从历史移除，文件没动', '', { icon: 'info', color: T.fg4 })}</div>`,
    cap: '只删记录不删文件；Q3 选 A：不会自动清' },
  { badge: bStep(3, '重新导出'), mock: dlg(`${dInput('示例_画布1')}${dNote('按 10-16 14:20 那次的设置预填', T.fg5)}${dBtns()}`),
    cap: '用行里的设置快照（镜序 · take · 输出名）重开同一路径' },
  { badge: bStep(4, '新行置顶'), mock: listBox(`${hist('export', '示例_画布1.mp4', '8 镜 · 00:42 · 刚刚', '打开文件夹', { fresh: true })}${hist('script', '分镜_画布1.pdf', '文件不在了', '重新导出', { gone: true })}`),
    cap: '新导出排最上；被重导的那行不动' },
  { badge: bEdge('快照里的镜没了'), mock: dlg(`${dRow(IMG.thumbMountain, '镜头 01 山脊远景', { on: true })}${dNote('快照里有 2 镜已不在画布上，已跳过', T.fg3)}${dBtns()}`),
    cap: '只列还在的镜；一镜都不剩就把「重新导出」灰掉' },
  { badge: bEdge('交付面板 · 片段'), mock: `${listBox(`<div style="height: 18px; display: flex; border-bottom: 1px solid ${T.bStrong}">${['交付', '片段', '历史'].map((t) => `<div style="width: 40px; display: flex; align-items: center; justify-content: center; font-size: 9px; color: ${t === '片段' ? T.fg1 : T.fg5}; ${t === '片段' ? `box-shadow: inset 0 -2px 0 ${T.accent};` : ''}">${t}</div>`).join('')}</div>
      <div style="height: 20px; display: flex; align-items: center; gap: 5px; padding: 0 6px; background: ${T.s5}"><span style="font-family: ${MONO}; font-size: 8.5px; color: ${T.fg5}">002</span><span style="font-size: 9px; color: ${T.fg2}; flex: 1">镜头 02 推近</span><span style="font-family: ${MONO}; font-size: 8.5px; color: ${T.fg4}">00:04:12</span></div>
      <div style="height: 20px; display: flex; align-items: center; gap: 5px; padding: 0 6px"><span style="font-family: ${MONO}; font-size: 8.5px; color: ${T.fg5}">003</span><span style="font-size: 9px; color: ${T.accent}; flex: 1">无产物 → 空隙 + 标记</span></div>`)}`,
    cap: `${now}：片段 / 历史只画标签（${code('delivery_panel.dart')}）；点行 = 播放头跳那一镜` },
]);
const S5 = section('导出标签 · 导出历史 · 交付页签', 'P1', 'export-records-table · export-tab-history · delivery-clips-tab · delivery-history-tab', `${now}：导出标签只有一个「导出视频」按钮（export_tab.dart）；新表 export_records 按合入顺序编号`, [s5States, s5Row2]);

// ================= 06 分镜 PDF · 图片 ZIP =================
const pdfCell = (thumb, no, o = {}) => `<div style="box-sizing: border-box; padding: 2px; border: 1px solid ${T.fg5}; border-radius: 1px; overflow: hidden; line-height: 1">
  ${thumb ? `<img src="${thumb}" alt="" style="display: block; width: 100%; height: 11px; object-fit: cover">` : `<div style="height: 11px; box-sizing: border-box; border: 1px dashed ${T.fg5}; display: flex; align-items: center; justify-content: center; font-size: 6px; color: ${T.fg6}">无缩略图</div>`}
  <div style="display: flex; justify-content: space-between; height: 8px; font-size: 6.5px; color: ${T.s2}; margin-top: 1px; white-space: nowrap"><b>${no}</b><span>${o.dur || '4 秒'}</span></div>
  <div style="height: 7px; font-size: 6px; color: ${T.s5}; white-space: nowrap; overflow: hidden">${o.cam || '中景 · 推'}</div>
  <div style="height: 2px; width: 90%; background: ${T.fg4}; margin-top: 1px"></div>
</div>`;
const pdfPage = (cells, w = 150) => `<div style="width: ${w}px; box-sizing: border-box; padding: 3px 4px 4px; background: ${T.fg1}; border-radius: 2px; box-shadow: 0 6px 16px rgba(0,0,0,0.5)">
  <div style="display: flex; justify-content: space-between; height: 8px; line-height: 8px; font-size: 6px; color: ${T.s2}; margin-bottom: 2px"><b>示例项目 · 画布 1</b><span>1 / 2</span></div>
  <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 2px">${cells}</div></div>`;
const cells6 = [IMG.thumbMountain, IMG.thumbWide, IMG.thumbWide, IMG.thumbMountain, '', IMG.thumbWide].map((t, i) => pdfCell(t, `0${i + 1}`)).join('');
const zipTree = `<div style="font-family: ${MONO}; font-size: 8.5px; color: ${T.fg3}; line-height: 1.55">示例_画布1.zip<br>├ 001_镜头01.png<br>├ 002_镜头02.png<br>└ metadata.json</div>`;
const s6States = row(158, 32, [
  { badge: bState('页面'), mock: `<div style="display: flex; justify-content: center">${pdfPage(cells6, 160)}</div>`, cap: '每页 6 镜：缩略图 · 镜号 · 景别运镜 · 时长 · 提示词摘要' },
  { badge: bState('对话框 · 默认'), mock: dlg(`<div style="font-size: 9px; color: ${T.fg3}; line-height: 1.7">范围　本画布 · 8 镜 · 2 页<br>字段语言　跟随界面（简体中文）</div>${dInput('分镜_画布1')}${dBtns()}`, '导出分镜 PDF'), cap: '字段名走 ARB，按当前语言传进来；景别运镜复用 camera_labels' },
  { badge: bState('生成中'), mock: dlg(`<div style="font-size: 9px; color: ${T.fg3}">第 1 / 2 页</div>${dProg(50).replace('取消导出', '取消')}${dBtns({ okDis: true, cancelDis: true })}`, '导出分镜 PDF'), cap: `先写 ${code('.partial')} 再改名；取消就删掉、不记历史` },
  { badge: bState('完成'), mock: toastMini('分镜_画布1.pdf 已导出', '打开文件夹', { icon: 'export', color: T.fg3, body: '8 镜 · 2 页' }), cap: '记一行 kind = pdf；导出标签那一格点亮' },
  { badge: bState('图片 ZIP'), mock: `<div style="display: flex; gap: 8px">${zipTree}</div>`, cap: `每镜选定产物 + ${code('metadata.json')}（英文协议键）；用现成 ${code('archive')}` },
]);
const s6Row2 = row(136, 46, [
  { badge: bStep(1, '点「分镜 PDF」'), mock: listBox(`${fmt('export', '拼接视频', 'mp4 · 现有对话框')}${fmt('script', '分镜 PDF', '每页 6 镜', { neu: true, on: true })}`), cap: '在合入前这一格灰着，悬停写「即将推出」' },
  { badge: bStep(2, '确认 → 生成'), mock: dlg(`<div style="font-size: 9px; color: ${T.fg3}">本画布 · 8 镜 · 2 页</div>${dProg(80).replace('取消导出', '取消')}`, '导出分镜 PDF'), cap: '镜序 = 叙事链（export_order），每镜取当前 take' },
  { badge: bStep(3, '打开文件夹'), mock: `<div style="display: flex; gap: 6px; align-items: flex-start">${pdfPage([IMG.thumbMountain, IMG.thumbWide].map((t, i) => pdfCell(t, `0${i + 7}`)).join(''), 110)}<span style="font-size: 9px; color: ${T.fg5}; line-height: 1.5">第 2 页<br>2 镜，空格不画框</span></div>`, cap: '镜数不满 6 的最后一页照常排，空位留白' },
  { badge: bEdge('视频没缩略图'), mock: `<div style="width: 70px; padding: 3px; background: ${T.fg1}; border-radius: 2px">${pdfCell('', '05', { cam: '远景 · 摇' })}</div>`, cap: `视频取 ${code('thumbnail_url')}；没有就画虚线占位，不现场抽帧` },
  { badge: bEdge('提示词太长'), mock: `<div style="width: 140px; box-sizing: border-box; padding: 4px; background: ${T.fg1}; border-radius: 2px; font-size: 7.5px; line-height: 1.35; color: ${T.s2}">清晨江面薄雾，一叶孤舟自远处缓缓驶来，船头老渔夫披蓑衣撒网，远山层叠……</div>`, cap: '摘要最多 3 行、超出用省略号；全文在画布里' },
  { badge: bEdge('SE-Q4 选 A · 字体'), mock: `<div style="font-size: 9px; color: ${T.fg3}; line-height: 1.6">${code('assets/fonts/NotoSansSC-Regular.otf')}<br>${code('OFL-NotoSansSC.txt')}<br>安装包约 +10 MB · 只给 PDF 用</div>`,
    cap: `登记进 ${code('core/licenses.dart')}（${now}只有 JetBrains Mono）；界面字体仍走系统回落链` },
]);
const S6 = section('分镜 PDF · 图片 ZIP', 'P2', 'storyboard-pdf-export（SE-Q4 选 A）· image-zip-export', '新依赖 pdf + 打包 Noto Sans SC；图片 ZIP 只用已有的 archive', [s6States, s6Row2]);

// ================= 组装 =================
const SECTIONS = [S1, S2, S3, S4, S5, S6];
const CONTENT_H = SECTIONS.reduce((a, s) => a + s.h, 0);
const H = HEAD_H + CONTENT_H + 12;
if (H > 2400) throw new Error('H too tall: ' + H);

const legend = `<span style="display: inline-flex; gap: 10px; align-items: center">${bState('状态')}${bStep(1, '流程步')}${bEdge('边界')}</span>`;
const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="position: absolute; left: ${PAD}px; right: ${PAD}px; top: 16px">
    <div style="display: flex; align-items: baseline; gap: 14px">
      <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">外壳菜单、系统通知与导出 · 第二批 · 状态与流程</div>
      <div style="color: ${T.fg4}">第二批画板「外壳菜单与导出」逐功能细化：状态条 · 流程帧 · 边界帧</div>
    </div>
    <div style="margin-top: 6px; height: 16px; font-size: 11px; color: ${T.accent}; white-space: nowrap">按建议走的决定：SE-Q4 选 A（打包 NotoSansSC-Regular.otf，约 +10 MB，OFL，登记 ${code('core/licenses.dart')}）· 新依赖 ${code('local_notifier')} 按同意画 · Q1 选 A · Q2 选 A · Q3 选 A</div>
    <div style="margin-top: 4px; height: 16px; display: flex; align-items: center; gap: 12px; font-size: 10.5px; color: ${T.fg5}">${legend}<span>「现状」= 对着 lib 核对过的现有行为；「新」= 第二批新增</span></div>
  </div>
  <div style="position: absolute; left: ${PAD}px; width: ${CW}px; top: ${HEAD_H}px; display: flex; flex-direction: column">
    ${SECTIONS.map((s) => s.html).join('')}
  </div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'ShellExportDetail.dc.html', html: page('外壳菜单、系统通知与导出 · 第二批 · 状态与流程', W, H, body, logic), H, warnings };
