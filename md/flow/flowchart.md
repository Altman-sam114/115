# 项目流程图

本文把 `md/flow/flow.md` 的核心逻辑画成可视化 Mermaid 图，方便人工快速复核。

## 1. Claw 核心逻辑图

读图说明：从左到右看。用户任务先进入 iPhone 控制台，经过规划、任务转换和 envelope 编码后，进入模拟事件流或桌面 Gateway。Gateway 产出事件和 artifact，手机端 reducer 把它们还原成 session，最后显示给用户审批或继续下一轮。

```mermaid
flowchart TD
  U["用户输入电脑任务<br/>人工给出目标、禁止项、验收标准"] --> S["ClawStore.phoneAgentCommand<br/>保存当前自然语言任务"]
  S --> P["PhoneAgentPlanner.makePlan<br/>拆成本地步骤、Gateway 步骤、阻断边界"]
  P --> T["PhoneAgentPlan.steps<br/>记录每一步目标、执行面、审批需求"]
  T --> B["ClawMobileBridge.makeTask<br/>生成 ClawMobileAction 和 toolArguments"]
  B --> A["ClawMobileTask.actions<br/>observe/control/extract/agentLoop/message 等动作"]
  A --> E["ClawMobileEnvelope<br/>schema、task、gateway profile、审批摘要"]
  E --> M{"发送模式<br/>simulatedEventStream 或 liveGateway"}
  M --> SIM["模拟事件流<br/>ClawGatewayEventStream.simulatedEvents"]
  M --> LIVE["WebSocket Live Gateway<br/>URLSessionClawGatewayTransport"]
  LIVE --> G["Tools/claw-gateway-server.mjs<br/>校验 token、schema、allowlist、workspace"]
  G --> H["Gateway action handlers<br/>屏幕、浏览器、文件、Shell、提取、桌面 App、agent loop"]
  H --> ART["Artifacts<br/>screenshot、browserTrace、fileDiff、commandOutput、agentTrace"]
  H --> EVT["ClawGatewayEvent<br/>actionStarted、artifactStored、completed、failed、approvalRequested"]
  SIM --> EVT
  EVT --> R["ClawGatewayEventStream.apply<br/>把事件 reduce 到 session"]
  ART --> R
  R --> SES["ClawGatewaySession<br/>results、artifacts、auditTrail、retryable"]
  SES --> UI["SwiftUI 面板<br/>展示计划、风险、事件、artifact、审批点"]
  UI --> LOOP{"用户审批或继续循环"}
  LOOP -->|"批准发送/重试"| M
  LOOP -->|"人工修改目标"| U
```

## 2. Gateway 执行与安全边界图

读图说明：这张图聚焦桌面 Gateway。所有动作先过策略检查，再进入具体 handler。任何真实控制都要经过 allowlist 和审批闸门；默认 dry-run 或写 artifact。

```mermaid
flowchart TD
  ENV["ClawMobileEnvelope<br/>来自 iOS 控制台"] --> VAL["validateEnvelope<br/>校验 schema、token 指纹、task actions"]
  VAL --> POL["actionPolicy<br/>检查 approval 和 allowedActionKinds"]
  POL -->|不允许| SKIP["actionSkipped<br/>写 auditLog 说明原因"]
  POL -->|允许| KIND{"action.kind"}
  KIND --> OBS["observeScreen<br/>dry-run 或 macOS 截图/窗口元数据"]
  KIND --> BRO["controlBrowser<br/>HTML/URL trace、浏览器打开/搜索计划"]
  KIND --> FILE["manageFiles<br/>workspace 内结构化写文件"]
  KIND --> SH["runShellCommand<br/>结构化命令 dry-run 或 allowlist 执行"]
  KIND --> EXT["extractData<br/>消费已有 artifact 生成结构化数据"]
  KIND --> APP["operateDesktopApp<br/>app/key allowlist、最终提交前停止"]
  KIND --> AG["runAgentLoop<br/>基于 session artifacts 生成下一步建议和安全闸门"]
  KIND --> MSG["composeMessage/composeEmail<br/>生成待确认草稿"]
  OBS --> CTX["sessionContext<br/>累计 screen、browser、file、shell、message、agent trace"]
  BRO --> CTX
  FILE --> CTX
  SH --> CTX
  EXT --> CTX
  APP --> CTX
  AG --> CTX
  MSG --> CTX
  CTX --> OUT["artifactStored + action result<br/>回传 file:// 引用、状态、retryable"]
```

## 3. Agent 迭代与云端验证流程图

读图说明：以后新功能不直接开写。人工先提出目标，Agent A 负责分析和写实现提示词，Agent B 在 `main` 上实现、轻量检查、提交并直推 `origin/main`，GitHub Actions 生成未加密结果包，Agent C 下载结果包复判；不通过就退回 Agent B 在 `main` 上追加修复 commit，最终通过后交回人工复核。

```mermaid
flowchart TD
  H["人工提出目标<br/>功能、禁止项、验收标准、测试要求"] --> A0["Agent A 阅读入口文档<br/>AGENTS、update_log、flow、flowchart、test"]
  A0 --> A1["Agent A 分析目标<br/>明确目标、非目标、风险、边界"]
  A1 --> PFILE["写入版本化提示词<br/>包含 CI、main push、artifact 要求"]
  PFILE --> B0["Agent B 同步 origin/main<br/>确认当前分支 main、无无关改动"]
  B0 --> B1["Agent B 小步实现<br/>代码、测试、必要文档"]
  B1 --> B2["Agent B 本地轻量检查<br/>git diff --check、语法检查、必要 smoke"]
  B2 --> B3["Agent B commit<br/>vX.Y: 简要概括本轮工作"]
  B3 --> PUSH["git push origin main<br/>触发 GitHub Actions"]
  PUSH --> CI["GitHub Actions ci-results<br/>build、smoke、静态检查"]
  CI --> ART["未加密 CI 结果包<br/>manifest、JUnit、日志、xcresult、报告"]
  ART --> C0["Agent C 下载结果包<br/>gh auth login + /private/tmp/claw-c-review-run"]
  C0 --> C2["核对 origin/main 最新 commit<br/>commitSha、runId、runAttempt、artifact 名称"]
  C2 --> C1{"验收结论"}
  C1 -->|不通过| FIX["问题清单<br/>要求 Agent B 在 main 追加修复 commit"]
  FIX --> B0
  C1 -->|通过且无需再改| REPORT["输出版本汇报<br/>版本、commit、run、artifact、测试、风险"]
  C1 -->|通过但需补文档| DOC["补齐核心文档<br/>仅本轮相关文件"]
  DOC --> B3
  REPORT --> HR["人工复核<br/>确认进入下一轮"]
  HR --> H
```
