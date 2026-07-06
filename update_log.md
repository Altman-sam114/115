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
- 当前核心闭环：用户自然语言任务 -> `PhoneAgentPlanner` -> `ClawMobileTask` -> `ClawMobileEnvelope` -> 模拟事件流或带有界重连/ping 可观测性和进程内 task replay guard 的 WebSocket Gateway -> `ClawGatewayEvent` -> session reducer -> Mission Run / 复核态势摘要 / 复核优先队列 / 复核聚焦详情 / Live Gateway 连接健康 / Artifact metadata 复核摘要 / 文件变更安全复核摘要 / Shell 命令安全复核摘要 / 提取完整性复核摘要 / 浏览器控制计划复核摘要 / 草稿最终提交安全复核摘要 / Gateway 能力复核摘要 / Accessibility 复核摘要 / Replay Guard 复核摘要 / AgentTrace 复核 UI / iPad 多栏工作台展示和审批。
- 当前 Gateway 能力：进程内 task replay guard、session-start 能力快照 `auditLog`、屏幕观察 dry-run/截图/窗口元数据/受控 Accessibility 摘要策略、浏览器 HTML/URL trace、带 metadata-only 计划复核的浏览器打开/搜索计划、workspace 文件写入与 metadata-only 文件变更安全复核、Shell dry-run/allowlist 执行与 metadata-only Shell 命令安全复核、带 metadata-only 完整性复核的结构化提取、带 metadata-only 草稿/最终提交安全复核的 messageDraft/桌面 App 审批闸门、带 readiness/checklist/risk/stop/handoff 与安全 metadata 的 `runAgentLoop`/`agentTrace`。
- 当前协作闭环：默认 `main` 直推，GitHub Actions 生成未加密 `ci-results` 结果包，Agent C 下载并核对 manifest/JUnit/日志后验收。
- 当前主要遗留：完整 macOS Accessibility bridge、Playwright/browser-use 兼容控制器、真实多轮 agent loop、live Gateway 后台保活/真实心跳协议/配对、完整 artifact 内容复核体验。

## 历史记录

