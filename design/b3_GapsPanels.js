// 第三批细化画板：面板与通知补漏 · 状态与流程（1280×H，静态）
// 对应第二批画板 b2_gaps_panels.js（GapsPanels.dc.html，「面板与通知补漏 · 第二批」）。
// 每个功能一节：状态条 / 逐步流程 / 边界帧三行；两列排，每列五节。
// plan.md 第 5 节：无阻塞决定（与本画板相关的 N1 / N2 / N3 / P1 / O1 / C1 / E1 都不在阻塞表里，一律按 b2 画板写的建议画）。
// 现状核对：notifications/providers/toast_center.dart（ToastKind 六种、停留 4/6/8 秒、失败与进度不自动消失、最多 3 张、
// 历史 100 条、打开即全部已读）· notifications/widgets/toast_layer.dart（right 16、bottom = 状态栏高、「还有 N 条 · 查看全部」
// 只在 historyHostReady 时可点）· notification_bell.dart（未读点 accent / 有失败 danger，空态「还没有通知」，Esc / 点外面关）·
// job_notification_listener.dart（「{name} 已生成」+ 查看、失败卡 dedupeKey = job-failed:节点）· shell_task_capsule.dart /
// shell_task_popover.dart（三态胶囊、活动在前、定位跨画布先 openCanvas、拿不到 ProjectRef 不画定位）·
// left_rail/left_rail_panel.dart（width 241 常量）· canvas_inspector_panel.dart（width 301）· left_rail/outline_panel.dart（行只有 onTap）·
// character_library_panel.dart（「N 张参考图 · M 处引用 / 未引用」，空态文案）· left_rail/assets_panel.dart（空态 / 无项目文案）·
// sequence/widgets/sequence_screen.dart（行只有 selectShot）· canvas/util/generate_gate.dart（先提示词后 Key，在途另判）·
// storyboard/widgets/script_import_dialog.dart（_busy 时取消与创建都灰；失败「画布未做改动」）·
// export/widgets/export_video_dialog.dart（进度条 + 取消导出；ffmpeg 缺失文案）· result_inspector_parts.dart（等待生成 / 图片文件缺失）。
const { T, IMG, SANS, MONO, page, ic, caret } = require('./common.js');

const W = 1280;
const PAD = 24, CGAP = 16;
const CW = Math.floor((W - 2 * PAD - CGAP) / 2); // 608
const FGAP = 8;
const MH = 84;            // 样稿框高
const CAP_F = 10, CAP_LH = 13, CAP_LINES = 3;
const CAP_H = CAP_LH * CAP_LINES;
const ROW_H = MH + 4 + CAP_H;
const RGAP = 8;
const TITLE_H = 22;
const SEC_H = TITLE_H + 6 + 3 * ROW_H + 2 * RGAP;
const SGAP = 18;
const TOP = 74;
const H = TOP + 5 * SEC_H + 4 * SGAP + 56;

// ---- 文字行数估算（CJK 1 em、ASCII 0.56 em，+6%）：说明超过 3 行直接报错，不让它被裁 ----
const strip = (s) => s.replace(/<[^>]+>/g, '').replace(/&[a-z]+;/g, 'x');
const ems = (s) => { let e = 0; for (const ch of strip(s)) e += ch.charCodeAt(0) > 0x2e7f ? 1 : 0.56; return e; };
const nLines = (s, w, f) => Math.max(1, Math.ceil((ems(s) * 1.06) / (w / f)));

// ---- 小件 ----
const code = (t) => `<span style="font-family: ${MONO}; font-size: 9.5px; color: ${T.fg3}">${t}</span>`;
const kbd = (k, c = T.fg4) => `<span style="font-family: ${MONO}; font-size: 9.5px; color: ${c}; white-space: nowrap">${k}</span>`;
const b = (t) => `<span style="color: ${T.fg1}; font-weight: 500">${t}</span>`;
const num = (n, c = T.accent, fg = T.onAccent) => `<span style="display: inline-flex; align-items: center; justify-content: center; width: 14px; height: 14px; border-radius: 7px; background: ${c}; color: ${fg}; font-size: 9px; font-weight: 700; font-family: ${MONO}; flex: none; vertical-align: -2px">${n}</span>`;
const prio = (p) => `<span style="height: 16px; padding: 0 5px; border-radius: 3px; border: 1px solid ${p === 'P1' ? T.washBorder : T.control}; color: ${p === 'P1' ? T.accent : T.fg4}; font-family: ${MONO}; font-size: 10px; display: inline-flex; align-items: center; flex: none">${p}</span>`;
const builtTag = `<span style="font-size: 9.5px; height: 16px; line-height: 16px; padding: 0 5px; border-radius: 8px; border: 1px solid ${T.outline}; color: ${T.fg4}; flex: none">已实现</span>`;
const newTag = `<span style="font-size: 9px; height: 13px; line-height: 13px; padding: 0 4px; border-radius: 7px; border: 1px solid ${T.washBorder}; background: ${T.wash}; color: ${T.accent}; flex: none">新</span>`;
const spinIc = (size = 12, color = T.accent) => `<span class="spin" style="display: flex; color: ${color}; flex: none">${ic('progress', size)}</span>`;

const tg = (on, focus = false) => `<span style="width: 20px; height: 11px; border-radius: 6px; background: ${on ? T.accent : T.control}; position: relative; flex: none; display: inline-block; ${focus ? `outline: 2px solid ${T.accent}; outline-offset: 1px;` : ''}"><span style="position: absolute; ${on ? 'right' : 'left'}: 2px; top: 2px; width: 7px; height: 7px; border-radius: 4px; background: ${on ? T.onAccent : T.fg5}"></span></span>`;
const trow = (label, on, o = {}) => `<div style="height: 14px; display: flex; align-items: center; gap: 6px; padding: 0 4px; border-radius: 2px; ${o.hot ? `background: ${T.s5};` : ''} color: ${o.dim ? T.fg6 : T.fg2}; font-size: 9.5px"><span style="flex: 1; white-space: nowrap">${label}</span>${tg(on, o.focus)}</div>`;
const chip = (label, on = false) => `<span style="display: inline-flex; align-items: center; height: 15px; padding: 0 5px; border-radius: 3px; font-size: 9px; white-space: nowrap; box-sizing: border-box; ${on ? `background: ${T.accent}; color: ${T.onAccent}; font-weight: 500` : `border: 1px solid ${T.controlStrong}; color: ${T.fg3}`}">${label}</span>`;
const pill = (label, on = false, dim = false) => `<span style="display: inline-flex; align-items: center; height: 14px; padding: 0 5px; border-radius: 7px; font-size: 9px; white-space: nowrap; ${on ? `background: ${T.s5}; color: ${T.fg1}` : `color: ${dim ? T.fg6 : T.fg4}`}">${label}</span>`;
const mbtn = (label, o = {}) => `<span style="display: inline-flex; align-items: center; gap: 3px; height: 17px; padding: 0 7px; border-radius: 3px; font-size: 9.5px; white-space: nowrap; box-sizing: border-box; ${o.primary ? `background: ${T.accent}; color: ${T.onAccent}; font-weight: 500;` : `border: 1px solid ${T.controlStrong}; color: ${T.fg2};`} ${o.dis ? 'opacity: 0.5;' : ''} ${o.hot ? `background: ${o.primary ? T.accentHover : T.s5};` : ''}">${o.spin ? spinIc(10, o.primary ? T.onAccent : T.accent) : ''}${o.icon ? ic(o.icon, 11) : ''}${label}</span>`;
const thumb = (src, w, h) => src
  ? `<img src="${src}" alt="" style="width: ${w}px; height: ${h}px; flex: none; object-fit: cover; border-radius: 2px; outline: 1px solid ${T.outline}; display: block">`
  : `<span style="width: ${w}px; height: ${h}px; flex: none; box-sizing: border-box; border-radius: 2px; background: ${T.thumb}; border: 1px solid ${T.outline}; display: inline-block"></span>`;
const mmenu = (inner, w = '100%') => `<div style="width: ${w}; box-sizing: border-box; padding: 3px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 5px; box-shadow: 0 10px 24px rgba(0,0,0,0.55)">${inner}</div>`;
const mi = (label, right = '', o = {}) => `<div style="height: 16px; display: flex; align-items: center; gap: 5px; padding: 0 5px; border-radius: 2px; font-size: 9.5px; color: ${o.dis ? T.fg6 : T.fg2}; ${o.hot ? `background: ${T.s5};` : ''}"><span style="flex: 1; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${label}</span>${right}</div>`;
const msep = `<div style="height: 1px; background: ${T.bStrong}; margin: 2px 0"></div>`;
const note = (t, c = T.fg5) => `<div style="font-size: 9px; color: ${c}; line-height: 12px">${t}</div>`;
const cursor = (x, y, kind = 'arrow') => {
  const glyph = kind === 'resize' ? `<span style="font-family: ${MONO}; font-size: 11px; color: ${T.fg1}">↔</span>`
    : kind === 'no' ? `<span style="display: inline-flex; width: 11px; height: 11px; box-sizing: border-box; border: 1.5px solid ${T.danger}; border-radius: 6px; position: relative"><span style="position: absolute; left: 3px; top: -1px; width: 1.5px; height: 10px; background: ${T.danger}; transform: rotate(45deg)"></span></span>`
    : `<svg width="10" height="14" viewBox="0 0 10 14" aria-hidden="true" style="display: block"><path d="M1 1v11l3-3 2 4 2-1-2-4h4z" fill="${T.fg1}" stroke="${T.bStrong}" stroke-width="0.8"></path></svg>`;
  return `<div style="position: absolute; left: ${x}px; top: ${y}px; display: flex; z-index: 5">${glyph}</div>`;
};
const panel = (inner, extra = '') => `<div style="box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.bStrong}; border-radius: 2px; overflow: hidden; ${extra}">${inner}</div>`;

