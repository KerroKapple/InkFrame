# LEG-1 ④ 安装物内含 NOTICE — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让双平台发布产物(macOS zip/DMG + Windows zip)的**根目录**内含 `THIRD-PARTY.md`,并在流水线内硬校验其在位——收掉 LEG-1(beta 准入第 9 条)最后一个子项。

**Architecture:** LEG-1 的 ①核实变体 ②仓库根 THIRD-PARTY.md ③关于页 showLicensePage 已随 #147 落地;app 内部 flutter_assets 已含全部许可文本(alpha.11 产物实测确认)。唯一缺口是**发行层**——用户不解包/不启动 app 就看不到任何许可文件。改动集中在三个打包点(release.yml mac zip 步、package-macos-dmg.sh、release.yml win zip 步),每个打包点后紧跟一条 in-place 断言,产物缺 NOTICE 即红。

**Tech Stack:** GitHub Actions(release.yml)、bash(ditto/unzip)、pwsh(Compress-Archive / System.IO.Compression)。

**验收(≡ LEG-1 卡原验收):** 双平台安装物含 NOTICE ✓(zip 根 + DMG 根)、关于区可见 ✓(已落)、字体目录含 OFL ✓(已落)。终验 = release.yml `workflow_dispatch` 演练跑一轮,下载 artifact 抽查。

**约束:**
- release.yml 属 CI 闸门(verifier boundary),全部改动走 feature 分支 + PR 评审合入,不直接动 main。
- 三处改动互不依赖,但同属一个原子语义(「产物含 NOTICE」),放同一 PR 单 commit 交付。
- 本卡不做 NOTICE 内容变更——THIRD-PARTY.md 内容以 #147 为准,本卡只管「随产物分发」。

---

### Task 1: macOS zip 步——staging 目录带上 THIRD-PARTY.md + 断言

**Files:**
- Modify: `.github/workflows/release.yml:87-92`(`zip unsigned .app` 步)

**背景:** 现行 `ditto -c -k --keepParent "$APP"` 直接压 .app,zip 根只有 `inkframe.app/`。改为 staging 目录(app + THIRD-PARTY.md)后压 staging,zip 根变为 `inkframe.app/` + `THIRD-PARTY.md` 两个条目——解包体验不变(app 仍在顶层)。

- [ ] **Step 1: 改写 zip 步并追加断言**

将现有步骤:

```yaml
      - name: zip unsigned .app (always uploadable)
        run: |
          mkdir -p dist
          APP="$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' | head -1)"
          echo "app bundle: $APP"
          ditto -c -k --keepParent "$APP" "dist/InkFrame-$BUILD_NAME-macos-arm64-unsigned.zip"
```

改为:

```yaml
      - name: zip unsigned .app (always uploadable)
        run: |
          mkdir -p dist
          APP="$(find build/macos/Build/Products/Release -maxdepth 1 -name '*.app' | head -1)"
          echo "app bundle: $APP"
          # zip 根 = .app + THIRD-PARTY.md（LEG-1 ④：许可 NOTICE 随安装物分发）
          STAGE="$(mktemp -d)"
          cp -R "$APP" "$STAGE/"
          cp THIRD-PARTY.md "$STAGE/"
          ZIP="dist/InkFrame-$BUILD_NAME-macos-arm64-unsigned.zip"
          ditto -c -k "$STAGE" "$ZIP"
          rm -rf "$STAGE"
          unzip -l "$ZIP" | grep -q '\bTHIRD-PARTY\.md$' || { echo "::error::zip 缺 THIRD-PARTY.md" >&2; exit 1; }
```

要点:
- `ditto -c -k "$STAGE"`(去掉 `--keepParent`)= 压 staging 的**内容物**,根即两条目。
- 断言用 `unzip -l … | grep -q` 就地钉死;grep 锚定行尾防止误匹配 app 内部同名路径(app 内不存在该文件,alpha.11 实测确认,锚定是防御性写法)。

- [ ] **Step 2: 本地等价验证 staging→ditto→断言逻辑**

release.yml 无法本地执行,但打包逻辑可以。用 alpha.11 已解包的 .app 跑一遍等价脚本:

