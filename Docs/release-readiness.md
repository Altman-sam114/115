# Claw 发布准备清单

评估日期：2026-09-27。目标：Mac/iPad 上可使用、可审计的电脑智能体控制台。当前仍为原型，**不是发布候选版本**。用户授权本次由一个 Agent X 连续迭代，不创建子 agent；规划、实现、云端 artifact 复判分别记录。

## 当前轮次

| 轮次 | 范围 | 验收门槛 |
| --- | --- | --- |
| v0.77 | 修复云端 async 测试编译与 readiness nonce 字符集不一致 | 最新 main 全部 required checks + 下载 artifact 复判 |
| v0.78 | Mac Catalyst 构建、iPad 方向、按窗口宽度自适应、工作台拆分 | Release Catalyst + iPhone/iPad XCTest + 全量 Gateway 回归 |

v0.79 聚焦普通任务和 Mission 的真实传输、任务身份绑定与重复发送防护；仅在前轮云端 artifact 通过后提交。本轮仍不代表发布候选。

## 发布门槛

1. **可重复构建**：共享 scheme，iOS Release/Catalyst Release 云端构建，最新 main 的 manifest/run/attempt 精确匹配；不存在被 continue-on-error 掩盖的失败。
2. **真实智能规划**：`PhoneAgentPlanner` 当前按关键词生成固定步骤，`ClawStore.defaultModel` 是 placeholder。必须接入经过用户配置的真实推理后端，具备超时、取消、schema 校验、提示注入隔离、费用/用量可见性和失败回退。没有模型服务或经过校验的本地 runtime，不能宣传已达到 OpenClaw 能力。
3. **真实参数与结果**：当前 bridge 中 browser HTML / writeText 存在示例占位内容。真实模式必须拒绝未填写的执行参数，用户审查的是最终结构化参数，结果必须区分模拟/dry-run/真实执行。
4. **桌面执行边界**：真正操作仍由桌面 Gateway 完成；Catalyst 客户端不能绕过 gateway allowlist、workspace、审批和最终提交确认。完整 Accessibility 输入/点击和浏览器控制器需要专项端到端验证。
5. **Mac/iPad 体验**：窗口缩放、iPad 分屏/横竖屏、大字体、键盘、VoiceOver、网络中断和恢复；重排不自动发任务、不丢失审批上下文。自动测试和截图不能替代真实授权桌面的人工交互验收。
6. **凭据与连接**：生产环境需要安全凭据存储、可撤销配对、TLS 与设备信任模型；readiness attestation 只报告能力，不能被当成配对或授权。
7. **分发**：确定最终 bundle identifier、版本、图标、隐私说明、签名证书/provisioning profile、Mac sandbox/公证和实际分发渠道。无签名云端 build 不等于可安装发布包。

## 停止条件

同因连续 CI 失败、三轮同一阻塞、两轮无有效 diff、账号/密钥/付费服务或人工作出产品决定才能继续、无法判断归属的工作区冲突，以及用户停止要求，均按 AGENTS 规则处理。不无限循环、不伪造发布完成、不通过无限增加复核面板代替可执行能力。

## 证据要求

每轮结果以最新 `origin/main` 的云端 artifact 为准。历史 run 只用于定位问题。最终报告必须给出 commit、run id、attempt、artifact 名称和实际运行的检查；未执行的真实设备、真实模型和分发检查应明确列出。
