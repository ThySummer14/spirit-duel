# 关键词能力蓝图

更新日期：2026-07-27

## 目标与边界

关键词是内容层复用规则能力的唯一入口。卡牌和角色只声明数据，`game-keywords.js` 负责解释关键词，`game-core.js` 只调用通用生命周期 API。核心规则、AI 和 UI 不得按卡牌 ID 或角色 ID 特判。

当前里程碑实现 14 个关键词，覆盖出牌时机、费用、控制、随机分支、伤害路由、交战修正、回合资源、自动出牌和玩家选择。新增角色应优先组合现有关键词；只有现有生命周期无法表达稳定、可复用的规则时才新增关键词。

## 关键词总表

| 关键词 | ID | 主要配置 | 生命周期或动作 | 状态归属 | 示例卡 |
| --- | --- | --- | --- | --- | --- |
| 响应 | `response` | `timing`, `responseTo` | 响应窗口与结算栈 | `responseWindow` | 霜障 |
| 瞬发 | `instant` | 卡牌关键词 | `modifyCardCost`, `afterCardPlayed` | 玩家 `keywordUsage` | 月幕 |
| 贯通 | `pierce` | 出击效果 | `combatOptions` | 无持久状态 | 熔锋决 |
| 眩晕 | `stun` | `freeze` 效果步骤与持续回合 | 出击/反击合法性 | 角色 `frozen` | 静默霜域、寒束 |
| 远程 | `remote` | 出击效果 | `combatOptions` | 无持久状态 | 疾电 |
| 运势 | `fortune` | `sides`, `threshold` | `beforeCardResolution`, `effectCondition` | 玩家最近一次结果 | 曙针 |
| 鼓舞 | `encourage` | `attack`, `shield` | `applyEffect`, `prepareCombat` | 玩家 `keywordUsage` | 辉月鼓舞 |
| 充能 | `charge` | 角色 `max`, `gainPerTurn`; 卡牌 `chargeCost` | `onTurnStart`, `canPlayCard`, `beforeCardResolution` | 玩家按角色 UID 存储 | 聚雷矢 |
| 倒计时 | `countdown` | `countdown`, `countdownReset` | `beforeRealmTrigger`, `afterRealmTrigger` | 幻境实例 | 焚线 |
| 占卜 | `divination` | `count` 与 `divination` 效果 | 暂停/恢复结算 | `pendingChoice` 与结算帧 | 索引页 |
| 化身 | `incarnation` | `trigger`, `priority` | `automaticCard`, `afterCardPlayed` | 玩家 `keywordUsage` | 残影回环 |
| 融合 | `fusion` | `attack`, `hp`, `maxStacks` | `canPlayCard`, `applyEffect` | 玩家按角色 UID、卡牌 ID 存储 | 云隙之相 |
| 协战 | `coop` | `attackBonus` | `combatOptions`, `afterCombat` | 玩家本回合攻击者列表 | 逐光 |
| 投射 | `projectile` | 自动目标伤害 | `damageRoute` | 无持久状态 | 墨渍 |

## 统一生命周期

关键词定义按 `priority` 和 ID 稳定排序。通用结算顺序如下：

1. 内容校验确认关键词存在、没有重复声明，并验证卡牌或角色配置。
2. `canPlayCard` 检查资源、层数和时机，返回结构化不可用原因。
3. `modifyCardCost` 计算最终鬼火费用。
4. 卡牌进入结算栈；响应牌先于原效果结算。
5. `beforeCardResolution` 支付一次性资源或产生确定性随机结果。
6. 每个数据化效果按 `condition + action + target` 执行；`effectCondition` 可扩展条件，`damageRoute` 可扩展自动目标。
7. 交战前合并 `combatOptions` 和 `prepareCombat` 的数值贡献；只有实际激活的令牌会被消费。
8. 交战后调用 `afterCombat`，出牌结束调用 `afterCardPlayed`。
9. 回合开始调用 `onTurnStart`，幻境触发前后调用对应幻境钩子。
10. UI 仅通过格式化钩子读取关键词状态，不复制规则判断。

