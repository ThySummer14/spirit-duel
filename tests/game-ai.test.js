import test from 'node:test';
import assert from 'node:assert/strict';

import { chooseAiCommand } from '../game-ai.js';
import {
  basicAttack,
  createGame,
  endTurn,
  levelUpUnit,
  passResponse,
  playCard,
  resolveDivinationChoice,
} from '../game-core.js';

function beginAiTurn(options = {}) {
  const state = createGame({ seed: 701, ...options });
  return endTurn(state, 0).state;
}

function putCardInHand(state, playerIndex, definitionId) {
  const instance = { instanceId: `ai-test-${definitionId}`, definitionId };
  state.players[playerIndex].hand.push(instance);
  return instance;
}

function applyCommand(state, playerIndex, command) {
  if (command.type === 'play-card') {
    return playCard(state, playerIndex, command.instanceId, command.targetId);
  }
  if (command.type === 'level-up') return levelUpUnit(state, playerIndex, command.unitId);
  if (command.type === 'attack') return basicAttack(state, playerIndex, command.unitId, command.targetId);
  if (command.type === 'divination-choice') return resolveDivinationChoice(state, playerIndex, command.instanceId);
  if (command.type === 'pass-response') return passResponse(state, playerIndex);
  return endTurn(state, playerIndex);
}

test('resolves an AI divination choice with a legal top-deck card', () => {
  let state = beginAiTurn({ enemyUnitIds: ['ink', 'ember', 'basalt', 'lumen'] });
  state.players[1].units.find((unit) => unit.id === 'ink').level = 2;
  state.players[1].hand = [];
  const divination = putCardInHand(state, 1, 'index-page');
  state = playCard(state, 1, divination.instanceId).state;

  const command = chooseAiCommand(state, 1);
  assert.equal(command.type, 'divination-choice');
  assert.ok(state.pendingChoice.instanceIds.includes(command.instanceId));
  const result = applyCommand(state, 1, command);
  assert.equal(result.error, null);
  assert.equal(result.state.pendingChoice, null);
  assert.equal(result.state.players[1].deck.at(-1).instanceId, command.instanceId);
});

test('prioritizes an immediate core lethal', () => {
  const state = beginAiTurn({ enemyUnitIds: ['ember', 'basalt', 'lumen', 'rime'] });
  state.players[1].hand = [];
  state.players[1].units.find((unit) => unit.id === 'ember').level = 3;
  state.players[0].avatarHp = 2;
  const lethal = putCardInHand(state, 1, 'horizon-burn');

  const command = chooseAiCommand(state);

  assert.equal(command.type, 'play-card');
  assert.equal(command.instanceId, lethal.instanceId);
  assert.equal(command.score, 1_000_000);
  assert.match(command.reason, /立即赢得/);
});

test('removes a threatening front unit with a clean damage spell', () => {
  const state = beginAiTurn();
  const threat = state.players[0].units[1];
  threat.hp = 3;
  threat.attack = 8;
  state.players[0].frontUnitId = threat.uid;
  state.players[1].hand = [];
  const removal = putCardInHand(state, 1, 'needle-arc');

  const command = chooseAiCommand(state);

  assert.equal(command.type, 'play-card');
  assert.equal(command.instanceId, removal.instanceId);
  assert.equal(command.targetId, threat.uid);
  assert.match(command.reason, /气绝/);
});

test('returns a legal command or falls back to end-turn', () => {
  const actionable = beginAiTurn();
  const command = chooseAiCommand(actionable);
  const result = applyCommand(actionable, 1, command);
  assert.equal(result.error, null);

  const exhausted = beginAiTurn();
  exhausted.players[1].hand = [];
  exhausted.players[1].energy = 0;
  exhausted.players[1].attackUsed = true;
  exhausted.players[1].levelUpUsed = true;
  assert.deepEqual(chooseAiCommand(exhausted), {
    type: 'end-turn',
    score: 0,
    reason: '没有剩余的有效行动，结束回合。',
  });
});

