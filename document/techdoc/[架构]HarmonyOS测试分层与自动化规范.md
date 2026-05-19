# HarmonyOS 测试分层与自动化规范（时光故事 / timestore）

**状态**：已定稿（与仓库任务契约、`qa` 子代理纪律及治理专条对齐）  
**权威关联**：[`.cursor/agents/qa.md`](../../.cursor/agents/qa.md) · [`.cursor/agents/GOVERNANCE-权威基线与可验证一致性.md`](../../.cursor/agents/GOVERNANCE-权威基线与可验证一致性.md)

---

## 1. 问题定义与目标

- **目标 A**：建立 **变更类型 → 必跑门禁 → 证据层级（L1/L2）** 的可执行矩阵，减少「本地绿 / 设备红」或口头验收口径漂移。
- **目标 B**：**自动化执行**定义为：从构建到归档证据由 **脚本 +（Tier0）MCP** 协同驱动，无徒手点按；**结果追踪**依赖固定目录、日志与可选 `summary.json`（见 [`scripts/run-hypium-evidence.ps1`](../../scripts/run-hypium-evidence.ps1)：默认 **`BuildBackend=Mcp`** 时脚本生成 **`tier0-mcp-handoff.json`**，由执行者在 Cursor 中调用 **deveco-mcp** 完成 `check_ets_files` / `build_project` 后再 `-SkipBuild` 续跑 hdc/Hypium）。
- **目标 C**：需求或代码变更时，**用例增补与注册规则**可审计（锚点、分层、`List.test.ets` 聚合）。

**诚实边界**：Tier2（设备 Hypium）依赖已连接 **真机或模拟器**；自动化指「无人值守脚本链」，不是「无硬件」。无设备池时，**合并门禁**与 **发布门禁**分离（见 §8）。

---

## 2. 测试分层（Tier0 / Tier1 / Tier2）

| 层级 | 代码位置 | 典型内容 | 证据层级 | 说明 |
|------|-----------|----------|----------|------|
| **Tier0** | 全量/变更涉及的 `.ets` + `entry` 模块 | **deveco-mcp（`user-deveco-mcp`）**：`check_ets_files` + `build_project` | L1 | 见 **§2.1**；可进纯软件 CI（须具备 MCP 执行环境）；**不得**单独支撑「真机 UI 行为」类强声称。 |
| **Tier1** | [`entry/src/test`](../../entry/src/test) | Hypium、无 `@kit.TestKit` 设备 UI 的纯逻辑 / 契约断言 | L1 | **禁止**用 Tier1 结论顶替派发要求的 **L2 设备侧**（见 `qa` 子代理）。 |
| **Tier2** | [`entry/src/ohosTest`](../../entry/src/ohosTest) | UiTest / `Driver`、`coldStartMainApp`、端到端主链 | **默认 L2** | 与任务 DoD 中「Hypium / hdc / 真机」类表述同级。 |

### 2.1 Tier0 权威执行（MCP）

本仓库认定 **Tier0 通过** 须同时满足：

1. **`check_ets_files`**：对本次变更涉及的 **`.ets` 文件路径列表**执行 ArkTS-Check，**无阻塞级诊断**（按 MCP 返回语义判定）。小改动可只传改动文件；**大范围重构**须扩展为覆盖主模块与测试目录下相关 `.ets`，避免「只检了入口文件」。
2. **`build_project`**：至少完成 **`entry@default`** 与 **`entry@ohosTest`** 两次构建（或等价的一次多 target 策略，以 MCP 实际能力为准），`build_intent` 默认 **`LogVerification`**（与调试/测试包一致）；需要干净构建时在 PR 或任务中注明 **`clean: true`**。

工具参数以工作区 MCP 描述为准，调用前须从 Cursor 运行时缓存 `mcps/user-deveco-mcp/tools/*.json` 读取对应工具 schema（位于用户目录 `.cursor/projects/<project-hash>/mcps/user-deveco-mcp/tools/`，与当前 Cursor 连接的 MCP 服务实时一致）。

