// 第二批画板：版本固定、过期标记与花费（1280×1380，静态）
// 当前 take（固定 = 转正）/ 过期标记 / 花费预告 + 批量运行确认 / 运行叙事链 / 「当下一镜的首帧」
const { T, IMG, SANS, MONO, page, ic } = require('./common.js');

const W = 1280, H = 1380;

// ---- 与 interactions.js 同一套小件（本地拷贝）----
const h3 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 8px; margin-bottom: 12px"><div style="font-weight: 500; color: ${T.fg1}">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const kbd = (k) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}">${k}</span>`;
const menuItem = (icon, label, key = '', extra = '') => `
  <div style="height: 28px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border-radius: 3px; color: ${T.fg2}; ${extra}">
    ${icon ? `<div style="color: ${T.fg4}; display: flex">${ic(icon, 16)}</div>` : '<div style="width: 16px"></div>'}
    <div style="flex: 1">${label}</div>${key ? kbd(key) : ''}
  </div>`;
const menuSep = `<div style="height: 1px; background: ${T.bStrong}; margin: 4px 0"></div>`;
const menu = (inner, width = 240) => `<div style="width: ${width}px; box-sizing: border-box; padding: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6)">${inner}</div>`;
const rules = (lines) => `<div style="font-size: 11px; color: ${T.fg4}; line-height: 1.65">${lines.map((l) => `· ${l}`).join('<br>')}</div>`;
const em = (t) => `<span style="color: ${T.fg2}">${t}</span>`;
const mono = (t) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${t}</span>`;
const two = (a, b) => `<div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 20px; margin-top: 10px">${rules(a)}${rules(b)}</div>`;

// 图钉：当前 = 琥珀底；可设为当前 = 灰色
const pinOn = `<div title="当前 · 已固定" style="width: 22px; height: 22px; flex: none; border-radius: 4px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; display: flex; align-items: center; justify-content: center; box-sizing: border-box">${ic('pin', 14)}</div>`;
const pinOff = `<div title="设为当前" style="width: 22px; height: 22px; flex: none; border-radius: 4px; color: ${T.fg6}; display: flex; align-items: center; justify-content: center">${ic('pin', 14)}</div>`;
const tag = (t, c = T.fg4, b = T.outline) => `<span style="height: 16px; padding: 0 5px; border-radius: 3px; border: 1px solid ${b}; color: ${c}; font-size: 10px; display: inline-flex; align-items: center; white-space: nowrap">${t}</span>`;

