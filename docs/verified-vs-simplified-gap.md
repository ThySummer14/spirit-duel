# 已核对原版规则 vs 当前可玩实现差距表

> 范围：`godot/content/verified_rules.json` 中 **8 式神 + 68 张专属卡**（另有萤草 3 张衍生 token 条目）。  
> 依据：`verified_rules.json` 来源索引、`research-notes/09`–`16`、`阴阳师百闻牌-机制全景.md`、`AGENTS.md`、用户指定录像路径（见 `verified_rules.json` → `video-200`）。  
> 生成说明：全库 `npm run audit:rules` 仍失败；本文只覆盖**已写入核对库**的角色，不宣称全库还原完成。

## 总览

| 维度 | Godot 可玩端 | Web/JS（`game-core.js`） |
| --- | --- | --- |
| 卡面/数值数据 | `ContentLoader` 启动时 merge `verified_rules.json` | **本 PR 起** `getCardDefinition` / `getUnitDefinition` 懒合并核对数据 |
| 结算专规 | `verified_card_rules.gd` + 分角色 `*_rules.gd` + `verify_*.gd` 正反例 | **仅凤凰火**接入 `game-phoenix-rules.js`；其余 7 式神仍走旧 effect 映射 |
| 审计 | 专测脚本（见下表） | `tests/game-phoenix-verified.test.js`（4 组）；全库 audit 仍大量 `known-approximation` |

| 式神 | 核对卡数 | Godot 专测 | Web 结算（本 PR 后） |
| --- | ---: | --- | --- |
| 钢风·大天狗 `datiangou-gangfeng` | 8 | `verify_steel_wind.gd` | 未接入专规 |
| 妖琴师 `yaoginshi` | 8 | `verify_yaoginshi.gd` | 未接入专规 |
| 大天狗 `datiangou` | 9 | `verify_datiangou.gd` | 未接入专规 |
| 一目连 `yimulian` | 8 | `verify_yimulian.gd` | 未接入专规 |
| 鸩 `zhen` | 8 | `verify_zhen.gd` | 未接入专规 |
| 凤凰火 `fenghuanghuo` | 8 | `verify_phoenix.gd` | **已接入**（投射/引燃/焚羽/炎舞增强/出云运势/觉醒叠身） |
| 桃花妖 `taohuayao` | 8 | `verify_peach.gd` | 未接入专规 |
| 萤草 `yingcao` | 8+3 token | `verify_firefly.gd` | 未接入专规 |

---

## 1. 钢风·大天狗（`datiangou-gangfeng`）

证据：`research-notes/09-steel-wind-video-rules.md`、`verified_rules` 来源 `video-200`、`balance-2023-11-23`、`origin-design-2023`。

### 被动 / 觉醒

| 项 | 原版应有机制 | 当前实现 | 证据 |
| --- | --- | --- | --- |
| 起源再临 / 龙卷钢风 | 使用**战斗牌**时倒计时 2（觉醒 1）：再使用该牌**起源法术**；气绝不移除（钢风） | Godot：`verified_card_rules` 战斗起源倒计时 + `verify_steel_wind.gd` | `verified_rules.units.datiangou-gangfeng` |
| Web | 同上 | 仍用 `game-content` 可玩化 assault/加甲近似；**无**起源替换、无战斗倒计时 | `game-content-classic.js` 290xx 段 |

### 卡牌（c29001–c29008）

| 卡 | 原版要点 | Web 旧映射问题 | Godot |
| --- | --- | --- | --- |
| c29001 钢羽之刃 | 1 护甲 + 起源风神一扇（投射 2 + 击退） | 缺起源链、护甲与公告后数值 | 已专测 |
| c29002 叶隐 | 瞬发移动 + 倒计时或抽牌 | 常为移动/抽牌简化 | 已专测 |
| c29003 钢风形态 | 进场护甲 + 回合末有护甲者倒计时 | 形态身材/倒计时简化 | 已专测 |
| c29004–c29008 | 起源战斗、连击、魔音、正义随机法术等 | 缺起源/复读/反制边界 | 已专测 |

**本 PR 修复：** 无（Godot 已有专测；Web 未改）。

---

## 2. 妖琴师（`yaoginshi`）

