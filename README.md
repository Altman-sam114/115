# Claw iOS Controller Prototype

这是一个 SwiftUI iPhone 原型 App，用手机作为 Claw 控制台：用户用自然语言描述电脑任务，App 生成可审批的执行计划和 JSON envelope，真正的浏览器、文件、Shell、桌面 App 操作交给用户自托管的 Claw Gateway 在电脑上执行。

当前版本不下载模型权重，模型保持占位状态。App 已完成 UI、数据流、本地 artifact 导入/扫描/校验、电脑接管规划器、Claw Gateway envelope、事件流 reducer、Mission Run 任务回合面板、Artifact metadata 详情复核、文件变更安全复核、提取完整性复核、草稿/最终提交安全复核、AgentTrace 复核摘要、Gateway 能力复核摘要、Accessibility artifact 复核摘要、Gateway Replay Guard 复核摘要、专用 metadata 复核统一脱敏、Live Gateway 连接健康摘要、有界重连与 ping 可观测性、Gateway 进程内 task replay guard、iPad 多栏复核工作台、Gateway 能力快照审计、macOS Accessibility 观察摘要、WebSocket transport 边界、Shortcuts 入口和 smoke 测试。

后续 Codex/Agent 接力开发必须先读 `AGENTS.md`。项目已建立“人工目标 -> Agent A 设计提示词 -> Agent B 在 main 上实现并推送 -> GitHub Actions 云端验证 -> Agent C 下载结果包复判 -> 人工复核 -> 下一轮”的迭代工作流，并准备支持未来由 Agent X 主控多轮调度 A/B/C。核心记忆和规范分布在 `AGENTS.md`、`update_log.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 和 `md/prompt/`。

## 协作与云端验证

当前协作制度固定以 `main` 作为上传、提交、推送和云端验证分支。Agent B 默认在本地跑轻量检查后提交并 push 到 `origin/main`，由 `.github/workflows/ci-results.yml` 运行 Claw build、Swift logic smoke、Gateway smoke 和静态检查，并上传未加密 `ci-results` 结果包。Agent C 必须用 GitHub CLI 下载结果包，核对 manifest、JUnit/摘要、主日志和关键结果文件后再验收。

角色召唤约定：`agenta`/`a:`/`A:` 召唤 Agent A，`agentb`/`b:`/`B:` 召唤 Agent B，`agentc`/`c:`/`C:` 召唤 Agent C，`agentx`/`x:`/`X:` 召唤 Agent X。Agent X 用于围绕总目标主控多轮迭代，不直接替代 A/B/C，而是调度 A -> B -> C 并根据 Agent C artifact 验收结论决定继续、退回、暂停或完成。没有角色前缀时按普通 Codex 任务处理。

## 内容

- `AGENTS.md`：项目入口记忆、基本规则、Agent A/B/C/X 工作流和交付要求。
- `update_log.md`：版本更新记录、关键决策、完成事项和遗留问题。
- `md/prompt/`：Agent A 每轮写给 Agent B 的版本化实现提示词。
- `md/test/test.md`：测试规范、测试分层、命令、触发条件和当前基线。
- `md/flow/flow.md`：项目当前核心逻辑、数据流、执行流和架构边界。
- `md/flow/flowchart.md`：核心逻辑和 Agent 迭代流程的 Mermaid 图。
- `.github/workflows/ci-results.yml`：main push 和手动触发的云端重验证 workflow，会上传 Agent C 可下载复判的未加密结果包。
- `Claw.xcodeproj`：可用 Xcode 打开的 iOS 工程，target 名暂未重命名。
- `Claw/Core/ClawModels.swift`：Agent 能力、模型 manifest、artifact 校验、自动化通道、Claw action schema 和聊天数据模型。
- `Claw/Services/ClawStore.swift`：App 状态、能力库、策略上下文、电脑接管规划器、Claw envelope、live gateway 请求和事件流。
- `Claw/Services/ClawShortcuts.swift`：App Intents / Shortcuts 动作，包括 Claw 执行计划、电脑接管规划和 Claw 电脑任务 payload。
- `Claw/Views/ContentView.swift`：五个底部 Tab：连接、聊天、电脑接管、能力、榜单。
- `Docs/claw-mobile-gateway-protocol.md`：当前 Claw computer-control envelope、动作 schema、审批和任务状态协议草案。
- `Tools/claw-gateway-server.mjs`：本地桌面 Gateway 原型，通过 WebSocket 接收 envelope 并推送事件。
- `Tools/claw-gateway-smoke.mjs`：启动一次性 Gateway 并验证 WebSocket 事件闭环。
- `Tools/ClawGatewayEventFixture.swift`：读取 envelope 并输出 `ClawGatewayEvent` JSON Lines 的协议 fixture。
- `ClawTests/ClawTests.swift`：核心数据和业务流测试。

## 方向

这个原型朝 OpenClaw 式电脑智能体迭代：

- 手机端：输入任务、生成计划、用 Mission Run 面板展示当前阶段/下一步/风险/证据、审批高风险动作、查看 envelope、Live Gateway 连接健康、Artifact metadata、文件变更安全、提取完整性、草稿/最终提交安全、Gateway 能力、Accessibility、Replay Guard 和 AgentTrace 审计摘要；iPad/宽屏下把命令、Mission Run、计划、Gateway 会话、事件、权限和日志分栏复核。
- 桌面网关：观察屏幕、控制浏览器、操作桌面 App、管理文件、运行受控 Shell、提取数据，并把事件、artifact 和审批请求推回手机端。
- 安全策略：token 只保留短 SHA-256 指纹；动作走白名单；敏感动作提升审批；Shell/文件/桌面接管默认需要网关确认。
- 边界：iOS 普通 App 不能静默控制电脑或读取其他 App 私有数据，电脑接管必须发生在用户授权的桌面/自托管网关。

## 本地模型

manifest 已预留：

- 模型文件：`claw-local-agent-q4.mlmodelc`
- tokenizer：`claw-tokenizer.model`
- 存储目录：`Application Support/ClawLocalModels`
- 默认不下载网络权重。
- 没有登记官方 SHA-256 时，只能进入 staged 状态，不启用真实 runtime。

## Claw Gateway

App 内置通道：

- App Intents：把 Claw 计划生成能力交给 Shortcuts。
- Share Sheet：把任务结果草稿交给 Mail/IM，由用户确认。
- URL Scheme / Universal Link：打开移动端可公开访问的目标入口。
- Claw Gateway：把 `claw.computer.control.v1` envelope 发给桌面端，执行浏览器、文件、Shell、桌面 App 和屏幕观察动作。

Gateway 发送模式：

- `模拟事件流`：本地回放 Gateway 事件，展示 action 结果、artifact、审批点和 retry。
- `Live Gateway`：准备 WebSocket 请求并发送 envelope，桌面端按 `ClawGatewayEvent` 推流；未配置 endpoint/token 时会安全回退到模拟事件流。手机端会从 live request、连接状态、最新 session 和事件流派生连接健康摘要，展示 preflight、是否可尝试 live、事件数量、最新事件、fallback/error/completed 状态、脱敏 endpoint/token 指纹、transport attempt、重连次数、ping 状态和脱敏错误摘要。

当前桌面 Gateway 原型已有受控工具边界：会校验 token、schema、动作白名单，把 artifact 写入 workspace，并回传事件/file URL 引用。v0.13 起，同一 Gateway 进程会按 `task.id` 和短 digest 记录已接受任务；重复提交同一任务时只返回 replay 审计事件流，写入 session 级 `auditLog` artifact `task-replay-guard.json`，并把每个 action 标记为 `actionSkipped`，不再次调用 action handler，不重复写 browser/file/shell/agentTrace 等业务 artifact。v0.14 起，手机端 Mission Run 和 Gateway 会话卡片会只用该 artifact event 的安全 metadata 派生 Replay Guard 复核摘要，显示重复任务已被进程内 guard 跳过、replay 次数、动作数、digest match、原始状态和安全标志；它不读取 Gateway `file://` payload。该 replay guard 只在当前 Gateway 进程内有效，重启或多进程不会持久化去重，也不是跨进程、跨重启或分布式 exactly-once。每个正常 Gateway session 在 `gatewayConnected` 后、任何 action 开始前，都会写入 session 级 `auditLog` artifact `gateway-capability-snapshot.json`，记录 workspace、session workspace、platform、短 token 指纹、envelope `allowedActionKinds`、策略 allowlist 和 Shell/browser/screen/window/accessibility/desktop/workspace 的 real、dry-run、disabled、unavailable 或 workspace-only 状态；快照 artifact event 会附带安全 metadata，手机端 reducer 会把无 action 绑定的 `artifactStored` 保存为 session-level artifact，Mission Run、Gateway 会话卡片和 iPad 多栏工作台只用 metadata 派生 Gateway 能力复核摘要。v0.16 起，手机端也只从 `accessibilityTree` artifact event metadata 派生 Accessibility 观察复核摘要，展示 mode、policy、候选控件数、节点数、平台、redaction 和 safety flags，不读取 Gateway `file://` payload。v0.17 起，手机/iPad 还会从所有 Gateway artifact event metadata 派生通用 Artifact metadata 详情复核，展示 metadata 覆盖率、脱敏计数、最近带 metadata 的 artifact、安全键值和 safety flags；该复核仍不打开 `reference`，不读取 `file://` payload。v0.18 起，AgentTrace、Gateway 能力、Accessibility、Replay Guard 和通用 Artifact metadata 专用复核摘要统一使用同一套安全显示脱敏路径，异常 Gateway metadata 中的 raw token、Authorization/header、`toolArguments`、`file://`、workspace path、命令输出、网页正文、截图内容或草稿正文不会直接进入 UI。v0.19 起，Gateway `extractData` 输出 artifact 会附带 metadata-only 的提取完整性复核摘要，手机/iPad 端展示提取模式、完整性状态、row count、来源 artifact 计数、来源 kind 和 safety flags；该摘要不读取 artifact payload，不展示 row 内容、URL/path、命令输出、网页正文、草稿正文、token 或 `toolArguments`，也不新增 schema/action/event/artifact kind。v0.20 起，Gateway 会在既有 `messageDraft` 和 `operateDesktopApp` 相关 artifact event 上附带 metadata-only 的草稿/最终提交安全复核摘要，手机/iPad 端展示是否需要最终提交审批、是否需要用户确认、草稿正文和 paste text 是否省略、提交键阻断计数和 safety flags；该摘要不读取 artifact payload，不展示草稿正文、粘贴文本、按键原文、URL/path、联系人、token、header 或 `toolArguments`，也不新增 schema/action/event/artifact kind。v0.21 起，Gateway 会在既有 `browserTrace` 和 `browser-control-*.json` artifact event 上附带 metadata-only 的浏览器控制计划复核摘要，手机/iPad 端展示是否请求打开浏览器、URL/search 是否仅记录 presence、HTML 输入、network fetch/blocked、app/host allowlist、执行状态和 safety flags；该摘要不读取 artifact payload，不展示 raw URL、搜索词、HTML/page text、表单字段、候选控件 label、stdout/stderr、token、header 或 `toolArguments`，也不新增 schema/action/event/artifact kind。v0.22 起，Gateway 会在 `manageFiles` 的既有 `fileDiff` artifact event 和路径阻断审计 artifact event 上附带 metadata-only 的文件变更安全复核摘要，手机/iPad 端展示 workspace policy、write attempted/succeeded、created/modified/deleted count、path/content/diff omission 和 safety flags；该摘要不读取 artifact payload，不展示 raw path、workspace path、文件内容、diff、patch、token、header 或 `toolArguments`，也不新增 schema/action/event/artifact kind。手机端还会在 Live Gateway request 附近显示连接健康摘要；该摘要只从已存在的 request、connection state、session 和事件派生，不写入 envelope，不读取 `file://` artifact payload。v0.12 起，客户端 WebSocket 在发送 envelope 后做一次 ping 观测，并在尚未收到桌面业务事件前最多重试 1 次；重连和 ping 只进入健康摘要，不代表后台保活、配对服务或桌面端心跳协议。快照、Artifact metadata review、File Change Safety review、提取完整性 review、Browser Control review、Delivery Safety review、Accessibility review、replay guard、metadata 和 health 摘要不包含 raw token、Authorization header、自然语言 instruction、`toolArguments`、网页正文、命令输出、截图内容、草稿正文、文件内容、diff、patch 或完整 workspace path，也不扩大 Gateway 权限，手机端不读取 Gateway `file://` 内容。`controlBrowser` 可从本地 HTML 或受 allowlist 约束的 URL 生成浏览轨迹、链接、标题、表格、表单和候选控件；默认只写入浏览器打开/搜索计划并附 metadata-only 计划复核，设置 `CLAW_ALLOW_BROWSER_CONTROL=1`、`CLAW_BROWSER_APP_ALLOWLIST` 和 `CLAW_BROWSER_HOST_ALLOWLIST` 后，可在 macOS 上打开允许的桌面浏览器并跳转到结构化 URL/搜索结果。`extractData` 会消费前序 browser/file/shell/screen/accessibility artifact 生成结构化结果。`runAgentLoop` 会消费同一 session 内的 artifact context，写出 `agentTrace`：保留 `sourceArtifacts`、`evidenceRows`、`observations`、`nextActions`、`safetyGates` 等旧字段，并新增 `readiness`、`decisionChecklist`、`selectedNextAction`、`riskTags`、`stopReason`、`handoffSummary`，用于解释证据是否充分、缺口在哪、当前推荐下一步和必须停下等待审批的原因；这些字段只从结构化 `toolArguments` 和已有 artifact 推导，不扩大浏览器、Shell、AppleScript 或桌面 App 权限。Gateway 会把 agentTrace 的证据分、缺失信号、下一步、风险标签、停止原因和 handoff 摘要压缩成可选字符串 metadata 随 artifact event 返回；手机端只用这些 metadata 做 Mission Run / Gateway 会话复核，不读取 Gateway `file://` 内容。`manageFiles` 可按 `toolArguments.writePath/writeText` 在 workspace 内真实写文件，路径逃逸会被阻断，并只在 metadata 中暴露计数、presence 和 omission flags。Shell 只接受结构化 `toolArguments.shellCommand`，默认 dry-run；必须同时设置 `CLAW_ALLOW_SHELL=1` 和 `CLAW_SHELL_ALLOWLIST` 才会真执行。屏幕观察默认 dry-run，设置 `CLAW_ALLOW_SCREEN_CAPTURE=1` 后可在 macOS 上生成真实截图 artifact，设置 `CLAW_ALLOW_WINDOW_METADATA=1` 后可读取前台窗口元数据；设置 `CLAW_ALLOW_ACCESSIBILITY_OBSERVE=1` 后，授权 macOS Gateway 可用固定只读 System Events 脚本采集前台 App/窗口和有限候选控件摘要，无权限或非 macOS 时写入可审计 accessibility-failed/accessibility-unavailable artifact。桌面 App 控制默认停在审批闸门，设置 `CLAW_ALLOW_DESKTOP_CONTROL=1`、`CLAW_DESKTOP_APP_ALLOWLIST` 和 `CLAW_DESKTOP_KEY_ALLOWLIST` 后，可在 macOS 上聚焦允许的 App、粘贴结构化草稿、执行允许的非提交快捷键，并在最终提交前回到用户确认。

