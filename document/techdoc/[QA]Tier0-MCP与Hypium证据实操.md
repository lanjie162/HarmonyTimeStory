# Tier0（MCP）与 Hypium L2 证据实操

**状态**：与 [\[架构\]HarmonyOS测试分层与自动化规范.md](./[架构]HarmonyOS测试分层与自动化规范.md) §2.1、§5、§7、§8、§10 对齐。  
**角色**：`qa` / 贡献者提测前自检。

---

## 1. 合并门禁 Tier0（默认：MCP）

规范认定 **Tier0 通过** = **`check_ets_files`**（本次变更相关 `.ets`）+ **`build_project`**（**`entry@default`** 与 **`entry@ohosTest`**，`build_intent` 默认 **`LogVerification`**）。

1. 调用 MCP 前从 Cursor 运行时缓存读取工具描述符（位于用户目录 `.cursor/projects/<project-hash>/mcps/user-deveco-mcp/tools/`，与当前 MCP 服务实时一致）：  
   - `check_ets_files.json`（ArkTS 静态检查）  
   - `build_project.json`（hvigor 构建）  
   - 更多工具参见 `harmonyos_knowledge_search.json`、`start_app.json` 等。
2. 在 Cursor 中对 **user-deveco-mcp** 依次执行：  
   - `check_ets_files`，`files` 为本次改动 `.ets`（大范围重构须扩展列表，勿只检入口文件）。  
   - `build_project`：`module` = `entry@default`，`build_intent` = `LogVerification`，`clean` 按 PR 说明。  
   - `build_project`：`module` = `entry@ohosTest`，其余同上。  
3. **`code-linter.json5`** 不替代 Tier0；可在 DevEco / 独立命令中并行执行，作为补充信号。

---

## 2. Hypium 证据脚本与 Tier0 衔接

脚本：[scripts/run-hypium-evidence.ps1](../../scripts/run-hypium-evidence.ps1)。

| 场景 | 操作 |
|------|------|
| **默认** `-BuildBackend Mcp` | 在证据目录生成 **`tier0-mcp-handoff.json`**、**`tier0-check-ets-git-candidates.txt`**。若无现成双 HAP，脚本**失败退出**，避免未做 Tier0 构建即安装/跑测。在 Cursor 按 handoff 完成 MCP 后，对**同一** `-OutDir` 执行 **`-SkipBuild`** 续跑。 |
| **已有 HAP** | 若本地已按 §1 完成 MCP 构建，可直接 **`-SkipBuild`**（或默认模式下 handoff 后目录内已有产物再 `-SkipBuild`）。 |
| **无 MCP 环境** | 使用 **`-BuildBackend Hvigor`**，且 PR/任务中写明 **`CR-x` 或团队约定** 的降级依据。 |

Handoff 中 `afterTier0RerunScript` 示例：`.\scripts\run-hypium-evidence.ps1 -SkipBuild`

---

## 3. L2 证据目录验收核对（QA）

归档或任务验收时，在同一证据目录下确认：

| 文件 / 字段 | 核对要点 |
|-------------|----------|
| `tier0-mcp-handoff.json` | 存在；`suggestedSteps` 与本轮 Tier0 一致。 |
| `tier0-check-ets-git-candidates.txt` | 与变更范围合理（非空或脚本回退的默认路径时须说明）。 |
| `summary.json` | **`tier0BuildBackend`**（`Mcp` / `Hvigor`）、**`skipBuild`** 与 PR 自述一致；与 handoff 执行轨迹可交叉核对。 |
| `git-commit.txt`、`hdc-list-targets.txt`、`aa-test.log` | 符合规范 §5 其余条。 |

---

## 4. CI 快路径与 §10（预留）

- **快路径 Tier0**：须具备 **deveco-mcp 等价能力**，或 **经 `CR-x` 备案** 的 hvigor/ArkTS-Check 自动化封装；**不得**用仅 `code-linter.json5` 替代 §2.1 Tier0。  
- **`code-linter.json5`**：可作为**并行** Job，与 Tier0 并列。  
- **慢路径 / 夜间**：设备池就绪后跑 `run-hypium-evidence.ps1`，上传日志与 `summary.json`。  
- 标准 GitHub 托管 Runner 若无 HarmonyOS SDK / MCP，**不得**宣称已满足仓库 Tier0；需自建 Runner 或团队 CI。

详见规范 [§10](./[架构]HarmonyOS测试分层与自动化规范.md#10-与-ci-的衔接预留)。
