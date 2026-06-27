# Codex 项目系统提示词：Claw Computer-Control

本文是后续 Codex 处理本仓库任务时必须优先阅读的项目级系统提示词、工程规范和交接总结。目标是把 Claw 持续迭代为类似 OpenClaw 的电脑智能体控制台，而不是法律、法务或合同类产品。

## 最高目标

Claw 的产品方向是：iPhone 作为控制台，桌面端 Claw Gateway 作为真正执行端，完成“观察电脑状态 -> 规划下一步 -> 执行受控动作 -> 回传 artifact -> 等待审批/继续循环”的电脑接管闭环。

必须坚持：

- 不要把项目重新带回法律、法务、合同、诉讼、律师、法院等垂直方向。
- 新功能优先服务电脑接管能力：屏幕观察、浏览器控制、桌面 App 操作、文件管理、受控 Shell、结构化提取、agent loop、审计和审批。
- iOS 端只做任务输入、计划生成、风险展示、用户审批、envelope 发送和事件查看；真正电脑操作发生在用户授权的桌面/自托管 Gateway。
- 任何高风险动作都要有结构化参数、白名单、审批闸门和 artifact 审计。

## 当前项目总结

仓库当前是 SwiftUI iPhone 原型 App：

- `Claw/Core/ClawModels.swift`：模型 manifest、能力分类、Claw action schema、Gateway 事件和 artifact 类型。
- `Claw/Services/ClawStore.swift`：App 状态、电脑接管规划器、Claw envelope、Gateway simulator、WebSocket live client、事件 reducer。
- `Claw/Services/ClawShortcuts.swift`：App Intents / Shortcuts 入口。
- `Claw/Views/ContentView.swift`：连接、聊天、电脑接管、能力、榜单等 UI。
- `Tools/claw-gateway-server.mjs`：本地桌面 Gateway 原型。
- `Tools/claw-gateway-direct-smoke.mjs`：直接调用 Gateway handler 的 smoke。
- `Tools/claw-gateway-smoke.mjs`：启动 WebSocket Gateway 的 smoke。
- `Tools/ClawGatewayEventFixture.swift`：协议 fixture。
- `Tools/LogicSmoke.swift`：Swift 业务逻辑 smoke。
- `Docs/claw-mobile-gateway-protocol.md`：computer-control envelope 和事件协议草案。
- `README.md`：面向用户和开发者的项目说明。

当前 git 基线只有一个提交：`2ced27b 1`。后续修改必须基于当前工作树，不要假设历史上下文一定准确。

## 关键协议和能力

当前 schema：

- `claw.computer.control.v1`

核心 action kind：

- `analyzeLocalContext`
- `requestPermission`
- `runAgentLoop`
- `observeScreen`
- `controlBrowser`
- `operateDesktopApp`
- `manageFiles`
- `runShellCommand`
- `extractData`
- `readContacts`
- `composeMessage`
- `composeEmail`
- `createReminder`
- `scheduleNotification`
- `openExternalURL`
- `runShortcut`
- `speechCapture`
- `backgroundRefresh`
- `desktopHandoff`
- `auditLog`
- `blockedUnsupported`

核心 artifact kind：

- `screenshot`
- `accessibilityTree`
- `commandOutput`
- `fileDiff`
- `browserTrace`
- `agentTrace`
- `messageDraft`
- `auditLog`

`runAgentLoop` 和 `agentTrace` 是当前朝 OpenClaw 式闭环推进的关键接口。后续要继续强化它们，让 Gateway 能基于同一 session 内的 screen/browser/file/shell/message artifacts 产生下一步建议、安全闸门和可审查轨迹。

## 编程原则

1. 先读现状
   - 修改前先读相关文件，不凭记忆改。
   - 优先使用 `grep`/`find`；如果环境有 `rg`，优先用 `rg`。
   - 当前项目可能没有完整 Xcode 环境，验证时要记录实际可跑和不可跑的命令。

2. 小步迭代
   - 每次只推进一个明确能力面。
   - 不做无关重构，不改无关 UI，不回滚用户或其他 agent 的改动。
   - 新增 action/artifact 时必须贯穿模型、planner、bridge、simulator、fixture、Gateway、smoke 和文档。

3. 安全默认
   - 不把自然语言直接交给 Shell、AppleScript 或桌面自动化。
   - Shell 只执行结构化 `toolArguments.shellCommand`，默认 dry-run，必须经过 `CLAW_ALLOW_SHELL` 和 `CLAW_SHELL_ALLOWLIST`。
   - 浏览器网络和打开桌面浏览器必须经过 host/app allowlist。
   - 桌面 App 控制必须经过 app/key allowlist，并在最终提交/发送前停下。
   - token 不写入 envelope，只保存短 SHA-256 指纹；运行时 token 只能走 header 或本地配置。

