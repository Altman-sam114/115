# Claw 发布准备清单

评估日期：2026-10-22。目标：Mac/iPad 上可使用、可审计的电脑智能体控制台。当前仍为原型，**不是发布候选版本**。用户本轮明确要求不开子 Agent；Agent X 单实例串行保留 A 规划 -> B 实现 -> C 云端 artifact 复判 -> X 判断各阶段，不冒充独立 Agent 验收。

## 当前轮次

最新通过基线是 v0.83 `91886b1edc84e6921ffaa30edcc973de264ac79e` / run `39814219315` attempt `1`，artifact `claw-ci-v0.83-main-91886b1edc84-run39814219315-attempt1` 已完成单实例 C 复判：精确 manifest/JUnit/主日志、14 项检查、双设备各 125 项 XCTest、双平台 Release、LogicSmoke/fixture/Gateway、四个 xcresult，以及实际打开的非白屏 PNG/第 1 帧 readiness JSON 一致。压缩 1,882,069 bytes，解压 4.3 MiB。历史失败见 update_log，不再作为当前状态。

v0.84 从 UI 转向最终执行参数：移除危险默认正文/命令和伪 HTML、本机步骤假远端路由；新增 typed 编辑和普通审批摘要绑定，真实发送前缺参数/配置变更拒绝，Gateway 移除文件和桌面自然语言兜底。首次 SHA `c89277813852fb3be07ec0613ea8061acde948be` / run `39822763413` attempt `1` 失败，manifest/JUnit/日志确认 LogicSmoke、WebSocket smoke 和双设备 XCTest 未通过。同版本修复当前待办审批投影、probe 最终参数/远端 scope 夹具和完整桌面 smoke 夹具，新增六状态回归；新 main 云端验收前不进入 v0.85，不以历史绿灯或 step 图标替代结果包。

| 轮次 | 范围 | 验收门槛 |
| --- | --- | --- |
| v0.83 | 按需工作台、未应用输入跨重排保留 | 已通过最新 SHA 的完整 artifact 与实际看图；真实交互仍缺 |
| v0.84 | 最终参数、普通审批绑定、Gateway 执行源 | 新 typed/Store/fixture/direct/WebSocket 矩阵 + 全量平台/非白屏证据 + 最新 artifact C 复判 |

## 发布门槛

1. **可重复构建**：共享 scheme，iOS Release/Catalyst Release 云端构建，最新 main 的 manifest/run/attempt 精确匹配；不存在被 continue-on-error 掩盖的失败。
2. **真实智能规划**：`PhoneAgentPlanner` 当前按关键词生成固定步骤，`ClawStore.defaultModel` 是 placeholder。必须接入经过用户配置的真实推理后端，具备超时、取消、schema 校验、提示注入隔离、费用/用量可见性和失败回退。没有模型服务或经过校验的本地 runtime，不能宣传已达到 OpenClaw 能力。
3. **真实参数与结果**：v0.84 移除 bridge 示例 HTML/正文/命令并增加最终参数和普通审批闸门，仍需本轮云端结果包及真实交互验收。所有旧 Gateway handler 的统一参数校验和实际结果复核仍需继续推进；模拟、dry-run、Live 事件与真实成功不能混淆。
4. **桌面执行边界**：真正操作仍由桌面 Gateway 完成；Catalyst 客户端不能绕过 gateway allowlist、workspace、审批和最终提交确认。完整 Accessibility 输入/点击和浏览器控制器需要专项端到端验证。
5. **Mac/iPad 体验**：窗口缩放、iPad 分屏/横竖屏、大字体、键盘、VoiceOver、网络中断和恢复；重排不自动发任务、不丢失审批上下文。自动测试和截图不能替代真实授权桌面的人工交互验收。
6. **凭据与连接**：生产环境需要安全凭据存储、可撤销配对、TLS 与设备信任模型；readiness attestation 只报告能力，不能被当成配对或授权。
7. **分发**：确定最终 bundle identifier、版本、图标、隐私说明、签名证书/provisioning profile、Mac sandbox/公证和实际分发渠道。无签名云端 build 不等于可安装发布包。

## 停止条件

同因连续 CI 失败、三轮同一阻塞、两轮无有效 diff、账号/密钥/付费服务或人工作出产品决定才能继续、无法判断归属的工作区冲突，以及用户停止要求，均按 AGENTS 规则处理。不无限循环、不伪造发布完成、不通过无限增加复核面板代替可执行能力。

## 证据要求

每轮结果以最新 `origin/main` 的云端 artifact 为准。历史 run 只用于定位问题。最终报告必须给出 commit、run id、attempt、artifact 名称和实际运行的检查；未执行的真实设备、真实模型和分发检查应明确列出。
