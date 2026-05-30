# 项目测试能力升级方案：分层 TDD 架构

> **场景**：项目级测试能力升级——从当前局部测试覆盖的现状，建立完整的 **分层 TDD** 测试基础设施，确保未来所有 Feature 改动都以测试驱动方式迭代。
> **角色**：qa（测试工程师）
> **日期**：2026-05-30

---

## 一、现状评估

### 1.1 已有测试资产

| 层级 | 文件 | 覆盖范围 | 框架 | 状态 |
|------|------|----------|------|------|
| **LocalUnit** (`src/test/`) | `LocalUnit.test.ets`, `List.test.ets` | Schema 版本契约、单例模式、文本规范化 | Hypium | ✅ 可用 |
| **Tier1 集成** (`ohosTest/`) | `Tier1RdbIntegration.test.ets` | RepositoryImpl 全量 CRUD、关联、照片操作、级联删除、GC | Hypium + RDB | ✅ 可用（~40 条用例） |
| **Tier2 E2E** (`ohosTest/`) | `V2Regression*.test.ets` | 人物/故事 CRUD 端到端、导入向导全流程、B2/cancelRequest 域 | Hypium + UI Driver | ✅ 可用（~20+ 条用例） |
| **Test Kit** | `V2RegressionTestKit.ets` | 导航、滚动、点击、断言、冷启动等可复用 helper | — | ✅ 可用 |
| **RDB Context** | `OhosTestRdbContext.ets` | 设备侧 RDB Context 获取（兼容性处理） | — | ✅ 可用 |

### 1.2 核心缺口（按严重程度排序）

| 缺口 | 影响 | 严重程度 |
|------|------|----------|
| **Service 层零测试** | PersonService / StoryService / ImportFeature 等核心业务逻辑无覆盖 | 🔴 高 |
| **页面逻辑零单元测试** | PersonDetailPage.buildMonthGroups 等关键方法无测试，近期频繁出现分组/排序 bug | 🔴 高 |
| **新增组件零测试** | PhotoSwiper、PhotoGridItem、KeyboardAwareInput 等无覆盖 | 🟡 中 |
| **E2E 覆盖率极低** | 仅覆盖导入向导，人物详情/故事详情/编辑页/照片浏览完全无 E2E | 🟡 中 |
| **无 TDD 工作流** | 无 "先写测试再写代码" 的流程保障，导致回归 bug 频繁 | 🔴 高 |
| **无 CI 自动化** | 测试需手动触发，无人值守验证 | 🟡 中 |
| **无覆盖率报告** | 无法量化覆盖程度 | 🟢 低 |
| **测试数据工厂缺失** | 每个测试用例自行构造数据，大量重复代码 | 🟡 中 |

### 1.3 近期 bug 回顾（测试缺口的直接证据）

| 问题 | 根因 | 可通过哪层测试捕获 |
|------|------|---------------------|
| 人物详情页不显示关联故事照片 | `buildMonthGroups` 中 story.photoCount 字段缺失 | Service / Page 单元测试 |
| 人物编辑页保存报错但数据成功 | `updatePerson` changesCount 判断逻辑错误 | Service 集成测试 |
| 人物保存后列表未刷新 | `PersonPage.onPageShow` 未调用 reload | Page 单元测试 / E2E |
| 故事编辑页封面等字段保存失败 | `updateStoryAll` changesCount 判断逻辑错误 | Service 集成测试 |
| 日历默认空值显示当前日期 | 未做空值 → 默认值映射 | 组件单元测试 |
| 添加照片未解析基本信息 | `pickPhotosFromAlbum` 缺少元数据获取 | Service / E2E |

---

## 二、分层 TDD 架构设计

### 2.1 分层模型（对齐项目架构）

```
┌────────────────────────────────────────────────────┐
│ Layer 4: E2E (ohosTest · UI Driver)                │
│ - 完整用户流程验证                                      │
│ - 冷启动 → 导航 → 操作 → 断言                            │
│ - 框架: Hypium + @kit.TestKit (ON, Driver)              │
├────────────────────────────────────────────────────┤
│ Layer 3: Integration (ohosTest · Service + RDB)        │
│ - Service 层 + 真实 RDB                                  │
│ - Feature 组合验证（如 addPhoto → query → remove）       │
│ - 框架: Hypium + abilityDelegatorRegistry               │
├────────────────────────────────────────────────────┤
│ Layer 2: Component (src/test/ · 组件级)                 │
│ - 页面逻辑单元测试                                        │
│ - 纯函数方法测试（buildMonthGroups, formatDate 等）          │
│ - 框架: Hypium (纯逻辑，不依赖设备 API)                    │
├────────────────────────────────────────────────────┤
│ Layer 1: Unit (src/test/ · 纯函数)                     │
│ - Domain 模型/Rules 测试                                   │
│ - 工具函数测试（normalize, parse 等）                      │
│ - 框架: Hypium                                           │
└────────────────────────────────────────────────────┘
```

