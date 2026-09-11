# 觉醒与 SSR 卡牌设计蓝图

更新日期：2026-09-11（v2 修订：SSR 全线降为 1 费，强度来源改为效果密度与关键词组合；新增「爆能」关键词提案）
状态：**设计稿，尚未实现**。本文档面向 `game-content.js` / `game-core.js` / `game-keywords.js` / `game-collection.js` 的现有架构，所有卡牌效果均映射到「条件 + 动作 + 目标」数据步骤；无法用现有步骤表达的部分在第 8 节单列引擎清单。

数值基准沿用现行规则：核心 30 生命、每回合 2 鬼火、角色 8–13 生命 / 1–3 攻击、同名卡默认 2 张。

---

## 1. 设计目标

1. **被动是角色的锚**：每名角色的觉醒牌直接进化自己的被动，SSR 与被动的运作节奏同频；出什么牌、什么时候觉醒，都围绕被动规划。
2. **SSR 的强度来自密度，不来自费用**：一回合只有 2 鬼火，2 费牌会吞掉整个回合。SSR 统一 **1 费**，真正的成本是 3 勾门槛、牌组限 1 与关键词资源（充能、响应留火、瞬发时机）；强度由效果密度与关键词组合兑现。
3. **充分利用关键词**：25 个注册关键词是这套规则的核心资产。SSR 平均每张约 2 个关键词，战斗牌挂 2–3 个战斗结算类关键词（先攻/连击/贯通/暴击/爆能），法术牌挂节奏与价值类关键词（瞬发/响应/占卜/连引/起源/专注/赐能/投射/不屈/眩晕）；觉醒牌保持「纯被动升级」定位，不抢关键词戏份。
4. **卡池贴合定位**：前线肉搏角色战斗牌占比高，控制与策略角色法术牌占比高；本设计对现有 8 名角色的卡池做了分布审计（第 6 节），结论是现有卡池已基本贴合，无需大改。
5. **纯数据可组合**：新卡不写死 ID 分支，全部走效果步骤与关键词注册表。

> 关于「一组（即两张）SSR」的解读：本设计取「每角色 2 张不同 SSR、牌组各限 1」。若希望对齐《百闻牌》「一张 SSR 可带 2 份」的收集体验，只需把 SSR 的 `deckLimit` 改回 2，卡牌设计本身不变。

---

## 2. 新机制一：觉醒牌

### 2.1 规则

| 项 | 约定 |
| --- | --- |
| 卡牌类型 | `awakening`，卡面标签「觉醒」（新增到 `CARD_TYPE_LABELS`） |
| 数量 | 每名角色恰好 1 张，牌组同名限 1（`deckLimit: 1`） |
| 使用条件 | 角色已升至 **2 勾**；费用 **1 鬼火** |
| 效果 | 角色获得 **+1/+1**（攻击 +1、生命上限 +1），被动永久升级为该角色定义的 `awakenedPassive`；金刚的觉醒额外授予永久不屈（`value.grantUnyielding`） |
| 时机 | 普通时机（`main`），与形态牌同级：**不可被响应**；被眩晕不影响打出（眩晕只封锁出击类动作） |
| 持续性 | 觉醒状态属于角色本身：气绝后倒计时归队、被复活，觉醒被动都保留；被动每回合计数（如弦月）沿用现有 `passiveUsage` 机制，觉醒时重置一次计数 |
| 展示 | 式神録检视层被动名旁显示「觉醒」徽记；打出时战报播报 `PASSIVE_AWAKENED` 事件 |

### 2.2 通用数据形状

```js
// 角色定义新增字段
{
  id: 'ember',
  passive: passive('ember-pursuit', '余烬追击', '……', [...]),
  awakenedPassive: passive('ember-pursuit-awakened', '烬燃冲锋', '……', [...]),
}

// 觉醒牌（八张共用同一结构）
card('awaken-ember', 'ember', '烬燃冲锋', 'awakening', 2,
  '觉醒：赤曜获得 +1/+1，被动「余烬追击」升级为「烬燃冲锋」——赤曜进入前线时，对敌方前线造成 2 点伤害；若敌方前线无人，改为对敌方核心造成 2 点伤害。',
  'auto', 'awaken', null, {
    cost: 1, rarity: 'rare', deckLimit: 1, starterCopies: 1, tags: ['觉醒'],
    effects: [{ condition: 'always', action: 'awaken', target: 'source', value: { attack: 1, hp: 1 } }],
  }),
```

### 2.3 数值取向

觉醒被动相对基础被动约 **×2 或新增一个维度**，不做无上限翻倍。八名角色的觉醒被动见第 5 节。

---

## 3. 新机制二：SSR 稀有度

### 3.1 规则与节奏设计

| 项 | 约定 |
| --- | --- |
| 稀有度 | `ssr`，中文标签「**传说**」，高于 `epic`（史诗） |
| 数量 | 每名角色恰好 2 张，牌组同名限 1（`deckLimit: 1`）；收藏持有上限仍为 2（普通 + 闪卡各一） |
| 门槛 | 统一 **3 勾 1 费**；真正的延迟来自勾玉进度（齐头并进规则下 3 勾通常在第 5–7 回合） |
| 获取 | 不进默认构筑，仅秘闻阁开包 / 御札合成（与「不夜宴席」扩展同一获取路径） |

