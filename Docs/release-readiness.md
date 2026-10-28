# Claw 发布准备清单

评估日期：2026-10-28。目标：Mac/iPad 上可使用、可审计的电脑智能体控制台。当前仍为原型，**不是发布候选版本**。用户本轮明确要求不开子 Agent；Agent X 单实例串行保留 A 规划 -> B 实现 -> C 云端 artifact 复判 -> X 判断各阶段，不冒充独立 Agent 验收。

## 当前轮次

v0.86 已通过：最新 main 基线 `0360175966eb99f32d9506a17e24ef57a1f3a0c5` / run `40166272414` attempt `1`，精确 artifact `claw-ci-v0.86-main-0360175966eb-run40166272414-attempt1` 完整下载（2,001,465 bytes / 4.9 MiB）。manifest/JUnit/主日志 15 项一致成功、双设备各 165 项与真实隔离 Keychain 通过；四份 xcresult 完整，静态解码 test summary 确认 0 failed/0 skipped。native signing JSON 全部正确、实际两张非白屏 PNG 与 attempt=1 JSON 一致，签名专项收口。Catalyst Metal runner 路径警告保留。早期失败/停止/恢复记录见 update_log，不将失败历史继续作为当前结论。

v0.87 增加实际 Gateway writer 的受控文本快照预览，不再只增加看板。显式读取、四类 allowlist、task/artifact/clean profile/revision 绑定、32 KiB/64 项/10 分钟、不读磁盘或任意 reference、原生 plain Text/清理与旧响应隔离；原 writer 省略内容不补回。云端预期 16 项、各 175 项测试，必须新 main 的完整 artifact 和实际看图后才能判通过；当前不预写成功。只读参考 aitrans，保留用户 DEVELOPMENT_TEAM/xcuserdata/旧 prompt。

| 轮次 | 范围 | 验收门槛 |
| --- | --- | --- |
| v0.83 | 按需工作台、未应用输入跨重排保留 | 已通过完整 artifact 与实际看图；真实交互仍缺 |
| v0.84 | 最终参数、普通审批绑定、Gateway 执行源 | 已通过 14 项与双设备各 136 项、实际看图 |
| v0.85 | 自托管模型请求与逐项参数审批 | 已通过 15 项/各 150 项，不等于真实模型质量 |
| v0.86 | 安全连接保存、草稿隔离、原生 CI 签名 | 已通过 15 项/各 165 项与实际图，不等于分发/实机锁屏 |
| v0.87 | 按需认证文本结果预览 | 待新 main 完整 16 项/各 175 项与 C 复判 |

## 发布门槛

1. **可重复构建**：共享 scheme，iOS Release/Catalyst Release 云端构建，最新 main 的 manifest/run/attempt 精确匹配；不存在被 continue-on-error 掩盖的失败。
2. **真实智能规划**：`PhoneAgentPlanner` 规则路径与本机 Core ML placeholder 保留；v0.85 增加用户配置的 Gateway Ollama 真实请求路径，协议合同已通过，仍须后续真实模型质量验收。还需视觉/证据输入、多轮模型工具规划、真实基准与实际操作证据，不能把 stub 或接通接口宣传成已达到 OpenClaw 能力。用量只展示服务实际计数，费用未知，不自动收费重试或 fallback。
3. **真实参数与结果**：v0.84 的 typed 参数与普通审批已通过云端，v0.85 模型派生参数仍走同一 gate。所有旧 Gateway handler 的统一参数校验和实际结果复核仍需继续推进；模拟、dry-run、Live 事件与真实成功不能混淆。
4. **桌面执行边界**：真正操作仍由桌面 Gateway 完成；Catalyst 客户端不能绕过 gateway allowlist、workspace、审批和最终提交确认。完整 Accessibility 输入/点击和浏览器控制器需要专项端到端验证。
5. **Mac/iPad 体验**：窗口缩放、iPad 分屏/横竖屏、大字体、键盘、VoiceOver、网络中断和恢复；重排不自动发任务、不丢失审批上下文。自动测试和截图不能替代真实授权桌面的人工交互验收。
6. **凭据与连接**：v0.86 设备独占 Keychain 凭据存储与安全 origin/草稿隔离已通过云端，仍须实际锁屏/生产签名访问验证；可撤销配对、TLS 部署与设备信任模型仍缺；readiness attestation 只报告能力，不能被当成配对或授权。
7. **分发**：确定最终 bundle identifier、版本、图标、隐私说明、签名证书/provisioning profile、Mac sandbox/公证和实际分发渠道。无签名云端 build 不等于可安装发布包。

## 停止条件

同因连续 CI 失败、三轮同一阻塞、两轮无有效 diff、账号/密钥/付费服务或人工作出产品决定才能继续、无法判断归属的工作区冲突，以及用户停止要求，均按 AGENTS 规则处理。不无限循环、不伪造发布完成、不通过无限增加复核面板代替可执行能力。

## 证据要求

每轮结果以最新 `origin/main` 的云端 artifact 为准。历史 run 只用于定位问题。最终报告必须给出 commit、run id、attempt、artifact 名称和实际运行的检查；未执行的真实设备、真实模型和分发检查应明确列出。
