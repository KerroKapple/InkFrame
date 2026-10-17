// 画板 2：通知卡片 + 提示音设置（1280×1000，可交互）
const { T, IMG, SANS, MONO, page, ic, CHIME_JS, TOAST_ENGINE_JS, TOAST_STACK } = require('./common.js');

const W = 1280, H = 1000;

const h2 = (t) => `<div style="font-size: 12px; font-weight: 500; color: ${T.fg1}; margin: 22px 0 10px">${t}</div>`;
const trigger = (key, label, hint) => `
  <button class="hov" type="button" onClick="{{ fire.${key} }}" style="height: 40px; padding: 0 12px; border-radius: 4px; border: 1px solid ${T.controlStrong}; background: ${T.s3}; display: flex; flex-direction: column; justify-content: center; gap: 1px">
    <span style="color: ${T.fg2}">${label}</span><span style="font-size: 10px; color: ${T.fg5}">${hint}</span>
  </button>`;
const choice = (group, key, label) => `
  <button type="button" onClick="{{ pick.${group}.${key} }}" style="height: 28px; padding: 0 12px; border-radius: 3px; font-size: 12px; display: flex; align-items: center; gap: 6px; {{ cs.${group}.${key} }}">${label}</button>`;
const playBtn = (key, label) => `
  <button class="hov" type="button" onClick="{{ audition.${key} }}" aria-label="试听 ${label}" style="height: 28px; padding: 0 10px; border-radius: 3px; border: 1px solid ${T.controlStrong}; display: flex; align-items: center; gap: 6px; color: ${T.fg2}">${ic('run', 12)}<span>${label}</span></button>`;
const box = (inner) => `<div style="background: ${T.s2}; border: 1px solid ${T.control}; border-radius: 4px; padding: 12px 14px; display: flex; flex-direction: column; gap: 10px">${inner}</div>`;
const specRow = (k, v) => `<div style="display: grid; grid-template-columns: 92px minmax(0, 1fr); gap: 12px; padding: 6px 0; border-bottom: 1px solid ${T.bSubtle}"><div style="color: ${T.fg4}">${k}</div><div style="color: ${T.fg2}">${v}</div></div>`;

