# V1-T4 构建与冒烟验收记录

**版本**：V1  
**任务**：V1-T4  
**记录ID**：`V1-T4-build-smoke-check-20260506-2343`  
**记录日期**：`2026-05-06`  
**提交人**：`software-engineer` / `qa-engineer`  
**架构复核**：`architect`（主会话模拟）  
**联合验收**：`product-manager`（主会话模拟）

---

## 1. 检查范围

- 分支/提交范围：`workspace current state @ 2026-05-06`
- 设备信息：`192.168.50.160:46629 (TCP Connected)`
- 构建命令：`hvigor assembleApp (debug, product=default)`
- 冒烟脚本入口：`hdc shell aa start` + `hdc shell uitest uiInput`

---

## 2. 构建门禁检查

| 检查项 | 结论 | 证据ID | 证据路径 | 备注 |
|--------|------|--------|----------|------|
| 单次构建成功 | [x] 通过 [ ] 不通过 | V1-T4-build-1-20260506-2235 | `evidence/V1/V1-T4/V1-T4-build-1-20260506-2235.log` | clean=true |
| 连续构建稳定（重复执行） | [x] 通过 [ ] 不通过 | V1-T4-build-2-20260506-2235 | `evidence/V1/V1-T4/V1-T4-build-2-20260506-2235.log` | clean=false |
| 构建日志可追溯 | [x] 通过 [ ] 不通过 | V1-T4-build-1/2-20260506-2235 | `evidence/V1/V1-T4/*.log` | 日志完整落盘 |
| 失败可定位（若发生） | [x] 通过 [ ] 不通过 | V1-QA-execution-record-20260506-2235 | `evidence/V1/V1-QA/V1-QA-execution-record-20260506-2235.md` | 启动阻塞已定位并关闭 |

---

## 3. 最小冒烟脚本执行结果

| 场景 | 执行结果 | 证据ID | 证据路径 | 问题描述（若有） |
|------|----------|--------|----------|------------------|
| 启动 | [x] 通过 [ ] 不通过 | start-ability-20260506-2320 | `evidence/V1/V1-QA/V1-QA-execution-record-20260506-2235.md` | 无 |
| 导航切换（`person <-> story`） | [x] 通过 [ ] 不通过 | v1-g2-story / v1-g2-person-roundtrip | `evidence/V1/V1-T2/non-mcp-20260506-2321/` | 无 |
| DB 初始化 | [x] 通过 [ ] 不通过 | V1-T4-hilog-focused-20260506-2331 | `evidence/V1/V1-T4/V1-T4-hilog-focused-20260506-2331.log` | 有 Rdb 相关记录可追溯 |

---

## 4. 可观测性最小集检查（V1-D7）

| 观测项 | 结论 | 证据ID | 证据路径 | 备注 |
|--------|------|--------|----------|------|
| 启动日志（开始/成功/失败） | [x] 通过 [ ] 不通过 | V1-T4-hilog-focused-20260506-2331 | `evidence/V1/V1-T4/V1-T4-hilog-focused-20260506-2331.log` | 含 StartAbility |
| 路由日志（进入/切换） | [x] 通过 [ ] 不通过 | v1-g2-* + V1-T4-hilog-focused | `evidence/V1/V1-T2/non-mcp-20260506-2321/` | 页面证据+日志映射 |
| DB 迁移/初始化日志 | [x] 通过 [ ] 不通过 | V1-T4-hilog-focused-20260506-2331 | `evidence/V1/V1-T4/V1-T4-hilog-focused-20260506-2331.log` | 含 Rdb* 记录 |
| 异常码日志 | [x] 通过 [ ] 不通过 | V1-T4-hilog-focused-20260506-2331 | `evidence/V1/V1-T4/V1-T4-hilog-focused-20260506-2331.log` | 含 error code/err is |

---

## 5. DoD 映射结论

| DoD | 判定 | 依据 |
|-----|------|------|
| V1-D5 构建稳定 | [x] 通过 / [ ] 有条件通过 / [ ] 不通过 | 构建门禁检查 |
| V1-D6 冒烟可执行 | [x] 通过 / [ ] 有条件通过 / [ ] 不通过 | 三场景执行结果 |
| V1-D7 可观测性最小集 | [x] 通过 / [ ] 有条件通过 / [ ] 不通过 | 日志最小集检查 |

---

## 6. 风险与遗留项

| 风险ID | 描述 | 影响 | 责任人 | 关闭期限 | 当前状态 |
|--------|------|------|--------|----------|----------|
| T4-R1 | 非 MCP 链路脚本较长 | 维护成本 | software-engineer | 下版本 | 已记录 |

---

## 7. 最终签收

- `software-engineer` 提交结论：通过  
- `qa-engineer` 提交结论：通过  
- `architect` 复核结论：通过（主会话模拟）  
- `product-manager` 联合验收意见：通过（主会话模拟）  
- 版本状态建议：`V1 可收口`

---

## 8. 证据清单（最小集）

- [x] `V1-T4-build-1-20260506-2235.log`  
- [x] `V1-T4-build-2-20260506-2235.log`  
- [x] `V1-T4-hilog-focused-20260506-2331.log`  
- [x] `V1-T4-crashlist-focused-20260506-2331.log`  
- [x] `V1-QA-execution-record-20260506-2235.md`  
- [x] `evidence/V1/V1-T2/non-mcp-20260506-2321/*`
