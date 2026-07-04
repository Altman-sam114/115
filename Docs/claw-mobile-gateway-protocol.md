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
| `observeScreen` | 截图、窗口标题、可访问性树 | Claw Gateway | 网关确认 |
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

`ClawGatewayLiveRequest` 会记录 endpoint、transport、requestPath、tokenFingerprint、headers、bodyBytes、taskID、command、actionCount 和 preflight 结果。它不保存原始 token。

## Gateway Session

发送任务后，手机端维护 `ClawGatewaySession`，用于呈现 OpenClaw 式的事件闭环：

- `status`: `prepared`、`running`、`completed`、`needsAttention`、`blocked`。
- `results`: 每个 action 的执行结果，包括 `pending`、`running`、`succeeded`、`failed`、`skipped`、`waitingForApproval`。
- `artifacts`: 网关回传的截图、可访问性树、命令输出、文件 diff、浏览轨迹、智能体轨迹、消息草稿和审计日志引用；v0.10 起手机端把 action-bound artifacts 和 session-level artifacts 一起计入 artifact count/kind summary。
- `sessionArtifacts`: 不绑定 action 的 session 级 artifact，例如 `gateway-capability-snapshot.json`；它不创建伪 action result，不影响成功/失败统计。
- `auditTrail`: session 级事件，例如 sandbox 工作目录、命令白名单、token 指纹和 retry 记录。

v0.9 起，桌面 Gateway 在 `gatewayConnected` 后、任何 action `actionStarted` 前，写入一个 session 级 `auditLog` artifact：`gateway-capability-snapshot.json`。它复用既有 `artifactStored` event kind，事件可以没有 `actionID`/`actionKind`，payload 只包含 workspace、session workspace、platform、短 token 指纹、envelope `allowedActionKinds`、策略 allowlist 和 capability 状态；不包含 raw token、Authorization header、用户自然语言、action `instruction`、`toolArguments`、网页正文、命令输出、截图内容或草稿正文。v0.10 起，该 artifact event 附带小型字符串 metadata，允许键为 `snapshotKind`、`tokenConfigured`、`tokenRequired`、`tokenFingerprint`、`allowedActionKinds`、`workspaceState`、`shellState`、`browserControlState`、`browserNetworkState`、`screenCaptureState`、`windowMetadataState`、`desktopControlState`、`safetyFlags` 和 `platform`。手机端只用这些 metadata 派生 Gateway capability review，不读取 `file://` payload。该快照只用于审计和复核，不改变 `claw.computer.control.v1` schema，不新增 action/artifact/event kind，也不扩大 Gateway 权限。

失败动作可以标记 `isRetryable`。手机端二次确认后，网关可重试失败动作并把新的 artifact 追加到对应 result。

## Mission Run Presentation Layer

v0.2 增加的 Mission Run 任务回合摘要只存在于手机端展示层。`ClawMissionRunSummary` 从 `ClawAutonomousLoopState`、最新 `ClawMobileTask` 和最新 `ClawGatewaySession` 派生，用于在电脑接管首屏展示当前目标、阶段、回合进度、下一步主动作、风险分、审批点、阻断数、artifact kind 摘要、最近 AgentTrace 复核摘要、Gateway capability review 和成功/失败/可重试计数。

v0.8 在 iPad/regular horizontal size class 上把同一组 presentation layer 信息重排为多栏复核工作台：左侧为命令输入和 Mission Run 主操作，右侧为计划、Claw 电脑任务、Gateway 会话、事件/envelope、权限和日志。compact iPhone 布局仍保持单栏滚动。

这不是 envelope 字段：Mission Run 和 iPad 多栏工作台都不写入 `ClawMobileEnvelope`，不改变 `claw.computer.control.v1` schema，不新增 action kind、artifact kind、Gateway event kind，也不扩大桌面 Gateway 的执行权限。桌面端仍只接收结构化 `task.actions[].toolArguments`，手机端仍只负责计划、审批、发送 envelope 和查看事件。手机端展示 AgentTrace 复核和 Gateway capability review 时只读取 artifact event 上的 metadata，不读取 Gateway `file://` artifact 内容。

## Live Gateway Transport

iOS live 模式使用 WebSocket：