**1 费的节奏弹性从哪来**——每张 SSR 至少接入一种关键词经济，避免「打出即空过」：

| 弹性来源 | 机制 | 覆盖的 SSR |
| --- | --- | --- |
| 瞬发 | 本回合第一张瞬发牌 **0 费** | 绯天陨火、织月长歌、永夜潮汐、绝对零度、苍狼王之相、仁王无双 |
| 响应 | 对手回合用**留存的鬼火**施放，不占己方回合 | 山陵共鸣 |
| 充能 | 赐能/爆能把**充能当第二货币** | 万雷天引（赐能 3）、雷神一击（爆能） |
| 价值回收 | 占卜/连引/起源把资源**回收到牌库** | 朱笔断罪、织月长歌、永夜潮汐、绯天陨火 |

### 3.2 收藏经济调整（`game-collection.js`）

| 项 | 现值（v2） | 调整后（v3） |
| --- | --- | --- |
| `rarityWeights` | common 0.60 / rare 0.345 / epic 0.055 | common 0.585 / rare 0.33 / epic 0.06 / **ssr 0.025** |
| `dupeValue` | 5 / 25 / 100 | **+ ssr 400** |
| `craftCost` | 40 / 200 / 600 | **+ ssr 2400** |
| 保底 | 25 包必出史诗 | 保留；另加**独立计数 40 包必出 SSR** |
| `RARITY_LABELS` | 常见 / 稀有 / 史诗 | **+ ssr 传说** |

---

## 4. 数值预算对标

SSR 与该角色最接近的现有牌对照。**费用全部 ≤ 对标牌**，增量来自关键词组合与效果密度；「严格更强」的对照都换了形态（更低攻击、更多条件、或改为节奏/资源型）。

| SSR | 费/勾/关键词 | 对标牌（现有效果） | SSR 增益 |
| --- | --- | --- | --- |
| 绯天陨火 | 1 / 3 / 瞬发·起源 | 灼界：1 费，全体 1 伤 + 核心 2 伤 | 全体 2 伤 + 核心 3 伤，瞬发免火，起源循环 |
| 烈焰无间 | 1 / 3 / 先攻·连击·贯通 | 熔锋决：2 费，出击 +3、贯通 | 1 费 +2 攻，先攻 + 连击补足密度 |
| 不动明王阵 | 1 / 3 / —（幻境） | 界碑阵列：前线 1 盾（耐久 5） | **全体** 1 盾（耐久 8） |
| 山陵共鸣 | 1 / 3 / 响应·不屈 | 固阵：1 费单体 4 盾 | 响应时机 + 岚岳 4 盾不屈 + 群体 2 盾 |
| 永夜潮汐 | 1 / 3 / 瞬发·连引 | 余辉唤回：复活满血 | 复活 + 全体 2 疗 + 核心 3 疗 + 连引 |
| 织月长歌 | 1 / 3 / 瞬发·专注·连引 | 折光：1 费抽 2 + 核心 1 疗 | 抽 3 + 核心 2 疗，瞬发免火 |
| 绝对零度 | 1 / 3 / 瞬发·眩晕 | 静默霜域：1 费单体眩晕 | **全体眩晕** + 全体 1 伤 |
| 霜神一刀 | 1 / 3 / 先攻·暴击 | 极霜断：2 费伤害翻倍 | 1 费 +1 攻，先攻 + 暴击 |
| 万雷天引 | 1 / 3 / 投射·赐能 | 聚雷矢：1 费 + 充能 2，5 伤 | 无充能门槛 3 伤；满充能共 6 伤 + 抽 1 |
| 雷神一击 | 1 / 3 / 先攻·贯通·爆能 | 雷光先袭：1 费先攻 | +1 攻贯通，爆能倾泻最多再 +3 |
| 墨海无量 | 1 / 3 / 倒计时（幻境） | 活页归档：每回合抽 1（耐久 3） | 倒计时 2 爆发：抽 2 + 敌前线 2 伤 + 己前线 2 盾（耐久 6） |
| 朱笔断罪 | 1 / 3 / 占卜·起源 | 蚀字：1 费 1 伤 + 1 层晶裂 | 占卜 3 + 3 伤 + 2 层晶裂 + 起源循环 |
| 孤狼一闪 | 1 / 3 / 先攻·贯通 | 狼袭 + 银牙：先攻 / +2 攻各 1 费 | +2 攻先攻贯通，击杀后撤 + 2 盾 |
| 苍狼王之相 | 1 / 3 / 瞬发（形态） | 月牙之相：+2/+1 | +3/+3 + 被动护盾增幅 + 瞬发免火 |
| 仁王无双 | 1 / 3 / 瞬发·不屈 | 不动如山：1 费单体不屈 | **全体不屈** + 金刚 4 盾 3 疗 + 瞬发免火 |
| 怒罗汉崩山 | 1 / 3 / 暴击·贯通 | 崩山拳：2 费伤害翻倍 | 1 费 +1 攻暴击贯通，护盾 ≥3 再 +2 |

---

## 5. 八名角色设计

