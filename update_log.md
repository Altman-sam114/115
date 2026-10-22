# 项目版本更新记录

本文记录 Claw 的正式版本、重要维护事项、关键决策和遗留问题；不是流水账。

## 维护规则

- 每完成一个正式版本或重要任务后追加记录。
- 记录必须包含：版本/任务名、日期、核心变更、关键文件、验证结果、遗留事项。
- 文档整理、目录迁移、回滚、打捞等不伪装成新版本，可写入“历史维护记录”。
- 若核心逻辑、测试规范或项目行为变化，必须同步更新本日志。
- 当前默认由 Agent B 在 `main` 上提交并 push 到 `origin/main` 触发云端验证；Agent C 通过下载结果包复判，不通过时退回 Agent B 追加修复 commit。
- commit 信息格式为 `vX.Y: 简要概括本轮工作`，必要时用简短正文概括核心变更、测试结果和遗留风险。

## 当前状态

- 项目方向：OpenClaw 式电脑接管智能体，iPhone 作为控制台，桌面 Claw Gateway 作为执行端。
- 最后完整通过的基线：v0.85 `edab5a9a6feb6598e9122122fe549951f02c1d6b` / run `39841407261` attempt `1`，artifact `claw-ci-v0.85-main-edab5a9a6feb-run39841407261-attempt1` 已下载并由单实例 C 复判通过：15 项检查、双设备各 150 项 XCTest、Release/LogicSmoke/fixture/Gateway/生产 HTTP client 与 21 个模型 fixture 请求，四个 xcresult Info/root 数据完整，实际打开两张非白屏 PNG，与 iPhone 第 1 帧/iPad 第 2 帧 readiness JSON 一致（1,973,076 bytes / 解压 4.7 MiB）。本机无 xcresulttool，未独立解码二进制；Catalyst runner Metal 路径警告保留。v0.86 待新 main 云端验收，不以旧证据替代。
- 当前 schema：`claw.computer.control.v1`。
- 当前核心闭环：用户自然语言任务 -> `PhoneAgentPlanner` -> `ClawMobileTask` -> `ClawMobileEnvelope` -> 模拟事件流或带有界重连/ping 可观测性和进程内 task replay guard 的 WebSocket Gateway -> `ClawGatewayEvent` -> session reducer -> Mission Run / Approval Fast Lane 审批快车道 / Control Snapshot 控制态势快照 / Operator Strip / Loop 继续态势 / Mac Agent Readiness Board 就绪看板 / Mac Gateway Action Preflight Matrix 动作预检矩阵 / Mac Agent Evidence Coverage Map 证据覆盖图 / Mac Agent Next Step Deck 下一步候选卡组 / Mac Agent Run Timeline 执行时间线 / Mac Agent Continuation Gate 继续闸门 / Mac Agent Review Radar 复核雷达 / Mac Agent Handoff Brief 人工交接简报 / Focus Context 聚焦上下文 / Review Detail Dock / Review Trail 复核路径 / Approval Queue 审批队列 / Payload Safety Ledger 载荷安全账本 / Artifact 证据索引 / 复核态势摘要 / 复核优先队列 / 复核聚焦详情 / Live Gateway 连接健康 / Artifact metadata 复核摘要 / 文件变更安全复核摘要 / Shell 命令安全复核摘要 / 提取完整性复核摘要 / 浏览器控制计划和策略诊断复核摘要 / 草稿最终提交安全和桌面策略诊断复核摘要 / Gateway 能力复核摘要 / Accessibility 信号质量复核摘要 / Replay Guard 复核摘要 / AgentTrace handoff 复核 UI / iPad 多栏工作台展示和审批。v0.66 工作区实现进一步加入父 safe decision -> 短时单次 receipt -> 显式 draft/queue/approve/freeze/send -> 全新 child selected action + `runAgentLoop` 的受限跨 task 续接；v0.71 在同一闸门上加入 `extractData` 的 goal/outputPath typed editor，固定 schema/source/completeness 与 exact-key/byte/path 校验；v0.72 在同一 presentation/store 边界加入固定优先级 Smart Operator Action Rail，历史 v0.72 `origin/main` commit `bcf87c8c50f70d3d4157ec41a83333e62cd1ecdc` 已由 run `32631022162` attempt `1` 的 Agent C artifact 复判通过。
- 当前 Smart Operator Action Rail：从既有 continuation/primary/resume/review metadata 按固定优先级派生单一用户显式入口；compact 与 regular 共享 summary/view/dispatcher，stale 或 scope mismatch 返回 disabled/none，不新增 Gateway action 或协议字段。历史 v0.72 `origin/main` commit `bcf87c8c50f70d3d4157ec41a83333e62cd1ecdc` 对应 run `32631022162` attempt `1`，artifact `claw-ci-v0.2-main-bcf87c8c50f7-run32631022162-attempt1` 已由 Agent C 复判通过。
- 当前 Gateway 能力：进程内 task replay guard、session-start 能力快照 `auditLog`、屏幕观察 dry-run/截图/窗口元数据/带 signal quality metadata 的受控 Accessibility 摘要策略、浏览器 HTML/URL trace、带 metadata-only 计划复核和 policy diagnostics 的浏览器打开/搜索计划、workspace 文件写入与 metadata-only 文件变更安全复核、Shell 仅结构化 `toolArguments` 来源、dry-run、裸 executable allowlist 执行、同名路径/顶层 alias/来源冲突阻断与 metadata-only Shell 命令安全复核、带 metadata-only 完整性复核的结构化提取、带 metadata-only 草稿/最终提交安全复核和桌面策略诊断的 messageDraft/桌面 App 审批闸门、带 readiness/checklist/risk/stop/handoff status、mac 证据质量分层、推荐动作 envelope 交集和安全 metadata 的 `runAgentLoop`/`agentTrace`。
- 当前协作闭环：默认 `main` 直推，GitHub Actions 生成未加密 `ci-results` 结果包，Agent C 下载并核对 manifest/JUnit/日志后验收。
- 当前主要遗留：v0.66 完整负向/action/六种 kind/UI 对称测试矩阵、v0.67 最新云端 artifact 验收与 `manageFiles` 编辑器完整 LogicSmoke/负向覆盖、完整 macOS Accessibility bridge、Playwright/browser-use 兼容控制器、跨重启/跨进程多轮状态、live Gateway 后台保活/真实心跳协议/配对、完整 artifact 内容复核体验。

## 历史记录

### v0.86 / 安全连接保存与草稿隔离
日期：2026-10-22

- 首次 C 退回：`c0698041a0e08b745359b4d9d9c23d3baa099371` / run `39849006621` attempt `1`，artifact `claw-ci-v0.86-main-c0698041a0e0-run39849006621-attempt1` 总计 107,330,139 bytes，未整包下载；通过 ZIP range 仅下载 591,139 bytes 的 manifest/JUnit/摘要/关键日志/四份 xcresult Info，缓存 664 KiB。身份一致，14 项中 XCTest/iPad 两项失败，双设备各执行 165 项、各 14 个断言失败（四个方法）；其他构建/smoke 通过不代表整体通过。完整 xcresult/截图未下载或验收。
- 同版本修复：未签名 simulator host 导致真实 Keychain 返回 -34018，云端改为 build-for-testing 一次后只给临时 simulator host 加隔离 CLAWCITEST ad-hoc entitlement 并核验签名，再双设备 test-without-building；不需要 Apple 账号，不改生产工程/团队/Release 签名，不跳过 Keychain 断言。Live request 不在共享 validator 前 trim 原地址，堵住 CR/LF 预处理绕过；任意地址/凭据编辑即移除旧 continuation receipt，不能改回同值再审批。新增 receipt 为零断言；新回归的数组等价检查改固定失败文案以免大段假数据膨胀日志，断言不减弱。Keychain 读取改用 LAContext.interactionNotAllowed，移除弃用 API 警告。修复仍须新 main 全量重验，不能推进 v0.87。
- 上轮 v0.85 最新精确 artifact/日志/实际 PNG 已完整通过 C 复判，为有效进展；本轮选择发布必需的真实连接身份和凭据安全，而非继续增加看板。用户要求不开子 Agent，仍单实例串行 A/B/C/X，不冒充独立审查。
- 新 Core 连接合同与生产 Keychain adapter：endpoint/token 单条版本化 record 原子更新、严格 duplicate key/16 KiB/字段/地址/header 校验、WhenUnlockedThisDeviceOnly、非 iCloud 同步，不写普通文件/UserDefaults/明文 fallback。默认测试/preview no-op，App 显式注入生产存储，移除硬编码私网默认值。启动只读取连接，不联网、不恢复任务/审批/receipt、不写执行 checkpoint。
- 表单与已应用完整 pair 分离，dirty 的模型/probe/readiness/live/continuation 全部零 transport，普通/续接在 session 前拒绝；编辑切回仍使旧模型/审批/续接冻结授权失效。成功存储后才应用新 pair，失败保留旧配置。共享保存/重读/还原/确认清除 UI、44pt/VoiceOver；清除成功才移除运行时 pair/旧授权/receipt，不宣称撤销远端 Token 或动作。
- 模型/live/probe/readiness/生产 WebSocket 统一 WSS 或精确 loopback WS、禁止 userinfo/query/fragment/控制字符/非法端口与 token 注入；非法 live request 不附 Authorization。WebSocket 改 ephemeral/无 cookie/cache/拒绝 redirect，endpoint 错误固定脱敏。Gateway action/schema/权限不变。
- 新增 14 项配置 XCTest 与一项冻结 continuation 集成回归，预期双设备各 165 项；含随机 test service 真实 Keychain 的单条 create/update/load/protection/非同步/delete/损坏记录拒绝，生产 transport 非法配置前置拒绝、dirty 全入口零调用和保存/清除失败矩阵。LogicSmoke 仅注入 fake，cloud swiftc 编译新 adapter；旧成功 probe/readiness 夹具迁移到合法 WSS/无 query 路径，独立敏感输入脱敏/安全负向断言保留。
- README、协议、flow/flowchart、test、release-readiness、prompt 索引同步。aitrans 只读参考原子 Keychain 思路，未修改/读取其凭据或下载权重。仅做本地非编译静态复核，所有编译和业务验证待新 main 云端 artifact；用户签名、xcuserdata 和旧 prompt 不提交。真实模型质量、桌面 E2E、Mac/iPad 键盘/VoiceOver/分屏、实机锁屏与签名分发仍缺，未宣布发布完成。

### v0.85 / 自托管模型规划主路径
日期：2026-10-22

- 修复后完整 C 通过：`edab5a9a6feb6598e9122122fe549951f02c1d6b` / run `39841407261` attempt `1`，精确 artifact 1,973,076 bytes / 解压 4.7 MiB，manifest/JUnit/摘要/主日志一致，15 项成功、双设备各 150 项 XCTest 零失败，生产模型 HTTP + 21 个有界 fixture 请求与原全矩阵通过。四个 xcresult Info/root 文件存在，iPhone 第 1 帧/iPad 第 2 帧实际非白屏 PNG 已打开；未独立解码二进制 xcresult，Catalyst Metal 路径警告保留。不以 stub 宣称真实模型质量或桌面 E2E。

- 首次 C 退回：`7336cdae7a45d07c3a4d5d38b2772b308509aed5` / run `39838524028` attempt `1`，已下载 `claw-ci-v0.85-main-7336cdae7a45-run39838524028-attempt1`（116,478 bytes / 解压 540 KiB），manifest/JUnit/主日志核对一致，14 项中 XCTest/iPad 两项失败。生产 Swift HTTP client 与 20 次有界 provider fixture 请求、双平台 Release、LogicSmoke/fixture/Gateway smoke 通过；XCTest 因新 checkpoint fake 的 clear 返回类型错误未编译，iPad 缺共享 host 停止，无截图，整轮不通过。追加测试签名修复使用现有 ClearResult，并合入逐项参数复核安全补强，保留全部断言后重新云端验收，不推进下一版本。
- 上轮修复与最新 run `39829293264` 已完成精确 artifact/日志/实际看图复判，属于有效进展；本轮不新增看板，转向真实推理请求和 typed 动作计划。
- 新独立 HTTP `claw.gateway.planning.v1` 控制面：强制非空 Gateway token、只发送本次文本与固定 schema、同机显式配置的 Ollama `/api/chat`、一次推理/无 redirect/重试/下载、固定输出与容量/超时预算、断连取消和固定脱敏错误，不进入任何电脑执行 pipeline。
- 新 Core 合同和独立 Swift HTTP transport，严格 nonce/shape/duplicate key/类型/字节/路径/URL 与八类 typed inputs；模型不能指定审批/风险/权限/安全开关或 loop。模型步骤不再靠标题/target 推断 kind，固定安全 toolArguments 与证据复核尾步沿用 Bridge/allowlist/最终参数/普通审批；缺正文仍不能真实发送。
- Store 规划 operation 绑定 command/profile/plan/task/session/continuation revision；成功只更新来源明确的待审计划和实际用量，失败不自动生成规则/模拟结果，取消和旧 scope 丢弃。Mission 启动保留有效模型计划，command/profile 编辑后的旧计划不能 queue 或启动。共享 Mac/iPad/iPhone 主入口有显式数据去向、请求/取消/失败、来源和用量，不在生命周期联网。
- 新增 14 项 XCTest（补强后预期各 150 项）与 LogicSmoke；新增 cloud-only Node planning smoke，并复用已编译 LogicSmoke 执行生产 HTTP client -> Gateway -> 小型 Ollama stub -> 待审批，验证协议与安全负向矩阵、不下载权重。首次提交后的静态复审发现有效模型字段可未打开即审批，追加进程内逐 action 参数复核集合：合法 typed Apply 才确认、真实审批和发送独立检查、模拟/关闭/stale 不绕过，Mission 提供下一项直接入口。最终验收须包含补强的最新 run。workflow 新增 syntax/smoke/manifest/JUnit/最终 gate，保留原全矩阵，成功预期 15 项检查。project 只暂存新增源码注册，不包含用户签名或 xcuserdata。
- README、协议、flow/flowchart、test、release readiness、prompt 索引与详细提示词同步；本地仅非编译静态检查，等待新 main 云端验收。aitrans 只读参考 operation/cancel 思路，无修改/权重/依赖复制。本轮接口/stub 不能替代真实模型质量、视觉多轮智能、实际 Mac/iPad 交互、桌面 E2E、配对/TLS 或签名分发，未宣布发布完成。

### v0.84 / 首次云端退回与夹具、待办审批投影修复
日期：2026-10-22

- 单实例 C 阶段核对 `c89277813852fb3be07ec0613ea8061acde948be` / run `39822763413` attempt `1`，artifact `claw-ci-v0.84-main-c89277813852-run39822763413-attempt1` 的 manifest、13 项 JUnit/摘要和实际主日志一致：LogicSmoke、WebSocket smoke、双设备 XCTest 失败；iPhone/iPad 各 135 项测试、6 个断言失败，集中在三个方法。Release/fixture/direct 等通过不代表整体通过，continue-on-error 图标不能替代底层 outcome。
- 为避免默认下载 127,779,653 bytes 结果包，选择性 ZIP range 下载约 588 KiB 的关键日志/manifest/JUnit/摘要和四个 xcresult Info.plist，缓存 1.7 MiB；完整 xcresult 和截图未作本次失败验收，不冒充已检查。
- 修复固定 approval policy 永久计为待办的问题：running/succeeded 不再重复要求同次审批，pending/无结果和 waitingForApproval 仍保留闸门，failed/skipped 仍阻断；计数改为就绪/已处理，不授权重复发送，真实发送 gate 不变。新增专门六状态 XCTest，预期各 136 项，LogicSmoke 保留并强化原就绪断言。
- 两个 probe stale 夹具改为明确 browser 远端意图，session/request revision 前显式填写最终参数并确认实际创建会话；不再依赖本机假 action 或缺参拒绝来假测 stale。共享 direct/WebSocket helper 自带完整 desktop action，并断言进入 action pipeline，保留缺参脱敏失败、keys-only 无 preview 粘贴、后续合法精确写入和无 fallback 文件断言。
- 同步 README、协议、flow/flowchart、test、release readiness 与版本化提示词。本地仅非编译静态检查；需 main 追加修复提交后完整云端重验，不提前进入 v0.85。用户签名/xcuserdata/旧 prompt 保留、aitrans 未修改，发布级总目标未完成。

### v0.84 / 最终执行参数与普通审批绑定
日期：2026-10-22

- 前置 C 阶段已核对 v0.83 `91886b1` / run `39814219315` attempt `1` 的最新结果包和实际截图，确认双设备各 125 项测试、14 项检查全通过；Catalyst 仍有 runner Metal 工具链路径警告，不声称零警告。
- Bridge 不再把本机解析/审计/系统能力预览误送 Gateway；无远端动作 blocked，明确平台阻断项保留。补英文 browser/report 等规则意图，仍是规则规划而非模型推理。
- 移除浏览器伪 HTML、默认 Shell pwd、占位文件正文、自然语言拼接的桌面正文/提交键；新增独立 `ClawTaskArguments.swift` 和共享父级参数 sheet/list，覆盖浏览器/文件/Shell/桌面/提取/消息邮件草稿。未知字段、缺输入、UTF-8、路径/URL 和固定安全策略 fail closed。
- Apply 绑定当前最新未发送普通 task/action 的完整快照，只改一个 action、撤销旧审批；普通审批摘要绑定最终 task/profile，连接字段/token revision 撤销，真实发送前复核失败零 transport/session/event/artifact，Mission 不误报已发送。模拟与 continuation receipt/frozen 边界独立。
- Gateway 文件不再把 instruction 写成正文，桌面不再将 inputPreview/target 作为执行输入，显式正文不被 trim；缺输入只有固定脱敏审计失败，后续合法动作继续。fixture 与 direct/WebSocket 共用小型缺输入/无 fallback/精确写入矩阵。
- 新增 10 项 XCTest（预期双设备各 135 项）及 LogicSmoke；原默认值断言换成更强的缺输入/路由边界断言，已有 live/continuation 回归保留。project 只注册两个新源码，用户签名与 xcuserdata 不纳入提交；同步 README/协议/flow/flowchart/test/release readiness/prompt，workflow 保留全量检查并增加新测试 helper 语法检查。
- 本地仅非编译静态检查，本轮代码/测试须 push 后以最新云端 artifact 复判；尚未接真实模型，未完成统一旧 handler 参数迁移、桌面 E2E、Mac 实际交互、配对/TLS 和签名分发，不宣布发布完成。

### v0.83 / Mac 与 iPad 主路径、按需复核和未应用输入保留
日期：2026-10-22

- 前置 C 阶段完成 `0a8d9c463651d3daf8436635388c9c36c69352aa` / run `39805029958` attempt `1` 的 `claw-ci-v0.82-main-0a8d9c463651-run39805029958-attempt1` 复判：14 项零失败 JUnit、两平台 Release、iPhone/iPad 各 118 项 XCTest、LogicSmoke/fixture/Gateway/validator、四个 xcresult、两份就绪 JSON 和实际 PNG 一致。iPad 第 2 帧才就绪，已实际看图；1,916,885 bytes / 解压 4.1 MiB，不再把旧白屏截图或自动化绿灯当成当前 UI 证据。
- compact/workbench 共用父级详情/展开 state，按“计划与审批、证据复核、会话与事件、连接与权限”显示；Mission 保留唯一 Smart Rail、风险审批/结果计数、简洁健康/失败和续接编辑。高级 metadata projector 显式展开才构建，所有既有安全组件保留；envelope 默认收起。规划器明确标为规则预览，不冒充已接入模型。
- 结果来源从匹配 task/session 的固定 channel 和 scoped ack 派生，不跟随当前发送设置变化，不回显任意 channel，也不把 Live 事件等同真实动作成功。现有 probe/readiness 本地 focus 同步保留，不新增隐式网络或任务动作。
- 修复续接子 View 重建丢失未应用输入：父级持有非 Codable、仅进程内的 editor input，按 draft/父 task/session/kind 绑定；重排保留，新 scope/不可用重绑或清空，旧字段不外显，Apply 精确匹配渲染/当前 summary 和 editable 后仍走原 typed Store validator。输入不进入 checkpoint、协议、日志或 artifact，不自动审批或发送。
- 新增 7 项 XCTest 和 LogicSmoke presentation/editor/source 回归，保留全部旧断言；同步 README、协议、flow/flowchart、test、release readiness、prompt 索引与版本化方案，workflow 只更新 PRODUCT_ITERATION。用户签名/xcuserdata/旧 prompt 保留；aitrans 只读参考，无依赖或权重复制。
- 本地仅必要非编译静态检查；本轮 Swift/UI/业务测试等待新 main run 和实际 artifact 看图复判，未声称通过。真实模型、最终 typed 参数、桌面 E2E、配对/TLS、真机交互和签名分发仍未完成。

### v0.82 / 云端启动截图非白屏闸门
日期：2026-10-22

- 下载复判 `7583e9a1a7df7117a6068a8cc8e28c4eaa075275` / run `39801453526` attempt `1` 的 `claw-ci-v0.82-main-7583e9a1a7df-run39801453526-attempt1`：13 项零失败 JUnit、manifest、主日志和四个 xcresult 一致；iPhone/iPad 各 118 项 XCTest 零失败，LogicSmoke、fixture/direct/WebSocket 和双平台 Release 通过，结果包 1,148,078 bytes / 解压 3.4 MiB。
- 实际打开截图后，iPhone 有任务界面、iPad 白屏仅有系统状态栏，因此整体 C 阶段退回，不把自动化绿灯或 PNG 存在当作 UI 通过。当前不能区分采集过早或实际 UI 启动问题，也不把 runner cold boot/data migration 误称 App 性能。
- 增加仅用于云端的系统 Vision/ImageIO validator 和有界 capture 脚本：固定识别 Claw + Mission Run，拒绝单 marker/状态栏/白屏，最多 15 帧、帧间 2 秒，只留最后真实帧和固定 readiness JSON，不记录 OCR 原文。CI policy v0.4 将 validator/self-test、JSON 严格校验纳入 manifest/JUnit/最终闸门，未就绪则失败。
- 同步 README、协议展示边界、flow/flowchart、test、prompt 索引、release readiness；不修改 App、Gateway、签名或业务断言。v0.83 只准备规划稿，未实施/暂存，需本轮完整云端复判通过后再推进。
- 本地仅非编译静态检查；validator、脚本、编译、模拟器和业务测试只在新 main run 执行。用户配置、旧 prompt、只读 aitrans 保持不变；新 SHA/run/artifact 待产生。

