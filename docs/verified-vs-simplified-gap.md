# 已核对原版规则 vs 实现差距表（Godot 验收轮）

2026-11-04 最新接续：五丸、食灵、猫掌柜、饴细工、兔丸、千姬6位／48张主体已核对接入，其中47张主要机制完成；甘如暖阳独立佳肴池仍明确partial。真实烹饪、中立食物、三猫与糖人融合、贝戟／咏流、选择UI及AI已接通，515项专项、双尺寸原生、22组相关旧回归及215.5 MiB本地Web构建通过，171个既有验证未改。全库仍有380张已知近似、586张未核对、962张待核验及21条审计诊断；旧JS测试仍失败。详见[本批验收](../output/godot-cooking-six-20261103/acceptance.md)。

2026-11-03 最新接续：季沧海、无尘、宁红夜、土御门胡桃、荒川之主、川猿、小袖之手共7位、56张主体及3张派生的主要机制已接入Godot；包括真实蓄力／主动释放、物品两次选择、永久结袂、持续眩晕与幻境按序暂停续结。815项角色专项+109项交叉、双尺寸原生、42组相关旧回归及203.0 MiB本地Web构建通过，165个既有验证未改。全库仍有415张已知近似、601张未核对、907张待核验及20条既有审计错误；旧JS引擎的原生派生校验仍失败。详见[合批验收](../output/godot-heptet-20261102/acceptance.md)。

2026-10-18 前批：鬼童丸、阿修罗16张主体牌接入真实首抽/抽到当回合增强、引路人原实例回库成长、复活重挂与可暂停续结的连续交战、己方伤害成长、独立复活自伤、条件战斗转移及幻境恢复。167项专项/原生鼠标检查和相关精简回归通过；完整原版卡面累计21位角色168张，明确简化809→795，新增条目仍待实机核验。见[研究55](../research-notes/55-oni-asura-rules.md)与[验收](../output/godot-oni-asura-20261018/acceptance.md)。

2026-10-17 前批：管狐、白藏主16张主体牌接入真实狐怒印记、形态倒计时继承、条件战斗免伤、指定目标整牌反制、敌方灵咒/眩晕逐个清除、临时属性及全队伤害上限；修正已核对形态继承旧检视文案。161项规则/原生鼠标检查及相关精简回归通过；完整原版卡面累计19位角色152张，明确简化820→809，新增条目仍待实机核验。见[研究54](../research-notes/54-pipe-white-fox-rules.md)与[验收](../output/godot-pipe-fox-20261017/acceptance.md)。

2026-10-17 前批：追月神、辉夜姬16张主体牌接入宵月真实瞬发/额外出击、上回合开始快照、鬼火变1自动响应与消耗清空，以及幻境耐久/能力叠加、真实检索、石钵召唤和条件替伤。185项规则/原生鼠标检查及相关精简回归通过；完整原版卡面累计17位角色136张，明确简化834→820，新增条目仍待实机核验。见[研究53](../research-notes/53-moon-bamboo-rules.md)与[验收](../output/godot-moon-bamboo-20261017/acceptance.md)。

2026-10-17 前批：薰、巫蛊师16张主体牌接入唯一守护、减伤/光环、真实干扰响应、蛊蚀叠层/气绝触发、施蛊原卡回手及蛊狱伤害替换，修正空能力原生形态气绝残留。148项规则/原生鼠标检查及相关精简回归通过；完整原版卡面累计15位角色120张，明确简化847→834，新条目仍待实机核验。未核对776、待核验297、已有来源原生207，19条既存诊断不变。见[研究52](../research-notes/52-owl-insect-rules.md)与[验收](../output/godot-owl-insect-20261017/acceptance.md)。

2026-10-17 前批：人面树、樱花妖16张主体牌接入生命战斗、真实形态诅咒、目标回合延迟自伤、气绝倒计时治疗/伤害、独立重复与飘零自由出击。167项规则/原生鼠标检查及相关精简回归通过；完整原版卡面累计13位角色104张。明确简化860→847，新条目仍待实机核验。未核对779、待核验281、已有来源原生207，19条既存诊断不变。见[研究51](../research-notes/51-tree-sakura-rules.md)与[验收](../output/godot-tree-sakura-20261017/acceptance.md)。

