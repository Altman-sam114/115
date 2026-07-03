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
- 当前核心闭环：用户自然语言任务 -> `PhoneAgentPlanner` -> `ClawMobileTask` -> `ClawMobileEnvelope` -> 模拟事件流或 WebSocket Gateway -> `ClawGatewayEvent` -> session reducer -> UI 展示和审批。
- 当前 Gateway 能力：屏幕观察 dry-run/截图策略、浏览器 HTML/URL trace、浏览器打开/搜索计划、workspace 文件写入、Shell dry-run/allowlist 执行、结构化提取、桌面 App 审批闸门、`runAgentLoop`/`agentTrace`。
- 当前协作闭环：默认 `main` 直推，GitHub Actions 生成未加密 `ci-results` 结果包，Agent C 下载并核对 manifest/JUnit/日志后验收。
- 当前主要遗留：完整 macOS Accessibility tree、Playwright/browser-use 兼容控制器、真实多轮 agent loop、live Gateway 心跳和重连、UI 级 artifact 复核体验。

## 历史记录

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
