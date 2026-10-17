// 画板 1：画布页改后（1600×1000，可交互）
const { T, IMG, SANS, MONO, page, ic, caret, CHIME_JS, TOAST_ENGINE_JS, TOAST_STACK } = require('./common.js');

const W = 1600, H = 1000;

// ---------- 顶部 chrome ----------
const menus = ['文件', '编辑', '画布', '节点', '窗口', '帮助'];
const chrome = `
<div style="position: absolute; left: 0; top: 0; right: 0; height: 30px; background: ${T.s4}; border-bottom: 1px solid ${T.bStrong}; display: flex; align-items: center; padding: 0 0 0 10px; gap: 20px">
  <div style="display: flex; align-items: center; gap: 8px">
    <div style="width: 18px; height: 18px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 10px; font-weight: 700; display: flex; align-items: center; justify-content: center">If</div>
    <div style="font-size: 12px; font-weight: 500; color: ${T.fg1}">InkFrame</div>
  </div>
  <div style="display: flex; gap: 20px; color: ${T.fg3}">${menus.map((m) => `<div>${m}</div>`).join('')}</div>
  <div style="flex: 1"></div>
  <div style="width: 300px; height: 22px; border-radius: 3px; background: ${T.s3}; border: 1px solid ${T.outline}; display: flex; align-items: center; gap: 6px; padding: 0 8px; color: ${T.fg6}">
    ${ic('search', 14)}
    <div style="flex: 1; font-size: 11px">搜索项目、节点、产物…</div>
    <div style="font-family: ${MONO}; font-size: 10px">Ctrl K</div>
  </div>
  <div style="display: flex; align-items: center; gap: 4px">
    <button class="hov" type="button" aria-label="通知" title="通知（F6）" onClick="{{ toggleBell }}" style="position: relative; width: 26px; height: 24px; border-radius: 4px; display: flex; align-items: center; justify-content: center; color: ${T.fg3}; {{ bellBtnStyle }}">
      ${ic('bell', 16)}
      <sc-if value="{{ hasUnread }}" hint-placeholder-val="{{ true }}">
        <div style="position: absolute; top: 3px; right: 4px; width: 6px; height: 6px; border-radius: 3px; background: ${T.accent}; box-shadow: 0 0 0 2px ${T.s4}"></div>
      </sc-if>
    </button>
    <div style="width: 26px; height: 24px; display: flex; align-items: center; justify-content: center; color: ${T.fg3}" aria-hidden="true">
      <svg width="15" height="15" viewBox="0 0 20 20" style="display: block"><circle cx="10" cy="10" r="2.6" fill="none" stroke="currentColor" stroke-width="1.5"></circle><path d="M10 2.5v2.2M10 15.3v2.2M2.5 10h2.2M15.3 10h2.2M4.7 4.7l1.6 1.6M13.7 13.7l1.6 1.6M4.7 15.3l1.6-1.6M13.7 6.3l1.6-1.6" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"></path></svg>
    </div>
  </div>
  <div style="display: flex; height: 30px; color: ${T.fg3}">
    <div style="width: 44px; display: flex; align-items: center; justify-content: center">${ic('zoomOut', 14)}</div>
    <div style="width: 44px; display: flex; align-items: center; justify-content: center"><div style="width: 9px; height: 9px; border: 1.3px solid currentColor; border-radius: 1px"></div></div>
    <div style="width: 44px; display: flex; align-items: center; justify-content: center">${ic('close', 16)}</div>
  </div>
</div>`;

// ---------- 外壳标签行 ----------
const tabs = ['工作室', '画布', '序列', '画廊', '导出'];
const tabbar = `
<div style="position: absolute; left: 0; top: 31px; right: 0; height: 34px; background: ${T.s3}; border-bottom: 1px solid ${T.bStrong}; display: flex; align-items: stretch; padding: 0 12px">
  ${tabs.map((t, i) => i === 1
    ? `<div style="padding: 0 16px; display: flex; align-items: center; color: ${T.fg1}; font-weight: 500; box-shadow: inset 0 -2px 0 ${T.accent}">${t}</div>`
    : `<div style="padding: 0 16px; display: flex; align-items: center; color: ${T.fg3}">${t}</div>`).join('')}
  <div style="width: 1px; background: ${T.control}; margin: 9px 12px"></div>
  <div style="display: flex; align-items: center; gap: 6px; color: ${T.fg5}">
    <span>我的工作室</span><span>›</span><span>示例项目</span><span>›</span><span style="color: ${T.fg1}">画布 1</span>
  </div>
  <div style="flex: 1"></div>
  <div style="display: flex; align-items: center; gap: 8px">
    <div style="height: 24px; padding: 0 10px; border-radius: 3px; border: 1px solid ${T.controlStrong}; color: ${T.fg2}; display: flex; align-items: center; gap: 6px">${ic('sequence', 14)}<span>在序列中查看</span></div>
    <div style="height: 24px; padding: 0 12px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-weight: 500; display: flex; align-items: center; gap: 6px">${ic('export', 14)}<span>导出视频</span></div>
  </div>
</div>`;

// ---------- 左侧导航条 ----------
const railBtn = (id, label) => `
  <button class="hov" type="button" aria-label="${label}" title="${label}" onClick="{{ rail.${id} }}" style="position: relative; width: 32px; height: 32px; border-radius: 4px; display: flex; align-items: center; justify-content: center; {{ rs.${id} }}">${ic(id, 20)}</button>`;
