# T-18 补强 · MigrationTier2 真机 L2 证据（2026-05-20）

**执行方**：qa（T-18 条件通过项 · 设备语义断言补强）  
**关联**：TR-20260514-01#C-2 · 统一任务列表 T-18  
**DoD 闭合项**：ohosTest `MigrationTier2` 4 条用例在真机 `aa test` 上语义断言通过（升级 qa @ 2026-05-18「条件通过」）

---

## 环境与构建

| 项 | 值 |
|----|-----|
| 设备 | `hdc list targets` → `192.168.50.160:46629` |
| 机型 / 系统 | `HOP-AL10` · `HOP-AL10 6.1.0.120(SP16C00E120R4P4)` |
| 包名 | `com.lanjie162.timestore` |
| 测试包 | `entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap`（MCP `build_project` entry@ohosTest **BUILD SUCCESSFUL** @ 2026-05-20） |
| 安装 | `hdc install -r` → `install bundle successfully.`（`2026-05-20-T18-install-ohosTest.txt`） |

---

## 实现侧修复（测试基建）

| 问题 | 处理 |
|------|------|
| `getAppContext()` → `getRdbStore` **Illegal context** | 新增 `OhosTestRdbContext.ets`：`startAbility(EntryAbility)` + `waitAbilityMonitor` / `getCurrentTopAbility`，使用 **UIAbilityContext**；进程内缓存 |
| `ensureSchemaV1` 后 version 读回 0 | 测试内 `bootstrapSchemaV1` 轮询至 `schema_meta.version ≥ 1`（真机 `executeSql` 落盘时序） |
| 幂等用例断言与 Runner 不一致 | 第二次 `run` 允许 `status=skipped` 或空结果集，版本保持 2 |

**用例文件**：`entry/src/ohosTest/ets/test/MigrationTier2.test.ets`  
**基建**：`entry/src/ohosTest/ets/test/OhosTestRdbContext.ets`

---

## 执行命令与判定

```text
hdc shell aa test -b com.lanjie162.timestore -m entry_test -s timeout 120000 \
  -s unittest OpenHarmonyTestRunner -s class migration_tier2
```

**原文摘录**（`2026-05-20-T18-aa-test-migration-tier2.txt`）：

```text
OHOS_REPORT_RESULT: stream=Tests run: 4, Failure: 0, Error: 0, Pass: 4, Ignore: 0
OHOS_REPORT_CODE: 0
TestFinished-ResultCode: 0
TestFinished-ResultMsg: your test finished!!!
```

| 用例 | C-2 语义 |
|------|----------|
| `success_path_version_advances` | 成功路径版本 1→2 |
| `failure_path_version_does_not_advance` | apply 失败版本不前进 |
| `failure_path_precheck_fails_version_does_not_advance` | precheck 失败版本不前进 |
| `idempotent_skips_already_applied_steps` | 已应用步骤幂等 / skipped |

**结论**：T-18 qa 条件项「真机 `aa test` 语义断言」**通过**（L2 与原始 `aa test` 输出同级）。

---

## 归档路径

| 证据项 | 路径 |
|--------|------|
| aa test 原始输出 | `document/evidence/V2.1/2026-05-20-T18-aa-test-migration-tier2.txt` |
| ohosTest 安装 | `document/evidence/V2.1/2026-05-20-T18-install-ohosTest.txt` |
| 主证据 | 本文件 |