// 迷你通知卡：TOAST_CARD 的视觉缩成样稿尺寸，内容写死
const KC = { success: T.success, error: T.danger, warning: T.accent, info: T.fg4, progress: T.accent, undo: T.fg3, export: T.fg3 };
const mtoast = (o) => `
  <div style="position: relative; box-sizing: border-box; display: flex; gap: 6px; padding: 6px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 5px; box-shadow: 0 8px 20px rgba(0,0,0,0.45); overflow: hidden; ${o.extra || ''}">
    ${o.thumb ? `<img src="${o.thumb}" alt="" style="width: 22px; height: 22px; flex: none; object-fit: cover; border-radius: 3px; outline: 1px solid ${T.outline}">`
    : `<div style="width: 22px; height: 22px; flex: none; border-radius: 3px; background: ${T.s5}; display: flex; align-items: center; justify-content: center; color: ${KC[o.k]}">${o.k === 'progress' ? spinIc(13) : ic(o.k, 13)}</div>`}
    <div style="flex: 1; min-width: 0">
      <div style="font-size: 9.5px; font-weight: 500; color: ${T.fg1}; line-height: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${o.title}</div>
      ${o.body ? `<div style="font-size: 9px; color: ${T.fg4}; line-height: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${o.body}</div>` : ''}
      ${o.pct != null ? `<div style="display: flex; align-items: center; gap: 4px; margin-top: 3px"><div style="flex: 1; height: 3px; border-radius: 2px; background: ${T.control}; overflow: hidden"><div style="height: 3px; width: ${o.pct}%; background: ${T.accent}"></div></div><span style="font-family: ${MONO}; font-size: 8.5px; color: ${T.fg4}">${o.pct}%</span></div>` : ''}
      ${o.act ? `<div style="display: flex; justify-content: flex-end; gap: 4px; margin-top: 3px">${o.act2 ? `<span style="height: 14px; padding: 0 5px; border-radius: 2px; border: 1px solid ${T.controlStrong}; color: ${T.fg2}; font-size: 8.5px; display: inline-flex; align-items: center">${o.act2}</span>` : ''}<span style="height: 14px; padding: 0 5px; border-radius: 2px; background: ${T.accent}; color: ${T.onAccent}; font-size: 8.5px; font-weight: 500; display: inline-flex; align-items: center">${o.act}</span></div>` : ''}
    </div>
    ${o.count != null ? `<div style="position: absolute; left: 0; bottom: 0; height: 2px; width: ${o.count}%; background: ${T.controlStrong}"></div>` : ''}
  </div>`;

// ---- 帧 ----
const FRAME_BORDER = { st: `1px solid ${T.outline}`, fl: `1px solid ${T.control}`, ed: `1px dashed ${T.washBorder}` };
const capErrs = [];
const frame = (kind, head, mock, cap, fw, mockStyle = '') => {
  const capHtml = `${head} ${cap}`;
  const lines = nLines(capHtml, fw, CAP_F);
  if (lines > CAP_LINES) capErrs.push(`${lines} 行 @${fw}px：${strip(capHtml)}`);
  return `
  <div style="width: ${fw}px; flex: none">
    <div style="position: relative; height: ${MH}px; box-sizing: border-box; padding: 6px; background: ${kind === 'ed' ? T.s2 : T.s1}; border: ${FRAME_BORDER[kind]}; border-radius: 4px; overflow: hidden; font-size: 10px; ${mockStyle}">${mock}</div>
    <div style="margin-top: 4px; height: ${CAP_H}px; overflow: hidden; font-size: ${CAP_F}px; line-height: ${CAP_LH}px; color: ${T.fg4}">${capHtml}</div>
  </div>`;
};
// 一行：[kind, head, mock, cap, mockStyle?]
const row = (kind, frames) => {
  const fw = Math.floor((CW - (frames.length - 1) * FGAP) / frames.length);
  return `<div style="display: flex; gap: ${FGAP}px; height: ${ROW_H}px">${frames.map(([head, mock, cap, ms]) => frame(kind, head, mock, cap, fw, ms)).join('')}</div>`;
};
const S = (name, mock, cap, ms) => [b(name), mock, cap, ms];
const F = (n, mock, cap, ms) => [num(n), mock, cap, ms];
const E = (name, mock, cap, ms) => [`<span style="color: ${T.accent}; font-weight: 500">边界 · ${name}</span>`, mock, cap, ms];

const section = (title, tags, now, st, fl, ed) => `
  <div style="width: ${CW}px; height: ${SEC_H}px; flex: none">
    <div style="height: ${TITLE_H}px; display: flex; align-items: center; gap: 6px; margin-bottom: 6px; border-bottom: 1px solid ${T.bSubtle}">
      <div style="font-weight: 500; color: ${T.fg1}; white-space: nowrap; font-size: 12.5px">${title}</div>${tags}
      <div style="flex: 1; min-width: 0; text-align: right; font-size: 10px; color: ${T.fg5}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${now}</div>
    </div>
    <div style="display: flex; flex-direction: column; gap: ${RGAP}px">${row('st', st)}${row('fl', fl)}${row('ed', ed)}</div>
  </div>`;

// =================== 1 通知：按类型开关 · 位置 ===================
const notifRows = (o = {}) => [
  ['生成完成', true], ['导出完成', o.exportOff ? false : true], ['失败', true], ['撤销', true], ['一般提示', o.generalOn || false],
].map(([l, on]) => trow(l, on)).join('');
const corner = (pos) => `
  <div style="position: relative; width: 44px; height: 30px; flex: none; box-sizing: border-box; border: 1px solid ${T.controlStrong}; border-radius: 3px; background: ${T.s3}">
    <div style="position: absolute; left: 0; right: 0; top: 0; height: 4px; background: ${T.s4}"></div>
    <div style="position: absolute; ${pos.includes('r') ? 'right' : 'left'}: 3px; ${pos.includes('b') ? 'bottom' : 'top'}: ${pos.includes('b') ? 3 : 7}px; width: 11px; height: 6px; border-radius: 1px; background: ${T.accent}"></div>
  </div>`;
const settingsNav = `
  <div style="display: flex; gap: 6px; height: 100%">
    <div style="width: 52px; flex: none; display: flex; flex-direction: column; gap: 2px; font-size: 9px; color: ${T.fg4}">
      <div style="height: 14px; padding: 0 4px; border-radius: 2px; background: ${T.wash}; color: ${T.accent}; display: flex; align-items: center">常规</div>
      <div style="height: 14px; padding: 0 4px; display: flex; align-items: center">API 密钥</div>
      <div style="height: 14px; padding: 0 4px; display: flex; align-items: center">快捷键</div>
      <div style="height: 14px; padding: 0 4px; display: flex; align-items: center">性能</div>
    </div>
    <div style="flex: 1; min-width: 0; font-size: 9px; color: ${T.fg4}; line-height: 13px">
      <div style="color: ${T.fg1}; font-weight: 500">通知</div><div>提示音 · InkFrame 默认</div><div>停留时长 · 标准</div>
      <div style="color: ${T.fg2}; display: flex; align-items: center; gap: 3px">显示哪些通知 ${newTag}</div><div>位置 ${newTag}</div>
    </div>
  </div>`;
const bellGlyph = (dot) => `<span style="position: relative; display: inline-flex; color: ${T.fg3}">${ic('bell', 15)}${dot ? `<span style="position: absolute; right: -1px; top: 0; width: 5px; height: 5px; border-radius: 3px; background: ${dot}"></span>` : ''}</span>`;
const histRow = (k, title, when) => `<div style="height: 18px; display: flex; align-items: center; gap: 5px; font-size: 9px"><span style="width: 14px; height: 14px; border-radius: 2px; background: ${T.s5}; display: flex; align-items: center; justify-content: center; color: ${KC[k]}">${ic(k, 10)}</span><span style="flex: 1; color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</span><span style="color: ${T.fg6}">${when}</span></div>`;
const miniWin = (inner, o = {}) => `
  <div style="position: relative; height: 100%; box-sizing: border-box; border: 1px solid ${T.controlStrong}; border-radius: 3px; background: ${T.s0}; overflow: hidden">
    <div style="position: absolute; left: 0; right: 0; top: 0; height: 9px; background: ${T.s4}; border-bottom: 1px solid ${T.bStrong}; font-size: 7px; color: ${T.fg6}; line-height: 9px; padding-left: 3px">${o.title || ''}</div>
    ${o.rail ? `<div style="position: absolute; left: 0; top: 9px; bottom: 7px; width: 9px; background: ${T.s4}; border-right: 1px solid ${T.bStrong}"></div>` : ''}
    <div style="position: absolute; left: 0; right: 0; bottom: 0; height: 7px; background: ${T.s3}; border-top: 1px solid ${T.bStrong}"></div>
    ${inner}
  </div>`;