### 2.2 各层职责与测试策略

| 层级 | 定位 | 测试对象 | 运行位置 | 框架 | 速度 | 占比目标 |
|------|------|----------|----------|------|------|----------|
| **L1 Unit** | 纯函数/纯数据 | Models, Rules, Utils, Schema | `src/test/` (本地) | Hypium | <1s | 50% |
| **L2 Component** | 页面逻辑 | Page buildXxx 方法, ViewModel, Service 纯逻辑部分 | `src/test/` (本地) | Hypium | <3s | 20% |
| **L3 Integration** | Service+DB | Service 全量方法 + 真实 RDB | `ohosTest/` (设备) | Hypium + RDB | <30s | 20% |
| **L4 E2E** | 端到端流程 | 核心用户旅程（冒烟级别） | `ohosTest/` (设备) | Hypium + UI Driver | <5min | 10% |

### 2.3 测试金字塔与 TDD 循环

```
         ╱╲
        ╱ E2E ╲         ← 少量，验证核心流程
       ╱────────╲
      ╱Integration╲     ← 中量，验证 Service+DB 组合
     ╱──────────────╲
    ╱    Component    ╲  ← 中量，验证页面逻辑
   ╱──────────────────╲
  ╱       Unit          ╲ ← 大量，验证纯函数
 ╱────────────────────────╲
```

**TDD 循环（每个 Feature）：**
1. **Red** — 基于需求/交互稿写失败的测试
2. **Green** — 实现最小代码让测试通过
3. **Refactor** — 重构代码，测试保持绿色
4. **Commit** — 测试+代码一起提交

---

## 三、实施计划（6 个阶段）

### 阶段 1：基础设施完善（预计改动 3-5 个文件）

**目标**：建立测试数据工厂、Mock 工具、测试 runner 脚本

| 任务 | 产出 | 位置 |
|------|------|------|
| 1.1 创建 `TestDataFactory` | 统一造数工具（Person/Story/Photo 工厂方法） | `entry/src/ohosTest/ets/test/TestDataFactory.ets` |
| 1.2 创建 `TestDbHelper` | 测试库快速创建/销毁（封装 ensureSchemaV1 + attachRdb） | `entry/src/ohosTest/ets/test/TestDbHelper.ets` |
| 1.3 创建 `ServiceTestBase` | Service 层集成测试基类（setup/teardown 模式） | `entry/src/ohosTest/ets/test/ServiceTestBase.ets` |
| 1.4 整理 `V2RegressionTestKit` | 补充通用断言、补充注释，提取到 `common/` 路径 | 已有，仅重构路径 |
| 1.5 创建测试运行脚本 | `hdc` 一键运行 ohosTest 的脚本 | `scripts/run_ohos_test.ps1` |

**验证标准**：`TestDataFactory.createPerson()` / `createStory()` 可被测试用例一行调用

---

### 阶段 2：Service 层集成测试补齐（L3）

**目标**：为所有 Service 方法编写真实 RDB 集成测试

| 任务 | 覆盖对象 | 优先级 |
|------|----------|--------|
| 2.1 `PersonServiceTier3.test.ets` | PersonService 全方法：create/list/get/update/delete + photo 操作 | 🔴 高 |
| 2.2 `StoryServiceTier3.test.ets` | StoryService 全方法：create/list/get/update/delete + updateStoryAll + photo 操作 | 🔴 高 |
| 2.3 `LinkServiceTier3.test.ets` | Person-Story 关联：link/unlink/isLinked/listLinked + 边角用例 | 🟡 中 |
| 2.4 `PhotoServiceTier3.test.ets` | 照片共享引用、去重、story cap 上限、GC 孤儿清理 | 🟡 中 |
| 2.5 `ImportServiceTier3.test.ets` | ImportFeature 核心逻辑（不含 UI） | 🟢 低 |

**关键测试点**（从 bug 列表反推）：
- `updatePerson` 空参数调用应返回 true（已修 bug 的回归用例）
- `updateStoryAll` 部分字段更新应全部生效
- `addPhotoForPerson` 带 metadata 应正确存储 `taken_at_cache`

---