- endpoint 必须是 `ws://` 或 `wss://`。
- envelope 通过第一条 WebSocket text message 发送。
- 原始 token 不写入 envelope；运行时通过 `Authorization: Bearer <token>` header 发送。
- `X-Claw-Schema` 固定为 `claw.computer.control.v1`。
- `X-Claw-Token-Fingerprint` 只放短 SHA-256 指纹，用于日志和双端核对。
- 桌面端按 `ClawGatewayEvent` JSON text message 持续推流。

当前仓库包含一个受策略约束的桌面 Gateway 原型：

- `Tools/claw-gateway-server.mjs`
  - 监听 WebSocket。
  - 校验 bearer token、schema 和 envelope token 指纹。
  - 校验 action 是否在 `allowedActionKinds` 内。
  - 在 session 开始后写入 `gateway-capability-snapshot.json` `auditLog` artifact，并附安全 metadata，审计 workspace、platform、token 短指纹、allowlist 和 real/dry-run/disabled/unavailable 状态。
  - 把 artifact 写入 workspace，并回传 `file://` 引用。
  - `manageFiles` 可按 `toolArguments.writePath/writeText` 在 workspace 内真实写文件，路径逃逸会被阻断。
  - Shell 只读取 `toolArguments.shellCommand`；默认 dry-run，必须设置 `CLAW_ALLOW_SHELL=1` 且命令在 `CLAW_SHELL_ALLOWLIST` 内才会真执行。
  - `controlBrowser` 可处理 `toolArguments.html`，也可在 `CLAW_ALLOW_BROWSER_NETWORK=1` 且 host allowlist 通过时抓取 URL；输出标题、链接、标题层级、表格、表单字段、候选控件和文本预览。默认只写入桌面浏览器打开/搜索计划；设置 `CLAW_ALLOW_BROWSER_CONTROL=1`、`CLAW_BROWSER_APP_ALLOWLIST` 和 `CLAW_BROWSER_HOST_ALLOWLIST` 后，可在 macOS 上打开允许的浏览器并跳转到结构化 URL/搜索结果。
  - `extractData` 会消费同一 session 内的 browser trace、file diff、command output、screen observation 和 accessibility tree artifact，生成 `artifact-grounded-extraction` 结构化结果。
  - `runAgentLoop` 会消费同一 session 内的 artifact context，写出 `agentTrace` artifact。v0.6 保留旧字段 `sourceArtifacts`、`evidenceRows`、`observations`、`nextActions`、`safetyGates`，并新增 `readiness`、`decisionChecklist`、`selectedNextAction`、`riskTags`、`stopReason`、`handoffSummary`，用于说明证据分数、满足/缺失信号、当前推荐下一步、风险标签和停在审批/最终提交前的原因。v0.7 会把这些安全摘要压缩成 artifact event 上的可选字符串 `metadata`，供手机端复核；旧事件缺少 metadata 仍合法。这些字段不进入 `ClawMobileEnvelope` schema，也不能作为可执行指令。
  - `observeScreen` 默认 dry-run；设置 `CLAW_ALLOW_SCREEN_CAPTURE=1` 后可在 macOS 上生成真实截图 artifact，设置 `CLAW_ALLOW_WINDOW_METADATA=1` 后可读取前台窗口元数据。
  - `operateDesktopApp` 默认停在审批闸门；设置 `CLAW_ALLOW_DESKTOP_CONTROL=1`、`CLAW_DESKTOP_APP_ALLOWLIST` 和 `CLAW_DESKTOP_KEY_ALLOWLIST` 后，可在 macOS 上聚焦允许的 App、粘贴结构化草稿、执行允许的非提交快捷键，并在最终提交前回到用户确认。
- `Tools/claw-gateway-smoke.mjs`
  - 启动一次性 Gateway。
  - 发送测试 envelope。
  - 验证 `gatewayConnected`、browser/file/shell/extract action result、artifact 文件落盘、browser trace 到结构化提取链路和 `sessionCompleted`。