const sec1 = section('通知：按类型开关 · 位置', prio('P2'),
  `现状：只有提示音 / 停留时长（notifications_section.dart）；ToastKind 六种不分来源，类别要新增 ${code('ToastCategory')}`,
  [
    S('默认', `<div style="display: flex; flex-direction: column; gap: 0">${notifRows()}</div>`, '生成完成 / 导出完成 / 失败 / 撤销开，一般提示关'),
    S('悬停 · 聚焦', `<div style="display: flex; flex-direction: column; gap: 1px">${trow('生成完成', true)}${trow('导出完成', true, { hot: true, focus: true })}${trow('失败', true)}</div>${cursor(70, 22)}`, '整行 s5；Tab 到开关出 accent 焦点环，空格切换'),
    S('已关一类', `<div style="display: flex; flex-direction: column; gap: 1px">${trow('导出完成', false)}</div>${note('关了：不出卡 · 不响 · 不发系统通知')}${note('铃铛照记一行，不加未读', T.fg6)}`, '关掉的类别三样都停；铃铛照记（N1 建议 A）'),
    S('位置', `<div style="display: flex; gap: 6px; align-items: flex-start">${corner('rb')}<div style="display: flex; flex-wrap: wrap; gap: 3px">${chip('跟随系统', true)}${chip('右下')}${chip('右上')}${chip('左下')}${chip('左上')}</div></div>${note('此刻落在：右下（Windows）')}`, '五选一；选跟随系统时旁边写出实际落在哪个角'),
  ],
  [
    F(1, settingsNav, '打开设置 › 常规，通知组接在提示音 / 停留时长下'),
    F(2, `<div style="display: flex; flex-direction: column; gap: 1px">${trow('撤销', true)}${trow('一般提示', true, { hot: true })}</div>${cursor(110, 18)}${note('当场写 preferences.json · toastMuted')}`, '点一下就生效，无「保存」；存字符串集合 → 枚举'),
    F(3, miniWin(`<div style="position: absolute; left: 8px; top: 20px; width: 46px; height: 24px; border: 1px solid ${T.accent}; border-radius: 2px; background: ${T.s3}"></div><div style="position: absolute; right: 6px; bottom: 12px; width: 70px; height: 20px; box-sizing: border-box; border: 1px dashed ${T.control}; border-radius: 3px; font-size: 8px; color: ${T.fg6}; display: flex; align-items: center; justify-content: center">不出卡</div>`, { title: 'Ctrl D 复制一份' }), '之后的「已复制」类提示不出卡、不响'),
    F(4, mmenu(`<div style="display: flex; align-items: center; height: 15px; font-size: 9.5px; color: ${T.fg1}; padding: 0 3px">通知<span style="flex: 1"></span>${bellGlyph('')}</div>${histRow('info', '已复制 1 个节点', '刚刚')}${histRow('success', '镜头 02 已生成', '3 分钟前')}`), '铃铛历史照记，铃铛不亮点；打开历史即全部已读（现状）'),
  ],
  [
    E('在场的卡', mtoast({ k: 'info', title: '已复制 1 个节点', count: 55 }) + note('关掉时它已在场：照原计时走完'), '关类别不收回在场的卡；只管之后到达的'),
    E('当场失败', mtoast({ k: 'error', title: '保存失败', body: '磁盘空间不足' }) + note('「失败」关着也出'), '「失败」只管后台任务；当场操作出错照出（N3 A）'),
    E('进度卡', mtoast({ k: 'progress', title: '正在导出 · 8 镜', pct: 42, act: '取消' }), '带「取消」的进度卡不受任何开关管'),
    E('macOS 右上', miniWin(`<div style="position: absolute; right: 4px; top: 12px; width: 64px; height: 14px; border-radius: 2px; background: ${T.s4}; border: 1px solid ${T.accent}"></div><div style="position: absolute; right: 4px; top: 29px; width: 64px; height: 14px; border-radius: 2px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}"></div>${note('')}`, { title: '40 标题栏', rail: true }), 'mac 右上：让开标题栏，最新贴角往下长；改角在场卡平移不重计时'),
  ],
);

// =================== 2 面板调宽 · 收起全部 ===================
const edgeMock = (o = {}) => `
  <div style="position: relative; height: 100%; display: flex; border: 1px solid ${T.outline}; border-radius: 2px; overflow: hidden">
    <div style="width: 6px; flex: none; background: ${T.s4}; border-right: 1px solid ${T.bStrong}"></div>
    ${o.collapsed ? '' : `<div style="position: relative; width: ${o.pw || 44}px; flex: none; background: ${T.s3}">
      <div style="margin: 6px 5px 0; height: 3px; background: ${T.control}; border-radius: 1px"></div>
      <div style="margin: 4px 5px 0; height: 3px; width: 60%; background: ${T.control}; border-radius: 1px"></div>
      <div style="margin: 4px 5px 0; height: 3px; width: 75%; background: ${T.control}; border-radius: 1px"></div>
      <div style="position: absolute; right: 0; top: 0; bottom: 0; width: ${o.hot ? 2 : 1}px; background: ${o.hot ? T.accent : T.bStrong}"></div>
      ${o.zone ? `<div style="position: absolute; right: -3px; top: 0; bottom: 0; width: 6px; border-left: 1px dashed ${T.washBorder}; border-right: 1px dashed ${T.washBorder}"></div>` : ''}
    </div>`}
    <div style="flex: 1; background-image: radial-gradient(${T.grid} 1px, transparent 1px); background-size: 7px 7px; position: relative">${o.stage || ''}</div>
    ${o.noInsp ? '' : `<div style="width: ${o.iw || 26}px; flex: none; background: ${T.s3}; border-left: 1px solid ${T.bStrong}"></div>`}
    ${o.bubble ? `<div style="position: absolute; left: ${(o.pw || 44) - 4}px; top: 30px; height: 14px; padding: 0 4px; border-radius: 3px; background: ${T.s5}; border: 1px solid ${T.overlayBorder}; font-family: ${MONO}; font-size: 8.5px; color: ${o.bubbleC || T.fg1}; display: flex; align-items: center; white-space: nowrap; z-index: 3">${o.bubble}</div>` : ''}
    ${o.cur ? cursor((o.pw || 44) + 2, 50, 'resize') : ''}
  </div>`;
const sec2 = section('面板调宽 · 收起全部面板', prio('P2'),
  `现状：${code('LeftRailPanel.width = 241')}、${code('CanvasInspectorPanel.width = 301')} 都是常量，没有收起检查器`,
  [
    S('默认', edgeMock(), '右沿看上去仍是 1px 线；热区 6px（虚线只在这里画）'),
    S('悬停', edgeMock({ hot: true, cur: true }), '变 2px accent，光标换左右箭头'),
    S('拖动中', edgeMock({ hot: true, pw: 58, bubble: '↔ 280' }), '跟手，旁边气泡写当前内容宽'),
    S('到界', edgeMock({ hot: true, pw: 70, bubble: '420 · 最大', bubbleC: T.fg4 }), '200–420 夹住，不弹；检查器 260–480（P1 A）'),
  ],
  [
    F(1, edgeMock({ hot: true, zone: true, cur: true }), '按住右沿热区'),
    F(2, edgeMock({ hot: true, pw: 60, bubble: '↔ 280', iw: 22 }), '拖到 280，舞台当场让宽'),
    F(3, edgeMock({ pw: 60, stage: note('写 leftPanelWidth', T.fg4).replace('<div', '<div style="padding: 4px"><div') + '</div>' }), '松手才落盘 preferences.json，全局一个值'),
    F(4, edgeMock({ hot: true, pw: 44, bubble: '↺ 240' }), '双击右沿回默认 240'),
  ],
  [
    E('窗口变窄', `<div style="display: flex; gap: 3px; height: 100%">${['压检查器', '压左面板', '收起左面板'].map((t, i) => `<div style="flex: 1; display: flex; flex-direction: column; gap: 2px"><div style="flex: 1">${edgeMock({ pw: [40, 26, 0][i], collapsed: i === 2, iw: [14, 14, 14][i] })}</div>${note(t)}</div>`).join('')}</div>`, '舞台至少 480；不够就逐级压，最后自动收起，记住的宽不动'),
    E('收起全部', edgeMock({ collapsed: true, noInsp: true, stage: `<div style="padding: 4px">${kbd('Ctrl Shift \\', T.fg2)}<br>${kbd('⌘⇧\\', T.fg2)}</div>` }), '两侧一起收，导航条留着；Win Ctrl Shift \\ / mac ⌘⇧\\'),
    E('再按恢复', `<div style="display: flex; flex-direction: column; gap: 2px; height: 100%"><div style="flex: 1">${edgeMock({ collapsed: true })}</div>${note('收起前：左关、检查器开 → 恢复成这样')}</div>`, '恢复收起前各自的开合；Ctrl \\ 仍只管左面板'),
    E('拖动中 Esc', edgeMock({ hot: true, pw: 44, bubble: 'Esc ↺ 原宽', bubbleC: T.fg4 }), '拖到一半按 Esc：回按下前的宽，不落盘（细化）'),
  ],
);

