# Claw iOS Controller Prototype

这是一个 SwiftUI iPhone 原型 App，用手机作为 Claw 控制台：用户用自然语言描述电脑任务，App 生成可审批的执行计划和 JSON envelope，真正的浏览器、文件、Shell、桌面 App 操作交给用户自托管的 Claw Gateway 在电脑上执行。

当前版本不下载模型权重，模型保持占位状态。App 已完成 UI、数据流、本地 artifact 导入/扫描/校验、电脑接管规划器、Claw Gateway envelope、事件流 reducer、Mission Run 任务回合面板、WebSocket transport 边界、Shortcuts 入口和 smoke 测试。

后续 Codex/Agent 接力开发必须先读 `AGENTS.md`。项目已建立“人工目标 -> Agent A 设计提示词 -> Agent B 在 main 上实现并推送 -> GitHub Actions 云端验证 -> Agent C 下载结果包复判 -> 人工复核 -> 下一轮”的迭代工作流。核心记忆和规范分布在 `AGENTS.md`、`update_log.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md` 和 `md/prompt/`。

## 协作与云端验证

当前协作制度固定以 `main` 作为上传、提交、推送和云端验证分支。Agent B 默认在本地跑轻量检查后提交并 push 到 `origin/main`，由 `.github/workflows/ci-results.yml` 运行 Claw build、Swift logic smoke、Gateway smoke 和静态检查，并上传未加密 `ci-results` 结果包。Agent C 必须用 GitHub CLI 下载结果包，核对 manifest、JUnit/摘要、主日志和关键结果文件后再验收。

角色召唤约定：`agenta`/`a:`/`A:` 召唤 Agent A，`agentb`/`b:`/`B:` 召唤 Agent B，`agentc`/`c:`/`C:` 召唤 Agent C。没有角色前缀时按普通 Codex 任务处理。

## 内容

- `AGENTS.md`：项目入口记忆、基本规则、Agent A/B/C 工作流和交付要求。
- `update_log.md`：版本更新记录、关键决策、完成事项和遗留问题。
- `md/prompt/`：Agent A 每轮写给 Agent B 的版本化实现提示词。
- `md/test/test.md`：测试规范、测试分层、命令、触发条件和当前基线。
- `md/flow/flow.md`：项目当前核心逻辑、数据流、执行流和架构边界。
- `md/flow/flowchart.md`：核心逻辑和 Agent 迭代流程的 Mermaid 图。
- `.github/workflows/ci-results.yml`：main push 和手动触发的云端重验证 workflow，会上传 Agent C 可下载复判的未加密结果包。
- `Claw.xcodeproj`：可用 Xcode 打开的 iOS 工程，target 名暂未重命名。
- `Claw/Core/ClawModels.swift`：Agent 能力、模型 manifest、artifact 校验、自动化通道、Claw action schema 和聊天数据模型。
- `Claw/Services/ClawStore.swift`：App 状态、能力库、策略上下文、电脑接管规划器、Claw envelope、live gateway 请求和事件流。
- `Claw/Services/ClawShortcuts.swift`：App Intents / Shortcuts 动作，包括 Claw 执行计划、电脑接管规划和 Claw 电脑任务 payload。
- `Claw/Views/ContentView.swift`：五个底部 Tab：连接、聊天、电脑接管、能力、榜单。
- `Docs/claw-mobile-gateway-protocol.md`：当前 Claw computer-control envelope、动作 schema、审批和任务状态协议草案。
- `Tools/claw-gateway-server.mjs`：本地桌面 Gateway 原型，通过 WebSocket 接收 envelope 并推送事件。
- `Tools/claw-gateway-smoke.mjs`：启动一次性 Gateway 并验证 WebSocket 事件闭环。
- `Tools/ClawGatewayEventFixture.swift`：读取 envelope 并输出 `ClawGatewayEvent` JSON Lines 的协议 fixture。
- `ClawTests/ClawTests.swift`：核心数据和业务流测试。

## 方向

这个原型朝 OpenClaw 式电脑智能体迭代：

- 手机端：输入任务、生成计划、用 Mission Run 面板展示当前阶段/下一步/风险/证据、审批高风险动作、查看 envelope 和审计摘要。
- 桌面网关：观察屏幕、控制浏览器、操作桌面 App、管理文件、运行受控 Shell、提取数据，并把事件、artifact 和审批请求推回手机端。
- 安全策略：token 只保留短 SHA-256 指纹；动作走白名单；敏感动作提升审批；Shell/文件/桌面接管默认需要网关确认。
- 边界：iOS 普通 App 不能静默控制电脑或读取其他 App 私有数据，电脑接管必须发生在用户授权的桌面/自托管网关。

## 本地模型

manifest 已预留：

- 模型文件：`claw-local-agent-q4.mlmodelc`
- tokenizer：`claw-tokenizer.model`
- 存储目录：`Application Support/ClawLocalModels`
- 默认不下载网络权重。
- 没有登记官方 SHA-256 时，只能进入 staged 状态，不启用真实 runtime。

## Claw Gateway

App 内置通道：

- App Intents：把 Claw 计划生成能力交给 Shortcuts。
- Share Sheet：把任务结果草稿交给 Mail/IM，由用户确认。
- URL Scheme / Universal Link：打开移动端可公开访问的目标入口。
- Claw Gateway：把 `claw.computer.control.v1` envelope 发给桌面端，执行浏览器、文件、Shell、桌面 App 和屏幕观察动作。

Gateway 发送模式：