2026-10-17 前批：独眼小僧、垢尝16张主体牌替换旧映射，规则、合法选择、AI及原版卡面同步。102项专项与相关精简回归通过；原版卡面累计11位角色88张。明确简化860、未核对782、待核验265、已有来源原生207，19条既存诊断保留。见[研究50](../research-notes/50-monk-cleaner-rules.md)与[本批验收](../output/godot-monk-cleaner-20261017/acceptance.md)。

2026-10-17 前批：缘结神、食梦貘16张主体牌替换近似，接入实例灵咒、逐张抽牌/检索区别、复活/消灭、追猎与自动攻击、梦魇牌移除替伤。120项专项及相关精简回归通过，原版完整卡面累计9位角色72张。明确简化873、未核对785、待核验249、已有来源原生207，19条既存诊断保留。见[研究49](../research-notes/49-bond-dream-rules.md)与[本批验收](../output/godot-bond-dream-20261017/acceptance.md)。

2026-10-17 前批：百目鬼、蟹姬16张主体牌替换近似，规则、目标/选择、AI和原生交互同步；130项专项及相关精简回归通过。原版完整卡面累计覆盖7位角色56张主体牌。全组仍待实机核验；明确简化889、未核对785、待核验233、已有来源原生207，19条既存诊断保留。见[研究48](../research-notes/48-eye-crab-rules.md)与[本批验收](../output/godot-eye-crab-20261017/acceptance.md)。

2026-10-17 前批：山风、泷夜叉姬、般若24张主体牌替换近似，规则、选择/目标界面、AI和原生鼠标交互同步；127项专项及相关精简回归通过。连同铁鼠、河童共40张主体牌复用原版完整卡面。明确简化902、未核对788、待核验217、已有来源原生207，19条既存诊断保留。见[研究47](../research-notes/47-wind-night-mask-rules.md)与[验收](../output/godot-wind-night-mask-20261017/acceptance.md)。

2026-10-17 前批：铁鼠、河童16张主体牌和幸运钱币已替换基础近似，109项定向规则/鼠标检查通过，相关运势/战斗/卡光回归及统一Web构建通过。当批明确简化925、未核对789、待核验193、已有来源原生207。下文八式神表为历史验收范围，后续各批见[研究46](../research-notes/46-iron-mouse-river-rules.md)和[验收](../output/godot-iron-mouse-20261017/acceptance.md)。

> **范围：** `godot/content/verified_rules.json` 中 **8 式神 + 68 张专属卡**（萤草另含 3 条衍生 token 条目）。  
> **依据：** 核对库来源索引、`research-notes/09`–`16`、`阴阳师百闻牌-机制全景.md`、`AGENTS.md`、录像 `video-200`（叶隐/钢风片段）。  
> **本轮范围（Hal 纠正）：** 仅 **Godot** 可玩竖切按核对规则验收；**Web/JS 本轮不做**（分支上历史凤凰火 Web 改动保留，不再扩展）。

## 验收结论（2026-10-10）