以下每名角色包含：定位与被动 → 觉醒牌 → 两张 SSR（含数据形状）→ 与被动的联动循环。「新引擎」标注该卡需要的、第 8 节清单中的条目。

### 5.1 赤曜（焰锋 · 爆发/突击）

- **被动「余烬追击」**：赤曜进入前线时，对敌方前线造成 1 点伤害。
- **觉醒「烬燃冲锋」**（awakening · 2 勾 · 1 费）：赤曜获得 +1/+1；被动升级为——进入前线时对敌方前线造成 **2** 点伤害；**若敌方前线无人，改为对敌方核心造成 2 点伤害**。
  - 新引擎：E1（awaken 动作）、P1（余烬追击的空前线分支）。
- **SSR「绯天陨火」**（spell · 3 勾 · 1 费 · 瞬发/起源）：敌方全体角色受到 2 点伤害，敌方核心受到 3 点伤害；起源：将一张「绯天陨火」洗回牌库。
  ```js
  keywords: [CARD_KEYWORDS.INSTANT, CARD_KEYWORDS.ORIGIN],
  effects: [
    { condition: 'always', action: 'damage', target: 'all-enemy-units', value: 2 },
    { condition: 'match-active', action: 'damage', target: 'enemy-avatar', value: 3 },
    { condition: 'always', action: 'origin-shuffle', target: 'ally-player' },
  ],
  ```
  - 新引擎：无（瞬发、起源、全体伤害均为现成机制）。
- **SSR「烈焰无间」**（combat · 3 勾 · 1 费 · 先攻/连击/贯通）：赤曜出击，本次攻击 +2，先攻、连击且贯通。
  ```js
  keywords: [CARD_KEYWORDS.FIRST_STRIKE, CARD_KEYWORDS.COMBO, CARD_KEYWORDS.PIERCE],
  effect: 'assault', value: 2,
  ```
  - 新引擎：无（三个战斗结算关键词全部现成）。
- **联动循环**：灰烬锁/烬印（晶裂放大伤害）→ 频繁出击触发余烬追击 → 2 勾觉醒后空前线也能烧核心 → 绯天陨火作为回合第一张瞬发牌**免费**清场斩核心，起源让它长局回流；烈焰无间是密度上限：先攻免反击、连击双段、贯通溢出烧牌手。1 费意味着同一回合还能补一张战斗牌或基础出击。

### 5.2 岚岳（垒卫 · 护阵/站场）

- **被动「岩壁」**：己方回合开始时，若岚岳位于前线，获得 1 点护盾。
- **觉醒「山岳壁垒」**（awakening · 2 勾 · 1 费）：岚岳获得 +1/+1；被动升级为——己方回合开始时，若位于前线，获得 **2** 点护盾，**且己方核心恢复 1 点生命**。
  - 新引擎：E1、P2（岩壁的护盾 + 核心回复组合）。
- **SSR「不动明王阵」**（realm · 3 勾 · 1 费）：幻境（耐久 8）：己方回合开始时，所有己方存活角色获得 1 点护盾。
  ```js
  realm: { hp: 8, trigger: 'owner-turn-start', triggerEffect: 'shield-all-allies', triggerValue: 1 },
  ```
  - 新引擎：E5（幻境触发效果 shield-all-allies）。
- **SSR「山陵共鸣」**（spell · 3 勾 · 1 费 · 响应/不屈）：响应伤害、出击或护盾：岚岳获得 4 点护盾与不屈，己方其他存活角色各获得 2 点护盾。
  ```js
  timing: 'response', responseTo: ['damage', 'assault', 'shield'],
  keywords: [CARD_KEYWORDS.RESPONSE, CARD_KEYWORDS.UNYIELDING],
  effects: [
    { condition: 'always', action: 'shield', target: 'source', value: 4 },
    { condition: 'always', action: 'grant-unyielding', target: 'source', value: 1 },
    { condition: 'always', action: 'shield', target: 'all-other-allies', value: 2 },
  ],
  ```
  - 新引擎：E4（目标 all-other-allies）。
- **联动循环**：镇守/重岩誓约进前线 → 岩壁逐回合攒盾，觉醒后核心也开始回血 → 不动明王阵把护盾雨铺满全队。山陵共鸣是**对手回合的答案**：对方爆发回合结束时留 1 点鬼火，响应窗口里一口气补 8+ 点护盾并给岚岳挂不屈——不占自己回合的节奏，这正是坦克该有的反应姿态。

### 5.3 弦月（织光 · 恢复/调度）

- **被动「月返」**：每个己方回合第一次使用弦月牌后，己方核心恢复 1 点生命。
- **觉醒「望月回响」**（awakening · 2 勾 · 1 费）：弦月获得 +1/+1；被动升级为——每个己方回合第一次使用弦月牌后，己方核心恢复 **2** 点生命；**若该牌为法术牌，抽 1 张牌**。
  - 新引擎：E1、P3（月返的卡牌类型判定；`CARD_PLAYED` 事件 payload 需带 `cardType`）。