### v0.26 / Mission Run 复核态势摘要

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunReviewReadinessSummary`，`ClawMissionRunSummary` 通过 computed helper 从完整复核优先队列、可用 detail review kind 和聚焦状态派生人工复核态势摘要。
- 摘要覆盖总优先项、可行动项、critical/high 项、metadata 待同步项、可用详细复核数、最高优先项、当前聚焦项和聚焦项是否有 detail row。
- Mission Run 在 artifact chips 后、复核优先队列前展示短态势摘要，并提供“聚焦最高优先项”按钮复用 v0.25 聚焦机制；compact iPhone 和 iPad regular 工作台复用同一面板。
- 摘要只使用固定文案、计数、枚举和已脱敏队列项字段，不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`。
- XCTest 和 Swift logic smoke 覆盖 idle、正常任务、聚焦状态、Shell 高优先/可行动计数、count 一致性和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway 权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.26（MissionRun复核态势摘要）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `node --check Tools/claw-gateway-server.mjs`、`node --check Tools/claw-gateway-direct-smoke.mjs`、`node --check Tools/claw-gateway-smoke.mjs` 通过。
- GitHub Actions run `28768979862` attempt `1` 对 commit `cf894226dedadeaada8121ca6fe19e85f2cdc5a6` 通过，artifact `claw-ci-v0.2-main-cf894226deda-run28768979862-attempt1` 已下载到 `/private/tmp/claw-c-review-28768979862/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前复核态势摘要是手机端 presentation-layer 汇总，不是自动安全裁决、自动执行 readiness、恶意检测或完整 payload viewer。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.25 / Mission Run 复核聚焦模式

日期：2026-07-06

核心变更：

- Mission Run 复核优先队列项升级为可点击按钮，用户可聚焦单个 `reviewKind` 并筛选对应详细复核 row，点击“全部”恢复全量详情。
- `ClawMissionRunSummary` 增加 detail focus helper，覆盖当前可用详细 review kind、聚焦后可见 kind、单行显示判断和聚焦队列项解析；聚焦状态只存在于 SwiftUI presentation layer。
- `approval`、`gateway-status` 或未知/过期聚焦项没有对应详细复核 row 时，UI 显示固定提示并保持全量详情，避免把其他风险清空。
- 队列行使用 SwiftUI `Button`、系统图标、选中描边和 VoiceOver label；compact iPhone 与 iPad regular 工作台复用同一 Mission Run 面板。
- XCTest 和 Swift logic smoke 覆盖无聚焦、有效聚焦、状态类/未知聚焦回退、Shell 聚焦和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway 权限，不读取 Gateway `file://` payload。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.25（MissionRun复核聚焦模式）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `node --check Tools/claw-gateway-server.mjs`、`node --check Tools/claw-gateway-direct-smoke.mjs`、`node --check Tools/claw-gateway-smoke.mjs` 通过。
- GitHub Actions run `28767970421` attempt `1` 对 commit `16ee75e04342b0994083d497c35cae5a30ecd97c` 通过，artifact `claw-ci-v0.2-main-16ee75e04342-run28767970421-attempt1` 已下载到 `/private/tmp/claw-c-review-28767970421/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke、node/plutil/git diff check 和 xcodebuild 日志。
- v0.25 验证记录提交后，GitHub Actions run `28768134701` attempt `1` 对最新 commit `ce4f61533768cfd141754c07e0ee46450c3eb81e` 通过，artifact `claw-ci-v0.2-main-ce4f61533768-run28768134701-attempt1` 已下载到 `/private/tmp/claw-c-review-28768134701/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前聚焦模式是手机端 presentation-layer 筛选，不是自动安全裁决、深链导航、完整 payload viewer 或跨 session 审计状态。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.24 / Mission Run 复核优先队列

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunReviewPriorityItem` 和 severity 模型，`ClawMissionRunSummary` 从既有 task/session/review summary 派生稳定排序的复核优先队列。
- 队列按审批/阻断、Replay Guard、草稿最终提交、Shell、文件变更、浏览器、提取完整性、Accessibility、Gateway 能力、Artifact metadata 和 AgentTrace 的固定 rank/review kind 输出，优先展示需要人工处理、metadata 缺失或高风险执行面的复核项。
- Mission Run 首屏在 artifact chips 后、详细 review rows 前展示前 5 个优先项；iPhone compact 和 iPad regular 多栏工作台自动复用同一面板。
- Gateway session card 和 result row 保留既有详细 review rows；排序逻辑留在 presentation 派生层，不放到 SwiftUI view 重算。
- 队列只使用固定文案、数字、枚举状态和已脱敏 summary 字段，不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`。
- XCTest 和 Swift logic smoke 覆盖 idle 空队列、排序稳定、高风险项、Shell policy 阻断优先级和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway 权限。

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
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.24（MissionRun复核优先队列）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`。
- GitHub Actions run `28766837880` attempt `1` 对 commit `7d805ac34775711bb679c772611ebecdd6128d58` 通过，artifact `claw-ci-v0.2-main-7d805ac34775-run28766837880-attempt1` 已下载到 `/private/tmp/claw-c-review-28766837880/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke 和 xcodebuild 日志。

遗留事项：

- 当前优先队列是手机端 presentation-layer 排序，不是自动安全裁决、恶意检测、完整审计或自动修复器。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.23 / Shell 命令安全复核

日期：2026-07-05

核心变更：

