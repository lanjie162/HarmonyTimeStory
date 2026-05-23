---
task_id: T-26
source_request: TR-20260520-01#C-5
source_doc: document/plan/2026-05-06-MVP研发工作计划-定稿.md#V2.2-T5
archived_at: 2026-05-23
final_status: 已通晒
---

## T-26 归档快照（原始行内容）

- **任务摘要**：**sortOrder 修正**：PhotoRef 查询按拍摄时间降序(晚→早)；缺失则添加时间降序
- **owner_role**: dev
- **acceptor_role[]**: [qa, pm]
- **DoD**: 权威：MVP §6.2 sortOrder；UI 原型 §3。排序正确。证据：L2（截图对比；模拟器不可测 taken_at_cache 时人工抽样容忍）
- **状态**: 已完成 → 已通晒
- **来源任务请求反链**: `document/task/requests/plan/[任务经理]2026-05-20-[V2.2]-数据模型补全版全九任务派发.md#C-5`
- **执行结果**: 已执行 by dev @ 2026-05-22; 证据: E1(RepositoryImpl ORDER BY) E2(构建exit:0) E3(交付文档); 真机验证: 排序逻辑代码确认+UI入口正常 @ 2026-05-22
- **验收结论**: 通过 by qa @ 2026-05-22; 通过 by pm @ 2026-05-22: 确认
- **质检结论**: 通过 by quality(manager) @ 2026-05-22; Q1~Q6 全通过; 综合归类: 通过
- **通晒回填**: 通晒 by broadcast @ 2026-05-23; 上游=document/plan/2026-05-06-MVP研发工作计划-定稿.md#V2.2-T5; 已置 closed; 任务请求=TR-20260520-01#C-5