证据：`research-notes/10-yaoginshi-countdown-rules.md`、`balance-2023-10-26`、`yaoginshi-encyclopedia`。

### 被动 / 觉醒

| 项 | 原版 | Web | Godot |
| --- | --- | --- | --- |
| 三歌倒计时 | 3 回合轮换：余韵群疗 / 入阵歌随机 5 伤 / 神乐歌队友倒计时与成长 / 镇魂歌抽牌+鬼火；觉醒替换能力；大合奏记录**实际生效种类** | 多为固定治疗或加攻近似 | `countdown_rules.gd` + `verify_yaoginshi.gd` |

### 卡牌 c12801–c12808

核对库含 `random-damage`、`countdown-change`、`awaken-yaoginshi` 等原生 action。Web 仍为抽牌/加力/直伤类 hooks。**Godot 已专测。**

**待核实（核对库已标）：** 入阵歌与大合奏动态文案、觉醒施法减倒计时与魔音交互 — `verificationPending` on c12805/c12808 等。

---

## 3. 大天狗（`datiangou`）

证据：`research-notes/11-datiangou-spell-replay.md`、`datiangou-balance-2020`、`balance-2021-05-20`。

### 被动 / 觉醒

法术使用后倒计时 2（觉醒 1）**复读同一法术**（非战斗牌）。

| 端 | 状态 |
| --- | --- |
| Godot | `spell_replay_rules.gd` + `verify_datiangou.gd` |
| Web | 无复读栈；法术多为单次 damage/draw |

### 卡牌 c10501–c10509

含吾即正义随机取得等级不高于自身的专属法术、暴风全体 3 伤等。Web 映射未实现随机法术取得与倒计时。**Godot 已专测。**

---

## 4. 一目连（`yimulian`）

证据：`research-notes/12-yimulian-form-lifecycle.md`、`yimulian-encyclopedia`、`balance-2020-11-26`。

### 被动 / 觉醒

形态**进场/离场（消灭）**触发倒计时；风符·龙逐次增目标等。

| 端 | 状态 |
| --- | --- |
| Godot | `form_countdown_rules.gd` + `verify_yimulian.gd` |
| Web | 形态多为 +身材；无离场倒计时、无风符多段 |

**待核实：** 风符·龙同波目标上限、与屏障叠加分配 — `verificationPending`（龙相关来源 `dragon-detail-2020`）。

---

## 5. 鸩（`zhen`）

证据：`research-notes/13-zhen-armor-break.md`、`zhen-official-intro`、`balance-2020-01-20`。

### 被动 / 觉醒

倒计时给敌方牌手破甲；觉醒按历史触发次数成长。

| 端 | 状态 |
| --- | --- |
| Godot | `armor_break_rules.gd` + `verify_zhen.gd` |
| Web | 破甲/毒伤多为固定伤害或加攻 |

**待核实：** 觉醒历史次数是否计入当前触发 — `units.zhen.verificationPending`。

---

## 6. 凤凰火（`fenghuanghuo`）— **本 PR Web 已修一批**

证据：`research-notes/14-phoenix-rules.md`、`phoenix-balance-2020-02-27`、`phoenix-use-faq-2020`。

### 被动 / 觉醒

| 项 | 原版 | Web（本 PR 前） | Web（本 PR 后） | Godot |
| --- | --- | --- | --- | --- |
| 凤火投射 | 凤凰火使用法术 → 投射 1（焚羽 +1 非战斗） | 无独立投射帧 | `phoenix-spell-used` 结算栈 | `phoenix_rules.gd` |
| 觉醒投射 | 己方式神使用法术 → 投射 1 | 觉醒仅改被动文案/加身材 | 同 Godot 触发条件 | 已专测 |

### 卡牌

