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

### Swift 核心逻辑改动

触发条件：

- 修改 `Claw/Core/ClawModels.swift`。
- 修改 `Claw/Services/ClawStore.swift`。
- 修改 planner、bridge、simulator、event reducer、autonomous loop。
- 修改 Mission Run presentation summary、Operator Strip、Loop 继续态势、Mac Agent Readiness Board 就绪看板、Mac Gateway Action Preflight Matrix 动作预检矩阵、Mac Agent Evidence Coverage Map 证据覆盖图、Mac Agent Next Step Deck 下一步候选卡组、Mac Agent Run Timeline 执行时间线、Mac Agent Continuation Gate 继续闸门、Focus Context 聚焦上下文、Review Detail Dock、Review Trail 复核路径、Approval Queue 审批队列、Payload Safety Ledger 载荷安全账本、Artifact 证据索引、复核优先队列、复核聚焦模式、复核态势摘要、下一步复核行动或 SwiftUI 展示派生模型。
- 修改 `Tools/LogicSmoke.swift`。

本地规则：

- 默认不运行 `swiftc`、`.build/claw-logic-smoke`、`xcodebuild build`、`xcodebuild build-for-testing` 或模拟器测试。
- 通过代码复核和非编译静态检查确认提交范围后，push 到 `origin/main`，由云端 workflow 覆盖 Swift logic smoke、iOS build、XCTest 编译或等价检查。

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
- Gateway direct smoke。
- Gateway WebSocket smoke。
- `xcodebuild build`。
- 结果包 manifest、failure summary、JUnit 或等价摘要、主日志和 `.xcresult`。

结果包最低内容：

- `ci-artifact-manifest.json`
- `ci-failure-summary.md`
- `junit.xml`
- `xcodebuild.log`
- `swift-logic-smoke.log`
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
- direct smoke 必须覆盖 artifact 落盘、workspace 文件写入、File Change Safety metadata、路径逃逸阻断审计、workspace 写入失败审计、workspace symlink 阻断、browser trace、Browser Control metadata、Shell Command Safety metadata、结构化提取、Shell dry-run/allowlist、缺少结构化 Shell 命令阻断、浏览器策略、桌面 App 审批闸门、`agentTrace` handoff status 和 mac 证据质量分层；dry-run screen/accessibility 必须进入 degradedSignals，不能进入 satisfiedSignals。
- WebSocket smoke 必须启动一次性 Gateway，验证事件闭环、browser/file/shell/extract/agent loop 主链路、AgentTrace satisfied/degraded/missing metadata 兼容、File Change Safety metadata、路径逃逸阻断审计、workspace 写入失败审计、Browser Control metadata、Shell Command Safety metadata 和 `sessionCompleted`。
- Swift logic smoke 必须覆盖 Mission Run Operator Strip 的空状态、lane 顺序、计数一致性、聚焦状态，Loop 继续态势的无 AgentTrace、metadata 缺失、final-submit-review、ready-to-continue、degraded/missing 计数和只聚焦 AgentTrace 行为，Mac Agent Readiness Board 就绪看板的 idle、固定五行顺序、ready/blocked/metadata/human count、capability/accessibility/agentTrace 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦和敏感字符串不外显，Mac Gateway Action Preflight Matrix 动作预检矩阵的 idle、action 顺序、ready/blocked/degraded/metadata/human count、发送前审批聚焦、发送后按 action kind 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦、可重试状态和敏感字符串不外显，Mac Agent Evidence Coverage Map 证据覆盖图的 idle、发送前 action/审批支撑、发送后 action/evidence/metadata/payload count、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦和敏感字符串不外显，Mac Agent Next Step Deck 下一步候选卡组的 idle、发送前审批候选、发送后人工确认/证据补齐/失败复核/Loop 下一步/抽查复核候选、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险可重试、AgentTrace 可继续和敏感字符串不外显，Mac Agent Run Timeline 执行时间线的 idle、发送前 action/审批时间线、发送后 action/evidence/handoff step、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险可重试、metadata 缺失回退和敏感字符串不外显，Mac Agent Continuation Gate 继续闸门的 idle、发送前审批、发送后人工/metadata/loop/抽查闸门、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险可重试、AgentTrace 可继续和敏感字符串不外显，Focus Context 聚焦上下文的 idle、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦和敏感字符串不外显，Review Detail Dock 的 idle、全量详情、detail 聚焦、状态级回退、过期回退、Shell 高风险聚焦和敏感字符串不外显，Review Trail 复核路径的 idle、四步顺序、证据/metadata/优先/下一步计数、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦和敏感字符串不外显，Approval Queue 审批队列的 idle、发送前审批、发送后 Gateway/Delivery/AgentTrace 确认、状态级聚焦、Shell 高风险聚焦、排序稳定和敏感字符串不外显，Payload Safety Ledger 载荷安全账本的 idle、payload-not-read/metadata-only/省略信号计数、detail 聚焦、状态级聚焦回退、过期聚焦回退、Shell 高风险聚焦和敏感字符串不外显，AgentTrace handoff status 的固定枚举、metadata 缺失回退和敏感字符串不外显，Artifact 证据索引的空状态、证据类型映射、metadata/redaction count、聚焦状态，复核优先队列的排序稳定、高风险复核项、复核聚焦过滤/回退、复核态势摘要 count 一致性、下一步复核行动和敏感字符串不外显；XCTest 也应覆盖同类 presentation-layer 派生。

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
