# Issue tracker：GitHub

本仓库的 issue 与 spec 以 GitHub issue 形式存在，所有操作使用 `gh` CLI。

## 约定

- **创建 issue**：`gh issue create --title "..." --body "..."`，多行正文用 heredoc。
- **读取 issue**：`gh issue view <number> --comments`，配合 `jq` 过滤评论并获取标签。
- **列出 issue**：`gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`，配合 `--label` 与 `--state` 过滤。
- **评论 issue**：`gh issue comment <number> --body "..."`
- **应用 / 移除标签**：`gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **关闭**：`gh issue close <number> --comment "..."`

仓库从 `git remote -v` 推断——在克隆目录内运行时 `gh` 会自动处理。

## 以 PR 作为请求面

**PR 作为请求面：否**。（若本仓库将外部 PR 视为功能请求，可改为 `yes`；`/triage` 会读取此标志。）

设为 `yes` 时，PR 与 issue 使用相同的标签和状态，通过 `gh pr` 等价命令操作：

- **读取 PR**：`gh pr view <number> --comments`，diff 用 `gh pr diff <number>`。
- **列出待 triage 的外部 PR**：`gh pr list --state open --json number,title,body,labels,author,authorAssociation,comments`，只保留 `authorAssociation` 为 `CONTRIBUTOR`、`FIRST_TIME_CONTRIBUTOR` 或 `NONE` 的（排除 `OWNER`/`MEMBER`/`COLLABORATOR`）。
- **评论 / 打标签 / 关闭**：`gh pr comment`、`gh pr edit --add-label`/`--remove-label`、`gh pr close`。

GitHub 的 issue 与 PR 共享同一数字空间，因此裸 `#42` 可能是二者之一——用 `gh pr view 42` 判断，失败则回退 `gh issue view 42`。

## 当技能说“发布到 issue tracker”

创建 GitHub issue。

## 当技能说“获取相关工单”

运行 `gh issue view <number> --comments`。

## 探路（wayfinding）操作

供 `/wayfinder` 使用。**地图**是一个单 issue，**子工单**作为 ticket。

- **地图**：一个带 `wayfinder:map` 标签的 issue，正文存放 Notes / Decisions-so-far / Fog。`gh issue create --label wayfinder:map`。
- **子工单**：作为 GitHub 子 issue 链接到地图（用 `gh api` 操作 sub-issues 端点）。未启用子 issue 时，把子工单加入地图正文的任务列表，并在子工单正文顶部写 `Part of #<map>`。标签为 `wayfinder:<type>`（`research`/`prototype`/`grilling`/`task`）。被认领后，工单分配给负责的开发者。
- **阻塞关系**：GitHub 原生 **issue 依赖**——UI 可见的规范表达。用 `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>` 添加边，其中 `<blocker-db-id>` 是阻塞者的数字 **数据库 id**（`gh api repos/<owner>/<repo>/issues/<n> --jq .id`，不是 `#number` 或 `node_id`）。GitHub 通过 `issue_dependencies_summary.blocked_by`（仅未关闭的阻塞者——实时门）报告。依赖不可用时，回退为在子工单正文顶部写一行 `Blocked by: #<n>, #<n>`。所有阻塞者关闭时工单解锁。
- **frontier 查询**：列出地图的未关闭子工单（`gh issue list --state open`，限定地图的子 issue / 任务列表），剔除有未关闭阻塞者（`issue_dependencies_summary.blocked_by > 0`，或 `Blocked by` 行中有未关闭 issue）或有 assignee 的；按地图顺序取第一个。
- **认领**：`gh issue edit <n> --add-assignee @me`——本次会话的首次写操作。
- **解决**：`gh issue comment <n> --body "<answer>"`，然后 `gh issue close <n>`，再把上下文指针（gist + 链接）追加到地图的 Decisions-so-far。
