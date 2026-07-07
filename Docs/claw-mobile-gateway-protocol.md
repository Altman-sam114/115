# Claw Computer-Control Gateway 协议草案

调研/设计日期：2026-06-10

## 定位

本 App 作为 OpenClaw 式电脑智能体的手机控制台：

1. 用户在手机端输入自然语言电脑任务。
2. `PhoneAgentPlanner` 生成可审查的电脑接管计划。
3. `ClawMobileBridge` 把计划转换成 Claw action 列表。
4. App 生成 `ClawMobileEnvelope`，通过模拟事件流或 WebSocket live gateway 交给用户授权的 Claw Gateway 审批和执行。
5. 真正的浏览器、文件、Shell、桌面 App 和屏幕观察动作发生在桌面/自托管网关，不发生在 iOS 沙盒内。

## Envelope

当前 schema 版本：`claw.computer.control.v1`

核心字段：

- `sourceApp`: 固定为 `Claw Controller`。
- `gateway`: 网关端点、设备名、安全模式、token 指纹、允许动作列表、审计策略。
- `task`: 用户指令、来源设备、目标网关、风险分、状态和动作列表。
- `task.actions[].toolArguments`: 结构化工具参数。桌面 Gateway 只应执行结构化字段，不应把自然语言 `instruction` 直接交给 Shell 或桌面自动化。
- `approvalSummary`: 审批点、阻断点和敏感动作统计。
- `auditRequired`: 是否必须写审计记录。

Token 不写入 payload，只保留短 SHA-256 指纹，例如 `sha256:abc123`。

`allowedActionKinds` 是执行策略，不只是 UI 展示：如果网关配置未允许某个动作，`ClawMobileBridge` 会把该动作标记为 `blocked`，整项任务进入 `blocked` 状态。`requiresApprovalForSensitiveData` 开启时，屏幕观察、浏览器控制、桌面 App 操作、文件写入、Shell 命令、联系人读取和消息/邮件草稿等敏感动作需要用户或网关确认。

## 电脑动作

| kind | 用途 | 执行端 | 默认审批 |
| --- | --- | --- | --- |
| `analyzeLocalContext` | 本地任务规划 | 手机端 | 自动 |
| `requestPermission` | 请求系统权限 | 手机端 | 自动/用户确认 |
| `observeScreen` | 截图、窗口标题、受控可访问性摘要 | Claw Gateway | 网关确认 |
| `controlBrowser` | 打开网页、搜索、点击、提取 | Claw Gateway | 网关确认 |
| `operateDesktopApp` | 控制桌面软件窗口和控件 | Claw Gateway | 网关确认 |
| `manageFiles` | 查找、移动、导出、上传文件 | Claw Gateway | 网关确认 |
| `runShellCommand` | 运行脚本、测试、构建命令 | Claw Gateway | 网关确认 |
| `extractData` | 从网页/文件/窗口提取结构化数据 | Claw Gateway | 网关确认 |
| `runAgentLoop` | 基于已有 artifact 生成证据化下一步建议 | Claw Gateway | 网关确认 |
| `readContacts` | 匹配联系人 | 手机端授权 | 用户确认 |
| `composeMessage` | 短信/IM 草稿 | 手机端/网关 | 用户确认 |
| `composeEmail` | 邮件草稿 | 手机端/网关 | 用户确认 |
| `createReminder` | 创建提醒/日程 | 手机端授权 | 自动 |
| `openExternalURL` | 打开链接/App | 手机端 | 自动 |
| `backgroundRefresh` | 检查网关任务状态 | 手机端 | 系统调度 |
| `desktopHandoff` | 泛化桌面接管 | Claw Gateway | 网关确认 |
| `auditLog` | 审计记录 | 手机端 | 自动 |
| `blockedUnsupported` | 平台禁止动作 | 不执行 | 已阻断 |

## 任务状态

- `queued`: 不含阻断动作且无需人工确认，可进入队列。
- `waitingForApproval`: 有用户确认或网关确认点。
- `readyToSend`: 用户已在 App 内审批，允许发送给网关。
- `sent`: 已发送给模拟事件流或 live gateway。
- `blocked`: 包含平台禁止动作或网关白名单禁止动作。

## Dispatch Mode

当前手机端支持两种发送模式：

- `simulatedEventStream`: 不连接桌面端，使用本地事件流模拟 Gateway 运行。用于无桌面端时审查计划、artifact 和失败重试。
- `liveGateway`: 生成 WebSocket 请求，把 envelope 发给 `ws://` 或 `wss://` 桌面 Gateway，并等待桌面端持续推送事件。如果 endpoint 或 token 未配置，会安全回退到模拟事件流。

`ClawGatewayLiveRequest` 会记录 endpoint、transport、requestPath、tokenFingerprint、headers、bodyBytes、taskID、command、actionCount 和 preflight 结果。它不保存原始 token。v0.11 起，手机端会从该 request、`ClawGatewayConnectionState`、最新 `ClawGatewaySession` 和 session 事件派生 `ClawGatewayLiveHealthSummary`，用于展示脱敏 endpoint、transport、request path、短 token 指纹、preflight、是否可尝试 live、事件数量、最新事件、fallback/error/completed 和 session 状态。v0.12 起，该摘要还会显示 transport attempt、重连次数、ping 状态和脱敏 transport error。

## Gateway Session

发送任务后，手机端维护 `ClawGatewaySession`，用于呈现 OpenClaw 式的事件闭环：

- `status`: `prepared`、`running`、`completed`、`needsAttention`、`blocked`。
- `results`: 每个 action 的执行结果，包括 `pending`、`running`、`succeeded`、`failed`、`skipped`、`waitingForApproval`。
- `artifacts`: 网关回传的截图、可访问性树、命令输出、文件 diff、浏览轨迹、智能体轨迹、消息草稿和审计日志引用；v0.10 起手机端把 action-bound artifacts 和 session-level artifacts 一起计入 artifact count/kind summary。
- `sessionArtifacts`: 不绑定 action 的 session 级 artifact，例如 `gateway-capability-snapshot.json`；它不创建伪 action result，不影响成功/失败统计。
- `auditTrail`: session 级事件，例如 sandbox 工作目录、命令白名单、token 指纹和 retry 记录。

v0.9 起，桌面 Gateway 在 `gatewayConnected` 后、任何 action `actionStarted` 前，写入一个 session 级 `auditLog` artifact：`gateway-capability-snapshot.json`。它复用既有 `artifactStored` event kind，事件可以没有 `actionID`/`actionKind`，payload 只包含 workspace、session workspace、platform、短 token 指纹、envelope `allowedActionKinds`、策略 allowlist 和 capability 状态；不包含 raw token、Authorization header、用户自然语言、action `instruction`、`toolArguments`、网页正文、命令输出、截图内容或草稿正文。v0.10 起，该 artifact event 附带小型字符串 metadata，v0.15 起允许键包含 `snapshotKind`、`tokenConfigured`、`tokenRequired`、`tokenFingerprint`、`allowedActionKinds`、`workspaceState`、`shellState`、`browserControlState`、`browserNetworkState`、`screenCaptureState`、`windowMetadataState`、`accessibilityTreeState`、`desktopControlState`、`safetyFlags` 和 `platform`。手机端只用这些 metadata 派生 Gateway capability review，不读取 `file://` payload。该快照只用于审计和复核，不改变 `claw.computer.control.v1` schema，不新增 action/artifact/event kind，也不扩大 Gateway 权限。

