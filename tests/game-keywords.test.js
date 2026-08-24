import test from 'node:test';
import assert from 'node:assert/strict';

import {
  CARD_KEYWORDS,
  KEYWORD_DEFINITIONS,
  applyCardResolutionKeywordHooks,
  applyCardPlayedKeywordHooks,
  applyKeywordEffect,
  applyTurnStartKeywordHooks,
  consumePlayerCombatKeywordActivations,
  completeRealmKeywordTrigger,
  getKeywordCombatOptions,
  getKeywordCardPlayabilityBlock,
  getKeywordCostReductionLabel,
  getKeywordDefinition,
  getKeywordModifiedCardCost,
  getKeywordStatusText,
  getPlayerKeywordStatuses,
  getUnitKeywordStatuses,
  preparePlayerCombatKeywords,
  validatePlayerKeywordUsage,
  validateUnitKeywordConfiguration,
  prepareRealmKeywordTrigger,
  validateCardKeywordConfiguration,
} from '../game-keywords.js';

test('keyword registry exposes immutable reusable definitions', () => {
  assert.ok(Object.isFrozen(CARD_KEYWORDS));
  assert.ok(Object.isFrozen(KEYWORD_DEFINITIONS));
  assert.deepEqual(KEYWORD_DEFINITIONS.map((definition) => definition.id), [
    CARD_KEYWORDS.RESPONSE,
    CARD_KEYWORDS.INSTANT,
    CARD_KEYWORDS.PIERCE,
    CARD_KEYWORDS.STUN,
    CARD_KEYWORDS.REMOTE,
    CARD_KEYWORDS.FORTUNE,
    CARD_KEYWORDS.ENCOURAGE,
    CARD_KEYWORDS.CHARGE,
    CARD_KEYWORDS.COUNTDOWN,
    CARD_KEYWORDS.DIVINATION,
    CARD_KEYWORDS.INCARNATION,
    CARD_KEYWORDS.FUSION,
    CARD_KEYWORDS.COOP,
    CARD_KEYWORDS.PROJECTILE,
    CARD_KEYWORDS.CHARGED,
    CARD_KEYWORDS.CHAIN,
    CARD_KEYWORDS.BESTOW,
    CARD_KEYWORDS.COOK,
    CARD_KEYWORDS.NIGHTFALL,
    CARD_KEYWORDS.ORIGIN,
    CARD_KEYWORDS.FOCUS,
    CARD_KEYWORDS.COMBO,
    CARD_KEYWORDS.FIRST_STRIKE,
    CARD_KEYWORDS.CRIT,
    CARD_KEYWORDS.UNYIELDING,
  ]);
  KEYWORD_DEFINITIONS.forEach((definition) => {
    assert.ok(Object.isFrozen(definition));
    assert.equal(getKeywordDefinition(definition.id), definition);
  });
});

test('instant uses the shared turn state and card cost lifecycle', () => {
  const state = { currentPlayer: 0, responseWindow: null };
  const player = { keywordUsage: {} };
  const card = { cost: 1, keywords: [CARD_KEYWORDS.INSTANT] };

  applyTurnStartKeywordHooks({ state, playerIndex: 0, player });
  assert.equal(getKeywordModifiedCardCost({ state, playerIndex: 0, player, card }), 0);
  assert.equal(getKeywordCostReductionLabel(card), '瞬发 · 免火');
  applyCardPlayedKeywordHooks({ state, playerIndex: 0, player, card, effectiveCost: 0 });
  assert.equal(player.keywordUsage.instant.used, true);
  assert.equal(getKeywordModifiedCardCost({ state, playerIndex: 0, player, card }), 1);

  applyTurnStartKeywordHooks({ state, playerIndex: 0, player });
  assert.equal(player.keywordUsage.instant.used, false);
});

test('keyword cost queries do not mutate missing usage state', () => {
  const state = { currentPlayer: 0, responseWindow: null };
  const player = { keywordUsage: {} };
  const card = { cost: 1, keywords: [CARD_KEYWORDS.INSTANT] };

  assert.equal(getKeywordModifiedCardCost({ state, playerIndex: 0, player, card }), 0);
  assert.deepEqual(player.keywordUsage, {});
});