const rail = `
<div style="position: absolute; left: 0; top: 0; bottom: 0; width: 43px; background: ${T.s4}; border-right: 1px solid ${T.bStrong}; display: flex; flex-direction: column; align-items: center; padding: 8px 0; gap: 4px; box-sizing: border-box">
  ${railBtn('outline', '大纲')}
  ${railBtn('assets', '素材')}
  ${railBtn('characters', '角色')}
  ${railBtn('script', '剧本')}
  <div style="flex: 1"></div>
  <div style="width: 32px; height: 32px; border-radius: 4px; display: flex; align-items: center; justify-content: center; color: ${T.fg5}" title="快捷键">${ic('shortcuts', 20)}</div>
  <div style="width: 32px; height: 32px; border-radius: 4px; display: flex; align-items: center; justify-content: center; color: ${T.fg5}" title="帮助">${ic('help', 20)}</div>
  <button class="hov" type="button" aria-label="收起侧栏" title="收起侧栏（Ctrl \\）" onClick="{{ rail.toggle }}" style="width: 32px; height: 32px; border-radius: 4px; display: flex; align-items: center; justify-content: center; color: ${T.fg5}">${ic('panelToggle', 20)}</button>
</div>`;

// ---------- 左栏面板 ----------
const panelHeader = (title, right = '') => `
  <div style="height: 36px; display: flex; align-items: center; padding: 0 12px; gap: 8px; border-bottom: 1px solid ${T.bSubtle}">
    <div style="font-weight: 500; color: ${T.fg1}">${title}</div>
    <div style="flex: 1"></div>${right}
  </div>`;
const filter = (hint) => `
  <div style="margin: 10px 12px 6px; height: 24px; border-radius: 3px; background: ${T.s2}; border: 1px solid ${T.outline}; display: flex; align-items: center; gap: 6px; padding: 0 8px; color: ${T.fg6}">${ic('search', 13)}<span style="font-size: 11px">${hint}</span></div>`;
const groupHead = (label, count, dot = '') => `
  <div style="height: 26px; display: flex; align-items: center; gap: 6px; padding: 0 12px; margin-top: 6px; color: ${T.fg5}; font-size: 11px">${dot}<span>${label}</span><span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">${count}</span></div>`;
const statusDot = (kind) => ({
  done: `<div style="color: ${T.success}" title="完成">${ic('success', 14)}</div>`,
  running: `<div style="display: flex; align-items: center; gap: 4px; color: ${T.accent}"><div class="spin" style="display: flex">${ic('progress', 13)}</div><span style="font-family: ${MONO}; font-size: 10px">62%</span></div>`,
  ready: `<div style="font-size: 10px; color: ${T.fg6}">就绪</div>`,
})[kind];
const outlineShot = (num, name, kind, thumb, status, selected) => `
  <div style="height: 40px; display: flex; align-items: center; gap: 8px; padding: 0 12px; ${selected ? `background: ${T.s5}` : ''}">
    <div style="font-family: ${MONO}; font-size: 10px; color: ${selected ? T.accent : T.fg5}; width: 16px">${num}</div>
    ${thumb ? `<img src="${thumb}" alt="" style="width: 44px; height: 25px; object-fit: cover; border-radius: 2px; outline: 1px solid ${T.outline}">`
      : `<div style="width: 44px; height: 25px; border-radius: 2px; background: ${T.thumb}; outline: 1px solid ${T.outline}; display: flex; align-items: center; justify-content: center; color: ${T.fg6}">${ic(kind === '视频' ? 'videoConfig' : 'imageConfig', 13)}</div>`}
    <div style="flex: 1; min-width: 0">
      <div style="color: ${selected ? T.fg1 : T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${name}</div>
      <div style="font-size: 10px; color: ${T.fg6}">${kind}配置</div>
    </div>
    ${statusDot(status)}
  </div>`;
const outlineChild = (label, thumb) => `
  <div style="height: 26px; display: flex; align-items: center; gap: 8px; padding: 0 12px 0 36px; color: ${T.fg4}">
    <div style="width: 10px; height: 10px; border-left: 1px solid ${T.control}; border-bottom: 1px solid ${T.control}; margin-top: -8px"></div>
    ${thumb ? `<img src="${thumb}" alt="" style="width: 28px; height: 16px; object-fit: cover; border-radius: 2px">` : `<div style="width: 28px; height: 16px; border-radius: 2px; background: ${T.thumb}"></div>`}
    <div style="font-size: 11px">${label}</div>
  </div>`;
const panelOutline = `
  ${panelHeader('大纲', `<div style="height: 22px; padding: 0 8px; border-radius: 3px; border: 1px solid ${T.outline}; display: flex; align-items: center; gap: 6px; color: ${T.fg3}; font-size: 11px">画布 1 ${caret()}</div>`)}
  ${filter('筛选镜头、节点…')}
  ${groupHead('水墨风格', '2 镜', `<div style="width: 8px; height: 8px; border-radius: 2px; background: #E8A87C"></div>`)}
  ${outlineShot('01', '第一个镜头', '图像', null, 'done', false)}
  ${outlineChild('成片 · 图像', IMG.thumbMountain)}
  ${outlineShot('02', '江上孤舟', '视频', null, 'running', true)}
  ${outlineChild('生成中…', null)}
  ${groupHead('未入链', '1')}
  <div style="height: 32px; display: flex; align-items: center; gap: 8px; padding: 0 12px 0 36px; color: ${T.fg3}">
    <img src="${IMG.thumbWide}" alt="" style="width: 44px; height: 25px; object-fit: cover; border-radius: 2px; outline: 1px solid ${T.outline}">
    <div style="flex: 1">远山参考</div><div style="font-size: 10px; color: ${T.fg6}">图像</div>
  </div>`;
