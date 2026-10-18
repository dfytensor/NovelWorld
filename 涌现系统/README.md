# 小说涌现系统 · 蓝图（skill × JEV 融合）
> 目标：把 novel-map skill 的创作方法论，装进 JEV 的多智能体涌现引擎，
> 用 JEV 自带的涌现叙事剧场（viz/theater_server.py）**可视化看到小说的涌现过程**。

---

## 一、架构映射表（skill ↔ JEV 原语）

| skill 概念 | JEV 原语 | 说明 |
|---|---|---|
| 人物卡（X六面体） | `agent state/traits` | 表=traits，里/核=state.情绪，伤=memory 初值，变=策略触发条件 |
| 性格指纹（敲桌/眯右眼） | `policy 策略` 固定动作 | 指纹=角色的确定性微动作 |
| 五层标签 | `world 语境` | 主分类/背景=世界常量；情节签=事件类型 |
| 39签检测器 | `judge 判定(文本)->Fuzzy` | **scan-emotion 词表直接翻译成 jev judge**（如 judge 悬念(句)->Fuzzy） |
| 情绪五道岗 | `goals` | 每章目标=签位配额（燃0.8/悬念0.7…） |
| 情节双闸 | `strategy` 前置 judge | 栏1/栏2=judge 俗套度/撞车度 >阈值则否决 |
| 伏笔账/钩子链 | `memory` | 记忆条目=伏笔登记；钩型=goal 达成检查 |
| 人物关系（爱恨情仇） | `state.关系{亲密}` | 关系边实时演化=剧场里的连线粗细 |
| B/M行为化表达 | act 的具象文本 | agent 输出=动作+微表情，不直陈情绪 |
| 涌现验收 | `meta_eval / judge 淘汰` | 低于签位配额的章策略被元认知淘汰 |

## 二、可视化（直接复用 JEV 现成件）

- **实时剧场**：`viz/theater_server.py --port 8787` 跑 novel 世界 →
  浏览器看：角色节点+关系边+消息粒子（绿=善意/红=冲突）、情绪条、适应度、
  叙事流（新策略/发明词汇/合作/误解/淘汰）、**累积涌现曲线**
- **"命运"干预**＝作者在环：投放事件（如"发现名册缺页"）、对角色说话、赐福/降罚——
  即"读者/作者介入改写情节"的可视化
- **静态仪表盘**：`viz/build_dashboard.py 300` 生成单文件 dashboard.html——整卷涌现轨迹回放

## 三、MVP 三阶段

### 阶段1 · novel.jev 世界（复刻 C1）
把《王爷只是个验尸的》四角色装进 jev：
- judge 定义（翻中文词表）：`judge 悬念度(句)`, `judge 疯癫嫌疑(行为,语境)`, `judge 信任(人,事)`, `judge 打脸力度(怼,受)`
- agent：沈晚（state:情绪{平静0.7,警觉0.5}; traits:手稳0.95,好奇0.6; goals:昭雪0.95;
  strategy: 验尸优先/程序内反击/指纹动作）
- agent：萧狁（traits:疯表演0.9,真话浓度0.4; strategy: 疯局掩护/轻声真话/眯右眼）
- agent：老景（外冷内热：嘴上否定+手上帮助双策略）、小满（记账策略+投喂策略）
- 事件流：六指尸→官媒司→名册缺页→开棺（ch1-30 卷纲事件作 world timeline）

### 阶段2 · 词签 judge 接入（检测器进引擎）
- 写 `novel_judges.jev`：把 scan-emotion.ps1 的 24 情绪词签逐条译成 judge
- agent 每次发言/行动后自评签位，未达配额 → 触发"补签策略"（=章级配额的自动化）

### 阶段3 · 剧场化验收
- theater_server 跑 300 tick = 一卷
- 看板验收线：涌现曲线持续上行 + 签种数增长 + 无策略淘汰潮
- 人的角色：作者当"命运"，在关键 tick 干预（=细纲调整），其余交给涌现

## 四、目录规划
```
F:\novelskill\涌现系统\
  novel.jev            ← 阶段1（C1世界）
  novel_judges.jev     ← 阶段2（词签判定器）
  run_novel.ps1        ← 启动剧场（调 jev 的 theater_server）
  README.md            ← 本蓝图
```
（运行依赖 F:\jev\.venv，引擎零改动，纯外挂世界文件）

---

## 五、首跑实录（2026-10 · 已验证）

```
novel.jev v0.2 在 JEV 真实引擎上跑通（--ticks 6）：
tick3 [合作机会]搬书架 → 四角色同事件、四种性格响应：
  沈晚: 记录(记下了。)@0.70
  萧狁: 发疯(本王乐意。)@0.85   ← 疯表演trait自动接管
  老景: 骂人压惊(废物。……都退下。)@0.70
  小满: 投喂(师姐，汤温了三回。)@0.80
tick6 [环境]窗外下雨 → 同样四种人设响应
情绪自然衰减(平静0.7→0.47)｜记忆写入(短期2+情节2)｜适应度开始累积
```
**性格分化涌现成功**——同一事件，四个人按各自 traits/goals 做出了"只有他会这么做"的反应。

### 启动命令（实测有效）
```
# 命令行跑世界
cd F:\jev
C:\Python314\python.exe -X utf8 jev\cli.py run F:\novelskill\涌现系统\novel.jev --ticks 30

# 涌现剧场可视化（浏览器 http://localhost:8787）
C:\Python314\python.exe -X utf8 F:\jev\viz\theater_server.py --port 8787 --pre 16

# 静态仪表盘（单文件html，双击即看涌现曲线）
C:\Python314\python.exe -X utf8 F:\jev\viz\build_dashboard.py 260
```

### 语法要点（踩坑记录）
- state 块必须**单行**（多行会解析失败）
- 无 world 块——事件由外部驱动器/theater 注入
- 中文引号禁止；字符串用直引号