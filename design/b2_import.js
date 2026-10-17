// 第二批画板：导入、拖放与查找（1280×1300，静态）
// 导入媒体 / 系统文件拖入 / 粘贴图片；左栏素材与角色拖进画布；提示词 @ 补全；画布内查找；小地图与回到内容；工具锁与便签。
// 修订：导入落盘统一 canvases/<id>/imports/（矛盾 8）；本板拥有拖放 / 剪贴板依赖决定（需定 1，矛盾 9）；
// 同画布素材 = 同画布粘贴（矛盾 10）；@{角色 id} 在导入 / 模板 / 跨项目粘贴时重映射（矛盾 18）；
// 文本 / 便签的双击编辑与 fix/demo-inspectors 的检查器正文框写同一个 type_config.text。
const { T, IMG, SANS, MONO, page, ic } = require('./common.js');

const W = 1280, H = 1300;
const COL = 384, MOCK_H = 152;
const code = (t) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${t}</span>`;

const h3 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 8px; margin-bottom: 8px"><div style="font-weight: 500; color: ${T.fg1}">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const kbd = (k) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}">${k}</span>`;
const menuSep = `<div style="height: 1px; background: ${T.bStrong}; margin: 4px 0"></div>`;
const menu = (inner, width = 240) => `<div style="width: ${width}px; box-sizing: border-box; padding: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6)">${inner}</div>`;
const mention = (name, gone = false) => `<span style="display: inline-flex; align-items: center; gap: 4px; height: 18px; padding: 0 6px 0 3px; margin: 0 2px; border-radius: 9px; background: ${gone ? T.s5 : T.wash}; border: 1px solid ${gone ? T.control : T.washBorder}; color: ${gone ? T.fg5 : T.accent}; font-size: 11px; vertical-align: 1px"><img src="${IMG.thumbMountain}" alt="" style="width: 12px; height: 12px; border-radius: 6px; object-fit: cover; ${gone ? 'filter: grayscale(1); opacity: .5' : ''}">${name}</span>`;
const rules = (lines) => `<div style="font-size: 11px; color: ${T.fg4}; line-height: 1.5; margin-top: 8px">${lines.map((l) => `<div style="display: flex; gap: 6px"><span style="color: ${T.fg6}; flex: none">·</span><span>${l}</span></div>`).join('')}</div>`;
const need = (t) => `<span style="color: ${T.accent}">需要：</span>${t}`;
const hl = (t) => `<span style="background: ${T.wash}; color: ${T.accent}; border-radius: 2px; padding: 0 1px">${t}</span>`;
const grid = (w, h, extra = '') => `position: relative; width: ${w}px; height: ${h}px; box-sizing: border-box; border-radius: 4px; border: 1px solid ${T.outline}; background-color: ${T.s1}; background-image: linear-gradient(${T.grid} 1px, transparent 1px), linear-gradient(90deg, ${T.grid} 1px, transparent 1px); background-size: 16px 16px; overflow: hidden; ${extra}`;

// 缩小的节点卡（与 main.js 同构：标题行 + 16:9 图区 + 状态行）
const card = ({ x, y, w = 150, title, type = '', box, status = '', outline = `1px solid ${T.outline}`, extra = '', fs = 10 }) => `
  <div style="position: absolute; left: ${x}px; top: ${y}px; width: ${w}px; ${extra}">
    <div style="height: 16px; display: flex; align-items: center; gap: 6px; font-size: ${fs}px"><div style="font-weight: 500; color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">${title}</div><div style="flex: 1"></div><div style="font-size: ${fs - 1}px; color: ${T.fg5}; flex: none">${type}</div></div>
    <div style="position: relative; width: ${w}px; height: ${Math.round(w * 9 / 16)}px; border-radius: 3px; background: ${T.thumb}; outline: ${outline}; overflow: hidden">${box}</div>
    <div style="height: 18px; display: flex; align-items: center; gap: 5px; font-size: 9px; color: ${T.fg5}; white-space: nowrap">${status}</div>
  </div>`;
