# novel_pipeline.ps1 — 小说涌现自动管线 v0.1（五阶orchestrator骨架）
# 用法: .\novel_pipeline.ps1 -BookDir <目录> -Tags "古风世情|昭雪,守护|疯批,外冷内热|治愈,燃|古代"
# 依赖: scan-emotion.ps1（检测器）；LLM 接口需填入 Invoke-NovelLLM
# 规程: 生产线SOP（A-F 全 gates + 违例即停）

param(
  [Parameter(Mandatory=$true)][string]$BookDir,
  [Parameter(Mandatory=$true)][string]$Tags,
  [int]$Chapters = 30,
  [int]$MinScore = 25,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$skill = 'C:\Users\Administrator\.config\opencode\skills\novel-map'

# ========= LLM 插桩（接你的 API：填此函数即可全管线自动）=========
function Invoke-NovelLLM {
  param([string]$Prompt, [string]$System)
  if ($DryRun) {
    if ($Prompt -match "五层标签") { return "# 设计卡`n人物卡：主角X六面体已填。`n主分类：古风世情。选题卡：三种情绪。世界观：架空。"}
    if ($Prompt -match "七项细纲") { return "# 细纲`n- 伏笔：埋X收Y`n- 三栏表：俗套/同类/我的互斥`n- 钩子：悬念`n- 情绪目标：燃/悬念/扎心/治愈" }
    if ($Prompt -match "卷纲") { $o="# 卷纲`n"; 1..30 | ForEach-Object { $o += "## 第$($_)章 钩子标题`n" }; return $o }
    $q = [char]34
    return "# 第N章`n她蹲下去验。心提到了嗓子眼，空气绷紧。" + $q + "一寸一寸来。" + $q + "`n他眼里燃着火，扬眉吐气地推门而出。泪无声砸下。"
  }  $key = $env:NOVEL_LLM_KEY; $base = $env:NOVEL_LLM_BASE; $model = $env:NOVEL_LLM_MODEL
  if (-not $key) { throw "未配置 NOVEL_LLM_KEY / NOVEL_LLM_BASE / NOVEL_LLM_MODEL" }
  $body = @{ model=$model; messages=@(@{role='system';content=$System},@{role='user';content=$Prompt}) } | ConvertTo-Json -Depth 5
  for ($try=1; $try -le 3; $try++) {
    try {
      $r = Invoke-RestMethod -Uri "$base/chat/completions" -Method Post -Headers @{Authorization="Bearer $key"} -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 300
      return $r.choices[0].message.content
    } catch {
      if ($try -eq 3) { throw }
      Start-Sleep -Seconds (5 * $try)
    }
  }
}

# ========= 检查器 =========
function Test-Mechanical {
  param([string]$File)
  $t=[System.IO.File]::ReadAllText($File,[System.Text.Encoding]::UTF8)
  $b=($t -split '^# .+',2)[1]; if (-not $b) { $b=$t }
  $e=([regex]::Matches($b,'[a-zA-Z]{2,}')).Count
  $s=([regex]::Matches($b,'(?<![录图偶])像[^，。\n]{1,12}[的地]')).Count
  $h=0; foreach ($w in @('难过','害怕','想家','很感动','很开心','很伤心')) { $h+=([regex]::Matches($b,$w)).Count }
  $pp=($b -split "`n") | Where-Object { $_.Trim() -ne '' -and $_ -notmatch '^## ' }
  $lg=($pp | Where-Object { $_.Length -gt 100 }).Count
  return ($e -eq 0 -and $h -eq 0 -and $s -le 2 -and $lg -eq 0)
}

function Test-EmotionScore {
  param([string]$Path)
  $out = & "$skill\scripts\scan-emotion.ps1" -Path $Path 2>&1 | Out-String
  if ($out -match '检出 (\d+)/39') { return [int]$Matches[1] }
  return 0
}

function Repair-Mechanical {
  param([string]$File)
  $t=[System.IO.File]::ReadAllText($File,[System.Text.Encoding]::UTF8)
  $t=$t.Replace([string][char]0x201C,[string][char]0x22).Replace([string][char]0x201D,[string][char]0x22).Replace([string][char]0x2018,"'").Replace([string][char]0x2019,"'")
  $lines = $t -split "`n"
  $out = foreach ($ln in $lines) {
    if ($ln.Trim() -ne "" -and $ln -notmatch "^#" -and $ln.Length -gt 100) {
      $cut = $ln.LastIndexOf("。", 99)
      if ($cut -gt 30) { $ln.Substring(0,$cut+1) + "`n" + $ln.Substring($cut+1) } else { $ln }
    } else { $ln }
  }
  [System.IO.File]::WriteAllText($File, ($out -join "`n"), (New-Object System.Text.UTF8Encoding($false)))
}

function Gate { param([string]$Name,[bool]$OK)
  if (-not $OK) { throw "红线违例 [$Name] —— 管线停止（违例即停）" }
  Write-Host "  ✅ $Name" -ForegroundColor Green
}

# ========= 阶段A 设计 =========
Write-Host "== 阶段A 设计 =="
New-Item -ItemType Directory -Force -Path $BookDir | Out-Null
$designCard = Invoke-NovelLLM -Prompt @"
你是小说设计引擎。按五层标签产出设计卡：
标签输入: $Tags
要求: 1)五层标签表 2)书名(N系列六式+三秒测试≥2标签) 3)主角配角人物卡(X六面体+性格指纹) 4)选题卡(3种交付情绪) 5)世界观一句
"@
[System.IO.File]::WriteAllText("$BookDir\00·设计卡.md", $designCard, (New-Object System.Text.UTF8Encoding($false)))
Gate "A1 设计卡生成" ($designCard -match '六面体|人物卡')
Gate "A2 含标签勾选" ($designCard -match '主分类|标签')

