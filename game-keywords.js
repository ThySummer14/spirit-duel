export const CARD_KEYWORDS = Object.freeze({
  RESPONSE: 'response',
  INSTANT: 'instant',
  PIERCE: 'pierce',
  STUN: 'stun',
  REMOTE: 'remote',
  FORTUNE: 'fortune',
  ENCOURAGE: 'encourage',
  CHARGE: 'charge',
  COUNTDOWN: 'countdown',
  DIVINATION: 'divination',
  INCARNATION: 'incarnation',
  FUSION: 'fusion',
  COOP: 'coop',
  PROJECTILE: 'projectile',
});

function defineKeyword(definition) {
  return Object.freeze({ priority: 50, ...definition });
}

function keywordUsageFor(player, keywordId) {
  if (!player.keywordUsage || typeof player.keywordUsage !== 'object' || Array.isArray(player.keywordUsage)) {
    player.keywordUsage = {};
  }
  const existing = player.keywordUsage[keywordId];
  if (existing !== undefined && (!existing || typeof existing !== 'object' || Array.isArray(existing))) {
    throw new Error(`关键词 ${keywordId} 的状态结构无效。`);
  }
  if (!existing) player.keywordUsage[keywordId] = {};
  return player.keywordUsage[keywordId];
}

function readKeywordUsage(player, keywordId) {
  return player.keywordUsage?.[keywordId] ?? {};
}