- `Tools/claw-gateway-direct-smoke.mjs`
  - 不监听端口，使用 `--emit-events` 直接验证同一套 Gateway handler。
  - 覆盖 workspace artifact、workspace 文件真实写入、browser trace 到结构化提取链路、Shell dry-run 阻断、allowlist Shell 真执行、浏览器打开/搜索计划与 allowlist 阻断，以及桌面 App 控制的审批闸门和 allowlist 阻断。
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
        "readinessScore": "72",
        "readinessCanContinue": "true",
        "satisfiedSignals": "screenObservation,accessibilityTree,browserTrace,fileDiff,commandOutput",
        "missingSignals": "messageDraft",
        "selectedNextActionKind": "composeMessage",
        "selectedNextActionRequiresApproval": "true",
        "riskTags": "approval-required,final-submit-gate,missing-message-draft",
        "stopReason": "final-submit",
        "handoffSummary": "Evidence score 72/100; missing messageDraft. Selected next action: composeMessage. Stop reason: final-submit."
      }
    }
  ],
  "isRetryable": false,
  "retryCount": 0,
  "createdAt": "2026-06-10T08:00:00Z"
}
```

`ClawGatewayArtifact.metadata` 是可选、字符串化、向后兼容的 artifact review metadata。当前仅用于 `agentTrace` 的轻量复核摘要，建议字段包括：

- `readinessScore`
- `readinessCanContinue`
- `satisfiedSignals`
- `missingSignals`
- `selectedNextActionKind`
- `selectedNextActionRequiresApproval`
- `riskTags`
- `stopReason`
- `handoffSummary`

metadata 只能包含安全摘要，不能放入浏览器正文、命令输出、截图内容、消息草稿、联系人、token 或其他敏感 payload。旧 Gateway 事件不带 metadata 时，手机端必须正常 decode，并降级显示已收到智能体轨迹但缺少详细复核 metadata。

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
3. 先推 `gatewayConnected`。
4. 立即写入 session 级 `gateway-capability-snapshot.json` `auditLog` artifact，附安全 metadata，并推一个无 action 绑定的 `artifactStored`。
5. 对每个 action 推 `actionStarted`。
6. 如有截图、命令输出、文件 diff、浏览轨迹或草稿，推 `artifactStored`。
7. 推 `actionCompleted`、`actionFailed`、`approvalRequested` 或 `actionSkipped`。
8. 最后推 `sessionCompleted`。

## 安全边界

- iOS 端不能静默读取其他 App 收件箱，也不能控制桌面屏幕。
- 桌面网关必须最小权限运行：限定工作目录、命令白名单、网络入口和 token。
- Shell、文件写入、桌面 App 提交表单、外发消息默认高风险。
- 每个动作应回传结果摘要、截图/日志引用、错误和可回滚信息。
- `gateway-capability-snapshot.json` payload 和 metadata 只能记录安全策略摘要、capability 状态和短 token 指纹，不能写入 raw token、Authorization header、自然语言 instruction、`toolArguments`、网页正文、命令输出、截图内容、草稿正文、联系人或完整 workspace path，也不能作为执行计划来源。
- `agentTrace` 的 readiness/checklist/risk/stop/handoff 只解释已有证据和下一步建议，不能把自然语言直接交给 Shell、AppleScript、浏览器或桌面 App，也不能绕过 action allowlist、workspace 限制或最终提交审批。
- `agentTrace` metadata 只能用于手机端复核展示，不能成为执行计划来源；手机端不得读取桌面 Gateway `file://` artifact 内容来补全无权限信息。

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
2. `observeScreen`: 已支持 macOS 截图和前台窗口元数据开关；继续补完整可访问性树和默认敏感区域打码。
3. `controlBrowser`: 已支持 macOS 浏览器打开/搜索策略；继续补点击、表单填写、标签管理和 Playwright/browser-use 兼容控制器。
4. `manageFiles`: 已支持 workspace 内结构化写文件；继续补真实 diff、回滚和目录授权 UI。
5. `runShellCommand`: 已有 allowlist 真执行边界；继续补 dry-run/approve/run 三阶段 UI 和命令模板。
6. `operateDesktopApp`: 已支持 macOS App 聚焦、粘贴草稿和 allowlist 快捷键；继续补视觉定位、控件级可访问性动作和回滚。
7. 手机端写入本地审计日志，并把屏幕、文件和账号上下文最小化保留。
