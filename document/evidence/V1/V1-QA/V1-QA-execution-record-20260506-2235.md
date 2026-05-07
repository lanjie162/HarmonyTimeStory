# V1 QA 执行记录（批次：20260506-2235）

- 日期：2026-05-06
- 执行角色：qa（主会话模拟）
- 产品参数：`product=default` `module=entry` `target=default` `ability=EntryAbility`
- 设备参数：`hvd=待补充（启动阶段自动识别后回填）`

---

## Gate-0：准备与同步（P0）

- 结论：通过
- 执行工具：`project_sync`
- 关键参数：`product=default`
- 日志证据：`evidence/V1/V1-T4/V1-T4-sync-20260506-2235.log`
- 执行结果：`ohpm install complete`，`hvigor --sync` 退出码 `0`，未见阻断错误

---

## Gate-1：构建门禁与启动冒烟（P1）

- 结论：通过（经非 MCP 真机链路恢复）
- 构建结果：
  - 第一次构建（`clean=true`）：通过  
    日志：`evidence/V1/V1-T4/V1-T4-build-1-20260506-2235.log`
  - 第二次构建（`clean=false`）：通过  
    日志：`evidence/V1/V1-T4/V1-T4-build-2-20260506-2235.log`
- 启动结果：
  - 未指定 `hvd` 时，工具要求明确设备。
  - `hvd=Mate X7`：模拟器启动后即退出（Device error）。
  - `hvd=MateBook Pro`：等待启动超时。
  - `hvd=Get parameter "ohos.qemu.hvd.name" fail! errNum is:1002!`：
    安装阶段提示签名异常，启动阶段失败：设备锁屏且开发者模式下无法自动解锁（Error Code: `10106102`）。
  - 用户提供 `deviceId=192.168.50.160:46629` 后复测：
    `start_app` 返回“未找到名称为 '192.168.50.160:46629' 的设备”，说明当前 `deveco-mcp` 设备视图未识别该真机。
- 阶段性阻塞说明（已解除）：
  - 首次阻塞：`10106102`（设备锁屏）。
  - 二次阻塞：`10104001`（目标 Ability 不存在），定位为应用未安装。
  - 处置：使用本地 hvigor 构建得到已签名包 `entry-default-signed.hap`，通过 `hdc install -r` 重装后重试。
  - 最终结果：`hdc shell aa start -b com.lanjie162.timestore -a EntryAbility` 返回 `start ability successfully.`

### 非 MCP 真机链路复测（2026-05-06 23:15）

- 链路说明：改用 `hdc` 直连真机执行启动与日志回收（无需 MCP 设备枚举）。
- 设备连接证据：
  - `hdc tconn 192.168.50.160:46629` 返回 `Connect OK`
  - `hdc list targets -v` 返回 `192.168.50.160:46629  TCP  Connected`
- 启动命令：`hdc shell aa start -b com.lanjie162.timestore -a EntryAbility`
- 结果：失败，错误码 `10106102`，错误信息为“启动时设备锁屏，自动解锁失败”。
- 官方口径（harmonyos_knowledge_search -> aa 工具文档）：`10106102` 的处理步骤为“解锁屏幕后重试”。
- 当前结论：该轮复测识别出锁屏前置条件，作为后续启动失败快速排障项保留。

### 非 MCP 真机链路复测（2026-05-06 23:20）

- 构建：本地 hvigor `assembleApp(debug)` 成功，签名流程通过（`SignHap`/`SignApp` 完成）。
- 安装：`hdc install -r entry-default-signed.hap` 成功。
- 启动：`aa start` 成功，日志出现：
  - `StartAbility com.lanjie162.timestore/EntryAbility`
  - `start ability successfully.`
- Gate-1 判定更新：满足“构建通过 + 启动到主壳页”门禁，准入 Gate-2。

---

## Gate-2：路由与页面可达验证（P2）

- 结论：通过（非 MCP 真机链路）
- 执行方式：`hdc shell uitest`（`dumpLayout` + `uiInput click` + `screenCap`）
- 证据目录：`evidence/V1/V1-T2/non-mcp-20260506-2321/`
- 五域进入成功证据（布局 JSON）：
  - `shell`：`v1-g2-shell.json`
  - `person`：`v1-g2-person.json`
  - `story`：`v1-g2-story.json`
  - `suggest`：`v1-g2-suggest.json`
  - `import`：`v1-g2-import.json`
- 导航往返证据：
  - `person <-> story`：`v1-g2-person-roundtrip.json`、`v1-g2-story.json`
  - `suggest -> person`：`v1-g2-person-from-suggest.json`
  - `import -> person`：`v1-g2-person-after-import.json`
- 判定说明：五域均可进入，关键返回路径可用（满足 Gate-2 退出条件）。

## Gate-3：全状态最小覆盖与日志回收（P3）

- 结论：通过（非 MCP 真机链路，日志可追溯）
- 三态证据（主壳页布局 JSON）：
  - 空态：`v1-g3-shell-empty.json`
  - 加载态：`v1-g3-shell-loading.json`
  - 错误态：`v1-g3-shell-error.json`
- 日志证据：
  - `evidence/V1/V1-T4/V1-T4-hilog-20260506-2321.log`
  - `evidence/V1/V1-T4/V1-T4-hilog-bundle-20260506-2321.log`
  - `evidence/V1/V1-T4/V1-T4-hilog-focused-20260506-2331.log`
  - `evidence/V1/V1-T4/V1-T4-crashlist-20260506-2321.log`（当前为 `no records found`）
- `evidence/V1/V1-T4/V1-T4-crashlist-focused-20260506-2331.log`（`no records found`）
- 四类事件映射（批次内）：
  - 启动：`aa start` 成功 + `StartAbility ... EntryAbility`
  - 路由：`uitest uiInput click` 触发页面切换并有对应页面布局证据
  - DB：`RdbServiceStub` / `RdbMgr` / `ConnectionPool ... *.db` 记录可检索
  - 异常码：日志中 `error code is 1`、`err is 27394049` 等异常码可追溯

## Gate-4：T1/T3 文档与代码复核（P4）

- 结论：通过
- 复核产物：
  - `evidence/V1/V1-T1/V1-T1-boundary-recheck-20260506-2321.md`
  - `evidence/V1/V1-T3/V1-T3-qa-recheck-20260506-2321.md`
- 复核结论摘要：
  - T1：边界证据链完整，可支撑 `D1/D8/D9` 判定。
  - T3：迁移/ADR/对账/异常恢复证据完整，可支撑 `D3/D4/D9` 判定。

## Gate-5：DoD 汇总与联合签收（P5）

- 结论：通过（主会话模拟联合签收完成）
- 最终文档：`evidence/V1/V1-QA/V1-QA-final-gate-20260506-2321.md`
- 签收结果：
  - `qa`：通过
  - `pm`：通过（主会话模拟）
