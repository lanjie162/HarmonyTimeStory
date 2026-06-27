# T-50 视觉 Token 扫尾 — 实现计划

## 需求总结

将 V2.5 四个页面 + PhotoSwiper 组件中的裸色 `#RRGGBB` 替换为 `$r('app.color.ts_*')` Token，实现全仓零裸色。

## 扫描结果

已使用 Token 的文件（无需修改）：
- `ShellPage.ets` ✅、`PersonPage.ets` ✅、`StoryPage.ets` ✅
- `PrivacyPage.ets` ✅、`ImportPage.ets` ✅、`SuggestPage.ets` ✅
- `PhotoGridItem.ets` ✅、`KeyboardAwareInput.ets` ✅

**存在裸色的 V2.5 文件**（需要修改）：

| 文件 | 裸色出现次数 |
|------|------------|
| `PersonDetailPage.ets` | 32 |
| `PersonDetailEditPage.ets` | 63 |
| `StoryDetailPage.ets` | 28 |
| `StoryDetailEditPage.ets` | ~90 |
| `PhotoSwiper.ets` | 13 |

## 设计决策（已确认）

| 决策项 | 结论 |
|--------|------|
| `#67C31F`（绿色） | → `$r('app.color.ts_brand_primary')`（琥珀色 `#B85C38`），品牌色统一 |
| 深色卡片背景 `#222/#333/#444` | 用已有 Token 近似替换 |
| `#000000` 全屏黑 | PhotoSwiper 使用 `Color.Black`（系统常量，非裸色） |
| `#FFFF00` DEBUG | 使用 `$r('app.color.ts_debug_banner')` |

## 色值映射表

| 当前裸色 | 替换 Token | dark 近似值 | 用途 |
|----------|-----------|-------------|------|
| `#111111` | `$r('app.color.ts_surface')` | #1C1B1F | 页面背景 |
| `#222222` | `$r('app.color.ts_surface_container')` | #2D2B32 | 卡片背景 |
| `#333333` | `$r('app.color.ts_surface_container_high')` | #35333A | 顶栏背景 |
| `#444444` | `$r('app.color.ts_surface_container_high')` | #35333A | 次要按钮/边框 |
| `#555555` | `$r('app.color.ts_text_muted')` | #888888 | 空态图标 |
| `#666666` | `$r('app.color.ts_text_tertiary')` | #A0A0A0 | 说明文字 |
| `#888888` | `$r('app.color.ts_text_muted')` | #888888 | 元数据 |
| `#AAAAAA` | `$r('app.color.ts_text_tertiary')` | #A0A0A0 | 弱辅助文字 |
| `#FFFFFF` | `$r('app.color.ts_import_bar_on_bg')` | #FFFFFF | 白字 |
| `#FF5555` | `$r('app.color.ts_color_error')` | #EF5350 | 错误/删除文字 |
| `#CC0000` | `$r('app.color.ts_color_error')` | #EF5350 | 删除按钮字色 |
| `#67C31F` | `$r('app.color.ts_brand_primary')` | #E8A882 | 按钮填充/强调 |
| `#1E88E5` | `$r('app.color.ts_color_info')` | #64B5F6 | 蓝色操作按钮 |
| `#FFFF00` | `$r('app.color.ts_debug_banner')` | #CE93D8 | DEBUG 文字 |
| `#000000` | `Color.Black` | — | PhotoSwiper 全屏背景 |
| `#1E1E1E` | `$r('app.color.ts_surface_container_high')` | #35333A | 菜单背景 |
| `#border: '#444444'` | `borderColor: 不设（用 ts_outline）` | — | 卡片边框 |

## 改动清单

### 1. `PersonDetailPage.ets` — 32 处替换

**关键改动**：
- 顶栏背景 `#333333` → `$r('app.color.ts_surface_container_high')`
- 页面背景 `#111111` → `$r('app.color.ts_surface')`
- 卡片背景 `#222222` → `$r('app.color.ts_surface_container')`
- 边框 `#444444` → `$r('app.color.ts_outline')`
- 编辑按钮 `#67C31F` → `$r('app.color.ts_brand_primary')`
- 添加照片 `#1E88E5` → `$r('app.color.ts_color_info')`
- 错误文字 `#FF5555` → `$r('app.color.ts_color_error')`
- 所有 `#FFFFFF` → `$r('app.color.ts_import_bar_on_bg')`
- 所有 `#AAAAAA` → `$r('app.color.ts_text_tertiary')`
- Circle fill `#444444` → `$r('app.color.ts_surface_container_high')`

### 2. `PersonDetailEditPage.ets` — 63 处替换

同 PersonDetailPage 映射规则。另有：
- AlertDialog button `#CC0000` → `$r('app.color.ts_color_error')`
- 保存按钮 `#67C31F` → `$r('app.color.ts_brand_primary')`
- 删除卡片底 `#CC0000` → `$r('app.color.ts_color_error')`
- 类型按钮：选中 `#67C31F` → `$r('app.color.ts_brand_primary')`，未选 `#444444` → `$r('app.color.ts_surface_container_high')`
- 性别按钮同上
- `#FFFF00` DEBUG → `$r('app.color.ts_debug_banner')`

### 3. `StoryDetailPage.ets` — 28 处替换

同 PersonDetailPage 映射规则。

### 4. `StoryDetailEditPage.ets` — ~90 处替换

同 PersonDetailEditPage 映射规则。

### 5. `PhotoSwiper.ets` — 13 处替换

- `#000000` → `Color.Black`
- `#FFFFFF` → `$r('app.color.ts_import_bar_on_bg')`
- `#AAAAAA` → `$r('app.color.ts_text_tertiary')`
- `#222222` → `$r('app.color.ts_surface_container')`
- `#FF5555` → `$r('app.color.ts_color_error')`
- `#CC0000` → `$r('app.color.ts_color_error')`
- `#1E1E1E` → `$r('app.color.ts_surface_container_high')`
- `#333333` → `$r('app.color.ts_surface_container_high')`
- `#40000000` → 保持（是透明度遮罩，非纯色）

## 无需改动项

| 项 | 原因 |
|----|------|
| `PromptAction.showToast` 调用 | 编程方式调用，不涉及颜色属性 |
| `AlertDialog` 的 `fontColor` | AlertDialog 颜色不属于 ImageFill/Text 颜色属性 |
| Gradient colors `['#66000000', '#00000000']` | 渐变层颜色，非 ImageFill/Text 直接取值 |
| `colorConsistentWarning` 类警告 | 这是 IDE 层面的提示，非裸色问题 |

## 验证步骤

1. `check_ets_files` 检查 5 个修改文件
2. `build_project`（module=entry@default, intent=LogVerification）
3. `git grep "'#[0-9A-Fa-f]{6}'" entry/src/main/ets` 确认零裸色残留
4. 真机验收：3 个详情页 + 2 个编辑页 + PhotoSwiper 页面加载正常，颜色可辨