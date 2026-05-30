# T-48 & T-49 实施计划

## 结论

两个任务同一模式：将当前「阅览/编辑一体化 Scroll」拆为「阅览态页面 + 编辑态独立页面」。T-48 复杂度 XL（时间线混排 + 故事封面穿插 + 粘性月份头），T-49 复杂度 L（结构相同但更简单）。PhotoSwiper 需先改造为 @Component（方案 A 已确认）。无日历组件——交互设计未包含。

---

## 一、需求理解与边界

### T-48：PersonDetailPage 阅览/编辑态分离 + 时间线混排

**权威基线**：[交互]PersonDetailPage-时间线混排交互设计（V2.5）

| DoD 要点 | 对应交互锚点 |
|----------|-------------|
| 阅览/编辑态分离 | §页面流：阅览态 → [编辑] → 编辑态 → [保存] → 阅览态 |
| 摘要行 | §摘要行：头像 + 类型 + 生日 + 照片/故事计数 + [+ 添加照片] + [导入相册…] |
| 时间线混排 | §时间线网格：照片+故事封面按拍摄时间降序，故事封面有 badge 底标条 |
| 粘性月份头 | §月份头粘性：`YYYY 年 M 月` 格式，跨月自动替换 |
| 点击照片 → 全屏 | §全屏浏览路径 → PhotoSwiper |
| 点击故事封面 → StoryDetailPage | §故事封面 · P-08 |
| 编辑态 | §编辑态：字段面板 + CalendarPicker 弹出 + [保存]/取消 |
| 空态/错误态 | §全状态与异常处理：P-11/P-12 |

### T-49：StoryDetailPage 阅览/编辑态分离 + 事件相册

**权威基线**：[交互]StoryDetailPage-事件相册交互设计（V2.5）

| DoD 要点 | 说明 |
|----------|------|
| 阅览/编辑态分离 | 同 T-48 模式 |
| 事件相册 | 3 列照片网格，点击跳 PhotoSwiper |
| 编辑态 | 字段面板 + [保存]/取消 |

### 非目标

- 不改变数据层（Service/Repository）
- 不改变 PhotoGridItem
- 不做日历组件（交互设计无此需求）
- 故事封面 URI 失效兜底降级为灰色占位

---

## 二、技术实现方案

### 2.1 架构：一页拆两页

```
Before: 阅览+编辑在同一页
After:  阅览态入口 + 编辑态独立页

PersonDetailPage.ets ──[编辑]──→ PersonDetailEditPage.ets ──[保存/←]──→ back
StoryDetailPage.ets  ──[编辑]──→ StoryDetailEditPage.ets  ──[保存/←]──→ back
```

编辑态 `router.back()` 后阅览态 `onPageShow` 自动 `refresh()`。

### 2.2 前置依赖：PhotoSwiper 改造为 @Component（方案 A）

去掉 `@Entry`，改为普通 `@Component`，数据通过 `@Prop` 传入，父页面 `if` 控制显示。

```typescript
@Component
export struct PhotoSwiper {
  @Prop photos: PhotoRefModel[] = [];
  @Prop initialIndex: number = 0;
  @Prop removeLabel: string = '移除';
  onRemove?: (photo: PhotoRefModel) => void;
  onClose?: () => void;
}
```

父页面用法：
```typescript
@State showSwiper: boolean = false;
@State swiperIndex: number = 0;

// 点击照片
this.showSwiper = true;
this.swiperIndex = index;

// build 中
if (this.showSwiper) {
  PhotoSwiper({
    photos: this.photos,
    initialIndex: this.swiperIndex,
    removeLabel: '从人物移除',
    onRemove: (photo) => { /* 执行移除 + 刷新 */ this.showSwiper = false; },
    onClose: () => { this.showSwiper = false; }
  })
}
```

同步从 `main_pages.json` 移除 `common/ui/PhotoSwiper` 路由（不再需要）。

### 2.3 T-48 PersonDetailPage 阅览态

```
┌─────────────────────────────────────────┐
│ ← 小明                         [编辑 ⋮] │  顶栏
├─────────────────────────────────────────┤
│ ┌────┐                                  │
│ │ 头  │  宝宝 · 男 · 2024-08-15          │  摘要行
│ │ 像  │  128 张照片 · 3 个故事           │
│ └────┘  [ + 添加照片 ]  [ 导入相册… ]    │
├─────────────────────────────────────────┤
│ 2025 年 10 月                           │  粘性月份头
├─────────────────────────────────────────┤
│ ┌────┬────┬────┐                        │
│ │  P │  P │  P │                        │  3 列 Grid
│ ├────┼────┼────┤                        │
│ │  P │  S │  P │  S = 故事封面 + badge  │
│ └────┴────┴────┘                        │
│ 📖 国庆游 · 12 张  →                    │  故事底标条
├─────────────────────────────────────────┤
│ 2025 年 8 月                            │  下一个月份头
│ ...                                      │
└─────────────────────────────────────────┘
```

