# 测试规范

本文指导 Agent A/B/C 选择非编译静态检查、GitHub Actions 云端重验证和 Agent C 结果包复判方式。

## 固定前缀 / 环境要求

- 工作目录：`/Users/a114514/Desktop/codex/aiclaw`
- 默认分支：`main`
- 默认远端：`origin/main`
- 云端 workflow：`.github/workflows/ci-results.yml`
- Agent C 下载缓存：`/private/tmp/claw-c-review-<run_id>/`
- Node：用于云端 `Tools/*.mjs` Gateway prototype 和 smoke；默认不在本地运行 `node --check` 或 smoke。
- Swift/Xcode：Swift 逻辑 smoke 和 iOS build 由云端 workflow 运行；默认不在本地运行 `swiftc`、`xcodebuild` 或模拟器验证。
- Gateway smoke 会在 CI 写入 `.build/*`；本地默认不运行。
- 当前项目没有包管理器配置；不要引入第三方依赖，除非人工明确同意。
- 如果本地没有配置 `origin`、GitHub 权限或 `gh auth login`，必须说明阻塞原因，不能伪装已经完成云端验收。

## 默认策略

- 默认云端重验证：Agent B 本地只做必要的非编译静态检查，提交并 push 到 `origin/main`，由 GitHub Actions 运行完整重验证。
- 从 2026-07-07 起，默认禁止本地编译、本地 build、本地 xcodebuild、本地 Swift logic smoke、本地 Gateway smoke、本地 `node --check`；代码、Swift、Gateway、UI 和测试改动统一交给云端 CI 验证。
- 文档-only 修改可本地跑 `git diff --check` 和 workflow/YAML 语法检查；业务测试仍以云端结果包为准。
- Swift / Xcode / Gateway / 协议相关改动完成后，默认进入 main push -> CI 结果包 -> Agent C 下载复判闭环。
- 云端失败时，Agent B 根据结果包中的 failure summary、manifest 和日志路径，在 `main` 上追加修复 commit 后重新 push。
- push、CI 查询和 artifact 验收必须使用仓库授权的 GitHub 账号 `Altman-sam114`；不得使用其他账号伪装完成。

## Agent X 循环下的验证规则

- Agent X 只负责主控调度和轮次判断，不替代 Agent A/B/C 的职责。
- 每一轮仍以 Agent B 非编译静态检查、`origin/main` push 后 GitHub Actions artifact、Agent C 下载复判为准。
- Agent X 不得跳过 Agent C artifact 验收，不得只凭 Agent B 的文字说明进入下一轮。
- Agent C 判定失败时，Agent X 只能选择退回 Agent B 修复、暂停等待人工确认或停止，不能继续下一轮伪装成功。
- Agent X 宣布总目标完成前，最后一轮必须有 Agent C 对最新 `origin/main` run 的 manifest、JUnit/摘要、日志和关键结果文件复判通过结论。
- 连续 3 轮同一阻塞、连续 2 轮无有效 diff、CI 连续同因失败、权限/账号/密钥/付费服务缺失、工作区冲突无法判断归属或用户要求停止时，Agent X 必须暂停或停止。

## Agent B 本地非编译静态检查

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

本地规则：