// =================== 3 大纲行：改名 · 右键 · 拖动排序 ===================
const oRow = (n, src, name, o = {}) => `
  <div style="position: relative; height: 18px; display: flex; align-items: center; gap: 5px; padding: 0 5px; ${o.sel ? `background: ${T.s5};` : ''} ${o.hot ? `background: ${T.s4};` : ''} ${o.ghost ? `border: 1px dashed ${T.control}; border-radius: 2px; opacity: 0.45; box-sizing: border-box;` : ''} ${o.dim ? 'opacity: 0.55;' : ''}">
    <span style="width: 12px; font-family: ${MONO}; font-size: 8.5px; color: ${o.sel ? T.accent : T.fg5}">${n}</span>${thumb(src, 20, 11)}
    ${o.edit ? `<span style="flex: 1; height: 14px; box-sizing: border-box; border: 1px solid ${T.accent}; border-radius: 2px; background: ${T.s1}; display: flex; align-items: center; padding: 0 3px; font-size: 9px"><span style="background: ${T.washBorder}; color: ${T.fg1}">${o.edit}</span><span style="width: 1px; height: 9px; background: ${T.fg1}"></span></span>`
    : `<span style="flex: 1; min-width: 0; font-size: 9.5px; color: ${o.sel ? T.fg1 : T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${name}</span>`}${o.right || ''}
  </div>`;
const gHead = (label, cnt, tint) => `<div style="height: 13px; display: flex; align-items: center; gap: 4px; padding: 0 5px; font-size: 8.5px; color: ${T.fg5}">${tint ? `<span style="width: 6px; height: 6px; border-radius: 1px; background: ${tint}"></span>` : ''}${label}<span style="font-family: ${MONO}; color: ${T.fg6}">${cnt}</span></div>`;
const insLine = `<div style="position: relative; height: 2px; margin: 0 5px; background: ${T.accent}"><span style="position: absolute; left: -2px; top: -2px; width: 5px; height: 5px; border-radius: 3px; background: ${T.accent}"></span></div>`;
const dragGhost = (top, label = '03 两人对视') => `<div style="position: absolute; left: 26px; top: ${top}px; width: 96px; height: 16px; box-sizing: border-box; padding: 0 5px; display: flex; align-items: center; gap: 4px; background: ${T.s5}; border: 1px solid ${T.overlayBorder}; border-radius: 3px; box-shadow: 0 6px 14px rgba(0,0,0,0.55); font-size: 9px; color: ${T.fg1}; z-index: 4">${thumb('', 14, 8)}${label}</div>`;
const outlineBase = (rows) => panel(`${gHead('水墨风格', '3 镜', T.teal)}${rows}`, 'height: 100%');
const sec3 = section('大纲行：改名 · 右键 · 拖动排序', prio('P1'),
  `现状：行只有 onTap = 单选 + 居中（outline_panel.dart），仓库里没有改节点名的入口`,
  [
    S('悬停 · 选中', outlineBase(`${oRow('01', IMG.thumbMountain, '山脊远景', { hot: true })}${oRow('02', IMG.thumbWide, '推近', { sel: true })}${oRow('03', '', '两人对视')}`), '悬停 s4；选中 s5 + 镜号 accent（与画布单选同步）'),
    S('改名中', outlineBase(`${oRow('01', IMG.thumbMountain, '山脊远景')}${oRow('02', IMG.thumbWide, '', { sel: true, edit: '雾中老人' })}${oRow('03', '', '两人对视')}`), '双击进入，全选原名；↵ / 失焦存，一步撤销'),
    S('拖动中', `<div style="position: relative; height: 100%">${outlineBase(`${oRow('01', IMG.thumbMountain, '山脊远景')}${insLine}${oRow('02', IMG.thumbWide, '推近')}${oRow('03', '', '两人对视', { ghost: true })}`)}${dragGhost(30)}</div>`, '原位留虚线，浮影跟手，插入线指落点'),
    S('不可拖', `<div style="position: relative; height: 100%">${panel(`${gHead('未入链', '2')}${oRow('—', '', '收尾远景', { dim: true })}${oRow('', '', 'take 2 · 成片', { dim: true })}${oRow('', '', '生成中…', { dim: true, right: spinIc(10) })}`, 'height: 100%')}${cursor(80, 30, 'no')}</div>`, '未入链、产物子行、生成中：按住不起拖，光标禁止'),
  ],
  [
    F(1, outlineBase(`${oRow('01', IMG.thumbMountain, '山脊远景')}${oRow('02', IMG.thumbWide, '推近')}${oRow('03', '', '两人对视', { hot: true })}`) + cursor(70, 50), '按住 03'),
    F(2, `<div style="position: relative; height: 100%">${outlineBase(`${oRow('01', IMG.thumbMountain, '山脊远景')}${oRow('02', IMG.thumbWide, '推近')}${oRow('03', '', '两人对视', { ghost: true })}`)}${dragGhost(36)}</div>`, '挪过 4px 才起拖（与框选同一阈值）'),
    F(3, `<div style="position: relative; height: 100%">${outlineBase(`${oRow('01', IMG.thumbMountain, '山脊远景')}${insLine}${oRow('02', IMG.thumbWide, '推近')}${oRow('03', '', '两人对视', { ghost: true })}`)}${dragGhost(30)}</div>`, '插入线落在 01 之后'),
    F(4, outlineBase(`${oRow('01', IMG.thumbMountain, '山脊远景')}${oRow('02', '', '两人对视', { sel: true })}${oRow('03', IMG.thumbWide, '推近')}`), '松手：叙事边摘出再接上，一个事务；镜号重排'),
  ],
  [
    E('改名放弃', outlineBase(`${oRow('02', IMG.thumbWide, '', { sel: true, edit: '' })}${note('Esc → 回原名「推近」')}${note('清空后存 → 回类型名「图像配置」')}`), 'Esc 放弃；清空回类型名'),
    E('越组', `<div style="position: relative; height: 100%">${panel(`${gHead('水墨风格', '3 镜', T.teal)}${oRow('03', '', '两人对视', { ghost: true })}${gHead('未分泳道', '1 镜')}${oRow('04', '', '收尾远景')}`, 'height: 100%')}${dragGhost(52)}${cursor(110, 56, 'no')}</div>`, '拖进别的组：无插入线，松手回弹（O1 A）'),
    E('写边失败', mtoast({ k: 'error', title: '没能调整顺序', body: '已恢复原顺序' }) + note('大纲回到拖之前'), '事务回滚，行回原位，出错误卡'),
    E('右键', mmenu(`${mi('生成', kbd('Ctrl ↵'))}${mi('复制一份', kbd('Ctrl D'))}${msep}${mi('删除')}`), '弹节点右键菜单原样；没选中的行先单选'),
  ],
);

// =================== 4 角色：按类型分组 · 被引用可点 ===================
const cRow = (src, name, meta, o = {}) => `
  <div style="height: 20px; display: flex; align-items: center; gap: 5px; padding: 0 5px; ${o.hot ? `background: ${T.s4};` : ''}">
    ${thumb(src, 15, 15)}
    <div style="flex: 1; min-width: 0; line-height: 10px"><div style="font-size: 9.5px; color: ${T.fg3}">${name}</div><div style="font-size: 8.5px; color: ${T.fg6}">${meta}</div></div>
  </div>`;
const refLink = (t) => `<span style="color: ${T.accent}; text-decoration: underline">${t}</span>`;
const refChip = (label, hot) => `<span style="display: inline-flex; align-items: center; height: 15px; padding: 0 5px; border-radius: 2px; box-sizing: border-box; font-size: 8.5px; white-space: nowrap; border: 1px solid ${hot ? T.washBorder : T.controlStrong}; background: ${hot ? T.wash : 'transparent'}; color: ${hot ? T.accent : T.fg3}">${label}${hot ? ' ↗' : ''}</span>`;
const miniTabs = (on) => `<div style="display: flex; gap: 2px; height: 13px; font-size: 8.5px">${['工作室', '画布 2', '序列'].map((t) => `<span style="padding: 0 5px; display: flex; align-items: center; border-radius: 2px; ${t === on ? `background: ${T.s5}; color: ${T.fg1}` : `color: ${T.fg5}`}">${t}</span>`).join('')}</div>`;
const nodeCard = (label, sel) => `<div style="width: 58px; height: 30px; box-sizing: border-box; border-radius: 3px; background: ${T.s3}; border: 1px solid ${sel ? T.accent : T.outline}; padding: 3px; font-size: 8px; color: ${T.fg2}">${label}</div>`;
const sec4 = section('角色：按类型分组 · 被引用可点', prio('P2'),
  `现状：不分类型；行写「N 张参考图 · M 处引用 / 未引用」，编辑框「被引用」chip 不可点`,
  [
    S('分组', panel(`${gHead('角色', '1')}${cRow(IMG.thumbMountain, '阿青', '3 张参考图 · 4 处引用')}${gHead('场景', '1')}${cRow(IMG.thumbWide, '雾中山脊', '1 张参考图 · 2 处引用')}`, 'height: 100%'), '角色 → 物品 → 场景；空组（此处物品）不画'),
    S('引用悬停', panel(`${gHead('角色', '1')}${cRow(IMG.thumbMountain, '阿青', `3 张参考图 · ${refLink('4 处引用')}`, { hot: true })}`, 'height: 100%') + cursor(90, 36), '「M 处引用」悬停 accent 下划线，点了开引用列表'),
    S('未引用', panel(`${gHead('物品', '1')}${cRow('', '青铜灯', '2 张参考图 · 未引用')}`, 'height: 100%'), '「未引用」是纯文字，不可点（现状文案）'),
    S('空态', panel(`<div style="padding: 14px 6px; text-align: center; font-size: 9px; color: ${T.fg5}; line-height: 13px">还没有角色 · 从节点结果「存为角色」开始</div>`, 'height: 100%'), '一个都没有：照现状空态，不画三个空组'),
  ],
  [
    F(1, mmenu(`<div style="font-size: 9px; color: ${T.fg4}; height: 13px">被引用</div><div style="display: flex; flex-wrap: wrap; gap: 3px">${refChip('画布 1 · 镜头 01')}${refChip('画布 2 · 镜头 04', true)}</div>`) + cursor(100, 30), '编辑框里点「画布 2 · 镜头 04」'),
    F(2, mmenu(`<div style="font-size: 9.5px; color: ${T.fg1}; font-weight: 500">有没保存的改动</div><div style="font-size: 8.5px; color: ${T.fg4}; margin: 2px 0 4px">先保存再去？</div><div style="display: flex; gap: 3px; justify-content: flex-end">${mbtn('取消')}${mbtn('放弃')}${mbtn('保存并前往', { primary: true })}</div>`), '有未存改动先问；没有就直接走'),
    F(3, `${miniTabs('画布 2')}<div style="margin-top: 6px; display: flex; gap: 6px">${nodeCard('镜头 03', false)}${nodeCard('镜头 04', false)}</div>`, '关框；跨画布先 openCanvas 画布 2'),
    F(4, `${miniTabs('画布 2')}<div style="margin-top: 6px; display: flex; gap: 6px; justify-content: center">${nodeCard('镜头 04', true)}</div>`, '单选镜头 04 并居中（挂起定位请求）'),
  ],
  [
    E('改类型', mmenu(`<div style="font-size: 9px; color: ${T.fg4}; height: 13px">类型</div><div style="display: flex; gap: 3px">${chip('角色')}${chip('物品', true)}${chip('场景')}</div>${note('保存后这一行移到「物品」组')}`), '编辑框三段切换；类型不进提示词（C1 A）'),
    E('老项目包', `<div style="font-size: 9px; color: ${T.fg3}; line-height: 13px">导入 2025 年的项目包<br>${code('characters')} 没有 ${code('kind')} 列<br>→ 全部落默认「角色」</div>`, '前向迁移加列带默认值；老包导入不报错'),
    E('引用已不在', mmenu(`<div style="font-size: 9px; color: ${T.fg4}; height: 13px">被引用</div><div style="display: flex; gap: 3px">${refChip('画布 1 · 镜头 01')}</div>${note('镜头 04 已删：chip 不再列')}`), '引用按实时节点算，删掉的不列，不会点空'),
  ],
);

// =================== 5 素材：悬停预览 · 导入 ===================
const aTile = (src, label, o = {}) => `
  <div style="width: 54px; flex: none">
    <div style="position: relative; width: 54px; height: 30px; border-radius: 2px; overflow: hidden; ${o.hot ? `outline: 2px solid ${T.accent}; outline-offset: 1px;` : `outline: 1px solid ${T.outline};`}">
      ${src ? `<img src="${src}" alt="" style="width: 54px; height: 30px; object-fit: cover; display: block">` : `<div style="width: 54px; height: 30px; background: ${T.thumb}"></div>`}
      ${o.imp ? `<span style="position: absolute; left: 2px; top: 2px; height: 10px; line-height: 10px; padding: 0 2px; border-radius: 2px; font-size: 7.5px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}">导入</span>` : ''}
    </div>
    <div style="font-size: 8px; color: ${T.fg4}; margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; ${o.mono ? `font-family: ${MONO}` : ''}">${label}</div>
  </div>`;
const assetsPanel = (tiles, extra = '', pw = 128) => `<div style="position: relative; height: 100%">${panel(`<div style="display: flex; gap: 2px; padding: 3px 4px 0; overflow: hidden">${pill('全部 6', true)}${pw > 100 ? pill('图片 3') + pill('视频 1') : ''}</div><div style="display: flex; gap: 6px; padding: 5px 5px 0">${tiles}</div>`, `width: ${pw}px; height: 100%`)}${extra}</div>`;
const preview = (left, inner) => `<div style="position: absolute; left: ${left}px; top: 2px; width: 64px; box-sizing: border-box; padding: 3px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 10px 24px rgba(0,0,0,0.6); z-index: 3">${inner}</div>`;
const sec5 = section('素材：悬停预览 · 导入的怎么显示', prio('P2'),
  `现状：两列网格，chip 只有 全部 / 图片 / 视频（assets_model.dart），没有悬停预览`,
  [
    S('悬停计时', assetsPanel(`${aTile(IMG.thumbMountain, '山脊远景 · take 2', { hot: true })}${aTile(IMG.thumbWide, '推近 · 成片')}`) + cursor(30, 34), '描边 accent；不到 400ms 不出预览'),
    S('图片预览', assetsPanel(`${aTile(IMG.thumbMountain, '山脊远景 · take 2', { hot: true })}`, preview(68, `<img src="${IMG.mountain}" alt="" style="width: 100%; height: 34px; object-fit: cover; display: block; border-radius: 2px">${note('1920×1080 · 今天 14:20', T.fg4)}`), 66), '贴面板右沿外；下面一行尺寸与时间'),
    S('视频预览', assetsPanel(`${aTile(IMG.thumbWide, '推近 · 成片', { hot: true })}`, preview(68, `<div style="position: relative"><img src="${IMG.wide}" alt="" style="width: 100%; height: 34px; object-fit: cover; display: block; border-radius: 2px"><div style="position: absolute; left: 0; bottom: 0; height: 2px; width: 40%; background: ${T.accent}"></div><span style="position: absolute; right: 2px; top: 2px; color: ${T.fg1}; display: flex">${ic('soundOff', 10)}</span></div>${note('静音 · 循环前 6 秒', T.fg4)}`), 66), '静音循环前 6 秒，底部细进度条'),
    S('空态', panel(`<div style="display: flex; gap: 2px; padding: 3px 4px 0">${pill('本画布', true)}${pill('项目全部')}</div><div style="padding: 14px 6px; text-align: center; font-size: 9px; color: ${T.fg5}">还没有生成的素材</div>`, 'height: 100%'), '没有项目时写「打开一个项目后显示素材」（现状）'),
  ],
  [
    F(1, assetsPanel(`${aTile(IMG.thumbMountain, '山脊远景 · take 2', { hot: true })}${aTile(IMG.thumbWide, '推近 · 成片')}`) + cursor(30, 34), '指到格子，开始计 400ms'),
    F(2, assetsPanel(`${aTile(IMG.thumbMountain, '山脊远景', { hot: true })}`, preview(68, `<img src="${IMG.mountain}" alt="" style="width: 100%; height: 40px; object-fit: cover; display: block; border-radius: 2px">`), 66), '时间到，预览浮出'),
    F(3, assetsPanel(`${aTile(IMG.thumbMountain, '山脊远景')}${aTile(IMG.thumbWide, '推近', { hot: true })}`, preview(68, `<img src="${IMG.wide}" alt="" style="width: 100%; height: 40px; object-fit: cover; display: block; border-radius: 2px">`), 66), '预览开着时移到邻格：直接换内容，不再等（细化）'),
    F(4, assetsPanel(`${aTile(IMG.thumbMountain, '山脊远景')}`, `<div style="position: absolute; left: 72px; top: 8px; font-size: 9px; color: ${T.fg5}; line-height: 13px">移出<br>滚动<br>按任意键</div>`, 66), '三者任一，预览立即收'),
  ],
  [
    E('导入的格', assetsPanel(`${aTile(IMG.thumbWide, 'ref_山脊.jpg', { imp: true, mono: true })}${aTile(IMG.thumbMountain, '山脊 · take 2')}`), '左上「导入」标；标签 = 原文件名，没有 take 号'),
    E('来源筛选', `<div style="display: flex; gap: 2px; flex-wrap: wrap">${pill('全部 6')}${pill('图片 3', false, true)}${pill('视频 1', false, true)}${pill('导入 2', true)}</div>${note('选「导入」时图片 / 视频退选（互斥）')}${note(`判据只看 origin == import；画廊同加`, T.fg6)}`, '「导入」与图片 / 视频互斥'),
    E('文件缺失', assetsPanel(`${aTile('', '山脊远景 · take 1', { hot: true })}`, preview(68, `<div style="height: 40px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 2px; background: ${T.thumb}; color: ${T.fg5}; font-size: 8.5px">${ic('warning', 12)}图片文件缺失</div>`), 66), '预览画缺失提示（同检查器文案），不出空框'),
  ],
);

// =================== 6 序列：回画布定位并重生成 ===================
const qRow = (idx, src, name, o = {}) => `
  <div style="position: relative; height: 16px; display: flex; align-items: center; gap: 4px; padding: 0 5px; border-bottom: 1px solid ${T.bSubtle}; ${o.sel ? `background: ${T.s5};` : ''}">
    ${o.sel ? `<div style="position: absolute; left: 0; top: 0; bottom: 0; width: 2px; background: ${T.accent}"></div>` : ''}
    <span style="font-family: ${MONO}; font-size: 8.5px; color: ${o.sel ? T.accent : T.fg5}; width: 18px">${idx}</span>${thumb(src, 18, 10)}
    <span style="flex: 1; min-width: 0; font-size: 9px; color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${name}</span>${o.right || ''}
  </div>`;
const chain = (sel = '002', o = {}) => panel(`${qRow('001', IMG.thumbMountain, '镜头 01 山脊远景')}${qRow('002', IMG.thumbWide, '镜头 02 推近', { sel: sel === '002', right: o.right })}${qRow('003', '', '镜头 03 两人对视', { sel: sel === '003' })}`, 'height: 100%');
const seqMenu = (o = {}) => mmenu(`${mi('在画布中定位')}${mi('定位并重生成', o.right2 || kbd('约 $0.75'), { hot: o.hot, dis: o.dis })}${o.reason ? `<div style="font-size: 8px; color: ${T.fg6}; padding: 0 5px 2px 5px">${o.reason}</div>` : `${msep}${mi('从这一镜播放')}`}`);
const capsule = (label, active = true) => `<span style="display: inline-flex; align-items: center; gap: 4px; height: 15px; padding: 0 6px; border-radius: 8px; box-sizing: border-box; font-size: 8.5px; white-space: nowrap; ${active ? `background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}` : `border: 1px solid ${T.outline}; color: ${T.fg5}`}">${active ? spinIc(9) : ''}${label}</span>`;
const statusBar = (inner) => `<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 18px; background: ${T.s1}; border-top: 1px solid ${T.bStrong}; display: flex; align-items: center; gap: 5px; padding: 0 5px; font-size: 8.5px; color: ${T.fg5}">${inner}</div>`;
const sec6 = section('序列：回画布定位并重生成', prio('P1'),
  `现状：叙事链行与 V1 片段只有点按 = selectShot（sequence_screen.dart），没有右键`,
  [
    S('菜单', `<div style="position: relative; height: 100%">${chain()}<div style="position: absolute; left: 6px; top: 10px; right: 0">${seqMenu()}</div></div>`, '两项都可点，价格读 cost_estimator'),
    S('悬停项', `<div style="position: relative; height: 100%">${chain()}<div style="position: absolute; left: 6px; top: 10px; right: 0">${seqMenu({ hot: true })}</div></div>`, '整行 s5；↑↓ 移动、↵ 选'),
    S('置灰 · 无配置', `<div style="position: relative; height: 100%">${chain('003')}<div style="position: absolute; left: 6px; top: 26px; right: 0">${seqMenu({ dis: true, right2: '', reason: '还没有配置节点' })}</div></div>`, '只有镜头节点：「并重生成」灰，原因写在下面'),
    S('置灰 · 在途', `<div style="position: relative; height: 100%">${chain('002', { right: spinIc(9) })}<div style="position: absolute; left: 6px; top: 10px; right: 0">${seqMenu({ dis: true, right2: '', reason: '正在生成' })}</div></div>`, '这一镜提交中 / 生成中：灰（与提示词条在途置灰同口径）'),
  ],
  [
    F(1, `<div style="position: relative; height: 100%">${chain()}${cursor(70, 22)}</div>`, '右键 002（叙事链行或 V1 片段）'),
    F(2, `<div style="position: relative; height: 100%">${chain()}<div style="position: absolute; left: 6px; top: 10px; right: 0">${seqMenu({ hot: true })}</div></div>`, '选「在画布中定位并重生成」（样稿里缩写）'),
    F(3, `${miniTabs('画布 2').replace('画布 2', '画布')}<div style="margin-top: 6px; display: flex; justify-content: center">${nodeCard('镜头 02 · 配置', true)}</div>`, '切画布标签，单选生成节点并居中'),
    F(4, `<div style="position: relative; height: 100%">${mtoast({ thumb: IMG.thumbWide, title: '镜头 02 推近 已生成', act: '查看' })}${statusBar(`<span style="flex: 1"></span>${capsule('生成中 1')}`)}</div>`, '提交，胶囊「生成中 1」；完成出卡，播放头不动'),
  ],
  [
    E('闸不过', `<div style="font-size: 9px; color: ${T.fg3}; line-height: 13px">没配 Key：</div>${note('只定位，不提交')}<div style="margin-top: 4px">${mbtn('生成', { primary: true, dis: true })}</div>${note('请在设置中配置 API Key', T.fg4)}`, '项照样可点；只定位，检查器写闸的原因'),
    E('价格未知', seqMenu({ right2: kbd('—') }), '自定义接口估不出价：写「—」，不写 $0.00'),
    E('生成失败', `${mtoast({ k: 'error', title: '镜头 02 推近 生成失败', body: '服务商超时' })}${note('同一节点再失败：替换这一张')}`, '失败卡不自动消失；同一节点只占一张（现状 dedupe）'),
    E('mac 右键', `<div style="font-size: 9px; color: ${T.fg3}; line-height: 14px">Windows：右键<br>macOS：双指点按 / ${kbd('Ctrl')} 点击<br>都在抬起时开</div>`, '与画布右键同口径；按住拖动不开菜单'),
  ],
);