```bash
cd /Users/kerro/Projects/InkFrame
S=/private/tmp/claude-501/-Users-kerro-Projects-InkFrame/a2c2acd2-2a7f-4745-98f0-05305f9023fe/scratchpad/alpha11
STAGE="$(mktemp -d)" && cp -R "$S/app/inkframe.app" "$STAGE/" && cp THIRD-PARTY.md "$STAGE/"
ditto -c -k "$STAGE" /tmp/leg1-verify.zip && rm -rf "$STAGE"
unzip -l /tmp/leg1-verify.zip | grep '\bTHIRD-PARTY\.md$' && unzip -l /tmp/leg1-verify.zip | head -6
rm /tmp/leg1-verify.zip
```

Expected: grep 命中一行 `THIRD-PARTY.md`;列表头部同时可见 `inkframe.app/` 条目(app 仍在 zip 根)。

### Task 2: macOS DMG——staging 加入 THIRD-PARTY.md

**Files:**
- Modify: `scripts/release/package-macos-dmg.sh:20-21`

- [ ] **Step 1: staging 复制处加一行**

将:

```bash
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
```

改为:

```bash
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
cp THIRD-PARTY.md "$STAGE/"   # LEG-1 ④：DMG 根含许可 NOTICE
```

说明:create-dmg 会把 staging 全部内容进卷,DMG 打开即见 `THIRD-PARTY.md`。DMG 步在 release.yml 标 `continue-on-error`(best-effort 骨架),不在脚本内加断言——zip 侧断言(Task 1/3)已构成硬闸;DMG 转硬要求是 GA 前另一张卡的事,本卡不越界。

- [ ] **Step 2: 语法自检**

```bash
bash -n scripts/release/package-macos-dmg.sh && echo OK
```

Expected: `OK`

### Task 3: Windows zip——Release 目录带上 THIRD-PARTY.md + 断言

**Files:**
- Modify: `.github/workflows/release.yml`(`Compress-Archive` 所在 pwsh 步,约 :149-150)

- [ ] **Step 1: Compress-Archive 前复制 + 压后断言**

将:

```yaml
          Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath "dist/InkFrame-$env:BUILD_NAME-windows-x64-unsigned.zip" -Force
```

改为:

```yaml
          # zip 根含 THIRD-PARTY.md（LEG-1 ④：许可 NOTICE 随安装物分发）
          Copy-Item THIRD-PARTY.md build/windows/x64/runner/Release/
          $zip = "dist/InkFrame-$env:BUILD_NAME-windows-x64-unsigned.zip"
          Compress-Archive -Path build/windows/x64/runner/Release/* -DestinationPath $zip -Force
          Add-Type -AssemblyName System.IO.Compression.FileSystem
          $entries = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $zip)).Entries.FullName
          if ($entries -notcontains 'THIRD-PARTY.md') { throw "zip 缺 THIRD-PARTY.md" }
```

要点:
- `Copy-Item` 落进 Release/ 后由既有 `Release/*` 通配自然入 zip 根,不改压包语义。
- Release/ 是 build 产物目录,复制进去不污染工作区(git status 干净)。
- 断言走 .NET ZipFile 读条目名,精确匹配根级 `THIRD-PARTY.md`。

- [ ] **Step 2: 断言逻辑本地等价验证(macOS pwsh 不可用,用 bash 等价)**

Windows pwsh 逻辑无法本地跑;等价性由 Task 1 Step 2 的同构验证 + workflow_dispatch 演练(Task 5)兜底。此步仅目检 yaml 缩进与上下文行一致:

```bash
grep -n -A8 "Copy-Item THIRD-PARTY.md" .github/workflows/release.yml
```

Expected: 输出与 Step 1 代码块一致,缩进与同步骤既有行(10 空格)对齐。

### Task 4: 文档回填 + 提交

**Files:**
- Modify: `docs/superpowers/plans/2026-07-07-launch-release-engineering.md:226-232`(LEG-1 卡状态行;MASTERPLAN :287 已标 ✓ 不动)
- Modify: `docs/BOARD.md`(「近期落地」表追加一行)

- [ ] **Step 1: launch 明细文档 LEG-1 卡标注 ④ 完成**

在 `docs/superpowers/plans/2026-07-07-launch-release-engineering.md` LEG-1 卡(:226-232)的「依赖」行后追加状态行:

```markdown
- 状态:①②③ 已随 #147 落地;④ 安装物含 NOTICE 已随本 PR 落地(mac zip/DMG + win zip 根含
  THIRD-PARTY.md,zip 侧流水线内断言硬校验)——**LEG-1 全项收口,beta 准入第 9 条 ✅**。
```

- [ ] **Step 2: BOARD.md 近期落地表追加一行**

在 `docs/BOARD.md` 「近期落地(非里程碑)」表末尾(#200 行后)追加:

```markdown
| LEG-1 ④ 收口:双平台安装物根含 THIRD-PARTY.md(mac staging-ditto / win Copy-Item 进 Release,zip 侧流水线断言硬校验;DMG 随 staging 进卷)——beta 准入第 9 条全项 ✅ | (本 PR 号) |
```

(提交前把 `(本 PR 号)` 换成实际 PR 号;若 PR 号在 push 前未知,先写 PR 名,merge 前 amend。)

- [ ] **Step 3: 全量本地闸门 + 提交**

```bash
flutter analyze lib test && flutter test --exclude-tags golden
git switch -c chore/leg1-notice-in-artifacts
git add .github/workflows/release.yml scripts/release/package-macos-dmg.sh \
        docs/BOARD.md \
        docs/superpowers/plans/2026-07-07-launch-release-engineering.md \
        docs/superpowers/plans/2026-07-28-leg-1-notice-in-artifacts.md
git commit -m "chore(legal): LEG-1 ④ 收口——双平台安装物根含 THIRD-PARTY.md + 流水线断言

- mac zip:staging 目录(app+NOTICE)ditto 压根,unzip -l 断言缺件即红
- DMG:staging 加入 THIRD-PARTY.md 随卷分发(best-effort 步不加断言,zip 侧为硬闸)
- win zip:Copy-Item 进 Release/ 随通配入根,ZipFile 读条目断言
- beta 准入第 9 条(第三方许可 NOTICE 上线)全项收口;文档回填 BOARD/launch 明细

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

Expected: analyze 无 issue、测试全过(本 PR 不含 Dart 改动,闸门为回归保险)、pre-commit hook 绿。

### Task 5: PR + workflow_dispatch 演练终验

- [ ] **Step 1: push + 建 PR**

push 权限受限时按惯例 pbcopy 后请用户 `!` 执行:

```bash
git push -u origin chore/leg1-notice-in-artifacts
gh pr create --title "chore(legal): LEG-1 ④ 收口——双平台安装物根含 THIRD-PARTY.md + 流水线断言" --body "(要点同 commit body;附 alpha.11 实测缺口证据:双平台 zip 根均无 NOTICE,仅 app 内部 flutter_assets 有)"
```

- [ ] **Step 2: PR CI 绿后合并**

```bash
gh pr checks <PR#> --watch
gh pr merge <PR#> --squash --delete-branch
```

Expected: 五项 check 全绿(本 PR 只动 release.yml/脚本/文档,test job 为回归保险)。

- [ ] **Step 3: workflow_dispatch 演练验真**

release.yml 支持 workflow_dispatch(只构建+传 artifact,不碰 Release):

```bash
gh workflow run release.yml --ref main
gh run watch $(gh run list --workflow=release.yml --limit 1 --json databaseId --jq '.[0].databaseId')
```

跑绿即代表两条 zip 内断言已实际通过(断言挂了 job 会红)。再下载 artifact 抽查一次眼见为实:

```bash
gh run download <run-id> -n macos -D /tmp/leg1-dry && unzip -l /tmp/leg1-dry/*.zip | grep 'THIRD-PARTY\.md$'
gh run download <run-id> -n windows -D /tmp/leg1-dry && unzip -l /tmp/leg1-dry/*windows*.zip | grep 'THIRD-PARTY\.md$'
rm -rf /tmp/leg1-dry
```

Expected: 两条 grep 各命中一行根级 `THIRD-PARTY.md`。

- [ ] **Step 4: (演练红时)按红修复**

断言若在演练中打红,直接看 job log 定位(mac 侧 `::error::` 注解 / win 侧 throw 消息),小修同分支流程重走。不许为了绿而放宽断言。