const left = `
<div style="position: absolute; left: 32px; top: 28px; width: 536px; bottom: 28px; overflow: hidden">
  <div style="font-size: 17px; font-weight: 500; color: ${T.fg1}">通知 · 右下角卡片</div>
  <div style="color: ${T.fg4}; margin-top: 6px; line-height: 1.6">替换现在屏幕底部居中、一次只能显示一条的提示条。生成、导出这类后台事件完成时，从窗口右下角滑入，响一声。</div>

  ${h2('触发一条看看')}
  <div style="display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 8px">
    ${trigger('success', '生成完成', '带作品缩略图 · 4 秒')}
    ${trigger('export', '导出完成', '打开文件夹 · 4 秒')}
    ${trigger('error', '生成失败', '不自动消失')}
    ${trigger('undo', '删除了节点', '带撤销 · 8 秒 · 不响')}
    ${trigger('progress', '长任务进度', '原地更新，跑完变完成')}
    ${trigger('warning', 'API Key 无效', '警告 · 6 秒')}
    ${trigger('burst', '连发 5 条', '看堆叠：最多露 3 张')}
    ${trigger('merge', '4 镜接连完成', '2 秒内合并成一张')}
  </div>

  ${h2('设置 › 常规 › 通知')}
  ${box(`
    <div style="display: flex; align-items: center; gap: 12px">
      <div style="width: 64px; color: ${T.fg2}">提示音</div>
      <div style="display: flex; gap: 6px; flex-wrap: wrap">
        ${choice('sound', 'inkframe', 'InkFrame 默认')}${choice('sound', 'system', '系统提示音')}${choice('sound', 'custom', '自定义…')}${choice('sound', 'off', '关闭')}
      </div>
    </div>
    <sc-if value="{{ soundInk }}" hint-placeholder-val="{{ true }}">
      <div style="display: flex; align-items: center; gap: 12px">
        <div style="width: 64px; color: ${T.fg4}">音色</div>
        <div style="display: flex; gap: 6px">
          ${choice('variant', 'a', 'A 双音上行')}${choice('variant', 'b', 'B 单音气泡')}${choice('variant', 'c', 'C 三音琶音')}
        </div>
      </div>
      <div style="padding-left: 76px; font-size: 11px; color: ${T.fg5}; line-height: 1.6">三个都是原创合成（不含任何第三方录音）。A 是默认：两个音往上走，短、软，读作「好了」。点选项即试听。</div>
    </sc-if>
    <sc-if value="{{ soundSystem }}" hint-placeholder-val="{{ false }}">
      <div style="padding-left: 76px; font-size: 11px; color: ${T.fg4}; line-height: 1.6">Windows 播放系统「通知」声音，macOS 播放系统「提示音」；换声音、调音量都在系统设置里。<br><span style="color: ${T.fg5}">网页里放不出系统声音，到应用里再试听。</span></div>
    </sc-if>
    <sc-if value="{{ soundCustom }}" hint-placeholder-val="{{ false }}">
      <div style="display: flex; align-items: center; gap: 10px; padding-left: 76px">
        <div style="height: 28px; padding: 0 10px; border-radius: 3px; border: 1px solid ${T.outline}; background: ${T.s3}; display: flex; align-items: center; gap: 8px; color: ${T.fg2}">${ic('sound', 14)}<span style="font-family: ${MONO}; font-size: 11px">ding.wav</span><span style="font-size: 10px; color: ${T.fg5}">48 KB · 0.6 秒</span></div>
        <div style="height: 28px; padding: 0 10px; border-radius: 3px; border: 1px solid ${T.controlStrong}; display: flex; align-items: center; color: ${T.fg2}">更换…</div>
      </div>
      <div style="padding-left: 76px; font-size: 11px; color: ${T.fg5}; line-height: 1.6">支持 wav / mp3 / ogg / m4a，不超过 2 MB，只播前 4 秒。选中的文件会复制进数据目录，原文件挪走也不受影响。</div>
    </sc-if>
    <div style="display: flex; align-items: center; gap: 12px">
      <div style="width: 64px; color: ${T.fg2}">停留时长</div>
      <div style="display: flex; gap: 6px">${choice('dwell', 'standard', '标准')}${choice('dwell', 'long', '加长')}${choice('dwell', 'never', '不自动关闭')}</div>
    </div>
  `)}

  ${h2('规格')}
  <div style="font-size: 11px">
    ${specRow('位置', '窗口右下，离右边 16、离状态栏 16；缩放条挪到画布左下，把这个角让出来')}
    ${specRow('卡片', '宽 360 · 内边距 12 · 卡间距 8 · 圆角 6 · 浮层底色加描边和阴影；类型靠图标区分，不铺整张彩色底')}
    ${specRow('内容', '左 40×40：作品缩略图，没有就放类型图标 · 标题最多 2 行 · 正文最多 2 行 · 元信息一行 · 动作最多 2 个')}
    ${specRow('动效', '从下往上滑入 16 + 淡入 200ms；淡出 + 下移 8，150ms；系统开了「减少动态效果」就只淡入淡出')}
    ${specRow('堆叠', '最新的贴着角落，最多露 3 张，其余收成「还有 N 条」，点开铃铛看全部')}
    ${specRow('时长', '提示 / 完成 4 秒 · 警告 6 秒 · 撤销 8 秒 · 失败不自动消失 · 进度卡跑完后按完成重新计时')}
    ${specRow('暂停', '鼠标停在通知区、键盘焦点在通知区、窗口失焦时，全部暂停计时')}
    ${specRow('合并', '同一个任务只更新原卡；2 秒内接连完成的同类结果合成一张「N 个镜头已生成」')}
    ${specRow('响不响', '后台事件到达才响：生成、导出、下载、更新。你自己刚做的操作（删除、复制、保存）不响。1.2 秒内最多响一次')}
    ${specRow('历史', '铃铛里保留本次会话最近 100 条，有未读时铃铛带点，有未读失败时点变红')}
  </div>
</div>`;