// =================== 7 剧本导入对话框 ===================
const dlg = (inner, foot) => `<div style="height: 100%; box-sizing: border-box; display: flex; flex-direction: column; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; overflow: hidden"><div style="height: 13px; padding: 0 5px; font-size: 9px; color: ${T.fg1}; font-weight: 500; border-bottom: 1px solid ${T.bStrong}">导入剧本</div><div style="flex: 1; padding: 3px 5px; overflow: hidden">${inner}</div><div style="height: 21px; display: flex; align-items: center; justify-content: flex-end; gap: 3px; padding: 0 4px; border-top: 1px solid ${T.bStrong}">${foot}</div></div>`;
const textArea = (inner, h = 18) => `<div style="height: ${h}px; box-sizing: border-box; padding: 2px 4px; background: ${T.s1}; border: 1px solid ${T.controlStrong}; border-radius: 2px; font-size: 8.5px; line-height: 11px; color: ${T.fg3}; overflow: hidden; position: relative">${inner}</div>`;
const castC = (name, cand) => `<span style="display: inline-flex; align-items: center; gap: 2px; height: 13px; padding: 0 5px; border-radius: 7px; box-sizing: border-box; font-size: 8.5px; ${cand ? `border: 1px dashed ${T.washBorder}; color: ${T.accent}` : `background: ${T.s5}; color: ${T.fg2}`}">${name}${cand ? ' · 新建' : ''}</span>`;
const sec7 = section('剧本导入对话框：识别角色 · 估时长', prio('P1'),
  `现状：粘贴 → 拆分 → 预览 → 「创建分镜」，ShotDraft 只有 label + notes（script_import_dialog.dart）`,
  [
    S('空态', dlg(`${textArea(`<span style="color: ${T.fg6}">粘贴剧本…</span>`)}${note('还没有可导入的内容。')}`, `${mbtn('取消')}${mbtn('创建镜头', { primary: true, dis: true })}`), '没拆出镜头：主按钮灰（现状）'),
    S('预览', dlg(`${note('3 镜 · 约 9 秒 · 2 个角色（1 个新建）', T.fg3)}<div style="display: flex; gap: 3px; margin-top: 2px">${castC('阿青')}${castC('老人', true)}</div>`, `${mbtn('取消')}${mbtn('创建 3 个镜头', { primary: true })}`), '角色与时长现算，纯函数、不调 LLM'),
    S('创建中', dlg(`${note('3 镜 · 约 9 秒', T.fg3)}${note('输入与策略锁住', T.fg6)}`, `${mbtn('取消', { dis: true })}${mbtn('创建中', { primary: true, spin: true })}`), '一个事务；取消与创建都灰（现状 _busy）'),
    S('失败', dlg(`<div style="display: flex; gap: 3px; align-items: center; font-size: 8.5px; color: ${T.danger}">${ic('error', 11)}脚本导入失败，画布未做改动。</div>`, `${mbtn('取消')}${mbtn('创建 3 个镜头', { primary: true })}`), '零残留（含新建角色）；框不关，可重试'),
  ],
  [
    F(1, dlg(textArea('山脊上，阿青回头望。<br>雾里走出一个老人，提着一盏灯。<br>两人对视，很久没有说话。', 30), `${mbtn('创建 3 个镜头', { primary: true })}`), '粘贴；空行分段默认'),
    F(2, dlg(textArea(`雾里走出一个<span style="background: ${T.washBorder}; color: ${T.fg1}">老人</span>，提着一盏灯。<div style="position: absolute; left: 50px; top: 12px; height: 12px; padding: 0 4px; border-radius: 2px; background: ${T.s5}; border: 1px solid ${T.overlayBorder}; font-size: 8px; color: ${T.fg1}; display: flex; align-items: center">设为角色</div>`, 28), `${mbtn('创建 3 个镜头', { primary: true })}`), '选中「老人」，浮出「设为角色」'),
    F(3, dlg(`<div style="display: flex; gap: 3px">${castC('阿青')}${castC('老人', true)}</div><div style="display: flex; align-items: center; gap: 3px; margin-top: 4px; font-size: 8.5px; color: ${T.fg3}"><span style="width: 9px; height: 9px; border-radius: 2px; background: ${T.accent}"></span>把估算时长写进镜头</div>`, `${mbtn('创建 3 个镜头', { primary: true, hot: true })}`), '候选成虚线 chip；时长默认写入'),
    F(4, mtoast({ k: 'undo', title: '已添加 3 镜到画布', body: '新建角色「老人」', act: '撤销' }), '关框，出撤销卡；接到链尾'),
  ],
  [
    E('退掉候选', dlg(`<div style="display: flex; gap: 3px">${castC('阿青')}<span style="display: inline-flex; align-items: center; height: 13px; padding: 0 5px; border-radius: 7px; border: 1px dashed ${T.control}; color: ${T.fg6}; font-size: 8.5px; text-decoration: line-through">老人</span></div>${note('点候选取消勾：不新建、不挂')}`, `${mbtn('创建 3 个镜头', { primary: true })}`), '候选可退；已有角色的实心 chip 不能退'),
    E('同名已有', dlg(`<div style="display: flex; gap: 3px">${castC('阿青')}</div>${note('再选「阿青」：已有同名，不出候选')}`, `${mbtn('创建 3 个镜头', { primary: true })}`), '按名字匹配已有角色，不重复新建'),
    E('估时长', `<div style="font-size: 8.5px; color: ${T.fg3}; line-height: 13px; font-family: ${MONO}">中文 4 字 / 秒<br>英文 2.5 词 / 秒<br>最少 2 秒 · 显示「N 秒」/ m:ss</div>`, '与剧本面板同一个函数（只留一份）'),
    E('撤销整次', `<div style="font-size: 9px; color: ${T.fg3}; line-height: 13px">${kbd('Ctrl Z', T.fg2)} / ${kbd('⌘Z', T.fg2)} 一步：</div>${note('3 个镜头 + 叙事边 + 新建角色一起回退')}`, '撤销卡消失后快捷键照样能撤'),
  ],
);

