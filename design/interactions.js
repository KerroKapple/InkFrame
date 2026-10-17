// 画板 5：画布交互——连线语义 / 拖线到空白处建节点 / 右键菜单 / 快捷键（1280×860，静态）
const { T, IMG, SANS, MONO, page, ic } = require('./common.js');

const W = 1280, H = 860;

const h3 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 8px; margin-bottom: 12px"><div style="font-weight: 500; color: ${T.fg1}">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const kbd = (k) => `<span style="font-family: ${MONO}; font-size: 10px; color: ${T.fg5}">${k}</span>`;

// ---- 连线语义 ----
const edgeSample = (stroke, dash, width, label, labelColor) => `
  <div style="position: relative; width: 120px; height: 24px; flex: none">
    <svg width="120" height="24" viewBox="0 0 120 24" aria-hidden="true" style="display: block">
      <path d="M6 12H112" fill="none" stroke="${stroke}" stroke-width="${width}" ${dash ? `stroke-dasharray="${dash}"` : ''} stroke-linecap="round"></path>
      <path d="M106 7.5L112 12l-6 4.5" fill="none" stroke="${stroke}" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"></path>
    </svg>
    ${label ? `<div style="position: absolute; left: 42px; top: 3px; height: 18px; padding: 0 6px; border-radius: 9px; background: ${T.s2}; border: 1px solid ${labelColor}; color: ${labelColor}; font-size: 10px; display: flex; align-items: center">${label}</div>` : ''}
  </div>`;
const edgeRow = (sample, name, meaning) => `
  <div style="display: flex; align-items: center; gap: 12px; padding: 9px 0; border-bottom: 1px solid ${T.bSubtle}">
    ${sample}
    <div style="min-width: 0"><div style="color: ${T.fg2}">${name}</div><div style="font-size: 11px; color: ${T.fg5}; line-height: 1.5">${meaning}</div></div>
  </div>`;
const edgesCol = `
  <div>
    ${h3('连线语义', '颜色加线型双重区分，色弱也能分清')}
    ${edgeRow(edgeSample(T.fg4, '', 2, '', ''), '叙事 · 下一镜', '镜头顺序；序列和导出按它排')}
    ${edgeRow(edgeSample(T.teal, '', 1.75, '首帧', T.teal), '首帧', '这张图当视频的第一帧')}
    ${edgeRow(edgeSample(T.peach, '', 1.75, '尾帧', T.peach), '尾帧', '这张图当视频的最后一帧')}
    ${edgeRow(edgeSample(T.sky, '5 4', 1.5, '参考', T.sky), '参考', '参考图，计入模型的参考图张数上限')}
    ${edgeRow(edgeSample(T.fg6, '1.5 3.5', 1.25, '', ''), '产出', '这个结果由哪个配置节点生成；系统自动画，不能点也不能删')}
    <div style="font-size: 11px; color: ${T.fg4}; line-height: 1.7; margin-top: 12px">
      · 端口只在悬停或选中节点时出现，没有连线就不常驻<br>
      · 拖线时只亮能接的目标，接不了的变暗<br>
      · 选中一条线：线变琥珀，中点出现「改语义 / 删除」<br>
      · 生成的结果放在配置节点右边，多张往下排，不再全部叠在左上角
    </div>
  </div>`;

// ---- 拖线到空白处 ----
const menuItem = (icon, label, key = '', extra = '') => `
  <div style="height: 28px; display: flex; align-items: center; gap: 8px; padding: 0 10px; border-radius: 3px; color: ${T.fg2}; ${extra}">
    ${icon ? `<div style="color: ${T.fg4}; display: flex">${ic(icon, 16)}</div>` : '<div style="width: 16px"></div>'}
    <div style="flex: 1">${label}</div>${key ? kbd(key) : ''}
  </div>`;
const menuSep = `<div style="height: 1px; background: ${T.bStrong}; margin: 4px 0"></div>`;
const menu = (inner, width = 240) => `<div style="width: ${width}px; box-sizing: border-box; padding: 4px; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6)">${inner}</div>`;
const dragCol = `
  <div>
    ${h3('拖线到空白处 → 建节点', '最常用的一步，省掉「先建节点再连线」')}
    <div style="position: relative; height: 300px">
      <div style="position: absolute; left: 0; top: 30px; width: 150px">
        <div style="font-size: 11px; font-weight: 500; color: ${T.fg2}; height: 18px">镜头 01 · 成片</div>
        <img src="${IMG.mountain}" alt="" style="width: 150px; height: 84px; object-fit: cover; border-radius: 4px; outline: 1px solid ${T.accent}">
      </div>
      <div style="position: absolute; left: 145px; top: 85px; width: 10px; height: 10px; border-radius: 5px; background: ${T.accent}"></div>
      <svg width="380" height="300" viewBox="0 0 380 300" aria-hidden="true" style="position: absolute; left: 0; top: 0">
        <path d="M150 90C200 90 170 150 214 150" fill="none" stroke="${T.accent}" stroke-width="1.75" stroke-dasharray="4 3"></path>
        <circle cx="214" cy="150" r="3.5" fill="${T.accent}"></circle>
      </svg>
      <div style="position: absolute; left: 140px; top: 158px">
        ${menu(`
          <div style="height: 28px; display: flex; align-items: center; gap: 6px; padding: 0 8px; margin-bottom: 4px; border-radius: 3px; background: ${T.s2}; border: 1px solid ${T.outline}; color: ${T.fg6}">${ic('search', 13)}<span style="font-size: 11px">直接打字搜索…</span></div>
          ${menuItem('videoConfig', '当首帧 · 新建视频配置', '', `background: ${T.s5}`)}
          ${menuItem('videoConfig', '当尾帧 · 新建视频配置')}
          ${menuItem('imageConfig', '当参考 · 新建图像配置')}
          ${menuSep}
          ${menuItem('link', '下一镜（叙事）')}
        `, 236)}
      </div>
    </div>
    <div style="font-size: 11px; color: ${T.fg4}; line-height: 1.7; margin-top: 4px">
      · 新节点落在松手的位置，并自动连好对应语义的线<br>
      · 双击空白、右键「新建…」、按 Tab：打开同一个搜索弹层<br>
      · 选中镜头后 Ctrl → 直接沿叙事链建下一镜，继承配置
    </div>
  </div>`;