v0.14 起，手机端会识别 session 级 `task-replay-guard.json` `auditLog` artifact，或 metadata 中带 `replayGuard=taskReplayGuard` 的 `auditLog` artifact，并只从 artifact event metadata 派生 `Gateway Replay Guard` 复核摘要。建议 metadata 键包括 `replayGuard`、`decision`、`taskID`、`replayDigest`、`digestMatchesFirst`、`firstSessionID`、`originalStatus`、`replayCount`、`actionCount`、`actionKinds` 和 `safetyFlags`。手机端可显示短 task id、短 digest、replay 次数、跳过动作数、首次状态、digest 是否匹配和安全标志；不得读取 `file://` payload，不得展示 raw token、Authorization header、`instruction`、`toolArguments`、业务 artifact payload 或完整 workspace path。metadata 缺失时，手机端必须降级为“metadata 待同步”。

v0.16 起，手机端会识别 `accessibilityTree` artifact 上的安全 metadata，并派生 Accessibility 观察复核摘要。v0.49 起，建议 metadata 键包括 `accessibilityTree=observeSummary`、`mode`、`accessibilityPolicy`、`signalQuality`、`evidenceTier`、`controlCoverage`、`includeAccessibilityTree`、`maxCandidateControls`、`nodeCount`、`candidateControlCount`、`platform`、`redaction`、`valuesOmitted`、`passwordFieldsOmitted`、`rawTextOmitted`、`actionExecutionSupported` 和 `safetyFlags`。手机端可显示本次观察是 dry-run、window-metadata、accessibility-summary、permission-missing、platform-unavailable 或 not-requested，以及证据层级、候选控件覆盖、候选控件数、节点数、省略标志和 observe-only 状态；不得读取 `file://` payload，不得展示 raw token、Authorization header、`toolArguments`、完整 workspace path、前台 App 名、窗口标题、控件 label/description、命令输出、截图内容、网页正文、raw text 或密码字段值。metadata 缺失时必须降级为“metadata 待同步”。

v0.17 起，手机端会对普通 Gateway artifact event metadata 派生通用 `Artifact metadata` 复核摘要。该摘要只统计当前 session 或 result 的 artifact 数、带 metadata 数、脱敏数，并展示最近带 metadata artifact 的安全键值和 `safetyFlags`；它不打开 artifact `reference`，不读取 `file://` payload，不新增协议字段，也不得展示 raw token、Authorization header、`toolArguments`、完整 workspace path、命令输出、网页正文、截图内容、草稿正文或密码字段值。metadata 缺失时必须降级为“metadata 待同步”。

v0.18 起，手机端所有专用 metadata 复核摘要共享同一套 UI 安全显示脱敏路径。AgentTrace、Gateway capability、Accessibility、Replay Guard 和通用 Artifact metadata review 的可见字符串在进入 SwiftUI 前必须清理 raw token、Authorization/header、Bearer、`toolArguments`、`file://`、完整 workspace path、命令输出、网页正文、截图内容和草稿正文。该加固不新增 Gateway 字段，不读取 artifact payload，也不改变 `claw.computer.control.v1` schema。

v0.19 起，`extractData` 输出 artifact event 会附带 metadata-only 的提取完整性复核摘要。建议 metadata 键包括 `extractionReview=artifactGrounded`、`mode`、`validateCompleteness`、`rowCount`、`completenessStatus`、`browserTraceCount`、`fileDiffCount`、`commandOutputCount`、`screenObservationCount`、`accessibilityTreeCount`、`messageDraftCount`、`sourceArtifactKinds` 和 `safetyFlags`。手机端可显示提取模式、完整性状态、行数、来源 artifact 计数、来源 kind 和安全标志；不得读取 `file://` payload，不得展示 row 内容、URL/path、命令输出、网页正文、草稿正文、联系人、raw token、Authorization/header、cookie 或 `toolArguments`。metadata 缺失时必须降级为“metadata 待同步”。该摘要不新增 schema 字段、action kind、artifact kind 或 event kind，也不扩大 Gateway 权限。

v0.20 起，`messageDraft` 和 `operateDesktopApp` 相关 artifact event 会附带 metadata-only 的草稿/最终提交安全复核摘要。建议 metadata 键包括 `deliveryReview=finalSubmitGate`、`mode`、`actionKind`、`targetKind`、`desktopPolicyDiagnostic`、`desktopRetryableReason`、`automationAttempted`、`appPolicyChecked`、`keyPolicyChecked`、`finalSubmitRequiresApproval`、`userApprovalRequired`、`draftBodyOmitted`、`pasteTextOmitted`、`submitBlocked`、`allowedKeyCount`、`blockedKeyCount`、`blockedSubmitKeyCount` 和 `safetyFlags`。v0.50 起，`operateDesktopApp` 的 `desktopPolicyDiagnostic` 固定为 `not-requested`、`dry-run`、`platform-unavailable`、`missing-target`、`app-blocked`、`key-blocked`、`automation-attempted` 或 `automation-failed`，`desktopRetryableReason` 固定为 `none`、`enable-desktop-control`、`requires-macos`、`provide-target-app`、`allow-desktop-app`、`allow-desktop-key`、`automation-failed` 或 `user-final-submit`。手机端可显示草稿或桌面动作是否停在最终提交闸门、是否需要用户确认、桌面策略诊断、重试原因、是否尝试自动化、是否检查 app/key 策略、草稿正文/paste text 是否省略和提交键阻断计数；不得读取 `file://` payload，不得展示草稿正文、粘贴文本、按键原文、target app、allowlist 值、URL/path、联系人、raw token、Authorization/header、cookie 或 `toolArguments`。metadata 缺失时必须降级为“metadata 待同步”。该摘要不新增 schema 字段、action kind、artifact kind 或 event kind，也不扩大 Gateway 权限。

v0.21 起，`controlBrowser` 的 `browserTrace` 和 `browser-control-*.json` artifact event 会附带 metadata-only 的浏览器控制计划复核摘要。建议 metadata 键包括 `browserReview=controlPlan`、`mode`、`actionKind=controlBrowser`、`browserControlPolicy`、`policyDiagnostic`、`retryableReason`、`browserControlRequested`、`openInBrowser`、`openAttempted`、`targetURLPresent`、`searchQueryPresent`、`localHTMLInput`、`networkFetchAttempted`、`networkBlocked`、`appAllowlistEnforced`、`hostAllowlistEnforced`、`appPolicyChecked`、`hostPolicyChecked`、`executed`、`timedOut`、`resultStatus` 和 `safetyFlags`。v0.48 起，`policyDiagnostic` 和 `retryableReason` 只能使用固定枚举，用于表达 dry-run、未请求、平台不可用、app/host allowlist 阻断、已打开或自动化失败；手机端可显示是否请求打开浏览器、是否尝试打开、URL/search 是否仅记录 presence、HTML 输入、network fetch/blocked、app/host allowlist、策略检查和执行状态；不得读取 `file://` payload，不得展示 raw URL、search query、HTML/page text、form fields、candidate control labels、browser app name、host、allowlist 值、stdout/stderr、raw token、Authorization/header、cookie 或 `toolArguments`。metadata 缺失时必须降级为“metadata 待同步”。该摘要不新增 schema 字段、action kind、artifact kind 或 event kind，也不扩大 Gateway 权限。

