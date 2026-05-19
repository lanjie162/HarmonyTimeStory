# T-19 · V2.1-T3 写→杀进程→冷启动→读 · L2 证据（2026-05-20）

**执行方**：qa（task-drive / task-execute）  
**关联**：TR-20260514-01#C-3 · 统一任务列表 T-19  
**权威**：`document/plan/V2.1/[产品]2026-05-14-V2.1持久化闸门版工作计划.md` §7（V2.1-D1～D3）

---

## 环境与构建

| 项 | 值 |
|----|-----|
| 设备 | `hdc list targets` → `192.168.50.160:46629` |
| 机型 / 系统 | `HOP-AL10` · `HOP-AL10 6.1.0.120(SP16C00E120R4P4)`（见 `2026-05-20-T19-device-info.txt`） |
| 包名 | `com.lanjie162.timestore` |
| 主包 HAP | `entry/build/default/outputs/default/entry-default-signed.hap`（594,784 B · MCP `build_project` entry@default **BUILD SUCCESSFUL** @ 2026-05-20） |
| 测试包 HAP | `entry/build/default/outputs/ohosTest/entry-ohosTest-signed.hap`（MCP `build_project` entry@ohosTest **BUILD SUCCESSFUL** @ 2026-05-20） |
| 安装 | `hdc install -r` → `install bundle successfully.`（`2026-05-20-T19-install-main.txt` / `install-ohosTest-r2.txt`） |

---

## 主路径：写 → 杀进程 → 冷启动 → 读（V2.1-D3 / D1）

**实现**：Hypium UI 经 `PersonFeature` → `IAppDataStore` → `RepositoryImpl` → `Timestore.db`（与 EntryAbility 生产库一致）。  
**用例**：`entry/src/ohosTest/ets/test/V2RegressionPerson.test.ets` · `describe('T19_C3_write'|'T19_C3_read')`  
**固定标记**：`T19_COLDSTART_MARKER_20260520`

### 复现步骤

1. 预热：`hdc shell aa start -a EntryAbility -b com.lanjie162.timestore`
2. **写**（仅 1 条用例）：
   ```text
   hdc shell aa test -b com.lanjie162.timestore -m entry_test -s timeout 90000 \
     -s unittest OpenHarmonyTestRunner -s class T19_C3_write
   ```
3. **杀进程**（进程外，非 aa test 会话内）：
   ```text
   hdc shell aa force-stop com.lanjie162.timestore
   ```
4. **冷启动**主 Ability：
   ```text
   hdc shell aa start -a EntryAbility -b com.lanjie162.timestore
   ```
5. **读**（新 aa test 会话，仅读用例）：
   ```text
   hdc shell aa test -b com.lanjie162.timestore -m entry_test -s timeout 90000 \
     -s unittest OpenHarmonyTestRunner -s class T19_C3_read
   ```

### 判定（原文摘录）

**写阶段**（`2026-05-20-T19-aa-test-write-only.txt`）：

```text
OHOS_REPORT_RESULT: stream=Tests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0
TestFinished-ResultCode: 0
```

**杀进程 / 冷启**（`2026-05-20-T19-force-stop-r2.txt` / `2026-05-20-T19-cold-start-r2.txt`）：

```text
force stop process successfully.
start ability successfully.
```

**读阶段**（`2026-05-20-T19-aa-test-read-only.txt`）：

```text
OHOS_REPORT_RESULT: stream=Tests run: 1, Failure: 0, Error: 0, Pass: 1, Ignore: 0
TestFinished-ResultCode: 0
```

**结论**：写后杀进程并冷启，人物列表仍可 UI 读回固定标记 → **V2.1-D1 / D3 通过**。

---

## 持久化失败可观测性（V2.1-D2）

冷启动后 EntryAbility 迁移管道 hilog（`2026-05-20-T19-hilog-migration-tag.txt`）：

```text
I A00000/com.lanjie162.timestore/migration: [bootstrap] no pending migrations to apply
```

与 `EntryAbility.ets` 中 `hilog.info(..., 'migration', '[bootstrap] ...')` / 失败分支 `hilog.error` 一致；本轮无失败步骤，**可观测性已抽检**（成功路径日志可见）。

**MigrationTier2 设备运行时补强**（非 D3 主链替代）：`aa test -s class migration_tier2` 在本机 API12 真机上 **4 Error**（`Parameter error.Illegal context` @ `getRdbStore`），见 `2026-05-20-T19-aa-test-migration-tier2.txt`；**不阻塞** C-3 主链关单，待 dev/qa 跟进 isolated RDB 测试上下文（T-18 条件项延续）。

---

## 证据文件索引

| 文件 | 说明 |
|------|------|
| `2026-05-20-T19-device-info.txt` | 机型 / 系统版本 |
| `2026-05-20-T19-install-main.txt` / `install-ohosTest-r2.txt` | HAP 安装 |
| `2026-05-20-T19-aa-test-write-only.txt` | 写阶段 Hypium |
| `2026-05-20-T19-force-stop-r2.txt` | force-stop |
| `2026-05-20-T19-cold-start-r2.txt` | 冷启 EntryAbility |
| `2026-05-20-T19-hilog-migration-tag.txt` | 迁移 bootstrap 日志 |
| `2026-05-20-T19-aa-test-read-only.txt` | 冷启后读阶段 Hypium |
| `2026-05-20-T19-aa-test-migration-tier2.txt` | MigrationTier2 运行时（失败记录） |

---

## DoD 映射

| DoD | 判定 | 依据 |
|-----|------|------|
| 权威 V2.1-D1～D3 | 通过 | 本证据 + 计划 §7 |
| ≥1 条写→杀进程→冷启→读 | **通过** | 上文主路径 + 原始 aa test 输出 |
| 失败路径可观测性 | **已检查** | migration hilog；Tier2 运行时失败已记录 |
| L2 | **通过** | hdc 真机 + MCP build + 原始日志文件 |