// ---- 右键菜单 ----
const ctxCol = `
  <div>
    ${h3('右键菜单', '和 Ctrl K、快捷键页出自同一张动作表')}
    <div style="display: flex; gap: 12px; align-items: flex-start">
      <div>
        <div style="font-size: 11px; color: ${T.fg5}; margin-bottom: 6px">节点</div>
        ${menu(`
          ${menuItem('run', '生成', 'Ctrl ↵')}
          ${menuItem('', '复制一份', 'Ctrl D')}
          ${menuSep}
          ${menuItem('', '剪切', 'Ctrl X')}${menuItem('', '复制', 'Ctrl C')}
          ${menuSep}
          ${menuItem('characters', '存为角色')}
          ${menuItem('videoConfig', '当下一镜的首帧')}
          ${menuItem('lane', '加入泳道 ›')}
          ${menuItem('sequence', '在序列中定位')}
          ${menuSep}
          <div style="height: 28px; display: flex; align-items: center; gap: 8px; padding: 0 10px; color: ${T.danger}"><div style="width: 16px"></div><div style="flex: 1">删除</div>${kbd('Del')}</div>
        `, 196)}
      </div>
      <div>
        <div style="font-size: 11px; color: ${T.fg5}; margin-bottom: 6px">空白处</div>
        ${menu(`
          ${menuItem('nodeLibrary', '新建… ', 'Tab')}
          ${menuItem('', '粘贴', 'Ctrl V')}
          ${menuItem('upload', '导入媒体…', 'Ctrl U')}
          ${menuItem('script', '导入剧本…')}
          ${menuSep}
          ${menuItem('', '全选', 'Ctrl A')}
          ${menuItem('fit', '适应视图', 'Shift 1')}
        `, 196)}
      </div>
    </div>
  </div>`;

// ---- 快捷键 ----
const keys = [
  ['V', '选择'], ['H / 按住空格', '平移'], ['I', '图像配置'], ['G', '视频配置'], ['F', '泳道'], ['L', '连线'],
  ['N', '便签'], ['Ctrl U', '上传媒体'], ['Ctrl F', '画布内搜索'], ['Ctrl ↵', '运行选中'], ['Ctrl D', '复制一份'], ['Tab', '新建…'],
  ['Shift 1', '适应全部'], ['Shift 2', '适应选中'], ['M', '小地图'], ['Ctrl \\', '收起侧栏'], ['F6', '跳到通知区'], ['Ctrl Z', '撤销（通知过期后也行）'],
];
const keyCell = ([k, v]) => `<div style="display: flex; align-items: center; gap: 10px; height: 26px"><span style="min-width: 78px; font-family: ${MONO}; font-size: 10px; color: ${T.fg3}">${k}</span><span style="color: ${T.fg4}; font-size: 11px">${v}</span></div>`;
const shortcuts = `
  <div style="position: absolute; left: 32px; right: 32px; bottom: 28px; border-top: 1px solid ${T.control}; padding-top: 14px">
    ${h3('快捷键', '单键只在画布有焦点、且不在输入框里时生效；与现有的 Del / Esc / Ctrl A / Ctrl ± / Ctrl 0 不冲突')}
    <div style="display: grid; grid-template-columns: repeat(6, minmax(0, 1fr)); gap: 2px 16px">${keys.map(keyCell).join('')}</div>
  </div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  <div style="position: absolute; left: 32px; top: 28px; display: flex; align-items: baseline; gap: 14px">
    <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">画布交互</div>
    <div style="color: ${T.fg4}">连线看得见、分得清；建节点少一步；常用动作都有菜单和快捷键</div>
  </div>
  <div style="position: absolute; left: 32px; right: 32px; top: 72px; display: grid; grid-template-columns: 360px 380px minmax(0, 1fr); gap: 32px">
    ${edgesCol}
    ${dragCol}
    ${ctxCol}
  </div>
  ${shortcuts}
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'Interactions.dc.html', html: page('画布交互', W, H, body, logic) };
