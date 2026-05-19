# T-9 · V2-D1～D4 · 测试计划与执行索引（评审收口）

**执行人**：qa（统一任务列表 **T-9**）  
**日期**：2026-05-10  
**关联派发**：`TR-20260509-02#C-6`；评审收口：`TR-20260510-01#C-1`  
**模板**：`document/plan/V2/qa/[QA]2026-05-09-V2关键验收证据最小模板.md`（路径 / 日志 / 判定）

## §1 · T-10 启动须知（G-2·A）

**T-10**（`TR-20260509-02#C-7`）须在 **T-9** 验收结论为「**通过**」后方可启动；「**有条件通过**」不得作为 **T-10** 前置。本索引不替代 **T-10** 之 **V2-D5/V2-D6** 真机取证。

## §2 · 子任务与 V2-D 映射（T9-ST-D1～D4）

| 子任务 | V2-D | 测试范围摘要 |
|--------|------|----------------|
| T9-ST-D1 | **V2-D1** | 人物 Tab 列表→详情→编辑、关联故事、手动加图（PH-01） |
| T9-ST-D2 | **V2-D2** | 故事 Tab 列表→详情→编辑、关联人物、手动加图（PH-01/ST-07 显性） |
| T9-ST-D3 | **V2-D3** | 导入主链（准备→条件→扫描→候选确认→写入）；**G-1·A** 形态三主路径 Must（`TR-20260509-03` / T-12～T-16、建议页）；**IM-09** 取消/重试与进度语义；异常态最小集见 §4 |
| T9-ST-D4 | **V2-D4** | **B2** 取消全链 + 与导入结合；证据范式对齐模板 **V2-D4** |

## §3 · 用例命中与一轮执行证据（可寻址）

| DoD 桶 | 用例/场景命中摘要 | 证据路径（归档路径 / 步骤） | 结果判定 |
|--------|-------------------|---------------------------|----------|
| **V2-D1** | 人物主路径、关联故事、相册加图、PH-01 | `document/task/archive/2026-05-10/[任务经理]T-4-人物主流程实现与回归.md`（通晒快照内执行结果 / 验收 / 复现步骤） | 与 T-4 **已通晒** 结论一致：主路径可复现 |
| **V2-D2** | 故事主路径、关联人物、相册加图、ST-07 说明 | `document/task/archive/2026-05-10/[任务经理]T-5-故事主流程实现与回归.md` | 与 T-5 **已通晒** 结论一致 |
| **V2-D3** | 形态一/二导入步序、扫描取消、写入刷新 | `document/evidence/V2/2026-05-09-T6-import-wizard-minimal.md` | 主顺序与 `ImportPage` 锚点可复核 |
| **V2-D3·G-1** | 形态三入口/最小页/条件/扫描取消/候选 | `document/evidence/V2/2026-05-10-T12-T16-import-suggest-batch.md` | 批量最小复现步骤 + 代码锚点 |
| **V2-D4** | `cancelRequest`、扫描中途取消、与导入链结合 | `document/evidence/V2/2026-05-09-T7-B2-cancel-minimal.md` | 取消语义与 T-6 交叉引用 |

### §3.1 · hdc 原生代跑一轮补充（2026-05-10 · 执行）

