# iOS Claw Controller 边界与落地方案

调研/设计日期：2026-06-10

## 结论

iOS App 不能像桌面自动化工具那样直接读取电脑屏幕、点击桌面应用、运行本机 Shell 或长期常驻接管系统。正确架构是把 iPhone 做成 Claw 控制台，把高权限动作交给用户自托管的桌面 Claw Gateway。

手机端负责：

1. 接收自然语言任务。
2. 生成可审查的电脑接管计划。
3. 展示风险、审批点和 token 指纹。
4. 发送 `claw.computer.control.v1` envelope。
5. 展示网关返回的截图、日志、文件变更和失败原因。

桌面网关负责：

1. 观察屏幕、窗口标题和可访问性树。
2. 控制浏览器和桌面 App。
3. 在授权目录内读写文件。
4. 在命令白名单内运行 Shell。
5. 回传每个 action 的结果和审计摘要。

## 通道

### App Intents / Shortcuts

适合把“生成 Claw 执行计划”和“生成 Claw 电脑任务 payload”暴露给 Siri、Shortcuts、Spotlight 和系统建议。

限制：App Intents 只暴露本 App 能力，不会让 App 获得控制其他 App 或桌面系统的通用权限。

### Share Sheet

适合把任务结果草稿、文件摘要或附件交给 Mail、Files、Notes、IM 等目标 App。系统会展示 `UIActivityViewController`，用户选择目标并确认。

限制：不能静默发送；目标 App 接收后的内部行为不可由本 App 完全控制。

### URL Scheme / Universal Link

适合打开移动端公开入口，例如任务结果链接、内部系统网页、IM 草稿链接。目标 App 必须公开 URL scheme 或 Universal Links。

限制：只能打开入口，不能保证目标 App 内部完成了点击、提交或发送。

### Claw Gateway

核心通道。App 将结构化电脑任务发给用户自托管的桌面网关，网关再执行浏览器、桌面 App、文件、Shell 和屏幕观察动作。

限制：需要用户部署、认证、审计和最小权限策略。不要把网关裸露到公网；token 不写入 payload，只写短 SHA-256 指纹。

## 安全策略

- 屏幕观察、浏览器控制、桌面 App 操作、文件写入和 Shell 命令默认高风险。
- Shell 必须限制工作目录、命令白名单、超时和输出大小。
- 文件操作必须限制授权目录，并回传变更清单。
- 外发消息、提交表单、上传文件和运行破坏性命令必须二次确认。
- 网关需要记录 action 输入、截图/日志引用、输出、失败原因和可回滚信息。

## 当前代码入口

- `Claw/Services/ClawStore.swift`
  - `PhoneAgentPlanner`
  - `ClawMobileBridge`
  - `defaultAutomationTargets`
  - `defaultPhoneAgentCapabilities`
- `Claw/Services/ClawShortcuts.swift`
  - Claw 执行计划 Intent
  - Claw 电脑 payload Intent
- `Claw/Views/ContentView.swift`
  - 电脑接管 Tab
  - Claw 电脑网关面板
- `Docs/claw-mobile-gateway-protocol.md`
  - `claw.computer.control.v1` envelope 和 action schema
