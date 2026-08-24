#!/usr/bin/env node
/**
 * balance-smoke.mjs — AI 对 AI 批量对局冒烟
 *
 * 双方均由 chooseAiCommand 驱动，批量跑对局并汇总：
 * - 崩溃 / 非法命令 / 超长对局（软锁）检测
 * - 回合数、胜负分布、激活与勾玉节奏（实际效果体检）
 *
 * 用法：node scripts/balance-smoke.mjs [对局数=30] [起始种子=1]
 */
import {
  basicAttack,
  createGame,
  endTurn,
  levelUpUnit,
  passResponse,
  playCard,
  resolveDivinationChoice,
} from '../game-core.js';
import { chooseAiCommand } from '../game-ai.js';

const GAMES = Number(process.argv[2] ?? 30);
const SEED_BASE = Number(process.argv[3] ?? 1);
const TURN_CAP = 300; // 半回合上限：超过即视为软锁

const applyCommand = (state, playerIndex, command) => {
  switch (command.type) {
    case 'play-card':
      return playCard(state, playerIndex, command.instanceId, command.targetId);
    case 'attack':
      return basicAttack(state, playerIndex, command.unitId, command.targetId);
    case 'level-up':
      return levelUpUnit(state, playerIndex, command.unitId);
    case 'divination-choice':
      return resolveDivinationChoice(state, playerIndex, command.instanceId);
    case 'pass-response':
      return passResponse(state, playerIndex);
    default:
      return endTurn(state, playerIndex);
  }
};

const stats = {
  crashes: 0,
  softlocks: 0,
  illegal: 0,
  finished: 0,
  playerWins: 0,
  aiWins: 0,
  rounds: [],
  maxRound: 0,
  fullLevelGames: 0,
};

for (let game = 0; game < GAMES; game += 1) {
  let state = createGame(SEED_BASE + game * 7919);
  let halfTurns = 0;
  let failure = null;
  try {
    let idleTurns = 0;
  while (state.winner === null && halfTurns < TURN_CAP) {
      const playerIndex = state.currentPlayer;
      const command = chooseAiCommand(state, playerIndex, { aggressive: idleTurns >= 8 });
      idleTurns = command.type === 'end-turn' ? idleTurns + 1 : 0;
      const result = applyCommand(state, playerIndex, command);
      if (result.error) {
        failure = `非法命令：${command.type}(${command.reason ?? ''}) → ${result.error}`;
        stats.illegal += 1;
        break;
      }
      state = result.state;
      halfTurns += 1;
    }
  } catch (error) {
    stats.crashes += 1;
    failure = `崩溃：${error.message}`;
  }

  if (failure) {
    console.log(`[seed ${SEED_BASE + game * 7919}] ${failure}`);
    continue;
  }
  if (state.winner === null) {
    stats.softlocks += 1;
    console.log(`[seed ${SEED_BASE + game * 7919}] 软锁：${halfTurns} 半回合未分胜负`);
    continue;
  }
  stats.finished += 1;
  if (state.winner === 0) stats.playerWins += 1;
  else stats.aiWins += 1;
  const rounds = Math.ceil(state.turnCounter / 2);
  stats.rounds.push(rounds);
  stats.maxRound = Math.max(stats.maxRound, rounds);
  const allMax = state.players.every((player) => player.units.every((unit) => unit.level === 3));
  if (allMax) stats.fullLevelGames += 1;
}

const avg = stats.rounds.length
  ? (stats.rounds.reduce((sum, value) => sum + value, 0) / stats.rounds.length).toFixed(1)
  : '-';
console.log('\n===== 冒烟汇总 =====');
console.log(`对局数：${GAMES}｜完成 ${stats.finished}｜崩溃 ${stats.crashes}｜非法命令 ${stats.illegal}｜软锁 ${stats.softlocks}`);
if (stats.finished) {
  console.log(`胜负：先手 ${stats.playerWins} / 后手 ${stats.aiWins}｜平均 ${avg} 回合｜最长 ${stats.maxRound} 回合`);
  console.log(`全员满勾（3 勾）对局：${stats.fullLevelGames}/${stats.finished}`);
}
process.exitCode = stats.crashes + stats.softlocks + stats.illegal > 0 ? 1 : 0;
