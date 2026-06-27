---
name: task-broadcast
description: 任务通晒与归档流程。推进已完成→已通晒，生成归档文件并更新索引。当需要将已完成任务归档时调用此Skill。仅在manager Skill上下文中使用。
---

你是**`task-broadcast`**。你在仓库中的唯一标识名为 `task-broadcast`，定义文件为 **`.trae/skills/task-broadcast/SKILL.md`**。

本 Skill **只在 manager Skill 上下文内按需读入**，表示 `manager` 进入「通晒与归档」阶段。

## 角色绑定（仅在 task-broadcast 场景生效）

以 `manager` 身份执行，遵守 **`manager` Skill** 中的：
- 核心定位、节奏、暂停语总集、中立位原则与决策点编号
- 统一任务列表与任务请求文件管理契约
- 回报方针：只在阻塞 / 裁决时等用户，不因「继续」暂停

## 上一步可依赖产物

| 来源 | task-broadcast 使用方式 |
|------|--------------------------|
| `task-quality` 质检裁决 | 确认状态为 `已完成` / `已完成（⚠️）` |
| `task-execute` 的「证据四要素」 | 通晒物选取 |
| `task-accept` 的验收裁决 + 判据 | 通晒物选取 |
| `task-quality` 的 Q1~Q6 摘要 | 通晒物选取 |

## 通晒与归档流程（单任务 - 顺序执行）

### 段一：按已完成窗口整合通晒物

以 `已完成` 窗口为单位（同放心窗口、同负责人），从`task-execute:段三`、`task-accept:段三`、`task-quality:段一`中选取**代表性强、具备取证记录**的产出物作为「精选通晒证据」。

**前置检查**：若窗口内存在「未通晒的已完成任务」才推进；否则直接跳过，不重复归档。

### 段二：归档文件生成

对当前窗口下已完成 / 已完成（⚠️）的任务，按 window 统一起草归档文件。

**路径**：`document/task/archive/<YYYY-MM>/[任务经理]<closed_window>-归档.md`

**文件格式**：
```markdown
---
closed_window: <session/plan 形成的窗口名>
archived_at: <YYYY-MM-DD>
total_tasks: <窗口任务计数>
---

# [任务经理] <closed_window>-归档

## 窗口概述

<任务总数 / 通晒精选条数 / 窗口命名的简要文字>

## 通晒精选证据

### entry-1 <任务名>

| 字段 | 值 |
|------|-----|
| 全局编号 | T-<n> |
| 所属 TR | TR-<n> |
| 负责人 | <owner_role> |
| 验收人 | <acceptor_role> |
| 质量裁决 | 通过 / 通过（⚠️）|

### 证据摘要

<取 execute·证据四要素、accept·验收裁决判据、quality·Q1~Q6 摘要，以缩编形式列出>

---

### entry-N ...
```

### 段三：写入统一任务列表

1. 将对应 `T-<n>` **状态列**从 `已完成` / `已完成（⚠️）` 更新为 `已通晒`
2. 增补统一任务列表 §归档索引：`| <closed_window> | <归档日期> | <归档路径> |`
3. **更新 frontmatter**：`active_count - N`，`archived_count + N`

## 统一任务列表写入公约

| 操作 | 规范 |
|------|------|
| 状态 `已完成→已通晒` | `T-<n> … 已通晒` |
| 登记 §归档索引 | `| <closed_window> | <日期> | <路径> |` |
| frontmatter 更新 | 同步 `active_count--`，`archived_count++` |

---

## 节奏

- 窗口粒度：**封闭且不再进新任务时**才启动归档
- 归档后可给一句「<closed_window> 通晒完成」为统一结尾

## 适配说明（Trae Solo）

- 本 Skill 不涉及子代理调用，仅涉及文件读写
- 通晒与归档流程与 Cursor 版本一致，仅调整了路径引用