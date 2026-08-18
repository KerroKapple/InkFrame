# LB-23 内存基线 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 收口 LB-23 四子项:① 全部缩略场景 `cacheWidth` 解码收敛(4 站点);② ImageCache 上限策略评估并落地;③ perf-baseline.md 内存水位节(方法论+阈值+可测项实测);④ keepAlive 持大对象盘点入档。

**Architecture:** 内存问题的根源排序:未缩解码 > 缓存上限 > 常驻对象。先修解码(一张 2048² 原图全解码 16MB,缩到 220px tile 只要 ~0.8MB,20 倍差),再定缓存上限(修完解码后才知道真实工作集),最后盘点常驻。lightbox 是**有意豁免**:InteractiveViewer 要缩放,必须全分辨率。

**Tech Stack:** `Image.file(cacheWidth:)`(既有 node_card/video_node_body 同款,ME-26 先例)、`PaintingBinding.instance.imageCache`、widget test 断言 `ResizeImage`(照抄 generation_render_node_e2e_test.dart:110 解包模式)。

**实测口径的诚实边界:** 卡片要求「空载/画廊 100 项/连续生成 20 张 RSS,双平台」。本 PR 落地方法论+表格+**mac 空载实测**;画廊/生成两项需真实数据与 API key(手工 SOP 已写清步骤),Windows 列需群里 Windows 机器——表格留待填标注归属,不假装测过。

---

### Task 1: cacheWidth 收口 ×4 站点 + lightbox 豁免注释

**Files:**
- Modify: `lib/features/gallery/widgets/gallery_tile.dart:92`
- Modify: `lib/features/canvas/widgets/batch_results_grid.dart:116`
- Modify: `lib/features/canvas/widgets/node_inputs_section.dart:181`
- Modify: `lib/features/canvas/widgets/image_config_inspector.dart:905`
- Modify: `lib/features/gallery/widgets/gallery_image_lightbox.dart:36`(仅加豁免注释)
- Test: `test/features/gallery/gallery_tile_cache_width_test.dart`(新建;若既有 gallery tile 测试文件存在则并入)

- [ ] **Step 1: 写失败测试(gallery tile 为代表,断言 ResizeImage)**

```dart
// LB-23:画廊 tile 必须 cacheWidth 缩略解码(220px tile 全解码原图 = 内存炸点)。
// ResizeImage 解包模式同 generation_render_node_e2e_test.dart(ME-26 先例)。
    final img = tester.widget<Image>(find.byType(Image));
    expect(img.image, isA<ResizeImage>(),
        reason: 'gallery tile 未设 cacheWidth——原图全解码');
```

(完整测试文件:pump 一个带临时图片文件的 GalleryTile,override fileResolver;
具体 harness 照抄该目录既有 gallery 测试的 ProviderScope overrides 写法。)

- [ ] **Step 2: 跑测试确认红**

```bash
flutter test test/features/gallery/ 2>&1 | tail -3
```

Expected: 新断言 FAIL(`is not ResizeImage`)。

- [ ] **Step 3: 四站点实现**

gallery_tile.dart(tile 上限 `_tileMaxExtent`=220,取自 gallery_screen;挪为共享 const 或就地复制注明来源):

```dart
      child: Image.file(
        file,
        fit: BoxFit.cover,
        // LB-23:按 tile 上限缩略解码,禁原图全解码(220 逻辑px × dpr)
        cacheWidth:
            (220 * MediaQuery.devicePixelRatioOf(context)).round(),
        errorBuilder: ...
      ),
```

batch_results_grid.dart(2 列网格,Inspector 面板宽 ~360,格宽上限取 180):

```dart
        return Image.file(
          file,
          fit: BoxFit.cover,
          // LB-23:2 列格宽上限 180 逻辑px × dpr 缩略解码
          cacheWidth:
              (180 * MediaQuery.devicePixelRatioOf(context)).round(),
          errorBuilder: ...
        );
```

node_inputs_section.dart / image_config_inspector.dart(微缩略图,`_kThumbSize`=28 / `_kCharacterThumbSize`=20):

```dart
                cacheWidth: (_kThumbSize *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
```

(inspector 同式用 `_kCharacterThumbSize`。)

gallery_image_lightbox.dart 仅加注释,不改行为:

```dart
              // LB-23 有意豁免 cacheWidth:InteractiveViewer 可缩放,
              // 必须全分辨率解码;lightbox 为瞬态单图,关窗即回收。
              child: Image.file(
```