| 式神 | Godot 规则层 | 规则专测 | UI/目标专测 | 本轮 Godot |
| --- | --- | --- | --- | --- |
| 钢风 `datiangou-gangfeng` | `verified_card_rules` + 起源战斗倒计时 | `verify_steel_wind` 115 ✓ | `verify_steel_wind_ui` 44 ✓ | **已对齐核对库** |
| 妖琴师 `yaoginshi` | `countdown_rules.gd` | `verify_yaoginshi` 126 ✓ | `verify_yaoginshi_ui` 30 ✓ | **已对齐核对库** |
| 大天狗 `datiangou` | `spell_replay_rules.gd` | `verify_datiangou` 115 ✓ | `verify_datiangou_ui` 38 ✓ | **已对齐核对库** |
| 一目连 `yimulian` | `form_countdown_rules.gd` | `verify_yimulian` 128 ✓ | `verify_yimulian_ui` 52 ✓ | **已对齐核对库** |
| 鸩 `zhen` | `armor_break_rules.gd` | `verify_zhen` 122 ✓ | `verify_zhen_ui` 48 ✓ | **已对齐核对库** |
| 凤凰火 `fenghuanghuo` | `phoenix_rules.gd` | `verify_phoenix` 122 ✓ | `verify_phoenix_ui` 57 ✓ | **已对齐核对库** |
| 桃花妖 `taohuayao` | `peach_rules.gd` | `verify_peach` 114 ✓ | `verify_peach_ui` 48 ✓ | **已对齐核对库** |
| 萤草 `yingcao` | `firefly_rules.gd` | `verify_firefly` 126 ✓ | `verify_firefly_ui` 54 ✓ | **已对齐核对库** |
| 交叉 | 多式神同局 | `verify_parallel_rules` 41 ✓ | — | **已对齐核对库** |

**复现命令（需 Godot 4.4+ headless，建议先 `export` + `--import`）：**

```bash
export GODOT_BIN=/path/to/Godot_v4.4.1-stable_linux.x86_64
./scripts/godot-verified-eight.sh
```

数据：`ContentLoader` 载入 `content.json` 后 **merge** `verified_rules.json`（与 `research-notes` 一致，不删历史「简化」导出文案）。

### Web/JS（本轮不做）

| 项目 | 状态 |
| --- | --- |
| `game-content*.js` 可玩化映射 | 未改；全库仍大量简化标记 |
| `npm run audit:rules` | 仍失败（`known-approximation` / `unreviewed` 占绝大多数） |
| 分支历史 | 曾接入凤凰火 Web overlay/专规；**本轮不再扩展 Web** |

---

## `verificationPending` 汇总（未删、未猜）

下列条目在核对库中**刻意保留**，表示缺指定录像/版本实机，Godot 采用牌文+公告+专测锁定的**保守实现**；专测中有断言「pending 仍存在」以防误标完成。

| 归属 | 卡/单位 | 待核实内容 | Godot 当前取舍 |
| --- | --- | --- | --- |
| 鸩 | `zhen` 觉醒 | 历史次数是否计入**当前**触发 | 按已完成次数增强；专测覆盖基础 2 破甲与成长 |
| 凤凰火 | `fenghuanghuo` | 魔音反制后「使用法术」帧；气绝前后焚羽快照 | 独立 `phoenix-spell-used` 帧；反制清本体不清已排队投射 |
| 桃花妖 | `taohuayao` | 零实际恢复是否成长；气绝后群复活成长时点 | 仅实际恢复触发；群复活后统一成长（专测） |
| 一目连 | `c11807` 风符·龙 | 两龙不共享次数、同波目标不重复 | 按 2020 细则转载实现；缺原作者视频交叉 |
| 鸩 | `c11604` 毒蚀 | 与屏障、碧羽散华同时存在时的优先级 | 专测有屏障/转换正反例；复杂叠层待录像 |
| 鸩 | `c11605` 觉醒 | 减计时与替换先后、历史是否含当次 | 牌文顺序+已完成次数；专测保留 pending 标记 |
| 鸩 | `c11607` 毒之华 | 奇数生命向下取整 | 向下取整；专测保留 pending |
| 凤凰火 | `c12401` 凤鸣 | 公告 3→2 与旧快照冲突 | **按 2020-02-27 公告取 2** |
| 凤凰火 | `c12405` 炎舞 | 屏障+贯通+破甲精细分配 | 贯通溢出已实现；多层分配待录像 |
| 凤凰火 | `c12406` 出云 | 投射/运势/反制/气绝先后 | 使用事件→投射→运势；专测保留 pending |
| 桃花妖 | `c10801` 等 | 零恢复成长 | 不触发成长；`verify_peach` 断言 pending 非空 |
| 桃花妖 | `c10809` 群复活 | 气绝时自身是否也得成长 | 先复活再统一成长；pending 保留 |
| 萤草 | `c10708` 虹彩等 | 闪烁层叠、多闪烁响应串接 | 力量归零+响应原战斗；多闪烁共用首张合法响应 |