本地启动 Gateway：

```sh
CLAW_GATEWAY_TOKEN=super-secret-token \
node Tools/claw-gateway-server.mjs
```

带 workspace 和 Shell 策略启动：

```sh
CLAW_GATEWAY_TOKEN=super-secret-token \
CLAW_WORKSPACE=.build/claw-gateway-workspace \
CLAW_ALLOW_SHELL=1 \
CLAW_SHELL_ALLOWLIST=pwd,ls \
CLAW_ALLOW_BROWSER_CONTROL=1 \
CLAW_BROWSER_APP_ALLOWLIST=Safari \
CLAW_BROWSER_HOST_ALLOWLIST=www.google.com,example.com \
CLAW_ALLOW_SCREEN_CAPTURE=1 \
CLAW_ALLOW_WINDOW_METADATA=1 \
CLAW_ALLOW_ACCESSIBILITY_OBSERVE=1 \
CLAW_ALLOW_DESKTOP_CONTROL=1 \
CLAW_DESKTOP_APP_ALLOWLIST=Slack,Notes \
CLAW_DESKTOP_KEY_ALLOWLIST=command+k,command+f,tab \
node Tools/claw-gateway-server.mjs
```

iOS App 中配置：

- Gateway URL：`ws://127.0.0.1:18789`（模拟器）或电脑局域网 IP（真机）
- Gateway Token：同一个 `super-secret-token`
- 发送模式：`Live Gateway`

