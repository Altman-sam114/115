# Claw iOS Controller Prototype

这是一个 SwiftUI iPhone 原型 App，用手机作为 Claw 控制台：用户用自然语言描述电脑任务，App 生成可审批的执行计划和 JSON envelope，真正的浏览器、文件、Shell、桌面 App 操作交给用户自托管的 Claw Gateway 在电脑上执行。

当前版本不下载模型权重，模型保持占位状态。App 已完成 UI、数据流、本地 artifact 导入/扫描/校验、电脑接管规划器、Claw Gateway envelope、事件流 reducer、Mission Run 任务回合面板、Mission Run Operator Strip、Mission Run Loop 继续态势、Mission Run Mac Agent Readiness Board 就绪看板、Mission Run Focus Context 聚焦上下文、Mission Run Review Detail Dock、Mission Run Review Trail 复核路径、Mission Run Approval Queue 审批队列、Mission Run Payload Safety Ledger 载荷安全账本、Mission Run Artifact 证据索引、Mission Run 复核优先队列、复核聚焦模式、复核态势摘要与下一步复核行动、Artifact metadata 详情复核、文件变更安全复核、提取完整性复核、草稿/最终提交安全复核、AgentTrace handoff 状态、mac 证据质量分层和复核摘要、Gateway 能力复核摘要、Accessibility artifact 复核摘要、Gateway Replay Guard 复核摘要、专用 metadata 复核统一脱敏、Live Gateway 连接健康摘要、有界重连与 ping 可观测性、Gateway 进程内 task replay guard、iPad 多栏复核工作台、Gateway 能力快照审计、macOS Accessibility 观察摘要、WebSocket transport 边界、Shortcuts 入口和 smoke 测试。

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

- 手机端：输入任务、生成计划、用 Mission Run 面板展示当前阶段/下一步/风险/证据、Operator Strip、Loop 继续态势、Mac Agent Readiness Board 就绪看板、Focus Context 聚焦上下文、Review Trail 复核路径、Approval Queue 审批队列、Payload Safety Ledger 载荷安全账本、Artifact 证据索引、复核态势摘要、下一步人工复核行动和按风险/可行动性排序的复核优先队列，可聚焦单个队列项查看对应详细复核，审批高风险动作、查看 envelope、Live Gateway 连接健康、Artifact metadata、文件变更安全、提取完整性、草稿/最终提交安全、Gateway 能力、Accessibility、Replay Guard 和 AgentTrace handoff 审计摘要；iPad/宽屏下把命令、Mission Run、计划、Gateway 会话、事件、权限和日志分栏复核，并在右侧顶部同步显示当前 Mission 复核详情 Dock、Mac Agent 就绪看板、复核路径、载荷安全账本和审批队列。
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

