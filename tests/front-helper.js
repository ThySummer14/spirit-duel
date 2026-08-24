import { GAME_RULES } from '../game-core.js';

// 测试助手：把指定角色的角色显式部署到该方战斗区（模拟出击后的留场状态）
export function deployToFront(state, playerIndex, unitId) {
  if (!state || state.winner !== null) throw new Error('对局尚未开始或已结束。');
  const player = state.players[playerIndex];
  const unit = player.units.find((candidate) => candidate.uid === unitId);
  if (!unit || unit.hp <= 0) throw new Error('只能部署存活的角色到战斗区。');
  player.frontUnitId = unit.uid;
}

// 测试助手：标记升级阶段已完成（新规则要求升勾先于出牌/出击）
export function completeUpgradePhase(state, playerIndex = 0) {
  state.players[playerIndex].levelUpUsed = true;
}

// 通用测试助手：各测试文件共用的手牌塞入与 createGame 包装
export function putCardInHand(state, playerIndex, definitionId) {
  const instance = { instanceId: `test-${definitionId}-${state.players[playerIndex].hand.length}`, definitionId };
  state.players[playerIndex].levelUpUsed = true; // 新规则：出牌前需完成升级阶段
  state.players[playerIndex].hand.push(instance);
  return instance;
}

export function makeWrappedCreateGame(rawCreateGame) {
  return (input = undefined) => {
    const state = rawCreateGame(input);
    state.players.forEach((player) => {
      player.levelUpUsed = true;
      player.units.forEach((unit) => { if (unit.level < 1) unit.level = 1; });
    });
    return state;
  };
}