const importBadge = `<div style="position: absolute; left: 4px; top: 4px; height: 16px; padding: 0 5px; border-radius: 3px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; color: ${T.fg3}; font-size: 9px; display: flex; align-items: center; gap: 3px">${ic('upload', 10)}<span>导入</span></div>`;
const promptPreview = (html) => `<div style="position: absolute; inset: 0; padding: 6px 8px; font-size: 9px; line-height: 1.55; color: ${T.fg2}; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden">${html}</div>`;

// ---------- A：导入媒体 ----------
const mockA = `
  <div style="${grid(COL, MOCK_H)}">
    <div style="position: absolute; left: 10px; top: 10px; width: 170px; height: 138px; box-sizing: border-box; border: 1.5px dashed ${T.accent}; border-radius: 6px; background: ${T.wash}; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; color: ${T.accent}">
      ${ic('upload', 20)}
      <div style="font-weight: 500">松手导入 3 个文件</div>
      <div style="font-size: 10px; color: ${T.fg4}">图片 2 · 视频 1 · 落在松手处</div>
    </div>
    ${card({ x: 196, y: 12, w: 84, title: '雾江.jpg', box: `<img src="${IMG.wide}" alt="" style="width: 100%; height: 100%; object-fit: cover">${importBadge}`, status: '<span>导入 · 1920×1080</span>' })}
    ${card({ x: 290, y: 12, w: 84, title: '船桨.mp4', box: `<img src="${IMG.mountain}" alt="" style="width: 100%; height: 100%; object-fit: cover; opacity: .3"><div style="position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; gap: 4px; color: ${T.accent}"><div class="spin" style="display: flex">${ic('progress', 12)}</div><span style="font-family: ${MONO}; font-size: 9px">48%</span></div><div style="position: absolute; left: 0; bottom: 0; height: 2px; width: 48%; background: ${T.accent}"></div>`, status: `<span style="color: ${T.accent}">复制中</span>` })}
    <div style="position: absolute; left: 196px; top: 96px; width: 178px; box-sizing: border-box; padding: 8px 10px; border-radius: 6px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; display: flex; gap: 8px; align-items: flex-start">
      <div style="color: ${T.success}; display: flex; flex: none">${ic('success', 14)}</div>
      <div style="flex: 1; min-width: 0"><div style="font-size: 10px; color: ${T.fg1}">已导入 2 个文件</div><div style="font-size: 9px; color: ${T.fg5}">跳过 1 个：notes.pdf 不是图片或视频</div></div>
      <div style="font-size: 10px; color: ${T.accent}; flex: none">撤销</div>
    </div>
  </div>`;
const colA = `
  <div>
    ${h3('导入媒体', 'Ctrl U · 拖入文件 · Ctrl V 粘贴图片')}
    ${mockA}
    ${rules([
      'Ctrl/⌘ U 或右键「导入媒体…」：可多选；图片 png / jpg / webp，视频 mp4 / mov / webm',
      `复制进 ${code('canvases/&lt;id&gt;/imports/')}（file_resolver 不许越出画布根）；导入、拖入、粘贴图片、跨画布素材都落这里`,
      '建产物节点（无来源配置），type_config 记相对路径 + origin: import + 原文件名',
      '复制中节点为 uploading（库里已有这档）；视频随后抽首帧、探时长写 duration_ms',
      '落点：快捷键在视口中心散布，拖入 / 粘贴图片在松手处；一次一张通知带撤销，不支持的点名跳过',
      need('拖入要 desktop_drop，读剪贴板图片要 pasteboard（需定 1，全部画板的粘贴 / 拖放以此为准）'),
    ])}
  </div>`;

// ---------- B：从左栏拖进画布 ----------
const dot = (c) => `<div style="width: 8px; height: 8px; border-radius: 4px; background: ${c}; flex: none"></div>`;
const dropItem = (color, label, sub = '', on = false, off = false) => `
  <div style="min-height: 26px; display: flex; align-items: center; gap: 8px; padding: 3px 8px; box-sizing: border-box; border-radius: 3px; ${on ? `background: ${T.s5};` : ''} ${off ? 'opacity: .45;' : ''}">
    ${dot(color)}<div style="flex: 1; min-width: 0"><div style="font-size: 11px; color: ${T.fg2}">${label}</div>${sub ? `<div style="font-size: 9px; color: ${T.fg5}">${sub}</div>` : ''}</div>
  </div>`;
