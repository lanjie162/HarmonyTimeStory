# T-7 · B2 取消语义最小证据（应用层）

- **关联派发**：`TR-20260509-02#C-4`（计划任务 V2-T4）
- **接口层**：`entry/src/main/ets/features/api/Services.ets` → `IImportService`；实现 `entry/src/main/ets/features/import/ImportFeature.ets`（`beginLongTask` / `cancelRequest` / `isCancelled` / `endLongTask`）。
- **调用点**：`ImportPage.ets` 扫描循环内轮询 `isCancelled`；全屏扫描层「取消扫描」→ `cancelRequest(requestId)`。
- **IM-09**：取消后展示「重试」回到条件步；扫描中长任务期间主列 `opacity` 降低且遮罩层承载主要操作，体现「取消中」交互骨架。
- **hilog**：本最小集未绑定系统 B2 管道；真机 hilog 取证建议归 **T-10** 或后续专项。本文档满足 **V2-D4 最小可复现步骤** 占位。

## 最小复现

1. 同 T-6 进入导入向导并完成选图至「开始扫描」。
2. 全屏扫描出现后立刻点「取消扫描」。
3. 期望：toast「扫描已取消（cancelRequest）」；出现「重试（IM-09）」；再次从条件步可重新扫描。
