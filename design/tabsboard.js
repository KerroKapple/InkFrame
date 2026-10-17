// 画板 4：页签去重——每个重复入口的去向（1280×860，静态）
const { T, SANS, page, ic } = require('./common.js');

const W = 1280, H = 860;

const tag = (text, kind) => {
  const k = {
    keep: `border: 1px solid ${T.controlStrong}; color: ${T.fg2}`,
    drop: `border: 1px dashed ${T.control}; color: ${T.fg6}; text-decoration: line-through`,
    move: `border: 1px solid ${T.washBorder}; background: ${T.wash}; color: ${T.accent}`,
    now: `border: 1px solid ${T.outline}; background: ${T.s4}; color: ${T.fg3}`,
  }[kind];
  return `<span style="display: inline-flex; align-items: center; height: 22px; padding: 0 8px; border-radius: 3px; font-size: 11px; ${k}">${text}</span>`;
};
const row = (where, now, after, why) => `
  <div style="display: grid; grid-template-columns: 150px 300px 32px minmax(0, 1fr) 300px; gap: 12px; align-items: center; padding: 12px 0; border-bottom: 1px solid ${T.bSubtle}">
    <div style="color: ${T.fg4}">${where}</div>
    <div style="display: flex; flex-wrap: wrap; gap: 6px">${now}</div>
    <div style="color: ${T.fg6}; text-align: center">→</div>
    <div style="display: flex; flex-wrap: wrap; gap: 6px; align-items: center">${after}</div>
    <div style="font-size: 11px; color: ${T.fg5}; line-height: 1.6">${why}</div>
  </div>`;

const rows = [
  row('顶部外壳标签', ['工作室', '画布', '序列', '画廊', '导出'].map((t) => tag(t, 'now')).join(''),
    tag('五个全部保留', 'keep'), '唯一的全局入口。画布页里凡是和它们同名的页签都拿掉'),
  row('画布页右上按钮', tag('导入脚本', 'now') + tag('序列预览', 'now') + tag('导出视频', 'now'),
    tag('导入脚本 → 工具条「更多」与左栏「剧本」', 'move') + tag('序列预览 → 在序列中查看', 'move') + tag('导出视频', 'keep'),
    '「序列预览」其实就是跳到序列标签，改名说实话，并把当前镜头带过去；导出保留一键轻入口'),
  row('画布顶部条', tag('画布 1', 'now') + tag('泳道：水墨风格', 'now') + tag('100%', 'now'),
    tag('整条删除', 'drop'),
    '画布名已在面包屑里，泳道名写在泳道上，缩放比例在左下缩放条——这一条三样都重复'),
  row('左栏页签', tag('画布', 'now') + tag('资产（没做）', 'now') + tag('角色', 'now'),
    `${tag('大纲', 'move')}${tag('素材', 'move')}${tag('角色', 'keep')}${tag('剧本（第二批）', 'move')}`,
    '文字页签换成图标导航条；「画布」和顶部标签同名，改叫大纲，画布列表并进大纲顶部的切换器；素材＝画廊的紧凑形态，同一份数据'),
  row('左侧 37px 工具条', tag('7 个占位方框', 'now'),
    tag('画布顶部居中的浮动工具条', 'move'),
    '左边让给导航条，避免两列竖排图标挨在一起；底部正中留给提示词条，右下留给通知'),
  row('底栏页签', tag('渲染队列', 'now') + tag('序列', 'now') + tag('导出历史（没做）', 'now'),
    `${tag('渲染队列 → 状态栏胶囊 + 任务弹层', 'move')}${tag('序列', 'drop')}${tag('导出历史 → 导出标签（第二批）', 'move')}`,
    '底栏整条拿掉，画布高度多出 173px；「序列」和顶部标签重复；任务进度改在节点角标、胶囊和通知里看'),
  row('检查器页签', tag('属性', 'now') + tag('状态（装饰）', 'now') + tag('历史（装饰）', 'now'),
    `${tag('属性', 'keep')}${tag('状态 → 属性顶部的状态行', 'move')}${tag('历史 → 选中节点的 take 历史', 'move')}`,
    '状态页签本来就是空的，状态已经内嵌在配置检查器里；历史做成真正能用的 take 列表，固定的那张往下游流'),
  row('右下角「+」按钮', tag('图像 / 视频 / 镜头 / 导入脚本', 'now'),
    tag('并进工具条与双击空白的新建菜单', 'move'),
    '它和工具条各管一半节点类型，两边都不全；右下角改放通知'),
].join('');

const legend = `
  <div style="display: flex; gap: 16px; align-items: center; font-size: 11px; color: ${T.fg5}; margin-top: 14px">
    <span style="display: flex; gap: 6px; align-items: center">${tag('现在', 'now')}现状</span>
    <span style="display: flex; gap: 6px; align-items: center">${tag('保留', 'keep')}不动</span>
    <span style="display: flex; gap: 6px; align-items: center">${tag('搬走', 'move')}搬到新位置</span>
    <span style="display: flex; gap: 6px; align-items: center">${tag('删除', 'drop')}直接删</span>
  </div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45; padding: 28px 32px; box-sizing: border-box">
  <div style="display: flex; align-items: baseline; gap: 14px">
    <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">页签去重：谁搬去哪</div>
    <div style="color: ${T.fg4}">方案 A：顶部五个标签是唯一完整入口，画布页里只留画布独有的东西</div>
  </div>
  ${legend}
  <div style="display: grid; grid-template-columns: 150px 300px 32px minmax(0, 1fr) 300px; gap: 12px; padding: 16px 0 8px; border-bottom: 1px solid ${T.control}; font-size: 11px; color: ${T.fg5}; margin-top: 8px">
    <div>位置</div><div>现在</div><div></div><div>改后</div><div>为什么</div>
  </div>
  ${rows}
  <div style="display: flex; gap: 10px; align-items: center; margin-top: 16px; font-size: 11px; color: ${T.fg4}">${ic('info', 16, `color: ${T.fg5}`)}<span>序列和导出并进画布（方案 B）留作第二阶段：等这一轮用顺了再看「画布 ↔ 序列」来回切是否真的嫌累。</span></div>
</div>`;

const logic = `
class Component extends DCLogic {
  renderVals() { return {}; }
}
`;

module.exports = { file: 'Tabs.dc.html', html: page('页签去重', W, H, body, logic) };
