// 第二批画板：撤销 / 重做与剪贴板（1280×1400，静态）
// 左侧 824 宽：三行 × 两栏（撤销入口 | 进栈清单；复制粘贴 | 落点与跨界；撤销卡 | 系统剪贴板）
// 右侧 360 宽：需要你定 + 要补的底座
const { T, IMG, SANS, MONO, page, ic } = require('./common.js');

const W = 1280, H = 1400;

// ---- 与 interactions.js 同一套小件（本地拷贝）----
const h3 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 8px; margin-bottom: 10px"><div style="font-weight: 500; color: ${T.fg1}; white-space: nowrap">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const kbd = (k, color = T.fg5) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${color}; white-space: nowrap">${k}</span>`;
const iconBox = (html, color = T.fg4) => `<div style="color: ${color}; display: flex">${html}</div>`;
const redoIcon = (size = 16) => `<div style="display: flex; transform: scaleX(-1)">${ic('undo', size)}</div>`;
const menuItem = (iconHtml, label, key = '', extra = '', dim = false) => `
  <div style="height: 28px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border-radius: 3px; color: ${dim ? T.fg6 : T.fg2}; ${extra}">
    ${iconHtml ? iconBox(iconHtml, dim ? T.fg6 : T.fg4) : '<div style="width: 16px"></div>'}
    <div style="flex: 1; white-space: nowrap">${label}</div>${key ? kbd(key, dim ? T.fg6 : T.fg5) : ''}
  </div>`;
const menuSep = `<div style="height: 1px; background: ${T.bStrong}; margin: 4px 0"></div>`;
const menu = (inner, width = 240) => `<div style="width: ${width}px; box-sizing: border-box; padding: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6)">${inner}</div>`;
const rules = (lines) => `<div style="font-size: 11px; color: ${T.fg4}; line-height: 1.6">${lines.map((l) => `<div>· ${l}</div>`).join('')}</div>`;
const sub = (t) => `<div style="font-size: 11px; color: ${T.fg5}; margin-bottom: 6px">${t}</div>`;
const code = (t) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${t}</span>`;

// 画布底部居中的小胶囊（轻提示，不走通知卡）
const capsule = (iconHtml, text, right = '') => `
  <div style="display: inline-flex; align-items: center; gap: 8px; height: 28px; padding: 0 12px; border-radius: 999px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; box-shadow: 0 8px 24px rgba(0,0,0,0.45); color: ${T.fg2}; font-size: 11px">
    ${iconBox(iconHtml, T.fg3)}<span style="white-space: nowrap">${text}</span>${right ? `<span style="width: 1px; height: 12px; background: ${T.control}"></span>${right}` : ''}
  </div>`;