v0.22 起，`manageFiles` 的既有 `fileDiff` artifact event 以及路径阻断/写入失败审计 artifact event 会附带 metadata-only 的文件变更安全复核摘要。建议 metadata 键包括 `fileChangeReview=workspaceWrite`、`mode`、`actionKind=manageFiles`、`workspacePolicy=session-workspace-only`、`workspaceScoped`、`pathEscapeBlocked`、`writeAttempted`、`writeSucceeded`、`createdFileCount`、`modifiedFileCount`、`deletedFileCount`、`requestedPathPresent`、`writeTextPresent`、`rawPathOmitted`、`contentOmitted`、`diffOmitted`、`resultStatus` 和 `safetyFlags`。手机端可显示 workspace policy、写入是否尝试/成功、路径逃逸是否阻断、变更计数和 path/content/diff 省略状态；不得读取 `file://` payload，不得展示 raw path、workspace/sessionWorkspace、文件名/目录名、文件内容、diff hunk、patch、stdout/stderr、raw token、Authorization/header、cookie 或 `toolArguments`。metadata 缺失时必须降级为“metadata 待同步”。该摘要不新增 schema 字段、action kind、artifact kind 或 event kind，也不扩大 Gateway 权限。

v0.23 起，`runShellCommand` 的既有 `commandOutput` artifact event 会附带 metadata-only 的 Shell 命令安全复核摘要。建议 metadata 键包括 `shellReview=commandSafety`、`mode`、`actionKind=runShellCommand`、`shellPolicy`、`structuredCommandPresent`、`commandParsed`、`allowlistConfigured`、`allowlistMatched`、`executionAttempted`、`executed`、`timedOut`、`exitCodePresent`、`exitCodeZero`、`stdoutPresent`、`stderrPresent`、`commandOmitted`、`stdoutOmitted`、`stderrOmitted`、`cwdOmitted`、`resultStatus` 和 `safetyFlags`。手机端可显示结构化命令是否存在、解析状态、Shell policy、allowlist 是否命中、是否尝试/完成执行、exit code 是否可复核、stdout/stderr 是否存在以及 command/stdout/stderr/cwd 省略状态；不得读取 `file://` payload，不得展示 raw command、binary/args、cwd、workspace/session path、stdout/stderr 内容、raw token、Authorization/header、cookie、自然语言 instruction 或 `toolArguments`。metadata 缺失时必须降级为“metadata 待同步”。该摘要不新增 schema 字段、action kind、artifact kind 或 event kind，也不扩大 Gateway Shell 权限。

v0.11 起，Gateway Session 面板在 Live request 附近展示连接健康摘要。该摘要只存在于手机端 presentation layer：不会写入 `ClawMobileEnvelope`，不会回传给 Gateway，不新增 `ClawGatewayEventKind`、action kind 或 artifact kind，也不读取 Gateway `file://` artifact payload。为了保持 live 状态可解释，手机端收到 `.gatewayConnected`、`.actionStarted`、`.artifactStored`、`.actionCompleted`、`.actionFailed`、`.approvalRequested` 和 `.actionSkipped` 等非终态 live 事件后保持 `streaming`，`.sessionCompleted`、`.fallbackUsed` 和 transport error 仍走终态或 fallback 路径。

失败动作可以标记 `isRetryable`。手机端二次确认后，网关可重试失败动作并把新的 artifact 追加到对应 result。

## Mission Run Presentation Layer

v0.2 增加的 Mission Run 任务回合摘要只存在于手机端展示层。`ClawMissionRunSummary` 从 `ClawAutonomousLoopState`、最新 `ClawMobileTask` 和最新 `ClawGatewaySession` 派生，用于在电脑接管首屏展示当前目标、阶段、回合进度、下一步主动作、风险分、审批点、阻断数、artifact kind 摘要、Approval Fast Lane、Control Snapshot、Operator Strip、Loop continuation brief、Mac Agent Readiness Board、Mac Gateway Action Preflight Matrix、Mac Agent Evidence Coverage Map、Mac Agent Next Step Deck、Mac Agent Run Timeline、Mac Agent Continuation Gate、Mac Agent Review Radar、Mac Agent Handoff Brief、Focus Context、Review Detail Dock、Review Trail、Approval Queue、Payload Safety Ledger、Artifact evidence index、Artifact metadata review、File Change Safety review、Shell Command Safety review、Extraction completeness review、Browser Control review、Delivery Safety review、最近 AgentTrace handoff 状态和复核摘要、Gateway capability review、Accessibility artifact review、Gateway Replay Guard review 和成功/失败/可重试计数。

v0.24 起，`ClawMissionRunSummary` 还会从既有状态和 review summary 派生 `reviewPriorityQueue` 或等价复核优先队列。该队列按阻断、审批、metadata 缺失、高风险执行面和可行动性排序，用于在 Mission Run 首屏先展示最需要人工查看的复核项。队列只包含固定文案、数字、枚举状态和已脱敏 summary 字段，不读取 artifact `reference`，不打开 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header/`toolArguments`。

v0.25 起，Mission Run 可在复核优先队列上聚焦单个队列项。聚焦只使用队列项 `reviewKind` 和既有 review summary 是否存在来筛选详细复核 row；`approval`、`gateway-status` 或未知/过期聚焦项没有对应详细 row 时，手机端保持全量详情并显示固定提示。该聚焦状态只存在于手机端 presentation layer，不写入 envelope，不回传 Gateway，不读取 artifact `reference` 或 Gateway `file://` payload。

v0.26 起，Mission Run 可从完整复核优先队列和既有 detail review kind 派生复核态势摘要。摘要可展示总优先项、可行动项、critical/high 项、metadata 待同步项、可用详细复核数、最高优先项和当前聚焦项是否有 detail row。该摘要只用于人工判断复核是否准备好和下一步看哪里，不是自动安全裁决或 Gateway 执行 readiness；不写入 envelope，不回传 Gateway，不读取 artifact `reference` 或 Gateway `file://` payload。

v0.27 起，Mission Run 可从当前有效聚焦项、完整复核优先队列和既有 detail review kind 派生下一步人工复核行动。行动建议优先使用当前聚焦项，否则使用完整队列最高优先项；没有队列但已有 detail review 时降级为抽查详细复核，完全 idle 时提示等待 Gateway 证据。该行动只用于帮助用户聚焦下一项复核，不是自动执行计划、自动安全裁决或 Gateway 执行 readiness；不写入 envelope，不回传 Gateway，不读取 artifact `reference` 或 Gateway `file://` payload。

