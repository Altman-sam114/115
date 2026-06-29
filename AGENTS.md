# AGENTS.md

本文是 Claw 项目的入口记忆、基本规则和多 Agent 迭代工作流。

## 1. 一句话总览

Claw 是一个 SwiftUI iPhone 控制台原型：手机端生成可审批的电脑接管任务，桌面 Claw Gateway 负责观察屏幕、控制浏览器、操作桌面 App、管理文件、运行受控 Shell、提取数据并回传事件和 artifact。

## 2. 必读文件

每轮任务开始必须按顺序阅读：

1. `AGENTS.md`
2. `update_log.md`
3. `md/flow/flow.md`
4. `md/flow/flowchart.md`
5. `md/test/test.md`
6. 与任务相关的源码、测试、README、协议文档

## 3. 项目基本规则

- 项目方向是 OpenClaw 式电脑智能体，不做法律、法务、合同、诉讼等垂直产品。
- iOS 端只负责输入、计划、风险展示、审批、envelope 发送和事件查看。
- 真实电脑操作只发生在用户授权的桌面/自托管 Gateway。
- 不把自然语言直接交给 Shell、AppleScript 或桌面自动化；必须使用结构化 `toolArguments`。
- token 不写入 envelope，只保存短 SHA-256 指纹；运行时 token 走 header 或本地配置。
- 新增 action/artifact 必须同步模型、planner、bridge、simulator、fixture、Gateway、smoke 和文档。
- 不回滚用户或其他 Agent 的改动，不做无关重构。

## 4. 核心架构边界

- `Claw/Core/ClawModels.swift`：schema、状态对象、事件、artifact、模型 manifest。
- `Claw/Services/ClawStore.swift`：App 状态、规划器、envelope、Gateway simulator、live client、event reducer。
- `Claw/Services/ClawShortcuts.swift`：Shortcuts/App Intents 入口。
- `Claw/Views/ContentView.swift`：SwiftUI 展示和交互。
- `Tools/claw-gateway-server.mjs`：桌面 Gateway 原型和受控执行器。
- `Tools/*smoke.mjs`、`Tools/LogicSmoke.swift`、`ClawTests/ClawTests.swift`：测试和回归入口。
- `Docs/claw-mobile-gateway-protocol.md`、`md/flow/*`：协议和核心逻辑说明。

## 5. 标准迭代工作流

### 人工

人工提出目标、禁止项、验收标准、性能/UI/测试要求。人工把本文件、`update_log.md`、`md/flow/flow.md`、`md/test/test.md` 和相关上下文交给 Agent A。

### Agent A：目标分析与提示词

Agent A 默认不直接写代码。必须阅读入口文档和相关源码，明确目标、非目标、边界、风险、验收标准，设计实现方案，并把给 Agent B 的详细提示词写入 `md/prompt/vX（阶段）/vX.Y（任务）.md`。

Agent A 提示词必须包含：版本号、版本分配依据、背景、目标、非目标、当前架构依据、实现步骤、关键文件、测试要求、文档更新要求、验收标准、风险和禁止项。

### Agent B：实现与测试

Agent B 按 Agent A 提示词实现。必须小步修改、补测试、按 `md/test/test.md` 选择测试层级、运行并记录命令结果、更新必要文档。不得擅自扩大范围、删除旧实现、伪造测试通过或绕过核心规则。

### Agent C：验收与核心逻辑更新

Agent C 阅读 Agent B 输出和实际 diff，核对测试结果，判断是否满足人工目标和 Agent A 提示词。

- 不通过：输出问题清单、回退原因、需要 Agent B 修复的具体文件/行为/测试，不得提交版本。
- 通过：更新 `md/flow/flow.md`、`md/flow/flowchart.md`，重要事项写入 `update_log.md`，然后按本轮版本号自动创建 git commit。

Agent C 通过后的 git 提交规则：

- 版本号以 Agent A 提示词版本为准，例如 `v0.2`、`v1.0`；人工指定版本时使用人工版本号。
- 提交前必须确认 `git status --short` 中只包含本轮相关文件；如有无关改动，先说明并排除，不得混入提交。
- 提交信息必须简洁说明版本做了什么，格式：`vX.Y: 简要概括本轮工作`。
- 提交正文可选；如本轮涉及多模块，正文用 2-5 行概括核心变更、测试结果和遗留风险。
- 提交完成后，Agent C 输出版本工作汇报：版本号、commit hash、核心变更、关键文件、测试结果、未跑测试及原因、遗留事项。

## 6. 测试规则

- 每次实现前先读 `md/test/test.md`。
- 默认从最小测试开始，根据改动范围扩大。
- Gateway JS 改动至少跑 `node --check` 和对应 smoke。
- Swift 核心逻辑改动至少跑 `Tools/LogicSmoke.swift` 编译和执行；可用完整 Xcode 时再跑 `xcodebuild`。
- 文档-only 改动至少跑 `git diff --check`，可不跑业务测试，但必须说明原因。
- 不得用“已验证”替代具体命令和结果。

## 7. 文档规则

- 代码或协议变化后必须更新 `README.md`、`Docs/claw-mobile-gateway-protocol.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 中受影响内容。
- 正式版本、重要维护、关键决策和遗留问题写入 `update_log.md`。
- Agent A 的详细实现提示词只放入 `md/prompt/`，不要塞进 `AGENTS.md`。
- `AGENTS.md` 保持入口规则精简；历史写 `update_log.md`；当前逻辑写 `md/flow/flow.md`；测试写 `md/test/test.md`。

## 8. 交付格式

最终回复必须包含：

- 本轮版本号；Agent C 通过并提交时必须包含 commit hash。
- 改了什么。
- 关键文件。
- 运行的验证命令和结果。
- 未运行的测试及原因。
- 已知风险或下一步建议。

## 9. 禁止项

- 禁止把项目方向改成法律/法务产品。
- 禁止让 iOS 端声称能静默控制电脑或读取其他 App 私有数据。
- 禁止自然语言直连 Shell、AppleScript 或真实桌面动作。
- 禁止绕过 allowlist、审批闸门、workspace 限制和 artifact 审计。
- 禁止删除测试断言来让测试通过。
- 禁止只改代码不改相关文档。
- 禁止 Agent C 验收不通过时提交版本。
- 禁止把无关改动混入版本提交。
