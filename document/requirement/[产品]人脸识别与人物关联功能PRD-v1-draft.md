---
title: 人脸识别与人物关联功能 PRD
version: D0.1（草稿）
date: 2026-05-31
status: draft
author: pm
source: 多轮技术调研 + 方案讨论
related:
  - document/techdoc/时光故事-MVP技术方案-v1.md
  - document/techdoc/HarmonyOS平台能力调研表-v1.md
  - document/task/requests/plan/[任务经理]2026-05-20-[V2.4]-端侧AI管线版六任务（含T1拆分）派发.md
---

# [产品] 人脸识别与人物关联功能 PRD

## 背景与目标

### 核心需求陈述

**用户**在管理家庭照片时，需要**按人物快速找到相关照片**，而非逐张翻阅。当前 App 已支持手动创建人物并关联照片，但手动逐张关联效率极低，用户期望系统能自动识别同一人物的照片并建议关联。

### 平台能力约束（调研结论）

| 约束 | 说明 |
|------|------|
| faceDetector 不输出特征向量 | 仅返回人脸区域（rect）、五官点（points）、姿态（pose）、置信度（probability） |
| faceComparator 仅支持 1v1 比对 | 输入两张图片，返回 isSamePerson + similarity；不支持指定人脸区域，需预先裁剪 |
| 华为图库人物搜索为系统私有能力 | 不对外暴露 API，无法借用系统已有的人脸分组 |
| faceDetector 不支持模拟器 | 开发调试必须真机 |
| faceComparator 禁止多线程并发 | 批量比对必须串行执行 |

### 目标

1. **自动识别人脸**：扫描已入库照片，检测人脸区域并持久化
2. **智能分组**：将检测到的人脸按「是否同一人」自动聚类
3. **用户确认**：系统产出建议分组，用户确认后才建立人物-照片关联
4. **增量归簇**：新导入照片自动与已有参考脸比对，命中即关联

---

## 用户与场景

### 用户角色

| 角色 | 说明 |
|------|------|
| 主要用户 | 家庭照片管理者，管理 5~20 个常拍人物，照片量 200~2000 张 |

### 核心场景

| # | 场景 | 用户任务 | 成功判据 |
|---|------|----------|----------|
| S1 | **冷启动**：用户刚装 App，还没创建任何人物 | 系统自动发现照片中的人物分组，推荐给用户 | 用户看到 3+ 个候选人物分组，确认后照片自动关联 |
| S2 | **指定参考脸**：用户创建「妈妈」人物，从照片中选定妈妈的脸 | 后续新照片中妈妈的脸自动关联到「妈妈」 | 新导入含妈妈的照片，无需手动操作即出现在「妈妈」人物下 |
| S3 | **增量发现**：日常使用中，新导入照片出现未见过的人脸 | 系统自动聚类新人物，推送到建议页 | 建议页出现新人物分组，用户确认后关联 |
| S4 | **合照处理**：一张照片含多个人脸 | 每个人脸独立识别，分别关联到对应人物 | 合照中妈妈和爸爸的脸分别关联到各自人物 |

---

## 需求范围（In/Out）

### In（本期交付）

| ID | 功能 | 优先级 | 说明 |
|----|------|--------|------|
| F-01 | 人脸检测 | Must | faceDetector.detect 扫描照片，识别人脸区域并持久化 |
| F-02 | 参考脸指定 | Must | 用户创建/编辑人物时，可从照片中选定一张脸作为参考脸 |
| F-03 | Tier-1 比对 | Must | 新入库照片与已有人物的参考脸比对，isSamePerson=true 自动关联 |
| F-04 | 冷启动聚类 | Should | 无参考脸时，对首批照片自动聚类，产出候选人物分组 |
| F-05 | 建议页 | Must | 展示候选人物分组，用户可确认/忽略/拆分/合并 |
| F-06 | 增量归簇 | Should | 新脸未命中 Tier-1 时，与 Tier-2 候选参考脸比对或新建候选簇 |
| F-07 | 人脸开关 | Must | 设置页人脸分析开关，关闭后停止扫描和比对 |

### Out（本期不做）

| ID | 功能 | 原因 |
|----|------|------|
| X-01 | 人脸特征向量导出 | faceDetector API 不提供 |
| X-02 | 调用华为图库人物搜索 | 系统私有能力，无公开 API |
| X-03 | 实时相机人脸检测 | faceDetector 耗时久，不适合实时场景 |
| X-04 | 跨设备人脸数据同步 | 本期仅端侧，不上云 |
| X-05 | 人脸识别（身份认证） | 本期仅做「同人归类」，不做身份认证 |

---

## 功能方案

### 1. 两级参考脸体系

```
Tier-1：用户指定参考脸（金标准）
  → 用户创建 Person 时选定一张脸
  → 所有新脸优先和 Tier-1 比对
  → isSamePerson=true → 直接关联到 Person

Tier-2：系统候选参考脸（自动发现）
  → 冷启动时自动聚类产出
  → 新脸未命中 Tier-1 时，和 Tier-2 比对
  → 命中 → 归入候选簇
  → 未命中 → 新建候选簇
  → 用户确认后升级为 Tier-1
```

