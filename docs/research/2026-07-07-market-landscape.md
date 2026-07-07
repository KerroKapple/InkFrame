# 调研存档:竞品与市场格局(2026-07-07)

> 上线前竞品/分发/冷启动调研的完整原始报告。摘要与行动项见 `docs/MASTERPLAN.md` §1。

## 竞品功能水位表

| 产品 | 形态 | 分镜/叙事 | 画布 | Local-first? | 价格 | InkFrame 差异点 |
|---|---|---|---|---|---|---|
| LTX Studio | 云套件 | **最强**:剧本→自动拆镜→动态分镜(导出 MP4/PDF);Elements 角色一致性 | 时间线非节点 | 否 | $15/$35/$125/月 credit | 数据不出本机;无 credit 加价;自由编排 |
| Flora (FloraFauna) | 云,节点画布 | 模板,无叙事层;FAUNA agent(2026-04,$52M a16z) | **节点无限画布**,50-60+ 模型 | 否 | $18/$54/$200/月 | 同画布但全云抽成;我们本地+直连 |
| Krea | 云套件 | 弱 | Realtime Canvas(<50ms)+ Node Agent(2026-02) | 否 | 订阅+credit | 实时性它强(本地难比);我们赢叙事管理+数据主权 |
| Freepik AI Suite | 云套件 | Storyboard 模式(3×3 关键帧→视频) | 无节点 | 否 | credit,39 图+36 视频模型 | 无工作流深度 |
| InvokeAI | 开源桌面(Apache 2.0) | 无(纯图像) | 图层式 Canvas | 是(本地 GPU) | 免费;商业版 $19/$49/月;**托管平台已关,团队入 Adobe,社区接管** | 我们做视频叙事+云模型 BYOK |
| ComfyUI | 开源桌面;Comfy Org **$30M 融资/$500M 估值(2026-04)** | 无叙事层 | **节点图鼻祖**;API Nodes 调闭源模型(抽成) | 是(本地推理) | 免费+云/API 抽成 | 学习曲线是它公认痛点;我们=开箱即用分镜工作室,BYOK 零抽成 |
| Recraft | 云无限画布 | 无 | 设计向(V4,2026-02) | 否 | $10/月起 | 赛道不同(设计资产) |
| Kaiber Superstudio | 云 | 弱 | 无限画布+节点,多模型 | 否 | $10-99/月 credit | 全云 credit,无 BYOK |
| Weavy→**Figma Weave** | 云节点画布 | 无 | 节点工作流 | 否 | credit | **2025-10 被 Figma ~$200M 收购**——范式被重金验证,local-first 位置让出 |
| 即梦(字节) | 云+App | **强**:Seedance 2.0 九宫格分镜→一键成片;剪映集成 | 智能画布 | 否 | 免费额度+订阅 | 云生态封闭 Key 不可自带;其模型可被我们编排 |
| 可灵(快手) | 云 | **强**:3.0 智能分镜多镜头(2026-05);6000 万创作者,年化 $2.4 亿 | 无节点 | 否 | credit | 「模型即导演」vs 我们「你当导演的本地工作台」;已有 kling provider |
| **NodeTool** ⚠️ | **开源桌面(Electron,AGPL)** | 有 storyboard 工作流用例 | 节点画布,16+ provider + 本地模型 | **是,BYOK 无抽成** | 免费 | **最直接近邻**:口号 "Every model. Your keys. Your canvas." 与我们几乎重合;424★ v0.7-RC 活跃;但泛工作台非叙事优先,成熟度低 |
| PAI Pro / Inline-Studio | 开源桌面 | PAI Pro:画布+时间线+角色持久,**须配 coding agent** | 节点 | 是 | 免费 | 314/149★ 早期;验证"local AI filmmaking"需求存在 |
| Open-Generative-AI | 开源(MIT,22.6k★) | storyboard 标 upcoming | 节点管线 | 自托管,BYOK 只对接单聚合商 | 免费 | star 多深度浅 |