const assetTile = (img, label) => `
  <div style="display: flex; flex-direction: column; gap: 4px">
    <img src="${img}" alt="" style="width: 104px; height: 59px; object-fit: cover; border-radius: 3px; outline: 1px solid ${T.outline}">
    <div style="font-size: 10px; color: ${T.fg5}">${label}</div>
  </div>`;
const panelAssets = `
  ${panelHeader('素材', `<div style="color: ${T.fg5}" title="上传">${ic('upload', 16)}</div>`)}
  <div style="margin: 10px 12px 0; height: 26px; border-radius: 4px; background: ${T.s2}; border: 1px solid ${T.outline}; display: flex; padding: 2px; gap: 2px; box-sizing: border-box">
    <div style="flex: 1; border-radius: 3px; background: ${T.s5}; color: ${T.fg1}; display: flex; align-items: center; justify-content: center; font-size: 11px">本画布</div>
    <div style="flex: 1; border-radius: 3px; color: ${T.fg4}; display: flex; align-items: center; justify-content: center; font-size: 11px">项目全部</div>
  </div>
  <div style="display: flex; gap: 6px; margin: 10px 12px 4px">
    <div style="height: 20px; padding: 0 8px; border-radius: 999px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 10px; display: flex; align-items: center">全部 4</div>
    <div style="height: 20px; padding: 0 8px; border-radius: 999px; border: 1px solid ${T.outline}; color: ${T.fg4}; font-size: 10px; display: flex; align-items: center">图片 3</div>
    <div style="height: 20px; padding: 0 8px; border-radius: 999px; border: 1px solid ${T.outline}; color: ${T.fg4}; font-size: 10px; display: flex; align-items: center">视频 1</div>
  </div>
  <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px 8px; padding: 8px 12px">
    ${assetTile(IMG.mountain, '镜头 01 · 成片')}
    ${assetTile(IMG.wide, '远山参考')}
    ${assetTile(IMG.wide, '镜头 01 · take 2')}
    ${assetTile(IMG.mountain, '镜头 02 · 首帧')}
  </div>
  <div style="padding: 4px 12px; font-size: 11px; color: ${T.fg5}">拖进画布即建节点；拖到配置节点上当参考或首帧</div>
  <div style="padding: 8px 12px"><a href="#" style="font-size: 11px; text-decoration: none">在画廊中打开全部 ›</a></div>`;
const charRow = (img, name, meta) => `
  <div style="height: 48px; display: flex; align-items: center; gap: 9px; padding: 0 12px">
    <img src="${img}" alt="" style="width: 36px; height: 36px; object-fit: cover; border-radius: 4px; outline: 1px solid ${T.outline}">
    <div style="flex: 1; min-width: 0"><div style="color: ${T.fg2}">${name}</div><div style="font-size: 10px; color: ${T.fg5}">${meta}</div></div>
    <div style="color: ${T.fg5}">${ic('more', 16)}</div>
  </div>`;
const panelChars = `
  ${panelHeader('角色')}
  ${filter('搜索角色…')}
  ${charRow(IMG.thumbMountain, '渔夫', '3 张参考图 · 2 处引用')}
  ${charRow(IMG.thumbWide, '孤舟', '1 张参考图 · 1 处引用')}
  <div style="margin: 8px 12px; height: 36px; border-radius: 4px; border: 1px dashed ${T.control}; display: flex; align-items: center; justify-content: center; color: ${T.fg4}; font-size: 11px">+ 新建角色</div>
  <div style="padding: 0 12px; font-size: 11px; color: ${T.fg5}; line-height: 1.6">拖到配置节点上即挂载；提示词里输入 @ 也能引用</div>`;
const scriptPara = (chip, text, chipStyle) => `
  <div style="display: flex; gap: 8px; padding: 8px 12px; align-items: flex-start">
    <div style="flex: none; height: 18px; padding: 0 6px; border-radius: 3px; font-family: ${MONO}; font-size: 10px; display: flex; align-items: center; ${chipStyle}">${chip}</div>
    <div style="color: ${T.fg2}; line-height: 1.6">${text}</div>
  </div>`;
const panelScript = `
  ${panelHeader('剧本', `<div style="font-size: 11px; color: ${T.fg4}">导入…</div>`)}
  ${scriptPara('01', '拂晓。雾江上一叶孤舟，远山隐入雾霭。', `background: ${T.s5}; color: ${T.success}`)}
  ${scriptPara('02', '江面雾气渐散，孤舟缓缓驶出画面。', `background: ${T.wash}; color: ${T.accent}`)}
  ${scriptPara('03', '渔夫收网，回望远山。', `border: 1px dashed ${T.control}; color: ${T.fg5}`)}
  <div style="padding: 10px 12px; font-size: 11px; color: ${T.fg5}; border-top: 1px solid ${T.bSubtle}; margin-top: 6px">3 段 · 已对应 2 镜 · 按字数估约 0:15</div>`;
const panel = `
<sc-if value="{{ panelOpen }}" hint-placeholder-val="{{ true }}">
<div style="position: absolute; left: 43px; top: 0; bottom: 0; width: 240px; background: ${T.s3}; border-right: 1px solid ${T.bStrong}; overflow: hidden">
  <sc-if value="{{ pOutline }}" hint-placeholder-val="{{ true }}">${panelOutline}</sc-if>
  <sc-if value="{{ pAssets }}" hint-placeholder-val="{{ false }}">${panelAssets}</sc-if>
  <sc-if value="{{ pChars }}" hint-placeholder-val="{{ false }}">${panelChars}</sc-if>
  <sc-if value="{{ pScript }}" hint-placeholder-val="{{ false }}">${panelScript}</sc-if>
</div>
</sc-if>`;

