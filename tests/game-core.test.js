import test from 'node:test';
import assert from 'node:assert/strict';

import {
  CARD_DEFINITIONS,
  DEFAULT_PLAYER_LINEUP,
  GAME_EVENTS,
  GAME_RULES,
  GAME_STATE_VERSION,
  basicAttack,
  createGame as rawCreateGame,
  canPlayCard,
  createDefaultDeckDefinition,
  deserializeGame,
  drawCards,
  endTurn,
  getCardDefinition,
  getEffectiveCardCost,
  getCardPlayability,
  getRound,
  isUpgradePending,
  getValidCombatTargets,
  levelUpUnit,
  passResponse,
  playCard,
  resolveDivinationChoice,
  serializeGame,
  validateContentCatalog,
  validateDeckDefinition,
} from '../game-core.js';

// 新规则：升勾先于出牌/出击。除升勾专项用例外，默认升级阶段已完成。
function createGame(input = undefined) {
  const state = rawCreateGame(input);
  state.players.forEach((player) => { player.levelUpUsed = true; });
  return state;
}

function findCard(state, playerIndex, definitionId) {
  return state.players[playerIndex].hand.find((card) => card.definitionId === definitionId);
}

function putCardInHand(state, playerIndex, definitionId) {
  const instance = { instanceId: `test-${definitionId}-${state.players[playerIndex].hand.length}`, definitionId };
  state.players[playerIndex].levelUpUsed = true; // 新规则：出牌前需完成升级阶段
  state.players[playerIndex].hand.push(instance);
  return instance;
}

test('creates a deterministic 30-life, 32-card opening state', () => {
  const first = createGame(42);
  const second = createGame(42);
  assert.deepEqual(first, second);
  assert.equal(first.players[0].avatarHp, 30);
  assert.equal(first.players[0].hand.length, GAME_RULES.openingHandSize);
  assert.equal(first.players[0].deck.length + first.players[0].hand.length, 32);
  assert.equal(first.players[0].energy, 2);
  assert.equal(first.players[0].maxEnergy, 2);
  assert.deepEqual(first.players[0].units.map((unit) => unit.id), [...DEFAULT_PLAYER_LINEUP]);
  assert.equal(getRound(first), 1);
});

test('builds a legal deck only from the four selected units', () => {
  const unitIds = ['storm', 'ink', 'ember', 'rime'];
  const definition = createDefaultDeckDefinition(unitIds);
  assert.deepEqual(validateDeckDefinition(definition), { valid: true, errors: [] });
  assert.equal(definition.cardIds.length, 32);

  const state = createGame({ seed: 7, playerUnitIds: unitIds });
  assert.deepEqual(state.players[0].units.map((unit) => unit.id), unitIds);
  const allCards = [...state.players[0].hand, ...state.players[0].deck];
  const unitCounts = new Map(unitIds.map((unitId) => [unitId, 0]));
  allCards.forEach((instance) => {
    const card = getCardDefinition(instance.definitionId);
    assert.ok(unitIds.includes(card.unitId));
    unitCounts.set(card.unitId, unitCounts.get(card.unitId) + 1);
  });
  unitCounts.forEach((count) => assert.equal(count, 8));
});

test('deck validation rejects incomplete and duplicate lineups', () => {
  const incomplete = createDefaultDeckDefinition(['ember', 'basalt', 'lumen']);
  assert.equal(validateDeckDefinition(incomplete).valid, false);
  const duplicate = createDefaultDeckDefinition(['ember', 'ember', 'lumen', 'rime']);
  assert.equal(validateDeckDefinition(duplicate).valid, false);
});

test('content catalog only references registered units, targets, and effects', () => {
  assert.deepEqual(validateContentCatalog(), { valid: true, errors: [] });
});

test('every card exposes immutable condition-action-target effect steps', () => {
  CARD_DEFINITIONS.forEach((card) => {
    assert.ok(Object.isFrozen(card.effects), `${card.name} effects should be frozen`);
    assert.ok(card.effects.length > 0, `${card.name} should define at least one effect step`);
    card.effects.forEach((effect) => {
      assert.ok(Object.isFrozen(effect), `${card.name} effect step should be frozen`);
      assert.equal(typeof effect.condition, 'string');
      assert.equal(typeof effect.action, 'string');
      assert.equal(typeof effect.target, 'string');
    });
    assert.ok(Object.isFrozen(card.responseTo), `${card.name} response triggers should be frozen`);
    assert.ok(Object.isFrozen(card.keywords), `${card.name} keywords should be frozen`);
  });

  assert.deepEqual(getCardDefinition('horizon-burn').effects, [
    { condition: 'always', action: 'damage', target: 'all-enemy-units', value: 1 },
    { condition: 'match-active', action: 'damage', target: 'enemy-avatar', value: 2 },
  ]);
  assert.deepEqual(getCardDefinition('refract').effects, [
    { condition: 'always', action: 'draw', target: 'ally-player', value: 2 },
    { condition: 'match-active', action: 'heal-avatar', target: 'ally-avatar', value: 1 },
  ]);
  assert.equal(getCardDefinition('hoar-barrier').timing, 'response');
  assert.deepEqual(getCardDefinition('hoar-barrier').responseTo, ['damage', 'assault', 'shield']);
  assert.deepEqual(getCardDefinition('moon-ward').keywords, ['instant']);
  assert.deepEqual(getCardDefinition('combustion-edge').keywords, ['pierce']);
  assert.deepEqual(getCardDefinition('static-dash').keywords, ['remote']);
  assert.deepEqual(getCardDefinition('radiant-encouragement').keywords, ['encourage']);
  assert.deepEqual(getCardDefinition('charged-bolt').keywords, ['charge']);
  assert.deepEqual(getCardDefinition('fireline').keywords, ['countdown']);
  assert.deepEqual(getCardDefinition('hoar-barrier').keywords, ['response']);
  assert.deepEqual(getCardDefinition('hush').keywords, ['stun']);
  assert.deepEqual(getCardDefinition('dawn-needle').keywords, ['fortune']);
  assert.deepEqual(getCardDefinition('index-page').keywords, ['divination']);
  assert.deepEqual(getCardDefinition('afterimage').keywords, ['incarnation']);
  assert.deepEqual(getCardDefinition('cloud-form').keywords, ['fusion']);
  assert.deepEqual(getCardDefinition('light-step').keywords, ['coop']);
  assert.deepEqual(getCardDefinition('black-stain').keywords, ['projectile']);
});

function createResponseScenario(seed) {
  const state = createGame({
    seed,
    enemyUnitIds: ['rime', 'basalt', 'lumen', 'ink'],
  });
  state.players[0].energy = 2;
  state.players[1].energy = 2;
  const damageCard = putCardInHand(state, 0, 'cinder-mark');
  const responseCard = putCardInHand(state, 1, 'hoar-barrier');
  const target = state.players[1].units.find((unit) => unit.id === 'rime');
  return { state, damageCard, responseCard, target };
}

