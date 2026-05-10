# T-9 · 签名构建 + hdc 真机安装与拉起（2026-05-10）

## 前置

- 工程根 **`build-profile.json5`** 已配置 **`signingConfigs.name=default`**（`type: HarmonyOS`，材料指向 `~/.ohos/config/default_timestore_*`，`keyAlias: debugKey`）。口令为 DevEco 密文，**本文件不重复**。

## 1 · DevEco MCP 构建（已签名）

- **工具**：`user-deveco-mcp` → `build_project`  
- **参数**：`module=entry@default`，`build_intent=LogVerification`，`clean=false`  
- **结果**：`BUILD SUCCESSFUL`；`:entry:default@SignHap` **约 11 s**（非 skip sign）。  
- **产物**：`entry/build/default/outputs/default/entry-default-signed.hap`  
  - **大小**：403,740 字节  
  - **时间**：2026-05-10 01:59（本机目录时间戳）

## 2 · hdc 设备

- **hdc**：`C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe`  
- **`hdc list targets`**：`192.168.50.160:46629`

## 3 · 安装

```text
hdc install c:\coding\DevEcoStudioProjects\timestore\entry\build\default\outputs\default\entry-default-signed.hap
```

**输出**：`install bundle successfully.`

## 4 · 拉起主 Ability

```text
hdc shell aa start -a EntryAbility -b com.lanjie162.timestore
```

**输出**：`start ability successfully.`

## 5 · 包信息摘录（`bm dump`）

- **`appProvisionType`**：`debug`  
- **`apiTargetVersion`**：`60101024`（与工程 targetSdk 6.1.1(24) 一致量级）  
- **`apiCompatibleVersion`**：`50000012`（compatible 5.0.0(12)）

## 6 · hilog 取样（包名过滤）

**命令**：`hdc hilog` 管道筛选 `com.lanjie162.timestore`（截取安装后窗口内若干行）。

**样例**（节选，证明设备侧已识别本 debug 包）：

```text
05-10 02:00:01.511 … app com.lanjie162.timestore is in debug mode, try builtin info
05-10 02:00:05.203 … getSingleFromCache bundleName: com.lanjie162.timestore
…
05-10 02:00:05.217 … bundleName=com.lanjie162.timestore
```

> **说明**：上述多为系统/AppGallery 链路与处置日志；应用内 **`testTag` / EntryAbility** 行可在前台再拉一段 `hdc hilog` 并加大窗口或按 PID 过滤补档。

## 7 · 结论

| 项 | 结果 |
|----|------|
| 签名 hap 产出 | ✅ |
| hdc 安装 | ✅ |
| aa 启动 | ✅ |
| T-9 全量 UI 用例手跑 | ⏳ 需 qa 按 `2026-05-10-T12-T16-import-suggest-batch.md` 等在设备上补跑并另档 |