- Gateway `runShellCommand` 的既有 `commandOutput` artifact event 增加 metadata-only 的 Shell Command Safety 摘要，覆盖结构化命令 presence、parse 状态、Shell policy、allowlist match、execution attempted/executed、timeout、exit code presence/zero、stdout/stderr presence、command/stdout/stderr/cwd omission flags 和 result status。
- 缺少结构化 `shellCommand`、解析失败、dry-run/allowlist policy 阻断和 allowlist 真执行路径均输出同类安全 metadata；metadata 只表达固定状态、布尔值、presence 和 safety flags，不把 raw command、binary/args、cwd/path、stdout/stderr 内容、自然语言 instruction 或 `toolArguments` 放入 metadata。
- 新增 `ClawGatewayShellCommandSafetyReviewSummary`，手机端只从 artifact event metadata 或 legacy `commandOutput` artifact 派生 Shell 命令安全复核摘要，不读取 Gateway `file://` payload。
- Mission Run、Gateway session card 和单个 result row 展示 Shell Command Safety 复核行；metadata 缺失时降级为“metadata 待同步”，不假定命令安全、已阻断或已执行。
- Gateway simulator、`Tools/ClawGatewayEventFixture.swift`、direct smoke 和 WebSocket smoke 同步输出/断言同类安全 metadata，覆盖 dry-run policy 阻断、allowlist 真执行和缺少结构化命令阻断。
- XCTest 和 Swift logic smoke 覆盖 Mission Run 派生、legacy metadata fallback、fixture 派生和恶意 metadata 脱敏。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不扩大 Gateway Shell 权限。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Tools/ClawGatewayEventFixture.swift`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.23（Shell命令安全复核）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (219 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (72 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- GitHub Actions run `28741888192` attempt `1` 对 commit `eb90f5bdbc327da864c7a5a3fe60852c5334b269` 通过，artifact `claw-ci-v0.2-main-eb90f5bdbc32-run28741888192-attempt1` 已下载到 `/private/tmp/claw-c-review-28741888192/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke 和 xcodebuild 日志。

遗留事项：

- 当前是 metadata-only Shell 命令安全复核，不是完整命令模板系统、交互式 shell、审批三阶段 UI、命令沙箱或恶意命令检测。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.22 / 文件变更安全复核

日期：2026-07-05

核心变更：

- Gateway `manageFiles` 的既有 `fileDiff` artifact event 增加 metadata-only 的 File Change Safety 摘要，覆盖 workspace policy、写入尝试/成功、路径逃逸阻断、created/modified/deleted count、path/content/diff omission flags 和 result status。
- 路径逃逸和写入失败路径会写入脱敏 `auditLog` artifact event，metadata 只表达固定状态、计数和 safety flags，不把 raw path、workspace path、文件内容、diff、patch 或 `toolArguments` 放入 metadata；Gateway workspace/session 写入补充 lstat/realpath symlink component 检查和 no-follow file open。
- 新增 `ClawGatewayFileChangeSafetyReviewSummary`，手机端只从 artifact event metadata 或 legacy `fileDiff` artifact 派生文件变更安全复核摘要，不读取 Gateway `file://` payload。
- Mission Run、Gateway session card 和单个 result row 展示 File Change Safety 复核行；metadata 缺失时降级为“metadata 待同步”，不假定写入安全。
- Gateway simulator、`Tools/ClawGatewayEventFixture.swift`、direct smoke 和 WebSocket smoke 同步输出/断言同类安全 metadata，覆盖普通 workspace 写入、路径逃逸阻断、写入失败审计和 workspace symlink 阻断。
- XCTest 和 Swift logic smoke 覆盖 Mission Run 派生、legacy metadata fallback、fixture 派生和恶意 metadata 脱敏。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Tools/ClawGatewayEventFixture.swift`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.22（文件变更安全复核）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (213 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (72 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- GitHub Actions run `28736316020` attempt `1` 对 commit `d78e7728b563fb90a402c382265fed00035b2bf7` 通过，artifact `claw-ci-v0.2-main-d78e7728b563-run28736316020-attempt1` 已下载到 `/private/tmp/claw-c-review-28736316020/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke 和 xcodebuild 日志。

遗留事项：

- 当前是 metadata-only 文件变更安全复核，不是完整 diff viewer，也不读取或展示 artifact payload。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.21 / 浏览器控制计划复核

日期：2026-07-05

核心变更：

