# V1-T3 Schema Compare

时间：2026-05-06 18:40 (UTC+8)

## 版本对比

- 迁移前：`schemaVersion=1`
- 迁移后：`schemaVersion=2`

## 结构变化

| 对象 | v1 | v2 | 结论 |
|------|----|----|------|
| `Person` | 存在 | 存在 | 保持 |
| `Story` | 存在 | 存在 | 保持 |
| `PhotoRef` | 存在 | 存在 | 保持 |
| `PhotoOwnerLink` | 存在 | 存在 | 保持 |
| `MigrationAudit` | 不存在 | 存在 | 新增 |

## 校验结论

- 目标版本结构达成：通过
- 不兼容破坏性改动：未发现

