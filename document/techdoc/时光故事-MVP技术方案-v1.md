# 时光故事（TimeStory）MVP 技术方案

**文档性质**：首版技术设计（与需求定稿对齐，随实现迭代升版）  
**版本**：V1.4.1  
**日期**：2026-05-06  
**关联文档**  
- 需求：[时光故事-MVP需求说明-v4.md](../requirement/时光故事-MVP需求说明-v4.md)（下称 **MVP**，定稿 **V4.4**：§8.4 三形态 + **IM-01～IM-10**，含 **8.4.0** 导入准备链路与 IM-10 双选项等交互收敛项）  
- 交互原型：[时光故事-MVP-UI原型-v1.md](../design/时光故事-MVP-UI原型-v1.md)（下称 **UI 原型**，**v1.2**：信息架构 `§2.2`、线框 `§4.0`）  
- 平台调研：[HarmonyOS平台能力调研表-v1.md](./HarmonyOS平台能力调研表-v1.md)（下称 **调研表**）  
- 待办：[TODO-跟踪.md](../TODO-跟踪.md)（**B2**、**§C** 与真机矩阵闭环）  
- 技术方案评审（交互裁定）：[2026-05-06-技术方案评审-交互决策附录.md](../meeting/2026-05-06-技术方案评审-交互决策附录.md)（**D-M1-1～D-M7-1**，与 **§6.1 / §6.3 / §9 / §12 O-3** 交叉引用）

---

## 1. 文档目的

在 **不替代需求条文** 的前提下，锁定 **工程结构、数据持久化、关键系统能力接入方式、任务与并发边界、验收可追溯映射**，作为 ArkTS 实现的单一技术入口。与 MVP 冲突时以 **MVP** 为准，并回修本文档。

---

## 2. 基线与约束