// 迷你节点卡（与 main.js 的卡同构：标题行 + 图区 + 状态行）
const card = ({ x, y, w = 104, bh = 58, title, type, box, status, sel = false, dim = false }) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; ${dim ? 'opacity: .4' : ''}">
    <div style="height: 16px; display: flex; align-items: center; gap: 4px; font-size: 10px">
      <div style="font-weight: 500; color: ${sel ? T.fg1 : T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</div><div style="flex: 1"></div><div style="font-size: 9px; color: ${T.fg5}; white-space: nowrap">${type}</div>
    </div>
    <div style="position: relative; width: ${w}px; height: ${bh}px; border-radius: 4px; background: ${T.thumb}; outline: 1px solid ${sel ? T.accent : T.outline}; overflow: hidden">${box}</div>
    <div style="height: 18px; display: flex; align-items: center; gap: 4px; font-size: 9px; color: ${T.fg5}; white-space: nowrap">${status}</div>
  </div>`;
const imgBox = (src) => `<img src="${src}" alt="" style="width: 100%; height: 100%; object-fit: cover">`;
const textBox = (t, size = 9, lines = 4) => `<div style="position: absolute; left: 0; right: 0; top: 0; padding: 6px 8px; font-size: ${size}px; line-height: 1.5; color: ${T.fg2}; display: -webkit-box; -webkit-line-clamp: ${lines}; -webkit-box-orient: vertical; overflow: hidden">${t}</div>`;

// ================= 撤销 / 重做：入口 =================
const entryCol = `
  <div>
    ${h3('撤销 / 重做', 'Windows Ctrl Z · Ctrl Y；macOS ⌘Z · ⇧⌘Z')}
    <div style="display: flex; gap: 12px; align-items: flex-start; margin-bottom: 10px">
      <div>
        ${sub('空白处右键（其余项见画布交互）')}
        ${menu(`
          ${menuItem(ic('undo', 16), '撤销 移动 3 个节点', 'Ctrl Z', `background: ${T.s5}`)}
          ${menuItem(redoIcon(16), '重做 新建 图像配置', 'Ctrl Y')}
          ${menuSep}
          ${menuItem(ic('nodeLibrary', 16), '新建…', 'Tab')}
          ${menuItem('', '粘贴', 'Ctrl V')}
        `, 236)}
      </div>
      <div>
        ${sub('栈空时')}
        ${menu(`
          ${menuItem(ic('undo', 16), '撤销', 'Ctrl Z', '', true)}
          ${menuItem(redoIcon(16), '重做', 'Ctrl Y', '', true)}
        `, 132)}
        <div style="font-size: 10px; color: ${T.fg5}; line-height: 1.6; margin-top: 8px">置灰不隐藏；⌘K 动作组同名</div>
      </div>
    </div>
    <div style="margin-bottom: 10px">${capsule(ic('undo', 14), '已撤销 · 移动 3 个节点', kbd('重做 Ctrl Y', T.fg4))}</div>
    ${rules([
      '名字 =「撤销 / 重做」+ 这一步；菜单、⌘K、按钮提示共用一份',
      '重做的主键：Windows Ctrl Y、macOS ⇧⌘Z；右键菜单、菜单栏「编辑」、⌘K、快捷键页都显示这一个',
      '文本框有焦点时 Ctrl Z 归文本框；离开后这段修改在画布栈里算一步',
      '撤销后选中受影响的节点，不在视口里就平移过去，缩放不变',
      '反馈只走画布底部胶囊；每个画布一个栈，最多 100 步，重启清空；有新操作就清空重做栈',
    ])}
  </div>`;

// ================= 撤销 / 重做：进栈清单 =================
const stackRow = (op, label) => `
  <div style="display: flex; align-items: center; gap: 12px; height: 21px; border-bottom: 1px solid ${T.bSubtle}">
    <div style="flex: 1; min-width: 0; color: ${T.fg3}; font-size: 11px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${op}</div>
    <div style="flex: none; font-size: 11px; color: ${T.accent}; white-space: nowrap">${label}</div>
  </div>`;
const offChip = (t) => `<div style="height: 20px; padding: 0 7px; border-radius: 3px; border: 1px solid ${T.outline}; background: ${T.s3}; color: ${T.fg5}; font-size: 10px; display: flex; align-items: center; white-space: nowrap">${t}</div>`;
const stackCol = `
  <div>
    ${h3('什么进栈', '一次用户编辑 = 一步；系统和任务做的不算')}
    <div style="display: flex; justify-content: space-between; font-size: 10px; color: ${T.fg6}; height: 16px"><span>操作</span><span>菜单里的名字</span></div>
    ${stackRow('新建节点（含新建菜单里建好并连线）', '新建 视频配置并连线')}
    ${stackRow('删除节点，连带它的线', '删除 3 个节点')}
    ${stackRow('拖动松手，多选一起算一步', '移动 3 个节点')}
    ${stackRow('加入 / 移出泳道', '移入泳道「水墨」')}
    ${stackRow('连线 / 删线 / 改语义', '连线 首帧 · 改为 参考')}
    ${stackRow('改参数 / 改名 / 改文本正文 / 挂摘角色', '修改 比例 · 重命名')}
    ${stackRow('设为当前（含批量 slot），连同它改写的线', '设为当前 · take 3')}
    ${stackRow('泳道新建 / 改名 / 改风格 / 排序', '修改泳道「水墨」风格')}
    ${stackRow('解散（节点留下）', '解散泳道「水墨」')}
    ${stackRow('删除泳道和内容', '删除泳道「水墨」和 4 个节点')}
    ${stackRow('粘贴 / 剪切 / 复制一份 / 导入剧本 / 导入媒体', '粘贴 4 个节点')}
    <div style="font-size: 10px; color: ${T.fg6}; margin: 10px 0 6px">不进栈</div>
    <div style="display: flex; flex-wrap: wrap; gap: 4px; margin-bottom: 10px">
      ${['选中', '视口与缩放', '工具态', '侧栏 / 检查器页签', '泳道折叠', '提交生成 / 取消 / 重跑 slot', '任务建的产物节点', '自动保存时机', '角色库 / 画廊 / 导出', '项目与画布增删（回收站）'].map(offChip).join('')}
    </div>
    ${rules([
      '改成首帧 / 尾帧会把同节点原来那条降成参考（同一事务），撤销两条一起回',
      '「设为当前」和它改写的 data 边是一步；系统自动改写的边不进栈，所以反向找边一律按两端（下游节点 + 端口 + 上游所属配置节点），不按边 id',
      '撤销失败整步回滚、留在栈顶；要撤的对象已不在（如任务失败清掉的占位产物）就丢掉这一步，提示「这一步已无法撤销」，不连带撤下一步',
    ])}
  </div>`;

// ================= 剪贴板：复制 / 粘贴 =================
const lineage = (x1, x2, y) => `<path d="M${x1} ${y}H${x2}" fill="none" stroke="${T.fg6}" stroke-width="1.25" stroke-dasharray="1.5 3.5" stroke-linecap="round"></path>`;
const cursor = (x, y) => `<svg width="14" height="18" viewBox="0 0 14 18" aria-hidden="true" style="position: absolute; left: ${x}px; top: ${y}px"><path d="M1 1v14l4-3.5 2.6 5.5 2.2-1-2.6-5.4H13z" fill="${T.fg1}" stroke="${T.s0}" stroke-width="1" stroke-linejoin="round"></path></svg>`;
const CFG_TXT = '拂晓雾江，渔夫站在船头收网，远景缓推到中景';
const copyCol = `
  <div>
    ${h3('复制 / 粘贴节点', 'Ctrl C · Ctrl X · Ctrl V')}
    <div style="position: relative; width: 380px; height: 222px; margin-bottom: 8px">
      <div style="position: absolute; left: 130px; top: 0; font-size: 10px; color: ${T.accent}">选中 2 个 · Ctrl C</div>
      <div style="position: absolute; left: 128px; top: 16px; width: 250px; height: 100px; box-sizing: border-box; border: 1px dashed ${T.accent}; border-radius: 6px"></div>
      <svg width="380" height="222" viewBox="0 0 380 222" aria-hidden="true" style="position: absolute; left: 0; top: 0">
        <path d="M104 69H138" fill="none" stroke="${T.sky}" stroke-width="1.5" stroke-dasharray="5 4" opacity=".45"></path>
        ${lineage(242, 268, 69)}
        ${lineage(242, 268, 179)}
      </svg>
      ${card({ x: 0, y: 24, title: '远山参考', type: '图像', box: imgBox(IMG.thumbWide), status: '选区外', dim: true })}
      ${card({ x: 138, y: 24, title: '镜头 01', type: '图像配置', box: textBox(CFG_TXT), status: '已生成 1 张' })}
      ${card({ x: 268, y: 24, title: '成片', type: '图像', box: imgBox(IMG.thumbMountain), status: '成片' })}
      <div style="position: absolute; left: 0; top: 142px; width: 120px; font-size: 10px; line-height: 1.6; color: ${T.fg5}">选区外的参考线不跟着走；内部的线和溯源换新 id</div>
      ${card({ x: 138, y: 134, title: '镜头 01', type: '图像配置', box: textBox(CFG_TXT), status: '新 id · 未生成', sel: true })}
      ${card({ x: 268, y: 134, title: '成片', type: '图像', box: imgBox(IMG.thumbMountain), status: '同一个文件', sel: true })}
      ${cursor(250, 172)}
    </div>
    ${rules([
      '带上两端都在选区里的线；产出线由 source_node_id 推导，跟着换成新 id',
      'Ctrl X = 复制 + 删除；粘贴出的节点成为选中；两者各算一步',
      '不复制批量 slot 和任务记录，产物只带当前主图（image_url / video_url / thumbnail_url）',
    ])}
  </div>`;

// ================= 剪贴板：落点与跨界 =================
const posRow = (cond, where) => `
  <div style="display: flex; gap: 12px; padding: 3px 0; border-bottom: 1px solid ${T.bSubtle}; font-size: 11px; line-height: 1.5">
    <div style="width: 148px; flex: none; color: ${T.fg3}">${cond}</div><div style="flex: 1; min-width: 0; color: ${T.fg4}">${where}</div>
  </div>`;
const cell = (t, span = 1, color = T.fg4) => `<div style="grid-column: span ${span}; padding: 3px 6px; background: ${T.s3}; color: ${color}; font-size: 11px; line-height: 1.45">${t}</div>`;
const head = (t) => `<div style="padding: 3px 6px; color: ${T.fg5}; font-size: 10px">${t}</div>`;
const pasteCol = `
  <div>
    ${h3('粘贴到哪 · 带什么', '')}
    ${posRow('指针在画布上', '选区包围盒的中心对准指针')}
    ${posRow('右键「粘贴」', '右键按下的那一点（与新建菜单同一锚点）')}
    ${posRow('指针不在画布 · 同画布', '原位置右下偏 lg，连按每次再偏一格')}
    ${posRow('指针不在画布 · 别的画布', '视口中心')}
    <div style="height: 10px"></div>
    <div style="display: grid; grid-template-columns: 60px repeat(3, minmax(0, 1fr)); gap: 2px">
      ${head('')}${head('同画布')}${head('同项目别的画布')}${head('别的项目')}
      ${cell('媒体文件', 1, T.fg3)}${cell('引用同一个文件')}${cell('复制一份', 1, T.accent)}${cell('复制一份', 1, T.accent)}
      ${cell('溯源', 1, T.fg3)}${cell('选区内换新 id；选区外断开（需要你定 4）', 3)}
      ${cell('角色引用', 1, T.fg3)}${cell('保留')}${cell('保留')}${cell('挂载和 @ 记号都去掉，胶囊提示')}
      ${cell('泳道', 1, T.fg3)}${cell('按落点重新判（resolveLaneDrop），不带原泳道 id', 3)}
      ${cell('参数', 1, T.fg3)}${cell('提示词 / provider / 比例 / seed 原样', 3)}
    </div>
    <div style="height: 10px"></div>
    ${rules([
      '媒体路径相对画布目录，resolve 不许越出画布根，所以跨画布要复制：复制件进目标画布 canvases/&lt;id&gt;/imports/',
      '先复制文件再写库，失败删掉复制件、零残留（同项目包导入）；同画布共用一个文件安全：引用按路径计，回收器只读',
    ])}
  </div>`;

// ================= 撤销卡 =================
const toastStatic = `
  <div style="position: relative; width: 360px; box-sizing: border-box; display: flex; gap: 12px; padding: 12px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.45), 0 2px 6px rgba(0,0,0,0.35); overflow: hidden">
    <div style="width: 40px; height: 40px; flex: none; border-radius: 4px; background: ${T.s5}; display: flex; align-items: center; justify-content: center; color: ${T.fg3}">${ic('undo', 20)}</div>
    <div style="flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px">
      <div style="font-size: 12px; font-weight: 500; line-height: 1.45; color: ${T.fg1}">已删除 3 个节点</div>
      <div style="font-size: 11px; line-height: 1.45; color: ${T.fg4}">卡片收起后按 Ctrl Z 仍可撤销</div>
      <div style="display: flex; justify-content: flex-end; margin-top: 4px">
        <button class="amber" type="button" style="height: 24px; padding: 0 10px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 11px; font-weight: 500">撤销</button>
      </div>
    </div>
    <div style="position: absolute; left: 0; bottom: 0; height: 2px; width: 58%; background: ${T.controlStrong}"></div>
  </div>`;
const timeline = `
  <div style="width: 360px; margin: 10px 0 8px">
    <div style="display: flex; height: 6px; border-radius: 3px; overflow: hidden">
      <div style="width: 40%; background: ${T.accent}"></div>
      <div style="flex: 1; background: repeating-linear-gradient(90deg, ${T.controlStrong} 0 6px, transparent 6px 10px)"></div>
    </div>
    <div style="display: flex; justify-content: space-between; font-size: 10px; color: ${T.fg5}; margin-top: 4px">
      <span>卡片停 8 秒（悬停暂停）</span><span>卡片收起，栈里这一步还在</span>
    </div>
  </div>`;
const toastCol = `
  <div>
    ${h3('和撤销卡的关系', '卡片是提醒，栈才是本体')}
    ${toastStatic}
    ${timeline}
    ${rules([
      '删除节点 / 解散泳道 / 删除泳道和内容 / 剪切 / 拖动换道（resolveCardDrop 已弹的那张）：进栈之外再弹卡；卡上「撤销」撤卡上这一步',
      '「解散（节点留下）」不确认：清掉道内节点的 lane_id、位置不动，直接解散 + 卡',
      '「删除泳道和内容」：一个事务软删道和道内节点；道内有生成中任务先确认，否则直接删 + 卡。和解散是两个动作、两步',
      '关闭画布 / 项目：丢掉它的栈并收起它的卡——现在卡还能点，restore 却什么也不做',
    ])}
  </div>`;

// ================= 系统剪贴板 =================
const sysCol = `
  <div>
    ${h3('系统剪贴板', '从别的软件贴进来')}
    <div style="position: relative; width: 380px; height: 120px; margin-bottom: 8px">
      <div style="position: absolute; left: 0; top: 0; font-size: 10px; color: ${T.fg5}">剪贴板是图片</div>
      <div style="position: absolute; left: 196px; top: 0; font-size: 10px; color: ${T.fg5}">剪贴板是文字</div>
      ${card({ x: 0, y: 16, w: 170, bh: 68, title: '剪贴板图像', type: '图像', box: imgBox(IMG.wide), status: '粘贴 · 未入链', sel: true })}
      ${card({ x: 196, y: 16, w: 170, bh: 68, title: '文本', type: '文本', box: textBox('第三场。夜，江边客栈。灯笼在风里晃，老板娘端着一碗面推门出来。', 10, 3), status: '可连到配置当提示词', sel: true })}
    </div>
    ${rules([
      '图片 → 图像产物节点，无源配置，文件写进本画布 canvases/&lt;id&gt;/imports/，与导入媒体同一条路',
      '文字 → 文本节点（typeConfig.text）；若是本应用复制出去的节点（文字指纹对得上）→ 按节点粘贴',
      '复制节点时往系统剪贴板写一份纯文字（标签 + 提示词）',
      `${code('Ctrl D')} 不变：只复制配置节点，不带线和产物，不碰剪贴板`,
    ])}
  </div>`;

// ================= 右栏：需要你定 + 底座 =================
const q = (title, opts, rec) => `
  <div>
    <div style="font-size: 12px; font-weight: 500; color: ${T.fg1}; line-height: 1.5; margin-bottom: 4px">${title}</div>
    <div style="font-size: 11px; color: ${T.fg3}; line-height: 1.6">${opts.map((o, i) => `<div><span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}">${'ABC'[i]}</span> ${o}</div>`).join('')}</div>
    <div style="font-size: 11px; color: ${T.accent}; line-height: 1.6; margin-top: 4px">建议 ${rec}</div>
  </div>`;
const decide = `
  <div style="background: ${T.wash}; border: 1px solid ${T.washBorder}; border-radius: 6px; padding: 14px 16px; display: flex; flex-direction: column; gap: 14px">
    <div style="font-weight: 500; color: ${T.fg1}">需要你定</div>
    ${q('1 · 删了之后又做了别的，再点卡上「撤销」', ['只撤删除这一步，从栈里抽掉', '一路撤到删除为止', '不在栈顶就让按钮失效'], 'A：卡上写哪步撤哪步；删除的复原彼此独立')}
    ${q('2 · 撤销「新建」时这个节点正在生成', ['照删，任务跑完，产物落成未入链结果', '拒绝撤销，提示先取消任务', '顺手取消任务'], 'A，胶囊补一句「任务仍在运行」；花钱的任务不该被 Ctrl Z 默默取消')}
    ${q('3 · 撤销批量 slot 的「设为当前」回到哪（进栈已定）', ['全回：原主图、原 promoted slot、原当前 take 和改写过的线', '只回「当前」标记，slot 的主图留下'], 'A：点 slot 时 promote 和设为当前是同一事务，撤销也一起回；反向令牌记旧 image_url、旧 promoted slot、旧 pinned_result_id')}
    ${q('4 · 粘贴产物，但源配置没一起复制', ['断开溯源，成为未入链的独立图', '同画布时仍挂原配置，多算一个 take'], 'A：跨画布只能断开，统一口径，也不悄悄改原配置的 take 号')}
    ${q('5 · 粘贴一大段分段文字', ['一个文本节点，胶囊给「按剧本拆镜…」', '直接打开剧本导入并预填', '每段一个文本节点'], 'A：Ctrl V 不该突然弹对话框')}
  </div>`;
const infra = `
  <div style="background: ${T.s1}; border: 1px solid ${T.outline}; border-radius: 6px; padding: 14px 16px">
    <div style="font-weight: 500; color: ${T.fg1}; margin-bottom: 4px">要补的底座</div>
    <div style="font-size: 11px; color: ${T.fg5}; line-height: 1.6; margin-bottom: 8px">现在只有删节点 / 删连线能撤，靠撤销卡的回调，没有栈</div>
    ${rules([
      `${code('CanvasHistoryController(canvasId)')}：keepAlive，undo / redo 列表，深度 100`,
      `${code('CanvasCommand')}：名字 + 受影响节点 + apply / revert，只持快照；多步合一条、一个 UnitOfWork`,
      `反向令牌：已有 NodeDeletion、removeEdge；补 addNode、moveNode、updateRole（含降级那条）、泳道改 / 解散 / 删除、设为当前（旧当前 + 被挪的边）`,
      `改参数记旧值；旧值不存在要能删键 → ${code('removeTypeConfigKeys')}`,
      `撤销前冲掉检查器 500ms 防抖 patch；多选删除并成一个 removeNodes 事务`,
      `Undo / Redo 进 kCanvasShortcuts（快捷键页自动收录）；app 级 ${code('canvasClipboardProvider')}；读剪贴板图片的依赖见「导入与查找」需要你定 1，与拖入共用一套`,
      `粘贴改写 id（同 import_remapper / 模板插入）：${code('pinned_result_id')}、${code('gen_inputs')} 里的源节点 id 选区内换新、选区外剥掉；跨项目再把提示词里的 ${code('@{角色 id}')} 换成角色名纯文字`,
    ])}
  </div>`;

const divider = `<div style="height: 1px; background: ${T.control}"></div>`;
const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="position: absolute; left: 32px; top: 24px; display: flex; align-items: baseline; gap: 14px">
    <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">撤销 / 重做与剪贴板</div>
    <div style="color: ${T.fg4}">画布上每一次编辑都能 Ctrl Z；节点能复制、剪切、粘贴，跨画布和项目也行</div>
  </div>
  <div style="position: absolute; left: 32px; top: 64px; width: 824px; display: flex; flex-direction: column; gap: 16px">
    <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 32px">${entryCol}${stackCol}</div>
    ${divider}
    <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 32px">${copyCol}${pasteCol}</div>
    ${divider}
    <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 32px">${toastCol}${sysCol}</div>
  </div>
  <div style="position: absolute; left: 888px; right: 32px; top: 64px; display: flex; flex-direction: column; gap: 16px">
    ${decide}
    ${infra}
  </div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'UndoClipboard.dc.html', html: page('撤销与剪贴板', W, H, body, logic) };