- **SSR「织月长歌」**（spell · 3 勾 · 1 费 · 瞬发/专注/连引）：抽 1 张牌，己方核心恢复 2 点生命；专注：若这是本回合使用的第一张牌，再抽 1 张；连引：抽取牌库中下一张弦月的牌。
  ```js
  keywords: [CARD_KEYWORDS.INSTANT, CARD_KEYWORDS.FOCUS, CARD_KEYWORDS.CHAIN],
  effects: [
    { condition: 'always', action: 'draw', target: 'ally-player', value: 1 },
    { condition: 'always', action: 'heal-avatar', target: 'ally-avatar', value: 2 },
    { condition: 'always', action: 'focus-draw', target: 'ally-player', value: 1 },
    { condition: 'always', action: 'chain-draw', target: 'ally-player' },
  ],
  ```
  - 新引擎：无（瞬发、专注、连引全部现成）。
- **SSR「永夜潮汐」**（spell · 3 勾 · 1 费 · 瞬发/连引）：唤醒一名离场角色，回复全部生命；己方全体存活角色恢复 2 点生命，己方核心恢复 3 点生命；连引：抽取牌库中下一张弦月的牌。
  ```js
  keywords: [CARD_KEYWORDS.INSTANT, CARD_KEYWORDS.CHAIN],
  effects: [
    { condition: 'always', action: 'revive', target: 'selected-ally', value: 4 },
    { condition: 'always', action: 'heal', target: 'all-ally-units', value: 2 },
    { condition: 'always', action: 'heal-avatar', target: 'ally-avatar', value: 3 },
    { condition: 'always', action: 'chain-draw', target: 'ally-player' },
  ],
  ```
  - 新引擎：E4（目标 all-ally-units 扩展到 heal）。
- **联动循环**：弦月手牌密度高（折光/凝神一注）→ 每回合第一张弦月牌稳定触发月返 → 觉醒后法术占比高的卡池让「回 2 + 抽 1」几乎每回合兑现 → 织月长歌作为首张瞬发牌免费铺资源（专注 + 连引最多抽 3），永夜潮汐在减员回合一口气拉回全员状态并复活。治疗 + 调度定位，攻击最低、法术最多。

### 5.4 白棱（霜刃 · 控制/破防）

- **被动「霜痕」**：白棱完成一次与敌方角色的交战后，眩晕该角色。
- **觉醒「霜噬」**（awakening · 2 勾 · 1 费）：白棱获得 +1/+1；被动升级为——完成与敌方角色的交战后，眩晕该角色**并使其进入 1 层晶裂**。
  - 新引擎：E1、P4（霜痕追加晶裂）。
- **SSR「绝对零度」**（spell · 3 勾 · 1 费 · 瞬发/眩晕）：眩晕敌方全体存活角色，并对每名敌方角色造成 1 点伤害。
  ```js
  keywords: [CARD_KEYWORDS.INSTANT, CARD_KEYWORDS.STUN],
  effects: [
    { condition: 'always', action: 'freeze', target: 'all-enemy-units', value: 1 },
    { condition: 'always', action: 'damage', target: 'all-enemy-units', value: 1 },
  ],
  ```
  - 新引擎：E6（freeze 支持全体目标）。
- **SSR「霜神一刀」**（combat · 3 勾 · 1 费 · 先攻/暴击）：白棱出击，本次攻击 +1，先攻且暴击。
  ```js
  keywords: [CARD_KEYWORDS.FIRST_STRIKE, CARD_KEYWORDS.CRIT], effect: 'assault', value: 1,
  ```
  - 新引擎：无。
- **联动循环**：霜痕让每个与白棱对撞的单位下回合瘫痪 → 觉醒后对撞同时挂晶裂，与晶裂/裂霜线的增伤乘区咬合 → 绝对零度作为**免费的首张瞬发牌**锁死敌方全场一回合，随后 2 鬼火完整留给追击；霜神一刀（先攻暴击双倍）配晶裂往往是那记终结。控制定位，法术过半（10/18）。

### 5.5 霆鸢（鸣羽 · 连击/压制）

- **被动「追风」**：霆鸢从后场换入前线完成交战后，对敌方核心造成 1 点伤害。角色关键词：充能（上限 3，每回合 +1）。
- **觉醒「疾风怒涛」**（awakening · 2 勾 · 1 费）：霆鸢获得 +1/+1；被动升级为——从后场换入前线完成交战后，对敌方核心造成 **2** 点伤害；**每次完成交战后获得 1 点充能**。
  - 新引擎：E1、P5（交战后充能；受角色 charge 配置的上限约束）。
- **SSR「万雷天引」**（spell · 3 勾 · 1 费 · 投射/赐能）：投射：对敌方前线造成 3 点伤害，前线空缺或被击破时改为伤害敌方核心；赐能 3：若霆鸢充能不小于 3，消耗 3 点，追加 3 点投射伤害并抽 1 张牌。
  ```js
  target: 'auto', // 卡面目标与墨渍同构：无需手选，投射路由接管每一段伤害
  keywords: [CARD_KEYWORDS.PROJECTILE, CARD_KEYWORDS.BESTOW], bestow: { cost: 3 },
  effects: [
    { condition: 'always', action: 'damage', target: 'selected-enemy', value: 3 },
    { condition: 'bestow-ready', action: 'damage', target: 'selected-enemy', value: 3 },
    { condition: 'bestow-ready', action: 'draw', target: 'ally-player', value: 1 },
  ],
  ```
  - 新引擎：无（伤害步骤目标沿用投射卡现有的 `selected-enemy` 形状，由 damageRoute 改写路由：第一段击破前线后，第二段自然流向核心；赐能现成）。
