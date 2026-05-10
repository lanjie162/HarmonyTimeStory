# T-9 · DevEco MCP 打包 + hdc 真机 — 签名与执行报告（2026-05-10）

## 1 · `user-deveco-mcp` 能做什么 / 不能做什么

| 能力 | 说明 |
|------|------|
| **`build_project`** | 等价于在工程根执行 **hvigor assembleHap**（本仓库为 `entry@default`）。**签名完全由工程根 `build-profile.json5` 的 `signingConfigs` 决定**；MCP **没有**单独的「只签名」或「注入口令」参数。 |
| **`start_app` / `get_hilog_or_faultlog_recent`** | 依赖 MCP 侧识别的设备列表；与命令行 **`hdc.exe` 所见的 TCP 真机**（如 `192.168.50.160:46629`）**可能不一致**。真机操作建议以 **`hdc` 命令行**为准。 |

## 2 · timestore：MCP 打包（未签名）— **成功**

- **调用**：`build_project`，`module=entry@default`，`build_intent=LogVerification`。  
- **结果**：`BUILD SUCCESSFUL`；日志含 `Will skip sign 'hos_hap'. No signingConfigs profile is configured`。  
- **产物**：`entry\build\default\outputs\default\app\entry-default.hap`（**无有效签名**）。

## 3 · timestore：真机 `hdc install`（无签名包）— **失败（已知）**

- **命令**：`hdc install …\entry-default.hap`  
- **结果**：`code:9568320 error: no signature file`（见 `2026-05-10-T9-device-hdc-session.md`）。

## 4 · timestore：尝试在 `build-profile.json5` 中补签名 — **两次失败结论**

### 4.1 复用 HelloWorld 的 **密文口令** + timestore 的 **.p12/.p7b/.cer 路径**

- **结果**：`SignHap` → `Init keystore failed` / `keystore password was incorrect`。  
- **结论**：DevEco 写入的 `000000…` 密文与 **具体 p12 文件**绑定，**不能跨工程拷贝**。

### 4.2 复用 HelloWorld 的 **整套材料路径**（同一套 p12/p7b/cer）

- **结果**：`00303074 Configuration Error` — **`AppScope/app.json5` 的 `bundleName` 与 SigningConfigs 中 profile 的 bundle 不一致**。  
- **结论**：不能把 HelloWorld 的 profile 用来签 **com.lanjie162.timestore**。

**推论**：要让 **timestore** 打出 **`entry-default-signed.hap`**，必须在 **`build-profile.json5`** 中配置 **与 `com.lanjie162.timestore` 匹配** 的一套 `material`，且 **`storePassword` / `keyPassword` 为 DevEco 针对该套 p12 生成的密文**（通常由 IDE **自动签名 / Fix** 写入）。

## 5 · 参考：HelloWorld 工程 — **签名包 + hdc 安装 + 拉起 Ability** — **成功**

用于证明 **本机 hdc → 真机** 链路正常（非 timestore 业务）。

| 步骤 | 命令 / 动作 | 结果 |
|------|-------------|------|
| 构建 | 在 `HelloWorld` 目录执行 hvigor `assembleHap`（该工程已含有效 `signingConfigs`） | `BUILD SUCCESSFUL`，`SignHap` UP-TO-DATE |
| 产物 | `HelloWorld\entry\build\default\outputs\default\entry-default-signed.hap` | 存在 |
| 安装 | `hdc install …\entry-default-signed.hap` | `install bundle successfully` |
| 启动 | `hdc shell aa start -a EntryAbility -b com.example.helloworld` | `start ability successfully` |

## 6 · 使 timestore 走通「MCP 打包签名 + hdc」的最短路径（需你本地 DevEco 一次）

1. 用 **DevEco Studio** 打开 **`timestore`** 工程。  
2. **File → Project Structure → Signing Configs**（或向导 **Fix**），对 **`com.lanjie162.timestore`** 使用 **自动签名**，直到 **工程级 `build-profile.json5`** 出现与 **`.ohos\config\default_timestore_*.p12`** 匹配的 **`signingConfigs`**（含 `storePassword` / `keyPassword` 密文）。  
3. 回到 Cursor 再调 **`build_project`**：应不再出现 `Will skip sign`，并生成 **`entry-default-signed.hap`**。  
4. 执行：  
   `hdc install c:\coding\DevEcoStudioProjects\timestore\entry\build\default\outputs\default\entry-default-signed.hap`  
5. 拉起（示例）：  
   `hdc shell aa start -a EntryAbility -b com.lanjie162.timestore`  
6. 取证：`hdc hilog` 或按包名过滤，将片段归档到 `document/evidence/V2/`。

> **安全**：含密文的 `build-profile.json5` 是否入库由团队策略决定；常见做法是 **不入库** 或仅提交占位 + 本地覆盖文件。

## 7 · hdc 可执行路径（本机）

`C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`

## 8 · 执行结果回填（2026-05-10）

工程已写入 **timestore** 专用 `signingConfigs` 后：`build_project` → **SignHap 成功**，`entry-default-signed.hap` 产出；**`hdc install` / `aa start`** 成功。详见 **`document/evidence/V2/2026-05-10-T9-signed-hdc-install-run.md`**。
