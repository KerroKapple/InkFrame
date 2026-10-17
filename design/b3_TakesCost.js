// 第三批细化画板：版本固定与花费 · 状态与流程（1280×H，静态）
// 原画板：b2_takes.js（b2/project/TakesCost.dc.html）。逐功能画 状态条 / 主流程 / 边界帧。
//
// 决定：TC-Q1 → A（改写边）：设为当前、或没固定时出了新 take，接在旧当前上的 data 边挪到新当前；线永远画在当前 take 上
// 决定：TC-Q2 → A（没固定时新 take 自动成为当前）
// 决定：TC-Q3 → C（只标输入真变了的那张 + 原因卡提一句上游）
// 决定：TC-Q4 → A（批量运行默认跳过已固定的，可勾回）
// 决定：TC-Q5 → C（对话框里切，记住上次；首次默认「只跑过期和没生成的」）
// 决定：TC-Q6 → 币种只用 USD（formatCostUsd）
// 决定：TC-Q7 → A（下一镜是图像配置时置灰说明）
// 决定：TC-Q8 → A（超过 50 个按顺序跑前 50 个，其余写「另 N 个不在本次」）
// 本板补定（无编号，按 node-cost / 现有代码口径）：价格未知写「—」不写 $0.00；并发时「谁是最新」按 result 节点建出来的时刻（= 提交时刻），不按完成时刻
const { T, IMG, SANS, MONO, page, ic } = require('./common.js');

const W = 1280, H = 2400;

// ---- 小件（照 b2 本地拷贝）----
const h3 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 8px; margin-bottom: 4px"><div style="font-weight: 500; color: ${T.fg1}">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const kbd = (k, c = T.fg5) => `<span style="font-family: ${MONO}; font-size: 9px; color: ${c}; white-space: nowrap">${k}</span>`;
const mono = (t) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${t}</span>`;
const em = (t) => `<span style="color: ${T.fg2}">${t}</span>`;
const tag = (t, c = T.fg4, b = T.outline) => `<span style="height: 14px; padding: 0 4px; border-radius: 3px; border: 1px solid ${b}; color: ${c}; font-size: 9px; display: inline-flex; align-items: center; white-space: nowrap; box-sizing: border-box">${t}</span>`;
const tagNew = `<span style="height: 14px; padding: 0 4px; border-radius: 3px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 9px; display: inline-flex; align-items: center; margin-left: 4px; box-sizing: border-box">新</span>`;

// 现状行：以「需：」开头的段落用琥珀「需」
const status = (has, need) => `<div style="font-size: 10.5px; color: ${T.fg4}; line-height: 1.5; margin-bottom: 0">
  <div><span style="color: ${T.fg5}">现状</span>　${has}</div>
  ${need ? `<div><span style="color: ${T.accent}">需</span>　${need}</div>` : ''}