// ---------- 画布 ----------
// 80% 缩放下的节点卡：宽 180，图区 180×101，端口在图区垂直中线
const NODE_W = 180, BOX_H = 101;
const nodeCard = ({ x, y, title, type, box, status, selected }) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${NODE_W}px">
    <div style="height: 18px; display: flex; align-items: center; gap: 6px; font-size: 11px">
      <div style="font-weight: 500; color: ${selected ? T.fg1 : T.fg2}">${title}</div><div style="flex: 1"></div><div style="font-size: 10px; color: ${T.fg5}">${type}</div>
    </div>
    <div style="position: relative; width: ${NODE_W}px; height: ${BOX_H}px; border-radius: 4px; background: ${T.thumb}; outline: 1px solid ${selected ? T.accent : T.outline}; overflow: hidden">${box}</div>
    <div style="height: 22px; display: flex; align-items: center; gap: 6px; font-size: 10px; color: ${T.fg5}">${status}</div>
  </div>`;
const port = (x, y, filled, color = T.fg5) => `<div style="position: absolute; left: ${x - 5}px; top: ${y - 5}px; width: 10px; height: 10px; border-radius: 5px; box-sizing: border-box; ${filled ? `background: ${color}` : `background: ${T.s1}; border: 1.5px solid ${color}`}"></div>`;
const NY = 140; // 节点标题行 y
const PY = NY + 18 + BOX_H / 2; // 端口 y
const X = [32, 280, 528, 776];
const edgePath = (x1, y1, x2, y2) => { const dx = Math.max(40, Math.min(160, Math.abs(x2 - x1) / 2)); return `M${x1} ${y1}C${x1 + dx} ${y1} ${x2 - dx} ${y2} ${x2} ${y2}`; };
const REF = { x: 280, y: 420 };
const refPY = REF.y + 18 + BOX_H / 2;
const edges = `
  <svg width="1014" height="911" viewBox="0 0 1014 911" aria-hidden="true" style="position: absolute; left: 0; top: 0; pointer-events: none">
    <path d="${edgePath(X[0] + NODE_W, PY, X[1], PY)}" fill="none" stroke="${T.fg6}" stroke-width="1.25" stroke-dasharray="1.5 3.5" stroke-linecap="round"></path>
    <path d="${edgePath(X[1] + NODE_W, PY, X[2], PY)}" fill="none" stroke="${T.teal}" stroke-width="1.75"></path>
    <path d="${edgePath(X[2] + NODE_W, PY, X[3], PY)}" fill="none" stroke="${T.fg6}" stroke-width="1.25" stroke-dasharray="1.5 3.5" stroke-linecap="round"></path>
    <path d="${edgePath(REF.x + NODE_W, refPY, X[2], PY)}" fill="none" stroke="${T.sky}" stroke-width="1.5" stroke-dasharray="5 4"></path>
  </svg>
  <div style="position: absolute; left: ${(X[1] + NODE_W + X[2]) / 2 - 16}px; top: ${PY - 9}px; height: 18px; padding: 0 6px; border-radius: 9px; background: ${T.s1}; border: 1px solid ${T.teal}; color: ${T.teal}; font-size: 10px; display: flex; align-items: center">首帧</div>
  <div style="position: absolute; left: ${(REF.x + NODE_W + X[2]) / 2 - 16}px; top: ${(refPY + PY) / 2 - 9}px; height: 18px; padding: 0 6px; border-radius: 9px; background: ${T.s1}; border: 1px solid ${T.sky}; color: ${T.sky}; font-size: 10px; display: flex; align-items: center">参考</div>`;
// 节点里的提示词：顶部对齐、最多 3 行（80% 缩放下 12px → 约 10px）
const promptBox = (text) => `<div style="position: absolute; left: 0; right: 0; top: 0; padding: 8px 10px; font-size: 10px; line-height: 1.55; color: ${T.fg2}; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden">${text}</div>`;
const nodes = `
  ${nodeCard({ x: X[0], y: NY, title: '镜头 01 · 第一个镜头', type: '图像配置', box: promptBox('拂晓，雾江上一叶孤舟，渔夫站在船头收网；镜头从远景缓推到中景，远山一层层浮出来。'), status: `<span style="color: ${T.success}">✓ 已生成 2 张</span><span>·</span><span>继承 水墨风格</span>`, selected: false })}
  ${nodeCard({ x: X[1], y: NY, title: '成片', type: '图像', box: `<img src="${IMG.mountain}" alt="" style="width: 100%; height: 100%; object-fit: cover">`, status: '<span>take 2 / 2</span>', selected: false })}
  ${nodeCard({ x: X[2], y: NY, title: '镜头 02 · 江上孤舟', type: '视频配置', box: promptBox('江面雾气渐散，渔夫撑船缓缓驶出画面，镜头缓推，结尾停在回望远山的侧脸上。'), status: `<span style="color: ${T.accent}">生成中 62%</span><span>·</span><span>万相 2.2</span>`, selected: true })}
  ${nodeCard({ x: X[3], y: NY, title: '成片', type: '视频', box: `<img src="${IMG.wide}" alt="" style="width: 100%; height: 100%; object-fit: cover; filter: blur(6px) grayscale(.4); opacity: .35"><div style="position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; color: ${T.accent}"><div class="spin" style="display: flex">${ic('progress', 18)}</div><div style="font-family: ${MONO}; font-size: 10px">62%</div></div><div style="position: absolute; left: 0; bottom: 0; height: 2px; width: 62%; background: ${T.accent}"></div>`, status: '<span>排队 0 · 已用 12 秒</span>', selected: false })}
  ${nodeCard({ x: REF.x, y: REF.y, title: '远山参考', type: '图像', box: `<img src="${IMG.wide}" alt="" style="width: 100%; height: 100%; object-fit: cover">`, status: '<span>上传 · 未入链</span>', selected: false })}
  ${port(X[0] + NODE_W, PY, true)}
  ${port(X[1], PY, false)}${port(X[1] + NODE_W, PY, true, T.teal)}
  ${port(X[2], PY, false, T.accent)}${port(X[2] + NODE_W, PY, true, T.accent)}
  ${port(X[3], PY, false)}
  ${port(REF.x + NODE_W, refPY, true, T.sky)}`;
const toolBtn = (id, label, key, hasCaret = false) => `
  <button class="hov" type="button" aria-label="${label}" title="${label}${key ? `（${key}）` : ''}" onClick="{{ tool.${id} }}" style="height: 32px; min-width: 32px; padding: 0 ${hasCaret ? 4 : 6}px; border-radius: 4px; display: flex; align-items: center; justify-content: center; gap: 2px; {{ ts.${id} }}">${ic(id, 20)}${hasCaret ? caret() : ''}</button>`;
const sep = `<div style="width: 1px; height: 20px; background: ${T.control}; margin: 0 4px; align-self: center"></div>`;
const toolbar = `
  <div style="position: absolute; top: 12px; left: 50%; transform: translateX(-50%); display: flex; gap: 2px; padding: 4px; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 6px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); color: ${T.fg3}; z-index: 5">
    ${toolBtn('select', '选择', 'V')}${toolBtn('pan', '平移', 'H / 按住空格')}
    ${sep}
    ${toolBtn('imageConfig', '图像配置', 'I', true)}${toolBtn('videoConfig', '视频配置', 'G')}${toolBtn('lane', '泳道', 'F')}${toolBtn('link', '连线', 'L')}${toolBtn('note', '便签', 'N')}${toolBtn('upload', '上传媒体', 'Ctrl U')}
    ${sep}
    ${toolBtn('more', '更多：导入剧本、整理布局、模板', '')}
  </div>`;
const laneBand = `
  <div style="position: absolute; left: 0; right: 0; top: 64px; height: 300px; border-top: 1px solid ${T.laneDivider}; border-bottom: 1px solid ${T.laneDivider}; background: rgba(232,168,124,0.025)"></div>
  <div style="position: absolute; left: 16px; top: 76px; height: 28px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.outline}">
    <div style="width: 8px; height: 8px; border-radius: 2px; background: #E8A87C"></div>
    <div style="font-weight: 500; color: ${T.fg1}">水墨风格</div>
    <div style="font-size: 11px; color: ${T.fg5}; max-width: 220px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">传统水墨画风，柔和笔触，雾气留白</div>
    <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">2 镜</div>
  </div>`;
const zoom = `
  <div style="position: absolute; left: 12px; bottom: 12px; display: flex; align-items: center; gap: 2px; padding: 3px; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 6px; color: ${T.fg3}">
    <div style="width: 26px; height: 26px; display: flex; align-items: center; justify-content: center" title="缩小">${ic('zoomOut', 16)}</div>
    <div style="width: 44px; text-align: center; font-family: ${MONO}; font-size: 11px; color: ${T.fg2}">80%</div>
    <div style="width: 26px; height: 26px; display: flex; align-items: center; justify-content: center" title="放大">${ic('zoomIn', 16)}</div>
    ${sep}
    <div style="width: 26px; height: 26px; display: flex; align-items: center; justify-content: center" title="适应全部（Shift 1）">${ic('fit', 16)}</div>
    <div style="width: 26px; height: 26px; display: flex; align-items: center; justify-content: center" title="小地图（M）">${ic('minimap', 16)}</div>
  </div>`;
const chip = (label, extra = '') => `<div style="height: 24px; padding: 0 8px; border-radius: 3px; border: 1px solid ${T.outline}; background: ${T.s3}; color: ${T.fg3}; font-size: 11px; display: flex; align-items: center; gap: 6px; ${extra}">${label}</div>`;
const promptBar = `
  <div style="position: absolute; left: 50%; bottom: 16px; transform: translateX(-50%); width: 608px; box-sizing: border-box; padding: 12px 12px 10px 14px; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 6px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); display: flex; flex-direction: column; gap: 10px">
    <div style="font-size: 13px; line-height: 1.6; color: ${T.fg1}">江面雾气渐散，<span style="display: inline-flex; align-items: center; gap: 4px; height: 20px; padding: 0 6px 0 3px; margin: 0 2px; border-radius: 10px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 12px; vertical-align: 1px"><img src="${IMG.thumbMountain}" alt="" style="width: 14px; height: 14px; border-radius: 7px; object-fit: cover">渔夫</span> 撑船缓缓驶出画面，镜头缓推，<br>结尾停在回望远山的侧脸上。</div>
    <div style="display: flex; align-items: center; gap: 6px">
      ${chip(`${ic('videoConfig', 13)}<span>万相 2.2 · 图生视频</span>${caret()}`)}
      ${chip('5 秒')}${chip('16:9')}
      ${chip(`<img src="${IMG.thumbMountain}" alt="" style="width: 16px; height: 12px; object-fit: cover; border-radius: 2px"><span>首帧 · 镜头 01</span>`, `border-color: ${T.teal}`)}
      <div style="flex: 1"></div>
      <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">36 字</div>
      <div style="font-size: 11px; color: ${T.fg5}">约 ¥0.70</div>
      <button class="amber" type="button" onClick="{{ generate }}" title="生成（Ctrl ↵）" style="height: 28px; padding: 0 12px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-weight: 500; display: flex; align-items: center; gap: 6px">${ic('run', 14)}<span>生成</span><span style="font-family: ${MONO}; font-size: 10px; opacity: .7">Ctrl ↵</span></button>
    </div>
  </div>`;
const canvas = `
<div style="position: absolute; top: 0; bottom: 0; right: 301px; background-color: ${T.s1}; background-image: linear-gradient(${T.grid} 1px, transparent 1px), linear-gradient(90deg, ${T.grid} 1px, transparent 1px); background-size: 19.2px 19.2px; overflow: hidden; {{ canvasStyle }}">
  ${laneBand}
  ${edges}
  ${nodes}
  ${toolbar}
  ${zoom}
  ${promptBar}