test('response priority alternates until both players pass, then resolves LIFO', () => {
  const { state, damageCard, responseCard, target } = createResponseScenario(115);
  putCardInHand(state, 0, 'hoar-barrier');
  const hpBefore = target.hp;
  const pending = playCard(state, 0, damageCard.instanceId, target.uid);

  assert.equal(pending.error, null);
  assert.equal(pending.pending, true);
  assert.equal(pending.state.phase, 'response');
  assert.equal(pending.state.responseWindow.playerIndex, 1);
  assert.equal(pending.state.responseWindow.consecutivePasses, 0);
  assert.equal(pending.state.responseWindow.depth, 0);
  assert.equal(pending.state.players[1].units[0].hp, hpBefore);
  assert.ok(pending.state.resolutionStack.length > 0);
  assert.equal(getCardPlayability(pending.state, 1, responseCard.instanceId).playable, true);
  assert.match(basicAttack(pending.state, 0, pending.state.players[0].frontUnitId).error, /响应窗口/);

  const chained = playCard(pending.state, 1, responseCard.instanceId, target.uid);
  assert.equal(chained.error, null);
  assert.equal(chained.pending, true);
  assert.equal(chained.state.responseWindow.playerIndex, 0);
  assert.equal(chained.state.responseWindow.depth, 1);
  assert.equal(chained.state.responseWindow.consecutivePasses, 0);

  const firstPass = passResponse(chained.state, 0);
  assert.equal(firstPass.pending, true);
  assert.equal(firstPass.state.responseWindow.playerIndex, 1);
  assert.equal(firstPass.state.responseWindow.consecutivePasses, 1);
  assert.equal(firstPass.state.players[1].units[0].shield, 0);

  const responseResolved = passResponse(firstPass.state, 1);
  assert.equal(responseResolved.pending, true);
  assert.equal(responseResolved.state.responseWindow.depth, 0);
  assert.equal(responseResolved.state.players[1].units[0].shield, 2);

  const rootFirstPass = passResponse(responseResolved.state, 1);
  const resolved = passResponse(rootFirstPass.state, 0);
  assert.equal(resolved.error, null);
  assert.equal(resolved.pending, false);
  assert.equal(resolved.state.phase, 'main');
  assert.equal(resolved.state.responseWindow, null);
  assert.deepEqual(resolved.state.resolutionStack, []);
  assert.equal(resolved.state.players[1].units[0].hp, hpBefore - 1);
  assert.equal(resolved.state.players[1].units[0].shield, 0);

  const order = resolved.state.events
    .filter((event) => event.type === GAME_EVENTS.RESOLUTION_STEP_RESOLVED)
    .reverse()
    .map((event) => event.payload.definitionId);
  assert.deepEqual(order.slice(-2), ['hoar-barrier', 'cinder-mark']);
});

test('two consecutive passes are required to resume the pending card unchanged', () => {
  const { state, damageCard, target } = createResponseScenario(116);
  const hpBefore = target.hp;
  const pending = playCard(state, 0, damageCard.instanceId, target.uid);
  const firstPass = passResponse(pending.state, 1);

  assert.equal(firstPass.error, null);
  assert.equal(firstPass.pending, true);
  assert.equal(firstPass.state.players[1].units[0].hp, hpBefore);
  assert.equal(firstPass.state.responseWindow.playerIndex, 0);
  assert.equal(firstPass.state.responseWindow.consecutivePasses, 1);

  const resolved = passResponse(firstPass.state, 0);

  assert.equal(resolved.error, null);
  assert.equal(resolved.state.players[1].units[0].hp, hpBefore - 3);
  assert.equal(resolved.state.responseWindow, null);
  assert.deepEqual(resolved.state.resolutionStack, []);
  assert.ok(resolved.state.events.some((event) => event.type === GAME_EVENTS.RESPONSE_PASSED));
});

test('an open response window and its resolution stack survive serialization', () => {
  const { state, damageCard, target } = createResponseScenario(117);
  const pending = playCard(state, 0, damageCard.instanceId, target.uid).state;
  const restored = deserializeGame(serializeGame(pending));

  assert.deepEqual(restored.responseWindow, pending.responseWindow);
  assert.deepEqual(restored.resolutionStack, pending.resolutionStack);
  assert.equal(restored.phase, 'response');
  assert.equal(restored.isResolving, false);
  const firstPass = passResponse(restored, 1).state;
  assert.equal(firstPass.responseWindow.consecutivePasses, 1);
  assert.deepEqual(passResponse(firstPass, 0).state.resolutionStack, []);
});

test('multiple response cards form a reusable LIFO chain', () => {
  const { state, damageCard, responseCard, target } = createResponseScenario(128);
  state.players[0].hand = [damageCard];
  state.players[1].hand = [responseCard];
  state.players[0].energy = 10;
  state.players[1].energy = 10;
  const playerResponse = putCardInHand(state, 0, 'hoar-barrier');
  putCardInHand(state, 0, 'hoar-barrier');
  putCardInHand(state, 1, 'hoar-barrier');

  let chained = playCard(state, 0, damageCard.instanceId, target.uid).state;
  chained = playCard(chained, 1, responseCard.instanceId, target.uid).state;
  chained = playCard(chained, 0, playerResponse.instanceId, chained.players[0].units[0].uid).state;
  assert.equal(chained.responseWindow.depth, 2);
  assert.equal(chained.responseWindow.playerIndex, 1);

  while (chained.responseWindow) {
    chained = passResponse(chained, chained.responseWindow.playerIndex).state;
  }
  const order = chained.events
    .filter((event) => event.type === GAME_EVENTS.RESOLUTION_STEP_RESOLVED)
    .reverse()
    .map((event) => event.payload.definitionId);
  assert.deepEqual(order.slice(-3), ['hoar-barrier', 'hoar-barrier', 'cinder-mark']);
});

test('response nesting stops at the configured depth without exceeding the stack limit', () => {
  const { state, damageCard, target } = createResponseScenario(129);
  state.players[0].hand = [damageCard];
  state.players[1].hand = [];
  state.players[0].energy = 20;
  state.players[1].energy = 20;
  for (let index = 0; index < 5; index += 1) {
    putCardInHand(state, 0, 'hoar-barrier');
    putCardInHand(state, 1, 'hoar-barrier');
  }

  let chained = playCard(state, 0, damageCard.instanceId, target.uid).state;
  for (let depth = 1; depth <= GAME_RULES.maxResponseDepth; depth += 1) {
    const playerIndex = chained.responseWindow.playerIndex;
    const response = chained.players[playerIndex].hand.find((card) => card.definitionId === 'hoar-barrier');
    const ownTarget = chained.players[playerIndex].units.find((unit) => unit.hp > 0);
    chained = playCard(chained, playerIndex, response.instanceId, ownTarget.uid).state;
  }

  assert.equal(chained.responseWindow.depth, GAME_RULES.maxResponseDepth - 1);
  assert.equal(chained.resolutionStack.some((frame) => frame.responseDepth > GAME_RULES.maxResponseDepth), false);
  assert.equal(chained.events.filter((event) => (
    event.type === GAME_EVENTS.RESOLUTION_STEP_RESOLVED
      && event.payload.definitionId === 'hoar-barrier'
  )).length, 1);
});

test('serialization rejects forged response priority and depth state', () => {
  const { state, damageCard, target } = createResponseScenario(130);
  const pending = playCard(state, 0, damageCard.instanceId, target.uid).state;
  const forgedPasses = JSON.parse(serializeGame(pending));
  forgedPasses.state.responseWindow.consecutivePasses = 2;
  assert.throws(() => deserializeGame(JSON.stringify(forgedPasses)), /响应窗口结构无效/);

  const forgedDepth = JSON.parse(serializeGame(pending));
  forgedDepth.state.resolutionStack.at(-1).responseDepth = GAME_RULES.maxResponseDepth + 1;
  assert.throws(() => deserializeGame(JSON.stringify(forgedDepth)), /结算帧无效/);
});

test('targeted damage spends one ghost fire and damages the chosen enemy', () => {
  const state = createGame(7);
  const instance = findCard(state, 0, 'cinder-mark') ?? putCardInHand(state, 0, 'cinder-mark');
  const before = state.players[1].units[2].hp;
  const result = playCard(state, 0, instance.instanceId, state.players[1].units[2].uid);
  assert.equal(result.error, null);
  assert.equal(result.state.players[1].units[2].hp, before - getCardDefinition('cinder-mark').value);
  assert.equal(result.state.players[0].energy, 1);
});