- **SSR「雷神一击」**（combat · 3 勾 · 1 费 · 先攻/贯通/爆能）：霆鸢出击，本次攻击 +1，先攻且贯通；爆能：额外消耗当前全部充能，每消耗 1 点充能，本次攻击再 +1。
  ```js
  keywords: [CARD_KEYWORDS.FIRST_STRIKE, CARD_KEYWORDS.PIERCE, CARD_KEYWORDS.BURST],
  burst: { perCharge: 1 },
  effect: 'assault', value: 1,
  ```
  - 新引擎：E7（新关键词「爆能」，见 8.2）。
- **联动循环**：疾电/雷走的换位节奏触发追风磨核心 → 觉醒后磨血翻倍、每次交战都攒充能 → 充能经济成为每回合的真实抉择：**攒满 3 点放万雷天引**（6 伤 + 抽牌，还会因投射连段追击核心）还是**随时倾泻进雷神一击**（满充能 +4 攻先攻贯通）。两张 SSR 共享同一货币、互为节奏两端。

### 5.6 玄砚（墨相 · 策略/消耗）

- **被动「墨护」**：玄砚存活时，己方部署幻境后，当前前线获得 1 点护盾。
- **觉醒「墨守万相」**（awakening · 2 勾 · 1 费）：玄砚获得 +1/+1；被动升级为——玄砚存活时，己方部署幻境后，当前前线获得 **2** 点护盾，**且该幻境耐久 +2**。
  - 新引擎：E1、P6（墨护追加耐久）。
- **SSR「墨海无量」**（realm · 3 勾 · 1 费 · 倒计时）：幻境（耐久 6，倒计时 2）：己方回合开始时推进倒计时；归零时抽 2 张牌、对敌方前线造成 2 点伤害、己方前线角色获得 2 点护盾，然后重置倒计时。
  ```js
  keywords: [CARD_KEYWORDS.COUNTDOWN],
  realm: {
    hp: 6, trigger: 'owner-turn-start',
    countdown: 2, countdownReset: 2,
    triggerEffects: [
      { effect: 'draw', value: 2 },
      { effect: 'damage-enemy-front', value: 2 },
      { effect: 'shield-front', value: 2 },
    ],
  },
  ```
  - 新引擎：E8（幻境多效果触发数组；倒计时现成）。
- **SSR「朱笔断罪」**（spell · 3 勾 · 1 费 · 占卜/起源）：占卜 3：检视牌库顶 3 张牌并将一张置于牌库顶；然后对一名敌方角色造成 3 点伤害，若其存活，使其进入 2 层晶裂；起源：将一张「朱笔断罪」洗回牌库。
  ```js
  keywords: [CARD_KEYWORDS.DIVINATION, CARD_KEYWORDS.ORIGIN],
  divination: { count: 3 },
  effects: [
    { condition: 'always', action: 'divination', target: 'ally-player', value: 3 },
    { condition: 'always', action: 'damage', target: 'selected-enemy', value: 3 },
    { condition: 'target-alive', action: 'apply-brittle', target: 'selected-enemy', value: 2 },
    { condition: 'always', action: 'origin-shuffle', target: 'ally-player' },
  ],
  ```
  - 新引擎：E9（验证占卜暂停后同卡后续步骤继续结算；结算栈按序应已支持，需补测试）。
- **联动循环**：玄砚的幻境数量与岚岳并列全队最多（活页归档/封缄书库/墨海无量共 3 张）→ 每次部署都被墨护转化为防线，觉醒后还加厚幻境耐久（更难被拆）→ 墨海无量每两回合一次「抽牌/消耗/护盾」三联爆发，朱笔断罪是占卜定序后的精准处刑，起源让两张 SSR 都能长局回流。纯策略法师定位，战斗牌仅 1 张。

### 5.7 银狼（狼牙 · 游击/连击）

- **被动「刃胄」**：银狼完成一次交战后，获得 1 点护盾。
- **觉醒「狼王胄」**（awakening · 2 勾 · 1 费）：银狼获得 +1/+1；被动升级为——完成一次交战后，获得 **2** 点护盾；**若此交战击倒了敌方角色，攻击 +1**。
  - 新引擎：E1、P7（刃胄强化 + 击杀成长；攻击成长走 E3 管线）。
- **SSR「孤狼一闪」**（combat · 3 勾 · 1 费 · 先攻/贯通）：银狼出击，本次攻击 +2，先攻且贯通；若击倒目标，银狼返回准备区并获得 2 点护盾。
  ```js
  keywords: [CARD_KEYWORDS.FIRST_STRIKE, CARD_KEYWORDS.PIERCE],
  effect: 'assault', value: 2,
  afterCombat: { onKill: 'return-to-reserve', shield: 2 },
  ```
  - 新引擎：E10（交战后置：击杀则撤回准备区 + 护盾）。
