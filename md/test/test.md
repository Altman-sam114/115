# 测试规范

本文指导 Agent B 和 Agent C 选择测试层级、记录命令和判断当前基线。

## 固定前缀 / 环境要求

- 工作目录：`/Users/a114514/Desktop/codex/aiclaw`
- Node：用于 `Tools/*.mjs` Gateway prototype 和 smoke。
- Swift/Xcode：Swift 逻辑 smoke 依赖完整 Xcode toolchain 和 macOS SDK。
- Gateway smoke 会写入 `.build/*`，需要工作区可写。
- 当前项目没有包管理器配置；不要引入第三方依赖，除非人工明确同意。
- 如果 `xcode-select` 指向 CommandLineTools 而非完整 Xcode，`xcodebuild` 可能不可用，必须在结果中说明。

## 测试分层

### 1. Probe / Fast

最快发现语法、schema、文档格式和主链路断点。

触发条件：

- 修改 `Tools/*.mjs`。
- 修改 Markdown 文档。
- 修改 Swift schema 后希望快速暴露明显编译风险。

命令：

```sh
git diff --check
node --check Tools/claw-gateway-server.mjs
node --check Tools/claw-gateway-direct-smoke.mjs
node --check Tools/claw-gateway-smoke.mjs
```

当前基线：

- `node --check` 应无输出并返回 0。
- 文档-only 修改至少跑 `git diff --check`。

### 2. Smoke

验证主要集成路径。

触发条件：

- 修改 Gateway handler、action policy、artifact 写入、WebSocket 事件。
- 修改 Claw envelope、Gateway event、artifact schema。
- 修改 `runAgentLoop`、`controlBrowser`、`extractData`、`operateDesktopApp`、`runShellCommand` 等核心动作。

命令：

```sh
node Tools/claw-gateway-direct-smoke.mjs
node Tools/claw-gateway-smoke.mjs
```

当前基线：

- direct smoke 必须覆盖 artifact 落盘、workspace 文件写入、browser trace、结构化提取、Shell dry-run/allowlist、浏览器策略、桌面 App 审批闸门、`agentTrace`。
- WebSocket smoke 必须启动一次性 Gateway，验证事件闭环、browser/file/shell/extract/agent loop 主链路和 `sessionCompleted`。

### 3. Stage Regression

覆盖当前阶段核心模块。

触发条件：

- 修改 `Claw/Core/ClawModels.swift`。
- 修改 `Claw/Services/ClawStore.swift`。
- 修改 planner、bridge、simulator、event reducer、autonomous loop。
- 修改 `Tools/LogicSmoke.swift`。

命令：

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

### 4. Full

全量测试和构建。

触发条件：

- 修改 SwiftUI UI、App Intents、Xcode project、核心 schema 或跨层集成。
- 准备交付阶段版本。
- Agent C 验收重要功能。

命令：

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

当前基线：

- 完整 Xcode 可用时应成功 build。
- 若本机只有 CommandLineTools，记录 `xcodebuild` 环境限制。

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
- 默认从最小测试开始。
- 根据改动范围扩大测试。
- 不得伪造测试结果。
- 不得删除断言来制造通过。
- 文档-only 修改可只跑静态检查，但必须说明未跑完整测试的原因。
- 最终回复必须写清楚每条测试命令和结果。