test('uses response priority during the player turn when preventing damage is beneficial', () => {
  const state = createGame({
    seed: 703,
    enemyUnitIds: ['rime', 'basalt', 'lumen', 'ink'],
  });
  state.players[0].energy = 2;
  state.players[1].energy = 2;
  state.players[0].hand = [];
  state.players[1].hand = [];
  const damage = putCardInHand(state, 0, 'cinder-mark');
  const response = putCardInHand(state, 1, 'hoar-barrier');
  const target = state.players[1].units.find((unit) => unit.id === 'rime');
  const pending = playCard(state, 0, damage.instanceId, target.uid).state;

  assert.equal(pending.currentPlayer, 0);
  assert.equal(pending.responseWindow.playerIndex, 1);
  const command = chooseAiCommand(pending, 1);
  assert.equal(command.type, 'play-card');
  assert.equal(command.instanceId, response.instanceId);
  assert.equal(applyCommand(pending, 1, command).error, null);
});

test('passes response priority instead of ending the current turn when no response is useful', () => {
  const state = createGame({
    seed: 704,
    enemyUnitIds: ['rime', 'basalt', 'lumen', 'ink'],
  });
  state.players[0].energy = 2;
  state.players[1].energy = 0;
  state.players[0].hand = [];
  state.players[1].hand = [];
  const damage = putCardInHand(state, 0, 'cinder-mark');
  putCardInHand(state, 0, 'hoar-barrier');
  putCardInHand(state, 1, 'hoar-barrier');
  const target = state.players[1].units.find((unit) => unit.id === 'rime');
  const pending = playCard(state, 0, damage.instanceId, target.uid).state;

  const command = chooseAiCommand(pending, 1);
  assert.equal(command.type, 'pass-response');
  assert.equal(applyCommand(pending, 1, command).error, null);
});

test('does not repeat level-up after the free upgrade is consumed', () => {
  const state = beginAiTurn();
  state.players[1].hand = [];
  state.players[1].attackUsed = true;

  const first = chooseAiCommand(state);
  assert.equal(first.type, 'level-up');
  const leveled = applyCommand(state, 1, first);
  assert.equal(leveled.error, null);
  assert.equal(leveled.state.players[1].levelUpUsed, true);

  const second = chooseAiCommand(leveled.state);
  assert.equal(second.type, 'end-turn');
});

test('does not mutate the supplied state', () => {
  const state = beginAiTurn();
  const snapshot = structuredClone(state);

  chooseAiCommand(state);

  assert.deepEqual(state, snapshot);
});

test('targets and destroys a low-durability enemy realm without mutating the supplied state', () => {
  let state = createGame(702);
  state.players[0].units.find((unit) => unit.id === 'basalt').level = 3;
  state.players[0].energy = 10;
  state = playCard(state, 0, putCardInHand(state, 0, 'wardline').instanceId).state;
  state.players[0].realms[0].hp = 1;
  const guarded = state.players[0].units[0];
  state.players[0].frontUnitId = guarded.uid;
  guarded.shield = 20;
  state = endTurn(state, 0).state;
  state.players[1].hand = [];
  const snapshot = structuredClone(state);
  const realmId = state.players[0].realms[0].uid;

  const command = chooseAiCommand(state, 1);
  assert.equal(command.type, 'attack');
  assert.equal(command.targetId, realmId);
  assert.deepEqual(state, snapshot);

  const result = applyCommand(state, 1, command);
  assert.equal(result.error, null);
  assert.equal(result.state.players[0].realms.length, 0);
});

test('completes a full AI turn with only legal commands inside the safety limit', () => {
  let state = beginAiTurn();
  const commands = [];

  for (let step = 0; step < 8; step += 1) {
    const command = chooseAiCommand(state);
    commands.push(command.type);
    const result = applyCommand(state, 1, command);
    assert.equal(result.error, null);
    state = result.state;
    if (command.type === 'end-turn') break;
  }

  assert.equal(commands.at(-1), 'end-turn');
  assert.ok(commands.length <= 8);
  assert.equal(state.currentPlayer, 0);
});
