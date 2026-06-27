# V3 C3 测试用例设计

> **来源**：T-41 · TR-20260520-04#C-1
> **权威锚点**：主计划 §4 · V3-T2 C3
> **覆盖范围**：V2.2 数据模型补全 / V2.3 异常与合规 / V2.5 交互升级 / T-37a 导入条件+形态一
> **排除范围**：V2.4 人脸覆盖（已废弃，延后至 V5）
> **证据等级**：L1（用例文档落档 `evidence/V3/` 可复核）
> **产出日期**：2026-06-27
> **基线参考**：V2.6 封板版全量测试 211/211 通过（taskconsuming=1383159ms）

---

## §1 用例格式规范

### 命名规范
```
{层级前缀}_{领域}_{场景描述}
```
- L1_：domain/model/、Rules、Utils 纯函数（本地 src/test）
- L2_：页面纯逻辑方法 buildXxx/formatXxx（本地 src/test）
- L3_：features/Service + 真实 RDB（ohosTest 设备）
- L4_：核心用户旅程 E2E（ohosTest 设备）

### C3 层级定义
C3 = 真机行为验证（L3 集成测试 + L4 E2E），在真机上通过 hdc aa test 执行，验证真实设备行为与预期一致。

---

## §2 V2.2 数据模型补全 - C3 用例

### 2.1 Person 字段扩展（T-22）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-PER-001 | Person 全字段创建与读取 | L3 | birthday/gender/remark/type/avatarBlob 创建后可读回 | L3_personService_createPerson_with_all_fields |
| V3C3-PER-002 | Person 默认值 | L3 | 未设置字段返回默认值 | L3_personService_createPerson_defaults |
| V3C3-PER-003 | birthday 设置后清除 | L3 | birthday 设值→更新为 null→读取为 null | L3_personService_updatePerson_birthday_set_clear |
| V3C3-PER-004 | gender 变更 | L3 | gender 创建后可更新 | L3_personService_updatePerson_gender_change |
| V3C3-PER-005 | remark 与 type 更新 | L3 | remark/type 可独立更新 | L3_personService_updatePerson_remark_and_type |
| V3C3-PER-006 | avatarBlob 置 null | L3 | avatarBlob 可清除 | L3_personService_updatePerson_avatarBlob_null |

### 2.2 Story 字段扩展（T-23）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-STO-001 | Story 全字段创建与读取 | L3 | timeStart/timeEnd/location/tags/coverPhotoUri 创建后可读回 | L3_storyService_createStory_with_all_fields |
| V3C3-STO-002 | Story 默认值 | L3 | 未设置字段返回默认值 | L3_storyService_createStory_defaults |
| V3C3-STO-003 | tags 往返 | L3 | tags 设置后读回一致 | L3_storyService_updateStoryAll_tags_roundtrip |
| V3C3-STO-004 | 部分更新 | L3 | updateStoryAll 仅更新传入字段 | L3_storyService_updateStoryAll_partial_update |

### 2.3 删除操作与级联规则（T-24）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-CAS-001 | 删除人物级联 | L3 | 删除 Person 后 Story 不变、PhotoRef 保留 | L3_personService_deletePerson_cascade |
| V3C3-CAS-002 | 删除故事级联 | L3 | 删除 Story 后 Person 不变、PhotoRef 保留 | L3_storyService_deleteStory_cascade |
| V3C3-CAS-003 | E2E 删除级联 | L4 | 真机 UI 删除人物后故事仍存在 | V2_CASCADE_story_after_person_delete |

### 2.4 PhotoRef 孤儿 GC（T-27）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-GC-001 | GC 清理无引用 | L3 | gcOrphan 清理无引用的 PhotoRef | L3_linkPhoto_gcOrphan_cleans_unreferenced |
| V3C3-GC-002 | GC 跳过有引用 | L3 | gcOrphan 不清理有引用的 PhotoRef | L3_linkPhoto_gcOrphan_skips_referenced |
| V3C3-GC-003 | E2E GC 触发 | L4 | 真机 UI 操作触发 GC | V2_GC_orphan_cleanup |

### 2.5 导入上限阻断（T-29）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-CAP-001 | Story 照片上限 1000 | L3 | Story 照片达 1000 后拒绝新增 | L3_linkPhoto_story_cap_1000 |
| V3C3-CAP-002 | Person 无上限 | L3 | Person 照片无上限限制 | L3_linkPhoto_person_no_cap |

---

## §3 V2.3 异常与合规 - C3 用例

### 3.1 失效态 ER-01（T-31）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-ERR-001 | URI 失效灰底 | L4 | PhotoSwiper 失效照片显示灰底+文字 | V2_PHOTOSWIPER_menu_remove（含失效态） |

### 3.2 权限拒绝引导 ER-02（T-32）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-PERM-001 | 权限拒绝引导 | L4 | 拒绝相册权限后显示引导文案 | 待 V3 补充（V2.6 占位） |

### 3.3 隐私说明页（T-33）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-PRIV-001 | 隐私页无人脸文本 | L4 | 隐私页无人脸功能入口（占位保留） | V2_PRIVACY_no_face_text |
| V3C3-PRIV-002 | 设置页无人脸入口 | L4 | 设置页无人脸开关/缓存清除 | V2_PRIVACY_settings_no_face_entry |

### 3.4 崩溃上报（T-34）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-CRASH-001 | 崩溃不闪退 | L4 | 异常场景不闪退，有兜底 | 待 V3 补充（V2.6 占位） |

---

