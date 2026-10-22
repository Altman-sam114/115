# Claw 发布准备清单

评估日期：2026-10-22。目标：Mac/iPad 上可使用、可审计的电脑智能体控制台。当前仍为原型，**不是发布候选版本**。用户本轮明确要求不开子 Agent；Agent X 单实例串行保留 A 规划 -> B 实现 -> C 云端 artifact 复判 -> X 判断各阶段，不冒充独立 Agent 验收。

## 当前轮次

当前已通过基线：`0a8d9c463651d3daf8436635388c9c36c69352aa` / run `39805029958` attempt `1`，`claw-ci-v0.82-main-0a8d9c463651-run39805029958-attempt1` 已下载复判：14 项零失败 JUnit、双设备各 118 项 XCTest、Release/Gateway/validator、四个 xcresult/两份 JSON/实际 PNG 一致。iPhone 第 1 帧、iPad 第 2 帧内容就绪，已看图确认非白屏（1,916,885 bytes / 解压 4.1 MiB）。以下 v0.82 首次失败记录为历史定位，不再是最新状态。

当前 v0.83 整理主路径与按需复核：保留单一主动作、审批风险/失败/续接，把重复 metadata 看板放入高级区，父级保留详情、展开和未应用输入并防止跨 scope 误用。规则规划和执行来源明确标注，wire/审批/receipt/权限不变。本轮代码与新增测试等待新 main run，不以基线通过代替本轮通过，也未完成真实模型、最终参数或发布门槛。

最后通过的基线为 `0b9746292f4b67afac09ea36d7df50eb3297d061` / run `38342562083` attempt `1`。v0.82 的 `07a6747fd7acd55779b7d15f35f06a64c19866ae` / run `39799453977` attempt `1` 已下载 `claw-ci-v0.82-main-07a6747fd7ac-run39799453977-attempt1` 复判不通过：manifest/JUnit/日志一致，Release 与 Gateway 检查通过，LogicSmoke/XCTest 因测试夹具接口不匹配未能编译，iPad 复用不完整 test host 安装失败（结果包解压 52 MiB）。本次只修正夹具和缺产物的云端早失败诊断，完整矩阵需新 main run 重验；不能把构建成功等同测试通过。

后续 `7583e9a1a7df7117a6068a8cc8e28c4eaa075275` / run `39801453526` attempt `1` 的未加密结果包已下载（1,148,078 bytes，解压 3.4 MiB）：13 项检查通过、iPhone/iPad 各 118 项 XCTest 零失败、Release/Gateway 回归通过。但 C 阶段实际打开截图发现 iPad 白屏，整体复判退回；不能把自动化全绿当成 UI 通过。现追加 CI policy v0.4 内容就绪闸门和有界真实帧采集，OCR 文本不外显；新 run 截图通过前不进入 v0.83。此轮不改变产品权限或假称已定位白屏根因。

v0.82 将真实 Gateway 与模拟结果彻底分开：同步 live 准备和 async live 发送在 preflight 失败时不调用 transport，显示“未发送，配置待修正”；throw、无有效终态 EOF 和取消只收口当前 session，保留真实部分结果/证据，结果未确认，不模拟执行、不自动重发，也不承诺撤销远端副作用。首个已接受的 task/session 终态不可被尾随错误、重复终态或迟帧改写。异步入口不临时修改用户模式；task/session 与配置/模式 revision 防止旧任务改写新 Mission。显式模拟与模拟 retry 独立保留。生产 WebSocket 在原始 wire 身份校验后绑定本次连接的远端 session，再映射到本地 session；错误 task、切换远端 session 或不匹配 offer 均不入库，收到任何桌面 payload 后不再自动重发。合法 continuation 保留远端 parentSessionID；重连诊断只用固定代码，不写 raw error。


| 轮次 | 范围 | 验收门槛 |
| --- | --- | --- |
| v0.77 | 修复云端 async 测试编译与 readiness nonce 字符集不一致 | 最新 main 全部 required checks + 下载 artifact 复判 |
| v0.78 | Mac Catalyst 构建、iPad 方向、按窗口宽度自适应、工作台拆分 | Release Catalyst + iPhone/iPad XCTest + 全量 Gateway 回归 |
| v0.82 | 普通 live 失败/模拟隔离、partial evidence、终态身份和异步 scope | 全量 12 项失败矩阵 + 原平台/Gateway checks + 最新 artifact C 复判 |
| v0.83 | 共享任务主路径、按需复核、未应用输入跨重排保留与 scope 防护 | 新 presentation/editor 回归 + 全量平台/Gateway/非白屏证据 + 最新 artifact C 复判 |

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
