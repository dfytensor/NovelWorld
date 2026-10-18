# 伏笔钩子对账器.ps1 · v0.3（成对制）
# 规程：
#   每章细纲必须含两段：【本章兑现】(来自chX的钩/伏笔，写明怎么兑) + 【本章新埋】(新伏笔，不设回收章)
#   钩子=局部承诺(章尾钩)，须在其后章节兑现；伏笔=全局承诺，兑现章随叙事节奏，允许标注"留续"
#   30章完结定义：钩子100%兑现；伏笔=每笔要么已兑、要么显式"留续"，不许无声失踪
# 用法: .\伏笔钩子对账器.ps1 -BookDir <目录>
param([Parameter(Mandatory=$true)][string]$BookDir)
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ledger = @()   # 埋账
$cash   = @()   # 兑账
Get-ChildItem $BookDir -Filter '细纲*.md' | Sort-Object Name | ForEach-Object {
  $chn = [int]($_.Name -replace '\D','')
  $t = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8)
  ([regex]::Matches($t, '(?m)^\s*[-*]?\s*新埋[:：]\s*(.+)$')) | ForEach-Object { $ledger += [pscustomobject]@{ Ch=$chn; Item=$_.Groups[1].Value.Trim(); Status='未兑' } }
  ([regex]::Matches($t, '(?m)^\s*[-*]?\s*兑现[:：]\s*(?:ch(\d+)[的\s]*)?(.+)$')) | ForEach-Object { $cash += [pscustomobject]@{ Ch=$chn; SrcCh=$_.Groups[1].Value; Item=$_.Groups[2].Value.Trim() } }
}

# 对账：每笔埋 → 找提及该要件的兑现
$report = foreach ($p in $ledger) {
  $kw = ($p.Item -replace '[，。；：""!？? ]','').Substring(0, [math]::Min(6, ($p.Item -replace '[，。；：""!？? ]','').Length))
  $hit = $cash | Where-Object { $_.Item -match [regex]::Escape($kw) -and [int]$_.Ch -gt $p.Ch } | Select-Object -First 1
  if ($hit) { $p.Status = "已兑(ch$($hit.Ch))" }
  [pscustomobject]@{ 埋章=$p.Ch; 伏笔=$p.Item; 状态=$p.Status }
}
"=== 伏笔总账（埋 $($ledger.Count) 笔 / 兑现记录 $($cash.Count) 条）==="
$report | Format-Table -AutoSize
$open = ($report | Where-Object { $_.状态 -eq '未兑' }).Count
"未兑: $open 笔 —— 每笔须二选一：补进后续章节细纲的【兑现】，或改标'留续'(合法，但全书留续≤30%)"
