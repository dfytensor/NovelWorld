# 状态维护.ps1 · 角色账+道具账（伏笔账见伏笔状态维护.ps1）
# 账本: 角色状态账.md / 道具账.md —— 每章细纲后追加更新
# 细纲格式要求（提示词已注入）:
#   角色变化：角色名｜变化描述（位置/关系/认知/伤势/情绪等）
#   道具变化：道具名｜变化描述（持有者/状态/出现或消失）
param([Parameter(Mandatory=$true)][string]$BookDir,[Parameter(Mandatory=$true)][int]$ChN,[string]$DesignCard="")
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function New-Ledger { param([string]$Path,[string]$Title)
  if (-not (Test-Path $Path)) { [System.IO.File]::WriteAllText($Path, "# $Title`n", (New-Object System.Text.UTF8Encoding($true))) }
}
function Init-LedgerFromDesign {
  param([string]$Path,[string]$Title,[string]$Seed,[string]$Pattern)
  New-Ledger $Path $Title
  $t=[System.IO.File]::ReadAllText($Path,[System.Text.Encoding]::UTF8)
  if ($t -match [regex]::Escape($Title) -and $t.Length -lt ($Title.Length+3) -and $DesignCard -ne "") {
    $names = [regex]::Matches($DesignCard,$Pattern) | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
    $seed = $Seed -replace '\{names\}', (($names | ForEach-Object { "- [$_] 初登场前：未展开" }) -join "`n")
    [System.IO.File]::WriteAllText($Path, ("# $Title`n$seed`n"), (New-Object System.Text.UTF8Encoding($true)))
  }
}

$xgFile = Join-Path $BookDir ("细纲ch{0:D2}.md" -f $ChN)
$xg = [System.IO.File]::ReadAllText($xgFile, [System.Text.Encoding]::UTF8)

$roleFile = Join-Path $BookDir '角色状态账.md'
$propFile = Join-Path $BookDir '道具账.md'
Init-LedgerFromDesign $roleFile '角色状态账' "初始名册（自设计卡提取）`n{names}" '\*\*(主角|配角)[·*]*\s*([^*（(]+)'
Init-LedgerFromDesign $propFile '道具账' "关键道具登记（自设计卡/卷纲提取，卷纲事件物如：断指/名册/信）`n{names}" ''

$stamp = "## ch$ChN"
$log = @()

# 角色变化
$rl = ([regex]::Matches($xg, '角色变化[^：:\n]*[：:]\s*([^\n|]{3,80})'))
if ($rl.Count -gt 0) {
  $log += $stamp
  $rl | ForEach-Object { $log += "- " + $_.Groups[1].Value.Trim() }
}

# 道具变化
$pl = ([regex]::Matches($xg, '道具变化[^：:\n]*[：:]\s*([^\n|]{3,80})'))
if ($pl.Count -gt 0) {
  $pl | ForEach-Object { $log += "[道具] " + $_.Groups[1].Value.Trim() }
}

if ($true) {  # 快照无条件落盘
  $target = if (($log | Where-Object { $_ -notmatch '^\[道具\]' }).Count -gt 0) { $roleFile } else { $null }
  if ($target) { Add-Content -Path $roleFile -Value ($log | Where-Object { $_ -notmatch '^\[道具\]' }) -Encoding UTF8 }
  $props = $log | Where-Object { $_ -match '^\[道具\]' } | ForEach-Object { $_ -replace '^\[道具\] ','' }
  if ($props) { Add-Content -Path $propFile -Value $props -Encoding UTF8 }
  # 章级快照: 状态chNN.md（回溯用）
  $snapFile = Join-Path $BookDir ("状态ch{0:D2}.md" -f $ChN)
  $ledgerFile2 = Join-Path $BookDir "伏笔账·未兑现.md"
  $openSnap = if (Test-Path $ledgerFile2) { [System.IO.File]::ReadAllText($ledgerFile2,[System.Text.Encoding]::UTF8) } else { "(无)" }
  $snap = "# 状态快照 ch$ChN`n`n## 本章角色变化`n" + (($log | Where-Object { $_ -notmatch "^\[道具\]" -and $_ -ne $stamp }) -join "`n") + "`n`n## 本章道具变化`n" + (($props | ForEach-Object { "- $_" }) -join "`n") + "`n`n## 本章伏笔操作`n" + (($log | Where-Object { $_ -match "^(兑现|新埋)" }) -join "`n") + "`n`n## 截至本章·未兑现账全文`n$openSnap"
  [System.IO.File]::WriteAllText($snapFile, $snap, (New-Object System.Text.UTF8Encoding($true)))
  Write-Host ("  状态账更新: 角色" + ($rl.Count) + "条, 道具" + ($pl.Count) + "条, 快照→状态ch$ChN.md")
}
