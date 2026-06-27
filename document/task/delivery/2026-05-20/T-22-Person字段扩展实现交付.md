# T-22 (C-1) Person 字段扩展 — 实现交付

---

## 1. 任务元信息

| 项目 | 值 |
|------|-----|
| 任务编号 | T-22 |
| 明细编号 | C-1 |
| 版本 | V2.2 数据模型补全版 |
| owner_role | dev |
| acceptor_role[] | [qa, pm] |
| 复杂度 | M |
| 优先级 | P1 |
| 来源 | `TR-20260520-01#C-1` |
| 交付日期 | 2026-05-20 |

---

## 2. 完成确认

### 权威锚点

- `document/requirement/时光故事-MVP需求说明-v4.md` §6.1 Person 字段表
- `document/design/时光故事-MVP-UI原型-v1.md` §4.2/§4.4
- 评审纪要 M1：「Person 类型枚举与 UI 原型 §4.2 对齐」

### 枚举值对齐

| 字段 | 权威锚点值（采用） | C-1 摘要原文（未采用） |
|------|-------------------|----------------------|
| type | 宝宝/成人/长辈/其他（默认其他） | 自定义/系统（笔误）|
| gender | 男/女/未填 | 男/女/未知（笔误）|

---

## 3. 变更文件清单

| # | 文件路径 | 变更类型 | 说明 |
|---|---------|----------|------|
| 1 | `entry/src/main/ets/domain/model/Models.ets` | 新增枚举 + 接口扩展 | GenderEnum、PersonTypeEnum、PersonModel 新增 5 字段 |
| 2 | `entry/src/main/ets/infrastructure/data/RdbSchema.ets` | DDL 升级 | person 表追加 5 列；SCHEMA_META_VERSION 1→3；修复旧 DB 版本跳跃 bug |
| 3 | `entry/src/main/ets/infrastructure/data/MigrationRegistry.ets` | 新增迁移步骤 | v2→v3: ALTER TABLE person ADD COLUMN (5 列) |
| 4 | `entry/src/main/ets/infrastructure/data/DataImpl.ets` | 新增测试上下文 | createV2SampleContext() + migrateV2ToV3() |
| 5 | `entry/src/main/ets/infrastructure/api/AppDataStore.ets` | 接口扩展 | CreatePersonParams/UpdatePersonParams + IAppDataStore 签名 |
| 6 | `entry/src/main/ets/infrastructure/repository/RepositoryImpl.ets` | SQL 全量改造 | listPersons/getPerson/createPerson/updatePerson + linkedPersonsForStory |
| 7 | `entry/src/main/ets/infrastructure/store/LocalMemoryStore.ets` | PersonModel 兼容 | PersonModel 新增字段默认值适配 |
| 8 | `entry/src/main/ets/features/api/Services.ets` | 接口扩展 | IPersonService 签名扩展 |
| 9 | `entry/src/main/ets/features/person/PersonFeature.ets` | 透传实现 | createPerson/updatePerson 全参数转发 |
| 10 | `entry/src/main/ets/pages/person/PersonDetailPage.ets` | UI 全字段编辑 | 头像 BLOB 选图/移除、类型选择、性别单选、生日 DatePicker、备注多行、档案摘要行 |
| 11 | `entry/src/main/ets/pages/person/PersonPage.ets` | UI 类型徽章 | 列表行显示类型标签 |
| 12 | `entry/src/main/ets/ohosTest/ets/test/Tier1RdbIntegration.test.ets` | 测试适配 | createPerson/updatePerson 调用适配新签名 |

---

## 4. 关键设计决策

| 决策 | 结论 | 理由 |
|------|------|------|
| 头像存储 | DB BLOB（person.avatar_blob） | 用户要求；方便未来迁移/备份 |
| 枚举序列化 | 整数存 DB | 与 photo_ref.ref_status 模式一致，类型安全 |
| Schema 迁移 | MigrationRunner v2→v3（ALTER TABLE）| 复用已有框架；向后兼容旧 DB |
| 生日类型 | INTEGER 时间戳 | 与 created_at/updated_at 一致 |
| ensureSchemaV1 行为 | 仅新库直接写版本号；旧库留由 MigrationRunner 升级 | 修复 v1→v3 版本跳跃 bug |

---

## 5. 自测记录

| 检查项 | 状态 |
|--------|------|
| 代码审查（6 文件核心逻辑） | ✅ |
| PersonModel 兼容性（LocalMemoryStore） | ✅ |
| DB schema 版本跳跃修复 | ✅ |
| 测试文件 API 适配 | ✅ |
| 枚举值对齐权威锚点 | ✅ |
| 构建通过 | ⏳待 IDE 构建验证 |
| 字段展示截图 | ⏳待真机验证 |

---

## 6. L1/L2 证据说明

| 证据等级 | 要求 | 当前状态 | 待执行 |
|----------|------|----------|--------|
| L1 | 代码引用检查（`DomainRules.maxStoryPhotos` 替换 → 本任务不涉及） | N/A | — |
| L2 | 构建通过 + 字段展示截图/日志 | 待验证 | IDE 构建 + hdc 截图 |

---

## 7. 回归建议

- **Tier1RdbIntegration**：`rdb_createPerson_trims_and_reads` 等 4 个 Person 测试已验证 API 适配
- **Tier2 回归（V2RegressionPerson）**：UI 层仅 `PersonPage` 增加类型徽章、`PersonDetailPage` 增加编辑字段，不改变原有交互路径，回归覆盖风险低
- **Schema 迁移**：建议 qa 在已有真实数据设备上做一次版本升级验证（V1/V2→V3），确认旧数据可正确读取

---

## 8. 参考文献

- MVP 需求 §6.1：`document/requirement/时光故事-MVP需求说明-v4.md`
- UI 原型 §4.2/§4.4：`document/design/时光故事-MVP-UI原型-v1.md`
- 评审纪要：`document/meeting/[主持人]2026-05-20-V2.2-V2.4增补计划评审纪要.md`
- 任务派发：`document/task/requests/plan/[任务经理]2026-05-20-[V2.2]-数据模型补全版全九任务派发.md`