test('only the first instant card on an owner turn costs zero ghost fire', () => {
  let state = createGame(118);
  const first = putCardInHand(state, 0, 'moon-ward');
  const second = putCardInHand(state, 0, 'moon-ward');
  const targetUid = state.players[0].units[1].uid;

  assert.equal(getEffectiveCardCost(state, 0, first.instanceId), 0);
  state = playCard(state, 0, first.instanceId, targetUid).state;
  assert.equal(state.players[0].energy, 2);
  assert.equal(state.players[0].keywordUsage.instant.used, true);
  assert.equal(getEffectiveCardCost(state, 0, second.instanceId), 1);

  state = playCard(state, 0, second.instanceId, targetUid).state;
  assert.equal(state.players[0].energy, 1);
  state = endTurn(endTurn(state, 0).state, 1).state;
  assert.equal(state.players[0].keywordUsage.instant.used, false);
});

test('pierce transfers only unshielded overkill damage to the enemy core', () => {
  const state = createGame(119);
  const ember = state.players[0].units.find((unit) => unit.id === 'ember');
  ember.level = 3;
  // 赤曜已拥有战斗区（复刻旧自动前线前提），本次不会触发「进入前线」被动
  state.players[0].frontUnitId = ember.uid;
  const defender = state.players[1].units[0];
  defender.hp = 2;
  defender.shield = 1;
  state.players[1].frontUnitId = defender.uid;
  const card = putCardInHand(state, 0, 'combustion-edge');
  const result = playCard(state, 0, card.instanceId);

  assert.equal(result.error, null);
  assert.equal(result.state.players[1].avatarHp, 26);
  assert.equal(result.state.players[0].damageDealt, 6);
  assert.ok(result.state.events.some((event) => (
    event.type === GAME_EVENTS.PIERCING_TRIGGERED && event.payload.damage === 3
  )));
});

test('remote combat attacks from reserve without replacing the front line or taking counter damage', () => {
  const state = createGame({ seed: 121, playerUnitIds: ['storm', 'basalt', 'lumen', 'rime'] });
  state.players[1].hand = [];
  const storm = state.players[0].units.find((unit) => unit.id === 'storm');
  const basalt = state.players[0].units.find((unit) => unit.id === 'basalt');
  const defender = state.players[1].units[0];
  state.players[1].frontUnitId = defender.uid;
  state.players[0].frontUnitId = basalt.uid;
  const frontBefore = state.players[0].frontUnitId;
  const stormHpBefore = storm.hp;
  const stormShieldBefore = storm.shield;
  const defenderHpBefore = defender.hp;
  const enemyCoreBefore = state.players[1].avatarHp;
  const card = putCardInHand(state, 0, 'static-dash');

  const result = playCard(state, 0, card.instanceId);
  const nextStorm = result.state.players[0].units.find((unit) => unit.uid === storm.uid);
  const nextDefender = result.state.players[1].units.find((unit) => unit.uid === defender.uid);
  const combatStarted = result.state.events.find((event) => (
    event.type === GAME_EVENTS.COMBAT_STARTED && event.payload.attackerUnitId === storm.uid
  ));
  const combatResolved = result.state.events.find((event) => (
    event.type === GAME_EVENTS.COMBAT_RESOLVED && event.payload.attackerUnitId === storm.uid
  ));

  assert.equal(result.error, null);
  assert.equal(result.state.players[0].frontUnitId, frontBefore);
  assert.equal(nextStorm.hp, stormHpBefore);
  assert.equal(nextStorm.shield, stormShieldBefore);
  assert.equal(nextDefender.hp, defenderHpBefore - storm.attack - 1);
  assert.equal(result.state.players[1].avatarHp, enemyCoreBefore);
  assert.equal(combatStarted.payload.remote, true);
  assert.equal(combatResolved.payload.remote, true);
  assert.equal(combatResolved.payload.enteredFromReserve, false);
  assert.equal(result.state.events.some((event) => (
    event.type === GAME_EVENTS.UNIT_ENTERED_FRONT && event.payload.unitId === storm.uid
  )), false);
  assert.equal(result.state.events.some((event) => (
    event.type === GAME_EVENTS.PASSIVE_TRIGGERED && event.payload.unitId === storm.uid
  )), false);
});

test('remote combat prevents counter damage when the attacker already owns the front line', () => {
  const state = createGame({ seed: 122, playerUnitIds: ['storm', 'basalt', 'lumen', 'rime'] });
  state.players[1].hand = [];
  const storm = state.players[0].units.find((unit) => unit.id === 'storm');
  const defender = state.players[1].units[0];
  state.players[1].frontUnitId = defender.uid;
  state.players[0].frontUnitId = storm.uid;
  const hpBefore = storm.hp;
  assert.ok(defender.attack > 0);
  const card = putCardInHand(state, 0, 'static-dash');

  const result = playCard(state, 0, card.instanceId);

  assert.equal(result.error, null);
  assert.equal(result.state.players[0].units.find((unit) => unit.uid === storm.uid).hp, hpBefore);
  assert.equal(result.state.events.find((event) => (
    event.type === GAME_EVENTS.COMBAT_STARTED && event.payload.attackerUnitId === storm.uid
  )).payload.remote, true);
});

test('charge grows on owner turns to its cap and survives serialization', () => {
  let state = createGame({ seed: 126, playerUnitIds: ['storm', 'basalt', 'lumen', 'rime'] });
  const storm = state.players[0].units.find((unit) => unit.id === 'storm');
  const resource = () => state.players[0].keywordUsage.charge.units[storm.uid];
  assert.deepEqual(resource(), { current: 1, max: 3 });

  state = endTurn(endTurn(state, 0).state, 1).state;
  assert.equal(resource().current, 2);
  state = endTurn(endTurn(state, 0).state, 1).state;
  assert.equal(resource().current, 3);
  state = endTurn(endTurn(state, 0).state, 1).state;
  assert.equal(resource().current, 3);

  const restored = deserializeGame(serializeGame(state));
  assert.deepEqual(restored.players[0].keywordUsage.charge.units[storm.uid], { current: 3, max: 3 });

  const malformed = JSON.parse(serializeGame(state));
  malformed.state.players[0].keywordUsage.charge.units[storm.uid].max = 99;
  assert.throws(() => deserializeGame(JSON.stringify(malformed)), /关键词使用状态无效/);
});

test('charge is reserved through a response window and paid once resolution resumes', () => {
  let state = createGame({
    seed: 127,
    playerUnitIds: ['storm', 'basalt', 'lumen', 'rime'],
    enemyUnitIds: ['rime', 'basalt', 'lumen', 'ink'],
  });
  state = endTurn(endTurn(state, 0).state, 1).state;
  state.players[0].energy = 2;
  state.players[1].energy = 2;
  const storm = state.players[0].units.find((unit) => unit.id === 'storm');
  const resource = () => state.players[0].keywordUsage.charge.units[storm.uid];
  const chargedCard = putCardInHand(state, 0, 'charged-bolt');
  putCardInHand(state, 1, 'hoar-barrier');
  const target = state.players[1].units.find((unit) => unit.id === 'rime');
  const hpBefore = target.hp;

  const pending = playCard(state, 0, chargedCard.instanceId, target.uid);
  assert.equal(pending.pending, true);
  assert.equal(pending.state.players[0].keywordUsage.charge.units[storm.uid].current, 2);
  assert.equal(getCardPlayability(state, 0, chargedCard.instanceId).playable, true);

  const restored = deserializeGame(serializeGame(pending.state));
  const firstPass = passResponse(restored, 1);
  const resolved = passResponse(firstPass.state, 0);
  assert.equal(resolved.error, null);
  assert.equal(resolved.state.players[0].keywordUsage.charge.units[storm.uid].current, 0);
  assert.equal(resolved.state.players[1].units.find((unit) => unit.uid === target.uid).hp, hpBefore - 5);
  assert.equal(resolved.state.events.filter((event) => event.type === GAME_EVENTS.KEYWORD_RESOURCE_SPENT).length, 1);
});

