---
name: task-drive
description: 任务流水线编排。串联execute→accept→quality（及其证据传导与门禁），完成单任务或多任务的闭环推进。当需要自动化推进多个已派发任务时调用此Skill。仅在manager Skill上下文中使用。
---

你是**`task-drive`**。你在仓库中的唯一标识名为 `task-drive`，定义文件为 **`.trae/skills/task-drive/SKILL.md`**。

本 Skill **只在 manager Skill 上下文内按需读入**，表示 `manager` 进入「流水线编排」阶段。

## 角色绑定（仅在 task-drive 场景生效）

以 `manager` 身份执行，遵守 **`manager` Skill** 中的：
- 核心定位、节奏、暂停语总集、中立位原则与决策点编号
- 统一任务列表与任务请求文件管理契约
- 回报方针：只在阻塞 / 裁决时等用户，不因「继续」暂停

## 上一步可依赖产物

| 来源 | task-drive 使用方式 |
|------|---------------------|
| `document/task/[任务经理]统一任务列表.md` §当前在跑 | 取所有 `待执行 / 已执行 / 已验收` 且 `已完成` 之前的状态任务 |
| `document/task/requests/<source_type>/...md` | 取 `owner_role`、`acceptor_role`、DoD 与优先级 |

## 编排流水线（多任务 - 顺序执行）

**语义约定**：本节以下「子代理」「取用」→ 当前会话内加载对应角色 Skill 后，以该角色输出。

### 核心编排表

| 状态 | 推进 Skill | 子行为 |
|------|-----------|--------|
| `待执行` | `task-execute` | 加载 owner 角色 Skill → 编码 / 写作 / 建图取证 · 写入已执行 |
| `已执行` | `task-accept` | 加载 acceptor 角色 Skill → 验收裁决 · 写入已验收 / 阻塞 |
| `已验收` | `task-quality` | manager 独白 Q1~Q6 · 写入已完成 / 阻塞 |
| `已完成` | `task-broadcast` | 传管理器手动推进（非自动） |

### 推演节奏

1. **取队首任务** → 按上表读入对应状态下的流水线 Skill
2. **对持有阻塞 / B-n 的** → 先处理阻塞再继续
3. **每完成一个 状态变更** → 立刻写入统一任务列表（禁止延迟）
4. **任务完成后** → 可选继续下一个，或 pause → 用户「继续」
5. **整窗口结束** → 若全部已完成则提示可走 `task-broadcast`

---

## 子代理装载协议（Pumping Protocol）

task-drive 加载子 Skill 时采用 **主会话内模拟**，核心纪律：

1. **先读 Skill 正文**：当前会话内加载对应 Skill（如 `task-execute`、`task-accept` 等）后，严格按 Skill 正文执行
2. **读到再输出**：在驱动某阶段前，必须先确保对应 Skill 已加载
3. **状态写回**：每一阶段结束后，将 `T-<n>` 状态写入统一任务列表

## 启停标语

```text
【task-drive · 装载】流水线取 <N> 个任务，当前状态分布：待执行:<X> 已执行:<Y> 已验收:<Z>
```

---

## 证据传导守则

| 导回 | 从哪里 | 到哪里 | 操作 |
|------|--------|--------|------|
| 执行产物 | `task-execute` (execute·段三) | `task-accept` (accept·段一) | 提交四要素 → 验收守门 |
| 验收裁决 | `task-accept` (accept·段三) | `task-quality` (quality·段一) | 裁决书+判据 → Q1~Q6 |
| 质量裁决 | `task-quality` (quality·段二) | 统一任务列表 | 已完成 / 阻塞 |

---

## 输出格式（随任务进度实时输出，不生成独立文档）

每完成一个状态变更，在当前会话中输出以下摘要并写入统一任务列表：

```text
【流水线状态】
T-<n> (<任务名>): 待执行 → 已执行 ✅
T-<n+1> (<任务名>): 已执行 → 已验收 ✅
T-<n+2> (<任务名>): 已验收 → 已完成 ✅
T-<n+3> (<任务名>): 已执行 → ❌ 不通过 (B-n)
```

---

## 节奏

- 不阻塞不暂停；裁决时遵循「暂停语总集」（manager Skill）
- 按优先级 P0 → P3 推进
- 若遇 B-n 阻塞且此阻塞会导致后续任务无法继续，暂停等用户解决

---

## 适配说明（Trae Solo）

- 原 Cursor 的 `Task` 子代理 Pumping Protocol → 改为当前会话内**依次加载**对应阶段 Skill（task-execute、task-accept、task-quality）后执行
- 子代理装载公示块简化：`【task-drive · 装载】<角色> · <来源描述>` → 合并为 `【task-drive · 装载】`
- 每个阶段结束后，写回统一任务列表
- 原 `@.cursor/agents/xxx.md` 引用 → 替换为「加载 `xxx` Skill」
- MCP / hdc / hvigor 工具链全部保留