### 2. 扫描流程

```
触发：照片入库后 / 后台闲时

对每张未扫描照片：
  1. faceDetector.detect(pixelMap) → Face[]
  2. 每个 Face 写入 face_record（photoUri + faceIndex + rect + probability）
  3. 标记照片已扫描

对每个新检测到的人脸：
  1. 和所有 Tier-1 参考脸比对（K 次，K=已有 Person 数）
     命中 → 写入 face_cluster_member，关联到对应 Person
     未命中 → 进入步骤 2
  2. 和所有 Tier-2 候选参考脸比对（M 次）
     命中 → 归入候选簇
     未命中 → 新建候选簇（该脸成为新簇的参考脸）
```

### 3. 冷启动聚类（无 Tier-1 时）

```
对首批 N 张照片的所有脸：
  1. 取 face[0]（最大脸，通常最清晰）→ 新建候选簇-0，face[0] 为参考脸
  2. face[0] 和 face[1..N] 逐一比对
     isSamePerson=true → 归入候选簇-0
     isSamePerson=false → 跳过
  3. 取下一个未归属脸 → 新建候选簇-1
  4. 重复直到所有脸归属
  5. 过滤：成员数 < 2 的簇不推送建议页
  → 产出候选簇列表 → 推送 SuggestPage
```

### 4. 建议页交互

| 操作 | 效果 |
|------|------|
| **确认** | 候选簇升级为 Tier-1，创建/关联 Person，所有成员脸的照片关联到该 Person |
| **忽略** | 删除候选簇，成员脸标记为已处理，不再推送 |
| **拆分** | 从簇中移除错误的脸，移除的脸重新进入未归属池 |
| **合并** | 两个候选簇合并，保留更高质量的参考脸 |

### 5. 人脸区域裁剪（供 faceComparator 使用）

```
从 face_record 读取 rect → 扩展 30% 边距 → createPixelMap({ region }) 区域解码
→ 裁剪出单人照 → 传给 faceComparator.compareFaces()
降级：区域解码失败时，全图解码 + readPixels 裁剪
最小尺寸约束：宽 > 100px，高 > 224px
```

### 6. 人脸开关（IM-10）

| 选项 | 效果 |
|------|------|
| 仅关闭后续分析 | 已有关联保留，新照片不再扫描检测 |
| 关闭并清空 | 删除所有 face_record + face_cluster + face_cluster_member，已有 Person 保留但无参考脸 |

---

## 优先级与版本计划

### 版本切分

| 版本 | 范围 | 对应任务 |
|------|------|----------|
| **V2.4-a** | F-01 人脸检测 + F-02 参考脸指定 + F-03 Tier-1 比对 + F-07 人脸开关 | T-35, T-36, T-38 |
| **V2.4-b** | F-04 冷启动聚类 + F-05 建议页 + F-06 增量归簇 | T-36, T-39 |
| **V2.4-c** | 导入条件真实逻辑 + 低端机降级 | T-37, T-40 |

### MoSCoW 优先级

| 优先级 | 功能 | 理由 |
|--------|------|------|
| **Must** | F-01, F-02, F-03, F-05, F-07 | 核心闭环：检测→指定参考脸→自动关联→建议确认→可关闭 |
| **Should** | F-04, F-06 | 提升体验：冷启动自动发现、增量归簇 |
| **Could** | 拆分/合并操作 | 建议页高级操作，可后续迭代 |

---

## 验收标准

| ID | 需求条款 | Given | When | Then | 证据等级 |
|----|----------|-------|------|------|----------|
| AC-01 | 人脸检测 | 照片已入库 | 触发扫描 | face_record 表写入人脸区域（rect + probability） | L2（真机 RDB 查询） |
| AC-02 | 参考脸指定 | 用户创建/编辑 Person | 从照片中选定一张脸 | 该脸成为 Person 的 Tier-1 参考脸，face_cluster.person_id 非空 | L2（真机 UI + RDB） |
| AC-03 | Tier-1 自动关联 | Person 已有参考脸 | 新入库照片含该人 | isSamePerson=true 的脸自动关联到 Person，无需手动操作 | L2（真机日志 + RDB） |
| AC-04 | 冷启动聚类 | 无任何 Person | 首批照片扫描完成 | 产出 ≥1 个候选簇（成员数 ≥2），推送 SuggestPage | L2（真机 UI 截图） |
| AC-05 | 建议页确认 | 候选簇存在 | 用户点击确认 | 候选簇升级为 Tier-1，创建 Person，成员脸照片关联到 Person | L2（真机 UI + RDB） |
| AC-06 | 建议页忽略 | 候选簇存在 | 用户点击忽略 | 候选簇删除，成员脸不再推送 | L2（真机 UI + RDB） |
| AC-07 | 合照多脸 | 一张照片含 2+ 人脸 | 扫描检测 | 每个人脸独立写入 face_record，各自可关联到不同 Person | L2（真机 RDB） |
| AC-08 | 人脸开关-仅关闭 | 人脸分析已开启 | 用户选择「仅关闭后续分析」 | 已有关联保留，新照片不再扫描 | L2（真机 UI + 日志） |
| AC-09 | 人脸开关-关闭并清空 | 人脸分析已开启 | 用户选择「关闭并清空」 | face_record + face_cluster + face_cluster_member 清空，Person 保留 | L2（真机 RDB 查询） |
| AC-10 | 比对性能 | K=10 个已有 Person | 新导入 1 张照片 | 每个脸 ≤15 次比对，≤5 秒完成 | L2（真机日志耗时） |

