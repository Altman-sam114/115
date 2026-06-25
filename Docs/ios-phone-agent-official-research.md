# iOS Claw Controller 能力边界调研

调研/设计日期：2026-06-10

## 目标

用户希望 Claw 像 OpenClaw 一样智能接管电脑：能观察屏幕、控制浏览器、操作桌面应用、运行脚本、整理文件、处理消息，并通过自然语言持续完成任务。

iOS 端的合理定位不是直接接管系统，而是控制台：

1. 接收文本或语音指令。
2. 生成电脑接管计划。
3. 让用户审批高风险动作。
4. 把结构化任务交给桌面 Claw Gateway。
5. 展示执行结果、截图/日志摘要和审计记录。

## 可实现能力

| 能力 | iOS 端 | 桌面网关 | 说明 |
| --- | --- | --- | --- |
| 本地任务规划 | 是 | 可选 | 手机端可生成 action plan 和 payload |
| 语音输入 | 是 | 否 | 使用 Speech / AVAudioSession，需要授权 |
| Shortcuts 入口 | 是 | 否 | 通过 App Intents 暴露计划和 payload 生成 |
| 联系人匹配 | 是 | 可选 | 需要 Contacts 授权 |
| 消息/邮件草稿 | 是 | 是 | 最终发送必须用户确认或由目标服务 API 支持 |
| 日历/提醒 | 是 | 可选 | EventKit 授权后可创建提醒 |
| 屏幕观察 | 否 | 是 | 需要桌面端屏幕录制/辅助功能授权 |
| 浏览器控制 | 否 | 是 | 由桌面网关打开、点击、提取、截图 |
| 桌面 App 操作 | 否 | 是 | 由桌面网关通过可访问性/视觉定位执行 |
| 文件读写 | 否 | 是 | 限定授权目录并记录变更 |
| Shell 命令 | 否 | 是 | 高风险，必须审批和白名单 |
| 长期常驻 | 受限 | 是 | iOS 后台受系统调度，网关适合长期运行 |

## 架构

```
User command
  -> iOS Claw Controller
  -> PhoneAgentPlanner
  -> ClawMobileBridge
  -> claw.computer.control.v1 envelope
  -> Desktop Claw Gateway
  -> Browser / Files / Shell / Desktop Apps
  -> Result + audit back to iOS
```

## 关键安全点

- iOS App 不获得桌面高权限。
- 网关 token 不进入 payload，只传短指纹。
- action 必须走 `allowedActionKinds` 白名单。
- Shell、文件写入、桌面提交、外发消息默认需要审批。
- 网关应提供截图、日志、文件 diff、命令输出和失败原因。

## 当前落地

- `Claw/Services/ClawStore.swift`
  - `PhoneAgentPlanner` 已识别浏览器、桌面 App、文件、Shell、消息、语音、提醒等任务。
  - `ClawMobileBridge` 生成 `claw.computer.control.v1` envelope。
- `Claw/Core/ClawModels.swift`
  - `ClawMobileActionKind` 包含 `observeScreen`、`controlBrowser`、`operateDesktopApp`、`manageFiles`、`runShellCommand`。
- `Claw/Views/ContentView.swift`
  - 电脑接管 Tab 展示计划、审批、任务队列和 payload。
- `Claw/Services/ClawShortcuts.swift`
  - Shortcuts 可生成 Claw 执行计划和电脑任务 payload。
