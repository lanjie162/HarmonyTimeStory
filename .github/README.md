# GitHub Actions 与 Tier0

本仓库**未**在默认 GitHub 托管 Runner 上启用强制 Tier0：`deveco-mcp` 与 HarmonyOS **SDK / hvigor** 需本机或自建 Runner。

- **合并前 Tier0**：见 [document/techdoc/[QA]Tier0-MCP与Hypium证据实操.md](../document/techdoc/[QA]Tier0-MCP与Hypium证据实操.md) §1–§2 与 [document/techdoc/[架构]HarmonyOS测试分层与自动化规范.md](../document/techdoc/[架构]HarmonyOS测试分层与自动化规范.md) §10。  
- **`code-linter.json5`**：若后续增加 Workflow，仅可作为**并行** Job，**不可替代** §2.1 MCP Tier0。