### v0.82 / 云端测试夹具接口修复
日期：2026-10-22

- 单实例 C 阶段下载复判 run `39799453977` attempt `1` 的 `claw-ci-v0.82-main-07a6747fd7ac-run39799453977-attempt1`（49,362,699 bytes，解压 52 MiB）：manifest SHA/run/attempt、JUnit 12 项 / 3 项失败和主日志一致；Release iOS/Catalyst、Gateway fixture/direct/WebSocket 通过，但 LogicSmoke 与 XCTest 编译失败，不能验收 v0.82。
- 根因是新增夹具把 event 的 `summary` 误传给 artifact、遗漏必填 `isRedacted`，以及引用不存在的 `hasLiveGatewayAck`。修正为现有 artifact initializer 和 `hasGatewayAck`，保留全部失败隔离、partial evidence、身份与脱敏断言，不改生产接口迁就测试。
- iPad `test-without-building` 在共享 test host 缺少 executable 时先输出固定诊断并失败，不再启动模拟器产生无效安装报告；正常 iPhone/iPad 验证、截图、结果包门槛不变。
- 修正本轮授权记录：用户要求不开子 Agent，由同一个 Agent X 串行规划、实现、复判；不声称独立审查。仅运行本地非编译静态检查，所有业务验证等待新 main run；签名、Xcode 用户文件和旧 prompt 保留，aitrans 未修改。

### v0.82 / 真实 Gateway 失败与模拟结果隔离
日期：2026-10-22

- 同步/async live preflight 未通过时保持未发送诊断、零 transport、零业务 artifact；移除自动模拟 fallback。throw、无终态 EOF 和取消只对精确 session 添加固定脱敏失败收口，保留部分结果、artifact 与 running 未确认状态。
- 生产 WebSocket 增加每连接远端 session 绑定，先校验 task/remote session/offer 再映射本地 session；拒绝错误首帧占绑定、同 task 混入其他 session 和错误 offer，保留合法远端 lineage。收到任何桌面 payload 后禁止自动重发，重连诊断改为固定代码。
- 首个匹配 task/session 的 terminal 锁定结果，拒绝同批/跨批重复终态和晚到业务帧；错身份终态不能决定完成或接收 continuation offer。continuation 保留远端 parentSessionID / 本地 sessionID 区分、冻结审批与单次 receipt 合同。
- async 发送不再跨 await 临时写回全局 dispatch mode；generation 跟踪模式/配置修改（含切回同 enum），旧任务只更新历史 session，不覆盖新任务/Mission/连接/request/focus。共享 health/Mission 区分未发送与结果未确认，不新增看板或 Gateway 权限。
- 新增 XCTest 完整 preflight/throw/partial/EOF/cancel/terminal/身份/交错/revision 矩阵和 LogicSmoke 核心隔离回归，同步 README、协议、flow/flowchart、test、release readiness 与 v0.82 prompt；workflow 仅修改 PRODUCT_ITERATION。
- 本地只允许并执行非编译静态检查；未运行编译、XCTest、LogicSmoke、Gateway smoke、node --check 或模拟器。基线 `0b9746292f4b67afac09ea36d7df50eb3297d061` / run `38342562083` attempt `1` / artifact `claw-ci-v0.81-main-0b9746292f4b-run38342562083-attempt1` 已由 C 复判通过：13 项 CI、iPhone/iPad 各 106 项 XCTest、LogicSmoke、fixture/direct/WebSocket smoke、iOS/Catalyst Release。本轮新 SHA/run/artifact 与 Agent C 验收待产生，未宣称本轮通过。
- 发布缺口仍包括真实最终 typed 参数、非关键词的真实模型 planner、Mac/iPad 主路径简化、授权桌面 E2E、凭据/配对/TLS、签名隐私与分发；aitrans 未修改，用户 signing/xcuserdata/旧 prompt 保留。

### v0.78 / Mac 与 iPad 工作台基础
日期：2026-09-27

- 首次 C 复判：b2a9cafde36a967cc5aa326965ca830f32ac292a / run 36309166142 attempt 1 失败。结果包 claw-ci-v0.78-main-b2a9cafde36a-run36309166142-attempt1（462358 bytes，解压 2.4M）identity、manifest、JUnit、日志及三个 xcresult 一致。iOS/Catalyst Release 均成功（126/135 秒）；iPhone/iPad 各 103 项 XCTest 零失败，但其后的 simctl launch 因选中设备 Shutdown 返回 405，没有截图，因此平台检查失败。
- 追加云端流程修复：截图前 bootstatus -b、显式安装本轮 Debug app，再 launch/screenshot；不删除任何测试或放宽门槛。加入 Release build timing summary 用于后续按证据优化。v0.79 live 发送草稿保留，未混入本次修复。新 run 仍须完整重验。

- 前置 v0.77 commit 7f618a3078fa59884d81c742eeb78957d8ee7069 / run 36308683756 attempt 1 已通过；下载 claw-ci-v0.2-main-7f618a3078fa-run36308683756-attempt1（344497 bytes，解压 1.4M），manifest、10 项零失败 JUnit、build/XCTest、LogicSmoke、fixture 与 Gateway 双 smoke 日志一致。
- 接续已有 v0.78 草稿：共享 scheme、Catalyst、iPad 四方向、侧栏/键盘导航、根视图聚焦与自适应工作台拆分。云端增加 Catalyst Release、iPad XCTest 和双设备截图；平台 outcome 纳入 manifest/JUnit/失败门槛。
- 本地仅静态检查；用户 signing team/xcuserdata 及旧提示词保留。aitrans 仅只读参考。v0.78 待 main push 云端验收，发布级总目标未完成。


### v0.77 / Readiness nonce 字符集根因修复
日期：2026-09-27

- 最新 main db863f4574f0ccf94f71e80ad2dd9cbd42546055 的 run 36234586078 attempt 1 失败；云端日志为 100 项 XCTest 中同一 readiness 测试 13 个断言失败，成功请求 fake call/response/close 为 0。artifact 下载核对进行中，不能判为通过。
- 生成器和 Gateway 允许 base64url 连字符，Swift validator 漏掉 ASCII 45，导致随机请求在 transport 前被拒绝。修复共享 validator，增加固定合法/非法字符与长度回归，不继续扩大超时。
- 修改 ClawModels.swift、ClawTests.swift、LogicSmoke.swift；同步 README、协议、flow、flowchart、test 和提示词。本地仅静态检查；新 main 云端验证待推送，未宣称发布就绪。
- v0.78 Mac/iPad 草稿、用户签名和旧提示词保留，不混入基线修复提交。


### v0.77 / 恢复云端验证基线
日期：2026-09-26

- 首次 artifact 复判：a3a48f4 / run 36233990856 / attempt 1 的 manifest、JUnit、日志和 xcresult 精确匹配；静态、Swift logic、fixture、Gateway direct/WebSocket、iOS build 通过，XCTest 仅 readiness duplicate fixture 1 秒启动观察失败。保留失败结论，追加独立 5 秒测试启动观察预算，生产 3 秒 response timeout 和关闭/取消断言不变；需新 run 重验。

- 复核最新 main run 34175749191 attempt 1：Swift logic smoke 和 XCTest 在六处 async autoclosure 断言编译失败，不能将此前的 readiness 修复记为通过。
- 修复 `Tools/LogicSmoke.swift`、`ClawTests/ClawTests.swift`：异步等待先求值，原有超时、取消、stale、无副作用和 close-count 断言全部保留。
- 用户明确禁止子 agent，本次由 Agent X 单实例顺序保留规划、实现、artifact 复判阶段；提示词在 `md/prompt/v0（核心智能能力）/v0.77（恢复云端验证基线）.md`。
- 本地仅静态检查；云端结果待最新 main push 后复判。Mac/iPad 和发布级智能能力仍是后续目标，未宣称完成。

### v0.76 / AgentTrace 证据交接包
日期：2026-08-24
实现范围：
 - 在 `Claw/Core/ClawModels.swift` 增加严格 typed 的 `ClawAgentTraceHandoffPackSummary`/item/PresentationContract，从已有 AgentTrace review metadata 派生固定五行证据、决策、审批、交接和安全摘要；未知/矛盾/越界状态 fail closed，不把 handoffSummary、风险原文或 artifact payload 带入展示。
 - 在 `Claw/Views/ContentView.swift` 把同一个 handoff pack projector/view 接入 compact iPhone Mission Run 和 regular iPad/mac Review Detail Dock；focus 只改变 AgentTrace detail scope，控件至少 44pt，VoiceOver 明确不自动继续、不审批、不发送、不执行电脑动作。
 - 增加 XCTest、LogicSmoke 和 README、协议、flow、flowchart、test 文档，明确本轮不修改 Gateway server、action/event/artifact/protocol、权限、后台循环或真实 macOS controller。
关键文件：
 - `Claw/Core/ClawModels.swift`、`Claw/Views/ContentView.swift`、`ClawTests/ClawTests.swift`、`Tools/LogicSmoke.swift`
 - `README.md`、`Docs/claw-mobile-gateway-protocol.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md`、`update_log.md`
 - `md/prompt/v0（核心智能能力）/v0.76（AgentTrace证据交接包）.md`
验证状态：本地仅执行 `git diff --check`、文本搜索和 diff 范围复核；未运行本地编译、XCTest、LogicSmoke、Gateway fixture/direct/WebSocket smoke、`node --check` 或 `xcodebuild`。提交并 push 后必须由最新 GitHub Actions artifact 与 Agent C 复判覆盖本轮 Swift、UI、LogicSmoke、XCTest、Gateway 回归、manifest/JUnit/日志和敏感信息合同。
遗留事项：等待 Agent B/main push 后的最新云端 run；Agent C 必须确认 artifact 与最新 commit/run/attempt 精确匹配后，才能宣布 v0.76 通过。

### v0.76 / readiness 云端失败修复
日期：2026-09-08

实现范围：

- 将 `ClawGatewayReadinessTransportFake` 的 call/release/close 协调改为线程安全的一次性 signal；`waitForCall`、`waitForClose`、wait-for-release、取消和 timeout 都有界，success/error/cancel 只记录一次 close。
- success fake 仅在同 nonce、response 可编码且严格计数满足时返回 response；`ClawStore.requestGatewayReadiness` 继续要求一次 request/response/close 和 application message，运行时 token 仍只在 Authorization header，stale/generation/binding guard 与无副作用合同不变。
- readiness XCTest/LogicSmoke 增加 bounded call/close 等待；未删除 duplicate、stale、redaction 或 side-effect 断言，也未修改 Gateway server、协议 schema、工程配置或 AgentTrace。

关键文件：`Claw/Services/ClawStore.swift`、`ClawTests/ClawTests.swift`、`Tools/LogicSmoke.swift`、`README.md`、`Docs/claw-mobile-gateway-protocol.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md`、`update_log.md`。

验证状态：仅执行允许的静态检查（`git status`、`git diff --check`、文本搜索和 diff 复核）；未运行本地编译、XCTest、LogicSmoke、Gateway smoke、fixture、`node --check` 或 `xcodebuild`。提交并 push 后必须由新的 GitHub Actions run 和 Agent C artifact 复判确认，不能把本轮静态检查或旧 cancelled run 当作通过。

遗留事项：等待 `origin/main` 最新 run 的 manifest、JUnit/摘要、XCTest、LogicSmoke、Gateway 回归、Xcode build 和 artifact 与修复 commit/run/attempt 完全匹配后验收。

### v0.75 / 受控 Gateway Readiness Attestation

日期：2026-08-23

实现范围：

- 增加独立 `claw.gateway.readiness.v1` control plane。request body 严格只允许 `controlPlane`、`kind`、`requestNonce`；response 使用固定 capability/policy/assessment/tokenHeader/effects/redaction schema，same nonce，所有 effects 固定为 `false`，未知字段、错误 enum、类型错误和非法 nonce fail closed。
- runtime token 仅进入本次 WebSocket `Authorization: Bearer` header；`tokenHeader` 只表达本次 header 被接受或不要求，不表达 pairing、authorization、trusted 或电脑可控。独立 URLSession transport/fake 保证单 request、单 response、单 close，具备有界 timeout/cancel、固定诊断和 generation/profile/Mission/stale guard。
- Gateway readiness route 位于普通 task envelope pipeline 之前，只读固定 config/policy projector，不调用 task/session/workspace/replay/event/artifact/auditLog/receipt/handler/Shell/browser/desktop 路径；response 不创建任务、会话、workspace、replay、event、artifact 或外部动作。direct/WebSocket smoke 增加 readiness 和普通 task 分流/no-side-effect 断言。
- compact iPhone Mission Run 与 regular iPad/宽屏 Review Detail Dock 在共享 health strip 复用同一 readiness summary/view/API，入口至少 44pt，VoiceOver 固定说明只读和无副作用边界；readiness 不改变 v0.73 probe、v0.74 checkpoint、Live health、审批、receipt、review focus 或 Smart Rail。
- 同步 README、协议、flow、flowchart、test 和本日志；未实现 pairing/authorization trust、后台保活、heartbeat、retry/reconnect、macOS target、Accessibility bridge、browser controller 或任何 task action。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `update_log.md`

验证状态：本轮只执行允许的非编译静态检查；本地未运行 build、XCTest、LogicSmoke、Gateway fixture/direct/WebSocket smoke、`node --check` 或 `xcodebuild`。commit、GitHub Actions run、artifact 和 Agent C 复判待 push 后产生，不能预写通过结论。

遗留事项：需要 Agent C 使用 `Altman-sam114` 下载最新 `origin/main` run，核对 readiness 固定 schema、一次 close、stale/no-side-effect/redaction、普通 task/v0.73/v0.74 回归、manifest/JUnit/日志/结果包与 commit/run/attempt 完全一致。

### v0.74 / 跨重启 Mission Run 安全交接快照

日期：2026-08-23

实现范围：

- 增加严格白名单、版本化 `ClawMissionRunCheckpoint`，只保存 phase/status、有限计数、固定布尔值、保存时间和既有任务 Live health 的有限 transport 观察；未知字段/版本、非法值、损坏或超限数据 fail closed，不保存 command、ID、payload、token、URL/path、receipt、lineage、审批、review focus 或 Smart Rail binding。
- 增加可注入的 no-op、in-memory fake 和 Application Support file store。生产只写固定的最新 `ClawMissionRun/last-checkpoint.json`，使用结构化 JSON、原子替换和可用时的 iOS 文件保护；读写清理失败只呈现固定脱敏状态。
- 在任务/审批/有效 Gateway 状态/完成/失败/回退/重试/continuation 边界 best-effort 保存；App 重启只恢复只读 metadata-only handoff summary，不恢复 task、session、event、artifact、live request、审批、receipt、review focus 或 Smart Rail。clear 只清本机快照。
- compact iPhone Mission Run 与 regular iPad/宽屏 Review Detail Dock 复用同一 checkpoint view、summary 和 Store clear API；补充 model/store/lifecycle/no-side-effect/redaction/UI 合同测试和 README、协议、flow、flowchart、test 文档。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/App/ClawApp.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `update_log.md`

验证状态：本轮实现后只执行允许的非编译静态检查；本地未运行编译、XCTest、LogicSmoke、Gateway fixture/direct/WebSocket smoke、`node --check` 或 `xcodebuild`。commit、GitHub Actions run、artifact 和 Agent C 复判待 push 后产生，不能预写通过结论。

明确未实现：持久 pairing、后台保活、自动重连/重试、跨重启可执行任务/session/event/artifact/receipt/continuation 恢复、Gateway/protocol/action/event/artifact 改动、原生 macOS/Mac Catalyst target、Accessibility bridge 或浏览器控制器。

### v0.73 / 显式 Live Gateway transport probe

日期：2026-08-23

当前实现范围：

- 在既有 Live Gateway health strip 增加一次性、用户显式的 transport probe summary 与 Store API。合法 `ws://`/`wss://` endpoint 和 runtime token 只用于独立 WebSocket header；连接后恰好发送一次 control-frame ping，在有界 timeout、失败或取消后关闭 socket。
- probe 不发送 JSON envelope/application message，不创建 Gateway session、event、artifact、replay、handler 或模拟 fallback，不修改任务 health、approval、continuation receipt、review focus 或 Smart Operator Rail。成功只表示 transport reachable，不表示 paired、authorized、Gateway ack、桌面权限或任务成功。
- 增加固定状态、固定脱敏诊断、task/session/profile/continuation/generation stale guard、重复点击 fail closed、fake transport 的 call/ping/application-message/body/close 断言；compact iPhone 与 regular iPad/宽屏 Dock 复用同一 view/summary/API，控件至少 44pt 并带 transport-only VoiceOver hint。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `update_log.md`
- `md/prompt/v0（核心智能能力）/v0.73（显式LiveGateway心跳探测）.md`

验证状态：初始实现 commit `668dcaa9e28d5a70cc65268bc88768d9fc7a58c3` 对应 run `32632990567`、attempt `1` 的 CI 全部通过，但 Agent C 发现验收矩阵缺口并退回补齐。最终修复 commit `11b8d7e6122549498bdfc35c96c7d2a810421825` 对应 run `32637596878`、attempt `1`、workflow `Claw CI Results`；artifact `claw-ci-v0.2-main-11b8d7e61225-run32637596878-attempt1` 未加密且 manifest 完全匹配，JUnit 10 checks/0 failures、XCTest 94 tests/0 failures、LogicSmoke、Gateway fixture/direct/WebSocket smoke、Xcode build、结果包和 fail gate 全部通过，Agent C 已下载并复判。期间未运行本地编译、XCTest、LogicSmoke、Gateway fixture/direct/WebSocket smoke、`node --check` 或 `xcodebuild`；仅执行允许的非编译静态检查。

未实现：后台保活、定时 heartbeat、自动重连/重试、静默配对、真实 pairing protocol、新 envelope/action/event/artifact/schema 字段、原生 macOS/Mac Catalyst target、Accessibility bridge 和 Gateway server 改动。已保留用户 Xcode 配置改动、旧 v0.70 prompt 及其他无关工作区文件。

### v0.73 追加修复 / Agent C 退回项

日期：2026-08-23

核心变更：

- 按 Agent C 结论补齐 model/store/transport fake/UI/XCTest/LogicSmoke 的失败、取消、timeout、重复/in-flight、redaction、no-side-effect 和 stale binding 矩阵；binding 覆盖 task/session/sessionTask/Mission scope、endpoint、token fingerprint/profile digest、request/session revision、continuation draft/receipt/lineage/source/decision、review focus 和 generation。
- 修正 probe dispatcher 不再隐式改写 review focus；compact iPhone 与 regular iPad/宽屏继续使用同一 summary/view/dispatcher，固定 title/icon/enabled、44pt 和 VoiceOver hint。

验证状态：本轮仅执行允许的 `git status`、`git diff --check/stat`、`rg` 和 diff 复核；未运行本地编译、XCTest、LogicSmoke、Gateway fixture/direct/WebSocket smoke、`node --check` 或 `xcodebuild`。修复 commit `11b8d7e6122549498bdfc35c96c7d2a810421825` 已 push 到 `origin/main`，对应 run `32637596878`、attempt `1`、artifact `claw-ci-v0.2-main-11b8d7e61225-run32637596878-attempt1`；Agent C 已按 manifest、JUnit、XCTest、LogicSmoke、Gateway 日志、Xcode result bundle 和 fail gate 复判通过。

遗留事项：不修改 Gateway server、fixture、direct/WebSocket smoke、workflow 或工程配置；继续保留用户 Xcode 配置和旧未跟踪 v0.70 prompt。

### v0.72 / Mac-iPad Smart Operator Action Rail

日期：2026-08-23

当前实现范围：

- 新增 metadata-only Smart Operator action summary、固定 continuation/primary/resume/focus 优先级和共享 stale-safe dispatcher；compact iPhone Mission Run 与 regular iPad/宽屏 Review Detail Dock 复用同一个 Rail view、summary 和既有 Store 闸门。
- continuation queue/approve/send、普通 Mission primary、显式 resume intent 和 focusReview 均不新增状态机或 Gateway action；focusReview 只更新当前 scoped focus。Rail 文本和 VoiceOver hint 固定脱敏，控件最小 44pt，渲染快照变化、scope/profile/receipt/review 不匹配时 fail closed。
- 补充 ClawTests、LogicSmoke、README、协议、flow、flowchart 和 test 文档；本轮未修改 Gateway、工程配置或 workflow，不增加协议字段。用户已有的 Xcode 配置改动和旧 v0.70 prompt 未纳入提交。

验证状态：仅执行允许的非编译静态检查；未运行本地编译、XCTest、LogicSmoke、Gateway fixture/direct/WebSocket smoke、`node --check` 或 `xcodebuild`。首次实现 commit `a73739b2c63aab22addfc51fc9c00d40f12189f3` 的 run `32630438110` 因 LogicSmoke 断言极性失败；修复 commit `bcf87c8c50f70d3d4157ec41a83333e62cd1ecdc` 对应 GitHub Actions run `32631022162`、attempt `1`、workflow `Claw CI Results`，artifact `claw-ci-v0.2-main-bcf87c8c50f7-run32631022162-attempt1` 未加密且 manifest 完全匹配，JUnit 10 checks/0 failures、XCTest 83 tests/0 failures、LogicSmoke/Gateway fixture/direct/WebSocket/Xcode build 和最终 fail gate 全部通过，Agent C 已下载并复判。遗留风险为 CI Node.js 20 deprecation warning、尚未做真实设备 UI/VoiceOver 运行时验收，以及 Gateway 原型不等于真实 macOS 控制器。

