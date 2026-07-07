# 调研存档:AIGC 模型 API 格局(2026-07-07)

> 上线前模型接入调研的完整原始报告。摘要与行动项见 `docs/MASTERPLAN.md` §6。
> 信息以 2026 年上半年检索为准,来源附文末;标注「未能核实」处勿当结论引用。

## 图像模型

| 模型/版本 | 最新版(时间) | API 形态 | 关键能力 | 价格量级 | OpenAI 兼容? | 接入建议 |
|---|---|---|---|---|---|---|
| OpenAI GPT Image 2 | 2026-04-21 发布;gpt-image-1.5 为前旗舰;**gpt-image-1 于 2026-10-23 弃用** | 同步 `/v1/images/generations`、`/images/edits`、`/responses`;SSE 流式部分预览 | thinking mode(生成前规划/联网找参考/自检)、~99% 字符级文字准确率(含 CJK)、4K、多轮编辑 | $0.005–0.21/图;1.5 标准档 ~$0.04/图 | 是(本尊) | **内置(已有)——P0 升级模型 ID,gpt-image-1 死线在前** |
| Google Nano Banana 系(Gemini 图像) | Nano Banana 2(2026-02-26)、NB Pro(=Gemini 3 Pro Image)、NB 2 Lite | Gemini `generateContent` 同步;另有 beta OpenAI 兼容端点 `/v1beta/openai/images/generations` | NB Pro:**最多 14 张参考图、最多 5 人角色一致性**、2K/4K、强文字渲染、studio 控制 | NB2 $0.045 起、Lite ~$0.034、Pro $0.134(1–2K)/$0.24(4K) | 部分(beta 兼容层) | **内置(已有)——P0 升级 NB2/NB Pro;14 参考图是分镜角色一致性刚需** |
| FLUX.2(BFL) | pro/flex/dev(32B 开源)/klein(4B,2026-01) | BFL 自有 REST(按 megapixel) | **最多 10 张参考图**、4MP 生成+编辑一体、强文字/版式;klein 亚秒级 | max 档首 MP $0.07 | 否(可经 OpenRouter) | 模板(OpenRouter/fal),暂不原生内置 |
| Stability | 仍 SD 3.5 世代;Stable Image Core/Ultra | 同步 REST(multipart) | Elo 已落后第一梯队(~1150-1180 vs GPT Image 1.5 的 1264) | 按图,便宜档 | 否 | 内置(已有)——维持,不加投入 |
| 字节 Seedream | 4.5(4K 编辑/多图合成/小字);**5.0 Lite(2026-02-13)**:多模态思考+联网+多轮图文编辑 | Volcano Ark / BytePlus ModelArk(兼容性未核实) | 编辑一致性、多参考图、4K | 4.5 $0.04/图;5.0 Lite $0.035/图 | 未核实 | **P1:模板优先(OpenRouter 已收录),量大再原生** |
| 阿里通义 | wan2.6-image / wan2.7-image-pro(4096²)、qwen-image-2.0/2.0-pro(中英文字渲染) | DashScope 同步+异步 | 合成图、编辑、文字渲染强 | 百炼按图,量级低 | **否(LiteLLM issue 证实 images 不能走兼容层)** | **内置(已有)——P0 升级模型 ID,复用现有 DashScope 基类** |
| 腾讯混元 | HunyuanImage 3.0(80B MoE 开源;3.0-Instruct 2026-01) | 云 API 存在,定价未能核实 | 开源最强之一 | 未能核实 | 否 | 不接(能力被覆盖;开源自托管非 InkFrame 场景) |
| Recraft | V4 / V4 Pro / V4.1 | **OpenAI 兼容:`https://external.api.recraft.ai/v1/images/generations`,已验证可直接用 OpenAI SDK** | 矢量、inpaint/outpaint、去背景、品牌风格 | V4 $0.04/图,Pro $0.25/图 | **是(已验证)** | **零代码解锁:写进「自定义 provider 已验证端点」文档(P1)** |
| Ideogram | 4.0(2026-06-03,开放权重,原生 2K) | 自有 API | 文字渲染最强(OCR ~0.97) | $0.03–0.10/图 | 否 | 不接;需要时走 fal/Replicate(文字渲染已被 GPT Image 2/qwen-image 覆盖) |