export const KEYWORD_DEFINITIONS = Object.freeze([
  defineKeyword({
    id: CARD_KEYWORDS.RESPONSE,
    label: '响应',
    description: '在对手待结算动作匹配时，可于响应窗口打出。',
    validateCard: (card) => (
      card.timing === 'response' && card.responseTo.length > 0
        ? []
        : [`${card.name} 的响应时机或触发动作配置无效。`]
    ),
  }),
  defineKeyword({
    id: CARD_KEYWORDS.INSTANT,
    label: '瞬发',
    description: '持有者行动回合内，第一张瞬发牌不消耗鬼火。',
    costReductionLabel: '瞬发 · 免火',
    onTurnStart: ({ player }) => {
      keywordUsageFor(player, CARD_KEYWORDS.INSTANT).used = false;
    },
    modifyCardCost: ({ state, playerIndex, player, cost }) => {
      const usage = readKeywordUsage(player, CARD_KEYWORDS.INSTANT);
      const available = state.currentPlayer === playerIndex
        && state.responseWindow === null
        && !usage.used;
      return available ? 0 : cost;
    },
    afterCardPlayed: ({ player, effectiveCost }) => {
      if (effectiveCost === 0) keywordUsageFor(player, CARD_KEYWORDS.INSTANT).used = true;
    },
    validateUsage: (usage) => (
      usage && typeof usage === 'object' && !Array.isArray(usage) && typeof usage.used === 'boolean'
    ),
  }),
  defineKeyword({
    id: CARD_KEYWORDS.PIERCE,
    label: '贯通',
    description: '对角色造成气绝时，将真实溢出伤害转移给敌方核心。',
    combatOptions: () => ({ pierce: true }),
    validateCard: (card) => (
      card.effects?.some((effect) => effect.action === 'assault')
        ? []
        : [`${card.name} 的贯通关键词只能用于包含出击动作的卡牌。`]
    ),
  }),
  defineKeyword({
    id: CARD_KEYWORDS.STUN,
    label: '眩晕',
    description: '被眩晕的角色无法出击或反击，在其持有者回合结束时减少持续回合。',
    validateCard: (card) => (
      card.effects?.some((effect) => effect.action === 'freeze' && Number.isInteger(effect.value) && effect.value > 0)
        ? []
        : [`${card.name} 的眩晕效果配置无效。`]
    ),
  }),
  defineKeyword({
    id: CARD_KEYWORDS.REMOTE,
    label: '远程',
    description: '从当前位置发动攻击，不改变己方前线，且本次攻击不会受到反击。',
    combatOptions: () => ({ remote: true }),
    validateCard: (card) => (
      card.effects?.some((effect) => effect.action === 'assault')
        ? []
        : [`${card.name} 的远程关键词只能用于包含出击动作的卡牌。`]
    ),
  }),
  defineKeyword({
    id: CARD_KEYWORDS.FORTUNE,
    label: '运势',
    description: '结算前投掷指定面数的骰子，达到阈值时触发运势成功步骤。',
    beforeCardResolution: ({ player, card, random }) => {
      const roll = Math.floor(random() * card.fortune.sides) + 1;
      const result = {
        roll,
        sides: card.fortune.sides,
        threshold: card.fortune.threshold,
        success: roll >= card.fortune.threshold,
      };
      keywordUsageFor(player, CARD_KEYWORDS.FORTUNE).last = result;
      return { eventType: 'fortune-rolled', payload: result };
    },
    effectCondition: ({ condition, player }) => {
      if (condition !== 'fortune-success') return undefined;
      return readKeywordUsage(player, CARD_KEYWORDS.FORTUNE).last?.success === true;
    },
    formatSpendLog: ({ source, value }) => (
      `${source.name} 的运势骰子为 ${value.payload.roll}/${value.payload.sides}`
      + `${value.payload.success ? '，运势成功。' : '，未达成。'}`
    ),
    validateUsage: (usage) => {
      const last = usage?.last;
      return usage
        && typeof usage === 'object'
        && !Array.isArray(usage)
        && last
        && Number.isInteger(last.roll)
        && Number.isInteger(last.sides)
        && Number.isInteger(last.threshold)
        && last.roll >= 1
        && last.roll <= last.sides
        && last.threshold >= 1
        && last.threshold <= last.sides
        && typeof last.success === 'boolean';
    },
    validateCard: (card) => {
      const valid = Number.isInteger(card.fortune?.sides)
        && card.fortune.sides >= 2
        && Number.isInteger(card.fortune?.threshold)
        && card.fortune.threshold >= 1
        && card.fortune.threshold <= card.fortune.sides
        && card.effects?.some((effect) => effect.condition === 'fortune-success');
      return valid ? [] : [`${card.name} 的运势配置无效。`];
    },
  }),
  defineKeyword({
    id: CARD_KEYWORDS.ENCOURAGE,
    label: '鼓舞',
    description: '可叠加至己方战意；下一次出击获得攻击加成与护盾，随后消耗全部鼓舞。',
    applyEffect: ({ player, value }) => {
      const usage = keywordUsageFor(player, CARD_KEYWORDS.ENCOURAGE);
      usage.attack = Math.max(0, Number(usage.attack) || 0) + value.attack;
      usage.shield = Math.max(0, Number(usage.shield) || 0) + value.shield;
      return { attack: usage.attack, shield: usage.shield };
    },
    prepareCombat: ({ player }) => {
      const usage = readKeywordUsage(player, CARD_KEYWORDS.ENCOURAGE);
      const attack = Math.max(0, Number(usage.attack) || 0);
      const shield = Math.max(0, Number(usage.shield) || 0);
      return attack > 0 || shield > 0
        ? { options: { attackBonus: attack, shieldBonus: shield }, activation: { attack, shield } }
        : null;
    },
    consumeCombatActivation: ({ player, activation }) => {
      delete player.keywordUsage[CARD_KEYWORDS.ENCOURAGE];
      return activation;
    },
    formatPlayerStatus: ({ player }) => {
      const usage = readKeywordUsage(player, CARD_KEYWORDS.ENCOURAGE);
      const attack = Math.max(0, Number(usage.attack) || 0);
      const shield = Math.max(0, Number(usage.shield) || 0);
      if (attack <= 0 && shield <= 0) return null;
      return {
        id: CARD_KEYWORDS.ENCOURAGE,
        label: '鼓舞',
        detail: `攻 +${attack} · 盾 +${shield}`,
        attack,
        shield,
      };
    },
    formatGainLog: ({ player, value }) => `${player.name} 获得鼓舞：攻击 +${value.attack}，护盾 +${value.shield}。`,
    formatConsumeLog: ({ attacker, value }) => `${attacker.name} 消耗鼓舞，获得 +${value.attack} 攻击与 ${value.shield} 点护盾。`,
    validateUsage: (usage) => (
      usage
      && typeof usage === 'object'
      && !Array.isArray(usage)
      && Number.isInteger(usage.attack)
      && usage.attack >= 0
      && Number.isInteger(usage.shield)
      && usage.shield >= 0
    ),
    validateCard: (card) => {
      const effects = card.effects?.filter((effect) => (
        effect.action === 'apply-keyword'
        && effect.value?.keywordId === CARD_KEYWORDS.ENCOURAGE
        && effect.target === 'ally-player'
      )) ?? [];
      const valid = effects.length > 0 && effects.every((effect) => (
        Number.isInteger(effect.value.attack)
        && effect.value.attack >= 0
        && Number.isInteger(effect.value.shield)
        && effect.value.shield >= 0
        && effect.value.attack + effect.value.shield > 0
      ));
      return valid ? [] : [`${card.name} 的鼓舞效果配置无效。`];
    },
  }),
  defineKeyword({
    id: CARD_KEYWORDS.CHARGE,
    label: '充能',
    requiresUnitKeyword: true,
    description: '角色在己方回合开始时获得充能，达到卡牌声明的数量后可支付并使用强化卡牌。',
    onTurnStart: ({ state, player, playerIndex, recordEvent, gameEvents }) => {
      (player.units ?? [])
        .filter((unit) => unit.keywords?.includes(CARD_KEYWORDS.CHARGE))
        .forEach((unit) => {
          const config = unit.keywordConfig?.[CARD_KEYWORDS.CHARGE];
          if (!config) return;
          const usage = keywordUsageFor(player, CARD_KEYWORDS.CHARGE);
          usage.units ??= {};
          const previous = usage.units[unit.uid]?.current ?? 0;
          const current = Math.min(config.max, previous + config.gainPerTurn);
          usage.units[unit.uid] = { current, max: config.max };
          const gained = current - previous;
          if (gained <= 0 || !recordEvent) return;
          recordEvent(
            state,
            gameEvents.KEYWORD_RESOURCE_GAINED,
            { playerIndex, unitId: unit.uid, keywordId: CARD_KEYWORDS.CHARGE, gained, current, max: config.max },
            `${unit.name} 获得 ${gained} 点充能，当前 ${current}/${config.max}。`,
            'success',
          );
        });
    },
    canPlayCard: ({ player, source, card }) => {
      const required = card.chargeCost;
      const current = readKeywordUsage(player, CARD_KEYWORDS.CHARGE).units?.[source.uid]?.current ?? 0;
      return current >= required
        ? null
        : { playable: false, code: 'charge', reason: `充能不足：需要 ${required}，${source.name} 当前为 ${current}。` };
    },
    beforeCardResolution: ({ player, source, card }) => {
      const usage = keywordUsageFor(player, CARD_KEYWORDS.CHARGE);
      const resource = usage.units?.[source.uid];
      if (!resource) return null;
      resource.current -= card.chargeCost;
      return { unitId: source.uid, spent: card.chargeCost, current: resource.current, max: resource.max };
    },
    formatUnitStatus: ({ player, unit }) => {
      if (!unit.keywords?.includes(CARD_KEYWORDS.CHARGE)) return null;
      const config = unit.keywordConfig?.[CARD_KEYWORDS.CHARGE];
      const resource = readKeywordUsage(player, CARD_KEYWORDS.CHARGE).units?.[unit.uid];
      return {
        id: CARD_KEYWORDS.CHARGE,
        label: '充能',
        detail: `${resource?.current ?? 0}/${resource?.max ?? config.max}`,
        current: resource?.current ?? 0,
        max: resource?.max ?? config.max,
      };
    },
    formatSpendLog: ({ source, value }) => `${source.name} 支付 ${value.spent} 点充能，剩余 ${value.current}/${value.max}。`,
    validateUsage: (usage, player) => {
      const chargeUnits = (player.units ?? [])
        .filter((unit) => unit.keywords?.includes(CARD_KEYWORDS.CHARGE));
      return usage
      && typeof usage === 'object'
      && !Array.isArray(usage)
      && usage.units
      && typeof usage.units === 'object'
      && !Array.isArray(usage.units)
      && Object.keys(usage.units).length === chargeUnits.length
      && chargeUnits.every((unit) => {
        const resource = usage.units[unit.uid];
        const configuredMax = unit.keywordConfig?.[CARD_KEYWORDS.CHARGE]?.max;
        return resource
        && Number.isInteger(resource.current)
        && Number.isInteger(resource.max)
        && resource.current >= 0
        && resource.max > 0
        && resource.current <= resource.max
        && resource.max === configuredMax;
      });
    },
    validateUnit: (unit) => {
      const config = unit.keywordConfig?.[CARD_KEYWORDS.CHARGE];
      const valid = Number.isInteger(config?.max)
        && config.max > 0
        && Number.isInteger(config.gainPerTurn)
        && config.gainPerTurn > 0
        && config.gainPerTurn <= config.max;
      return valid ? [] : [`${unit.name} 的充能角色配置无效。`];
    },
    validateCard: (card) => (
      Number.isInteger(card.chargeCost) && card.chargeCost > 0
        ? []
        : [`${card.name} 的充能消耗配置无效。`]
    ),
  }),
  defineKeyword({
    id: CARD_KEYWORDS.COUNTDOWN,
    label: '倒计时',
    description: '幻境在触发时机推进计数，归零后结算效果并重置。',
    formatStatus: ({ source }) => (Number.isInteger(source.countdown) ? `倒计时 ${source.countdown}` : ''),
    beforeRealmTrigger: ({ state, playerIndex, realm, recordEvent, gameEvents }) => {
      realm.countdown = Math.max(0, realm.countdown - 1);
      recordEvent(
        state,
        gameEvents.COUNTDOWN_TICKED,
        { playerIndex, cardId: realm.cardId, countdown: realm.countdown },
        `${realm.name} 的倒计时降至 ${realm.countdown}。`,
        'turn',
      );
      if (realm.countdown > 0) return false;
      recordEvent(
        state,
        gameEvents.COUNTDOWN_TRIGGERED,
        { playerIndex, cardId: realm.cardId },
        `${realm.name} 的倒计时效果触发。`,
        'card',
      );
      return true;
    },
    afterRealmTrigger: ({ realm }) => {
      realm.countdown = realm.countdownReset;
    },
    validateCard: (card) => {
      const valid = card.type === 'realm'
        && Number.isInteger(card.realm?.countdown)
        && card.realm.countdown > 0
        && Number.isInteger(card.realm?.countdownReset)
        && card.realm.countdownReset > 0;
      return valid ? [] : [`${card.name} 的倒计时幻境配置无效。`];
    },
  }),
  defineKeyword({
    id: CARD_KEYWORDS.DIVINATION,
    label: '占卜',
    description: '检视牌库顶的若干张牌，选择其中一张置于牌库顶。',
    validateCard: (card) => {
      const valid = Number.isInteger(card.divination?.count)
        && card.divination.count > 1
        && card.effects?.some((effect) => effect.action === 'divination');
      return valid ? [] : [`${card.name} 的占卜配置无效。`];
    },
  }),
  defineKeyword({
    id: CARD_KEYWORDS.INCARNATION,
    label: '化身',
    description: '己方回合开始抽牌后，每回合最多由系统自动免费使用一张满足条件的化身牌。',
    onTurnStart: ({ player }) => {
      keywordUsageFor(player, CARD_KEYWORDS.INCARNATION).used = false;
    },
    automaticCard: ({ player, card }) => {
      const usage = readKeywordUsage(player, CARD_KEYWORDS.INCARNATION);
      return usage.used || card.incarnation?.trigger !== 'owner-turn-start' ? null : { priority: card.incarnation.priority ?? 50 };
    },
    afterCardPlayed: ({ player, automatic }) => {
      if (automatic) keywordUsageFor(player, CARD_KEYWORDS.INCARNATION).used = true;
    },
    validateUsage: (usage) => (
      usage && typeof usage === 'object' && !Array.isArray(usage) && typeof usage.used === 'boolean'
    ),
    validateCard: (card) => {
      const valid = card.target === 'auto'
        && card.incarnation?.trigger === 'owner-turn-start'
        && Number.isInteger(card.incarnation?.priority ?? 50);
      return valid ? [] : [`${card.name} 的化身配置无效。`];
    },
  }),
  defineKeyword({
    id: CARD_KEYWORDS.FUSION,
    label: '融合',
    description: '重复使用同名融合牌时将数值叠加到来源角色，直到该牌声明的层数上限。',
    canPlayCard: ({ player, source, card }) => {
      const current = readKeywordUsage(player, CARD_KEYWORDS.FUSION).units?.[source.uid]?.cards?.[card.id]?.stacks ?? 0;
      return current < card.fusion.maxStacks
        ? null
        : { playable: false, code: 'fusion-max', reason: `${source.name} 的「${card.name}」已达 ${card.fusion.maxStacks} 层融合上限。` };
    },
    applyEffect: ({ player, source, card, value }) => {
      const usage = keywordUsageFor(player, CARD_KEYWORDS.FUSION);
      usage.units ??= {};
      usage.units[source.uid] ??= { cards: {} };
      const cards = usage.units[source.uid].cards;
      const current = cards[card.id] ?? {
        stacks: 0,
        attack: 0,
        hp: 0,
        attackPerStack: value.attack,
        hpPerStack: value.hp,
        maxStacks: value.maxStacks,
      };
      const next = {
        stacks: current.stacks + 1,
        attack: current.attack + value.attack,
        hp: current.hp + value.hp,
        attackPerStack: value.attack,
        hpPerStack: value.hp,
        maxStacks: value.maxStacks,
      };
      cards[card.id] = next;
      source.attack += value.attack;
      source.maxHp += value.hp;
      if (source.hp > 0) source.hp += value.hp;
      source.fusion = { cardId: card.id, name: card.name, ...next, maxStacks: value.maxStacks };
      return { unitId: source.uid, cardId: card.id, ...next, maxStacks: value.maxStacks };
    },
    formatUnitStatus: ({ player, unit }) => {
      const cards = readKeywordUsage(player, CARD_KEYWORDS.FUSION).units?.[unit.uid]?.cards;
      const entries = Object.values(cards ?? {});
      if (!entries.length) return null;
      const stacks = entries.reduce((total, entry) => total + entry.stacks, 0);
      const attack = entries.reduce((total, entry) => total + entry.attack, 0);
      const hp = entries.reduce((total, entry) => total + entry.hp, 0);
      return { id: CARD_KEYWORDS.FUSION, label: '融合', detail: `${stacks} 层 · 攻 +${attack} · 命 +${hp}`, stacks, attack, hp };
    },
    formatGainLog: ({ source, card, value }) => (
      `${source.name} 与「${card.name}」完成第 ${value.stacks} 层融合，获得 +${card.fusion.attack} 攻击与 +${card.fusion.hp} 生命。`
    ),
    validateUsage: (usage, player) => {
      if (!usage || typeof usage !== 'object' || Array.isArray(usage) || !usage.units || typeof usage.units !== 'object') return false;
      return Object.entries(usage.units).every(([unitId, unitUsage]) => (
        player.units.some((unit) => unit.uid === unitId)
        && unitUsage
        && typeof unitUsage === 'object'
        && !Array.isArray(unitUsage)
        && unitUsage.cards
        && Object.values(unitUsage.cards).every((entry) => (
          Number.isInteger(entry.stacks) && entry.stacks > 0
          && Number.isInteger(entry.maxStacks) && entry.maxStacks > 1 && entry.stacks <= entry.maxStacks
          && Number.isInteger(entry.attack) && entry.attack >= 0
          && Number.isInteger(entry.hp) && entry.hp >= 0
          && Number.isInteger(entry.attackPerStack) && entry.attackPerStack >= 0
          && Number.isInteger(entry.hpPerStack) && entry.hpPerStack >= 0
          && entry.attack === entry.stacks * entry.attackPerStack
          && entry.hp === entry.stacks * entry.hpPerStack
          && entry.attackPerStack + entry.hpPerStack > 0
        ))
      ));
    },
    validateCard: (card) => {
      const effect = card.effects?.find((candidate) => (
        candidate.action === 'apply-keyword'
        && candidate.value?.keywordId === CARD_KEYWORDS.FUSION
        && candidate.target === 'source'
      ));
      const valid = effect
        && Number.isInteger(card.fusion?.attack)
        && card.fusion.attack >= 0
        && Number.isInteger(card.fusion?.hp)
        && card.fusion.hp >= 0
        && card.fusion.attack + card.fusion.hp > 0
        && Number.isInteger(card.fusion?.maxStacks)
        && card.fusion.maxStacks > 1
        && effect.value.attack === card.fusion.attack
        && effect.value.hp === card.fusion.hp
        && effect.value.maxStacks === card.fusion.maxStacks;
      return valid ? [] : [`${card.name} 的融合配置无效。`];
    },
  }),
  defineKeyword({
    id: CARD_KEYWORDS.COOP,
    label: '协战',
    description: '本回合已有另一名友方角色发动攻击时，获得卡牌声明的出击加成。',
    onTurnStart: ({ player }) => {
      keywordUsageFor(player, CARD_KEYWORDS.COOP).attackers = [];
    },
    combatOptions: ({ player, source, card }) => {
      const attackers = readKeywordUsage(player, CARD_KEYWORDS.COOP).attackers ?? [];
      const ready = attackers.some((unitId) => unitId !== source.uid);
      return ready ? { attackBonus: card.coop.attackBonus, coop: true } : {};
    },
    afterCombat: ({ player, attacker }) => {
      const usage = keywordUsageFor(player, CARD_KEYWORDS.COOP);
      usage.attackers ??= [];
      if (!usage.attackers.includes(attacker.uid)) usage.attackers.push(attacker.uid);
    },
    formatPlayerStatus: ({ player }) => {
      const count = readKeywordUsage(player, CARD_KEYWORDS.COOP).attackers?.length ?? 0;
      if (!count) return null;
      return { id: CARD_KEYWORDS.COOP, label: '协战', detail: `${count} 名已出击`, title: '由另一名角色使用协战牌可触发加成' };
    },
    validateUsage: (usage, player) => (
      usage
      && typeof usage === 'object'
      && !Array.isArray(usage)
      && Array.isArray(usage.attackers)
      && new Set(usage.attackers).size === usage.attackers.length
      && usage.attackers.every((unitId) => player.units.some((unit) => unit.uid === unitId))
    ),
    validateCard: (card) => {
      const valid = card.effects?.some((effect) => effect.action === 'assault')
        && Number.isInteger(card.coop?.attackBonus)
        && card.coop.attackBonus > 0;
      return valid ? [] : [`${card.name} 的协战配置无效。`];
    },
  }),
  defineKeyword({
    id: CARD_KEYWORDS.PROJECTILE,
    label: '投射',
    description: '伤害优先命中敌方前线角色，前线空缺时改为伤害敌方核心。',
    damageRoute: ({ state, enemyIndex }) => {
      const enemy = state.players[enemyIndex];
      const front = enemy.units.findIndex((unit) => unit.uid === enemy.frontUnitId && unit.hp > 0);
      return front >= 0 ? { type: 'unit', unitIndex: front } : { type: 'avatar' };
    },
    validateCard: (card) => {
      const valid = card.target === 'auto'
        && card.effects?.some((effect) => effect.action === 'damage');
      return valid ? [] : [`${card.name} 的投射配置无效。`];
    },
  }),
]);