const mockB = `
  <div style="${grid(COL, MOCK_H)}">
    <div style="position: absolute; left: 0; top: 0; bottom: 0; width: 104px; background: ${T.s4}; border-right: 1px solid ${T.bStrong}">
      <div style="height: 22px; display: flex; align-items: center; padding: 0 8px; font-size: 10px; font-weight: 500; color: ${T.fg1}">素材</div>
      <img src="${IMG.wide}" alt="" style="display: block; margin: 2px 7px 0; width: 90px; height: 50px; object-fit: cover; border-radius: 3px; outline: 1px dashed ${T.control}; opacity: .35">
      <div style="font-size: 9px; color: ${T.fg6}; padding: 3px 8px 0">远山参考</div>
      <div style="height: 1px; background: ${T.bSubtle}; margin: 8px 0 0"></div>
      <div style="height: 22px; display: flex; align-items: center; padding: 0 8px; font-size: 10px; font-weight: 500; color: ${T.fg1}">角色</div>
      <div style="height: 28px; display: flex; align-items: center; gap: 6px; padding: 0 8px">
        <img src="${IMG.thumbMountain}" alt="" style="width: 20px; height: 20px; border-radius: 10px; object-fit: cover">
        <div style="flex: 1; min-width: 0"><div style="font-size: 10px; color: ${T.fg2}">渔夫</div><div style="font-size: 9px; color: ${T.fg6}">3 张 · 2 处</div></div>
      </div>
    </div>
    ${card({ x: 114, y: 14, w: 116, title: '镜头 02 · 江上孤舟', type: '视频', box: promptPreview('江面雾气渐散，渔夫撑船缓缓驶出画面，镜头缓推。'), status: '<span>万相 2.2 · 已有首帧</span>', outline: `1.5px dashed ${T.accent}` })}
    <img src="${IMG.wide}" alt="" style="position: absolute; left: 186px; top: 54px; width: 60px; height: 34px; object-fit: cover; border-radius: 3px; outline: 1px solid ${T.accent}; box-shadow: 0 8px 20px rgba(0,0,0,0.6); opacity: .9">
    <div style="position: absolute; left: 236px; top: 30px">
      ${menu(`
        <div style="height: 20px; display: flex; align-items: center; padding: 0 8px; font-size: 9px; color: ${T.fg5}">放到「镜头 02」</div>
        ${dropItem(T.sky, '当参考', '', true)}
        ${dropItem(T.teal, '替换首帧')}
        ${dropItem(T.peach, '当尾帧', '万相 2.2 不支持尾帧', false, true)}
      `, 140)}
    </div>
  </div>`;
const colB = `
  <div>
    ${h3('从左栏拖进画布', '素材格、角色行都能拖')}
    ${mockB}
    ${rules([
      '素材拖到空白处：建导入式产物节点；同画布 = 同画布粘贴（新节点指向同一文件，不复制），跨画布先复制进本画布 imports/（需定 2）',
      '拖到配置节点：松手弹菜单，只列合法项：参考恒有，首 / 尾帧看 provider 能力位，不支持的置灰写原因',
      '已有首帧时写「替换首帧」，一次撤销复原；视频素材没有合法项，按落空白处理',
      '角色行拖到图像 / 视频配置：直接追加进 character_ids，超配额按 ref_image_budget 点名',
      need('左栏包 Draggable、舞台加 DragTarget，不用新依赖'),
    ])}
  </div>`;

// ---------- C：@ 补全 ----------
const pickRow = (img, name, meta, on = false, tag = '') => `
  <div style="height: 30px; display: flex; align-items: center; gap: 8px; padding: 0 8px; border-radius: 3px; ${on ? `background: ${T.s5}` : ''}">
    <img src="${img}" alt="" style="width: 20px; height: 20px; border-radius: 10px; object-fit: cover">
    <div style="flex: 1; min-width: 0"><div style="font-size: 11px; color: ${T.fg1}">${name}</div><div style="font-size: 9px; color: ${T.fg5}">${meta}</div></div>
    ${tag ? `<div style="height: 16px; padding: 0 5px; border-radius: 8px; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 9px; display: flex; align-items: center">${tag}</div>` : ''}
  </div>`;