test('combat keywords contribute composable options without coupling to card ids', () => {
  assert.deepEqual(getKeywordCombatOptions({ card: { keywords: [CARD_KEYWORDS.PIERCE] } }), { pierce: true });
  assert.deepEqual(getKeywordCombatOptions({ card: { keywords: [CARD_KEYWORDS.REMOTE] } }), { remote: true });
  assert.deepEqual(
    getKeywordCombatOptions({ card: { keywords: [CARD_KEYWORDS.PIERCE, CARD_KEYWORDS.REMOTE] } }),
    { pierce: true, remote: true },
  );
});

test('encourage accumulates as player state and is consumed only after combat', () => {
  const player = { name: '巡界者', keywordUsage: {} };
  const first = applyKeywordEffect({
    player,
    effect: { value: { keywordId: CARD_KEYWORDS.ENCOURAGE, attack: 2, shield: 1 } },
  });
  const second = applyKeywordEffect({
    player,
    effect: { value: { keywordId: CARD_KEYWORDS.ENCOURAGE, attack: 1, shield: 2 } },
  });

  assert.deepEqual(first.value, { attack: 2, shield: 1 });
  assert.deepEqual(second.value, { attack: 3, shield: 3 });
  const prepared = preparePlayerCombatKeywords({ player });
  assert.deepEqual(prepared.options, { attackBonus: 3, shieldBonus: 3 });
  assert.deepEqual(prepared.activations, [{
    keywordId: CARD_KEYWORDS.ENCOURAGE,
    value: { attack: 3, shield: 3 },
  }]);
  assert.deepEqual(getPlayerKeywordStatuses(player), [{
    id: CARD_KEYWORDS.ENCOURAGE,
    label: '鼓舞',
    detail: '攻 +3 · 盾 +3',
    attack: 3,
    shield: 3,
  }]);
  assert.deepEqual(player.keywordUsage.encourage, { attack: 3, shield: 3 });

  const consumed = consumePlayerCombatKeywordActivations(
    { player, attacker: { name: '赤曜' } },
    prepared.activations,
  );
  assert.deepEqual(consumed[0].value, { attack: 3, shield: 3 });
  assert.deepEqual(preparePlayerCombatKeywords({ player }).options, { attackBonus: 0, shieldBonus: 0 });
  assert.deepEqual(getPlayerKeywordStatuses(player), []);
  assert.deepEqual(validatePlayerKeywordUsage(player), []);
  assert.match(
    validatePlayerKeywordUsage({ keywordUsage: { encourage: 'bad' } }).join(' '),
    /状态结构无效/,
  );
});

test('charge grows per unit, gates cards, and is paid through the resolution hook', () => {
  const unit = {
    id: 'test-unit',
    uid: 'player:test-unit',
    name: '测试角色',
    keywords: [CARD_KEYWORDS.CHARGE],
    keywordConfig: { charge: { max: 3, gainPerTurn: 1 } },
  };
  const player = { name: '巡界者', units: [unit], keywordUsage: {} };
  const card = { name: '蓄能牌', keywords: [CARD_KEYWORDS.CHARGE], chargeCost: 2 };
  const context = { player, source: unit, card };

  applyTurnStartKeywordHooks({ player });
  assert.deepEqual(player.keywordUsage.charge.units[unit.uid], { current: 1, max: 3 });
  assert.equal(getKeywordCardPlayabilityBlock(context).code, 'charge');
  assert.deepEqual(getUnitKeywordStatuses(player, unit), [{
    id: CARD_KEYWORDS.CHARGE,
    label: '充能',
    detail: '1/3',
    current: 1,
    max: 3,
  }]);

  applyTurnStartKeywordHooks({ player });
  assert.equal(getKeywordCardPlayabilityBlock(context), null);
  const payments = applyCardResolutionKeywordHooks(context);
  assert.deepEqual(payments[0].value, { unitId: unit.uid, spent: 2, current: 0, max: 3 });
  assert.equal(player.keywordUsage.charge.units[unit.uid].current, 0);
  assert.deepEqual(validatePlayerKeywordUsage(player), []);
  assert.deepEqual(validateUnitKeywordConfiguration(unit), []);
});