const KEYWORD_MAP = new Map(KEYWORD_DEFINITIONS.map((definition) => [definition.id, definition]));

export function getKeywordDefinition(keywordId) {
  return KEYWORD_MAP.get(keywordId);
}

function keywordDefinitionsFor(source) {
  return (source?.keywords ?? [])
    .map((keywordId) => KEYWORD_MAP.get(keywordId))
    .filter(Boolean)
    .sort((left, right) => left.priority - right.priority || left.id.localeCompare(right.id));
}

export function applyTurnStartKeywordHooks(context) {
  KEYWORD_DEFINITIONS.forEach((definition) => definition.onTurnStart?.(context));
}

export function getKeywordModifiedCardCost(context) {
  return keywordDefinitionsFor(context.card).reduce(
    (cost, definition) => definition.modifyCardCost?.({ ...context, cost }) ?? cost,
    context.card.cost,
  );
}

export function applyCardPlayedKeywordHooks(context) {
  keywordDefinitionsFor(context.card).forEach((definition) => definition.afterCardPlayed?.(context));
}

export function getKeywordCardPlayabilityBlock(context) {
  for (const definition of keywordDefinitionsFor(context.card)) {
    const block = definition.canPlayCard?.(context);
    if (block) return block;
  }
  return null;
}

export function applyCardResolutionKeywordHooks(context) {
  return keywordDefinitionsFor(context.card)
    .map((definition) => {
      const value = definition.beforeCardResolution?.(context);
      if (!value) return null;
      return {
        keywordId: definition.id,
        label: definition.label,
        eventType: value.eventType,
        value: value.payload ?? value,
        rawValue: value,
        text: definition.formatSpendLog?.({ ...context, value })
          ?? `${context.source.name} 支付${definition.label}。`,
      };
    })
    .filter(Boolean);
}