// ---- 迷你节点卡（与 main.js 的 nodeCard 同构，按 120 宽画）----
const CW = 120, CH = 68;
const card = ({ x, y, title, type, box, status, outline = T.outline, dim = false }) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${CW}px; ${dim ? 'opacity: .55' : ''}">
    <div style="height: 16px; display: flex; align-items: center; gap: 4px; font-size: 10px">
      <div style="font-weight: 500; color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</div><div style="flex: 1"></div><div style="color: ${T.fg5}">${type}</div>
    </div>
    <div style="position: relative; width: ${CW}px; height: ${CH}px; border-radius: 4px; background: ${T.thumb}; outline: 1px solid ${outline}; overflow: hidden">${box}</div>
    <div style="height: 18px; display: flex; align-items: center; gap: 4px; font-size: 10px; color: ${T.fg5}; white-space: nowrap">${status}</div>
  </div>`;
const imgBox = (src) => `<img src="${src}" alt="" style="width: 100%; height: 100%; object-fit: cover">`;
const promptBox = (text) => `<div style="padding: 6px 7px; font-size: 9px; line-height: 1.5; color: ${T.fg2}; display: -webkit-box; -webkit-line-clamp: 4; -webkit-box-orient: vertical; overflow: hidden">${text}</div>`;
const curve = (x1, y1, x2, y2, stroke, extra) => { const dx = Math.max(16, (x2 - x1) / 2); return `<path d="M${x1} ${y1}C${x1 + dx} ${y1} ${x2 - dx} ${y2} ${x2} ${y2}" fill="none" stroke="${stroke}" ${extra}></path>`; };
const lineage = (x1, y1, x2, y2) => curve(x1, y1, x2, y2, T.fg6, 'stroke-width="1.25" stroke-dasharray="1.5 3.5" stroke-linecap="round"');

// ================= A · 当前 take =================
const PY = 16 + CH / 2; // 卡片端口 y（相对卡顶）
const takeCards = `
  <div style="position: relative; width: 290px; height: 210px; flex: none">
    <svg width="290" height="210" viewBox="0 0 290 210" aria-hidden="true" style="position: absolute; left: 0; top: 0">
      ${lineage(120, PY, 160, PY)}${lineage(120, PY, 160, 106 + PY)}
      ${curve(280, 106 + PY, 290, 106 + PY, T.teal, 'stroke-width="1.75"')}
    </svg>
    ${card({ x: 0, y: 0, title: '镜头 01', type: '图像配置', box: promptBox('拂晓，雾江上一叶孤舟，渔夫站在船头收网；远山一层层浮出来。'), status: `<span style="color: ${T.success}">3 个 take</span><span>·</span><span style="color: ${T.fg3}">当前 take 2</span>` })}
    ${card({ x: 160, y: 0, title: '成片', type: '图像', box: imgBox(IMG.wide), status: '<span>take 3 / 3 · 未采用</span>', dim: true })}
    ${card({ x: 160, y: 106, title: '成片', type: '图像', box: imgBox(IMG.mountain) + `<div style="position: absolute; right: 4px; top: 4px">${pinOn}</div>`, status: `<span style="color: ${T.accent}">take 2 / 3 · 当前</span>`, outline: T.accent })}
    <div style="position: absolute; left: 0; top: 112px; width: 124px; font-size: 10px; color: ${T.fg5}; line-height: 1.6">当前 take：琥珀描边 + 图钉<br>其余 take：图区半透明<br>「未采用」= 比当前新，<br>但当前是固定的<br>首帧线只从当前 take 出 →</div>
  </div>`;

const slot = (src, chosen) => `<div style="position: relative; width: 38px; height: 22px; border-radius: 2px; overflow: hidden; outline: 1px solid ${chosen ? T.accent : T.outline}"><img src="${src}" alt="" style="width: 100%; height: 100%; object-fit: cover; ${chosen ? '' : 'opacity: .7'}">${chosen ? `<div style="position: absolute; right: 1px; top: 1px; width: 10px; height: 10px; border-radius: 5px; background: ${T.accent}; color: ${T.onAccent}; display: flex; align-items: center; justify-content: center">${ic('success', 8)}</div>` : ''}</div>`;
const histRow = (img, label, meta, right, current, extra = '') => `
  <div style="padding: 6px 10px; ${current ? `background: ${T.s5}` : ''}">
    <div style="display: flex; align-items: center; gap: 8px">
      <img src="${img}" alt="" style="width: 56px; height: 32px; object-fit: cover; border-radius: 3px; outline: 1px solid ${current ? T.accent : T.outline}">
      <div style="flex: 1; min-width: 0"><div style="color: ${T.fg2}; display: flex; align-items: center; gap: 6px">${label}</div><div style="font-size: 10px; color: ${T.fg5}">${meta}</div></div>
      ${right}
    </div>${extra}
  </div>`;
const historyPanel = `
  <div style="width: 300px; flex: none; background: ${T.s3}; border: 1px solid ${T.bStrong}; border-radius: 4px; overflow: hidden">
    <div style="height: 26px; display: flex; background: ${T.s4}; border-bottom: 1px solid ${T.bStrong}; font-size: 11px">
      <div style="padding: 0 12px; display: flex; align-items: center; color: ${T.fg4}">属性</div>
      <div style="padding: 0 12px; display: flex; align-items: center; color: ${T.fg1}; box-shadow: inset 0 -2px 0 ${T.accent}">历史</div>
    </div>
    <div style="padding: 6px 10px 2px; font-size: 10px; color: ${T.fg5}">镜头 01 的全部 take · 当前那张往下游流</div>
    ${histRow(IMG.wide, `take 3 ${tag('批量 4 张')}`, '18 分钟前', pinOff, false,
      `<div style="display: flex; gap: 4px; margin: 5px 0 0 64px">${slot(IMG.wide, false)}${slot(IMG.mountain, true)}${slot(IMG.wide, false)}${slot(IMG.mountain, false)}</div>`)}
    ${histRow(IMG.mountain, `take 2 ${tag('在用', T.teal, T.teal)}`, '今天 18:02 · 种子 4127', pinOn, true)}
    ${histRow(IMG.wide, 'take 1', '今天 17:55 · 种子 902', `<div style="display: flex; align-items: center; gap: 2px; color: ${T.fg3}; font-size: 10px">设为当前${pinOff}</div>`, false)}
  </div>`;

const colTake = `
  <div>
    ${h3('当前 take · 固定', '「转正」并进来：一镜只有一个「当前」，固定 = 新 take 不顶替它')}
    <div style="display: flex; gap: 20px">${takeCards}${historyPanel}</div>
    ${two([
      `${em('当前 = 固定的 ?? 最新的')}；判据收成 ${mono('currentResultFor')}，序列 / 导出 / 画廊 / ⌘K 产物组共用`,
      `存配置节点 type_config.${mono('pinned_result_id')}，JSONB 键，不用迁移；导入 / 模板 / 跨项目粘贴的改写见右侧「过期标记」`,
      `固定的被删 → 回落最新；撤销删除时一起回来`,
      `${em('撤销')}：「设为当前」连同它改写的 data 边算一步（Q1 选 A 时）；反向按边两端的节点找边，不按边 id`,
    ], [
      `${em('批量 take')} 展开成 slot；点 slot = 现有 promote + 设为当前，同一事务。「转正」「设为产物」退场`,
      `固定时出了新 take：通知写「当前仍是 take 2」+「设为当前」`,
      `导出默认勾当前 take，行尾标「固定」；收 BOARD 第 200 行`,
      `成片检查器（已有 定位来源节点 / 在序列中定位 / 播放）加一个「设为当前」，是当前就显示打勾置灰`,
    ])}
  </div>`;

// ================= B · 过期标记 =================
const dirtyCard = `
  <div style="position: relative; width: 120px; height: 102px; flex: none">
    ${card({ x: 0, y: 0, title: '成片', type: '视频', box: imgBox(IMG.wide), status: `<span style="color: ${T.accent}; display: flex; align-items: center; gap: 3px">${ic('dirty', 12)}已过期</span><span>· take 2</span>`, outline: T.washBorder })}
  </div>`;
const reason = (k, v) => `<div style="display: flex; gap: 8px; padding: 2px 0"><div style="width: 50px; flex: none; color: ${T.fg5}">${k}</div><div style="flex: 1; min-width: 0; color: ${T.fg2}">${v}</div></div>`;
const dirtyPop = `
  <div style="width: 256px; flex: none; box-sizing: border-box; padding: 10px 12px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6); font-size: 11px">
    <div style="display: flex; align-items: center; gap: 6px; color: ${T.fg1}; font-weight: 500; margin-bottom: 4px"><div style="color: ${T.accent}; display: flex">${ic('dirty', 14)}</div>生成这张之后，输入变了</div>
    ${reason('提示词', '「…雾气渐散」→「…晨光破雾」')}
    ${reason('种子', `${mono('4127')} → ${mono('88')}`)}
    ${reason('泳道风格', '「水墨风格」改过')}
    ${reason('首帧', '镜头 01 换成 take 3')}
    <div style="font-size: 10px; color: ${T.fg6}; margin-top: 2px">上游 镜头 01 也已过期</div>
    <div style="display: flex; justify-content: flex-end; margin-top: 6px">
      <div style="height: 24px; padding: 0 10px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-weight: 500; display: flex; align-items: center; gap: 6px">${ic('run', 12)}重新生成 <span style="font-family: ${MONO}; font-size: 10px; opacity: .75">约 $0.75</span></div>
    </div>
  </div>`;
const oRow = (n, name, right) => `
    <div style="height: 28px; display: flex; align-items: center; gap: 6px; padding: 0 8px">
      <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}; width: 14px">${n}</div>
      <div style="flex: 1; min-width: 0; color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${name}</div>${right}
    </div>`;
const outlineMini = `
  <div style="width: 150px; flex: none">
    <div style="font-size: 10px; color: ${T.fg5}; margin-bottom: 4px">左栏大纲</div>
    <div style="background: ${T.s3}; border: 1px solid ${T.bStrong}; border-radius: 4px; padding: 2px 0">
      ${oRow('02', '江上孤舟', `<div style="display: flex; align-items: center; gap: 2px; color: ${T.accent}; font-size: 10px">${ic('dirty', 12)}过期</div>`)}
      ${oRow('03', '远山隐没', `<div style="color: ${T.success}; display: flex">${ic('success', 13)}</div>`)}
    </div>
    <div style="font-size: 10px; color: ${T.fg6}; line-height: 1.55; margin-top: 6px">配置卡状态行：<br>「当前 take 已过期」</div>
  </div>`;
const colDirty = `
  <div>
    ${h3('过期标记', '比对快照得出；改回原值，标记自己消失')}
    <div style="display: flex; gap: 12px; align-items: flex-start">${dirtyCard}${dirtyPop}${outlineMini}</div>
    ${two([
      `${em('快照')}：建 job 的同一事务写 result 的 type_config.${mono('gen_inputs')}——提示词 / 负向 / 种子 / 模型参数 / 运镜、泳道与画布底稿风格、挂载角色、每条 data 入边的源与 image_url`,
      `不拿 jobs 行当快照：它 30 天 / 按画布上限会被清`,
    ], [
      `${em('只标当前 take')}；旧 take 是历史不标；没快照的老产物不标`,
      `不算变化：改名、位置、层级、批量张数、原本就随机的种子`,
      `清除：重新生成，或换一张不过期的设为当前`,
    ])}
    ${two([
      `${em('重映射')}：${mono('gen_inputs')} 里的源节点 id 和 ${mono('pinned_result_id')} 一起处理。导入项目包（${mono('import_remapper')}）按 UUID 映射改写`,
      `插入模板：模板不带产物，两样都不该出现，出现就剥掉`,
    ], [
      `跨项目粘贴：映射得到的改写，映射不到的剥掉；剥掉源 id 的 take 记作「没快照」，不标过期`,
      `提示词里的 ${mono('@{角色 id}')} 同样要改写或剥掉，规则在 ImportSearch`,
    ])}
  </div>`;

// ================= C · 花费 + 批量运行 =================
const costTip = `
  <div style="display: flex; flex-direction: column; align-items: flex-end; gap: 6px">
    <div style="width: 268px; box-sizing: border-box; padding: 8px 10px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); font-size: 11px">
      <div style="display: flex; align-items: baseline; gap: 6px"><span style="color: ${T.fg5}">预计</span><span style="color: ${T.fg1}; font-size: 13px; font-weight: 500">约 $0.75</span></div>
      <div style="color: ${T.fg4}; margin-top: 2px">万相 图生视频 · 5 秒 · 720p</div>
      <div style="font-size: 10px; color: ${T.fg6}; margin-top: 2px">$0.30 / 秒（1080p）× 0.5 · 以服务商账单为准</div>
    </div>
    <div style="display: flex; align-items: center; gap: 8px">
      <div style="font-size: 11px; color: ${T.fg5}">约 $0.75</div>
      <div style="height: 28px; padding: 0 12px; border-radius: 3px; background: ${T.accentHover}; color: ${T.onAccent}; font-weight: 500; display: flex; align-items: center; gap: 6px">${ic('run', 14)}<span>生成</span><span style="font-family: ${MONO}; font-size: 10px; opacity: .7">Ctrl ↵</span></div>
    </div>
    <div style="display: flex; gap: 6px">${tag('批量 $0.032 × 4 = $0.13')}${tag('自定义接口 —')}${tag('&lt;$0.01')}</div>
  </div>`;

const runRow = (n, name, model, cost, state, stateColor = T.fg4, dim = false) => `
  <div style="display: grid; grid-template-columns: 18px minmax(0, 1fr) 132px 40px 86px; align-items: center; gap: 8px; height: 30px; padding: 0 12px; border-bottom: 1px solid ${T.bSubtle}; ${dim ? 'opacity: .5' : ''}">
    <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}">${n}</div>
    <div style="color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${name}</div>
    <div style="font-size: 10px; color: ${T.fg5}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${model}</div>
    <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}; text-align: right">${cost}</div>
    <div style="font-size: 10px; color: ${stateColor}; white-space: nowrap">${state}</div>
  </div>`;
const seg = (a, b) => `<div style="height: 22px; border-radius: 4px; background: ${T.s2}; border: 1px solid ${T.outline}; display: flex; padding: 2px; gap: 2px; box-sizing: border-box; font-size: 10px"><div style="padding: 0 8px; border-radius: 3px; background: ${T.s5}; color: ${T.fg1}; display: flex; align-items: center">${a}</div><div style="padding: 0 8px; border-radius: 3px; color: ${T.fg4}; display: flex; align-items: center">${b}</div></div>`;
const check = (on, label) => `<div style="display: flex; align-items: center; gap: 6px; font-size: 11px; color: ${T.fg3}"><div style="width: 13px; height: 13px; border-radius: 3px; box-sizing: border-box; ${on ? `background: ${T.accent}; color: ${T.onAccent}` : `border: 1px solid ${T.control}`}; display: flex; align-items: center; justify-content: center">${on ? ic('success', 10) : ''}</div>${label}</div>`;
const runDialog = `
  <div style="width: 452px; flex: none; background: ${T.s3}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6); overflow: hidden">
    <div style="height: 40px; display: flex; align-items: center; gap: 8px; padding: 0 12px; border-bottom: 1px solid ${T.bStrong}; background: ${T.s4}">
      <div style="color: ${T.fg4}; display: flex">${ic('sequence', 16)}</div>
      <div style="font-weight: 500; color: ${T.fg1}">运行叙事链 · 画布 1</div>
      <div style="flex: 1"></div>${seg('只跑过期和没生成的', '全部')}
    </div>
    ${runRow('01', '第一个镜头', '万相 图像 × 4 张', '$0.13', '没生成过')}
    ${runRow('02', '江上孤舟', '万相 图生视频 5 秒 720p', '$0.75', '等 01 · 首帧', T.sky)}
    ${runRow('03', '远山隐没', '可灵 V3 5 秒 1080p', '$1.75', '已过期', T.accent)}
    ${runRow('04', '收网', '自定义接口', '—', '价格未知')}
    ${runRow('05', '回望', '万相 图像', '', '跳过 · 已固定', T.fg5, true)}
    ${runRow('06', '旧版开场', '万相 图生视频', '', '跳过 · 已停用', T.fg5, true)}
    <div style="display: flex; align-items: center; gap: 12px; padding: 10px 12px 0">${check(false, '包括已固定的')}<div style="flex: 1"></div><div style="font-size: 10px; color: ${T.fg5}">预计 4:10 · 并发 2 · 单次最多 50</div></div>
    <div style="display: flex; align-items: center; gap: 8px; padding: 10px 12px 12px">
      <div style="flex: 1; font-size: 11px; color: ${T.fg3}">4 个 · 约 ${em('$2.63')} · 另 1 个价格未知</div>
      <button type="button" class="hov" style="height: 28px; padding: 0 12px; border-radius: 3px; border: 1px solid ${T.controlStrong}; color: ${T.fg2}">取消</button>
      <button type="button" class="amber" style="height: 28px; padding: 0 12px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-weight: 500; display: flex; align-items: center; gap: 6px">${ic('run', 14)}运行 4 个</button>
    </div>
  </div>`;

const colRun = `
  <div>
    ${h3('花费预告 · 批量运行', '运行前就知道要花多少；一次跑多个，先确认')}
    <div style="display: flex; gap: 20px; align-items: flex-start">
      ${runDialog}
      <div style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 10px">
        ${costTip}
        ${rules([
          `估算来自 ${mono('estimateCostUsd')}，单位 USD，不读账单`,
          `${em('价格未知')}写「—」：自定义接口的 costModel 是 perCall 0，检查器现在会写成 $0.00，要改。合计行统一写「另 N 个价格未知」`,
          `${em('币种')}只用 USD（$，${mono('formatCostUsd')}）。第一批 Main 稿上的「¥0.70」是旧写法，会改成 $`,
          `悬停任何「生成」出明细；提示词条在按钮左侧常驻金额`,
          `${em('耗时')} = jobs 表同 provider 最近 10 次 completed_at − submitted_at 的中位数；没历史写「—」。格式全应用共用：不到 60 秒写「N 秒」，满 60 秒写 m:ss`,
        ])}
      </div>
    </div>
    ${two([
      `${em('确认规则（只在这里定，Selection / ContextMenus 引用）')}：要跑的节点 ≥ 2 个才弹，单个照旧不弹；对话框逐行列出节点 + 合计；单次最多 50 个`,
      `${em('入口')}：多选 Ctrl ↵、右键「生成 N 个」、大纲组头「运行这组」、更多「运行叙事链」、⌘K，全走这一个对话框`,
      `${em('顺序')}（同样只在这里定）按 data 边的依赖：批内有上游 → 下游等它成功，用新的当前 take 再提交；没有依赖的按叙事链序；受全局并发与 provider 上限`,
      `超过 50 个：按上面的顺序取前 50 个，底部写「另 N 个不在本次」，按钮「运行 50 个」（Q8）`,
    ], [
      `${em('不跑批外上游')}：用它现在的当前 take；没有 take → 「缺首帧 · 跳过」；草稿（没提示词）不列`,
      `上游失败 → 下游不提交；任务胶囊可取消这一批（parameters.${mono('run_group')}，不用迁移）`,
      `${em('已停用')}的节点（type_config.${mono('disabled')}）列一行「跳过 · 已停用」：不计数、不计价，也不能勾回；要跑先右键「启用」`,
      `已固定的列「跳过 · 已固定」，可用「包括已固定的」勾回（Q4）`,
    ])}
  </div>`;

// ================= D · 当下一镜的首帧 =================
const caseRow = (next, result, last = false) => `
  <div style="display: grid; grid-template-columns: 108px minmax(0, 1fr); gap: 10px; padding: 4px 0; ${last ? '' : `border-bottom: 1px solid ${T.bSubtle}`}; font-size: 11px; line-height: 1.55">
    <div style="color: ${T.fg2}">${next}</div><div style="color: ${T.fg4}">${result}</div>
  </div>`;
const colNext = `
  <div>
    ${h3('当下一镜的首帧', '节点右键，把这张图接到叙事链下一镜的首帧')}
    <div style="display: flex; gap: 4px; align-items: flex-start; margin-bottom: 8px">
      ${menu(`
        ${menuItem('videoConfig', '当下一镜的首帧', '›', `background: ${T.s5}`)}
        ${menuItem('pin', '设为当前')}
      `, 184)}
      <div style="margin-top: 2px">${menu(`${menuItem('', '02 · 江上孤舟')}${menuItem('', '02b · 远景分支')}`, 150)}</div>
    </div>
    <div style="font-size: 10px; color: ${T.fg6}; line-height: 1.55; margin-bottom: 2px">下一镜 = 来源配置节点的 narrative 后继。take 卡上右键用这张；配置卡上右键用它的当前 take</div>
    ${caseRow('链尾，没有下一镜', '右侧同泳道建视频配置，连好叙事 + 首帧')}
    ${caseRow('视频配置，没首帧', '连一条首帧边')}
    ${caseRow('视频配置，已有首帧', '确认后替换；已是这张 → 打勾置灰')}
    ${caseRow('镜头节点（剧本）', '走「用本镜备注生成」建视频配置再连')}
    ${caseRow('图像配置', '置灰并说明（Q7）')}
    ${caseRow('多个后继', '子菜单列出各分支，按 sortOrder')}
    ${caseRow('模型不支持首帧', '照连不换模型；检查器模型行出黄字', true)}
    <div style="font-size: 11px; color: ${T.fg4}; line-height: 1.65; margin-top: 4px">· 一次 Ctrl Z 撤掉整组（节点 + 边）<br>· 视频 take 不出这项；「尾帧当首帧」要先抽帧，放 P2</div>
  </div>`;

// ================= 需要你定 =================
const q = (n, title, opts, rec, span = 1) => `
  <div style="font-size: 11px; line-height: 1.55; ${span > 1 ? `grid-column: span ${span}` : ''}">
    <div style="color: ${T.fg1}; font-weight: 500">${n} ${title}</div>
    <div style="color: ${T.fg3}">${opts}</div>
    <div style="color: ${T.accent}">建议 ${rec}</div>
  </div>`;
const decide = `
  <div style="background: ${T.wash}; border: 1px solid ${T.washBorder}; border-radius: 6px; padding: 12px 16px 14px">
    <div style="display: flex; align-items: baseline; gap: 12px; margin-bottom: 8px"><div style="font-weight: 500; color: ${T.accent}">需要你定</div><div style="font-size: 11px; color: ${T.fg4}">原 Q6 币种已定：只用 USD，第一批 Main 稿的 ¥ 会改成 $</div></div>
    <div style="display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px 24px">
      ${q('Q1', '下游连线怎么跟着当前 take', 'A. 改写连线：设为当前、或没固定时出了新 take，就把接在旧当前上的 data 边挪过去，线永远画在当前 take 上<br>B. 连线不动，生成时解析到同一配置的当前 take', 'A：所见即所用，生成侧读边的代码不用改', 2)}
      ${q('Q2', '没固定时，新 take 自动成为当前吗', 'A. 是，就是现在的「取最新」<br>B. 否，一律手动设为当前', 'A；固定只管不被顶替')}
      ${q('Q3', '过期往下游传多深', 'A. 只标输入真变了的那张<br>B. 沿链传递　C. A + 原因卡提一句上游', 'C')}
      ${q('Q4', '批量运行跳不跳过已固定的', 'A. 默认跳过，可勾回<br>B. 照跑', 'A：固定 = 这张定了，别再花钱')}
      ${q('Q5', '运行叙事链默认跑哪些', 'A. 只跑过期和没生成过的<br>B. 全部　C. 对话框里切，记住上次', 'C，首次默认 A')}
      ${q('Q7', '下一镜是图像配置时', 'A. 置灰说明　B. 先插一个视频配置<br>C. 改成当参考连上', 'A：不偷换语义')}
      ${q('Q8', '一次选了超过 50 个', 'A. 按批量顺序跑前 50 个，其余写「另 N 个不在本次」<br>B. 不让运行，提示缩小选择', 'A：上游先跑，剩下的下次接着跑')}
    </div>
  </div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="position: absolute; left: 32px; top: 28px; display: flex; align-items: baseline; gap: 14px">
    <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">版本固定、过期标记与花费</div>
    <div style="color: ${T.fg4}">满意的锁住不再付费重跑；上游改了下游看得见；运行前知道要花多少</div>
  </div>
  <div style="position: absolute; left: 32px; right: 32px; top: 70px; display: flex; flex-direction: column; gap: 20px">
    <div style="display: grid; grid-template-columns: 610px minmax(0, 1fr); gap: 32px">${colTake}${colDirty}</div>
    <div style="height: 1px; background: ${T.control}; margin: -6px 0"></div>
    <div style="display: grid; grid-template-columns: 780px minmax(0, 1fr); gap: 32px">${colRun}${colNext}</div>
    ${decide}
  </div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'TakesCost.dc.html', html: page('版本固定与花费', W, H, body, logic) };