## 视频模型

| 模型/版本 | 最新版(时间) | API 形态 | 关键能力 | 价格量级 | 接入建议 |
|---|---|---|---|---|---|
| Kling | **3.0 世代(2026-02-04):Video 3.0/3.0 Omni/Image 3.0/Image 3.0 Omni;3.0 Turbo(2026-06-17)**;Motion Control 3.0 | kling.ai/dev REST 异步 | 15s 多镜头(单 prompt 2–6 shots 智能分镜)、4K/60fps、原生音频+5 语对口型、首尾帧、元素一致性、动作迁移 | 官方 $0.075/s 起;fal Standard $0.084/s | **内置(已有 v3+omni)——补 Turbo 变体与 Motion Control(P0/P1)**。⚠️ 现有 provider 走 DashScope 渠道(非 kling.ai 官方 API);Turbo/Motion Control 以渠道上架为前提 |
| 通义万相 Wan | 2.6(2026-03-28);**wan2.7 已上百炼**(i2v:首帧/首尾帧/视频续写;r2v 参考生视频) | DashScope 异步 create→poll(与现有基类一致) | 1080p24、15s、多镜头、原生音频+对口型、r2v | $0.04–0.07/s | **内置(已有)——P0 升级 2.6/2.7 模型 ID + 首尾帧/续写任务类型**(复审勘正:仓库四件已全在 wan2.7,首尾帧/r2v 已实现;P0 仅剩『视频续写』) |
| Google Veo | 3.1 + 3.1 Fast + **3.1 Lite(最具性价比)** | Gemini API 异步 long-running | **3 张参考图**、首尾帧、**extend 视频延长(1 分钟+)**、原生音频 | Lite ~$0.05/s、Fast $0.15/s、Std $0.40/s | **P1 新内置首选:能力矩阵最贴分镜;可复用 Gemini key 生态** |
| OpenAI Sora | sora-2 / pro | Videos API 异步 | — | $0.10–0.50/s | **不接(红线):2026-03-24 宣布弃用,API 2026-09-24 关停,无后继** |
| Runway | Gen-4.5;Aleph 2(v2v 编辑) | 开发者 API credits | 高质量运动、v2v | ~$0.1–0.25/s(口径冲突) | 不接原生;聚合器(P2) |
| Luma | Ray 3.14(2026-01-26,原生 1080p) | Dream Machine API | HDR、关键帧 | 中档 | 聚合器(P2) |
| MiniMax 海螺 | Hailuo 2.3 + 2.3 Fast | platform.minimax.io 异步 | 风格化(动漫/水墨/游戏 CG)强 | ~$0.19/条起 | P2 模板;CN 用户呼声高再原生 |
| 字节 Seedance | 1.5 Pro;**2.0(2026-02)** | Volcano/BytePlus + **OpenRouter 视频 API 首发** | **9 图+3 视频+3 音频参考**、lens switch 多镜头、影视级运镜 | Fast $0.022/s–Pro $0.247/s | **P1:性价比+参考能力第一梯队;经 OpenRouter/模板,量大再原生** |
| PixVerse | V6(2026-03-30) | 官方 API credits 异步 | 多镜头+音频、15s 1080p、20+ 镜头光学控制 | $0.15–0.40/5s(V5 参考) | P2 聚合器模板 |
| Vidu(生数) | Q3(2026-01-30,16s 音画一体);Q3 r2v(2026-04-13);**已入驻阿里云百炼** | MaaS credits(错峰半价) | **多参考(主体/环境/服装/道具/风格)**、多镜头、6 类 VFX | ~$0.0375/s 量级(2.0 参考) | **P2 靠前:优先验证经百炼接入(可复用 DashScope 通道)** |

## 聚合器

- **OpenRouter(最高价值)**:图像统一 API(2026-06-23,`POST /api/v1/images`,官方宣称 OpenAI 兼容)+
  视频 API(2026-04-15,`POST /api/v1/videos` 异步,归一化含首尾帧/参考图),30+ 图像模型与主流视频模型。
  ⚠️ 注意 `/api/v1/images` 与现有模板 `/images/generations` 的**路径差异**——模板需支持可配端点路径。
