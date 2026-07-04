# 项目版本更新记录

本文记录 Claw 的正式版本、重要维护事项、关键决策和遗留问题；不是流水账。

## 维护规则

- 每完成一个正式版本或重要任务后追加记录。
- 记录必须包含：版本/任务名、日期、核心变更、关键文件、验证结果、遗留事项。
- 文档整理、目录迁移、回滚、打捞等不伪装成新版本，可写入“历史维护记录”。
- 若核心逻辑、测试规范或项目行为变化，必须同步更新本日志。
- 当前默认由 Agent B 在 `main` 上提交并 push 到 `origin/main` 触发云端验证；Agent C 通过下载结果包复判，不通过时退回 Agent B 追加修复 commit。
- commit 信息格式为 `vX.Y: 简要概括本轮工作`，必要时用简短正文概括核心变更、测试结果和遗留风险。

## 当前状态

- 项目方向：OpenClaw 式电脑接管智能体，iPhone 作为控制台，桌面 Claw Gateway 作为执行端。
- 当前 schema：`claw.computer.control.v1`。
- 当前核心闭环：用户自然语言任务 -> `PhoneAgentPlanner` -> `ClawMobileTask` -> `ClawMobileEnvelope` -> 模拟事件流或 WebSocket Gateway -> `ClawGatewayEvent` -> session reducer -> Mission Run / Gateway 能力复核摘要 / AgentTrace 复核 UI / iPad 多栏工作台展示和审批。
- 当前 Gateway 能力：session-start 能力快照 `auditLog`、屏幕观察 dry-run/截图策略、浏览器 HTML/URL trace、浏览器打开/搜索计划、workspace 文件写入、Shell dry-run/allowlist 执行、结构化提取、桌面 App 审批闸门、带 readiness/checklist/risk/stop/handoff 与安全 metadata 的 `runAgentLoop`/`agentTrace`。
- 当前协作闭环：默认 `main` 直推，GitHub Actions 生成未加密 `ci-results` 结果包，Agent C 下载并核对 manifest/JUnit/日志后验收。
- 当前主要遗留：完整 macOS Accessibility tree、Playwright/browser-use 兼容控制器、真实多轮 agent loop、live Gateway 心跳和重连、完整 artifact 内容复核体验。

## 历史记录

### v0.10 / 手机端 Gateway 能力复核摘要

日期：2026-07-04

核心变更：

- Gateway `gateway-capability-snapshot.json` `auditLog` artifact event 附带安全 metadata，包含固定 allowlist 键：snapshot kind、token 配置/短指纹、allowedActionKinds、workspace/shell/browser/screen/window/desktop capability state、safety flags 和 platform。
- Swift `ClawGatewaySession` 新增向后兼容的 `sessionArtifacts`，旧 JSON 缺字段时默认为空；`artifactCount` 和 artifact kind summary 改为统计 session-level artifacts 与 action-bound artifacts。
- Reducer 对无 action 绑定的 `artifactStored` 不再丢弃，而是合并到 `sessionArtifacts` 并写入 auditTrail；action-bound artifact 仍进入对应 action result，不创建伪 result。
- 新增 `ClawGatewayCapabilityReviewSummary`，Mission Run、Gateway session card 和 iPad regular 工作台展示 metadata 派生的 Gateway 能力复核摘要；UI 不读取 `file://` 内容，不显示 raw token、完整 path、payload、`instruction` 或 `toolArguments`。
- Simulator、XCTest、Swift logic smoke、Gateway direct/WebSocket smoke 同步覆盖 session-level artifact、metadata allowlist、一致性和无敏感内容泄露。
- 同步 README、协议和 flow/flowchart 文档；本轮不新增 schema/action/event/artifact kind，不扩大 Gateway 权限。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.10（手机端Gateway能力复核摘要）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (108 events)`。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (18 events)`。
- 无签名 iOS build 通过，输出 `BUILD SUCCEEDED`。
- `xcodebuild build-for-testing` 通过，输出 `TEST BUILD SUCCEEDED`，确认 `ClawTests` 可编译；本机未启动模拟器执行 XCTest。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。

遗留事项：

- push `origin/main` 后仍需等待 GitHub Actions `ci-results` 结果包，供 Agent C 下载并核对 manifest、JUnit/摘要、Gateway direct/WebSocket smoke 日志、Swift logic smoke 和 xcodebuild 日志后复判。
- 当前是 metadata 摘要复核，不是完整 artifact JSON viewer；live Gateway 心跳/重连、真实多轮 agent loop 和完整 artifact 内容复核仍待后续轮次推进。

