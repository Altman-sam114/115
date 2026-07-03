# 测试规范

本文指导 Agent A/B/C 选择本地轻量检查、GitHub Actions 云端重验证和 Agent C 结果包复判方式。

## 固定前缀 / 环境要求

- 工作目录：`/Users/a114514/Desktop/codex/aiclaw`
- 默认分支：`main`
- 默认远端：`origin/main`
- 云端 workflow：`.github/workflows/ci-results.yml`
- Agent C 下载缓存：`/private/tmp/claw-c-review-<run_id>/`
- Node：用于 `Tools/*.mjs` Gateway prototype 和 smoke。
- Swift/Xcode：Swift 逻辑 smoke 依赖完整 Xcode toolchain 和 macOS SDK。
- Gateway smoke 会写入 `.build/*`，需要工作区可写。
- 当前项目没有包管理器配置；不要引入第三方依赖，除非人工明确同意。
- 如果本地没有配置 `origin`、GitHub 权限或 `gh auth login`，必须说明阻塞原因，不能伪装已经完成云端验收。

## 默认策略

- 默认云端重验证：Agent B 本地只跑轻量检查，提交并 push 到 `origin/main`，由 GitHub Actions 运行完整重验证。
- 默认不跑本机完整 build：只有人工明确说“本机测试”“本地 build”“本地 xcodebuild”“本地跑探针”等，才把本机完整构建或模拟器验证作为默认路径。
- 文档-only 修改仍需本地跑 `git diff --check` 和 workflow/YAML 语法检查；业务测试可不跑，但必须说明原因。
- Swift / Xcode / Gateway / 协议相关改动完成后，默认进入 main push -> CI 结果包 -> Agent C 下载复判闭环。
- 云端失败时，Agent B 根据结果包中的 failure summary、manifest 和日志路径，在 `main` 上追加修复 commit 后重新 push。

## Agent B 本地轻量检查

### 文档和流程改动

触发条件：

- 修改 `AGENTS.md`、`README.md`、`update_log.md`、`md/flow/*`、`md/test/test.md`、`md/prompt/*`。
- 修改 `.github/workflows/*.yml`。

命令：

```sh
git diff --check
ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'
```

当前基线：

- `git diff --check` 无输出并返回 0。
- YAML 解析输出 `yaml ok`。

### Gateway JS 改动

触发条件：

- 修改 `Tools/*.mjs`。
- 修改 Gateway handler、action policy、artifact 写入、WebSocket 事件。

命令：

```sh
node --check Tools/claw-gateway-server.mjs
node --check Tools/claw-gateway-direct-smoke.mjs
node --check Tools/claw-gateway-smoke.mjs
```

当前基线：

- `node --check` 应无输出并返回 0。
- direct/WebSocket smoke 默认由云端 workflow 重跑；人工要求本机验证时再本地运行。

### Swift 核心逻辑改动

触发条件：

- 修改 `Claw/Core/ClawModels.swift`。
- 修改 `Claw/Services/ClawStore.swift`。
- 修改 planner、bridge、simulator、event reducer、autonomous loop。
- 修改 `Tools/LogicSmoke.swift`。

本地优先命令：

```sh
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc \
  -swift-version 6 \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
  -target arm64-apple-macosx26.0 \
  -module-cache-path .build/SwiftModuleCache \
  Claw/Core/ClawModels.swift Claw/Services/ClawStore.swift Tools/LogicSmoke.swift \
  -o .build/claw-logic-smoke

.build/claw-logic-smoke
```

当前基线：

- 输出应包含 `Claw logic smoke passed`。
- 如果 SDK 或完整 Xcode 不存在，记录具体错误，不得声称通过。
- 云端 workflow 也会运行等价 logic smoke 并把日志写入结果包。

## GitHub Actions 云端重验证

触发条件：

```yaml
on:
  push:
    branches:
      - main
  workflow_dispatch:
```

默认覆盖：

