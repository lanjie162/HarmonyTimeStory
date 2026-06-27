# T-43 CalendarPicker 组件封装 — 实现计划

## 需求总结

将鸿蒙原生 `CalendarPicker` 封装到弹窗中，替换 `PersonDetailEditPage` 生日选择、`StoryDetailEditPage` 起止日期共 **3 处** inline CalendarPicker。

## 当前状态

- [PersonDetailEditPage.ets](file:///c:/coding/DevEcoStudioProjects/timestore/entry/src/main/ets/pages/person/PersonDetailEditPage.ets#L464-L472)：inline `CalendarPicker`，直接嵌入编辑表单，选择即变更，无取消恢复机制
- [StoryDetailEditPage.ets](file:///c:/coding/DevEcoStudioProjects/timestore/entry/src/main/ets/pages/story/StoryDetailEditPage.ets#L386-L394 / L405-L414)：两处 inline `CalendarPicker`，行为同上

## 设计决策（已确认）

| 决策项 | 结论 |
|--------|------|
| 弹窗方案 | **使用鸿蒙内置 `CalendarPickerDialog.show()` API**（API 10+，零新增文件） |
| 未来日期 | 不禁选 |
| 结束日期校验 | onAccept 中校验失败 → 不更新值 + Toast 提示（Dialog 仍关闭，用户需重新打开选择） |
| 未设置默认值 | `2000-01-01`（与交互规格一致） |
| 取消行为 | 取消时值不变，Dialog 关闭 |

## API 调研确认

鸿蒙内置 `CalendarPickerDialog.show()` 签名（API 10+）：

```typescript
CalendarPickerDialog.show({
  selected: Date,                          // 当前值
  hintRadius: number,                      // 选中态圆角
  onAccept: (value: Date) => void,         // 确定回调
  onCancel: () => void,                    // 取消回调
  onChange: (value: Date) => void,         // 选择变更（实时）
  acceptButtonStyle?: PickerDialogButtonStyle,  // 可选定制确定按钮
  cancelButtonStyle?: PickerDialogButtonStyle,  // 可选定制取消按钮
})
```

**关键发现**：该 API 提供开箱即用的日历弹窗（确定/取消/日期选择），无需自定义 CustomDialog。局限是 onAccept 触发后 Dialog 自动关闭，不支持拦截。

## 改动清单

### 1. 修改 `PersonDetailEditPage.ets`

**替换生日字段**（L455~L472）：

```typescript
// 替换前：inline CalendarPicker + onChange
Row({ space: 8 }) { Text('生日') ... Text(this.draftBirthdayText) }
CalendarPicker({ ... }).onChange((val) => { ... })

// 替换后：可点击行 → show()
Row({ space: 8 }) {
  Text('生日')
    .fontSize(14)
    .fontColor('#AAAAAA')
  Text(this.draftBirthdayText)
    .fontSize(14)
    .fontColor('#FFFFFF')
  Text(' 📅')
    .fontSize(14)
    .fontColor('#67C31F')
}
.width('100%')
.onClick((): void => {
  CalendarPickerDialog.show({
    selected: buildDatePickerDate(this.draftBirthday),
    onAccept: (value: Date): void => {
      this.draftBirthday = value.getTime();
      this.draftBirthdayText = formatBirthday(this.draftBirthday);
    }
  })
})
```

**要点**：
- 无取消回调时，取消自动不修改值（闭包中的 `draftBirthday` 不变）
- 不新增 import（CalendarPickerDialog 无需导入，是全局 API）

### 2. 修改 `StoryDetailEditPage.ets`

**替换开始日期字段**（L377~L394）：同生日模式。

```typescript
Row({ space: 8 }) {
  Text('开始日期')
    .fontSize(14)
    .fontColor('#AAAAAA')
  Text(this.draftTimeStartText)
    .fontSize(14)
    .fontColor('#FFFFFF')
  Text(' 📅')
    .fontSize(14)
    .fontColor('#67C31F')
}
.width('100%')
.onClick((): void => {
  CalendarPickerDialog.show({
    selected: buildPickerDate(this.draftTimeStart),
    onAccept: (value: Date): void => {
      this.draftTimeStart = value.getTime();
      this.draftTimeStartText = formatDate(this.draftTimeStart);
    }
  })
})
```

**替换结束日期字段**（L396~L414）：带校验。

```typescript
Row({ space: 8 }) {
  Text('结束日期')
    .fontSize(14)
    .fontColor('#AAAAAA')
  Text(this.draftTimeEndText)
    .fontSize(14)
    .fontColor('#FFFFFF')
  Text(' 📅')
    .fontSize(14)
    .fontColor('#67C31F')
}
.width('100%')
.onClick((): void => {
  CalendarPickerDialog.show({
    selected: buildPickerDate(this.draftTimeEnd),
    onAccept: (value: Date): void => {
      if (value.getTime() < this.draftTimeStart) {
        promptAction.showToast({ message: '结束日期不能早于开始日期' });
        return; // 不更新值
      }
      this.draftTimeEnd = value.getTime();
      this.draftTimeEndText = formatDate(this.draftTimeEnd);
    }
  })
})
```

## 无需改动项

| 项 | 原因 |
|----|------|
| `formatBirthday` / `buildDatePickerDate` | 其他地方仍被引用，保留 |
| `formatDate` / `buildPickerDate` | 同上 |
| `CalendarPickerDialog.ets` 新文件 | **不新建**，使用系统内置 API |
| `import` 语句 | CalendarPickerDialog 是全局 API，无需 import |

## 风险与缓解

| 风险 | 缓解措施 |
|------|----------|
| 校验失败时 Dialog 仍关闭 | 用户看到 Toast 后重新打开即可修正，体验可接受；与项目已有模式一致 |
| API 兼容性（API 10+） | 项目 minCompatibleVersion 已在 API 10 以上（项目已使用 CalendarPicker，同为 API 10+），无风险 |
| CalendarPickerDialog 无法定制外观 | 用 `acceptButtonStyle` / `cancelButtonStyle` 做基础定制，满足交互稿要求 |

## 验收标准（DoD 对齐）

| 标准 | 验证方式 |
|------|----------|
| 编辑态点击 📅 弹出日历 Dialog | L1：真机截图 × 3（生日/开始/结束各一张） |
| 选择日期后点确定 → 文本更新 + Dialog 关闭 | L1：真机截图 |
| 点取消 → 文本保持原值 + Dialog 关闭 | L1：真机截图 |
| 结束日期选早于开始 → Toast "结束日期不能早于开始日期" + 值不更新 | L1：真机截图（showToast 瞬间） |

## 验证步骤

1. `check_ets_files` 检查修改的两个文件
2. `build_project`（module=entry@default, intent=LogVerification）确认无编译错误
3. 真机验证 3 个字段的弹出/确定/取消/校验行为