test('stun prevents attacks and counterattacks through the shared unit status', () => {
  let state = createGame({ seed: 120, playerUnitIds: ['rime', 'ember', 'basalt', 'lumen'] });
  const card = putCardInHand(state, 0, 'hush');
  const target = state.players[1].units[0];
  state = playCard(state, 0, card.instanceId, target.uid).state;

  assert.equal(state.players[1].units[0].frozen, 1);
  state.currentPlayer = 1;
  state.players[1].energy = 1;
  assert.match(basicAttack(state, 1, target.uid).error, /眩晕|冻结/);
});

test('fortune uses deterministic RNG and only resolves its success steps after the threshold', () => {
  const state = createGame(121);
  const card = putCardInHand(state, 0, 'dawn-needle');
  const target = state.players[1].units[0];
  const beforeHp = target.hp;
  const result = playCard(state, 0, card.instanceId, target.uid);
  const roll = result.state.events.find((event) => event.type === GAME_EVENTS.FORTUNE_ROLLED);
  const damage = beforeHp - result.state.players[1].units[0].hp;

  assert.ok(roll);
  assert.equal(damage, roll.payload.success ? 4 : 2);
  assert.equal(roll.payload.success, roll.payload.roll >= roll.payload.threshold);
  assert.deepEqual(deserializeGame(serializeGame(result.state)).players[0].keywordUsage.fortune.last, {
    roll: roll.payload.roll,
    sides: roll.payload.sides,
    threshold: roll.payload.threshold,
    success: roll.payload.success,
  });
});

test('divination pauses resolution, survives serialization, and places the selected card on top', () => {
  let state = createGame({ seed: 122, playerUnitIds: ['ink', 'ember', 'basalt', 'lumen'] });
  state.players[0].units.find((unit) => unit.id === 'ink').level = 2;
  const card = putCardInHand(state, 0, 'index-page');
  state = playCard(state, 0, card.instanceId).state;

  assert.equal(state.phase, 'choice');
  assert.equal(state.pendingChoice.type, 'divination');
  assert.equal(state.pendingChoice.instanceIds.length, 3);
  assert.equal(state.events.some((event) => event.type === GAME_EVENTS.CARD_PLAYED && event.payload.definitionId === 'index-page'), false);

  const malformed = JSON.parse(serializeGame(state));
  malformed.state.pendingChoice.instanceIds[0] = 'missing-from-deck';
  assert.throws(() => deserializeGame(JSON.stringify(malformed)), /待选择状态无效/);

  state = deserializeGame(serializeGame(state));
  const selected = state.pendingChoice.instanceIds[0];
  state = resolveDivinationChoice(state, 0, selected).state;
  assert.equal(state.pendingChoice, null);
  assert.equal(state.phase, 'main');
  assert.equal(state.players[0].deck.at(-1).instanceId, selected);
  assert.ok(state.events.some((event) => event.type === GAME_EVENTS.DIVINATION_RESOLVED));
  assert.ok(state.events.some((event) => event.type === GAME_EVENTS.CARD_PLAYED && event.payload.definitionId === 'index-page'));
});

test('incarnation automatically plays one eligible card for free after the owner draw', () => {
  let state = createGame({ seed: 123, playerUnitIds: ['storm', 'ember', 'basalt', 'lumen'] });
  state.players[0].units.find((unit) => unit.id === 'storm').level = 2;
  state.players[0].avatarHp = 25;
  const incarnation = putCardInHand(state, 0, 'afterimage');
  const deckBefore = state.players[0].deck.length;

  state = endTurn(state, 0).state;
  state = endTurn(state, 1).state;

  assert.equal(state.players[0].hand.some((card) => card.instanceId === incarnation.instanceId), false);
  assert.equal(state.players[0].energy, GAME_RULES.maxEnergy);
  assert.equal(state.players[0].avatarHp, 26);
  assert.equal(state.players[0].deck.length, deckBefore - 2);
  assert.equal(state.players[0].keywordUsage.incarnation.used, true);
  assert.ok(state.events.some((event) => event.type === GAME_EVENTS.INCARNATION_TRIGGERED));
});

test('fusion stacks declared bonuses and blocks the same fusion card at its cap', () => {
  let state = createGame({ seed: 124, playerUnitIds: ['storm', 'ember', 'basalt', 'lumen'] });
  const storm = state.players[0].units.find((unit) => unit.id === 'storm');
  storm.level = 2;
  const first = putCardInHand(state, 0, 'cloud-form');
  const second = putCardInHand(state, 0, 'cloud-form');
  const third = putCardInHand(state, 0, 'cloud-form');

  state = playCard(state, 0, first.instanceId).state;
  state = playCard(state, 0, second.instanceId).state;
  state.players[0].energy = 1;

  const fused = state.players[0].units.find((unit) => unit.id === 'storm');
  assert.equal(fused.attack, 5);
  assert.equal(fused.maxHp, 10);
  assert.equal(fused.hp, 10);
  assert.equal(fused.fusion.stacks, 2);
  assert.equal(getCardPlayability(state, 0, third.instanceId).code, 'fusion-max');
  assert.match(getCardPlayability(state, 0, third.instanceId).reason, /2 层融合上限/);
  assert.doesNotThrow(() => deserializeGame(serializeGame(state)));

  const malformed = JSON.parse(serializeGame(state));
  malformed.state.players[0].keywordUsage.fusion.units[storm.uid].cards['cloud-form'].stacks = 99;
  assert.throws(() => deserializeGame(JSON.stringify(malformed)), /关键词使用状态无效/);
});

test('coop gains its bonus only after a different ally has attacked this turn', () => {
  let state = createGame(125);
  const ember = state.players[0].units.find((unit) => unit.id === 'ember');
  state = basicAttack(state, 0, ember.uid).state;
  const coopCard = putCardInHand(state, 0, 'light-step');
  state = playCard(state, 0, coopCard.instanceId).state;

  const combat = state.events.find((event) => (
    event.type === GAME_EVENTS.COMBAT_STARTED
    && event.payload.attackerUnitId === state.players[0].units.find((unit) => unit.id === 'lumen').uid
  ));
  assert.equal(combat.payload.keywordBonuses.attack, 2);
  assert.deepEqual(state.players[0].keywordUsage.coop.attackers.sort(), [
    state.players[0].units.find((unit) => unit.id === 'ember').uid,
    state.players[0].units.find((unit) => unit.id === 'lumen').uid,
  ].sort());
});

test('projectile damages the enemy front first and the core only when the front is empty', () => {
  let state = createGame({ seed: 126, playerUnitIds: ['ink', 'ember', 'basalt', 'lumen'] });
  const first = putCardInHand(state, 0, 'black-stain');
  state.players[1].frontUnitId = state.players[1].units[0].uid;
  const frontId = state.players[1].frontUnitId;
  const frontBefore = state.players[1].units.find((unit) => unit.uid === frontId).hp;
  state = playCard(state, 0, first.instanceId).state;
  assert.equal(state.players[1].units.find((unit) => unit.uid === frontId).hp, frontBefore - 2);
  assert.equal(state.players[1].avatarHp, 30);

  state.players[1].units.forEach((unit) => { unit.hp = 0; });
  state.players[1].frontUnitId = null;
  state.players[0].energy = 1;
  const second = putCardInHand(state, 0, 'black-stain');
  state = playCard(state, 0, second.instanceId).state;
  assert.equal(state.players[1].avatarHp, 28);
});