- 默认不运行 `node --check`、direct smoke 或 WebSocket smoke。
- 通过代码复核和非编译静态检查确认提交范围后，push 到 `origin/main`，由云端 workflow 覆盖 `node --check`、direct smoke 和 WebSocket smoke。
- 浏览器网络重定向测试必须使用小型本地 HTTP fixture：direct smoke 覆盖同 host 相对跳转、5 跳边界、非法 Location/协议和跨 host 阻断；direct/WebSocket 都必须以目标 hit count 为 0 证明未授权目标未被联系，并核对 action-bound 脱敏 Browser artifact。
- Agent Loop 推荐策略测试必须覆盖 request、envelope 与固定支持种类的交集：direct smoke 覆盖全阻断、部分交集、request 子集、固定集合过滤和显式空请求，并验证所有 trace 派生字段都属于三方交集且 metadata 不泄露列表；WebSocket smoke 覆盖 envelope 只允许 `runAgentLoop` 的 `requested/effective/blocked=2/0/2`、`none`、blocked handoff 和 session 完成。Swift/XCTest 覆盖未知 policy、越界/矛盾计数、selected 未授权均进入人工复核并禁止继续 Loop。
- Agent Loop selected-action decision 测试必须核对 `evidence-first-safe-v1`、固定 reason、候选数量、1-based 序位、候选成员和一致性。双 smoke 覆盖 policy-blocked、证据恢复、免审批优先和审批回退，并证明未选高风险候选不污染 selected stop/handoff；Swift/XCTest 对审批字段缺失、未知 reason、ordinal 越界、成员/一致性 false 及 kind/approval/readiness/stop/handoff 矛盾统一 fail closed。
- 以下 v0.66 条目定义生产合同必须最终达到的云端覆盖，不代表当前工作区 diff 已完整覆盖。当前 baseline 只覆盖主要成功路径、receipt 复用/并发复用、单组 binding mismatch、wire offer 提取与 redaction，以及一条 Swift continuation happy path；其余签发拒绝、expiry/eviction/restart、action shape/parameter/policy/side-effect、六种 kind/state/UI 和 Direct/WebSocket 对称矩阵均为残余必补覆盖。最新云端 artifact 未证明这些残余项前，Agent C 不得把完整矩阵判为通过。
- v0.66 receipt 签发测试必须覆盖严格 valid/allowed/`safe-without-approval`/`ready-to-continue`/selected non-none 成功，以及 approval-required、final-submit、external/destructive、needs-evidence、policy-blocked、no-action、complete、unknown/missing/contradictory contract、effective intersection/handler 漂移和父 context 超过 6 条或 256 KiB 时不签发。offer 固定 TTL 600 秒、cache 容量 128、单次进程内消费；raw receipt 只允许出现在 WebSocket 或 `--emit-events-stream` stdout 的私有 framed wire offer，不得进入诊断 stdout/stderr、artifact/metadata/event summary、JUnit、failure summary、manifest 或 UI 可见输出。
- v0.66 child success 测试必须证明 child task/action/session ID 全新，actions 恰好按 receipt selected kind、`runAgentLoop` 排列；按精确 task ID 审批/冻结/发送后，Gateway 在新 workspace 中把冻结父快照复制为与父隔离的可变 child session context，先执行 selected handler，再由 child 本轮结果生成新的 AgentTrace 和不同的可选下一轮 receipt。首次发送尝试后 iOS vault 必须清理，continuation transport 不得自动重连/重发同一 frozen envelope；receipt 成功消费后 iOS vault 和 Gateway cache 都不能复用。
- v0.66 child fail-closed 测试必须逐项覆盖 lineage/contract/receipt 缺失、空值、未知、污染或格式错误，伪造/过期/已消费/淘汰/重启失效 receipt，并发双消费，父 task/session/artifact/digest、round、selected kind、decision、token/profile/policy 不匹配，父 child ID 复用，action 数量/顺序/唯一性错误，当前 allowlist/handler/policy 阻断，以及参数缺失、未知 key、alias 冲突、超长、类型错误和路径逃逸。每个失败都必须发生在 replay/workspace/event/artifact/handler 前，断言无文件、网络、Shell、浏览器、桌面或草稿副作用，错误不可重试且不回显 marker 或 raw receipt。
- v0.66 Direct/WebSocket 必须对称覆盖父 receipt 签发、child 成功、context 继承、新 workspace、action 顺序、新 AgentTrace、新 receipt 和单次消费，以及 forged/expired/consumed/mismatch/policy/shape/parameter/side-effect 全矩阵。WebSocket 失败只允许无 action identity 的安全 envelope error，不得把 receipt 或未知 action kind送入 Swift 闭合 enum event。Swift Gateway fixture `--self-test` 必须覆盖私有 offer 提取、公开 event 剥离、receipt redaction、成功 child contract 和无 handler/已消费 fail-closed。
- Gateway unsupported handler 测试必须在 direct 与 WebSocket 两条云端路径覆盖 known-enum + envelope-allowed + handler-unsupported：最终事件只能是 action-bound `actionFailed`/`failed`/non-retryable，不得出现同 action 的 `actionCompleted`、`approvalRequested` 或 policy `actionSkipped`；只允许 redacted `auditLog`，禁止 screenshot、browserTrace、fileDiff、commandOutput、extractedData、messageDraft、agentTrace 等业务 artifact。
- unsupported smoke 必须用唯一敏感 marker 和文件/Shell/网络/桌面/草稿副作用哨兵，断言 summary、artifact title/metadata/payload 不泄漏 instruction、inputPreview、target、`toolArguments`、URL/path/command/正文，且后续合法 action 和 `sessionCompleted` 仍到达。Swift Gateway fixture 必须对同类已知 action输出 `actionFailed`、不可重试和 action-bound redacted audit；fixture 编译运行只在云端执行。
- direct/WebSocket 还必须各自覆盖未知 action kind：固定返回不可重试的 `unsupported_action_kind`，不进入 replay/session workspace、action-bound event、handler、artifact 或正常 `sessionCompleted`，错误不得回显未知 kind；WebSocket 只允许无 action identity 的 envelope error event。Swift fixture云端 `--self-test` 必须真实检查 known-enum unsupported 合同。
- v0.68 普通 Dispatch Preflight 必须在 replay cache、workspace、`gatewayConnected`、能力快照 audit artifact、action event、业务 artifact 和 handler 前运行；direct/WebSocket/fixture 覆盖合法 `sent`、缺失/未知、`waitingForApproval`、`queued`、`blocked`、`draft`、`readyToSend`、`approvedFrozen`、`complete` 以及敏感 action `automatic` 伪造。每个失败只允许固定无 action identity、`isRetryable=false` 的 envelope error，禁止 task/action identity、状态原文、instruction、target、`toolArguments`、URL/path/正文/token/receipt 泄漏，并断言无 replay record、workspace、事件、artifact、handler 或文件/网络/Shell/浏览器/桌面/草稿副作用；同一 task 随后合法 `sent` 必须仍可首次执行。allowlist skip/unsupported handler、continuation `readyToSend + receipt` 和 receipt 单次消费必须回归。上述 fixture、direct/WebSocket、Swift LogicSmoke/XCTest 和 Xcode build 只在云端执行，本地不得运行 `node --check`、fixture、smoke、LogicSmoke、XCTest 或编译。