const preview = `
<div style="position: absolute; left: 600px; top: 28px; width: 648px; height: 944px; border-radius: 6px; border: 1px solid ${T.outline}; overflow: hidden; background-color: ${T.s1}; background-image: linear-gradient(${T.grid} 1px, transparent 1px), linear-gradient(90deg, ${T.grid} 1px, transparent 1px); background-size: 24px 24px">
  <div style="position: absolute; left: 0; right: 0; top: 0; height: 30px; background: ${T.s4}; border-bottom: 1px solid ${T.bStrong}; display: flex; align-items: center; gap: 8px; padding: 0 8px 0 12px">
    <div style="width: 16px; height: 16px; border-radius: 3px; background: ${T.accent}; color: ${T.onAccent}; font-size: 9px; font-weight: 700; display: flex; align-items: center; justify-content: center">If</div>
    <div style="color: ${T.fg3}; font-size: 11px">窗口右下角预览</div>
    <div style="flex: 1"></div>
    <button class="hov" type="button" aria-label="通知" onClick="{{ toggleBell }}" style="position: relative; width: 26px; height: 24px; border-radius: 4px; display: flex; align-items: center; justify-content: center; color: ${T.fg3}; {{ bellBtnStyle }}">
      ${ic('bell', 16)}
      <sc-if value="{{ hasUnread }}" hint-placeholder-val="{{ false }}"><div style="position: absolute; top: 3px; right: 4px; width: 6px; height: 6px; border-radius: 3px; {{ dotStyle }}; box-shadow: 0 0 0 2px ${T.s4}"></div></sc-if>
    </button>
  </div>
  <div style="position: absolute; left: 0; right: 0; bottom: 0; height: 22px; background: ${T.s4}; border-top: 1px solid ${T.bStrong}; display: flex; align-items: center; padding: 0 12px; font-size: 10px; color: ${T.fg5}">状态栏</div>
  <sc-if value="{{ bellOpen }}" hint-placeholder-val="{{ false }}">
  <div class="pop" style="position: absolute; right: 8px; top: 34px; width: 360px; max-height: 520px; overflow: hidden; background: ${T.s4}; border: 1px solid ${T.overlayBorder}; border-radius: 6px; box-shadow: 0 24px 64px rgba(0,0,0,0.6); z-index: 50">
    <div style="height: 38px; display: flex; align-items: center; gap: 12px; padding: 0 12px; border-bottom: 1px solid ${T.bStrong}">
      <div style="font-weight: 500; color: ${T.fg1}">通知</div><div style="flex: 1"></div>
      <button class="hovfg" type="button" onClick="{{ clearHistory }}" style="font-size: 11px; color: ${T.fg4}">清空</button>
    </div>
    <sc-if value="{{ historyEmpty }}" hint-placeholder-val="{{ false }}"><div style="padding: 28px 12px; text-align: center; color: ${T.fg5}; font-size: 11px">还没有通知</div></sc-if>
    <sc-for list="{{ historyView }}" as="h" hint-placeholder-count="3">
      <div style="display: flex; gap: 10px; padding: 8px 12px; align-items: center">
        <sc-if value="{{ h.hasThumb }}" hint-placeholder-val="{{ false }}"><img src="{{ h.thumb }}" alt="" style="width: 32px; height: 32px; object-fit: cover; border-radius: 3px"></sc-if>
        <sc-if value="{{ h.noThumb }}" hint-placeholder-val="{{ true }}"><div style="width: 32px; height: 32px; border-radius: 3px; background: ${T.s5}; display: flex; align-items: center; justify-content: center; {{ h.tile }}">${ic('bell', 16)}</div></sc-if>
        <div style="flex: 1; min-width: 0"><div style="color: ${T.fg2}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{{ h.title }}</div><div style="font-size: 10px; color: ${T.fg5}; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">{{ h.body }}</div></div>
        <div style="font-size: 10px; color: ${T.fg6}">{{ h.when }}</div>
      </div>
    </sc-for>
  </div>
  </sc-if>
  ${TOAST_STACK('right: 16px; bottom: 38px')}
</div>`;

