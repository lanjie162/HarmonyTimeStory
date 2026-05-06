# 时光故事（TimeStory）HarmonyOS 平台能力调研表

<!-- 稳定章节锚点（供跨文档链接，勿删改 id）：harmonyos-sec-2-5、harmonyos-sec-7 -->

**版本**：V1.2  
**日期**：2026-05-05（**V1.1**：文档调研结案；**V1.2**：文中 **IM-*** 与 [时光故事-MVP需求说明-v4.md](../requirement/时光故事-MVP需求说明-v4.md) **V4.3 §8.4.4** 对齐；真机/矩阵见 [TODO-跟踪.md](../TODO-跟踪.md#todo-sec-c) **§C**）  
**用途**：确定 **最低 HarmonyOS / API 基线**、各能力 **可用性与限制**、**降级矩阵**；结论回填至 [§9.4 平台基线与降级矩阵](../requirement/时光故事-MVP需求说明-v4.md#mvp-sec-9-4) 及 [§12 风险与依赖](../requirement/时光故事-MVP需求说明-v4.md#mvp-sec-12)（文档：[时光故事-MVP需求说明-v4.md](../requirement/时光故事-MVP需求说明-v4.md) **V4.3+**）。  
**调研责任人**：（可选；测试补录 §2 时可填）  
**计划完成日期**：（可选）  
**deveco-mcp 初筛**：2026-05-05 已通过 `harmonyos_knowledge_search` 拉取官方文档摘要。**第二轮补充**（同日）：TaskPool、MediaAssetManager、`WithTheme`/Environment 深浅色。  
**文档调研状态**：**已结案**（工程快照 + 产品最低 **API12** 已入 §2.1 / §7）；**§2–§4、§7 余格、R-01/R-02/R-05 真机结论** 不在本文维护待办，见 **[TODO-跟踪.md §C](../TODO-跟踪.md#todo-sec-c)**。

---

## 1. 调研目标

1. 选定工程 **最低 HarmonyOS / API** 档位，并文档化。  
2. 对 **PhotoPicker**、**媒体 URI 持久化**（含云相册经系统呈现的资源）、**Vision Kit / 人脸检测与聚类**、**地理元数据**、**后台任务**、**深色主题** 在各档位上的行为做 **真机 + 当前 SDK** 验证。  
3. 输出 **降级矩阵**，驱动 **IM-06**（人脸）、**IM-09**（长任务）、**IX-02**、**ER-01** 的实现阈值与验收放宽系数（条号以 **MVP V4.3 §8.4.4** 为准）。

---

## 2. 环境信息（测试补录，跟踪见 [TODO-跟踪 §C2](../TODO-跟踪.md#todo-sec-c)）

| 项 | 内容 |
|----|------|
| DevEco Studio 版本 | *测试填写* |
| SDK / API 主工程 target | *测试填写* |
| 测试真机型号与系统版本（至少 2 档：中端 + 低端） | *测试填写* |
| 云相册测试账号（华为云图库开启） | *测试填写* |

### 2.1 工程当前配置（仓库快照，便于与文档基线对照）

来源：[build-profile.json5](../../build-profile.json5)（`default` 产品）。

| 项 | 当前值 | 与调研的关系 |
|----|--------|----------------|
| targetSdkVersion | 6.1.1(24) | 工程编译目标；不代表最低可运行系统。 |
| compatibleSdkVersion | **5.0.0(12)**（产品裁定 MVP 最低 **API 12**，2026-05-05） | 已与官方 `faceDetector` / `faceComparator` **文档起始 5.0.0(12)** 对齐；**R-04** 文档张力以「抬高最低档」关闭。 |

---

<a id="harmonyos-sec-2-5"></a>

## 2.5 deveco-mcp 知识库初筛（文档侧，2026-05-05）

以下条目来自 **HarmonyOS 开发者文档** 检索摘要，用于缩小真机验证范围；**§7 结论区** 中产品/工程已裁定项见表内 **【产品已裁定】** 等行，**余下真机格** 由测试按 [TODO-跟踪 §C](../TODO-跟踪.md#todo-sec-c) 补录。

### A. PhotoViewPicker / 媒体选择（Media Library Kit）

| 要点 | 文档依据（摘要） |
|------|------------------|
| **PhotoViewPicker** 类首批支持 **API version 10** 起。 | [PhotoViewPicker](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-photoaccesshelper-photoviewpicker) |
| `select()` 返回的 `PhotoSelectResult.photoUris` 具有 **永久授权**，可通过 `photoAccessHelper.getAssets` 使用；详见「媒体文件 URI 的使用方式」。 | 同上接口页「注意」 |
| 未传 `PhotoSelectOptions` 时，默认最大可选数量等为文档所述默认值（接口页：**默认最大 50** 等，以官方为准）。 | 同上 |
| **使用注意**：界面从图库返回后，**不宜在 Picker 回调内直接** 用 URI `open`；应异步或在后续用户操作中打开（官方指南说明）。 | [使用 Picker 选择媒体库资源](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/photoaccesshelper-photoviewpicker) |
| **地理 / EXIF**：文档说明对用户相册资源 EXIF 中地理位置等做了去隐私处理；若要读取被去隐私化前的信息，需 **`ohos.permission.MEDIA_LOCATION`**（及相册管理相关权限准备）。 | 同上指南「requestImageData」相关注意 |

### B. 媒体 URI、云路径与 ER-01

| 要点 | 文档依据（摘要） |
|------|------------------|
| 媒体资源 **真实路径** 示例含 **`/storage/cloud/...`**，与本地路径并列说明，支持「云侧物理位置与虚拟 URI」认知，利于 **断网 / 云删除** 失效态设计。 | [Media Library Kit 常见问题 - 媒体资源的常用路径表示](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/medialibrary-asset-management-faq) |
| **禁止**自行拼接、截断媒体库 URI/Path 充当真实路径操作，须走标准流程（`getAssets`、Picker 等）。 | 同上 FAQ |

### C. Core Vision Kit — 人脸检测 / 人脸比对

| 要点 | 文档依据（摘要） |
|------|------------------|
| **faceDetector**、**faceComparator** 官方 API 页标注 **起始版本：5.0.0(12)**（与 HarmonyOS 文档版本体系一致，**不等同**于旧「API 9/10/11」整数口径，工程对齐时请对照 **Studio/SDK 映射表**）。 | [faceDetector API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/core-vision-face-detector-api)、[faceComparator API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/core-vision-facecomparator-api) |
| **人脸检测**约束：建议 720p 以上；宽高像素范围；**接口耗时较久，不适合实时**；**不支持同一用户启用多个线程**（并发同一特性会排队或繁忙）。 | [Core Vision 简介 - 约束与限制](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/core-vision-introduction)、人脸检测指南 |
| **人脸比对**：仅 **1v1**；图像质量约束同人脸检测类文档。 | [人脸比对指南](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/core-vision-face-comparator) |
| **Kit 暂不支持模拟器**；设备类型含 Phone、Tablet、PC/2in1；**支持国家/地区**以简介页为准（文档写明中国境内为主，港澳台除外以官方为准）。 | Core Vision 简介 |

**对 MVP IM-06（人脸）的映射（文档侧；V4.3 条号，旧稿曾写作 IM-04）**

- **参考图 / 1v1 相似筛选**：官方路径为 **`faceComparator.compareFaces`**（两图 PixelMap），与需求「参考图模式」一致，且 **起始版本见上（5.0.0(12)）**。
- **人脸簇**：官方文档未提供「相册级人脸聚类」一键 API；**簇** 更可能为 **应用层**：先 **`faceDetector.detect` 得框**，再自建簇 / 或用比对做聚合（注意 **耗时与禁止多线程**）。真机须验证大规模下的性能是否满足 [§9.2 性能（验收量化）](../requirement/时光故事-MVP需求说明-v4.md#mvp-sec-9-2)。

### D. 与 R-01（云相册统一引用）的关系

文档侧 **支持**「Picker + 媒体库标准流程」统一处理用户可见资源；云资源物理路径在 FAQ 中单独说明。**最终**仍须在 **开启华为云图库** 的真机上验证：`photoUris` 在断网、仅缩略图、云端删除后的 **open / requestImageData** 行为（填 §3.1 云相册行）。

### E. TaskPool（**MVP §8.4** 相册导入与扫描、与 UI 解耦，**IM-09**、**IX-01**）

| 要点 | 文档依据（摘要） |
|------|------------------|
| **taskpool** 模块为应用提供 **多线程任务池**；首批接口自 **API version 9** 起支持。 | [@ohos.taskpool](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-taskpool) |
| 用于「后台执行、不长期阻塞 UI」的典型路径：`taskpool.execute`（`@Concurrent` 函数）或 **Task** 模式（可 **cancel**、优先级）。 | 同上；参见 [TaskPool 开发指导](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/taskpool-introduction) |
| **不建议**在任务中执行 **长时间阻塞**（尤其无限期阻塞），以免占满工作线程影响调度。 | taskpool 模块说明 |
| **SequenceRunner**（文档标注 **11+**）：命名串行队列，适合「多张照片依次做人脸检测」等 **严格串行**，与 Core Vision「同一特性勿多线程并发」可组合设计（Vision 调用仍在单 worker 内串行）。 | [SequenceRunner](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-taskpool#sequencerunner-11) |
| **长时任务（LongTask，文档 12+）**：无执行时间上限类语义、**terminateTask** 回收线程——**§8.4**「可取消长扫」可对照该能力做技术方案，**真机验证**取消与内存。 | 同文件内 LongTask / terminateTask 章节 |

**与 Core Vision（§2.5-C）的并存原则（文档侧建议）**  
- Vision：`faceDetector`/`faceComparator` **进程内并发约束**以 Vision 文档为准。  
- TaskPool：适合 **批量解码、遍历 URI 列表、准备 PixelMap** 等；**进入 Vision API 的调用**建议集中在 **单串行队列**（如 `SequenceRunner`）内，避免违反 Vision「不支持同一用户启用多个线程」类约束。

### F. 深浅色与系统主题（MVP §9.1）

| 要点 | 文档依据（摘要） |
|------|------------------|
| **WithTheme**：可设置子树 **深浅色**（`ThemeColorMode.SYSTEM` / `DARK` / `LIGHT`）与自定义 token；组件自 **API version 12** 起支持。 | [WithTheme](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-with-theme) |
| **Environment**：`colorMode` 等内置键可经 `Environment.envProp` → AppStorage → 组件读取，用于 **跟随系统** 深浅色判断；注意与 **UIContext** 生命周期相关限制（须在明确上下文场景使用）。 | [Environment 设备环境查询](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-environment) |
| **应用级 configuration**（如 `fontSizeScale` 跟随系统）见应用配置文件 **configuration** 标签说明（与主题换肤指南交叉引用）。 | Environment 文档内链 |

**对 MVP**：最低验收为 **系统切换深/浅色后主要页面可读、对比度可接受**；若需 **系统组件 token 级** 一致体验，可评估 **API 12+ WithTheme** 与工程 **targetSdk** 对齐。

### G. MediaAssetManager（大图请求、取消，与 IM-09）

| 要点 | 文档依据（摘要） |
|------|------------------|
| `requestImage` / `requestImageData` 等一般需要 **`ohos.permission.READ_IMAGEVIDEO`**；**通过 Picker 返回 URI 按指南调用** 时，文档说明 **可不申请** `READ_IMAGEVIDEO`（以官方指南为准）。 | [MediaAssetManager](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-photoaccesshelper-mediaassetmanager) |
| 上述接口返回 **requestId**，可用 **`cancelRequest`（文档标注 12+）** 取消尚未回调的请求——与 MVP「智能导入可取消」强相关；**API 11 真机须确认**是否下发该 API。 | 同上 MediaAssetManager |
| **quickRequestImage** 等为 **13+** 能力，智能导入若需「快路径」须单独做版本分支。 | 同上 |

---

## 3. 分 API 档位能力表（模板）

在对应单元格填写：**支持 / 部分支持（说明） / 不支持** + 简要备注 + 文档/API 链接。

### 3.1 API 12（HarmonyOS NEXT 等，以实际官方命名为准）

| 能力维度 | 支持情况 | 备注与限制 |
|----------|----------|------------|
| PhotoPicker 多选、安全授权 | **文档：支持（API10+ 起）** | PhotoViewPicker 首批 API 10；本行在 12 档默认 **支持**。 |
| 选中项 URI 持久化 / 重启后仍可用 | **文档：永久授权** | 接口页写明 `photoUris` **永久授权** + `getAssets`；重启与权限回收边界见 **[TODO §C3](../TODO-跟踪.md#todo-sec-c)**。 |
| 华为云相册资源在 PhotoPicker 中的 URI 行为（断网、仅缩略图等） | **测试验证（[TODO §C3](../TODO-跟踪.md#todo-sec-c)）** | 文档 FAQ 提及云路径形态；**R-01** 验证项。 |
| 媒体库地理元数据读取 | **文档：条件支持** | EXIF 地理等去隐私；需 **`ohos.permission.MEDIA_LOCATION`** 等（见 §2.5-A）。 |
| Vision Kit 人脸检测 | **文档：起始 5.0.0(12)** | `faceDetector` API 页；**不支持模拟器**；耗时、**禁多线程**。 |
| 人脸聚类 / 特征（端侧） | **文档：无系统级「聚类」API** | 需求「簇」= 应用层策略 + `faceDetector`；性能基线见 **[TODO §C8](../TODO-跟踪.md#todo-sec-c)**。 |
| 参考图人脸匹配（与 **IM-06** 对齐，V4.3） | **文档：起始 5.0.0(12)** | `faceComparator` 1v1；与参考图模式一致。 |
| 后台长任务 / 进度（与 **IM-09** 对齐，V4.3） | **文档：TaskPool API9+；LongTask/cancel 等见 12+ 说明** | 见 **§2.5-E**；与 Vision 串行策略在 **§2.5-E 末段**；取消与内存见 **[TODO §C3/C9](../TODO-跟踪.md#todo-sec-c)**。 |
| 媒体大图请求取消 | **文档：cancelRequest 12+** | 见 **§2.5-G**；低版本须备选方案。 |
| 深色模式 / 系统主题跟随 | **文档：Environment；WithTheme 12+** | 见 **§2.5-F**；系统主题抽检见 **[TODO §C3](../TODO-跟踪.md#todo-sec-c)**。 |

### 3.2 API 11（HarmonyOS 4.x 等）

| 能力维度 | 支持情况 | 备注与限制 |
|----------|----------|------------|
| PhotoPicker 多选、安全授权 | **文档：支持（API10+）** | 与 3.1 同源。 |
| URI 持久化 / 云相册 | **文档倾向支持；测试验证** | 依赖系统图库与账号配置；见 **[TODO §C3](../TODO-跟踪.md#todo-sec-c)**。 |
| 地理元数据 | **文档：条件支持** | 同 §2.5-A。 |
| 人脸检测 / 聚类 / 参考图 | **低于 MVP 最低 API12，本行仅供对照** | 官方 API 起始 **5.0.0(12)**。工程 `compatibleSdkVersion` 已产品裁定为 **5.0.0(12)**（见 §2.1）；**R-04** 已关闭。 |
| 后台长任务 | **文档：TaskPool 9+；SequenceRunner 11+** | **cancelRequest** 等见 §2.5-G 可能与 11 档不一致，真机核对。 |
| 深色模式 | **文档：Environment 可用；WithTheme 为 12+** | 低版本以资源与系统跟随为主，见 §2.5-F。 |

### 3.3 API 10 及以下（历史对照；**MVP 已裁定最低 API12，非交付目标**）

| 能力维度 | 支持情况 | 备注与限制 |
|----------|----------|------------|
| PhotoViewPicker | **文档：支持（API10+）** | 与 §2.5-A 一致。 |
| TaskPool | **文档：支持（API9+）** | 适合扫描与解码；**SequenceRunner 为 11+**，API10 档串行策略须另选（如单 Task 队列）。 |
| MediaAssetManager.cancelRequest | **文档：12+** | 低于 12 时本能力不可用；MVP 以 **API12** 为底，见 **§2.1**。 |
| Core Vision 人脸 | **文档：5.0.0(12) 起** | MVP **最低 API12** 与文档起点一致；本行不再触发 **R-04** 拆包。 |
| WithTheme | **文档：12+** | 主题深度定制可能不可用，依赖资源与默认组件样式。 |

---

## 4. 降级矩阵（模板；填写跟踪见 [TODO §C4](../TODO-跟踪.md#todo-sec-c)）

**说明**：行 = 能力或场景；列 = 机型分档或 API 分档；单元格 = 行为（开启 / 降级 / 关闭）+ 阈值（如 RAM、相册张数）。

| 需求 ID | 场景 / 能力 | 中端机（基线） | 低端机 / 低 API | 备注 |
|---------|-------------|----------------|-----------------|------|
| IM-06 | 人脸簇模式（§8.4） |  |  |  |
| IM-06 | 参考图模式（§8.4） |  |  |  |
| IM-09 | **§8.4** 相册扫描 / 长任务 |  |  | **文档**：TaskPool 承载遍历/解码；取消依赖 **MediaAssetManager.cancelRequest（12+）** 须对低版本降级。 |
| IX-02 | 人脸索引后台任务 |  |  | **文档**：Vision 串行 + TaskPool **SequenceRunner（11+）** 组合；禁止 Vision 多线程。 |
| IX-02 | 相册全量扫描 |  |  |  |
| ER-01 | 云资源断网展示 |  |  |  |
| §9.2 | 列表首屏 1.5s |  | 允许放宽系数： |  |

---

## 5. 需求条目反向追溯（「降级后验收调整」列见 [TODO §C5](../TODO-跟踪.md#todo-sec-c)）

将矩阵结论映射到 [时光故事-MVP需求说明-v4.md](../requirement/时光故事-MVP需求说明-v4.md)（示例：[§9.4](../requirement/时光故事-MVP需求说明-v4.md#mvp-sec-9-4)）各条目，便于测试用例分层：

| MVP 条目 | 依赖的平台能力 | 降级后验收调整 |
|----------|----------------|----------------|
| IM-01～IM-03、IM-04～IM-07 | **§8.4** 三形态入口与条件（PhotoPicker、媒体查询、地理、人脸、**AND**） |  |
| IM-10 | 人脸开关；停止新索引 / **形态三** 新建议等（见定稿 **IM-10**） |  |
| IM-09 | 长任务、不阻塞 UI；**TaskPool**；**cancelRequest（12+）** 见 **R-05** | 低版本取消语义降级 |
| IX-01 / IX-02 | 索引与降级；**SequenceRunner（11+）** 串行 Vision |  |
| ER-01 | URI、网络、权限 |  |
| §9.1 主题 | **Environment** / **WithTheme（12+）** | 低版本以资源色值与系统跟随为主 |
| §9.2 性能 | 列表与网格、扫描 |  |

---

## 6. 风险与假设

| ID | 描述 | 状态 | 对需求文档的回修 |
|----|------|------|-------------------|
| R-01 | 假设：云相册资源可通过 PhotoPicker 与本地资源统一引用，无需 App 侧华为云 SDK。 | **测试闭环（[TODO §C7](../TODO-跟踪.md#todo-sec-c)）** | 若不成立，研发走 [TODO-跟踪.md](../TODO-跟踪.md) **B1** 回修 [§5.1](../requirement/时光故事-MVP需求说明-v4.md#mvp-sec-5-1) / [§6.1](../requirement/时光故事-MVP需求说明-v4.md#mvp-sec-6-1) |
| R-02 | 人脸聚类准确率与耗时随相册规模非线性增长。 | **测试闭环（[TODO §C8](../TODO-跟踪.md#todo-sec-c)）** | 可收紧 **IX-02** / **§8.4** 形态一·二默认扫描范围 |
| R-03 | 地理位置缺失率高。 | 已知 | 文案与 **IM-05** 地点降级路径（V4.3） |
| R-04 | **官方 `faceDetector` / `faceComparator` 文档起始版本为 5.0.0(12)**，曾与工程 **compatibleSdkVersion=4.0.0(10)** 不一致。 | **已关闭（产品 + 工程）** | 产品裁定 **MVP 最低 API 12**；工程 `compatibleSdkVersion` 已调至 **5.0.0(12)**（见 [build-profile.json5](../../build-profile.json5)）；定稿 [§9.4](../requirement/时光故事-MVP需求说明-v4.md#mvp-sec-9-4)。 |
| R-05 | **`MediaAssetManager.cancelRequest` 为 12+**；MVP 最低已 **API12**，系统级取消接口可用性以真机确认为准。 | **测试闭环 + 研发实现**（[TODO §C9](../TODO-跟踪.md#todo-sec-c) + [TODO-跟踪.md](../TODO-跟踪.md) **B2**） | 应用层队列兜底与文案；与 **IM-09** 验收对齐。 |

---

<a id="harmonyos-sec-7"></a>

## 7. 结论回填区（测试补录 + 发版前对齐 MVP）

**最低 API** 已由产品与工程裁定（见上表首行）。**余下各格** 由测试按 **[TODO-跟踪 §C6 / C10](../TODO-跟踪.md#todo-sec-c)** 补全后，发版前将本节与 [§9.4 表格](../requirement/时光故事-MVP需求说明-v4.md#mvp-sec-9-4)、[§12 首段](../requirement/时光故事-MVP需求说明-v4.md#mvp-sec-12) **对齐**（定稿 **V4.3+** 时，**§8.4** 三形态与 **IM-01～IM-10** 为验收主索引）。

**说明**：本节 **不再** 作为「调研待办」关闭条件；文档调研已在 **§8** 结案。

| 项目 | 结论 |
|------|------|
| **推荐最低 HarmonyOS / API** | **【产品已裁定，2026-05-05】** MVP **最低 API version 12**，与工程 `compatibleSdkVersion` **5.0.0(12)** 及官方人脸 API 文档起点一致。**机型分档上的**体验阈值仍以 §3 / §4 真机为准。 |
| **工程 compileSdk / target** | 见 §2.1：`targetSdkVersion` **6.1.1(24)**，`compatibleSdkVersion` **5.0.0(12)**（与 [需求说明 §9.4](../requirement/时光故事-MVP需求说明-v4.md#mvp-sec-9-4) 一致）。 |
| **放弃支持的最低档（若有）** | **测试补录**（[TODO §C6](../TODO-跟踪.md#todo-sec-c)）— 例：机型分档上是否关闭「簇」扫描等。 |
| **PhotoPicker + 云相册 URI 策略摘要** | **【文档】** `photoUris` 永久授权 + 标准 `getAssets`/读写流程；云物理路径见 FAQ。**【测试补录】** 断网 / 云删策略（[TODO §C6](../TODO-跟踪.md#todo-sec-c)）。 |
| **人脸能力在低端机的默认策略** | **【文档】** 串行队列、控制并发、非实时。**【测试补录】** 超时阈值与是否关闭「簇」扫描（[TODO §C6](../TODO-跟踪.md#todo-sec-c)）。 |
| **IM-09 任务模型（文档预填）** | **【文档】** TaskPool（API9+）+ 建议 Vision 调用走 **SequenceRunner（11+）**；大图请求取消注意 **R-05**。 |
| **深浅色（文档预填）** | **【文档】** `Environment.colorMode` 跟随系统；**WithTheme** 为 API12+ 增强项。 |
| **§9.2 性能门槛在低端机的放宽系数** | **测试补录**（验收基准见 [§9.2](../requirement/时光故事-MVP需求说明-v4.md#mvp-sec-9-2)；[TODO §C6](../TODO-跟踪.md#todo-sec-c)）。 |
| **调研完成签字 / 日期** | **测试结案时填写**（[TODO §C6](../TODO-跟踪.md#todo-sec-c)） |

---

## 8. 文档调研结案（原 Checklist 已废除）

**文档调研阶段**（deveco-mcp 初筛两轮 + 工程 **build-profile** 快照 + 产品最低 **API12** / **R-04** 关闭）已 **结案**。  
原「测试阶段 / 发版前 / R-01」拆条 **`- [ ]` 清单已废除**，不再在本文档维护；**真机、§4 矩阵、§5 映射、§7 余格、R-01/R-02/R-05 验证、发版前与 MVP §9.4/§12 对齐** 一律在 **[TODO-跟踪.md §C](../TODO-跟踪.md#todo-sec-c)** 跟踪。

- [x] **deveco-mcp** `harmonyos_knowledge_search` 文档初筛已写入 **§2.5**，并更新 **§3.1 / §3.2 / §6 R-04 / §7 预填**（2026-05-05）  
- [x] **deveco-mcp 第二轮**：§2.5 **E/F/G**（TaskPool、深浅色、MediaAssetManager）、**§3.3** 填首版、**§4** 备注、**§6 R-05**、**§7** 增 **IM-09**/主题预填、**§5** 追溯更新（2026-05-05）  
- [x] **V1.2**：全文 **IM-*** 与 MVP **V4.3 §8.4.4** 对齐（2026-05-05）  
- [x] **文档调研结案**（V1.1）：真机/矩阵/风险验证与 MVP 对齐改 **TODO-跟踪 §C**；原 §8 未勾选项 **全部关闭**（不再作为调研待办）。

---

**文档结束**
