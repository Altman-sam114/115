# 项目核心流程文档

## 0. 一句话总览

Claw 的当前主链路是：用户在 iPhone 输入电脑任务，App 生成可审批的 Claw computer-control envelope，桌面 Gateway 在安全策略内执行或模拟执行，并把事件、artifact、审批点和失败信息回传给手机端。

v0.70 在现有 Live Gateway Health 旁增加配对诊断和显式恢复意图 presentation。诊断先核对 endpoint、运行时 token、当前 task/session/request affinity，再区分可尝试 live、真实当前 Gateway ack、失败、模拟回退、完成和 stale/mismatch；配置或 token 指纹不等于持久配对。用户显式记录恢复意图后只改变内存 presentation 状态，不发送网络、不自动重试、不审批/queue/freeze/send、不消费或刷新 continuation receipt；task、session、profile、session revision 或 continuation 状态变化时旧意图 fail closed。compact iPhone 与 regular iPad/mac 复用同一 summary、Store API 和 view，宽屏布局不代表原生 macOS target。

## 1. 当前核心数据流

```text
用户自然语言任务
  -> ClawStore.phoneAgentCommand
  -> PhoneAgentPlanner.makePlan
  -> PhoneAgentPlan.steps
  -> ClawMobileBridge.makeTask
  -> ClawMobileTask.actions
  -> ClawMobileBridge.makeEnvelope
  -> ClawMobileEnvelope(JSON)
  -> 模拟事件流或 WebSocket live Gateway
  -> ClawGatewayLiveRequest + ClawGatewayConnectionState 记录 preflight 和连接阶段
  -> URLSessionClawGatewayTransport 有界重连 + ping 可观测性
  -> Gateway Dispatch Preflight：普通首次 dispatch 只接受 sent；敏感 approval/audit 合同 fail closed；continuation 走独立 readyToSend + receipt 分支
  -> Gateway process-local task replay guard 防止同一 task.id 重复执行 handler
  -> Gateway session-start capability snapshot auditLog + 安全 metadata
  -> schema action kind gate：未知 kind 固定拒绝，不生成任务 session、action-bound event 或 artifact；WebSocket 仅返回无 action identity 的 envelope error event
  -> approval/envelope allowlist policy -> fixed handler support gate
  -> schema-known unsupported action -> action-bound redacted auditLog + actionFailed/non-retryable，不进入业务 handler
  -> ClawGatewayEvent
  -> ClawGatewayEventStream.apply
  -> ClawGatewaySession.results/sessionArtifacts/auditTrail
  -> MissionRunResolution 以当前 task.id 绑定同 task session/request/events，拒绝旧任务数据回退
  -> ClawGatewayLiveHealthSummary 从已绑定 request、连接状态、session、事件、attempt/reconnect/ping 派生连接健康摘要
  -> ClawMissionRunSummary.missionScopeID 在发送前使用 task.id、发送后使用 session.id
  -> ClawMissionRunReviewFocus 把 reviewKind 绑定到当前 scope；scope 变化时旧聚焦失效并恢复全量详情
  -> ClawGatewayArtifactMetadataReviewSummary 从 artifact event metadata 派生通用 metadata 复核摘要
  -> ClawGatewayFileChangeSafetyReviewSummary 从 manageFiles artifact metadata 派生文件变更安全和策略诊断复核摘要
  -> ClawGatewayShellCommandSafetyReviewSummary 从 runShellCommand artifact metadata 派生 Shell 命令安全和策略诊断复核摘要
  -> ClawGatewayExtractionCompletenessReviewSummary 从 extractData artifact metadata 派生提取完整性和来源策略诊断复核摘要
  -> ClawGatewayBrowserControlReviewSummary 从 controlBrowser artifact metadata 派生浏览器控制计划和策略诊断复核摘要
  -> ClawGatewayDeliverySafetyReviewSummary 从 messageDraft/operateDesktopApp artifact metadata 派生草稿/最终提交安全和桌面 App 策略诊断复核摘要
  -> ClawGatewayCapabilityReviewSummary 从 snapshot metadata 派生能力复核摘要
  -> ClawGatewayAccessibilityReviewSummary 从 accessibilityTree metadata 派生观察信号质量、证据层级、控件覆盖和 observe-only 复核摘要
  -> ClawGatewayTaskReplayGuardReviewSummary 从 task-replay-guard metadata 派生重复任务复核摘要
  -> ClawGatewayArtifact.metadata 上的 agentTrace 安全摘要、证据质量和 handoff 状态
  -> ClawMissionRunSummary 派生任务回合摘要、Live Gateway 连接健康 / Mission Run Live Gateway Health Strip 连接健康条、Approval Fast Lane 审批快车道、Mac Agent Control Snapshot 控制态势快照（含 Live Health 信号）、Operator Strip（含 Live/策略格）、Loop 继续态势、Mac Agent Readiness Board 就绪看板 / Policy Diagnostics Board 策略诊断看板、Mac Gateway Action Preflight Matrix 动作预检矩阵、Mac Agent Evidence Coverage Map 证据覆盖图、Mac Agent Next Step Deck 下一步候选卡组、Mac Agent Run Timeline 执行时间线、Mac Agent Continuation Gate 继续闸门、Mac Agent Review Radar 复核雷达、Mac Agent Handoff Brief 人工交接简报、Focus Context 聚焦上下文、Review Detail Dock、Review Trail 复核路径、Approval Queue 审批队列、Payload Safety Ledger 载荷安全账本、Artifact 证据索引、Artifact metadata、文件变更安全、Shell 命令安全、提取完整性、浏览器控制计划、草稿/最终提交安全、Gateway 能力复核摘要、Accessibility 复核摘要、Replay Guard 复核摘要、AgentTrace handoff 复核摘要、复核优先队列、聚焦详情、复核态势摘要和下一步复核行动
  -> SwiftUI Mission Run / iPad 多栏工作台展示 Approval Fast Lane 审批快车道、Mac Agent Control Snapshot 控制态势快照、Operator Strip、Loop 继续态势、Mac Agent Readiness Board 就绪看板、Mac Gateway Action Preflight Matrix 动作预检矩阵、Mac Agent Evidence Coverage Map 证据覆盖图、Mac Agent Next Step Deck 下一步候选卡组、Mac Agent Run Timeline 执行时间线、Mac Agent Continuation Gate 继续闸门、Mac Agent Review Radar 复核雷达、Mac Agent Handoff Brief 人工交接简报、Focus Context 聚焦上下文、Review Detail Dock、Review Trail 复核路径、Approval Queue 审批队列、Payload Safety Ledger 载荷安全账本、Artifact 证据索引、复核态势、下一步复核行动、聚焦优先队列、复核、审批、重试或下一轮；regular Dock 通过共享 Mission primary action view/dispatcher 提供当前 Mission 的既有主动作，compact 保持单栏入口
```

## 2. 当前协作验证流