</div>`;

// ---------- 右侧检查器 ----------
const field = (label, body) => `
  <div style="display: flex; flex-direction: column; gap: 6px; padding: 10px 14px 0">
    <div style="font-size: 11px; color: ${T.fg4}">${label}</div>${body}
  </div>`;
const select = (text) => `<div style="height: 26px; border-radius: 3px; background: ${T.s2}; border: 1px solid ${T.outline}; display: flex; align-items: center; padding: 0 8px; gap: 6px; color: ${T.fg2}"><div style="flex: 1">${text}</div>${caret()}</div>`;
const inspectorProps = `
  <div style="padding: 12px 14px 10px; border-bottom: 1px solid ${T.bSubtle}">
    <div style="display: flex; align-items: center; gap: 8px">
      <div style="color: ${T.fg5}">${ic('videoConfig', 16)}</div>
      <div style="font-weight: 500; color: ${T.fg1}">镜头 02 · 江上孤舟</div>
    </div>
    <div style="display: flex; align-items: center; gap: 8px; margin-top: 10px">
      <div class="spin" style="display: flex; color: ${T.accent}">${ic('progress', 13)}</div>
      <div style="font-size: 11px; color: ${T.accent}">生成中</div>
      <div style="flex: 1; height: 4px; border-radius: 2px; background: ${T.control}; overflow: hidden"><div style="width: 62%; height: 4px; background: ${T.accent}"></div></div>
      <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg4}">62%</div>
    </div>
    <div style="font-size: 10px; color: ${T.fg5}; margin-top: 6px">万相 2.2 · 已用 12 秒 · <span style="color: ${T.fg3}">取消</span></div>
  </div>
  ${field('提示词', `<div style="min-height: 58px; border-radius: 3px; background: ${T.s2}; border: 1px solid ${T.outline}; padding: 8px; color: ${T.fg2}; line-height: 1.55">江面雾气渐散，孤舟缓缓驶出画面，镜头缓推。</div>`)}
  ${field('模型', select('万相 2.2 · 图生视频'))}
  <div style="display: flex; gap: 8px; padding: 0 14px 0 0">
    <div style="flex: 1">${field('时长', select('5 秒'))}</div>
    <div style="flex: 1; margin-left: -14px">${field('画幅', select('16:9'))}</div>
  </div>
  ${field('首帧', `<div style="display: flex; align-items: center; gap: 8px"><img src="${IMG.thumbMountain}" alt="" style="width: 56px; height: 32px; object-fit: cover; border-radius: 2px; outline: 1px solid ${T.teal}"><div style="flex: 1"><div style="color: ${T.fg2}">镜头 01 · 成片</div><div style="font-size: 10px; color: ${T.fg5}">take 2</div></div><div style="font-size: 11px; color: ${T.accent}">定位</div></div>`)}
  ${field('参考图 · 1 / 3', `<div style="display: flex; gap: 6px"><img src="${IMG.thumbWide}" alt="" style="width: 56px; height: 32px; object-fit: cover; border-radius: 2px; outline: 1px solid ${T.sky}"><div style="width: 56px; height: 32px; border-radius: 2px; border: 1px dashed ${T.control}; color: ${T.fg5}; display: flex; align-items: center; justify-content: center">+</div></div>`)}
  ${field('风格', `<div style="display: flex; align-items: center; gap: 8px; color: ${T.fg2}"><div style="width: 14px; height: 14px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; display: flex; align-items: center; justify-content: center">${ic('success', 11)}</div>继承泳道「水墨风格」</div>`)}
  <div style="position: absolute; left: 0; right: 0; bottom: 0; height: 36px; border-top: 1px solid ${T.bSubtle}; display: flex; align-items: center; padding: 0 14px; font-size: 11px; color: ${T.fg5}">预计花费 约 ¥0.70 · 种子 随机</div>`;
const takeRow = (img, label, meta, current) => `
  <div style="display: flex; align-items: center; gap: 10px; padding: 8px 14px; ${current ? `background: ${T.s5}` : ''}">
    <img src="${img}" alt="" style="width: 72px; height: 41px; object-fit: cover; border-radius: 3px; outline: 1px solid ${current ? T.accent : T.outline}">
    <div style="flex: 1"><div style="color: ${T.fg2}">${label}</div><div style="font-size: 10px; color: ${T.fg5}">${meta}</div></div>
    ${current ? `<div style="color: ${T.accent}" title="已固定">${ic('pin', 16)}</div>` : ''}
  </div>`;
const inspectorHistory = `
  <div style="padding: 12px 14px 6px; font-size: 11px; color: ${T.fg4}">镜头 01 的全部 take · 固定的那张往下游流</div>
  ${takeRow(IMG.mountain, 'take 2', '今天 18:02 · 种子 4127 · 18 秒', true)}
  ${takeRow(IMG.wide, 'take 1', '今天 17:55 · 种子 902 · 21 秒', false)}`;
const inspectorTab = (key, label) => `<button type="button" onClick="{{ tabs.${key} }}" style="height: 29px; padding: 0 14px; display: flex; align-items: center; {{ tabStyle.${key} }}">${label}</button>`;
const inspector = `
<div style="position: absolute; right: 0; top: 0; bottom: 0; width: 300px; background: ${T.s3}; border-left: 1px solid ${T.bStrong}">
  <div style="height: 29px; display: flex; border-bottom: 1px solid ${T.bStrong}; background: ${T.s4}">
    ${inspectorTab('props', '属性')}${inspectorTab('history', '历史')}
  </div>
  <sc-if value="{{ tabProps }}" hint-placeholder-val="{{ true }}">${inspectorProps}</sc-if>
  <sc-if value="{{ tabHistory }}" hint-placeholder-val="{{ false }}">${inspectorHistory}</sc-if>