### v0.71 / ExtractData Continuation Typed Editor

日期：2026-08-23

当前实现范围：

- 为 `extractData` continuation draft 增加 metadata-only presentation summary、goal/outputPath typed editor 和 `ClawStore.updateContinuationExtractionArguments`；compact iPhone 与 regular iPad/宽屏工作台复用同一 summary、Store API 和 SwiftUI view。
- 固定 exact key set、source priority、schema、`validateCompleteness=true`，并在客户端增加 UTF-8 字节上限、NUL、绝对/`~`/反斜杠归一化逃逸/`..` segment 和固定脱敏 validation message；safe receipt、approval-gated、非法、stale、queued/frozen/sent 状态保持既有 queue/approval/freeze/send 闸门。
- 补充 Swift XCTest、LogicSmoke、Gateway continuation preflight 兼容收紧、direct/WebSocket 负向 fixture 和相关 README/协议/flow/test 文档；未新增 Gateway 协议字段或 handler。最新云端结果包已证明 Gateway fixture/direct/WebSocket 回归、LogicSmoke、XCTest 和 Xcode build 通过。

验证状态：仅执行 `git status`、`git diff --check`、文本搜索和 diff 复核；未运行本地编译、build、XCTest、Swift LogicSmoke、Gateway fixture/direct/WebSocket smoke、`node --check` 或 `xcodebuild`。`origin/main` commit `26e02061e0e73082a04c7d0377b7eb135e8e16b2` 对应 GitHub Actions run `32628660909`、attempt `1`、workflow `Claw CI Results`；artifact `claw-ci-v0.2-main-26e02061e0e7-run32628660909-attempt1` 未加密且 manifest 完全匹配，JUnit 10 checks/0 failures、XCTest 82 tests/0 failures，Agent C 已通过复判。遗留风险为 CI Node.js 20 deprecation warning，以及 Gateway 原型不等于真实 macOS 控制器。

### v0.70 / Live Gateway 配对诊断与显式恢复意图

日期：2026-08-09

当前实现范围：

- 在现有 Swift presentation/store 边界加入 metadata-only pairing diagnostics，区分 endpoint/token 配置、可尝试 live、当前 task/session Gateway ack、失败、模拟回退、完成和 stale/mismatch。
- 在 compact Mission Run 与 regular iPad/宽屏 Review Detail Dock 复用同一配对诊断/恢复意图视图；用户点击后只记录绑定当前 scope/profile/session revision/continuation 状态的内存 intent，不触发网络、重试、审批、发送或 receipt 变化。
- 未增加 Gateway handshake、schema/event/action/artifact 字段，未实现持久配对、后台保活、静默恢复、原生 macOS/Mac Catalyst target；旧 scope 和 profile/receipt 变化 fail closed。

关键文件：`Claw/Core/ClawModels.swift`、`Claw/Services/ClawStore.swift`、`Claw/Views/ContentView.swift`、`ClawTests/ClawTests.swift`、`Tools/LogicSmoke.swift`、`README.md`、`Docs/claw-mobile-gateway-protocol.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md`。

验证状态：仅计划执行 `git diff --check`、文本/diff 复核和必要静态检查；未运行本地编译、XCTest、LogicSmoke、Gateway fixture/direct/WebSocket smoke、`node --check` 或 `xcodebuild`。commit/run/artifact 待 push 后由 GitHub Actions 和 Agent C 复判。

### v0.69 / macOS-iPad Regular Workbench Primary Action

日期：2026-08-09

核心变更：

- regular iPad/宽屏工作台的右侧 Review Detail Dock 就地复用 `missionRunSummary` 的 primary action 标题、SF Symbol、enabled 状态和既有 Store dispatcher；regular 左栏隐藏重复入口，compact iPhone 保持原单栏入口。
- 共享 primary action view/dispatcher 接收渲染时的 Mission summary，并在执行前重新核对 command、task/session/sessionTask、mission scope、phase、primary title/icon/kind 和 enabled 状态；旧 summary、旧 scope、stale action、等待 Gateway 与阻断状态均 fail closed，不能绕过审批、workspace、allowlist、live preflight、continuation receipt 或冻结/发送闸门。
- app 与 test target 的 `TARGETED_DEVICE_FAMILY` 仅从 `1` 扩展为 `"1,2"`，没有修改用户的 team/bundle/scheme 配置，也没有修改 xcuserdata；工程仍没有原生 macOS 或 Mac Catalyst target。
- 补充 idle、审批、复核、完成、Gateway wait 和 blocked 的 presentation action 状态覆盖，以及 disabled/blocked dispatcher 无副作用断言。UI 继续只读 metadata-only 展示状态，不暴露 token、receipt、payload、路径、URL、正文或 UUID。

关键文件：

- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `Claw.xcodeproj/project.pbxproj`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `update_log.md`

验证结果：

- 本轮仅进行 `git status`、`git diff --check`、文本/diff 复核和必要的 `plutil -lint`；未运行本地编译、build、XCTest、Swift LogicSmoke、Gateway fixture、direct/WebSocket smoke、`xcodebuild` 或 `node --check`。
- 首次提交 `91edee2e30583231801b847e8c359e5c33033a53` 的 GitHub Actions run `31297226825` attempt `1` 失败：OpenStep project 中未加引号的 `TARGETED_DEVICE_FAMILY = 1,2;` 破坏 `plutil`/Xcode project parse，且 LogicSmoke 对非 retryable needsAttention 状态错误期待 retry title/icon。
- 本修复轮次改为 `TARGETED_DEVICE_FAMILY = "1,2"`，并把同一非 retryable 命令的 primary action 期待改为 `查看处理要求` / `exclamationmark.magnifyingglass`；只做静态复核后提交并 push，新的云端 artifact 与 Agent C 复判待产生，不能将本地静态检查描述为业务通过。
- 后续 run `31297519524` attempt `1` 暴露 `ClawMissionRunPanel` 的 SwiftUI memberwise initializer 不接受带默认值的 `showsPrimaryAction` 参数（`extra argument 'showsPrimaryAction'`）；本轮改为显式 `Bool` 参数并让 compact 入口传入 `true`，regular Dock 继续传入 `false`。仅做静态检查后提交，云端复验与 Agent C artifact 复判待产生。

遗留事项：

- 需要 Agent C 下载最新 `origin/main` CI artifact，核对 manifest、JUnit/摘要、主日志、XCTest、LogicSmoke、fixture、direct/WebSocket smoke、Xcode build 和 target family 变更与 commit/run/attempt 完全匹配。
- regular 布局语义不代表原生 macOS 应用；完整 macOS Accessibility/browser controller、跨重启多轮状态和持久 live Gateway pairing 仍待后续版本。

### v0.68 / Gateway 普通任务统一 Dispatch Preflight

日期：2026-08-09

核心变更：

- Gateway 普通首次 dispatch 在 replay cache、workspace、`gatewayConnected`、能力快照 artifact、action event、业务 artifact 和 handler 前增加统一 preflight；仅 `task.status=sent` 可进入普通执行流，缺失/未知及各非发送状态固定 fail closed。
- allowlisted 敏感 Gateway action 必须满足 Gateway 敏感审批、审计开关、`auditRequired` 和 `userConfirmation`/`gatewayApproval` 合同；敏感 action 伪造 `automatic` 不再进入 handler。allowlist 未允许或显式 blocked action 保留既有逐 action skip。
- preflight 错误为无 action identity、不可重试、无敏感回显的 envelope-level error，失败不创建 replay/workspace、不写 artifact、不发业务事件、不执行 handler；continuation 继续沿用 `readyToSend + receipt`、lineage 和单次消费合同。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/ClawGatewayEventFixture.swift`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `update_log.md`

验证结果：

- 按本轮规则只进行代码、文本和 diff 静态复核；未运行本地编译、build、XCTest、Swift LogicSmoke、Gateway fixture、direct/WebSocket smoke、`xcodebuild` 或 `node --check`。
- 初始提交 `c8fc1d004b22f4aabe777a8ed990c4b780f7efaf` 的 run `31295276252` attempt `1` 暴露 direct smoke 兼容性问题：`--emit-events` 捕获 preflight 后改变了既有 runtime/unknown-action 非零退出合同；Agent C 判定不通过，其他检查通过。
- 修复提交 `81c6a16c200725f2ab964d5448d9886e551a6cdd` 的 GitHub Actions run `31295620742` attempt `1` 已通过；Agent C 下载并核对 artifact `claw-ci-v0.2-main-81c6a16c2007-run31295620742-attempt1`，manifest 与 `main` commit/run/attempt 完全匹配。git diff、plutil、node-check、Swift LogicSmoke、Swift Gateway fixture、Gateway direct smoke（353 events）、Gateway WebSocket smoke（135 events）、Xcode build、XCTest（75 tests，0 failures）、artifact packaging/fail gate 全部 success。

遗留事项：

- 普通 dispatch preflight 仍是客户端 envelope 合同加 Gateway 进程内策略检查，不提供跨进程/跨设备的密码学审批证明；Gateway handler、allowlist、workspace 和审批闸门仍必须持续 fail closed。
- iPad/mac regular workbench 主动作就地化、原生 macOS target、完整 Accessibility/browser controller、跨重启多轮状态和持久 live Gateway pairing 仍待后续版本。

### v0.67 / Continuation Parameter Editor `manageFiles` 文件续接参数编辑

日期：2026-08-09

核心变更：

- 为选中的 `manageFiles` continuation draft 增加受限 typed 参数编辑：`operation` 固定为 `writeText`，`workspaceOnly` 固定为 `true`，只允许编辑 `writePath` 和 `writeText`。
- 编辑 API 继续使用既有 continuation validator；路径必须是 workspace 内的相对路径，拒绝绝对路径、`~` 和 `..` 路径段；路径/正文等参数每个字符串值最多 4096 个 UTF-8 bytes，非法输入返回固定脱敏提示并保持 `readyForInput`。只有带有效 receipt 的 safe-without-approval 草稿在参数合法后进入 `readyForApproval`；approval-required/destructive 的 `manageFiles` 草稿即使参数合法也保持 `needsApproval`、无 receipt、不可 queue/send，但未入队前仍可编辑。
- 编辑只发生在尚未入队的 draft，且不改变父 task/session/AgentTrace、decision digest、receipt handle/expiry、Mission scope 或 review focus。入队生成全新 child，actions 恰好为 `[manageFiles, runAgentLoop]`；入队、审批冻结、发送以及 stale/blocked 状态后均锁定编辑。
- compact iPhone 与 regular iPad/mac 复用同一 continuation presentation summary、编辑视图和 typed API。raw receipt、token、父 payload、Gateway 绝对路径和未过滤 metadata 继续按 redaction 规则从 UI/VoiceOver、event、artifact metadata、日志和 CI 摘要中省略；用户正文不复制到 auditLog 或 artifact metadata。
- 不修改 Gateway handler、continuation receipt/lineage/TTL/单次消费、审批或发送协议；v0.67 仍不提供其他 action kind 的通用参数编辑器，也不放宽 destructive/approval-required 策略。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `update_log.md`

验证结果：

- 本 sidecar 只允许文档非编译静态检查；未运行本地编译、build、XCTest、Swift LogicSmoke、Gateway fixture、direct/WebSocket smoke、`xcodebuild` 或 `node --check`。
- 初版 commit `d9d3426f70f5c1d894702196496dde078eb36e91` 的 GitHub Actions run `31291864338` attempt `1` 与 commit 匹配，但 XCTest 的 75 个测试中有 2 个失败：`manageFiles` fixture 伪造了 approval-required action 的 safe receipt，违反既有 receipt 签发合同；静态检查、LogicSmoke、fixture、direct/WebSocket smoke、Xcode build 等其余结果通过。
- 本修复轮次改为真实 approval-gated fixture，必须提交并 push 到 `origin/main` 后交给 GitHub Actions；Agent C 需要用仓库授权账号下载最新未加密 artifact，核对 manifest、JUnit/摘要、主日志、XCTest、LogicSmoke、fixture、direct/WebSocket smoke 和 Xcode build 与最新 commit/run/attempt 完全匹配后再判定。修复 run 尚未产生，不能预写通过结果。

遗留事项：

- 当前 v0.67 还需由实现 Agent 提交/核对 `manageFiles` editor 的 approval-gated helper、LogicSmoke 覆盖及完整云端负向矩阵，然后由 Agent C 复判；不能将本地文档检查视为业务验证。
- receipt 仍不跨 Gateway 进程、重启、设备或 10 分钟；其他五种 continuation action 仍没有通用参数编辑器。

### v0.66 / Trusted Cross-Task Multi-Round Continuation 可信跨任务多轮续接

日期：2026-07-26

核心变更：

- 正式定义 v0.65 decision、Gateway continuation receipt 与 child 用户审批三个独立信任条件；任一都不能替代另一项。
- 只有完整 `safe-without-approval + ready-to-continue + selected != none` 父合同可以签发 receipt；approval-required、final-submit、external/destructive、needs-evidence、blocked、complete、policy-blocked、no-action 或 metadata gap 只能形成不可派发草稿。
- receipt 固定为 32 字节随机 base64url、服务端 hash 索引、TTL 600 秒、进程内最多 128 条、单次原子消费；过期、淘汰、并发复用或 Gateway 重启全部失效。
- continuation 流固定为用户显式 draft -> queue -> 按 task ID approve/freeze -> 按同一 task ID send；child 使用全新 task/action/session ID，actions 恰好是 receipt selected action 后接 `runAgentLoop`，首次发送尝试后清理 iOS vault，不自动创建、审批、发送、重连、重发或重试 receipt。
- Gateway child preflight 先于 replay、workspace、event、artifact 和 handler；成功后才把最多 6 条/256 KiB 的冻结父 context 快照复制为与父隔离的可变 child session context，先执行 selected action，再基于本轮结果生成新 AgentTrace。任一校验失败均不可重试且无业务副作用。
- raw receipt 仅存在于 wire DTO、iOS 内存 vault、私有 frozen envelope 和 Gateway cache；公开 envelope、UI/VoiceOver、普通 event、artifact/metadata、日志、JUnit、failure summary 和 manifest 一律省略。
- GitHub Actions 新增真实 iPhone Simulator XCTest step；simulator discovery 前预创建 `xctest.log` 并捕获 discovery 错误，XCTest 成功时缺少 `xctest.log` 或 `ClawTests.xcresult` 会在写出摘要后使 packaging 失败。

关键文件：

- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `update_log.md`
- `md/prompt/v0（核心智能能力）/v0.66（可信跨任务多轮续接）.md`

验证结果：

- 本轮工作区修复只允许本地非编译静态检查；未运行编译、build、XCTest、Swift/Gateway smoke、fixture、`xcodebuild` 或 `node --check`。
- v0.66 Swift、Gateway、测试、workflow 和文档实现已存在于当前工作区；GitHub Actions run、commit SHA、run attempt、artifact 名称和 Agent C 复判结论仍待提交后的最新 `origin/main` 云端验收，不预写通过结果。

遗留事项：

- receipt 不跨 Gateway 进程、重启、设备或 10 分钟，不提供持久授权、分布式 exactly-once 或无人值守循环。
- approval 型、最终提交、外部网络、破坏性、证据不足和无动作 recommendation 在 v0.66 没有 continuation dispatch 路径。
- simulator/fixture 只能使用明确测试 provider 或显示不可 live dispatch，不得伪造生产 receipt。
- 当前 baseline 测试未覆盖完整签发拒绝、expiry/eviction/restart、action shape/parameter/policy/side-effect、六种 kind/state/UI 和 Direct/WebSocket 对称矩阵；这些是保持生产合同不变的残余必补覆盖。

### v0.65 / Agent Loop Selected Action Decision Contract 智能体选中动作决策契约

日期：2026-07-26

核心变更：

- `runAgentLoop` 为 selected action 增加 `evidence-first-safe-v1` 固定决策合同，记录固定 reason、候选数量、1-based 序位、候选成员和一致性。
- 三方交集阻断、无需动作、证据恢复、证据不足回退、免审批优先和审批回退使用不同固定 reason；selected 风险、stop 和 handoff 不再被未选候选污染。
- 手机/iPad 对合同字段缺失、未知、越界或 kind/approval/readiness/stop/handoff 组合矛盾 fail closed，禁止 Loop 继续并要求人工复核。
- simulator、Swift Gateway fixture、双 smoke、XCTest、LogicSmoke 和正式协议同步新合同；metadata 不包含完整 allowlist、自然语言 reason 或 artifact payload。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `Tools/ClawGatewayEventFixture.swift`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.65（AgentLoopSelectedActionDecisionContract）.md`

验证结果：

- 本地仅允许非编译静态检查；未运行编译、Swift/Gateway smoke、XCTest、`xcodebuild` 或 `node --check`。
- GitHub Actions 完整验证和 Agent C 最新 run artifact 复判待本轮提交并 push 后执行。

遗留事项：

- 决策合同是 metadata-only 审计证据，不提供密码学绑定，不会自动执行推荐；真实 action 仍必须重新通过全部 Gateway gate。
- simulator/fixture 是确定性预览，不替代真实 Gateway 的 session artifact 上下文选择；真实多轮调度和持久执行状态机仍待后续版本。

### v0.64 / Gateway Unsupported Action Fail Closed 未支持动作固定阻断

日期：2026-07-26

核心变更：

- Gateway 在 approval/envelope allowlist 后增加固定 handler 支持 gate；schema 已知但无 Node handler 的 action 不再进入 generic success。
- schema 未知 action kind 在任何 session/event/artifact 前固定拒绝且不回显原值，避免 Swift 闭合 enum 解码失败。
- unsupported action 固定产生 action-bound `actionFailed`/`failed`、不可重试和 redacted metadata-only `auditLog`，不调用业务 handler、不写业务 artifact、不尝试业务副作用；当前 action 失败后继续后续合法 action。
- Swift Gateway fixture 与固定 9 类 Node handler 合同对齐，无 handler 的已知 action 不再报告 succeeded。
- direct/WebSocket 云端 smoke 要求覆盖状态绑定、脱敏 audit、业务 artifact 禁止集合、副作用与敏感 marker 哨兵、后续合法 action 和 session completion。
- CI 新增 Swift Gateway fixture 编译与 `--self-test`，并纳入 manifest、JUnit 和最终 fail gate。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Tools/ClawGatewayEventFixture.swift`
- `.github/workflows/ci-results.yml`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.64（GatewayUnsupportedActionFailClosed）.md`

验证结果：

- 本地仅允许 `git diff --check` 和静态复核；未运行编译、Swift/Gateway smoke、XCTest、`xcodebuild` 或 `node --check`。
- GitHub Actions 完整验证和 Agent C 最新 run artifact 复判待 v0.64 汇总提交并 push 后执行，不提前标记通过。

遗留事项：

- 固定支持集合与 dispatch 必须持续保持一致；未来新增 handler 时需同步 Gateway、fixture、direct/WebSocket smoke 和文档。
- unsupported audit 是运行审计，不提供密码学执行证明；手机端仍不得把 `sessionCompleted` 解释为每个 action 均成功。

### v0.63 / Mission Run Session Affinity And Scoped Focus 会话归属与聚焦作用域

日期：2026-07-26

核心变更：