</div>`;

// 帧：样稿 76 高 + 说明（最多 3 行）。label = 状态名（粗）或流程编号
const MOCK_H = 66;
const num = (n) => `<div style="position: absolute; left: 4px; top: 4px; width: 16px; height: 16px; border-radius: 8px; background: ${T.accent}; color: ${T.onAccent}; font-family: ${MONO}; font-size: 10px; font-weight: 500; display: flex; align-items: center; justify-content: center; z-index: 2">${n}</div>`;
const cap = (label, text) => {
  const need = text.startsWith('需：');
  const body = need ? `<span style="color: ${T.accent}">需：</span>${text.slice(2)}` : text;
  return `<div style="font-size: 10px; line-height: 1.45; color: ${T.fg4}; margin-top: 5px; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden"><span style="color: ${T.fg1}; font-weight: 500">${label}</span>${label ? '　' : ''}${body}</div>`;
};
const frame = (label, mock, text, opts = {}) => `
  <div style="min-width: 0">
    <div style="position: relative; height: ${MOCK_H}px; box-sizing: border-box; background: ${T.s1}; border: 1px solid ${opts.hot ? T.washBorder : T.bStrong}; border-radius: 4px; overflow: hidden; display: flex; align-items: center; justify-content: center; padding: 4px">
      ${opts.n ? num(opts.n) : ''}${mock}
    </div>
    ${cap(label, text)}
  </div>`;
const rowLabel = (t) => `<div style="font-size: 10px; color: ${T.fg5}; padding-top: 4px; letter-spacing: 1px">${t}</div>`;
const row = (label, frames) => `
  <div style="display: grid; grid-template-columns: 44px minmax(0, 1fr); gap: 12px">
    ${rowLabel(label)}
    <div style="display: grid; grid-template-columns: repeat(${frames.length}, minmax(0, 1fr)); gap: 10px">${frames.join('')}</div>
  </div>`;
const section = (head, stat, rows) => `
  <div style="display: flex; flex-direction: column; gap: 8px">
    <div>${head}${stat}</div>
    ${rows.join('')}
  </div>`;
const divider = `<div style="height: 1px; background: ${T.control}"></div>`;

// ---- 迷你件 ----
const pinOn = (s = 16) => `<div style="width: ${s}px; height: ${s}px; flex: none; border-radius: 3px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; display: flex; align-items: center; justify-content: center; box-sizing: border-box">${ic('pin', s - 6)}</div>`;
const pinOff = (s = 16, c = T.fg6) => `<div style="width: ${s}px; height: ${s}px; flex: none; border-radius: 3px; color: ${c}; display: flex; align-items: center; justify-content: center">${ic('pin', s - 6)}</div>`;
const spin = (s = 10, c = T.accent) => `<div class="spin" style="display: flex; color: ${c}">${ic('progress', s)}</div>`;

// 迷你节点卡：标题行 12 / 图区 40 / 状态行 12
const mini = ({ title = '成片', type = '图像', img = IMG.mountain, box = '', st = '', outline = T.outline, dim = false, w = 92, corner = '' }) => `
  <div style="width: ${w}px; flex: none; ${dim ? 'opacity: .55' : ''}">
    <div style="height: 12px; display: flex; align-items: center; gap: 3px; font-size: 9px"><div style="font-weight: 500; color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</div><div style="flex: 1"></div><div style="color: ${T.fg5}">${type}</div></div>
    <div style="position: relative; height: 32px; border-radius: 3px; background: ${T.thumb}; outline: 1px solid ${outline}; overflow: hidden">${box || (img ? `<img src="${img}" alt="" style="width: 100%; height: 100%; object-fit: cover">` : '')}${corner ? `<div style="position: absolute; right: 2px; top: 2px">${corner}</div>` : ''}</div>
    <div style="height: 13px; display: flex; align-items: center; gap: 3px; font-size: 9px; color: ${T.fg5}; white-space: nowrap; overflow: hidden">${st}</div>
  </div>`;
const promptBox = (t) => `<div style="padding: 3px 4px; font-size: 8px; line-height: 1.45; color: ${T.fg2}; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden">${t}</div>`;

// 历史页迷你行
const hRow = (img, label, meta, right, { current = false, hover = false, inUse = false } = {}) => `
  <div style="display: flex; align-items: center; gap: 5px; padding: 3px 5px; ${current || hover ? `background: ${T.s5}` : ''}; border-radius: 2px">
    <img src="${img}" alt="" style="width: 32px; height: 18px; flex: none; object-fit: cover; border-radius: 2px; outline: 1px solid ${inUse ? T.accent : T.outline}">
    <div style="flex: 1; min-width: 0"><div style="font-size: 9px; color: ${T.fg2}; display: flex; align-items: center; gap: 3px; white-space: nowrap">${label}</div><div style="font-size: 8px; color: ${T.fg5}; white-space: nowrap; overflow: hidden">${meta}</div></div>
    ${right}
  </div>`;
const hPanel = (inner, w = 124) => `<div style="width: ${w}px; box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.bStrong}; border-radius: 3px; padding: 2px">${inner}</div>`;

// 迷你菜单
const mItem = (icon, label, right = '', extra = '') => `<div style="height: 15px; display: flex; align-items: center; gap: 5px; padding: 0 5px; border-radius: 2px; font-size: 9px; color: ${T.fg2}; white-space: nowrap; ${extra}">${icon ? `<div style="color: ${T.fg4}; display: flex">${ic(icon, 11)}</div>` : '<div style="width: 11px"></div>'}<div style="flex: 1">${label}</div>${right}</div>`;
const mSep = `<div style="height: 1px; background: ${T.bStrong}; margin: 2px 0"></div>`;
const mMenu = (inner, w = 116) => `<div style="width: ${w}px; box-sizing: border-box; padding: 2px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 24px 64px rgba(0,0,0,0.6)">${inner}</div>`;

// 迷你通知卡
const mToast = (icon, color, title, body = '', a1 = '', a2 = '', w = 150) => `
  <div style="width: ${w}px; box-sizing: border-box; display: flex; gap: 5px; padding: 5px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 24px 64px rgba(0,0,0,0.45)">
    <div style="width: 18px; height: 18px; flex: none; border-radius: 3px; background: ${T.s5}; color: ${color}; display: flex; align-items: center; justify-content: center">${ic(icon, 11)}</div>
    <div style="flex: 1; min-width: 0">
      <div style="font-size: 9px; font-weight: 500; color: ${T.fg1}; line-height: 1.35">${title}</div>
      ${body ? `<div style="font-size: 8px; color: ${T.fg4}; line-height: 1.35">${body}</div>` : ''}
      ${a1 ? `<div style="display: flex; justify-content: flex-end; gap: 3px; margin-top: 3px">${a2 ? `<div style="height: 14px; padding: 0 5px; border-radius: 2px; border: 1px solid ${T.controlStrong}; color: ${T.fg2}; font-size: 8px; display: flex; align-items: center">${a2}</div>` : ''}<div style="height: 14px; padding: 0 5px; border-radius: 2px; background: ${T.accent}; color: ${T.onAccent}; font-size: 8px; font-weight: 500; display: flex; align-items: center">${a1}</div></div>` : ''}
    </div>
  </div>`;

// 迷你按钮
const mBtn = (label, kind = 'amber', extra = '') => {
  const st = {
    amber: `background: ${T.accent}; color: ${T.onAccent}`,
    hover: `background: ${T.accentHover}; color: ${T.onAccent}`,
    ghost: `border: 1px solid ${T.controlStrong}; color: ${T.fg2}`,
    off: `background: ${T.s5}; color: ${T.fg6}`,
  }[kind];
  return `<div style="height: 18px; padding: 0 7px; border-radius: 3px; box-sizing: border-box; ${st}; font-size: 9px; font-weight: 500; display: inline-flex; align-items: center; gap: 4px; white-space: nowrap; ${extra}">${label}</div>`;
};
const genBtn = (kind = 'amber', lead = ic('run', 10)) => mBtn(`${lead}生成 ${kbd('Ctrl ↵', kind === 'off' ? T.fg6 : T.onAccent)}`, kind);

// 迷你检查器行
const iRow = (k, v) => `<div style="display: flex; align-items: center; gap: 6px; height: 16px; font-size: 9px"><div style="width: 44px; color: ${T.fg5}">${k}</div><div style="flex: 1; min-width: 0; white-space: nowrap; overflow: hidden">${v}</div></div>`;
const iBox = (inner, w = 130) => `<div style="width: ${w}px; box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.bStrong}; border-radius: 3px; padding: 3px 6px">${inner}</div>`;
const money = (t, c = T.accent) => `<span style="font-family: ${MONO}; font-size: 9px; color: ${c}">${t}</span>`;

// 迷你提示框
const mTip = (inner, w = 130) => `<div style="width: ${w}px; box-sizing: border-box; padding: 4px 6px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); font-size: 9px; line-height: 1.45">${inner}</div>`;

// 状态胶囊（照 shell_task_capsule.dart 的三态）
const capsule = (kind, text) => {
  const st = kind === 'active'
    ? `background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}`
    : `border: 1px solid ${T.outline}; color: ${T.fg5}`;
  return `<div style="height: 16px; padding: 0 6px; border-radius: 999px; box-sizing: border-box; ${st}; font-size: 9px; display: inline-flex; align-items: center; gap: 4px; white-space: nowrap">${kind === 'active' ? spin(9) : ''}${text}</div>`;
};
const statusBar = (inner, w = 140) => `<div style="width: ${w}px; height: 22px; box-sizing: border-box; background: ${T.s3}; border-top: 1px solid ${T.bStrong}; display: flex; align-items: center; padding: 0 6px; gap: 6px; font-size: 9px; color: ${T.fg5}">${inner}</div>`;

// 迷你运行对话框
const dRow = (n, name, cost, state, c = T.fg4, dim = false) => `
  <div style="display: grid; grid-template-columns: 12px minmax(0, 1fr) 30px 48px; gap: 4px; align-items: center; height: 11px; padding: 0 5px; font-size: 8px; border-bottom: 1px solid ${T.bSubtle}; ${dim ? 'opacity: .5' : ''}">
    <div style="font-family: ${MONO}; color: ${T.fg5}">${n}</div><div style="color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${name}</div>
    <div style="font-family: ${MONO}; color: ${T.fg3}; text-align: right">${cost}</div><div style="color: ${c}; white-space: nowrap; overflow: hidden">${state}</div>
  </div>`;
const dlg = (rows, foot, btn, w = 150) => `
  <div style="width: ${w}px; box-sizing: border-box; background: ${T.s3}; border: 1px solid ${T.overlayBorder}; border-radius: 4px; box-shadow: 0 24px 64px rgba(0,0,0,0.6); overflow: hidden">
    <div style="height: 12px; display: flex; align-items: center; gap: 4px; padding: 0 5px; background: ${T.s4}; border-bottom: 1px solid ${T.bStrong}; font-size: 8px; color: ${T.fg1}; font-weight: 500">${ic('sequence', 9)}运行叙事链</div>
    ${rows}
    <div style="display: flex; align-items: center; gap: 4px; padding: 2px 5px">
      <div style="flex: 1; min-width: 0; font-size: 8px; color: ${T.fg3}; white-space: nowrap; overflow: hidden">${foot}</div>${btn}
    </div>
  </div>`;
const dBtn = (t, off = false) => `<div style="height: 13px; padding: 0 5px; border-radius: 2px; font-size: 8px; font-weight: 500; display: flex; align-items: center; white-space: nowrap; ${off ? `background: ${T.s5}; color: ${T.fg6}` : `background: ${T.accent}; color: ${T.onAccent}`}">${t}</div>`;

// 连线小图：左卡 → 右卡（data 首帧线 teal，与 edge_style 首帧色一致）
const wire = (w = 18, c = T.teal, dashed = false) => `<svg width="${w}" height="10" viewBox="0 0 ${w} 10" aria-hidden="true" style="flex: none"><path d="M0 5H${w}" fill="none" stroke="${c}" stroke-width="1.5" ${dashed ? 'stroke-dasharray="2 3"' : ''}></path></svg>`;

const slotCell = (kind) => {
  const map = {
    promoted: `<div style="position: relative; width: 24px; height: 14px; border-radius: 2px; overflow: hidden; outline: 1px solid ${T.accent}"><img src="${IMG.mountain}" alt="" style="width: 100%; height: 100%; object-fit: cover"></div>`,
    success: `<div style="width: 24px; height: 14px; border-radius: 2px; overflow: hidden; outline: 1px solid ${T.outline}"><img src="${IMG.wide}" alt="" style="width: 100%; height: 100%; object-fit: cover; opacity: .7"></div>`,
    error: `<div style="width: 24px; height: 14px; border-radius: 2px; outline: 1px solid ${T.danger}; background: ${T.thumb}; color: ${T.danger}; display: flex; align-items: center; justify-content: center">${ic('error', 9)}</div>`,
    generating: `<div style="width: 24px; height: 14px; border-radius: 2px; outline: 1px solid ${T.outline}; background: ${T.thumb}; display: flex; align-items: center; justify-content: center">${spin(9)}</div>`,
  };
  return map[kind];
};

// ================= A · 当前 take · 固定 =================
const pinRight = `<div style="display: flex; align-items: center; gap: 2px; font-size: 8px; color: ${T.fg3}">设为当前${pinOff(14, T.fg3)}</div>`;
const secTake = section(
  h3('当前 take · 固定', '一镜只有一个「当前」；固定 = 新 take 不顶替它。「转正」并进来'),
  status(
    `${mono('take_numbers.dart')} 已有 take 号；${mono('node_artifacts.dart')} 的 ${mono('latestResultFor')} 就是「当前 = 最新」，按 result 节点 created_at 比；${mono('inspector_history_panel.dart')} 已有 take 列表 +「在用」（有 data 出边），头注释写「图钉固定没有数据模型，不画」；${mono('batch_results_controller.dart')} 已有 转正 / 重跑 / 取消整批；${mono('batch_slot_view.dart')} 四态 promoted / success / error / generating（cancelled 与空 url 并入 error）`,
    `${mono('currentResultFor')}（固定的 ?? 最新的）+ type_config.${mono('pinned_result_id')}（patchTypeConfig，不迁移）；图钉、「设为当前」、边改写都是新的`,
  ),
  [
    row('状态', [
      frame('默认', hPanel(hRow(IMG.wide, 'take 3', '2 分钟前', '', { current: true }) + hRow(IMG.mountain, 'take 2', '18 分钟前', '')), '没固定：最新的就是当前（现有「取最新」），行不带图钉'),
      frame('悬停', hPanel(hRow(IMG.wide, 'take 3', '2 分钟前', '') + hRow(IMG.mountain, 'take 2', '18 分钟前', pinRight, { hover: true })), '需：悬停行右侧出灰图钉「设为当前」；键盘聚焦同样出'),
      frame('已固定', hPanel(hRow(IMG.wide, 'take 3', '2 分钟前', pinOff(14)) + hRow(IMG.mountain, `take 2 ${tag('在用', T.teal, T.teal)}`, '种子 4127', pinOn(14), { current: true, inUse: true })), '琥珀图钉 + s5 底；比它新的 take 写「未采用」'),
      frame('进行中', hPanel(hRow(IMG.wide, `take 4 ${spin(9)}`, '生成中 42%', '') + hRow(IMG.mountain, 'take 2', '当前 · 已固定', pinOn(14), { current: true })), '新 take 在途；当前仍是固定那张，下游线不动'),
      frame('出错', mToast('error', T.danger, '没能设为当前', '写入失败，图钉已复原', '重试'), '需：写库失败 → 图钉回到原处 + 错误卡；边不改写（同事务）'),
      frame('禁用', `<div style="display: flex; flex-direction: column; gap: 4px; align-items: flex-start">${mBtn(`${ic('success', 10)}已是当前`, 'off')}${mBtn(`${ic('pin', 10)}设为当前`, 'ghost')}</div>`, '成片检查器动作行：是当前 → 打勾置灰；否则可点'),
      frame('空态', hPanel(`<div style="padding: 10px 6px; font-size: 9px; color: ${T.fg5}">还没有生成过</div>`), '名下没有产物：现有 inspectorHistoryEmpty 一行 fg5'),
      frame('批量 slot', `<div style="display: flex; flex-direction: column; gap: 4px; align-items: center"><div style="display: flex; gap: 4px">${slotCell('promoted')}${slotCell('success')}${slotCell('error')}${slotCell('generating')}</div><div style="font-size: 8px; color: ${T.fg5}">当前 · 成功 · 失败 · 生成中</div></div>`, '照 batch_slot_view 四态；「当前」沿用 batchActionCurrent'),
    ]),
    row('流程', [
      frame('', hPanel(hRow(IMG.wide, 'take 3', '最新', '') + hRow(IMG.mountain, 'take 2', '18 分钟前', pinRight, { hover: true })), '历史页悬停 take 2 → 出「设为当前」', { n: 1 }),
      frame('', hPanel(hRow(IMG.mountain, 'take 2', '写入中…', `<div style="display: flex">${spin(11)}</div>`, { hover: true })), '点下：一个事务写 pinned_result_id + 把旧当前（take 3）的 data 边挪到 take 2', { n: 2 }),
      frame('', `<div style="display: flex; align-items: center">${mini({ title: 'take 2', img: IMG.mountain, outline: T.accent, corner: pinOn(14), st: `<span style="color: ${T.accent}">当前 · 已固定</span>`, w: 74 })}${wire(16)}${mini({ title: '镜头 02', type: '视频配置', img: '', box: promptBox('江上孤舟，镜头慢推'), st: '首帧 ← take 2', w: 66 })}</div>`, '画布：首帧线从 take 2 出，take 3 图区半透明、写「未采用」', { n: 3 }),
      frame('', mToast('pin', T.accent, '已设为当前 · take 2', '改了 1 条连线', '撤销'), '反馈卡带「撤销」：固定 + 改写的边算一步', { n: 4 }),
      frame('', `<div style="display: flex; flex-direction: column; gap: 4px; align-items: center"><div style="display: flex; gap: 4px">${slotCell('success')}${slotCell('promoted')}${slotCell('success')}${slotCell('success')}</div>${mBtn(`${ic('pin', 10)}设为当前`, 'amber')}</div>`, '批量：点 slot = promote + 设为当前同一事务；「转正」「设为产物」退场', { n: 5 }),
    ]),
    row('边界', [
      frame('并发', `<div style="display: flex; flex-direction: column; gap: 3px; font-size: 8px; color: ${T.fg4}; width: 160px"><div>${mono('A')} 17:01 提交 · 17:06 完成</div><div>${mono('B')} 17:02 提交 · 17:04 完成</div><div style="color: ${T.accent}">当前 = B（提交晚）</div></div>`, 'result 节点在提交时预建，最新按它的 created_at：后提交的赢，与谁先完成无关；边各改写一次、串行', { hot: true }),
      frame('取消', `<div style="display: flex; flex-direction: column; gap: 4px; align-items: center">${capsule('idle', '任务 1')}<div style="font-size: 8px; color: ${T.fg4}">take 4 已取消 · 当前仍 take 3</div></div>`, '取消 → result 节点软删（批量已有成功 slot 则保留，可设为当前）；当前与边不动'),
      frame('失败', mToast('error', T.danger, '镜头 01 生成失败', '当前仍是 take 3', '查看'), 'result 节点软删；当前不变、下游线不动；现有 jobNotifyFailed 卡'),
      frame('固定后来新 take', mToast('success', T.success, '镜头 01 已生成 take 4', '当前仍是 take 2', '设为当前'), '固定的不被顶替；卡上可直接改设'),
      frame('删掉固定的', hPanel(hRow(IMG.wide, 'take 3', '回落为当前', '', { current: true }) + `<div style="padding: 2px 5px; font-size: 8px; color: ${T.fg6}">take 2 已删除 · 撤销可回</div>`), '回落最新、边改写到它；撤销删除时固定和边一起回来'),
      frame('撤销', `<div style="display: flex; flex-direction: column; gap: 4px; align-items: center"><div style="display: flex; gap: 6px">${tag('Ctrl Z', T.fg3)}${tag('⌘Z', T.fg3)}</div><div style="font-size: 8px; color: ${T.fg4}">Windows · macOS</div></div>`, '一步撤掉固定 + 边改写；反向按边两端的节点找边，不按边 id'),
    ]),
  ],
);

// ================= B · 过期标记 =================
const dirtySt = `<span style="color: ${T.accent}; display: flex; align-items: center; gap: 2px">${ic('dirty', 9)}已过期</span>`;
const reasonTip = mTip(`<div style="color: ${T.fg1}; font-weight: 500; display: flex; align-items: center; gap: 3px"><span style="color: ${T.accent}; display: flex">${ic('dirty', 10)}</span>生成之后，输入变了</div><div style="color: ${T.fg4}">提示词 · 种子 · 首帧</div><div style="color: ${T.fg6}">上游 镜头 01 也已过期</div>`, 136);
const secDirty = section(
  h3('过期标记', '比对快照得出；改回原值，标记自己消失'),
  status(
    `尚无：result 节点不存生成时的输入；jobs 行会被清，不能当快照。${mono('dirty')} 图标只在设计稿图标集里`,
    `建 job 的同一事务写 result 的 type_config.${mono('gen_inputs')}（gen-inputs-snapshot）；比对纯函数；import_remapper 改写 / 剥除`,
  ),
  [
    row('状态', [
      frame('默认', mini({ st: `<span style="color: ${T.success}">完成</span><span>· take 2</span>` }), '输入没变：现有「完成」状态行'),
      frame('已过期', mini({ outline: T.washBorder, st: `${dirtySt}<span>· take 2</span>` }), '需：琥珀图标 + washBorder 描边；大纲行尾同标'),
      frame('悬停', reasonTip, '需：悬停 / 聚焦标记出原因卡：逐项 旧 → 新'),
      frame('重新生成中', mini({ outline: T.washBorder, st: `${spin(9)}<span>生成中</span><span style="color: ${T.fg6}">· 仍过期</span>` }), '新 take 成功并成为当前前，标记不摘'),
      frame('重生成失败', mToast('error', T.danger, '镜头 02 生成失败', '仍是过期的 take 2', '查看'), '失败卡照旧；标记留着'),
      frame('没快照', mini({ img: IMG.wide, st: '<span>完成 · 老产物</span>' }), '没有 gen_inputs 的老产物不标，也不出原因卡'),
    ]),
    row('流程', [
      frame('', iBox(iRow('提示词', `<span style="color: ${T.fg2}">…晨光破雾</span>`) + iRow('种子', mono('88')) + iRow('保存', `<span style="color: ${T.fg5}">已保存</span>`)), '在上游配置节点改提示词 / 种子；防抖落库', { n: 1 }),
      frame('', `<div style="display: flex; align-items: center">${mini({ title: '镜头 01', type: '图像配置', img: '', box: promptBox('拂晓，晨光破雾'), st: `<span style="color: ${T.accent}">当前 take 已过期</span>`, w: 76 })}${wire(10, T.fg6, true)}${mini({ outline: T.washBorder, st: dirtySt, w: 58 })}</div>`, '落库后比对：当前 take 出标记，配置卡状态行同步', { n: 2 }),
      frame('', reasonTip, '悬停标记 → 原因卡；底部「重新生成 约 $0.03」', { n: 3 }),
      frame('', mini({ st: `<span style="color: ${T.success}">完成</span><span>· take 3</span>` }), '新 take 成功、成为当前 → 标记消失', { n: 4 }),
      frame('', iBox(iRow('提示词', `<span style="color: ${T.fg2}">…雾气渐散</span>`) + iRow('标记', `<span style="color: ${T.fg5}">已消失</span>`)), '或者：改回原值 → 比对相等，标记自己消失', { n: 5 }),
    ]),
    row('边界', [
      frame('上游传递', `<div style="display: flex; align-items: center">${mini({ title: '01', outline: T.washBorder, st: dirtySt, w: 60 })}${wire(10)}${mini({ title: '02', type: '视频', img: IMG.wide, st: '完成', w: 60 })}</div>`, 'Q3=C：只标真变了的那张；下游的原因卡写「上游也已过期」'),
      frame('首帧换了', `<div style="display: flex; align-items: center">${mini({ title: 'take 3', corner: pinOn(14), outline: T.accent, w: 60 })}${wire(10)}${mini({ title: '02', type: '视频', img: IMG.wide, outline: T.washBorder, st: dirtySt, w: 60 })}</div>`, 'Q1=A：上游换当前、边被改写 → 下游首帧源变了，下游当前 take 过期'),
      frame('固定的也会过期', mini({ outline: T.washBorder, corner: pinOn(14), st: `${dirtySt}<span>· 已固定</span>` }), '固定不压标记；运行叙事链默认仍跳过它（Q4）'),
      frame('导入 / 粘贴', `<div style="display: flex; flex-direction: column; gap: 3px; font-size: 8px; color: ${T.fg4}"><div>${mono('gen_inputs')} 源 id → 映射改写</div><div>映射不到 → 剥掉 = 没快照</div><div style="color: ${T.fg6}">不标过期</div></div>`, '导入项目包、跨项目粘贴同一规则；模板不带产物，出现就剥'),
      frame('不算变化', `<div style="display: flex; flex-wrap: wrap; gap: 3px; width: 150px">${tag('改名')}${tag('挪位置')}${tag('层级')}${tag('批量张数')}${tag('随机种子')}</div>`, '这些改动不出标记'),
    ]),
  ],
);

// ================= C · 花费预告 · 批量运行确认 =================
const costTipMock = mTip(`<div><span style="color: ${T.fg5}">预计</span> <span style="color: ${T.fg1}; font-weight: 500">约 $0.75</span></div><div style="color: ${T.fg4}">万相 图生视频 · 5 秒 · 720p</div><div style="color: ${T.fg6}">以服务商账单为准</div>`, 140);
const runRowsA = dRow('01', '第一个镜头', '$0.13', '没生成过') + dRow('02', '江上孤舟', '$0.75', '等 01', T.sky) + dRow('03', '远山隐没', '$1.75', '已过期', T.accent);
const secRun = section(
  h3('花费预告 · 批量运行确认', '运行前就知道要花多少；一次跑 ≥ 2 个先确认（含「运行叙事链」）'),
  status(
    `${mono('cost_estimator.dart')} 已有 ${mono('estimateCostUsd')} + ${mono('formatCostUsd')}（≤ 0 写 $0.00、不到 1 分写 &lt;$0.01）；图像 / 视频检查器「预估费用」行已有；自定义接口模板是 perCall 0 → 现在显示 $0.00；${mono('canvas_prompt_bar.dart')} 注释写预估费用先不画；${mono('generate_gate.dart')} 已有「先提示词再 Key」；${mono('inspector_submit_controller.dart')} 四态 idle / submitting / running / failure；${mono('shell_task_capsule.dart')} 已有「生成中 N · 排队 M」/「任务 N · 失败 K」`,
    `${mono('estimateNodeCost')} 算不出返回空 → 写「—」（node-cost）；提示词条常驻金额；批量运行 planner / executor / 对话框，${mono('run_group')} 写进 parameters`,
  ),
  [
    row('花费', [
      frame('默认', iBox(iRow('批量', mono('4 张')) + iRow('预估费用', money('$0.13'))), '检查器现有行：mono + accent'),
      frame('悬停「生成」', costTipMock, '需：悬停任何「生成」出明细卡'),
      frame('价格未知', iBox(iRow('供应商', '自定义接口') + iRow('预估费用', money('—', T.fg4))), '需：costModel 为 perCall 0 → 写「—」，不再是 $0.00'),
      frame('不到一分', iBox(iRow('预估费用', money('&lt;$0.01'))), 'formatCostUsd 现有写法'),
      frame('禁用', `<div style="display: flex; flex-direction: column; gap: 3px; align-items: flex-start">${genBtn('off')}<div style="font-size: 8px; color: ${T.fg5}">先填提示词 / 先配 Key</div></div>`, 'generate_gate：金额照算，按钮灰'),
      frame('提交中', `<div style="display: flex; align-items: center; gap: 6px"><span style="font-size: 9px; color: ${T.fg5}">约 $0.75</span>${mBtn(`${spin(10, T.onAccent)}生成`, 'amber', 'opacity: .7')}</div>`, 'submitting / running：按钮转圈不可再点'),
      frame('提交失败', `<div style="display: flex; flex-direction: column; gap: 3px; align-items: flex-start">${genBtn()}<div style="font-size: 8px; color: ${T.danger}">缺少 API Key</div></div>`, 'InspectorSubmitFailure 现有文案；金额不变'),
    ]),
    row('对话框', [
      frame('默认', dlg(runRowsA, '3 个 · 约 $2.63', dBtn('运行 3 个')), '逐行节点 + 价 + 状态；合计在底'),
      frame('有价格未知', dlg(dRow('03', '远山隐没', '$1.75', '已过期', T.accent) + dRow('04', '收网', '—', '价格未知'), '约 $1.75 · 另 1 个价格未知', dBtn('运行 2 个')), '「—」不进合计；统一写「另 N 个价格未知」'),
      frame('有跳过', dlg(dRow('05', '回望', '', '跳过 · 已固定', T.fg5, true) + dRow('06', '旧版开场', '', '跳过 · 已停用', T.fg5, true) + dRow('03', '远山隐没', '$1.75', '已过期', T.accent), '1 个 · 约 $1.75', dBtn('运行 1 个')), '已固定可用「包括已固定的」勾回；已停用不能勾回'),
      frame('超过 50', dlg(dRow('50', '第 50 镜', '$0.03', '没生成过'), '另 12 个不在本次', dBtn('运行 50 个')), 'Q8=A：按依赖顺序取前 50'),
      frame('空态', dlg(`<div style="padding: 6px 5px; font-size: 8px; color: ${T.fg5}">没有要跑的镜头</div>`, '全部已固定或已停用', dBtn('运行', true)), '按钮置灰；提示切「全部」或勾「包括已固定的」'),
      frame('运行中', statusBar(`<span>画布 1</span><div style="flex: 1"></div>${capsule('active', '生成中 2 · 排队 2')}`, 150), '对话框关闭，进度看现有任务胶囊'),
    ]),
    row('流程', [
      frame('', mMenu(mItem('sequence', '运行叙事链', '', `background: ${T.s5}`) + mItem('run', '生成 3 个', kbd('Ctrl ↵')) + mSep + mItem('script', '导入剧本…')), '更多 ›「运行叙事链」；多选 Ctrl ↵、右键、大纲组头、⌘K 同一个对话框', { n: 1 }),
      frame('', dlg(runRowsA, '3 个 · 约 $2.63', dBtn('运行 3 个')), '切「只跑过期和没生成的 / 全部」（记住上次）；看逐行价', { n: 2 }),
      frame('', statusBar(`<div style="flex: 1"></div>${capsule('active', '生成中 2 · 排队 1')}`, 140), '点「运行 3 个」→ 按 data 依赖排队；没依赖的按叙事链序', { n: 3 }),
      frame('', `<div style="display: flex; align-items: center">${mini({ title: '01 · take 1', corner: pinOff(14, T.fg3), outline: T.accent, st: `<span style="color: ${T.success}">完成 · 当前</span>`, w: 70 })}${wire(12)}${mini({ title: '02', type: '视频', img: '', box: `<div style="height: 100%; display: flex; align-items: center; justify-content: center">${spin(12)}</div>`, st: '用新首帧提交', w: 62 })}</div>`, '01 成功 → 成为当前、边改写（Q1=A）→ 02 才拿它当首帧提交', { n: 4 }),
      frame('', mToast('success', T.success, '运行叙事链 · 3 个已生成', '预计花费约 $2.63', '查看'), '一张汇总卡，不逐个弹；金额写「预计」不读账单', { n: 5 }),
    ]),
    row('边界', [
      frame('只选 1 个', `<div style="display: flex; align-items: center; gap: 6px"><span style="font-size: 9px; color: ${T.fg5}">约 $0.13</span>${genBtn('hover')}</div>`, '要跑的 < 2 个不弹，直接提交（现有 submitWithPending）'),
      frame('上游失败', dlg(dRow('01', '第一个镜头', '$0.13', '失败', T.danger) + dRow('02', '江上孤舟', '$0.75', '未提交 · 上游失败', T.fg5), '1 失败 · 1 未提交', dBtn('重跑失败的')), '下游不提交、不花钱；汇总卡写「3 个已生成 · 1 个失败 · 1 个未提交」'),
      frame('取消这一批', mMenu(mItem('queue', '运行叙事链 · 3 个') + mItem('close', '取消这一批', '', `background: ${T.s5}; color: ${T.danger}`)), '任务弹层按 run_group 整批取消：已完成的留下，在途的发 cancel，排队的撤掉'),
      frame('并发上限', statusBar(`<div style="flex: 1"></div>${capsule('active', '生成中 2 · 排队 5')}`, 140), '受全局并发与 provider 上限；同一配置节点一批只跑一次'),
      frame('跑的途中改了配置', iBox(iRow('提示词', `<span style="color: ${T.fg2}">已改</span>`) + iRow('03', `<span style="color: ${T.fg5}">排队中 · 提交时读新值</span>`)), '已提交的不受影响；还在排队的提交那一刻读终稿'),
      frame('macOS / Windows', `<div style="display: flex; flex-direction: column; gap: 4px; align-items: center"><div style="display: flex; gap: 6px">${tag('Ctrl ↵', T.fg3)}${tag('⌘↵', T.fg3)}</div><div style="font-size: 8px; color: ${T.fg4}">对话框里 ↵ 运行 · Esc 取消</div></div>`, '多选生成键位随平台；对话框持焦，↵ / Esc 两边一致'),
    ]),
  ],
);

// ================= D · 当下一镜的首帧 =================
const nodeMenuBase = (hl, extra = '') => mMenu(
  mItem('run', '生成') +
  mItem('videoConfig', `当下一镜的首帧${tagNew}`, '›', hl) + extra +
  mSep + mItem('characters', '存为角色'), 128);
const secNext = section(
  h3('当下一镜的首帧', '节点右键：把这张图接到叙事链下一镜的首帧'),
  status(
    `尚无：节点右键菜单（${mono('node_menu_model.dart')}）现有 生成 · 复制一份 | 存为角色 · 加入泳道 › · 在序列中定位 | 删除；新建菜单「下一镜」与 ${mono('nextNarrativeSortOrder')} 已有；建节点 + 连线失败回滚的口径在 ${mono('canvas_tool_actions.dart')}`,
    `菜单项 + 子菜单（menu-split 之后）；动作进 ${mono('util/canvas_next_shot_actions.dart')}，节点 + 边一步撤销`,
  ),
  [
    row('状态', [
      frame('默认', nodeMenuBase(''), '需：take 卡 / 图像配置卡右键出这项'),
      frame('悬停', `<div style="display: flex; gap: 2px; align-items: flex-start">${mMenu(mItem('videoConfig', '当下一镜的首帧', '›', `background: ${T.s5}`), 92)}${mMenu(mItem('', '02 · 江上孤舟') + mItem('', '02b · 远景'), 76)}</div>`, '子菜单列各叙事后继，按 sortOrder'),
      frame('已是这张', mMenu(mItem('success', '02 · 江上孤舟', '', `color: ${T.fg6}`) + mItem('', '02b · 远景'), 110), '这张已是 02 的首帧 → 打勾置灰'),
      frame('禁用 · 图像配置', mMenu(mItem('videoConfig', '当下一镜的首帧', '', `color: ${T.fg6}`) + `<div style="padding: 0 5px 3px 21px; font-size: 8px; color: ${T.fg6}">下一镜是图像配置</div>`, 128), 'Q7=A：置灰并说明，不偷换成参考'),
      frame('禁用 · 没 take', mMenu(mItem('videoConfig', '当下一镜的首帧', '', `color: ${T.fg6}`) + `<div style="padding: 0 5px 3px 21px; font-size: 8px; color: ${T.fg6}">还没有生成过</div>`, 128), '配置卡名下没产物时置灰；视频 take 不出这项'),
    ]),
    row('流程', [
      frame('', mini({ title: 'take 3', img: IMG.wide, st: '完成' }), '在 take 卡上右键（配置卡上右键 = 用它的当前 take）', { n: 1 }),
      frame('', `<div style="display: flex; gap: 2px; align-items: flex-start">${mMenu(mItem('videoConfig', '当下一镜的首帧', '›', `background: ${T.s5}`), 92)}${mMenu(mItem('', '02 · 江上孤舟', '', `background: ${T.s5}`), 76)}</div>`, '悬停 › 选下一镜', { n: 2 }),
      frame('', mTip(`<div style="color: ${T.fg1}; font-weight: 500">替换 02 的首帧？</div><div style="color: ${T.fg4}">现在是 镜头 01 · take 2</div><div style="display: flex; justify-content: flex-end; gap: 3px; margin-top: 3px">${dBtn('替换')}</div>`, 130), '02 已有首帧才问；没有就跳过这步', { n: 3 }),
      frame('', `<div style="display: flex; align-items: center">${mini({ title: 'take 3', img: IMG.wide, outline: T.accent, corner: pinOn(14), st: `<span style="color: ${T.accent}">当前</span>`, w: 66 })}${wire(14)}${mini({ title: '02', type: '视频配置', img: '', box: promptBox('江上孤舟'), outline: T.washBorder, st: dirtySt, w: 62 })}</div>`, '首帧线连上；02 的当前 take 因首帧变了标过期', { n: 4 }),
      frame('', mToast('undo', T.fg3, '已接到 02 的首帧', '', '撤销'), '反馈卡带撤销；一次撤掉整组', { n: 5 }),
    ]),
    row('边界', [
      frame('链尾', `<div style="display: flex; align-items: center">${mini({ title: 'take 3', img: IMG.wide, w: 58 })}${wire(10)}${mini({ title: '新 · 视频配置', type: '', img: '', box: promptBox(''), outline: T.accent, st: '刚建', w: 70 })}</div>`, '没有下一镜：右侧同泳道建视频配置，连叙事 + 首帧，一步撤销'),
      frame('用的不是当前', mToast('pin', T.accent, '已接到 02 的首帧', 'take 3 同时设为当前', '撤销'), 'Q1=A 线只从当前出：用非当前 take 时一并设为当前，一步撤销'),
      frame('模型不支持首帧', iBox(iRow('模型', `<span style="color: ${T.accent}">万相 文生视频 · 不读首帧</span>`) + iRow('首帧', '镜头 01 · take 3'), 140), '照连不换模型；检查器模型行出黄字'),
      frame('写入失败', mToast('error', T.danger, '没能接上首帧', '节点和连线都已撤回', '重试'), '建节点 + 连线一个事务；失败零残留，同新建菜单回滚口径'),
      frame('撤销', `<div style="display: flex; flex-direction: column; gap: 4px; align-items: center"><div style="display: flex; gap: 6px">${tag('Ctrl Z', T.fg3)}${tag('⌘Z', T.fg3)}</div><div style="font-size: 8px; color: ${T.fg4}">节点 + 边 + 设为当前</div></div>`, '整组一步；在文本框里 Ctrl Z / ⌘Z 归文本框'),
    ]),
  ],
);

// ================= 本板取的决定 =================
const dItem = (k, v) => `<div style="font-size: 11px; line-height: 1.5"><span style="color: ${T.fg1}; font-weight: 500">${k}</span>　<span style="color: ${T.fg3}">${v}</span></div>`;
const decide = `
  <div style="background: ${T.wash}; border: 1px solid ${T.washBorder}; border-radius: 6px; padding: 10px 16px 12px">
    <div style="font-weight: 500; color: ${T.accent}; margin-bottom: 6px">本板取的决定</div>
    <div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 4px 24px">
      ${dItem('TC-Q1 → A', '改写边：下游连线跟着当前 take 挪（阻塞项，按建议）')}
      ${dItem('Q2 → A', '没固定时新 take 自动成为当前')}
      ${dItem('Q3 → C', '只标真变的 + 原因卡提上游')}
      ${dItem('Q4 → A', '批量默认跳过已固定，可勾回')}
      ${dItem('Q5 → C', '对话框里切、记住上次，首次「只跑过期和没生成的」')}
      ${dItem('Q6', '币种只用 USD')}
      ${dItem('Q7 → A', '下一镜是图像配置时置灰说明')}
      ${dItem('Q8 → A', '超过 50 跑前 50，其余写「另 N 个不在本次」')}
      ${dItem('补定', '价格未知写「—」；并发按提交时刻定最新')}
    </div>
  </div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="position: absolute; left: 32px; right: 32px; top: 22px; display: flex; flex-direction: column; gap: 16px">
    <div>
      <div style="display: flex; align-items: baseline; gap: 14px">
        <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">版本固定与花费 · 状态与流程</div>
        <div style="color: ${T.fg4}">逐功能：状态条 / 主流程 / 边界帧。琥珀「需」= 现在代码里还没有</div>
      </div>
      <div style="font-size: 11px; color: ${T.accent}; margin-top: 4px">按建议：TC-Q1 取 A（改写边）——设为当前、或没固定时出了新 take，接在旧当前上的 data 边挪到新当前；币种只用 USD</div>
    </div>
    ${secTake}
    ${divider}
    ${secDirty}
    ${divider}
    ${secRun}
    ${divider}
    ${secNext}
    ${decide}
  </div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'TakesCostDetail.dc.html', html: page('版本固定与花费 · 状态与流程', W, H, body, logic), W, H };