与 **[`code-linter.json5`](../../code-linter.json5)** 的关系：**不纳入 Tier0 门禁判定**；仍推荐在 DevEco / 本地或独立流水线中执行，作为 **ESLint 性能与安全规则** 的补充信号。若当前环境 **无法使用 deveco-mcp**，须在 PR 或任务中 **明示降级路径**（例如仅本地 `hvigor` + IDE 分析）并经 **`CR-x` 或团队书面约定**，避免静默收窄 Tier0。

**与证据脚本 [`scripts/run-hypium-evidence.ps1`](../../scripts/run-hypium-evidence.ps1) 的衔接**：脚本默认 **不直接调用 hvigor**；在未传 `-SkipBuild` 时写入证据目录下的 **`tier0-mcp-handoff.json`**、**`tier0-check-ets-git-candidates.txt`**，供按 §2.1 调用 MCP；HAP 未生成时脚本会失败退出，避免在缺 Tier0 构建时继续安装/跑测。无 MCP 时传 **`-BuildBackend Hvigor`**（经 **CR-x** 或团队约定）以本地 hvigor 构建。

**实操指引（贡献者 / QA）**：[\[QA\]Tier0-MCP与Hypium证据实操.md](./[QA]Tier0-MCP与Hypium证据实操.md)（handoff、`-SkipBuild`、证据目录核对、CI §10 对齐）。  
**DEBUG 与真实选图缺口**：[\[QA\]DEBUG与真实选图-E2E缺口.md](./[QA]DEBUG与真实选图-E2E缺口.md)。

**命令与踩坑索引**（勿凭记忆改参数）：

- 仓库实践索引：[`document/evidence/V2/2026-05-10-T9-hdc-agent-execution.md`](../evidence/V2/2026-05-10-T9-hdc-agent-execution.md)
- 执行细则：[`document/plan/V2/qa/[QA]2026-05-10-T9-V2-D1-D4-hdc原生测试执行详细计划.md`](../plan/V2/qa/[QA]2026-05-10-T9-V2-D1-D4-hdc原生测试执行详细计划.md)

---

## 3. 变更类型 → 必跑门禁（六维矩阵，含 Tier2 子分级）

在 PR 或任务中勾选；**跳过某一 Tier 须在 PR 描述或任务中引用 `CR-x` 或 DoD 明文降级**（见治理专条 §3.6）。

Tier2 按改动范围划分为 A/B/C/D 四级，详见 §4.1。

| 变更类型 | Tier0 | Tier1 | Tier2A | Tier2B | Tier2C | Tier2D |
|----------|:------:|:-----:|:------:|:------:|:------:|:------:|
| 纯资源 / 文案无行为 | 必跑 | 可选 | 可选 | 否 | 否 | 否 |
| UI 样式 / 布局 | 必跑 | 可选 | 建议 | 可选 | 可选 | 否 |
| 页面路由 / Shell / Tab | 必跑 | 可选 | **必跑** | 可选 | 可选 | 否 |
| Feature 业务规则 | 必跑 | 建议 | **必跑** | **必跑** | 可选 | 否 |
| 导入 / 扫描链路 | 必跑 | 可选 | **必跑** | 可选 | **必跑** | 可选 |
| Data / RDB / Repository | 必跑 | **必跑** | **必跑** | **必跑** | 建议 | 可选 |
| Ability / 启动 / 权限 | 必跑 | 可选 | **必跑** | 可选 | 可选 | 可选 |
| 依赖 / SDK / API 级别 | 必跑 | 建议 | **必跑** | 建议 | 可选 | 可选 |
| **发布 / 版本结项** | **必跑** | **必跑** | **必跑** | **必跑** | **必跑** | **必跑** |

---

## 4.1 Tier2 子分级（A / B / C / D）

本仓库 Tier2（设备 Hypium）按改动范围分为四级，通过 `describe` 名称前缀实现 `aa test -s class` 精确过滤。

### 分级依据（基于 23 用例 552s 实测耗时）