</div>`;

// ---------- 状态栏 + 任务胶囊 ----------
const statusbar = `
<div style="position: absolute; left: 0; right: 0; bottom: 0; height: 22px; background: ${T.s4}; border-top: 1px solid ${T.bStrong}; display: flex; align-items: center; gap: 12px; padding: 0 12px; font-size: 10px; color: ${T.fg5}">
  <span>示例项目 · 画布 1</span><span>5 节点 · 4 边</span><span>选中 1</span>
  <button class="hov" type="button" onClick="{{ toggleTasks }}" aria-label="任务" style="height: 18px; padding: 0 8px; border-radius: 999px; display: flex; align-items: center; gap: 6px; color: ${T.accent}; border: 1px solid ${T.washBorder}; background: ${T.wash}; font-size: 10px">
    <div class="spin" style="display: flex">${ic('progress', 11)}</div><span>生成中 1 · 排队 1</span>
  </button>
  <div style="flex: 1"></div>
  <span style="font-family: ${MONO}">D:\\InkFrame\\projects</span><span style="font-family: ${MONO}">v0.1.0-alpha.12</span>
</div>`;
const taskRow = (title, meta, right, pct) => `
  <div style="padding: 10px 12px; border-bottom: 1px solid ${T.bSubtle}">
    <div style="display: flex; align-items: center; gap: 8px"><div style="flex: 1; color: ${T.fg2}">${title}</div>${right}</div>
    <div style="font-size: 10px; color: ${T.fg5}; margin-top: 2px">${meta}</div>
    ${pct != null ? `<div style="height: 4px; border-radius: 2px; background: ${T.control}; margin-top: 8px; overflow: hidden"><div style="height: 4px; width: ${pct}%; background: ${T.accent}"></div></div>` : ''}
  </div>`;
const tasksPopover = `
<sc-if value="{{ tasksOpen }}" hint-placeholder-val="{{ false }}">
<div class="pop" style="position: absolute; left: 200px; bottom: 30px; width: 340px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6); z-index: 30">
  <div style="height: 36px; display: flex; align-items: center; padding: 0 12px; border-bottom: 1px solid ${T.bStrong}"><div style="font-weight: 500; color: ${T.fg1}">任务</div><div style="flex: 1"></div><div style="font-size: 11px; color: ${T.fg5}">并发 2</div></div>
  ${taskRow('镜头 02 · 视频', '万相 2.2 · 已用 12 秒', `<span style="font-size: 11px; color: ${T.fg4}">取消</span>`, 62)}
  ${taskRow('镜头 03 · 图像', 'Gemini · 排队中', `<span style="font-size: 11px; color: ${T.fg4}">取消</span>`, null)}
  ${taskRow('镜头 01 · 图像', 'Gemini · 完成 · 18 秒', `<span style="font-size: 11px; color: ${T.accent}">定位</span>`, null)}
  <div style="height: 32px; display: flex; align-items: center; padding: 0 12px; font-size: 11px; color: ${T.fg5}">清除已完成</div>