const mockC = `
  <div style="${grid(COL, MOCK_H)}">
    <div style="position: absolute; left: 134px; top: 2px">
      ${menu(`
        ${pickRow(IMG.thumbMountain, `${hl('渔')}夫`, '3 张参考图', true, '已挂载')}
        ${pickRow(IMG.thumbWide, `老${hl('渔')}翁`, '1 张参考图')}
        ${menuSep}
        <div style="height: 26px; display: flex; align-items: center; gap: 8px; padding: 0 8px; color: ${T.fg3}; font-size: 11px"><div style="color: ${T.fg4}; display: flex">${ic('characters', 14)}</div><div style="flex: 1">从图片新建角色…</div></div>
      `, 200)}
    </div>
    <div style="position: absolute; left: 10px; right: 10px; bottom: 6px; height: 38px; box-sizing: border-box; padding: 0 6px 0 12px; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 6px; display: flex; align-items: center; gap: 8px">
      <div style="flex: 1; min-width: 0; font-size: 12px; color: ${T.fg1}; white-space: nowrap; overflow: hidden">拂晓，雾江上一叶孤舟，<span style="color: ${T.accent}">@渔</span><span style="display: inline-block; width: 1px; height: 14px; background: ${T.fg1}; vertical-align: -2px"></span></div>
      <div style="height: 24px; padding: 0 10px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-weight: 500; font-size: 11px; display: flex; align-items: center; gap: 5px; flex: none">${ic('run', 12)}<span>生成</span></div>
    </div>
  </div>`;
const colC = `
  <div>
    ${h3('提示词里 @角色', '提示词条和检查器的提示词框都有')}
    ${mockC}
    ${rules([
      `插入后：雾江上一叶孤舟，${mention('渔夫')} 站在船头`,
      '输入 @ 弹出，打字筛选；↑↓ 选，↵ / Tab 插入，Esc 收起；已挂载的排前面',
      `文字里存记号 ${code('@{角色 id}')}，插入同时追加进 character_ids；退格整块删，不卸载（需定 3）`,
      '发出时记号换成角色名，描述照旧按 character_ids 顺序注入',
      `角色被删：标签变灰 ${mention('渔夫', true)}，发出时去掉`,
      `项目包导入、模板插入、跨项目粘贴都改写记号：能映射的与 character_ids 走同一张角色表换新 id（项目包导入即 ${code('import_remapper')} 的 characterMap）`,
      '角色没跟过来的（跨项目粘贴、模板没带该角色）：记号降成纯文字「@名字」，同时从 character_ids 剔除；名字取不到就删掉记号',
    ])}
  </div>`;

// ---------- D：画布内查找 ----------
const findBtn = (label, t) => `<button class="hov" type="button" aria-label="${label}" style="width: 24px; height: 24px; border-radius: 3px; display: flex; align-items: center; justify-content: center; color: ${T.fg3}; font-family: ${MONO}; font-size: 12px">${t}</button>`;
const mockD = `
  <div style="${grid(COL, MOCK_H)}">
    <div style="position: absolute; left: 42px; top: 8px; width: 300px; height: 34px; box-sizing: border-box; padding: 0 4px 0 10px; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 6px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); display: flex; align-items: center; gap: 6px">
      <div style="color: ${T.fg5}; display: flex">${ic('search', 14)}</div>
      <div style="flex: 1; font-size: 12px; color: ${T.fg1}">雾江<span style="display: inline-block; width: 1px; height: 13px; background: ${T.fg1}; vertical-align: -2px; margin-left: 1px"></span></div>
      <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg4}">2 / 3</div>
      <div style="width: 1px; height: 18px; background: ${T.control}"></div>
      ${findBtn('上一个（Shift ↵）', '↑')}${findBtn('下一个（↵）', '↓')}
      <button class="hov" type="button" aria-label="关闭查找（Esc）" style="width: 24px; height: 24px; border-radius: 3px; display: flex; align-items: center; justify-content: center; color: ${T.fg4}">${ic('close', 14)}</button>
    </div>
    ${card({ x: 10, y: 52, w: 112, title: '镜头 01 · 拂晓', type: '图像', box: promptPreview(`拂晓，${hl('雾江')}上一叶孤舟，渔夫站在船头收网。`), status: '<span>命中 · 提示词</span>', outline: `1px solid ${T.washBorder}` })}
    ${card({ x: 136, y: 52, w: 112, title: `${hl('雾江')}.jpg`, type: '导入', box: `<img src="${IMG.wide}" alt="" style="width: 100%; height: 100%; object-fit: cover">`, status: `<span style="color: ${T.accent}">当前 · 文件名</span>`, outline: `2px solid ${T.accent}` })}
    ${card({ x: 262, y: 52, w: 112, title: '镜头 03 · 远山', type: '视频', box: promptPreview('远山一层层浮出来，光线偏冷。'), status: '<span>未命中</span>', extra: 'opacity: .35' })}
  </div>`;
