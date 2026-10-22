# Claw 发布准备清单

评估日期：2026-10-22。目标：Mac/iPad 上可使用、可审计的电脑智能体控制台。当前仍为原型，**不是发布候选版本**。用户本轮明确要求不开子 Agent；Agent X 单实例串行保留 A 规划 -> B 实现 -> C 云端 artifact 复判 -> X 判断各阶段，不冒充独立 Agent 验收。

## 当前轮次

最新通过基线是 v0.84 `263d0213f076ccd4a9e1a3b933d891e552713e31` / run `39829293264` attempt `1`，artifact `claw-ci-v0.84-main-263d0213f076-run39829293264-attempt1` 已完成单实例 C 复判：精确 manifest/JUnit/主日志、14 项检查、双设备各 136 项 XCTest、双平台 Release、LogicSmoke/fixture/Gateway，四个 xcresult Info/root 数据文件完整，以及实际打开的非白屏 PNG/第 1 帧 readiness JSON 一致。压缩 1,912,515 bytes，解压 4.4 MiB。本机无 xcresulttool，未独立解码二进制对象；Catalyst runner Metal 路径警告仍在。历史失败见 update_log，不再作为当前状态。

v0.85 新增显式自托管模型规划：生产 Swift HTTP client -> authenticated Gateway -> 用户已配置同机 Ollama -> typed 计划 -> 既有最终参数/审批主路径；有界请求、取消、stale、schema/来源/用量与无执行副作用。云端使用小型 provider stub 检查真实 I/O，不下载权重。本轮待新 main 云端结果，真实模型质量、实际使用模型服务与真实桌面 E2E 尚未验收。

| 轮次 | 范围 | 验收门槛 |
| --- | --- | --- |
| v0.83 | 按需工作台、未应用输入跨重排保留 | 已通过最新 SHA 的完整 artifact 与实际看图；真实交互仍缺 |
| v0.84 | 最终参数、普通审批绑定、Gateway 执行源 | 修复后 14 项检查与双设备各 136 项全通过、实际看图 |
| v0.85 | 自托管模型请求、typed 计划与审批主路径 | 生产 HTTP client/stub/负向安全矩阵 + 全量云端 artifact；不等于模型质量验收 |

## 发布门槛

1. **可重复构建**：共享 scheme，iOS Release/Catalyst Release 云端构建，最新 main 的 manifest/run/attempt 精确匹配；不存在被 continue-on-error 掩盖的失败。
2. **真实智能规划**：`PhoneAgentPlanner` 规则路径与本机 Core ML placeholder 保留；v0.85 增加用户配置的 Gateway Ollama 真实请求路径，仍须本轮云端合同与后续真实模型质量验收。还需视觉/证据输入、多轮模型工具规划、真实基准与实际操作证据，不能把 stub 或接通接口宣传成已达到 OpenClaw 能力。用量只展示服务实际计数，费用未知，不自动收费重试或 fallback。
3. **真实参数与结果**：v0.84 的 typed 参数与普通审批已通过云端，v0.85 模型派生参数仍走同一 gate。所有旧 Gateway handler 的统一参数校验和实际结果复核仍需继续推进；模拟、dry-run、Live 事件与真实成功不能混淆。
4. **桌面执行边界**：真正操作仍由桌面 Gateway 完成；Catalyst 客户端不能绕过 gateway allowlist、workspace、审批和最终提交确认。完整 Accessibility 输入/点击和浏览器控制器需要专项端到端验证。
5. **Mac/iPad 体验**：窗口缩放、iPad 分屏/横竖屏、大字体、键盘、VoiceOver、网络中断和恢复；重排不自动发任务、不丢失审批上下文。自动测试和截图不能替代真实授权桌面的人工交互验收。
6. **凭据与连接**：生产环境需要安全凭据存储、可撤销配对、TLS 与设备信任模型；readiness attestation 只报告能力，不能被当成配对或授权。
7. **分发**：确定最终 bundle identifier、版本、图标、隐私说明、签名证书/provisioning profile、Mac sandbox/公证和实际分发渠道。无签名云端 build 不等于可安装发布包。

## 停止条件

同因连续 CI 失败、三轮同一阻塞、两轮无有效 diff、账号/密钥/付费服务或人工作出产品决定才能继续、无法判断归属的工作区冲突，以及用户停止要求，均按 AGENTS 规则处理。不无限循环、不伪造发布完成、不通过无限增加复核面板代替可执行能力。

## 证据要求

每轮结果以最新 `origin/main` 的云端 artifact 为准。历史 run 只用于定位问题。最终报告必须给出 commit、run id、attempt、artifact 名称和实际运行的检查；未执行的真实设备、真实模型和分发检查应明确列出。