export function getKeywordEffectConditionDecision(context) {
  for (const definition of keywordDefinitionsFor(context.card)) {
    const decision = definition.effectCondition?.(context);
    if (decision !== undefined) return decision;
  }
  return undefined;
}

export function getKeywordDamageRoute(context) {
  return keywordDefinitionsFor(context.card)
    .map((definition) => definition.damageRoute?.(context))
    .find(Boolean) ?? null;
}

export function applyCombatResolvedKeywordHooks(context) {
  KEYWORD_DEFINITIONS.forEach((definition) => definition.afterCombat?.(context));
}

export function getAutomaticKeywordCardTrigger(context) {
  return keywordDefinitionsFor(context.card)
    .map((definition) => definition.automaticCard?.(context))
    .find(Boolean) ?? null;
}

export function getKeywordCombatOptions(context) {
  return keywordDefinitionsFor(context.card).reduce(
    (options, definition) => ({ ...options, ...(definition.combatOptions?.(context) ?? {}) }),
    {},
  );
}

export function applyKeywordEffect(context) {
  const keywordId = context.effect?.value?.keywordId;
  const definition = KEYWORD_MAP.get(keywordId);
  if (!definition?.applyEffect) return null;
  const value = definition.applyEffect({ ...context, value: context.effect.value });
  if (!value) return null;
  return {
    keywordId,
    label: definition.label,
    value,
    text: definition.formatGainLog?.({ ...context, value }) ?? `${context.player.name} 获得${definition.label}。`,
  };
}

