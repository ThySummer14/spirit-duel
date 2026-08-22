import { GAME_RULES } from './game-core.js';

// 测试助手：把指定角色的角色显式部署到该方战斗区（模拟出击后的留场状态）
export function deployToFront(state, playerIndex, unitId) {
  if (!state || state.winner !== null) throw new Error('对局尚未开始或已结束。');
  const player = state.players[playerIndex];
  const unit = player.units.find((candidate) => candidate.uid === unitId);
  if (!unit || unit.hp <= 0) throw new Error('只能部署存活的角色到战斗区。');
  player.frontUnitId = unit.uid;
}