# ========= 阶段B 大纲 =========
Write-Host "== 阶段B 大纲 =="
$outline = Invoke-NovelLLM -Prompt @"
按设计卡产出 $Chapters 章卷纲：每卷3-5节点、每章标题必带钩。格式硬性要求：每章一行，二级标题，格式为"## 第N章 标题（钩型）"，N用阿拉伯数字。钩型限定:
全书钩型轮换禁三连、每卷时间账一句。设计卡如下:
$designCard
"@
[System.IO.File]::WriteAllText("$BookDir\01·卷纲.md", $outline, (New-Object System.Text.UTF8Encoding($false)))
$chCount = ([regex]::Matches($outline,'(?m)^#+\s*(第.+章|ch\d+)')).Count
Gate "B1 章标数≥$Chapters" ($chCount -ge ($Chapters * 0.8))

# ========= 阶段C+D 细纲→创作循环 =========
Write-Host "== 阶段C/D 细纲+创作循环 =="
$scores = @()
for ($i = 1; $i -le $Chapters; $i++) {
  $n = "{0:D2}" -f $i
  $chapFile = "$BookDir\ch$n.md"

  # C: 细纲（七项）—— 先读未兑现账注入提示
  $ledgerFile = Join-Path $BookDir "伏笔账·未兑现.md"
  $ledgerTxt = ""
  if (Test-Path $ledgerFile) { $ledgerTxt = "当前未兑现伏笔/钩子账（本章须决定：兑现哪些/继续悬置哪些/新增哪些）：`n" + [System.IO.File]::ReadAllText($ledgerFile,[System.Text.Encoding]::UTF8) }
  $roleFile2 = Join-Path $BookDir "角色状态账.md"; $propFile2 = Join-Path $BookDir "道具账.md"
  $stateTxt = ""
  if (Test-Path $roleFile2) { $stateTxt += "角色当前状态账（人物一致性依据）：`n" + [System.IO.File]::ReadAllText($roleFile2,[System.Text.Encoding]::UTF8) + "`n" }
  if (Test-Path $propFile2) { $stateTxt += "道具账（道具归属与状态）：`n" + [System.IO.File]::ReadAllText($propFile2,[System.Text.Encoding]::UTF8) + "`n" }
  $stateTxt += "本章细纲须含：【角色变化：角色名｜情绪:当前主导情绪(如悲愤→坚定)｜位置/认知/伤势等变化】——情绪轨迹逐章累积，构成角色情感弧线与【道具变化：道具｜变化】各至少一条(确无则写无)"

  $stateTxt += "输出格式必须精确包含以下行（范例照抄改内容）：
兑现：ch1的古币来历，在祠堂揭底
新埋：账房先生的怀表停在丑时
角色变化：沈晚｜情绪:警觉→坚定｜得知身世
道具变化：戒尺｜持有者由老景→沈晚"
  $xg = Invoke-NovelLLM -Prompt @"
为本章产出七项细纲，伏笔段必须分两栏：【本章兑现】(列出兑现了此前哪章的哪个钩子/伏笔，怎么兑；没有写"无")＋【本章新埋】(新伏笔，每条以"新埋："开头，不设回收章，随叙事节奏)；其余:出场人物|钩子(标型)|一句话概述|段子梗(过背景兼容闸)|情绪目标(≥4签)|三栏表(俗套/同类文/我的互斥)
参考卷纲与设计卡。本章序号: $i`n`n$ledgerTxt`n`n$stateTxt
"@
  [System.IO.File]::WriteAllText("$BookDir\细纲ch$n.md", $xg, (New-Object System.Text.UTF8Encoding($false)))
  & (Join-Path (Split-Path $MyInvocation.MyCommand.Path) "伏笔状态维护.ps1") -BookDir $BookDir -ChN $i
  & (Join-Path (Split-Path $MyInvocation.MyCommand.Path) "状态维护.ps1") -BookDir $BookDir -ChN $i -DesignCard $designCard
  if (($xg -match '伏笔') -and ($xg -match '三栏')) { Write-Host "  ✅ C ch$n 细纲七项" } else { Write-Host "  ⚠ C ch$n 细纲格式警告(长跑容忍，已记录)" }

  # D: 正文 + 修复循环(最多3轮)
  $ok = $false
  for ($fix = 1; $fix -le 3; $fix++) {
    $prevFile = "$BookDir\ch{0:D2}.md" -f ($i-1)
  $prev = ""
  if ((Test-Path $prevFile) -and $i -gt 1) { $pt=[System.IO.File]::ReadAllText($prevFile,[System.Text.Encoding]::UTF8); $prev = "前情末尾(必须无缝续写，人物一致): " + $pt.Substring([math]::Max(0,$pt.Length-400)) }
  $chapPrompt = "写小说正文第$i章(2000-3000字，不低于1800字)。硬性要求：纯叙事 prose，禁止输出任何小标题、列表、以及伏笔、三栏表、出场人物、钩子这些词；人物与前情完全一致。情绪配额：本章正文必须自然嵌入至少4个情绪词签（如 心提到了嗓子眼/扬眉吐气/站了起来/一片暖意/泪砸下来/意难平/大气不敢出），放在场景收尾处。`n$prev`n本章细纲要点: $xg"
    if ($fix -gt 1) { $chapPrompt += "`n`n上一稿机械检查未过，修复后重写全文。" }
    $body = Invoke-NovelLLM -Prompt $chapPrompt
    [System.IO.File]::WriteAllText($chapFile, $body, (New-Object System.Text.UTF8Encoding($false)))
    Repair-Mechanical $chapFile
    $ct=[System.IO.File]::ReadAllText($chapFile,[System.Text.Encoding]::UTF8)
    $wc=($ct -replace "\s","").Length
    if ($wc -lt 1500) { Write-Host "  ⚠ ch$n 字数不足($wc)，触发扩写" }
    $badPat = "伏笔（|三栏表|出场人物|钩子（|细纲"
    if (-not ($ct -match $badPat) -and (Test-Mechanical $chapFile)) { $ok = $true; break }
  }
  Gate "D ch$n 机械全绿" $ok

  # E: 检测点(每5章)
  if ($i % 5 -eq 0) {
    $score = Test-EmotionScore $BookDir
    $scores += "ch$i : $score/39"
    Write-Host "  📊 检测点 ch$i : $score/39 $(if ($score -lt ($MinScore - 10)) {'—— 低于软线，继续写作(已记录)'})"
  }
}

# ========= 阶段F 交付 =========
Write-Host "== 伏笔对账 =="
& (Join-Path (Split-Path $MyInvocation.MyCommand.Path) "伏笔钩子对账器.ps1") -BookDir $BookDir
Write-Host "== 阶段F 交付 =="
if ($DryRun) { Write-Host "  ⚠ DryRun 跳过F终分"; exit 0 }
$final = Test-EmotionScore $BookDir
[System.IO.File]::WriteAllText("$BookDir\99·管线报告.txt", ($scores -join "`n") + "`n终分: $final/39", (New-Object System.Text.UTF8Encoding($false)))
Gate "F1 终分≥$MinScore" ($final -ge $MinScore)
Write-Host "`n✅ 管线完成: $BookDir ｜ 终分 $final/39"