test('a countdown realm ticks on owner turns, triggers at zero, and resets', () => {
  let state = createGame(120);
  state.players[0].units.find((unit) => unit.id === 'ember').level = 2;
  const card = putCardInHand(state, 0, 'fireline');
  state = playCard(state, 0, card.instanceId).state;

  assert.equal(state.players[0].realms[0].countdown, 2);
  assert.deepEqual(state.players[0].realms[0].keywords, ['countdown']);
  state = endTurn(endTurn(state, 0).state, 1).state;
  assert.equal(state.players[0].realms[0].countdown, 1);

  // 敌方出击进入战斗区并留场，倒计时触发时才有前线目标可打
  const defenderUid = state.players[1].units[0].uid;
  const hpBefore = state.players[1].units[0].hp;
  state = endTurn(state, 0).state;
  state.players[1].levelUpUsed = true; // 回合开始重置后补标记
  state = basicAttack(state, 1, defenderUid).state;
  state = endTurn(state, 1).state;

  assert.equal(state.players[0].realms[0].countdown, 2);
  assert.equal(state.players[1].units.find((unit) => unit.uid === defenderUid).hp, hpBefore - 3);
  assert.ok(state.events.some((event) => event.type === GAME_EVENTS.COUNTDOWN_TRIGGERED));
});

test('encourage accumulates, survives non-combat actions, and persists through serialization', () => {
  let state = createGame(121);
  const first = putCardInHand(state, 0, 'radiant-encouragement');
  state = playCard(state, 0, first.instanceId).state;

  assert.deepEqual(state.players[0].keywordUsage.encourage, { attack: 2, shield: 1 });
  assert.ok(state.events.some((event) => event.type === GAME_EVENTS.KEYWORD_STATE_GAINED));
  const levelTarget = state.players[0].units[1];
  state = levelUpUnit(state, 0, levelTarget.uid).state;
  assert.deepEqual(state.players[0].keywordUsage.encourage, { attack: 2, shield: 1 });

  const restored = deserializeGame(serializeGame(state));
  assert.deepEqual(restored.players[0].keywordUsage.encourage, { attack: 2, shield: 1 });
  state = endTurn(state, 0).state;
  assert.deepEqual(state.players[0].keywordUsage.encourage, { attack: 2, shield: 1 });
});

test('the next basic attack consumes encourage before damage and counter damage', () => {
  let state = createGame(122);
  const card = putCardInHand(state, 0, 'radiant-encouragement');
  state = playCard(state, 0, card.instanceId).state;
  const attacker = state.players[0].units[0];
  state.players[0].frontUnitId = attacker.uid;
  const defender = state.players[1].units[0];
  state.players[1].frontUnitId = defender.uid;
  defender.maxHp = 20;
  defender.hp = 20;
  const attackerHpBefore = attacker.hp;
  const defenderHpBefore = defender.hp;

  state = basicAttack(state, 0, attacker.uid).state;

  assert.equal(defender.hp - state.players[1].units.find((unit) => unit.uid === defender.uid).hp, attacker.attack + 2);
  assert.equal(state.players[0].units[0].hp, attackerHpBefore - Math.max(0, defender.attack - 1));
  assert.equal(state.players[0].keywordUsage.encourage, undefined);
  const consumed = state.events.find((event) => event.type === GAME_EVENTS.KEYWORD_STATE_CONSUMED);
  assert.deepEqual(consumed.payload.value, { attack: 2, shield: 1 });
  assert.deepEqual(
    state.events.find((event) => event.type === GAME_EVENTS.COMBAT_STARTED).payload.keywordBonuses,
    { attack: 2, shield: 1 },
  );
  assert.equal(defenderHpBefore, 20);
});

test('an encouraged attack into an empty front hits the core and preserves its shield', () => {
  let state = createGame(125);
  const card = putCardInHand(state, 0, 'radiant-encouragement');
  state = playCard(state, 0, card.instanceId).state;
  state.players[1].units.forEach((unit) => { unit.hp = 0; });
  state.players[1].frontUnitId = null;
  const attacker = state.players[0].units[0];
  const coreHpBefore = state.players[1].avatarHp;

  state = basicAttack(state, 0, attacker.uid).state;

  assert.equal(state.players[1].avatarHp, coreHpBefore - attacker.attack - 2);
  assert.equal(state.players[0].units[0].shield, 1);
  assert.equal(state.players[0].keywordUsage.encourage, undefined);
});

test('combat and remote cards both consume encourage without card-specific branches', () => {
  let combatState = createGame(123);
  combatState.players[1].hand = [];
  const encourageCard = putCardInHand(combatState, 0, 'radiant-encouragement');
  const combatCard = putCardInHand(combatState, 0, 'flash-thrust');
  combatState = playCard(combatState, 0, encourageCard.instanceId).state;
  combatState.players[0].frontUnitId = combatState.players[0].units[0].uid;
  const combatDefender = combatState.players[1].units[0];
  combatState.players[1].frontUnitId = combatDefender.uid;
  combatDefender.maxHp = 30;
  combatDefender.hp = 30;
  const combatHpBefore = combatDefender.hp;
  combatState = playCard(combatState, 0, combatCard.instanceId).state;
  assert.equal(combatHpBefore - combatState.players[1].units.find((unit) => unit.uid === combatDefender.uid).hp, 7);
  assert.equal(combatState.players[0].keywordUsage.encourage, undefined);

  let remoteState = createGame({ seed: 124, playerUnitIds: ['storm', 'lumen', 'basalt', 'rime'] });
  remoteState.players[1].hand = [];
  const storm = remoteState.players[0].units.find((unit) => unit.id === 'storm');
  const basalt = remoteState.players[0].units.find((unit) => unit.id === 'basalt');
  remoteState.players[0].frontUnitId = basalt.uid;
  const remoteDefender = remoteState.players[1].units[0];
  remoteState.players[1].frontUnitId = remoteDefender.uid;
  remoteDefender.maxHp = 30;
  remoteDefender.hp = 30;
  const remoteHpBefore = remoteDefender.hp;
  const remoteEncourage = putCardInHand(remoteState, 0, 'radiant-encouragement');
  const remoteCard = putCardInHand(remoteState, 0, 'static-dash');
  remoteState = playCard(remoteState, 0, remoteEncourage.instanceId).state;
  remoteState = playCard(remoteState, 0, remoteCard.instanceId).state;

  assert.equal(remoteHpBefore - remoteState.players[1].units.find((unit) => unit.uid === remoteDefender.uid).hp, storm.attack + 3);
  assert.equal(remoteState.players[0].frontUnitId, basalt.uid);
  assert.equal(remoteState.players[0].units.find((unit) => unit.uid === storm.uid).shield, 1);
  assert.equal(remoteState.players[0].keywordUsage.encourage, undefined);
});

test('multi-step area damage resolves units before the enemy avatar', () => {
  const state = createGame(111);
  state.players[0].units.find((unit) => unit.id === 'ember').level = 3;
  const instance = putCardInHand(state, 0, 'horizon-burn');
  const enemyHpBefore = state.players[1].units.map((unit) => unit.hp);
  const result = playCard(state, 0, instance.instanceId);

  assert.equal(result.error, null);
  assert.deepEqual(
    result.state.players[1].units.map((unit) => unit.hp),
    enemyHpBefore.map((hp) => hp - 1),
  );
  assert.equal(result.state.players[1].avatarHp, 28);
});

test('multi-step draw and avatar healing preserve their ordered values', () => {
  const state = createGame({ seed: 112, playerUnitIds: ['storm', 'basalt', 'rime', 'ink'] });
  state.players[0].units.find((unit) => unit.id === 'storm').level = 2;
  state.players[0].avatarHp = 20;
  const instance = putCardInHand(state, 0, 'afterimage');
  const handBefore = state.players[0].hand.length;
  const deckBefore = state.players[0].deck.length;
  const result = playCard(state, 0, instance.instanceId);

  assert.equal(result.error, null);
  assert.equal(result.state.players[0].hand.length, handBefore);
  assert.equal(result.state.players[0].deck.length, deckBefore - 1);
  assert.equal(result.state.players[0].avatarHp, 21);
});

