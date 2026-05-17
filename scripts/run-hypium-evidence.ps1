<#
.SYNOPSIS
  一键生成 Hypium / hdc 证据包：Tier0 构建默认走 MCP 约定、安装双 HAP、`aa test`、解析摘要为 summary.json。

.DESCRIPTION
  默认输出目录：document/evidence/local/<UTC 时间戳>-hypium-evidence
  需已安装 hdc 并连接设备；需 debug 签名 HAP。

  **Tier 参数**
  - `-Tier Tier2`（默认）：仅执行 ohosTest 设备侧测试
  - `-Tier Tier1`：仅建议通过 DevEco Studio 运行本地单元测试（此脚本提示跳转）
  - `-Tier All`：先 Tier1（仅提示），再 Tier2 设备侧测试

  **Tier0 与构建（与 document/techdoc/[架构]HarmonyOS测试分层与自动化规范.md §2.1 对齐）**
  - 默认 **`-BuildBackend Mcp`**…（同下文）
  - **`-SkipBuild`**：跳过构建步骤，直接使用已有 HAP。

  **超时说明**：默认 `-TimeoutMs 120000`（2min），适合本地快速失败调试。
  若全量 32 用例正常跑满（约 15-20min）需长时间等待，请传 `-TimeoutMs 600000`（10min）。

.PARAMETER Tier
  `Tier2`（默认）| `Tier1` | `All`。见 .DESCRIPTION。

.PARAMETER SkipBuild
  跳过构建步骤，直接使用已有 HAP。

.PARAMETER BuildBackend
  `Mcp`（默认）| `Hvigor`。见 .DESCRIPTION。

.PARAMETER Tier2Subset
  Tier2 子分级过滤：`All`（默认，全量）| `A` | `AB` | `ABC` | `AC` | `AD`。仅 `$Tier` 为 `Tier2` 或 `All` 时生效。
  一级匹配；非 All 时通过 `-s class` 过滤只跑对应层级。
  对应表见文档 `§4.1`。

.PARAMETER OutDir
  指定证据目录；不传则自动创建带时间戳的子目录于 document/evidence/local/。
