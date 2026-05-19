# T-20 · V2.1-T4 导入主链 + B2 同构建回归 · L2 证据（2026-05-20）

**执行方**：qa（task-drive / task-execute）  
**关联**：TR-20260514-01#C-4 · 统一任务列表 T-20  
**权威**：V2.1 专档 **V2.1-D4**；需求 §8.4

---

## 环境与同构建标识

| 项 | 值 |
|----|-----|
| 设备 | `192.168.50.160:46629`（见 `2026-05-20-T20-device-info.txt`） |
| 机型 / 系统 | HOP-AL10 · 6.1.0.120(SP16C00E120R4P4) |
| 主包 | `entry/build/default/outputs/default/entry-default-signed.hap`（MCP `build_project` entry@default **BUILD SUCCESSFUL** @ 2026-05-20） |
| 测试包 | `entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap`（MCP `build_project` entry@ohosTest **BUILD SUCCESSFUL** @ 2026-05-20） |
| 安装 | `hdc install -r` 主包 + 测试包均 **install bundle successfully.**（`2026-05-20-T20-install-main.txt` / `…-install-ohosTest.txt`） |

**持久化共回归说明**：本轮与 **T-19** 共用同一 `entry@default` / `entry@ohosTest` 构建会话；导入/B2 用例经 UI 创建人物并 `确认导入`，数据经 `IAppDataStore` → `RepositoryImpl` → RDB（与 C-1 真相源一致）。T-19 冷启链见 `2026-05-20-T19-cold-start-persistence.md`。

---

## 导入主链（Tier2D_V2RegressionImportFull）

**命令**：

```text
hdc shell aa test -b com.lanjie162.timestore -m entry_test -s timeout 180000 \
  -s unittest OpenHarmonyTestRunner -s class Tier2D_V2RegressionImportFull
```

**结果**（`2026-05-20-T20-aa-test-import-full.txt`）：

```text
OHOS_REPORT_RESULT: stream=Tests run: 3, Failure: 0, Error: 1, Pass: 2, Ignore: 0
```

| 用例 | 判定 | 说明 |
|------|------|------|
| `V2_D3_import_prepare_step_and_back` | **Pass** | 向导准备步 → DEBUG 进条件步 →「上一步」可见 |
| `V2_D3_import_confirm_select_all_none_invert` | **Pass** | 扫描 → 候选步全选/全不选/反选 → **确认导入** |
| `V2_D3_import_empty_owner_id_warning` | **Error** | 期望空列表文案「还没有人物档案」；设备库已有历史人物数据，**非主链阻塞**（用例与「非空库」环境不匹配） |

**主链结论**：关键路径（进向导 → 条件 → 扫描 → 候选 → 确认导入）**已覆盖且通过**。

---

## B2 取消链路（Tier2C_V2RegressionB2）

**命令**：

```text
hdc shell aa test -b com.lanjie162.timestore -m entry_test -s timeout 180000 \
  -s unittest OpenHarmonyTestRunner -s class Tier2C_V2RegressionB2
```

**结果**（`2026-05-20-T20-aa-test-b2.txt`）：

```text
OHOS_REPORT_RESULT: stream=Tests run: 3, Failure: 0, Error: 0, Pass: 3, Ignore: 0
OHOS_REPORT_CODE: 0
```

| 用例 | 语义 |
|------|------|
| `V2_D4_b2_cancel_invalid_request` | 错误 requestId 负例 + 真取消 + 重试入口 |
| `V2_D4_b2_rescan_after_confirm_then_cancel` | 候选回条件重扫再取消 |
| `V2_D4_b2_cancelling_banner` | 取消中横幅 + 重试 |

**B2 结论**：**3/3 通过**。

---

## V2.1-D4 总判定（执行侧）

| 桶 | 判定 |
|----|------|
| 导入主链 | **通过**（主路径 2/2 关键用例；1 边界用例记缺陷/补测） |
| B2 同构建 | **通过**（3/3） |
| 持久化共回归 | **通过**（同构建 + UI 写路径；冷启链见 T-19） |
| **综合** | **有条件通过**：待补 `V2_D3_import_empty_owner_id_warning`（空库或隔离数据策略） |

---

## 归档索引

| 文件 | 内容 |
|------|------|
| `2026-05-20-T20-import-b2-regression.md` | 本文件 |
| `2026-05-20-T20-aa-test-import-full.txt` | 导入套 raw |
| `2026-05-20-T20-aa-test-b2.txt` | B2 套 raw |
| `2026-05-20-T20-device-info.txt` | 设备信息 |
| `2026-05-20-T20-install-main.txt` / `…-install-ohosTest.txt` | 安装日志 |
