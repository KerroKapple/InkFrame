// InkFrame 图标集 v1：20×20 网格，1.5 描边，圆头圆角，currentColor。
// 同一份路径数据既生成设计稿里的内联 SVG，也导出给 Flutter 端（icons.json）。
const n = (v) => Number(v.toFixed(3)).toString();
const C = (cx, cy, r) => `M${n(cx - r)} ${n(cy)}a${n(r)} ${n(r)} 0 1 0 ${n(2 * r)} 0a${n(r)} ${n(r)} 0 1 0 ${n(-2 * r)} 0z`;
const R = (x, y, w, h, r) =>
  `M${n(x + r)} ${n(y)}h${n(w - 2 * r)}a${n(r)} ${n(r)} 0 0 1 ${n(r)} ${n(r)}v${n(h - 2 * r)}a${n(r)} ${n(r)} 0 0 1 ${n(-r)} ${n(r)}h${n(-(w - 2 * r))}a${n(r)} ${n(r)} 0 0 1 ${n(-r)} ${n(-r)}v${n(-(h - 2 * r))}a${n(r)} ${n(r)} 0 0 1 ${n(r)} ${n(-r)}z`;
const SP = (cx, cy, r) => {
  const k = (a) => n(a * r);
  return `M${n(cx)} ${n(cy - r)}c${k(0.15)} ${k(0.6)} ${k(0.4)} ${k(0.85)} ${k(1)} ${k(1)}` +
    `c${k(-0.6)} ${k(0.15)} ${k(-0.85)} ${k(0.4)} ${k(-1)} ${k(1)}` +
    `c${k(-0.15)} ${k(-0.6)} ${k(-0.4)} ${k(-0.85)} ${k(-1)} ${k(-1)}` +
    `c${k(0.6)} ${k(-0.15)} ${k(0.85)} ${k(-0.4)} ${k(1)} ${k(-1)}z`;
};
const S = (d) => ({ d });
const F = (d) => ({ d, fill: true });

const FRAME_OPEN = 'M9.75 3.75H4.75a1.5 1.5 0 0 0-1.5 1.5v10a1.5 1.5 0 0 0 1.5 1.5h10a1.5 1.5 0 0 0 1.5-1.5v-5';
const SPEAKER = 'M3.5 8v4h3l4 3.25V4.75L6.5 8z';

