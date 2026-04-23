# ADR-0006: 视频播放库选用 media_kit

- **Status**: accepted
- **Date**: 2026-04-22
- **Deciders**: P9 (Tech Lead)
- **Related**: PRD §5 / T5 Sprint 方向选型 (`docs/specs/2026-04-22-t5-direction-candidates.md`) / CLAUDE.md Tech Stack

---

## Context

T5 Sprint 已拍板做**视频节点 UI 接入**（6 款视频 Provider 已就绪：Wanx T2V/I2V/R2V + Kling v3 + Kling v3 Omni + Hailuo），用户场景需要：

1. **NodeCard 视频 body**：hover 态播放首帧循环 / 悬浮播放按钮
2. **VideoLightbox 全屏播放**：进度拖拽 / 倍速 / 音量 / 暂停恢复
3. **平台范围**：macOS + Windows（桌面端，不考虑移动端）

**硬约束：**

- Flutter Desktop 官方 `video_player` 插件 macOS / Windows 支持**均未 GA**：macOS 基于老 AVKit 桥有已知 memory leak（flutter/flutter#108646 未修），Windows 基于 WMF 不支持常见容器（WebM / HEVC）。
- 视频 Provider 返回 URL 域名不可控（Wanx 走阿里 OSS 预签，Hailuo 走自家 CDN，Kling 走 DashScope OSS），播放端必须支持 HTTPS range + 多容器（MP4 / WebM / MOV）。
- CLAUDE.md Tech Stack 已登记 `ffmpeg_kit_flutter` 做视频导出——但 `ffmpeg_kit_flutter` **只做转码 / 抽帧，不是播放器**。
- 桌面端必须能渲染到 Flutter Widget 树里（不能开新窗口播放），Lightbox 要叠加在 Canvas 之上。

**已知假设：**

- 用户环境：macOS 13+ / Windows 10+（PRD §16 支持矩阵）
- 视频时长：2 秒 – 10 秒（PRD §5.3 duration 档位）
- 单次 Lightbox 同时播放 ≤ 1 路
- 缩略图走独立 `ThumbnailService`（ffmpeg 抽首帧），**不**依赖播放库

## Decision

**决定：** 用 [`media_kit`](https://pub.dev/packages/media_kit)（基于 libmpv / MPV）作为 InkFrame 所有视频播放的唯一库。

**理由（3 条底层逻辑）：**

1. **双平台 GA 且活跃**：media_kit 是目前 pub.dev 上唯一在 macOS + Windows 都**稳定发版**（1.x）、月活提交的 Flutter 桌面视频方案；官方 `video_player` 桌面端仍在 `_windows` / `_macos` 分治 alpha。
2. **容器与协议全覆盖**：libmpv 原生支持 MP4 / WebM / MOV / HLS / DASH + HTTPS range + 硬解，不会被 Provider 的 CDN 返回格式卡住。
3. **API 与 Flutter Widget 树原生结合**：`Player` + `VideoController` + `Video` widget 三件套，能直接嵌到 NodeCard 的小缩略图和 Lightbox 的全屏 View，不用开原生窗口，避开 `video_player` 桌面端的 PiP 窗口问题。

## Consequences

**好的：**
- 一套 API 打通 macOS + Windows，Lightbox 和 NodeCard hover 预览复用同一个 `Player` 实例池
- 支持 HTTPS 流式播放（range request），不用提前全量下载到磁盘，和 VideoDownloadService 的"用户主动下载"语义解耦
- libmpv 硬解，2-10 秒短视频启播延迟 < 200 ms

**坏的 / 欠的债：**
- ⚠️ **二进制体积**：打包后 macOS `.app` 增 ~35 MB（libmpv dylib），Windows 增 ~45 MB（libmpv.dll + 依赖）——可接受（PRD 未设包体上限），但需在 Release Notes 提示
- ⚠️ **plugin registrant 污染**：引入 `media_kit_libs_macos_video` / `media_kit_libs_windows_video` 会动 `macos/Flutter/GeneratedPluginRegistrant.swift` 和 `windows/flutter/generated_plugin_registrant.cc`——generated 文件变更必须进 commit
- ⚠️ **libmpv 许可**：LGPL-2.1，动态链接合规但需要在 About 页加 license 声明（TD-003 登记）

**中性的（需要持续观察的）：**
- 启动时首个 Player 实例的 libmpv 初始化 ~80-120 ms，需要在 NodeCard hover 前预热（S5 slice 处理）
- Player 实例数超过 3 时内存占用明显上升，需要 LRU 池化（S5 slice 预留 hook）

## Alternatives Considered

### 方案 A: 官方 `video_player` + 桌面子插件
- 优势：Flutter 官方维护，移动端回用 API 一致
- 否决理由：macOS 子插件 memory leak 未修（flutter#108646）；Windows 子插件不支持 WebM / HEVC，Provider CDN 返回的容器没法保证；桌面端仍然标 alpha。

### 方案 B: `flutter_vlc_player`
- 优势：VLC 内核，容器支持齐全
- 否决理由：仅 iOS/Android maintained，桌面端 fork 散乱，最近一次桌面端发版 > 10 个月；和 CLAUDE.md "活跃维护" 要求相悖。

### 方案 C: 纯 `ffmpeg_kit_flutter` + 自绘帧
- 优势：已在 tech stack，无新增依赖
- 否决理由：`ffmpeg_kit_flutter` 是转码 SDK 不是播放器——要自己写 demuxer + 音视频同步 + 渲染管线，工作量 > 整个 T5 Sprint；典型"造轮子跑偏"。

### 方案 D: 走原生 macOS AVPlayer + Windows MediaPlayer 双端各自实现
- 优势：系统原生，性能最优
- 否决理由：需要写两套 platform channel + 两套 widget 嵌入层；维护成本 2×；和 SOLID D（依赖抽象）冲突，Flutter 层要再包一层适配。

## Revisit Triggers

- 当 Flutter 官方 `video_player` 桌面端升级到 stable 且覆盖 WebM / HEVC
- 当 media_kit 连续 2 个季度无 release（仓库进入维护模式）
- 当单 Player 实例内存占用 > 150 MB（libmpv 解码管线异常）
- 至迟在 **2026-10-22** 前重审（T5 上线后半年）

## 影响文件

- `pubspec.yaml`：新增 `media_kit` + `media_kit_video` + `media_kit_libs_macos_video` + `media_kit_libs_windows_video` 依赖
- `macos/Flutter/GeneratedPluginRegistrant.swift`：由 `flutter pub get` 自动更新（入 commit）
- `windows/flutter/generated_plugin_registrant.cc` + `windows/flutter/generated_plugins.cmake`：同上
- `lib/services/video_player_service.dart`（T5-S5 新增）：封装 `Player` 实例池 + LRU
- `lib/features/canvas/widgets/video_lightbox.dart`（T5-S5 新增）：全屏 Lightbox
- `docs/adr/0000-index.md`：登记 ADR-0006
- `docs/CLAUDE.md` Tech Stack 段：`Video Playback: media_kit`（后续 PR 补）
