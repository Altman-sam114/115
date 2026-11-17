# 当前任务工作台

状态：v0.87 已验收；v0.88 实现中，总目标仍进行中。

## 目标与验收

- 目标：Mac/iPad 主输入聚焦 AI 计划、提供真实平台权限引导；拆分 ContentView 命令面板；建立可审计 workspace 选测。
- 非目标：不更改执行/审批合同，不新增 action/artifact，不声称真实模型或桌面 E2E 已完成；不改 aitrans、不开子 agent、仅云端编译。
- 验收：iOS/Catalyst Release、相关 workspace XCTest、双平台启动截图、manifest/JUnit 中 selected/skipped 与失败门槛一致；未知范围回退 full。

## 基线与编辑记录

- main / 6150c8c28bc8bd3201e0dda3642863cf88505bb7，与 origin/main 一致。
- 既有用户改动仍为流程文档、workflow paths-ignore、工程 DEVELOPMENT_TEAM/xcuserdata、历史文档；保留且只暂存本轮 hunks。
- 本轮预计：ContentView、独立 PhoneAgentCommandPanel、project.pbxproj（只加文件引用）、ci-results.yml（只选测）、Tools/select-ci-scope.py、md/test/test.md（仅本轮选测段落）、Docs/platform-capabilities.md、update_log.md（仅本轮追加）、work.md。

## 计划与进度

- [x] v0.87 修复与验收：6150c8c / run 44074605185 attempt 1 / claw-ci-v0.87-main-6150c8c28bc8-run44074605185-attempt1，2,028,174 bytes；manifest/JUnit/实际日志 16 项通过，双设备各 175 passed/0 failed/0 skipped，xcresulttool 只读解码一致，双 PNG 实际打开，ready attempt=2，native signing 正确。Metal runner 搜索路径 warning 保留。
- [x] 增加自动 workspace/full；whole-push 范围、未知回 full、云端自测、显式 skipped、实际 xcresult 摘要计数门槛。首次 CI/工程修改自动 full，因所有门槛/汇总均受影响，全部检查相关。
- [x] 命令面板独立文件；AI 主入口/⌘Return、菜单内规则与演练、大字体 AnyLayout；按需引导含共享连接配置和平台权限说明。
- [x] git diff --check / YAML / plutil 与 pbx ID 唯一检查通过；仅暂存本轮 hunks（排除 paths-ignore、DEVELOPMENT_TEAM 与既有流程重写）。
- [ ] main commit/push，首次 full（CI/工程改动需要验证所有被影响的门槛），后续纯展示切片验证 workspace 分支。
- [ ] 云端结果包核对、实际看图、日志收口。

## 验证与证据

- baseline：git diff --check、YAML 解析、工程 plutil lint、本地链接和 diff 范围核对。
- direct：workspace profile 选择器云端自测；iOS/Catalyst build；工作台导航、窗口/大字体与编辑状态的选中 XCTest；双平台真实启动截图。
- optional：不跑 Gateway/model/Swift fixture，未修改它们或执行合同；若改动超出 allowlist 选择器必须 full。
- 本机禁止编译、smoke、fixture、node syntax、模拟器；只读解码下载的 xcresult 不启动测试。
- commit/run/attempt/artifact：待本轮提交。

## 恢复入口

- 当前：实现 v0.88；读取 work.md 和真实 diff 后继续。
- 下一步：选测与 UI；通过后推进有界证据输入与真实模型多轮计划切片。
- 发布遗留：真实模型质量、桌面 E2E、签名/分发/隐私、Mac/iPad 人工交互；详见 Docs/platform-capabilities.md。