### Swift 核心逻辑改动

触发条件：

- 修改 `Claw/Core/ClawModels.swift`。
- 修改 `Claw/Services/ClawStore.swift`。
- 修改 planner、bridge、simulator、event reducer、autonomous loop。
- 修改 Mission Run presentation summary、Approval Fast Lane 审批快车道、Mac Agent Control Snapshot（含 Live Health 信号） 控制态势快照、Operator Strip（gateway/live/policy/evidence/review/next）、Loop 继续态势、Mac Agent Readiness Board、Policy Diagnostics Board 就绪看板、Mac Gateway Action Preflight Matrix 动作预检矩阵、Mac Agent Evidence Coverage Map 证据覆盖图、Mac Agent Next Step Deck 下一步候选卡组、Mac Agent Run Timeline 执行时间线、Mac Agent Continuation Gate 继续闸门、Mac Agent Review Radar 复核雷达、Mac Agent Handoff Brief 人工交接简报、Focus Context 聚焦上下文、Review Detail Dock、Review Trail 复核路径、Approval Queue 审批队列、Payload Safety Ledger 载荷安全账本、Artifact 证据索引、复核优先队列、复核聚焦模式、复核态势摘要、下一步复核行动或 SwiftUI 展示派生模型。
- Mission Run 会话归属测试必须覆盖连续任务 A/B：B 未发送时不得继承 A 的 session、结果、artifact、metadata 复核或 Live Gateway 状态；B 发送后 session.taskID 必须等于 B task.id。
- scoped review focus 测试必须覆盖同 scope 保留、切换 task 失效、task-to-session 失效、全量详情回退、固定 stale 提示，以及旧命令敏感片段和 scope UUID 不外显。
- v0.69 Mission primary action presentation 必须覆盖 idle/start、waitingForApproval/approveAndContinue、needsAttention/continueAfterReview、completed/start、实际 live-prepared observing Gateway/waiting/disabled 和 blocked/inspectBlocked 状态的 title/icon/enabled 三元组；regular Dock 与 compact panel 必须复用同一渲染 summary/view/dispatcher，dispatcher 对 stale command/task/session/sessionTask/mission scope/phase/action 或 disabled 状态不得调用 Store。按钮至少 44pt，并带不自动发送且不绕过手机审批的 VoiceOver hint；验证只在云端 Swift logic smoke、XCTest 和 Xcode build 执行。
- v0.70 pairing diagnostics/resume intent 必须覆盖 endpoint 缺失、非 ws/wss、token 缺失、配置但无 ack、匹配当前 task/session 的 live ack、transport failed、fallback、completed、旧 request/profile/session scope stale/mismatch；必须分开断言 canAttemptLive 与真实 Gateway ack。显式恢复按钮只能在当前 live failure/可重试 scope 出现，点击前后 task/session/events/envelope/approval/frozen/receipt 状态不变；intent 必须绑定 profile digest、session revision 和 continuation 状态，变化后 disabled/stale。compact iPhone 与 regular iPad/mac 必须复用同一 summary/API/view，按钮至少 44pt 并带“不自动发送” VoiceOver hint。UI、摘要、日志和云端 artifact 不得出现 raw token、Authorization/Bearer、receipt、UUID、payload/toolArguments、workspace/path、URL query 或正文；本轮不改 Gateway protocol、handshake、持久 secret、后台保活或静默恢复。
- continuation Swift/XCTest/LogicSmoke 仍必须覆盖六种推荐 kind 的 typed 参数草稿、`readyForInput`、strict safe selected 的 `readyForApproval`，以及 approval selected 只能 `needsApproval` 且无法 queue/send；invalid metadata、selected none、policy blocked、no-action、stale trace、错误父 task/session/artifact、profile 变化和 receipt 过期统一 fail closed。v0.67 只为 `manageFiles` 增加编辑器测试：固定 `operation=writeText`、`workspaceOnly=true`，允许编辑 `writePath`/`writeText`；必须覆盖空路径、空正文、绝对路径、`~`、包含 `..` 的路径段、未知 key 和超过 4096 UTF-8 bytes 的任一字符串值，断言固定脱敏提示、保持 `readyForInput`、不能 queue/创建 child/写 approval record/frozen envelope。带有效 receipt 的 safe-without-approval 草稿在合法相对路径和非空正文后进入 `readyForApproval`，且父 task/session/AgentTrace scope、decision digest、receipt handle/expiry 保持不变；approval-required/destructive 的 `manageFiles` 草稿即使参数合法也必须保留 `needsApproval`、无 receipt、不可 queue/send，但未入队前可继续编辑。入队后 child actions 必须恰好为 `[manageFiles, runAgentLoop]`，入队、审批冻结和发送后的编辑请求必须被拒绝；compact iPhone 与 regular iPad/mac 必须复用同一 summary/view/API，并覆盖 VoiceOver hint、44pt 控件和 raw receipt/token/父 payload/绝对路径/metadata 不外显。其他五种 kind 的 `readyForInput` 仍是无通用编辑路径的阻断态，完整六种 kind 和负向状态矩阵仍是残余覆盖。
- v0.67 的 Swift、XCTest、LogicSmoke、fixture、direct smoke、WebSocket smoke 和 Xcode build 必须在提交并 push `origin/main` 后由 GitHub Actions 验证；本地只允许 `git status`、`git diff --check`、文本/diff 复核等非编译检查。Agent C 必须下载最新 run 的未加密 artifact，核对 `ci-artifact-manifest.json`、`ci-failure-summary.md`、JUnit/摘要、`xcodebuild.log`、`xctest.log`、`ClawTests.xcresult`、`swift-logic-smoke.log`、fixture/direct/WebSocket 日志与 commit/run/attempt 一致，不能以本地输出或旧 artifact 代替。
- 创建 continuation draft 前后必须断言父 Mission scope、task/session/events/live request 和 review focus 不变；只有显式 queue child 后才切换 scope并显示安全 lineage breadcrumb。旧按钮、错误 task ID、摘要不匹配、重复 send、审批后 action/profile/lineage 变化都必须拒绝或使 approval/frozen envelope 失效。
- compact iPhone 与 regular iPad/mac 必须复用同一 continuation presentation summary，覆盖生成草稿、参数缺口、needsApproval、过期、queued、approvedFrozen 和 sent 状态；动态文本不得溢出，按钮至少 44pt并带“不自动发送”的 VoiceOver hint。UI、accessibility label、日志和 redacted envelope 不得出现 raw receipt、完整 `toolArguments`、父 payload、URL/path/正文、token/header、workspace 或敏感 marker。
- 修改 `Tools/LogicSmoke（含 Mission Run Live Gateway Health Strip）.swift`。

