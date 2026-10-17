// 画板 6：提示词条与节点文字——宽度随画布、内容多了往上长、文字格式（1280×1000，可交互）
const { T, IMG, SANS, MONO, page, ic, caret } = require('./common.js');

const W = 1280, H = 1080;

const h2 = (t, note = '') => `<div style="display: flex; align-items: baseline; gap: 10px; margin: 0 0 12px"><div style="font-weight: 500; color: ${T.fg1}">${t}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>`;
const mention = (name) => `<span style="display: inline-flex; align-items: center; gap: 4px; height: 20px; padding: 0 6px 0 3px; margin: 0 2px; border-radius: 10px; background: ${T.wash}; border: 1px solid ${T.washBorder}; color: ${T.accent}; font-size: 12px; vertical-align: 1px"><img src="${IMG.thumbMountain}" alt="" style="width: 14px; height: 14px; border-radius: 7px; object-fit: cover">${name}</span>`;
const chip = (label, extra = '') => `<div style="height: 24px; padding: 0 8px; border-radius: 3px; border: 1px solid ${T.outline}; background: ${T.s3}; color: ${T.fg3}; font-size: 11px; display: flex; align-items: center; gap: 6px; flex: none; ${extra}">${label}</div>`;
const genBtn = `<div style="height: 28px; padding: 0 12px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-weight: 500; display: flex; align-items: center; gap: 6px; flex: none">${ic('run', 14)}<span>生成</span><span style="font-family: ${MONO}; font-size: 10px; opacity: .7">Ctrl ↵</span></div>`;
const barShell = (w, textBlock, counter = '24 字', chips = true) => `
  <div style="width: ${w}px; box-sizing: border-box; padding: 12px 12px 10px 14px; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 6px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); display: flex; flex-direction: column; gap: 10px">
    ${textBlock}
    <div style="display: flex; align-items: center; gap: 6px; min-width: 0">
      ${chips ? `${chip(`${ic('videoConfig', 13)}<span>万相 2.2</span>${caret()}`)}${chip('5 秒')}${chip('16:9')}${chip('+2', `color: ${T.fg5}`)}` : ''}
      <div style="flex: 1"></div>
      <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}; flex: none">${counter}</div>
      ${genBtn}
    </div>
  </div>`;
const textStyle = `font-size: 13px; line-height: 1.6; color: ${T.fg1}`;

// ---- A：宽度随画布 ----
// 统一按 0.615 缩小，方便三种窗口放在同一张图里比较
const S = 0.615;
const widthRow = (label, canvasW, barW, why) => `
  <div style="display: flex; align-items: center; gap: 16px; margin-bottom: 10px">
    <div style="width: 150px; flex: none"><div style="color: ${T.fg2}">${label}</div><div style="font-size: 11px; color: ${T.fg5}">画布 ${canvasW} → 条宽 <span style="color: ${T.accent}">${barW}</span></div><div style="font-size: 10px; color: ${T.fg6}">${why}</div></div>
    <div style="position: relative; width: ${Math.round(canvasW * S)}px; height: 64px; border-radius: 4px; border: 1px solid ${T.outline}; background-color: ${T.s1}; background-image: linear-gradient(${T.grid} 1px, transparent 1px), linear-gradient(90deg, ${T.grid} 1px, transparent 1px); background-size: 14.8px 14.8px; flex: none">
      <div style="position: absolute; left: 50%; bottom: 10px; transform: translateX(-50%); width: ${Math.round(barW * S)}px; height: 30px; border-radius: 4px; background: ${T.s4}; border: 1px solid ${T.control}; box-shadow: 0 6px 18px rgba(0,0,0,0.5)"></div>
      <div style="position: absolute; left: 50%; bottom: 44px; transform: translateX(-50%); font-family: ${MONO}; font-size: 9px; color: ${T.fg5}">${barW}</div>
    </div>
  </div>`;
const sectionA = `
  <div>
    ${h2('宽度跟着画布走', '条宽 = 画布宽 × 60%，夹在 480 到 880 之间；画布窄于 512 时贴边留 16')}
    ${widthRow('窗口 1280', 697, 480, '下限：再窄就挤成一列字')}
    ${widthRow('窗口 1600', 1014, 608, '画布的 60%')}
    ${widthRow('窗口 2560', 1977, 880, '上限：再宽一行字太长不好读')}
  </div>`;

// ---- B：内容多了往上长 ----
const stateCol = (title, note, inner) => `
  <div style="display: flex; flex-direction: column; gap: 8px; width: 380px">
    <div><div style="color: ${T.fg2}">${title}</div><div style="font-size: 11px; color: ${T.fg5}">${note}</div></div>
    <div style="height: 236px; display: flex; flex-direction: column; justify-content: flex-end">${inner}</div>
  </div>`;
