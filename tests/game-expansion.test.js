import test from 'node:test';
import assert from 'node:assert/strict';

import {
  GAME_STATE_VERSION,
  createGame as rawCreateGame,
  deserializeGame,
  endTurn,
  getCardDefinition,
  passResponse,
  playCard,
  serializeGame,
} from '../game-core.js';

function putCardInHand(state, playerIndex, definitionId) {
  const instance = { instanceId: `test-${definitionId}-${state.players[playerIndex].hand.length}`, definitionId };
  state.players[playerIndex].hand.push(instance);
  return instance;
  state.players[playerIndex].levelUpUsed = true; // 新规则：出牌前需完成升级阶段
}

function createGame(input = undefined) {
  const state = rawCreateGame(input);
  state.players.forEach((player) => {
    player.levelUpUsed = true;
    player.units.forEach((unit) => { if (unit.level < 1) unit.level = 1; });
  });;
  return state;
}

function play(state, playerIndex, definitionId, targetId = null) {
  const instance = putCardInHand(state, playerIndex, definitionId);
  state.players[playerIndex].levelUpUsed = true; // 新规则：任意回合出牌前需完成升勾
  const result = playCard(state, playerIndex, instance.instanceId, targetId);
  assert.equal(result.error, null);
  let current = result.state;
  // 可响应步骤会打开响应窗口，测试中双方依次放弃以走完结算
  let guard = 0;
  while (current.responseWindow && guard < 10) {
    const passer = passResponse(current, current.responseWindow.playerIndex);
    assert.equal(passer.error, null);
    current = passer.state;
    guard += 1;
  }
  return current;
}

function end(state, playerIndex) {
  const result = endTurn(state, playerIndex);
  assert.equal(result.error, null);
  return result.state;
}

function findUnit(state, playerIndex, unitId) {
  return state.players[playerIndex].units.find((unit) => unit.id === unitId);
}

test('focus draws an extra card only as the first card of the turn', () => {
  let state = createGame({ seed: 11 });
  const handBefore = state.players[0].hand.length;
  const deckBefore = state.players[0].deck.length;

  state = play(state, 0, 'single-mind');
  // +1（塞入）-1（打出）+2（基础抽 1 + 专注抽 1）
  assert.equal(state.players[0].hand.length, handBefore + 2);
  assert.equal(state.players[0].deck.length, deckBefore - 2);

  const before2 = state.players[0].hand.length;
  state = play(state, 0, 'single-mind');
  // 第二张不再触发专注：+1 -1 +1
  assert.equal(state.players[0].hand.length, before2 + 1);
  assert.ok(state.log.some((entry) => entry.text.includes('专注未达成')));
});

test('chain pulls the next same-unit card from the deck into the hand', () => {
  let state = createGame({ seed: 12 });
  const lumenUnit = findUnit(state, 0, 'lumen');
  lumenUnit.level = 2;
  // 清空牌库中的弦月牌，保证连引唯一目标可断言
  state.players[0].deck = state.players[0].deck
    .filter((card) => getCardDefinition(card.definitionId).unitId !== 'lumen');
  state.players[0].deck.push({ instanceId: 'test-chain-target', definitionId: 'mend' });
  const deckBefore = state.players[0].deck.length;

  state = play(state, 0, 'moonlit-verse', findUnit(state, 0, 'ember').uid);
  assert.equal(state.players[0].deck.length, deckBefore - 1);
  assert.ok(state.players[0].hand.some((card) => card.instanceId === 'test-chain-target'));
  assert.ok(state.log.some((entry) => entry.text.includes('连引')));
});

test('origin shuffles a copy of itself back into the deck', () => {
  let state = createGame({ seed: 13, playerUnitIds: ['ember', 'basalt', 'lumen', 'ink'] });
  findUnit(state, 0, 'ink').level = 2;
  const deckBefore = state.players[0].deck.length;

  state = play(state, 0, 'origin-manuscript');
  // 抽 1，起源洗回 1：牌库净不变
  assert.equal(state.players[0].deck.length, deckBefore);
  assert.equal(state.players[0].deck.filter((card) => card.definitionId === 'origin-manuscript').length, 1);
});