### v0.9 / Gateway 能力快照 artifact

日期：2026-07-04

核心变更：

- Gateway 每个 session 在 `gatewayConnected` 后、任何 action `actionStarted` 前写入 session 级 `auditLog` artifact：`gateway-capability-snapshot.json`。
- 快照 payload 只记录 workspace、session workspace、platform、Node 版本、短 token 指纹、envelope `allowedActionKinds`、action kind 列表、策略 allowlist 和 workspace/shell/browser/screen/window/desktop capability 状态。
- 快照明确 raw token、Authorization header、自然语言 instruction、`toolArguments`、网页正文、命令输出、截图内容和草稿正文均 omitted；本轮复用既有 `auditLog` artifact kind 和 `artifactStored` event kind，不新增 schema/action/event/artifact kind，不扩大 Gateway 权限。
- direct smoke 和 WebSocket smoke 增加快照存在性、事件顺序、redacted、无 raw token、token fingerprint、allowedActionKinds、workspace scope 和策略/capability 状态断言。
- 同步 README、协议和 flow/flowchart 文档，明确快照只用于审计复核，不作为执行计划来源。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.9（Gateway能力快照artifact）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (108 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (18 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 本轮未修改 Swift 模型、store、UI 或 `Tools/LogicSmoke.swift`，本地未跑 Swift logic smoke 和 iOS build；push `origin/main` 后由 GitHub Actions 覆盖。

遗留事项：

- Agent C 仍需下载最新 GitHub Actions `ci-results` 结果包，核对 manifest、JUnit/摘要、Gateway direct/WebSocket smoke 日志、Swift logic smoke 和 xcodebuild 日志后复判。
- 当前快照是 Gateway session 级安全摘要；完整 artifact JSON viewer、live Gateway 心跳和重连、真实多轮 agent loop 仍待后续轮次推进。

### v0.8 / iPad 多栏复核工作台

日期：2026-07-04

核心变更：

- 电脑接管页在 regular horizontal size class 下切换为左右两栏工作台：左侧显示命令输入和 Mission Run 主操作，右侧显示计划、Claw 电脑任务、Gateway 会话、事件/envelope、权限矩阵和执行日志。
- compact 布局保持原有单栏滚动顺序，不删除任何现有入口或操作按钮。
- 本轮只复用既有 `ClawStore` 安全路径和现有面板，不新增 source of truth，不改变 `claw.computer.control.v1` schema，不新增 action/artifact/event，不扩大 Gateway 权限。
- 同步 README、协议和 flow 文档，明确 iPad 工作台属于 presentation layer，不读取 Gateway `file://` artifact 内容。

关键文件：

- `Claw/Views/ContentView.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.8（iPad多栏复核工作台）.md`
- `update_log.md`

验证结果：

- 无签名 iOS build 通过，输出 `BUILD SUCCEEDED`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 本轮未修改 `Claw/Core/ClawModels.swift`、`Claw/Services/ClawStore.swift` 或 `Tools/*.mjs`，本地未跑 Swift logic smoke 和 Gateway smoke；云端 CI 仍会覆盖。
- push `origin/main` 后仍需等待 GitHub Actions `ci-results` 结果包供 Agent C 复判。

遗留事项：

- 当前是分栏复核工作台，不是完整 artifact JSON viewer；真实多轮 agent loop、完整 artifact 内容复核、live Gateway 心跳和重连仍待后续轮次推进。

### v0.7 / 手机端 AgentTrace 复核体验

日期：2026-07-04

核心变更：

- `ClawGatewayArtifact` 新增向后兼容的可选字符串 `metadata`，旧 artifact JSON 缺少 metadata 时仍可 decode。
- Gateway 和 simulator 在 `agentTrace` artifact event 上附带安全复核摘要：证据分、是否可继续、满足/缺失信号、推荐下一步、审批需求、风险标签、停止原因和 handoff 摘要。
- 手机端新增 `ClawAgentTraceReviewSummary`，Mission Run、Gateway session 和 result 行可显示最近 AgentTrace 复核状态、脱敏状态、缺口、下一步和停止原因。
- direct/WebSocket smoke 增加 artifact metadata 与 trace JSON 关键字段一致性断言；Swift logic smoke 和 XCTest 覆盖 metadata 存在与缺失路径。
- 同步 README、协议、flow/flowchart 和本提示词，明确 metadata 只用于手机端复核展示，不读取 Gateway `file://` 内容，不扩大执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.7（手机端AgentTrace复核体验）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (104 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (17 events)`。
- 无签名 iOS build 通过，输出 `BUILD SUCCEEDED`。
- `xcodebuild build-for-testing` 通过，输出 `TEST BUILD SUCCEEDED`，确认 `ClawTests` 可编译；本机 CoreSimulator 服务不可用，未执行模拟器 XCTest。
- GitHub Actions run `28703524664` attempt `1` 通过；Agent C 下载结果包 `claw-ci-v0.2-main-545c6b79c86d-run28703524664-attempt1` 并核对 manifest/JUnit/日志通过，manifest commit 为 `545c6b79c86d50e877e3929274aee10345b5aa8a`。

遗留事项：

- 当前只展示 `agentTrace` 的安全 metadata 摘要；完整 JSON artifact viewer、iPad 多栏复核面板、真实多轮 agent loop、live Gateway 心跳和重连仍待后续轮次推进。

### v0.6 / 增强 AgentTrace 证据策略

日期：2026-07-04

核心变更：

- Gateway `runAgentLoop` 的 `agentTrace` artifact 保留旧字段，并新增 `readiness`、`decisionChecklist`、`selectedNextAction`、`riskTags`、`stopReason` 和 `handoffSummary`。
- 新增证据策略只基于结构化 `toolArguments`、同 session 既有 artifact context、候选下一步和安全闸门推导，不扩大真实浏览器、Shell、AppleScript 或桌面 App 权限。
- direct smoke 和 WebSocket smoke 增加对证据分数、browser/file/command 满足信号、messageDraft 缺口、下一步选择、审批风险标签和停止原因的断言。
- 同步 README、协议和 flow 文档，明确本轮是 `agentTrace` artifact 智能化扩展，不改变 `claw.computer.control.v1` schema。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.6（增强AgentTrace证据策略）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (104 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (17 events)`。
- push `origin/main` 后仍需等待 GitHub Actions `ci-results` 结果包供 Agent C 复判。

遗留事项：

- `agentTrace` 仍是单轮 artifact 证据策略；真实多轮 agent loop、手机端详细 trace 预览和 Agent C 云端 artifact 复判由后续闭环继续推进。

### v0.5 / 引入 Agent X 循环迭代文档基线

日期：2026-07-04

核心变更：

- 新增 Agent X 召唤、职责、循环判断和停止条件。
- 将现有 Agent A/B/C 云端验证流程扩展为可被 Agent X 多轮调度。
- 更新 flow、flowchart、test、prompt README 和 README 中的协作说明。
- 明确本轮只做文档准备，不启动真实自动循环。

关键文件：

- `AGENTS.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/README.md`
- `md/prompt/v0（协作自动化）/v0.5（引入AgentX循环迭代）.md`
- `update_log.md`

验证结果：

- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过。

遗留事项：

- 后续人工可用 `agentx:` 提供总目标 X，启动 Agent X 主控循环。
- Agent X 真正执行循环时，仍必须经过 Agent A 提示词、Agent B 实现 push、Agent C 云端 artifact 验收。

### v0.2 / 任务回合化游戏体验

日期：2026-07-03

核心变更：

- 增加 `ClawMissionRunSummary`、阶段轨道和主动作派生模型，把现有 loop/task/session 状态整理为任务目标、阶段、回合进度、下一步动作、风险、审批、阻断、结果和 artifact 摘要。
- 将电脑接管页首屏更新为 Mission Run 面板，主按钮只调用已有安全路径：启动任务回合、审批并继续、复核后重试；阻断和等待状态不绕过审批或策略。
- 补充 XCTest 和 Swift logic smoke，覆盖 idle、待审批、需处理、完成重试和阻断状态。
- 同步 README、协议和 flow 文档，明确本轮是手机端 presentation layer 优化，不改变 `claw.computer.control.v1` schema，不新增 Gateway action/artifact/event。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证结果：

- Swift logic smoke 已通过，输出 `Claw logic smoke passed`。
- 无签名 iOS build 已通过，输出 `BUILD SUCCEEDED`。
- `git diff --check` 已通过，无输出。
- workflow YAML 语法检查已通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 已通过，输出 `OK`。
- push `origin/main` 后仍需等待 GitHub Actions `ci-results` 结果包供 Agent C 复判。

遗留事项：

- Mission Run 目前只显示 artifact kind 和计数；后续可继续增强手机端 artifact 预览、审批队列和回滚提示。
- Gateway smoke 由 GitHub Actions 云端重验证覆盖。

### v0.1 / 项目骨架与电脑接管原型

日期：2026-06-25 至 2026-06-27

核心变更：

- 建立 SwiftUI iPhone 控制台原型。
- 建立 Claw action schema、Gateway profile、mobile envelope、Gateway event reducer。
- 建立本地 Gateway Node 原型和 direct/WebSocket smoke。
- 增加 `runAgentLoop` 和 `agentTrace`，让 Gateway 能基于 session artifact 生成观察-规划-动作建议-验证轨迹。
- 增加 Shortcuts/App Intents 入口、本地模型 artifact 校验和模拟事件流。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Services/ClawShortcuts.swift`
- `Claw/Views/ContentView.swift`
- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Tools/LogicSmoke.swift`
- `Docs/claw-mobile-gateway-protocol.md`
- `README.md`

验证结果：

- 已建立 Swift 逻辑 smoke、XCTest、Gateway direct smoke、Gateway WebSocket smoke。
- 最近一次文档整理任务未运行完整业务测试；需在下一次代码改动后按 `md/test/test.md` 重新执行相关测试。

遗留事项：

- 部分 README/协议文档仍需同步最新 `runAgentLoop`/`agentTrace` 细节。
- 需要将真实 Gateway 工具层从 prototype handler 抽成可插拔执行器。
- 需要补充完整 Accessibility bridge 和真实浏览器点击/表单控制。

## 历史维护记录

### 建立多 Agent 协作系统文档

日期：2026-06-28

核心变更：

- 按“人工 -> Agent A -> Agent B -> Agent C -> 人工复核”的迭代模式建立项目记忆和规范文档。
- 统一项目入口为 `AGENTS.md`。
- 新增 `update_log.md`、`md/prompt/README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`。

关键文件：

- `AGENTS.md`
- `update_log.md`
- `md/prompt/README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证结果：

- 文档创建后需运行 `git diff --check`。
- 业务测试不要求运行，因为本次只建立文档和流程规范。

遗留事项：

- 后续 Agent A 应从 `v0.2` 开始继续分配提示词版本，除非人工指定版本。

### 补充 Agent C 版本提交规则

日期：2026-06-29

核心变更：

- 明确 Agent C 验收不通过时退回 Agent B，不创建版本提交。
- 明确 Agent C 验收通过后自动按版本号创建 git commit。
- 规范提交信息：`vX.Y: 简要概括本轮工作`，并要求最终输出版本号、commit hash、核心变更、关键文件、测试结果和遗留事项。

关键文件：

- `AGENTS.md`
- `md/flow/flowchart.md`
- `update_log.md`

验证结果：

- 文档-only 改动，需运行 `git diff --check`。

遗留事项：

- 当前修改本身不自动提交；后续从 Agent C 正式验收通过的版本开始执行自动提交规则。

### 升级 main 直推与云端结果包验收制度

日期：2026-07-03

核心变更：

- 将协作流程从本地 Agent C 提交验收升级为 `main` 直推、GitHub Actions 云端重验证和 Agent C 下载未加密结果包复判。
- 增加 Agent A/B/C 角色召唤、最终回复身份标识、main push 规则、失败时 main 追加修复 commit 规则。
- 新增 `ci-results` workflow 设计，要求产出 manifest、failure summary、JUnit/摘要、xcodebuild 日志、Swift/Gateway smoke 日志和 `.xcresult`。
- 说明本次是协作制度和验证骨架升级，不代表业务能力、产品质量或 Gateway 实现发生功能提升。

关键文件：

- `AGENTS.md`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `.github/workflows/ci-results.yml`

验证结果：

- 本地应运行 `git diff --check`。
- 本地应运行 `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`。
- 当前本地仓库未配置 `origin` 时，无法完成真实 `git push origin main`、GitHub Actions run 和 Agent C artifact 下载复判；配置远端后需补跑完整闭环。

遗留事项：

- 配置真实 `origin/main` 后，必须执行一次 main push 云端试跑，下载 `/private/tmp/claw-c-review-<run_id>/` 结果包，并核对 manifest 的 `commitSha`、`runId` 和 `runAttempt`。