</div>
</sc-if>`;

// ---------- 铃铛下拉：本次会话的通知历史 ----------
const bellPanel = `
<sc-if value="{{ bellOpen }}" hint-placeholder-val="{{ false }}">
<div class="pop" style="position: absolute; right: 150px; top: 34px; width: 360px; max-height: 460px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6); z-index: 50; overflow: hidden">
  <div style="height: 38px; display: flex; align-items: center; gap: 12px; padding: 0 12px; border-bottom: 1px solid ${T.bStrong}">
    <div style="font-weight: 500; color: ${T.fg1}">通知</div><div style="flex: 1"></div>
    <div style="font-size: 11px; color: ${T.fg4}">全部已读</div><div style="font-size: 11px; color: ${T.fg4}">清空</div>
  </div>
  <div style="font-size: 10px; color: ${T.fg5}; padding: 8px 12px 4px">本次会话</div>
  <sc-for list="{{ historyView }}" as="h" hint-placeholder-count="3">
    <div style="display: flex; gap: 10px; padding: 8px 12px; align-items: center">
      <sc-if value="{{ h.hasThumb }}" hint-placeholder-val="{{ false }}"><img src="{{ h.thumb }}" alt="" style="width: 32px; height: 32px; object-fit: cover; border-radius: 3px"></sc-if>
      <sc-if value="{{ h.noThumb }}" hint-placeholder-val="{{ true }}"><div style="width: 32px; height: 32px; border-radius: 3px; background: ${T.s5}; display: flex; align-items: center; justify-content: center; {{ h.tile }}">${ic('bell', 16)}</div></sc-if>
      <div style="flex: 1; min-width: 0"><div style="color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{{ h.title }}</div><div style="font-size: 10px; color: ${T.fg5}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{{ h.body }}</div></div>
      <div style="font-size: 10px; color: ${T.fg6}">{{ h.when }}</div>
    </div>
  </sc-for>
