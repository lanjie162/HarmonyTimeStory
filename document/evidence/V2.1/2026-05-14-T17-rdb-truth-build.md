# T-17 · RDB 真相源（TR-20260514-01#C-1）· 构建证据

**日期**：2026-05-14  
**owner**：dev  
**关联派发**：`document/task/requests/plan/[任务经理]2026-05-14-[V2.1]-持久化闸门五任务派发.md` **C-1**

## 结论

- **ArkTS-Check**：`RepositoryImpl.ets`、`AppDataInstaller.ets` 等关键文件经 MCP **check_ets_files** 无 **Error**（`ValuesBucket` 已改为 `relationalStore.ValuesBucket` 字面量形式）。  
- **整包构建**：MCP **build_project**，`module=entry@default`，`build_intent=LogVerification` → **BUILD SUCCESSFUL**（hvigor `assembleHap`，约 3m31s）。

## 代码锚点（L2 可追溯）

| 主题 | 路径 |
|------|------|
| 数据面接口 | `entry/src/main/ets/infrastructure/api/AppDataStore.ets` |
| RDB 实现 | `entry/src/main/ets/infrastructure/repository/RepositoryImpl.ets` |
| Schema v1 | `entry/src/main/ets/infrastructure/data/RdbSchema.ets` |
| 装配 | `entry/src/main/ets/bootstrap/AppDataInstaller.ets` |
| 启动顺序 | `entry/src/main/ets/entryability/EntryAbility.ets`（`getRdbStore` → `ensureSchemaV1` → `RepositoryImpl.attachRdb` → `installAppDataStore` → `loadContent`） |
| 领域服务 | `entry/src/main/ets/features/person/PersonFeature.ets`、`features/story/StoryFeature.ets` |

## 说明

- **`LocalMemoryStore`**：文件保留，主应用路径已不再通过 `singletonMemoryStore` 作为唯一真相；后续单测若需内存实现可显式 `new PersonService(memStore)` 扩展（当前未接）。  
- **T-18**：`schema_meta.version` 当前由 `RdbSchema` 写入门闩值；与 ADR 一致的「失败不推进 / 步骤幂等」细化归 **T-18**。