- **SSR「苍狼王之相」**（form · 3 勾 · 1 费 · 瞬发）：银狼获得 +3/+3；此后银狼完成交战后获得的护盾 +1（「刃胄」与「狼王胄」均受此加成）。
  ```js
  keywords: [CARD_KEYWORDS.INSTANT],
  effect: 'form', value: { attack: 3, hp: 3 },
  passiveAmp: { aegisBonus: 1 },
  ```
  - 新引擎：E11（被动护盾增幅标记；与觉醒被动叠加时每回合 3 盾）。
- **联动循环**：贴脸换血 → 每次交战刃胄回盾把换血变成白嫖 → 觉醒后 2 盾 + 击杀加攻，滚雪球成中后期主战力 → 苍狼王之相作为**免费首张瞬发牌**完成变身再全回合行动；孤狼一闪是游击的终极形态——先攻杀掉目标后撤回准备区（不给对方反击回合）并带回 2 盾。战斗牌占比全队最高。

### 5.8 金刚（不坏 · 铁壁/不屈）

- **被动「石肤」**：己方回合开始时，若金刚位于前线，恢复 1 点生命。
- **觉醒「不坏金身」**（awakening · 2 勾 · 1 费）：金刚获得 +1/+1 与**不屈**；被动升级为——己方回合开始时，若位于前线，恢复 **2** 点生命**并获得 1 点护盾**。
  - 新引擎：E1（value.grantUnyielding）、P8（石肤的回复 + 护盾组合）。
- **SSR「仁王无双」**（spell · 3 勾 · 1 费 · 瞬发/不屈）：己方全体存活角色获得不屈；金刚获得 4 点护盾并恢复 3 点生命。
  ```js
  keywords: [CARD_KEYWORDS.INSTANT, CARD_KEYWORDS.UNYIELDING],
  effects: [
    { condition: 'always', action: 'grant-unyielding', target: 'all-ally-units', value: 1 },
    { condition: 'always', action: 'shield', target: 'source', value: 4 },
    { condition: 'always', action: 'heal', target: 'source', value: 3 },
  ],
  ```
  - 新引擎：E4（目标 all-ally-units）。
- **SSR「怒罗汉崩山」**（combat · 3 勾 · 1 费 · 暴击/贯通）：金刚出击，本次攻击 +1，暴击且贯通；若金刚当前护盾不低于 3 点，本次攻击额外 +2。
  ```js
  keywords: [CARD_KEYWORDS.CRIT, CARD_KEYWORDS.PIERCE],
  effect: 'assault', value: 1,
  combatOption: { shieldThreshold: 3, bonusAttack: 2 },
  ```
  - 新引擎：E12（combatOptions 护盾门槛加成）。
- **联动循环**：13 生命 + 石肤让金刚是全队最稳的前线 → 觉醒获得不屈 + 「回 2 + 1 盾」，彻底变成拆不掉的堡垒 → 仁王无双作为**免费首张瞬发牌**把不屈铺给全队（对方斩杀回合的终极答案）；怒罗汉崩山把防御经济转化为爆发：攒着的护盾越多这一拳越重（护盾 ≥3 时 2+1+2 攻再翻倍，溢出贯通）。铁壁定位，战斗与防护法术均衡分布。

---

## 6. 卡池分布审计（含新增后）

现有卡池已按定位分布，本次只做加法。新增后各角色类型分布：

| 角色 | 战斗 | 法术 | 形态 | 幻境 | 觉醒 | 合计 | 定位核对 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 赤曜 | 4→**5** | 8→**9** | 2 | 1 | **1** | 15→**18** | 突击手：战斗 + 直伤为主 ✓ |
| 岚岳 | 3 | 8→**9** | 2 | 2→**3** | **1** | 15→**18** | 坦克：防护法术 + 幻境 ✓ |
| 弦月 | 1 | 11→**13** | 2 | 1 | **1** | 15→**18** | 治疗/调度：法术占 72% ✓ |
| 白棱 | 4→**5** | 9→**10** | 2 | 0 | **1** | 15→**18** | 控制：法术为主 + 少量高质战斗 ✓ |
| 霆鸢 | 3→**4** | 8→**9** | 2 | 2 | **1** | 15→**18** | 连击/压制：战斗 + 直伤均衡 ✓ |
| 玄砚 | 1 | 10→**11** | 2 | 2→**3** | **1** | 15→**18** | 策略：法术 + 幻境最多 ✓ |
| 银狼 | 5→**6** | 6 | 1→**2** | 0 | **1** | 12→**15** | 游击决斗家：战斗占比最高 ✓ |
| 金刚 | 4→**5** | 6→**7** | 1 | 1 | **1** | 12→**15** | 铁壁：战斗 + 防护均衡 ✓ |

新增 24 张（8 觉醒 + 16 SSR）后全卡池 **114 → 138** 种。一条顺带修正建议：银狼的 1 费法术「刃胄」与被动同名但效果是通用护盾，建议改名为「狼革」避免与觉醒被动「狼王胄」在战报里混淆。

---

## 7. 默认构筑调整

觉醒牌进默认构筑（`starterCopies: 1`），每套默认构筑让出一个后期名额，总数保持 8 张不变；SSR 全部为收集内容（`starterCopies: 0`）。