当前桌面 Gateway 原型已有受控工具边界：会校验 token、schema、动作白名单，把 artifact 写入 workspace，并回传事件/file URL 引用。v0.13 起，同一 Gateway 进程会按 `task.id` 和短 digest 记录已接受任务；重复提交同一任务时只返回 replay 审计事件流，写入 session 级 `auditLog` artifact `task-replay-guard.json`，并把每个 action 标记为 `actionSkipped`，不再次调用 action handler，不重复写 browser/file/shell/agentTrace 等业务 artifact。v0.14 起，手机端 Mission Run 和 Gateway 会话卡片会只用该 artifact event 的安全 metadata 派生 Replay Guard 复核摘要，显示重复任务已被进程内 guard 跳过、replay 次数、动作数、digest match、原始状态和安全标志；它不读取 Gateway `file://` payload。该 replay guard 只在当前 Gateway 进程内有效，重启或多进程不会持久化去重，也不是跨进程、跨重启或分布式 exactly-once。每个正常 Gateway session 在 `gatewayConnected` 后、任何 action 开始前，都会写入 session 级 `auditLog` artifact `gateway-capability-snapshot.json`，记录 workspace、session workspace、platform、短 token 指纹、envelope `allowedActionKinds`、策略 allowlist 和 Shell/browser/screen/window/accessibility/desktop/workspace 的 real、dry-run、disabled、unavailable 或 workspace-only 状态；快照 artifact event 会附带安全 metadata，手机端 reducer 会把无 action 绑定的 `artifactStored` 保存为 session-level artifact，Mission Run、Gateway 会话卡片和 iPad 多栏工作台只用 metadata 派生 Gateway 能力复核摘要。v0.16 起，手机端也只从 `accessibilityTree` artifact event metadata 派生 Accessibility 观察复核摘要，展示 mode、policy、候选控件数、节点数、平台、redaction 和 safety flags，不读取 Gateway `file://` payload。v0.17 起，手机/iPad 还会从所有 Gateway artifact event metadata 派生通用 Artifact metadata 详情复核，展示 metadata 覆盖率、脱敏计数、最近带 metadata 的 artifact、安全键值和 safety flags；该复核仍不打开 `reference`，不读取 `file://` payload。v0.18 起，AgentTrace、Gateway 能力、Accessibility、Replay Guard 和通用 Artifact metadata 专用复核摘要统一使用同一套安全显示脱敏路径，异常 Gateway metadata 中的 raw token、Authorization/header、`toolArguments`、`file://`、workspace path、命令输出、网页正文、截图内容或草稿正文不会直接进入 UI。v0.19 起，Gateway `extractData` 输出 artifact 会附带 metadata-only 的提取完整性复核摘要，手机/iPad 端展示提取模式、完整性状态、row count、来源 artifact 计数、来源 kind 和 safety flags；该摘要不读取 artifact payload，不展示 row 内容、URL/path、命令输出、网页正文、草稿正文、token 或 `toolArguments`，也不新增 schema/action/event/artifact kind。v0.20 起，Gateway 会在既有 `messageDraft` 和 `operateDesktopApp` 相关 artifact event 上附带 metadata-only 的草稿/最终提交安全复核摘要，手机/iPad 端展示是否需要最终提交审批、是否需要用户确认、草稿正文和 paste text 是否省略、提交键阻断计数和 safety flags；该摘要不读取 artifact payload，不展示草稿正文、粘贴文本、按键原文、URL/path、联系人、token、header 或 `toolArguments`，也不新增 schema/action/event/artifact kind。v0.21 起，Gateway 会在既有 `browserTrace` 和 `browser-control-*.json` artifact event 上附带 metadata-only 的浏览器控制计划复核摘要，手机/iPad 端展示是否请求打开浏览器、URL/search 是否仅记录 presence、HTML 输入、network fetch/blocked、app/host allowlist、执行状态和 safety flags；该摘要不读取 artifact payload，不展示 raw URL、搜索词、HTML/page text、表单字段、候选控件 label、stdout/stderr、token、header 或 `toolArguments`，也不新增 schema/action/event/artifact kind。v0.22 起，Gateway 会在 `manageFiles` 的既有 `fileDiff` artifact event 和路径阻断审计 artifact event 上附带 metadata-only 的文件变更安全复核摘要，手机/iPad 端展示 workspace policy、write attempted/succeeded、created/modified/deleted count、path/content/diff omission 和 safety flags；该摘要不读取 artifact payload，不展示 raw path、workspace path、文件内容、diff、patch、token、header 或 `toolArguments`，也不新增 schema/action/event/artifact kind。v0.23 起，Gateway 会在 `runShellCommand` 的既有 `commandOutput` artifact event 上附带 metadata-only 的 Shell Command Safety 摘要，手机/iPad 端展示 structured command presence、parse 状态、Shell policy、allowlist match、execution attempted/executed、exit code presence/zero、stdout/stderr presence 和 command/stdout/stderr/cwd omission flags；该摘要不读取 artifact payload，不展示 raw command、binary/args、cwd/path、stdout、stderr、token、header、自然语言 instruction 或 `toolArguments`，也不新增 schema/action/event/artifact kind。v0.24 起，手机端 Mission Run 会把既有复核摘要按阻断、审批、metadata 缺失、高风险执行面和可行动性派生为复核优先队列；该队列只存在于 presentation layer，不写入 envelope，不改变 Gateway 协议，不读取 `file://` payload。v0.25 起，复核优先队列可在 Mission Run 内聚焦单个队列项：有对应详细复核 row 的 `reviewKind` 会筛选到该 row，审批/状态类或过期聚焦会保持全量详情并显示固定提示；该聚焦状态只属于手机端 presentation layer，不写入 envelope，不改变 Gateway 协议，不读取 `file://` payload。v0.26 起，Mission Run 会从完整复核优先队列派生复核态势摘要，展示总优先项、可行动项、高优先项、metadata 缺口、最高优先项和聚焦状态；该摘要只帮助人工判断复核是否准备好，不是自动安全裁决或执行 readiness，不写入 envelope，不改变 Gateway 协议，不读取 `file://` payload。v0.27 起，Mission Run 会从当前有效聚焦项、完整复核优先队列和可用详细复核派生下一步人工复核行动，提示先聚焦哪一类复核或在无证据时等待 Gateway 结果；该行动只复用聚焦 UI，不是自动执行计划，不写入 envelope，不改变 Gateway 协议，不读取 `file://` payload。v0.28 起，Mission Run 会从 artifact kind、metadata/redaction count、可用 detail review kind 和当前聚焦项派生 Artifact 证据索引，显示哪些复核项已有对应证据类型、metadata 是否同步以及当前聚焦项是否有证据；该索引只帮助人工选择复核入口，不是完整 payload viewer、自动安全裁决或自动修复器，不写入 envelope，不改变 Gateway 协议，不读取 `file://` payload。v0.29 起，Mission Run 会从既有阶段、结果计数、Artifact 证据索引、复核态势和下一步复核行动派生 Operator Strip，把 Gateway、证据、复核和下一步压缩为 4 条可扫视操作态势；该 Strip 只可聚焦已有复核项，不执行 Gateway 动作，不写入 envelope，不改变 Gateway 协议，不读取 `file://` payload。v0.30 起，Gateway `agentTrace` metadata 增加固定枚举 `handoffStatus`，手机端把证据缺口、审批等待、最终提交复核、阻断、可继续或完成状态展示为 AgentTrace handoff chip，并纳入复核优先队列；该状态只用于人工复核，不是自动执行授权、自动安全裁决或 Gateway readiness。v0.32 起，手机端 Mission Run 会从已脱敏 AgentTrace review、handoff 状态、readiness、satisfied/degraded/missing 计数和 selected next action 派生 Loop 继续态势卡，提示可继续、需要证据、等待审批、最终提交复核、阻断、完成或 metadata 待同步；卡片按钮只能聚焦 AgentTrace 详细复核，不会审批、发送、重试或自动继续。v0.33 起，Mission Run 会从当前聚焦项、复核优先队列、Artifact 证据索引、复核态势和下一步复核行动派生 Focus Context 聚焦上下文，显示当前聚焦是否有 detail row、证据/metadata 状态和清除聚焦入口；它只改变本地聚焦状态，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续。v0.35 起，Mission Run 会从 Artifact 证据索引、复核态势摘要、下一步复核行动、复核优先队列和有效聚焦项派生 Review Trail 复核路径，按固定四步展示证据覆盖、metadata 状态、最高优先复核和下一步；Trail 只改变本地聚焦，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续，不读取 `auditTrail` 原文或 Gateway `file://` payload。手机端还会在 Live Gateway request 附近显示连接健康摘要；该摘要只从已存在的 request、connection state、session 和事件派生，不写入 envelope，不读取 `file://` artifact payload。v0.12 起，客户端 WebSocket 在发送 envelope 后做一次 ping 观测，并在尚未收到桌面业务事件前最多重试 1 次；重连和 ping 只进入健康摘要，不代表后台保活、配对服务或桌面端心跳协议。快照、Mission Run Operator Strip、Loop 继续态势、Focus Context 聚焦上下文、Review Trail 复核路径、AgentTrace handoff status、Artifact 证据索引、复核优先队列、复核聚焦模式、复核态势摘要、下一步复核行动、Artifact metadata review、File Change Safety review、Shell Command Safety review、提取完整性 review、Browser Control review、Delivery Safety review、Accessibility review、replay guard、metadata 和 health 摘要不包含 raw token、Authorization header、自然语言 instruction、`toolArguments`、网页正文、命令输出、截图内容、草稿正文、文件内容、diff、patch 或完整 workspace path，也不扩大 Gateway 权限，手机端不读取 Gateway `file://` 内容。`controlBrowser` 可从本地 HTML 或受 allowlist 约束的 URL 生成浏览轨迹、链接、标题、表格、表单和候选控件；默认只写入浏览器打开/搜索计划并附 metadata-only 计划复核，设置 `CLAW_ALLOW_BROWSER_CONTROL=1`、`CLAW_BROWSER_APP_ALLOWLIST` 和 `CLAW_BROWSER_HOST_ALLOWLIST` 后，可在 macOS 上打开允许的桌面浏览器并跳转到结构化 URL/搜索结果。`extractData` 会消费前序 browser/file/shell/screen/accessibility artifact 生成结构化结果。`runAgentLoop` 会消费同一 session 内的 artifact context，写出 `agentTrace`：保留 `sourceArtifacts`、`evidenceRows`、`observations`、`nextActions`、`safetyGates` 等旧字段，并新增 `readiness`、`decisionChecklist`、`selectedNextAction`、`riskTags`、`stopReason`、`handoffStatus`、`handoffSummary`，用于解释证据是否充分、缺口在哪、当前推荐下一步、固定交接状态和必须停下等待审批的原因；这些字段只从结构化 `toolArguments` 和已有 artifact 推导，不扩大浏览器、Shell、AppleScript 或桌面 App 权限。Gateway 会把 agentTrace 的证据分、满足/降级/缺失信号、下一步、风险标签、停止原因、handoff 状态和 handoff 摘要压缩成可选字符串 metadata 随 artifact event 返回；手机端只用这些 metadata 做 Mission Run / Gateway 会话复核和 Loop 继续态势，不读取 Gateway `file://` 内容。`manageFiles` 可按 `toolArguments.writePath/writeText` 在 workspace 内真实写文件，路径逃逸会被阻断，并只在 metadata 中暴露计数、presence 和 omission flags。Shell 只接受结构化 `toolArguments.shellCommand`，默认 dry-run；必须同时设置 `CLAW_ALLOW_SHELL=1` 和 `CLAW_SHELL_ALLOWLIST` 才会真执行；Shell safety metadata 只表达 policy/result/presence/omission 状态。屏幕观察默认 dry-run，设置 `CLAW_ALLOW_SCREEN_CAPTURE=1` 后可在 macOS 上生成真实截图 artifact，设置 `CLAW_ALLOW_WINDOW_METADATA=1` 后可读取前台窗口元数据；设置 `CLAW_ALLOW_ACCESSIBILITY_OBSERVE=1` 后，授权 macOS Gateway 可用固定只读 System Events 脚本采集前台 App/窗口和有限候选控件摘要，无权限或非 macOS 时写入可审计 accessibility-failed/accessibility-unavailable artifact。桌面 App 控制默认停在审批闸门，设置 `CLAW_ALLOW_DESKTOP_CONTROL=1`、`CLAW_DESKTOP_APP_ALLOWLIST` 和 `CLAW_DESKTOP_KEY_ALLOWLIST` 后，可在 macOS 上聚焦允许的 App、粘贴结构化草稿、执行允许的非提交快捷键，并在最终提交前回到用户确认。