## §4 V2.5 交互升级 - C3 用例

### 4.1 Tabs 原生导航（T-44）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-TAB-001 | Tab 切换 | L4 | 人物/故事 Tab 切换正常 | V2_SHELLTAB_switch_person_story |
| V3C3-TAB-002 | Tab 状态保持 | L4 | 切换后返回保持当前 Tab | V2_SHELLTAB_state_keep |

### 4.2 PersonPage 列表增强（T-45）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-PERLIST-001 | BottomSheet 创建 | L4 | +创建 → BottomSheet → 刷新列表 | V2_PERSON_create_via_bottomsheet |
| V3C3-PERLIST-002 | 左滑删除 | L4 | 左滑 → 确认删除 → 列表更新 | V2_PERSON_swipe_delete |

### 4.3 StoryPage 列表增强（T-46）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-STOLIST-001 | BottomSheet 创建 | L4 | +创建 → BottomSheet → 刷新列表 | V2_STORY_create_via_bottomsheet |
| V3C3-STOLIST-002 | 左滑删除 | L4 | 左滑 → 确认删除 → 列表更新 | V2_STORY_swipe_delete |

### 4.4 PhotoSwiper 全屏浏览（T-47）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-PHOTO-001 | 全屏打开 | L4 | 点击照片 → 全屏 Swiper | V2_PHOTOSWIPER_open |
| V3C3-PHOTO-002 | 左右切换 | L4 | 左右滑动切换照片 | V2_PHOTOSWIPER_swipe |
| V3C3-PHOTO-003 | 下滑关闭 | L4 | 下滑关闭全屏 | V2_PHOTOSWIPER_close |
| V3C3-PHOTO-004 | 菜单移除 | L4 | ⋮菜单 → 移除照片 | V2_PHOTOSWIPER_menu_remove |

### 4.5 PersonDetailPage 时间线混排（T-48）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-PDETAIL-001 | 阅览编辑分离 | L4 | 编辑/阅览态切换 | V2_PERSON_detail_view_edit |
| V3C3-PDETAIL-002 | 标签增删 | L4 | 标签添加/移除 | V2_D2_story_tags_add_and_remove（标签逻辑） |
| V3C3-PDETAIL-003 | 保存闭环 | L4 | 编辑→保存→返回详情 | V2_PERSON_detail_save |

### 4.6 StoryDetailPage 事件相册（T-49）

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-SDETAIL-001 | 阅览编辑分离 | L4 | 编辑/阅览态切换 | V2_STORY_detail_view_edit |
| V3C3-SDETAIL-002 | 标签增删 | L4 | 标签添加/移除 | V2_D2_story_tags_add_and_remove |
| V3C3-SDETAIL-003 | 保存闭环 | L4 | 编辑→保存→返回详情 | V2_STORY_detail_save |

---

## §5 T-37a 导入条件+形态一 - C3 用例

### 5.1 导入条件页

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-IMPCOND-001 | 进入导入向导 | L4 | 导入相册… → 导入向导 | V2_IMPCOND_enter_wizard |
| V3C3-IMPCOND-002 | 条件页可见 | L4 | 时间条件 + 开始扫描 | V2_IMPCOND_condition_page_visible |
| V3C3-IMPCOND-003 | 扫描按钮 | L4 | 开始扫描可点击 | V2_IMPCOND_scan_button_visible |
| V3C3-IMPCOND-004 | 返回闭环 | L4 | 返回 → 人物详情 | V2_IMPCOND_back_from_wizard |

### 5.2 形态一完整流程

| 用例 ID | 用例名 | 层级 | 验证点 | V2.6 对应用例 |
|---------|--------|------|--------|--------------|
| V3C3-IMPFULL-001 | 完整链路 | L4 | 入口→选图→条件→扫描→候选→写入 | V2RegressionImportFull 用例 |

---

## §6 用例统计

| 版本 | 覆盖维度 | C3 用例数 | V2.6 已对应 | V3 待补充 |
|------|----------|-----------|-----------|-----------|
| V2.2 | 数据模型补全 | 14 | 14 | 0 |
| V2.3 | 异常与合规 | 6 | 4 | 2（权限拒绝/崩溃上报占位） |
| V2.5 | 交互升级 | 16 | 16 | 0 |
| T-37a | 导入条件+形态一 | 5 | 5 | 0 |
| **合计** | — | **41** | **39** | **2** |

### V3 待补充用例（2 条）
1. **V3C3-PERM-001 权限拒绝引导**：V2.6 为占位，V3 需补充真机权限拒绝场景验证
2. **V3C3-CRASH-001 崩溃不上报**：V2.6 为占位，V3 需补充真机崩溃兜底验证

---

## §7 与 V2.6 的关系

V2.6 封板版全量测试 211/211 已覆盖本文档列出的 39/41 条 C3 用例（通过 L3 集成测试 + L4 E2E）。

V3 启动时，需在此基础上补充 2 条占位用例（权限拒绝、崩溃上报），并可根据 V3 新增 Feature 扩展用例集。

V2.4 人脸覆盖已去除（T-35~T-40 废弃，延后至 V5）。

---

## §8 证据归档

- 本文档：`document/evidence/V3/[QA]V3-C3-测试用例设计.md`
- V2.6 全量测试通过日志：211/211 通过（taskconsuming=1383159ms，2026-06-27）
- V2.6 测试代码：`entry/src/ohosTest/ets/test/`（L3PersonService/L3StoryService/L3LinkPhotoService/V2Regression*）