const colD = `
  <div>
    ${h3('画布内查找', 'Ctrl/⌘ F，和 Ctrl K 分开')}
    ${mockD}
    ${rules([
      'Ctrl/⌘ F 打开，浮在工具条下方居中；正在编辑文字时也接管',
      '搜本画布已加载的图像 / 视频配置、镜头、文本、便签、产物：标题、提示词、文本 / 便签正文、shot_notes、导入文件名；不读库',
      '↵ 下一个、Shift ↵ 上一个，循环；每跳一个单选它，保持缩放移到视口中心',
      '命中淡琥珀描边、当前实色，其余降到 35%；Esc 关闭，选中留在当前',
      '分工：Ctrl K 跨实体、选一个就关；Ctrl F 只看本画布、开着逐个过',
    ])}
  </div>`;

// ---------- E：小地图与回到内容 ----------
const zcell = (inner, w = 26, extra = '') => `<div style="width: ${w}px; height: 26px; display: flex; align-items: center; justify-content: center; ${extra}">${inner}</div>`;
const mockE = `
  <div style="${grid(COL, MOCK_H)}">
    <div style="position: absolute; left: 50%; top: 10px; transform: translateX(-50%); height: 28px; padding: 0 12px; border-radius: 14px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; box-shadow: 0 10px 30px rgba(0,0,0,0.5); display: flex; align-items: center; gap: 6px; color: ${T.fg2}; font-size: 11px">${ic('fit', 14)}<span>回到内容</span>${kbd('Shift 1')}</div>
    <div style="position: absolute; left: 10px; bottom: 46px; width: 160px; height: 64px; box-sizing: border-box; border-radius: 6px; background: ${T.s3}; border: 1px solid ${T.control}; overflow: hidden">
      <div style="position: absolute; left: 0; right: 0; top: 10px; height: 26px; background: ${T.s5}"></div>
      <div style="position: absolute; left: 12px; top: 15px; width: 18px; height: 14px; border-radius: 2px; background: ${T.fg5}"></div>
      <div style="position: absolute; left: 36px; top: 15px; width: 18px; height: 14px; border-radius: 2px; background: ${T.fg4}"></div>
      <div style="position: absolute; left: 60px; top: 15px; width: 18px; height: 14px; border-radius: 2px; background: ${T.fg5}"></div>
      <div style="position: absolute; left: 24px; top: 38px; width: 18px; height: 14px; border-radius: 2px; background: ${T.fg6}"></div>
      <div style="position: absolute; left: 98px; top: 30px; width: 52px; height: 28px; box-sizing: border-box; border: 1.5px solid ${T.accent}; border-radius: 2px; background: ${T.wash}"></div>
    </div>
    <div style="position: absolute; left: 10px; bottom: 10px; width: 160px; box-sizing: border-box; display: flex; align-items: center; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 6px; color: ${T.fg3}">
      ${zcell(ic('zoomOut', 14))}${zcell(`<span style="font-family: ${MONO}; font-size: 10px">80%</span>`, 36)}${zcell(ic('zoomIn', 14))}${zcell('<span style="font-size: 10px">适应</span>', 36, `border-left: 1px solid ${T.control}`)}${zcell(ic('minimap', 14), 34, `border-left: 1px solid ${T.control}; background: ${T.wash}; color: ${T.accent}`)}
    </div>
    <div style="position: absolute; right: 14px; bottom: 14px; font-size: 10px; color: ${T.fg6}">视口里一个节点都没有</div>
  </div>`;