- **fal.ai**:1000+ 模型最长尾,但专有队列协议(submit→status→result),非 OpenAI 兼容;做「fal 队列协议模板」放 P2。
- Replicate:2025-11 被 Cloudflare 收购,方向不确定,观望。
- 302.ai:CN 付款友好;图像/视频端点兼容性未核实,先实测。
- 其他镜像(WaveSpeed/Kie 等):不官方支持,文档告知用户可自行填自定义 provider。

## 能力趋势(按分镜工作流价值排序)

1. **单次生成多镜头叙事(multi-shot)成一线标配**(Kling 3.0 智能分镜、Seedance 2.0 lens switch、Wan 2.6、PixVerse V6、Vidu Q3)——范式变化:一个节点产出"一场戏"而非"一个镜头"。
2. **原生音画同步 + 多语对口型**普及 → 节点模型需要"音频开关/音轨"概念。
3. **多模态参考成一致性主战场**(NB Pro 14 图/5 人;Seedance 9 图+3 视频+3 音频;Vidu 多类型参考)→ 画布连线 role 体系需扩展为多参考+参考类型(角色/道具/场景/风格/音色)。
4. **视频延长/续写**(Veo extend、wan2.7 续写)→ 时间线"接着拍"交互。
5. 首尾帧过渡已全行业标配(我们已有,保持)。
6. 动作/运镜迁移(Kling Motion Control 3.0、Wan r2v)。
7. 图像"推理式生成"(GPT Image 2 thinking、Seedream 5.0)→ 多轮编辑链有价值。
8. 文字渲染基本解决;视频编辑模型(Runway Aleph 2 v2v)出现。

## 行动建议(已转任务卡,见 MASTERPLAN §6)

- **P0**:OpenAI 升级 gpt-image-1.5/2(死线 2026-10-23);移除一切 Sora 规划;Gemini 升级 NB2/Pro + 多参考图;
  Wanx(复审勘正:仓库四件已全在 wan2.7,首尾帧/r2v 已实现)仅剩补『视频续写』任务类型;
  Kling 3.0 Turbo 入列(⚠️ 以 DashScope 渠道上架为前提,见视频表)。
- **P1**:Veo 3.1(Lite);OpenRouter 图像模板(可配路径);Recraft 写入已验证端点文档;Seedream/Seedance 经模板。
- **P2**:OpenRouter 视频模板(优先)或 fal 队列模板;Vidu 经百炼验证。
- **横切**:现有 OpenAI 兼容模板仅 t2i、maxRefImages=0——参考图工作流需模板扩展(`/images/edits`/多图输入);
  DashScope 图像**不能**走 OpenAI 兼容层已证实,现有原生 wanx 路线正确。

## 来源(节选,完整见调研记录)

OpenAI:developers.openai.com/api/docs/pricing、/deprecations、openai.com/index/introducing-chatgpt-images-2-0;
Sora 关停:help.openai.com/en/articles/20001152;Google:deepmind.google/models/gemini-image/pro、
developers.googleblog.com(Veo 3.1)、ai.google.dev/gemini-api/docs/openai;BFL:bfl.ai/models/flux-2、/pricing;
Kling:ir.kuaishou.com(3.0 发布)、kling.ai/dev/pricing;Wan/DashScope:help.aliyun.com/zh/model-studio/*、
github.com/BerriAI/litellm/issues/28763;Seedream/Seedance:byteplus.com、seed.bytedance.com、openrouter.ai/bytedance/*;
Recraft:recraft.ai/docs/api-reference、docs.litellm.ai/docs/providers/recraft;Vidu:platform.vidu.com/docs/pricing;
聚合器:openrouter.ai/blog/announcements/image-api、/video-generation、docs.fal.ai、blog.cloudflare.com/replicate-joins-cloudflare。

**未能核实**:混元 3.0 商用 API 定价;Volcano Ark 图像端点 OpenAI 兼容性;302.ai 图像/视频兼容性;
Runway Gen-4.5 单价($0.12 vs $0.25 两口径冲突)。
