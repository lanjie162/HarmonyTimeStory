# Skill: task-broadcast（task 包 · 原子）

> **Skill 元信息**
>
> - **属于**：[`manager`](../../../manager.md)
> - **层级**：task 包 · **原子层**
> - **目的**：把统一任务列表 §当前在跑 中状态为 `已完成` 的任务推进为 `已通晒`：
>   1. 上游回填：更新任务请求文件 §接收记录 + 上游产物的 `task_request` 字段为 `closed`
>   2. 状态扭转 `已完成 → 已通晒`
>   3. 触发归档：把 `已通晒` 任务从 §当前在跑 移到 `document/task/archive/<YYYY-MM>/`，§归档索引 留印
> - **入口**：
>   - 用户字面：「通晒 T-12」「关掉 T-13」「归档已完成」
>   - §当前在跑 中状态=`已完成` 的任意任务
> - **专属编号**：不分配新编号；引用 `T-n` / `B-x` / `TR-…`
> - **来源选型触发**：**每条任务开始**（阶段一步骤 1）。规则按 [`manager.md`](../../../manager.md) §来源选型 §节奏 §暂停语总集 执行
> - **主入参**：单条 `T-n`（状态=`已完成`）
> - **主出参**：任务请求 §接收记录 + 上游 `task_request` 字段（`accepted → closed`）+ §当前在跑 该 T-n 的 `通晒回填` 列填充 + 状态 `已完成 → 已通晒` + 归档动作（§当前在跑 行迁移到归档文件 + §归档索引 留印）

## 信息边界（强制）

> 引用 [`manager.md`](../../../manager.md) §任务请求契约 → 信息边界。本 skill 在回填上游 `task_request` 字段时**严禁写入 `T-<数字>`**，只能维护 `TR-…#C-<n>(closed)`。
>
> 任务请求文件 §接收记录 是 `T-n` 与 `C-<n>` 的内部映射点（task 包内部物件），可保留 `T-n` 字段。

## 通晒口径

| 步骤 | 操作 | 物件 |
|------|------|------|
| 1 | 上游产物 `task_request` 字段：`#C-<n>(accepted) → #C-<n>(closed)` | 评审纪要 / 计划 / ad-hoc 命题文档 |
| 2 | 任务请求 §接收记录 该明细行追加 `closed_at`、`完成证据链接` | task 请求文件 |
| 3 | 任务请求 frontmatter `status`：全部 `closed` 后置 `closed`；部分则保持 `partially_accepted` 但加备注 | task 请求文件 |
| 4 | §当前在跑 该 T-n 的 `通晒回填` 列填充 + `状态` 列扭转为 `已通晒` | 统一任务列表 |
| 5 | §当前在跑 该 T-n 行迁移到 `document/task/archive/<YYYY-MM>/<原行>.md` | 统一任务列表 + 归档目录 |
| 6 | §归档索引 追加一行：`T-n / TR-…#C-<n> / 归档时间 / 归档文件路径` | 统一任务列表 |

## 归档协议

引用 [`manager.md`](../../../manager.md) §归档协议。本 skill 是归档动作的**唯一执行者**：

- 归档触发条件：本 skill 在阶段二步骤 5 完成状态扭转为 `已通晒` 后立即执行
- 归档目标路径：`document/task/archive/<YYYY-MM>/T-<n>-<任务摘要简化>.md`
- 归档文件内容：
  ```yaml
  ---
  task_id: T-<n>
  source_request: TR-…#C-<n>
  source_doc: <上游产物路径#锚点>
  archived_at: <YYYY-MM-DD>
  final_status: 已通晒
  ---
  ```
  正文：原 §当前在跑 该 T-n 行的全部列内容（任务摘要 / owner_role / acceptor_role[] / DoD / 执行结果 / 验收结论 / 质检结论 / 通晒回填 / 备注）
- §归档索引 追加行格式：

  ```text
  | T-n | 任务摘要 | TR-…#C-<n> | 归档时间 | 归档文件路径 |
  ```

- §当前在跑 该 T-n 行物理删除（不留 `已通晒` 行 —— 终态走归档，不在 §当前在跑 占位）
- 统一任务列表 frontmatter `active_count` -1，`archived_count` +1

## 核心工作流

### 阶段一 · 任务读取与上游产物定位

1. **【条目 Tn · 来源】**（必达，用户暂停点）
   - 触发节点：每条任务进入本 skill 的第一步
   - 选项与暂停语：使用 [`manager.md`](../../../manager.md) §暂停语总集 第 1 行（`【来源】` 模板，前缀写为 `【条目 Tn · 来源】`）
2. 读 §当前在跑 该 `T-n` 行：
   - 状态必须 = `已完成`；否则提示「不在通晒环节，跳过」并退出
   - 读取 `任务摘要` / `来源任务请求反链`（`TR-…#C-<n>`）/ `执行结果` / `验收结论` / `质检结论`
3. 由 `来源任务请求反链` 定位任务请求文件路径：

   ```text
   document/task/requests/<source_type>/<file>.md  # 由 TR-… 解析
   ```