v0.36 起，Mission Run Approval Queue 是手机端 presentation-layer 队列：它从现有 task action、Gateway result、Delivery Safety review、AgentTrace review 和复核优先队列汇总手机审批、Gateway 等待确认、最终提交闸门、AgentTrace 交接以及失败/可重试复核。队列只使用固定标题、状态、action kind、approval level 和已脱敏 compact status；按钮只改变本地聚焦，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续，不写入 envelope，不读取 `toolArguments`、artifact `reference`、`auditTrail` 原文或 Gateway `file://` payload。

v0.37 起，Mission Run Payload Safety Ledger 是手机端 presentation-layer 载荷边界账本：它只从已有 detail review summary 的 `hasMetadata` 和白名单 `safetyFlags` 派生，汇总哪些复核项声明 `artifact-payload-not-read`、哪些是 `metadata-only`、有多少省略/保护信号以及 metadata 缺口。Ledger 在 compact Mission Run 和 iPad/mac 右侧 Dock 展示；row 只改变本地聚焦，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续，不写入 envelope，不读取 artifact `reference`、Gateway `file://` payload、文件内容、命令输出、diff、网页正文、草稿正文或 `toolArguments`。

v0.38 起，Mission Run Mac Agent Readiness Board 是手机端 presentation-layer 就绪看板：它只从已有 Gateway capability、Accessibility、AgentTrace/Loop、review readiness 和 approval queue 派生连接回执、桌面能力、屏幕观察、Loop 继续和人工闸门五类 row，帮助 iPad/mac 工作台快速判断桌面智能体是否具备继续下一轮的证据和人工确认条件。Board 在 compact Mission Run 和 iPad/mac 右侧 Dock 展示；row 只改变本地聚焦，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续，不写入 envelope，不读取 artifact `reference`、Gateway `file://` payload、文件内容、命令输出、diff、网页正文、草稿正文或 `toolArguments`。