v0.28 起，Mission Run 可从 artifact kind、Artifact metadata review 的 metadata/redaction count、可用 detail review kind 和当前聚焦项派生 Artifact 证据索引。索引用固定 review kind 到 artifact kind 的映射展示哪些复核项已有证据类型、metadata 是否同步、当前聚焦项是否有证据，并允许聚焦对应详细复核。该索引只用于帮助人工选择复核入口，不是完整 payload viewer、自动安全裁决、恶意检测、完整审计或自动修复器；不写入 envelope，不回传 Gateway，不读取 artifact `reference` 或 Gateway `file://` payload。

v0.29 起，Mission Run 可从既有阶段、回合进度、结果计数、Artifact 证据索引、复核态势摘要和下一步复核行动派生 Operator Strip。Strip 用 4 个固定 lane 展示 Gateway、证据、复核和下一步态势；只有已有 detail review kind 可被聚焦，不执行 Gateway 动作，不打开 artifact 内容。该 Strip 只用于 iPad/宽屏和 compact Mission Run 的快速扫视，不是自动执行控制台、自动安全裁决或 Gateway readiness；不写入 envelope，不回传 Gateway，不读取 artifact `reference` 或 Gateway `file://` payload。

v0.32 起，Mission Run 可从既有 AgentTrace review、handoff 状态、readiness、satisfied/degraded/missing 计数和 selected next action 派生 Loop continuation brief。Brief 用固定文案提示可继续、需要证据、等待审批、最终提交复核、阻断、完成、metadata 待同步或尚无 AgentTrace；唯一按钮只能聚焦 `agent-trace` detail review，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续。该 Brief 只用于人工判断下一轮是否可由用户显式触发，不是自动执行授权、自动安全裁决或 Gateway readiness；不写入 envelope，不回传 Gateway，不读取 artifact `reference` 或 Gateway `file://` payload。

v0.33 起，Mission Run 可从当前有效聚焦项、复核优先队列、Artifact 证据索引、复核态势摘要和下一步复核行动派生 Focus Context 聚焦上下文。上下文会展示当前聚焦是否有 detail row、证据是否覆盖、metadata 是否待核、是否需要人工动作，并提供清除聚焦或聚焦对应 detail 的按钮。该上下文只用于解释本地复核焦点，不是自动执行计划、自动安全裁决或 Gateway readiness；按钮不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取 artifact `reference` 或 Gateway `file://` payload。

v0.34 起，regular iPad/mac 工作台会把 Mission Run 聚焦状态提升为左右栏共享，并在右侧顶部显示 Mission Review Detail Dock。Dock 通过 `reviewDetailDockSummary(focusedOn:)` 描述当前是无证据、全量详情、单项 detail 聚焦、状态级聚焦回退还是过期聚焦回退；实际详情 row 仍复用既有 metadata-only 安全摘要。Dock 只改变本地聚焦或清除聚焦，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取 artifact `reference` 或 Gateway `file://` payload。

v0.35 起，Mission Run 可从 Artifact 证据索引、复核态势摘要、下一步复核行动、复核优先队列和当前有效聚焦项派生 Mission Review Trail。Trail 用固定四步短路径展示证据覆盖、metadata 状态、最高优先复核和下一步复核；在 compact Mission Run 和 regular iPad/mac 右侧 Dock 中复用同一摘要。Trail 按钮只聚焦已有 detail 或队列项，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取 artifact `reference`、`auditTrail` 原文或 Gateway `file://` payload。

v0.36 起，Mission Run 可从既有 task action、Gateway action result、Delivery Safety review、AgentTrace review 和复核优先队列派生 Approval Queue 审批队列。队列按固定 rank 展示发送前手机审批、发送后 Gateway 等待确认、最终提交安全、AgentTrace 交接、失败/可重试复核和策略阻断；item 只包含固定 title/status/reason/icon/reviewKind、action kind title、approval title、metadata 状态和是否可聚焦。队列按钮只聚焦已有 detail review 或状态项，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取 action `toolArguments`、artifact `reference`、`auditTrail` 原文或 Gateway `file://` payload。

v0.37 起，Mission Run 可从既有 detail review summary 的 `hasMetadata` 和白名单 `safetyFlags` 派生 Payload Safety Ledger 载荷安全账本。账本展示每类详细复核是否有 metadata、是否声明 `artifact-payload-not-read`、是否为 `metadata-only`、省略/保护信号数量和 metadata 缺口；item 只包含固定 title/status/guidance/icon/reviewKind、计数和可聚焦状态。账本按钮只聚焦已有 detail review，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取 artifact `reference`、Gateway `file://` payload、文件内容、命令输出、diff、网页正文、草稿正文或 action `toolArguments`。

v0.38 起，Mission Run 可从既有 Gateway capability review、Accessibility review、AgentTrace/Loop continuation、复核态势和审批队列派生 Mac Agent Readiness Board 就绪看板。看板固定展示连接回执、桌面能力、屏幕观察、Loop 继续和人工闸门五类 row，并统计 ready、blocked、metadata 待同步和人工确认数量；item 只包含固定 title/status/guidance/icon/reviewKind、计数和可聚焦状态。看板按钮只聚焦已有 detail review 或队列项，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取 artifact `reference`、Gateway `file://` payload、文件内容、命令输出、diff、网页正文、草稿正文或 action `toolArguments`。

v0.39 起，Mission Run 可从当前 `ClawMobileTask.actions`、actionID 关联的 Gateway result、审批级别、结构化参数 presence 和既有复核域派生 Mac Gateway Action Preflight Matrix 动作预检矩阵。矩阵按 action 顺序展示每个 action 的 kind、审批状态、是否可派发、是否阻断、是否 metadata 待同步、是否降级、是否需要人工和是否可重试；发送前的手机审批聚焦 `approval`，发送后的 Gateway result 按 action kind 聚焦 Browser/File/Shell/Delivery/AgentTrace 等复核域。矩阵按钮只聚焦已有 detail review 或队列项，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、文件内容、命令输出、diff、网页正文或草稿正文。

v0.40 起，Mission Run 可从 Action Preflight Matrix、Artifact Evidence Index、Payload Safety Ledger 和复核优先队列派生 Mac Agent Evidence Coverage Map 证据覆盖图。覆盖图按复核域展示 action 支撑、artifact 证据、metadata、payload 边界、人工复核和 metadata 缺口；发送前可显示审批/action 支撑但不会伪装 Gateway 证据已覆盖，发送后按 Browser/File/Shell/Delivery/AgentTrace 等复核域汇总覆盖状态。覆盖图按钮只聚焦已有 detail review 或队列项，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、文件内容、命令输出、diff、网页正文或草稿正文。

v0.41 起，Mission Run 可从复核态势、下一步复核行动、Loop 继续态势、Mac Agent 就绪、动作预检、证据覆盖和审批队列派生 Mac Agent Next Step Deck 下一步候选卡组。卡组固定展示人工确认、证据补齐、失败复核、Loop 下一步和抽查复核候选；idle 时不虚构候选，pre-send 时只显示手机审批/action 支撑，AgentTrace 可继续时仍要求用户显式触发下一轮。卡组按钮只聚焦已有 detail review 或队列项，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、文件内容、命令输出、diff、网页正文或草稿正文。