const colE = `
  <div>
    ${h3('小地图 · 回到内容', '都在画布角落，不占工具条')}
    ${mockE}
    ${rules([
      'M 或缩放条末格开合，默认收起；开合全局记在 preferences.json',
      '贴在缩放条正上方、同宽，提示词条现有的避让不用改',
      '画泳道色带、节点小块和视口框；点 = 跳过去，拖框 = 平移，滚轮不缩放',
      '回到内容：有节点但视口里一个都看不到、平移停下 300ms 后出现；点 = 适应全部（同 Shift 1）',
      '空画布不出（那里是空画布引导）；查找条开着时让位',
    ])}
  </div>`;

// ---------- F：工具锁与便签 ----------
const tb = (id, extra = '') => `<div style="position: relative; width: 28px; height: 28px; border-radius: 4px; display: flex; align-items: center; justify-content: center; color: ${T.fg3}; ${extra}">${ic(id, 16)}</div>`;
const mockF = `
  <div style="${grid(COL, MOCK_H)}">
    <div style="position: absolute; left: 10px; top: 10px; display: flex; gap: 2px; padding: 3px; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 6px">
      ${tb('select')}
      <div style="width: 1px; height: 18px; background: ${T.control}; margin: 0 3px; align-self: center"></div>
      <div style="position: relative; width: 28px; height: 28px; border-radius: 4px; display: flex; align-items: center; justify-content: center; background: ${T.wash}; outline: 1px solid ${T.washBorder}; color: ${T.accent}">${ic('imageConfig', 16)}<div style="position: absolute; right: -3px; bottom: -3px; width: 12px; height: 12px; border-radius: 6px; background: ${T.s4}; display: flex; align-items: center; justify-content: center; color: ${T.accent}">${ic('pin', 9)}</div></div>
      ${tb('videoConfig')}${tb('text')}${tb('shot')}${tb('note')}
    </div>
    <div style="position: absolute; left: 10px; top: 46px; height: 20px; padding: 0 7px; border-radius: 3px; background: ${T.s5}; color: ${T.fg2}; font-size: 10px; display: flex; align-items: center; gap: 4px">图像配置 · 已锁定 ${kbd('Q 解锁')}</div>
    <div style="position: absolute; left: 22px; top: 82px; width: 130px; height: 66px; box-sizing: border-box; border: 1.5px dashed ${T.accent}; border-radius: 4px; display: flex; align-items: center; justify-content: center; gap: 5px; color: ${T.accent}; font-size: 10px">${ic('imageConfig', 13)}<span>点一下放一个</span></div>
    ${card({ x: 214, y: 14, w: 80, title: '文本', type: 'T', box: `<div style="position: absolute; inset: 0; padding: 5px 7px; font-size: 9px; line-height: 1.5; color: ${T.fg2}; outline: 1px solid ${T.accent}; outline-offset: -3px; border-radius: 2px">雨夜的城市，霓虹倒影<span style="display: inline-block; width: 1px; height: 10px; background: ${T.fg1}; vertical-align: -1px"></span></div>`, status: '<span>双击编辑中</span>' })}
    <div style="position: absolute; left: 289px; top: 47px; width: 10px; height: 10px; border-radius: 5px; background: ${T.fg5}"></div>
    <div style="position: absolute; left: 306px; top: 30px; width: 68px; height: 72px; box-sizing: border-box; padding: 6px 7px; border-radius: 3px; background: ${T.wash}; border: 1px solid ${T.washBorder}; box-shadow: 0 6px 14px rgba(0,0,0,0.35); font-size: 10px; line-height: 1.5; color: ${T.fg1}">第二场改成黄昏？问导演</div>
    <div style="position: absolute; right: 10px; top: 106px; font-size: 9px; color: ${T.fg5}">便签 N · 不进提示词</div>
    <div style="position: absolute; left: 214px; top: 126px; font-size: 9px; color: ${T.fg5}">连线后并入提示词</div>
  </div>`;