// =================== 8 导出视频一键 ===================
const split = (o = {}) => `
  <div style="display: inline-flex; height: 19px; border-radius: 3px; overflow: hidden; border: 1px solid ${o.dis ? T.control : T.accent}; ${o.dis ? 'opacity: 0.5;' : ''}">
    <span style="display: flex; align-items: center; gap: 3px; padding: 0 6px; background: ${o.dis ? T.s4 : (o.hotMain ? T.accentHover : T.accent)}; color: ${o.dis ? T.fg4 : T.onAccent}; font-size: 9px; font-weight: 500; white-space: nowrap">${o.spin ? spinIc(10, T.onAccent) : ic('export', 10)}${o.label || '导出视频'}</span>
    <span style="display: flex; align-items: center; padding: 0 4px; background: ${o.dis ? T.s4 : (o.hotCaret ? T.accentHover : T.accent)}; border-left: 1px solid ${o.dis ? T.control : T.onAccent}; ${o.caretDis ? 'opacity: 0.5;' : ''}">${caret(o.dis ? T.fg5 : T.onAccent)}</span>
  </div>`;
const tabBar = (inner) => `<div style="height: 26px; box-sizing: border-box; display: flex; align-items: center; justify-content: flex-end; gap: 6px; padding: 0 4px; background: ${T.s1}; border: 1px solid ${T.outline}; border-radius: 2px">${inner}</div>`;
const sec8 = section('导出视频：按上次设置一键', prio('P2'),
  `现状：标签栏「导出视频」只开对话框（export_video_dialog.dart：进度条 + 取消导出）`,
  [
    S('默认', `${tabBar(split())}${note('上次：今天 14:20 · 8 镜')}`, '主体 = 按上次设置直接导出；▾ = 现有对话框'),
    S('悬停', `${tabBar(split({ hotMain: true }))}${cursor(108, 12)}${note('主体与 ▾ 分别高亮')}`, '两段各自悬停；tooltip 写上次规则'),
    S('禁用', `${tabBar(split({ dis: true }))}${note('画布上还没有视频生成结果', T.fg4)}`, '整颗灰，tooltip 照现状三种原因'),
    S('导出中', `${tabBar(split({ spin: true, label: '导出中', caretDis: true }))}${note('▾ 也灰；进度在通知卡')}`, '同一画布同时只导一份'),
  ],
  [
    F(1, `${tabBar(split({ hotMain: true }))}${cursor(108, 12)}`, '点主体'),
    F(2, mtoast({ k: 'progress', title: '正在导出 · 8 镜', pct: 36, act: '取消' }), '进度卡，带取消；不受类别开关管'),
    F(3, mtoast({ k: 'export', title: '已导出 镜头_20261017.mp4', body: '跳过 2 镜（没有视频）', act: '打开文件夹' }), '原地变完成卡，归「导出完成」类'),
    F(4, `<div style="font-family: ${MONO}; font-size: 8.5px; color: ${T.fg3}; line-height: 13px">镜头_20261017.mp4<br><span style="color: ${T.accent}">镜头_20261017 (2).mp4</span></div>${note('再导一次：不覆盖，自动加 (2)')}`, '同名不覆盖，依次 (2)、(3)'),
  ],
  [
    E('没导出过', `${tabBar(split({ label: '导出视频…' }))}${note('没有上次设置：主体也开对话框')}`, '首次永远走对话框'),
    E('预检不过', dlg(`<div style="font-size: 8px; color: ${T.danger}; line-height: 11px">未检测到 ffmpeg——安装后重试</div>${note('其余照现状对话框')}`, `${mbtn('取消')}${mbtn('导出', { primary: true, dis: true })}`).replace('导入剧本', '导出视频'), '开对话框，原因放顶上（现状文案）'),
    E('取消', `${mtoast({ k: 'info', title: '已取消导出' })}${note('不写 export_records · 不留半成品')}`, '取消后上次设置不变'),
    E('没有视频的镜', `<div style="font-size: 9px; color: ${T.fg3}; line-height: 13px">8 镜里 2 镜只有图</div>${note('照导 6 镜，完成卡写「跳过 2 镜」')}`, 'E1 建议 A：与对话框只列有视频的镜一致'),
  ],
);