test('conditional follow-up only applies brittle while the damaged target survives', () => {
  const livingState = createGame({ seed: 113, playerUnitIds: ['ink', 'basalt', 'lumen', 'rime'] });
  const livingCard = putCardInHand(livingState, 0, 'erode-script');
  const livingTarget = livingState.players[1].units[1];
  livingTarget.hp = 5;
  const livingResult = playCard(livingState, 0, livingCard.instanceId, livingTarget.uid);
  const updatedLivingTarget = livingResult.state.players[1].units[1];
  assert.equal(updatedLivingTarget.hp, 4);
  assert.equal(updatedLivingTarget.brittle, 1);

  const lethalState = createGame(114);
  lethalState.players[0].units.find((unit) => unit.id === 'rime').level = 3;
  const lethalCard = putCardInHand(lethalState, 0, 'fracture');
  const lethalTarget = lethalState.players[1].units[1];
  lethalTarget.hp = 2;
  const lethalResult = playCard(lethalState, 0, lethalCard.instanceId, lethalTarget.uid);
  const updatedLethalTarget = lethalResult.state.players[1].units[1];
  assert.equal(updatedLethalTarget.hp, 0);
  assert.equal(updatedLethalTarget.brittle, 0);
});

test('a reserve unit moves into the front line when it attacks', () => {
  const state = createGame(12);
  // 本家规则：开局战斗区为空，所有角色都在准备区
  assert.equal(state.players[0].frontUnitId, null);
  const attackerHpBefore = state.players[0].units[2].hp;
  const defender = state.players[1].units[0];
  state.players[1].frontUnitId = defender.uid;
  assert.ok(defender.attack > 0);
  const first = basicAttack(state, 0, state.players[0].units[2].uid);
  assert.equal(first.error, null);
  assert.equal(first.state.players[0].frontUnitId, first.state.players[0].units[2].uid);
  assert.equal(first.state.players[0].units[2].hp, attackerHpBefore - defender.attack);
  assert.equal(first.state.events.find((event) => (
    event.type === GAME_EVENTS.COMBAT_STARTED && event.payload.attackerUnitId === state.players[0].units[2].uid
  )).payload.remote, false);
  const second = basicAttack(first.state, 0, first.state.players[0].units[1].uid);
  assert.match(second.error, /已经出击/);
});

test('one unit can level up per turn and unlock higher-level cards', () => {
  const state = rawCreateGame(24);
  // 手动塞牌：保留未完成升级阶段的初始状态以验证升勾流程
  const form = { instanceId: 'test-ember-form-manual', definitionId: 'ember-form' };
  state.players[0].hand.push(form);
  assert.equal(getCardPlayability(state, 0, form.instanceId).code, 'upgrade');

  const leveled = levelUpUnit(state, 0, state.players[0].units[0].uid);
  assert.equal(leveled.error, null);
  assert.equal(leveled.state.players[0].units[0].level, 2);
  assert.match(levelUpUnit(leveled.state, 0, leveled.state.players[0].units[1].uid).error, /已经提升/);

  const played = playCard(leveled.state, 0, form.instanceId);
  assert.equal(played.error, null);
  assert.equal(played.state.players[0].units[0].attack, 4);
  assert.equal(played.state.players[0].units[0].maxHp, 11);
});

test('knocked out units return after two owner turns', () => {
  let state = createGame(19);
  state.players[0].units[1].hp = 0;
  state.players[0].units[1].knockout = 2;
  state = endTurn(state, 0).state;
  state = endTurn(state, 1).state;
  assert.equal(state.players[0].units[1].knockout, 1);
  state = endTurn(state, 0).state;
  state = endTurn(state, 1).state;
  assert.equal(state.players[0].units[1].knockout, 0);
  assert.ok(state.players[0].units[1].hp > 0);
});

test('a card cannot be played while its source unit is knocked out', () => {
  const state = createGame(88);
  const card = findCard(state, 0, 'flash-thrust') ?? putCardInHand(state, 0, 'flash-thrust');
  state.players[0].units[0].hp = 0;
  state.players[0].units[0].knockout = 2;
  assert.equal(canPlayCard(state, 0, card.instanceId), false);
  assert.equal(getCardPlayability(state, 0, card.instanceId).code, 'source-away');
  assert.match(getCardPlayability(state, 0, card.instanceId).reason, /赤曜正处于气绝/);
});

test('a deployed realm triggers at the start of its owner turn', () => {
  let state = createGame(55);
  state.players[0].units[1].level = 3;
  const realm = putCardInHand(state, 0, 'wardline');
  state = playCard(state, 0, realm.instanceId).state;
  assert.equal(state.players[0].realms.length, 1);
  state.players[0].frontUnitId = state.players[0].units[2].uid;
  const frontIndex = state.players[0].units.findIndex((unit) => unit.uid === state.players[0].frontUnitId);
  const shieldBefore = state.players[0].units[frontIndex].shield;
  state = endTurn(state, 0).state;
  state = endTurn(state, 1).state;
  assert.equal(state.players[0].units[frontIndex].shield, shieldBefore + 1);
});

test('drawing from an empty deck immediately loses the match', () => {
  const state = createGame(77);
  state.players[0].deck = [];
  drawCards(state, 0, 1);
  assert.equal(state.players[0].avatarHp, 0);
  assert.equal(state.winner, 1);
  assert.match(state.log.find((entry) => entry.type === 'deck-exhausted').text, /牌库枯竭/);
});

test('core damage ends the match and records the winner', () => {
  const state = createGame(99);
  state.players[0].units[0].level = 3;
  state.players[1].avatarHp = 2;
  const card = putCardInHand(state, 0, 'horizon-burn');
  const result = playCard(state, 0, card.instanceId);
  assert.equal(result.error, null);
  assert.equal(result.state.players[1].avatarHp, 0);
  assert.equal(result.state.winner, 0);
  assert.equal(result.state.phase, 'finished');
});

test('ember passive damages the enemy front once when entering from reserve', () => {
  const state = createGame(101);
  const ember = state.players[0].units.find((unit) => unit.id === 'ember');
  state.players[0].frontUnitId = state.players[0].units.find((unit) => unit.id === 'basalt').uid;
  const defender = state.players[1].units[0];
  state.players[1].frontUnitId = defender.uid;
  const hpBefore = defender.hp;

  const result = basicAttack(state, 0, ember.uid);

  assert.equal(result.error, null);
  assert.equal(result.state.players[1].units.find((unit) => unit.uid === defender.uid).hp, hpBefore - ember.attack - 1);
  assert.equal(result.state.events.filter((event) => event.type === GAME_EVENTS.PASSIVE_TRIGGERED && event.payload.unitId === ember.uid).length, 1);
  assert.deepEqual(result.state.eventQueue, []);
});

test('basalt passive grants shield only while it owns the front line', () => {
  let state = createGame(102);
  const basaltUid = state.players[0].units.find((unit) => unit.id === 'basalt').uid;
  state.players[0].frontUnitId = basaltUid;
  state = endTurn(endTurn(state, 0).state, 1).state;
  assert.equal(state.players[0].units.find((unit) => unit.uid === basaltUid).shield, 1);

  state.players[0].frontUnitId = state.players[0].units.find((unit) => unit.id === 'ember').uid;
  state = endTurn(endTurn(state, 0).state, 1).state;
  assert.equal(state.players[0].units.find((unit) => unit.uid === basaltUid).shield, 1);
});

test('lumen passive heals the core once per owner turn', () => {
  let state = createGame(103);
  state.players[0].avatarHp = 20;
  const first = putCardInHand(state, 0, 'mend');
  const second = putCardInHand(state, 0, 'mend');
  const targetUid = state.players[0].units[1].uid;

  state = playCard(state, 0, first.instanceId, targetUid).state;
  assert.equal(state.players[0].avatarHp, 21);
  state = playCard(state, 0, second.instanceId, targetUid).state;
  assert.equal(state.players[0].avatarHp, 21);

  state = endTurn(endTurn(state, 0).state, 1).state;
  const third = putCardInHand(state, 0, 'mend');
  state = playCard(state, 0, third.instanceId, targetUid).state;
  assert.equal(state.players[0].avatarHp, 22);
});