#### 关键实现：时间线混排

1. **数据合并**：将 `this.photos`（PhotoRefModel）和关联故事的封面项合并为一个统一列表 `TimelineItem[]`
2. **按月分组**：按 `takenAt`（照片）/ `timeStart`（故事）时间戳降序排列
3. **故事封面穿插**：故事封面通过其 `timeStart` 锚定到对应月份，在网格中占据 1 个 GridItem，附加 `📖 故事名` badge（右下角，品牌色半透明底 + 白色文字），故事封面所在行后紧跟底标条
4. **粘性月份头**：用 `List` + `ListItemGroup({ header: ... })` 实现分组粘性（ArkUI 原生支持），或用 Scroll + 手动计算 offset 做悬浮。首选 ArkUI 原生 sticky
5. **故事底标条**：`📖 {故事名} · {n} 张  →`，占整行，点击跳 StoryDetailPage

#### 关键实现：摘要行

- 头像 64vp 圆
- 类型标签 + 生日文本纯展示
- 照片/故事计数：`{n} 张照片 · {m} 个故事`
- `[+ 添加照片]` 按钮：触发 PhotoPicker，写入后刷新
- `[导入相册…]` 按钮：pushUrl → ImportPage

#### 空态 / 错误态

- 空态（零照片 + 零故事）：显示空态引导卡 `🖼️ 还没有照片` + `[+ 添加照片]`
- 错误态（人物已删除）：全页 `⚠️ 人物不存在或已被删除` + `[返回人物列表]`

### 2.4 T-48 PersonDetailEditPage 编辑态

从 PersonDetailPage 搬迁全部编辑区代码，包装为独立页：

- 顶栏：`← 编辑人物          [保存]`
- 头像操作：更换/移除
- 显示名：TextInput
- 类型：按钮组（宝宝/成人/长辈/其他）
- 生日：点击弹出 CustomDialog + CalendarPicker，不可选未来日期
- 性别：按钮组
- 备注：TextArea
- 关联故事：新建/关联/解除
- 照片管理：选图 + 3列网格
- 危险操作：红色文字 [删除人物]，触发 AlertDialog

点击 `←`：refresh() 重置 draft → router.back()
点击 [保存]：校验 → updatePerson → Toast → router.back()

### 2.5 T-49 StoryDetailPage 阅览态

```
┌─────────────────────────────────────────┐
│ ← 国庆游                       [编辑 ⋮] │
├─────────────────────────────────────────┤
│ ┌─────────────────────────────────────┐ │
│ │ 国庆游                              │ │  故事档案卡
│ │ 故事 · 2025-10-01 ~ 2025-10-07      │ │
│ │ 北京                                │ │
│ └─────────────────────────────────────┘ │
├─────────────────────────────────────────┤
│ 关联人物：小明  小红  ...                │  横向标签
├─────────────────────────────────────────┤
│ 事件相册                                │  标题
│ ┌────┬────┬────┐                        │
│ │  P │  P │  P │                        │  3 列网格
│ └────┴────┴────┘                        │
└─────────────────────────────────────────┘
```

- 故事档案卡：标题 + 时间范围 + 地点
- 关联人物标签：横向 Row 展示已关联人物名称
- 事件相册：3 列照片网格，点击跳 PhotoSwiper
- ↶ 编辑：跳 StoryDetailEditPage

### 2.6 T-49 StoryDetailEditPage 编辑态

从 StoryDetailPage 搬迁编辑区：

- 顶栏：`← 编辑故事          [保存]`
- 标题/描述/封面/地点/时间范围(CalendarPicker)/标签
- 关联人物：创建/关联/解除
- 照片管理：选图 + 网格
- 危险操作：[删除故事]

---

## 三、文件改动清单

### T-47 改造（前置依赖，先行）
| 文件 | 操作 | 说明 |
|------|------|------|
| `common/ui/PhotoSwiper.ets` | 重构 | 去 @Entry → @Component + @Prop；父页面 if 控制 |
| `main_pages.json` | 修改 | 移除 `common/ui/PhotoSwiper` 路由 |