const colF = `
  <div>
    ${h3('工具锁 · 便签', '两个 P2 小工具')}
    ${mockF}
    ${rules([
      '现状 图像 I / 视频 G / 文本 T / 镜头 / 便签 N 一按就在视口中心建一个；锁定后改为点放，每点一下空白处建一个',
      'Q 或双击工具按钮锁定；V、Esc、换工具解锁；连线 L 本来就是模式，不参与',
      'N 建便签：没有端口，不进提示词和大纲，查找能搜到；三种底色',
      `正文只有一个键 ${code('type_config.text')}：检查器正文框（fix/demo-inspectors 已上，F1 已修）是随时可用的那条路；双击文本 / 便签卡就地编辑只是快捷入口`,
      '两处走同一条防抖写入链（InspectorSubmitController：失败重试、退出前冲刷），失焦再写一笔并重载画布；就地编辑时检查器正文框只读跟随',
      '新键 Ctrl U、Ctrl F、M、Q、N 都不撞现有键；单键只在画布持焦且不在文字里时生效',
      'Esc 一次只收一层：菜单 > @ 弹层 > 查找条 > 框选进行中 > 工具锁 > 清空选中',
    ])}
  </div>`;

// ---------- 需要你定 ----------
const q = (n, title, opts, rec) => `
  <div>
    <div style="color: ${T.fg1}; font-weight: 500; margin-bottom: 4px">${n}. ${title}</div>
    ${opts.map((o) => `<div style="font-size: 11px; color: ${T.fg3}; line-height: 1.5">${o}</div>`).join('')}
    <div style="font-size: 11px; color: ${T.accent}; line-height: 1.5; margin-top: 2px">建议 ${rec}</div>
  </div>`;
const decide = `
  <div style="background: ${T.wash}; border: 1px solid ${T.washBorder}; border-radius: 6px; padding: 12px 18px 14px">
    <div style="font-weight: 500; color: ${T.accent}; margin-bottom: 8px">需要你定</div>
    <div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px 32px">
      ${q(1, '拖入和粘贴图片用哪套依赖（UndoClipboard、ContextMenus 的粘贴 / 拖放都引用这一条）', ['A. desktop_drop + pasteboard，两个小插件', 'B. super_drag_and_drop + super_clipboard，一套全包，但带 Rust 原生库，构建变重', '画布内复制粘贴节点走应用内 canvasClipboardProvider，往系统剪贴板只写纯文字，两案都不用另加'], 'A')}
      ${q(2, '别的画布拖来的素材', ['A. 复制进本画布 canvases/&lt;id&gt;/imports/，两边互不影响', 'B. 改成项目级共享路径，要动 file_resolver 和产物路径的存法'], 'A')}
      ${q(3, '@ 标签和挂载的关系', ['A. 插入即挂载，删标签不卸载', 'B. 双向同步，标签删光即卸载', 'C. 纯文字 @名字，不存 id'], 'A：character_ids 仍是唯一来源')}
      ${q(4, '工具锁做不做', ['A. 做：Q + 双击工具按钮，进点放模式', 'B. 不做：靠 Ctrl D（只复制配置节点）和 Tab 菜单连续建'], 'A，排 P2')}
      ${q(5, '便签怎么存', ['A. 仍是 text，type_config.variant = note，不迁移', 'B. 新类型 note，nodes.type 加一档，新增一条前向迁移'], 'A；提示词拼装、大纲要排除便签，检查器沿用文本正文框')}
      ${q(6, '导入的视频能不能直接当一镜', ['A. 不能：和产物一样不入叙事链，只当首帧 / 参考', 'B. 能：叙事链放开到导入节点，序列和导出排序跟着改'], 'A 先上，B 等剪辑需求明确')}
    </div>
  </div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45; padding: 28px 32px; box-sizing: border-box; display: flex; flex-direction: column; gap: 16px">
  <div style="display: flex; align-items: baseline; gap: 14px">
    <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">导入、拖放与查找</div>
    <div style="color: ${T.fg4}">外部文件和左栏里的东西怎么进画布；画布里的东西怎么找到；再补三个角落里的小工具</div>
  </div>
  <div style="display: grid; grid-template-columns: repeat(3, ${COL}px); gap: 18px 32px">
    ${colA}${colB}${colC}
    ${colD}${colE}${colF}
  </div>
  ${decide}
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'ImportSearch.dc.html', html: page('导入、拖放与查找', W, H, body, logic) };