### 阶段 3：页面逻辑单元测试补齐（L2）

**目标**：为页面中可剥离的纯逻辑方法编写本地单元测试

| 任务 | 覆盖方法 | 优先级 |
|------|----------|--------|
| 3.1 `PersonDetailLogic.test.ets` | `buildMonthGroups`（分组+排序核心逻辑）、`formatBirthday`、`typeLabel`、`genderLabel` | 🔴 高 |
| 3.2 `StoryDetailLogic.test.ets` | `buildDateRangeText`、`buildMetaInfoText`、`getDisplayTags` | 🟡 中 |
| 3.3 `PhotoSwiperLogic.test.ets` | `formatDate`、健康状态判定逻辑 | 🟡 中 |
| 3.4 `PersonEditLogic.test.ets` | `buildDatePickerDate`、表单校验逻辑 | 🟡 中 |
| 3.5 `StoryEditLogic.test.ets` | `buildPickerDate`、标签解析逻辑 | 🟡 中 |

**实现策略**：将这些纯函数从组件中提取为可单独导出的 standalone functions，在 `src/test/` 中测试。

> **决策 1 确认（2026-05-30）**：采用方案 A —— 提取纯函数再测。不采用方案 B（E2E 间接验证）。理由：L2 测试速度快（本地 <3s）、不依赖真机、边界条件覆盖容易。代码小幅重构（提取 standalone function）反而使组件更清晰。

---

### 阶段 4：核心 UI 组件 E2E 补齐（L4）

**目标**：用 UI Driver 覆盖核心用户旅程

| 任务 | 覆盖旅程 | 优先级 |
|------|----------|--------|
| 4.1 `V2RegressionPersonDetail.test.ets` | 人物详情页：查看信息、时间线分组显示、照片浏览、PhotoSwiper 打开/关闭 | 🔴 高 |
| 4.2 `V2RegressionStoryDetail.test.ets` | 故事详情页：查看信息、照片列表、人物关联显示 | 🟡 中 |
| 4.3 `V2RegressionPersonEdit.test.ets` | 人物编辑：修改字段、保存、返回验证 | 🟡 中 |
| 4.4 `V2RegressionStoryEdit.test.ets` | 故事编辑：修改字段、保存、返回验证 | 🟡 中 |
| 4.5 `V2RegressionPhotoFlow.test.ets` | 照片流程：添加照片 → 元数据验证 → 移除照片 | 🟡 中 |

**注意**：E2E 用例保持精简（冒烟级别），不超过 5-8 条/页面。避免 E2E 爆炸。

---

### 阶段 5：TDD 工作流建立

**目标**：建立可执行的 TDD 流程规范，确保未来所有 Feature 以测试先行

| 任务 | 产出 |
|------|------|
| 5.1 编写 `TDD工作流规范.md` | 定义 Red → Green → Refactor → Commit 流程 + Code Review 检查清单 |
| 5.2 更新 `project_rules.md` | 添加 "Feature 开发必须包含对应层级测试" 规则 |
| 5.3 创建 PR 模板 | `.trae/templates/pr_template.md` 含测试检查清单 |
| 5.4 创建测试用例模板 | `TestTemplate.test.ets` 各层测试骨架文件 |

---

### 阶段 6：CI 自动化与覆盖率

**目标**：建立自动化测试运行机制

| 任务 | 产出 |
|------|------|
| 6.1 配置 `hdc aa test` 运行脚本 | `scripts/run_all_tests.ps1` 一键运行全部测试 |
| 6.2 配置 `check_ets_files` 门禁 | 确保每次构建前静态检查通过 |

---

## 四、TDD 工作流规范（草案）

### 4.1 Feature 开发流程

```
需求/交互稿
    │
    ▼
┌──────────────────────────────────────┐
│ Step 1: 写测试（RED）                    │
│ - L1: 新 Model/Rules → 写 Unit 测试    │
│ - L2: 新页面逻辑 → 写 Component 测试   │
│ - L3: 新 Service 方法 → 写 Integration │
│ - L4: 新用户旅程 → 写 E2E 测试（可选）  │
└──────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────┐
│ Step 2: 跑测试确认失败（RED ✓）        │
└──────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────┐
│ Step 3: 写最小实现（GREEN）            │
└──────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────┐
│ Step 4: 跑测试确认通过（GREEN ✓）      │
└──────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────┐
│ Step 5: 重构（REFACTOR）              │
│ - 保持测试绿色                         │
└──────────────────────────────────────┘
    │
    ▼
┌──────────────────────────────────────┐
│ Step 6: Commit（测试+代码一起提交）     │
│ - commit message 标注 TEST: 前缀      │
└──────────────────────────────────────┘
```

