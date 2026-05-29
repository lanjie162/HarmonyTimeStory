# 项目规则

## 输入组件键盘收起规范

所有 `TextInput` / `TextArea` 必须使用 `common/ui/KeyboardAwareInput` 中导出的 `TextInputWithKeyboard` / `TextAreaWithKeyboard` Builder 声明。

- **禁止直接使用** `TextInput` / `TextArea` 组件，除非有非常规参数需求且已用注释显式说明原因（如 `// skip-rule: KeyboardAwareInput`）
- Builder 的 `onSubmit` 参数内**不要手动调用** `dismissSoftKeyboard()` — Builder 在 `onSubmit` 中已自动兜底
- 新增含文本输入的页面时需要确保导入并使用 Builder 而非原生组件

### 正确用法

```typescript
import { TextInputWithKeyboard, TextAreaWithKeyboard } from '../../common/ui/KeyboardAwareInput';

TextInputWithKeyboard({
  placeholder: '名称',
  value: this.draftName,
  onChange: (v: string): void => { this.draftName = v; }
})

TextAreaWithKeyboard({
  placeholder: '备注',
  value: this.draftRemark,
  onChange: (v: string): void => { this.draftRemark = v; }
})
```

### 错误用法

```typescript
// 错误：直接用 TextInput 不自动收键盘
TextInput({ placeholder: '名称', text: this.name })
  .onChange((v: string): void => { this.name = v; })

// 错误：直接用 TextArea 不自动收键盘
TextArea({ placeholder: '备注', text: this.remark })
  .onChange((v: string): void => { this.remark = v; })
```

---

## 基线 DoD 一致性检查

当任务涉及**已定稿基线文档**的交付或验收时，必须：

1. 检查 DoD 或验收标准是否包含 `权威：` 锚点和 `证据：L1` / `证据：L2`（参见 governance Skill）
2. L2 声称需要 L2 级证据，除非 DoD 显式允许 L1 且 CR/计划范围允许
3. 高约束域任务（基线或 Must 要求比演示更强的验证）——拒绝静默缩水，升级 `CR-x` 或显式 Out

---

## Skill 产出文件命名规范

Skill 创建 `.md` 文档时，文件名必须以角色前缀开头：

| 角色 | 前缀 |
|------|------|
| sa | `[架构]` |
| dev | `[研发]` |
| qa | `[QA]` |
| pm | `[产品]` |
| ued | `[交互]` |
| vd | `[视觉]` |
| manager (review-meeting) | `[主持人]` |
| manager (version-planning) | `[项目经理]` |
| manager (task 相关) | `[任务经理]` |

未映射角色需用户确认前缀后才能创建文件。