| 卡 | 原版 | Web 旧实现 | 本 PR |
| --- | --- | --- | --- |
| c12401 凤鸣 | 瞬发，对牌手 **2** 伤（2020 公告；资料快照 3 冲突） | 3 伤直伤 | 合并核对 2 伤 + 投射 |
| c12402 瑞翔 | 全体敌方式神 1 伤 | 近似 | 合并 + 投射 |
| c12403 焚羽 | 4/6 **替换基础**；非战斗 +1 | +4/+6 叠加 | `setBase` + `formRules.nonCombatDamageBonus` |
| c12404 凤火 | 可选任意存活式神 | 仅敌方 | `any-living-unit` / `selected-any` |
| c12405 炎舞 | 贯通投射 5 + 每次对牌手伤害 +1 | 固定 5  front | 增强计数 `phoenixAvatarHits` + 贯通溢出 |
| c12406 出云 | 5/6 + 用法术时运势 4 得凤火 | 仅身材 | 运势生成（简化骰子，无改骰组合） |
| c12407 引燃 | 击杀后再对**该式神牌手** 2 伤 | 无条件第二段直伤 | `phoenix-ignite` |
| c12408 觉醒 | +1/+1，可重复叠身；觉醒被动 | 一次性 awaken | `awaken-phoenix` |

**仍待核实（核对库已标）：** 魔音反制后是否保留「使用法术」事件、屏障+贯通精细分配、出云与反制/气绝顺序 — `verificationPending` on unit/c12405/c12406。

**测试：** `tests/game-phoenix-verified.test.js`；Godot：`verify_phoenix.gd`（本环境未装 Godot，未执行）。

---

## 7. 桃花妖（`taohuayao`）

证据：`research-notes/15-peach-rules.md`、`peach-official-guide`、`peach-swift-trial`。

### 被动 / 觉醒

治疗/复活友方时给予力量（觉醒永久 +2/+2）。迅捷试炼、气绝时群疗等。

| 端 | 状态 |
| --- | --- |
| Godot | `peach_rules.gd` + `verify_peach.gd` |
| Web | 多为 heal + 固定 buff |

**待核实：** 满血零恢复是否触发成长、气绝后群复活时点 — `units.taohuayao.verificationPending`。

---

## 8. 萤草（`yingcao`）

证据：`research-notes/16-firefly-rules.md`、`firefly-official-guide`、`firefly-may2020-balance`。

### 被动 / 觉醒

形态瞬发抽牌（觉醒：全体形态）；鼓舞仅普攻消耗；点点手牌增强等。

| 端 | 状态 |
| --- | --- |
| Godot | `firefly_rules.gd` + `verify_firefly.gd` |
| Web | 形态/治疗简化 |

衍生 token：`yingcao-zhiyu` 等 3 条在核对库中，Web 未实现生成链。

---

## `npm run audit:rules` 仍失败的原因（本 PR 后）

全库约 **250+ 式神 / 2100+ 卡** 仍在 `game-content*.js` 中保留「可玩化映射」或未经核对。审计摘要（仅统计卡库文本标记，不代表语义等价）：

- 式神：`known-approximation` 154，`unreviewed` 88，`source-backed-native` 5，`pending-verification` 3  
- 卡牌：`known-approximation` 1071，`unreviewed` 975，`source-backed-native` 58，`pending-verification` 10  

**清零条件：** 所有条目 `source-backed-native` 且无 `verificationPending` 未决项 — 当前远未达成。

---

## 本 PR 实际修复范围（摘要）

1. **文档：** 本差距表。  
2. **数据层：** `game-verified-merge.js` + `getCardDefinition` / `getUnitDefinition` 懒合并 `verified_rules.json`。  
3. **规则层（Web）：** 凤凰火 8 张卡 + 被动投射链（`game-phoenix-rules.js` + `game-core.js` 扩展）。  
4. **测试：** `tests/game-phoenix-verified.test.js`；`npm test` 168 项通过。  

**未修复：** 其余 7 式神在 Web 端的倒计时/起源/破甲/形态生命周期/妖琴师大合奏等；全库 audit 未通过。

---

## 建议后续优先级（证据硬度）

1. **妖琴师** — 公告+百科+专测齐全，Web 差距大且独立模块已存在于 Godot。  
2. **鸩** — 破甲系统 `armor_break_rules.gd` 可平移。  
3. **钢风** — 录像+公告硬证据；起源战斗与魔音边界已有 notes。  
4. **大天狗法术复读** — 与钢风共享 countdown/spell 基础设施。  

（优先级供排期参考，不代表用户已授权批量改写。）