v0.42 起，Mission Run 可从动作预检、证据覆盖、审批队列和复核态势派生 Mac Agent Run Timeline 执行时间线。时间线按 action 顺序串起计划/审批、Gateway result、metadata、证据同步、阻断/失败/跳过/完成和人工交接摘要；idle 时不虚构 step，pre-send 时不伪装 Gateway 已执行。时间线按钮只聚焦已有 detail review 或队列项，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、`auditTrail` 原文、artifact payload、文件内容、命令输出、stdout/stderr、diff/patch、网页正文、草稿正文、token、Authorization/header、cookie 或 secret。

v0.43 起，Mission Run 可从 Next Step Deck、Run Timeline、Approval Queue、Review Readiness、Loop 继续态势和 Mac Agent Readiness Board 派生 Mac Agent Continuation Gate 继续闸门。闸门按固定 row 压缩展示阻断/可重试、人工确认、metadata/证据缺口、Loop 可继续和抽查入口；idle 时不虚构可继续状态，AgentTrace 可继续时仍要求用户显式触发下一轮。闸门按钮只聚焦已有 detail review 或队列项，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、`auditTrail` 原文、artifact payload、文件内容、命令输出、stdout/stderr、diff/patch、网页正文、草稿正文、token、Authorization/header、cookie 或 secret。

v0.44 起，Mission Run 可从 Review Readiness、Evidence Coverage Map、Action Preflight Matrix、Approval Queue、Continuation Gate、Loop 继续态势和 Mac Agent Readiness Board 派生 Mac Agent Review Radar 复核雷达。雷达固定展示安全复核、证据覆盖、执行状态、人工交接和 Loop 继续五个 sector，并汇总优先信号、就绪、阻断、人工动作和 metadata 缺口；idle 时不虚构 sector，AgentTrace 可继续时仍只提示用户显式触发下一轮。雷达按钮只聚焦已有 detail review 或队列项，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、`auditTrail` 原文、artifact payload、文件内容、命令输出、stdout/stderr、diff/patch、网页正文、草稿正文、token、Authorization/header、cookie 或 secret。

v0.45 起，Mission Run 可从 Review Radar、Continuation Gate、Next Step Deck、Run Timeline、Approval Queue、Focus Context 和 Loop 继续态势派生 Mac Agent Handoff Brief 人工交接简报。简报固定展示阻断/可重试、人工确认、metadata/证据缺口、Loop 下一轮和抽查复核五个 item，并汇总完成、阻断、人工、可重试、metadata 和 Loop 候选；idle 时不虚构 item，AgentTrace 可继续时仍只提示用户显式触发下一轮。简报按钮只聚焦已有 detail review 或队列项，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、`auditTrail` 原文、artifact payload、文件内容、命令输出、stdout/stderr、diff/patch、网页正文、草稿正文、token、Authorization/header、cookie 或 secret。

v0.46 起，Mission Run 可从 Handoff Brief、Continuation Gate、Review Radar、Approval Queue、Loop 继续态势、Operator Strip 和 Focus Context 派生 Mac Agent Control Snapshot 控制态势快照。快照用固定枚举区分 idle、聚焦、阻断、等待人工、可重试、metadata 待同步、可显式继续和可抽查，并只提供一个本地聚焦入口；idle 时不虚构可控制或可继续状态，AgentTrace 可继续时仍只提示用户显式触发下一轮。快照按钮只聚焦已有 detail review 或队列项，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、`auditTrail` 原文、artifact payload、文件内容、命令输出、stdout/stderr、diff/patch、网页正文、草稿正文、token、Authorization/header、cookie 或 secret。

v0.47 起，Mission Run 可从既有 Approval Queue 派生 Approval Fast Lane 审批快车道。快车道只展示首要人工确认入口、审批/动作标签、metadata 状态和固定检查点；按钮只聚焦已有 detail review 或状态项，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续；不写入 envelope，不回传 Gateway，不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、`auditTrail` 原文、artifact payload、文件内容、命令输出、stdout/stderr、diff/patch、网页正文、草稿正文、token、Authorization/header、cookie 或 secret。

v0.8 在 iPad/regular horizontal size class 上把同一组 presentation layer 信息重排为多栏复核工作台：左侧为命令输入和 Mission Run 主操作，右侧为 Mission 复核详情 Dock、计划、Claw 电脑任务、Gateway 会话、事件/envelope、权限和日志。compact iPhone 布局仍保持单栏滚动。

这不是 envelope 字段：Mission Run、Approval Fast Lane、Control Snapshot、Operator Strip、Loop continuation brief、Mac Agent Readiness Board、Mac Gateway Action Preflight Matrix、Mac Agent Evidence Coverage Map、Mac Agent Next Step Deck、Mac Agent Run Timeline、Mac Agent Continuation Gate、Mac Agent Review Radar、Mac Agent Handoff Brief、Focus Context、Review Detail Dock、Review Trail、Approval Queue、Payload Safety Ledger、Artifact 证据索引、复核优先队列、复核聚焦模式、复核态势摘要、下一步复核行动、Live Gateway health summary、Artifact metadata review、File Change Safety review、Shell Command Safety review、Extraction completeness review、Browser Control review、Delivery Safety review、AgentTrace handoff status、Gateway capability review、Accessibility artifact review、Replay Guard review 和 iPad 多栏工作台都不写入 `ClawMobileEnvelope`，不改变 `claw.computer.control.v1` schema，不新增 action kind、artifact kind、Gateway event kind，也不扩大桌面 Gateway 的执行权限。桌面端仍只接收结构化 `task.actions[].toolArguments`，手机端仍只负责计划、审批、发送 envelope 和查看事件。手机端展示 Approval Fast Lane、Control Snapshot、Operator Strip、Loop continuation brief、Mac Agent Readiness Board、Mac Gateway Action Preflight Matrix、Mac Agent Evidence Coverage Map、Mac Agent Next Step Deck、Mac Agent Run Timeline、Mac Agent Continuation Gate、Mac Agent Review Radar、Mac Agent Handoff Brief、Focus Context、Review Detail Dock、Review Trail、Approval Queue、Payload Safety Ledger、Artifact 证据索引、复核优先队列、复核聚焦详情、复核态势摘要、下一步复核行动、Artifact metadata、File Change Safety、Shell Command Safety、Extraction completeness、Browser Control、Delivery Safety、AgentTrace handoff status、Gateway capability、Accessibility artifact、Replay Guard 和 Live Gateway health summary 时只读取安全 metadata、固定枚举或既有事件摘要，不读取 Gateway `file://` artifact 内容；所有专用 metadata review 的 UI 可见字符串必须先经过同一套敏感值脱敏。

## Live Gateway Transport

iOS live 模式使用 WebSocket：

- endpoint 必须是 `ws://` 或 `wss://`。
- envelope 通过第一条 WebSocket text message 发送。
- 原始 token 不写入 envelope；运行时通过 `Authorization: Bearer <token>` header 发送。
- `X-Claw-Schema` 固定为 `claw.computer.control.v1`。
- `X-Claw-Token-Fingerprint` 只放短 SHA-256 指纹，用于日志和双端核对。
- 桌面端按 `ClawGatewayEvent` JSON text message 持续推流。

