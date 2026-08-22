import test from 'node:test';
import assert from 'node:assert/strict';

import {
  basicAttack,
  createGame,
  endTurn,
  levelUpUnit,
  playCard,
} from '../game-core.js';
import {
  captureBattleSnapshot,
  deriveBattleFeedback,
} from '../game-presentation.js';

function putCardInHand(state, playerIndex, definitionId) {
  const instance = { instanceId: `test-${definitionId}-${state.players[playerIndex].hand.length}`, definitionId };
  state.players[playerIndex].hand.push(instance);
  return instance;
}

test('derives attacker and defender impacts from a combat', () => {
  const state = createGame(201);
  state.players[0].frontUnitId = state.players[0].units[0].uid;
  state.players[1].frontUnitId = state.players[1].units[0].uid;
  const attackerUid = state.players[0].frontUnitId;
  const defenderUid = state.players[1].frontUnitId;
  const snapshot = captureBattleSnapshot(state);
  const next = basicAttack(state, 0, attackerUid).state;

  const feedback = deriveBattleFeedback(snapshot, next);

  assert.equal(feedback.unitImpacts.get(attackerUid).isAttacker, true);
  assert.ok(feedback.unitImpacts.get(attackerUid).hpDelta < 0);
  assert.equal(feedback.unitImpacts.get(attackerUid).isRemoteAttacker, false);
  assert.ok(feedback.unitImpacts.get(defenderUid).hpDelta < 0);
  assert.equal(feedback.unitImpacts.get(defenderUid).isAttacker, false);
  assert.equal(feedback.cue.type, 'combat');
  assert.equal(feedback.cue.unitId, attackerUid);
});

test('distinguishes a remote attacker that remains in reserve and takes no counter damage', () => {
  const state = createGame({ seed: 207, playerUnitIds: ['storm', 'basalt', 'lumen', 'rime'] });
  state.players[1].hand = [];
  const storm = state.players[0].units.find((unit) => unit.id === 'storm');
  const basalt = state.players[0].units.find((unit) => unit.id === 'basalt');
  const defender = state.players[1].units[0];
  state.players[1].frontUnitId = defender.uid;
  state.players[0].frontUnitId = basalt.uid;
  defender.maxHp = 20;
  defender.hp = 20;
  const frontBefore = state.players[0].frontUnitId;
  const snapshot = captureBattleSnapshot(state);
  const card = putCardInHand(state, 0, 'static-dash');
  const next = playCard(state, 0, card.instanceId).state;

  const feedback = deriveBattleFeedback(snapshot, next);
  const attackerImpact = feedback.unitImpacts.get(storm.uid);
  const defenderImpact = feedback.unitImpacts.get(defender.uid);

  assert.equal(next.players[0].frontUnitId, frontBefore);
  assert.equal(attackerImpact.isAttacker, true);
  assert.equal(attackerImpact.isRemoteAttacker, true);
  assert.equal(attackerImpact.hpDelta, 0);
  assert.ok(defenderImpact.hpDelta < 0);
  assert.equal(feedback.cue.type, 'remote-combat');
  assert.match(feedback.cue.kicker, /远程出击/);
  assert.match(feedback.cue.detail, /目标无法反击/);
});

test('shows keyword readiness and marks the next attacker as empowered', () => {
  let state = createGame(208);
  const readySnapshot = captureBattleSnapshot(state);
  const card = putCardInHand(state, 0, 'radiant-encouragement');
  state = playCard(state, 0, card.instanceId).state;
  const readyFeedback = deriveBattleFeedback(readySnapshot, state);
  assert.equal(readyFeedback.cue.type, 'keyword-gained');
  assert.match(readyFeedback.cue.title, /鼓舞/);

  const attackerUid = state.players[0].units[0].uid;
  const combatSnapshot = captureBattleSnapshot(state);
  const next = basicAttack(state, 0, attackerUid).state;
  const combatFeedback = deriveBattleFeedback(combatSnapshot, next);
  assert.equal(combatFeedback.unitImpacts.get(attackerUid).isKeywordEmpowered, true);
  assert.match(combatFeedback.cue.detail, /攻击 \+2，护盾 \+1/);
});

test('gives level-up feedback priority and reports its delta', () => {
  const state = createGame(202);
  const unitUid = state.players[0].units[1].uid;
  const snapshot = captureBattleSnapshot(state);
  const next = levelUpUnit(state, 0, unitUid).state;

  const feedback = deriveBattleFeedback(snapshot, next);

  assert.equal(feedback.unitImpacts.get(unitUid).levelDelta, 1);
  assert.equal(feedback.cue.type, 'level-up');
  assert.equal(feedback.cue.unitId, unitUid);
});