```text
人工提出目标
  -> Agent A 本地分析并写版本化提示词
  -> Agent B 同步 origin/main 并在 main 上实现
  -> Agent B 本地非编译静态检查
  -> Agent B commit 并 push 到 origin/main
  -> GitHub Actions 运行 build / XCTest / smoke / 静态检查
  -> GitHub Actions 上传未加密 ci-results 结果包
  -> Agent C 下载结果包并核对 manifest / JUnit / 日志 / 关键文件
      -> 不通过：退回 Agent B 在 main 上追加修复 commit
      -> 通过：确认 origin/main 最新 run 通过，必要时补齐文档并重新验证
  -> 人工复核进入下一轮
```

当前制度固定使用 `main` 作为唯一上传、提交、推送和云端验证分支；不默认使用 `smalldata_test`、`develop`、`codeb/...`、候选分支或 PR 合并流。

### 2.1 Agent X 主控循环准备态

Agent X 是未来可由 `agentx:`、`x:` 或 `X:` 召唤的主控调度角色。Agent X 不替代 Agent A/B/C，不直接绕过实现或验收；它只接收人工总目标 X，将总目标拆成多个小轮次，并在每轮结束后基于 Agent C 的云端 artifact 验收结论决定下一步。

```text
人工给 Agent X 总目标 X
  -> Agent X 拆分当前轮次目标、非目标、验收标准和停止条件
  -> Agent A 阅读上下文并写当前轮次版本化提示词
  -> Agent B 按提示词实现、非编译静态检查、commit 并 push origin/main
  -> GitHub Actions 生成最新 run 的未加密 ci-results artifact
  -> Agent C 下载 artifact 并核对 manifest / JUnit / 日志 / 关键结果文件
  -> Agent X 判断：
      -> 通过且总目标未完成：继续下一轮
      -> 不通过且可修：退回 Agent B 在 main 追加修复 commit
      -> 需要人工决策、权限或方向变化：暂停
      -> 通过且总目标完成：宣布完成
```

Agent X 必须停止或暂停的情况包括：总目标已完成、连续 3 轮遇到同一阻塞、连续 2 轮没有有效 diff、CI 连续同因失败、需要账号/权限/密钥/付费服务/人工决策、工作区存在无法判断归属的冲突，或用户要求停止/改变方向。Agent X 禁止无条件无限循环，禁止跳过 Agent C 结果包复判，禁止把旧 run、旧 artifact 或本地输出冒充最新云端结果。

## 3. 当前核心执行流

1. 用户在 App 输入任务，或通过 Shortcuts/App Intents 传入任务。
2. `ClawStore.generatePhoneAgentPlan()` 调用 `PhoneAgentPlanner.makePlan()`。
3. planner 根据关键词和 iOS 权限边界生成步骤：本地规划、屏幕观察、浏览器控制、文件/Shell/桌面 App、结构化提取、agent loop、消息草稿、审计。
4. `ClawStore.queueClawMobileTaskFromCurrentPlan()` 调用 `ClawMobileBridge.makeTask()`。
5. bridge 将步骤转换成 `ClawMobileAction`，补充 `toolArguments`、审批级别、敏感数据标记和风险分。
6. 用户审批后，`sendLatestClawMobileTask()` 根据 `gatewayDispatchMode` 选择：
   - `simulatedEventStream`：本地生成 `ClawGatewayEvent`。
   - `liveGateway`：准备 WebSocket 请求，endpoint/token 不满足时回退模拟流；客户端默认最多重试 1 次并做一次 ping 观测，从 request、connection state、session、事件和 transport 诊断派生 Live Gateway 连接健康摘要。
7. 桌面 Gateway 原型 `Tools/claw-gateway-server.mjs` 校验 schema、token、动作白名单和策略。
8. Gateway 先查进程内 task replay guard：同一 `task.id` 已被接受过时，只写 `task-replay-guard.json` `auditLog`、逐个 action 返回 `actionSkipped` 并结束 session，不调用 action handler。
9. 正常路径在 `gatewayConnected` 后写入 session 级 `gateway-capability-snapshot.json` `auditLog` artifact，记录 workspace、platform、短 token 指纹、envelope allowlist、策略 allowlist 和 capability 状态，并在 artifact event metadata 上附安全字符串摘要。
10. action 通过 approval/envelope policy 后必须再命中固定 Node handler 支持集合；不支持时只写 action-bound、redacted、metadata-only `auditLog`，返回 `actionFailed`/`failed`/non-retryable，不调用业务 handler、不写业务 artifact，也不尝试业务副作用。
11. unsupported action 失败后继续处理 envelope 中的后续合法 action；固定 handler 写对应 artifact 并返回成功、失败或等待审批，session 最终仍可完成。
12. 手机端 reducer 用事件更新 session；无 action 绑定的 `artifactStored` 进入 `sessionArtifacts` 和 auditTrail，action-bound artifact 保持 result 合并逻辑。
13. UI 显示结果、artifact、审批点、retry 状态、Live Gateway 连接健康摘要、Approval Fast Lane 审批快车道、Mac Agent Control Snapshot 控制态势快照、Mission Run Operator Strip、Loop 继续态势、Mac Agent Readiness Board 就绪看板、Mac Gateway Action Preflight Matrix 动作预检矩阵、Mac Agent Evidence Coverage Map 证据覆盖图、Mac Agent Next Step Deck 下一步候选卡组、Mac Agent Run Timeline 执行时间线、Mac Agent Continuation Gate 继续闸门、Mac Agent Review Radar 复核雷达、Mac Agent Handoff Brief 人工交接简报、Focus Context 聚焦上下文、Review Detail Dock、Review Trail 复核路径、Approval Queue 审批队列、Payload Safety Ledger 载荷安全账本、Artifact 证据索引、复核态势摘要、下一步人工复核行动、按风险/可行动性排序的复核优先队列、当前聚焦的队列项详情、Artifact metadata 复核摘要、文件变更安全复核摘要、提取完整性复核摘要、浏览器控制计划复核摘要、草稿/最终提交安全复核摘要、Gateway 能力复核摘要、Accessibility 复核摘要、Replay Guard 复核摘要和 AgentTrace handoff 复核摘要。
14. `ClawAutonomousLoopState` 记录计划、审批、发送、观察、重试等自动循环状态。

### 3.1 v0.66 可信跨任务续接流