---

## 风险与待确认问题

### 风险

| ID | 风险 | 影响 | 缓解 |
|----|------|------|------|
| R-01 | faceComparator 误判（isSamePerson 不准） | 错误关联照片到人物 | Tier-1 由用户指定参考脸兜底；建议页需用户确认；支持拆分操作 |
| R-02 | faceDetector 在合照中漏检小脸 | 小脸/远景脸未识别 | 可接受，后续可降低检测阈值重扫 |
| R-03 | 大量照片首次扫描耗时长 | 中度用户约 1 小时 | 分批扫描 + 进度展示；后台闲时执行 |
| R-04 | 区域解码 createPixelMap({ region }) 部分图片失败 | 无法裁剪人脸区域 | 降级为全图解码 + readPixels；最差传整图给 faceComparator |
| R-05 | faceComparator 不支持模拟器 | 开发调试必须真机 | L1/L2 测试用 Mock；L3 必须真机 |

### 待确认问题

| # | 问题 | 建议 | 影响 |
|---|------|------|------|
| Q-01 | 冷启动聚类首批扫描多少张照片？ | 建议 50 张，平衡速度与分组质量 | 影响首次体验 |
| Q-02 | 候选簇成员数 < 2 是否推送？ | 建议不推送，减少噪音 | 影响建议页内容量 |
| Q-03 | faceComparator 比对阈值是否可调？ | 建议 T_show=0.82（交互评审 M5 已定），但 isSamePerson 由 API 返回，不可调 | 可能影响准确率 |
| Q-04 | 原始 DoD「输出人脸特征向量（float[]）」如何处理？ | 建议修改为「输出人脸区域（FaceRect）+ 支持 faceComparator 1v1 比对」，因 API 不提供特征向量 | 需 CR 变更 |

---

## DoD 对齐映射

| 需求条款 | 原始 DoD 编号 | 修改建议 |
|----------|--------------|----------|
| F-01 人脸检测 | C-1 (T-35) | **修改**：~~输出人脸特征向量（float[]）~~ → 输出人脸区域（FaceRect）+ face_record 持久化 |
| F-02 参考脸指定 | C-2 (T-36) | **保留**：参考图模式与 IM-06 一致 |
| F-03 Tier-1 比对 | C-2 (T-36) | **新增**：faceComparator 1v1 比对，isSamePerson 判定 |
| F-04 冷启动聚类 | C-2 (T-36) | **修改**：~~K-means 或 pairwise 阈值比对~~ → 贪心聚类（faceComparator.isSamePerson） |
| F-05 建议页 | C-5 (T-39) | **保留**：IM-03 建议列表驱动 SuggestPage |
| F-07 人脸开关 | C-4 (T-38) | **保留**：IM-10 双选项 |

---

## 附录：数据模型（技术参考）

### face_record 表

```sql
CREATE TABLE IF NOT EXISTS face_record (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  photo_uri    TEXT    NOT NULL,
  face_index   INTEGER NOT NULL,
  rect_left    INTEGER NOT NULL,
  rect_top     INTEGER NOT NULL,
  rect_width   INTEGER NOT NULL,
  rect_height  INTEGER NOT NULL,
  probability  REAL    NOT NULL,
  scanned_at   INTEGER NOT NULL,
  UNIQUE(photo_uri, face_index)
);
```

### face_cluster 表

```sql
CREATE TABLE IF NOT EXISTS face_cluster (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  reference_face_id INTEGER NOT NULL,
  person_id         INTEGER,
  created_at        INTEGER NOT NULL,
  FOREIGN KEY (reference_face_id) REFERENCES face_record(id),
  FOREIGN KEY (person_id) REFERENCES person(id)
);
```

### face_cluster_member 表

```sql
CREATE TABLE IF NOT EXISTS face_cluster_member (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  cluster_id     INTEGER NOT NULL,
  face_record_id INTEGER NOT NULL,
  similarity     REAL,
  joined_at      INTEGER NOT NULL,
  FOREIGN KEY (cluster_id) REFERENCES face_cluster(id),
  FOREIGN KEY (face_record_id) REFERENCES face_record(id),
  UNIQUE(cluster_id, face_record_id)
);
```

### 状态流转

```
face_cluster.person_id = NULL  →  Tier-2 候选簇（系统自动发现，待确认）
face_cluster.person_id = 42    →  Tier-1 已确认簇（用户已关联到 Person#42）

用户在 SuggestPage 确认：
  UPDATE face_cluster SET person_id = 42 WHERE id = 5;
  → 候选簇自动升级为 Tier-1
  → 后续新脸优先和此簇参考脸比对
```
