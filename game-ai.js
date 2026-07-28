import {
  basicAttack,
  canPlayCard,
  getCardDefinition,
  getCardPlayability,
  getValidCombatTargets,
  getValidTargets,
  levelUpUnit,
  passResponse,
  playCard,
  resolveDivinationChoice,
} from './game-core.js';

const WIN_SCORE = 1_000_000;

function unitByUid(player, unitId) {
  return player.units.find((unit) => unit.uid === unitId) ?? null;
}

function realmByUid(player, realmId) {
  return player.realms.find((realm) => realm.uid === realmId) ?? null;
}

function scoreTransition(before, after, playerIndex) {
  const enemyIndex = 1 - playerIndex;
  const beforePlayer = before.players[playerIndex];
  const afterPlayer = after.players[playerIndex];
  const beforeEnemy = before.players[enemyIndex];
  const afterEnemy = after.players[enemyIndex];
  const details = [];

  if (after.winner === playerIndex) return { score: WIN_SCORE, reason: '可立即赢得对局。' };
  if (after.winner === enemyIndex) return { score: -WIN_SCORE, reason: '该行动会立即输掉对局。' };

  let score = 0;
  const enemyCoreDamage = beforeEnemy.avatarHp - afterEnemy.avatarHp;
  const ownCoreHealing = afterPlayer.avatarHp - beforePlayer.avatarHp;
  if (enemyCoreDamage > 0) {
    score += enemyCoreDamage * 160;
    details.push(`对敌方核心造成 ${enemyCoreDamage} 点伤害`);
  }
  if (ownCoreHealing > 0) {
    score += ownCoreHealing * 28;
    details.push(`恢复己方核心 ${ownCoreHealing} 点`);
  }

  let enemyDamage = 0;
  let ownDamage = 0;
  let enemyKnockouts = 0;
  let ownRevives = 0;
  let protection = 0;
  let control = 0;
  let growth = 0;
  let enemyRealmDamage = 0;
  let enemyRealmsDestroyed = 0;

  beforeEnemy.units.forEach((unit) => {
    const next = unitByUid(afterEnemy, unit.uid);
    if (!next) return;
    enemyDamage += Math.max(0, unit.hp - next.hp);
    if (unit.hp > 0 && next.hp <= 0) enemyKnockouts += 1;
    control += Math.max(0, next.frozen - unit.frozen) * 70;
    control += Math.max(0, next.brittle - unit.brittle) * 32;
  });

  beforePlayer.units.forEach((unit) => {
    const next = unitByUid(afterPlayer, unit.uid);
    if (!next) return;
    ownDamage += Math.max(0, unit.hp - next.hp);
    if (unit.hp <= 0 && next.hp > 0) ownRevives += 1;
    protection += Math.max(0, next.hp - unit.hp) * 18;
    protection += Math.max(0, next.shield - unit.shield) * 12;
    growth += Math.max(0, next.attack - unit.attack) * 24;
    growth += Math.max(0, next.maxHp - unit.maxHp) * 10;
  });

  beforeEnemy.realms.forEach((realm) => {
    const next = realmByUid(afterEnemy, realm.uid);
    enemyRealmDamage += realm.hp - (next?.hp ?? 0);
    if (!next) enemyRealmsDestroyed += 1;
  });

  score += enemyDamage * 30;
  score -= ownDamage * 24;
  score += enemyKnockouts * 750;
  score += ownRevives * 620;
  score += protection + control + growth;
  score += Math.max(0, afterPlayer.realms.length - beforePlayer.realms.length) * 100;
  score += enemyRealmDamage * 34;
  score += enemyRealmsDestroyed * 260;
  score += Math.max(0, afterPlayer.hand.length - beforePlayer.hand.length) * 18;

  if (enemyKnockouts) details.push(`使 ${enemyKnockouts} 名敌方角色气绝`);
  else if (enemyDamage) details.push(`造成 ${enemyDamage} 点角色伤害`);
  if (ownDamage) details.push(`预计承受 ${ownDamage} 点反击伤害`);
  if (ownRevives) details.push(`唤回 ${ownRevives} 名己方角色`);
  if (control) details.push('施加有效控制');
  if (protection) details.push('提升己方生存能力');
  if (growth) details.push('强化己方角色');
  if (enemyRealmsDestroyed) details.push(`摧毁 ${enemyRealmsDestroyed} 处敌方幻境`);
  else if (enemyRealmDamage) details.push(`对敌方幻境造成 ${enemyRealmDamage} 点伤害`);

  return {
    score,
    reason: details.length ? `${details.join('，')}。` : '该行动当前没有可衡量收益。',
  };
}