- `模拟事件流`：本地回放 Gateway 事件，展示 action 结果、artifact、审批点和 retry。
- `Live Gateway`：准备 WebSocket 请求并发送 envelope，桌面端按 `ClawGatewayEvent` 推流；未配置 endpoint/token 时会安全回退到模拟事件流。

当前桌面 Gateway 原型已有受控工具边界：会校验 token、schema、动作白名单，把 artifact 写入 workspace，并回传事件/file URL 引用。`controlBrowser` 可从本地 HTML 或受 allowlist 约束的 URL 生成浏览轨迹、链接、标题、表格、表单和候选控件；默认只写入浏览器打开/搜索计划，设置 `CLAW_ALLOW_BROWSER_CONTROL=1`、`CLAW_BROWSER_APP_ALLOWLIST` 和 `CLAW_BROWSER_HOST_ALLOWLIST` 后，可在 macOS 上打开允许的桌面浏览器并跳转到结构化 URL/搜索结果。`extractData` 会消费前序 browser/file/shell/screen artifact 生成结构化结果。`manageFiles` 可按 `toolArguments.writePath/writeText` 在 workspace 内真实写文件，路径逃逸会被阻断。Shell 只接受结构化 `toolArguments.shellCommand`，默认 dry-run；必须同时设置 `CLAW_ALLOW_SHELL=1` 和 `CLAW_SHELL_ALLOWLIST` 才会真执行。屏幕观察默认 dry-run，设置 `CLAW_ALLOW_SCREEN_CAPTURE=1` 后可在 macOS 上生成真实截图 artifact。桌面 App 控制默认停在审批闸门，设置 `CLAW_ALLOW_DESKTOP_CONTROL=1`、`CLAW_DESKTOP_APP_ALLOWLIST` 和 `CLAW_DESKTOP_KEY_ALLOWLIST` 后，可在 macOS 上聚焦允许的 App、粘贴结构化草稿、执行允许的非提交快捷键，并在最终提交前回到用户确认。

本地启动 Gateway：

```sh
CLAW_GATEWAY_TOKEN=super-secret-token \
node Tools/claw-gateway-server.mjs
```

带 workspace 和 Shell 策略启动：

```sh
CLAW_GATEWAY_TOKEN=super-secret-token \
CLAW_WORKSPACE=.build/claw-gateway-workspace \
CLAW_ALLOW_SHELL=1 \
CLAW_SHELL_ALLOWLIST=pwd,ls \
CLAW_ALLOW_BROWSER_CONTROL=1 \
CLAW_BROWSER_APP_ALLOWLIST=Safari \
CLAW_BROWSER_HOST_ALLOWLIST=www.google.com,example.com \
CLAW_ALLOW_DESKTOP_CONTROL=1 \
CLAW_DESKTOP_APP_ALLOWLIST=Slack,Notes \
CLAW_DESKTOP_KEY_ALLOWLIST=command+k,command+f,tab \
node Tools/claw-gateway-server.mjs
```

iOS App 中配置：

- Gateway URL：`ws://127.0.0.1:18789`（模拟器）或电脑局域网 IP（真机）
- Gateway Token：同一个 `super-secret-token`
- 发送模式：`Live Gateway`

Gateway smoke：

```sh
node Tools/claw-gateway-direct-smoke.mjs
node Tools/claw-gateway-smoke.mjs
```

`direct-smoke` 不监听端口，用 `--emit-events` 直接验证同一套 Gateway handler、workspace artifact、browser trace 到结构化提取链路、workspace 文件真实写入、Shell dry-run 阻断、allowlist Shell 真执行、浏览器打开/搜索计划与 allowlist 阻断，以及桌面 App 控制的审批闸门和 allowlist 阻断；`claw-gateway-smoke` 会实际启动 WebSocket server。

## 运行

打开 `Claw.xcodeproj`，选择 `Claw` scheme，在 iPhone 模拟器或真机运行。

命令行构建可使用完整 Xcode 路径：

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild \
  -project Claw.xcodeproj \
  -scheme Claw \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

逻辑 smoke：

```sh
/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc \
  -swift-version 6 \
  -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk \
  -target arm64-apple-macosx26.0 \
  -module-cache-path .build/SwiftModuleCache \
  Claw/Core/ClawModels.swift Claw/Services/ClawStore.swift Tools/LogicSmoke.swift \
  -o .build/claw-logic-smoke

.build/claw-logic-smoke
```

## 完成情况

- 2026-07-03：新增 v0.2 任务回合化体验。电脑接管页首屏增加 Mission Run 面板，把现有计划、审批、自治循环、Gateway session、artifact 和 retry 状态整理成目标、阶段、主动作、风险、证据和结果摘要；本轮不改变 `claw.computer.control.v1` schema，也不扩展 Gateway 权限。
- 2026-07-03：升级协作制度为 main 直推、GitHub Actions 云端重验证和 Agent C 下载未加密结果包复判；新增 `ci-results` workflow。验证：本轮至少需运行 `git diff --check` 和 workflow YAML 语法检查；真实云端试跑依赖仓库配置 `origin`。
- 2026-06-28：建立多 Agent 协作系统和项目记忆目录，统一入口为 `AGENTS.md`，新增 `update_log.md`、`md/prompt/README.md`、`md/prompt/v0（项目初始化）/v0.1（建立多Agent迭代文档）.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`。验证：文档-only 改动，按 `md/test/test.md` 运行静态检查；未运行 Gateway/Swift smoke。
- 2026-06-27：新增项目级开发规范草案，固化后续 Codex 开发规范、测试矩阵、README/协议文档更新要求和项目方向约束。后续已迁移为标准入口 `AGENTS.md`。