test('rime passive freezes a surviving combat defender', () => {
  const state = createGame(104);
  const rime = state.players[0].units.find((unit) => unit.id === 'rime');
  state.players[0].frontUnitId = rime.uid;
  state.players[1].frontUnitId = state.players[1].units[1].uid;
  const defenderUid = state.players[1].frontUnitId;

  const result = basicAttack(state, 0, rime.uid);

  assert.equal(result.error, null);
  assert.equal(result.state.players[1].units.find((unit) => unit.uid === defenderUid).frozen, 1);
});

test('storm passive damages the enemy core only after a reserve attack', () => {
  let state = createGame({ seed: 105, playerUnitIds: ['storm', 'basalt', 'lumen', 'rime'] });
  const stormUid = state.players[0].units.find((unit) => unit.id === 'storm').uid;
  state.players[0].frontUnitId = state.players[0].units.find((unit) => unit.id === 'basalt').uid;
  const defender = state.players[1].units[0];
  state.players[1].frontUnitId = defender.uid;

  state = basicAttack(state, 0, stormUid).state;
  assert.equal(state.players[1].avatarHp, 29);

  state = endTurn(endTurn(state, 0).state, 1).state;
  // 回合开始归位后重新出击部署，保证敌方战斗区仍有人；升勾标记随回合重置，先补上
  state.players[1].frontUnitId = defender.uid;
  state.players[0].levelUpUsed = true;
  // 霓鸢已归位准备区，再次出击仍是从后场换入，追风再次生效
  state = basicAttack(state, 0, stormUid).state;
  assert.equal(state.players[1].avatarHp, 28);
});

test('ink passive shields the front when its owner deploys a realm', () => {
  let state = createGame({ seed: 106, playerUnitIds: ['ink', 'basalt', 'lumen', 'rime'] });
  const ink = state.players[0].units.find((unit) => unit.id === 'ink');
  ink.level = 3;
  const realm = putCardInHand(state, 0, 'living-archive');
  const frontUid = state.players[0].units[1].uid;
  state.players[0].frontUnitId = frontUid;

  state = playCard(state, 0, realm.instanceId).state;

  assert.equal(state.players[0].units.find((unit) => unit.uid === frontUid).shield, 1);
  assert.equal(state.players[0].realms.length, 1);
});

test('a finished match leaves no pending passive events', () => {
  const state = createGame({ seed: 107, playerUnitIds: ['storm', 'basalt', 'lumen', 'rime'] });
  const stormUid = state.players[0].units.find((unit) => unit.id === 'storm').uid;
  state.players[0].frontUnitId = state.players[0].units.find((unit) => unit.id === 'basalt').uid;
  state.players[1].avatarHp = 1;

  const result = basicAttack(state, 0, stormUid);

  assert.equal(result.state.winner, 0);
  assert.deepEqual(result.state.eventQueue, []);
  assert.equal(result.state.isFlushingEvents, false);
  assert.doesNotThrow(() => JSON.stringify(result.state));
});

test('serializes and restores a deterministic game state', () => {
  let state = createGame(108);
  state = levelUpUnit(state, 0, state.players[0].units[1].uid).state;
  state = basicAttack(state, 0, state.players[0].units[2].uid).state;

  const firstJson = serializeGame(state);
  const restored = deserializeGame(firstJson);

  assert.equal(JSON.parse(firstJson).version, GAME_STATE_VERSION);
  assert.deepEqual(restored, state);
  assert.equal(serializeGame(restored), firstJson);
});

test('restoring a game discards runtime event queue state', () => {
  const envelope = JSON.parse(serializeGame(createGame(109)));
  envelope.state.eventQueue = [{ id: 999, type: GAME_EVENTS.TURN_STARTED }];
  envelope.state.isFlushingEvents = true;

  const restored = deserializeGame(JSON.stringify(envelope));

  assert.deepEqual(restored.eventQueue, []);
  assert.equal(restored.isFlushingEvents, false);
});

test('rejects invalid serialized JSON', () => {
  assert.throws(() => deserializeGame('{not-json'), /JSON/);
  assert.throws(() => deserializeGame(null), /JSON 字符串/);
});

test('rejects unknown save versions and malformed game structures', () => {
  const validEnvelope = JSON.parse(serializeGame(createGame(110)));
  assert.throws(
    () => deserializeGame(JSON.stringify({ ...validEnvelope, version: GAME_STATE_VERSION + 1 })),
    /不支持的对局存档版本/,
  );

  const missingPlayers = cloneEnvelope(validEnvelope);
  delete missingPlayers.state.players;
  assert.throws(() => deserializeGame(JSON.stringify(missingPlayers)), /缺少必要字段：players/);

  const wrongPlayerCount = cloneEnvelope(validEnvelope);
  wrongPlayerCount.state.players = [wrongPlayerCount.state.players[0]];
  assert.throws(() => deserializeGame(JSON.stringify(wrongPlayerCount)), /必须包含 2 名玩家/);

  const missingKeywordUsage = cloneEnvelope(validEnvelope);
  delete missingKeywordUsage.state.players[0].keywordUsage;
  assert.throws(() => deserializeGame(JSON.stringify(missingKeywordUsage)), /关键词使用状态无效/);

  const malformedEncourage = cloneEnvelope(validEnvelope);
  malformedEncourage.state.players[0].keywordUsage.encourage = 'bad';
  assert.throws(() => deserializeGame(JSON.stringify(malformedEncourage)), /关键词使用状态无效/);
});

function cloneEnvelope(envelope) {
  return JSON.parse(JSON.stringify(envelope));
}

test('realm deployment creates unique runtime identities and replaces the same definition at full durability', () => {
  let state = createGame(301);
  state.players[0].units.find((unit) => unit.id === 'basalt').level = 3;
  state.players[0].energy = 10;
  const firstCard = putCardInHand(state, 0, 'wardline');
  state = playCard(state, 0, firstCard.instanceId).state;
  const firstRealm = state.players[0].realms[0];
  assert.match(firstRealm.uid, /^realm-\d+$/);
  assert.equal(firstRealm.hp, 5);
  assert.equal(firstRealm.maxHp, 5);

  firstRealm.hp = 1;
  const secondCard = putCardInHand(state, 0, 'wardline');
  state.players[0].energy = 10;
  state = playCard(state, 0, secondCard.instanceId).state;
  assert.equal(state.players[0].realms.length, 1);
  assert.notEqual(state.players[0].realms[0].uid, firstRealm.uid);
  assert.equal(state.players[0].realms[0].hp, 5);
  assert.equal(state.players[0].realms[0].maxHp, 5);
});

test('a basic attack can target a realm without damaging the front or taking counter damage', () => {
  let state = createGame(302);
  state.players[0].units.find((unit) => unit.id === 'basalt').level = 3;
  state.players[0].energy = 10;
  state = playCard(state, 0, putCardInHand(state, 0, 'wardline').instanceId).state;
  state.players[0].frontUnitId = state.players[0].units.find((unit) => unit.id === 'basalt').uid;
  state = endTurn(state, 0).state;
  state.players[1].levelUpUsed = true; // 回合开始重置后补标记

  const realmId = state.players[0].realms[0].uid;
  const attacker = state.players[1].units[1];
  const defender = state.players[0].units.find((unit) => unit.uid === state.players[0].frontUnitId);
  const attackerHp = attacker.hp;
  const defenderHp = defender.hp;
  assert.ok(getValidCombatTargets(state, 1).includes(realmId));

  state = basicAttack(state, 1, attacker.uid, realmId).state;
  assert.equal(state.players[0].realms[0].hp, 5 - attacker.attack);
  assert.equal(state.players[0].units.find((unit) => unit.uid === defender.uid).hp, defenderHp);
  assert.equal(state.players[1].units.find((unit) => unit.uid === attacker.uid).hp, attackerHp);
  assert.equal(state.players[1].frontUnitId, attacker.uid);
});