#>
[CmdletBinding()]
param(
  [string] $BundleName = 'com.lanjie162.timestore',
  [string] $TestModule = 'entry_test',
  [int] $TimeoutMs = 120000,
  [switch] $SkipBuild,
  [ValidateSet('Mcp', 'Hvigor')]
  [string] $BuildBackend = 'Mcp',
  [string] $OutDir = '',
  [ValidateSet('Tier1', 'Tier2', 'All')]
  [string] $Tier = 'Tier2',
  [ValidateSet('All', 'A', 'AB', 'ABC', 'AC', 'AD')]
  [string] $Tier2Subset = 'All'
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot

$hapMain = Join-Path $RepoRoot 'entry\build\default\outputs\default\entry-default-signed.hap'
$hapTest = Join-Path $RepoRoot 'entry\build\default\outputs\ohosTest\entry-ohosTest-signed.hap'

if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmss'Z'")
  $OutDir = Join-Path $RepoRoot "document\evidence\local\${stamp}-hypium-evidence"
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# ── Tier1：本地单元测试 ──────────────────────────────────────────────
function Invoke-Tier1Hint {
  Write-Host "`n===== Tier1: 本地单元测试（src/test/）====="
  Write-Host "src/test/ 下的测试为纯逻辑/契约断言，不依赖设备。"
  Write-Host "请在 DevEco Studio 中通过 'entry' 模块的单元测试运行器执行："
  Write-Host "  entry/src/test/List.test.ets 聚合了以下套件："
  Write-Host "  - tier1_dataLayer_schemaMarkers (2 tests)"
  Write-Host "  - tier1_repository_singleton (2 tests)"
  Write-Host "  - tier1_repository_text_normalize (3 tests)"
  Write-Host " 共计 7 个本地用例。"
  Write-Host "`nIDE 操作：右键 entry/src/test/ → Run 'Tests in entry.test'"
  Write-Host "或使用 hvigorw 命令："
  Write-Host "  hvigorw --mode module -p module=entry@default -p buildMode=debug assembleHap`n"
}

# ── Tier2：设备侧 `aa test` ──────────────────────────────────────────
function Invoke-Tier2AaTest {
  param([string] $EvidenceDir)

  Write-Host "`n===== Tier2: 设备侧 ohosTest（aa test）====="

  if (-not (Test-Path -LiteralPath $hapMain)) {
    throw "未找到主 HAP: $hapMain"
  }
  if (-not (Test-Path -LiteralPath $hapTest)) {
    throw "未找到测试 HAP: $hapTest"
  }

  $hdc = Get-Command hdc -ErrorAction SilentlyContinue
  if (-not $hdc) {
    throw '未在 PATH 中找到 hdc，请安装 HarmonyOS 设备连接工具。'
  }

  Write-Host "安装 HAP 到设备..."
  $hdcInstall = & hdc install $hapMain 2>&1
  $hdcInstall | Out-File (Join-Path $EvidenceDir 'hdc-install-main.log') -Encoding utf8
  $hdcInstallTest = & hdc install $hapTest 2>&1
  $hdcInstallTest | Out-File (Join-Path $EvidenceDir 'hdc-install-ohosTest.log') -Encoding utf8

  & hdc list targets 2>&1 | Out-File (Join-Path $EvidenceDir 'hdc-list-targets.txt') -Encoding utf8
  & git -C $RepoRoot rev-parse HEAD 2>&1 | Out-File (Join-Path $EvidenceDir 'git-commit.txt') -Encoding utf8

  Write-Host "执行 aa test（超时 $TimeoutMs ms）..."
  Write-Host "Tier2Subset: $Tier2Subset"

  # ── Tier2 子分级 class 过滤 ──────────────────────────────────
  $subsetMap = @{
    'A'   = @('Tier2A_EntryAbilitySmoke', 'Tier2A_V2RegressionShell')
    'AB'  = @('Tier2A_EntryAbilitySmoke', 'Tier2A_V2RegressionShell',
              'Tier2B_V2RegressionPerson', 'Tier2B_V2RegressionStory')
    'ABC' = @('Tier2A_EntryAbilitySmoke', 'Tier2A_V2RegressionShell',
              'Tier2B_V2RegressionPerson', 'Tier2B_V2RegressionStory',
              'Tier2C_V2RegressionSuggestImport', 'Tier2C_V2RegressionB2')
    'AC'  = @('Tier2A_EntryAbilitySmoke', 'Tier2A_V2RegressionShell',
              'Tier2C_V2RegressionSuggestImport', 'Tier2C_V2RegressionB2')
    'AD'  = @('Tier2A_EntryAbilitySmoke', 'Tier2A_V2RegressionShell',
              'Tier2D_V2RegressionImportFull')
  }

  $aaArgs = @(
    'shell', 'aa', 'test',
    '-b', $BundleName,
    '-m', $TestModule,
    '-s', "timeout $TimeoutMs"
  )

  # 非 All 时追加 -s class 过滤
  if ($Tier2Subset -ne 'All' -and $subsetMap.ContainsKey($Tier2Subset)) {
    foreach ($cls in $subsetMap[$Tier2Subset]) {
      $aaArgs += '-s'
      $aaArgs += 'class'
      $aaArgs += $cls
    }
  }

  $aaArgs += '-s'
  $aaArgs += 'unittest'
  $aaArgs += 'OpenHarmonyTestRunner'
  $logPath = Join-Path $EvidenceDir 'aa-test.log'
  $aaOut = & hdc @aaArgs 2>&1
  $aaExit = $LASTEXITCODE
  $aaOut | Out-File -FilePath $logPath -Encoding utf8

  $text = $aaOut | Out-String

  # ── 解析总结果行 ──────────────────────────────────────────────
  $summaryMatch = [regex]::Match($text, 'Tests run:\s*(\d+)\s*,\s*Failure:\s*(\d+)\s*,\s*Error:\s*(\d+)\s*,\s*Pass:\s*(\d+)')

  # ── 按 suite(class) 逐个解析 ─────────────────────────────────
  $suiteResults = @()
  $suiteIter = [regex]::Matches($text, "OHOS_REPORT_SUM:\s*(\d+)\s*`r?`nOHOS_REPORT_STATUS:\s*class=(.+?)(?:`r?`n|$)")
  $suitePass = 0
  $suiteFail = 0
  $suiteTotal = 0
  foreach ($m in $suiteIter) {
    $className = $m.Groups[2].Value.Trim()
    $suiteTotal++

    # 查找该 class 下有没有 -1 的 test
    $classBlock = @()
    $blockStart = $m.Index
    $blockEnd = if ($m.Index + $m.Length -lt $text.Length) { $m.Index + $m.Length + 2000 } else { $text.Length - 1 }
    $classContent = $text.Substring($m.Index, [Math]::Min($blockEnd - $m.Index, $text.Length - $m.Index))
    $hasError = $classContent -match "OHOS_REPORT_STATUS_CODE:\s*-1"
    $hasPassTest = $classContent -match "OHOS_REPORT_STATUS_CODE:\s*0"

    if ($hasError) {
      $suiteFail++
      $suiteResults += [ordered]@{
        class    = $className
        status   = 'ERROR'
      }
    } elseif ($hasPassTest) {
      $suitePass++
      $suiteResults += [ordered]@{
        class    = $className
        status   = 'PASS'
      }
    } else {
      $suiteResults += [ordered]@{
        class    = $className
        status   = 'UNKNOWN'
      }
    }
  }

  $summary = [ordered]@{
    tier              = 'Tier2'
    bundleName        = $BundleName
    testModule        = $TestModule
    runner            = 'OpenHarmonyTestRunner'
    timeoutMs         = $TimeoutMs
    hapMain           = $hapMain
    hapTest           = $hapTest
    evidenceDir       = $EvidenceDir
    skipBuild         = [bool]$SkipBuild
    tier0BuildBackend = $BuildBackend
    testsRun          = if ($summaryMatch.Success) { [int]$summaryMatch.Groups[1].Value } else { $null }
    failure           = if ($summaryMatch.Success) { [int]$summaryMatch.Groups[2].Value } else { $null }
    error             = if ($summaryMatch.Success) { [int]$summaryMatch.Groups[3].Value } else { $null }
    pass              = if ($summaryMatch.Success) { [int]$summaryMatch.Groups[4].Value } else { $null }
    parsed            = $summaryMatch.Success
    hdcExitCode       = $aaExit
    suites            = $suiteResults
    suitesPassed      = $suitePass
    suitesFailed      = $suiteFail
    generatedAtUtc    = (Get-Date).ToUniversalTime().ToString('o')
  }
  $jsonPath = Join-Path $EvidenceDir 'summary.json'
  $summary | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonPath -Encoding utf8

  Write-Host "证据已写入: $EvidenceDir"
  Write-Host "summary.json: $(Get-Content -Raw $jsonPath)"

  $global:aaExitCode = $aaExit
  $global:summaryMatchSuccess = $summaryMatch.Success
  if ($summaryMatch.Success) {
    $global:aaFailure = [int]$summaryMatch.Groups[2].Value
    $global:aaError = [int]$summaryMatch.Groups[3].Value
  } else {
    $global:aaFailure = 0
    $global:aaError = 0
  }
}

# ── 判断 Tier0 构建逻辑 ──────────────────────────────────────────────
function Invoke-Tier0Build {
  if ($SkipBuild) {
    return
  }
  if ($BuildBackend -eq 'Mcp') {
    Write-McpTier0Handoff -EvidenceDir $OutDir
    $mainOk = Test-Path -LiteralPath $hapMain
    $testOk = Test-Path -LiteralPath $hapTest
    if (-not $mainOk -or -not $testOk) {
      throw @"
缺少构建产物（Tier0 默认由 MCP 完成，本脚本不调用 hvigor）:
  主包: $hapMain 存在=$mainOk
  测试包: $hapTest 存在=$testOk
请先在本机 Cursor 中按证据目录下的 tier0-mcp-handoff.json 调用 deveco-mcp 的 check_ets_files 与 build_project，再执行:
  .\scripts\run-hypium-evidence.ps1 -SkipBuild -OutDir "$OutDir"
若需在无 MCP 环境用 hvigor 一次构建，请使用:
  .\scripts\run-hypium-evidence.ps1 -BuildBackend Hvigor
"@
    }
    Write-Warning '已检测到现有 HAP；请确认本轮已由 MCP 按 tier0-mcp-handoff.json 完成 Tier0 构建后再继续 hdc/aa test。'
  }
  else {
    Invoke-HvigorBuild
  }
}

# ── 工具函数（与旧版保持兼容） ──────────────────────────────────────
function Get-ChangedEtsPathsRelative {
  $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
  $gitArgsList = @(
    @('diff', '--name-only', '--diff-filter=ACMR'),
    @('diff', '--cached', '--name-only', '--diff-filter=ACMR')
  )
  foreach ($ga in $gitArgsList) {
    $out = & git -C $RepoRoot @ga 2>$null
    if ($out) {
      foreach ($line in $out) {
        $t = $line.Trim()
        if ($t.Length -gt 0 -and $t -match '\.ets$') {
          [void]$set.Add(($t -replace '/', '\'))
        }
      }
    }
  }
  if ($set.Count -eq 0) {
    [void]$set.Add('entry\src\ohosTest\ets\test\List.test.ets')
  }
  return ($set | Sort-Object)
}

function Write-McpTier0Handoff {
  param([string] $EvidenceDir)
  $etsList = @(Get-ChangedEtsPathsRelative)
  $etsList | Out-File -FilePath (Join-Path $EvidenceDir 'tier0-check-ets-git-candidates.txt') -Encoding utf8

  $logDefault = (Join-Path $EvidenceDir 'mcp-build-entry-default.log')
  $logOhosTest = (Join-Path $EvidenceDir 'mcp-build-entry-ohosTest.log')

  $handoff = [ordered]@{
    tier0Authority = 'deveco-mcp (user-deveco-mcp)'
    readme         = '在 Cursor 中通过 MCP 调用下列工具，调用前从 Cursor 运行时缓存 mcps/user-deveco-mcp/tools/*.json 读对应工具 schema；完成后若产物已生成到 entry/build/... 下，请使用本脚本 -SkipBuild 重跑以继续 hdc + aa test。'
    suggestedSteps = @(
      @{
        tool      = 'check_ets_files'
        arguments = @{
          files = @($etsList | ForEach-Object { ($_ -replace '\\', '/') })
        }
      },
      @{
        tool      = 'build_project'
        arguments = @{
          module       = 'entry@default'
          build_intent = 'LogVerification'
          clean        = $false
          log_path     = $logDefault
        }
      },
      @{
        tool      = 'build_project'
        arguments = @{
          module       = 'entry@ohosTest'
          build_intent = 'LogVerification'
          clean        = $false
          log_path     = $logOhosTest
        }
      }
    )
    afterTier0RerunScript = ".\scripts\run-hypium-evidence.ps1 -SkipBuild -Tier $Tier"
    generatedAtUtc      = (Get-Date).ToUniversalTime().ToString('o')
  }
  $handoffPath = Join-Path $EvidenceDir 'tier0-mcp-handoff.json'
  $handoff | ConvertTo-Json -Depth 8 | Out-File -FilePath $handoffPath -Encoding utf8
  Write-Host "已写入 Tier0 MCP 交接: $handoffPath"
}

function Invoke-HvigorBuild {
  $candidates = @(
    (Join-Path $RepoRoot 'hvigorw.bat'),
    (Join-Path $RepoRoot 'hvigorw'),
    'hvigorw',
    'hvigor'
  )
  $exe = $null
  foreach ($c in $candidates) {
    if ($c -match '[\\/]' -and (Test-Path -LiteralPath $c)) {
      $exe = $c
      break
    }
    $cmd = Get-Command $c -ErrorAction SilentlyContinue
    if ($cmd) {
      $exe = $cmd.Source
      break
    }
  }
  if (-not $exe) {
    throw '未找到 hvigorw/hvigor。请安装/配置 DevEco CLI，或改用默认 -BuildBackend Mcp 并按 tier0-mcp-handoff.json 在 Cursor 中执行 MCP，然后 -SkipBuild 重跑。'
  }
  Write-Host "执行构建 (Hvigor): $exe assembleHap ..."
  & $exe assembleHap -p module=entry@default -p module=entry@ohosTest
  if ($LASTEXITCODE -ne 0) {
    throw "hvigor 构建失败，退出码 $LASTEXITCODE"
  }
}

# ════════════════════════════════════════════════════════════════════
# 主流程
# ════════════════════════════════════════════════════════════════════

# ── Tier1（仅提示） ────────────────────────────────────────────────
if ($Tier -eq 'Tier1' -or $Tier -eq 'All') {
  Invoke-Tier1Hint
  if ($Tier -eq 'Tier1') {
    Write-Host "`nTier1 提示已完成。退出。"
    exit 0
  }
}

# ── Tier2（设备侧） ────────────────────────────────────────────────
if ($Tier -eq 'Tier2' -or $Tier -eq 'All') {
  Invoke-Tier0Build

  $global:aaExitCode = 0
  $global:aaFailure = 0
  $global:aaError = 0
  $global:summaryMatchSuccess = $false

  Invoke-Tier2AaTest -EvidenceDir $OutDir

  $fail = 1
  if ($global:summaryMatchSuccess) {
    if ($global:aaFailure -eq 0 -and $global:aaError -eq 0 -and $global:aaExitCode -eq 0) {
      $fail = 0
    }
  }
  exit $fail
}