import { GAME_EVENTS } from './game-core.js?v=b7fb8b28';

export function captureBattleSnapshot(state) {
  return {
    nextEventId: state?.nextEventId ?? 0,
    players: (state?.players ?? []).map((player) => ({
      avatarHp: player.avatarHp,
      units: Object.fromEntries(player.units.map((unit) => [unit.uid, {
        hp: unit.hp,
        shield: unit.shield,
        level: unit.level,
        knockout: unit.knockout,
      }])),
      realms: Object.fromEntries(player.realms.map((realm) => [realm.uid, {
        name: realm.name,
        hp: realm.hp,
        maxHp: realm.maxHp,
      }])),
    })),
  };
}

function eventsSince(previousSnapshot, state) {
  return (state.events ?? [])
    .filter((event) => event.id >= previousSnapshot.nextEventId)
    .sort((first, second) => first.id - second.id);
}

function unitByUid(state, unitId) {
  for (let playerIndex = 0; playerIndex < state.players.length; playerIndex += 1) {
    const unit = state.players[playerIndex].units.find((candidate) => candidate.uid === unitId);
    if (unit) return { playerIndex, unit };
  }
  return null;
}

function knockoutCue(impact) {
  return {
    type: 'knockout',
    kicker: '气绝 / BREAK',
    title: `${impact.name} 气绝`,
    detail: `生命归零，将在 ${impact.knockout} 个己方回合后归队。`,
    playerIndex: impact.playerIndex,
    unitId: impact.unitId,
  };
}

function levelCue(impact) {
  return {
    type: 'level-up',
    kicker: '勾玉提升 / LEVEL UP',
    title: `${impact.name} · ${impact.level} 勾`,
    detail: '高阶卡牌的使用权限已更新。',
    playerIndex: impact.playerIndex,
    unitId: impact.unitId,
  };
}

function combatCue(state, event) {
  const attacker = unitByUid(state, event.payload.attackerUnitId)?.unit;
  const defender = unitByUid(state, event.payload.defenderUnitId)?.unit;
  const remote = event.payload.remote === true;
  const keywordBonuses = event.payload.keywordBonuses ?? { attack: 0, shield: 0 };
  const empowered = keywordBonuses.attack > 0 || keywordBonuses.shield > 0;
  const bonusDetail = empowered
    ? ` 关键词强化：攻击 +${keywordBonuses.attack}，护盾 +${keywordBonuses.shield}。`
    : '';
  return {
    type: remote ? 'remote-combat' : 'combat',
    kicker: remote ? '远程出击 / REMOTE' : '前线交战 / CLASH',
    title: `${attacker?.name ?? '攻击者'} 对阵 ${defender?.name ?? '界碑核心'}`,
    detail: remote
      ? `${defender ? '攻击者保持当前位置，目标无法反击。' : '攻击者保持当前位置，远程攻击直达核心。'}${bonusDetail}`
      : `${defender ? '双方攻命同时进入战斗结算。' : '对方战斗区空缺，此次攻击直达核心。'}${bonusDetail}`,
    playerIndex: event.payload.attackerPlayerIndex,
    unitId: event.payload.attackerUnitId,
    targetUnitId: event.payload.defenderUnitId ?? null,
  };
}

function keywordGainCue(event) {
  const value = event.payload.value ?? {};
  return {
    type: 'keyword-gained',
    kicker: `${event.payload.label ?? '战斗状态'} / READY`,
    title: `${event.payload.label ?? '战斗状态'}已蓄势`,
    detail: `下一次出击：攻击 +${value.attack ?? 0}，护盾 +${value.shield ?? 0}。`,
    playerIndex: event.payload.playerIndex,
  };
}

function coreHitCue(impact) {
  return {
    type: 'core-hit',
    kicker: '核心受击 / CORE HIT',
    title: `${impact.name} 核心 ${impact.hpDelta}`,
    detail: `剩余 ${impact.hp} 点生命。`,
    playerIndex: impact.playerIndex,
  };
}

function unitHitCue(impact) {
  return {
    type: 'unit-hit',
    kicker: '单位受击 / IMPACT',
    title: `${impact.name} ${impact.hpDelta}`,
    detail: `剩余 ${impact.hp} 点生命。`,
    playerIndex: impact.playerIndex,
    unitId: impact.unitId,
  };
}

function realmDestroyedCue(event) {
  return {
    type: 'realm-destroyed',
    kicker: '幻境破碎 / REALM BREAK',
    title: `「${event.payload.name}」已摧毁`,
    detail: '该幻境已离开幻境席，持续效果终止。',
    playerIndex: event.payload.playerIndex,
    realmId: event.payload.realmId,
  };
}

function realmHitCue(impact) {
  return {
    type: 'realm-hit',
    kicker: '幻境受击 / REALM HIT',
    title: `${impact.name} ${impact.hpDelta}`,
    detail: `剩余 ${impact.hp}/${impact.maxHp} 点耐久。`,
    playerIndex: impact.playerIndex,
    realmId: impact.realmId,
  };
}