| 角色 | 调整 | 调整后默认构筑 |
| --- | --- | --- |
| 赤曜 | 灼界 ×2→×1，+烬燃冲锋 ×1 | 焰闪×2 烬印×2 赤炼之躯×2 灼界×1 烬燃冲锋×1 |
| 岚岳 | 界碑阵列 ×2→×1，+山岳壁垒 ×1 | 固阵×2 镇守×2 山门之相×2 界碑阵列×1 山岳壁垒×1 |
| 弦月 | 余辉唤回 ×2→×1，+望月回响 ×1 | 回响疗愈×2 折光×2 月环之相×2 余辉唤回×1 望月回响×1 |
| 白棱 | 晶裂 ×2→×1，+霜噬 ×1 | 冰脉斩×2 静默霜域×2 冰镜之相×2 晶裂×1 霜噬×1 |
| 霆鸢 | 引雷天网 ×2→×1，+疾风怒涛 ×1 | 雷走×2 鸣闪×2 惊雷之翼×2 引雷天网×1 疾风怒涛×1 |
| 玄砚 | 活页归档 ×2→×1，+墨守万相 ×1 | 墨障×2 蚀字×2 无相墨躯×2 活页归档×1 墨守万相×1 |
| 银狼 | 刃胄 ×2→×1，+狼王胄 ×1 | 霜咬×2 连霜双击×2 狼袭×2 刃胄×1 狼王胄×1 |
| 金刚 | 金刚不坏 ×2→×1，+不坏金身 ×1 | 岩拳×2 山岳之誓×2 震地踏×1 金身之相×1 金刚不坏×1 不坏金身×1 |

> 金刚默认构筑原为 岩拳×2 + 山岳之誓×2 + 金刚不坏×2 + 金身之相×1 + 震地踏×1，减一张金刚不坏后维持 8 张。

---

## 8. 引擎落地清单

### 8.1 内容与校验（game-content.js）

- C1 `CARD_TYPE_LABELS` 增加 `awakening: '觉醒牌'`；角色定义增加 `awakenedPassive`。
- C2 卡牌定义支持 `deckLimit`（默认 = `copiesPerCard`）；`validateDeckDefinition` 按卡牌级 `deckLimit` 校验同名上限。
- C3 `validateContentCatalog`：`knownRarities` 增加 `ssr`；新增结构校验——每名角色恰好 1 张觉醒牌（类型 awakening、`deckLimit: 1`、声明了 `awakenedPassive`）与恰好 2 张 SSR；觉醒牌的 `effects` 只允许 `awaken` 步骤。

### 8.2 核心规则（game-core.js）与关键词（game-keywords.js）

- **E1 `awaken` 动作**：读取来源角色的 `awakenedPassive`，整体替换 `unit.passive`，重置该被动的 `passiveUsage` 计数，按 value 给 +1/+1，`value.grantUnyielding` 为真时设置 `unit.unyielding = true`（金刚），广播 `PASSIVE_AWAKENED` 事件。
- **E2 序列化**：`serializeGame` / `deserializeGame` 校验觉醒后的 `unit.passive` 与角色 `awakenedPassive` 定义一致；`GAME_STATE_VERSION` 递增。
- **E3 `stat-growth` 动作（攻击成长管线）**：新增 `unit.attackBonus`（非形态来源的永久攻击成长）。攻击计算统一为 `baseAttack + attackBonus + formBonus`；烹饪 +1 改走 `attackBonus`（顺带修复现有「后出的形态会清掉烹饪加成」的问题——当前 `applyForm` 直接 `unit.attack = unit.baseAttack + bonus`，会覆盖烹饪与任何成长）。v2 中仅「狼王胄」击杀加攻依赖该管线。
- **E4 新目标与来源指向**：`all-ally-units`（heal / shield / grant-unyielding 通用，跳过 `hp <= 0`）、`all-other-allies`（shield）；同时让 shield / heal / grant-unyielding 处理器支持 `target: 'source'` 的来源单位语义（当前只有 assault / fortify / form 走 sourceIndex，`山陵共鸣`、`仁王无双` 依赖此扩展）。
- **E5 幻境触发效果**：`shield-all-allies`。
- **E6 `freeze` 全体目标**：绝对零度。
- **E7 新关键词「爆能 burst」**（雷神一击）：充能经济的「全部倾泻」端，参照鼓舞的两阶段协议——`beforeCardResolution` 读取来源角色当前充能、按 `burst.perCharge` 折算并清空充能、把倾泻值写入 `keywordUsage.burst.pending`；`combatOptions` 读取 pending 折算 `attackBonus`；`afterCardPlayed` 清理 pending。`validateCard`：卡牌须含出击动作并声明 `burst` 配置；存档校验 pending 结构；0 充能时可正常打出（倾泻 +0）。注册进 `CARD_KEYWORDS` / `KEYWORD_DEFINITIONS`，按 KEYWORD_BLUEPRINT 的新增关键词检查表走全流程（含战报与状态展示「本次倾泻 +N」）。
- **E8 幻境 `triggerEffects` 数组**：按序结算多效果（墨海无量；倒计时为现成机制）。
- **E9 占卜后续步骤**：占卜暂停恢复后继续同卡后续 effectIndex（补测试，预期结算栈已支持）。
- **E10 交战后置 `on-kill-return-to-reserve`**：本次交战击倒目标 → 来源撤回准备区（清 `frontUnitId`）+ 护盾。
- **E11 被动增幅标记**：`unit.passiveAmp.aegisBonus`，刃胄/狼王胄 handler 读取。
- **E12 `combatOptions` 护盾门槛**：`shieldThreshold` + `bonusAttack`。
- **P1–P8 觉醒被动 handler**（复用现有事件，全部纯数据）：
  - P1 烬燃冲锋：`passive-damage-enemy-front` 加 `fallbackAvatar` 参数分支。
  - P2 山岳壁垒：岩壁 + 核心 1 疗。
  - P3 望月回响：月返 + `cardType === 'spell'` 抽牌（`CARD_PLAYED` payload 增加 `cardType`）。
  - P4 霜噬：霜痕 + 1 层晶裂。
  - P5 疾风怒涛：追风 2 伤 + 每次交战 +1 充能（写 `keywordUsage.charge`，受上限约束；觉醒时充能上限不变仍为 3）。
  - P6 墨守万相：墨护 2 盾 + 幻境耐久 +2。
  - P7 狼王胄：刃胄 2 盾 + `!defenderSurvived` 时攻击成长（走 E3）。
  - P8 不坏金身：石肤回 2 + 1 盾。