本地规则：

- 默认不运行 `swiftc`、`.build/claw-logic-smoke`、`xcodebuild build`、`xcodebuild build-for-testing` 或模拟器测试。
- 通过代码复核和非编译静态检查确认提交范围后，push 到 `origin/main`，由云端 workflow 覆盖 Swift logic smoke、iOS build 和真实 iPhone Simulator XCTest。

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
- Swift Gateway event fixture 编译和 `--self-test` 合同检查。
- Gateway direct smoke。
- Gateway WebSocket smoke。
- `xcodebuild build`。
- 在动态发现的可用 iPhone Simulator 上执行 `xcodebuild test`。
- 结果包 manifest、failure summary、JUnit 或等价摘要、主日志和 `.xcresult`。

结果包最低内容：

- `ci-artifact-manifest.json`
- `ci-failure-summary.md`
- `junit.xml`
- `xcodebuild.log`
- `xctest.log`（总是预创建，包含 simulator discovery 和 XCTest 失败诊断）
- `ClawTests.xcresult`（XCTest outcome 为 success 时强制存在；缺失会使 packaging 失败）
- `swift-logic-smoke.log`
- `swift-gateway-fixture.log`
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
- `xctestLogPath`
- `xctestResultBundlePath`
- `xctestArtifactsOutcome`
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