公开 API 包括：

- `getKeywordCardPlayabilityBlock()` 与 `getKeywordModifiedCardCost()`
- `applyCardResolutionKeywordHooks()` 与 `getKeywordEffectConditionDecision()`
- `getKeywordDamageRoute()` 与 `getKeywordCombatOptions()`
- `preparePlayerCombatKeywords()` 与 `consumePlayerCombatKeywordActivations()`
- `applyCombatResolvedKeywordHooks()` 与 `getAutomaticKeywordCardTrigger()`
- `prepareRealmKeywordTrigger()` 与 `completeRealmKeywordTrigger()`
- `getPlayerKeywordStatuses()`、`getUnitKeywordStatuses()` 与 `getKeywordStatusText()`
- `validateCardKeywordConfiguration()`、`validateUnitKeywordConfiguration()` 与 `validatePlayerKeywordUsage()`

## 内容配置契约

所有关键词通过 `CARD_KEYWORDS` 常量声明：

```js
keywords: [CARD_KEYWORDS.PROJECTILE]
```

关键词专属字段必须与数据化效果一致。例如融合卡同时声明配置和效果步骤：

```js
fusion: { attack: 1, hp: 1, maxStacks: 2 },
effects: [{
  condition: 'always',
  action: 'apply-keyword',
  target: 'source',
  value: { keywordId: CARD_KEYWORDS.FUSION, attack: 1, hp: 1, maxStacks: 2 },
}],
```

目录校验会拒绝未知关键词、重复关键词、无出击动作的贯通/远程/协战牌、未声明响应关键词的响应牌，以及未声明眩晕关键词的 `freeze` 效果。

## 状态归属

| 状态类型 | 存储位置 | 典型关键词 |
| --- | --- | --- |
| 每回合是否使用 | `player.keywordUsage[keywordId]` | 瞬发、化身 |
| 玩家可消费增益 | `player.keywordUsage[keywordId]` | 鼓舞 |
| 按角色资源 | `player.keywordUsage[keywordId].units[uid]` | 充能 |
| 按角色和卡牌叠层 | `player.keywordUsage.fusion.units[uid].cards[cardId]` | 融合 |
| 本回合攻击者 | `player.keywordUsage.coop.attackers` | 协战 |
| 角色控制状态 | 角色实例 | 眩晕 |
| 幻境计数 | 幻境实例 | 倒计时 |
| 暂停中的玩家选择 | `state.pendingChoice` | 占卜 |
| 暂时结算参数 | 结算帧 | 目标、效果索引、响应上下文 |

结算帧、响应窗口、AI 命令和 UI 统一使用 `targetId`。角色 UID 与幻境 `realm-*` UID 共用这一契约，具体动作再按目标实体类型结算。

状态不得包含 DOM、函数、计时器或运行时监听器。

## 确定性与存档

当前 `GAME_STATE_VERSION` 为 v5。运势使用对局自带的确定性 RNG，不能直接调用 `Math.random()`。占卜候选、结算帧、融合数值与幻境实例均可 JSON 序列化。

恢复时必须拒绝：

- 未知关键词状态或不符合定义的状态结构。
- 占卜候选不再属于对应牌库，或关联结算帧不存在。
- 融合层数越界、累计攻击/生命与每层数值不一致。
- 充能角色引用、当前值或上限与角色配置不一致。

运行时事件队列和执行标记在恢复时清理，不能写入持久存档。

## AI 契约

- AI 只能通过规则层暴露的合法命令操作状态。
- 运势模拟必须使用克隆状态的确定性 RNG。
- 遇到 `pendingChoice.type === 'divination'` 时返回 `divination-choice` 命令。
- 占卜选择优先把下一回合更易使用、评分更高的牌置顶。
- 化身由规则层触发，AI 不伪造免费出牌命令。
- 融合、充能、协战等评分先读取规则层的可用性和模拟结果，不复制规则条件。

## UI 契约