### T-48
| 文件 | 操作 | 说明 |
|------|------|------|
| **新建** `pages/person/PersonDetailEditPage.ets` | 新建 | 编辑态独立页，从 PersonDetailPage 搬迁编辑区 |
| `pages/person/PersonDetailPage.ets` | 重构 | 删编辑区 → 纯阅览态：摘要行 + 时间线混排（粘性月份头 + Grid + 故事封面穿插 + 故事底标条）+ PhotoSwiper 接入 + 空态/错误态 |
| `main_pages.json` | 修改 | 新增 `PersonDetailEditPage` |

### T-49
| 文件 | 操作 | 说明 |
|------|------|------|
| **新建** `pages/story/StoryDetailEditPage.ets` | 新建 | 编辑态独立页，从 StoryDetailPage 搬迁编辑区 |
| `pages/story/StoryDetailPage.ets` | 重构 | 删编辑区 → 纯阅览态：档案卡 + 关联人物标签 + 事件相册 + PhotoSwiper 接入 |
| `main_pages.json` | 修改 | 新增 `StoryDetailEditPage` |

---

## 四、实施步骤

### 前置依赖
- [ ] **前置-1**：重构 PhotoSwiper.ets 为 @Component（去 @Entry、@Prop 替代 router.getParams）
- [ ] **前置-2**：从 main_pages.json 移除 `common/ui/PhotoSwiper`
- [ ] **前置-3**：静态检查 + 构建验证

### 第一波：T-48 PersonDetailPage
- [ ] **T48-1**：新建 PersonDetailEditPage.ets — 从 PersonDetailPage 搬迁全部编辑区代码，包装为独立页
- [ ] **T48-2**：重构 PersonDetailPage.ets 为纯阅览态 — 删除所有编辑区代码（~500 行），重写为：摘要行 + 时间线混排（List 粘性分组 + Grid + 故事封面穿插 + 故事底标条）+ PhotoSwiper 接入 + 空态/错误态
- [ ] **T48-3**：main_pages.json 注册 PersonDetailEditPage
- [ ] **T48-4**：静态检查 + 构建验证

### 第二波：T-49 StoryDetailPage
- [ ] **T49-1**：新建 StoryDetailEditPage.ets — 从 StoryDetailPage 搬迁全部编辑区代码
- [ ] **T49-2**：重构 StoryDetailPage.ets 为纯阅览态 — 删除编辑区，重写为：档案卡 + 关联人物标签 + 事件相册 + PhotoSwiper 接入
- [ ] **T49-3**：main_pages.json 注册 StoryDetailEditPage
- [ ] **T49-4**：静态检查 + 构建验证

---

## 五、验证策略

| 场景 | T-48 | T-49 | 方法 |
|------|------|------|------|
| 阅览态正常渲染 | ✓ | ✓ | start_app + 截图 |
| ↶ 跳编辑态 | ✓ | ✓ | 点 [编辑] → 确认页面跳转 |
| 编辑态保存后返回刷新 | ✓ | ✓ | 改字段 → 保存 → 回阅览态确认 |
| 时间线混排（照片+故事封面） | ✓ | — | 确认多个月份分组、故事封面有 badge |
| 粘性月份头 | ✓ | — | 滚动确认月份头替换 |
| 故事底标条跳转 | ✓ | — | 点击底标 → StoryDetailPage |
| 空态引导 | ✓ | — | 零照片零故事时展示 |
| 点击照片 → PhotoSwiper | ✓ | ✓ | 点击 → 全屏 → 滑动 → 关闭 |
| PhotoSwiper 移除后刷新 | ✓ | ✓ | 移除 → 关闭 → 页码确认减少 |
| 事件相册 | — | ✓ | 3 列照片网格 |

---

## 六、风险

| 风险 | 等级 | 缓解 |
|------|------|------|
| PersonDetailPage ~795 行重构，删改量大 | 中 | 先建编辑态文件搬迁，再删阅览态中对应代码，确保不丢代码 |
| List sticky 分组在 ArkUI 中行为需验证 | 中 | 先查阅 harmonyos_knowledge_search 确认 API；若不可用，回退手动 Scroll + offset 计算悬浮 |
| 故事封面穿插逻辑需新数据结构 | 低 | 定义 `TimelineItem` 接口（照片/封面统一），在 `refresh()` 中构建 |
| 故事封面 URI 失效 | 低 | 使用 Image.onError 兜底，显示灰色占位 + 书名文字 |
| T-44 Tabs 导航兼容性 | 低 | 两个编辑态都是 pushUrl，不影响 Tabs 栈 |