```text
父 session 完成
  -> 校验最新 AgentTrace 的 v0.65 safe/approval decision
  -> 只有完整 safe contract 才冻结有界父 context并签发 10 分钟、单次、进程内 receipt
     approval-required/destructive decision 不签发 receipt，只允许生成 needsApproval 草稿
  -> transport 提取 raw receipt 到 iOS 内存 vault，公开 event 不含 receipt
  -> 用户显式生成独立 continuation draft，父 Mission scope 和 focus 不变
  -> 参数完整时用户可显式入队全新 child task
     参数不完整则停在 readyForInput
  -> v0.67 仅 manageFiles 提供 typed 编辑器：
     operation 固定 writeText，workspaceOnly 固定 true，用户填写 writePath/writeText
     validator 要求 workspace 相对路径、非空正文和每个字符串值 <= 4096 UTF-8 bytes
     非法输入留在 readyForInput；safe receipt 草稿的合法输入进入 readyForApproval
     approval-gated 草稿的合法输入仍是 needsApproval，无 receipt 且不可 queue/send
     其他 selected kind 的 readyForInput 仍无通用编辑路径
  -> child 固定等待新审批
  -> 用户按 task ID 审批，绑定 task/profile/lineage digest 并冻结 raw envelope
  -> 用户按同一 task ID 发送 frozen envelope
  -> Gateway 在 replay/workspace/event/artifact/handler 前验证并原子消费 receipt
  -> 冻结父快照深拷贝为与父隔离的可变 child session context
  -> 先执行 receipt 绑定的 selected action
  -> 再执行 runAgentLoop，基于父 seed 与本轮结果产生新 decision/可选新 receipt
```

decision、receipt 和 child approval 是三个独立信任条件，互不替代。只有 `safe-without-approval + ready-to-continue + selected != none` 能获得 receipt；approval-required、final-submit、external/destructive、needs-evidence、blocked、complete、policy-blocked、no-action 或 metadata gap 只能生成不可派发的 `needsApproval`/blocked draft。receipt 固定 TTL 600 秒、容量 128、单次消费、进程内有效；过期、淘汰、重启、并发复用、profile/allowlist/handler/参数变化或任一 lineage 不匹配都在业务副作用前拒绝。首次发送尝试后清理 iOS vault，continuation 不使用普通任务的同-envelope 自动重连/重发。

child task/action/session ID 全部新建，actions 必须恰好是 selected action 后接 `runAgentLoop`。父 context 每条最多 6 个来源记录、最多 256 KiB；Gateway 冻结缓存快照，消费后再深拷贝为与父隔离的可变 child session context，供 child 追加本轮结果。child 使用新 workspace，不读取父 `file://`、父绝对路径或父 workspace。v0.67 合法 `manageFiles` 参数只能在 draft 入队前编辑；safe receipt 草稿可进入 `readyForApproval`，approval-gated 草稿保持 `needsApproval` 且不可 queue/send。入队创建 child 后、审批冻结后以及 `sent`/`stale`/`blocked` 状态均锁定，不能 queue/send 以外再次修改。compact iPhone 与 regular iPad/mac 复用同一 continuation summary/view/API；编辑器和摘要可显示当前用户正在复核的文件参数，但 raw receipt、token、父 payload、Gateway 绝对路径和未过滤 metadata 不进入 UI/VoiceOver、event、artifact metadata、日志或 CI 摘要。raw receipt 只存在于 wire DTO、内存 vault、私有 frozen envelope 和 Gateway cache。

## 4. 核心模块

### 4.1 SwiftUI App

职责：

- 展示连接、聊天、电脑接管、能力和榜单。
- 让用户输入任务、配置 Gateway URL/token、切换发送模式、查看 envelope 和事件。
- 在电脑接管首屏用 Mission Run 面板汇总任务目标、阶段、下一步主动作、风险、审批点、Gateway 结果、artifact 证据、Mac Agent Control Snapshot 控制态势快照、Operator Strip、Loop 继续态势、Mac Agent Readiness Board 就绪看板、Mac Gateway Action Preflight Matrix 动作预检矩阵、Mac Agent Evidence Coverage Map 证据覆盖图、Mac Agent Next Step Deck 下一步候选卡组、Mac Agent Run Timeline 执行时间线、Mac Agent Continuation Gate 继续闸门、Mac Agent Review Radar 复核雷达、Mac Agent Handoff Brief 人工交接简报、Focus Context 聚焦上下文、Review Detail Dock、Review Trail 复核路径、Approval Queue 审批队列、Payload Safety Ledger 载荷安全账本、Artifact 证据索引、复核态势摘要、下一步人工复核行动、按阻断/审批/metadata 缺失/高风险执行面排序的复核优先队列、当前聚焦项对应的详细复核、Live Gateway 连接健康摘要、Artifact metadata 复核摘要、文件变更安全复核摘要、提取完整性复核摘要、浏览器控制计划复核摘要、草稿/最终提交安全复核摘要、Gateway 能力复核摘要、Accessibility 复核摘要、Replay Guard 复核摘要和最近 AgentTrace handoff 复核摘要。
- 在 iPad/regular horizontal size class 上用多栏工作台重排同一组展示层信息：左侧命令输入和 Mission Run，右侧 Mission 复核详情 Dock、计划、Claw 电脑任务、Gateway 会话、事件/envelope、权限和日志；regular 左栏隐藏重复的 Mission primary action，右侧 Dock 共享 `missionRunSummary` 的标题、图标、enabled 状态和 Store dispatcher；compact 布局保持单栏。该 regular 语义适用于 iPad 或宽屏 Mac Catalyst/类似环境，不代表原生 macOS target。

输入：

- 用户文本。
- Gateway 配置。
- Gateway event stream。

输出：

- UI 状态。
- `ClawMissionRunSummary` 派生展示状态、Operator Strip、Loop 继续态势、Mac Agent Readiness Board 就绪看板、Mac Gateway Action Preflight Matrix 动作预检矩阵、Mac Agent Evidence Coverage Map 证据覆盖图、Mac Agent Next Step Deck 下一步候选卡组、Mac Agent Run Timeline 执行时间线、Mac Agent Continuation Gate 继续闸门、Mac Agent Review Radar 复核雷达、Mac Agent Handoff Brief 人工交接简报、Focus Context 聚焦上下文、Review Detail Dock、Review Trail 复核路径、Approval Queue 审批队列、Payload Safety Ledger 载荷安全账本、Artifact 证据索引、下一步复核行动、复核优先队列、`ClawGatewayLiveHealthSummary` 连接健康摘要、`ClawGatewayArtifactMetadataReviewSummary` 通用 metadata 复核摘要、`ClawGatewayFileChangeSafetyReviewSummary` 文件变更安全复核摘要、`ClawGatewayShellCommandSafetyReviewSummary` Shell 命令安全复核摘要、`ClawGatewayExtractionCompletenessReviewSummary` 提取完整性复核摘要、`ClawGatewayBrowserControlReviewSummary` 浏览器控制计划复核摘要、`ClawGatewayDeliverySafetyReviewSummary` 草稿/最终提交安全复核摘要、`ClawGatewayCapabilityReviewSummary` 能力复核摘要、`ClawGatewayAccessibilityReviewSummary` 观察复核摘要、`ClawGatewayTaskReplayGuardReviewSummary` 复核摘要和 `ClawAgentTraceReviewSummary` handoff 复核摘要。
- `ClawMobileEnvelope`。
- 审批/发送/重试动作。

禁止：

- 声称 iOS 可静默控制电脑。
- 读取其他 App 私有数据。

### 4.2 PhoneAgentPlanner

职责：

- 把自然语言命令拆成可审查的步骤。
- 标记 iOS 可执行、Gateway-only、blockedByIOS、needsUserConfirmation 等边界。