`URLSessionClawGatewayTransport` 会在客户端 WebSocket 打开并发送 envelope 后生成一个本地 `.gatewayConnected` 进度事件，表示“客户端已打开 WebSocket 并等待桌面端事件”。桌面 Gateway 随后也可以推送自己的 `.gatewayConnected`；手机端 health summary 会统计重复连接事件并把非终态 live 事件保持为 `streaming`。

v0.12 起，客户端 transport 有固定上限的可观测性增强：默认最多重试 1 次，总尝试次数最多 2 次；每次发送 envelope 后做一次 WebSocket ping 观测。attempt、reconnect、ping 和 transport error 通过现有 `.gatewayConnected` / `.fallbackUsed` 的安全 summary 传给手机端 health summary，例如 `attempt=2 reconnect=1 ping=ok`。这不新增 event kind，不改变 envelope，不要求桌面 Gateway 新增协议，也不是 iOS 后台保活或配对服务。为了避免重复执行风险，transport 仅在尚未收到桌面 Gateway 业务事件前重发 envelope；收到桌面事件后的错误仍交给现有 fallback/复核路径。

v0.13 起，桌面 Gateway 原型增加进程内 task replay guard，作为 v0.12 客户端有界重连的 server-side 防线。同一 Gateway 进程首次接受某个 `task.id` 时按正常路径执行；后续重复提交同一任务时，新建 replay session，只返回 `gatewayConnected`、session-level `task-replay-guard.json` `auditLog`、每个 action 的 `actionSkipped` 和 `sessionCompleted`。replay path 不调用 action handler，不写 browser/file/shell/screen/agentTrace/messageDraft 等业务 artifact，不新增 event kind、action kind 或 artifact kind。replay audit payload 和 metadata 只记录 task id、短 digest、首次 session id、原始状态、replay count、action count/kinds 和安全标志；不包含 raw token、Authorization header、自然语言 instruction、`toolArguments`、命令输出、网页正文、截图内容、草稿正文或完整 workspace path。该防护只在当前 Gateway 进程内有效；重启、多 Gateway 进程、cache 淘汰或远端分布式执行不具备持久化 exactly-once 语义。

当前仓库包含一个受策略约束的桌面 Gateway 原型：

- `Tools/claw-gateway-server.mjs`
  - 监听 WebSocket。
  - 校验 bearer token、schema 和 envelope token 指纹。
  - 校验 action 是否在 `allowedActionKinds` 内。
  - 对同一进程内重复提交的 `task.id` 启用 replay guard：重复任务只写 `task-replay-guard.json` `auditLog`，逐个 action 返回 `actionSkipped`，不重新执行 handler 或写业务 artifact。
  - 在 session 开始后写入 `gateway-capability-snapshot.json` `auditLog` artifact，并附安全 metadata，审计 workspace、platform、token 短指纹、allowlist 和 real/dry-run/disabled/unavailable 状态，包括 `accessibilityTreeState`。
  - 把 artifact 写入 workspace，并回传 `file://` 引用。
  - `manageFiles` 可按 `toolArguments.writePath/writeText` 在 workspace 内真实写文件，路径逃逸会被阻断；v0.22 起既有 `fileDiff` artifact event 和路径阻断审计 artifact event 会附 File Change Safety metadata，只写 workspace policy、写入状态、计数、presence 和 omission flags，不写 raw path、workspace path、文件内容、diff 或 `toolArguments`。
  - Shell 只读取 `toolArguments.shellCommand`；默认 dry-run，必须设置 `CLAW_ALLOW_SHELL=1` 且命令在 `CLAW_SHELL_ALLOWLIST` 内才会真执行。v0.23 起，`commandOutput` artifact event 会附 Shell Command Safety metadata，只写结构化命令 presence、parse/policy/allowlist/执行/exit code/stdout/stderr presence 和 omission flags，不写 raw command、cwd/path、stdout/stderr 内容或 `toolArguments`。
  - `controlBrowser` 可处理 `toolArguments.html`，也可在 `CLAW_ALLOW_BROWSER_NETWORK=1` 且 host allowlist 通过时抓取 URL；输出标题、链接、标题层级、表格、表单字段、候选控件和文本预览。默认只写入桌面浏览器打开/搜索计划；设置 `CLAW_ALLOW_BROWSER_CONTROL=1`、`CLAW_BROWSER_APP_ALLOWLIST` 和 `CLAW_BROWSER_HOST_ALLOWLIST` 后，可在 macOS 上打开允许的浏览器并跳转到结构化 URL/搜索结果。v0.48 起，`browserTrace` 和 `browser-control-*.json` artifact event 会附 Browser Control policy diagnostics metadata，只写请求/策略/allowlist/策略诊断/重试原因/执行状态和 omission flags，不写 raw URL、search query、HTML/page text、form fields、candidate labels、browser app name、host、allowlist 值或 `toolArguments`。
  - `extractData` 会消费同一 session 内的 browser trace、file diff、command output、screen observation 和 accessibility tree artifact，生成 `artifact-grounded-extraction` 结构化结果，并在 artifact event metadata 上附 metadata-only 的完整性复核摘要；metadata 只含计数、状态、source kind 和 safety flags，不含 row 内容、URL/path、命令输出或 `toolArguments`。
  - `runAgentLoop` 会消费同一 session 内的 artifact context，写出 `agentTrace` artifact。v0.6 保留旧字段 `sourceArtifacts`、`evidenceRows`、`observations`、`nextActions`、`safetyGates`，并新增 `readiness`、`decisionChecklist`、`selectedNextAction`、`riskTags`、`stopReason`、`handoffSummary`，用于说明证据分数、满足/缺失信号、当前推荐下一步、风险标签和停在审批/最终提交前的原因。v0.7 会把这些安全摘要压缩成 artifact event 上的可选字符串 `metadata`，供手机端复核；旧事件缺少 metadata 仍合法。v0.31 起，`decisionChecklist[].status` 可为 `satisfied`、`degraded` 或 `missing`，`readiness.degradedSignals` 记录 dry-run、window metadata、network blocked、failed、unavailable 或 not-requested 等降级证据；这些降级证据不计入 readiness score。这些字段不进入 `ClawMobileEnvelope` schema，也不能作为可执行指令。
  - `observeScreen` 默认 dry-run；设置 `CLAW_ALLOW_SCREEN_CAPTURE=1` 后可在 macOS 上生成真实截图 artifact，设置 `CLAW_ALLOW_WINDOW_METADATA=1` 后可读取前台窗口元数据，设置 `CLAW_ALLOW_ACCESSIBILITY_OBSERVE=1` 后可在授权 macOS Gateway 上通过固定只读 System Events 脚本采集前台 App/窗口和有限候选控件摘要。该摘要只写既有 `accessibilityTree` artifact，并在 artifact event metadata 上附 signal quality、evidence tier、control coverage、省略标志和 `actionExecutionSupported=false`；metadata 不写前台 App 名、窗口标题、控件 label/description、raw text 或密码字段值，不执行点击、输入或任意选择器。无权限或非 macOS 时写入可审计 permission-missing/platform-unavailable 信号。
  - `operateDesktopApp` 默认停在审批闸门；设置 `CLAW_ALLOW_DESKTOP_CONTROL=1`、`CLAW_DESKTOP_APP_ALLOWLIST` 和 `CLAW_DESKTOP_KEY_ALLOWLIST` 后，可在 macOS 上聚焦允许的 App、粘贴结构化草稿、执行允许的非提交快捷键，并在最终提交前回到用户确认。该 handler 会在相关 artifact event metadata 上附 Delivery Safety 和桌面策略诊断摘要，只写固定策略诊断、重试原因、是否尝试自动化、是否检查 app/key 策略、最终提交闸门、用户确认、正文/paste 省略和按键计数，不写草稿正文、paste text、按键原文、target app、allowlist 值或 `toolArguments`。
  - `composeMessage`/`composeEmail` 写既有 `messageDraft` artifact 并等待用户确认；v0.20 起会附 Delivery Safety metadata，说明草稿正文已从 metadata 中省略且最终发送需要用户确认，不新增真实发送能力。