| 项 | 结论 |
|----|------|
| 最低系统 / API | **API version 12**；工程 `compatibleSdkVersion` **5.0.0(12)**（见根目录 `build-profile.json5`），与 MVP §9.1 / §9.4 一致。 |
| 应用形态 | 单 **entry** 模块、Stage 模型；首期设备类型 **phone**（与当前 `module.json5` 一致）。 |
| 原图与云端 | **不复制原图、不向自有服务端上传原图**；仅持久化系统授予的 **URI/资源标识** 与业务元数据（MVP §2、§6）。 |
| 人脸 | **端侧** Core Vision：`faceDetector`、`faceComparator`（文档起点与最低档一致，见调研表 §2.5-C、§6 R-04）。 |
| 真机矩阵 / 降级阈值 | 文档调研已结案；**数值化降级矩阵** 以 [TODO-跟踪 §C](../TODO-跟踪.md#todo-sec-c) 驱动调研表 §4 / §7 回填后再并入本文 **§10** 或升 **V1.1**。 |

---

## 3. 总体架构

### 3.1 分层结构

四层，每层对外暴露 **`api/`**（仅 interface / 类型），向内隐藏 **实现**。上层只能 import 紧邻下层 **`api/`** + **`domain/`**，不碰实现目录。

```
┌──────────────────────────────────────────┐
│  pages/         UI 层                     │
│                 import: api + domain      │
└────────────────┬─────────────────────────┘
                 │       features/api/
┌────────────────▼─────────────────────────┐
│  features/      业务层  ┌─ api/           │
│                         │  IPersonService │
│  ├─ person/             │  IStoryService  │
│  ├─ story/              │  IImportService │
│  ├─ import/             │  ISuggestionService │
│  └─ suggest/            │                 │
│      import: infrastructure/api + domain  │
└────────────────┬─────────────────────────┘
                 │       infrastructure/api/
┌────────────────▼─────────────────────────┐
│  infrastructure/ 基础设施层               │
│                         ┌─ api/           │
│  ├─ repository/         │  IPhotoRepository│
│  ├─ media/              │  IMediaPicker   │
│  ├─ vision/             │  IVisionService │
│  ├─ task/               │  ITaskRunner    │
│  └─ data/               │                 │
│      import: domain + @ohos.*             │
└──────────────────────────────────────────┘

  domain/        纯模型与规则（无 IO，所有层都可 import）
  bootstrap/     装配点（唯一可见所有实现 + api 的地方）
```

### 3.2 各层对外 API（`api/`）

`features/api/`（对外 = 给 `pages` 调用）
- `IPersonService` —— 人物的 CRUD、关联故事与照片
- `IStoryService` —— 故事的 CRUD、关联人物
- `IImportService` —— **MVP §8.4** 形态一 / 形态二：**选图 → 导入准备 → 条件 → 后台扫描 → 候选确认**（含取消、重试）；与 **`PhotoOwnerLink`** 定向写入编排
- `ISuggestionService` —— **形态三（§8.4.3）**：建议队列 / 未读数、单条与批量接受·忽略、**仅确认后** 写 **`PhotoOwnerLink`（人物）**；与 **IM-03、IM-10** 协同；**不得**与形态一/二混在一个「导入向导」接口内隐瞒副作用
- 返回类型用 `domain/` 中定义的 DTO，不返回 RDB 行对象

接口命名可在实现 PR 中微调，但 **`IImportService` 与 `ISuggestionService` 职责边界** 须保持上述分离。

`infrastructure/api/`（对外 = 给 `features` 调用，**`pages` 禁止 import**）
- `IPhotoRepository` —— PhotoRef 去重、查询、孤儿标记
- `IMediaPicker` —— 打开系统选图、返回 URI 列表
- `IVisionService` —— 人脸检测、1v1 比对
- `ITaskRunner` —— 后台长任务、进度、取消

### 3.3 目录约定

| 路径 | 性质 | 说明 |
|------|------|------|
| `bootstrap/` | 装配 | 创建所有 impl、注入；**唯一** 同时 import **`api/`** 与实现的地方 |
| `pages/shell/`、`pages/person/`、`pages/story/`、`pages/import/`、`pages/suggest/`、`pages/privacy/`、`pages/settings/` | UI | `@Component`、路由、薄 VM（逻辑路由域见 **§3.3.1**，对齐 **UI 原型 §2.2**） |
| `features/api/` | **公开** | **仅** interface / 类型，供 `pages` 调用 |
| `features/person/`、`features/story/`、`features/import/`、`features/suggest/` | **隐藏** | 实现 **`features/api/`** 中的接口；编排、状态机 |
| `infrastructure/api/` | **公开** | **仅** interface / 类型，供 `features` 调用 |
| `infrastructure/repository/`、`infrastructure/media/`、`infrastructure/vision/`、`infrastructure/task/`、`infrastructure/data/` | **隐藏** | 实现 **`infrastructure/api/`** 中接口；可调 RDB、`@ohos.*` |
| `domain/model/`、`domain/rules/` | 共享 | 纯数据与规则，所有层可 import |

### 3.3.1 逻辑路由域与 `pages/` 映射（对齐 UI 原型 v1.2 §2.2）

与 **UI 原型** 的「路由域」一一对应，便于评审与验收点名；实现可在各域下再拆子页文件，但 **域名与主导航归属** 不变。

| 路由域 | `pages/` 分包（约定） | 说明 |
|--------|----------------------|------|
| `shell` | `pages/shell/` | 启动、可选首次轻引导 |
| `person` | `pages/person/` | 人物列表 / 新建编辑 / 详情；**人物 Tab 顶栏**承载形态三 **未读建议徽章**（见 **§6.2**） |
| `story` | `pages/story/` | 故事列表 / 新建编辑 / 详情 |
| `import` | `pages/import/` | 形态一 / 二共用向导：**导入准备**、条件、扫描进度、候选确认 |
| `suggest` | `pages/suggest/` | 形态三：**人脸关联建议**审阅（单条 / 批量操作） |
| `privacy` | `pages/privacy/` | 隐私与说明静态页（PR-01 等） |
| `settings` | `pages/settings/` | 人脸与索引、清除特征缓存等（IM-10、PR-02） |

Shell 层 **底栏 Tab「人物 / 故事」** 由 **`shell` + `person` / `story` 内容区** 组合实现即可，具体文件拆分属实现细节，须在工程内保持一致。

### 3.4 约束（硬规则）

1. `pages/` 不得 import `features/person/` / `story/` / `import/` / `suggest/`。  
2. `pages/` 不得 import `infrastructure/api/` 及 `infrastructure/` 下任何路径。  
3. `features/` 不得 import `infrastructure/repository/` / `media/` / `vision/` / `task/` / `data/`。  
4. `features/` 与 `infrastructure/` 的实现文件不得 import ArkUI 组件。  
5. `features/` 的实现文件不得 import `@ohos.*`（系统能力全部封装在 `infrastructure/`）。

### 3.5 高层数据流（摘要）

1. **手动加图**：`PhotoViewPicker` → URI 列表 → **去重得到/复用 `PhotoRef`** → 写 **`PhotoOwnerLink`**（`ownerKind`=故事/人物）（事务内计数校验 **ST-07**）。  
2. **相册导入与智能关联（MVP §8.4）**：**形态一** 指定 `storyId` + 条件 → 后台扫描 → 候选确认 → **`PhotoOwnerLink`（故事）**；**形态二** 指定 `personId` + 条件 → 同上 → **`PhotoOwnerLink`（人物）**；**形态三** 对已入库 **`PhotoRef`** 后台挖掘 **人脸→人物建议** → **仅确认后** 写 **`PhotoOwnerLink`（人物）**。**「地点」**（形态一、二若启用）实现语义：坐标 ∩ 逆地理列（**§4.2 `PhotoRef`**），与 **MVP IM-05** 无坐标 **NULL** 降级一致；**不**把地点主数据放在 `scanSummaryJson`。  
3. **删除与 GC**：边表删除 → `PhotoRef` 若无任何边则 **标记孤立** → 启动/闲时任务物理删行及人脸侧缓存键（MVP §6.3）。

### 3.6 Mock 测试约定

每层只依赖下一层的 **`api/`**，不碰实现，因此可逐层替换：

| 测什么 | 替换什么 | 效果 |
|--------|----------|------|
| **`pages` 预览 / UI 冒烟** | `features/api/` → Stub | 页面可起、可导航、可看占位/空态，**不加载** features 实现，不连库 |
| **`features` 单测** | `infrastructure/api/` → Mock | 编排与流程可独立验证、断言错误码，**不碰** 真相册 / Vision |
| **`infrastructure` 单测** | （通常针对具体 impl 做集成/单元，不在本约束范围） | — |

**组装点 `bootstrap/`** 在真环境里把 `*Impl` 注入各层；测试时各层直接从 **`api/`** 接 Stub / Mock。

**共享类型**：`domain/model/` 存放跨层 DTO / 枚举，所有层可 import，无 IO、无接口实现。

**§3 评审备忘（有条件通过，2026-05-05；路由映射已对齐 UI v1.2，2026-05-06）**：**四层依赖与 `features/api/`、`infrastructure/api/` 边界** 作为基线冻结。**`pages/` 逻辑路由域与 `features/suggest/`、`ISuggestionService`** 已按 **UI 原型 v1.2 §2.2** 写入 **§3.3.1 / §3.2**；工程落地若需偏差须在实现 PR 说明并同步 **§13**。细粒度文件命名仍以 **§12 O-5** 收口。

---

## 4. 数据模型与持久化

### 4.1 引擎选型

采用 **`relationalStore`（RDB）** 存放结构化业务数据，理由：多表关联、唯一约束、事务与 **单故事 1000 张** 原子校验、后续导出/搜索扩展（V1.1）均依赖关系型能力。

### 4.2 表结构设计（与 MVP §6 对齐）

以下字段名为逻辑名，实现时可按团队规范映射为 snake_case；**须**建立 MVP 要求的唯一索引。

**Person**

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 自增 |
| displayName | TEXT NOT NULL | PE-02 |
| personType | INTEGER | 枚举：宝宝/成人/长辈/其他，默认其他 |
| birthday | INTEGER NULL | 可选，存 Unix 天或 ISO 字符串由实现统一 |
| gender | INTEGER | 男/女/未填 |
| note | TEXT NULL | 备注 |
| avatarLocalPath | TEXT NULL | **头像**：**本地单独存储**，**不**走 `PhotoRef`、**不**与 **`PhotoOwnerLink`（人物侧挂载）** 共用引用链。用户在 **PhotoPicker** 选定后，将**裁切/缩放后的图像**写入 **应用沙箱**（如 `filesDir` 下独占文件），本字段仅存 **沙箱内相对路径或应用内可解析的私有 URI**（实现锁定一种）；未设头像则为 NULL。与 MVP「不批量复制相册原图」一致：仅**单张、小体积、用户明确作为头像**的落盘。 |
| createdAt / updatedAt | INTEGER NOT NULL | **列表排序**：人物列表按 `updatedAt` 降序（MVP §7） |

**Story**

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | |
| title | TEXT NOT NULL | |
| description | TEXT NULL | |
| startDate / endDate | INTEGER 或 TEXT | 与产品日历组件一致即可；单日则相等 |
| coverPhotoRefId | INTEGER NULL FK | 手选封面；**未设时** UI 取「故事内展示顺序第一张」（MVP §6.1，顺序规则见下） |
| locationText | TEXT NULL | 手填地点 |
| tagsJson | TEXT NULL | 自定义标签序列化格式在实现中锁定并记入本文 **修订记录** |
| createdAt / updatedAt | INTEGER NOT NULL | 故事列表 `updatedAt` 降序 |

**PhotoRef**（系统媒体 **去重** 一行）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | |
| uri | TEXT NOT NULL UNIQUE | 系统返回 URI，**唯一约束** 保证「同一系统资源一条」 |
| takenAtCache | INTEGER NULL | 拍摄时间缓存，来自 EXIF/媒体库；无则 NULL |
| addedAt | INTEGER NOT NULL | 首次插入本表时间，用于 §6.2 次级排序 |
| width | INTEGER NULL | 图像/视频帧 **宽**（像素）；**元数据扫描**完成后写入；未知则 NULL |
| height | INTEGER NULL | **高**（像素）；同上 |
| geoLatitude | REAL NULL | **纬度**（WGS84）；仅在有 **`ohos.permission.MEDIA_LOCATION`** 且系统/EXIF 提供可读地理信息时写入，否则 NULL（与 MVP **IM-05** 地点缺失语义、调研表 **EXIF 去隐私** 一致） |
| geoLongitude | REAL NULL | **经度**；同上 |
| geoCountry | TEXT NULL | **逆地理**：国家/地区名（或 ISO 代码，实现锁定一种）；**无坐标 / 无网络 / 逆地理失败** 时为 NULL |
| geoProvince | TEXT NULL | **逆地理**：省 / 州级行政区；同上 |
| geoCity | TEXT NULL | **逆地理**：地级市 / 市级；**文字类筛选** 的主粒度之一（如 **§8.4** 形态一/二「按城市」） |
| geoDistrict | TEXT NULL | **逆地理**：区 / 县级；可选筛选粒度 |
| geoReverseAt | INTEGER NULL | **可选**：逆地理结果写入时间戳，便于重算与对账 |
| refStatus | INTEGER NOT NULL | **生命周期状态**（枚举值实现锁定，建议：`PENDING_SCAN` / `READY` / `SOFT_DELETED`）。含义见下。 |
| deletedAt | INTEGER NULL | 可选；进入 **SOFT_DELETED** 的时间戳，供 GC 排序与排查 |
| scanSummaryJson | TEXT NULL | **扫描管线摘要**（JSON，**落盘**）：**人脸索引**、解码规格、任务 id、失败重试等与 **§8.4 / IX** 强相关的结构化信息；**schema 由实现首版锁定**并记入 **§13 修订记录**或 **§12 O-6**。**不**承担标签、通用业务检索字段；**地理筛选** 以 **列式坐标 + 逆地理列** 为准。 |
| isReferenced | INTEGER NOT NULL | **是否被引用**：`0` / `1`；与 **`referenceCount`** **同事务**维护，恒满足 **`isReferenced = 1` 当且仅当 `referenceCount > 0`**。 |
| referenceCount | INTEGER NOT NULL | **引用总数（落盘）**：本 `PhotoRef` 在应用内的引用个数，等于 **`PhotoOwnerLink` 中 `photoRefId = 本行` 的行数**（含 **`ownerKind`=故事** 与 **人物** 两侧）+ **`Story.coverPhotoRefId = 本行.id` 的故事条数**（每个故事封面最多计 **1**）。用于 GC、列表过滤与调试；**须与 `PhotoOwnerLink` / 封面外键强一致**，禁止仅靠异步估算。 |

**`refStatus` 枚举（与 MVP §6.3 孤儿 + 闲时 GC 对齐）**

| 值（示例） | 含义 |
|------------|------|
| **PENDING_SCAN** | **入库待扫描**：`uri` 已写入且满足 UNIQUE，**元数据补全、人脸索引等**异步任务尚未完成；列表可占位展示，**§8.4 形态一/二的人脸筛选**等依赖索引的能力须待状态变为 **READY** 或按产品约定降级。 |
| **READY** | **已扫描完成**：可正常参与列表、详情、**§8.4** 筛选及失效态判断。 |
| **SOFT_DELETED** | **软删除**：业务上不再展示该行；**无** **`PhotoOwnerLink`** 且 **无** `Story.cover` 指向本行后，由 **闲时 GC** **物理删除**本行（及人脸侧缓存键等，若有）。 |

**与 `uri` 去重**：同一 `uri` **仅一行**。若存在 **`SOFT_DELETED`** 旧行且用户再次选入同资源，**复用该行**：将 `refStatus` 重置为 **PENDING_SCAN**（并重新跑扫描）或经产品裁定直接 **READY**，**禁止** 因 UNIQUE 失败而静默失败无提示。

**图片/媒体「摘要信息」落盘分工（PhotoRef，MVP 收束）**

| 类别 | 载体 | 用途 |
|------|------|------|
| **时间** | `takenAtCache` | 排序、**§8.4** 时间条件 |
| **尺寸** | `width` / `height` | 列表占位、解码策略（**非**「业务标签类筛选」） |
| **坐标** | `geoLatitude` / `geoLongitude` | **§8.4** 形态一/二地点条件与 **IM-05**：范围、有无地理数据；无权限或无数据为 **NULL** |
| **逆地理（可筛）** | `geoCountry`～`geoDistrict` | **文字 / 层级类筛选**（如按省、市）；由 **坐标** 在 **有网络且服务可用** 时异步写入，**失败全 NULL**；**MVP 不引入** 标签、通用业务 JSON 索引 |
| **人脸与任务管线** | `scanSummaryJson` | 与 **§6** 扫描流水线对齐；**不**承载地理筛选主数据 |

**写入时机**：`width`/`height`/`geoLatitude`/`geoLongitude` 在 **元数据扫描** 阶段写入；**逆地理列** 在 **坐标已就绪** 后由 **独立逆地理任务** 写入（可重试、可整列 NULL）；**失败** 不阻塞 **`READY`**（与 **IM-05** 地点缺失降级一致）。**`scanSummaryJson`** 由人脸/管线任务写入。

**位置与逆地理筛选（索引建议）**

- **MVP**：至少 **`refStatus`**、**`PhotoOwnerLink`（`ownerKind`,`ownerId`,`sortKey`）`**；对 **`geoCity`**（或实际筛选主列）可按埋点增加 **INDEX**；**坐标范围** 查询若频繁再评估 **复合索引**（与 **§9.2** 一致）。  
- **不做**：标签、通用 **`extraFilterJson` / 业务检索宽表`** 等 **MVP 范围外** 设计；若后续版本需要，另起需求评审。

**`scanSummaryJson` / `referenceCount` / `isReferenced` 维护要点**

- **引用计数**：在 **插入 / 删除** **`PhotoOwnerLink`**，以及 **更新 / 清空** `Story.coverPhotoRefId` 的**同一事务**内，**递增或递减**对应 `PhotoRef.referenceCount`，并重算 **`isReferenced`**。可选定期 **校验任务**（闲时按 `ownerKind`/`ownerId`/`photoRefId` **COUNT** 对账）防止漂移。  
- **扫描摘要**：元数据任务写入 **`width`/`height`/`geoLatitude`/`geoLongitude`**；逆地理任务写入 **`geoCountry`**～**`geoDistrict`**（可部分 NULL）；人脸与长任务管线写入 / 合并 **`scanSummaryJson`**；进入 **`PENDING_SCAN`** 时可清空或写入「进行中」占位；**`READY`** 时应达到可验收形态（字段集合由实现锁定）。  
- **GC 判定**：**`referenceCount = 0`**（且与边表、封面实际无引用一致）时，方可将 **`refStatus`** 置为 **`SOFT_DELETED`** 并走 §4.3 闲时物理删；**不得以** 仅 `isReferenced` 过期缓存替代事实计数。

### 4.2.1 关系表 — PersonStory（人物—故事）

与 MVP **§6.2** 一致；主键 **自增 `id`**，**业务唯一性** 由 **UNIQUE** 保证。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 自增 |
| personId | INTEGER NOT NULL FK → Person.id | |
| storyId | INTEGER NOT NULL FK → Story.id | |
| role | TEXT NULL | MVP 可选：在该故事中的角色说明 |
| sortOrder | INTEGER NULL | MVP 可选：人物在该故事关联列表中的顺序（若产品不用可恒 NULL） |
| createdAt | INTEGER NOT NULL | 可选：写入关联时间，供审计 |
| **约束** | | **UNIQUE(`personId`, `storyId`)**；建议 **INDEX(`storyId`)**、**INDEX(`personId`)** 便于列表反查 |

### 4.2.2 关系表 — PhotoOwnerLink（故事 / 人物 — 照片，**主路径**）

**已定稿（2026-05-05）**：需求文档中的 **StoryPhoto**、**PersonPhoto** 在本工程 **合并为一张泛化边表** `PhotoOwnerLink`（物理表名实现可改为 `media_owner_link` 等，**全工程统一**）。**验收语义** 仍以 MVP **§6.2 / §6.3** 为准，下表为技术落库形态。

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PK | 自增 |
| ownerKind | INTEGER NOT NULL | **`1` = 故事**（对应 MVP **StoryPhoto**）、**`2` = 人物**（对应 MVP **PersonPhoto**）；枚举常量 **实现锁定** |
| ownerId | INTEGER NOT NULL | `ownerKind=1` 时为 `Story.id`，`=2` 时为 `Person.id` |
| photoRefId | INTEGER NOT NULL FK → PhotoRef.id | **同一** (`ownerKind`,`ownerId`) 下同一 `photoRefId` **仅一行** |
| linkedAt | INTEGER NOT NULL | **本条边写入时间**，用于 MVP §6.2 **无拍摄时间**时的 **次级降序** |
| sortKey | INTEGER NOT NULL | **派生排序键**：由 **`PhotoRef.takenAtCache`**、**`PhotoRef.addedAt`**、**`linkedAt`** 按团队统一公式编码为可 **`ORDER BY` 降序** 的稳定键；**展示语义** 仍为 **拍摄时间降序，缺则添加时间降序**；**MVP 不提供** 用户拖动改序 |
| **约束** | | **UNIQUE(`ownerKind`, `ownerId`, `photoRefId`)**；建议 **INDEX(`ownerKind`, `ownerId`, `sortKey` DESC)** |

**多态外键**：`ownerId` **不能** 同时对 `Story`、`Person` 声明数据库级 FK；**须在 `infrastructure/repository` 写入路径校验** `ownerId` 存在性，并由 **单测** 覆盖非法组合。

**与 `PhotoRef.referenceCount` 的对应**：每插入/删除一行 **`PhotoOwnerLink`**，对对应 `PhotoRef.referenceCount` **±1**；**不包含** `PersonStory`。

### 4.2.3 与 MVP 文档用语对照（避免验收歧义）

| MVP 需求文档用词 | 本方案实现 |
|------------------|------------|
| **StoryPhoto** | **`PhotoOwnerLink`** 且 **`ownerKind` = 故事** |
| **PersonPhoto** | **`PhotoOwnerLink`** 且 **`ownerKind` = 人物** |

### 4.3 业务规则（实现要点）

- **ST-07**：在插入 **`PhotoOwnerLink`（`ownerKind`=故事）** 的同一事务内 **`COUNT(*)` WHERE `ownerKind`=故事 AND `ownerId`=该故事**，若 ≥1000 则 **ROLLBACK** 并返回可本地化错误码。  
- **级联**：严格按 MVP §6.3 实现：删除人物时删除其 **`PhotoOwnerLink`（`ownerKind`=人物）** 与 **`PersonStory`**；删除故事时删除其 **`PhotoOwnerLink`（`ownerKind`=故事）** 与 **`PersonStory`** 中该故事行；**不**误删仍被其他挂载引用的 `PhotoRef` 等（与 MVP 条文一致，仅将「StoryPhoto/PersonPhoto」替换为 **`PhotoOwnerLink` 条件删除**）。  
- **PH-01**：插入边前按 `photoRefId` + 侧唯一约束捕获重复，UI 提示「已存在」。  
- **GC**：当 **`referenceCount = 0`**（与 **`PhotoOwnerLink`** 及 `Story.cover` 实际无引用 **对账一致**）时，将 **`refStatus` 置为 `SOFT_DELETED`**（并写 `deletedAt` 若启用）；在 `EntryAbility.onForeground` 后或 `idle` 对 **`SOFT_DELETED`** 且 **`referenceCount` 仍为 0** 者执行 **物理删行**（及人脸侧缓存键等，若有）。删除前仍须确认无悬垂外键。**人物头像**为沙箱文件，**不参与** `PhotoRef` 判定；**删除 Person** 时须 **同步删除** `avatarLocalPath` 对应文件（若存在）。  
- **列表与计数**：默认查询 **`refStatus = READY`**；**PENDING_SCAN**、**SOFT_DELETED** 是否出现在任何 UI 由产品裁定，须在实现与验收用例中一致。  

**§4 评审备忘（通过，2026-05-05）**：**§4.1～§4.3**（RDB 选型、表结构与约束、**`PhotoOwnerLink`** 主路径、**`PhotoRef`** 生命周期与 **坐标 + 逆地理** 筛选、`Person.avatarLocalPath`、引用计数与 GC）评审 **通过**，作为 MVP 持久化基线冻结。**§12 O-6**（`scanSummaryJson` 具体 JSON schema）在扫描任务首版合入时锁定，**不**回溯改变本章表级与业务规则结论。

---

## 5. 媒体与 PhotoPicker

### 5.1 选图

- 使用 **`PhotoViewPicker`**（调研表 §2.5-A）；**不在 Picker 回调内同步阻塞** 打开 URI，异步排队（官方指南）。  
- 多选上限：以官方 `PhotoSelectOptions` 为准；超大单次选择可在产品层做分批提示。

### 5.2 读图与元数据

- 大图/二进制：`MediaAssetManager`（调研表 §2.5-G）；**取消** 与 **IM-09** 对齐：**`cancelRequest`（12+）** + 应用层协作取消标志（[TODO B2](../TODO-跟踪.md) / 调研表 R-05）。  
- **地点 / 拍摄时间**：在具备 **`ohos.permission.MEDIA_LOCATION`** 时尝试读取地理 EXIF；**无权限或无数据** 时按 MVP **IM-05** 地点语义降级，不得崩溃。  
- **与 §4 落库分工**：本路径读出的 **像素宽高**、**WGS84 坐标**（若有）写入 **`PhotoRef`** 的 **`width`/`height`/`geoLatitude`/`geoLongitude`**，与 **`refStatus`** 元数据扫描阶段一致（见 **§4.2**）。**逆地理列**（`geoCountry`～`geoDistrict`）**不在** Picker/单次读图回调内阻塞等待，由 **§4** 所述 **独立逆地理任务** 异步补全（可全 NULL）。  
- **云相册 URI**：按系统 FAQ 认知设计 **ER-01** 文案（本地删除 vs 云端/网络不可访问）；行为以 **TODO §C3** 真机结论为准。

### 5.3 展示失效态

解码失败、权限回收、云资源不可用时：缩略位展示 **失效态**，提供「从故事/人物移除此引用」入口；**不**因单张失效阻塞整页（MVP §8.6）。

**§5 评审备忘（通过，2026-05-05）**：**§5.1～§5.3**（Picker、**MediaAssetManager** 与 **IM-09（MVP V4.3）/ R-05** 取消路径、元数据与 **§4** 落库衔接、**ER-01** 云资源、失效态）评审 **通过**。真机边界结论仍以 **TODO §C3** 回填为准，**不**阻塞本章基线。

---

## 6. 相册导入与智能关联（MVP §8.4，IM-01～IM-10）

**与 MVP V4.4 对齐**：需求见 [时光故事-MVP需求说明-v4.md](../requirement/时光故事-MVP需求说明-v4.md) **§8.4**（**8.4.0～8.4.4**，含 **选图 → 导入准备 → 条件页 → 扫描 → 候选确认**）、**§8.5**（IX-01/IX-02）、**§9.2**、**§9.4**。**`StoryPhoto`/`PersonPhoto`** 分别对应 **`PhotoOwnerLink`** 的 **`ownerKind`=故事 / 人物**（**§4.2.3**）。

| MVP ID | 技术落点 |
|--------|----------|
| IM-01 | **形态一**：导入页绑定 **`storyId`**；确认写入 **`PhotoOwnerLink`（故事）**；**ST-07** |
| IM-02 | **形态二**：导入页绑定 **`personId`**；确认写入 **`PhotoOwnerLink`（人物）**；**PH-01** |
| IM-03 | **形态三**：后台建议 → 审阅 UI → **仅确认** 写 **`PhotoOwnerLink`（人物）**；**禁止**自动写边 |
| IM-04 | **时间**条件（形态一、二） |
| IM-05 | **地点**条件；**§3.5**；未知 bucket / 降级 |
| IM-06 | **人脸**（端侧、双模式、首次开关）；形态一、二、三凡触发人脸处 |
| IM-07 | **AND**、无 **OR**（形态一、二多条件） |
| IM-08 | **候选 / 建议** UI 与确认批量写 **`PhotoRef` + `PhotoOwnerLink`**；**§4.2.2** + **MVP 数据模型 §6.2** 顺序 |
| IM-09 | **长任务**：进度、取消、重试；**§6.3** |
| IM-10 | **关人脸**：停新索引 / 聚类 / **形态三新建议**（边界实现锁定）；已写入边保留 |

**形态一 / 形态二（定向批量）** 由同一套 **`IImportService`（名称可迭代）** 编排，以 **`targetOwnerKind` + `targetId`** 区分落 **`PhotoOwnerLink`** 的侧别；**形态三** 为 **独立后台编排 + 建议存储 + 审阅页**（不得把未确认建议等同于 **`PersonPhoto`**）。

### 6.1 定向批量流水线（形态一 / 形态二）

1. **输入**：**`targetOwnerKind`**（故事 / 人物）+ **`storyId` 或 `personId`**（**IM-01 / IM-02**）；**IM-04** 时间；地点与人脸条件（**IM-05、IM-06**）。  
2. **导入准备**：PhotoPicker 返回后先执行元数据导入（URI 去重、`PhotoRef` upsert、拍摄时间/坐标写入），以便条件页具备确定性的筛选输入；该阶段不写业务边。  
3. **扫描**：TaskPool 分页遍历相册或预剪枝子集（**O-2** 锁定 **Media Library** 查询与剪枝）；**IX-01** 不长期阻塞 UI。**评审裁定**：首轮实现 **优先按导入条件做时间窗 / 预剪枝** 缩小候选集（见 [交互决策附录](../meeting/2026-05-06-技术方案评审-交互决策附录.md) **D-M5-2**）；全库遍历或兜底策略待性能结论回填 **§6** 并关闭 **O-2**。  
4. **过滤（IM-05、IM-07）**：已启用子条件 **AND**；**不提供 OR**。**地点** 同 **§3.5**；缺失规则与 **IM-05**、UI 说明一致。  
5. **人脸（IM-06、O-1）**  
   - **参考图**（含形态二「与人物头像比对」等产品语义）：`faceComparator.compareFaces` **1v1**；分辨率上限；**串行** Vision（调研表 **§2.5-C、E**）。  
   - **人脸簇（默认）**：`faceDetector.detect` → 聚类（**O-1**）；**串行** Vision。  
   - **`refStatus`**：若人脸依赖 **`READY`/`scanSummaryJson`**，**PENDING_SCAN** 处置须在验收用例中显式锁定，**禁止**静默丢候选。  
6. **输出（IM-08）**：候选 → 全选/反选/剔除 → **仅确认项** upsert **`PhotoRef`** + **`PhotoOwnerLink`（与 `targetOwnerKind` 一致）`**（**`sortKey`/`linkedAt`** 符合 **MVP 数据模型 §6.2** 与 **§4.2.2**）。**故事侧** 同一事务 **ST-07**（**§4.3**）；**人物侧** **PH-01** 去重。

### 6.2 后台人脸建议（形态三）

1. **范围**：对 **已存在** 的 **`PhotoRef` 集合** 扫描（「已入库」边界：已挂载至应用 / 或含孤儿可扫等，**首版实现锁定** 并记入 **§13**）。**不**经过 **PhotoPicker** 本路径。  
2. **产出**：端侧生成 **`{ photoRefId, suggestedPersonId, … }`** 建议列表；建议可落 **独立表或队列**（**不得**在未确认前写入 **`PhotoOwnerLink`（人物）**）。  
3. **确认**：独立 **`pages/suggest/`** 审阅 UI（与 **UI 原型 v1.2 §4.0 图 5** 一致：说明条、单条接受/忽略、批量操作）。**入口（已定稿）**：**人物 Tab 顶栏徽章**，展示 **未读建议条数**，点击进入审阅页。用户接受 → 批量写 **`PhotoOwnerLink`（人物）`**（**PH-01**）；拒绝 → 丢弃建议。  
4. **IM-10**：关人脸后 **停止生成新建议**；交互上提供双选项（仅关闭后续分析 / 关闭并清空现有建议，默认推荐清空），实现按用户选择处理建议队列。

### 6.3 取消、重试与降级（IM-09、IM-10、IX-01/02）

- **进度（IM-09）**：扫描 / 人脸 / 批量写库各阶段可观测进度。  
- **呈现形态（与 UI 原型 §1「可恢复任务」一致）**：长任务须在应用内 **选定一种** 呈现策略并在全工程保持一致：**全屏进度页**（如 **UI 原型 §4.0** 扫描线框）**或** **后台运行 + BottomSheet（或等价）持续提示**。**评审裁定（2026-05-06）**：MVP 首轮默认 **全屏进度页**（[交互决策附录](../meeting/2026-05-06-技术方案评审-交互决策附录.md) **D-M5-1**）；返回键 / 取消是否等价须在实现说明或 **§13** 单点约定；若改用 BottomSheet 路径须在 **§13** 与 PR 说明。**可恢复任务**：返回主导航后任务不静默丢失，取消 / 重试入口可达。  
- **取消（IM-09、IX-01）**：`AbortSignal` 等价物 + TaskPool + **`MediaAssetManager.cancelRequest`**（**§5.2**、TODO **B2** / **R-05**）。  
- **重试（IM-09）**：与 **§5.3**、**ER-01** 区分。  
- **IM-10**：见 **§6.2** 第 4 点及 **IM-06** 全局人脸开关说明（与 **§7** 一致）。  
- **IX-02**：降级矩阵与配置项（最大扫描张数、禁用簇等）；导入上限采用机型分档默认值：`low=100`、`mid=200`、`high=500`，并预留远程配置调优。  
- **性能（MVP §9.2）**：形态一 / 二在 **仅时间 + 单日** 下候选生成 **< 3s**（中端基线；分档见调研表）。

**§6 评审备忘（对齐 MVP V4.4 + UI v1.2，2026-05-06）**：需求 **§8.4** 三形态与 **IM-01～IM-10**；技术方案 **§6.1～§6.3**。**形态三入口** 已与 **UI 原型 §2.2** 对齐（顶栏徽章 → **`suggest`**）。**O-1、O-2、O-6** 与 **IX-02** 仍待回填；**形态三** 扫描全集与建议存储 schema 由实现首版锁定并记入 **§13**。

---

## 7. 人脸特征与隐私（PR-02）

- 若持久化人脸特征或聚类中间结果：存 **应用沙箱**（如单独表或 KV），**隐私页** 说明范围；提供 **「清除人脸缓存」** 动作（MVP PR-02），与 GC 协同删除。  
- 首次人脸能力：**独立开关 + 说明**（MVP **IM-06**）。

**§7 评审备忘（通过，2026-05-05）**：沙箱存储、**PR-02** 清除动作与 **IM-06** 开关说明评审 **通过**；持久化形态细节随 **§12 O-1** POC 收敛。

---

## 8. 主题（MVP §9.1）

- **基线**：`Environment` / 资源色值 **跟随系统** 深浅色。  
- **增强（API 12）**：可按需引入 **`WithTheme`** 统一 token（调研表 §2.5-F）。  
- 验收：系统切换后主要列表/详情/导入页 **可读、对比度可接受**。

**§8 评审备忘（通过，2026-05-05）**：系统深浅色基线及 **WithTheme** 可选增强评审 **通过**。

---

## 9. 崩溃与错误栈（MVP §5.1 / §14）

- **范围**：崩溃栈或厂商等价通道；**不含原图**、用户标识 **默认匿名或可关闭**（与隐私页一致）。  
- **实现选型**：在工程集成阶段在 **AppGallery Connect 崩溃服务** 或华为推荐 SDK 中二选一，于 **V1.1 技术附录** 填包名与初始化位置；本文仅约束 **数据最小化** 与 **隐私文案一致性**。  
- **集成时机（评审裁定）**：允许 **内测 / 联调** 阶段 **未接入** 正式崩溃通道（占位或关闭）；**商店或正式发布前** 必须关闭 **§12 O-3** 并完成本节边界验收（[交互决策附录](../meeting/2026-05-06-技术方案评审-交互决策附录.md) **D-M6-1**）。

**§9 评审备忘（通过，2026-05-05）**：崩溃上报 **数据边界** 与隐私一致性评审 **通过**；具体 SDK 与初始化位置由 **§12 O-3** 关闭（时机见上文 **D-M6-1**）。

---

## 10. 权限声明（草案）

在 `module.json5` 中按需声明（以最终实现与审核为准）：

- 相册读取：**按官方指南** 区分「仅 Picker 返回 URI」与「**§8.4** 形态一/二批量扫描相册」路径；后者通常需要 **`ohos.permission.READ_IMAGEVIDEO`**（名称以当前 SDK 为准）。  
- **地理元数据**：`ohos.permission.MEDIA_LOCATION`（调研表 §2.5-A）。  
- 禁止声明与「上传原图至自有服务器」相关的多余权限。

**§10 评审备忘（通过，2026-05-05）**：相册 / 地理元数据声明路径与 **§5**、**§6**（含 **§8.4** 三形态）能力划分评审 **通过**；最终以 **`module.json5`** 过审版本为准。

---

## 11. 需求追溯矩阵（节选）

| MVP 条目 | 技术落点 |
|----------|----------|
| §6 数据模型 | §4 表结构（含 **`PhotoOwnerLink`** 与 MVP **StoryPhoto/PersonPhoto** 对照 §4.2.3）、约束、事务 |
| §6.2 排序 | `takenAtCache` + `addedAt` 查询 `ORDER BY`；不写用户拖动 |
| §6.3 删除 / GC | 仓库级联 + 后台 GC 任务 |
| PE / ST / PH | `pages/person`、`pages/story` + **`features/api/`**（`IPersonService`、`IStoryService`）；实现见 **`features/person/`、`features/story/`** |
| MVP §8.4 / IM-01～IM-10 | **§6**（**§6.1** 形态一/二；**§6.2** 形态三；**§6.3** 长任务与 **IM-10**）；`pages/import` + `features/import/` + **`IImportService`**；形态三 **`pages/suggest` + `features/suggest/` + `ISuggestionService`**（**§3.2、§3.3.1**） |
| UI `shell` / 主导航 | **§3.3.1** `pages/shell/` + Tab 壳（人物 / 故事） |
| UI `privacy` | **§3.3.1** `pages/privacy/`；静态说明与 PR-01 |
| UI `settings` | **§3.3.1** `pages/settings/`；**§7** IM-10 / PR-02 |
| UI `suggest` / IM-03 | **§6.2**；顶栏徽章入口（**§3.3.1 `person`**） |
| IM-05 地理缺失 / 权限 | **§5.2**；**§4** `geo*` / 逆地理 **NULL**；**§3.5** / **§6.1** 与 **未知/bucket** UI |
| IM-06 / IM-10 | **§6.1** 人脸双模式；**§6.3** 关人脸停新索引与形态三新建议 |
| IM-03 形态三 | **§6.2** 建议存储 + 确认写 **`PhotoOwnerLink`（人物）** |
| ST-07 / PH-01 | **§6.1** 输出步：**故事** **ST-07**；**人物** **PH-01** + **§4.3** |
| ER-01 / ER-02 | §5.3 + 权限引导；**§6.3** 重试与失效态区分 |
| IX-01 / IX-02 | **§6.3** + TaskPool + 串行 Vision + 可配置降级 |
| §9.2 性能 | **§6.3** 形态一/二「仅时间 + 单日」**< 3s**；列表分页、网格虚拟化、索引；大库见 TODO **C8** |

---

## 12. 开放项与下一版修订

| ID | 内容 | 关闭条件 |
|----|------|----------|
| O-1 | 人脸簇具体算法与 embedding 是否落库 | POC + R-02 基线（TODO C8） |
| O-2 | 相册扫描数据源（全库 vs 时间窗预剪枝） | 性能测试后写入 §6 |
| O-3 | 崩溃 SDK 选型与初始化位置 | **发版 / 商店发布前** 工程集成 PR 关闭（内测可占位，见 **§9**、[交互决策附录](../meeting/2026-05-06-技术方案评审-交互决策附录.md) **D-M6-1**） |
| O-4 | `tagsJson` 格式锁定 | 首次故事保存接口合入 |
| O-5 | **各层内模块与文件粒度细化**（不改变 §3 四层与 `api/` 依赖方向） | **UI 原型已 v1.2 定稿**：以本文 **§3.2 / §3.3 / §3.3.1** 为基线，在 **首个贯通 MVP 主路径的实现 PR** 中落地目录与接口命名；若与本文不一致须在 PR 说明并同步 **§13**。收口责任人：研发 + 架构评审。 |
| O-6 | **`PhotoRef.scanSummaryJson` 的 JSON schema**（字段名、版本号、与任务 id 的对应） | 扫描任务首版合入 + 本条写入 §13 |
| O-7 | ~~照片边表选型~~ **已定**：采用 **`PhotoOwnerLink`** 泛化表（**2026-05-05**）；双表方案废弃 | **已完成** |

---

## 13. 修订记录

| 版本 | 日期 | 说明 |
|------|------|------|
| V1.4.1 | 2026-05-06 | **交互式技术方案评审裁定归档**：关联 [交互决策附录](../meeting/2026-05-06-技术方案评审-交互决策附录.md)；正文修订 **§6.1 步骤 3**（**D-M5-2** 优先剪枝 / **O-2**）、**§6.3**（**D-M5-1** 默认全屏进度页）、**§9** 与 **§12 O-3**（**D-M6-1** 发版前接入）；其余 **D-M1-1、D-M2-1、D-M3-1、D-M4-1、D-M7-1** 见附录一览 |
| V1.4.0 | 2026-05-06 | **对齐 MVP V4.4 + UI 原型 v1.2**：关联文档增 UI 原型；**§3.2** 引入 **`ISuggestionService`** 与 **`features/suggest/`**；**§3.3 / §3.3.1** 增补 **`pages/suggest|privacy|settings`** 及路由域映射；**§6.2** 形态三入口改为顶栏徽章→**`suggest`**；**§6.3** 长任务 UI 形态与原型一致；**§11、§12 O-5** 同步 |
| V1.0 | 2026-05-05 | 首版：架构、RDB 表结构、媒体与智能导入要点、权限与追溯矩阵 |
| V1.0.1 | 2026-05-05 | 增补 **§3.3**：页面与流程解耦、依赖接口与 mock 测试约定（评审结论） |
| V1.0.2 | 2026-05-05 | **§3.1** 按 §3.3 重组：组装根、`features/*/usecase|vm|pages`、`domain/contracts`、依赖规范与目录树 |
| V1.0.3 | 2026-05-05 | **§3.1 / §3.3 / §11**：页面 **全部** `pages/*`；`features` **仅** usecase；**`domain/contracts/app`** 与内部分层契约；mock features 后 pages 可独立运行 |
| V1.0.4 | 2026-05-05 | 契约迁至 **`features/contracts/`**（`app/`、`persistence/`、`sys/`）；**`pages` 仅 import `app/`**；**`repository`/`platform` 实现内部契约**；同步 §3.1、§3.3、§11 |
| V1.0.5 | 2026-05-05 | **§3.1 重写**：三条硬规则 + 单一依赖图 + 一张目录表；**§3.3 缩为测试约定**，去掉与 §3.1 重复的大段 |
| V1.1.0 | 2026-05-05 | **§3 整章重构**：四层（pages → features → infrastructure → domain）；对外接口目录与 impl 分离；逐层可 mock（评审定稿） |
| V1.1.1 | 2026-05-05 | 目录 **`contracts/`** 统一更名为 **`api/`**（`features/api/`、`infrastructure/api/`）；§3、§11 同步 |
| V1.1.2 | 2026-05-05 | **§3 有条件通过** 备忘 + **§12 O-5**：待 UI 设计后重议各层内模块划分 |
| V1.1.3 | 2026-05-05 | **§4 Person**：头像改为 **沙箱本地存储**（`avatarLocalPath`），**不再**使用 `PhotoRef` 外键；§4.3 GC 与删人物同步删头像文件 |
| V1.1.4 | 2026-05-05 | **§4 PhotoRef**：新增 **`refStatus`**（`PENDING_SCAN` / `READY` / `SOFT_DELETED`）、可选 **`deletedAt`**；GC 与孤儿语义改为经 **SOFT_DELETED** 再物理删；同 URI 复用规则 |
| V1.1.5 | 2026-05-05 | **§4 PhotoRef**：**`scanSummaryJson`**、**`isReferenced`**、**`referenceCount`**（落盘）；维护要点与 GC 与 **`referenceCount`** 对齐；**§12 O-6** |
| V1.1.6 | 2026-05-05 | **§4.2.1**：**PersonStory** / **StoryPhoto** / **PersonPhoto** 字段级设计与索引建议；**`referenceCount`** 不含 `PersonStory` |
| V1.1.7 | 2026-05-05 | **§4.2.2** 可选泛化边表 **`PhotoOwnerLink`**；双表 vs 泛化取舍与 **§4.3** 措辞；**§12 O-7** |
| V1.2.0 | 2026-05-05 | **已定稿**：照片边 **统一 `PhotoOwnerLink`**；§4.2 重组为 **4.2.1 PersonStory / 4.2.2 PhotoOwnerLink / 4.2.3 用语对照**；§3.5、§4.3、§6、§12 O-7、全文替换双表主路径 |
| V1.2.1 | 2026-05-05 | **§4 PhotoRef**：列式摘要 **`width`/`height`/`geoLatitude`/`geoLongitude`**；可选 **`metaSummaryJson`**；与 **`scanSummaryJson`** 分工及写入时机 |
| V1.2.2 | 2026-05-05 | **§4 PhotoRef**：**`mimeType`/`mediaKind`/`durationMs`/`sizeBytes`**、预留 **`extraFilterJson`（schemaVersion）**；摘要分工表 + **未来筛选与索引** 建议 |
| V1.2.3 | 2026-05-05 | **收束**：去掉 MIME/类型/体积、`metaSummaryJson`、`extraFilterJson` 与泛化「未来筛选」；**仅** 列式 **坐标 + 逆地理**（`geoCountry`～`geoDistrict`）支撑 **地理类筛选**；`scanSummaryJson` 说明同步 |
| V1.2.4 | 2026-05-05 | **§3.5**：智能导入 **「地点」** 与需求用语对齐——实现侧为 **坐标条件 ∩ 逆地理列匹配**，并交叉 **§4.2**（彼时需求条号 **IM-03** 指地点；**MVP V4.3** 起地点为 **IM-05**） |
| V1.2.5 | 2026-05-05 | **§4 评审通过**（2026-05-05）：§4.1～§4.3 基线冻结备忘；**O-6** 仍待实现合入时锁定 schema |
| V1.2.6 | 2026-05-05 | **§5.2 / §6.1 / §11**：与已冻结 **§4** 衔接——读图路径写 **`PhotoRef` 列式元数据**、逆地理异步；导入过滤与 **§3.5** 地点语义对齐；追溯矩阵补地点条（彼时 **IM-03**，**V4.3** 为 **IM-05**） |
| V1.2.7 | 2026-05-05 | **§5～§10 评审通过**（逐章备忘，2026-05-05）；**§6.1** 输出步修正为 **MVP §6.2** + **§4.2.2**（原误指技术方案 §6.2） |
| V1.2.8 | 2026-05-05 | **§6 重新评审**：对照当时 **V4.2** 系 **§8.4** 扩写 **IM 追溯表**（条号 **IM-03/04/09** 等，**V4.3** 已重排为 **IM-01～IM-10**）、**ST-07**、**`refStatus`**、**§9.2**；**§11** 同步 |
| V1.2.9 | 2026-05-05 | 对齐需求 **MVP V4.3**：**§8.4** 三形态 + **IM-01～IM-10**；本章改为 **§6.1～§6.3**；§3.5、§4、§5、§7、§10、§11 条号与措辞同步 |
| V1.3.0 | 2026-05-06 | 对齐交互评审纪要：导入流程新增「导入准备」阶段；IM-10 关闭人脸双选项策略落地；IX-02 补充分档扫描上限默认值（100/200/500） |

---

**文档结束**