## 测试数据与下载容量限制

本项目默认采用小数据量验证策略，避免下载过大 artifact、模型、数据集、缓存或结果包，把本机、CI runner 或临时目录容量撑爆。

规则：

- 测试数据必须尽量小，只覆盖必要边界。
- CI artifact 只上传必要文件：manifest、JUnit 或测试摘要、关键日志、失败摘要、必要结果包。
- 不上传大体积 DerivedData、完整 build cache、无关截图、视频、模型文件、历史 artifact 或重复压缩包。
- Agent C 下载 artifact 前优先确认只下载最新 run 对应的必要结果包。
- 下载缓存默认放在 `/private/tmp/<project>-review-<run_id>/`，Claw 当前使用 `/private/tmp/claw-c-review-<run_id>/`。
- 下载后应检查目录大小：

```sh
du -sh /private/tmp/<project>-review-<run_id>/
```

- 禁止使用非 `Altman-sam114` 的 GitHub 账号伪装完成 push、CI 或 artifact 验收。
- 禁止默认下载大体积测试数据、模型、历史 artifact 或无关产物。

## 本地编译和本机构建禁用说明

从 2026-07-07 起，默认不在本地运行 Xcode build、Swift logic smoke、Gateway smoke、`node --check` 或其他本地编译/构建型验证；这些全部交给 GitHub Actions。

当前基线：