export function deriveBattleFeedback(previousSnapshot, state) {
  const unitImpacts = new Map();
  const coreImpacts = new Map();
  const realmImpacts = new Map();
  if (!previousSnapshot) return { unitImpacts, coreImpacts, realmImpacts, cardPlayed: null, cue: null };

  const newEvents = eventsSince(previousSnapshot, state);
  // 最新一次出牌：用于「出牌卡面展示」（己方左侧 / 敌方右侧）
  const cardPlayedEvent = newEvents.filter((event) => event.type === GAME_EVENTS.CARD_PLAYED).at(-1) ?? null;
  const cardPlayed = cardPlayedEvent
    ? {
        playerIndex: cardPlayedEvent.payload.playerIndex,
        definitionId: cardPlayedEvent.payload.definitionId ?? null,
      }
    : null;
  const combatEvents = newEvents.filter((event) => event.type === GAME_EVENTS.COMBAT_STARTED);
  const latestCombatByAttacker = new Map();
  combatEvents.forEach((event) => latestCombatByAttacker.set(event.payload.attackerUnitId, event));

  state.players.forEach((player, playerIndex) => {
    const previousPlayer = previousSnapshot.players?.[playerIndex];
    if (!previousPlayer) return;

    const coreHpDelta = player.avatarHp - previousPlayer.avatarHp;
    if (coreHpDelta !== 0) {
      coreImpacts.set(playerIndex, {
        playerIndex,
        playerId: player.id,
        name: player.name,
        hpDelta: coreHpDelta,
        hp: player.avatarHp,
      });
    }

    player.units.forEach((unit) => {
      const previousUnit = previousPlayer.units?.[unit.uid];
      if (!previousUnit) return;
      const hpDelta = unit.hp - previousUnit.hp;
      const shieldDelta = unit.shield - previousUnit.shield;
      const levelDelta = unit.level - previousUnit.level;
      const knockedOut = previousUnit.hp > 0 && unit.hp <= 0;
      const returned = previousUnit.hp <= 0 && unit.hp > 0;
      const attackerEvent = latestCombatByAttacker.get(unit.uid);
      const isAttacker = Boolean(attackerEvent);
      const isRemoteAttacker = attackerEvent?.payload.remote === true;
      const keywordBonuses = attackerEvent?.payload.keywordBonuses ?? { attack: 0, shield: 0 };
      const isKeywordEmpowered = keywordBonuses.attack > 0 || keywordBonuses.shield > 0;
      if (!hpDelta && !shieldDelta && !levelDelta && !knockedOut && !returned && !isAttacker) return;

      unitImpacts.set(unit.uid, {
        playerIndex,
        unitId: unit.uid,
        name: unit.name,
        hpDelta,
        shieldDelta,
        levelDelta,
        knockedOut,
        returned,
        isAttacker,
        isRemoteAttacker,
        isKeywordEmpowered,
        hp: unit.hp,
        shield: unit.shield,
        level: unit.level,
        knockout: unit.knockout,
      });
    });

    player.realms.forEach((realm) => {
      const previousRealm = previousPlayer.realms?.[realm.uid];
      if (!previousRealm) return;
      const hpDelta = realm.hp - previousRealm.hp;
      if (!hpDelta) return;
      realmImpacts.set(realm.uid, {
        playerIndex,
        realmId: realm.uid,
        name: realm.name,
        hpDelta,
        hp: realm.hp,
        maxHp: realm.maxHp,
        destroyed: false,
      });
    });
  });

  newEvents.filter((event) => event.type === GAME_EVENTS.REALM_DESTROYED).forEach((event) => {
    const previousRealm = previousSnapshot.players?.[event.payload.playerIndex]?.realms?.[event.payload.realmId];
    realmImpacts.set(event.payload.realmId, {
      playerIndex: event.payload.playerIndex,
      realmId: event.payload.realmId,
      name: event.payload.name ?? previousRealm?.name ?? '未知幻境',
      hpDelta: -(previousRealm?.hp ?? 0),
      hp: 0,
      maxHp: previousRealm?.maxHp ?? 0,
      destroyed: true,
    });
  });

  const impacts = [...unitImpacts.values()];
  const knockedOut = impacts.find((impact) => impact.knockedOut);
  if (knockedOut) return { unitImpacts, coreImpacts, realmImpacts, cardPlayed, cue: knockoutCue(knockedOut) };

  const destroyedRealmEvent = newEvents.filter((event) => event.type === GAME_EVENTS.REALM_DESTROYED).at(-1);
  if (destroyedRealmEvent) return { unitImpacts, coreImpacts, realmImpacts, cardPlayed, cue: realmDestroyedCue(destroyedRealmEvent) };

  const leveled = impacts.find((impact) => impact.levelDelta > 0);
  if (leveled) return { unitImpacts, coreImpacts, realmImpacts, cardPlayed, cue: levelCue(leveled) };

  const damagedRealm = [...realmImpacts.values()].find((impact) => impact.hpDelta < 0);
  if (damagedRealm) return { unitImpacts, coreImpacts, realmImpacts, cardPlayed, cue: realmHitCue(damagedRealm) };

  const latestCombat = combatEvents.at(-1);
  if (latestCombat) return { unitImpacts, coreImpacts, realmImpacts, cardPlayed, cue: combatCue(state, latestCombat) };

  const latestKeywordGain = newEvents.filter((event) => event.type === GAME_EVENTS.KEYWORD_STATE_GAINED).at(-1);
  if (latestKeywordGain) return { unitImpacts, coreImpacts, realmImpacts, cardPlayed, cue: keywordGainCue(latestKeywordGain) };

  const damagedCore = [...coreImpacts.values()].find((impact) => impact.hpDelta < 0);
  if (damagedCore) return { unitImpacts, coreImpacts, realmImpacts, cardPlayed, cue: coreHitCue(damagedCore) };

  const damagedUnit = impacts.find((impact) => impact.hpDelta < 0);
  return {
    unitImpacts,
    coreImpacts,
    realmImpacts,
    cue: damagedUnit ? unitHitCue(damagedUnit) : null,
  };
}