### 4.2 测试先行检查清单（Code Review 用）

- [ ] 新增的 `domain/model/` 类型是否有对应的 L1 单元测试？
- [ ] 新增的 `features/` Service 方法是否有对应的 L3 集成测试？
- [ ] 新增的页面逻辑（buildXxx, formatXxx）是否有对应的 L2 组件测试？
- [ ] 涉及数据变更的操作是否有回归测试覆盖？
- [ ] 测试用例命名是否清晰（描述场景+期望）？

---

## 五、测试用例命名规范

```
{层级前缀}_{领域}_{场景描述}

示例：
- L1_model_photoMetadata_default_values
- L2_personDetail_buildMonthGroups_empty_photos
- L2_personDetail_buildMonthGroups_mixed_photo_and_story
- L3_personService_updatePerson_empty_params_returns_true
- L3_storyService_updateStoryAll_partial_fields_all_saved
- L4_e2e_personDetail_photoSwiper_open_and_close
- L4_e2e_storyDetail_add_photo_verify_metadata
```

---

## 六、测试用例质量标准

### 6.1 测试用例质量标准（必须遵守）

| 维度 | 标准 |
|------|------|
| **独立性** | 每个测试用例应可独立运行，不依赖其他用例的执行顺序 |
| **可重复性** | 相同条件下多次运行应得到相同结果 |
| **清晰度** | 用例命名应能独立说明测试意图，无需看用例体 |
| **断言明确** | 每个测试应有明确的期望结果，且应有 1~3 个关键断言 |
| **边界覆盖** | 覆盖正常、异常、边界三类场景 |
| **速度** | L1/L2 测试应尽量快（<3s），避免过多的准备/清理 |

### 6.2 边界条件覆盖检查表

每个功能点应覆盖：
- ✅ 正常流程
- ✅ 空值（null/undefined/空数组/空字符串）
- ✅ 边界值（最大/最小/刚好触发阈值）
- ✅ 异常数据（格式不符、范围越界）
- ✅ 历史 bug 的回归用例

### 6.3 测试代码质量标准

测试代码也是代码，同样需要质量保障：
- **测试代码同样要 Code Review**：测试代码与实现代码同等重要，合并前同样需要评审
- **测试代码同样要重构**：随着业务逻辑变更，测试代码也应随之演进
- **避免测试间耦合**：每个测试用例应独立准备和清理数据
- **测试代码同样需要注释**：复杂的测试 setup/teardown 或断言需要注释说明意图

---

## 七、质量门禁（Quality Gates）

### 7.1 测试门禁分级

| 门禁等级 | 检查项 | 触发时机 | 放行条件 |
|---------|--------|----------|----------|
| **Tier0** | 静态检查（check_ets_files） + 构建通过 | 每次提交 | ✅ 无警告/错误 |
| **Tier1** | L1（本地）单元测试 + L2 组件测试 | 提测前 | ✅ 通过率 100% |
| **Tier2** | L3（设备）集成测试 | 合并前 | ✅ 通过率 ≥ 95% |
| **Tier3** | L4（设备）E2E 冒烟测试 | 发布前 | ✅ 通过率 100% |

### 7.2 测试数据管理策略

| 层级 | 测试数据策略 |
|------|-------------|
| **L1/L2** | 使用固定测试数据，可预测，便于断言 |
| **L3** | 使用独立测试数据库，不与开发数据库混用，测试后清理 |
| **L4** | 冒烟测试使用最小数据集，数据量要小，运行要快 |

**TestDbHelper 设计要求**：
- 每次测试运行创建新的、独立的数据库文件（可使用临时目录或带时间戳的文件名）
- 测试运行后自动清理测试数据库文件
- 优先考虑内存数据库（如支持）来加速 L3 测试

---

## 八、测试资产治理

### 8.1 测试用例分级管理

根据优先级和重要性，将用例分为：
- **P0**：核心业务逻辑，必须全过，任何失败阻塞发布
- **P1**：重要功能，尽量全过，单个失败可评估风险后有条件通过
- **P2**：次要功能，有问题可容忍，后续修复

### 8.2 不稳定测试（Flaky Test）处理

**判定标准**：
- 连续失败 3 次或同一用例在相同条件下失败率 > 20%

**处理流程**：
1. 标记为「Flaky」并记录问题
2. 单独修复或临时禁用（禁用需注明原因和修复计划）
3. 修复后重新启用并验证稳定性