- 卡面展示关键词标签和规则文案；状态文本通过关键词格式化 API 生成。
- 玩家可见文案统一使用“眩晕”，内部 `frozen` 仅为兼容字段。
- 占卜弹层在选择完成前不可关闭，桌面显示多列，390px 移动端显示单列。
- 等待占卜时手牌显示 `choice-wait`；融合达到上限显示 `fusion-max`。
- 融合层数显示在角色卡，协战显示本回合已出击角色数，充能显示当前值/上限。
- 关键词 UI 不得改变前线、后场和手牌席的稳定尺寸，也不得造成页面级横向滚动。

## 组合与优先级

- 多个 `combatOptions` 通过对象合并，攻击加成通过通用数值字段累计。
- 鼓舞采用“准备贡献与激活令牌 → 交战发生后消费”两阶段协议，取消或非法行动不消耗。
- 远程只改变位置和反击规则，不阻止贯通、鼓舞或协战提供数值。
- 投射只负责伤害路由，不改变伤害值和后续伤害事件。
- 运势只决定带条件的效果步骤是否执行，不跳过基础效果。
- 当前响应只支持单层；需要连锁响应时必须先定义优先级、双方连续放弃和栈深限制。

## 融合的当前语义

当前战场固定为四名角色，没有可召唤的同名单位，因此“融合”定义为同一来源角色重复使用同名融合牌并叠加数值。这个语义有明确层数上限、UI 状态和存档校验。

未来若引入召唤单位，单位合体应作为独立扩展：先定义单位所有权、战场槽位、素材移除、状态继承和死亡事件，再决定是否复用 `fusion` ID。不能让当前角色强化语义隐式承担单位合体。

## 测试矩阵

每个关键词至少需要以下证据：

1. 内容配置合法与非法用例。
2. 核心成功路径和不触发路径。
3. 与回合、气绝、响应或前线状态相关的边界用例。
4. 有持久状态时的序列化、恢复和损坏状态拒绝。
5. AI 可见机制的固定局面命令测试。
6. 有专属交互或布局时的桌面、移动端真实浏览器验收。

当前规则测试为 83 项；14 个关键词全部有注册表覆盖，幻境目标、AI 决策、v5 状态存档、双方命令重放、隔离回放帧和会话存档也有专项回归。

## 新角色复用步骤

1. 在 `game-content.js` 定义角色和至少 12 种候选卡。
2. 在卡牌上声明 `keywords: [CARD_KEYWORDS.X]` 和该关键词要求的配置字段。
3. 使用现有 `condition + action + target` 组合效果，不修改 `playCard()`。
4. 运行内容目录校验，修复配置契约错误。
5. 为角色被动与关键词组合增加固定局面测试。
6. 检查 AI 是否能通过现有合法命令使用该卡。
7. 检查构筑标签、不可用原因、战场状态和移动端布局。
8. 运行 `npm test`、`npm run audit` 和真实浏览器验收。

## 新增关键词检查表

只有确认现有关键词和效果步骤无法组合表达时，才执行：

1. 写清触发时机、输入、状态归属、优先级和终止条件。
2. 在 `CARD_KEYWORDS` 与 `KEYWORD_DEFINITIONS` 注册定义。
3. 优先复用现有生命周期；确需新钩子时保持输入输出为纯数据。
4. 增加卡牌/角色/存档配置校验。
5. 通过规则 facade 暴露能力，避免 UI 或 AI 直接读取内部结构。
6. 增加事件与战报文本，让触发过程可观察。
7. 增加成功、失败、组合、存档和 AI 测试。
8. 对新交互完成桌面和移动端验收。
9. 更新本蓝图和 `PROJECT_STATUS.md`。

## 已知限制

- 响应仍为单层，不支持双方连续响应或多层结算栈交互。
- 融合目前是角色强化语义，不是召唤单位合体。
- 幻境已有唯一运行时身份、耐久、受击/摧毁事件和通用 `targetId` 战斗目标契约。
- AI 为一步模拟与可配置评分，尚无难度档位和多步搜索。