| 层级 | describe 前缀 | 套件 | 预计耗时 | 适用范围 |
|------|---------------|------|----------|----------|
| **Tier2A** | `Tier2A_` | `EntryAbilitySmoke` + `Shell` | ~12s | 路由/Shell/Tab 变更必跑 |
| **Tier2B** | `Tier2B_` | `Person` + `Story`（纯 CRUD，不含扫描） | ~134s | 核心域业务规则变更必跑 |
| **Tier2C** | `Tier2C_` | `SuggestImport` + `B2`（含 DEBUG 扫描慢流程） | ~325s | 导入/扫描链路变更必跑 |
| **Tier2D** | `Tier2D_` | `ImportFull`（边界补充） | ~80s | 补充覆盖/发布门禁 |

### 执行命令

```bash
# Tier2A 快速回归
hdc shell aa test -b com.lanjie162.timestore -m entry_test `
  -s timeout 300000 -s class Tier2A_EntryAbilitySmoke `
  -s class Tier2A_V2RegressionShell -s unittest OpenHarmonyTestRunner

# Tier2A+Tier2B 核心回归（~2.5min）
hdc shell aa test ... -s class Tier2A_EntryAbilitySmoke `
  -s class Tier2A_V2RegressionShell -s class Tier2B_V2RegressionPerson `
  -s class Tier2B_V2RegressionStory -s unittest OpenHarmonyTestRunner

# 全量（发布门禁，默认，~9min）
hdc shell aa test ... -s unittest OpenHarmonyTestRunner
```

### 与 §3 矩阵的对应关系

| 变更范围 | 必跑层级 | 期望耗时 |
|----------|---------|----------|
| 路由/Shell/Tab 改动 | Tier2A | ~12s |
| 业务规则/CRUD 改动 | Tier2A + Tier2B | ~2.5min |
| 导入/扫描链路改动 | Tier2A + Tier2C | ~6min |
| 发布/版本结项 | Tier2A + Tier2B + Tier2C + Tier2D | ~9min |

### 脚本支持

`scripts/run-hypium-evidence.ps1` 新增 `-Tier2Subset` 参数（`All` / `A` / `AB` / `ABC` / `AC` / `AD`）自动拼接 `-s class` 过滤。

- **域拆分**：按业务域维护多个 `*.test.ets`（人物 / 故事 / 建议与导入 / B2 等），共享逻辑集中在 [`entry/src/ohosTest/ets/test/V2RegressionTestKit.ets`](../../entry/src/ohosTest/ets/test/V2RegressionTestKit.ets)。
- **唯一聚合入口**：[`entry/src/ohosTest/ets/test/List.test.ets`](../../entry/src/ohosTest/ets/test/List.test.ets) 必须 `import` 并调用各域套件的 `default` 函数；**禁止**存在未通过 `List.test.ets` 注册的用例文件。
- **命名**：`it` 第一参为稳定用例名（如 `V2_D3_import_scan_confirm_commit`），便于过滤与证据索引。Hypium 报告中的 `class=` 为 **describe 套件名**（拆分后为 `V2RegressionPerson` / `V2RegressionStory` / `V2RegressionSuggestImport` / `V2RegressionB2` 等）；历史日志中的 `V2Regression` 为拆分前套件名，证据仍有效。

---

## 5. 证据合同（L2 追踪）

每次回归或任务验收，建议产出以下 **可复核** 材料（路径可自定义，但须写入任务/PR）：

1. **提交点**：`git rev-parse HEAD`（或等价 CI 变量）。
2. **构建产物**：`entry-default-signed.hap`、`entry-ohosTest-signed.hap` 路径与生成时间。
3. **设备摘要**：`hdc list targets`（按团队约定脱敏）。
4. **执行日志**：完整 `aa test` 输出，含 `user test started` 与结尾 `Tests run: …, Pass: …`。
5. **可选**：同目录 `summary.json`（由 [`scripts/run-hypium-evidence.ps1`](../../scripts/run-hypium-evidence.ps1) 解析生成）。
6. **Tier0（Mcp 模式）**：同目录 **`tier0-mcp-handoff.json`**（及 **`tier0-check-ets-git-candidates.txt`**），证明已按 handoff 调用 MCP 或可与 `summary.json` 中字段 `tier0BuildBackend` / `skipBuild` 交叉核对。