function createCardCandidates(state, playerIndex) {
  const evaluationBase = state.responseWindow ? settleResponseWindows(state) : state;
  const player = state.players[playerIndex];
  return player.hand.flatMap((instance) => {
    if (!canPlayCard(state, playerIndex, instance.instanceId)) return [];
    const definition = getCardDefinition(instance.definitionId);
    const targets = definition.target === 'auto'
      ? (definition.effect === 'assault'
        ? [null, ...getValidCombatTargets(state, playerIndex).filter((targetId) => targetId.startsWith('realm-'))]
        : [null])
      : getValidTargets(state, playerIndex, definition.id);

    return targets.flatMap((targetId) => {
      const result = playCard(state, playerIndex, instance.instanceId, targetId);
      if (result.error) return [];
      let projected = result.state;
      if (projected.pendingChoice?.playerIndex === playerIndex) {
        const choice = chooseDivinationInstance(projected, playerIndex);
        projected = resolveDivinationChoice(projected, playerIndex, choice).state;
      }
      projected = settleResponseWindows(projected);
      const evaluation = scoreTransition(evaluationBase, projected, playerIndex);
      return [{
        type: 'play-card',
        instanceId: instance.instanceId,
        definitionId: definition.id,
        targetId,
        ...evaluation,
      }];
    });
  });
}

function settleResponseWindows(state) {
  let projected = state;
  for (let step = 0; projected.responseWindow && step < 128; step += 1) {
    const result = passResponse(projected, projected.responseWindow.playerIndex);
    if (result.error) break;
    projected = result.state;
  }
  return projected;
}

function chooseDivinationInstance(state, playerIndex) {
  const choice = state.pendingChoice;
  if (!choice || choice.playerIndex !== playerIndex) return null;
  return [...choice.instanceIds]
    .map((instanceId) => {
      const instance = state.players[playerIndex].deck.find((candidate) => candidate.instanceId === instanceId);
      const card = instance && getCardDefinition(instance.definitionId);
      return { instanceId, score: card ? (4 - card.level) * 10 - card.cost : -1 };
    })
    .sort((left, right) => (right.score - left.score) || left.instanceId.localeCompare(right.instanceId))[0]?.instanceId ?? null;
}

function createLevelCandidates(state, playerIndex) {
  const player = state.players[playerIndex];
  return player.units.flatMap((unit) => {
    const result = levelUpUnit(state, playerIndex, unit.uid);
    if (result.error) return [];

    const unlockedCards = player.hand.filter((instance) => {
      const before = getCardPlayability(state, playerIndex, instance.instanceId);
      const after = getCardPlayability(result.state, playerIndex, instance.instanceId);
      return before.code === 'level' && after.playable;
    }).length;
    return [{
      type: 'level-up',
      unitId: unit.uid,
      score: 42 + unlockedCards * 35,
      reason: unlockedCards
        ? `提升勾玉并立即解锁 ${unlockedCards} 张手牌。`
        : '提升勾玉，为后续高阶卡牌做准备。',
    }];
  });
}

function createAttackCandidates(state, playerIndex) {
  const targets = [
    null,
    ...getValidCombatTargets(state, playerIndex).filter((targetId) => targetId.startsWith('realm-')),
  ];
  return state.players[playerIndex].units.flatMap((unit) => {
    return targets.flatMap((targetId) => {
      const result = basicAttack(state, playerIndex, unit.uid, targetId);
      if (result.error) return [];
      return [{
        type: 'attack',
        unitId: unit.uid,
        targetId,
        ...scoreTransition(state, result.state, playerIndex),
      }];
    });
  });
}

function commandTieBreak(command) {
  if (command.type === 'play-card') return 3;
  if (command.type === 'attack') return 2;
  if (command.type === 'level-up') return 1;
  return 0;
}

/**
 * Chooses one legal action without modifying the supplied game state.
 * The caller applies the command through game-core, then asks again.
 */
export function chooseAiCommand(state, playerIndex = 1) {
  const player = state?.players?.[playerIndex];
  if (!player || state.winner !== null) {
    return { type: 'end-turn', score: 0, reason: '当前没有可执行的 AI 行动。' };
  }
  if (state.pendingChoice?.playerIndex === playerIndex) {
    return {
      type: 'divination-choice',
      instanceId: chooseDivinationInstance(state, playerIndex),
      score: 0,
      reason: '选择下一张更容易使用的卡牌。',
    };
  }

  if (state.responseWindow) {
    if (state.responseWindow.playerIndex !== playerIndex) {
      return { type: 'pass-response', score: 0, reason: '当前响应优先权属于对手。' };
    }
    const candidates = createCardCandidates(state, playerIndex).filter((command) => command.score > 0);
    candidates.sort((first, second) => (second.score - first.score)
      || (commandTieBreak(second) - commandTieBreak(first)));
    return candidates[0] ?? {
      type: 'pass-response',
      score: 0,
      reason: '没有更有利的响应，放弃当前优先权。',
    };
  }
  if (state.currentPlayer !== playerIndex) {
    return { type: 'end-turn', score: 0, reason: '当前没有可执行的 AI 行动。' };
  }

  const candidates = [
    ...createCardCandidates(state, playerIndex),
    ...createAttackCandidates(state, playerIndex),
    ...createLevelCandidates(state, playerIndex),
  ].filter((command) => command.score > 0);

  candidates.sort((first, second) => (second.score - first.score)
    || (commandTieBreak(second) - commandTieBreak(first)));

  return candidates[0] ?? {
    type: 'end-turn',
    score: 0,
    reason: '没有剩余的有效行动，结束回合。',
  };
}