export function preparePlayerCombatKeywords(context) {
  return KEYWORD_DEFINITIONS.reduce((prepared, definition) => {
    const contribution = definition.prepareCombat?.(context);
    if (!contribution) return prepared;
    prepared.options.attackBonus += contribution.options?.attackBonus ?? 0;
    prepared.options.shieldBonus += contribution.options?.shieldBonus ?? 0;
    prepared.activations.push({ keywordId: definition.id, value: contribution.activation });
    return prepared;
  }, { options: { attackBonus: 0, shieldBonus: 0 }, activations: [] });
}

export function consumePlayerCombatKeywordActivations(context, activations) {
  return activations.map((activation) => {
    const definition = KEYWORD_MAP.get(activation.keywordId);
    const value = definition.consumeCombatActivation({ ...context, activation: activation.value });
    return {
      keywordId: definition.id,
      label: definition.label,
      value,
      text: definition.formatConsumeLog?.({ ...context, value })
        ?? `${context.attacker.name} 消耗${definition.label}。`,
    };
  });
}

export function getPlayerKeywordStatuses(player) {
  return KEYWORD_DEFINITIONS
    .map((definition) => definition.formatPlayerStatus?.({ player }))
    .filter(Boolean);
}

export function getUnitKeywordStatuses(player, unit) {
  return KEYWORD_DEFINITIONS
    .map((definition) => definition.formatUnitStatus?.({ player, unit }))
    .filter(Boolean);
}

