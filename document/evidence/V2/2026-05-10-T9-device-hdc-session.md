# T-9 · 真机 hdc 取证会话（2026-05-10）

> **目的**：按用户要求，用 **hdc** 对当前已连接真机做可复现取证；与 **T-9** DoD 中「路径/日志/判定」对齐。  
> **说明**：本会话**未**完成应用内 UI 全路径手跑——根因见 **§4**。

## §1 · 环境

| 项 | 值 |
|----|-----|
| 工作区 | `c:\coding\DevEcoStudioProjects\timestore` |
| hdc 路径 | `C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe` |
| 构建 | MCP `build_project`：`entry@default`，`LogVerification`，**BUILD SUCCESSFUL**（与索引 §7.1 一致） |
| hap 产物 | `entry\build\default\outputs\default\app\entry-default.hap`（及同目录 `entry-default-unsigned.hap`） |

## §2 · 设备连接（未向用户索要 IP：已由 hdc 发现）

```text
> hdc list targets
192.168.50.160:46629
```

> 若需**改连**其它真机，请提供 **`IP:port`**（与 `hdc list targets` 显示格式一致）；本机当前默认即上列。

## §3 · 设备属性（hdc shell）

```text
> hdc shell param get const.product.model
HOP-AL10

> hdc shell param get const.ohos.fullsdk.version
Get parameter "const.ohos.fullsdk.version" fail! errNum is:106!

> hdc shell param get const.product.software.version
HOP-AL10 6.1.0.117(SP8C00E115R4P4)
```

**解读**：机型 **HOP-AL10**；软件版本串 **6.1.0.117(…)**（用于与同版 hap/证据对齐）。

## §4 · 安装本工程 hap（失败 · 阻塞）

**命令**：

```text
hdc install c:\coding\DevEcoStudioProjects\timestore\entry\build\default\outputs\default\app\entry-default.hap
```

**设备返回**：

```text
[Info]App install path:...entry-default.hap msg:error: failed to install bundle. code:9568320 error: no signature file.
```

**结论**：当前工程 **未配置 `signingConfigs`**（hvigor 亦提示 skip sign），产出为 **无有效签名** 包；真机 **拒绝安装**（code **9568320**）。  
**解除条件（二选一即可）**：在 `build-profile.json5` 配置 **debug/发布签名** 后重打 hap 再 `hdc install`；或由你方提供 **已签可装** 的 `entry-default-signed.hap` 路径。

## §5 · hilog 取样（成功 · 证明 hdc 日志链路可用）

**命令**：

```text
hdc hilog
```

**截取**（前若干行，含 **2026-05-10** 时间戳，证明为真机侧实时/近实时日志）：

```text
05-10 01:33:31.116 23809 23809 I A00011/com.huawei.hmos.vassistant/HwVA_VaWindowManager: getWindow VA_HALF_WINDOW
05-10 01:33:31.117 23809 23809 E A00011/com.huawei.hmos.vassistant/HwVA_VaWindowManager: findWindow throws {"code":1300002}
05-10 01:33:31.133  3266  3266 W A01A00/com.ohos.sceneboard/SYS_UI: AppLifeCycleManager: onProcessDied, uid: 20020019, bundleName: com.huawei.hmos.aidataservice, pid: 21574
…（后续多行系统/三方应用日志）
```

> 上述片段**未**包含 `com.lanjie162.timestore` 包名——因 **§4** 安装未成功，本应用进程未启动。

## §6 · 与 T-9 DoD 的对照（诚实缺口）

| DoD 条目 | 本会话是否满足 | 说明 |
|-----------|----------------|------|
| V2-D1～D4 用例命中 + 一轮执行记录 | **否** | 应用未装上设备，无法在真机跑主路径 |
| 阻塞/严重缺陷状态 | **部分** | **安装阻塞**：无签名（code 9568320）已记录 |
| 路径/日志/判定 | **部分** | 有 **hdc/hilog** 与 **机型/版本**；缺 **本包** 运行日志与界面判定 |

## §7 · 下一步（需你方一项输入即可继续）

1. **优先**：在仓库配置 **signingConfigs** 后告知，或发 **已签 hap** 路径 → 本会话可继续 `hdc install` → `aa start` → 按 `2026-05-10-T12-T16-import-suggest-batch.md` 手跑并另存 **带包名过滤** 的 hilog 文件。  
2. **可选**：若默认设备非 **192.168.50.160:46629**，请发目标 **`IP:port`**，并确保该机上已打开 **USB 调试 / 无线调试** 且 `hdc list targets` 可见。