test('countdown owns its realm trigger lifecycle and resets after resolution', () => {
  const records = [];
  const context = {
    state: {},
    playerIndex: 0,
    realm: {
      cardId: 'test-realm',
      name: '测试幻境',
      keywords: [CARD_KEYWORDS.COUNTDOWN],
      countdown: 2,
      countdownReset: 2,
    },
    recordEvent: (...args) => records.push(args),
    gameEvents: { COUNTDOWN_TICKED: 'tick', COUNTDOWN_TRIGGERED: 'trigger' },
  };

  assert.equal(prepareRealmKeywordTrigger(context), false);
  assert.equal(context.realm.countdown, 1);
  assert.equal(getKeywordStatusText(context.realm), '倒计时 1');
  assert.equal(records.at(-1)[1], 'tick');

  assert.equal(prepareRealmKeywordTrigger(context), true);
  assert.equal(context.realm.countdown, 0);
  assert.equal(records.at(-1)[1], 'trigger');
  completeRealmKeywordTrigger(context);
  assert.equal(context.realm.countdown, 2);
});

test('keyword validation rejects unknown, duplicate, and incompatible declarations', () => {
  const baseCard = {
    name: '测试牌',
    type: 'spell',
    effects: [{ action: 'shield' }],
    keywords: [],
  };
  assert.deepEqual(validateCardKeywordConfiguration(baseCard), []);
  assert.match(
    validateCardKeywordConfiguration({ ...baseCard, keywords: ['missing'] }).join(' '),
    /未知关键词/,
  );
  assert.match(
    validateCardKeywordConfiguration({ ...baseCard, keywords: [CARD_KEYWORDS.INSTANT, CARD_KEYWORDS.INSTANT] }).join(' '),
    /重复声明/,
  );
  assert.match(
    validateCardKeywordConfiguration({ ...baseCard, keywords: [CARD_KEYWORDS.PIERCE] }).join(' '),
    /包含出击动作/,
  );
  assert.match(
    validateCardKeywordConfiguration({ ...baseCard, keywords: [CARD_KEYWORDS.REMOTE] }).join(' '),
    /包含出击动作/,
  );
  assert.match(
    validateCardKeywordConfiguration({ ...baseCard, keywords: [CARD_KEYWORDS.ENCOURAGE] }).join(' '),
    /鼓舞效果配置无效/,
  );
  assert.deepEqual(validateCardKeywordConfiguration({
    ...baseCard,
    keywords: [CARD_KEYWORDS.ENCOURAGE],
    effects: [{
      condition: 'always',
      action: 'apply-keyword',
      target: 'ally-player',
      value: { keywordId: CARD_KEYWORDS.ENCOURAGE, attack: 2, shield: 1 },
    }],
  }), []);
  assert.match(validateCardKeywordConfiguration({
    ...baseCard,
    keywords: [CARD_KEYWORDS.ENCOURAGE],
    effects: [{
      condition: 'always',
      action: 'apply-keyword',
      target: 'enemy-avatar',
      value: { keywordId: CARD_KEYWORDS.ENCOURAGE, attack: 2, shield: 1 },
    }],
  }).join(' '), /鼓舞效果配置无效/);
  assert.match(
    validateUnitKeywordConfiguration({ name: '错误角色', keywords: [CARD_KEYWORDS.CHARGE], keywordConfig: {} }).join(' '),
    /充能角色配置无效/,
  );
  assert.match(
    validateCardKeywordConfiguration({ ...baseCard, keywords: [CARD_KEYWORDS.CHARGE] }).join(' '),
    /充能消耗配置无效/,
  );
  assert.match(
    validateCardKeywordConfiguration({ ...baseCard, keywords: [CARD_KEYWORDS.COUNTDOWN] }).join(' '),
    /倒计时幻境配置无效/,
  );
});