### 8.3 测试债务管理

如果暂时跳过了某些测试，应记录为「测试债务」并后续补全：
- 在代码注释中标记 `// TODO: TEST_DEBT - 原因与补全计划`
- 在任务列表中登记并在合理时间内补全

---

## 九、分层测试的责任边界与 TDD 节奏

### 9.1 分层测试的责任边界（明确）

| 层级 | 测试责任 | 对应代码 |
|------|---------|---------|
| **L1 Unit** | 纯函数、无副作用 | `domain/model/` |
| **L2 Component** | 页面纯逻辑方法 | `pages/`（提取为独立函数后） |
| **L3 Integration** | Service 层 + 真实 RDB | `features/`、`infrastructure/repository/` |
| **L4 E2E** | 真实用户流程（冒烟） | `pages/` + UI Driver |

### 9.2 TDD 节奏与日常开发的平衡

并非所有功能都必须从 L1 写到 L4，可根据风险等级灵活调整：
- **高风险功能必须 TDD**：涉及数据变更、核心业务逻辑的功能必须走完整 TDD
- **低风险功能可简化**：纯 UI 展示、不涉及业务逻辑的功能可适当简化测试
- **渐进式落地**：不用一次性把所有页面逻辑都提取，可从 bug 高频的模块开始

**提取纯函数再测试的安全网**：
1. 先加 E2E/L3 测试作为安全网
2. 小步提取，每次只提取小函数
3. 每次提取后运行测试验证无回归
4. 确保提取重构不改变行为

---

## 十、关键设计决策确认

| 决策 | 选项 | 确认结论 |
|------|------|----------|
| L2 页面逻辑测试策略 | 方案A：提取函数再测 / 方案B：E2E间接验证 | ✅ **方案A** — 提取纯函数，在 src/test/ 本地测试 |
| L3 Mock vs 真实 RDB | Mock / 真实RDB | ✅ **真实RDB** — 项目已有 Tier1 真实RDB集成测试验证可行，不引入Mock偏差 |

> **决策 1 确认（2026-05-30）**：采用方案 A —— 提取纯函数再测。不采用方案 B（E2E 间接验证）。理由：L2 测试速度快（本地 <3s）、不依赖真机、边界条件覆盖容易。代码小幅重构（提取 standalone function）反而使组件更清晰。
>
> **决策 2 确认（2026-05-30）**：L3 继续使用真实 RDB 而非 Mock。理由：现有 `Tier1RdbIntegration.test.ets` 已证明真实 RDB 集成测试可行（每个 suite 创建独立 `TimestoreTier3_{timestamp}.db`，测试后销毁）。不引入 Mock 层，避免 Mock 与真实行为的偏差，保持测试置信度。
>
> **决策 3 确认（2026-05-30，评审会）**：补充「测试用例质量标准」、「质量门禁」、「测试资产治理」、「分层测试责任边界与 TDD 节奏」章节到方案文档。
>
> **决策 4 确认（2026-05-30，评审会）**：TestDbHelper 优先考虑内存数据库（如支持）来加速 L3 测试。

---

## 十一、风险与缓解

| 风险 | 缓解措施 |
|------|----------|
| ohosTest 在 CI 环境无真机 | L1/L2 本地测试覆盖核心逻辑；L3/L4 依赖手动触发 `hdc aa test` |
| Service 层依赖真实 RDB 导致测试慢 | 每个 Suite 使用独立 `TimestoreTier3_{timestamp}.db`，测试后销毁 |
| E2E 测试不稳定（flaky） | 用例限制在冒烟级别；使用 V2_TIMEOUT 快速失败策略 |
| 团队 TDD 习惯未建立 | 通过 PR 模板 + Code Review 检查清单强制执行 |

---

## 十二、验收标准

1. **基础设施完整**：TestDataFactory、TestDbHelper（含内存数据库支持）、ServiceTestBase 可被直接使用
2. **Service 层 100% 覆盖**：所有 PersonService / StoryService 公开方法有 L3 测试
3. **关键页面逻辑有测**：PersonDetailPage.buildMonthGroups 等 bug 高频方法有 L2 测试
4. **核心旅程有 E2E**：人物详情、故事详情的冒烟 E2E 可运行
5. **规范文档落地**：TDD 工作流规范 + PR 模板 + 测试命名规范 + 测试用例质量标准已写入项目规则
6. **回归保护生效**：近期 6 个 bug 的反向用例已纳入测试套件
7. **质量门禁落地**：Tier0-Tier3 测试门禁已在项目规则中明确