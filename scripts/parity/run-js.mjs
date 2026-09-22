#!/usr/bin/env node
/**
 * 双实现对拍 · JS 侧
 * 用法: node scripts/parity/run-js.mjs scripts/parity/sample-origin.json out/js-snapshot.json
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import { createGame, playCard, levelUpUnit, basicAttack, endTurn, passResponse, resolveDivinationChoice, serializeGame } from '../../game-core.js';
import { createDefaultDeckDefinition, getCardsForUnit } from '../../game-content.js';

function snapshot(state) {
  return {
    turn: state.turnCounter,
    current: state.currentPlayer,
    winner: state.winner === null ? -1 : state.winner,
    phase: state.phase,
    responseWindow: state.responseWindow !== null,
    stackDepth: state.resolutionStack?.length ?? 0,
    pendingChoice: state.pendingChoice != null,
    encourage: {
      attack: state.players[0]?.keywordUsage?.encourage?.attack ?? 0,
      shield: state.players[0]?.keywordUsage?.encourage?.shield ?? 0,
    },
    players: state.players.map((player) => ({
      avatarHp: player.avatarHp,
      energy: player.energy,
      handCount: player.hand.length,
      deckCount: player.deck.length,
      attackUsed: player.attackUsed === true,
      levelUpUsed: player.levelUpUsed === true,
      frontUnitId: player.frontUnitId,
      units: player.units.map((unit) => ({
        id: unit.id,
        hp: unit.hp,
        maxHp: unit.maxHp,
        attack: unit.attack,
        shield: unit.shield,
        knockout: unit.knockout,
        frozen: unit.frozen,
        level: unit.level,
        awakened: unit.awakened === true,
        formId: unit.form?.cardId ?? null,
        front: player.frontUnitId === unit.uid,
      })),
    })),
  };
}

function findHandIndex(state, playerIndex, cardId) {
  return state.players[playerIndex].hand.findIndex((item) => item.definitionId === cardId);
}

function applyNeutral(state, cmd) {
  const p = cmd.player;
  if (cmd.type === 'level-up') {
    const unit = state.players[p].units[cmd.unit];
    const result = levelUpUnit(state, p, unit.uid);
    return result;
  }
  if (cmd.type === 'play-card') {
    const handIndex = findHandIndex(state, p, cmd.card);
    if (handIndex < 0) return { state, error: `手中没有 ${cmd.card}` };
    const instance = state.players[p].hand[handIndex];
    return playCard(state, p, instance.instanceId, cmd.target ?? null);
  }
  if (cmd.type === 'attack') {
    const unit = state.players[p].units[cmd.unit];
    return basicAttack(state, p, unit.uid, cmd.target ?? null);
  }
  if (cmd.type === 'end-turn') return endTurn(state, p);
  if (cmd.type === 'pass-response') return passResponse(state, p);
  if (cmd.type === 'divination-choice') {
    const pending = state.pendingChoice;
    if (!pending) return { state, error: 'no pending choice' };
    const shown = new Set(pending.instanceIds ?? []);
    let instance = state.players[p].deck.find((item) => item.instanceId === cmd.card);
    if (!instance) {
      instance = state.players[p].deck.find((item) => shown.has(item.instanceId) && item.definitionId === cmd.card);
    }
    if (!instance) {
      instance = state.players[p].deck.find((item) => item.definitionId === cmd.card);
    }
    if (!instance) return { state, error: `deck missing ${cmd.card}` };
    return resolveDivinationChoice(state, p, instance.instanceId);
  }
  return { state, error: `未知命令 ${cmd.type}` };
}

const [, , samplePath, outPath] = process.argv;
if (!samplePath || !outPath) {
  console.error('usage: node scripts/parity/run-js.mjs <sample.json> <out.json>');
  process.exit(2);
}
const sample = JSON.parse(readFileSync(samplePath, 'utf8'));
const playerDeckDefinition = createDefaultDeckDefinition(sample.lineupA);
const enemyDeckDefinition = createDefaultDeckDefinition(sample.lineupB);
let state = createGame({
  seed: sample.seed,
  playerDeckDefinition,
  enemyDeckDefinition,
});
if (Array.isArray(sample.injectHand)) {
  for (const item of sample.injectHand) {
    const pIdx = item.player ?? 0;
    state.players[pIdx].hand.push({
      instanceId: `${state.players[pIdx].id}-inj-${state.nextCardId}`,
      definitionId: item.card,
      isHolo: false,
    });
    state.nextCardId += 1;
  }
}
if (Array.isArray(sample.injectDeckTop)) {
  for (const item of sample.injectDeckTop) {
    const pIdx = item.player ?? 0;
    state.players[pIdx].deck.push({
      instanceId: `${state.players[pIdx].id}-top-${state.nextCardId}`,
      definitionId: item.card,
      isHolo: false,
    });
    state.nextCardId += 1;
  }
}
if (Array.isArray(sample.injectLevels)) {
  for (const item of sample.injectLevels) {
    const pIdx = item.player ?? 0;
    const unit = state.players[pIdx].units[item.unit ?? 0];
    if (unit) unit.level = item.level ?? 1;
  }
}
if (Array.isArray(sample.injectEnergy)) {
  for (const item of sample.injectEnergy) {
    const pIdx = item.player ?? 0;
    state.players[pIdx].energy = (state.players[pIdx].energy ?? 0) + (item.amount ?? 0);
  }
}
const steps = [];
for (const cmd of sample.commands) {
  const before = snapshot(state);
  const result = applyNeutral(state, cmd);
  if (result.error) {
    steps.push({ seq: cmd.seq, type: cmd.type, ok: false, error: result.error, before });
    // 对拍脚本允许失败记录，继续跑完以便比对
    state = result.state ?? state;
    continue;
  }
  state = result.state;
  steps.push({ seq: cmd.seq, type: cmd.type, ok: true, after: snapshot(state) });
}
const payload = {
  side: 'js',
  sample: sample.name,
  seed: sample.seed,
  snapshot: snapshot(state),
  steps,
  initialStateHash: serializeGame(createGame({
    seed: sample.seed,
    playerDeckDefinition: createDefaultDeckDefinition(sample.lineupA),
    enemyDeckDefinition: createDefaultDeckDefinition(sample.lineupB),
  })).length,
};
mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, JSON.stringify(payload, null, 2) + '\n');
console.log(`JS_PARITY_OK steps=${steps.length} ok=${steps.filter((s) => s.ok).length} → ${outPath}`);