- `Tools/claw-gateway-smoke.mjs`
  - 启动一次性 Gateway 验证正常路径。
  - 额外启动同一进程内可接收两次连接的 Gateway 验证 replay guard。
  - 验证 `gatewayConnected`、browser/file/shell/extract/action draft result、artifact 文件落盘、browser trace 到结构化提取链路、Browser Control metadata、Accessibility signal quality metadata、File Change Safety metadata、Shell Command Safety metadata、提取完整性 metadata、Delivery Safety metadata、Desktop App policy diagnostics、路径逃逸阻断、写入失败审计、重复 envelope 的 `task-replay-guard.json` / `actionSkipped` 和 `sessionCompleted`。
- `Tools/claw-gateway-direct-smoke.mjs`
  - 不监听端口，使用 `--emit-events` 直接验证同一套 Gateway handler。
  - 覆盖 workspace artifact、workspace 文件真实写入、File Change Safety metadata、路径逃逸阻断、写入失败审计、workspace symlink 阻断、browser trace 到结构化提取链路、Browser Control metadata、Accessibility signal quality metadata、Shell Command Safety metadata、提取完整性 metadata、Delivery Safety metadata、Desktop App policy diagnostics、Shell dry-run 阻断、allowlist Shell 真执行、缺少结构化 Shell 命令阻断、浏览器打开/搜索计划与 allowlist 阻断、同一 `--emit-events` 进程内重复 envelope 的 replay guard，以及桌面 App 控制的审批闸门和 allowlist 阻断。
- `Tools/ClawGatewayEventFixture.swift`
  - 从 envelope 生成 JSON Lines 事件，用于协议 fixture 和桌面端实现对照。

启动本地 Gateway：

```sh
CLAW_GATEWAY_TOKEN=super-secret-token node Tools/claw-gateway-server.mjs
```

启用 workspace、Shell allowlist 和桌面 App 策略：

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

手机端配置：

- Gateway URL：模拟器用 `ws://127.0.0.1:18789`；真机用电脑局域网 IP。
- Gateway Token：同一个 `super-secret-token`。
- 发送模式：`Live Gateway`。

## Gateway Event Stream

live gateway 与模拟器共用 `ClawGatewayEvent`，手机端只依赖事件 reducer 更新 session：

```json
{
  "id": "UUID",
  "sessionID": "UUID",
  "taskID": "UUID",
  "sequence": 12,
  "kind": "actionCompleted",
  "actionID": "UUID",
  "actionKind": "runAgentLoop",
  "actionTitle": "运行电脑智能体循环",
  "resultStatus": "succeeded",
  "summary": "电脑智能体循环已完成一次观察、决策、受限动作建议和验证记录。",
  "artifacts": [
    {
      "id": "UUID",
      "kind": "agentTrace",
      "title": "agent-loop-1.json",
      "reference": "file:///workspace/session/agent-loop-1.json",
      "isRedacted": true,
      "metadata": {
        "readinessScore": "50",
        "readinessCanContinue": "true",
        "satisfiedSignals": "browserTrace,fileDiff,commandOutput",
        "degradedSignals": "screenObservation,accessibilityTree",
        "missingSignals": "messageDraft",
        "selectedNextActionKind": "composeMessage",
        "selectedNextActionRequiresApproval": "true",
        "riskTags": "degraded-screen-observation,degraded-accessibility-tree,approval-required,final-submit-gate,missing-message-draft",
        "stopReason": "final-submit",
        "handoffStatus": "final-submit-review",
        "handoffSummary": "Evidence score 50/100 from browserTrace, fileDiff, commandOutput; degraded screenObservation, accessibilityTree; missing messageDraft. Selected next action: composeMessage. Stop reason: final-submit."
      }
    }
  ],
  "isRetryable": false,
  "retryCount": 0,
  "createdAt": "2026-06-10T08:00:00Z"
}
```

`ClawGatewayArtifact.metadata` 是可选、字符串化、向后兼容的 artifact review metadata。当前用于 `agentTrace`、capability snapshot、Accessibility、Replay Guard、通用 artifact metadata、File Change Safety、Shell Command Safety、extraction completeness、Browser Control 和 Delivery Safety 的轻量复核摘要。`agentTrace` 建议字段包括：

- `readinessScore`
- `readinessCanContinue`
- `satisfiedSignals`
- `degradedSignals`
- `missingSignals`
- `selectedNextActionKind`
- `selectedNextActionRequiresApproval`
- `riskTags`
- `stopReason`
- `handoffStatus`
- `handoffSummary`

v0.30 起，`agentTrace` metadata 建议包含固定枚举 `handoffStatus`，用于把证据缺口、审批等待、最终提交复核、阻断、可继续或完成状态压缩成一个安全字符串。建议值包括 `needs-evidence`、`waiting-for-approval`、`final-submit-review`、`blocked`、`ready-to-continue` 和 `complete`。该状态只由 `readinessCanContinue`、`selectedNextActionRequiresApproval`、`riskTags` 和 `stopReason` 等结构化字段派生，不从自然语言 `handoffSummary` 或 artifact payload 解析；手机端展示时仍只用于人工复核，不是自动执行授权或 Gateway readiness。

v0.31 起，`agentTrace` metadata 建议包含 `degradedSignals`，只使用固定 source 枚举列表，例如 `screenObservation,accessibilityTree`。`runAgentLoop` 会把真实或可操作证据计入 `satisfiedSignals`，把 dry-run、window metadata、network blocked、failed、unavailable 或 not-requested 等 artifact 计入 `degradedSignals`，完全没有 artifact 时计入 `missingSignals`。降级证据可用于人工复核和风险提示，但不增加 readiness score，也不能作为自动执行授权。

metadata 只能包含安全摘要，不能放入浏览器正文、命令输出、截图内容、消息草稿、联系人、token、完整 URL/path、row 内容、`toolArguments` 或其他敏感 payload。旧 Gateway 事件不带 metadata 时，手机端必须正常 decode，并按对应复核摘要降级显示 metadata 待同步。

事件类型：

- `sessionPrepared`
- `liveRequestPrepared`
- `gatewayConnected`
- `actionStarted`
- `artifactStored`
- `actionCompleted`
- `actionFailed`
- `approvalRequested`
- `actionSkipped`
- `sessionCompleted`
- `fallbackUsed`