const longText = `拂晓，雾江上一叶孤舟，${mention('渔夫')} 站在船头收网。<br>镜头从远景缓推到中景，雾气慢慢散开，<br>远山的轮廓一层层浮出来，水面有细碎的反光。<br>节奏要慢，留出呼吸感；不要出现现代物件。<br>结尾停在渔夫回望远山的侧脸上，<br>光线偏冷，只在山脊留一点暖色。<br>整体保持水墨质感，笔触柔和。<br>再补一句：船尾的木桨要有水滴落下。`;
const sectionB = `
  <div>
    ${h2('内容多了往上长', '一行起步，最多长到 8 行，再多就在框里滚动；条底边不动')}
    <div style="display: flex; gap: 28px; align-items: flex-end">
      ${stateCol('空着', '占位提示写清能填什么', barShell(380, `<div style="${textStyle}; color: ${T.fg6}">描述这一镜：主体、动作、镜头、光线…  输入 @ 引用角色</div>`, '0 字'))}
      ${stateCol('两行', '@角色 显示成带头像的标签；Enter 换行，Ctrl ↵ 生成', barShell(380, `<div style="${textStyle}">拂晓，雾江上一叶孤舟，${mention('渔夫')} 站在船头收网。<br>镜头从远景缓推到中景。</div>`, '38 字'))}
      ${stateCol('到顶了', '8 行封顶，上沿淡出提示还能往上滚', barShell(380, `<div style="position: relative"><div style="${textStyle}; height: 166px; overflow: hidden; display: flex; flex-direction: column; justify-content: flex-end">${longText}</div><div style="position: absolute; left: 0; right: 0; top: 0; height: 28px; background: linear-gradient(${T.s4}, rgba(38,38,38,0))"></div><div style="position: absolute; right: -6px; top: 18px; width: 3px; height: 72px; border-radius: 2px; background: ${T.controlStrong}"></div></div>`, '186 字'))}
    </div>
  </div>`;

// ---- 试着打字（受控 textarea，行数随内容变）----
const sectionLive = `
  <div>
    ${h2('试着打字', '这里的框是真的：按行数长高，超过 8 行开始滚动')}
    <div style="width: 608px; box-sizing: border-box; padding: 12px 12px 10px 14px; background: ${T.s4}; border: 1px solid ${T.control}; border-radius: 6px; display: flex; flex-direction: column; gap: 10px">
      <label for="live-prompt" style="position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0)">提示词</label>
      <textarea id="live-prompt" value="{{ text }}" onChange="{{ onText }}" rows="{{ rows }}" placeholder="描述这一镜：主体、动作、镜头、光线…" style="width: 100%; box-sizing: border-box; resize: none; border: 0; outline: none; background: transparent; padding: 0; margin: 0; font-family: ${SANS}; font-size: 13px; line-height: 1.6; color: ${T.fg1}; {{ areaStyle }}"></textarea>
      <div style="display: flex; align-items: center; gap: 6px">
        ${chip(`${ic('imageConfig', 13)}<span>Gemini</span>${caret()}`)}${chip('16:9')}
        <div style="flex: 1"></div>
        <div style="font-family: ${MONO}; font-size: 10px; color: ${T.fg6}">{{ count }}</div>
        ${genBtn}
      </div>
    </div>
  </div>`;

// ---- C：节点卡里的提示词 ----
const cardFrame = (label, inner, w = 224) => `
  <div style="display: flex; flex-direction: column; gap: 8px">
    <div style="font-size: 11px; color: ${T.fg5}">${label}</div>
    <div style="width: ${w}px">${inner}</div>
  </div>`;
const nodeHead = (title, type, size = 12) => `<div style="height: 20px; display: flex; align-items: center; gap: 6px; font-size: ${size}px"><div style="font-weight: 500; color: ${T.fg2}">${title}</div><div style="flex: 1"></div><div style="font-size: ${size - 2}px; color: ${T.fg5}">${type}</div></div>`;
const before = `
  ${nodeHead('第一个镜头', 'image')}
  <div style="position: relative; height: 126px; border-radius: 4px; background: ${T.thumb}; outline: 1px solid ${T.outline}">
    <div style="position: absolute; left: 10px; right: 10px; bottom: 8px; font-size: 11px; color: ${T.fg4}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">拂晓的雾江上一叶孤舟，远山隐入雾霭</div>
  </div>
  <div style="font-size: 10px; color: ${T.fg5}; margin-top: 6px">已就绪</div>`;
const after = (scale = 1) => `
  ${nodeHead('镜头 01 · 第一个镜头', '图像配置')}
  <div style="height: 126px; box-sizing: border-box; border-radius: 4px; background: ${T.thumb}; outline: 1px solid ${T.outline}; padding: 10px 12px; display: flex; flex-direction: column; gap: 8px">
    <div style="font-size: 12px; line-height: 1.55; color: ${T.fg2}; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden">拂晓，雾江上一叶孤舟，${mention('渔夫')} 站在船头收网；镜头从远景缓推到中景，雾气慢慢散开，远山一层层浮出来。</div>
    <div style="flex: 1"></div>
    <div style="font-size: 10px; color: ${T.fg5}; display: flex; gap: 6px"><span>远景 → 中景</span><span>·</span><span>平视</span><span>·</span><span>35mm</span></div>
  </div>
  <div style="font-size: 10px; color: ${T.fg5}; margin-top: 6px; display: flex; gap: 6px"><span>就绪</span><span>·</span><span>继承 水墨风格</span></div>`;