- Mission Run resolver 以最新 task 为根，只选择同 task 的 session、live request 和 events；新任务未发送时不再继承旧任务结果、artifact、复核摘要或连接健康。
- summary 新增 task/session 归属和不可见 mission scope；发送前 scope 使用 task ID，发送后使用 session ID。
- iPhone compact 与 iPad/mac 多栏共享聚焦升级为 scope + review kind；切换任务或 task-to-session 后旧聚焦 fail closed，恢复全量详情并显示固定失效提示，不外显 UUID。
- XCTest 和 Swift logic smoke 覆盖连续 Mission A/B、同 scope 聚焦、跨 scope 失效、全量回退及旧敏感命令不外显。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.63（MissionRunSessionAffinityScopedFocus）.md`

验证结果：

- 本地只运行非编译静态检查；build、Swift/Gateway smoke 和 Xcode 验证交给最新 `origin/main` GitHub Actions。
- GitHub Actions 结果包待本轮 push 后由 Agent C 下载并复判 manifest、JUnit、主日志和关键结果。

遗留事项：

- 本轮 scope 是 presentation-layer 身份绑定，不提供密码学证明，也不实现跨设备持久聚焦。
- 真实多轮 agent loop、持久调度和跨 session 状态机仍待后续版本。

### v0.62 / Agent Loop Envelope Allowlist Intersection 智能体下一步白名单交集

日期：2026-07-26

核心变更：

- Gateway 将结构化 `allowedNextActions`、envelope `allowedActionKinds` 与固定支持推荐种类取交集，去重并保持请求顺序；空交集只生成 `none`，不产生越权 iteration 或 safety gate。
- 全阻断路径增加固定 `policy-blocked`、`next-action-policy-blocked`、blocked handoff 和 `blocked-by-next-action-policy`；部分交集只保留 envelope 内动作。
- `agentTrace` metadata 新增固定交集策略、请求/有效/阻断计数和 selected 授权布尔，不暴露完整 allowlist；手机/iPad 对未知、越界、未授权或矛盾证据 fail closed。
- direct/WebSocket smoke 覆盖全阻断和部分交集；XCTest/LogicSmoke 覆盖合法证据及非法 policy、越界/矛盾计数和未授权 selected action。
- 推荐仍是 advisory artifact，任何真实 action 都必须重新通过 Gateway `actionPolicy`、审批、workspace 和 handler allowlist。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `Tools/ClawGatewayEventFixture.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.62（AgentLoopEnvelopeAllowlistIntersection）.md`

验证结果：

- 本地只运行非编译静态检查；build、Swift/Gateway smoke 和 Xcode 验证交给最新 `origin/main` GitHub Actions。
- GitHub Actions 结果包待本轮 push 后由 Agent C 下载并复判 manifest、JUnit、主日志和关键结果。

遗留事项：

- 推荐动作仍不自动执行；真实多轮 agent loop、持久调度和跨 session 状态机继续留待后续版本。
- metadata 是审计证据，不提供密码学绑定；执行时必须始终重新检查当前 envelope/action policy。

### v0.61 / Browser Redirect Host Allowlist 浏览器重定向逐跳白名单

日期：2026-07-26

核心变更：

- Gateway URL 抓取改为手动重定向，最多跟随 5 跳并共享 12 秒总超时；每跳请求前精确检查 HTTP(S)、URL credentials 和 host allowlist。
- 跨 host、非法协议/credentials/Location、超限、HTTP、timeout 和 network 错误均形成 action-bound 脱敏 Browser artifact，只失败当前 action。
- Browser Control metadata 与手机/iPad 复核新增固定 network diagnostic、逐跳检查、计数、阻断和上限证据，不外显 URL、host、Location、header、cookie、正文或 redirect chain。
- direct smoke 覆盖相对跳转和 5 跳边界；direct/WebSocket 都以本地 HTTP fixture 的目标 hit count 为 0 证明跨 host 目标未被联系。
- 本轮保证只覆盖 Gateway fetch；AppleScript 打开后的桌面浏览器导航仍不受 Gateway 逐跳策略控制。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `Tools/ClawGatewayEventFixture.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.61（BrowserRedirectHostAllowlist）.md`

验证结果：

- 本地只运行非编译静态检查；build/smoke 等待云端 workflow。
- GitHub Actions 结果包待本轮 push 后由 Agent C 下载复判。

遗留事项：

- DNS rebinding、CNAME/代理改写、私网 CIDR 和桌面浏览器自身跳转不在本轮覆盖范围。
- Mission Run session affinity、Agent Loop 推荐动作与 envelope allowlist 交集仍待后续迭代。

### v0.60 / Shell Structured Argument Provenance Shell 结构化参数来源

日期：2026-07-26

核心变更：

- Gateway `runShellCommand` 只允许 `toolArguments.shellCommand` 驱动命令；顶层 `shellCommand` / `commandLine` 不再作为 fallback。
- 任一顶层 alias 存在即 action-bound fail closed，包括与合法嵌套命令并存的冲突来源；阻断发生在 parse、binary allowlist 和 `runProcess` 前。
- Shell Safety metadata 增加固定 `invalid-structured-command-source` mode/diagnostic 和 `invalid-command-source-blocked` safety flag，手机/iPad/mac 复核 UI 可明确显示来源阻断。
- direct smoke 覆盖两个 alias 和冲突来源，WebSocket smoke 覆盖 alias-only；测试以伪造 allowlisted executable 和 marker 证明无副作用，并核对事件与阻断 artifact 不泄露命令。
- XCTest/LogicSmoke 覆盖固定诊断、policy review 派生和未知 alias metadata 值不外显。
- 不改变合法 Swift envelope、schema/action/event/artifact kind、Shell allowlist 或审批权限。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.60（ShellStructuredArgumentProvenance）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；build/smoke 等待云端 workflow。
- GitHub Actions 结果包待本轮 push 后由 Agent C 下载复判。

遗留事项：

- Browser redirect host allowlist、Mission Run session affinity、Agent Loop 推荐动作与 envelope allowlist 交集仍待后续迭代。
- 完整 Accessibility bridge、Playwright/browser-use、真实多轮 agent loop 和 artifact payload 复核仍是长期目标。

### v0.59 / Shell Executable Identity Allowlist Shell 可执行文件身份白名单

日期：2026-07-26

核心变更：

- 修复 `CLAW_SHELL_ALLOWLIST` 只检查 `path.basename(parsed.command)`，却执行原始路径造成的同名 executable 绕过。
- Shell 真执行现要求 command token 不含 `/` 或 `\\`，并以裸名称精确命中 allowlist；路径形式统一在 `runProcess` 前按 `allowlist-blocked` 阻断。
- Shell 路径阻断事件改用固定摘要，不回显 raw executable path；metadata 保持 `allowlistMatched=false`、`executionAttempted=false` 和 `binaryAllowlistChecked=true`。
- direct/WebSocket smoke 创建同名 `pwd` 测试 executable，并用副作用标记不存在证明没有执行；正常裸 `pwd` allowlist 真执行继续覆盖。
- 不改变 schema/action/event/artifact kind，不扩大 Shell 权限，不读取 artifact payload。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.59（ShellExecutableIdentityAllowlist）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；build/smoke 等待云端 workflow。
- GitHub Actions 结果包待本轮 push 后由 Agent C 下载复判。

遗留事项：

- `structuredShellCommand()` 仍兼容顶层 `shellCommand` / `commandLine` 别名，与协议规定的仅 `toolArguments.shellCommand` 来源不一致，后续应单独收紧并补 provenance 回归。
- Browser redirect host allowlist、Mission Run session affinity、完整 Accessibility bridge、真实多轮 agent loop 和 artifact payload 复核仍待后续迭代。

### v0.58 / Shell Allowlist Evidence Accuracy Shell 白名单证据准确性

日期：2026-07-26

核心变更：

- 修正 Shell disabled/dry-run 在 binary allowlist 查询前短路，却输出 `binaryAllowlistChecked=true` 的误报；现固定输出 `false`。
- Shell enabled 且实际进入 allowlist 判断、以及 allowlist-enabled 执行路径继续输出 `true`。
- Gateway、simulator、direct/WebSocket smoke、XCTest 和 LogicSmoke 对齐该证据语义。
- 同步 README、协议、flow、test 和 Agent A 提示词；不改变 Shell 权限、allowlist 匹配、schema/action/event/artifact，也不读取 payload。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Claw/Services/ClawStore.swift`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.58（ShellAllowlistEvidenceAccuracy）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；build/smoke 等待云端 workflow。
- GitHub Actions 结果包待本轮 push 后由 Agent C 下载复判。

遗留事项：

- Shell policy diagnostics 仍是 metadata-only 复核，不是自动授权、自动审批或任意命令执行能力。
- 完整 Accessibility bridge、Playwright/browser-use、真实多轮 agent loop 和完整 artifact payload 复核体验仍是后续遗留。

### v0.57 / Operator Strip Live/Policy Lanes 操作条连接与策略格

日期：2026-07-12

核心变更：

- Operator Strip 固定 lanes 扩展为 gateway、live、policy、evidence、review、next。
- Live 格复用 `ClawMissionRunLiveGatewayHealthStrip`；Policy 格复用 `ClawMissionRunPolicyDiagnosticsBoard`。
- `operatorStrip(focusedOn:liveHealth:policyBoard:)` 支持可选注入，Mission Run 传入现有 strip/board。
- XCTest / LogicSmoke 更新 idle lane id 期望。
- 同步 README、flow、test、protocol 和 Agent A 提示词。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.57（OperatorStripLivePolicyLanes）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；build/smoke 等待云端 workflow。
- GitHub Actions 结果包待本轮 push 后由 Agent C 下载复判。

遗留事项：

- lanes 仍是 presentation-layer 摘要，不是自动连接、自动审批或安全裁决。
- 完整 Accessibility bridge、Playwright/browser-use、真实多轮 agent loop 和完整 artifact payload 复核体验仍是后续遗留。


### v0.56 / Control Snapshot Live Health Signal 控制态势连接健康信号

日期：2026-07-12

核心变更：

- `ClawMissionRunControlSnapshotSummary` 增加 live health 只读信号：`liveHealthState`、`liveHealthStatus`、`canAttemptLive`、`hasLiveFallback`、`hasLiveError`、`lastPingSucceeded`。
- `controlSnapshot(focusedOn:liveHealth:)` 可选并入 v0.55 Health Strip；fallback/error 时注解 status/guidance/tone。
- Control Snapshot UI 展示 live 回退/需复核/可 live/ping chips。
- Mission Run 与 Dock 传入 `store.missionRunLiveGatewayHealthStrip`。
- XCTest / LogicSmoke 覆盖 fallback 信号与脱敏。
- 同步 README、flow、test、protocol 和 Agent A 提示词。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.56（ControlSnapshotLiveHealthSignal）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；build/smoke 等待云端 workflow。
- GitHub Actions 结果包待本轮 push 后由 Agent C 下载复判。

遗留事项：

- 不是真实心跳协议、后台保活或配对服务。
- 完整 Accessibility bridge、Playwright/browser-use、真实多轮 agent loop 和完整 artifact payload 复核体验仍是后续遗留。


### v0.55 / Mission Run Live Gateway Health Strip 连接健康条

日期：2026-07-12

核心变更：

- 新增 presentation-layer `ClawMissionRunLiveGatewayHealthStrip`，从既有 `ClawGatewayLiveHealthSummary` 派生 title/status/guidance/healthState/checklist。
- `ClawStore.missionRunLiveGatewayHealthStrip` 供 Mission Run 直接读取，不改 transport 协议。
- compact Mission Run 与 iPad Dock 在 Control Snapshot 后展示健康条；只读展示 preflight、ack、fallback、ping、reconnect 状态。
- XCTest / LogicSmoke 覆盖 fallback/streaming/ping 与脱敏。
- 同步 README、flow/flowchart、test、protocol 和 Agent A 提示词。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.55（MissionRunLiveGatewayHealthStrip）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；build/smoke 等待云端 workflow。
- GitHub Actions 结果包待本轮 push 后由 Agent C 下载复判。

遗留事项：

- 健康条不是真实心跳协议、后台保活、配对服务或自动重连策略。
- 完整 Accessibility bridge、Playwright/browser-use、真实多轮 agent loop 和完整 artifact payload 复核体验仍是后续遗留。


### v0.54 / Mission Run Policy Diagnostics Board 策略诊断看板

日期：2026-07-12

核心变更：

- 新增 presentation-layer `ClawMissionRunPolicyDiagnosticsBoard`，固定汇总 Desktop App、Shell、文件变更、提取来源和浏览器五类策略诊断。
- 看板只从既有 Delivery/Shell/File/Extraction/Browser review 的 diagnostic、retry reason 与 requires* 派生，不读取 payload，不执行 Gateway 动作。
- compact Mission Run 与 iPad Dock 在 Readiness Board 后展示；row 只改变本地聚焦。
- XCTest / LogicSmoke 覆盖 idle、有证据和聚焦路径。
- 同步 README、flow/flowchart、测试说明和 Agent A 提示词。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.54（MissionRunPolicyDiagnosticsBoard）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；build/smoke 等待云端 workflow。
- GitHub Actions 结果包待本轮 push 后由 Agent C 下载复判。

遗留事项：

- 看板不是自动安全裁决、自动审批或 Gateway readiness 授权。
- 完整 Accessibility bridge、Playwright/browser-use、真实多轮 agent loop、live Gateway 保活/配对和完整 artifact 内容复核体验仍是后续遗留。


### v0.53 / Extraction Source Completeness Diagnostics 提取来源完整性诊断

日期：2026-07-12

核心变更：

- Gateway `extractData` metadata 增加固定 `extractionPolicyDiagnostic`、`extractionRetryableReason`、`policyChecked`、`sourceCoverageChecked` 和 `completenessChecked`。
- 诊断枚举覆盖 not-requested、dry-run、empty、partial、complete；retry reason 覆盖 none、provide-source-artifacts、review-empty-extraction、review-partial-extraction。
- `ClawGatewayExtractionCompletenessReviewSummary` 解析 allowlist 新字段并派生 `requiresExtractionPolicyReview`；`"none"` retry reason 不被 cleanValue 丢弃。
- Extraction review row 与复核优先队列展示诊断 chips。
- Simulator、Gateway smoke、XCTest 和 LogicSmoke 覆盖固定键与敏感值拒绝。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.53（ExtractionSourceCompletenessDiagnostics）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；build/smoke 等待云端 workflow。
- GitHub Actions 结果包待本轮 push 后由 Agent C 下载复判。

遗留事项：

- 当前 Extraction Source Completeness Diagnostics 是 metadata-only 复核，不是自动补源或完整 row payload viewer。
- 完整 macOS Accessibility bridge、Playwright/browser-use、真实多轮 agent loop、live Gateway 保活/配对和完整 artifact 内容复核体验仍是后续遗留。


### v0.52 / File Change Policy Diagnostics 文件变更策略诊断

日期：2026-07-12

核心变更：

- Gateway `manageFiles` metadata 增加固定 `filePolicyDiagnostic`、`fileRetryableReason`、`policyChecked`、`workspacePolicyChecked` 和 `pathPolicyChecked`。
- 诊断枚举覆盖 not-requested、path-escape-blocked、workspace-write-failed、write-attempted 和 write-succeeded；retry reason 覆盖 none、provide-workspace-path、fix-workspace-scope、retry-write 和 review-write-failure。
- `ClawGatewayFileChangeSafetyReviewSummary` 解析 allowlist 新字段并派生 `requiresFilePolicyReview`；UI chips 与复核优先队列同步。
- Simulator、Gateway smoke、XCTest 和 LogicSmoke 覆盖固定键、成功写入、路径逃逸、写入失败、敏感值拒绝。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；不扩大 workspace 写权限，不读取 raw path/content/diff。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.52（FileChangePolicyDiagnostics）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；build/smoke 等待云端 workflow。
- GitHub Actions 结果包待本轮 push 后由 Agent C 下载复判。

遗留事项：

- 当前 File Change Policy Diagnostics 是 metadata-only 复核，不是完整 payload viewer 或跨 workspace 写权限扩展。
- 完整 macOS Accessibility bridge、Playwright/browser-use、真实多轮 agent loop、live Gateway 保活/配对和完整 artifact 内容复核体验仍是后续遗留。


### v0.51 / Shell Command Policy Diagnostics Shell 命令策略诊断

日期：2026-07-12

核心变更：

- Gateway `runShellCommand` commandOutput metadata 增加固定 `shellPolicyDiagnostic`、`shellRetryableReason`、`policyChecked`、`binaryAllowlistChecked` 和 `structuredCommandChecked`。
- Shell 策略诊断枚举覆盖 not-requested、missing-structured-command、command-parse-failed、dry-run、allowlist-blocked、execution-attempted 和 execution-failed；retry reason 覆盖 none、provide-structured-command、fix-command-parse、enable-shell、configure-shell-allowlist、allow-shell-binary、automation-failed 和 review-execution。
- `ClawGatewayShellCommandSafetyReviewSummary` 解析并 allowlist 新字段，`compactStatus` 纳入 diagnostic，`requiresShellPolicyReview` 用 metadata 缺失、阻断、失败和 retry reason 派生人工复核需求。
- Shell Safety review row 展示 policy diagnostic、retry reason 和 policy/binary/structured checked chips；复核优先队列改为提示“确认 Shell 策略、allowlist 和执行状态”。
- Simulator、Gateway direct/WebSocket smoke、XCTest 和 Swift logic smoke 覆盖固定键、dry-run、missing structured command、allowlist 真执行、敏感字段丢弃和 metadata 缺失回退。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不读取 Gateway `file://` payload，不展示 raw command、stdout/stderr、cwd、token/header 或 `toolArguments`。
- 本轮不新增 schema/event/action/artifact kind，不扩大 Gateway Shell 权限，不实现自然语言 Shell 或自动执行。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.51（ShellCommandPolicyDiagnostics）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；Swift logic smoke、iOS build、XCTest 编译、Gateway smoke 和 `node --check` 均等待云端 workflow 覆盖。
- GitHub Actions 结果包待本轮提交并 push 后由 Agent C 下载复判。

遗留事项：

- 当前 Shell Command Policy Diagnostics 是 metadata-only 复核，不是自然语言 Shell、自动 allowlist 放行或完整 command payload viewer。
- 完整 macOS Accessibility bridge、Playwright/browser-use 兼容控制器、真实多轮 agent loop、live Gateway 后台保活/真实心跳协议/配对和完整 artifact 内容复核体验仍是后续遗留。


### v0.50 / Desktop App Policy Diagnostics 桌面 App 策略诊断

日期：2026-07-07

核心变更：

- Gateway `operateDesktopApp` Delivery Safety metadata 增加固定 `desktopPolicyDiagnostic`、`desktopRetryableReason`、`automationAttempted`、`appPolicyChecked` 和 `keyPolicyChecked`。
- 桌面策略诊断枚举覆盖 not-requested、dry-run、platform-unavailable、missing-target、app-blocked、key-blocked、automation-attempted 和 automation-failed；retry reason 覆盖 none、enable-desktop-control、requires-macos、provide-target-app、allow-desktop-app、allow-desktop-key、automation-failed 和 user-final-submit。
- `ClawGatewayDeliverySafetyReviewSummary` 解析并 allowlist 新字段，`compactStatus` 纳入 policy 诊断，`requiresDesktopPolicyReview` 用 metadata 缺失、阻断、失败、自动化尝试和最终提交闸门派生人工复核需求。
- Delivery Safety review row 展示 policy diagnostic、retry reason、automation attempted、app policy checked 和 key policy checked chips；复核优先队列改为提示“确认桌面策略和提交闸门”。
- Simulator、Gateway direct/WebSocket smoke、XCTest 和 Swift logic smoke 覆盖固定键、desktop dry-run、desktop app policy blocked、message draft not-requested、敏感字段丢弃和 metadata 缺失回退。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不读取 Gateway `file://` payload，不展示 target app、allowlist 值、key sequence、paste text、草稿正文、osascript stdout/stderr、token/header 或 `toolArguments`。
- 本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 桌面控制权限，不实现新点击、输入、视觉定位、控件级 Accessibility 动作或自动提交。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.50（DesktopAppPolicyDiagnostics）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；Swift logic smoke、iOS build、XCTest 编译、Gateway smoke 和 `node --check` 均等待云端 workflow 覆盖。
- GitHub Actions 结果包待本轮提交并 push 后由 Agent C 下载复判。

遗留事项：

- 当前 Desktop App Policy Diagnostics 是 metadata-only 复核，不是完整 macOS Accessibility bridge、真实控件级点击/输入、视觉定位、自动提交或自动授权机制。
- Playwright/browser-use 兼容控制器、真实多轮 agent loop、live Gateway 后台保活/真实心跳协议/配对和完整 artifact 内容复核体验仍是后续遗留。

### v0.49 / Mac Accessibility Signal Quality 观察信号质量

日期：2026-07-07

核心变更：

- Gateway `accessibilityTree` artifact event metadata 增加固定 `signalQuality`、`evidenceTier`、`controlCoverage`、`valuesOmitted`、`passwordFieldsOmitted`、`rawTextOmitted` 和 `actionExecutionSupported=false`。
- signal quality 从既有 `mode` 派生：not-requested、dry-run、window-metadata、accessibility-summary、permission-missing 或 platform-unavailable；evidence tier 固定为 missing/degraded/satisfied，control coverage 固定为 none/window-only/candidate-controls。
- `ClawGatewayAccessibilityReviewSummary` 解析并 allowlist 新字段，`compactStatus` 和 `requiresSignalReview` 可提示信号质量缺口、降级证据或异常 action support。
- Accessibility review row 展示 signal quality、evidence tier、control coverage、省略标志和 observe-only 状态；复核优先队列改为提示“确认 Accessibility 信号质量和省略标志”。
- Simulator、direct smoke、WebSocket smoke、XCTest 和 Swift logic smoke 覆盖固定键、枚举派生、metadata 缺失回退、敏感字段丢弃和 dry-run Accessibility 降级证据。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不读取 Gateway `file://` payload，不展示前台 App 名、窗口标题、控件 label/description、raw text、密码字段值、token/header 或 `toolArguments`。
- 本轮不新增 schema/event/action/artifact kind，不扩大 Gateway Accessibility 权限，不实现点击、输入、表单提交、任意选择器或完整 Accessibility bridge。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.49（MacAccessibilitySignalQuality）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；Swift logic smoke、iOS build、XCTest 编译、Gateway smoke 和 `node --check` 均等待云端 workflow 覆盖。
- GitHub Actions 结果包待本轮提交并 push 后由 Agent C 下载复判。

遗留事项：

- 当前 Accessibility Signal Quality 是 metadata-only 复核，不是完整 macOS Accessibility bridge、控件级点击/输入、表单提交、视觉定位、默认敏感区域打码或自动授权机制。
- Playwright/browser-use 兼容控制器、真实多轮 agent loop、live Gateway 后台保活/真实心跳协议/配对和完整 artifact 内容复核体验仍是后续遗留。

### v0.48 / Browser Control Policy Diagnostics 浏览器策略诊断

日期：2026-07-07

核心变更：

- Gateway `controlBrowser` 的 `browserTrace` 和 `browser-control-*.json` artifact event metadata 增加固定 `policyDiagnostic`、`retryableReason`、`openAttempted`、`appPolicyChecked` 和 `hostPolicyChecked`。
- 诊断枚举覆盖 not-requested、dry-run、platform-unavailable、app-blocked、host-blocked、opened 和 automation-failed；retry reason 覆盖 none、enable-browser-control、requires-macos、allow-browser-app、allow-browser-host 和 automation-failed。
- `ClawGatewayBrowserControlReviewSummary` 解析新增字段并通过 allowlist 丢弃不安全值，`requiresPolicyReview` 用 metadata 缺失、阻断、失败、超时和固定诊断派生是否需要人工复核。
- Browser Control review row 展示策略诊断、重试原因、open attempt、app/host policy checked chips；复核优先队列用策略诊断状态提示“确认策略诊断和重试原因”。
- Gateway direct/WebSocket smoke、XCTest 和 Swift logic smoke 增加 policy diagnostics、固定键和敏感字符串不外显断言；本轮仍不读取 Gateway `file://` payload，不展示 raw URL、search query、HTML/page text、browser app name、host、allowlist 值、stdout/stderr、token/header 或 `toolArguments`。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 浏览器权限。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.48（BrowserControlPolicyDiagnostics）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；Swift logic smoke、iOS build、XCTest 编译、Gateway smoke 和 `node --check` 均等待云端 workflow 覆盖。
- GitHub Actions 结果包待本轮提交并 push 后由 Agent C 下载复判。