- `git diff --check`。
- `plutil -lint Claw.xcodeproj/project.pbxproj`。
- `node --check Tools/*.mjs`。
- Swift logic smoke 编译和执行。
- Gateway direct smoke。
- Gateway WebSocket smoke。
- `xcodebuild build`。
- 结果包 manifest、failure summary、JUnit 或等价摘要、主日志和 `.xcresult`。

结果包最低内容：

- `ci-artifact-manifest.json`
- `ci-failure-summary.md`
- `junit.xml`
- `xcodebuild.log`
- `swift-logic-smoke.log`
- `gateway-direct-smoke.log`
- `gateway-websocket-smoke.log`
- `Claw.xcresult`（如果 xcodebuild 能生成）

manifest 必须至少记录：

- `version`
- `branch`
- `commitSha`
- `shortSha`
- `runId`
- `runAttempt`
- `workflowName`
- `createdAt`
- `projectName`
- `scheme`
- `destination`
- `resultBundlePath`
- `junitPath`
- `buildLogPath`
- `failureSummaryPath`
- `staticChecksOutcome`
- `buildOutcome`
- `testOutcome`
- `projectSpecificReports`

artifact 命名：

```text
claw-ci-${version}-${branch_slug}-${short_sha}-run${run_id}-attempt${run_attempt}
```

## Agent C 结果包复判

Agent C 必须先确认 GitHub CLI 登录状态：

```sh
gh auth status
```

未登录时先执行：

```sh
gh auth login
```

下载示例：

```sh
mkdir -p /private/tmp/claw-c-review-<run_id>
gh run download <run_id> --dir /private/tmp/claw-c-review-<run_id>
```

复判要求：

- 确认 `origin/main` 最新 commit 与 manifest 的 `commitSha` 完全一致。
- 确认 manifest 的 `branch` 是 `main`。
- 确认 manifest 的 `runId`、`runAttempt` 对应正在验收的 workflow run。
- 打开 `ci-failure-summary.md`、`junit.xml`、`xcodebuild.log` 和项目专属日志。
- CI 失败时，指出失败 step、日志路径、需要 Agent B 修复的文件/行为/测试。
- CI 通过时，输出版本号、commit hash、run id、artifact 名称、测试结果、未跑测试和残余风险。

## 人工明确要求时的本机构建

完整 Xcode build：

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Claw.xcodeproj \
  -scheme Claw \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Gateway smoke：

```sh
node Tools/claw-gateway-direct-smoke.mjs
node Tools/claw-gateway-smoke.mjs
```

当前基线：

- 完整 Xcode 可用时 `xcodebuild build` 应成功。
- direct smoke 必须覆盖 artifact 落盘、workspace 文件写入、browser trace、结构化提取、Shell dry-run/allowlist、浏览器策略、桌面 App 审批闸门、`agentTrace`。
- WebSocket smoke 必须启动一次性 Gateway，验证事件闭环、browser/file/shell/extract/agent loop 主链路和 `sessionCompleted`。

## 静态检查

```sh
git status --short
git diff --check
grep -R -n -E "法律|法务|合同|诉讼|律师|法院|legal|lawyer|court|lawsuit|litigation|counsel" Claw Tools Docs README.md ClawTests AGENTS.md md update_log.md
```

说明：

- 方向扫描允许在规范文档中出现“不要法律方向”等禁止项说明。
- 如果出现 `contract`，需判断是否是协议契约含义。

## 规则

- 每次实现前先读本文件。
- 默认本地轻量检查 + 云端重验证。
- 不得伪造测试结果。
- 不得删除断言来制造通过。
- 不得把旧 artifact、旧 output 或 checkout 自带报告冒充本轮云端结果。
- 文档-only 修改可只跑本地静态检查，但必须说明未跑业务测试的原因。
- 最终回复必须写清楚每条测试命令和结果、云端 run 状态、结果包是否已下载复判。
