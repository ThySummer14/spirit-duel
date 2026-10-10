import test from 'node:test';
import assert from 'node:assert/strict';
import { createGame, getCardDefinition, playCard } from '../game-core.js';
import { makeWrappedCreateGame, putCardInHand } from './front-helper.js';

const createGameReady = makeWrappedCreateGame((input) => createGame(input));

function phoenixFixture(seed = 12409) {
  const lineup = ['fenghuanghuo', 'datiangou', 'yaoginshi', 'basalt'];
  const state = createGameReady({ seed, playerUnitIds: lineup, enemyUnitIds: lineup });
  const player = state.players[0];
  player.hand = [];
  player.energy = 40;
  player.units.forEach((unit) => {
    unit.level = 3;
    unit.passive_hooks = [];
  });
  return state;
}

function play(state, definitionId, targetId = null) {
  putCardInHand(state, 0, definitionId);
  const instance = state.players[0].hand.at(-1);
  const result = playCard(state, 0, instance.instanceId, targetId);
  assert.equal(result.error, null, result.error ?? definitionId);
  return result.state;
}

test('凤鸣按维护公告为2伤并独立触发投射', () => {
  let state = phoenixFixture();
  const card = getCardDefinition('c12401');
  assert.equal(card.text.includes('2点'), true);
  assert.equal(card.phoenixBaseDamage, 2);
  state = play(state, 'c12401');
  assert.equal(state.players[1].avatarHp, 27);
  assert.equal(state.players[0].units[0].phoenixAvatarHits, 2);
});

test('引燃仅在击杀时追加牌手伤害', () => {
  let state = phoenixFixture();
  state.players[1].frontUnitId = state.players[1].units[3].uid;
  const targetUid = state.players[1].units[0].uid;
  state = play(state, 'c12407', targetUid);
  assert.equal(state.players[1].units[0].hp, 2);
  assert.equal(state.players[1].avatarHp, 30);
  state.players[1].units[0].hp = 2;
  state = play(state, 'c12407', targetUid);
  assert.equal(state.players[1].units[0].hp, 0);
  assert.equal(state.players[1].avatarHp, 28);
});

test('焚羽以setBase安装身材并加成非战斗伤害', () => {
  let state = phoenixFixture();
  state = play(state, 'c12403');
  const phoenix = state.players[0].units[0];
  assert.equal(phoenix.attack, 4);
  assert.equal(phoenix.maxHp, 6);
  assert.equal(phoenix.formRules.nonCombatDamageBonus, 1);
  state = play(state, 'c12401');
  assert.equal(state.players[1].avatarHp, 25);
});

test('觉醒后可重复叠身材且队友法术触发投射', () => {
  let state = phoenixFixture();
  state = play(state, 'c12408');
  assert.equal(state.players[0].units[0].awakened, true);
  assert.equal(state.players[1].avatarHp, 29);
  const basalt = state.players[0].units[3];
  state = play(state, 'brace', basalt.uid);
  assert.equal(state.players[1].avatarHp, 28);
  const before = state.players[0].units[0].attack;
  state = play(state, 'c12408');
  assert.equal(state.players[0].units[0].attack, before + 1);
});