遗留事项：

- 当前 Browser Control Policy Diagnostics 是 metadata-only 复核，不是 Playwright/browser-use 控制器、网页正文 viewer、真实点击/表单执行或自动放权机制。
- 完整 macOS Accessibility bridge、Playwright/browser-use 兼容控制器、真实多轮 agent loop、live Gateway 后台保活/真实心跳协议/配对和完整 artifact 内容复核体验仍是后续遗留。

### v0.47 / Approval Fast Lane 审批快车道

日期：2026-07-07

核心变更：

- 新增 `ClawMissionRunApprovalFastLaneSummary`，`ClawMissionRunSummary` 可从既有 Approval Queue 派生首要人工确认入口、审批/动作标签、metadata 状态和固定检查点。
- Fast Lane 在 `ClawMissionApprovalQueueView` 顶部展示，compact Mission Run 和 iPad/mac 右侧 Dock 复用同一摘要；按钮只聚焦对应复核项或状态项。
- Fast Lane 不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、`auditTrail` 原文、文件内容、命令输出、stdout/stderr、diff、网页正文、草稿正文、token、header、cookie 或 secret。
- XCTest 和 Swift logic smoke 覆盖 idle、发送前审批、发送后首要确认、detail 聚焦、状态级聚焦、Shell 高风险和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.47（ApprovalFastLane）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；Swift logic smoke、iOS build、XCTest 编译、Gateway smoke 和 `node --check` 均等待云端 workflow 覆盖。
- GitHub Actions 结果包待本轮提交并 push 后由 Agent C 下载复判。

遗留事项：

- 当前 Approval Fast Lane 是手机端 presentation-layer 审批快车道，不是自动审批、批量审批、自动发送、自动重试、自动继续、自动安全裁决或完整 payload viewer。
- Browser Control Policy Diagnostics、macOS Accessibility 信号质量和 AgentLoop continuation proposal 仍是后续候选。

### v0.46 / Mac Agent Control Snapshot 控制态势快照

日期：2026-07-07

核心变更：

- 新增 `ClawMissionRunControlSnapshotSummary`，`ClawMissionRunSummary` 可从 Handoff Brief、Continuation Gate、Review Radar、Approval Queue、Loop 继续态势、Focus Context 和 Operator Strip 派生一眼可读的 Mac 控制态势。
- Snapshot 区分 idle、focused、blocked、waiting-human、retryable、metadata-pending、ready-to-continue 和 reviewable 状态，汇总是否需人工、是否 metadata 缺口、是否阻断/可重试、是否可由用户显式触发下一轮。
- compact Mission Run 在 Operator Strip 前展示 Snapshot；iPad/mac 右侧 Mission Review Detail Dock 也在顶部上下文后复用同一 Snapshot 和共享聚焦状态。
- Snapshot 按钮只改变本地复核聚焦，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、`auditTrail` 原文、文件内容、命令输出、stdout/stderr、diff、网页正文、草稿正文、token、header、cookie 或 secret。
- XCTest 和 Swift logic smoke 覆盖 idle、发送前审批等待、发送后控制态势、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.46（MacAgentControlSnapshot）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；Swift logic smoke、iOS build、XCTest 编译、Gateway smoke 和 `node --check` 均等待云端 workflow 覆盖。
- GitHub Actions 结果包待本轮提交并 push 后由 Agent C 下载复判。

遗留事项：

- 当前 Control Snapshot 是手机端 presentation-layer 控制态势快照，不是自动执行授权、自动审批、自动重试、自动继续、自动安全裁决、完整 payload viewer 或完整 Gateway readiness。
- 完整 macOS Accessibility bridge、Playwright/browser-use 兼容控制器、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.45 / Mac Agent Handoff Brief 人工交接简报

日期：2026-07-07

核心变更：

- 新增 `ClawMissionRunHandoffBriefItem` 和 `ClawMissionRunHandoffBriefSummary`，`ClawMissionRunSummary` 可从 Review Radar、Continuation Gate、Next Step Deck、Run Timeline、Approval Queue、Focus Context 和 Loop 继续态势派生人工交接简报。
- Brief 固定汇总阻断/可重试、人工确认、metadata/证据缺口、Loop 下一轮和抽查复核五个 item，统计 done/blocked/human/retryable/metadata/loop/optional 信号；idle 不虚构 item，AgentTrace 可继续时仍提示用户显式触发下一轮。
- compact Mission Run 在 Review Radar 后展示 Brief；iPad/mac 右侧 Mission Review Detail Dock 也在 Review Radar 后、Review Trail 前复用同一 Brief 和共享聚焦状态。
- Brief row 只改变本地聚焦，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、`auditTrail` 原文、文件内容、命令输出、stdout/stderr、diff、网页正文、草稿正文、token、header、cookie 或 secret。
- XCTest 和 Swift logic smoke 覆盖 idle、发送前审批、发送后五 item、primary 排序、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险/可重试、AgentTrace 可继续和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.45（MacAgentHandoffBrief）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；Swift logic smoke、iOS build、XCTest 编译、Gateway smoke 和 `node --check` 均等待云端 workflow 覆盖。
- GitHub Actions 结果包待本轮提交并 push 后由 Agent C 下载复判。

遗留事项：

- 当前 Mac Agent Handoff Brief 是手机端 presentation-layer 人工交接简报，不是自动执行计划、自动审批、自动重试、自动继续、自动安全裁决、完整 payload viewer 或完整 Gateway readiness。
- 完整 macOS Accessibility bridge、Playwright/browser-use 兼容控制器、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.44 / Mac Agent Review Radar 复核雷达

日期：2026-07-07

核心变更：

- 新增 `ClawMissionRunReviewRadarSector` 和 `ClawMissionRunReviewRadarSummary`，`ClawMissionRunSummary` 可从 Review Readiness、Evidence Coverage Map、Action Preflight Matrix、Approval Queue、Continuation Gate、Loop 继续态势和 Mac Agent Readiness Board 派生复核雷达。
- Radar 固定汇总安全复核、证据覆盖、执行状态、人工交接和 Loop 继续五个 sector，统计 priority/ready/blocked/human/metadata/loop 信号；idle 不虚构 sector，AgentTrace 可继续时仍提示用户显式触发下一轮。
- compact Mission Run 在 Continuation Gate 后展示 Radar；iPad/mac 右侧 Mission Review Detail Dock 也在 Continuation Gate 后、Review Trail 前复用同一 Radar 和共享聚焦状态。
- Radar row 只改变本地聚焦，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、`auditTrail` 原文、文件内容、命令输出、stdout/stderr、diff、网页正文、草稿正文、token、header、cookie 或 secret。
- XCTest 和 Swift logic smoke 覆盖 idle、发送前审批、发送后五 sector、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险/可重试、AgentTrace 可继续和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.44（MacAgentReviewRadar）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；Swift logic smoke、iOS build、XCTest 编译、Gateway smoke 和 `node --check` 均等待云端 workflow 覆盖。
- GitHub Actions 结果包待本轮提交并 push 后由 Agent C 下载复判。

遗留事项：

- 当前 Mac Agent Review Radar 是手机端 presentation-layer 复核雷达，不是自动执行授权、自动审批、自动重试、自动继续、自动安全裁决、完整 payload viewer 或完整 Gateway readiness。
- 完整 macOS Accessibility bridge、Playwright/browser-use 兼容控制器、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.43 / Mac Agent Continuation Gate 继续闸门

日期：2026-07-07

核心变更：

- 新增 `ClawMissionRunContinuationGateItem` 和 `ClawMissionRunContinuationGateSummary`，`ClawMissionRunSummary` 可从 Next Step Deck、Run Timeline、Approval Queue、Review Readiness、Loop 继续态势和 Mac Agent Readiness Board 派生继续闸门。
- Gate 固定汇总阻断/可重试、人工确认、metadata/证据缺口、Loop 可继续和抽查入口；idle 不虚构可继续状态，AgentTrace 可继续时仍提示用户显式触发下一轮。
- compact Mission Run 在 Run Timeline 后展示 Gate；iPad/mac 右侧 Mission Review Detail Dock 也在 Run Timeline 后、Review Trail 前复用同一 Gate 和共享聚焦状态。
- Gate row 只改变本地聚焦，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、`auditTrail` 原文、文件内容、命令输出、stdout/stderr、diff、网页正文、草稿正文、token、header、cookie 或 secret。
- XCTest 和 Swift logic smoke 覆盖 idle、发送前审批闸门、发送后人工/metadata/Loop 闸门、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险/可重试和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.43（MacAgentContinuationGate）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；Swift logic smoke、iOS build、XCTest 编译、Gateway smoke 和 `node --check` 均等待云端 workflow 覆盖。
- GitHub Actions 结果包待本轮提交并 push 后由 Agent C 下载复判。

遗留事项：

- 当前 Continuation Gate 是手机端 presentation-layer 继续闸门，不是自动执行授权、自动审批、自动重试、自动继续、完整 payload viewer、完整 forensic timeline 或完整 Gateway readiness。
- 完整 macOS Accessibility bridge、Playwright/browser-use 兼容控制器、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.42 / Mac Agent Run Timeline 执行时间线

日期：2026-07-07

核心变更：

- 新增 `ClawMissionRunTimelineStep` 和 `ClawMissionRunTimelineSummary`，`ClawMissionRunSummary` 可从动作预检矩阵、证据覆盖图、审批队列和复核态势派生 Mac Agent Run Timeline。
- Timeline 按 action 顺序串起计划/审批、Gateway result、metadata、证据同步、阻断/可重试和人工交接摘要；idle 不虚构 step，pre-send 不伪装 Gateway 已执行。
- compact Mission Run 在 Next Step Deck 后、指标网格前展示 Timeline；iPad/mac 右侧 Mission Review Detail Dock 也在 Next Step Deck 后、Review Trail 前复用同一 Timeline 和共享聚焦状态。
- Timeline row 只改变本地聚焦，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、`auditTrail` 原文、文件内容、命令输出、stdout/stderr、diff、网页正文、草稿正文、token 或 header。
- XCTest 和 Swift logic smoke 覆盖 idle、发送前 action/审批时间线、发送后 action/evidence/handoff step、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险/可重试和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.42（MacAgentRunTimeline）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；Swift logic smoke、iOS build、XCTest 编译、Gateway smoke 和 `node --check` 均等待云端 workflow 覆盖。
- GitHub Actions 结果包待本轮提交并 push 后由 Agent C 下载复判。

遗留事项：

- 当前 Mac Agent Run Timeline 是手机端 presentation-layer 执行时间线，不是自动执行授权、自动审批、自动重试、自动继续、完整 payload viewer、完整 forensic timeline 或完整 Gateway readiness。
- 完整 macOS Accessibility bridge、Playwright/browser-use 兼容控制器、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.41 / Mac Agent Next Step Deck 下一步候选卡组

日期：2026-07-07

核心变更：

- 新增 `ClawMissionRunNextStepCandidate` 和 `ClawMissionRunNextStepDeck`，`ClawMissionRunSummary` 可从复核态势、下一步复核行动、Loop 继续态势、Mac Agent 就绪、动作预检、证据覆盖和审批队列派生下一步候选卡组。
- Deck 固定汇总人工确认、证据补齐、失败复核、Loop 下一步和抽查复核候选；idle 不虚构候选，pre-send 只展示手机审批/action 支撑，AgentTrace 可继续时仍提示用户显式触发下一轮。
- compact Mission Run 在 Evidence Coverage Map 后、指标网格前展示 Deck；iPad/mac 右侧 Mission Review Detail Dock 也在 Coverage Map 后、Review Trail 前复用同一 Deck 和共享聚焦状态。
- Deck row 只改变本地聚焦，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、文件内容、命令输出、diff、网页正文或草稿正文。
- XCTest 和 Swift logic smoke 覆盖 idle、发送前审批候选、发送后候选排序、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险/可重试、AgentTrace 可继续和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.41（MacAgent下一步候选卡组）.md`
- `update_log.md`

验证结果：

- 本地只运行非编译静态检查；Swift logic smoke、iOS build、XCTest 编译、Gateway smoke 和 `node --check` 均等待云端 workflow 覆盖。
- GitHub Actions 结果包待本轮提交并 push 后由 Agent C 下载复判。

遗留事项：

- 当前 Mac Agent Next Step Deck 是手机端 presentation-layer 候选卡组，不是自动计划器、自动执行授权、自动审批、自动重试、自动继续、完整 payload viewer 或完整 Gateway readiness。
- 完整 macOS Accessibility bridge、Playwright/browser-use 兼容控制器、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.40 / Mac Agent Evidence Coverage Map 证据覆盖图

日期：2026-07-07

核心变更：

- 新增 `ClawMissionRunEvidenceCoverageItem` 和 `ClawMissionRunEvidenceCoverageMap`，`ClawMissionRunSummary` 可从 Action Preflight Matrix、Artifact Evidence Index、Payload Safety Ledger 和复核优先队列派生证据覆盖图。
- Coverage Map 按复核域汇总 action 支撑、artifact 证据、metadata、payload 边界、人工复核和 metadata 缺口；发送前可显示 action/审批支撑但不伪装 Gateway 证据已覆盖，发送后按 Browser/File/Shell/Delivery/AgentTrace 等复核域汇总覆盖状态。
- compact Mission Run 在 Action Preflight Matrix 后展示 Coverage Map；iPad/mac 右侧 Mission Review Detail Dock 也在 Matrix 后、Review Trail 前复用同一 Coverage Map 和共享聚焦状态。
- Coverage Map row 只改变本地聚焦，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、文件内容、命令输出、diff、网页正文或草稿正文。
- XCTest 和 Swift logic smoke 覆盖 idle、发送前 action/审批支撑、发送后 action/evidence/metadata/payload count、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.40（MacAgentEvidenceCoverageMap）.md`
- `update_log.md`

验证结果：

- 2026-07-07 人工规则更新：后续默认禁止本地编译、本地 build、本地 xcodebuild、本地 Swift logic smoke、本地 Gateway smoke 和本地 `node --check`；本轮最终验收以 GitHub Actions 结果包为准。
- 本地只保留非编译静态检查记录；Swift logic smoke、iOS build、XCTest 编译、Gateway smoke 和 `node --check` 均等待云端 workflow 覆盖。
- GitHub Actions 结果包待本轮提交并 push 后由 Agent C 下载复判。

遗留事项：