> v1 中的「revive value 对象化」已删除：永夜潮汐简化为复活 + 群体治疗 + 连引，不再需要复活附加成长。瞬发/响应/起源/连引/专注/赐能/投射/倒计时全部复用现有关键词，无新增引擎工作。

### 8.3 收藏（game-collection.js）

- 第 3.2 节的经济表；`CARDS_BY_RARITY` 纳入 `ssr` 键；`COLLECTION_RULES.version` 升 3；40 包 SSR 独立保底计数器进存档校验。

### 8.4 UI（battle-render / formation / app / styles）

- 觉醒牌专属卡面轮廓与 SSR（传说）配色（`styles.css` / `formation.css` 稀有度色阶延伸）。
- 式神録被动区：觉醒后被动名 + 「觉醒」徽记；战报播报觉醒。
- 构筑页：牌组内同名计数按 `deckLimit` 显示上限；SSR 标签「传说」。
- 幻境多效果触发的战报按序拆条播报；爆能倾泻值在出牌预览与战报中可见。

### 8.5 AI（game-ai.js）

- 觉醒牌：中期（2 勾当回合空闲鬼火）倾向打出，评分参考被动升级收益的静态估值。
- SSR：走现有效果模拟评分；爆能的充能清空与攻击加成在模拟中由规则层钩子自然体现，AI 无需特判。
- 山陵共鸣的响应决策复用现有 AI 响应评分（收益 = 潜在受击护盾 + 不屈价值）。
- 占卜 + 伤害组合牌沿用现有 `divination-choice` 命令。

---

## 9. 测试矩阵

1. **内容契约**：每角色 1 觉醒 / 2 SSR 数量校验；缺 `awakenedPassive`、觉醒牌带非 awaken 步骤、未知稀有度 `ssr`（旧目录）、`deckLimit` 超限均被拒绝。
2. **觉醒**：打出后被动文本与 hooks 替换、`passiveUsage` 重置、+1/+1 生效、金刚不屈授予、气绝归队/复活后觉醒保留、序列化往返一致、伪造被动被拒绝。
3. **各觉醒被动**：触发 / 不触发（条件不满足）/ 与基础被动相同事件的边界（P1 空前线、P3 法术判定、P5 充能上限、P7 击杀判定）。
4. **SSR**：16 张逐一的成功路径与边界——瞬发免火仅每回合第一张、响应牌在对手回合消耗留存鬼火、投射两段伤害的路由连段、赐能 3 的充能门槛、爆能倾泻清零与 0 充能兜底、全体冻结跳过死者、击杀撤回、幻境多效果顺序、占卜后续步骤、护盾门槛。
5. **攻击成长管线**：烹饪 / 狼王胄击杀成长 / 后出形态三者叠加与被覆盖的回归（修复项）。
6. **收藏**：ssr 权重分布、40 包保底、折算 400 / 合成 2400、v2→v3 存档兼容。
7. **AI**：觉醒命令、SSR 出牌、爆能倾泻与攒充能的抉择、山陵共鸣响应的固定局面断言。
8. **验收**：`npm test`、`npm run smoke`（30 局，加入新卡的默认构筑与随机编成）、`npm run audit`、桌面 + 390px 移动端真实浏览器对局（觉醒播报、SSR 卡面、牌组上限提示）。

---

## 10. 实施顺序建议

1. 引擎骨架：C1–C3 + E1–E4（awakening 类型、awaken 动作、deckLimit、ssr 稀有度注册、攻击成长管线）+ 对应测试。
2. 八张觉醒牌与 P1–P8 + 序列化（E2）+ 测试；默认构筑切换（第 7 节）。
3. 十六张 SSR 与 E5–E12（含「爆能」关键词的注册表全流程）+ 测试。
4. 收藏经济（8.3）与 UI（8.4）。
5. AI 评分（8.5）、全量验收（第 9 节）、平衡微调一轮（重点观察：绝对零度的锁场强度、万雷天引与雷神一击的充能抉择、瞬发 SSR 的免费节奏、银狼觉醒滚雪球速度）。