- [ ] **Step 4: 测试绿 + 全量闸门**

```bash
flutter test test/features/gallery/ test/features/canvas/ 2>&1 | tail -2
flutter analyze lib test 2>&1 | tail -1
```

Expected: 全过、no issues。

- [ ] **Step 5: 提交**

```bash
git add -A lib/features test/features
git commit -m "perf(memory): LB-23 cacheWidth 收口——gallery tile/batch grid/两处微缩略图缩略解码,lightbox 有意豁免

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

### Task 2: ImageCache 上限策略落地

**Files:**
- Modify: `lib/main.dart`(bootstrap 段,ensureInitialized 之后)
- Test: `test/app_boot_image_cache_test.dart`(新建)

**评估结论(写入 perf-baseline,代码只落结果):** Flutter 默认 100MB/1000 张。修完 Task 1 后主要占用=画布 result 卡(已 cacheWidth 到节点宽)+ 画廊 tile(~0.8MB@2x);100 项画廊 ≈ 80MB,贴默认上限,滚动即抖动淘汰。桌面机内存充裕,上调到 **256MB** 换滚动流畅;条目数上限 1000 不动(桌面场景先触字节限)。

- [ ] **Step 1: 失败测试**

```dart
// LB-23:ImageCache 字节上限必须显式设定(默认 100MB 贴画廊工作集,滚动抖动淘汰)。
testWidgets('imageCache 上限 = 256MB', (tester) async {
  // main() 的 bootstrap 不可直接调,断言常量与运行时一致的最小面:
  expect(kImageCacheMaxBytes, 256 << 20);
});
```

实现时若 main.dart 结构允许抽 `configureImageCache()` 纯函数则连行为一起测
(调用后 `PaintingBinding.instance.imageCache.maximumSizeBytes == kImageCacheMaxBytes`);
不允许则常量测试 + main 内一行赋值,以 analyze+启动日志为证。

- [ ] **Step 2: 实现(main.dart bootstrap,ensureInitialized 后)**

```dart
      // LB-23:ImageCache 字节上限 100MB→256MB。修完 cacheWidth 后画廊 100 项
      // 工作集 ≈80MB 贴默认上限,滚动即抖动淘汰;桌面内存充裕,上调换流畅。
      // 条目上限 1000 不动(桌面先触字节限)。评估记录见 docs/perf-baseline.md。
      PaintingBinding.instance.imageCache.maximumSizeBytes =
          kImageCacheMaxBytes;
```

常量放 `lib/core/constants/`(与既有数值常量同居,命名 `kImageCacheMaxBytes = 256 << 20`)。

- [ ] **Step 3: 测试绿 + 提交**

```bash
flutter test test/app_boot_image_cache_test.dart && flutter analyze lib test 2>&1 | tail -1
git add -A lib test && git commit -m "perf(memory): LB-23 ImageCache 上限 100MB→256MB——画廊工作集评估驱动,常量入 core/constants

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

### Task 3: perf-baseline.md 内存水位节 + mac 空载实测

**Files:**
- Modify: `docs/perf-baseline.md`(追加「内存水位」节)

- [ ] **Step 1: 追加内存水位节(方法论+阈值+表格)**