- Gateway `controlBrowser` 的 `browserTrace` 和 `browser-control-*.json` artifact event 增加 metadata-only 的 Browser Control 摘要，覆盖是否请求打开浏览器、URL/search 是否仅以 presence 记录、HTML 输入、network fetch/blocked、app/host allowlist、执行状态和安全 omission flags。
- 新增 `ClawGatewayBrowserControlReviewSummary`，手机端只从 artifact event metadata 或 legacy browser artifact 派生浏览器控制计划复核摘要，不读取 Gateway `file://` payload。
- Mission Run、Gateway session card 和单个 result row 展示 Browser Control 复核行；metadata 缺失时降级为“metadata 待同步”，不把抽取或 dry-run 误判为真实浏览器点击。
- Gateway simulator 和 `Tools/ClawGatewayEventFixture.swift` 同步输出同类安全 metadata，保持模拟、fixture、direct smoke 和 WebSocket smoke 一致。
- Gateway direct/WebSocket smoke 断言 Browser Control metadata 固定键、策略字段和 omission flags，并确认 metadata 不泄露 raw URL、search query、HTML/page text、form/candidate label、stdout/stderr、token 或 `toolArguments`。
- Gateway `--emit-events` 在退出前等待 stdout flush，避免 metadata 增多后 direct smoke 偶发截断事件流。
- XCTest 和 Swift logic smoke 覆盖 Mission Run 派生、legacy metadata fallback、浏览器策略字段和恶意 metadata 脱敏。
- 同步 README、协议、flow/flowchart 和测试说明；本轮不新增 schema/event/action/artifact kind，不实现真实浏览器点击/表单控制，不扩大 Gateway 权限。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Tools/ClawGatewayEventFixture.swift`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.21（浏览器控制计划复核）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (198 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (51 events)`。
- 待完成 `git diff --check`、workflow YAML 语法检查、push `origin/main` 和 GitHub Actions artifact 复判。

遗留事项：

- 当前是 metadata-only 浏览器控制计划复核，不是网页正文 viewer、真实点击/表单执行或 Playwright/browser-use 控制器。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.20 / 草稿最终提交安全复核

日期：2026-07-05

核心变更：

- Gateway `messageDraft` 和 `operateDesktopApp` 相关 artifact event 增加 metadata-only 的 Delivery Safety 摘要，覆盖 final-submit gate、用户确认、草稿正文/paste text 省略和提交键阻断计数。
- 新增 `ClawGatewayDeliverySafetyReviewSummary`，手机端只从 artifact event metadata 派生草稿/最终提交安全复核摘要，不读取 Gateway `file://` payload。
- Mission Run、Gateway session card 和单个 result row 展示 Delivery Safety 复核行；metadata 缺失时降级为“metadata 待同步”，不做假阳性安全判断。
- Gateway direct/WebSocket smoke 断言 `messageDraft` 和桌面 App dry-run metadata 存在，并确认 metadata 不泄露草稿正文、paste text、按键原文、URL/path、token 或 `toolArguments`。
- XCTest 和 Swift logic smoke 覆盖 Mission Run 派生、legacy metadata fallback、桌面提交键阻断计数和恶意 metadata 脱敏。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不实现真实发送/提交，不扩大 Gateway 权限。

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
- `md/prompt/v0（核心智能能力）/v0.20（草稿最终提交安全复核）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (186 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (51 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 待 push `origin/main` 后由 GitHub Actions 覆盖 xcodebuild、Swift logic smoke、Gateway direct/WebSocket smoke 和结果包验收。

遗留事项：

- 当前是 metadata-only 草稿/最终提交安全复核，不是完整草稿正文 viewer，也不读取或展示 artifact payload。
- 真实消息发送、最终提交、完整 macOS Accessibility bridge、浏览器真实点击和完整 artifact 内容复核体验仍是后续遗留。

### v0.19 / 提取完整性复核

日期：2026-07-05

核心变更：

- Gateway `extractData` 输出 artifact event 增加安全 metadata，覆盖提取模式、完整性校验、row count、来源 artifact 计数、source kinds 和 safety flags。
- 新增 `ClawGatewayExtractionCompletenessReviewSummary`，手机端只从 `extractData` artifact metadata 派生完整性复核摘要，不读取 Gateway `file://` payload。
- Mission Run、Gateway session card 和单个 result row 展示提取完整性复核行，帮助用户在草稿或最终提交前判断结构化结果是否有足够 artifact 依据。
- Gateway direct/WebSocket smoke 断言 metadata 与提取 payload 的计数一致，并确认 metadata 不泄露 row 内容、URL/path、命令输出、网页正文、token 或 `toolArguments`。
- XCTest 和 Swift logic smoke 覆盖 Mission Run 派生、metadata fallback 和恶意 metadata 脱敏。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。

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
- `md/prompt/v0（核心智能能力）/v0.19（提取完整性复核）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (179 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (44 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 待 push `origin/main` 后由 GitHub Actions 覆盖 xcodebuild、Swift logic smoke、Gateway direct/WebSocket smoke 和结果包验收。

遗留事项：

- 当前是 metadata-only 提取完整性复核，不是完整 extraction artifact viewer，也不读取或展示 row payload。
- 完整 artifact payload 复核体验、浏览器控制计划复核、草稿/最终提交安全复核、真实多轮 agent loop 和 Playwright/browser-use 兼容控制器仍是后续遗留。

### v0.18 / 手机端 Metadata 复核脱敏加固

日期：2026-07-05

核心变更：

- 新增集中 `ClawArtifactMetadataDisplaySanitizer`，统一专用 metadata review 的安全显示路径。
- AgentTrace、Gateway capability、Accessibility、Replay Guard 和通用 Artifact metadata review 的 UI 可见字段统一脱敏 raw token、Authorization/header、Bearer、`toolArguments`、`file://` 和 workspace path。
- XCTest 增加恶意 AgentTrace / Gateway capability metadata 脱敏覆盖；Swift logic smoke 增加专用复核摘要敏感值不外显断言。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不修改 Gateway JS，不扩大 Gateway 权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.18（手机端Metadata复核脱敏加固）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 本轮未修改 `Tools/*.mjs`，本地未跑 Gateway JS smoke；push `origin/main` 后由 GitHub Actions 覆盖 Gateway direct/WebSocket smoke、Swift logic smoke 和 xcodebuild，并由 Agent C 下载结果包复判。

