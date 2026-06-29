# 项目版本更新记录

本文记录 Claw 的正式版本、重要维护事项、关键决策和遗留问题；不是流水账。

## 维护规则

- 每完成一个正式版本或重要任务后追加记录。
- 记录必须包含：版本/任务名、日期、核心变更、关键文件、验证结果、遗留事项。
- 文档整理、目录迁移、回滚、打捞等不伪装成新版本，可写入“历史维护记录”。
- 若核心逻辑、测试规范或项目行为变化，必须同步更新本日志。
- Agent C 验收通过后，必须按 Agent A 版本号自动创建 git commit；验收不通过时不得提交，必须退回 Agent B 修复。
- commit 信息格式为 `vX.Y: 简要概括本轮工作`，必要时用简短正文概括核心变更、测试结果和遗留风险。

## 当前状态

- 项目方向：OpenClaw 式电脑接管智能体，iPhone 作为控制台，桌面 Claw Gateway 作为执行端。
- 当前 schema：`claw.computer.control.v1`。
- 当前核心闭环：用户自然语言任务 -> `PhoneAgentPlanner` -> `ClawMobileTask` -> `ClawMobileEnvelope` -> 模拟事件流或 WebSocket Gateway -> `ClawGatewayEvent` -> session reducer -> UI 展示和审批。
- 当前 Gateway 能力：屏幕观察 dry-run/截图策略、浏览器 HTML/URL trace、浏览器打开/搜索计划、workspace 文件写入、Shell dry-run/allowlist 执行、结构化提取、桌面 App 审批闸门、`runAgentLoop`/`agentTrace`。
- 当前主要遗留：完整 macOS Accessibility tree、Playwright/browser-use 兼容控制器、真实多轮 agent loop、live Gateway 心跳和重连、UI 级 artifact 复核体验。

## 历史记录

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