4. 真实闭环
   - 不满足于 UI 文案，要让能力真实出现在 envelope、Gateway event、artifact 和 smoke 断言里。
   - 每个 Gateway action 应至少产出一个可审查 artifact 或明确的 skipped/failed reason。
   - 新增能力必须能被模拟事件流和 live Gateway 事件流 reducer 表达。

## 标准工作流

每次接到任务后按这个顺序执行：

1. 读 `agent.md`、`README.md` 和相关源码。
2. 用 `git status --short` 确认工作树，保留已有改动。
3. 明确本次改动属于哪类：
   - iOS 规划/状态/UI
   - Claw envelope/schema
   - Gateway handler
   - Gateway event/reducer
   - 测试/smoke
   - 文档/规范
4. 修改代码。
5. 更新测试或 smoke 断言。
6. 更新 `README.md` 的完成情况或能力说明。
7. 如协议变化，更新 `Docs/claw-mobile-gateway-protocol.md`。
8. 跑验证命令，记录结果。
9. 最终回复要说明改了什么、跑了什么、哪些因环境限制没跑。

## 测试规范

改动后按影响范围选择验证。只改 Markdown 时可不跑全部测试，但必须说明未跑原因。

### Gateway JavaScript

改动 `Tools/*.mjs` 后至少运行：

```sh
node --check Tools/claw-gateway-server.mjs
node --check Tools/claw-gateway-direct-smoke.mjs
node --check Tools/claw-gateway-smoke.mjs
node Tools/claw-gateway-direct-smoke.mjs
node Tools/claw-gateway-smoke.mjs
```

如果 smoke 需要写 `.build`，确保 workspace 可写。若失败，优先修测试覆盖或实现，不要删除断言绕过问题。

### Swift 逻辑

改动 `Claw/Core`、`Claw/Services`、`Tools/LogicSmoke.swift` 后运行：

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

如果本机没有完整 Xcode 或 SDK 路径不同，报告具体错误，不要声称已通过。

### Xcode 构建

可用完整 Xcode 时运行：

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

如果 `xcode-select` 指向 CommandLineTools 导致 `xcodebuild` 不可用，记录该限制。

### 方向回归检查

每次较大改动后运行语义残留检查：

```sh
grep -R -n -E "法律|法务|合同|诉讼|律师|法院|legal|lawyer|court|lawsuit|litigation|counsel" Claw Tools Docs README.md ClawTests
```

允许出现非法律含义的 `contract`，例如 “protocol contract”，但最终说明要标明这是协议契约含义，不是法律方向。

## README 和文档更新规则

每次完成代码或协议改动后必须同步：

- `README.md`
  - 更新当前能力说明。
  - 更新 smoke/test 命令或覆盖范围。
  - 在“完成情况”中追加一条日期、改动摘要和验证结果。
- `Docs/claw-mobile-gateway-protocol.md`
  - 只要 action kind、artifact kind、Gateway event、toolArguments、策略开关或 envelope 字段变化，就必须更新。
- `agent.md`
  - 如果项目方向、工作流、测试矩阵或安全策略变化，必须同步更新。

不要只改代码不改文档；后续 Codex 依赖这些文档接力。

## 完成定义

一个任务只有同时满足下面条件才算完成：

- 能力朝电脑接管智能体方向推进，而不是偏离到法律类产品。
- 源码、测试、README、协议文档保持一致。
- 新增行为有 smoke 或逻辑测试覆盖。
- 安全边界没有弱化。
- 验证命令已运行，或明确说明环境限制和未运行原因。
- 最终回复简洁列出：改动文件、行为变化、验证结果、剩余风险。

## 后续优先级

优先做这些方向：

1. 强化 `runAgentLoop`：从 artifact 生成更可靠的下一步计划、失败恢复和多轮状态机。
2. 强化真实桌面观察：macOS 窗口元数据、截图、可访问性树 bridge。
3. 强化浏览器控制：Playwright/browser-use 兼容层、表单填写、点击候选控件。
4. 强化桌面 App 控制：更细 app/key allowlist、最终提交前确认、回滚记录。
5. 强化 live Gateway：更完整 WebSocket 生命周期、心跳、错误重连、token 配对体验。
6. 强化 UI：让手机端清楚展示计划、风险、artifact、审批点和 agent loop 状态。

不要优先做营销页、法律模板、泛聊天能力或无审计的“自动执行”。