- 当前 Mac Agent Evidence Coverage Map 是手机端 presentation-layer 证据覆盖图，不是完整 payload viewer、自动安全裁决、完整审计链、自动执行授权或完整 Gateway readiness。
- 完整 macOS Accessibility bridge、Playwright/browser-use 兼容控制器、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.39 / Mac Gateway Action Preflight Matrix 动作预检矩阵

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunActionPreflightItem` 和 `ClawMissionRunActionPreflightMatrix`，`ClawMissionRunSummary` 可从当前 task action、actionID 关联的 Gateway result、审批级别、结构化参数 presence 和既有复核域派生 action 级预检矩阵。
- Matrix 按 action 顺序展示可派发、阻断、metadata 待同步、降级、人工确认和可重试状态；发送前手机审批聚焦 `approval`，发送后 Gateway result 按 action kind 聚焦 Browser/File/Shell/Delivery/AgentTrace 等复核域。
- compact Mission Run 在 Mac Agent Readiness Board 后展示 Matrix；iPad/mac 右侧 Mission Review Detail Dock 也复用同一 Matrix 和共享聚焦状态。
- Matrix row 只改变本地聚焦，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不读取或展示 action `toolArguments` 原文、artifact `reference`、Gateway `file://` payload、文件内容、命令输出、diff、网页正文或草稿正文。
- XCTest 和 Swift logic smoke 覆盖 idle、发送前审批聚焦、发送后 action kind 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦、可重试状态和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.39（MacGatewayActionPreflightMatrix）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`；仅有 CoreSimulator 服务不可用警告。
- 本地无签名 `build-for-testing` 通过，输出 `** TEST BUILD SUCCEEDED **`；仅有 CoreSimulator 服务不可用警告。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- GitHub Actions run `28806689288` attempt `1` 对 commit `9a8253f8457bcf185cd2afab3efae4e1de76ed6d` 通过，artifact `claw-ci-v0.2-main-9a8253f8457b-run28806689288-attempt1` 已下载到 `/private/tmp/claw-c-review-28806689288/` 并核对 manifest、JUnit、failure summary、Swift logic smoke、Gateway direct/WebSocket smoke、node/plutil/git diff check、xcodebuild 日志和 `Claw.xcresult/Info.plist`。

遗留事项：

- 当前 Mac Gateway Action Preflight Matrix 是手机端 presentation-layer 预检矩阵，不是自动执行授权、自动审批、自动安全裁决、完整 Gateway readiness、真实 per-action payload viewer 或 action metadata 证明系统。
- 完整 macOS Accessibility bridge、Playwright/browser-use 兼容控制器、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.38 / Mac Agent Readiness Board 就绪看板

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunMacAgentReadinessItem` 和 `ClawMissionRunMacAgentReadinessBoard`，`ClawMissionRunSummary` 可从既有 capability、Accessibility、AgentTrace/Loop、复核态势和审批队列派生 Mac Agent 就绪看板。
- Board 固定展示连接回执、桌面能力、屏幕观察、Loop 继续和人工闸门五类 row，并统计 ready、blocked、metadata 待同步和人工确认数量。
- compact Mission Run 在 Loop 继续态势后展示 Board；iPad/mac 右侧 Mission Review Detail Dock 也复用同一 Board 和共享聚焦状态。
- Board row 只改变本地聚焦，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不读取 artifact `reference`、Gateway `file://` payload、文件内容、命令输出、diff、网页正文、草稿正文或 `toolArguments`。
- XCTest 和 Swift logic smoke 覆盖 idle、发送后 readiness、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.38（MacAgentReadinessBoard）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`；仅有 CoreSimulator 服务不可用警告。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- GitHub Actions run `28804589869` attempt `1` 对 commit `9f4eae91891b58f397f9e26b16ce6665bef728fa` 通过，artifact `claw-ci-v0.2-main-9f4eae91891b-run28804589869-attempt1` 已下载到 `/private/tmp/claw-c-review-28804589869/` 并核对 manifest、JUnit、failure summary、Swift logic smoke、Gateway direct/WebSocket smoke、node/plutil/git diff check、xcodebuild 日志和 `Claw.xcresult/Info.plist`。

遗留事项：

- 当前 Mac Agent Readiness Board 是手机端 presentation-layer 就绪看板，不是完整 macOS Accessibility bridge、浏览器真实点击/表单控制、自动执行授权、自动审批、自动安全裁决或完整 Gateway readiness。
- 完整 macOS Accessibility bridge、Playwright/browser-use 兼容控制器、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.37 / Artifact Payload Safety Ledger 载荷安全账本

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunPayloadSafetyLedgerItem` 和 `ClawMissionRunPayloadSafetyLedgerSummary`，`ClawMissionRunSummary` 可从已有 detail review 的 `hasMetadata` 和白名单 `safetyFlags` 派生 payload 边界账本。
- Ledger 统计 payload 未读取、metadata-only、保护/省略信号和 metadata 缺口；item 只使用固定标题、状态、guidance、icon、reviewKind、计数和聚焦状态。
- compact Mission Run 在 Artifact 证据索引后展示 Payload Safety Ledger；iPad/mac 右侧 Mission Review Detail Dock 在 Review Trail 后展示同一 Ledger。
- Ledger row 只改变本地聚焦，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续；不读取 artifact `reference`、Gateway `file://` payload、文件内容、命令输出、diff、网页正文、草稿正文或 `toolArguments`。
- XCTest 和 Swift logic smoke 覆盖 idle、发送后 payload 边界计数、detail 聚焦、状态级聚焦回退、过期聚焦回退、Shell 高风险聚焦和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.37（ArtifactPayloadSafetyLedger）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`；仅有 CoreSimulator 服务不可用警告。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- GitHub Actions run `28799070479` attempt `1` 对 commit `1f07fc3cd91a35a96111aae8eb3fb0574e0a6bca` 通过，artifact `claw-ci-v0.2-main-1f07fc3cd91a-run28799070479-attempt1` 已下载到 `/private/tmp/claw-c-review-28799070479/` 并核对 manifest、JUnit、failure summary、Swift logic smoke、Gateway direct/WebSocket smoke、node/plutil/git diff check 和 xcodebuild 日志。
- 后续验证记录 commit `260b32380860bec26170ed7eb6f56532bc830dda` 的 run `28799863898` 在 `swift-logic-smoke` 因 `Tools/LogicSmoke.swift` 大表达式 type-check 压力失败；追加 commit `c1a8d661dfb9c6e47336868e9d33613f81ca8fb3` 将相关断言拆成显式中间数组和字符串。
- GitHub Actions run `28801091805` attempt `1` 对 commit `c1a8d661dfb9c6e47336868e9d33613f81ca8fb3` 通过，artifact `claw-ci-v0.2-main-c1a8d661dfb9-run28801091805-attempt1` 已下载到 `/private/tmp/claw-c-review-28801091805/` 并核对 manifest、JUnit、failure summary、Swift logic smoke、Gateway direct/WebSocket smoke、node/plutil/git diff check、xcodebuild 日志和 `Claw.xcresult/Info.plist`。

遗留事项：

- 当前 Payload Safety Ledger 是手机端 presentation-layer 载荷边界账本，不是完整 artifact payload viewer、自动安全裁决、恶意检测器、完整审计链或 Gateway readiness。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.36 / Mission Approval Queue 审批队列

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunApprovalQueueItem` 和 `ClawMissionRunApprovalQueueSummary`，`ClawMissionRunSummary` 可从当前有效聚焦项和 approval queue 派生可展示队列摘要。
- `ClawStore.missionRunSummary` 从现有 task action、blocked action、Gateway waiting/failed/retryable result、Delivery Safety review、AgentTrace review 和复核优先队列派生 Mission Approval Queue。
- 队列覆盖发送前手机审批、发送后 Gateway 确认、最终提交闸门、AgentTrace 交接、失败/可重试复核和策略阻断；已发送后的任务审批行降级为 status-only 抽查，不压过 Gateway 当前确认点。
- compact Mission Run 和 iPad/mac 右侧 Mission Review Detail Dock 在 Review Trail 后展示 Approval Queue；队列行只改变本地聚焦，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续。
- XCTest 和 Swift logic smoke 覆盖 idle、发送前审批、发送后 Gateway/Delivery/AgentTrace 确认、状态级聚焦、Shell 高风险聚焦、排序稳定和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.36（MissionApprovalQueue）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`；仅有 CoreSimulator 服务不可用警告。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- GitHub Actions run `28793530009` attempt `1` 对 commit `50167248a7ede45fbcf3e608da6262611fe4ff4a` 通过，artifact `claw-ci-v0.2-main-50167248a7ed-run28793530009-attempt1` 已下载到 `/private/tmp/claw-c-review-28793530009/` 并核对 manifest、JUnit、failure summary、Swift logic smoke、Gateway direct/WebSocket smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前 Approval Queue 是手机端 presentation-layer 审批/确认队列，不是自动审批、自动执行、自动安全裁决、完整 artifact payload viewer、完整审计链或 Gateway readiness。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.35 / Mission Review Trail 复核路径

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunEvidenceTrailSummary` 和 `ClawMissionRunEvidenceTrailStep`，`ClawMissionRunSummary` 可从 Artifact 证据索引、复核态势摘要、下一步复核行动、复核优先队列和当前有效聚焦项派生固定四步复核路径。
- Trail 以“证据覆盖 / metadata 状态 / 优先复核 / 下一步”串起人工复核顺序，覆盖 idle、detail 聚焦、状态级聚焦和过期聚焦回退。
- Mission Run 主面板在 Artifact 证据索引后展示 Trail；regular iPad/mac 右侧 Mission Review Detail Dock 也复用同一 Trail 并跟随左侧聚焦状态。
- Trail row 只改变本地聚焦或展示状态，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续。
- XCTest 和 Swift logic smoke 覆盖 Trail 的 idle、四步顺序、证据/metadata/优先/下一步计数、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.35（MissionReviewTrail）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`；仅有 CoreSimulator 服务不可用警告。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- GitHub Actions run `28789371045` attempt `1` 对 commit `6282fe833cafdda060d74ab0a2e246a21f22f6cf` 通过，artifact `claw-ci-v0.2-main-6282fe833caf-run28789371045-attempt1` 已下载到 `/private/tmp/claw-c-review-28789371045/` 并核对 manifest、JUnit、failure summary、Swift logic smoke、Gateway direct/WebSocket smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前 Review Trail 是手机端 presentation-layer 复核路径，不是完整证据链、审计链、forensic timeline、artifact payload viewer、自动执行、自动审批、自动安全裁决或 Gateway readiness。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.34 / iPad Mission Review Detail Dock

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunReviewDetailDockSummary`，`ClawMissionRunSummary` 可从 raw focus、复核优先队列和可用 detail review 派生 regular 工作台右侧 Dock 展示模式。
- `activeReviewFocus(from:)` 统一收敛当前聚焦：detail 和队列状态项保留，未知/过期聚焦回退 nil，避免 UI 把无效聚焦当作 detail row。
- iPad/mac regular 工作台把 `focusedReviewKind` 提升到左右栏共享，左侧 Mission Run 的复核选择会同步到右侧 “Mission 复核详情” Dock；compact iPhone 保持单栏本地聚焦状态。
- 抽出 `ClawMissionDetailReviewRows`，左侧 Mission Run 和右侧 Dock 复用同一套 metadata-only 安全摘要 row。
- Dock 覆盖无证据、全量详情、detail 聚焦、状态级聚焦、过期聚焦和 Shell 高风险聚焦；按钮只改变本地聚焦或清除聚焦，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续。
- XCTest 和 Swift logic smoke 覆盖 Dock 派生、聚焦共享相关模型回退和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.34（iPadMissionReviewDetailDock）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`；仅有 CoreSimulator 服务不可用警告。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- GitHub Actions run `28787504818` attempt `1` 对 commit `2b8ab8e494e156808d2615e5e69b215109ee15af` 通过，artifact `claw-ci-v0.2-main-2b8ab8e494e1-run28787504818-attempt1` 已下载到 `/private/tmp/claw-c-review-28787504818/` 并核对 manifest、JUnit、failure summary、Swift logic smoke、Gateway direct/WebSocket smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前 Review Detail Dock 是手机端 presentation-layer 宽屏复核布局，不是完整 artifact payload viewer、自动执行、自动审批、自动安全裁决或 Gateway readiness。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.33 / Mission Run Focus Context 聚焦上下文

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunFocusContextSummary`，`ClawMissionRunSummary` 可从当前聚焦项、复核优先队列、Artifact 证据索引、复核态势摘要和下一步复核行动派生聚焦上下文。
- Mission Run 面板在复核优先队列后展示 Focus Context 卡，覆盖无聚焦、detail 聚焦、状态级聚焦和过期聚焦，显示是否有 detail row、证据覆盖、metadata 缺口和人工动作状态。
- Focus Context 只提供聚焦对应 detail 或清除聚焦的本地 UI 行为，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续。
- 修复 Loop 继续态势、下一步复核行动和复核态势摘要卡片的 VoiceOver 容器策略，避免父级 `.combine` 合并内部按钮。
- XCTest 和 Swift logic smoke 覆盖 idle、detail 聚焦、状态级聚焦、过期聚焦、Shell 高风险聚焦和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.33（MissionRunFocusContext）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- GitHub Actions run `28783608872` attempt `1` 对 commit `11d6fc1bcdb6fd424f88b8ae6e4bd5382970515b` 通过，artifact `claw-ci-v0.2-main-11d6fc1bcdb6-run28783608872-attempt1` 已下载到 `/private/tmp/claw-c-review-28783608872/` 并核对 manifest、JUnit、failure summary、Swift logic smoke、Gateway direct/WebSocket smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前 Focus Context 是手机端 presentation-layer 聚焦说明，不是自动执行、自动审批、自动安全裁决、Gateway readiness 或完整 artifact payload viewer。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.32 / Mission Run Loop 继续态势

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunLoopContinuationSummary`，`ClawMissionRunSummary` 可从安全 AgentTrace metadata、handoff 状态、readiness、满足/降级/缺失证据计数和 selected next action 派生 loop 继续态势。
- Mission Run 面板在 Operator Strip 后展示 Loop 继续态势卡，覆盖无 AgentTrace、metadata 待同步、可继续、需要证据、等待审批、最终提交复核、阻断和完成状态。
- Loop 继续态势卡只提供聚焦 AgentTrace 详细复核的按钮，不执行 Gateway 动作，不审批、不发送、不重试、不自动继续。
- `ClawAgentTraceReviewSummary` 解析并白名单化 v0.31 `degradedSignals`，AgentTrace row 展示降级信号 chip；恶意 metadata 不会外显 token、Authorization、`file://`、本地路径或 `toolArguments`。
- Simulator、XCTest 和 Swift logic smoke 同步 v0.31 证据质量语义：screen/accessibility dry-run 进入 degradedSignals，默认证据分为 50。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway JS 或执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.32（MissionRunLoopContinuationBrief）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- GitHub Actions run `28781650300` attempt `1` 对 commit `304dd220487749597a35578763194e9aef999b71` 通过，artifact `claw-ci-v0.2-main-304dd2204877-run28781650300-attempt1` 已下载到 `/private/tmp/claw-c-review-28781650300/` 并核对 manifest、JUnit、failure summary、Swift logic smoke、Gateway direct/WebSocket smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前 Loop 继续态势是手机端 presentation-layer 人工复核摘要，不是自动继续、自动审批、自动安全裁决、Gateway readiness 或完整 artifact payload viewer。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.31 / AgentTrace Mac Evidence Quality

日期：2026-07-06

核心变更：

- Gateway `runAgentLoop` 为 input source 派生 `satisfied`、`degraded` 和 `missing` 证据质量，不再只按 artifact count 判断 readiness。
- dry-run screen observation、window metadata、dry-run/window-metadata Accessibility、network blocked、failed、unavailable 或 not-requested 证据进入 `degradedSignals`，不进入 `satisfiedSignals`，也不增加 readiness score。
- `decisionChecklist[].status` 支持 `degraded`，`readiness` 新增 `degradedSignals`，risk tags 新增 `degraded-<source>`，handoff summary 会用安全 source enum 提示降级证据。
- `agentTrace` artifact event metadata 新增可选 `degradedSignals`，direct/WebSocket smoke 精确核对 metadata key、trace JSON 字段和值一致。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway 权限，不改变 iOS UI。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.31（AgentTraceMacEvidenceQuality）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs`、`node --check Tools/claw-gateway-direct-smoke.mjs`、`node --check Tools/claw-gateway-smoke.mjs` 通过。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (219 events)`。
- `node Tools/claw-gateway-smoke.mjs` 沙盒内监听 `127.0.0.1:18879` 因 `EPERM` 失败；提升权限重跑通过，输出 `Claw Gateway smoke passed (79 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- GitHub Actions run `28779619275` attempt `1` 对 commit `57879c4e7497c798068d2bd10905f50bd935a0bb` 通过，artifact `claw-ci-v0.2-main-57879c4e7497-run28779619275-attempt1` 已下载到 `/private/tmp/claw-c-review-28779619275/` 并核对 manifest、JUnit、failure summary、Swift logic smoke、Gateway direct/WebSocket smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前 evidence quality 是 AgentTrace metadata-only 启发式质量分层，不是真实 macOS UI 可控性证明、自动安全裁决、自动执行授权或完整 payload viewer。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.30 / AgentTrace Handoff Status

日期：2026-07-06

核心变更：

- Gateway `runAgentLoop` 为 `agentTrace` 派生固定枚举 `handoffStatus`，从 readiness、selected next action、risk tags 和 stop reason 判断 `needs-evidence`、`waiting-for-approval`、`final-submit-review`、`blocked`、`ready-to-continue` 或 `complete`。
- `agentTrace` artifact event metadata 新增 `handoffStatus`，direct/WebSocket smoke 精确核对 metadata key、trace JSON 字段和值是否合法。
- 手机端 `ClawAgentTraceReviewSummary` 解析并安全白名单化 `handoffStatus`，恶意自由文本状态不会进入 UI。
- AgentTrace row 增加 handoff 状态 chip；Mission Run 复核优先队列把需要证据、等待审批、最终提交复核和阻断状态判为可行动复核项。
- Simulator、XCTest 和 Swift logic smoke 覆盖 handoff 状态、metadata 缺失回退和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway 权限。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.30（AgentTraceHandoffStatus）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `node --check Tools/claw-gateway-server.mjs`、`node --check Tools/claw-gateway-direct-smoke.mjs`、`node --check Tools/claw-gateway-smoke.mjs` 通过。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (219 events)`。
- GitHub Actions run `28777405447` attempt `1` 对 commit `01ad990eb3a9cc504ec5f6c5641631eecf0b1fec` 通过，artifact `claw-ci-v0.2-main-01ad990eb3a9-run28777405447-attempt1` 已下载到 `/private/tmp/claw-c-review-28777405447/` 并核对 manifest、JUnit、failure summary、Swift logic smoke、Gateway direct/WebSocket smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前 handoffStatus 是 AgentTrace metadata-only 人工复核状态，不是自动执行授权、自动安全裁决、Gateway readiness、完整 payload viewer 或自动修复器。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.29 / iPad Mission Run Operator Strip

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunOperatorStrip`、`ClawMissionRunOperatorLane` 和 tone 模型，`ClawMissionRunSummary` 通过 computed helper 从阶段、回合进度、结果计数、Artifact 证据索引、复核态势摘要和下一步复核行动派生 4 条操作态势 lane。
- Operator Strip 固定展示 Gateway、证据、复核和下一步状态，帮助 iPad/宽屏工作台快速扫视当前任务态势；compact iPhone 复用同一面板并保持可换行。
- Strip lane 只使用固定文案、计数、枚举和既有安全 summary；可聚焦 lane 只调用已有 detail review 聚焦，不执行 Gateway 动作，不读取 artifact payload。
- SwiftUI 新增 `ClawMissionRunOperatorStripView` 和 `ClawMissionRunOperatorLaneView`，使用 `Label`、语义字体、44pt 以上触控区和 VoiceOver label/hint。
- XCTest 和 Swift logic smoke 覆盖 idle、正常任务、delivery 聚焦、Shell 高风险、lane 顺序、count 一致性和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway 权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.29（iPadMissionRunOperatorStrip）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `node --check Tools/claw-gateway-server.mjs`、`node --check Tools/claw-gateway-direct-smoke.mjs`、`node --check Tools/claw-gateway-smoke.mjs` 通过。
- GitHub Actions run `28773957914` attempt `1` 对 commit `fb3833a8f2cec4f89b62a780bbe9333f88b49114` 通过，artifact `claw-ci-v0.2-main-fb3833a8f2ce-run28773957914-attempt1` 已下载到 `/private/tmp/claw-c-review-28773957914/` 并核对 manifest、JUnit、failure summary、Swift logic smoke、Gateway direct/WebSocket smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前 Operator Strip 是手机端 presentation-layer 操作态势带，不是自动执行控制台、自动安全裁决、Gateway readiness、完整 payload viewer 或自动修复器。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.28 / Mission Run Artifact 证据索引

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunArtifactEvidenceIndex` 和 `ClawMissionRunArtifactEvidenceItem`，`ClawMissionRunSummary` 通过 computed helper 从 artifact kind、Artifact metadata review count、可用 detail review kind、复核优先队列和当前聚焦项派生 Artifact 证据索引。
- 证据索引按固定 review kind 到 artifact kind 的映射展示哪些复核项已有证据类型、metadata 是否同步、redaction count 和当前聚焦项是否有证据；索引只表达证据类型覆盖，不打开 artifact payload。
- Mission Run 在 artifact chips 后、复核态势摘要前展示 Artifact 证据索引；item row 使用 SwiftUI `Button` 聚焦对应详细复核，compact iPhone 和 iPad regular 工作台复用同一面板。
- 证据索引只使用固定文案、计数、枚举 title 和既有安全 summary，不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`。
- XCTest 和 Swift logic smoke 覆盖 idle、正常任务、delivery 聚焦、Shell 证据映射、metadata/redaction count、item 顺序和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway 权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.28（MissionRunArtifact证据索引）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `node --check Tools/claw-gateway-server.mjs`、`node --check Tools/claw-gateway-direct-smoke.mjs`、`node --check Tools/claw-gateway-smoke.mjs` 通过。
- GitHub Actions run `28771766504` attempt `1` 对 commit `123fb44934ffab03651ad0c74a07a92878098c3f` 通过，artifact `claw-ci-v0.2-main-123fb44934ff-run28771766504-attempt1` 已下载到 `/private/tmp/claw-c-review-28771766504/` 并核对 manifest、JUnit、failure summary、Swift logic smoke、Gateway direct/WebSocket smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前 Artifact 证据索引是手机端 presentation-layer 证据类型覆盖，不是完整 payload viewer、自动安全裁决、恶意检测、完整审计或自动修复器。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.27 / Mission Run 下一步复核行动

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunNextReviewAction`，`ClawMissionRunSummary` 通过 computed helper 从当前有效聚焦项、完整复核优先队列和可用 detail review kind 派生下一步人工复核行动。
- 下一步行动优先使用当前聚焦项，否则使用完整队列最高优先项；没有队列但已有 detail review 时降级为抽查详细复核，完全 idle 时提示等待 Gateway 证据。
- Mission Run 在复核态势摘要后、复核优先队列前展示下一步复核行动，并提供聚焦按钮复用 v0.25 聚焦机制；compact iPhone 和 iPad regular 工作台复用同一面板。
- 下一步复核行动的聚焦状态同时接受队列项和已存在的 detail review kind，避免 detail-only fallback 按钮被 presentation 层误判为过期聚焦。
- 下一步行动只使用固定文案、计数、枚举和已脱敏队列项字段，不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`。
- XCTest 和 Swift logic smoke 覆盖 idle、正常任务、聚焦状态、Shell 高优先行动、count/目标一致性和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway 权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.27（MissionRun下一步复核行动）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `node --check Tools/claw-gateway-server.mjs`、`node --check Tools/claw-gateway-direct-smoke.mjs`、`node --check Tools/claw-gateway-smoke.mjs` 通过。
- GitHub Actions run `28770520084` attempt `1` 对首个实现 commit `adcdbbd0d8544f98241a37171af202a773cad0d1` 通过；reviewer 随后指出 detail-only fallback 聚焦边界，已追加修复。
- GitHub Actions run `28770668477` attempt `1` 对修复 commit `b4950c5db224796e1b7194afa84fda4a48eaa8f4` 通过，artifact `claw-ci-v0.2-main-b4950c5db224-run28770668477-attempt1` 已下载到 `/private/tmp/claw-c-review-28770668477/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前下一步复核行动是手机端 presentation-layer 引导，不是自动安全裁决、自动执行计划、恶意检测、完整 payload viewer 或自动修复器。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.26 / Mission Run 复核态势摘要

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunReviewReadinessSummary`，`ClawMissionRunSummary` 通过 computed helper 从完整复核优先队列、可用 detail review kind 和聚焦状态派生人工复核态势摘要。
- 摘要覆盖总优先项、可行动项、critical/high 项、metadata 待同步项、可用详细复核数、最高优先项、当前聚焦项和聚焦项是否有 detail row。
- Mission Run 在 artifact chips 后、复核优先队列前展示短态势摘要，并提供“聚焦最高优先项”按钮复用 v0.25 聚焦机制；compact iPhone 和 iPad regular 工作台复用同一面板。
- 摘要只使用固定文案、计数、枚举和已脱敏队列项字段，不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`。
- XCTest 和 Swift logic smoke 覆盖 idle、正常任务、聚焦状态、Shell 高优先/可行动计数、count 一致性和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway 权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.26（MissionRun复核态势摘要）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `node --check Tools/claw-gateway-server.mjs`、`node --check Tools/claw-gateway-direct-smoke.mjs`、`node --check Tools/claw-gateway-smoke.mjs` 通过。
- GitHub Actions run `28768979862` attempt `1` 对 commit `cf894226dedadeaada8121ca6fe19e85f2cdc5a6` 通过，artifact `claw-ci-v0.2-main-cf894226deda-run28768979862-attempt1` 已下载到 `/private/tmp/claw-c-review-28768979862/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke、node/plutil/git diff check 和 xcodebuild 日志。
- GitHub Actions run `28769138272` attempt `1` 对验证记录 commit `e2ea7265692ba3a11b5de45dbd6d56335923b5b0` 失败，failure summary 指向 `swift-logic-smoke`；日志显示 `Tools/LogicSmoke.swift` 中复核态势脱敏断言的长字符串表达式触发 Swift 编译器 type-check 超时，已通过拆分中间数组追加修复。
- GitHub Actions run `28769430607` attempt `1` 对修复 commit `38d530a6572a92f7bcb84a55ee875d605576e554` 通过，artifact `claw-ci-v0.2-main-38d530a6572a-run28769430607-attempt1` 已下载到 `/private/tmp/claw-c-review-28769430607/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前复核态势摘要是手机端 presentation-layer 汇总，不是自动安全裁决、自动执行 readiness、恶意检测或完整 payload viewer。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.25 / Mission Run 复核聚焦模式

日期：2026-07-06

核心变更：

- Mission Run 复核优先队列项升级为可点击按钮，用户可聚焦单个 `reviewKind` 并筛选对应详细复核 row，点击“全部”恢复全量详情。
- `ClawMissionRunSummary` 增加 detail focus helper，覆盖当前可用详细 review kind、聚焦后可见 kind、单行显示判断和聚焦队列项解析；聚焦状态只存在于 SwiftUI presentation layer。
- `approval`、`gateway-status` 或未知/过期聚焦项没有对应详细复核 row 时，UI 显示固定提示并保持全量详情，避免把其他风险清空。
- 队列行使用 SwiftUI `Button`、系统图标、选中描边和 VoiceOver label；compact iPhone 与 iPad regular 工作台复用同一 Mission Run 面板。
- XCTest 和 Swift logic smoke 覆盖无聚焦、有效聚焦、状态类/未知聚焦回退、Shell 聚焦和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway 权限，不读取 Gateway `file://` payload。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.25（MissionRun复核聚焦模式）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `node --check Tools/claw-gateway-server.mjs`、`node --check Tools/claw-gateway-direct-smoke.mjs`、`node --check Tools/claw-gateway-smoke.mjs` 通过。
- GitHub Actions run `28767970421` attempt `1` 对 commit `16ee75e04342b0994083d497c35cae5a30ecd97c` 通过，artifact `claw-ci-v0.2-main-16ee75e04342-run28767970421-attempt1` 已下载到 `/private/tmp/claw-c-review-28767970421/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke、node/plutil/git diff check 和 xcodebuild 日志。
- v0.25 验证记录提交后，GitHub Actions run `28768134701` attempt `1` 对最新 commit `ce4f61533768cfd141754c07e0ee46450c3eb81e` 通过，artifact `claw-ci-v0.2-main-ce4f61533768-run28768134701-attempt1` 已下载到 `/private/tmp/claw-c-review-28768134701/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke、node/plutil/git diff check 和 xcodebuild 日志。

遗留事项：

- 当前聚焦模式是手机端 presentation-layer 筛选，不是自动安全裁决、深链导航、完整 payload viewer 或跨 session 审计状态。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.24 / Mission Run 复核优先队列

日期：2026-07-06

核心变更：

