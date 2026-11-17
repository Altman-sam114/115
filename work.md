# 当前任务工作台

状态：执行中；总目标为 macOS / iPad 发布级智能体，当前先恢复 v0.87 云端验收。

## 目标与验收

- 目标：定位并修复 main v0.87 失败，取得新精确 SHA 的云端证据；随后推进 Mac/iPad 实用体验及权限引导。
- 非目标：不改只读参考 aitrans，不开子 agent，不本地编译/业务测试，不宣称原型已发布。
- 验收：相关 HTTP/Gateway/Swift 真实合同测试成功，iOS/Catalyst 编译和双设备 XCTest/启动证据可核对；保持认证、审批、workspace 和日志脱敏断言。
- 风险：既有 artifact 已过期，历史日志仅用于定位；真实模型/桌面操作/生产签名仍待专项。

## 基线与本轮编辑记录

- main / 02b8b024422be26cd2fbaaaec40f39d6808f3803，fetch 后 origin/main 同步。
- 已有改动：AGENTS/README/test/flow/protocol/release/log/prompt 文档、workflow paths-ignore、工程 DEVELOPMENT_TEAM、xcuserdata 与历史未跟踪文档。全部保留，不混入本轮提交。
- 本轮文件：work.md；Tools/claw-artifact-preview-smoke.mjs、update_log.md（仅追加本轮段落）。若需 workflow 修改仅暂存本轮 hunks。

## 计划与进度

- [x] 核对规范、真实 diff、授权账号 Altman-sam114、分支/远端、只读参考入口。
- [x] 获取旧 run 40624695706 attempt 1 日志：artifact-preview-smoke 在 approved fixture sessionCompleted 断言失败；其余 step 成功但不作为当前验收。artifact API 无可下载结果包。
- [x] 修复 authenticated fixture 指纹；增加缺失/错误指纹无副作用回归及精确 session cwd 断言，不放宽生产安全门槛。
- [ ] 静态复核、仅提交本轮文件、push main，跟踪精确 SHA。
- [ ] 下载必要结果包，核对 manifest/JUnit/日志/xcresult/实际截图。
- [ ] 记录结果后选择下一轮 Mac/iPad 优化目标。

## 验证与证据

- baseline：git diff --check、范围/diff 核对。
- direct：artifact preview smoke（含 registry、HTTP、真实 Gateway writer、生产 Swift transport），关联 Swift fixture/logic、iOS 与 Catalyst build、双平台 XCTest/启动。
- optional：本次接管未验收 v0.87 跨层结果读取改动（Swift model/Store/HTTP/UI/Gateway writer），其 Gateway direct/WebSocket/model HTTP 依赖和完整既有 16 项皆有相关性；本轮恢复这组验收，不声称已有模块选测。
- 账号：gh auth status 确认 Altman-sam114 active；不使用另一账号。
- 未运行：所有本地 build/XCTest/smoke/node syntax/模拟器，遵守 cloud-only。
- run/commit/artifact：待新提交。旧日志缓存 /private/tmp/claw-review-40624695706/actions.log。

## 恢复入口

- 当前根因：preview smoke envelope 缺 gateway.tokenFingerprint，Gateway validateEnvelope 在 session 建立前拒绝；继续核对 writer 内容及 workspace 断言。
- 下一步：修复夹具、云端验证。通过后按模型执行质量/权限引导/桌面与分屏体验选择下一切片。