桌面端最低实现要求：

1. 接收 `claw.computer.control.v1` envelope。
2. 校验 schema、token、设备名、白名单和工作目录策略。
3. 如 `task.id` 在同一 Gateway 进程内已接受过，可进入 replay guard：先推 `gatewayConnected`，写入 session 级 `task-replay-guard.json` `auditLog`，对每个 action 推 `actionSkipped`，最后推 `sessionCompleted`，且不得调用 action handler。
4. 正常路径先推 `gatewayConnected`。
5. 立即写入 session 级 `gateway-capability-snapshot.json` `auditLog` artifact，附安全 metadata，并推一个无 action 绑定的 `artifactStored`。
6. 对每个 action 推 `actionStarted`。
7. 如有截图、命令输出、文件 diff、浏览轨迹或草稿，推 `artifactStored`。
8. 推 `actionCompleted`、`actionFailed`、`approvalRequested` 或 `actionSkipped`。
9. 最后推 `sessionCompleted`。

## 安全边界

- iOS 端不能静默读取其他 App 收件箱，也不能控制桌面屏幕。
- 桌面网关必须最小权限运行：限定工作目录、命令白名单、网络入口和 token。
- Shell、文件写入、桌面 App 提交表单、外发消息默认高风险。
- 每个动作应回传结果摘要、截图/日志引用、错误和可回滚信息。
- `gateway-capability-snapshot.json` payload 和 metadata 只能记录安全策略摘要、capability 状态和短 token 指纹，不能写入 raw token、Authorization header、自然语言 instruction、`toolArguments`、网页正文、命令输出、截图内容、草稿正文、联系人或完整 workspace path，也不能作为执行计划来源。
- `agentTrace` 的 readiness/checklist/risk/stop/handoff 只解释已有证据和下一步建议，不能把自然语言直接交给 Shell、AppleScript、浏览器或桌面 App，也不能绕过 action allowlist、workspace 限制或最终提交审批。
- `agentTrace` metadata 只能用于手机端复核展示，不能成为执行计划来源；手机端不得读取桌面 Gateway `file://` artifact 内容来补全无权限信息。
- File Change Safety metadata 只能用于手机端复核展示，不能成为执行计划来源；metadata 和手机端 UI 不得包含 raw path、workspace/sessionWorkspace、文件名/目录名、文件内容、diff hunk、patch、stdout/stderr、token、Authorization/header、cookie、secret 或 `toolArguments`。metadata 缺失时必须降级为“metadata 待同步”，路径阻断或写入失败只能通过固定状态、计数和 omission flags 展示。
- Shell Command Safety metadata 只能用于手机端复核展示，不能成为执行计划来源；metadata 和手机端 UI 不得包含 raw command、binary/args、cwd、workspace/session path、stdout/stderr 内容、token、Authorization/header、cookie、secret、自然语言 instruction 或 `toolArguments`。metadata 缺失时必须降级为“metadata 待同步”，policy 阻断或真实执行只能通过固定状态、布尔值、presence 和 omission flags 展示。
- Desktop App policy diagnostics metadata 只能用于手机端复核展示，不能成为执行计划来源；metadata 和手机端 UI 不得包含 target app、app allowlist、key sequence、paste text、草稿正文、osascript stdout/stderr、token、Authorization/header、cookie、secret、workspace path 或 `toolArguments`。`desktopPolicyDiagnostic` 和 `desktopRetryableReason` 只能使用固定枚举，metadata 缺失时必须降级为“metadata 待同步”，不能假定已经安全、已执行或已提交。
- Live Gateway health summary 只能用于手机端连接状态复核，不能成为执行计划来源；摘要必须脱敏 endpoint/userinfo/query、raw token、Authorization header、完整 workspace path、artifact payload、命令输出、网页正文、截图内容、草稿正文和联系人。
- Live Gateway retry/ping 只说明 transport 可达性，不代表桌面 Gateway 已授权或完成任务；重连不得绕过 token、schema、allowlist、workspace 或审批闸门。
- Gateway task replay guard 只阻止同一 Gateway 进程内重复提交再次执行 handler；replay audit 和 metadata 必须脱敏，不能写 raw token、Authorization header、`instruction`、`toolArguments`、业务 artifact payload 或完整 workspace path，也不能声称跨进程、跨重启或分布式 exactly-once。
- Accessibility signal quality metadata 只能用于手机端复核展示，不能成为执行计划来源，不能放入前台 App 名、窗口标题、控件 label/description、raw text、选择器、坐标、完整 tree、token、Authorization/header、workspace path 或 `toolArguments`；`signalQuality`、`evidenceTier` 和 `controlCoverage` 只能使用固定枚举，`actionExecutionSupported` 当前必须为 `false`。

## 当前代码入口

- `Claw/Core/ClawModels.swift`
  - `ClawMobileActionKind`
  - `ClawApprovalLevel`
  - `ClawTaskStatus`
  - `ClawGatewayProfile`
  - `ClawMobileAction`
  - `ClawMobileTask`
  - `ClawMobileEnvelope`
- `Claw/Services/ClawStore.swift`
  - `PhoneAgentPlanner`
  - `ClawMobileBridge`
  - `ClawGatewayLiveClient`
  - `ClawGatewayTransport`
  - `ClawGatewayEventStream`
  - `queueClawMobileTaskFromCurrentPlan()`
  - `approveLatestClawMobileTask()`
  - `sendLatestClawMobileTask()`
  - `sendLatestClawMobileTaskOverLiveGateway()`
- `Claw/Services/ClawShortcuts.swift`
  - `BuildClawMobilePayloadIntent`
- `Claw/Views/ContentView.swift`
  - `ClawMobileBridgePanel`
- `Tools/claw-gateway-server.mjs`
  - local desktop Gateway prototype
- `Tools/claw-gateway-smoke.mjs`
  - WebSocket Gateway smoke
- `Tools/ClawGatewayEventFixture.swift`
  - envelope-to-event fixture

## 下一步真实接入

1. 把 `Tools/claw-gateway-server.mjs` 的受控 prototype handler 抽成可插拔真实工具层。
2. `observeScreen`: 已支持 macOS 截图、前台窗口元数据和受控 Accessibility 观察摘要开关；继续补完整 Accessibility bridge、默认敏感区域打码和控件级只读结构化标注。
3. `controlBrowser`: 已支持 macOS 浏览器打开/搜索策略；继续补点击、表单填写、标签管理和 Playwright/browser-use 兼容控制器。
4. `manageFiles`: 已支持 workspace 内结构化写文件；继续补真实 diff、回滚和目录授权 UI。
5. `runShellCommand`: 已有 allowlist 真执行边界和 metadata-only Shell Command Safety review；继续补 dry-run/approve/run 三阶段 UI 和命令模板。
6. `operateDesktopApp`: 已支持 macOS App 聚焦、粘贴草稿和 allowlist 快捷键；继续补视觉定位、控件级可访问性动作和回滚。
7. 手机端写入本地审计日志，并把屏幕、文件和账号上下文最小化保留。
