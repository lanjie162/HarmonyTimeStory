# V2 · T-12～T-16 · 导入与形态三收口 · 最小证据（批量）

**日期**：2026-05-10  
**范围**：`TR-20260509-03#C-1`～`#C-5` 对应 `T-12`～`T-16`（dev 交付 + qa/ued/pm 会签口径见统一任务列表）。

## 构建与静态检查

- **ReadLints**（Cursor）：`ImportPage.ets`、`SuggestPage.ets`、`PersonPage.ets` 等本轮改动文件 **无 linter 报错**。  
- **assembleHap**：本环境 **未提供可脚本化 hvigor CLI**（无 `hvigorw` / PATH 未注册 DevEco hvigor）；请在 DevEco 对 **`entry@default`** 执行 **Assemble Hap / LogVerification** 作为编译期证据补全（与 T-6/T-7 证据口径一致）。

## 复现步骤（主路径）

### T-12 · 形态三入口 #6

1. 从主壳进入 **人物 Tab**（`PersonPage`）。  
2. 顶栏右侧点击 **「建议」** → 进入 `SuggestPage`。  
3. 打开 **故事详情**（`StoryDetailPage`）→ 确认 **无**「进入建议页壳页」按钮；人物详情（`PersonDetailPage`）同样 **无** 建议入口。

### T-13 · 形态三 #7 最小页

1. 在 `SuggestPage` 阅读顶栏 **§4.6 说明** 文案块。  
2. 在列表中对 **「候选示例」** 分别点 **接受 / 忽略** → 应出现 toast 与行内状态文案。

### T-14 · 条件页 #3

1. 人物或故事详情 → **进入导入向导** → 选图 → 准备 → **条件**。  
2. 依次可见 **时间 / 地点 / 人脸** 三块 Toggle；勾选 **人脸** 后出现 **蓝色说明占位**（IM-04～07 / IM-10 降级说明）。

### T-15 · 扫描取消 #4（IM-09）

1. 条件步点 **开始扫描** → 全屏遮罩出现。  
2. 点 **取消扫描** → 弹出 **二次确认对话框**；选 **确定取消** → 文案出现 **「正在取消…」** 语义（遮罩内提示）。  
3. 回到 **条件** 步后，**时间/地点/人脸及 HEIC/去重** 开关状态应保持（未因取消被静默重置）。

### T-16 · 候选 #5（IM-08 + ST-07）

1. 扫描完成后进入 **候选确认**：网格行左侧 **开关（等同勾选占位）**、**全选 / 全不选 / 反选**、主按钮 **「确认导入」**。  
2. **全不选** 后点 **确认导入** → toast「请至少勾选一项候选」。  
3. 勾选 ≤9 项后 **确认导入** → toast 汇总成功数；`router.back()` 后详情 **onPageShow** 刷新网格（沿用 T-6 行为）。

## 代码锚点

- `entry/src/main/ets/pages/person/PersonPage.ets` — 顶栏「建议」入口（T-12）  
- `entry/src/main/ets/pages/person/PersonDetailPage.ets` / `story/StoryDetailPage.ets` — 移除故事/人物详情建议入口（T-12）  
- `entry/src/main/ets/pages/suggest/SuggestPage.ets` — §4.6 说明 + 单条接受/忽略（T-13）  
- `entry/src/main/ets/pages/import/ImportPage.ets` — 条件三块、IM-09 对话框取消、候选网格与「确认导入」、ST-07 勾选上限 toast（T-14～T-16）