**任务锚点**：证据正文引用派发材料中的 **`TR-…#C-n`**；**禁止**将全局任务编号 `T-<数字>` 写入证据作为唯一锚点（与 `manager` / `sa` 契约一致）。

---

## 6. 附录 A：`aa test` 正确与错误写法

**Bundle / 模块**（以本仓库为准，若变更请同步改脚本与下表）：

- `bundleName`：`com.lanjie162.timestore`（见 [`AppScope/app.json5`](../../AppScope/app.json5)）
- 测试模块名：`entry_test`（见 [`entry/src/ohosTest/module.json5`](../../entry/src/ohosTest/module.json5)）

**正确**（Runner 为类名，非 describe 名）：

```text
hdc shell aa test -b com.lanjie162.timestore -m entry_test -s timeout 180000 -s unittest OpenHarmonyTestRunner
```

**错误**（将导致进程异常或 App died，仓库已踩坑）：

```text
hdc shell aa test … -s unittest ActsAbilityTest
```

`ActsAbilityTest` 为 Hypium **describe 套件显示名**，**不是** `-s unittest` 的合法取值。

**护栏**：

- **禁止**在同包测试过程中对宿主 `bundle` 执行 `aa force-stop`，会终止测试进程（见证据索引中的「实现侧要点」）。
- **release 签名**应用不支持 `aa test`，仅 **debug 签** 可跑 instrumentation。

---

## 7. 附录 B：PR 合并前检查清单（自评）

- [ ] **Tier0**：已执行 MCP **`check_ets_files`**（覆盖本次相关 `.ets`）+ **`build_project`**（`entry@default` 与 `entry@ohosTest`）；或已写明 **无 MCP 降级** 与依据。
- [ ] 已按 §3 矩阵勾选本次变更对应的 Tier0 / Tier1 / Tier2。
- [ ] 若未跑 Tier2：已写 **`CR-x` 或 DoD 降级`** 链接/摘要。
- [ ] 新增或修改 **Tier2** 用例：已在用例旁注释 **需求章节或 TR 锚点**；已注册进 `List.test.ets`。
- [ ] 涉及 DEBUG 测试入口：已评估 **真实用户路径缺口**（见 §9）。

---

## 8. 合并门禁 vs 发布门禁

| 门禁 | 最低要求 | 适用 |
|------|------------|------|
| **合并** | Tier0 通过（§2.1：**MCP `check_ets_files` + `build_project`**）；Tier1 若有则通过；**Tier2A** 按变更类型矩阵（§3）选跑 | 日常 PR |
| **发布 / 版本结项** | Tier0 + Tier2 全层级（A/B/C/D）及任务 DoD 要求的 L2 证据 | 里程碑、派发 DoD 含 L2 时 |

无设备池时，允许 PR 在 **仅 Tier0** 合并，但 **不得**宣称已满足需 L2 的结项 DoD。

---

## 9. 技术护栏（DEBUG 与测试形态）

- 主代码中 **Hypium / E2E 专用控件**（如「跳过选图」类 DEBUG 按钮）须在需求或测试设计中标明 **与真实选图路径的差异**。
- **长期目标**：以 **编译期开关 / Flavor** 收敛 DEBUG 入口，避免 release 渠道包暴露可触达测试后门。
- **当前**：以 BuildProfile / DEBUG 条件编译为最低要求（与实现代码同步演进）。

---

## 10. 与 CI 的衔接（预留）

本仓库 **根目录未强制** GitHub Actions；若后续引入 CI：

- **快路径**：仅 Tier0，且与 §2.1 对齐——在 Runner 上调用 **deveco-mcp 等价能力**（`check_ets_files` + `build_project`），或对接到同一套 ArkTS-Check / hvigor 的 **经 `CR-x` 备案的自动化封装**；`code-linter.json5` 可作为并行 job，**不替代** Tier0 判定。
- **慢路径 / 夜间**：连接设备池或官方模拟器镜像后执行 `scripts/run-hypium-evidence.ps1`，上传日志与 `summary.json` 为 artifact。

---

## 11. 文档修订

修订本规范须走 **`CR-x`** 或版本计划变更，并在 PR 中说明对矩阵或证据合同的影响。