const zoomed = (pct, showText) => {
  const s = pct / 100;
  return `
  <div style="display: flex; flex-direction: column; gap: 8px">
    <div style="font-size: 11px; color: ${T.fg5}">缩放 ${pct}%</div>
    <div style="width: ${Math.round(224 * s)}px">
      <div style="height: ${Math.round(20 * s)}px; display: flex; align-items: center; font-size: ${Math.max(9, Math.round(12 * s))}px; font-weight: 500; color: ${T.fg2}; white-space: nowrap; overflow: hidden">镜头 01 · 第一个镜头</div>
      <div style="height: ${Math.round(126 * s)}px; box-sizing: border-box; border-radius: ${Math.max(2, Math.round(4 * s))}px; background: ${T.thumb}; outline: 1px solid ${T.outline}; padding: ${Math.round(10 * s)}px ${Math.round(12 * s)}px">
        ${showText ? `<div style="font-size: ${(12 * s).toFixed(1)}px; line-height: 1.55; color: ${T.fg2}; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden">拂晓，雾江上一叶孤舟，渔夫站在船头收网；镜头从远景缓推到中景，雾气慢慢散开。</div>` : `<div style="height: 100%; display: flex; align-items: center; justify-content: center; color: ${T.fg6}">${ic('imageConfig', Math.round(28 * s))}</div>`}
      </div>
    </div>
  </div>`;
};
const sectionC = `
  <div>
    ${h2('节点卡里的提示词', '顶部对齐、最多 3 行；镜头语言单独一行；缩放到 60% 以下不画字，只留类型图标')}
    <div style="display: flex; gap: 32px; align-items: flex-end">
      ${cardFrame('现在：一行灰字贴在大方框底部', before)}
      ${cardFrame('改后：顶部对齐，三行封顶', after())}
      ${zoomed(60, true)}
      ${zoomed(45, false)}
    </div>
  </div>`;

const specs = [
  ['提示词条字号', '13 / 行高 1.6（正文 12 偏小，写长提示词吃力）；节点预览 12 / 1.55'],
  ['键位', 'Enter 换行 · Ctrl ↵ 生成 · @ 弹出角色列表 · Esc 收起列表'],
  ['计数', '右下角显示字数；超过所选模型的提示词上限时变琥珀并提示会被截断'],
  ['条的位置', '画布底部居中，离底 16；和右下角通知横向重叠时，通知整体抬到条的上沿之上'],
];
const specBlock = `
  <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px 28px">
    ${specs.map(([k, v]) => `<div style="display: flex; gap: 12px; font-size: 11px"><div style="width: 84px; flex: none; color: ${T.fg4}">${k}</div><div style="color: ${T.fg2}; line-height: 1.6">${v}</div></div>`).join('')}
  </div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45; padding: 28px 32px; box-sizing: border-box; display: flex; flex-direction: column; gap: 28px">
  <div style="display: flex; align-items: baseline; gap: 14px">
    <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">提示词条与节点文字</div>
    <div style="color: ${T.fg4}">画布里的两处文本框：底部的提示词条随窗口尺寸变宽变窄，节点卡里的提示词换成能读的排版</div>
  </div>
  <div style="display: flex; gap: 40px">
    <div style="flex: none">${sectionA}</div>
    <div style="flex: 1; min-width: 0">${sectionLive}</div>
  </div>
  ${sectionB}
  ${sectionC}
  ${specBlock}
</div>`;

const logic = `
class Component extends DCLogic {
  constructor(props) {
    super(props);
    this.state = { text: '拂晓，雾江上一叶孤舟，渔夫站在船头收网。\\n镜头从远景缓推到中景。' };
  }
  renderVals() {
    const text = this.state.text || '';
    // 估行数：每段按 13px 汉字宽度折行，内宽 ≈ 580
    const perLine = Math.floor(580 / 13);
    let lines = 0;
    for (const p of text.split('\\n')) lines += Math.max(1, Math.ceil(p.length / perLine));
    const rows = Math.min(8, Math.max(1, lines));
    return {
      text: text,
      rows: rows,
      areaStyle: lines > 8 ? 'overflow-y: auto' : 'overflow-y: hidden',
      count: text.replace(/\\s/g, '').length + ' 字',
      onText: (e) => this.setState({ text: e.target.value }),
    };
  }
}
`;

module.exports = { file: 'PromptText.dc.html', html: page('提示词条与节点文字', W, H, body, logic) };
