# 当前任务工作台

状态：总目标 active；v0.87/v0.88 已收口。当前 v0.89 有界证据规划已完成方案核对，开始实现；用户本轮明确授权持续多开子代理。

## 目标与验收

- 目标：用户明确选择一份已读取的 Live 文本结果后，让已配置的电脑模型依据该结果制定下一步计划，推进真实结果→AI 规划→人工复核闭环。
- 非目标：不自动上传结果、不读任意路径、不自动执行或审批、不新增 action/artifact、不下载模型权重、不本地编译、不改 aitrans。
- 并行策略：按用户最新要求，3个子代理分别负责后端、Swift回归、生产HTTP集成，主代理统一客户端和验收。
- 验收：客户端仅当前 clean/live/唯一 selection/已读快照可请求；Gateway 从内存注册表核对身份+digest，有界 8 KiB，不截断，过期/超限/伪造必须拒绝且不联系模型；固定模型 system contract 与 typed proposal/审批保留；关闭预览或 scope 变化使在途结果失效。同步协议、flow 与直接负向回归，并用新精确 SHA 云端结果包验收。
- 风险：提示词隔离不等于已证明防提示注入；本轮模型 stub 合同不能证明真实模型质量。生产签名/桌面 E2E/实际键盘和 VoiceOver 仍须专项。

## 基线与本轮编辑记录

- main / origin/main = 818246d865e4d56ab8c9dbe2bce2c2b1b7239cd4。
- 已验收最新展示范围：run 44082644085 attempt 1 / claw-ci-v0.88-main-818246d865e4-run44082644085-attempt1，1,442,383 bytes。selection/manifest/JUnit/logs 一致为 9 selected success + 7 explicit skipped，双设备各 9 passed/0 failed/0 skipped；xcresult 只读解码一致，原生签名和双 PNG 实际复核，ready 均 2。缓存 /private/tmp/claw-review-44082644085。
- full 基线 e85694d / run 44077364459 attempt 1 / claw-ci-v0.88-main-e85694d7332a-run44077364459-attempt1，1,989,048 bytes；16 项和双设备各 175 passed/0 failed/0 skipped，实际看图与签名通过。详情在 update_log.md。
- 用户遗留：AGENTS/README/flow/test/protocol/release/log/prompt 流程维护、workflow paths-ignore、DEVELOPMENT_TEAM、xcuserdata、历史未跟踪文档；不提交这些旧改动，不 stash/覆盖/回滚。
- 本会话收尾文档的本地新增：本文件、update_log.md 的本日结论与当前状态、Docs/release-readiness.md 的本日更新。尚未提交/推送，避免纯文档触发远端现有业务 CI（paths-ignore 为用户未提交改动）。下一轮暂存只取本轮 hunks。
- v0.89 预计编辑：ClawModelPlanning.swift、ClawStore.swift、ClawArtifactPreviewView.swift、PhoneAgentView.swift、PhoneAgentCommandPanel.swift（导航/计划ID归属）、claw-model-planner.mjs、Gateway 的 planning registry 注入、直接相关 Swift/Node 测试与协议/flow/日志；如需修改其他文件先记录原因。

## 计划与进度

- [x] 识别当前模型只有 command 输入、已有 preview 内存快照和身份/scope 保护；对照真实源码拟定方案。
- [x] 已重读规范/状态/源码，fetch 后 main 与 origin/main 同步；Altman-sam114 active。当前新增并行：后端三文件、Swift XCTest 两文件、生产 HTTP fixture 两文件；主代理负责 Core/Store/UI/文档。各代理不提交/不本地业务测试，根代理统一验收。
- [x] 定义可选 evidence 引用（task/artifact ID + SHA-256，不带原始正文/任意 path），保持无 evidence 请求兼容。
- [x] Gateway 用既有 ArtifactPreviewRegistry 查不可变快照、校验 digest/8 KiB，模型仅接收 command + 不可信 evidence 内容，不接收凭据/路径/原始身份；错误只固定诊断。
- [x] Store 仅接受当前已读 Live selection，捕获 preview generation；取消/关闭/任务/配置变化丢弃在途结果，保留已有参数复核和审批。
- [x] UI 提供明确的“把此结果交给电脑模型制定下一步计划”动作，保留内容不自动交给模型的边界；反馈超限/过期/等待/失败/取消。
- [x] 子代理完成后端矩阵、11 个新增 XCTest（预期186）、生产 Swift HTTP→Gateway writer snapshot→模型 stub 正负链路；只读交叉复核发现 UI 旧请求冒领替代计划ID和普通规划进度误归属风险，已改本次planID返回与isPlanning(using:)归属；模型固定模式区分普通目标原文和注册快照，避免JSON外观冒充已选证据。补断言；根代理另发现客户端strict JSON错误被误映射422，已修为400并新增原始JSON/UTF8/413与provider422回归，预计29个模型夹具请求。未削弱安全门槛。
- [x] 已同步协议/flow/测试说明；git diff --check 与 workflow YAML 解析通过；只暂存本轮 hunks，保留用户原 paths-ignore/签名与流程维护。
- [ ] main 精确提交/云端验证→结果包/截图复核，失败追加修复。

## 验证与证据

- baseline：git diff --check；修改配置时才 YAML/plutil/对象 ID；文档路径/diff 核对。
- direct：Swift request/Store scope/cancel/evidence input tests、Node registry digest/身份/容量/过期/错误不联系模型、生产 Swift HTTP→Gateway→模型 stub；受影响目标 iOS/Catalyst、双设备 XCTest/preview UI 启动。
- optional：涉及共享 Store/模型控制面/Gateway 注册表与 Swift/Node HTTP 合同，保守 selector 会 full；需在实现时按真实 diff 再核对关联范围。不以旧结果替代新 SHA。
- 未运行：v0.89 未实现故无新测试；始终禁本地 build/XCTest/Swift/Gateway smoke/fixture/node syntax/模拟器。
- 账号：上一轮每次 push 前 gh auth status 均为 Altman-sam114 active；下一次远端操作前重新核对。
- 云端慢证据：v0.88 full 的 iPad boot 数据迁移约 6 分钟，宿主首启再约 6 分钟，实际测试仅 12.5 秒；不要无证据归因于业务代码或删除断言。后续可单独改进云端模拟器生命周期。

## 恢复入口

- 从上述 v0.89 第 2 项开始，尚无业务实现，不要把方案当作已完成功能。
- 可复用 ClawArtifactPreviewSelection/Content、availableArtifactPreviews、artifactPreviewGeneration、ArtifactPreviewRegistry。
- HTTP model transport 当前允许 409、不允许 404；证据不可用建议固定 409。handleModelPlanning 当前只接受四个字段，加入 evidence 时保持 exact shape 和 duplicate-key/size 检查。
- 只读参考已查 aitrans 的 ModelSetupGuideView.swift；WorkBuddy 腾讯官方页 https://cloud.tencent.com/product/workbuddy 已读，结论见 Docs/platform-capabilities.md；未安装、登录或调用其服务。
- 总目标仍 active；真实模型质量/桌面 E2E、Mac/iPad 人工交互、生产签名与分发尚未验收，不能宣布发布级完成。