## 桌面 local-first 的结构性优势(用于叙事)
数据主权(NDA 前期物料不上云)、BYOK 直连零加价(全行业只有 NodeTool 和我们承诺)、
本地文件系统+ffmpeg 导出(云平台限时长/排队)、无席位月费、可后续混编本地模型。

## 分发与商业模式
- 渠道:**GitHub Releases(主)+ winget + Homebrew cask**;MAS/微软商店暂缓(内嵌 PG 子进程+外部 ffmpeg 沙盒风险)。
- 模式:✅ 开源+赞助 → 远期团队版(InvokeAI $19/$49 模式);个人**永久全功能免费**(LM Studio 路线);
  ❌ credit 转售;⚠️ 云增值只能做可选便利层且明示可绕过。
- 许可证需尽早拍板:Apache 2.0(利采用)vs AGPL(防云厂商白嫖)。

## 冷启动 playbook(按投入产出)
1. **Show HN**:提前攒 karma(零 karma Show HN 有分钟级被删案例);周二-四 9:00-12:00 ET;标题中性;
   首小时逐条回复;备好「为什么不用 Electron/为什么内嵌 Postgres」答辩;landing 秒开无追踪脚本。
2. **Reddit r/StableDiffusion + r/aivideo + r/LocalLLaMA**:完整工作流复现帖(剧本→节点图→成片),非广告体;
   社区共识是多模型 workflow stack,反 slop、重开源。
3. **X build-in-public**:30-90s demo,前 5-7 秒先出成片再倒叙;静音可看(动态字幕互动高 70%);硬切。
4. **B站长教程 + 小红书长尾词**(「AI 分镜 本地」「可灵 API 工作流」,前十条赞<500 的词);可与 AI 测评
   KOL(秋芝2046 类,245 万粉级)合作送测;国内 local-first 叙事全新。
5. Product Hunt 不押注(日均 500+ 产品 indie 被淹);同周铺 Uneed/Fazier/Smol Launch。
6. 素材:主 demo、两张对比图(vs ComfyUI/vs 云价目表)、3-5 个单功能 GIF、双语 README(已有)、
   一键示例项目、秒开 landing。

## 定位验证:半空位
- ⚠️ 英文口号撞车 NodeTool("Every model. Your keys. Your canvas.");该交叉点已非无人区但没人做成
  (全部 <500★,无产品级打磨、无叙事优先)。
- ✅ 「**分镜/故事优先的本地工作室**」无人齐备;✅ 中文市场全空(即梦/可灵全云,无 local-first BYOK
  桌面工具面向中文用户,且我们已内置 Kling/Wanx)。
- 措辞:主口号建议 "The local-first AI storyboard studio — your script, your keys, your machine";
  不用「唯一/first」绝对化(HN 会打脸);差异化永不锚定生成质量(可灵/即梦的智能分镜是模型层能力,
  我们编排它们)。

## 关键来源(节选)
LTX ltx.io/studio;Flora florafauna.ai($52M 见 arturmarkus.com);Krea docs.krea.ai;InvokeAI GitHub README
(托管关闭/团队入 Adobe);ComfyUI $500M(TechCrunch 2026-04-24);Figma 收购 Weavy(figma.com/blog);
即梦 Seedance 2.0 分镜实测(news.qq.com 2026-02);可灵 3.0(sina 2026-05-11);NodeTool nodetool.ai +
GitHub(424★,2026-07-02 活跃);LM Studio free-for-work;winget-pkgs;Blender Dev Fund;
HN 发布指南 markepear.dev;PH 替代 getlaunchlist.com;小红书 AI 运营 xiangyugongzuoliu.com。

**未能核实**:即梦具体定价;Ollama 融资额(口径矛盾);ComfyUI 许可证表述冲突(引用前查 repo LICENSE);
NodeTool 用户量(仅 star 数)。