v0.39 起，Mission Run Mac Gateway Action Preflight Matrix 是手机端 presentation-layer 动作预检矩阵：它从当前 `ClawMobileTask.actions`、actionID 关联的 Gateway result、审批级别、结构化参数 presence 和既有复核域派生每个 action 的可派发、阻断、metadata 待同步、降级和人工确认状态。Matrix 在 compact Mission Run 和 iPad/mac 右侧 Dock 展示；row 只改变本地聚焦，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续，不写入 envelope，不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、文件内容、命令输出、diff、网页正文或草稿正文。

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

`direct-smoke` 不监听端口，用 `--emit-events` 直接验证同一套 Gateway handler、workspace artifact、browser trace 到结构化提取链路、Browser Control metadata、File Change Safety metadata、Shell Command Safety metadata、提取完整性 metadata、Delivery Safety metadata、workspace 文件真实写入、路径逃逸阻断、写入失败审计、workspace symlink 阻断、Shell dry-run 阻断、allowlist Shell 真执行、缺少结构化 Shell 命令阻断、浏览器打开/搜索计划与 allowlist 阻断、`agentTrace` 证据充分性/降级证据/缺口/下一步选择/审批停止原因/handoff 状态、artifact metadata 与 trace JSON 关键字段一致性、同一进程内重复 envelope 的 replay guard，以及桌面 App 控制的审批闸门和 allowlist 阻断；Swift logic smoke 还覆盖 Mission Run Operator Strip、Loop 继续态势、Mac Agent Readiness Board 就绪看板、Mac Gateway Action Preflight Matrix 动作预检矩阵、Focus Context 聚焦上下文、Review Detail Dock、Review Trail 复核路径、Approval Queue 审批队列、Payload Safety Ledger 载荷安全账本、AgentTrace handoff 状态、Artifact 证据索引、复核优先队列的排序、聚焦过滤、复核态势摘要、下一步复核行动和脱敏断言；`claw-gateway-smoke` 会实际启动 WebSocket server，并覆盖同类 `agentTrace` 证据策略、degraded signal metadata、handoff status metadata 断言、Browser Control metadata、File Change Safety metadata、Shell Command Safety metadata、提取完整性 metadata、Delivery Safety metadata、路径逃逸阻断、写入失败审计和同一 Gateway 进程内两次 WebSocket 连接的 replay guard。

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

