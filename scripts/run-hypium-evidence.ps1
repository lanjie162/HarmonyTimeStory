<#
.SYNOPSIS
  一键生成 Hypium / hdc 证据包：Tier0 构建默认走 MCP 约定、安装双 HAP、`aa test`、解析摘要为 summary.json。

.DESCRIPTION
  默认输出目录：document/evidence/local/<UTC 时间戳>-hypium-evidence
  需已安装 hdc 并连接设备；需 debug 签名 HAP。

  **Tier0 与构建（与 document/techdoc/[架构]HarmonyOS测试分层与自动化规范.md §2.1 对齐）**
  - **默认 `-BuildBackend Mcp`**：PowerShell **无法直接调用 MCP**，脚本会在证据目录写入 **`tier0-mcp-handoff.json`**（及 `tier0-check-ets-git-candidates.txt`），供在 **Cursor 中对 `user-deveco-mcp` 执行 `check_ets_files` + `build_project`**；若两份 HAP 尚不存在则 **终止**并提示先 MCP 构建后加 **`-SkipBuild`** 重跑。
  - **`-BuildBackend Hvigor`**：在 PATH/工程根存在 `hvigorw`/`hvigor` 时直接执行 `assembleHap`（Tier0 经 **CR-x** 降级场景）。
  - **`-SkipBuild`**：跳过上述任一路径，要求 `entry-default-signed.hap` / `entry-ohosTest-signed.hap` 已存在（例如已由 MCP 在本机构建完毕）。

.PARAMETER SkipBuild
  跳过构建步骤，直接使用已有 HAP。

.PARAMETER BuildBackend
  `Mcp`（默认）| `Hvigor`。见 .DESCRIPTION。

.PARAMETER OutDir
  指定证据目录；不传则自动创建带时间戳的子目录于 document/evidence/local/。
#>
[CmdletBinding()]
param(
  [string] $BundleName = 'com.lanjie162.timestore',
  [string] $TestModule = 'entry_test',
  [int] $TimeoutMs = 180000,
  [switch] $SkipBuild,
  [ValidateSet('Mcp', 'Hvigor')]
  [string] $BuildBackend = 'Mcp',
  [string] $OutDir = ''
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
    readme         = '在 Cursor 中通过 MCP 调用下列工具；完成后若产物已生成到 entry/build/... 下，请使用本脚本 -SkipBuild 重跑以继续 hdc + aa test。'
    toolSchemas    = @(
      'mcps/user-deveco-mcp/tools/check_ets_files.json',
      'mcps/user-deveco-mcp/tools/build_project.json'
    )
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
    afterTier0RerunScript = ".\scripts\run-hypium-evidence.ps1 -SkipBuild"
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

if (-not $SkipBuild) {
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
  .\scripts\run-hypium-evidence.ps1 -SkipBuild -OutDir `"$OutDir`"
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

$hdcInstall = & hdc install $hapMain 2>&1
$hdcInstall | Out-File (Join-Path $OutDir 'hdc-install-main.log') -Encoding utf8
$hdcInstallTest = & hdc install $hapTest 2>&1
$hdcInstallTest | Out-File (Join-Path $OutDir 'hdc-install-ohosTest.log') -Encoding utf8

& hdc list targets 2>&1 | Out-File (Join-Path $OutDir 'hdc-list-targets.txt') -Encoding utf8
& git -C $RepoRoot rev-parse HEAD 2>&1 | Out-File (Join-Path $OutDir 'git-commit.txt') -Encoding utf8

$aaArgs = @(
  'shell', 'aa', 'test',
  '-b', $BundleName,
  '-m', $TestModule,
  '-s', "timeout $TimeoutMs",
  '-s', 'unittest', 'OpenHarmonyTestRunner'
)
$logPath = Join-Path $OutDir 'aa-test.log'
$aaOut = & hdc @aaArgs 2>&1
$aaExit = $LASTEXITCODE
$aaOut | Out-File -FilePath $logPath -Encoding utf8

$text = $aaOut | Out-String
$match = [regex]::Match($text, 'Tests run:\s*(\d+)\s*,\s*Failure:\s*(\d+)\s*,\s*Error:\s*(\d+)\s*,\s*Pass:\s*(\d+)')
$summary = [ordered]@{
  bundleName         = $BundleName
  testModule         = $TestModule
  runner             = 'OpenHarmonyTestRunner'
  timeoutMs          = $TimeoutMs
  hapMain            = $hapMain
  hapTest            = $hapTest
  evidenceDir        = $OutDir
  skipBuild          = [bool]$SkipBuild
  tier0BuildBackend  = $BuildBackend
  testsRun           = if ($match.Success) { [int]$match.Groups[1].Value } else { $null }
  failure            = if ($match.Success) { [int]$match.Groups[2].Value } else { $null }
  error              = if ($match.Success) { [int]$match.Groups[3].Value } else { $null }
  pass               = if ($match.Success) { [int]$match.Groups[4].Value } else { $null }
  parsed             = $match.Success
  hdcExitCode        = $aaExit
  generatedAtUtc     = (Get-Date).ToUniversalTime().ToString('o')
}
$jsonPath = Join-Path $OutDir 'summary.json'
$summary | ConvertTo-Json -Depth 6 | Out-File -FilePath $jsonPath -Encoding utf8

Write-Host "证据已写入: $OutDir"
Write-Host "summary.json: $(Get-Content -Raw $jsonPath)"

$fail = 1
if ($match.Success) {
  $f = [int]$match.Groups[2].Value
  $e = [int]$match.Groups[3].Value
  if ($f -eq 0 -and $e -eq 0 -and $aaExit -eq 0) {
    $fail = 0
  }
}
exit $fail