Gateway smoke：

```sh
node Tools/claw-gateway-direct-smoke.mjs
node Tools/claw-gateway-smoke.mjs
```

`direct-smoke` 不监听端口，用 `--emit-events` 直接验证同一套 Gateway handler、workspace artifact、browser trace 到结构化提取链路、Browser Control metadata、File Change Safety metadata、提取完整性 metadata、Delivery Safety metadata、workspace 文件真实写入、路径逃逸阻断、写入失败审计、workspace symlink 阻断、Shell dry-run 阻断、allowlist Shell 真执行、浏览器打开/搜索计划与 allowlist 阻断、`agentTrace` 证据充分性/缺口/下一步选择/审批停止原因、artifact metadata 与 trace JSON 关键字段一致性、同一进程内重复 envelope 的 replay guard，以及桌面 App 控制的审批闸门和 allowlist 阻断；`claw-gateway-smoke` 会实际启动 WebSocket server，并覆盖同类 `agentTrace` 证据策略、metadata 断言、Browser Control metadata、File Change Safety metadata、提取完整性 metadata、Delivery Safety metadata、路径逃逸阻断、写入失败审计和同一 Gateway 进程内两次 WebSocket 连接的 replay guard。

## 运行

打开 `Claw.xcodeproj`，选择 `Claw` scheme，在 iPhone 模拟器或真机运行。