test('cooking collects three ingredients and buffs the whole team once', () => {
  let state = createGame({ seed: 14 });
  const statsBefore = state.players[0].units.map((unit) => [unit.attack, unit.maxHp]);

  state = play(state, 0, 'ember-feast-fish');
  state = play(state, 0, 'mountain-granary', findUnit(state, 0, 'ember').uid);
  assert.equal(state.players[0].keywordUsage.cook.fish, 1);
  assert.equal(state.players[0].keywordUsage.cook.rice, 1);
  state.players[0].units.forEach((unit, index) => {
    assert.equal(unit.attack, statsBefore[index][0]);
  });

  state.players[0].energy = 2; // 测试直充鬼火，专注验证烹饪结算
  state = play(state, 0, 'frost-pickle', findUnit(state, 1, 'storm').uid);
  // 三种食材各消耗 1，全体 +1/+1
  assert.equal(state.players[0].keywordUsage.cook.fish, 0);
  assert.equal(state.players[0].keywordUsage.cook.rice, 0);
  assert.equal(state.players[0].keywordUsage.cook.herb, 0);
  state.players[0].units.forEach((unit, index) => {
    assert.equal(unit.attack, statsBefore[index][0] + 1);
    assert.equal(unit.maxHp, statsBefore[index][1] + 1);
  });
  assert.ok(state.log.some((entry) => entry.text.includes('灵宴')));
});

test('charge-up ticks on owner turn start and resolves at the threshold', () => {
  let state = createGame({ seed: 15 });
  findUnit(state, 0, 'basalt').level = 2;
  state = play(state, 0, 'bedrock-attitude');
  const tracked = () => findUnit(state, 0, 'basalt');
  assert.equal(tracked().chargeUp.counters, 0);
  assert.equal(tracked().chargeUp.threshold, 2);

  state = end(state, 0); // AI 行动
  assert.equal(tracked().chargeUp.counters, 0, '对手回合不推进蓄力');
  state = end(state, 1); // 回到己方回合，蓄力 1/2
  assert.equal(tracked().chargeUp.counters, 1);

  state = end(state, 0);
  state = end(state, 1); // 蓄力 2/2 触发
  assert.equal(tracked().chargeUp, null);
  assert.ok(tracked().shield >= 4);
  assert.ok(state.log.some((entry) => entry.text.includes('成熟')));
});

test('nightfall registers a delayed effect that fires on the scheduled round', () => {
  let state = createGame({ seed: 16 });
  findUnit(state, 0, 'rime').level = 3;
  state = play(state, 0, 'longest-night');
  assert.equal(state.players[0].keywordUsage.nightfall.pending.triggered, false);

  let guard = 0;
  while (state.turnCounter < 5 && state.winner === null && guard < 40) {
    state = end(state, state.currentPlayer);
    guard += 1;
  }
  assert.equal(state.players[0].keywordUsage.nightfall.pending.triggered, true);
  assert.ok(state.log.some((entry) => entry.text.includes('夜幕降临')));
  const enemyHpSum = state.players[1].units.reduce((total, unit) => total + Math.max(0, unit.hp), 0);
  const enemyMaxSum = state.players[1].units.reduce((total, unit) => total + unit.maxHp, 0);
  assert.ok(enemyHpSum < enemyMaxSum);
});

test('bestow consumes storm charge to unlock the empowered damage step', () => {
  let state = createGame({ seed: 17, playerUnitIds: ['storm', 'ember', 'basalt', 'lumen'] });
  const storm = findUnit(state, 0, 'storm');
  storm.level = 2;
  state.players[0].keywordUsage.charge = { units: { [storm.uid]: { current: 2, max: 3 } } };
  const enemy = findUnit(state, 1, 'storm');
  const hpBefore = enemy.hp;

  state = play(state, 0, 'thunder-endow', enemy.uid);
  // 2 + 3（赐能）= 5 点伤害
  assert.equal(findUnit(state, 1, 'storm').hp, Math.max(0, hpBefore - 5));
  assert.equal(state.players[0].keywordUsage.charge.units[storm.uid].current, 0);
});

test('expansion state serializes with the bumped game version', () => {
  let state = createGame({ seed: 18 });
  state = play(state, 0, 'ember-feast-fish');
  const json = serializeGame(state);
  assert.equal(JSON.parse(json).version, GAME_STATE_VERSION);
  const restored = deserializeGame(json);
  assert.equal(restored.players[0].keywordUsage.cook.fish, 1);
  assert.equal(restored.players[0].cardsPlayedThisTurn, 1);
});

test('new expansion cards are absent from starter decks and the catalog stays valid', async () => {
  const { validateContentCatalog, createDefaultDeckDefinition, CARD_DEFINITIONS } = await import('../game-core.js');
  assert.deepEqual(validateContentCatalog(), { valid: true, errors: [] });
  const starterIds = new Set(createDefaultDeckDefinition(['ember', 'basalt', 'lumen', 'rime']).cardIds);
  ['ember-feast-fish', 'undying-ember', 'bedrock-attitude', 'moonlit-verse', 'longest-night', 'thunder-endow'].forEach((id) => {
    assert.equal(starterIds.has(id), false, `${id} 不应出现在默认构筑`);
    assert.ok(getCardDefinition(id), `${id} 应已注册`);
  });
  assert.equal(CARD_DEFINITIONS.length, 72 + 11 + 7); // 机制深化：4 关键词代表牌 + 3 响应触发牌
});