export function validatePlayerKeywordUsage(player) {
  if (!player.keywordUsage || typeof player.keywordUsage !== 'object' || Array.isArray(player.keywordUsage)) {
    return ['关键词使用状态必须是对象。'];
  }
  return Object.entries(player.keywordUsage).flatMap(([keywordId, usage]) => {
    const definition = KEYWORD_MAP.get(keywordId);
    if (!definition) return [`存在未知关键词状态 ${keywordId}。`];
    if (!definition.validateUsage) return [];
    return definition.validateUsage(usage, player) ? [] : [`关键词 ${keywordId} 的状态结构无效。`];
  });
}

export function getKeywordCostReductionLabel(card) {
  return keywordDefinitionsFor(card)
    .map((definition) => definition.costReductionLabel)
    .find(Boolean) ?? null;
}

export function getKeywordStatusText(source) {
  return keywordDefinitionsFor(source)
    .map((definition) => definition.formatStatus?.({ source }))
    .filter(Boolean)
    .join(' · ');
}

export function prepareRealmKeywordTrigger(context) {
  for (const definition of keywordDefinitionsFor(context.realm)) {
    if (definition.beforeRealmTrigger?.(context) === false) return false;
  }
  return true;
}

export function completeRealmKeywordTrigger(context) {
  keywordDefinitionsFor(context.realm).forEach((definition) => definition.afterRealmTrigger?.(context));
}

