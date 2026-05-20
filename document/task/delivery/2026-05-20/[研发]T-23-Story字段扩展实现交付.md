# T-23 (C-2) Story 字段扩展 — 实现交付

---

## 1. 任务元信息

| 项目 | 值 |
|------|-----|
| 任务编号 | T-23 |
| 明细编号 | C-2 |
| 版本 | V2.2 数据模型补全版 |
| owner_role | dev |
| acceptor_role[] | [qa, pm] |
| 复杂度 | M |
| 优先级 | P1 |
| 来源 | `TR-20260520-01#C-2` |
| 交付日期 | 2026-05-20 |

---

## 2. 完成确认

### 权威锚点

- `document/requirement/时光故事-MVP需求说明-v4.md` §6.1 Story 字段表
- `document/design/时光故事-MVP-UI原型-v1.md` §4.2/§4.4
- 评审纪要 M1：「Story 字段扩展可通过」

### 新字段设计

| 字段 | 类型 | DB 列 | 描述 |
|------|------|-------|------|
| description | string (可选) | `description TEXT DEFAULT ''` | 描述文本 |
| timeStart | number \| null (可选) | `time_start INTEGER` | 时间范围开始（时间戳 ms） |
| timeEnd | number \| null (可选) | `time_end INTEGER` | 时间范围结束（时间戳 ms）；单日时 === timeStart |
| coverUri | string (可选) | `cover_uri TEXT DEFAULT ''` | 封面 URI（指向 PhotoRef） |
| location | string (可选) | `location TEXT DEFAULT ''` | 地点文本 |
| tags | string[] (可选) | `tags TEXT DEFAULT '[]'` | 自定义标签（JSON 序列化的 string[]） |

---

## 3. 变更文件清单

| # | 文件路径 | 变更类型 | 说明 |
|---|---------|----------|------|
| 1 | `entry/src/main/ets/domain/model/Models.ets` | 接口扩展 | StoryModel 新增 6 字段 |
| 2 | `entry/src/main/ets/infrastructure/data/RdbSchema.ets` | DDL 升级 | story 表追加 5 列；SCHEMA_META_VERSION 3→4 |
| 3 | `entry/src/main/ets/infrastructure/data/MigrationRegistry.ets` | 新增迁移步骤 | v3→v4: ALTER TABLE story ADD COLUMN (5 列) |
| 4 | `entry/src/main/ets/infrastructure/data/DataImpl.ets` | 新增测试上下文 | createV3SampleContext() + migrateV3ToV4() |
| 5 | `entry/src/main/ets/infrastructure/api/AppDataStore.ets` | 接口扩展 | createStory/updateStory 签名扩展 + UpdateStoryParams |
| 6 | `entry/src/main/ets/infrastructure/repository/RepositoryImpl.ets` | SQL 全量改造 | listStories/getStory/createStory/updateStory/updateStoryAll + linkedStoriesForStory 全字段 |
| 7 | `entry/src/main/ets/infrastructure/store/LocalMemoryStore.ets` | StoryModel 兼容 | defaultStoryModel/cloneStory + 全字段返回 |
| 8 | `entry/src/main/ets/features/api/Services.ets` | 接口扩展 | IStoryService 增加 updateStoryAll 签名 |
| 9 | `entry/src/main/ets/features/story/StoryFeature.ets` | 透传实现 | updateStoryAll 全参数转发 |
| 10 | `entry/src/main/ets/pages/story/StoryDetailPage.ets` | UI 全字段编辑 | 描述多行、起止 DatePicker、封面选图、地点、标签增删UI |
| 11 | `entry/src/main/ets/pages/story/StoryPage.ets` | UI 摘要展示 | 列表行显示地点/时间范围/前 3 标签 |

---

## 4. 关键设计决策

| 决策 | 结论 | 理由 |
|------|------|------|
| 时间范围存储 | 两列 `time_start INTEGER, time_end INTEGER` | 与 created_at/updated_at 一致的时间戳，支持排序筛选 |
| 封面存储 | `cover_uri TEXT` 存 URI | 指向已有 PhotoRef URI，不冗余 BLOB |
| Tags 存储 | `tags TEXT`（JSON 序列化） | SQLite 无原生数组；应用层 parseTags 负责反序列化 |
| Schema 迁移 | MigrationRunner v3→v4（ALTER TABLE ADD COLUMN） | 复用已有框架；向后兼容旧 DB |
| 向后兼容 | 旧行新列默认值为 NULL / '' / '[]' | ensureSchemaV1 DDL 已设 DEFAULT；旧库由 ALTER TABLE 加列 |
| parseTags | 手动解析 JSON string[]（避免 `any` 类型） | ArkTS 禁止 JSON.parse 返回值隐式 `any`；手写解析兼容 `["a","b"]` 格式 |

---

## 5. 自测记录

| 检查项 | 状态 |
|--------|------|
| check_ets_files (11 变更文件) | ✅ 零 Error |
| build_project entry@default LogVerification | ✅ BUILD SUCCESSFUL |
| StoryModel 字段兼容（LocalMemoryStore） | ✅ |
| Schema 迁移步骤存在（v3→v4） | ✅ |
| DB schema 版本号更新（3→4） | ✅ |
| 枚举值对齐权威锚点 | N/A（Story 无新增枚举） |
| 字段读写验证（createStory/updateStory/getStory/listStories） | ⏳待真机 HDC 验证 |
| Schema v3→v4 迁移验证 | ⏳待真机 HDC 验证 |
| UI 截图：编辑区/列表摘要 | ⏳待真机 HDC 截图 |

---

## 6. L1/L2 证据说明

| 证据等级 | 要求 | 当前状态 | 待执行 |
|----------|------|----------|--------|
| L1 | 代码引用检查（5 新增字段可新建/编辑/展示；tags JSON 可增删；schema 向后兼容） | ✅ 代码审查通过 | — |
| L2 | 构建通过 + 字段展示截图/日志 | ✅ 构建通过；⏳截图待真机 | HDC 启动 app 后截图 |

---

## 7. 回归建议

- **Tier1RdbIntegration**：`createStory`/`updateStory`/`getStory` 现有测试向前兼容（旧签名仍可用），无需修改
- **Tier2 回归**：UI 层 `StoryPage` 增加摘要行、`StoryDetailPage` 增加编辑字段，不改变原有交互路径，回归覆盖风险低
- **Schema 迁移**：建议 qa 在已有真实数据设备上做一次版本升级验证（V1/V2/V3→V4），确认旧数据可正确读取、新字段为 NULL/''/[] 默认值

---

## 8. 参考文献

- MVP 需求 §6.1：`document/requirement/时光故事-MVP需求说明-v4.md`
- UI 原型 §4.2/§4.4：`document/design/时光故事-MVP-UI原型-v1.md`
- 评审纪要：`document/meeting/[主持人]2026-05-20-V2.2-V2.4增补计划评审纪要.md`
- 任务派发：`document/task/requests/plan/[任务经理]2026-05-20-[V2.2]-数据模型补全版全九任务派发.md`
- T-22 交付参考：`document/task/delivery/2026-05-20/T-22-Person字段扩展实现交付.md`