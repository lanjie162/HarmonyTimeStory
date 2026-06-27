# Bug #L3-1：`createStory` SQLite 插入失败修复方案

**角色**：dev（研发工程师）
**日期**：2026-06-05
**影响范围**：所有 L3 集成测试中依赖 `createStory` 的用例（L3StoryService 27条 + L3LinkPhotoService ~20条）

---

## 1. 根因分析

### 问题现象

```
SQLite: Generic error. Possible causes: Insert failed or the updated data does not exist.
    at createStory entry (RepositoryImpl.ets:299)
    at createStory entry (StoryFeature.ets:17:23)
```

### 根本原因

**`story` 表缺少 `photo_count` 列**，但 `RepositoryImpl.createStory()` 在 INSERT 的 ValuesBucket 中包含了 `photo_count: 0`。

### 证据链

| 位置 | 涉及 `photo_count` | 状态 |
|------|---------------------|------|
| `RdbSchema.ets:36-47` — `CREATE TABLE story (...)` | **无** `photo_count` 定义 | ❌ 缺失 |
| `MigrationRegistry.ets` — v3→v4 迁移 | **无** `photo_count` ADD COLUMN | ❌ 缺失 |
| `RepositoryImpl.ets:279` — `createStory` INSERT | 包含 `vb['photo_count'] = 0` | ❌ 使用时未定义 |
| `RepositoryImpl.ets:256,306,421` — SELECT | `SELECT ... photo_count` | ❌ 读时无列 |
| `RepositoryImpl.ets:135` — `rowToStory` | `getColumnIndex('photo_count')` | ❌ 读时无列 |
| `RepositoryImpl.ets:596,724` — UPDATE | `SET photo_count = ...` | ❌ 写时无列 |

### 为什么部分测试通过？

- **V2Regression E2E 测试（33条通过）**：复用设备上已有的数据库，该数据库来自更早的 `create table` 版本（当时包含 `photo_count`）
- **L3 集成测试（143条 Error）**：每次使用 `TestDbHelper` 创建**全新数据库**，`ensureSchemaV1` 生成的 `story` 表**不含** `photo_count`
- **L3PersonService 部分通过**：仅 `createPerson`（不涉及 photo_count）的用例通过

---

## 2. 修复方案

### 2.1 DDL 修复

在 `RdbSchema.ets` 的 `story` 表定义中增加 `photo_count` 列：

```sql
'photo_count INTEGER NOT NULL DEFAULT 0'
```

**文件**：`RdbSchema.ets:36-47`

### 2.2 Migration 补充

添加 v4→v5 迁移步骤，为早期版本创建的数据库补充 `photo_count` 列：

**文件**：`MigrationRegistry.ets`
- 新增 `applyV4ToV5` 函数：`ALTER TABLE story ADD COLUMN photo_count INTEGER NOT NULL DEFAULT 0;`
- 注册 `v4_to_v5_story_photo_count` 迁移步骤
- 更新 `RDB_SCHEMA_META_VERSION` 从 4 → 5

---

## 3. 改动清单

| 文件 | 改动内容 | 影响 |
|------|----------|------|
| `domain/data/RdbSchema.ets` | DDL 增加 `photo_count INTEGER NOT NULL DEFAULT 0` | 新数据库自动创建该列 |
| `domain/data/MigrationRegistry.ets` | 新增 v4→v5 迁移 + 更新版本号 | 存量数据库热升级 |
| `domain/data/RdbSchema.ets` | `RDB_SCHEMA_META_VERSION = 4` → `5` | 版本号对齐 |

---

## 4. 验证计划

### 4.1 构建验证
```bash
hvigor assembleDefault --mode module -p module=entry@default
hvigor assembleOhosTest --mode module -p module=entry@ohosTest
```

### 4.2 真机执行 L3 测试
```bash
hdc install entry-default-signed.hap
hdc install entry-ohosTest-signed.hap
hdc shell aa test -b com.lanjie162.timestore -m entry_test -s unittest OpenHarmonyTestRunner -w 300
```

### 4.3 期望结果
- L3PersonService：28条全部 PASS（回归确认无退化）
- L3StoryService：27条全部 PASS（原 Error → PASS）
- L3LinkPhotoService：24条全部 PASS（原 Error → PASS）
- V2Regression E2E：仍保持 33+ PASS（无退化）

### 4.4 存量数据库验证
确认 v4→v5 迁移不会影响已在设备上运行的生产数据库。

---

## 5. 风险与回归建议

| 风险 | 影响 | 概率 | 缓解 |
|------|------|------|------|
| `photo_count` DEFAULT 0 与运行时 UPDATE 时序错位 | 照片计数短暂滞后 | 低 | DEFAULT 0 + 首次 addPhoto 即 UPDATE +1，最终一致 |
| v4→v5 迁移在超大数据库中耗时 | 启动延迟 | 极低 | ALTER TABLE ADD COLUMN 是 O(1) 元数据操作 |
| `person` 表是否需要 `photo_count` | 当前代码不读/不写 person.photo_count | 无 | 无需改动 |

---

## 6. 后续优化项

- 确认 PersonModel 的 `photoCount` 字段缺失（当前未使用，但 StoryModel 有 `photoCount`），如需统一可跟踪独立任务