4. 由任务请求文件 frontmatter `source_doc` + `source_anchor` 定位上游产物路径
5. 公示：

   ```text
   【broadcast 准备】T-<n>；任务请求=<TR-…#C-<n>>（路径 …）；上游产物=<source_doc#anchor>。
   ```

### 阶段二 · 上游回填 + 状态扭转 + 归档

1. **回填上游产物 `task_request` 字段**（按 §通晒口径 步骤 1）：
   - 找到上游 `source_anchor` 处对应的 `task_request` 字段
   - 把 `TR-…#C-<n>(accepted)` 修改为 `TR-…#C-<n>(closed)`
   - **严禁**写入 `T-<数字>`

2. **回填任务请求 §接收记录**（按 §通晒口径 步骤 2）：
   - 找到 §接收记录 表中 `明细编号=C-<n>` 的行
   - 追加 / 更新 `closed_at` 列、`完成证据链接` 列（取 `执行结果` 列中的关键证据路径）
   - 期望表头扩展：

     ```text
     | 明细编号 | 决策 | 统一任务列表编号 | accepted_at | closed_at | 完成证据链接 |
     ```

3. **更新任务请求 frontmatter `status`**（按 §通晒口径 步骤 3）：
   - 该 TR-… 文件内全部明细都已 `closed` → `status: closed`
   - 仍有未 `closed` 明细 → 保持原 `status`，但在 frontmatter 加注 `notes: 部分明细已闭环（C-1, C-3）`

4. **写 §当前在跑 该 T-n 的 `通晒回填` 列**：

   ```text
   通晒 by broadcast @ <YYYY-MM-DD>; 上游=<source_doc#anchor>; 已置 closed; 任务请求=<TR-…#C-<n>>
   ```

5. **状态扭转**：`已完成 → 已通晒`

6. **执行归档**（按 §归档协议）：
   - 创建归档目录（若不存在）：`document/task/archive/<YYYY-MM>/`
   - 写归档文件：`T-<n>-<任务摘要简化>.md`（含 frontmatter + 原行内容）
   - §归档索引 追加行
   - §当前在跑 该 T-n 行物理删除
   - 统一任务列表 frontmatter `active_count -1` / `archived_count +1` / `last_updated` 更新为今天

7. 输出 `【已通晒并归档】T-<n>，TR-…#C-<n> = closed，归档：<archive 路径>。`

### 阶段三 · 收口

1. 本轮处理摘要：

   ```text
   ## 【broadcast 摘要】
   - 通晒并归档：N1 条
   - 上游回填失败（待补）：N2 条
   - 阻塞升级：N3 条
   ```

2. 阻塞 → 升级 manager 后退出。

## Task 委派模板

通常 broadcast 不需要切角色子代理，由本 skill 在 manager 上下文直接执行（动作以读写文件为主）。

如遇上游产物归 `pm` / `architect` 维护且需要二次确认，可按需委派：

```text
【委派方式】Task（任务：T-<n>，通晒回填确认）；subagent_type=<pm|architect>；要求：确认 §source_anchor 修改前后一致性。
```

## 阻塞单格式

```text
## 阻塞单 B-<序号>
- 关联条目：T-<n>
- 阻塞类型：上游产物已被改名 / 已被归档 / `task_request` 字段缺失 / 任务请求文件丢失 / 多上游冲突
- 触发条件：…
- 已尝试：…
- 升级路径：→ manager（由 manager 决定是否新建一次性回填 / 跨期归档）
- 截止预期：…
```

阻塞单同步追加到统一任务列表 §阻塞单。

## 输出格式（默认）

```text
## 【broadcast 准备】公示
## 上游 task_request 字段更新前后对比
## 任务请求 §接收记录 行更新
## 任务请求 frontmatter status 更新（如有）
## §当前在跑 T-n 行更新（通晒回填列、状态扭转）
## 归档动作（archive 路径、§归档索引、active_count/archived_count 调整）
## 【broadcast 摘要】
## 阻塞单（若有）
```

## 注意事项（task-broadcast 专属）

- **信息边界守门**：上游 `task_request` 字段只写 `TR-…#C-<n>(closed)`，**严禁**写入 `T-<数字>`
- **归档动作不可逆**：归档前必须确认状态确实为 `已通晒`；不接受用户跳过质检直接归档（绕过 quality skill 视为流程违规，提示并阻止）
- **不跨列写**：仅写 §当前在跑 该 T-n 的 `通晒回填` 列与 `状态` 列；不写其他业务列
- **不跨任务**：单次通晒只服务本 T-n（编排批量由编排层 skill 负责，原子层守住单条边界）
- **上游不可达不强写**：若上游产物路径已不存在 / 已改名，转阻塞单升级 manager（不擅自创建）；本 skill 不负责修复上游
- **空目录策略**：归档目录按 `<YYYY-MM>` 按需创建，不预创建空目录
- **frontmatter 维护**：每次归档完成必须同步 `active_count` / `archived_count` / `last_updated`

> 通用注意事项（保持中立 / 灵活适配 / 上下文管理 / 引用规范 / 完整性兜底）见 manager.md §注意事项。

风格：中文；结论先行；表格优先。

**状态（manager 自用）**：`[准备 / 上游回填 / 状态扭转 / 归档执行 / 阻塞升级]`