const body = `
<div style="width: ${W}px; height: ${H}px; position: relative; overflow: hidden; background: ${T.s2}; color: ${T.fg2}; font-family: ${SANS}; font-size: 12px; line-height: 1.45">
  ${left}
  ${preview}
</div>`;

const logic = `
class Component extends DCLogic {
  constructor(props) {
    super(props);
    this.state = {
      sound: 'inkframe', variant: 'a', dwell: 'standard', bell: false, hover: false, seq: 2, unread: 0, started: false, lastChime: 0,
      toasts: [
        { id: 1, kind: 'export', title: '导出完成', body: '示例项目_画布1.mp4 · 12.4 MB · 00:15', meta: '示例项目 · 刚刚', a1: '打开文件夹', sticky: true, remaining: 4000, total: 4000, progress: 0 },
        { id: 2, kind: 'success', title: '镜头 01 已生成', body: '水墨风格 · 图像 · 用时 18 秒', meta: '示例项目 · 画布 1 · 刚刚', thumb: '${IMG.thumbMountain}', a1: '查看', a2: '再来一张', sticky: true, remaining: 4000, total: 4000, progress: 0 },
      ],
      history: [],
    };
  }
  componentDidMount() { this.timer = setInterval(() => this.tickToasts(), 100); }
  componentWillUnmount() { clearInterval(this.timer); }
  chimeNow() {
    const now = Date.now();
    if (now - (this.lastChime || 0) < 1200) return;
    this.lastChime = now;
    if (this.state.sound === 'inkframe') this.playChime(this.state.variant);
  }
  toastAction(t, which) { this.closeToast(t.id); }
  start() {
    if (this.state.started) return;
    this.setState({ started: true, toasts: this.state.toasts.map((x) => Object.assign({}, x, { sticky: false })) });
  }
  fire(kind) {
    this.start();
    const P = (t) => this.pushToast(t);
    if (kind === 'success') P({ kind: 'success', title: '镜头 03 已生成', body: '水墨风格 · 图像 · 用时 21 秒', meta: '示例项目 · 画布 1 · 刚刚', thumb: '${IMG.thumbMountain}', a1: '查看', a2: '再来一张', chime: true });
    if (kind === 'export') P({ kind: 'export', title: '导出完成', body: '示例项目_画布1.mp4 · 12.4 MB · 00:15', meta: '示例项目 · 刚刚', a1: '打开文件夹', a2: '打开文件', chime: true });
    if (kind === 'error') P({ kind: 'error', title: '镜头 02 生成失败', body: '服务商返回 429：请求太频繁，稍后重试即可。', meta: '万相 2.2 · 示例项目 · 画布 1', a1: '重试', a2: '查看详情', chime: true });
    if (kind === 'undo') P({ kind: 'undo', title: '已删除 2 个节点', body: '卡片消失后 Ctrl Z 仍可撤销', a1: '撤销' });
    if (kind === 'progress') P({ kind: 'progress', title: '镜头 04 · 生成中', body: 'Gemini · 图像 · 4 张', meta: '示例项目 · 画布 1', rate: 2.5, dedupe: 'job-4', a1: '在任务中查看', a2: '取消',
      done: { title: '镜头 04 已生成', body: '4 张 · 用时 38 秒', thumb: '${IMG.thumbWide}', a1: '查看', a2: '再来一组', chime: true } });
    if (kind === 'warning') P({ kind: 'warning', title: '万相的 API Key 无效', body: '密钥被服务商拒绝，后面的生成已暂停。', a1: '去设置', chime: true });
    if (kind === 'burst') {
      const items = [
        { kind: 'success', title: '镜头 05 已生成', body: '图像 · 用时 17 秒', thumb: '${IMG.thumbWide}', a1: '查看', chime: true },
        { kind: 'info', title: '已复制 3 个节点' },
        { kind: 'warning', title: '参考图超出上限', body: 'Gemini 最多 3 张，第 4 张没有发送' },
        { kind: 'export', title: '导出完成', body: '片段_02.mp4 · 4.1 MB', a1: '打开文件夹' },
        { kind: 'success', title: '镜头 06 已生成', body: '图像 · 用时 19 秒', thumb: '${IMG.thumbMountain}', a1: '查看' },
      ];
      items.forEach((t, i) => setTimeout(() => P(t), i * 260));
    }
    if (kind === 'merge') {
      for (let i = 0; i < 4; i++) setTimeout(() => this.mergeDone(i), i * 420);
    }
  }
  mergeDone(i) {
    const live = this.state.toasts.find((x) => x.merge === 'batch' && !x.leaving);
    if (live) {
      const n = live.count + 1;
      this.setState({ toasts: this.state.toasts.map((x) => x === live ? Object.assign({}, x, { count: n, title: n + ' 个镜头已生成', body: '镜头 07–' + (6 + n) + ' · 水墨风格', remaining: x.total }) : x) });
      return;
    }
    this.pushToast({ kind: 'success', merge: 'batch', count: 1, title: '镜头 07 已生成', body: '水墨风格 · 图像', thumb: '${IMG.thumbWide}', a1: '查看', chime: true });
  }
${CHIME_JS}
${TOAST_ENGINE_JS}
  renderVals() {
    const s = this.state;
    const on = 'background: ${T.accent}; color: ${T.onAccent}; font-weight: 500';
    const off = 'border: 1px solid ${T.controlStrong}; color: ${T.fg2}';
    const cs = { sound: {}, variant: {}, dwell: {} };
    for (const k of ['inkframe', 'system', 'custom', 'off']) cs.sound[k] = s.sound === k ? on : off;
    for (const k of ['a', 'b', 'c']) cs.variant[k] = s.variant === k ? on : off;
    for (const k of ['standard', 'long', 'never']) cs.dwell[k] = s.dwell === k ? on : off;
    const pick = { sound: {}, variant: {}, dwell: {} };
    for (const k of Object.keys(cs.sound)) pick.sound[k] = () => { this.setState({ sound: k }); if (k === 'inkframe') this.playChime(s.variant); };
    for (const k of Object.keys(cs.variant)) pick.variant[k] = () => { this.setState({ variant: k }); this.playChime(k); };
    for (const k of Object.keys(cs.dwell)) pick.dwell[k] = () => this.setState({ dwell: k });
    const fire = {};
    for (const k of ['success', 'export', 'error', 'undo', 'progress', 'warning', 'burst', 'merge']) fire[k] = () => this.fire(k);
    const kindColor = { success: '${T.success}', export: '${T.fg3}', error: '${T.danger}', warning: '${T.accent}', info: '${T.fg4}', undo: '${T.fg3}' };
    const unreadError = (s.history || []).slice(0, s.unread || 0).some((h) => h.kind === 'error');
    return {
      cs: cs, pick: pick, fire: fire,
      soundInk: s.sound === 'inkframe', soundSystem: s.sound === 'system', soundCustom: s.sound === 'custom',
      bellOpen: s.bell, hasUnread: (s.unread || 0) > 0,
      dotStyle: 'background: ' + (unreadError ? '${T.danger}' : '${T.accent}'),
      bellBtnStyle: s.bell ? 'background: ${T.s5}; color: ${T.fg1}' : '',
      toggleBell: () => this.setState({ bell: !s.bell, unread: 0 }),
      openBell: () => this.setState({ bell: true, unread: 0 }),
      clearHistory: () => this.setState({ history: [], unread: 0 }),
      historyEmpty: (s.history || []).length === 0,
      historyView: (s.history || []).map((h) => ({ title: h.title, body: h.body, when: h.when, thumb: h.thumb, hasThumb: !!h.thumb, noThumb: !h.thumb, tile: 'color: ' + (kindColor[h.kind] || '${T.fg4}') })),
      tv: this.toastView(),
      stackEnter: () => this.setState({ hover: true }),
      stackLeave: () => this.setState({ hover: false }),
    };
  }
}
`;

module.exports = { file: 'Toasts.dc.html', html: page('通知卡片与提示音', W, H, body, logic) };