遗留事项：

- Artifact 的严格时间顺序仍沿用当前 `sessionArtifacts + results.artifacts` 派生方式；如需修正跨 action/session-level artifact 的“latest”语义，应在后续版本引入带序号或时间戳的 presentation 聚合。
- 浏览器控制计划复核、提取完整性复核和草稿/最终提交安全复核仍是后续高价值增量。

### v0.17 / 手机端 Artifact metadata 详情复核

日期：2026-07-05

核心变更：

- 新增 `ClawGatewayArtifactMetadataReviewSummary`，手机端只从 Gateway artifact event metadata、kind/title 和脱敏标记派生通用 metadata 复核摘要，不读取 Gateway `file://` payload。
- `ClawMissionRunSummary` 增加 artifact metadata review，Mission Run、Gateway session card 和单个 result row 展示 artifact 总数、metadata 覆盖率、脱敏数、最近带 metadata artifact、安全键值和 safety flags。
- 通用 metadata review 会脱敏 raw token、Authorization/header、`toolArguments`、payload/body/content、workspace path、`file://`、命令输出、网页正文、截图内容和草稿正文等敏感字段。
- XCTest 和 Swift logic smoke 覆盖 metadata 存在、metadata 缺失 fallback、敏感字段脱敏和 Mission Run 派生。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不修改 Gateway JS，不扩大 Gateway 权限。

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
- `md/prompt/v0（核心智能能力）/v0.17（手机端ArtifactMetadata详情复核）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 无签名 generic iOS build 通过，输出 `BUILD SUCCEEDED`；本机 CoreSimulator 服务不可用，仅产生 simulator 发现日志，不影响 generic iOS build。
- 本轮未修改 `Tools/*.mjs`，本地未跑 Gateway JS smoke；push `origin/main` 后由 GitHub Actions 覆盖 Gateway direct/WebSocket smoke、Swift logic smoke 和 xcodebuild，并由 Agent C 下载结果包复判。

遗留事项：

- 当前是手机端 metadata-only 复核，不是完整 artifact JSON viewer，也不读取 Gateway `file://` payload。
- 完整 artifact payload 复核体验、真实多轮 agent loop、Playwright/browser-use 兼容控制器和完整 Accessibility bridge 仍是后续遗留。

### v0.16 / 手机端 Accessibility artifact 复核摘要

日期：2026-07-05

核心变更：

- 新增 `ClawGatewayAccessibilityReviewSummary`，手机端只从 `accessibilityTree` artifact event metadata 派生观察复核摘要，不读取 Gateway `file://` payload。
- `ClawMissionRunSummary` 增加 Accessibility review，Mission Run、Gateway session card 和单个 result row 展示 mode、policy、节点数、候选控件数、platform、redaction、safety flags 和脱敏状态。
- Gateway simulator 的 `accessibilityTree` artifact 附带 v0.15 同款安全 metadata，XCTest 和 Swift logic smoke 覆盖 metadata 解析、legacy fallback、Mission Run 派生和敏感字段不展示。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不修改 Gateway JS，不扩大 Gateway 权限。

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
- `md/prompt/v0（核心智能能力）/v0.16（手机端AccessibilityArtifact复核摘要）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 本轮未修改 `Tools/*.mjs`，本地未跑 Gateway JS smoke；push `origin/main` 后由 GitHub Actions 覆盖 Gateway direct/WebSocket smoke、Swift logic smoke 和 xcodebuild，并由 Agent C 下载结果包复判。

遗留事项：

- 当前是手机端 metadata-only 复核，不是完整 artifact JSON viewer，也不读取 Gateway `file://` payload。
- 完整 Accessibility bridge、控件级动作、敏感区域打码和真实浏览器点击仍是后续遗留。

### v0.15 / macOS Accessibility 观察摘要

日期：2026-07-05

核心变更：

- Gateway 新增显式 `CLAW_ALLOW_ACCESSIBILITY_OBSERVE=1` 开关；默认仍为 dry-run/window metadata，不做真实 Accessibility 读取。
- `observeScreen` 继续复用既有 `accessibilityTree` artifact；授权 macOS Gateway 上只用固定只读 System Events 脚本采集前台 App/窗口和有限候选控件摘要，无权限或非 macOS 时返回可审计 failed/unavailable artifact。
- `gateway-capability-snapshot.json` capability 和 metadata 增加 `accessibilityTreeState`，同时标记 Accessibility 文本为 summary-only、值和密码字段省略、动作执行不支持。
- 手机端 `ClawGatewayCapabilityReviewSummary` 解析 `accessibilityTreeState`，Mission Run / Gateway 能力行展示 `ax <state>` chip；模拟事件流、XCTest 和 Swift logic smoke 覆盖该 metadata。
- direct/WebSocket smoke 覆盖默认 dry-run 状态、metadata allowlist，以及显式 env 开启但 CI 无 macOS 权限时仍能生成合法审计 artifact。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不执行点击/输入，不让 iOS 声称能读取其他 App 私有数据。

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
- `md/prompt/v0（核心智能能力）/v0.15（macOSAccessibility观察摘要）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (173 events)`。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (44 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。

遗留事项：

- 当前是只读观察摘要，不是完整 Accessibility bridge；尚未实现控件级点击、输入、表单提交、视觉定位或默认敏感区域打码。
- macOS Accessibility 权限缺失、非 macOS 或 CI 无 GUI 时会返回 failed/unavailable 审计结果，这是预期安全降级。
- 本地未跑无签名 iOS xcodebuild；本轮按测试规范使用轻量检查，push `origin/main` 后由 GitHub Actions 覆盖 xcodebuild、Swift logic smoke、Gateway direct/WebSocket smoke 和结果包验收。

### v0.14 / 手机端 Replay Guard 复核摘要

日期：2026-07-05

核心变更：

- 新增 `ClawGatewayTaskReplayGuardReviewSummary`，手机端只从 `task-replay-guard.json` `auditLog` artifact metadata 派生 replay guard 复核摘要，不读取 Gateway `file://` payload。
- `ClawMissionRunSummary` 增加 replay guard review，blocked 状态遇到 replay guard session 时优先说明重复任务已被 Gateway Replay Guard 跳过、未重新执行桌面 handler。
- Mission Run 面板和 Gateway session card 新增 Replay Guard row，展示 replay 次数、跳过动作数、digest match、首次状态、短 task/session/digest、action kind 和 safety flags；metadata 缺失时降级为待同步。
- XCTest 和 Swift logic smoke 覆盖 replay guard metadata 解析、legacy fallback、session-level artifact 合并、Mission Run 派生和敏感字段不展示。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不修改 Gateway JS，不扩大 Gateway 权限。

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
- `md/prompt/v0（核心智能能力）/v0.14（手机端ReplayGuard复核摘要）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 无签名 iOS build 通过，输出 `BUILD SUCCEEDED`；本机 CoreSimulator 服务不可用，仅影响 simulator 发现日志，不影响 generic iOS build。

遗留事项：

- 本轮不改变 Gateway JS；本地未跑 Gateway direct/WebSocket smoke，push `origin/main` 后由 GitHub Actions 覆盖。
- 仍需本轮 push 后等待 GitHub Actions `ci-results` 结果包，供 Agent C 下载并核对 manifest、JUnit/摘要、Swift logic smoke、Gateway direct/WebSocket smoke 和 xcodebuild 日志后复判。

### v0.13 / Gateway task replay guard

日期：2026-07-04

核心变更：

- `Tools/claw-gateway-server.mjs` 新增进程内 task replay cache；首次接受 `task.id` 前登记安全记录，重复提交同一任务时进入 replay guard，不再调用 action handler。
- replay guard 复用既有 `auditLog` artifact、`artifactStored` event、`actionSkipped` event 和 `sessionCompleted` event；重复任务会写 session-level `task-replay-guard.json`，逐个 action 返回 skipped。
- replay audit payload/metadata 只记录 task id、短 digest、首次 session id、原始状态、replay count、action count/kinds 和安全标志，不包含 raw token、Authorization header、自然语言 instruction、`toolArguments`、业务 artifact payload 或完整 workspace path。
- `--emit-events` 支持 JSON array 输入，用于同一 Gateway 进程内连续处理重复 envelope；单 envelope 输入保持兼容。
- direct smoke 覆盖同一 `--emit-events` 进程内重复 envelope；WebSocket smoke 保留原 `--once` 正常路径，并新增非 `--once` server 上两次连接的 replay guard 验证。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 权限，不做跨重启持久化 exactly-once。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.13（GatewayTaskReplayGuard）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (146 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (44 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。

遗留事项：

- replay guard 只覆盖同一 Gateway 进程生命周期；进程重启、多 Gateway 进程、cache 淘汰或分布式执行仍可能重复处理同一 `task.id`。
- 本轮未修改 Swift 代码，本地未跑 Swift logic smoke 或 iOS build；push `origin/main` 后由 GitHub Actions 覆盖 Swift logic smoke、Gateway direct/WebSocket smoke 和 xcodebuild，并由 Agent C 下载结果包复判。

### v0.12 / Live Gateway 有界重连与心跳可观测性

日期：2026-07-04

核心变更：

- `URLSessionClawGatewayTransport` 新增 `ClawGatewayTransportRetryPolicy`，默认最多重试 1 次；每次 WebSocket 发送 envelope 后执行一次 ping 观测。
- transport 复用现有 `.gatewayConnected` 进度事件携带 `attempt`、`reconnect`、`ping` 和脱敏 `transportError`，不新增 event/action/artifact kind，不改变 `claw.computer.control.v1`。
- 重连只在尚未收到桌面 Gateway 业务事件前进行；收到桌面事件后的错误仍走现有 fallback/复核路径，避免重复发送 envelope 扩大执行风险。
- `ClawGatewayLiveHealthSummary` 新增 attempt、reconnect、ping、transport error 派生字段，并扩展敏感信息遮蔽；Gateway 会话 UI chip 展示尝试次数、重连次数、ping 状态和短错误摘要。
- XCTest 和 Swift logic smoke 覆盖 reconnect/ping summary 解析、重连后完成、ping failed 不中断、最终失败 fallback 和错误摘要脱敏。
- 同步 README、协议和 flow/flowchart；本轮不做后台保活、配对服务或桌面端真实心跳协议，不扩大 Gateway 权限。

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
- `md/prompt/v0（核心智能能力）/v0.12（LiveGateway有界重连与心跳可观测性）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 无签名 iOS build 通过，输出 `BUILD SUCCEEDED`。
- `xcodebuild build-for-testing` 通过，输出 `TEST BUILD SUCCEEDED`，确认 `ClawTests` 可编译；本机 CoreSimulator 服务不可用，未执行模拟器 XCTest。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- 本轮未修改 `Tools/*.mjs`，本地未跑 Gateway JS smoke；push `origin/main` 后由 GitHub Actions 覆盖 Gateway direct/WebSocket smoke。

遗留事项：

- 本轮是客户端有界重连和 ping 可观测性，不是 iOS 后台保活、桌面端真实心跳协议、配对服务或 server-side task idempotency。
- push `origin/main` 后仍需等待 GitHub Actions `ci-results` 结果包，供 Agent C 下载并核对 manifest、JUnit/摘要、Gateway direct/WebSocket smoke 日志、Swift logic smoke 和 xcodebuild 日志后复判。

### v0.11 / Live Gateway 连接健康摘要

日期：2026-07-04

核心变更：

- 新增 `ClawGatewayLiveHealthSummary`，手机端从 `ClawGatewayLiveRequest`、`ClawGatewayConnectionState`、最新 `ClawGatewaySession` 和 session 事件派生 Live Gateway 连接健康摘要。
- 摘要展示脱敏 endpoint、transport、request path、短 token 指纹、preflight、是否可尝试 live、事件数量、最新事件、fallback/error/completed、session status、重复 `gatewayConnected` 兼容提示和安全 detail line。
- 修正 live 状态语义：live 模式收到 `.gatewayConnected`、`.actionStarted`、`.artifactStored`、`.actionCompleted`、`.actionFailed`、`.approvalRequested`、`.actionSkipped` 等非终态事件后保持 `streaming`，不再降回 `awaitingGateway`；`.sessionCompleted`、`.fallbackUsed` 和 transport error 仍走既有终态/fallback 路径。
- Gateway 会话面板在 Live request 附近展示连接健康行，iPad regular 工作台通过复用同一 panel 自动覆盖；UI 不显示 raw token、Authorization header、完整 headers、完整 workspace path、`toolArguments` 或 artifact payload。
- XCTest 和 Swift logic smoke 覆盖 idle/request/preflight、endpoint 脱敏、缺 token fallback、live progress streaming、completed mock transport、transport error fallback 和敏感内容不泄露。
- 同步 README、协议、flow 和 flowchart；本轮不新增 schema/action/event/artifact kind，不做自动重连/心跳，不扩大 Gateway 权限。

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
- `md/prompt/v0（核心智能能力）/v0.11（LiveGateway连接健康摘要）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 无签名 iOS build 通过，输出 `BUILD SUCCEEDED`。
- `xcodebuild build-for-testing` 通过，输出 `TEST BUILD SUCCEEDED`，确认 `ClawTests` 可编译；本机 CoreSimulator 服务不可用，未执行模拟器 XCTest。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- 本轮未修改 `Tools/*.mjs`，本地未跑 Gateway JS smoke；push `origin/main` 后由 GitHub Actions 覆盖 Gateway direct/WebSocket smoke。

遗留事项：

- push `origin/main` 后仍需等待 GitHub Actions `ci-results` 结果包，供 Agent C 下载并核对 manifest、JUnit/摘要、Gateway direct/WebSocket smoke 日志、Swift logic smoke 和 xcodebuild 日志后复判。
- 当前是 Live Gateway 连接健康摘要，不是自动重连、心跳协议、配对流程或完整 artifact 内容 viewer；这些仍待后续轮次推进。

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