- 云端 `xcodebuild build` 应成功。
- direct smoke 必须覆盖 artifact 落盘、workspace 文件写入、File Change Safety metadata 和 policy diagnostics、路径逃逸阻断审计、workspace 写入失败审计、workspace symlink 阻断、browser trace、Browser Control metadata 和 policy diagnostics、Accessibility signal quality metadata、Shell Command Safety metadata 和 policy diagnostics、结构化提取、Shell dry-run/allowlist、缺少结构化 Shell 命令阻断、浏览器策略、桌面 App 审批闸门、Desktop App policy diagnostics、`agentTrace` handoff status、mac 证据质量分层、Agent Loop 推荐交集全阻断/部分允许，以及 unsupported handler 的 failed/non-retryable/action-bound redacted audit/无业务副作用/后续 action 继续矩阵；Shell disabled dry-run 必须断言 `binaryAllowlistChecked=false`，allowlist-enabled 裸命令路径必须保持 `true`；同名 executable 路径必须在执行前阻断；顶层 `shellCommand`、顶层 `commandLine` 和合法嵌套字段与 alias 冲突必须在 parse 前阻断，并以伪造 allowlisted executable 的副作用文件不存在证明未执行，同时断言事件和阻断 payload 不泄露原命令；dry-run screen/accessibility 必须进入 degradedSignals，不能进入 satisfiedSignals。
- WebSocket smoke 必须启动一次性 Gateway，验证事件闭环、browser/file/shell/extract/agent loop 主链路、AgentTrace satisfied/degraded/missing metadata 兼容、envelope 仅允许 `runAgentLoop` 时推荐空交集只返回 `none` 和 blocked handoff、File Change Safety metadata 和 policy diagnostics、路径逃逸阻断审计、workspace 写入失败审计、Browser Control metadata 和 policy diagnostics、Accessibility signal quality metadata、Shell Command Safety metadata 和 policy diagnostics（含 dry-run `binaryAllowlistChecked=false`）、同名 executable 路径阻断、顶层 Shell alias 阻断及无副作用/无命令泄露、Delivery Safety 固定桌面策略键、unsupported handler fail-closed 对称矩阵和 `sessionCompleted`。
- Swift logic smoke 必须覆盖 Mission Run Approval Fast Lane 审批快车道的 idle、发送前审批、发送后首要确认、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦和敏感字符串不外显，Control Snapshot 控制态势快照的 idle、发送前审批、发送后控制状态、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险可重试、AgentTrace 可继续和敏感字符串不外显，Operator Strip 的空状态、lane 顺序、计数一致性、聚焦状态，Loop 继续态势的无 AgentTrace、metadata 缺失、final-submit-review、ready-to-continue、degraded/missing 计数和只聚焦 AgentTrace 行为，Mac Agent Readiness Board 就绪看板的 idle、固定五行顺序、ready/blocked/metadata/human count、capability/accessibility/agentTrace 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦和敏感字符串不外显，Mac Gateway Action Preflight Matrix 动作预检矩阵的 idle、action 顺序、ready/blocked/degraded/metadata/human count、发送前审批聚焦、发送后按 action kind 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦、可重试状态和敏感字符串不外显，Mac Agent Evidence Coverage Map 证据覆盖图的 idle、发送前 action/审批支撑、发送后 action/evidence/metadata/payload count、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦和敏感字符串不外显，Mac Agent Next Step Deck 下一步候选卡组的 idle、发送前审批候选、发送后人工确认/证据补齐/失败复核/Loop 下一步/抽查复核候选、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险可重试、AgentTrace 可继续和敏感字符串不外显，Mac Agent Run Timeline 执行时间线的 idle、发送前 action/审批时间线、发送后 action/evidence/handoff step、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险可重试、metadata 缺失回退和敏感字符串不外显，Mac Agent Continuation Gate 继续闸门的 idle、发送前审批、发送后人工/metadata/loop/抽查闸门、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险可重试、AgentTrace 可继续和敏感字符串不外显，Mac Agent Review Radar 复核雷达的 idle、发送前审批、发送后五 sector、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险可重试、AgentTrace 可继续和敏感字符串不外显，Mac Agent Handoff Brief 人工交接简报的 idle、发送前审批、发送后五 item、primary 排序、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险可重试、AgentTrace 可继续和敏感字符串不外显，Focus Context 聚焦上下文的 idle、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦和敏感字符串不外显，Review Detail Dock 的 idle、全量详情、detail 聚焦、状态级回退、过期回退、Shell 高风险聚焦和敏感字符串不外显，Review Trail 复核路径的 idle、四步顺序、证据/metadata/优先/下一步计数、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦和敏感字符串不外显，Approval Queue 审批队列的 idle、发送前审批、发送后 Gateway/Delivery/AgentTrace 确认、状态级聚焦、Shell 高风险聚焦、排序稳定和敏感字符串不外显，Payload Safety Ledger 载荷安全账本的 idle、payload-not-read/metadata-only/省略信号计数、detail 聚焦、状态级聚焦回退、过期聚焦回退、Shell 高风险聚焦和敏感字符串不外显，Accessibility signal quality 的固定枚举/metadata 缺失回退/敏感字符串不外显，Delivery Safety 桌面策略诊断的固定枚举、metadata 缺失回退、敏感字符串不外显和 `requiresDesktopPolicyReview`，AgentTrace handoff status 的固定枚举、metadata 缺失回退和敏感字符串不外显，Artifact 证据索引的空状态、证据类型映射、metadata/redaction count、聚焦状态，复核优先队列的排序稳定、高风险复核项、复核聚焦过滤/回退、复核态势摘要 count 一致性、下一步复核行动和敏感字符串不外显；XCTest 也应覆盖同类 presentation-layer 派生。

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
- 默认本地非编译静态检查 + 云端重验证。
- 禁止默认本地编译、本地 build、本地 xcodebuild、本地 Swift logic smoke、本地 Gateway smoke 或本地 `node --check`。
- 不得伪造测试结果。
- 不得删除断言来制造通过。
- 不得把旧 artifact、旧 output 或 checkout 自带报告冒充本轮云端结果。
- 文档-only 修改可只跑本地静态检查，但必须说明未跑业务测试的原因。
- 最终回复必须写清楚每条测试命令和结果、云端 run 状态、结果包是否已下载复判。