</div>
</sc-if>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  ${chrome}
  ${tabbar}
  <div style="position: absolute; left: 0; right: 0; top: 66px; bottom: 23px">
    ${rail}
    ${panel}
    ${canvas}
    ${inspector}
  </div>
  ${statusbar}
  ${tasksPopover}
  ${bellPanel}
  ${TOAST_STACK('right: 16px; bottom: 39px')}
</div>`;

const logic = `
class Component extends DCLogic {
  constructor(props) {
    super(props);
    this.state = {
      panel: 'outline', panelOpen: true, tool: 'select', bell: false, tasks: false, tab: 'props', hover: false, seq: 2, unread: 2,
      toasts: [
        { id: 1, kind: 'export', title: '导出完成', body: '示例项目_画布1.mp4 · 12.4 MB · 00:15', meta: '示例项目 · 刚刚', a1: '打开文件夹', sticky: true, remaining: 0, total: 0, progress: 0 },
        { id: 2, kind: 'success', title: '镜头 01 已生成', body: '水墨风格 · 图像 · 用时 18 秒', meta: '示例项目 · 画布 1 · 刚刚', thumb: '${IMG.thumbMountain}', a1: '查看', a2: '再来一张', sticky: true, remaining: 0, total: 0, progress: 0 },
      ],
      history: [
        { id: 2, kind: 'success', title: '镜头 01 已生成', body: '水墨风格 · 图像 · 用时 18 秒', when: '刚刚', thumb: '${IMG.thumbMountain}' },
        { id: 1, kind: 'export', title: '导出完成', body: '示例项目_画布1.mp4 · 12.4 MB', when: '刚刚', thumb: '' },
      ],
    };
  }
  componentDidMount() { this.timer = setInterval(() => this.tickToasts(), 100); }
  componentWillUnmount() { clearInterval(this.timer); }
  chimeNow() { this.playChime('a'); }
  toastAction(t, which) { this.closeToast(t.id); }
  pickRail(id) {
    if (id === this.state.panel && this.state.panelOpen) { this.setState({ panelOpen: false }); return; }
    this.setState({ panel: id, panelOpen: true });
  }
  generate() {
    this.pushToast({ kind: 'progress', title: '镜头 02 · 生成中', body: '万相 2.2 · 图生视频 · 5 秒', meta: '示例项目 · 画布 1', dedupe: 'job-shot02', rate: 2.2, a1: '在任务中查看', a2: '取消',
      done: { title: '镜头 02 已生成', body: '水墨风格 · 视频 · 用时 46 秒', thumb: '${IMG.thumbWide}', a1: '查看', a2: '再来一条', chime: true } });
  }
${CHIME_JS}
${TOAST_ENGINE_JS}
  renderVals() {
    const s = this.state;
    const on = 'color: ${T.accent}; background: ${T.wash}';
    const off = 'color: ${T.fg4}';
    const rs = {};
    for (const k of ['outline', 'assets', 'characters', 'script']) rs[k] = (s.panelOpen && s.panel === k) ? on : off;
    const ts = {};
    for (const k of ['select', 'pan', 'imageConfig', 'videoConfig', 'lane', 'link', 'note', 'upload', 'more']) ts[k] = s.tool === k ? 'color: ${T.accent}; background: ${T.wash}' : '';
    const tool = {};
    for (const k of Object.keys(ts)) tool[k] = () => this.setState({ tool: k });
    const kindColor = { success: '${T.success}', export: '${T.fg3}', error: '${T.danger}', warning: '${T.accent}', info: '${T.fg4}', undo: '${T.fg3}' };
    return {
      rs: rs, ts: ts, tool: tool,
      rail: {
        outline: () => this.pickRail('outline'), assets: () => this.pickRail('assets'),
        characters: () => this.pickRail('characters'), script: () => this.pickRail('script'),
        toggle: () => this.setState({ panelOpen: !s.panelOpen }),
      },
      panelOpen: s.panelOpen,
      pOutline: s.panel === 'outline', pAssets: s.panel === 'assets', pChars: s.panel === 'characters', pScript: s.panel === 'script',
      canvasStyle: s.panelOpen ? 'left: 284px' : 'left: 43px',
      tabProps: s.tab === 'props', tabHistory: s.tab === 'history',
      tabs: { props: () => this.setState({ tab: 'props' }), history: () => this.setState({ tab: 'history' }) },
      tabStyle: {
        props: s.tab === 'props' ? 'color: ${T.fg1}; background: ${T.s3}; box-shadow: inset 0 1px 0 ${T.accent}' : 'color: ${T.fg4}',
        history: s.tab === 'history' ? 'color: ${T.fg1}; background: ${T.s3}; box-shadow: inset 0 1px 0 ${T.accent}' : 'color: ${T.fg4}',
      },
      bellOpen: s.bell, hasUnread: (s.unread || 0) > 0,
      bellBtnStyle: s.bell ? 'background: ${T.s5}; color: ${T.fg1}' : '',
      toggleBell: () => this.setState({ bell: !s.bell, unread: 0, tasks: false }),
      openBell: () => this.setState({ bell: true, unread: 0 }),
      tasksOpen: s.tasks, toggleTasks: () => this.setState({ tasks: !s.tasks, bell: false }),
      historyView: (s.history || []).map((h) => ({ title: h.title, body: h.body, when: h.when, thumb: h.thumb, hasThumb: !!h.thumb, noThumb: !h.thumb, tile: 'color: ' + (kindColor[h.kind] || '${T.fg4}') })),
      generate: () => this.generate(),
      tv: this.toastView(),
      stackEnter: () => this.setState({ hover: true }),
      stackLeave: () => this.setState({ hover: false }),
    };
  }
}
`;

module.exports = { file: 'Main.dc.html', html: page('画布页 · 改后', W, H, body, logic) };
