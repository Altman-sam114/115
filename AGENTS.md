# AGENTS.md

本文是 Claw 项目的入口记忆、基本规则、main 直推云端验证规则和多 Agent 迭代工作流。

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

### 角色召唤

- 用户消息以 `agenta`、`a:` 或 `A:` 开头，表示召唤 Agent A。
- 用户消息以 `agentb`、`b:` 或 `B:` 开头，表示召唤 Agent B。
- 用户消息以 `agentc`、`c:` 或 `C:` 开头，表示召唤 Agent C。
- 没有这些前缀时，按普通 Codex 任务处理；如果任务需要 A/B/C 边界，先提醒用户指定角色，或明确本轮按普通任务执行。
- Agent A 最终回复第一行必须写：`我是 Agent A。`
- Agent B 最终回复第一行必须写：`我是 Agent B。`
- Agent C 最终回复第一行必须写：`我是 Agent C。`

### 人工

人工提出目标、禁止项、验收标准、性能/UI/测试要求。人工把本文件、`update_log.md`、`md/flow/flow.md`、`md/test/test.md` 和相关上下文交给 Agent A。

### Agent A：目标分析与提示词

Agent A 默认不直接写代码。必须阅读入口文档和相关源码，明确目标、非目标、边界、风险、验收标准，设计实现方案，并把给 Agent B 的详细提示词写入 `md/prompt/vX（阶段）/vX.Y（任务）.md`。

Agent A 提示词必须包含：版本号、版本分配依据、背景、目标、非目标、当前架构依据、实现步骤、关键文件、测试要求、云端 CI/main push/artifact 要求、文档更新要求、验收标准、风险和禁止项。

### Agent B：实现与测试

Agent B 按 Agent A 提示词实现。必须先同步最新 `origin/main`，确认当前分支是 `main` 且工作区无无关改动；小步修改、补测试、按 `md/test/test.md` 选择本地轻量检查，更新必要文档。完成后提交本轮相关文件并直接 push 到 `origin/main`，触发 GitHub Actions 云端重验证。不得擅自扩大范围、删除旧实现、伪造测试通过或绕过核心规则。

### Agent C：验收与核心逻辑更新

Agent C 阅读 Agent B 输出、实际 diff、`origin/main` 最新 commit 和 GitHub Actions 结果包，核对测试结果，判断是否满足人工目标和 Agent A 提示词。Agent C 不能只验收 Agent B 的文字说明；必须用 `gh auth login` 后下载未加密 CI 结果包，核对 manifest、JUnit/摘要、主日志和关键结果文件。

- 不通过：输出问题清单、回退原因、需要 Agent B 在 `main` 追加修复 commit 的具体文件/行为/测试，不得把失败 run 判为通过。
- 通过：确认 `origin/main` 最新 commit 对应的 workflow run 通过，确认结果包 manifest 与最新 commit/run 完全一致；如需补齐核心文档，必须作为本轮相关 main 追加 commit 并重新触发云端验证。

### main 直推和云端验证规则

- 本项目默认固定使用 `main` 作为唯一上传、提交、推送和云端验证分支。
- 暂不设计 `smalldata_test`、`develop`、`codeb/...` 或其他长期/候选分支；已有其他分支只记录现状，不纳入默认流程。
- 任何 Agent 在 `git push origin main` 或改变远端 `main` 前，都必须确认当前分支是 `main`、目标远端是 `origin/main`，且提交范围只包含本轮相关文件。
- 默认不创建 PR、不等待 PR merge；本阶段采用 main 直推触发 GitHub Actions 的闭环。
- 云端失败时，默认退回 Agent B 在 `main` 上追加修复 commit 后继续 push，不做回滚式处理，除非人工明确要求。
- CI 结果包必须未加密，至少包含 `ci-artifact-manifest.json`、`ci-failure-summary.md`、主构建日志、JUnit 或等价摘要、项目关键结果文件。
- Agent C 下载缓存默认放在 `/private/tmp/claw-c-review-<run_id>/`，人工确认后再清理。
- 提交信息必须简洁说明版本做了什么，格式：`vX.Y: 简要概括本轮工作`；版本号以 Agent A 提示词或人工指定为准。

## 6. 测试规则

- 每次实现前先读 `md/test/test.md`。
- 默认本地只跑轻量检查，然后 commit/push 到 `origin/main` 由 GitHub Actions 做重验证。
- 只有人工明确要求“本机测试”“本地 build”“本地 xcodebuild”等，才默认在本机跑完整构建或模拟器验证。
- Gateway JS 改动本地至少跑 `node --check`；云端结果包必须覆盖对应 smoke。
- Swift 核心逻辑改动本地优先跑 Swift logic smoke；云端结果包必须覆盖 build、logic smoke 或等价检查。
- 文档-only 改动至少跑 `git diff --check` 和 workflow/YAML 语法检查，可不跑业务测试，但必须说明原因。
- 不得用“已验证”替代具体命令和结果。

## 7. 文档规则

- 代码或协议变化后必须更新 `README.md`、`Docs/claw-mobile-gateway-protocol.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 中受影响内容。
- 正式版本、重要维护、关键决策和遗留问题写入 `update_log.md`。
- Agent A 的详细实现提示词只放入 `md/prompt/`，不要塞进 `AGENTS.md`。
- `AGENTS.md` 保持入口规则精简；历史写 `update_log.md`；当前逻辑写 `md/flow/flow.md`；测试写 `md/test/test.md`。
- 协作流程和云端验证制度变化必须同步 `README.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md` 和 `md/prompt/README.md`。

## 8. 交付格式

最终回复必须包含：

- 本轮版本号；已提交时必须包含 commit hash。
- 改了什么。
- 关键文件。
- 运行的验证命令和结果。
- 当前分支、commit SHA、run id、run attempt、artifact 名称；如未能 push 或下载 artifact，写明阻塞原因。
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
- 禁止把旧 artifact、旧 output 或 checkout 自带报告冒充本轮云端结果。
- 禁止没有权限下载 artifact 时伪装已核对；必须先完成 `gh auth login` 或说明权限阻塞。