export function validateCardKeywordConfiguration(card, unit = null) {
  if (!Array.isArray(card.keywords)) return [`${card.name} 的关键词必须是数组。`];

  const errors = [];
  const seen = new Set();
  card.keywords.forEach((keywordId) => {
    if (seen.has(keywordId)) errors.push(`${card.name} 重复声明了关键词 ${keywordId}。`);
    seen.add(keywordId);
    const definition = KEYWORD_MAP.get(keywordId);
    if (!definition) {
      errors.push(`${card.name} 使用了未知关键词 ${keywordId}。`);
      return;
    }
    if (unit && definition.requiresUnitKeyword && !unit.keywords?.includes(keywordId)) {
      errors.push(`${card.name} 的来源角色未声明关键词 ${keywordId}。`);
    }
    errors.push(...(definition.validateCard?.(card) ?? []));
  });
  card.effects
    ?.filter((effect) => effect.action === 'apply-keyword')
    .forEach((effect) => {
      const keywordId = effect.value?.keywordId;
      if (!KEYWORD_MAP.has(keywordId)) errors.push(`${card.name} 试图施加未知关键词 ${String(keywordId)}。`);
      else if (!seen.has(keywordId)) errors.push(`${card.name} 的关键词效果 ${keywordId} 未在卡牌上声明。`);
    });
  return errors;
}

export function validateUnitKeywordConfiguration(unit) {
  if (unit.keywords === undefined) return [];
  if (!Array.isArray(unit.keywords)) return [`${unit.name} 的关键词必须是数组。`];
  const errors = [];
  const seen = new Set();
  unit.keywords.forEach((keywordId) => {
    if (seen.has(keywordId)) errors.push(`${unit.name} 重复声明了关键词 ${keywordId}。`);
    seen.add(keywordId);
    const definition = KEYWORD_MAP.get(keywordId);
    if (!definition) errors.push(`${unit.name} 使用了未知关键词 ${keywordId}。`);
    else errors.push(...(definition.validateUnit?.(unit) ?? []));
  });
  return errors;
}
