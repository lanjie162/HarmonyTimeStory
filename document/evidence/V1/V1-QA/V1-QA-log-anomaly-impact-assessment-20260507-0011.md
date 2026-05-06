# V1 QA 异常日志影响评估附录

- 批次：`20260506-2321`
- 评估时间：`2026-05-07 00:11 (UTC+8)`
- 评估角色：`qa`（主会话模拟，参考 `dev` 并行论证）
- 适用范围：`V1-T4` 日志可观测与 `V1-QA` 放行判定补充说明

---

## 1. 输入证据

- `evidence/V1/V1-T4/V1-T4-hilog-focused-20260506-2331.log`
- `evidence/V1/V1-T4/V1-T4-hilog-bundle-20260506-2321.log`
- `evidence/V1/V1-T4/V1-T4-hilog-20260506-2321.log`
- `evidence/V1/V1-T4/V1-T4-crashlist-20260506-2321.log`
- `evidence/V1/V1-T4/V1-T4-crashlist-focused-20260506-2331.log`
- `evidence/V1/V1-QA/V1-QA-execution-record-20260506-2235.md`
- `evidence/V1/V1-QA/V1-QA-final-gate-20260506-2321.md`

---

## 2. 异常分类与影响判定

| 异常类别 | 典型现象 | 影响范围 | 影响等级 | 判定 |
|---|---|---|---|---|
| 应用侧告警 | `null assertThread`、`GetAsset failed` 等 | 可能影响稳定性观感 | Minor | 可接受，需跟踪 |
| 系统/平台噪声 | `battery/netmanager/... err`、系统服务 E/W | 非业务主链 | Minor | 不作为阻断依据 |
| 会话切换异常 | `sessionException`、`onAbilityDied` 周边日志 | 生命周期切换阶段 | Minor | 结合功能结果判定可接受 |
| 崩溃记录 | crashlist 两次均 `no records found` | 放行阻断项 | 无 | 不构成 Blocker |

---

## 3. 与 DoD 的关系

- `D5`（构建稳定）：不受当前异常日志影响，已有连续构建成功证据。
- `D6`（冒烟可执行）：启动、路由往返、状态切换均已通过，异常未导致链路阻断。
- `D7`（可观测最小集）：已覆盖启动/路由/DB/异常码四类事件，满足“可追溯”要求。

---

## 4. 放行影响结论

- 是否构成 Blocker：**否**
- 放行建议：**有条件通过（风险可接受）**
- 条件说明：
  1. 当前异常未表现为崩溃或核心链路失败；
  2. 需在下版本继续跟踪应用域高频 E/W 日志；
  3. 将日志异常纳入回归趋势对账，不影响本次 V1 放行。

---

## 5. 后续跟踪动作

1. 增加“应用域异常日志”白名单/黑名单分桶与阈值。
2. 对 `com.lanjie162.timestore` 域内高频 E/W 做一次最小复现与归因。
3. 下一批次执行 30~60 分钟稳定性回归，并产出趋势对比记录。

