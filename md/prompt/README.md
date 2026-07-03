# Prompt 目录

本目录保存每轮 Agent A 写给 Agent B 的详细实现提示词。

## 角色召唤

- `agenta`、`a:` 或 `A:`：召唤 Agent A。
- `agentb`、`b:` 或 `B:`：召唤 Agent B。
- `agentc`、`c:` 或 `C:`：召唤 Agent C。
- 没有角色前缀时，按普通 Codex 任务处理；如果任务需要 A/B/C 边界，先提醒用户指定角色，或明确本轮按普通任务执行。

最终回复身份标识：

- Agent A 第一行写：`我是 Agent A。`
- Agent B 第一行写：`我是 Agent B。`
- Agent C 第一行写：`我是 Agent C。`

## 命名建议

- `md/prompt/v0（项目初始化）/v0.1（建立迭代文档）.md`
- `md/prompt/v0（项目初始化）/v0.2（优化测试规范）.md`
- `md/prompt/v1（核心功能）/v1.0（实现主流程）.md`
- `md/prompt/v1（核心功能）/v1.1（修复主流程问题）.md`

## 版本管理规则

- Agent A 每次写提示词都必须写入版本号。
- 人工指定版本时，以人工指定为准。
- 人工未指定版本时，Agent A 自动判断版本，从 `v0.1` 开始。
- 同一阶段的小任务、修复、优化递增小版本，例如 `v0.1` -> `v0.2` -> `v0.3`。
- 大任务、架构阶段、核心功能阶段或重要里程碑新开大版本，例如 `v0.x` -> `v1.0`。
- 同一大版本下的提示词放在同一个目录：`md/prompt/v0（简要标题）/`、`md/prompt/v1（简要标题）/`。
- 文件名使用 `v0.1（简要说明）.md`，说明要短，能表达本轮目标。

## 云端阶段要求

Agent A 写提示词时必须默认采用 main 直推和云端结果包验收流程：

- Agent B 每轮开始前同步最新 `origin/main`，确认当前分支是 `main`，确认工作区无无关改动。
- Agent B 本地只跑与改动匹配的轻量检查；只有人工明确要求时才默认跑本机完整 build。
- Agent B 完成后提交本轮相关文件并 `git push origin main`，触发 GitHub Actions。
- Agent C 只验收 `origin/main` 最新 commit 对应的 workflow run 和未加密 CI 结果包。
- Agent C 必须通过 `gh auth login` 后下载结果包到 `/private/tmp/claw-c-review-<run_id>/`。
- Agent C 必须核对 `ci-artifact-manifest.json` 中的 `branch`、`commitSha`、`runId`、`runAttempt`、日志路径和 outcome。
- CI 失败时，Agent C 退回 Agent B 在 `main` 上追加修复 commit；默认不创建 PR、不使用候选分支、不回滚。
- CI 通过且文档齐全时，Agent C 输出版本汇报；如还需补文档，必须作为本轮相关 main 追加 commit 并重新验证。

本阶段不默认使用 `smalldata_test`、`develop`、`codeb/...` 或 PR 合并流；这些分支名只在人工另行要求时进入提示词。

## 每份提示词必须包含

- 版本号。
- 版本分配依据。
- 背景。
- 目标。
- 非目标。
- 当前架构依据。
- 实现步骤。
- 关键文件。
- 测试要求。
- main push 和 GitHub Actions 验证要求。
- CI 结果包内容、下载位置和 Agent C 复判要求。
- 文档更新要求。
- 验收标准。
- 风险和禁止项。
