# T-9 · hdc 原生代跑 · 执行主证据（2026-05-10）

**执行方**：qa（Agent 终端编排 + 文档调研）  
**关联计划**：[document/plan/V2/qa/[QA]2026-05-10-T9-V2-D1-D4-hdc原生测试执行详细计划.md](../../plan/V2/qa/[QA]2026-05-10-T9-V2-D1-D4-hdc原生测试执行详细计划.md)  
**模板**：[document/plan/V2/qa/[QA]2026-05-09-V2关键验收证据最小模板.md](../../plan/V2/qa/[QA]2026-05-09-V2关键验收证据最小模板.md)

---

## 复现步骤（环境 + 命令）

1. **设备**：`hdc list targets` → 本机为 `192.168.50.160:46629`。  
2. **机型 / 版本**：`param get const.product.model` → `HOP-AL10`；`param get const.product.software.version` → `HOP-AL10 6.1.0.117(SP8C00E115R4P4)`。  
3. **HAP**：主包 `entry-default-signed.hap`；测试包 `entry-ohosTest-signed.hap`（本会话前工作区无 hap，已用 DevEco MCP `build_project` 生成产物，**不替代** UI 用例通过判定）。  
4. **安装**：`hdc install <绝对路径>\entry-default-signed.hap` → `install bundle successfully.`  
5. **拉起**：`hdc shell aa start -a EntryAbility -b com.lanjie162.timestore` → `start ability successfully.`  
6. **测试包安装**：`hdc install …\entry-ohosTest-signed.hap` → 成功。  
7. **Hypium CLI（错误写法 · 首轮）**：`-s unittest ActsAbilityTest` → **错误**：`ActsAbilityTest` 为 describe 套名，**不是** `unittest` 参数取值；设备返回 **App died**。  
8. **Hypium CLI（正确写法 · 重跑 2026-05-10）**：按 [unittest-guidelines](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/unittest-guidelines) 使用 **`OpenHarmonyTestRunner`**：

```text
hdc shell aa test -b com.lanjie162.timestore -m entry_test -s timeout 30000 -s unittest OpenHarmonyTestRunner
```

完整命令与截断输出见：[2026-05-10-T9-hdc-phase-a-b-log.txt](./2026-05-10-T9-hdc-phase-a-b-log.txt)、[2026-05-10-T9-hdc-install-ohosTest.txt](./2026-05-10-T9-hdc-install-ohosTest.txt)、[2026-05-10-T9-hdc-aa-test-retry.txt](./2026-05-10-T9-hdc-aa-test-retry.txt)（错误 runner）、[2026-05-10-T9-hdc-aa-test-rerun-OpenHarmonyTestRunner.txt](./2026-05-10-T9-hdc-aa-test-rerun-OpenHarmonyTestRunner.txt)（正确 runner）。

---

## 运行日志（摘录）

**安装主包**（原文）：

```text
[Info]App install path:…\entry-default-signed.hap msg:install bundle successfully.
```

**拉起主 Ability**（原文）：

```text
start ability successfully.
```

**aa test（错误：`-s unittest ActsAbilityTest`）**：

```text
TestFinished-ResultCode: -1
TestFinished-ResultMsg: App died
user test finished.
```

**aa test（正确：`-s unittest OpenHarmonyTestRunner`）** — 见 `2026-05-10-T9-hdc-aa-test-rerun-OpenHarmonyTestRunner.txt`（仅示例套 1 条）：

```text
OHOS_REPORT_RESULT: stream=Tests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0
OHOS_REPORT_CODE: 0
TestFinished-ResultCode: 0
TestFinished-ResultMsg: your test finished!!!
user test finished.
```

**aa test · V2-D1～D4 自动化子集（2026-05-10 · run6）**：工程内 `entry/src/ohosTest/ets/test/V2DRegression.test.ets`（`describe('V2Regression')`）+ `List.test.ets` 注册；需同时安装主包与 `entry-ohosTest-signed.hap`。命令示例：

```text
hdc install …\entry-default-signed.hap
hdc install …\entry-ohosTest-signed.hap
hdc shell aa test -b com.lanjie162.timestore -m entry_test -s timeout 180000 -s unittest OpenHarmonyTestRunner
```

**run6 摘录**（完整见 [2026-05-10-T9-V2D1-D4-hypium-run6.txt](./2026-05-10-T9-V2D1-D4-hypium-run6.txt)）：

```text
OHOS_REPORT_RESULT: stream=Tests run: 5, Failure: 0, Error: 0, Pass: 5, Ignore: 0
TestFinished-ResultCode: 0
TestFinished-ResultMsg: your test finished!!!
```

