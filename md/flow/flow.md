# 项目核心流程文档

## 0. 一句话总览

Claw 的当前主链路是：用户在 iPhone 输入电脑任务，App 生成可审批的 Claw computer-control envelope，桌面 Gateway 在安全策略内执行或模拟执行，并把事件、artifact、审批点和失败信息回传给手机端。

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
  -> ClawGatewayEvent
  -> ClawGatewayEventStream.apply
  -> ClawGatewaySession.results/artifacts/auditTrail
  -> ClawMissionRunSummary 派生任务回合摘要
  -> SwiftUI Mission Run 展示、审批、重试或下一轮
```

## 2. 当前协作验证流

```text
人工提出目标
  -> Agent A 本地分析并写版本化提示词
  -> Agent B 同步 origin/main 并在 main 上实现
  -> Agent B 本地轻量检查
  -> Agent B commit 并 push 到 origin/main
  -> GitHub Actions 运行 build / smoke / 静态检查
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
  -> Agent B 按提示词实现、轻量检查、commit 并 push origin/main
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
   - `liveGateway`：准备 WebSocket 请求，endpoint/token 不满足时回退模拟流。
7. 桌面 Gateway 原型 `Tools/claw-gateway-server.mjs` 校验 schema、token、动作白名单和策略。
8. Gateway action handler 写 artifact 并返回状态：成功、失败、等待审批、跳过。
9. 手机端 reducer 用事件更新 session，UI 显示结果、artifact、审批点、retry 状态。
10. `ClawAutonomousLoopState` 记录计划、审批、发送、观察、重试等自动循环状态。

## 4. 核心模块

### 4.1 SwiftUI App

职责：

- 展示连接、聊天、电脑接管、能力和榜单。
- 让用户输入任务、配置 Gateway URL/token、切换发送模式、查看 envelope 和事件。
- 在电脑接管首屏用 Mission Run 面板汇总任务目标、阶段、下一步主动作、风险、审批点、Gateway 结果和 artifact 证据。

输入：

- 用户文本。
- Gateway 配置。
- Gateway event stream。

输出：

- UI 状态。
- `ClawMissionRunSummary` 派生展示状态。
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

输入：

- `ClawMobileTask`
- `ClawGatewayEvent`

输出：

- `ClawGatewaySession`
- action result、artifact、auditTrail

禁止：

- 丢失 actionID/actionKind 对应关系。
- 用自然语言状态替代结构化 result status。

### 4.5 Desktop Gateway Prototype

职责：

- 通过 WebSocket 或 `--emit-events` 接收 envelope。
- 校验 schema、token、动作白名单。
- 处理 action 并写入 workspace artifact。

当前 action handler：

- `observeScreen`：dry-run 或 macOS 截图/窗口元数据。
- `controlBrowser`：HTML/URL trace、浏览器打开/搜索计划、受 allowlist 的 macOS 浏览器控制。
- `manageFiles`：workspace 内结构化写文件。
- `runShellCommand`：结构化命令 dry-run 或 allowlist 执行。
- `extractData`：消费同 session artifact 生成结构化数据。
- `operateDesktopApp`：桌面 App 聚焦、粘贴、allowlist 快捷键、最终提交前审批。
- `runAgentLoop`：基于 session artifacts 生成观察-规划-动作建议-验证 `agentTrace`，并在 artifact 内部记录 readiness、decisionChecklist、selectedNextAction、riskTags、stopReason 和 handoffSummary。
- `composeMessage`/`composeEmail`：生成待确认草稿。

禁止：

- 自然语言直连 Shell 或桌面自动化。
- 路径逃逸到 workspace 外。
- 未经 app/key/host allowlist 控制浏览器或桌面 App。
- 用 `agentTrace` 的下一步建议绕过结构化 `toolArguments`、allowlist 或最终提交审批。

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
- `ClawGatewaySession`：手机端会话视图模型。
- `ClawAutonomousLoopState`：自治循环状态。
- `ClawMissionRunSummary`：手机端 presentation layer 摘要，只从 loop/task/session 派生，不进入 envelope 或 Gateway 协议。

## 6. 用户入口

- App UI：`ContentView` 内连接、聊天、电脑接管 Mission Run 面板和相关详情面板。
- Shortcuts/App Intents：`ClawShortcuts.swift`。
- Gateway CLI：`node Tools/claw-gateway-server.mjs` 或 `--emit-events`。
- Smoke：`Tools/claw-gateway-direct-smoke.mjs`、`Tools/claw-gateway-smoke.mjs`、`Tools/LogicSmoke.swift`。

## 7. 层关系

- 前端层：SwiftUI views 只展示和触发 `ClawStore` 方法。
- 状态层：`ClawStore` 是主要 ObservableObject。
- 模型层：`ClawModels.swift` 定义跨 UI、Gateway、测试共享的 schema。
- 展示派生层：`ClawMissionRunSummary` 从现有状态组合首屏任务回合视图，不作为新的 source of truth。
- 执行层：桌面 Gateway Node 原型负责真实或 dry-run 工具动作。
- 文档层：README 面向开发者，`Docs/*` 面向协议，`md/flow/*` 面向当前真实逻辑和协作闭环，`AGENTS.md` 面向 Agent 工作规则。
- 测试层：本地轻量检查、GitHub Actions 云端重验证、XCTest/Swift logic smoke、Gateway JS smoke。

## 8. 已确认铁律

- Claw 不做法律方向；任何“法律/合同”等词只可作为禁止项或非目标出现。
- iOS 不能越权控制电脑；必须通过用户授权的 Gateway。
- Gateway 只执行结构化参数。
- 所有敏感动作默认审批。
- Shell、文件、浏览器网络、桌面 App 控制必须受 allowlist 限制。
- 每个重要 action 都要产生 artifact 或明确失败/跳过原因。
- 新协议字段必须同步测试和文档。
- Agent C 验收必须基于 `origin/main` 最新 run 的未加密结果包，不能只看 Agent B 文字汇报。
- 云端失败默认用 main 追加修复 commit 处理，不默认回滚或引入候选分支。
- Agent X 只能调度 A/B/C 多轮迭代，不能代替 Agent C 宣布云端 artifact 验收通过。

## 9. 测试映射

- Planner/bridge/schema 变更：本地 Swift logic smoke（需要时）+ 云端 xcodebuild/logic smoke/结果包验收。
- Gateway handler 变更：本地 `node --check Tools/*.mjs` + 云端 direct smoke/WebSocket smoke/结果包验收。
- Event reducer 变更：Swift logic smoke、XCTest 或等价云端 build 结果。
- Mission Run 派生摘要或首屏任务回合 UI 变更：XCTest/Swift logic smoke 覆盖 idle、待审批、需处理、完成、阻断摘要；云端 xcodebuild 覆盖 SwiftUI 编译。
- 文档-only 变更：本地 `git diff --check`、workflow YAML 语法检查；云端由 `main` push 触发结果包。

## 10. 未来扩展点

- 将 Gateway prototype handler 拆成可插拔工具层。
- 引入真实 macOS Accessibility tree bridge。
- 增加 Playwright/browser-use 兼容浏览器控制器。
- 强化 `runAgentLoop` 多轮状态机、失败恢复、下一步策略和手机端 artifact 复核体验。
- 增加 live Gateway 心跳、重连、配对和审计日志持久化。
- UI 上继续增强 Mission Run 内的 artifact 预览、审批队列和回滚提示。
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
