# 项目规则

## 方案与计划优先原则

任何开发或修改任务必须遵循以下流程：

1. **先做方案，再动代码** - 接到需求或任务后，首先制定详细的方案和计划，包括但不限于：
   - 需求理解与澄清
   - 技术方案设计
   - 实现步骤拆解
   - 风险点与注意事项
   - 验收标准
2. **方案需用户确认** - 方案制定后，必须等待用户明确表达「方案确认」或「可以开始执行」的指示
3. **禁止随意编码** - 未获得用户明确确认前，不得修改任何代码、创建或删除文件
4. **方案修改需重新确认** - 执行过程中如需调整方案，需先与用户沟通并获得新的确认

---

## 分层 TDD 测试规范

所有 Feature 开发必须遵循分层测试驱动开发（TDD）流程。详见 [QA]测试能力升级方案_分层TDD架构.md。

### 测试分层要求

| 层级 | 测试内容 | 运行位置 | 触发时机 |
|------|----------|----------|----------|
| **L1 Unit** | domain/model/、Rules、Utils 纯函数 | `src/test/` 本地 | 新增/修改纯函数时 |
| **L2 Component** | 页面纯逻辑方法（buildXxx, formatXxx 等） | `src/test/` 本地 | 新增/修改页面逻辑时 |
| **L3 Integration** | features/Service + 真实 RDB | `ohosTest/` 设备 | 新增/修改 Service 方法时 |
| **L4 E2E** | 核心用户旅程（冒烟级别） | `ohosTest/` 设备 | 关键流程变更时 |

### TDD 开发流程

每个 Feature 必须遵循：Red（写失败的测试）→ Green（写最小实现）→ Refactor（保持测试绿色）→ Commit（测试+代码一起提交）。

### 测试先行检查清单（Code Review 必查）

- [ ] 新增的 `domain/model/` 类型是否有对应的 L1 单元测试？
- [ ] 新增的 `features/` Service 方法是否有对应的 L3 集成测试？
- [ ] 新增的页面逻辑（buildXxx, formatXxx）是否有对应的 L2 组件测试？
- [ ] 涉及数据变更的操作是否有回归测试覆盖？
- [ ] 测试用例命名是否清晰（格式：`{层级前缀}_{领域}_{场景描述}`）？

### 测试用例命名规范

```
{层级前缀}_{领域}_{场景描述}

示例：
- L1_model_photoMetadata_default_values
- L2_personDetail_buildMonthGroups_empty_photos
- L3_personService_updatePerson_empty_params_returns_true
- L4_e2e_personDetail_photoSwiper_open_and_close
```

---

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