// =================== 9 产物检查器（已实现） ===================
const insp = (inner, head = '镜头 01 · 图像') => `<div style="height: 100%; box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.bStrong}; overflow: hidden"><div style="height: 13px; display: flex; gap: 8px; padding: 0 5px; font-size: 8.5px; border-bottom: 1px solid ${T.bStrong}"><span style="color: ${T.fg1}; box-shadow: inset 0 -1px 0 ${T.accent}">属性</span><span style="color: ${T.fg5}">历史</span><span style="flex: 1"></span><span style="color: ${T.fg5}">${head}</span></div><div style="padding: 4px 5px">${inner}</div></div>`;
const pv = (inner) => `<div style="position: relative; height: 28px; border-radius: 2px; overflow: hidden; background: ${T.thumb}; border: 1px solid ${T.outline}; box-sizing: border-box; display: flex; align-items: center; justify-content: center; color: ${T.fg5}; font-size: 8.5px; gap: 3px">${inner}</div>`;
const playDot = `<span style="position: absolute; left: 50%; top: 50%; width: 16px; height: 16px; margin: -8px 0 0 -8px; box-sizing: border-box; border: 1.5px solid ${T.fg1}; border-radius: 8px; display: flex; align-items: center; justify-content: center"><svg width="7" height="7" viewBox="0 0 14 14" aria-hidden="true"><path d="M4.5 3l6 4-6 4z" fill="${T.fg1}"></path></svg></span>`;
const acts = (items) => `<div style="display: flex; gap: 3px; margin-top: 4px">${items.replace(/font-size: 9.5px/g, 'font-size: 8px').replace(/padding: 0 7px/g, 'padding: 0 4px')}</div>`;
const sec9 = section('产物检查器', `${prio('P3')}${builtTag}`,
  `现状：照 result_inspector_parts.dart 画，三处对齐见边界行`,
  [
    S('有图', insp(`${pv(`<img src="${IMG.mountain}" alt="" style="position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover">`)}${acts(`${mbtn('定位来源节点')}${mbtn('在序列中定位')}`)}`), '预览 16:9 + 参数组 + 动作行'),
    S('等待生成', insp(`${pv(`${spinIc(10)}等待生成`)}${acts(`${mbtn('定位来源节点')}${mbtn('在序列中定位', { dis: true })}`)}`), '还没出片：预览写「等待生成」'),
    S('文件缺失', insp(`${pv(`${ic('warning', 11)}图片文件缺失`)}${acts(`${mbtn('定位来源节点')}`)}`), '文件被挪走：预览写缺失，参数照列'),
    S('视频', insp(`${pv(`<img src="${IMG.wide}" alt="" style="position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover">${playDot}`)}${acts(`${mbtn('播放', { icon: 'run' })}${mbtn('定位来源节点')}`)}`, '镜头 02 · 视频'), '首帧 + 播放浮标；点预览 = 灯箱'),
  ],
  [
    F(1, `<div style="display: flex; gap: 6px; justify-content: center; padding-top: 10px">${nodeCard('镜头 01 · 配置', false)}${nodeCard('成片', true)}</div>`, '点画布上的产物卡'),
    F(2, insp(`${pv(`<img src="${IMG.mountain}" alt="" style="position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover">`)}${note('服务商 Gemini · 16:9 · 种子 4127', T.fg4)}`), '检查器切到产物：参数与画廊同口径'),
    F(3, insp(`${note('…参数组…', T.fg6)}${acts(`${mbtn('定位来源节点', { hot: true })}${mbtn('在序列中定位')}`)}`) + cursor(36, 62), '点「定位来源节点」'),
    F(4, `<div style="display: flex; gap: 6px; justify-content: center; padding-top: 10px">${nodeCard('镜头 01 · 配置', true)}${nodeCard('成片', false)}</div>`, '单选来源配置并居中（同画布内）'),
  ],
  [
    E('置灰不隐藏', insp(`${acts(`${mbtn('定位来源节点')}${mbtn('在序列中定位', { dis: true })}`)}${note('不在链上：50%，tooltip 写原因')}`), '不可用的动作 50%，不隐藏'),
    E('批量 slot', insp(`<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 3px">${[IMG.thumbMountain, IMG.thumbWide, IMG.thumbWide, ''].map((s, i) => `<div style="position: relative; height: 16px; border-radius: 2px; overflow: hidden; background: ${T.thumb}; ${i === 0 ? `outline: 1px solid ${T.accent};` : `outline: 1px solid ${T.outline};`}">${s ? `<img src="${s}" alt="" style="width: 100%; height: 100%; object-fit: cover; display: block">` : `<div style="display: flex; justify-content: center; padding-top: 3px">${spinIc(9)}</div>`}</div>`).join('')}</div>`), '有批量 slot：预览换 2×N 网格（现状）'),
    E('要对齐的三处', `<div style="font-size: 8.5px; color: ${T.fg3}; line-height: 13px">${num(1, T.danger, T.fg1)} ${code('image / result')} → 走 ARB<br>${num(2, T.danger, T.fg1)} 00:00:05 → 「5 秒」<br>${num(3, T.danger, T.fg1)} Material 图标 → 图标集 v1</div>`, 'result-inspector-align 一片做完'),
  ],
);