test('gives knockout feedback priority over combat', () => {
  const state = createGame(203);
  const defender = state.players[1].units[0];
  defender.hp = 1;
  state.players[1].frontUnitId = defender.uid;
  const attackerUid = state.players[0].units[2].uid;
  const snapshot = captureBattleSnapshot(state);
  const next = basicAttack(state, 0, attackerUid).state;

  const feedback = deriveBattleFeedback(snapshot, next);
  const impact = feedback.unitImpacts.get(defender.uid);

  assert.equal(impact.knockedOut, true);
  assert.equal(impact.returned, false);
  assert.equal(feedback.cue.type, 'knockout');
  assert.equal(feedback.cue.unitId, defender.uid);
});

test('derives core damage without requiring a combat event', () => {
  const state = createGame(204);
  const snapshot = captureBattleSnapshot(state);
  const next = structuredClone(state);
  next.players[1].avatarHp -= 4;

  const feedback = deriveBattleFeedback(snapshot, next);

  assert.equal(feedback.coreImpacts.get(1).hpDelta, -4);
  assert.equal(feedback.cue.type, 'core-hit');
  assert.equal(feedback.cue.playerIndex, 1);
});

test('reports returned units and shield changes as unit impacts', () => {
  const state = createGame(205);
  const unit = state.players[0].units[2];
  unit.hp = 0;
  unit.shield = 2;
  const snapshot = captureBattleSnapshot(state);
  const next = structuredClone(state);
  const returned = next.players[0].units[2];
  returned.hp = 4;
  returned.shield = 0;

  const feedback = deriveBattleFeedback(snapshot, next);
  const impact = feedback.unitImpacts.get(unit.uid);

  assert.equal(impact.hpDelta, 4);
  assert.equal(impact.shieldDelta, -2);
  assert.equal(impact.returned, true);
  assert.equal(impact.knockedOut, false);
});

test('returns empty feedback for the first frame and unchanged states without mutations', () => {
  const state = createGame(206);
  const before = structuredClone(state);
  const snapshot = captureBattleSnapshot(state);

  const firstFrame = deriveBattleFeedback(null, state);
  const unchanged = deriveBattleFeedback(snapshot, state);

  assert.equal(firstFrame.unitImpacts.size, 0);
  assert.equal(firstFrame.coreImpacts.size, 0);
  assert.equal(firstFrame.cue, null);
  assert.equal(unchanged.unitImpacts.size, 0);
  assert.equal(unchanged.coreImpacts.size, 0);
  assert.equal(unchanged.cue, null);
  assert.deepEqual(state, before);
});

test('derives a visible realm impact when durability is lost', () => {
  let state = createGame(209);
  state.players[0].units.find((unit) => unit.id === 'basalt').level = 3;
  state.players[0].energy = 10;
  state = playCard(state, 0, putCardInHand(state, 0, 'wardline').instanceId).state;
  state = endTurn(state, 0).state;
  const realmId = state.players[0].realms[0].uid;
  const snapshot = captureBattleSnapshot(state);

  state.players[1].frontUnitId = state.players[1].units[0].uid;
  const next = basicAttack(state, 1, state.players[1].units[0].uid, realmId).state;
  const feedback = deriveBattleFeedback(snapshot, next);

  assert.ok(feedback.realmImpacts.get(realmId).hpDelta < 0);
  assert.equal(feedback.realmImpacts.get(realmId).destroyed, false);
  assert.equal(feedback.cue.type, 'realm-hit');
  assert.equal(feedback.cue.realmId, realmId);
});

test('gives realm destruction a high-priority central cue', () => {
  let state = createGame(210);
  state.players[0].units.find((unit) => unit.id === 'basalt').level = 3;
  state.players[0].energy = 10;
  state = playCard(state, 0, putCardInHand(state, 0, 'wardline').instanceId).state;
  state.players[0].realms[0].hp = 1;
  state = endTurn(state, 0).state;
  const realmId = state.players[0].realms[0].uid;
  const snapshot = captureBattleSnapshot(state);

  state.players[1].frontUnitId = state.players[1].units[0].uid;
  const next = basicAttack(state, 1, state.players[1].units[0].uid, realmId).state;
  const feedback = deriveBattleFeedback(snapshot, next);

  assert.equal(feedback.realmImpacts.get(realmId).destroyed, true);
  assert.equal(feedback.cue.type, 'realm-destroyed');
  assert.equal(feedback.cue.realmId, realmId);
});