| 项 | 证据路径 | 结果判定 |
|----|----------|----------|
| **详细命令计划（调研落盘）** | `document/plan/V2/qa/[QA]2026-05-10-T9-V2-D1-D4-hdc原生测试执行详细计划.md` | 可执行级 hdc/`hdc shell` 序列已归档 |
| **Phase A/B（安装 / bm dump / aa start / hilog）** | `document/evidence/V2/2026-05-10-T9-hdc-agent-execution.md`；原始输出 `2026-05-10-T9-hdc-phase-a-b-log.txt` | **通过**（与 §8 设备一致） |
| **Hypium · `OpenHarmonyTestRunner`（示例套 + V2Regression）** | `document/evidence/V2/2026-05-10-T9-V2D1-D4-hypium-run6.txt`；用例源码 `entry/src/ohosTest/ets/test/V2DRegression.test.ets` | **历史子集**：**Tests run: 5, Pass: 5**（`ActsAbilityTest.assertContain` + `V2_D1` / `V2_D2` / `V2_D3_suggest` / `V2_D3_import_wizard_shell`）。**未覆盖**：派发全文中的关联故事/相册/PH-01、导入主链写入、IM-09/B2 全链（见主证据「结果记录」表） |
| **Hypium · V2Regression run25（`ImportPage` 向导 `Scroll` 后主链 + IM-09 + 候选提交）** | `document/evidence/V2/2026-05-10-T9-V2D1-D4-hypium-run25-import-scroll.txt`；构建日志 `2026-05-10-T9-mcp-build-entry-default.log`、`2026-05-10-T9-mcp-build-entry-ohosTest.log` | **通过**：**Tests run: 9, Pass: 9**（含 `V2_D3_import_conditions_scan_cancel_im09`、`V2_D3_import_scan_confirm_commit`）。**真机**：`hdc list targets` → **`192.168.73.160:46629`**；**命令模板**：`document/plan/V2/qa/[QA]2026-05-10-T9-V2-D1-D4-hdc原生测试执行详细计划.md` §6 |
| **Hypium · run26（mock 相册等价 + PH-01 人物/故事/导入 + B2 S2～S4 应用层矩阵）** | `document/evidence/V2/2026-05-10-T9-V2D1-D4-hypium-run26-album-b2-ph01.txt`（取证命令见 QA 详细计划 **§6.1**）；用例源码 `entry/src/ohosTest/ets/test/V2DRegression.test.ets`；DEBUG 钩子 `PersonDetailPage` / `StoryDetailPage` / `ImportPage`；**主档**已与 **`hypium-run28-ime-dismiss.txt`** 同步（IME 收起后主键）；历史副本 `…-hypium-run27-dev-nested-scroll.txt` | **通过**：**Tests run: 16, Pass: 16, Error: 0**（2026-05-11；含嵌套 `Scroll` / `Grid.scrollBar(Off)` + **`SoftKeyboard` 主动收键盘** 后主键）。**语义**：系统 **PhotoViewPicker** 仍为手测范畴；本篇为 **mock `file://e2e/...` + DEBUG 按钮**；**OS 级 B2** 仍以 T-10 / hilog 专项为准。**边界**：不与 §3 主表派发「全量手跑」互斥 |
| **V2-D1～D4 历史证据（§3 主表）** | 各归档路径不变 | 与 Hypium **互补**；**不以 run26（16/16）/run25/run6 替代** §3 全量语义（派发「全量」手跑与归档仍并行） |

## §4 · 异常态最小集（D3/D4 交叉）

| 项 | 说明 | 证据或登记 |
|----|------|------------|
| **PH-01** 重复 URI | 人物/故事加图与导入链 | T-4/T-5 执行结果；T-6 最小证据 § |
| **ST-07** 上限/全不选 | 故事侧 9 张说明；候选步「至少勾选一项」 | T-5 归档；`2026-05-10-T12-T16-import-suggest-batch.md` §T-16 |
| **IM-09** 取消 | 扫描取消对话框与「正在取消…」、回条件保留状态 | T-7；批量证据 §T-15 |

## §5 · 阻塞 / 严重缺陷状态（DoD-2）

| 项 | 状态 |
|----|------|
| 统一任务列表 **§阻塞单** | **暂无**（见 `document/task/[任务经理]统一任务列表.md`） |
| 本索引登记之 **P1 阻塞缺陷** | **无**（安装类）；**执行侧**：首轮 `aa test` 因 **错误使用 `ActsAbilityTest` 作 runner** 导致 App died；**重跑已纠正**（见 `2026-05-10-T9-hdc-aa-test-rerun-OpenHarmonyTestRunner.txt`）；**V2Regression** 曾误用同包 `aa force-stop` 致 App died，已移除（见主证据 run6 段「实现侧要点」）；**run6** `Pass 5/5`（`2026-05-10-T9-V2D1-D4-hypium-run6.txt`）；**run24** 曾 **`V2_D3_import_scan_confirm_commit` 失败**（候选步底部按钮被裁切）；**研发**在 `ImportPage.ets` 向导主体增加 **`Scroll`** 后 **run25** `Pass 9/9`（`2026-05-10-T9-V2D1-D4-hypium-run25-import-scroll.txt`）；**run26** 扩充用例 + IM-09 滚动断言后主键 **`Pass 16/16`**（`hypium-run26-album-b2-ph01.txt`，**2026-05-11** 起与 **`hypium-run28-ime-dismiss.txt`** 同步，含 **`SoftKeyboard`**） |
| **T-9 全文 DoD** | **Hypium**：历史 **run25** **9/9**；扩充 **run26** 已取证 **`hypium-run26-album-b2-ph01.txt`** **Pass 16/16**。**仍不等同**派发「全量」之 **§3 主表逐项手跑**；**真相册 UI / OS B2** 不由此套替代 |

## §6 · 最小复现（索引自身）

1. 打开本文件 §3 表，逐行打开「证据路径」所列 Markdown。  
2. 对照 **V2-D1～D4** 行，确认均存在 **路径 + 步骤或快照文字 + 判定** 三要素。  
3. 期望：可第三方扫读完成 **T-9** DoD 与 `TR-20260510-01#C-1` 收口项之对齐检查。

## §7 · 本会话可复现实测（2026-05-10 · 工具链）

> 本节为**应需补做**的客观执行记录；**不**替代 §3 所列历史归档证据，**不**等同于 V2-D1～D4 全量 UI/E2E 手跑。

### 7.1 工程构建（已通过）

