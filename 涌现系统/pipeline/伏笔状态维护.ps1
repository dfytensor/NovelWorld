# 伏笔状态维护.ps1 v2 · 编号制双账本（表格化）
# 未兑现账格式: | 编号 | 埋于 | 内容 | 状态 |
# 已兑现账格式: | 编号 | 埋于→兑于 | 内容 | 兑现方式 |
param([Parameter(Mandatory=$true)][string]$BookDir,[Parameter(Mandatory=$true)][int]$ChN)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$open   = Join-Path $BookDir '伏笔账·未兑现.md'
$closed = Join-Path $BookDir '伏笔账·已兑现.md'
$openHdr  = "# 未兑现账（当前悬置）`n`n| 编号 | 埋于 | 内容 | 状态 |`n|---|---|---|---|`n"
$closedHdr = "# 已兑现账`n`n| 编号 | 埋于→兑于 | 内容 | 兑现方式 |`n|---|---|---|---|`n"
if (-not (Test-Path $open))   { [System.IO.File]::WriteAllText($open,  $openHdr,  (New-Object System.Text.UTF8Encoding($true))) }
if (-not (Test-Path $closed)) { [System.IO.File]::WriteAllText($closed, $closedHdr, (New-Object System.Text.UTF8Encoding($true))) }

# 读账（只取数据行 | F### | ...）
$openRows  = @([System.IO.File]::ReadAllLines($open,[System.Text.Encoding]::UTF8)   | Where-Object { $_ -match '^\| F\d+ \|(?!.*---)' })
$closedRows= @([System.IO.File]::ReadAllLines($closed,[System.Text.Encoding]::UTF8)| Where-Object { $_ -match '^\| F\d+ \|(?!.*---)' })

# 编号器: F001 起
$max = 0
foreach ($r in ($openRows + $closedRows)) { $m=[regex]::Match($r,'F(\d+)'); if ($m.Success -and [int]$m.Groups[1].Value -gt $max) { $max=[int]$m.Groups[1].Value } }

$xg = [System.IO.File]::ReadAllText((Join-Path $BookDir ("细纲ch{0:D2}.md" -f $ChN)), [System.Text.Encoding]::UTF8)
$log = @()

# 1) 兑现 → 匹配(双字滑窗) → 移入已兑现账
([regex]::Matches($xg,'兑现[:：]\s*([^\n|]{3,80})')) | ForEach-Object {
  $entry = $_.Groups[1].Value.Trim()
  if ($entry -eq '无') { return }
  $clean = $entry -replace '[，。；：!？? a-zA-Z0-9的了吗呢吧啊在一是和与及]',''
  $idx = $null
  for ($i=0; $i -lt $openRows.Count; $i++) {
    for ($c2=0; $c2 -lt $clean.Length-1; $c2++) {
      if ($openRows[$i] -match [regex]::Escape($clean.Substring($c2,2))) { $idx=$i; break }
    }
    if ($idx -ne $null) { break }
  }
  if ($idx -ne $null) {
    $row = $openRows[$idx]; $fid=[regex]::Match($row,'F\d+').Value; $mb=[regex]::Match($row,'\| (ch\d+) \|').Groups[1].Value
    $closedRows += "| $fid | $mb→ch$ChN | $entry | 本章细纲兑现 |"
    $openRows = @($openRows | Where-Object { $_ -ne $row })
    $log += "✅ $fid ($mb→ch$ChN) 已兑现: $entry"
  } else {
    $max++; $fid = "F{0:D3}" -f $max
    $closedRows += "| $fid | ?→ch$ChN | $entry | 直接兑现(补记) |"
    $log += "✅ $fid 补记兑现: $entry"
  }
}

# 2) 新埋 → 编号入未兑现账
([regex]::Matches($xg,'新埋[:：]\s*([^\n|]{3,80})')) | ForEach-Object {
  $item = $_.Groups[1].Value.Trim()
  if ($item -eq '无') { return }
  $max++; $fid = "F{0:D3}" -f $max
  $openRows += "| $fid | ch$ChN | $item | ⏳未兑 |"
  $log += "📌 $fid 新埋(ch$ChN): $item"
}

# 3) 回写
[System.IO.File]::WriteAllText($open,   ($openHdr   + (($openRows   | Sort-Object) -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($true)))
[System.IO.File]::WriteAllText($closed, ($closedHdr + (($closedRows| Sort-Object) -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($true)))
Write-Host ("  账本v2: " + ($log -join " ｜ ") + " ｜ 当前悬置 $($openRows.Count) 笔")