**未写入 pending 的 8 式神：** 钢风、妖琴师、大天狗、一目连（除上表 c11807）、萤草（除上表）在核对库单位级无 `verificationPending`；边界靠 `research-notes` + 专测覆盖。

---

## 分式神要点（Godot = 核对实现；Web = 本轮不做）

### 1. 钢风·大天狗 `datiangou-gangfeng`

- **证据：** `research-notes/09-steel-wind-video-rules.md`，`video-200`，`balance-2023-11-23`，起源替换 `origin-design-2023`。
- **Godot：** 战斗牌起源倒计时（气绝不移除）、叶隐移动/倒计时或抽牌、形态护甲联动倒计时、吾即正义随机法术等 — `verify_steel_wind`。
- **Web：** 本轮不做（仍为旧 assault/加甲映射）。

### 2. 妖琴师 `yaoginshi`

- **证据：** `research-notes/10-yaoginshi-countdown-rules.md`，`balance-2023-10-26`。
- **Godot：** 四歌倒计时、入阵歌 5 点随机分配、觉醒大合奏记录实际种类、魔音与自动复读边界 — `verify_yaoginshi`。
- **Web：** 本轮不做。

### 3. 大天狗 `datiangou`

- **证据：** `research-notes/11-datiangou-spell-replay.md`。
- **Godot：** 法术复读倒计时、吾即正义等级约束随机法术、暴风等 — `verify_datiangou`。
- **Web：** 本轮不做。

### 4. 一目连 `yimulian`

- **证据：** `research-notes/12-yimulian-form-lifecycle.md`。
- **Godot：** 形态进场/消灭触发、风符倒计时、罡风/鼓舞/瞬响应 — `verify_yimulian`；`c11807` 见 pending 表。
- **Web：** 本轮不做。

### 5. 鸩 `zhen`

- **证据：** `research-notes/13-zhen-armor-break.md`，`balance-2020-01-20`。
- **Godot：** 牌手/式神破甲、毒伤转破甲、战斗双向转化、碧羽散华等 — `verify_zhen`；觉醒/毒蚀/毒之华见 pending 表。
- **Web：** 本轮不做。

### 6. 凤凰火 `fenghuanghuo`

- **证据：** `research-notes/14-phoenix-rules.md`。
- **Godot：** 完整 8 牌 + 投射链 — `verify_phoenix`；凤鸣/炎舞/出云见 pending 表。
- **Web：** 本轮不做（分支遗留早期 Web 接入，不扩展）。

### 7. 桃花妖 `taohuayao`

- **证据：** `research-notes/15-peach-rules.md`。
- **Godot：** 治疗/复活成长、检索、形态、迅捷、气绝可用群疗 — `verify_peach`；见 pending 表。
- **Web：** 本轮不做。

### 8. 萤草 `yingcao`

- **证据：** `research-notes/16-firefly-rules.md`，`firefly-may2020-balance`。
- **Godot：** 形态瞬发抽牌、鼓舞、点点手牌增强、虹彩生成 — `verify_firefly`；闪烁边界见 pending 表。
- **Web：** 本轮不做。

---

## `npm run audit:rules`（全库规则审计）

审计读取 `game-content.js` 全库，并合并 `godot/content/verified_rules.json` 核对覆盖层。它并非只检查 Web，也不只覆盖本文历史八式神范围。`known-approximation`、`unreviewed` 或待核对项尚未清零时应继续失败。

普通测试、专用检查与 AI 对局通过，只证明其覆盖的行为和程序稳定性；不表示 Godot 全库或 Web 全库已经还原。具体修复范围、来源版本与剩余项以各轮 `research-notes` 和全库审计输出为准。

---

## 变更日志（本分支）

| 轮次 | 内容 |
| --- | --- |
| 前序 | 差距表初稿；Web 凤凰火试验性接入 |
| **本轮** | Godot 八式神专测全绿；`scripts/godot-verified-eight.sh`；`verified_card_rules` / 专测脚本 `ContentLoader` preload；本文档改为 Godot 验收口径 |