输入：

- 用户命令。
- `PhoneAgentCapability` 列表。

输出：

- `PhoneAgentPlan`。

禁止：

- 直接执行动作。
- 绕过用户确认。

### 4.3 ClawMobileBridge

职责：

- 把 `PhoneAgentPlan` 转成 `ClawMobileTask` 和 `ClawMobileEnvelope`。
- 为每个 action 生成结构化 `toolArguments`。
- 应用 Gateway action allowlist 和敏感动作审批策略。

输入：

- `PhoneAgentPlan`
- `ClawGatewayProfile`
- 当前能力/文档上下文

输出：

- `ClawMobileTask`
- `ClawMobileEnvelope`

禁止：

- 把原始 token 放入 envelope。
- 让不在 allowlist 中的动作进入可执行状态。

### 4.4 ClawGatewayEventStream

职责：

- 生成模拟事件流。
- 创建 prepared session。
- 将 live/simulated `ClawGatewayEvent` reduce 到 `ClawGatewaySession`。
- 保存无 action 绑定的 session-level artifacts，不创建伪 action result。
- live 模式收到非终态 Gateway 事件后保持 `streaming`，不把活跃事件流降回 `awaitingGateway`。

输入：

- `ClawMobileTask`
- `ClawGatewayEvent`

输出：

- `ClawGatewaySession`
- action result、sessionArtifacts、artifact、auditTrail

禁止：

- 丢失 actionID/actionKind 对应关系。
- 把 session-level artifact 混进伪 action result。
- 用自然语言状态替代结构化 result status。

### 4.5 Desktop Gateway Prototype

职责：

- 通过 WebSocket 或 `--emit-events` 接收 envelope。
- 校验 schema、token、动作白名单。
- 对同一 Gateway 进程内重复提交的 `task.id` 启用 replay guard：写 `task-replay-guard.json` `auditLog`，返回 `actionSkipped`，不重新执行 handler 或写业务 artifact。
- 在 session 开始后写入 `gateway-capability-snapshot.json` `auditLog`，并附安全 metadata，说明当前 Gateway 是 real、dry-run、disabled、unavailable 还是 workspace-only。
- 处理 action 并写入 workspace artifact。

当前 action handler：

- `observeScreen`：dry-run、macOS 截图、窗口元数据或受 `CLAW_ALLOW_ACCESSIBILITY_OBSERVE=1` 控制的前台 Accessibility 只读摘要；`accessibilityTree` event metadata 只暴露固定 signal quality、evidence tier、control coverage、计数、省略标志和 `actionExecutionSupported=false`，不暴露前台 App 名、窗口标题、控件 label/description、raw text 或密码字段值。
- `controlBrowser`：HTML/URL trace、Gateway fetch 重定向逐跳 host/protocol/credentials 检查、浏览器打开/搜索计划、metadata-only Browser Control 网络/重定向策略诊断复核、受 allowlist 的 macOS 浏览器控制。逐跳保证不覆盖 AppleScript 打开后的桌面浏览器导航。
- `manageFiles`：workspace 内结构化写文件，路径逃逸、workspace symlink 组件和 no-follow 写入失败会被阻断；既有 `fileDiff` artifact event 和路径阻断/写入失败 `auditLog` event 附 metadata-only 文件变更安全复核摘要；metadata 只含 workspace policy、写入状态、计数、presence 和 omission flags，不含 raw path、workspace path、文件内容、diff、patch 或 `toolArguments`。
- `runShellCommand`：只从 `toolArguments.shellCommand` 读取结构化命令；顶层 `shellCommand` / `commandLine` 任一存在时 action-bound fail closed，并输出固定来源阻断诊断。合法命令进入 dry-run 或 allowlist 执行；allowlist 只授权不含 `/` 或 `\\` 的裸 executable token，同名路径在 `runProcess` 前阻断。既有 `commandOutput` artifact event 附 metadata-only Shell 命令安全复核摘要；metadata 只含结构化命令 presence、解析/policy/allowlist/执行/exit code/stdout/stderr presence 和 omission flags，不含 raw command、cwd/path、stdout/stderr 内容或 `toolArguments`。
- `extractData`：消费同 session artifact 生成结构化数据，并在输出 artifact event metadata 上附完整性状态、row count、来源计数、source kind 和 safety flags；metadata 不含 row 内容、URL/path、命令输出或 `toolArguments`。
- `operateDesktopApp`：桌面 App 聚焦、粘贴、allowlist 快捷键、最终提交前审批，并在相关 artifact event metadata 上附草稿/最终提交安全和桌面策略诊断摘要；metadata 只含固定策略诊断、重试原因、自动化尝试状态、app/key 策略检查状态、审批/省略/计数/safety flags，不含草稿正文、paste text、target app、allowlist 值、按键原文或 `toolArguments`。
- `runAgentLoop`：基于 session artifacts 生成观察-规划-动作建议-验证 `agentTrace`，并在 artifact 内部记录 readiness、decisionChecklist、selectedNextAction、selectedActionDecision、riskTags、stopReason、handoffStatus 和 handoffSummary；v0.31 起，decisionChecklist 区分 `satisfied`、`degraded` 和 `missing`，dry-run、window metadata、network blocked、failed、unavailable 或 not-requested 证据只进入 degradedSignals，不计入 readiness score；v0.65 的 selected decision 使用固定 `evidence-first-safe-v1` 分支、候选数量/序位和一致性证据，stop/handoff 风险只绑定实际选中动作。Gateway 把这些安全摘要压缩成 artifact event 上的可选字符串 metadata 供手机端复核。
- `composeMessage`/`composeEmail`：生成待确认草稿，并在 `messageDraft` artifact event metadata 上标记最终发送需要用户确认、草稿正文已从 metadata 省略。
- session-start `auditLog`：`gateway-capability-snapshot.json`，只记录 workspace、session workspace、platform、短 token 指纹、allowedActionKinds、策略 allowlist 和 capability 状态，并把 `snapshotKind`、token 配置/指纹、allowlist、capability state、`accessibilityTreeState`、safety flags 和 platform 压缩成 artifact event metadata；不记录 raw token、Authorization header、自然语言 instruction、`toolArguments`、网页正文、命令输出、截图内容、草稿正文、联系人或完整 workspace path。
- replay guard `auditLog`：`task-replay-guard.json`，只记录 task id、短 digest、首次 session id、原始状态、replay count、action count/kinds 和安全标志；不记录 raw token、Authorization header、自然语言 instruction、`toolArguments`、业务 artifact payload 或完整 workspace path。该防护只在当前 Gateway 进程生命周期内有效，不是跨重启持久化 exactly-once。

禁止：

- 自然语言直连 Shell 或桌面自动化。
- 路径逃逸到 workspace 外。
- 未经 app/key/host allowlist 控制浏览器或桌面 App。
- 用 `agentTrace` 的下一步建议绕过结构化 `toolArguments`、allowlist 或最终提交审批。
- 把 `agentTrace` 的策略 metadata 当成执行授权，或让推荐动作逃逸 `allowedNextActions ∩ envelope.allowedActionKinds ∩ fixed-supported` 交集。
- 把 replay guard 描述成跨进程、跨重启或分布式 exactly-once，或在 replay path 调用 action handler。