test('destroying a realm removes it immediately and records damage before destruction', () => {
  let state = createGame(303);
  state.players[0].units.find((unit) => unit.id === 'basalt').level = 3;
  state.players[0].energy = 10;
  state = playCard(state, 0, putCardInHand(state, 0, 'wardline').instanceId).state;
  state.players[0].realms[0].hp = 1;
  const realmId = state.players[0].realms[0].uid;
  state = endTurn(state, 0).state;
  state.players[1].levelUpUsed = true; // 回合开始重置后补标记

  const realmAttacker = state.players[1].units[0];
  state.players[1].frontUnitId = realmAttacker.uid;
  state = basicAttack(state, 1, realmAttacker.uid, realmId).state;
  assert.equal(state.players[0].realms.length, 0);
  const realmEvents = state.events
    .filter((event) => event.payload.realmId === realmId)
    .sort((left, right) => left.id - right.id);
  assert.deepEqual(realmEvents.slice(-2).map((event) => event.type), [
    GAME_EVENTS.REALM_DAMAGED,
    GAME_EVENTS.REALM_DESTROYED,
  ]);
});

test('a combat card can explicitly attack a realm', () => {
  let state = createGame(304);
  state.players[0].units.find((unit) => unit.id === 'basalt').level = 3;
  state.players[0].energy = 10;
  state = playCard(state, 0, putCardInHand(state, 0, 'wardline').instanceId).state;
  const realmId = state.players[0].realms[0].uid;
  state = endTurn(state, 0).state;
  const attacker = state.players[1].units.find((unit) => unit.id === 'storm');
  const combatCard = putCardInHand(state, 1, 'static-dash');

  const result = playCard(state, 1, combatCard.instanceId, realmId);
  assert.equal(result.error, null);
  assert.ok(result.state.players[0].realms[0].hp < 5);
});

test('serialization preserves damaged realms and rejects forged realm identity or durability', () => {
  let state = createGame(305);
  state.players[0].units.find((unit) => unit.id === 'basalt').level = 3;
  state.players[0].energy = 10;
  state = playCard(state, 0, putCardInHand(state, 0, 'wardline').instanceId).state;
  state.players[0].realms[0].hp = 2;
  const restored = deserializeGame(serializeGame(state));
  assert.equal(restored.players[0].realms[0].hp, 2);

  const forgedHp = JSON.parse(serializeGame(state));
  forgedHp.state.players[0].realms[0].hp = 99;
  assert.throws(() => deserializeGame(JSON.stringify(forgedHp)), /幻境实例无效/);

  const forgedCard = JSON.parse(serializeGame(state));
  forgedCard.state.players[0].realms[0].cardId = 'missing-realm';
  assert.throws(() => deserializeGame(JSON.stringify(forgedCard)), /幻境实例无效/);

  const duplicate = JSON.parse(serializeGame(state));
  duplicate.state.players[1].realms.push(cloneEnvelope(duplicate.state.players[0].realms[0]));
  assert.throws(() => deserializeGame(JSON.stringify(duplicate)), /幻境实例无效/);
});

test('battle zone starts empty and a knockout leaves it empty without auto replacement', () => {
  const state = createGame(13);
  // 本家规则：开局双方战斗区为空，所有角色都在准备区
  assert.equal(state.players[0].frontUnitId, null);
  assert.equal(state.players[1].frontUnitId, null);

  // 敌方战斗区有人被气绝后，战斗区变空，不自动补位
  const defender = state.players[1].units[0];
  state.players[1].frontUnitId = defender.uid;
  defender.hp = 1;
  const attacker = state.players[0].units[0];
  const result = basicAttack(state, 0, attacker.uid);
  assert.equal(result.error, null);
  assert.equal(result.state.players[1].frontUnitId, null);
  const nextDefender = result.state.players[1].units.find((unit) => unit.uid === defender.uid);
  assert.equal(nextDefender.hp, 0);
  assert.ok(result.state.players[1].units.slice(1).every((unit) => unit.hp > 0), '其他角色不应被自动补位影响');
});

test('battle-zone unit returns to reserve at the start of its owner turn', () => {
  let state = createGame(14);
  const unit = state.players[0].units[2];
  state.players[0].frontUnitId = unit.uid;

  // 对手回合内留场可被攻击
  state = endTurn(state, 0).state;
  assert.equal(state.players[0].frontUnitId, unit.uid, '对手回合内应留在战斗区');
  state = endTurn(state, 1).state;
  assert.equal(state.players[0].frontUnitId, null, '己方回合开始时应归位准备区');
  assert.ok(state.events.some((event) => (
    event.type === GAME_EVENTS.UNIT_RETURNED
      && event.payload.unitId === unit.uid
      && event.payload.source === 'battle-zone'
  )));
  assert.ok(unit.hp > 0, '归位角色保持存活');
});

test('attacking into an empty battle zone hits the core directly', () => {
  const state = createGame(15);
  assert.equal(state.players[1].frontUnitId, null);
  assert.deepEqual(getValidCombatTargets(state, 0), []);
  const attacker = state.players[0].units[0];
  const coreBefore = state.players[1].avatarHp;

  const result = basicAttack(state, 0, attacker.uid);
  assert.equal(result.error, null);
  assert.equal(result.state.players[1].avatarHp, coreBefore - result.state.players[0].units[0].attack);
  assert.equal(result.state.players[0].frontUnitId, attacker.uid, '攻击者留场');
});

test('attacking with a second unit replaces the battle-zone occupant back to reserve', () => {
  const state = createGame(16);
  const first = state.players[0].units[0];
  const second = state.players[0].units[2];
  state.players[0].energy = 10;
  state.players[0].attackUsed = false;

  // 第一名角色出击留场
  let next = basicAttack(state, 0, first.uid, null).state;
  next.players[0].attackUsed = false;
  // 第二名角色出击替换：原战斗区角色回准备区
  const replaced = basicAttack(next, 0, second.uid);
  assert.equal(replaced.error, null);
  assert.equal(replaced.state.players[0].frontUnitId, second.uid);
  const enteredEvents = replaced.state.events.filter((event) => (
    event.type === GAME_EVENTS.UNIT_ENTERED_FRONT && event.payload.unitId === second.uid
  ));
  assert.equal(enteredEvents.length, 1);
  assert.equal(enteredEvents[0].payload.previousFrontUnitId, first.uid, '被替换角色回到准备区');
});

test('upgrade phase is enforced before playing cards or attacking', () => {
  const state = rawCreateGame(17);
  // 新回合未升勾且有可升级角色时：出牌与出击都被拦截（手动塞牌避免助手改写升勾标记）
  assert.equal(isUpgradePending(state, 0), true);
  state.players[0].hand.push({ instanceId: 'manual-mend', definitionId: 'mend' });
  const allyUid = state.players[0].units[1].uid;
  assert.equal(playCard(state, 0, 'manual-mend', allyUid).error, '升级阶段：请先选择一名角色提升勾玉。');
  assert.match(basicAttack(state, 0, state.players[0].units[0].uid).error, /升级阶段/);

  // 升勾后解除限制
  const leveled = levelUpUnit(state, 0, state.players[0].units[0].uid);
  assert.equal(leveled.error, null);
  assert.equal(isUpgradePending(leveled.state, 0), false);
  assert.equal(getCardPlayability(leveled.state, 0, 'manual-mend', {}).code, 'ready');
  assert.equal(playCard(leveled.state, 0, 'manual-mend', allyUid).error, null);

  // 全员满勾时不再强制
  const maxed = rawCreateGame(18);
  maxed.players.forEach((player) => {
    player.units.forEach((unit) => { unit.level = GAME_RULES.maxUnitLevel; });
  });
  assert.equal(isUpgradePending(maxed, 0), false);
});