// =================== 10 铃铛 · 任务胶囊（已实现，作为反馈出口） ===================
const popRow = (name, meta, act, o = {}) => `<div style="height: 18px; display: flex; align-items: center; gap: 4px; font-size: 8.5px; ${o.hot ? `background: ${T.s5};` : ''} padding: 0 3px"><span style="flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis"><span style="color: ${T.fg2}">${name}</span> <span style="color: ${o.fail ? T.danger : T.fg5}">${meta}</span></span>${act ? `<span style="color: ${T.accent}">${act}</span>` : ''}</div>`;
const sec10 = section('铃铛 · 任务胶囊', `${prio('P3')}${builtTag}`,
  `现状：notification_bell.dart、shell_task_capsule.dart / shell_task_popover.dart；上面几节的反馈都落在这里`,
  [
    S('铃铛三态', `<div style="display: flex; gap: 14px; align-items: center; height: 30px; padding-left: 4px">${bellGlyph('')}${bellGlyph(T.accent)}${bellGlyph(T.danger)}</div>${note('无未读 · 未读 · 未读里有失败')}`, '点 accent，有失败换 danger；打开即全部已读'),
    S('历史空态', mmenu(`<div style="height: 14px; font-size: 9.5px; color: ${T.fg1}">通知</div><div style="padding: 10px 0; text-align: center; font-size: 9px; color: ${T.fg5}">还没有通知</div>`), '空时没有「清空」；有内容按本次会话新 → 旧'),
    S('胶囊 · 活动', `<div style="position: relative; height: 100%">${statusBar(`<span>12 节点 · 9 边</span><span style="flex: 1"></span>${capsule('生成中 2 · 排队 1')}`)}</div>`, 'wash 底 + 转圈；为 0 的那段省掉'),
    S('胶囊 · 终态', `<div style="position: relative; height: 100%">${statusBar(`<span style="flex: 1"></span><span style="display: inline-flex; align-items: center; height: 15px; padding: 0 6px; border-radius: 8px; border: 1px solid ${T.outline}; font-size: 8.5px; color: ${T.fg5}">任务 3 · <span style="color: ${T.danger}">&nbsp;失败 1</span></span>`)}${note('注册表空：整个不画')}</div>`, 'outline 边 fg5；失败段 danger'),
  ],
  [
    F(1, `<div style="position: relative; height: 100%">${statusBar(`<span style="flex: 1"></span>${capsule('生成中 1')}`)}${cursor(118, 64)}</div>`, '点胶囊'),
    F(2, mmenu(`<div style="height: 13px; display: flex; font-size: 9px; color: ${T.fg1}">任务<span style="flex: 1"></span><span style="color: ${T.fg5}">并发 2</span></div>${popRow('镜头 02 推近', '生成中', '取消')}${popRow('镜头 04', '失败', '定位', { fail: true })}<div style="font-size: 8.5px; color: ${T.fg4}; text-align: right">清除已完成</div>`), '活动在前、终态在后；失败行 tooltip 是原因'),
    F(3, mmenu(`${popRow('镜头 02 推近', '生成中', '取消')}${popRow('镜头 04', '失败 · 画布 2', '定位', { fail: true, hot: true })}`) + cursor(118, 26), '点失败行「定位」'),
    F(4, `${miniTabs('画布 2')}<div style="margin-top: 6px; display: flex; justify-content: center">${nodeCard('镜头 04', true)}</div>`, '别的画布先 openCanvas，再单选 + 居中'),
  ],
  [
    E('还有 N 条', `<div style="display: flex; flex-direction: column; align-items: flex-end; gap: 3px"><span style="height: 13px; padding: 0 6px; border-radius: 7px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; color: ${T.fg5}; font-size: 8.5px; display: inline-flex; align-items: center; opacity: 0.6">还有 2 条 · 查看全部</span>${mtoast({ k: 'success', title: '镜头 01 已生成', extra: 'width: 100%' })}</div>`, '上面压着对话框时不可点（historyHostReady）'),
    E('无项目上下文', mmenu(`${popRow('镜头 07', '完成 · 别的项目', '')}${note('拿不到 ProjectRef：不画「定位」', T.fg6)}`), '绝不挂一个点了没反应的按钮'),
    E('关弹层', `<div style="font-size: 9px; color: ${T.fg3}; line-height: 14px">再点胶囊<br>点外面（含铃铛）<br>${kbd('Esc', T.fg2)}（弹层开着时持焦）</div>`, '三种都关；铃铛与胶囊不会同时开'),
    E('并发上限', mmenu(`${popRow('镜头 01', '生成中', '取消')}${popRow('镜头 02', '生成中', '取消')}${popRow('镜头 03', '排队中', '取消')}`), '超过「并发 N」的排队；排队中也能取消'),
  ],
);

// =================== 排版 ===================
const cols = [[sec1, sec3, sec6, sec8, sec10], [sec2, sec4, sec5, sec7, sec9]];
if (capErrs.length) throw new Error('说明超过 3 行：\n' + capErrs.join('\n'));

const legend = (border, label) => `<span style="display: inline-flex; align-items: center; gap: 5px"><span style="width: 18px; height: 11px; box-sizing: border-box; border: ${border}; border-radius: 2px; background: ${T.s1}"></span>${label}</span>`;
const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="position: absolute; left: ${PAD}px; top: 18px; right: ${PAD}px">
    <div style="display: flex; align-items: baseline; gap: 14px">
      <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">面板与通知补漏 · 第二批 · 状态与流程</div>
      <div style="color: ${T.fg4}; font-size: 11.5px">GapsPanels 九项 + 作为反馈出口的铃铛与任务胶囊；每节三行：状态 / 流程 / 边界</div>
    </div>
    <div style="display: flex; align-items: center; gap: 16px; margin-top: 6px; font-size: 10.5px; color: ${T.fg5}">
      ${legend(FRAME_BORDER.st, '状态（实线）')}${legend(FRAME_BORDER.fl, '流程（数字徽标）')}${legend(FRAME_BORDER.ed, '边界（虚线）')}
      <span>无阻塞决定；「需要你定」N1–N3 / P1 / O1 / C1 / E1 一律按 b2 建议画 · 标「细化」的是本板补的规则</span>
    </div>
  </div>
  ${cols.map((c, i) => `<div style="position: absolute; left: ${PAD + i * (CW + CGAP)}px; top: ${TOP}px; width: ${CW}px; display: flex; flex-direction: column; gap: ${SGAP}px">${c.join('')}</div>`).join('')}
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

console.error(`W=${W} H=${H} CW=${CW} SEC_H=${SEC_H}`);
module.exports = { file: 'GapsPanelsDetail.dc.html', html: page('面板与通知补漏 · 第二批 · 状态与流程', W, H, body, logic) };