- **工具**：`user-deveco-mcp` → **`build_project`**  
- **参数（run25 取证）**：`module=entry@default` 与 **`module=entry@ohosTest`**，`build_intent=LogVerification`，`clean=false`  
- **结果**：`hvigor ... assembleHap` → **`BUILD SUCCESSFUL`**（主包约 **1 min 6 s**、测试包约 **1 min 55 s** 量级，见 `document/evidence/V2/2026-05-10-T9-mcp-build-entry-default.log` 与 `…-ohosTest.log`）。  
- **告警摘录**：ArkTS WARN（如 `showToast`/`router.back` deprecated、`@Entry` export 建议等）；**签名**：工程已配置 `signingConfigs` 时产出 **`entry-default-signed.hap` / `entry-ohosTest-signed.hap`**（与 `hdc install` 一致）。

### 7.2 真机 / hdc（2026-05-10 已执行一轮）

- **命令与输出**：`document/evidence/V2/2026-05-10-T9-hdc-phase-a-b-log.txt`（`list targets` / `param` / `install` / `bm dump` 头段 / `aa start` / `hilog` 节选）。  
- **设备（run25）**：`192.168.73.160:46629`；**hdc** 使用 SDK 绝对路径（见详细计划 §2）。历史记录曾出现 `192.168.50.160:46629`，以当时 `hdc list targets` 为准。  
- **更新（2026-05-10～05-11）**：`aa test` + `OpenHarmonyTestRunner` 已在真机跑通 **9/9**（见 `2026-05-10-T9-V2D1-D4-hypium-run25-import-scroll.txt`）；扩充 **run26** **16/16**（主证据 `hypium-run26-album-b2-ph01.txt`，与 **`hypium-run28-ime-dismiss.txt`** 同步）；历史 **5/5** 见 `2026-05-10-T9-V2D1-D4-hypium-run6.txt`。**仍存缺口**：派发「全量」语义下部分项仍以 §3 主表与手跑证据为准，**不以 Hypium 套替代**。

### 7.3 单文件 ArkTS-Check（仅供参考）

- **工具**：`user-deveco-mcp` → **`check_ets_files`**（`ImportPage.ets`、`PersonPage.ets`、`SuggestPage.ets`）。  
- **现象**：单文件诊断中出现 **Error**（如导出名 `getXxxService`、局部 `arkts-no-any-unknown`），与 **7.1 工程级 assembleHap 成功**并存。  
- **判定**：**以 7.1 工程构建结论为准**；单文件检查缺完整模块闭包时可产生误报/不一致，若要以 IDE 诊断清零为目标须 **dev** 在工程上下文复核。

## §8 · 状态与真机 hdc（2026-05-10 更新）

- **统一任务列表 T-9**：**`已完成`**（质检 **quality(manager)** `2026-05-11` **通过（Q1～Q6）**；详见 `document/task/[任务经理]统一任务列表.md` §当前在跑）；下一环 **通晒（task-broadcast）**。**§阻塞单 B-1** 已解除（signed hap + `hdc install`）。**2026-05-10～05-11 补充**：Hypium **run25** `Pass 9/9`、**run26** `Pass 16/16`（见上表 §3.1）。  
- **真机会话主档**（list targets、机型、安装错误、hilog 截取）：`document/evidence/V2/2026-05-10-T9-device-hdc-session.md`。  
- **MCP 打包 + hdc + 签名结论（必读）**：`document/evidence/V2/2026-05-10-T9-deveco-mcp-hdc-signing-report.md`。  
- **签名 hap + hdc 安装/拉起（2026-05-10）**：`document/evidence/V2/2026-05-10-T9-signed-hdc-install-run.md`。  
- **hdc 原生代跑主证据（2026-05-10）**：`document/evidence/V2/2026-05-10-T9-hdc-agent-execution.md`；**详细计划**：`document/plan/V2/qa/[QA]2026-05-10-T9-V2-D1-D4-hdc原生测试执行详细计划.md`。  
- **Hypium V2Regression run6（Pass 5/5）**：`document/evidence/V2/2026-05-10-T9-V2D1-D4-hypium-run6.txt`。  
- **Hypium V2Regression run25（Pass 9/9，含导入候选提交）**：`document/evidence/V2/2026-05-10-T9-V2D1-D4-hypium-run25-import-scroll.txt`。  
- **Hypium run26（相册 mock + PH-01 + B2 矩阵，Pass 16/16）**：`document/evidence/V2/2026-05-10-T9-V2D1-D4-hypium-run26-album-b2-ph01.txt`（与 **`hypium-run28-ime-dismiss.txt`** 同步）；代跑范式 **§6.1**：`document/plan/V2/qa/[QA]2026-05-10-T9-V2-D1-D4-hdc原生测试执行详细计划.md`。  
- **设备**：历史 run25 记录为 **`192.168.73.160:46629`**；**run26** 同轮取证为 **`192.168.50.160:46629`**（若换机以当时 `hdc list targets` 为准）。