```markdown
## 内存水位（LB-23）

### 方法论
- 指标：进程 RSS（mac `ps -o rss= -p <pid>`；win 任务管理器「内存」列或
  `Get-Process inkframe | % WorkingSet64`）。Release 构建，采样前静置 10s。
- 三场景：**空载**（启动进 Studio 不开项目）；**画廊 100 项**（示例项目扩种或真实项目，
  Gallery 滚到底再回顶）；**连续生成 20 张**（任一 provider，1024px，逐张等完成）。

### 阈值（验收线）
| 场景 | 阈值 | 依据 |
|---|---|---|
| 空载 | < 400 MB | Flutter desktop shell + 嵌入式 PG 常驻 |
| 画廊 100 项 | < 800 MB | 空载 + ImageCache 上限 256MB + 解码抖动余量 |
| 连续生成 20 张后回落 | < 900 MB 且 10min 内不再增长 | 泄漏红线：持续线性增长即 bug |

### 实测记录
| 场景 | macOS (arm64) | Windows (x64) |
|---|---|---|
| 空载 | (本 PR 实测填入) | 待测（群内 Windows 机） |
| 画廊 100 项 | 待测（需 ≥100 项真实产物） | 待测 |
| 连续生成 20 张 | 待测（需 API key 手工跑，SOP 如上） | 待测 |

### ImageCache 策略（评估记录）
默认 100MB/1000 张 → 字节上限调 256MB（`kImageCacheMaxBytes`，main bootstrap 设定）。
依据：cacheWidth 收口后画廊 100 项工作集 ≈80MB 贴默认上限，滚动抖动淘汰；
桌面内存充裕。条目上限不动。cacheWidth 覆盖清单：node_card / video_node_body（先例）
+ gallery_tile / batch_results_grid / node_inputs_section / image_config_inspector（本卡）；
豁免：gallery_image_lightbox（InteractiveViewer 缩放需全分辨率）。

### keepAlive 常驻盘点（LB-23 子项④）
8 文件（database / providers / rate_limiter / canvas_transform / inspector_submit /
export_controller / generation_controller / jobs_registry）。持大对象者仅
ImageCache 域外的 jobs_registry（handle 缓存，随 purge 收敛）与 database pool——
均为设计内常驻；无未管控大对象。上线后如需精算记 BP 系。
```

- [ ] **Step 2: mac 空载实测并填表**

```bash
flutter build macos --release 2>&1 | tail -1
APP="$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' | head -1)"
open "$APP" && sleep 15
PID=$(pgrep -x inkframe | head -1)
echo "RSS: $(( $(ps -o rss= -p "$PID") / 1024 )) MB"
osascript -e 'quit app "inkframe"'
```

把输出 MB 填进表格 macOS 空载格(格式如 `312 MB(2026-07-31,alpha.11+`本机`)`)。

> 注意:本机曾有 DebugProfile.entitlements 沙箱坑(memory:local_dev_unlocks)——
> Release 构建不走 DebugProfile,预期可直接起;若启动失败,记录失败原因并把该格标
> 「待测(本机 release 启动受阻)」,不伪造数值。

- [ ] **Step 3: keepAlive 盘点核实(grep 复核后如实修正上表文件清单)**

```bash
grep -rln "keepAlive" lib --include="*.dart"
```

以实际输出为准修正盘点段;若发现真持大对象的常驻 provider,如实记录并在 BOARD 技术债表加行。

### Task 4: 状态回填 + PR

**Files:**
- Modify: `docs/BOARD.md`(近期落地表加行)
- Modify: `docs/MASTERPLAN.md:111`(LB-23 标 ✅)
- Modify: `docs/superpowers/plans/2026-07-07-launch-backend.md:186-188`(LB-23 卡加状态行)

- [ ] **Step 1: 三处回填**

MASTERPLAN :111 的 `**LB-23 内存基线**(...)` 后加 `✅ #206`;backend plan LB-23 卡后加:

```markdown
  状态:已随 #206 落地——cacheWidth 收口 ×4(lightbox 有意豁免)、ImageCache 256MB
  (kImageCacheMaxBytes)、perf-baseline 内存水位节(mac 空载已实测;画廊/生成/win 列
  按 SOP 待填)、keepAlive 盘点无未管控大对象。
```

BOARD 近期落地表(#205 行后):

```markdown
| LB-23 内存基线:cacheWidth 缩略解码收口 ×4 站点(gallery tile/batch grid/两微缩略图;lightbox InteractiveViewer 有意豁免)+ ImageCache 上限 100→256MB + perf-baseline 内存水位节(方法论/阈值/mac 空载实测,画廊与生成场景按 SOP 待填)+ keepAlive 盘点 | #206 |
```

(PR 号预写 #206,建 PR 时核实。)

- [ ] **Step 2: 全量闸门 + 提交 + push(pbcopy 交用户)+ PR + CI 绿合并**

```bash
flutter analyze lib test && flutter test --exclude-tags golden
git add -A docs && git commit -m "docs: LB-23 收口回填——perf-baseline 内存水位节 + BOARD/MASTERPLAN/backend 计划三处状态

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
git push -u origin perf/lb-23-memory-baseline   # 用户 ! 执行
gh pr create --title "perf: LB-23 内存基线——cacheWidth 收口 + ImageCache 256MB + 水位基线" --body "(注意:正文技术记号一律反引号,禁裸 @)"
gh pr checks <PR#> --watch && gh pr merge <PR#> --squash --delete-branch
```