- 新增 `ClawMissionRunReviewPriorityItem` 和 severity 模型，`ClawMissionRunSummary` 从既有 task/session/review summary 派生稳定排序的复核优先队列。
- 队列按审批/阻断、Replay Guard、草稿最终提交、Shell、文件变更、浏览器、提取完整性、Accessibility、Gateway 能力、Artifact metadata 和 AgentTrace 的固定 rank/review kind 输出，优先展示需要人工处理、metadata 缺失或高风险执行面的复核项。
- Mission Run 首屏在 artifact chips 后、详细 review rows 前展示前 5 个优先项；iPhone compact 和 iPad regular 多栏工作台自动复用同一面板。
- Gateway session card 和 result row 保留既有详细 review rows；排序逻辑留在 presentation 派生层，不放到 SwiftUI view 重算。
- 队列只使用固定文案、数字、枚举状态和已脱敏 summary 字段，不读取 Gateway `file://` payload，不展示 raw URL/path/command/stdout/stderr/diff/token/header 或 `toolArguments`。
- XCTest 和 Swift logic smoke 覆盖 idle 空队列、排序稳定、高风险项、Shell policy 阻断优先级和敏感字符串不外显。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不改变 Gateway 权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.24（MissionRun复核优先队列）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 本地无签名 iOS build 通过，输出 `** BUILD SUCCEEDED **`。
- GitHub Actions run `28766837880` attempt `1` 对 commit `7d805ac34775711bb679c772611ebecdd6128d58` 通过，artifact `claw-ci-v0.2-main-7d805ac34775-run28766837880-attempt1` 已下载到 `/private/tmp/claw-c-review-28766837880/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke 和 xcodebuild 日志。

遗留事项：

- 当前优先队列是手机端 presentation-layer 排序，不是自动安全裁决、恶意检测、完整审计或自动修复器。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.23 / Shell 命令安全复核

日期：2026-07-05

核心变更：

- Gateway `runShellCommand` 的既有 `commandOutput` artifact event 增加 metadata-only 的 Shell Command Safety 摘要，覆盖结构化命令 presence、parse 状态、Shell policy、allowlist match、execution attempted/executed、timeout、exit code presence/zero、stdout/stderr presence、command/stdout/stderr/cwd omission flags 和 result status。
- 缺少结构化 `shellCommand`、解析失败、dry-run/allowlist policy 阻断和 allowlist 真执行路径均输出同类安全 metadata；metadata 只表达固定状态、布尔值、presence 和 safety flags，不把 raw command、binary/args、cwd/path、stdout/stderr 内容、自然语言 instruction 或 `toolArguments` 放入 metadata。
- 新增 `ClawGatewayShellCommandSafetyReviewSummary`，手机端只从 artifact event metadata 或 legacy `commandOutput` artifact 派生 Shell 命令安全复核摘要，不读取 Gateway `file://` payload。
- Mission Run、Gateway session card 和单个 result row 展示 Shell Command Safety 复核行；metadata 缺失时降级为“metadata 待同步”，不假定命令安全、已阻断或已执行。
- Gateway simulator、`Tools/ClawGatewayEventFixture.swift`、direct smoke 和 WebSocket smoke 同步输出/断言同类安全 metadata，覆盖 dry-run policy 阻断、allowlist 真执行和缺少结构化命令阻断。
- XCTest 和 Swift logic smoke 覆盖 Mission Run 派生、legacy metadata fallback、fixture 派生和恶意 metadata 脱敏。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不扩大 Gateway Shell 权限。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Tools/ClawGatewayEventFixture.swift`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.23（Shell命令安全复核）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (219 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (72 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- GitHub Actions run `28741888192` attempt `1` 对 commit `eb90f5bdbc327da864c7a5a3fe60852c5334b269` 通过，artifact `claw-ci-v0.2-main-eb90f5bdbc32-run28741888192-attempt1` 已下载到 `/private/tmp/claw-c-review-28741888192/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke 和 xcodebuild 日志。

遗留事项：

- 当前是 metadata-only Shell 命令安全复核，不是完整命令模板系统、交互式 shell、审批三阶段 UI、命令沙箱或恶意命令检测。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.22 / 文件变更安全复核

日期：2026-07-05

核心变更：

- Gateway `manageFiles` 的既有 `fileDiff` artifact event 增加 metadata-only 的 File Change Safety 摘要，覆盖 workspace policy、写入尝试/成功、路径逃逸阻断、created/modified/deleted count、path/content/diff omission flags 和 result status。
- 路径逃逸和写入失败路径会写入脱敏 `auditLog` artifact event，metadata 只表达固定状态、计数和 safety flags，不把 raw path、workspace path、文件内容、diff、patch 或 `toolArguments` 放入 metadata；Gateway workspace/session 写入补充 lstat/realpath symlink component 检查和 no-follow file open。
- 新增 `ClawGatewayFileChangeSafetyReviewSummary`，手机端只从 artifact event metadata 或 legacy `fileDiff` artifact 派生文件变更安全复核摘要，不读取 Gateway `file://` payload。
- Mission Run、Gateway session card 和单个 result row 展示 File Change Safety 复核行；metadata 缺失时降级为“metadata 待同步”，不假定写入安全。
- Gateway simulator、`Tools/ClawGatewayEventFixture.swift`、direct smoke 和 WebSocket smoke 同步输出/断言同类安全 metadata，覆盖普通 workspace 写入、路径逃逸阻断、写入失败审计和 workspace symlink 阻断。
- XCTest 和 Swift logic smoke 覆盖 Mission Run 派生、legacy metadata fallback、fixture 派生和恶意 metadata 脱敏。
- 同步 README、协议、flow/flowchart、测试说明和 Agent A 提示词；本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Tools/ClawGatewayEventFixture.swift`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.22（文件变更安全复核）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (213 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (72 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- GitHub Actions run `28736316020` attempt `1` 对 commit `d78e7728b563fb90a402c382265fed00035b2bf7` 通过，artifact `claw-ci-v0.2-main-d78e7728b563-run28736316020-attempt1` 已下载到 `/private/tmp/claw-c-review-28736316020/` 并核对 manifest、JUnit、failure summary、Swift/Gateway smoke 和 xcodebuild 日志。

遗留事项：

- 当前是 metadata-only 文件变更安全复核，不是完整 diff viewer，也不读取或展示 artifact payload。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.21 / 浏览器控制计划复核

日期：2026-07-05

核心变更：

- Gateway `controlBrowser` 的 `browserTrace` 和 `browser-control-*.json` artifact event 增加 metadata-only 的 Browser Control 摘要，覆盖是否请求打开浏览器、URL/search 是否仅以 presence 记录、HTML 输入、network fetch/blocked、app/host allowlist、执行状态和安全 omission flags。
- 新增 `ClawGatewayBrowserControlReviewSummary`，手机端只从 artifact event metadata 或 legacy browser artifact 派生浏览器控制计划复核摘要，不读取 Gateway `file://` payload。
- Mission Run、Gateway session card 和单个 result row 展示 Browser Control 复核行；metadata 缺失时降级为“metadata 待同步”，不把抽取或 dry-run 误判为真实浏览器点击。
- Gateway simulator 和 `Tools/ClawGatewayEventFixture.swift` 同步输出同类安全 metadata，保持模拟、fixture、direct smoke 和 WebSocket smoke 一致。
- Gateway direct/WebSocket smoke 断言 Browser Control metadata 固定键、策略字段和 omission flags，并确认 metadata 不泄露 raw URL、search query、HTML/page text、form/candidate label、stdout/stderr、token 或 `toolArguments`。
- Gateway `--emit-events` 在退出前等待 stdout flush，避免 metadata 增多后 direct smoke 偶发截断事件流。
- XCTest 和 Swift logic smoke 覆盖 Mission Run 派生、legacy metadata fallback、浏览器策略字段和恶意 metadata 脱敏。
- 同步 README、协议、flow/flowchart 和测试说明；本轮不新增 schema/event/action/artifact kind，不实现真实浏览器点击/表单控制，不扩大 Gateway 权限。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Tools/ClawGatewayEventFixture.swift`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/v0（核心智能能力）/v0.21（浏览器控制计划复核）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (198 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (51 events)`。
- 待完成 `git diff --check`、workflow YAML 语法检查、push `origin/main` 和 GitHub Actions artifact 复判。

遗留事项：

- 当前是 metadata-only 浏览器控制计划复核，不是网页正文 viewer、真实点击/表单执行或 Playwright/browser-use 控制器。
- 完整 macOS Accessibility bridge、浏览器真实点击/表单控制、完整 artifact payload 复核体验和真实多轮 agent loop 仍是后续遗留。

### v0.20 / 草稿最终提交安全复核

日期：2026-07-05

核心变更：