## Wave2 接续验收（2026-10-15）

本轮在 Godot 接入九位角色的72张真实构筑牌，另处理已有皮肤／衍生牌与番茄、烟分身、烬染的生命周期；蛇行击和送祝福按后续正式公告回填。范围和验证日志见 [验收](../output/godot-wave2-20261014/acceptance.md) 与研究33–36。旧HTML/JS专属执行器没有逐角色同步。

本轮全库审计仍失败：式神条目145近似、64未核对、26待核验、15资料支持原生；卡牌966近似、805未核对、132待核验、211资料支持原生。235个式神条目与1903张牌尚未闭合。新增标注旧库番茄／烬染独立构筑16张牌缺乏官方来源，保留旧入口及缺陷，审计明确报告未实现；没有通过删入口、缩卡池或把其旧效果标成已验证处理。罗生门之鬼的随机池及权重缺口仍在。

## 久次良、吸血姬接续（2026-10-15）

本批为 Godot 的两位角色16张主体牌建立原生规则，替换旧库固定伤害／回血／护甲近似：派生力量、伤害转移、逐段吸血、恢复事件、手牌实例增强、幻境耐久、秘宝生命下限和帷幕均有独立执行。目标、自动响应、当前状态检视和 AI 使用同一规则入口。另按正式公告补正幽光之火、吸魂灯、金运大吉、五谷丰壤、福满乾坤五张旧牌。见 [研究37](../research-notes/37-armor-blood-rules.md)、[研究38](../research-notes/38-balance-followup-20220126.md) 与 [验收记录](../output/godot-armor-blood-20261015/acceptance.md)。

当前全库审计分类：单位144项已知近似、63项未核对、28项待核对、15项已建立原生资料与实现；卡牌958项已知近似、797项未核对、152项待核对、207项已建立原生资料与实现。本轮将缺少录像／后续公告穷尽核验的旧牌重新标为待核对，因此原生分类计数比上一轮减少4，不能用减少待办数字冒充完成。`audit:rules`仍应退出1。

血香的连击线索已定位为巅疯赛特殊模式，常规对战采用官方免疫战斗伤害改版。白骨能力复制、初拥跨阵营归属、部分血蝠复杂防止伤害组合、同名幻境规则及上限仍需指定录像实机核验；没有把这些推断去标记。旧HTML/JS专属结算仍有大量历史近似。上一轮列出的19项全库诊断继续保留。

## 共享护甲上限与送祝福接续（2026-10-15）

补上上一批明确留下的65535护甲／破甲上限，覆盖式神和牌手的实际获得事件、临时护甲、破甲首次获得观察者、天籁18号结果、水龙卷预测及卡面完整数值显示。送祝福补上2021-06-29维护公告转载中的抽牌；仍保留原帖、后续普通更新和指定录像的核验缺口，未提升为完全还原。新增规则、AI与两种尺寸的真实鼠标交互验证见 [验收](../output/godot-armor-limit-20261015/acceptance.md) 和 [研究39](../research-notes/39-armor-limit-blessing-followup.md)。

全库分类保持单位144近似／63未核对／28待核对／15原生资料及实现，卡牌958近似／797未核对／152待核对／207原生资料及实现；19项既有诊断仍在。上一批复制能力、初拥归属、部分复杂防止伤害、同名幻境与上限缺口未在本批处理。

## 2026-10-15 荒接续

荒的基础／觉醒与8张主体牌从旧护甲／固定伤害映射移入 `huang_rules.gd`，新增真实耐久、自毁、随机逐段伤害、一次回手、手牌弃牌选择及AI路径。官网本次直接取得的JS与荒海／月坠图片是数据依据，普通2020-11-26公告补足月坠触发后必须移除的规则。全组仍为 `pending-verification`，没有增加 `source-backed-native` 计数；旧HTML/JS角色专规未同步。来源与尚未核验的时序／使用边界见 [研究40](../research-notes/40-huang-realm-rules.md)，实际检查见 [验收](../output/godot-huang-20261015/acceptance.md)。