### 4.6 GitHub Actions CI Results

职责：

- 在 `main` push 或手动触发时运行本项目重验证。
- 生成未加密 `ci-results` 结果包，供 Agent C 下载复判。
- 在 manifest 中记录 branch、commitSha、runId、runAttempt、workflowName、各检查 outcome 和关键日志路径。

输入：

- `origin/main` 最新 commit。
- `.github/workflows/ci-results.yml` 中定义的 Claw build、Swift logic smoke、Gateway smoke 和静态检查命令。

输出：

- `ci-artifact-manifest.json`
- `ci-failure-summary.md`
- `junit.xml`
- `xcodebuild.log`
- Swift/Gateway smoke 日志和 `.xcresult`。

禁止：

- 复用带密码发布包作为 Agent C 验收包。
- 把 checkout 里的旧 artifact 当成本轮云端结果。
- 缺权限或未下载 artifact 时声称已经核对。

## 5. 核心状态对象

- `LocalClawModel`：本地模型占位、artifact manifest、安装状态。
- `ArtifactValidationResult`：本地 artifact 缺失/暂存/校验状态。
- `PhoneAgentPlan`：手机端任务计划。
- `PhoneAgentStep`：单个计划步骤和权限边界。
- `ClawGatewayProfile`：endpoint、device、securityMode、tokenFingerprint、allowedActionKinds。
- `ClawMobileAction`：可发给 Gateway 的动作。
- `ClawMobileTask`：电脑接管任务。
- `ClawMobileEnvelope`：live/simulated Gateway 的请求体。
- `ClawGatewayEvent`：Gateway 推送事件。
- `ClawGatewaySession`：手机端会话视图模型，区分 action results 和 session-level artifacts。
- `ClawGatewayLiveHealthSummary`：手机端从 `ClawGatewayLiveRequest`、`ClawGatewayConnectionState`、最新 session 和事件流派生的连接健康摘要；只展示脱敏 endpoint、transport、request path、短 token 指纹、preflight、事件数量、最新事件、attempt、reconnect、ping、脱敏 transport error、fallback/error/completed 和 session 状态，不写入 envelope，不新增协议字段，不做后台保活。
- `ClawAutonomousLoopState`：自治循环状态。
- `ClawGatewayArtifactMetadataReviewSummary`：手机端从 Gateway artifact event metadata 派生通用 metadata 复核摘要，只展示 metadata 覆盖率、脱敏计数、最近带 metadata 的 artifact、安全键值和 safety flags，不读取 Gateway `file://` 内容。
- `ClawGatewayFileChangeSafetyReviewSummary`：手机端从 `manageFiles` 的 `fileDiff`、路径阻断或写入失败 artifact metadata 派生文件变更安全复核摘要，只展示 workspace policy、写入尝试/成功、路径逃逸阻断、变更计数、path/content/diff 省略状态和 safety flags，不读取 Gateway `file://` 内容，不展示 raw path、workspace/sessionWorkspace、文件名/目录名、文件内容、diff、patch、token、header 或 `toolArguments`。
- `ClawGatewayShellCommandSafetyReviewSummary`：手机端从 `runShellCommand` 的 `commandOutput` artifact metadata 派生 Shell 命令安全复核摘要，只展示结构化命令 presence、解析状态、Shell policy、allowlist match、执行状态、exit code presence/zero、stdout/stderr presence 和 command/stdout/stderr/cwd 省略状态，不读取 Gateway `file://` 内容，不展示 raw command、binary/args、cwd/path、stdout/stderr 内容、token、header、自然语言 instruction 或 `toolArguments`。
- `ClawGatewayExtractionCompletenessReviewSummary`：手机端从 `extractData` 输出 artifact metadata 派生提取完整性复核摘要，只展示提取模式、完整性状态、row count、来源 artifact 计数、source kind 和 safety flags，不读取 Gateway `file://` 内容，不展示 row 内容、URL/path、命令输出、网页正文、草稿正文或 `toolArguments`。
- `ClawGatewayBrowserControlReviewSummary`：手机端从 `controlBrowser` artifact metadata 派生浏览器控制计划与网络重定向策略复核，只展示固定诊断、布尔状态、0...5 跳计数、allowlist/执行状态和 omission flags；不读取 Gateway `file://` 内容，不展示 raw URL、host、Location、redirect chain、header/cookie、页面正文或 `toolArguments`。
- `ClawGatewayDeliverySafetyReviewSummary`：手机端从 `messageDraft` 和 `operateDesktopApp` artifact metadata 派生草稿/最终提交安全和桌面策略诊断复核摘要，只展示固定桌面策略诊断、重试原因、自动化尝试状态、app/key 策略检查状态、最终提交闸门、用户确认、正文/paste 省略和按键计数，不读取 Gateway `file://` 内容，不展示草稿正文、paste text、target app、allowlist 值、按键原文、URL/path、联系人或 `toolArguments`。
- `ClawGatewayCapabilityReviewSummary`：手机端从 `gateway-capability-snapshot.json` `auditLog` metadata 派生的能力复核摘要，只展示短 token 指纹、allowlist、capability state、`accessibilityTreeState` 和 safety flags，不读取 Gateway `file://` 内容，UI 可见字符串统一走 metadata 脱敏路径。
- `ClawGatewayAccessibilityReviewSummary`：手机端从 `accessibilityTree` artifact metadata 派生的观察复核摘要，只展示 mode、policy、signal quality、evidence tier、control coverage、节点数、候选控件数、platform、redaction、省略标志、`actionExecutionSupported=false` 和 safety flags，不读取 Gateway `file://` 内容，不展示前台 App 名、窗口标题、控件 label/description、raw text 或密码字段值，UI 可见字符串统一走 metadata 脱敏路径。
- `ClawGatewayTaskReplayGuardReviewSummary`：手机端从 `task-replay-guard.json` `auditLog` metadata 派生的 Replay Guard 复核摘要，只展示重复次数、跳过动作数、短 digest、首次状态和 safety flags，不读取 Gateway `file://` 内容，不声称跨进程 exactly-once，UI 可见字符串统一走 metadata 脱敏路径。
- `ClawAgentTraceReviewSummary`：手机端从最近 `agentTrace` artifact metadata 派生的复核摘要和固定 handoff 状态，只展示安全字符串摘要和枚举状态；v0.31 的 `degradedSignals` 仍是固定 source 枚举 metadata；v0.62 解析交集策略与计数；v0.65 进一步校验 selected decision 固定 policy/reason、候选数量/序位、成员、一致性以及 kind/approval/readiness/stop/handoff 组合。缺失、未知、越界或矛盾状态 fail closed，不读取 Gateway `file://` 内容。
- `ClawMissionRunReviewPriorityItem`：手机端 presentation layer 队列项，只从既有 Mission Run summary、review summary 和 session/action 状态派生，用固定 severity/rank/review kind 排序首屏复核重点，并作为聚焦详情的安全输入；不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`。
- `ClawMissionRunReviewReadinessSummary`：手机端 presentation layer 复核态势摘要，只从完整复核优先队列、可用 detail review kind 和聚焦状态派生，展示总优先项、可行动项、高优先项、metadata 缺口、最高优先项和聚焦状态；不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`，不是自动执行 readiness。
- `ClawMissionRunNextReviewAction`：手机端 presentation layer 下一步人工复核行动，只从当前有效聚焦项、完整复核优先队列和可用 detail review kind 派生，提示用户下一步聚焦哪类复核或等待 Gateway 证据；不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`，不是自动执行计划。
- `ClawMissionRunArtifactEvidenceIndex`：手机端 presentation layer Artifact 证据索引，只从 artifact kind、Artifact metadata review 的 metadata/redaction count、可用 detail review kind、复核优先队列和当前聚焦项派生，展示复核项对应的证据类型覆盖和 metadata 状态；不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`，不是完整 payload viewer 或自动安全裁决。
- `ClawMissionRunPayloadSafetyLedgerSummary`：手机端 presentation layer 载荷安全账本，只从已有 detail review summary 的 `hasMetadata` 和白名单 `safetyFlags` 派生，展示 payload 未读取、metadata-only、保护/省略信号和 metadata 缺口；不读取 Gateway `file://` payload、artifact `reference`、文件内容、命令输出、diff、网页正文、草稿正文或 `toolArguments`，不是完整 payload viewer、恶意检测器或自动安全裁决。
- `ClawMissionRunMacAgentReadinessBoard`：手机端 presentation layer Mac Agent 就绪看板，只从已有 Gateway capability、Accessibility、AgentTrace/Loop、复核态势和审批队列派生连接回执、桌面能力、屏幕观察、Loop 继续和人工闸门 row；不写入 envelope，不回传 Gateway，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续，不读取 Gateway `file://` payload、artifact `reference`、文件内容、命令输出、diff、网页正文、草稿正文或 `toolArguments`，不是自动执行授权或完整 Gateway readiness。
- `ClawMissionRunActionPreflightMatrix`：手机端 presentation layer 动作预检矩阵，只从当前 task action、actionID 关联的 Gateway result、审批级别、结构化参数 presence 和既有复核域派生 action 级可派发、阻断、metadata、降级、人工确认和可重试状态；不写入 envelope，不回传 Gateway，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续，不读取或展示 action `toolArguments` 原文、Gateway `file://` payload、artifact `reference`、文件内容、命令输出、diff、网页正文或草稿正文。
- `ClawMissionRunEvidenceCoverageMap`：手机端 presentation layer 证据覆盖图，只从 Action Preflight Matrix、Artifact Evidence Index、Payload Safety Ledger 和复核优先队列派生每个复核域的 action 支撑、artifact 证据、metadata、payload 边界、人工复核和 metadata 缺口；不写入 envelope，不回传 Gateway，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续，不读取或展示 action `toolArguments` 原文、Gateway `file://` payload、artifact `reference`、文件内容、命令输出、diff、网页正文或草稿正文。
- `ClawMissionRunNextStepDeck`：手机端 presentation layer 下一步候选卡组，只从复核态势、下一步复核行动、Loop 继续态势、Mac Agent 就绪、动作预检、证据覆盖和审批队列派生人工确认、证据补齐、失败复核、Loop 下一步和抽查复核候选；idle 不虚构候选，AgentTrace 可继续也只能提示用户显式触发下一轮；不写入 envelope，不回传 Gateway，不执行 Gateway 动作、不审批、不发送、不重试、不自动继续，不读取或展示 action `toolArguments` 原文、Gateway `file://` payload、artifact `reference`、文件内容、命令输出、diff、网页正文或草稿正文。
- `ClawMissionRunContinuationGateSummary`：手机端 presentation layer 继续闸门，只从 Next Step Deck、Run Timeline、Approval Queue、Review Readiness、Loop 继续态势和 Mac Agent 就绪看板派生阻断、可重试、人工确认、metadata/证据缺口、Loop 可继续和抽查入口；它不自动继续、不审批、不发送、不重试，只允许聚焦已有复核项；不读取或展示 action `toolArguments` 原文、Gateway `file://` payload、artifact `reference`、`auditTrail` 原文、文件内容、命令输出、stdout/stderr、diff、网页正文、草稿正文、token、header、cookie 或 secret。
- `ClawMissionRunReviewRadarSummary`：手机端 presentation layer 复核雷达，只从 Review Readiness、Evidence Coverage Map、Action Preflight Matrix、Approval Queue、Continuation Gate、Loop 继续态势和 Mac Agent 就绪看板派生安全复核、证据覆盖、执行状态、人工交接和 Loop 继续五个 sector；它不自动继续、不审批、不发送、不重试，只允许聚焦已有复核项；不读取或展示 action `toolArguments` 原文、Gateway `file://` payload、artifact `reference`、`auditTrail` 原文、文件内容、命令输出、stdout/stderr、diff、网页正文、草稿正文、token、header、cookie 或 secret。
- `ClawMissionRunHandoffBriefSummary`：手机端 presentation layer 人工交接简报，只从 Review Radar、Continuation Gate、Next Step Deck、Run Timeline、Approval Queue、Focus Context 和 Loop 继续态势派生阻断/可重试、人工确认、metadata/证据缺口、Loop 下一轮和抽查复核五个 item；它不自动继续、不审批、不发送、不重试，只允许聚焦已有复核项；不读取或展示 action `toolArguments` 原文、Gateway `file://` payload、artifact `reference`、`auditTrail` 原文、文件内容、命令输出、stdout/stderr、diff、网页正文、草稿正文、token、header、cookie 或 secret。
- `ClawMissionRunControlSnapshotSummary`：手机端 presentation layer 控制态势快照，只从 Handoff Brief、Continuation Gate、Review Radar、Approval Queue、Loop 继续态势、Operator Strip 和 Focus Context 派生 idle、聚焦、阻断、等待人工、可重试、metadata 待同步、可显式继续或可抽查状态；它不自动继续、不审批、不发送、不重试，只允许聚焦已有复核项；不读取或展示 action `toolArguments` 原文、Gateway `file://` payload、artifact `reference`、`auditTrail` 原文、文件内容、命令输出、stdout/stderr、diff、网页正文、草稿正文、token、header、cookie 或 secret。
- `ClawMissionRunApprovalFastLaneSummary`：手机端 presentation layer 审批快车道，只从既有 Approval Queue 派生首要人工确认入口、审批/动作标签、metadata 状态和固定检查点；它不自动审批、不发送、不重试、不继续，只允许聚焦已有复核项或状态项；不读取或展示 action `toolArguments` 原文、Gateway `file://` payload、artifact `reference`、`auditTrail` 原文、文件内容、命令输出、stdout/stderr、diff、网页正文、草稿正文、token、header、cookie 或 secret。
- `ClawMissionRunEvidenceTrailSummary`：手机端 presentation layer 复核路径，只从 Artifact 证据索引、复核态势摘要、下一步复核行动、复核优先队列和当前有效聚焦项派生，按固定四步展示证据覆盖、metadata 状态、最高优先复核和下一步复核；按钮只聚焦已有 detail 或队列项，不执行 Gateway 动作，不读取 `auditTrail` 原文或 Gateway `file://` payload。
- `ClawMissionRunOperatorStrip`：手机端 presentation layer 操作态势带，只从阶段、回合进度、结果计数、Artifact 证据索引、复核态势摘要和下一步复核行动派生，展示 Gateway、证据、复核和下一步 4 个 lane；不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`，不是自动执行控制台或 Gateway readiness。
- `ClawMissionRunLoopContinuationSummary`：手机端 presentation layer Loop 继续态势，只从 Mission Run 状态和安全 AgentTrace review metadata 派生，展示 handoff、readiness、满足/降级/缺失证据计数、下一步 action 和审批要求；按钮只能聚焦 AgentTrace detail，不发送、不审批、不重试、不自动继续，不读取 Gateway `file://` payload。
- `ClawMissionRunReviewDetailDockSummary`：手机端 presentation layer 右侧 Dock 摘要，只从 raw focus、有效复核队列和可用 detail review 派生，说明 regular 工作台右侧应显示无证据、全量详情、单项详情、状态项回退或过期聚焦回退；不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`，不执行 Gateway 动作。
- `ClawMissionRunSummary`：手机端 presentation layer 摘要，只从 loop/task/session 派生，不进入 envelope 或 Gateway 协议；iPad 多栏工作台只重排该展示层和既有会话/日志面板，并展示 Approval Fast Lane 审批快车道、Mac Agent Control Snapshot 控制态势快照、Operator Strip、Loop 继续态势、Mac Agent Next Step Deck 下一步候选卡组、Mac Agent Run Timeline 执行时间线、Mac Agent Continuation Gate 继续闸门、Mac Agent Review Radar 复核雷达、Mac Agent Handoff Brief 人工交接简报、Focus Context 聚焦上下文、Review Detail Dock、Review Trail 复核路径、Approval Queue 审批队列、Payload Safety Ledger 载荷安全账本、Artifact 证据索引、复核态势摘要、下一步复核行动、复核优先队列、聚焦详情、Artifact metadata、File Change Safety、Shell Command Safety、提取完整性、Browser Control、Delivery Safety、Gateway capability、Accessibility、Replay Guard 和 AgentTrace handoff 复核摘要。regular Dock 的 primary action 仍只由该 summary 驱动并通过既有 Store 闸门执行。

## 6. 用户入口

- App UI：`ContentView` 内连接、聊天、电脑接管 Mission Run 面板、iPad 多栏复核工作台和相关详情面板。
- Shortcuts/App Intents：`ClawShortcuts.swift`。
- Gateway CLI：`node Tools/claw-gateway-server.mjs` 或 `--emit-events`。
- Smoke：`Tools/claw-gateway-direct-smoke.mjs`、`Tools/claw-gateway-smoke.mjs`、`Tools/LogicSmoke.swift`。

## 7. 层关系

- 前端层：SwiftUI views 只展示和触发 `ClawStore` 方法。
- 状态层：`ClawStore` 是主要 ObservableObject。
- 模型层：`ClawModels.swift` 定义跨 UI、Gateway、测试共享的 schema。
- 展示派生层：`ClawMissionRunSummary` 从现有状态组合首屏任务回合视图、Approval Fast Lane 审批快车道、Mac Agent Control Snapshot 控制态势快照、Operator Strip、Loop 继续态势、Mac Gateway Action Preflight Matrix 动作预检矩阵、Mac Agent Evidence Coverage Map 证据覆盖图、Mac Agent Next Step Deck 下一步候选卡组、Mac Agent Run Timeline 执行时间线、Mac Agent Continuation Gate 继续闸门、Mac Agent Review Radar 复核雷达、Mac Agent Handoff Brief 人工交接简报、Focus Context 聚焦上下文、Review Detail Dock、Review Trail 复核路径、Approval Queue 审批队列、Payload Safety Ledger 载荷安全账本、Artifact 证据索引、复核态势摘要、复核优先队列和聚焦详情 helper，不作为新的 source of truth。
- 执行层：桌面 Gateway Node 原型负责真实或 dry-run 工具动作。
- 文档层：README 面向开发者，`Docs/*` 面向协议，`md/flow/*` 面向当前真实逻辑和协作闭环，`AGENTS.md` 面向 Agent 工作规则。
- 测试层：本地非编译静态检查、GitHub Actions 云端重验证、云端 XCTest/Swift logic smoke、云端 Gateway JS smoke。
- v0.66 起 CI 会动态选择可用 iPhone Simulator 实际执行 `ClawTests`，并把 `xctest.log`、`ClawTests.xcresult` 和 outcome 纳入 manifest/JUnit/fail gate；不再只用 build 证明 XCTest 源码可编译。

## 8. 已确认铁律

- Claw 不做法律方向；任何“法律/合同”等词只可作为禁止项或非目标出现。
- iOS 不能越权控制电脑；必须通过用户授权的 Gateway。
- Gateway 只执行结构化参数。
- 所有敏感动作默认审批。
- Shell、文件、浏览器网络、桌面 App 控制必须受 allowlist 限制。
- 每个重要 action 都要产生 artifact 或明确失败/跳过原因。
- 新协议字段必须同步测试和文档。
- Gateway capability snapshot 只能作为审计复核 artifact，不能新增权限，不能成为执行计划来源，payload 和 metadata 不能包含 raw token、Authorization header、自然语言 instruction、`toolArguments`、网页正文、命令输出、截图内容、草稿正文、联系人或完整 workspace path。
- `agentTrace` metadata、degradedSignals 和 handoffStatus 只能用于手机端复核展示，不能成为执行计划来源，不能放入浏览器正文、命令输出、截图内容、草稿正文、联系人或 token；手机端展示前必须统一脱敏 raw token、Authorization/header、`toolArguments`、`file://` 和完整 workspace path；handoffStatus 只能使用固定枚举，不能从自然语言或 payload 解析，degradedSignals 只能使用固定 source 枚举，不能从 payload 文本解析。
- `runAgentLoop` 推荐集合必须按结构化 request、envelope action allowlist 和 Gateway 固定支持推荐种类取交集。空交集只生成 `none` 并 blocked handoff；metadata 只记录固定 policy/diagnostic、有限计数和 selected 授权布尔，不记录完整列表。推荐是 artifact 审计证据，真实执行仍须重新通过 `actionPolicy`、审批、workspace 和 handler allowlist。
- continuation 必须把 v0.65 decision、Gateway receipt 和 child 用户审批分开；receipt 不是授权，父审批不能继承。所有操作按精确 task/session/draft ID 执行，不得 latest-first；审批和发送分离，冻结 envelope 内容变化即失效。
- continuation lineage/receipt preflight 必须早于 task replay、workspace、session/event、artifact 和 handler。失败路径无 replay record、无 workspace、无业务事件/artifact、无 handler 或外部副作用，且不回显 raw receipt 或污染 payload。
- receipt 只能进程内保存 10 分钟、最多 128 条并单次消费；Gateway 重启、过期、淘汰或并发复用必须 fail closed。Gateway 只可把有界冻结父快照复制为与父隔离的可变 child session context，并使用新 workspace；child 不能读取父 `file://` 或父路径。
- `extractData` 完整性 metadata 只能用于手机端复核展示，不能成为执行计划来源，不能放入 row 内容、URL/path、命令输出、网页正文、草稿正文、联系人、token 或 `toolArguments`；手机端展示前必须统一脱敏敏感值。
- File Change Safety metadata 只能用于手机端复核展示，不能成为执行计划来源，不能放入 raw path、workspace/sessionWorkspace、文件名/目录名、文件内容、diff hunk、patch、stdout/stderr、token、Authorization/header、cookie、secret 或 `toolArguments`；metadata 缺失时必须显示“metadata 待同步”，不能假定写入安全。
- Shell Command Safety metadata 只能用于手机端复核展示，不能成为执行计划来源，不能放入 raw command、binary/args、cwd、workspace/session path、stdout/stderr 内容、token、Authorization/header、cookie、secret、自然语言 instruction 或 `toolArguments`；v0.51 起固定展示 `shellPolicyDiagnostic`/`shellRetryableReason` 与 policy/binary/structured checked 状态，v0.58 起 dry-run 在 binary allowlist 查询前短路时必须是 `binaryAllowlistChecked=false`，不能把未检查误报为已检查；v0.59 起含路径分隔符的 executable token 即使 basename 命中也必须阻断，且不能把原始路径写入事件；v0.60 起顶层 Shell alias 或来源冲突必须显示 `invalid-structured-command-source`，保持 parse/allowlist/execution 未开始并省略 alias 值；metadata 缺失时必须显示“metadata 待同步”，不能假定命令安全、已阻断或已执行。
- Browser Control metadata 只能用于手机端复核展示，不能成为执行计划来源，不能放入 raw URL、search query、HTML/page text、form fields、candidate labels、browser app name、host、allowlist 值、stdout/stderr、token、Authorization/header 或 `toolArguments`；policy diagnostic 和 retryable reason 只能是固定枚举；metadata 缺失时必须显示“metadata 待同步”，不能假定安全或已执行。
- Accessibility signal quality metadata 只能用于手机端复核展示，不能成为执行计划来源，不能放入前台 App 名、窗口标题、控件 label/description、raw text、选择器、坐标、完整 tree、token、Authorization/header、workspace path 或 `toolArguments`；signal/evidence/coverage 只能是固定枚举，当前 `actionExecutionSupported` 必须保持 `false`。
- Delivery Safety metadata 只能用于手机端复核展示，不能成为执行计划来源，不能放入草稿正文、paste text、target app、allowlist 值、按键原文、URL/path、联系人、token、Authorization/header 或 `toolArguments`；desktop policy diagnostic 和 retryable reason 只能是固定枚举，metadata 缺失时必须显示“metadata 待同步”，不能假定安全、已执行或已提交。
- Agent C 验收必须基于 `origin/main` 最新 run 的未加密结果包，不能只看 Agent B 文字汇报。
- 云端失败默认用 main 追加修复 commit 处理，不默认回滚或引入候选分支。
- Agent X 只能调度 A/B/C 多轮迭代，不能代替 Agent C 宣布云端 artifact 验收通过。

## 9. 测试映射

- Planner/bridge/schema 变更：本地只做非编译静态检查，云端 xcodebuild/logic smoke/结果包验收。
- Gateway handler 变更：本地只做非编译静态检查，云端 `node --check`、direct smoke、WebSocket smoke 和结果包验收。
- Event reducer 变更：本地只做非编译静态检查，云端 Swift logic smoke、真实 iPhone Simulator XCTest 和 Xcode build 结果。
- Mission Run 派生摘要或首屏任务回合 UI 变更：XCTest/Swift logic smoke 覆盖 idle、待审批、需处理、完成、阻断摘要、Approval Fast Lane 审批快车道、Mac Agent Control Snapshot 控制态势快照、Operator Strip、Loop 继续态势、Mac Agent Readiness Board 就绪看板、Mac Gateway Action Preflight Matrix 动作预检矩阵、Mac Agent Evidence Coverage Map 证据覆盖图、Mac Agent Next Step Deck 下一步候选卡组、Mac Agent Run Timeline 执行时间线、Mac Agent Continuation Gate 继续闸门、Focus Context 聚焦上下文、Review Detail Dock、Review Trail 复核路径、Approval Queue 审批队列、Payload Safety Ledger 载荷安全账本、AgentTrace handoff 状态、Artifact 证据索引、复核优先队列、复核聚焦、复核态势摘要、下一步复核行动和敏感字符串不外显；Artifact metadata、File Change Safety、Shell Command Safety、提取完整性、Browser Control、Delivery Safety、Gateway capability、Accessibility signal quality、Replay Guard 和 AgentTrace 复核摘要需覆盖 metadata 存在和缺失两种路径；云端 xcodebuild 覆盖 SwiftUI 编译。
- 文档-only 变更：本地 `git diff --check`、workflow YAML 语法检查；云端由 `main` push 触发结果包。

## 10. 未来扩展点

- 将 Gateway prototype handler 拆成可插拔工具层。
- 将当前 macOS Accessibility 观察摘要演进为完整 Accessibility bridge。
- 增加 Playwright/browser-use 兼容浏览器控制器。
- 在 v0.66 受限可信跨 task 续接基础上继续强化多轮失败恢复、持久但可撤销的用户授权、跨进程协调和完整 artifact 复核；当前 receipt 不跨重启且不支持无人值守循环。
- 在 v0.12 有界重连/ping 可观测性基础上，继续补完整 live Gateway 后台保活、真实心跳协议、配对和审计日志持久化。
- UI 上继续增强 Mission Run 内的 artifact 预览、完整审批处理体验和回滚提示。
- 配置真实 `origin` 后持续执行 main 直推和 Agent C 下载结果包复判。
- 后续可由 `agentx:` 启动主控循环，但每轮仍必须经过 Agent A 提示词、Agent B main push 和 Agent C artifact 验收。

## 11. 不允许破坏的行为

- staged 模型不能启用真实 runtime。
- token 不能进入 envelope body。
- Gateway allowlist 未通过时必须 blocked/skipped/failed，不能执行。
- 最终发送、提交、外发消息必须停在用户确认。
- `ClawGatewayEventStream.apply` 必须能按事件累积结果和 artifact。
- Smoke 断言不能因为实现不方便被删除。
- CI manifest 的 commitSha/runId/runAttempt 必须对应 Agent C 正在验收的 `origin/main` 最新 run。