命令行构建可使用完整 Xcode 路径：

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

逻辑 smoke：

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

## 完成情况

- 2026-07-05：新增 v0.22 文件变更安全复核。Gateway `manageFiles` 的既有 `fileDiff` artifact event 和路径阻断/写入失败审计 event metadata 增加 workspace policy、write attempted/succeeded、created/modified/deleted count、path/content/diff omission 和 safety flags；Mission Run、Gateway 会话和单个 result row 展示 metadata-only File Change Safety 摘要，并收紧 workspace symlink/no-follow 写入防护。本轮不读取 Gateway `file://` payload，不展示 raw path、workspace path、文件内容、diff、patch、token、header 或 `toolArguments`，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-05：新增 v0.21 浏览器控制计划复核。Gateway `controlBrowser` 的 `browserTrace` 和 `browser-control-*.json` artifact event metadata 增加请求打开、URL/search presence、HTML 输入、network fetch/blocked、app/host allowlist、执行状态和 omission flags；Mission Run、Gateway 会话和单个 result row 展示 metadata-only Browser Control 摘要。本轮不读取 Gateway `file://` payload，不展示 raw URL、搜索词、HTML/page text、表单字段、候选控件 label、stdout/stderr 或 `toolArguments`，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-05：新增 v0.20 草稿/最终提交安全复核。Gateway `messageDraft` 和 `operateDesktopApp` artifact event metadata 增加 final-submit gate、用户确认、正文/paste 省略和提交键阻断计数；Mission Run、Gateway 会话和单个 result row 展示 metadata-only 摘要。本轮不读取 Gateway `file://` payload，不展示草稿正文、粘贴文本、按键原文、URL/path、联系人或 `toolArguments`，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-05：新增 v0.19 提取完整性复核。Gateway `extractData` artifact event metadata 增加提取模式、完整性状态、row count、来源 artifact 计数、source kinds 和 safety flags；Mission Run、Gateway 会话和单个 result row 展示 metadata-only 摘要。本轮不读取 Gateway `file://` payload，不展示 row 内容/URL/path/命令输出/`toolArguments`，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-05：新增 v0.17 手机端 Artifact metadata 详情复核。Mission Run、Gateway 会话和单个 result row 会从 Gateway artifact event metadata 派生通用复核摘要，展示 metadata 覆盖率、脱敏计数、最近带 metadata 的 artifact、安全键值和 safety flags；本轮不读取 Gateway `file://` payload，不新增 schema/event/action/artifact kind，不修改 Gateway JS，不扩大 Gateway 权限。
- 2026-07-05：新增 v0.16 手机端 Accessibility artifact 复核摘要。Mission Run、Gateway 会话和单个 result row 会从 `accessibilityTree` artifact metadata 派生观察摘要，展示 mode、policy、候选控件数、节点数、平台、redaction 和 safety flags；本轮不读取 Gateway `file://` payload，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-05：新增 v0.15 macOS Accessibility 观察摘要。`observeScreen` 继续复用既有 `accessibilityTree` artifact，默认 dry-run/window metadata；显式设置 `CLAW_ALLOW_ACCESSIBILITY_OBSERVE=1` 且运行在授权 macOS Gateway 时，才采集前台 App/窗口和有限候选控件只读摘要。Gateway capability snapshot metadata 新增 `accessibilityTreeState`，手机端 Gateway 能力复核摘要展示 `ax <state>`；本轮不新增 schema/event/action/artifact kind，不执行点击/输入，不让 iOS 声称能读取其他 App 私有数据。
- 2026-07-05：新增 v0.14 手机端 Replay Guard 复核摘要。Mission Run 和 Gateway 会话卡片会从 `task-replay-guard.json` `auditLog` metadata 派生重复任务安全跳过摘要，展示 replay 次数、跳过动作数、digest match、首次状态和安全标志；本轮不读取 Gateway `file://` payload，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-04：新增 v0.13 Gateway task replay guard。桌面 Gateway 在进程内记录已接受的 `task.id`，重复提交同一任务时只返回 `gatewayConnected`、session-level `task-replay-guard.json` `auditLog`、每个 action 的 `actionSkipped` 和 `sessionCompleted`，不再次执行 action handler、不写业务 artifact；direct/WebSocket smoke 覆盖同一进程内重复 envelope。该能力不新增 schema/event/action/artifact kind，不扩大 Gateway 权限，不是跨重启持久化 exactly-once。
- 2026-07-04：新增 v0.12 Live Gateway 有界重连与 ping 可观测性。`URLSessionClawGatewayTransport` 默认最多重试 1 次，并在发送 envelope 后执行一次 ping 观测；health summary/UI 展示 attempt、reconnect、ping 和脱敏 transport error。重连仅限尚未收到桌面业务事件前，不新增 schema/event/action/artifact kind，不做后台保活，不扩大 Gateway 权限。
- 2026-07-04：新增 v0.11 Live Gateway 连接健康摘要。手机端从 `ClawGatewayLiveRequest`、连接状态、最新 Gateway session 和事件流派生 health summary，展示 preflight、脱敏 endpoint、transport、短 token 指纹、事件数量、最新事件、fallback/error/completed 和 session 状态；live 非终态事件保持 `streaming`，不降回 `awaitingGateway`。本轮不新增 schema/event/action/artifact kind，不做自动重连，不扩大 Gateway 权限。
- 2026-07-04：新增 v0.10 手机端 Gateway 能力复核摘要。Gateway capability snapshot artifact 附带安全 metadata；Swift session 保存无 action 绑定的 session-level artifacts，`artifactCount` 和 kind summary 纳入 `auditLog`；Mission Run、Gateway 会话卡片和 iPad 工作台展示 metadata 派生的 Gateway capability review，不读取 `file://` 内容，不新增 schema/action/event/artifact kind，不扩大 Gateway 权限。
- 2026-07-04：新增 v0.9 Gateway 能力快照 artifact。Gateway 每个 session 会在 `gatewayConnected` 后写入 `gateway-capability-snapshot.json` `auditLog` artifact，用于审计 workspace、platform、短 token 指纹、allowedActionKinds、策略 allowlist 和 real/dry-run/disabled/unavailable/workspace-only 状态；本轮复用既有 `auditLog` artifact kind 和 `artifactStored` event kind，不改变 schema，不新增权限，不写 raw token、自然语言 instruction、`toolArguments` 或动作输出内容。
- 2026-07-04：新增 v0.8 iPad 多栏复核工作台。电脑接管页在 regular horizontal size class 下使用左右两栏：左侧保留命令输入和 Mission Run 主操作，右侧集中计划、Claw 电脑任务、Gateway 会话、事件/envelope、权限矩阵和执行日志；compact iPhone 布局保持原有单栏。本轮只重排现有展示层，不改变 schema，不新增 action/artifact/event，不读取 Gateway `file://` 内容，不扩展执行权限。
- 2026-07-04：新增 v0.7 手机端 AgentTrace 复核体验。`ClawGatewayArtifact.metadata` 变为可选字符串字典，Gateway/simulator 在 `agentTrace` artifact event 上附带安全复核摘要，Mission Run / Gateway 会话显示证据分、缺口、下一步、停止原因和脱敏状态；本轮不读取 Gateway `file://` 内容，不新增 action/artifact/event kind，不扩展执行权限。
- 2026-07-04：新增 v0.6 AgentTrace 证据策略。Gateway `runAgentLoop` 的 `agentTrace` artifact 在保留旧字段基础上新增 readiness、decisionChecklist、selectedNextAction、riskTags、stopReason 和 handoffSummary；direct/WebSocket smoke 断言新增字段。本轮不改变 `claw.computer.control.v1` schema，不扩展 Gateway 执行权限。
- 2026-07-04：新增 v0.5 Agent X 循环迭代文档基线。补充 `agentx`/`x:`/`X:` 召唤规则、Agent X 主控调度职责、停止条件、flow/flowchart/test/prompt README 协作说明和小数据量 artifact 下载限制；本轮只做文档准备，不启动真实 Agent X 自动循环。
- 2026-07-03：新增 v0.2 任务回合化体验。电脑接管页首屏增加 Mission Run 面板，把现有计划、审批、自治循环、Gateway session、artifact 和 retry 状态整理成目标、阶段、主动作、风险、证据和结果摘要；本轮不改变 `claw.computer.control.v1` schema，也不扩展 Gateway 权限。
- 2026-07-03：升级协作制度为 main 直推、GitHub Actions 云端重验证和 Agent C 下载未加密结果包复判；新增 `ci-results` workflow。验证：本轮至少需运行 `git diff --check` 和 workflow YAML 语法检查；真实云端试跑依赖仓库配置 `origin`。
- 2026-06-28：建立多 Agent 协作系统和项目记忆目录，统一入口为 `AGENTS.md`，新增 `update_log.md`、`md/prompt/README.md`、`md/prompt/v0（项目初始化）/v0.1（建立多Agent迭代文档）.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`。验证：文档-only 改动，按 `md/test/test.md` 运行静态检查；未运行 Gateway/Swift smoke。
- 2026-06-27：新增项目级开发规范草案，固化后续 Codex 开发规范、测试矩阵、README/协议文档更新要求和项目方向约束。后续已迁移为标准入口 `AGENTS.md`。