const ICONS = [
  // ---- 左栏导航条 ----
  { id: 'outline', zh: '大纲', group: 'rail', parts: [F(C(4.5, 5, 1.1)), S('M7.75 5H16'), S('M4.5 7.25V15h1.75'), S('M4.5 10h1.75'), F(C(8.5, 10, 1.1)), S('M11.25 10H16'), F(C(8.5, 15, 1.1)), S('M11.25 15H16')] },
  { id: 'assets', zh: '素材', group: 'rail', parts: [S('M6.5 3.5H15a1.5 1.5 0 0 1 1.5 1.5v8.5'), S(R(3.5, 6.5, 10, 10, 1.5)), S('M3.75 14.25l2.75-2.75 2.5 2.5 1.5-1.5 2.75 2.75'), F(C(10.25, 9.25, 1))] },
  { id: 'characters', zh: '角色', group: 'rail', parts: [S(C(10, 6.75, 3)), S('M4 16.75c.9-3.2 3.2-5 6-5s5.1 1.8 6 5')] },
  { id: 'script', zh: '剧本', group: 'rail', parts: [S('M5.5 2.5h5.75L15 6.25V16a1.5 1.5 0 0 1-1.5 1.5h-8A1.5 1.5 0 0 1 4 16V4a1.5 1.5 0 0 1 1.5-1.5z'), S('M11 2.75V6.5h3.75'), S('M7 10h5.75M7 12.75h5.75M7 15.5h3.25')] },
  { id: 'nodeLibrary', zh: '节点库', group: 'rail', parts: [S(R(3.5, 3.5, 5.5, 5.5, 1.25)), S(R(11, 3.5, 5.5, 5.5, 1.25)), S(R(3.5, 11, 5.5, 5.5, 1.25)), S('M13.75 11.25v5M11.25 13.75h5')] },
  { id: 'templates', zh: '模板', group: 'rail', parts: [S(R(3, 3.5, 14, 13, 1.5)), S('M3 7.5h14M8.25 7.5v9')] },
  { id: 'panelToggle', zh: '收起侧栏', group: 'rail', parts: [S(R(2.75, 3.75, 14.5, 12.5, 1.5)), S('M7.75 3.75v12.5'), S('M12.75 8.25L11 10l1.75 1.75')] },
  { id: 'shortcuts', zh: '快捷键', group: 'rail', parts: [S(R(2.5, 5, 15, 10, 1.75)), S('M5.5 8.25h1M9.5 8.25h1M13.5 8.25h1'), S('M6.5 11.75h7')] },
  { id: 'help', zh: '帮助', group: 'rail', parts: [S(C(10, 10, 7.25)), S('M7.75 8.1a2.25 2.25 0 1 1 3.35 1.95c-.65.4-1.1.9-1.1 1.6v.4'), F(C(10, 14.1, 0.9))] },
  // ---- 画布工具条 ----
  { id: 'select', zh: '选择', group: 'tool', key: 'V', parts: [S('M5.25 3.25v12.5l3.6-3.4 2.25 4.4 2.05-1-2.2-4.35h4.8z')] },
  { id: 'pan', zh: '平移', group: 'tool', key: 'H', parts: [S('M7.5 10.5V5.25a1.25 1.25 0 0 1 2.5 0V9'), S('M10 9V3.75a1.25 1.25 0 0 1 2.5 0V9'), S('M12.5 9V5.25a1.25 1.25 0 0 1 2.5 0v6.5c0 3.2-2.25 5.5-5.25 5.5h-.75c-1.6 0-2.95-.75-3.9-2l-2.6-3.6a1.3 1.3 0 0 1 2.05-1.6l1.95 2.2')] },
  { id: 'imageConfig', zh: '图像配置', group: 'tool', key: 'I', parts: [S(FRAME_OPEN), S('M3.25 14.25l3.5-3.5 3 3 2-2 4.5 4.5'), F(SP(14.75, 5.25, 3.25))] },
  { id: 'videoConfig', zh: '视频配置', group: 'tool', key: 'G', parts: [S(FRAME_OPEN), S('M7.75 8.75v5l4.25-2.5z'), F(SP(14.75, 5.25, 3.25))] },
  { id: 'lane', zh: '泳道', group: 'tool', key: 'F', parts: [S(R(2.5, 3.5, 15, 5.5, 1.25)), S(R(2.5, 11, 15, 5.5, 1.25)), S('M5 6.25h3.5M5 13.75h3.5')] },
  { id: 'link', zh: '连线', group: 'tool', key: 'L', parts: [S(C(5, 15, 2.1)), S(C(15, 5, 2.1)), S('M7.1 15c3.9 0 1.9-10 5.8-10')] },
  { id: 'note', zh: '便签', group: 'tool', key: 'N', parts: [S('M4.5 3.5h11a1 1 0 0 1 1 1v7.75L12.25 16.5H4.5a1 1 0 0 1-1-1v-11a1 1 0 0 1 1-1z'), S('M16.5 12.25h-3.25a1 1 0 0 0-1 1v3.25'), S('M6.5 7.25h7M6.5 10h4.5')] },
  { id: 'shot', zh: '镜头', group: 'tool', parts: [S('M3.5 8.5h13v6.75a1.75 1.75 0 0 1-1.75 1.75h-9.5A1.75 1.75 0 0 1 3.5 15.25z'), S('M3.5 8.5V5.75A1.75 1.75 0 0 1 5.25 4h9.5a1.75 1.75 0 0 1 1.75 1.75V8.5'), S('M7.5 4.25l-2 4M11.5 4.25l-2 4M15.25 4.5l-1.85 3.75')] },
  { id: 'upload', zh: '上传', group: 'tool', key: 'Ctrl U', parts: [S('M10 12.75V3.5'), S('M6.75 6.75L10 3.5l3.25 3.25'), S('M3.5 12.5V15A1.5 1.5 0 0 0 5 16.5h10a1.5 1.5 0 0 0 1.5-1.5v-2.5')] },
  { id: 'more', zh: '更多', group: 'tool', parts: [F(C(4.75, 10, 1.2)), F(C(10, 10, 1.2)), F(C(15.25, 10, 1.2))] },
  { id: 'run', zh: '运行', group: 'tool', key: 'Ctrl ↵', parts: [S('M6.25 4.25v11.5L15.5 10z')] },
  { id: 'search', zh: '搜索', group: 'tool', key: 'Ctrl F', parts: [S(C(8.75, 8.75, 5.25)), S('M12.75 12.75l3.75 3.75')] },
  // ---- 视图 ----
  { id: 'zoomIn', zh: '放大', group: 'view', parts: [S('M10 4.5v11M4.5 10h11')] },
  { id: 'zoomOut', zh: '缩小', group: 'view', parts: [S('M4.5 10h11')] },
  { id: 'fit', zh: '适应全部', group: 'view', key: 'Shift 1', parts: [S('M3.5 7.5V5A1.5 1.5 0 0 1 5 3.5h2.5M12.5 3.5H15A1.5 1.5 0 0 1 16.5 5v2.5M16.5 12.5V15a1.5 1.5 0 0 1-1.5 1.5h-2.5M7.5 16.5H5A1.5 1.5 0 0 1 3.5 15v-2.5')] },
  { id: 'minimap', zh: '小地图', group: 'view', key: 'M', parts: [S(R(2.5, 4, 15, 12, 1.5)), S(R(9.25, 8.5, 5.75, 5, 0.75))] },
  // ---- 通知与状态 ----
  { id: 'bell', zh: '通知', group: 'notify', parts: [S('M5.5 13.25V9a4.5 4.5 0 0 1 9 0v4.25l1.25 1.75H4.25z'), S('M8.5 17.25a1.6 1.6 0 0 0 3 0')] },
  { id: 'success', zh: '完成', group: 'notify', parts: [S('M4.75 10.5l3.25 3.25 7.25-7.5')] },
  { id: 'error', zh: '失败', group: 'notify', parts: [S('M6 6l8 8M14 6l-8 8')] },
  { id: 'warning', zh: '警告', group: 'notify', parts: [S('M10 4.75v6.5'), F(C(10, 14.75, 1.05))] },
  { id: 'info', zh: '提示', group: 'notify', parts: [S('M10 8.75v6.5'), F(C(10, 5.25, 1.05))] },
  { id: 'progress', zh: '进行中', group: 'notify', parts: [S('M10 3.5a6.5 6.5 0 1 1-6.5 6.5')] },
  { id: 'undo', zh: '撤销', group: 'notify', parts: [S('M7.5 4.75L4.25 8l3.25 3.25'), S('M4.25 8h7.5a4.25 4.25 0 0 1 0 8.5H9.25')] },
  { id: 'close', zh: '关闭', group: 'notify', parts: [S('M6.5 6.5l7 7M13.5 6.5l-7 7')] },
  { id: 'sound', zh: '提示音', group: 'notify', parts: [S(SPEAKER), S('M13.25 7.25a3.75 3.75 0 0 1 0 5.5'), S('M15.25 5.25a6.5 6.5 0 0 1 0 9.5')] },
  { id: 'soundOff', zh: '静音', group: 'notify', parts: [S(SPEAKER), S('M13.5 8l4 4M17.5 8l-4 4')] },
  { id: 'dirty', zh: '已过期', group: 'notify', parts: [S('M10 3.25L17.25 16H2.75z'), S('M10 8v3.75'), F(C(10, 13.6, 0.9))] },
  { id: 'pin', zh: '固定', group: 'notify', parts: [S('M7.25 3.25h5.5'), S('M8.5 3.25v4.5l-2.75 3v1.5h8.5v-1.5l-2.75-3v-4.5'), S('M10 12.25V17')] },
  { id: 'history', zh: '历史', group: 'notify', parts: [S('M3.6 10a6.4 6.4 0 1 0 1.9-4.55'), S('M3.5 3.5v2.75h2.75'), S('M10 6.75V10l2.25 1.5')] },
  { id: 'export', zh: '导出', group: 'notify', parts: [S('M11.75 3.5h4.75v4.75'), S('M16.5 3.5l-7 7'), S('M14.5 11.5V15a1.5 1.5 0 0 1-1.5 1.5H5A1.5 1.5 0 0 1 3.5 15V7A1.5 1.5 0 0 1 5 5.5h3.5')] },
  { id: 'sequence', zh: '序列', group: 'notify', parts: [S(R(2.5, 5, 15, 10, 1.5)), S('M7.5 5v10M12.5 5v10')] },
  { id: 'queue', zh: '渲染队列', group: 'notify', parts: [S('M10 3.25l7 3.5-7 3.5-7-3.5z'), S('M3 10.25l7 3.5 7-3.5'), S('M3 13.75l7 3.5 7-3.5')] },
  // ---- 工作室左栏 / 节点类型补充 ----
  { id: 'text', zh: '文本', group: 'tool', key: 'T', parts: [S('M4.5 5.5V3.75h11V5.5'), S('M10 3.75v12.5'), S('M7.75 16.25h4.5')] },
  { id: 'projects', zh: '全部项目', group: 'rail', parts: [S('M2.75 6.25V5A1.5 1.5 0 0 1 4.25 3.5h3.5l1.75 2h6.25a1.5 1.5 0 0 1 1.5 1.5v8A1.5 1.5 0 0 1 15.75 16.5H4.25A1.5 1.5 0 0 1 2.75 15z'), S('M2.75 8.25h14.5')] },
  { id: 'trash', zh: '回收站', group: 'rail', parts: [S('M3.5 5.5h13'), S('M8 5.5V4a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v1.5'), S('M5 5.5l.75 10.6a1.5 1.5 0 0 0 1.5 1.4h5.5a1.5 1.5 0 0 0 1.5-1.4L15 5.5'), S('M8.5 9v5M11.5 9v5')] },
  { id: 'settings', zh: '设置', group: 'rail', parts: [S('M8.137 4.56L8.51 2.65L11.49 2.65L11.863 4.56A5.75 5.75 0 0 1 12.529 4.836L14.144 3.749L16.251 5.856L15.164 7.471A5.75 5.75 0 0 1 15.44 8.137L17.35 8.51L17.35 11.49L15.44 11.863A5.75 5.75 0 0 1 15.164 12.529L16.251 14.144L14.144 16.251L12.529 15.164A5.75 5.75 0 0 1 11.863 15.44L11.49 17.35L8.51 17.35L8.137 15.44A5.75 5.75 0 0 1 7.471 15.164L5.856 16.251L3.749 14.144L4.836 12.529A5.75 5.75 0 0 1 4.56 11.863L2.65 11.49L2.65 8.51L4.56 8.137A5.75 5.75 0 0 1 4.836 7.471L3.749 5.856L5.856 3.749L7.471 4.836A5.75 5.75 0 0 1 8.137 4.56Z'), S(C(10, 10, 2.5))] },
];

function svg(id, size, style = '') {
  const ic = ICONS.find((i) => i.id === id);
  if (!ic) throw new Error('unknown icon ' + id);
  const inner = ic.parts
    .map((p) => p.fill
      ? `<path d="${p.d}" fill="currentColor" stroke="none"></path>`
      : `<path d="${p.d}" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"></path>`)
    .join('');
  return `<svg width="${size}" height="${size}" viewBox="0 0 20 20" aria-hidden="true" focusable="false" style="display: block; flex: none${style ? '; ' + style : ''}">${inner}</svg>`;
}

module.exports = { ICONS, svg };
