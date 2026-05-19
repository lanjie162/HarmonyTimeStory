# T-10 · C9（R-05）· UI 自动化 ≡ API12 真机（归档索引）

**日期**：2026-05-11  
**关联任务**：`document/task/[任务经理]统一任务列表.md` · §当前在跑 · **T-10**（派发 `TR-20260509-02#C-7`）  
**采纳口径（用户显式）**：**同一套 UI 自动化（Hypium + hdc `aa test`）在已连接 API12 真机上执行，视同满足「API12 真机验证」**，不以额外徒手点击替代自动化结论。

## §1 · V2-D5 最小证据映射（对齐模板主档）

模板：`document/plan/V2/qa/[QA]2026-05-09-V2关键验收证据最小模板.md`

| 模板字段 | 本任务归档 |
|----------|------------|
| **复现步骤** | `document/plan/V2/qa/[QA]2026-05-10-T9-V2-D1-D4-hdc原生测试执行详细计划.md` **§6.1**（`aa test` / `OpenHarmonyTestRunner` / timeout）；被测源码 `entry/src/ohosTest/ets/test/V2DRegression.test.ets` |
| **运行日志（等价输出）** | **主档**：`document/evidence/V2/2026-05-10-T9-V2D1-D4-hypium-run26-album-b2-ph01.txt`（**Tests run: 16, Pass: 16**）；同期副本 `hypium-run28-ime-dismiss.txt` |
| **结果记录** | **通过**（自动化全绿）。**R-05/C9 相关用例**：`V2_D3_import_conditions_scan_cancel_im09`（取消扫描 + IM-09）、`V2_D4_b2_cancel_invalid_request_debug`、`V2_D4_b2_rescan_after_confirm_then_cancel_im09`、`V2_D4_b2_cancelling_banner_after_dialog` |
| **归档路径** | 本目录 `README.md` + 上列 `.txt` / `.md` 相对路径 |

## §2 · 机型 / 构建 / API 级别（与 hap 同链路）

| 项 | 证据 |
|----|------|
| 设备枚举 / 机型 | `document/evidence/V2/2026-05-10-T9-device-hdc-session.md` §2～§3（**HOP-AL10** 等） |
| 包级 API / debug | `document/evidence/V2/2026-05-10-T9-signed-hdc-install-run.md` §5（**apiTargetVersion** / **apiCompatibleVersion**） |
| 说明 | **run26** 与上述会话为**同一工程构建与测试包体系**下的 Hypium 执行记录；若换机以当时 `hdc list targets` 为准 |

## §3 · DoD-3（B2 与同版结合）

- **同轮次**：**run26** 单套执行同时覆盖 **B2 应用层矩阵（V2_D4_b2_*）** 与 **导入链取消/IM-09**，**未拆版**绕过 **P-3**。  
- **残余口径**：不额外声称 **OS 媒体栈内部 hilog** 已逐条核对；在本归档采纳的「UI 自动化 ≡ 真机」原则下，**以应用可观测行为 + Hypium 全绿**作为 **C9** 闭合依据。

## §4 · TODO C9 回写建议

`document/TODO-跟踪.md` **C9**（R-05 API12 取消语义）：建议在产品/流程侧将 **本 README + run26 主档** 视为 **R-05 真机确认** 的可追溯闭环；是否勾选 **[x]** 由 **pm / 用户**定稿（本文件不代替勾选）。