**实现侧要点（可复核）**：① 同包 `ohosTest` 下 **禁止** `aa force-stop <bundle>`，否则测试进程一并退出（App died）；② `startAbility` 不清理 `router` 栈，冷启动用 **`pressBack` 直至主壳标题**；③ 人物页「新建」区原在列表下方，列表变长时 **输入区被挤出屏**，已改为 **新建区在列表上方**（`PersonPage.ets`）；④ 长列表点行用 **`List.scrollSearch` / `fling` 兜底**。

**hilog（系统侧拉起链路，节选）**：见 [2026-05-10-T9-hdc-hilog-app-sample.txt](./2026-05-10-T9-hdc-hilog-app-sample.txt)（含 `EntryAbility/com.lanjie162.timestore/entry/0` 等）。

---

## 结果记录（T-9 DoD）

| DoD 桶 | 本轮是否「用例命中 + 一轮执行」 | 说明 |
|--------|----------------------------------|------|
| V2-D1～D2（**Hypium 最小子集**） | **是** | `V2Regression`：`V2_D1_person_main_create_and_detail`、`V2_D2_story_main_create_and_detail`；**不含**关联故事、相册加图、PH-01 手测项。 |
| V2-D3～D4（**Hypium 最小子集**） | **部分** | `V2_D3_suggest_entry_minimal`（形态三入口）、`V2_D3_import_wizard_shell_from_person`（导入向导壳 + 选图入口文案）；**不含**相册选图、扫描中 IM-09 全链、**B2 cancelRequest** 与写入闭环。 |
| **Hypium 全量（示例套 + V2Regression）** | **是** | `OpenHarmonyTestRunner` 下 **Tests run: 5, Pass: 5**（见 `2026-05-10-T9-V2D1-D4-hypium-run6.txt`）。 |
| Phase A 安装/拉起/hilog 基线 | **是** | 见 `2026-05-10-T9-hdc-phase-a-b-log.txt`。 |

**总判定**：**Hypium + hdc 一轮**：示例套与 **V2Regression 四用例已跑通**（run6）。相对派发 **T-9 全文** DoD（人物/故事 **全**验收项、导入 **主链**、B2 与异常态最小集等），**仍属「子集达标、全文未收口」**——§3 历史证据与手工/最小 Markdown 证据 **仍有效**；未以自动化替代 IM-09/B2/相册闭环。

**T-10 门禁**：在 **pm 未书面收窄 T-9 门禁** 的前提下，**仍不建议**以「T-9 已通过」启动 T-10；可将 **run6** 作为 **V2-D1～D4 可回归子集** 的客观门禁输入。

---

## 归档路径

| 证据项 | 路径 |
|--------|------|
| 详细 hdc 命令计划 | `document/plan/V2/qa/[QA]2026-05-10-T9-V2-D1-D4-hdc原生测试执行详细计划.md` |
| Phase A/B 原始会话 | `document/evidence/V2/2026-05-10-T9-hdc-phase-a-b-log.txt` |
| ohosTest 安装 | `document/evidence/V2/2026-05-10-T9-hdc-install-ohosTest.txt` |
| aa test `-m entry` 重试（错误 runner） | `document/evidence/V2/2026-05-10-T9-hdc-aa-test-retry.txt` |
| aa test **OpenHarmonyTestRunner**（重跑通过） | `document/evidence/V2/2026-05-10-T9-hdc-aa-test-rerun-OpenHarmonyTestRunner.txt` |
| aa test **V2Regression + 示例套**（run6，Pass 5/5） | `document/evidence/V2/2026-05-10-T9-V2D1-D4-hypium-run6.txt` |
| hilog 样本 | `document/evidence/V2/2026-05-10-T9-hdc-hilog-app-sample.txt` |
| 本主证据 | `document/evidence/V2/2026-05-10-T9-hdc-agent-execution.md` |

---

## DoD 结论映射（T-9 / TR-20260509-02#C-6 摘要）

| DoD 编号（派发语义） | 证据路径 | 判定 | 风险 |
|----------------------|----------|------|------|
| 可执行范围 + V2-D1～D4 用例命中与执行 | 本文件 + 详细计划 §5～§6 + `2026-05-10-T9-V2-D1-D4-plan-and-execution-index.md` §3.1 | **部分满足**：**hdc + `aa test` 已映射** `V2Regression` 最小子集（run6 **Pass 5/5**）；派发「全量」项仍以 §3 主表 + 缺口说明为准 | 自动化未覆盖相册/B2/IM-09 全链；PersonPage 布局曾为测试可测性调整 |
| 阻塞/严重缺陷单列 | 本文件 §结果记录 | **无 P1 安装阻塞**；Hypium **参数错误已纠正**；**禁止**同包 `aa force-stop` 代冷启动（见上「实现侧要点」） | 扩展用例时勿复用会杀掉 `entry_test` 的 shell |
| 证据模板四字段 | 本文件 + 计划 | **已按最小字段组织** | — |