- 2026-07-06：新增 v0.39 Mac Gateway Action Preflight Matrix 动作预检矩阵。手机端从当前任务 action、actionID 关联的 Gateway result、审批级别、结构化参数 presence 和既有复核域派生每个 action 的可派发、阻断、metadata 待同步、降级和人工确认状态；compact Mission Run 和 iPad/mac 右侧 Dock 复用同一矩阵。Matrix 只改变本地聚焦，不读取或展示 `toolArguments` 原文、Gateway `file://` payload、artifact `reference`、文件内容、命令输出、diff、网页正文或草稿正文，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续。本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-06：新增 v0.38 Mac Agent Readiness Board 就绪看板。手机端从既有 Gateway capability、Accessibility、AgentTrace/Loop、复核态势和审批队列派生连接、能力、观察、Loop 和人工闸门五类 readiness row；compact Mission Run 和 iPad/mac 右侧 Dock 复用同一看板。Board 只改变本地聚焦，不读取 Gateway `file://` payload、artifact `reference`、文件内容、命令输出、diff、网页正文、草稿正文或 `toolArguments`，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续。本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-06：新增 v0.37 Artifact Payload Safety Ledger 载荷安全账本。手机端从已有 detail review 的 `hasMetadata` 和白名单 `safetyFlags` 派生 payload 边界摘要，展示 payload 未读取、metadata-only、保护/省略信号和 metadata 缺口；compact Mission Run 和 iPad/mac 右侧 Dock 复用同一账本。Ledger 只改变本地聚焦，不读取 Gateway `file://` payload、artifact `reference`、文件内容、命令输出、diff、网页正文、草稿正文或 `toolArguments`，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续。本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-06：新增 v0.36 Mission Approval Queue 审批队列。手机端从现有 task action、Gateway result、Delivery Safety review、AgentTrace review 和复核优先队列派生待确认队列，覆盖发送前手机审批、发送后 Gateway 确认、最终提交闸门、AgentTrace 交接和失败/可重试复核；compact Mission Run 和 iPad/mac 右侧 Dock 复用同一队列。队列只改变本地聚焦，不读取 Gateway `file://` payload、artifact `reference`、`auditTrail` 原文或 `toolArguments`，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续。本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-06：新增 v0.35 Mission Review Trail 复核路径。手机端从 Artifact 证据索引、复核态势、下一步复核行动、复核优先队列和当前有效聚焦项派生固定四步路径，展示证据覆盖、metadata 状态、最高优先复核和下一步；compact Mission Run 和 iPad/mac 右侧 Dock 复用同一摘要。Trail 只改变本地聚焦，不读取 Gateway `file://` payload 或 `auditTrail` 原文，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续。本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-06：新增 v0.34 iPad Mission Review Detail Dock。regular iPad/mac 工作台把 Mission Run 聚焦状态提升到左右栏共享，右侧顶部新增 Mission 复核详情 Dock，显示当前聚焦、下一步或全量详细复核 fallback；compact iPhone 保持单栏。Dock 只复用既有 metadata-only 安全摘要和固定文案，不读取 Gateway `file://` payload，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续。本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-06：新增 v0.33 Mission Run Focus Context 聚焦上下文。手机端从当前聚焦项、复核优先队列、Artifact 证据索引、复核态势和下一步复核行动派生聚焦上下文卡，提示当前聚焦是否有 detail row、证据/metadata 状态和清除聚焦入口；按钮只改变本地聚焦，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续。本轮不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header/workspace path 或 `toolArguments`，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-06：新增 v0.32 Mission Run Loop 继续态势。手机端从安全 AgentTrace metadata 派生 Loop 继续态势卡，汇总 handoff 状态、readiness、满足/降级/缺失证据计数、下一步 action 和审批要求；按钮只能聚焦 AgentTrace 详细复核，不执行发送、审批、重试或自动继续。本轮不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header/workspace path 或 `toolArguments`，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-06：新增 v0.31 AgentTrace mac 证据质量。Gateway `runAgentLoop` 将输入证据分成 satisfied、degraded 和 missing，dry-run、window metadata、network blocked、failed、unavailable 或 not-requested 证据不再被当成真实可继续证据；metadata 新增安全 `degradedSignals`，不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-06：新增 v0.30 AgentTrace handoff 状态。Gateway `runAgentLoop` 从 readiness、selected next action、risk tags 和 stop reason 派生固定 `handoffStatus` metadata，手机端 Mission Run、Gateway 会话和 result row 展示 handoff chip，并把需要证据、等待审批、最终提交复核和阻断状态纳入复核优先队列；本轮不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-06：新增 v0.29 iPad Mission Run Operator Strip。手机端从阶段、回合进度、结果计数、Artifact 证据索引、复核态势和下一步复核行动派生 4 条操作态势 lane，帮助 iPad/宽屏工作台快速扫视 Gateway、证据、复核和下一步；本轮不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-06：新增 v0.28 Mission Run Artifact 证据索引。手机端从 artifact kind、metadata/redaction count、可用 detail review kind 和当前聚焦项派生证据索引，在 artifact chips 后展示各复核项的证据类型覆盖和 metadata 状态，并可聚焦对应详细复核；本轮不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-06：新增 v0.27 Mission Run 下一步复核行动。手机端从当前有效聚焦项、完整复核优先队列和可用详细复核派生下一步人工复核行动，并在 Mission Run 中提供聚焦按钮；本轮不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-06：新增 v0.26 Mission Run 复核态势摘要。手机端从完整复核优先队列和已有 detail review kind 派生人工复核态势，展示总优先项、可行动项、高优先项、metadata 缺口、最高优先项和聚焦状态，并可一键聚焦最高优先项。本轮不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`，不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。
- 2026-07-05：新增 v0.23 Shell 命令安全复核。Gateway `runShellCommand` 的既有 `commandOutput` artifact event metadata 增加 structured command presence、parse 状态、Shell policy、allowlist match、execution attempted/executed、exit code presence/zero、stdout/stderr presence 和 command/stdout/stderr/cwd omission flags；Mission Run、Gateway 会话和单个 result row 展示 metadata-only Shell Command Safety 摘要。本轮不读取 Gateway `file://` payload，不展示 raw command、binary/args、cwd/path、stdout、stderr、token、header、自然语言 instruction 或 `toolArguments`，不新增 schema/event/action/artifact kind，不扩大 Gateway Shell 权限。
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
