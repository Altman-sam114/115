# Claw 发布准备清单

评估日期：2026-10-22。目标：Mac/iPad 上可使用、可审计的电脑智能体控制台。当前仍为原型，**不是发布候选版本**。用户本轮明确要求不开子 Agent；Agent X 单实例串行保留 A 规划 -> B 实现 -> C 云端 artifact 复判 -> X 判断各阶段，不冒充独立 Agent 验收。

## 当前轮次

最新通过基线为 v0.85 `edab5a9a6feb6598e9122122fe549951f02c1d6b` / run `39841407261` attempt `1`，artifact `claw-ci-v0.85-main-edab5a9a6feb-run39841407261-attempt1` 已完成单实例 C 复判：manifest/JUnit/摘要/实际日志一致，15 项成功、iPhone/iPad 各 150 项 XCTest 零失败、双平台 Release、LogicSmoke/fixture/Gateway 和生产 Swift HTTP client + 21 个有界 provider fixture 请求通过。四个 xcresult Info/root 数据存在；两张实际非白屏 PNG 已打开，对应 iPhone 第 1 帧/iPad 第 2 帧 readiness。压缩 1,973,076 bytes / 解压 4.7 MiB，本机无 xcresulttool，未独立解码二进制，Catalyst runner Metal 路径警告保留。历史首次失败及修复见 update_log，不冒充该失败已通过。

v0.86 补发布必需的单条 Keychain endpoint/token 原子存储、只恢复连接不恢复任务、显式保存/重读/还原/清除、dirty 全入口零调用、旧授权失效与统一安全 origin/header/无 redirect transport。新增 15 项测试，预期双设备各 165 项；默认 fake/no-op 不访问真实用户 Keychain，实际 Keychain 测试仅随机 namespace。新 main 云端 artifact 尚待产生，不把旧基线当作本轮通过。

v0.86 首次 run `39849006621` / SHA `c0698041a0e08b745359b4d9d9c23d3baa099371` 的精确 artifact 已复判退回：双设备各 165 项、14 个断言失败，涉及无签名测试宿主的 Keychain -34018、Live request 先 trim 丢失 CR/LF，以及改回连接后旧续接 receipt 可重新审批。仅选择性下载必要证据（591,139 bytes / 664 KiB），没有验收完整 xcresult 或截图。追加云端临时 simulator ad-hoc 测试 entitlement、原地址先验证和编辑即撤销 receipt；保留原断言，等待新 main 完整重验。临时签名不是生产分发签名，也不是 Keychain 实机锁屏验收。

v0.85 的真实模型请求接口已通过协议与安全合同，但 cloud provider 仍是小型 stub，不下载模型权重，不证明真实模型质量、证据/视觉多轮智能或实际桌面 E2E。v0.86 的本机 secret 存储不等于配对、可撤销设备信任或真实 Mac/iPad 交互验收。

| 轮次 | 范围 | 验收门槛 |
| --- | --- | --- |
| v0.83 | 按需工作台、未应用输入跨重排保留 | 已通过最新 SHA 的完整 artifact 与实际看图；真实交互仍缺 |
| v0.84 | 最终参数、普通审批绑定、Gateway 执行源 | 修复后 14 项检查与双设备各 136 项全通过、实际看图 |
| v0.85 | 自托管模型请求、typed 计划与审批主路径 | 已通过 15 项/各 150 项测试与实际看图，不等于模型质量验收 |
| v0.86 | 安全连接保存与草稿隔离 | Keychain/dirty/授权负向矩阵 + 完整云端 artifact 待验收 |

## 发布门槛

1. **可重复构建**：共享 scheme，iOS Release/Catalyst Release 云端构建，最新 main 的 manifest/run/attempt 精确匹配；不存在被 continue-on-error 掩盖的失败。
2. **真实智能规划**：`PhoneAgentPlanner` 规则路径与本机 Core ML placeholder 保留；v0.85 增加用户配置的 Gateway Ollama 真实请求路径，协议合同已通过，仍须后续真实模型质量验收。还需视觉/证据输入、多轮模型工具规划、真实基准与实际操作证据，不能把 stub 或接通接口宣传成已达到 OpenClaw 能力。用量只展示服务实际计数，费用未知，不自动收费重试或 fallback。
3. **真实参数与结果**：v0.84 的 typed 参数与普通审批已通过云端，v0.85 模型派生参数仍走同一 gate。所有旧 Gateway handler 的统一参数校验和实际结果复核仍需继续推进；模拟、dry-run、Live 事件与真实成功不能混淆。
4. **桌面执行边界**：真正操作仍由桌面 Gateway 完成；Catalyst 客户端不能绕过 gateway allowlist、workspace、审批和最终提交确认。完整 Accessibility 输入/点击和浏览器控制器需要专项端到端验证。
5. **Mac/iPad 体验**：窗口缩放、iPad 分屏/横竖屏、大字体、键盘、VoiceOver、网络中断和恢复；重排不自动发任务、不丢失审批上下文。自动测试和截图不能替代真实授权桌面的人工交互验收。
6. **凭据与连接**：v0.86 新增设备独占 Keychain 凭据存储与安全 origin/草稿隔离，仍须新云端验收和实际锁屏/签名访问验证；可撤销配对、TLS 部署与设备信任模型仍缺；readiness attestation 只报告能力，不能被当成配对或授权。
7. **分发**：确定最终 bundle identifier、版本、图标、隐私说明、签名证书/provisioning profile、Mac sandbox/公证和实际分发渠道。无签名云端 build 不等于可安装发布包。

## 停止条件

同因连续 CI 失败、三轮同一阻塞、两轮无有效 diff、账号/密钥/付费服务或人工作出产品决定才能继续、无法判断归属的工作区冲突，以及用户停止要求，均按 AGENTS 规则处理。不无限循环、不伪造发布完成、不通过无限增加复核面板代替可执行能力。

## 证据要求

每轮结果以最新 `origin/main` 的云端 artifact 为准。历史 run 只用于定位问题。最终报告必须给出 commit、run id、attempt、artifact 名称和实际运行的检查；未执行的真实设备、真实模型和分发检查应明确列出。