- Gateway `messageDraft` 和 `operateDesktopApp` 相关 artifact event 增加 metadata-only 的 Delivery Safety 摘要，覆盖 final-submit gate、用户确认、草稿正文/paste text 省略和提交键阻断计数。
- 新增 `ClawGatewayDeliverySafetyReviewSummary`，手机端只从 artifact event metadata 派生草稿/最终提交安全复核摘要，不读取 Gateway `file://` payload。
- Mission Run、Gateway session card 和单个 result row 展示 Delivery Safety 复核行；metadata 缺失时降级为“metadata 待同步”，不做假阳性安全判断。
- Gateway direct/WebSocket smoke 断言 `messageDraft` 和桌面 App dry-run metadata 存在，并确认 metadata 不泄露草稿正文、paste text、按键原文、URL/path、token 或 `toolArguments`。
- XCTest 和 Swift logic smoke 覆盖 Mission Run 派生、legacy metadata fallback、桌面提交键阻断计数和恶意 metadata 脱敏。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不实现真实发送/提交，不扩大 Gateway 权限。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.20（草稿最终提交安全复核）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (186 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (51 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 待 push `origin/main` 后由 GitHub Actions 覆盖 xcodebuild、Swift logic smoke、Gateway direct/WebSocket smoke 和结果包验收。

遗留事项：

- 当前是 metadata-only 草稿/最终提交安全复核，不是完整草稿正文 viewer，也不读取或展示 artifact payload。
- 真实消息发送、最终提交、完整 macOS Accessibility bridge、浏览器真实点击和完整 artifact 内容复核体验仍是后续遗留。

### v0.19 / 提取完整性复核

日期：2026-07-05

核心变更：

- Gateway `extractData` 输出 artifact event 增加安全 metadata，覆盖提取模式、完整性校验、row count、来源 artifact 计数、source kinds 和 safety flags。
- 新增 `ClawGatewayExtractionCompletenessReviewSummary`，手机端只从 `extractData` artifact metadata 派生完整性复核摘要，不读取 Gateway `file://` payload。
- Mission Run、Gateway session card 和单个 result row 展示提取完整性复核行，帮助用户在草稿或最终提交前判断结构化结果是否有足够 artifact 依据。
- Gateway direct/WebSocket smoke 断言 metadata 与提取 payload 的计数一致，并确认 metadata 不泄露 row 内容、URL/path、命令输出、网页正文、token 或 `toolArguments`。
- XCTest 和 Swift logic smoke 覆盖 Mission Run 派生、metadata fallback 和恶意 metadata 脱敏。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 权限。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.19（提取完整性复核）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (179 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (44 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 待 push `origin/main` 后由 GitHub Actions 覆盖 xcodebuild、Swift logic smoke、Gateway direct/WebSocket smoke 和结果包验收。

遗留事项：

- 当前是 metadata-only 提取完整性复核，不是完整 extraction artifact viewer，也不读取或展示 row payload。
- 完整 artifact payload 复核体验、浏览器控制计划复核、草稿/最终提交安全复核、真实多轮 agent loop 和 Playwright/browser-use 兼容控制器仍是后续遗留。

### v0.18 / 手机端 Metadata 复核脱敏加固

日期：2026-07-05

核心变更：

- 新增集中 `ClawArtifactMetadataDisplaySanitizer`，统一专用 metadata review 的安全显示路径。
- AgentTrace、Gateway capability、Accessibility、Replay Guard 和通用 Artifact metadata review 的 UI 可见字段统一脱敏 raw token、Authorization/header、Bearer、`toolArguments`、`file://` 和 workspace path。
- XCTest 增加恶意 AgentTrace / Gateway capability metadata 脱敏覆盖；Swift logic smoke 增加专用复核摘要敏感值不外显断言。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不修改 Gateway JS，不扩大 Gateway 权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.18（手机端Metadata复核脱敏加固）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 本轮未修改 `Tools/*.mjs`，本地未跑 Gateway JS smoke；push `origin/main` 后由 GitHub Actions 覆盖 Gateway direct/WebSocket smoke、Swift logic smoke 和 xcodebuild，并由 Agent C 下载结果包复判。

遗留事项：

- Artifact 的严格时间顺序仍沿用当前 `sessionArtifacts + results.artifacts` 派生方式；如需修正跨 action/session-level artifact 的“latest”语义，应在后续版本引入带序号或时间戳的 presentation 聚合。
- 浏览器控制计划复核、提取完整性复核和草稿/最终提交安全复核仍是后续高价值增量。

### v0.17 / 手机端 Artifact metadata 详情复核

日期：2026-07-05

核心变更：

- 新增 `ClawGatewayArtifactMetadataReviewSummary`，手机端只从 Gateway artifact event metadata、kind/title 和脱敏标记派生通用 metadata 复核摘要，不读取 Gateway `file://` payload。
- `ClawMissionRunSummary` 增加 artifact metadata review，Mission Run、Gateway session card 和单个 result row 展示 artifact 总数、metadata 覆盖率、脱敏数、最近带 metadata artifact、安全键值和 safety flags。
- 通用 metadata review 会脱敏 raw token、Authorization/header、`toolArguments`、payload/body/content、workspace path、`file://`、命令输出、网页正文、截图内容和草稿正文等敏感字段。
- XCTest 和 Swift logic smoke 覆盖 metadata 存在、metadata 缺失 fallback、敏感字段脱敏和 Mission Run 派生。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不修改 Gateway JS，不扩大 Gateway 权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.17（手机端ArtifactMetadata详情复核）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 无签名 generic iOS build 通过，输出 `BUILD SUCCEEDED`；本机 CoreSimulator 服务不可用，仅产生 simulator 发现日志，不影响 generic iOS build。
- 本轮未修改 `Tools/*.mjs`，本地未跑 Gateway JS smoke；push `origin/main` 后由 GitHub Actions 覆盖 Gateway direct/WebSocket smoke、Swift logic smoke 和 xcodebuild，并由 Agent C 下载结果包复判。

遗留事项：

- 当前是手机端 metadata-only 复核，不是完整 artifact JSON viewer，也不读取 Gateway `file://` payload。
- 完整 artifact payload 复核体验、真实多轮 agent loop、Playwright/browser-use 兼容控制器和完整 Accessibility bridge 仍是后续遗留。

### v0.16 / 手机端 Accessibility artifact 复核摘要

日期：2026-07-05

核心变更：

- 新增 `ClawGatewayAccessibilityReviewSummary`，手机端只从 `accessibilityTree` artifact event metadata 派生观察复核摘要，不读取 Gateway `file://` payload。
- `ClawMissionRunSummary` 增加 Accessibility review，Mission Run、Gateway session card 和单个 result row 展示 mode、policy、节点数、候选控件数、platform、redaction、safety flags 和脱敏状态。
- Gateway simulator 的 `accessibilityTree` artifact 附带 v0.15 同款安全 metadata，XCTest 和 Swift logic smoke 覆盖 metadata 解析、legacy fallback、Mission Run 派生和敏感字段不展示。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不修改 Gateway JS，不扩大 Gateway 权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.16（手机端AccessibilityArtifact复核摘要）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 本轮未修改 `Tools/*.mjs`，本地未跑 Gateway JS smoke；push `origin/main` 后由 GitHub Actions 覆盖 Gateway direct/WebSocket smoke、Swift logic smoke 和 xcodebuild，并由 Agent C 下载结果包复判。

遗留事项：

- 当前是手机端 metadata-only 复核，不是完整 artifact JSON viewer，也不读取 Gateway `file://` payload。
- 完整 Accessibility bridge、控件级动作、敏感区域打码和真实浏览器点击仍是后续遗留。

### v0.15 / macOS Accessibility 观察摘要

日期：2026-07-05

核心变更：

- Gateway 新增显式 `CLAW_ALLOW_ACCESSIBILITY_OBSERVE=1` 开关；默认仍为 dry-run/window metadata，不做真实 Accessibility 读取。
- `observeScreen` 继续复用既有 `accessibilityTree` artifact；授权 macOS Gateway 上只用固定只读 System Events 脚本采集前台 App/窗口和有限候选控件摘要，无权限或非 macOS 时返回可审计 failed/unavailable artifact。
- `gateway-capability-snapshot.json` capability 和 metadata 增加 `accessibilityTreeState`，同时标记 Accessibility 文本为 summary-only、值和密码字段省略、动作执行不支持。
- 手机端 `ClawGatewayCapabilityReviewSummary` 解析 `accessibilityTreeState`，Mission Run / Gateway 能力行展示 `ax <state>` chip；模拟事件流、XCTest 和 Swift logic smoke 覆盖该 metadata。
- direct/WebSocket smoke 覆盖默认 dry-run 状态、metadata allowlist，以及显式 env 开启但 CI 无 macOS 权限时仍能生成合法审计 artifact。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不执行点击/输入，不让 iOS 声称能读取其他 App 私有数据。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.15（macOSAccessibility观察摘要）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (173 events)`。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (44 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。

遗留事项：

- 当前是只读观察摘要，不是完整 Accessibility bridge；尚未实现控件级点击、输入、表单提交、视觉定位或默认敏感区域打码。
- macOS Accessibility 权限缺失、非 macOS 或 CI 无 GUI 时会返回 failed/unavailable 审计结果，这是预期安全降级。
- 本地未跑无签名 iOS xcodebuild；本轮按测试规范使用轻量检查，push `origin/main` 后由 GitHub Actions 覆盖 xcodebuild、Swift logic smoke、Gateway direct/WebSocket smoke 和结果包验收。

### v0.14 / 手机端 Replay Guard 复核摘要

日期：2026-07-05

核心变更：

- 新增 `ClawGatewayTaskReplayGuardReviewSummary`，手机端只从 `task-replay-guard.json` `auditLog` artifact metadata 派生 replay guard 复核摘要，不读取 Gateway `file://` payload。
- `ClawMissionRunSummary` 增加 replay guard review，blocked 状态遇到 replay guard session 时优先说明重复任务已被 Gateway Replay Guard 跳过、未重新执行桌面 handler。
- Mission Run 面板和 Gateway session card 新增 Replay Guard row，展示 replay 次数、跳过动作数、digest match、首次状态、短 task/session/digest、action kind 和 safety flags；metadata 缺失时降级为待同步。
- XCTest 和 Swift logic smoke 覆盖 replay guard metadata 解析、legacy fallback、session-level artifact 合并、Mission Run 派生和敏感字段不展示。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不修改 Gateway JS，不扩大 Gateway 权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.14（手机端ReplayGuard复核摘要）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 无签名 iOS build 通过，输出 `BUILD SUCCEEDED`；本机 CoreSimulator 服务不可用，仅影响 simulator 发现日志，不影响 generic iOS build。

遗留事项：

- 本轮不改变 Gateway JS；本地未跑 Gateway direct/WebSocket smoke，push `origin/main` 后由 GitHub Actions 覆盖。
- 仍需本轮 push 后等待 GitHub Actions `ci-results` 结果包，供 Agent C 下载并核对 manifest、JUnit/摘要、Swift logic smoke、Gateway direct/WebSocket smoke 和 xcodebuild 日志后复判。

### v0.13 / Gateway task replay guard

日期：2026-07-04

核心变更：

- `Tools/claw-gateway-server.mjs` 新增进程内 task replay cache；首次接受 `task.id` 前登记安全记录，重复提交同一任务时进入 replay guard，不再调用 action handler。
- replay guard 复用既有 `auditLog` artifact、`artifactStored` event、`actionSkipped` event 和 `sessionCompleted` event；重复任务会写 session-level `task-replay-guard.json`，逐个 action 返回 skipped。
- replay audit payload/metadata 只记录 task id、短 digest、首次 session id、原始状态、replay count、action count/kinds 和安全标志，不包含 raw token、Authorization header、自然语言 instruction、`toolArguments`、业务 artifact payload 或完整 workspace path。
- `--emit-events` 支持 JSON array 输入，用于同一 Gateway 进程内连续处理重复 envelope；单 envelope 输入保持兼容。
- direct smoke 覆盖同一 `--emit-events` 进程内重复 envelope；WebSocket smoke 保留原 `--once` 正常路径，并新增非 `--once` server 上两次连接的 replay guard 验证。
- 同步 README、协议和 flow/flowchart；本轮不新增 schema/event/action/artifact kind，不扩大 Gateway 权限，不做跨重启持久化 exactly-once。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.13（GatewayTaskReplayGuard）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (146 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (44 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。

遗留事项：

- replay guard 只覆盖同一 Gateway 进程生命周期；进程重启、多 Gateway 进程、cache 淘汰或分布式执行仍可能重复处理同一 `task.id`。
- 本轮未修改 Swift 代码，本地未跑 Swift logic smoke 或 iOS build；push `origin/main` 后由 GitHub Actions 覆盖 Swift logic smoke、Gateway direct/WebSocket smoke 和 xcodebuild，并由 Agent C 下载结果包复判。

### v0.12 / Live Gateway 有界重连与心跳可观测性

日期：2026-07-04

核心变更：

- `URLSessionClawGatewayTransport` 新增 `ClawGatewayTransportRetryPolicy`，默认最多重试 1 次；每次 WebSocket 发送 envelope 后执行一次 ping 观测。
- transport 复用现有 `.gatewayConnected` 进度事件携带 `attempt`、`reconnect`、`ping` 和脱敏 `transportError`，不新增 event/action/artifact kind，不改变 `claw.computer.control.v1`。
- 重连只在尚未收到桌面 Gateway 业务事件前进行；收到桌面事件后的错误仍走现有 fallback/复核路径，避免重复发送 envelope 扩大执行风险。
- `ClawGatewayLiveHealthSummary` 新增 attempt、reconnect、ping、transport error 派生字段，并扩展敏感信息遮蔽；Gateway 会话 UI chip 展示尝试次数、重连次数、ping 状态和短错误摘要。
- XCTest 和 Swift logic smoke 覆盖 reconnect/ping summary 解析、重连后完成、ping failed 不中断、最终失败 fallback 和错误摘要脱敏。
- 同步 README、协议和 flow/flowchart；本轮不做后台保活、配对服务或桌面端真实心跳协议，不扩大 Gateway 权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.12（LiveGateway有界重连与心跳可观测性）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 无签名 iOS build 通过，输出 `BUILD SUCCEEDED`。
- `xcodebuild build-for-testing` 通过，输出 `TEST BUILD SUCCEEDED`，确认 `ClawTests` 可编译；本机 CoreSimulator 服务不可用，未执行模拟器 XCTest。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- 本轮未修改 `Tools/*.mjs`，本地未跑 Gateway JS smoke；push `origin/main` 后由 GitHub Actions 覆盖 Gateway direct/WebSocket smoke。

遗留事项：

- 本轮是客户端有界重连和 ping 可观测性，不是 iOS 后台保活、桌面端真实心跳协议、配对服务或 server-side task idempotency。
- push `origin/main` 后仍需等待 GitHub Actions `ci-results` 结果包，供 Agent C 下载并核对 manifest、JUnit/摘要、Gateway direct/WebSocket smoke 日志、Swift logic smoke 和 xcodebuild 日志后复判。

### v0.11 / Live Gateway 连接健康摘要

日期：2026-07-04

核心变更：

- 新增 `ClawGatewayLiveHealthSummary`，手机端从 `ClawGatewayLiveRequest`、`ClawGatewayConnectionState`、最新 `ClawGatewaySession` 和 session 事件派生 Live Gateway 连接健康摘要。
- 摘要展示脱敏 endpoint、transport、request path、短 token 指纹、preflight、是否可尝试 live、事件数量、最新事件、fallback/error/completed、session status、重复 `gatewayConnected` 兼容提示和安全 detail line。
- 修正 live 状态语义：live 模式收到 `.gatewayConnected`、`.actionStarted`、`.artifactStored`、`.actionCompleted`、`.actionFailed`、`.approvalRequested`、`.actionSkipped` 等非终态事件后保持 `streaming`，不再降回 `awaitingGateway`；`.sessionCompleted`、`.fallbackUsed` 和 transport error 仍走既有终态/fallback 路径。
- Gateway 会话面板在 Live request 附近展示连接健康行，iPad regular 工作台通过复用同一 panel 自动覆盖；UI 不显示 raw token、Authorization header、完整 headers、完整 workspace path、`toolArguments` 或 artifact payload。
- XCTest 和 Swift logic smoke 覆盖 idle/request/preflight、endpoint 脱敏、缺 token fallback、live progress streaming、completed mock transport、transport error fallback 和敏感内容不泄露。
- 同步 README、协议、flow 和 flowchart；本轮不新增 schema/action/event/artifact kind，不做自动重连/心跳，不扩大 Gateway 权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.11（LiveGateway连接健康摘要）.md`
- `update_log.md`

验证结果：

- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- 无签名 iOS build 通过，输出 `BUILD SUCCEEDED`。
- `xcodebuild build-for-testing` 通过，输出 `TEST BUILD SUCCEEDED`，确认 `ClawTests` 可编译；本机 CoreSimulator 服务不可用，未执行模拟器 XCTest。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- 本轮未修改 `Tools/*.mjs`，本地未跑 Gateway JS smoke；push `origin/main` 后由 GitHub Actions 覆盖 Gateway direct/WebSocket smoke。

遗留事项：

- push `origin/main` 后仍需等待 GitHub Actions `ci-results` 结果包，供 Agent C 下载并核对 manifest、JUnit/摘要、Gateway direct/WebSocket smoke 日志、Swift logic smoke 和 xcodebuild 日志后复判。
- 当前是 Live Gateway 连接健康摘要，不是自动重连、心跳协议、配对流程或完整 artifact 内容 viewer；这些仍待后续轮次推进。

### v0.10 / 手机端 Gateway 能力复核摘要

日期：2026-07-04

核心变更：

- Gateway `gateway-capability-snapshot.json` `auditLog` artifact event 附带安全 metadata，包含固定 allowlist 键：snapshot kind、token 配置/短指纹、allowedActionKinds、workspace/shell/browser/screen/window/desktop capability state、safety flags 和 platform。
- Swift `ClawGatewaySession` 新增向后兼容的 `sessionArtifacts`，旧 JSON 缺字段时默认为空；`artifactCount` 和 artifact kind summary 改为统计 session-level artifacts 与 action-bound artifacts。
- Reducer 对无 action 绑定的 `artifactStored` 不再丢弃，而是合并到 `sessionArtifacts` 并写入 auditTrail；action-bound artifact 仍进入对应 action result，不创建伪 result。
- 新增 `ClawGatewayCapabilityReviewSummary`，Mission Run、Gateway session card 和 iPad regular 工作台展示 metadata 派生的 Gateway 能力复核摘要；UI 不读取 `file://` 内容，不显示 raw token、完整 path、payload、`instruction` 或 `toolArguments`。
- Simulator、XCTest、Swift logic smoke、Gateway direct/WebSocket smoke 同步覆盖 session-level artifact、metadata allowlist、一致性和无敏感内容泄露。
- 同步 README、协议和 flow/flowchart 文档；本轮不新增 schema/action/event/artifact kind，不扩大 Gateway 权限。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.10（手机端Gateway能力复核摘要）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (108 events)`。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (18 events)`。
- 无签名 iOS build 通过，输出 `BUILD SUCCEEDED`。
- `xcodebuild build-for-testing` 通过，输出 `TEST BUILD SUCCEEDED`，确认 `ClawTests` 可编译；本机未启动模拟器执行 XCTest。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。

遗留事项：

- push `origin/main` 后仍需等待 GitHub Actions `ci-results` 结果包，供 Agent C 下载并核对 manifest、JUnit/摘要、Gateway direct/WebSocket smoke 日志、Swift logic smoke 和 xcodebuild 日志后复判。
- 当前是 metadata 摘要复核，不是完整 artifact JSON viewer；live Gateway 心跳/重连、真实多轮 agent loop 和完整 artifact 内容复核仍待后续轮次推进。

### v0.9 / Gateway 能力快照 artifact

日期：2026-07-04

核心变更：

- Gateway 每个 session 在 `gatewayConnected` 后、任何 action `actionStarted` 前写入 session 级 `auditLog` artifact：`gateway-capability-snapshot.json`。
- 快照 payload 只记录 workspace、session workspace、platform、Node 版本、短 token 指纹、envelope `allowedActionKinds`、action kind 列表、策略 allowlist 和 workspace/shell/browser/screen/window/desktop capability 状态。
- 快照明确 raw token、Authorization header、自然语言 instruction、`toolArguments`、网页正文、命令输出、截图内容和草稿正文均 omitted；本轮复用既有 `auditLog` artifact kind 和 `artifactStored` event kind，不新增 schema/action/event/artifact kind，不扩大 Gateway 权限。
- direct smoke 和 WebSocket smoke 增加快照存在性、事件顺序、redacted、无 raw token、token fingerprint、allowedActionKinds、workspace scope 和策略/capability 状态断言。
- 同步 README、协议和 flow/flowchart 文档，明确快照只用于审计复核，不作为执行计划来源。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.9（Gateway能力快照artifact）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (108 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (18 events)`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 本轮未修改 Swift 模型、store、UI 或 `Tools/LogicSmoke.swift`，本地未跑 Swift logic smoke 和 iOS build；push `origin/main` 后由 GitHub Actions 覆盖。

遗留事项：

- Agent C 仍需下载最新 GitHub Actions `ci-results` 结果包，核对 manifest、JUnit/摘要、Gateway direct/WebSocket smoke 日志、Swift logic smoke 和 xcodebuild 日志后复判。
- 当前快照是 Gateway session 级安全摘要；完整 artifact JSON viewer、live Gateway 心跳和重连、真实多轮 agent loop 仍待后续轮次推进。

### v0.8 / iPad 多栏复核工作台

日期：2026-07-04

核心变更：

- 电脑接管页在 regular horizontal size class 下切换为左右两栏工作台：左侧显示命令输入和 Mission Run 主操作，右侧显示计划、Claw 电脑任务、Gateway 会话、事件/envelope、权限矩阵和执行日志。
- compact 布局保持原有单栏滚动顺序，不删除任何现有入口或操作按钮。
- 本轮只复用既有 `ClawStore` 安全路径和现有面板，不新增 source of truth，不改变 `claw.computer.control.v1` schema，不新增 action/artifact/event，不扩大 Gateway 权限。
- 同步 README、协议和 flow 文档，明确 iPad 工作台属于 presentation layer，不读取 Gateway `file://` artifact 内容。

关键文件：

- `Claw/Views/ContentView.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.8（iPad多栏复核工作台）.md`
- `update_log.md`

验证结果：

- 无签名 iOS build 通过，输出 `BUILD SUCCEEDED`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- 本轮未修改 `Claw/Core/ClawModels.swift`、`Claw/Services/ClawStore.swift` 或 `Tools/*.mjs`，本地未跑 Swift logic smoke 和 Gateway smoke；云端 CI 仍会覆盖。
- push `origin/main` 后仍需等待 GitHub Actions `ci-results` 结果包供 Agent C 复判。

遗留事项：

- 当前是分栏复核工作台，不是完整 artifact JSON viewer；真实多轮 agent loop、完整 artifact 内容复核、live Gateway 心跳和重连仍待后续轮次推进。

### v0.7 / 手机端 AgentTrace 复核体验

日期：2026-07-04

核心变更：

- `ClawGatewayArtifact` 新增向后兼容的可选字符串 `metadata`，旧 artifact JSON 缺少 metadata 时仍可 decode。
- Gateway 和 simulator 在 `agentTrace` artifact event 上附带安全复核摘要：证据分、是否可继续、满足/缺失信号、推荐下一步、审批需求、风险标签、停止原因和 handoff 摘要。
- 手机端新增 `ClawAgentTraceReviewSummary`，Mission Run、Gateway session 和 result 行可显示最近 AgentTrace 复核状态、脱敏状态、缺口、下一步和停止原因。
- direct/WebSocket smoke 增加 artifact metadata 与 trace JSON 关键字段一致性断言；Swift logic smoke 和 XCTest 覆盖 metadata 存在与缺失路径。
- 同步 README、协议、flow/flowchart 和本提示词，明确 metadata 只用于手机端复核展示，不读取 Gateway `file://` 内容，不扩大执行权限。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.7（手机端AgentTrace复核体验）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- Swift logic smoke 编译通过。
- `.build/claw-logic-smoke` 通过，输出 `Claw logic smoke passed`。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (104 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (17 events)`。
- 无签名 iOS build 通过，输出 `BUILD SUCCEEDED`。
- `xcodebuild build-for-testing` 通过，输出 `TEST BUILD SUCCEEDED`，确认 `ClawTests` 可编译；本机 CoreSimulator 服务不可用，未执行模拟器 XCTest。
- GitHub Actions run `28703524664` attempt `1` 通过；Agent C 下载结果包 `claw-ci-v0.2-main-545c6b79c86d-run28703524664-attempt1` 并核对 manifest/JUnit/日志通过，manifest commit 为 `545c6b79c86d50e877e3929274aee10345b5aa8a`。

遗留事项：

- 当前只展示 `agentTrace` 的安全 metadata 摘要；完整 JSON artifact viewer、iPad 多栏复核面板、真实多轮 agent loop、live Gateway 心跳和重连仍待后续轮次推进。

### v0.6 / 增强 AgentTrace 证据策略

日期：2026-07-04

核心变更：

- Gateway `runAgentLoop` 的 `agentTrace` artifact 保留旧字段，并新增 `readiness`、`decisionChecklist`、`selectedNextAction`、`riskTags`、`stopReason` 和 `handoffSummary`。
- 新增证据策略只基于结构化 `toolArguments`、同 session 既有 artifact context、候选下一步和安全闸门推导，不扩大真实浏览器、Shell、AppleScript 或桌面 App 权限。
- direct smoke 和 WebSocket smoke 增加对证据分数、browser/file/command 满足信号、messageDraft 缺口、下一步选择、审批风险标签和停止原因的断言。
- 同步 README、协议和 flow 文档，明确本轮是 `agentTrace` artifact 智能化扩展，不改变 `claw.computer.control.v1` schema。

关键文件：

- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/v0（核心智能能力）/v0.6（增强AgentTrace证据策略）.md`
- `update_log.md`

验证结果：

- `node --check Tools/claw-gateway-server.mjs` 通过。
- `node --check Tools/claw-gateway-direct-smoke.mjs` 通过。
- `node --check Tools/claw-gateway-smoke.mjs` 通过。
- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过，输出 `yaml ok`。
- `node Tools/claw-gateway-direct-smoke.mjs` 通过，输出 `Claw Gateway direct smoke passed (104 events)`。
- `node Tools/claw-gateway-smoke.mjs` 在普通沙箱内因 `listen EPERM 127.0.0.1:18879` 被阻断，升级权限后通过，输出 `Claw Gateway smoke passed (17 events)`。
- push `origin/main` 后仍需等待 GitHub Actions `ci-results` 结果包供 Agent C 复判。

遗留事项：

- `agentTrace` 仍是单轮 artifact 证据策略；真实多轮 agent loop、手机端详细 trace 预览和 Agent C 云端 artifact 复判由后续闭环继续推进。

### v0.5 / 引入 Agent X 循环迭代文档基线

日期：2026-07-04

核心变更：

- 新增 Agent X 召唤、职责、循环判断和停止条件。
- 将现有 Agent A/B/C 云端验证流程扩展为可被 Agent X 多轮调度。
- 更新 flow、flowchart、test、prompt README 和 README 中的协作说明。
- 明确本轮只做文档准备，不启动真实自动循环。

关键文件：

- `AGENTS.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/test/test.md`
- `md/prompt/README.md`
- `md/prompt/v0（协作自动化）/v0.5（引入AgentX循环迭代）.md`
- `update_log.md`

验证结果：

- `git diff --check` 通过。
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'` 通过。

遗留事项：

- 后续人工可用 `agentx:` 提供总目标 X，启动 Agent X 主控循环。
- Agent X 真正执行循环时，仍必须经过 Agent A 提示词、Agent B 实现 push、Agent C 云端 artifact 验收。

### v0.2 / 任务回合化游戏体验

日期：2026-07-03

核心变更：

- 增加 `ClawMissionRunSummary`、阶段轨道和主动作派生模型，把现有 loop/task/session 状态整理为任务目标、阶段、回合进度、下一步动作、风险、审批、阻断、结果和 artifact 摘要。
- 将电脑接管页首屏更新为 Mission Run 面板，主按钮只调用已有安全路径：启动任务回合、审批并继续、复核后重试；阻断和等待状态不绕过审批或策略。
- 补充 XCTest 和 Swift logic smoke，覆盖 idle、待审批、需处理、完成重试和阻断状态。
- 同步 README、协议和 flow 文档，明确本轮是手机端 presentation layer 优化，不改变 `claw.computer.control.v1` schema，不新增 Gateway action/artifact/event。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Views/ContentView.swift`
- `ClawTests/ClawTests.swift`
- `Tools/LogicSmoke.swift`
- `README.md`
- `Docs/claw-mobile-gateway-protocol.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证结果：

- Swift logic smoke 已通过，输出 `Claw logic smoke passed`。
- 无签名 iOS build 已通过，输出 `BUILD SUCCEEDED`。
- `git diff --check` 已通过，无输出。
- workflow YAML 语法检查已通过，输出 `yaml ok`。
- `plutil -lint Claw.xcodeproj/project.pbxproj` 已通过，输出 `OK`。
- push `origin/main` 后仍需等待 GitHub Actions `ci-results` 结果包供 Agent C 复判。

遗留事项：

- Mission Run 目前只显示 artifact kind 和计数；后续可继续增强手机端 artifact 预览、审批队列和回滚提示。
- Gateway smoke 由 GitHub Actions 云端重验证覆盖。

### v0.1 / 项目骨架与电脑接管原型

日期：2026-06-25 至 2026-06-27

核心变更：

- 建立 SwiftUI iPhone 控制台原型。
- 建立 Claw action schema、Gateway profile、mobile envelope、Gateway event reducer。
- 建立本地 Gateway Node 原型和 direct/WebSocket smoke。
- 增加 `runAgentLoop` 和 `agentTrace`，让 Gateway 能基于 session artifact 生成观察-规划-动作建议-验证轨迹。
- 增加 Shortcuts/App Intents 入口、本地模型 artifact 校验和模拟事件流。

关键文件：

- `Claw/Core/ClawModels.swift`
- `Claw/Services/ClawStore.swift`
- `Claw/Services/ClawShortcuts.swift`
- `Claw/Views/ContentView.swift`
- `Tools/claw-gateway-server.mjs`
- `Tools/claw-gateway-direct-smoke.mjs`
- `Tools/claw-gateway-smoke.mjs`
- `Tools/LogicSmoke.swift`
- `Docs/claw-mobile-gateway-protocol.md`
- `README.md`

验证结果：

- 已建立 Swift 逻辑 smoke、XCTest、Gateway direct smoke、Gateway WebSocket smoke。
- 最近一次文档整理任务未运行完整业务测试；需在下一次代码改动后按 `md/test/test.md` 重新执行相关测试。

遗留事项：

- 部分 README/协议文档仍需同步最新 `runAgentLoop`/`agentTrace` 细节。
- 需要将真实 Gateway 工具层从 prototype handler 抽成可插拔执行器。
- 需要补充完整 Accessibility bridge 和真实浏览器点击/表单控制。

## 历史维护记录

### 建立多 Agent 协作系统文档

日期：2026-06-28

核心变更：

- 按“人工 -> Agent A -> Agent B -> Agent C -> 人工复核”的迭代模式建立项目记忆和规范文档。
- 统一项目入口为 `AGENTS.md`。
- 新增 `update_log.md`、`md/prompt/README.md`、`md/test/test.md`、`md/flow/flow.md`、`md/flow/flowchart.md`。

关键文件：

- `AGENTS.md`
- `update_log.md`
- `md/prompt/README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证结果：

- 文档创建后需运行 `git diff --check`。
- 业务测试不要求运行，因为本次只建立文档和流程规范。

遗留事项：

- 后续 Agent A 应从 `v0.2` 开始继续分配提示词版本，除非人工指定版本。

### 补充 Agent C 版本提交规则

日期：2026-06-29

核心变更：

- 明确 Agent C 验收不通过时退回 Agent B，不创建版本提交。
- 明确 Agent C 验收通过后自动按版本号创建 git commit。
- 规范提交信息：`vX.Y: 简要概括本轮工作`，并要求最终输出版本号、commit hash、核心变更、关键文件、测试结果和遗留事项。

关键文件：

- `AGENTS.md`
- `md/flow/flowchart.md`
- `update_log.md`

验证结果：

- 文档-only 改动，需运行 `git diff --check`。

遗留事项：

- 当前修改本身不自动提交；后续从 Agent C 正式验收通过的版本开始执行自动提交规则。

### 升级 main 直推与云端结果包验收制度

日期：2026-07-03

核心变更：

- 将协作流程从本地 Agent C 提交验收升级为 `main` 直推、GitHub Actions 云端重验证和 Agent C 下载未加密结果包复判。
- 增加 Agent A/B/C 角色召唤、最终回复身份标识、main push 规则、失败时 main 追加修复 commit 规则。
- 新增 `ci-results` workflow 设计，要求产出 manifest、failure summary、JUnit/摘要、xcodebuild 日志、Swift/Gateway smoke 日志和 `.xcresult`。
- 说明本次是协作制度和验证骨架升级，不代表业务能力、产品质量或 Gateway 实现发生功能提升。

关键文件：

- `AGENTS.md`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `.github/workflows/ci-results.yml`

验证结果：

- 本地应运行 `git diff --check`。
- 本地应运行 `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/ci-results.yml"); puts "yaml ok"'`。
- 当前本地仓库未配置 `origin` 时，无法完成真实 `git push origin main`、GitHub Actions run 和 Agent C artifact 下载复判；配置远端后需补跑完整闭环。

遗留事项：

- 配置真实 `origin/main` 后，必须执行一次 main push 云端试跑，下载 `/private/tmp/claw-c-review-<run_id>/` 结果包，并核对 manifest 的 `commitSha`、`runId` 和 `runAttempt`。

## v0.79 真实发送一致性（2026-09-27）

普通任务 live envelope 现在以 `sent` wire 状态进入 Gateway，Bridge 与 Mission 开始/审批按钮显式使用 async transport；审批绑定当前 task ID，已发送任务不能重复审批或重复创建 session。新增 transport recorder、Mission 一次性发送与任务替换回归。v0.78 修复 run `36310198213` 的 103 项 iPhone/iPad XCTest、Swift/Gateway smoke 和 iOS/Catalyst Release 均通过；iPad 启动截图阶段超时，artifact `claw-ci-v0.78-main-8409d0ab66e1-run36310198213-attempt1` 已核对并判定不通过。当前 workflow 将设备预启动并优先选择 iPad mini，降低重复 boot 导致的云端耗时。

## v0.80 真实会话与模拟重试隔离（2026-09-27）

仅允许进程内登记的 simulated session 使用本机模拟 retry；live 或未知来源 session 拒绝重试并保留失败事件、artifact 与审批状态，Mission 继续路径同步 fail closed。

## v0.81 平台图标兼容性（2026-09-27）

修复云端 iPad 启动日志中的 `folder.badge.gearshape.fill` 无效 SF Symbol，统一为 `folder.fill`，并纳入平台日志验收。
