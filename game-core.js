import {
  CARD_DEFINITIONS,
  DEFAULT_ENEMY_LINEUP,
  DEFAULT_PLAYER_LINEUP,
  GAME_RULES,
  UNIT_DEFINITIONS,
  createDefaultDeckDefinition,
  getCardDefinition,
  getStarterCardIdsForUnit,
  getUnitDefinition,
  validateDeckDefinition,
} from './game-content.js?v=789632f4';
import {
  CARD_KEYWORDS,
  applyCardPlayedKeywordHooks,
  applyCardResolutionKeywordHooks,
  applyCombatResolvedKeywordHooks,
  applyKeywordEffect,
  applyTurnStartKeywordHooks,
  consumePlayerCombatKeywordActivations,
  completeRealmKeywordTrigger,
  getKeywordCombatOptions,
  getKeywordCardPlayabilityBlock,
  getKeywordDamageRoute,
  getKeywordEffectConditionDecision,
  getKeywordModifiedCardCost,
  getAutomaticKeywordCardTrigger,
  preparePlayerCombatKeywords,
  prepareRealmKeywordTrigger,
  validateCardKeywordConfiguration,
  validatePlayerKeywordUsage,
  validateUnitKeywordConfiguration,
} from './game-keywords.js?v=789632f4';

export {
  CARD_DEFINITIONS,
  DEFAULT_ENEMY_LINEUP,
  DEFAULT_PLAYER_LINEUP,
  GAME_RULES,
  UNIT_DEFINITIONS,
  createDefaultDeckDefinition,
  getCardDefinition,
  getCardsForUnit,
  getStarterCardIdsForUnit,
  getUnitDefinition,
  validateDeckDefinition,
} from './game-content.js?v=789632f4';

export {
  CARD_KEYWORDS,
  KEYWORD_DEFINITIONS,
  getKeywordCostReductionLabel,
  getKeywordDefinition,
  getPlayerKeywordStatuses,
  getUnitKeywordStatuses,
  getKeywordStatusText,
  validateCardKeywordConfiguration,
} from './game-keywords.js?v=789632f4';

export const GAME_EVENTS = Object.freeze({
  MATCH_STARTED: 'match-started',
  TURN_STARTED: 'turn-started',
  CARD_DRAWN: 'card-drawn',
  HAND_BURNED: 'hand-burned',
  DECK_EXHAUSTED: 'deck-exhausted',
  UNIT_LEVELED: 'unit-leveled',
  CARD_PLAYED: 'card-played',
  UNIT_ENTERED_FRONT: 'unit-entered-front',
  COMBAT_STARTED: 'combat-started',
  COMBAT_RESOLVED: 'combat-resolved',
  UNIT_DAMAGED: 'unit-damaged',
  UNIT_HEALED: 'unit-healed',
  AVATAR_HEALED: 'avatar-healed',
  UNIT_KNOCKED_OUT: 'unit-knocked-out',
  UNIT_RETURNED: 'unit-returned',
  AVATAR_DAMAGED: 'avatar-damaged',
  FORM_CHANGED: 'form-changed',
  REALM_DEPLOYED: 'realm-deployed',
  REALM_TRIGGERED: 'realm-triggered',
  REALM_DAMAGED: 'realm-damaged',
  REALM_DESTROYED: 'realm-destroyed',
  COUNTDOWN_TICKED: 'countdown-ticked',
  COUNTDOWN_TRIGGERED: 'countdown-triggered',
  PIERCING_TRIGGERED: 'piercing-triggered',
  KEYWORD_STATE_GAINED: 'keyword-state-gained',
  KEYWORD_STATE_CONSUMED: 'keyword-state-consumed',
  KEYWORD_RESOURCE_GAINED: 'keyword-resource-gained',
  KEYWORD_RESOURCE_SPENT: 'keyword-resource-spent',
  FORTUNE_ROLLED: 'fortune-rolled',
  DIVINATION_STARTED: 'divination-started',
  DIVINATION_RESOLVED: 'divination-resolved',
  INCARNATION_TRIGGERED: 'incarnation-triggered',
  PASSIVE_TRIGGERED: 'passive-triggered',
  RESPONSE_WINDOW_OPENED: 'response-window-opened',
  RESPONSE_PASSED: 'response-passed',
  RESOLUTION_STEP_RESOLVED: 'resolution-step-resolved',
  MATCH_FINISHED: 'match-finished',
});

export const GAME_STATE_VERSION = 12;

const MAX_EVENT_CHAIN_LENGTH = 64;
const MAX_RESOLUTION_STACK_LENGTH = 64;
const REQUIRED_STATE_FIELDS = Object.freeze([
  'rng',
  'nextCardId',
  'nextEventId',
  'nextResolutionId',
  'nextRealmId',
  'turnCounter',
  'currentPlayer',
  'phase',
  'winner',
  'log',
  'events',
  'resolutionStack',
  'responseWindow',
  'pendingChoice',
  'players',
]);

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function assertGameStateStructure(state) {
  if (!state || typeof state !== 'object' || Array.isArray(state)) {
    throw new Error('对局存档缺少有效的 state 对象。');
  }

  REQUIRED_STATE_FIELDS.forEach((field) => {
    if (!Object.hasOwn(state, field)) throw new Error(`对局存档缺少必要字段：${field}。`);
  });

  if (!Array.isArray(state.players) || state.players.length !== 2) {
    throw new Error('对局存档必须包含 2 名玩家。');
  }
  if (state.players.some((player) => !player || typeof player !== 'object' || Array.isArray(player))) {
    throw new Error('对局存档的玩家结构无效。');
  }
  if (state.players.some((player) => validatePlayerKeywordUsage(player).length > 0)) {
    throw new Error('对局存档的关键词使用状态无效。');
  }
  if (state.players.some((player) => !Array.isArray(player.realms))) {
    throw new Error('对局存档的幻境状态无效。');
  }
  if (state.players.some((player) => player.realms.some((realm) => !Array.isArray(realm.keywords)))) {
    throw new Error('对局存档的幻境关键词状态无效。');
  }
  state.players.forEach((player, index) => {
    const label = `玩家 ${index + 1}`;
    if (!Number.isInteger(player.mulligansUsed) || player.mulligansUsed < 0 || player.mulligansUsed > GAME_RULES.mulliganCount) {
      throw new Error(`${label}的开局调度计数无效。`);
    }
    if (!Number.isInteger(player.bonusUpgrades) || player.bonusUpgrades < 0) {
      throw new Error(`${label}的额外升勾计数无效。`);
    }
    player.units.forEach((unit) => {
      if (typeof unit.unyielding !== 'boolean') throw new Error(`${label}的角色不屈状态无效。`);
      if (!Number.isInteger(unit.level) || unit.level < 0 || unit.level > GAME_RULES.maxUnitLevel) {
        throw new Error(`${label}的 ${unit.name ?? '角色'} 勾玉等级无效。`);
      }
      if (unit.hp > unit.maxHp) throw new Error(`${label}的 ${unit.name ?? '角色'} 生命超过上限。`);
    });
  });
  const realmIds = new Set();
  state.players.forEach((player) => {
    player.realms.forEach((realm) => {
      const definition = realm && getCardDefinition(realm.cardId);
      const realmDefinition = definition?.type === 'realm' ? definition.realm : null;
      const hasValidIdentity = typeof realm?.uid === 'string' && /^realm-\d+$/.test(realm.uid);
      const hasValidHealth = Number.isInteger(realm?.hp)
        && Number.isInteger(realm?.maxHp)
        && realm.hp > 0
        && realm.hp <= realm.maxHp
        && realm.maxHp === realmDefinition?.hp;
      const matchesDefinition = realmDefinition
        && realm.unitId === definition.unitId
        && JSON.stringify(realm.keywords) === JSON.stringify(definition.keywords)
        && realm.trigger === realmDefinition.trigger
        && realm.triggerEffect === realmDefinition.triggerEffect
        && realm.triggerValue === realmDefinition.triggerValue;
      if (!hasValidIdentity || realmIds.has(realm.uid) || !hasValidHealth || !matchesDefinition) {
        throw new Error('对局存档的幻境实例无效。');
      }
      realmIds.add(realm.uid);
    });
  });
  const highestRealmId = [...realmIds].reduce((highest, uid) => Math.max(highest, Number(uid.slice(6))), 0);
  if (!Number.isInteger(state.nextRealmId) || state.nextRealmId <= highestRealmId) {
    throw new Error('对局存档的幻境序列无效。');
  }
  if (!Array.isArray(state.log) || !Array.isArray(state.events)) {
    throw new Error('对局存档的战报或事件结构无效。');
  }
  if (!Array.isArray(state.resolutionStack)) {
    throw new Error('对局存档的结算栈结构无效。');
  }
  if (state.resolutionStack.length > MAX_RESOLUTION_STACK_LENGTH) {
    throw new Error('对局存档的结算栈超过安全上限。');
  }
  const validFrames = state.resolutionStack.every((frame) => {
    const card = frame && getCardDefinition(frame.definitionId);
    const commonValid = frame
      && typeof frame === 'object'
      && !Array.isArray(frame)
      && Number.isInteger(frame.resolutionId)
      && frame.resolutionId > 0
      && (frame.playerIndex === 0 || frame.playerIndex === 1)
      && typeof frame.instanceId === 'string'
      && card
      && (frame.targetId === null || typeof frame.targetId === 'string')
      && typeof frame.respondable === 'boolean';
    if (!commonValid) return false;
    if (frame.kind === 'card-complete') return frame.respondable === false;
    return frame.kind === 'card-effect'
      && Number.isInteger(frame.effectIndex)
      && frame.effectIndex >= 0
      && frame.effectIndex < getCardEffects(card).length
      && typeof frame.responseOffered === 'boolean'
      && Number.isInteger(frame.responseDepth)
      && frame.responseDepth >= 0
      && frame.responseDepth <= GAME_RULES.maxResponseDepth;
  });
  if (!validFrames) throw new Error('对局存档的结算帧无效。');
  if (state.responseWindow !== null) {
    const window = state.responseWindow;
    const frame = state.resolutionStack.at(-1);
    const card = frame && getCardDefinition(frame.definitionId);
    const effect = card && frame.kind === 'card-effect' ? getCardEffects(card)[frame.effectIndex] : null;
    const expectedKeys = [
      'action', 'consecutivePasses', 'definitionId', 'depth', 'id', 'playerIndex',
      'resolutionId', 'sourcePlayerIndex', 'target', 'targetId',
    ];
    const validWindow = window
      && typeof window === 'object'
      && !Array.isArray(window)
      && JSON.stringify(Object.keys(window).sort()) === JSON.stringify(expectedKeys)
      && frame?.respondable === true
      && frame.responseOffered === true
      && window.id === `response-${frame.resolutionId}-${frame.responseDepth}`
      && window.resolutionId === frame.resolutionId
      && window.definitionId === frame.definitionId
      && window.sourcePlayerIndex === frame.playerIndex
      && window.depth === frame.responseDepth
      && window.action === effect?.action
      && window.target === effect?.target
      && window.targetId === frame.targetId
      && (window.consecutivePasses === 0 || window.consecutivePasses === 1)
      && window.playerIndex === (window.consecutivePasses === 0 ? 1 - frame.playerIndex : frame.playerIndex);
    if (!validWindow) throw new Error('对局存档的响应窗口结构无效。');
  }
  if (state.pendingChoice !== null) {
    const choice = state.pendingChoice;
    const validChoice = choice
      && typeof choice === 'object'
      && !Array.isArray(choice)
      && choice.type === 'divination'
      && (choice.playerIndex === 0 || choice.playerIndex === 1)
      && Number.isInteger(choice.resolutionId)
      && Array.isArray(choice.instanceIds)
      && choice.instanceIds.length > 0
      && choice.instanceIds.every((instanceId) => typeof instanceId === 'string')
      && new Set(choice.instanceIds).size === choice.instanceIds.length;
    const owner = validChoice ? state.players[choice.playerIndex] : null;
    const idsRemainInDeck = validChoice && choice.instanceIds.every((instanceId) => (
      owner.deck.some((instance) => instance.instanceId === instanceId)
    ));
    const resolutionRemains = validChoice && state.resolutionStack.some((frame) => (
      frame.resolutionId === choice.resolutionId
    ));
    if (!validChoice || !idsRemainInDeck || !resolutionRemains) {
      throw new Error('对局存档的待选择状态无效。');
    }
  }
  if (state.currentPlayer !== 0 && state.currentPlayer !== 1) {
    throw new Error('对局存档的当前玩家无效。');
  }
  if (state.winner !== null && state.winner !== 0 && state.winner !== 1) {
    throw new Error('对局存档的胜者字段无效。');
  }
  if (typeof state.phase !== 'string') {
    throw new Error('对局存档的阶段字段无效。');
  }
}

export function serializeGame(state) {
  assertGameStateStructure(state);
  const snapshot = clone(state);
  delete snapshot.eventQueue;
  delete snapshot.isFlushingEvents;
  delete snapshot.isResolving;
  return JSON.stringify({ version: GAME_STATE_VERSION, state: snapshot });
}

export function deserializeGame(json) {
  if (typeof json !== 'string') throw new Error('对局存档必须是 JSON 字符串。');

  let envelope;
  try {
    envelope = JSON.parse(json);
  } catch {
    throw new Error('对局存档不是有效的 JSON。');
  }

  if (!envelope || typeof envelope !== 'object' || Array.isArray(envelope)) {
    throw new Error('对局存档缺少有效的版本信封。');
  }
  if (envelope.version !== GAME_STATE_VERSION) {
    throw new Error(`不支持的对局存档版本：${String(envelope.version)}。`);
  }

  assertGameStateStructure(envelope.state);
  const state = clone(envelope.state);
  state.eventQueue = [];
  state.isFlushingEvents = false;
  state.isResolving = false;
  return state;
}

function nextRandom(state) {
  state.rng = (Math.imul(state.rng, 1664525) + 1013904223) >>> 0;
  return state.rng / 4294967296;
}

function shuffle(state, items) {
  for (let index = items.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(nextRandom(state) * (index + 1));
    [items[index], items[swapIndex]] = [items[swapIndex], items[index]];
  }
}

function recordEvent(state, type, payload = {}, text = '', tone = 'neutral') {
  const event = {
    id: state.nextEventId,
    turn: state.turnCounter,
    type,
    payload,
  };
  state.nextEventId += 1;
  state.events.unshift(event);
  state.events = state.events.slice(0, 120);

  if (!text) return event;
  state.log.unshift({ id: event.id, turn: state.turnCounter, text, tone, type });
  state.log = state.log.slice(0, 50);
  return event;
}

function emitGameEvent(state, type, payload = {}, text = '', tone = 'neutral') {
  const event = recordEvent(state, type, payload, text, tone);
  state.eventQueue ??= [];
  state.eventQueue.push(event);
  flushEventQueue(state);
  return event;
}

function flushEventQueue(state) {
  if (state.isFlushingEvents) return;
  state.isFlushingEvents = true;
  let processed = 0;
  try {
    while (state.eventQueue.length && state.winner === null) {
      if (processed >= MAX_EVENT_CHAIN_LENGTH) {
        state.eventQueue.length = 0;
        recordEvent(state, GAME_EVENTS.PASSIVE_TRIGGERED, { blocked: 'event-chain-limit' }, '事件链超过安全上限，后续触发已停止。', 'danger');
        break;
      }
      processed += 1;
      dispatchPassiveHooks(state, state.eventQueue.shift());
    }
  } finally {
    if (state.winner !== null) state.eventQueue.length = 0;
    state.isFlushingEvents = false;
  }
}

function createUnits(unitIds, ownerId) {
  return unitIds.map((unitId) => {
    const definition = getUnitDefinition(unitId);
    if (!definition) throw new Error(`未知角色：${unitId}`);
    return {
      ...definition,
      uid: `${ownerId}:${definition.id}`,
      baseAttack: definition.attack,
      baseMaxHp: definition.maxHp,
      hp: definition.maxHp,
      shield: 0,
      knockout: 0,
      frozen: 0,
      brittle: 0,
      unyielding: false,
      // 本家规则：角色初始 0 勾（未激活），首次升勾 0→1 后才可被选中/出击/使用其卡牌
      level: 0,
      form: null,
      passiveUsage: {},
    };
  });
}

function createDeck(state, owner, deckDefinition) {
  const deck = deckDefinition.cardIds.map((definitionId) => ({
    instanceId: `${owner}-${state.nextCardId++}`,
    definitionId,
  }));
  shuffle(state, deck);
  return deck;
}

function createPlayer(state, id, name, deckDefinition) {
  const units = createUnits(deckDefinition.unitIds, id);
  const player = {
    id,
    name,
    avatarHp: GAME_RULES.startingAvatarHp,
    maxAvatarHp: GAME_RULES.startingAvatarHp,
    energy: 0,
    maxEnergy: GAME_RULES.maxEnergy,
    deck: [],
    hand: [],
    units,
    // 本家规则：战斗区初始为空，所有角色都在准备区，出击后才进入战斗区
    frontUnitId: null,
    attackUsed: false,
    levelUpUsed: false,
    mulligansUsed: 0,
    bonusUpgrades: 0,
    keywordUsage: {},
    turnsTaken: 0,
    cardsPlayed: 0,
    cardsPlayedThisTurn: 0,
    damageDealt: 0,
    realms: [],
  };
  player.deck = createDeck(state, id, deckDefinition);
  return player;
}

function normalizeGameOptions(input) {
  const options = typeof input === 'number' ? { seed: input } : (input ?? {});
  const playerDeckDefinition = options.playerDeckDefinition
    ?? createDefaultDeckDefinition(options.playerUnitIds ?? DEFAULT_PLAYER_LINEUP);
  const enemyDeckDefinition = options.enemyDeckDefinition
    ?? createDefaultDeckDefinition(options.enemyUnitIds ?? DEFAULT_ENEMY_LINEUP);

  const playerValidation = validateDeckDefinition(playerDeckDefinition);
  const enemyValidation = validateDeckDefinition(enemyDeckDefinition);
  if (!playerValidation.valid) throw new Error(playerValidation.errors.join(' '));
  if (!enemyValidation.valid) throw new Error(enemyValidation.errors.join(' '));

  return {
    seed: (options.seed ?? Date.now()) >>> 0,
    playerDeckDefinition,
    enemyDeckDefinition,
  };
}

function unitIndexByUid(player, unitUid) {
  return player.units.findIndex((unit) => unit.uid === unitUid);
}

// 读取当前战斗区角色下标；战斗区为空或角色已气绝时返回 -1，不再自动补位
function frontIndexOf(player) {
  const currentIndex = unitIndexByUid(player, player.frontUnitId);
  return player.units[currentIndex]?.hp > 0 ? currentIndex : -1;
}

// 战斗区角色离开战斗区（气绝或回合开始回退）时归位准备区
function leaveBattleZone(player, unitIndex, source) {
  const unit = player.units[unitIndex];
  if (!unit || player.frontUnitId !== unit.uid) return false;
  player.frontUnitId = null;
  return { unitIndex, unitId: unit.uid, source };
}

function checkWinner(state) {
  if (state.winner !== null) return;
  const defeated = state.players.findIndex((player) => player.avatarHp <= 0);
  if (defeated < 0) return;

  state.winner = 1 - defeated;
  state.phase = 'finished';
  state.resolutionStack.length = 0;
  state.responseWindow = null;
  state.pendingChoice = null;
  recordEvent(
    state,
    GAME_EVENTS.MATCH_FINISHED,
    { winner: state.winner, defeated },
    `${state.players[state.winner].name} 稳定了界碑核心。`,
    'success',
  );
}

export function drawCards(state, playerIndex, count = 1) {
  const player = state.players[playerIndex];
  for (let drawIndex = 0; drawIndex < count; drawIndex += 1) {
    const drawn = player.deck.pop();
    if (drawn) {
      player.hand.push(drawn);
      recordEvent(state, GAME_EVENTS.CARD_DRAWN, { playerIndex, instanceId: drawn.instanceId });
      continue;
    }

    player.avatarHp = 0;
    recordEvent(
      state,
      GAME_EVENTS.DECK_EXHAUSTED,
      { playerIndex },
      `${player.name} 的牌库枯竭，对局判负。`,
      'danger',
    );
    checkWinner(state);
    break;
  }

  // 本家规则：手牌上限 12 张，超出部分被焚毁
  if (player.hand.length > GAME_RULES.maxHandSize) {
    const burned = player.hand.splice(GAME_RULES.maxHandSize);
    burned.forEach((instance) => {
      recordEvent(
        state,
        GAME_EVENTS.HAND_BURNED,
        { playerIndex, instanceId: instance.instanceId, definitionId: instance.definitionId },
        `${player.name} 的手牌超出上限，${getCardDefinition(instance.definitionId).name} 被焚毁。`,
        'danger',
      );
    });
  }
}

function damageAvatar(state, playerIndex, amount, sourcePlayerIndex = null) {
  const player = state.players[playerIndex];
  const damage = Math.max(0, amount);
  player.avatarHp = Math.max(0, player.avatarHp - damage);
  if (sourcePlayerIndex !== null) state.players[sourcePlayerIndex].damageDealt += damage;
  recordEvent(
    state,
    GAME_EVENTS.AVATAR_DAMAGED,
    { playerIndex, sourcePlayerIndex, damage },
    `${player.name} 的核心受到 ${damage} 点伤害。`,
    'danger',
  );
  checkWinner(state);
}

function damageUnit(state, playerIndex, unitIndex, baseAmount, sourcePlayerIndex = null) {
  const player = state.players[playerIndex];
  const unit = player.units[unitIndex];
  if (!unit || unit.hp <= 0) return { damage: 0, knockedOut: false };

  let amount = baseAmount;
  if (unit.brittle > 0) {
    amount += 1;
    unit.brittle -= 1;
  }

  const absorbed = Math.min(unit.shield, amount);
  unit.shield -= absorbed;
  const unshieldedDamage = amount - absorbed;
  // 不屈：生命大于 1 时，至多受到使其生命降为 1 的伤害
  const unyieldingSave = unit.unyielding && unit.hp > 1 && unshieldedDamage >= unit.hp;
  const effectiveDamage = unyieldingSave ? unit.hp - 1 : unshieldedDamage;
  const damage = Math.min(unit.hp, effectiveDamage);
  const overkill = Math.max(0, unshieldedDamage - unit.hp);
  unit.hp = Math.max(0, unit.hp - damage);
  if (sourcePlayerIndex !== null) state.players[sourcePlayerIndex].damageDealt += damage;
  recordEvent(
    state,
    GAME_EVENTS.UNIT_DAMAGED,
    { playerIndex, unitIndex, unitId: unit.uid, sourcePlayerIndex, damage, absorbed, overkill },
    `${unit.name} 受到 ${damage} 点伤害${absorbed ? `，护盾抵消 ${absorbed} 点` : ''}${unyieldingSave ? '，不屈抵住致命伤' : ''}。`,
    damage > 0 ? 'danger' : 'neutral',
  );

  const knockedOut = unit.hp === 0;
  if (knockedOut) {
    unit.shield = 0;
    unit.knockout = GAME_RULES.knockoutCountdown;
    unit.frozen = 0;
    unit.brittle = 0;
    unit.chargeUp = null;
    recordEvent(
      state,
      GAME_EVENTS.UNIT_KNOCKED_OUT,
      { playerIndex, unitIndex },
      `${unit.name} 气绝，将在 ${GAME_RULES.knockoutCountdown} 个己方回合后归队。`,
      'danger',
    );
    // 本家规则：气绝角色自动离开战斗区回到准备区，战斗区变空，不自动补位
    leaveBattleZone(player, unitIndex, 'knockout');
  }
  return { damage, knockedOut, overkill };
}

function damageRealm(state, playerIndex, realmId, baseAmount, sourcePlayerIndex = null) {
  const player = state.players[playerIndex];
  const realmIndex = player.realms.findIndex((realm) => realm.uid === realmId);
  const realm = player.realms[realmIndex];
  if (!realm || realm.hp <= 0) return { damage: 0, destroyed: false };

  const damage = Math.min(realm.hp, Math.max(0, baseAmount));
  realm.hp -= damage;
  if (sourcePlayerIndex !== null) state.players[sourcePlayerIndex].damageDealt += damage;
  recordEvent(
    state,
    GAME_EVENTS.REALM_DAMAGED,
    { playerIndex, sourcePlayerIndex, realmId: realm.uid, cardId: realm.cardId, damage, hp: realm.hp },
    `幻境「${realm.name}」受到 ${damage} 点伤害。`,
    'danger',
  );
  if (realm.hp > 0) return { damage, destroyed: false };

  player.realms.splice(realmIndex, 1);
  emitGameEvent(
    state,
    GAME_EVENTS.REALM_DESTROYED,
    { playerIndex, sourcePlayerIndex, realmId: realm.uid, cardId: realm.cardId, name: realm.name },
    `幻境「${realm.name}」已被摧毁。`,
    'danger',
  );
  return { damage, destroyed: true };
}

function healUnit(state, playerIndex, unitIndex, amount) {
  const unit = state.players[playerIndex].units[unitIndex];
  if (!unit || unit.hp <= 0) return;
  const healed = Math.min(amount, unit.maxHp - unit.hp);
  unit.hp += healed;
  recordEvent(
    state,
    GAME_EVENTS.UNIT_HEALED,
    { playerIndex, unitIndex, unitId: unit.uid, healed },
    `${unit.name} 恢复 ${healed} 点生命。`,
    'success',
  );
}

function healAvatar(state, playerIndex, amount) {
  const player = state.players[playerIndex];
  const healed = Math.min(Math.max(0, amount), player.maxAvatarHp - player.avatarHp);
  player.avatarHp += healed;
  emitGameEvent(
    state,
    GAME_EVENTS.AVATAR_HEALED,
    { playerIndex, healed },
    `${player.name} 的核心恢复 ${healed} 点生命。`,
    'success',
  );
}

function reviveUnit(state, playerIndex, unitIndex, amount) {
  // 本家规则：复活一律回复全部生命（amount 参数保留以兼容效果签名）
  void amount;
  const player = state.players[playerIndex];
  const unit = player.units[unitIndex];
  if (!unit || unit.hp > 0) return;
  unit.hp = unit.maxHp;
  unit.knockout = 0;
  unit.shield = 0;
  // 复活角色回到准备区，需要重新出击才能进入战斗区
  recordEvent(
    state,
    GAME_EVENTS.UNIT_RETURNED,
    { playerIndex, unitIndex, hp: unit.hp, source: 'card' },
    `${unit.name} 被余辉唤回，恢复 ${unit.hp} 点生命。`,
    'success',
  );
}

function resolveCombat(state, attackerPlayerIndex, attackerUnitIndex, options = 0) {
  const combatOptions = typeof options === 'object' && options !== null ? options : {};
  const bonus = typeof options === 'number' ? options : (combatOptions.bonus ?? 0);
  const pierce = combatOptions.pierce === true;
  const remote = combatOptions.remote === true;
  const combo = combatOptions.combo === true;
  const firstStrike = combatOptions.firstStrike === true;
  const crit = combatOptions.crit === true;
  const targetId = combatOptions.targetId ?? null;
  const attackerPlayer = state.players[attackerPlayerIndex];
  const defenderPlayerIndex = 1 - attackerPlayerIndex;
  const defenderPlayer = state.players[defenderPlayerIndex];
  const attacker = attackerPlayer.units[attackerUnitIndex];
  if (!attacker || attacker.hp <= 0) return;
  if (targetId?.startsWith('realm-') && !defenderPlayer.realms.some((realm) => realm.uid === targetId)) return;
  const preparedKeywords = preparePlayerCombatKeywords({
    state,
    playerIndex: attackerPlayerIndex,
    player: attackerPlayer,
    attacker,
  });
  const keywordBonuses = {
    attack: preparedKeywords.options.attackBonus + (combatOptions.attackBonus ?? 0),
    shield: preparedKeywords.options.shieldBonus,
  };
  if (keywordBonuses.shield > 0) attacker.shield += keywordBonuses.shield;
  const consumedKeywordStates = consumePlayerCombatKeywordActivations({
    state,
    playerIndex: attackerPlayerIndex,
    player: attackerPlayer,
    attacker,
  }, preparedKeywords.activations);
  consumedKeywordStates.forEach((consumed) => {
    recordEvent(
      state,
      GAME_EVENTS.KEYWORD_STATE_CONSUMED,
      {
        playerIndex: attackerPlayerIndex,
        unitId: attacker.uid,
        keywordId: consumed.keywordId,
        label: consumed.label,
        value: consumed.value,
      },
      consumed.text,
      'success',
    );
  });

  const previousFrontUnitId = attackerPlayer.frontUnitId;
  const enteredFromReserve = !remote && previousFrontUnitId !== attacker.uid;
  if (!remote) attackerPlayer.frontUnitId = attacker.uid;
  if (enteredFromReserve) {
    emitGameEvent(
      state,
      GAME_EVENTS.UNIT_ENTERED_FRONT,
      { playerIndex: attackerPlayerIndex, unitId: attacker.uid, previousFrontUnitId },
      `${attacker.name} 从准备区进入前线。`,
      'turn',
    );
  }

  const defenderIndex = frontIndexOf(defenderPlayer);
  const defender = defenderPlayer.units[defenderIndex];
  const basePower = attacker.attack + bonus + keywordBonuses.attack;
  // 暴击：本次出击伤害翻倍
  const attackPower = crit ? basePower * 2 : basePower;

  const targetRealm = targetId
    ? defenderPlayer.realms.find((realm) => realm.uid === targetId)
    : null;
  if (targetRealm) {
    recordEvent(
      state,
      GAME_EVENTS.COMBAT_STARTED,
      { attackerPlayerIndex, attackerUnitId: attacker.uid, defenderPlayerIndex, defenderUnitId: null, targetRealmId: targetRealm.uid, remote, keywordBonuses },
      `${attacker.name} 向幻境「${targetRealm.name}」发起出击。`,
    );
    const result = damageRealm(state, defenderPlayerIndex, targetRealm.uid, attackPower, attackerPlayerIndex);
    applyCombatResolvedKeywordHooks({
      state,
      playerIndex: attackerPlayerIndex,
      player: attackerPlayer,
      attacker,
      defender: null,
      combatOptions,
    });
    emitGameEvent(state, GAME_EVENTS.COMBAT_RESOLVED, {
      attackerPlayerIndex,
      attackerUnitId: attacker.uid,
      defenderPlayerIndex,
      defenderUnitId: null,
      targetRealmId: targetRealm.uid,
      defenderSurvived: !result.destroyed,
      enteredFromReserve,
      remote,
      keywordBonuses,
    });
    return;
  }

  if (!defender || defenderIndex < 0) {
    recordEvent(
      state,
      GAME_EVENTS.COMBAT_STARTED,
      { attackerPlayerIndex, attackerUnitId: attacker.uid, defenderUnitId: null, remote, keywordBonuses },
      remote ? `${attacker.name} 越过空缺前线发起远程攻击。` : `${attacker.name} 突破空缺前线。`,
      'success',
    );
    damageAvatar(state, defenderPlayerIndex, attackPower, attackerPlayerIndex);
    applyCombatResolvedKeywordHooks({
      state,
      playerIndex: attackerPlayerIndex,
      player: attackerPlayer,
      attacker,
      defender: null,
      combatOptions,
    });
    emitGameEvent(state, GAME_EVENTS.COMBAT_RESOLVED, {
      attackerPlayerIndex,
      attackerUnitId: attacker.uid,
      defenderPlayerIndex,
      defenderUnitId: null,
      defenderSurvived: false,
      enteredFromReserve,
      remote,
      keywordBonuses,
    });
    return;
  }

  const counterPower = defender.attack;
  let counterAllowed = !remote && defender.frozen === 0;
  recordEvent(
    state,
    GAME_EVENTS.COMBAT_STARTED,
    { attackerPlayerIndex, attackerUnitId: attacker.uid, defenderPlayerIndex, defenderUnitId: defender.uid, remote, keywordBonuses },
    remote ? `${attacker.name} 向 ${defender.name} 发起远程出击。` : `${attacker.name} 向 ${defender.name} 发起出击。`,
  );
  const result = damageUnit(state, defenderPlayerIndex, defenderIndex, attackPower, attackerPlayerIndex);
  if (result.knockedOut && pierce && result.overkill > 0) {
    recordEvent(
      state,
      GAME_EVENTS.PIERCING_TRIGGERED,
      { attackerPlayerIndex, attackerUnitId: attacker.uid, defenderPlayerIndex, defenderUnitId: defender.uid, damage: result.overkill },
      `${attacker.name} 的贯通对 ${defenderPlayer.name} 核心造成 ${result.overkill} 点伤害。`,
      'danger',
    );
    damageAvatar(state, defenderPlayerIndex, result.overkill, attackerPlayerIndex);
  }
  if (result.knockedOut && state.winner === null) damageAvatar(state, defenderPlayerIndex, 1, attackerPlayerIndex);
  // 连击：追加一次等量战斗伤害（目标存活时）
  let defenderDown = result.knockedOut;
  if (combo && state.winner === null && defender.hp > 0) {
    const comboResult = damageUnit(state, defenderPlayerIndex, defenderIndex, attackPower, attackerPlayerIndex);
    defenderDown = defenderDown || comboResult.knockedOut;
    if (comboResult.knockedOut && state.winner === null) damageAvatar(state, defenderPlayerIndex, 1, attackerPlayerIndex);
  }
  // 先攻：首次伤害即气绝目标时，不受反击
  if (firstStrike && defenderDown) counterAllowed = false;
  if (state.winner === null && attacker.hp > 0 && counterAllowed && counterPower > 0) {
    damageUnit(state, attackerPlayerIndex, attackerUnitIndex, counterPower, defenderPlayerIndex);
  }
  applyCombatResolvedKeywordHooks({
    state,
    playerIndex: attackerPlayerIndex,
    player: attackerPlayer,
    attacker,
    defender,
    combatOptions,
  });
  emitGameEvent(state, GAME_EVENTS.COMBAT_RESOLVED, {
    attackerPlayerIndex,
    attackerUnitId: attacker.uid,
    defenderPlayerIndex,
    defenderUnitId: defender.uid,
    defenderSurvived: defender.hp > 0,
    enteredFromReserve,
    remote,
    keywordBonuses,
  });
}

function applyForm(state, playerIndex, sourceIndex, card) {
  const unit = state.players[playerIndex].units[sourceIndex];
  const bonuses = card.value ?? { attack: 0, hp: 0 };
  const damageTaken = Math.max(0, unit.maxHp - unit.hp);
  unit.attack = unit.baseAttack + (bonuses.attack ?? 0);
  unit.maxHp = unit.baseMaxHp + (bonuses.hp ?? 0);
  unit.hp = unit.hp > 0 ? Math.max(1, unit.maxHp - damageTaken) : 0;
  unit.form = {
    cardId: card.id,
    name: card.name,
    attackBonus: bonuses.attack ?? 0,
    hpBonus: bonuses.hp ?? 0,
  };
  recordEvent(
    state,
    GAME_EVENTS.FORM_CHANGED,
    { playerIndex, unitIndex: sourceIndex, form: unit.form },
    `${unit.name} 切换为「${card.name}」。`,
    'success',
  );
}

function deployRealm(state, playerIndex, card) {
  const player = state.players[playerIndex];
  const realm = {
    uid: `realm-${state.nextRealmId++}`,
    cardId: card.id,
    unitId: card.unitId,
    name: card.name,
    text: card.text,
    keywords: [...card.keywords],
    ...clone(card.realm),
    maxHp: card.realm.hp,
  };
  const existingIndex = player.realms.findIndex((candidate) => candidate.cardId === card.id);
  if (existingIndex >= 0) player.realms[existingIndex] = realm;
  else player.realms.push(realm);
  emitGameEvent(
    state,
    GAME_EVENTS.REALM_DEPLOYED,
    { playerIndex, realm: clone(realm), sourceUnitId: `${player.id}:${card.unitId}` },
    `${player.name} 部署幻境「${card.name}」。`,
    'card',
  );
}

const REALM_TRIGGER_HANDLERS = new Map([
  ['shield-front', (state, ownerIndex, realm) => {
    const owner = state.players[ownerIndex];
    const frontIndex = frontIndexOf(owner);
    if (frontIndex < 0) return;
    owner.units[frontIndex].shield += realm.triggerValue;
    recordEvent(state, GAME_EVENTS.REALM_TRIGGERED, { ownerIndex, cardId: realm.cardId, unitIndex: frontIndex }, `${realm.name} 为 ${owner.units[frontIndex].name} 提供 ${realm.triggerValue} 点护盾。`, 'success');
  }],
  ['damage-enemy-front', (state, ownerIndex, realm) => {
    const enemyIndex = 1 - ownerIndex;
    const frontIndex = frontIndexOf(state.players[enemyIndex]);
    if (frontIndex < 0) return;
    recordEvent(state, GAME_EVENTS.REALM_TRIGGERED, { ownerIndex, cardId: realm.cardId, targetIndex: frontIndex }, `${realm.name} 引动前线雷压。`, 'card');
    damageUnit(state, enemyIndex, frontIndex, realm.triggerValue, ownerIndex);
  }],
  ['draw', (state, ownerIndex, realm) => {
    recordEvent(state, GAME_EVENTS.REALM_TRIGGERED, { ownerIndex, cardId: realm.cardId }, `${realm.name} 翻开一页新的战术记录。`, 'card');
    drawCards(state, ownerIndex, realm.triggerValue);
  }],
]);

function triggerRealms(state, playerIndex, trigger) {
  const player = state.players[playerIndex];
  player.realms.map((realm) => realm.uid).forEach((realmId) => {
    const realm = player.realms.find((candidate) => candidate.uid === realmId);
    if (!realm) return;
    if (realm.trigger !== trigger || state.winner !== null) return;
    const keywordContext = { state, playerIndex, realm, recordEvent, gameEvents: GAME_EVENTS };
    if (!prepareRealmKeywordTrigger(keywordContext)) return;
    REALM_TRIGGER_HANDLERS.get(realm.triggerEffect)?.(state, playerIndex, realm);
    completeRealmKeywordTrigger(keywordContext);
  });
}

function resolveChargeUpStep(state, playerIndex, unit, step) {
  const player = state.players[playerIndex];
  const enemyIndex = 1 - playerIndex;
  const enemy = state.players[enemyIndex];
  if (step.action === 'shield-self') {
    unit.shield += step.value;
    recordEvent(state, GAME_EVENTS.CARD_PLAYED, { playerIndex, unitId: unit.uid, effect: 'charge-shield' }, `${unit.name} 获得 ${step.value} 点护盾。`, 'success');
    return;
  }
  if (step.action === 'heal-self') {
    healUnit(state, playerIndex, player.units.indexOf(unit), step.value);
    return;
  }
  if (step.action === 'damage-enemy-front') {
    const frontIndex = enemy.units.findIndex((candidate) => candidate.uid === enemy.frontUnitId && candidate.hp > 0);
    if (frontIndex >= 0) damageUnit(state, enemyIndex, frontIndex, step.value, playerIndex);
    else damageAvatar(state, enemyIndex, step.value, playerIndex);
    return;
  }
  if (step.action === 'damage-enemy-avatar') {
    damageAvatar(state, enemyIndex, step.value, playerIndex);
    return;
  }
  if (step.action === 'draw') drawCards(state, playerIndex, step.value);
}

function advanceChargeUps(state, playerIndex) {
  const player = state.players[playerIndex];
  player.units.forEach((unit) => {
    const chargeUp = unit.chargeUp;
    if (!chargeUp || unit.hp <= 0) return;
    chargeUp.counters += 1;
    if (chargeUp.counters < chargeUp.threshold) {
      recordEvent(state, GAME_EVENTS.CARD_PLAYED, { playerIndex, unitId: unit.uid, effect: 'charge-tick', counters: chargeUp.counters }, `${unit.name} 的蓄力推进至 ${chargeUp.counters}/${chargeUp.threshold}。`, 'turn');
      return;
    }
    recordEvent(state, GAME_EVENTS.CARD_PLAYED, { playerIndex, unitId: unit.uid, effect: 'charge-trigger' }, `${unit.name} 的蓄力「${chargeUp.name}」成熟，开始结算。`, 'success');
    const steps = chargeUp.effects;
    unit.chargeUp = null;
    steps.forEach((step) => resolveChargeUpStep(state, playerIndex, unit, step));
    checkWinner(state);
  });
}

function resolveNightfallIfDue(state, playerIndex) {
  const player = state.players[playerIndex];
  const pending = player.keywordUsage?.nightfall?.pending;
  if (!pending || pending.triggered || state.turnCounter < pending.round) return;
  pending.triggered = true;
  const enemyIndex = 1 - playerIndex;
  recordEvent(state, GAME_EVENTS.CARD_PLAYED, { playerIndex, effect: 'nightfall', round: pending.round }, `夜幕降临：「${pending.name}」生效。`, 'danger');
  if (pending.effect === 'damage-all-enemy-units') {
    state.players[enemyIndex].units.forEach((unit, index) => {
      if (unit.hp > 0) damageUnit(state, enemyIndex, index, pending.value, playerIndex);
    });
  } else if (pending.effect === 'heal-all-own-units') {
    player.units.forEach((unit, index) => {
      if (unit.hp > 0) healUnit(state, playerIndex, index, pending.value);
    });
  } else if (pending.effect === 'damage-enemy-avatar') {
    damageAvatar(state, enemyIndex, pending.value, playerIndex);
  }
  checkWinner(state);
}

function beginTurn(state, playerIndex) {
  const player = state.players[playerIndex];
  player.turnsTaken += 1;
  player.maxEnergy = GAME_RULES.maxEnergy;
  player.energy = player.maxEnergy;
  player.attackUsed = false;
  player.levelUpUsed = false;
  if (playerIndex === 0 && player.turnsTaken === GAME_RULES.bonusUpgradeTurn) {
    player.bonusUpgrades += 1;
    recordEvent(
      state,
      GAME_EVENTS.TURN_STARTED,
      { playerIndex, bonusUpgrade: true },
      `${player.name} 获得一次额外升勾机会。`,
      'success',
    );
  }
  player.cardsPlayedThisTurn = 0;
  applyTurnStartKeywordHooks({ state, playerIndex, player, recordEvent, gameEvents: GAME_EVENTS });

  player.units.forEach((unit, unitIndex) => {
    if (unit.hp > 0 || unit.knockout <= 0) return;
    unit.knockout -= 1;
    if (unit.knockout === 0) {
      // 本家规则：气绝倒计时结束后复活并回复全部生命
      unit.hp = unit.maxHp;
      recordEvent(
        state,
        GAME_EVENTS.UNIT_RETURNED,
        { playerIndex, unitIndex, hp: unit.hp, source: 'countdown' },
        `${unit.name} 自行归队，生命回复至 ${unit.hp}/${unit.maxHp}。`,
        'success',
      );
    }
  });

  advanceChargeUps(state, playerIndex);
  resolveNightfallIfDue(state, playerIndex);
  triggerRealms(state, playerIndex, 'owner-turn-start');
  if (state.winner === null) drawCards(state, playerIndex, 1);
  if (state.winner === null) triggerAutomaticKeywordCards(state, playerIndex);
  if (state.winner === null) {
    emitGameEvent(state, GAME_EVENTS.TURN_STARTED, { playerIndex }, `${player.name} 获得行动权。`, 'turn');
  }
  // 本家规则：己方回合开始时，战斗区角色自动回退准备区（攻击者留场穿越对手回合后归位）
  const returningIndex = frontIndexOf(player);
  if (returningIndex >= 0) {
    const returningUnit = player.units[returningIndex];
    leaveBattleZone(player, returningIndex, 'turn-start');
    recordEvent(
      state,
      GAME_EVENTS.UNIT_RETURNED,
      { playerIndex, unitIndex: returningIndex, unitId: returningUnit.uid, source: 'battle-zone' },
      `${returningUnit.name} 从战斗区返回准备区。`,
      'neutral',
    );
  }
}

export function createGame(input = undefined) {
  const options = normalizeGameOptions(input);
  const state = {
    rng: options.seed,
    nextCardId: 1,
    nextEventId: 1,
    nextResolutionId: 1,
    nextRealmId: 1,
    turnCounter: 1,
    currentPlayer: 0,
    phase: 'main',
    winner: null,
    log: [],
    events: [],
    eventQueue: [],
    isFlushingEvents: false,
    resolutionStack: [],
    responseWindow: null,
    pendingChoice: null,
    isResolving: false,
    players: [],
  };

  state.players = [
    createPlayer(state, 'player', '巡界者', options.playerDeckDefinition),
    createPlayer(state, 'ai', '失序体', options.enemyDeckDefinition),
  ];
  // 开局：双方最左侧首位角色免费升至 1 勾（激活）
  state.players.forEach((player) => {
    const first = player.units[0];
    if (first) first.level = 1;
  });
  drawCards(state, 0, GAME_RULES.openingHandSize - 1);
  drawCards(state, 1, GAME_RULES.openingHandSize - 1);
  beginTurn(state, 0);
  recordEvent(state, GAME_EVENTS.MATCH_STARTED, { playerIndex: 0 }, '灵契编成已锁定，对局开始。', 'turn');
  return state;
}

function sourceUnitFor(player, card) {
  return player.units.findIndex((unit) => unit.id === card.unitId);
}

export function getFormation(state, playerIndex) {
  const player = state.players[playerIndex];
  const frontIndex = frontIndexOf(player);
  return {
    frontIndex,
    frontUnitId: player.frontUnitId,
    reserveIndexes: player.units
      .map((unit, index) => (index !== frontIndex ? index : -1))
      .filter((index) => index >= 0),
    reserveUnitIds: player.units
      .filter((unit, index) => index !== frontIndex)
      .map((unit) => unit.uid),
  };
}

export function getValidTargets(state, playerIndex, definitionId) {
  const card = getCardDefinition(definitionId);
  if (!card) return [];
  const own = state.players[playerIndex];
  const enemy = state.players[1 - playerIndex];
  // 未激活（0 勾）角色无法被效果选中
  if (card.target === 'ally-unit') return own.units.filter((unit) => unit.hp > 0 && unit.level >= 1).map((unit) => unit.uid);
  if (card.target === 'knocked-ally') return own.units.filter((unit) => unit.hp <= 0 && unit.level >= 1).map((unit) => unit.uid);
  if (card.target === 'enemy-unit') return enemy.units.filter((unit) => unit.hp > 0 && unit.level >= 1).map((unit) => unit.uid);
  return [];
}

export function getValidCombatTargets(state, playerIndex) {
  const enemy = state.players[1 - playerIndex];
  // 本家规则：只能攻击敌方战斗区内的角色；战斗区为空时直接攻击核心（targetId 为 null）
  const frontIndex = frontIndexOf(enemy);
  const frontId = frontIndex >= 0 ? enemy.units[frontIndex].uid : null;
  return [
    ...(frontId ? [frontId] : []),
    ...enemy.realms.filter((realm) => realm.hp > 0).map((realm) => realm.uid),
  ];
}

function getCardEffects(card) {
  if (Array.isArray(card.effects) && card.effects.length > 0) return card.effects;
  return [{
    condition: 'always',
    action: card.effect,
    target: card.target,
    value: card.value,
  }];
}

function cardMatchesResponseWindow(card, responseWindow) {
  return card.timing === 'response'
    && card.responseTo.includes(responseWindow.action);
}

function effectiveCardCostForDefinition(state, playerIndex, card) {
  const player = state.players[playerIndex];
  return getKeywordModifiedCardCost({ state, playerIndex, player, card });
}

export function getEffectiveCardCost(state, playerIndex, instanceId) {
  const instance = state.players[playerIndex]?.hand.find((candidate) => candidate.instanceId === instanceId);
  const card = instance && getCardDefinition(instance.definitionId);
  return card ? effectiveCardCostForDefinition(state, playerIndex, card) : null;
}

function selectedEffectTarget({ state, player, enemyIndex, targetUnitIndex, effect }) {
  if (!Number.isInteger(targetUnitIndex)) return null;
  if (['selected-enemy', 'enemy-unit'].includes(effect.target)) {
    return state.players[enemyIndex].units[targetUnitIndex] ?? null;
  }
  if (['selected-ally', 'ally-unit', 'knocked-ally'].includes(effect.target)) {
    return player.units[targetUnitIndex] ?? null;
  }
  return null;
}

const EFFECT_CONDITION_HANDLERS = new Map([
  ['always', {
    allows: () => true,
  }],
  ['source-ready', {
    canPlay: ({ source }) => (source.frozen > 0
      ? { playable: false, code: 'frozen', reason: `${source.name}被眩晕，无法发动战斗牌。` }
      : null),
    allows: ({ source }) => source.frozen === 0,
  }],
  ['match-active', {
    allows: ({ state }) => state.winner === null,
  }],
  ['target-alive', {
    allows: (context) => selectedEffectTarget(context)?.hp > 0,
  }],
  ['fortune-success', {
    allows: (context) => getKeywordEffectConditionDecision(context) === true,
  }],
  ['bestow-ready', {
    allows: (context) => getKeywordEffectConditionDecision(context) === true,
  }],
]);

// 升级阶段强制先行：本回合尚未升勾且存在可升级的存活角色时，需先完成升勾才能出牌/出击
// 开局调度：首回合行动前可替换手牌（最多 GAME_RULES.mulliganCount 张）
export function canMulligan(state, playerIndex) {
  if (state.winner !== null || state.pendingChoice || state.responseWindow) return false;
  if (state.currentPlayer !== playerIndex) return false;
  const player = state.players[playerIndex];
  return player.mulligansUsed < GAME_RULES.mulliganCount
    && player.turnsTaken <= 1
    && player.cardsPlayedThisTurn === 0
    && !player.attackUsed;
}

export function mulliganCard(state, playerIndex, instanceId) {
  if (state.pendingChoice) return { state, error: '请先完成当前的占卜选择。' };
  if (state.responseWindow) return { state, error: '请先处理当前响应窗口。' };
  if (state.winner !== null || state.currentPlayer !== playerIndex) return { state, error: '现在无法替换手牌。' };
  const player = state.players[playerIndex];
  if (player.mulligansUsed >= GAME_RULES.mulliganCount) return { state, error: '开局替换机会已用完。' };
  if (player.turnsTaken > 1 || player.cardsPlayedThisTurn > 0 || player.attackUsed) {
    return { state, error: '已进入行动阶段，无法再替换手牌。' };
  }
  const index = player.hand.findIndex((item) => item.instanceId === instanceId);
  if (index < 0) return { state, error: '没有找到这张牌。' };

  const next = clone(state);
  const nextPlayer = next.players[playerIndex];
  const [replaced] = nextPlayer.hand.splice(index, 1);
  nextPlayer.deck.unshift(replaced); // 换下的牌沉到牌库底
  nextPlayer.mulligansUsed += 1;
  drawCards(next, playerIndex, 1);
  recordEvent(
    next,
    GAME_EVENTS.CARD_DRAWN,
    { playerIndex, replacedInstanceId: instanceId },
    `${nextPlayer.name} 替换了开局手牌（${nextPlayer.mulligansUsed}/${GAME_RULES.mulliganCount}）。`,
    'neutral',
  );
  return { state: next, error: null };
}

export function isUpgradePending(state, playerIndex) {
  if (state.winner !== null || state.currentPlayer !== playerIndex) return false;
  const player = state.players[playerIndex];
  return !player.levelUpUsed
    && player.units.some((unit) => unit.hp > 0 && unit.level < GAME_RULES.maxUnitLevel);
}

export function getCardPlayability(state, playerIndex, instanceId, options = {}) {
  const player = state.players[playerIndex];
  const instance = player?.hand.find((candidate) => candidate.instanceId === instanceId);
  const card = instance && getCardDefinition(instance.definitionId);
  if (!instance || !card) return { playable: false, code: 'missing', reason: '没有找到这张牌。' };
  if (state.winner !== null) return { playable: false, code: 'finished', reason: '对局已经结束。' };
  if (state.pendingChoice) return { playable: false, code: 'choice-wait', reason: '请先完成当前的占卜选择。' };
  if (state.responseWindow) {
    if (state.responseWindow.playerIndex !== playerIndex) {
      return { playable: false, code: 'response-wait', reason: '等待对手决定是否响应。' };
    }
    if (!cardMatchesResponseWindow(card, state.responseWindow)) {
      return { playable: false, code: 'response-only', reason: '响应窗口中只能使用符合触发条件的响应牌。' };
    }
  } else if (state.currentPlayer !== playerIndex) {
    return { playable: false, code: 'turn', reason: '等待对手完成行动。' };
  }
  if (!options.skipUpgradeGate && isUpgradePending(state, playerIndex)) {
    return { playable: false, code: 'upgrade', reason: '升级阶段：请先选择一名角色提升勾玉。' };
  }
  const effectiveCost = effectiveCardCostForDefinition(state, playerIndex, card);
  if (player.energy < effectiveCost) return { playable: false, code: 'energy', reason: `鬼火不足：需要 ${effectiveCost}，当前 ${player.energy}。` };

  const sourceIndex = sourceUnitFor(player, card);
  const source = player.units[sourceIndex];
  if (sourceIndex < 0 || source.hp <= 0) {
    return { playable: false, code: 'source-away', reason: `${source?.name ?? '本源角色'}正处于气绝。` };
  }
  if (source.level < 1) {
    return { playable: false, code: 'source-dormant', reason: `${source.name} 尚未激活（0 勾），先提升勾玉。` };
  }
  if (source.level < card.level) {
    return { playable: false, code: 'level', reason: `需要 ${card.level} 勾玉，${source.name} 当前为 ${source.level} 勾。` };
  }
  const enemyIndex = 1 - playerIndex;
  const effectContext = { state, player, playerIndex, enemyIndex, source, sourceIndex, card };
  const keywordBlock = getKeywordCardPlayabilityBlock(effectContext);
  if (keywordBlock) return keywordBlock;
  for (const effect of getCardEffects(card)) {
    const conditionHandler = EFFECT_CONDITION_HANDLERS.get(effect.condition);
    const effectHandler = EFFECT_HANDLERS.get(effect.action);
    if (!conditionHandler) return { playable: false, code: 'effect', reason: `卡牌条件 ${effect.condition} 尚未注册。` };
    if (!effectHandler) return { playable: false, code: 'effect', reason: `卡牌动作 ${effect.action} 尚未注册。` };
    const conditionBlock = conditionHandler.canPlay?.({ ...effectContext, effect });
    if (conditionBlock) return conditionBlock;
    const effectBlock = effectHandler.canPlay?.({ ...effectContext, effect });
    if (effectBlock) return effectBlock;
  }
  if (card.target !== 'auto' && getValidTargets(state, playerIndex, card.id).length === 0) {
    return { playable: false, code: 'no-target', reason: '当前没有有效目标。' };
  }
  return { playable: true, code: 'ready', reason: '可以使用。' };
}

export function canPlayCard(state, playerIndex, instanceId) {
  return getCardPlayability(state, playerIndex, instanceId).playable;
}

function startDivination(state, playerIndex, card, frame) {
  const player = state.players[playerIndex];
  const count = Math.min(card.divination.count, player.deck.length);
  const instanceIds = player.deck.slice(-count).map((instance) => instance.instanceId);
  if (!instanceIds.length) return;
  state.pendingChoice = {
    type: 'divination',
    playerIndex,
    resolutionId: frame.resolutionId,
    definitionId: card.id,
    instanceIds,
  };
  state.phase = 'choice';
  recordEvent(
    state,
    GAME_EVENTS.DIVINATION_STARTED,
    clone(state.pendingChoice),
    `${player.name} 正在占卜牌库顶的 ${instanceIds.length} 张牌。`,
    'card',
  );
}

const EFFECT_HANDLERS = new Map([
  ['assault', {
    canPlay: ({ source }) => (source.frozen > 0
      ? { playable: false, code: 'frozen', reason: `${source.name}被眩晕，无法发动战斗牌。` }
      : null),
    resolve: ({ state, playerIndex, source, sourceIndex, card, effect, targetId }) => resolveCombat(state, playerIndex, sourceIndex, {
      bonus: effect.value ?? card.value,
      targetId,
      ...getKeywordCombatOptions({ state, playerIndex, player: state.players[playerIndex], source, card, effect }),
    }),
  }],
  ['damage', {
    resolve: ({ state, enemyIndex, targetUnitIndex, card, playerIndex, effect }) => {
      const amount = effect.value ?? card.value;
      const route = getKeywordDamageRoute({ state, enemyIndex, playerIndex, card, effect });
      if (route?.type === 'unit') {
        damageUnit(state, enemyIndex, route.unitIndex, amount, playerIndex);
        return;
      }
      if (route?.type === 'avatar') {
        damageAvatar(state, enemyIndex, amount, playerIndex);
        return;
      }
      if (['selected-enemy', 'enemy-unit'].includes(effect.target)) {
        damageUnit(state, enemyIndex, targetUnitIndex, amount, playerIndex);
        return;
      }
      if (effect.target === 'all-enemy-units') {
        state.players[enemyIndex].units.forEach((unit, index) => {
          if (unit.hp > 0) damageUnit(state, enemyIndex, index, amount, playerIndex);
        });
        return;
      }
      if (effect.target === 'enemy-avatar') damageAvatar(state, enemyIndex, amount, playerIndex);
    },
  }],
  ['burn-all', {
    resolve: ({ state, enemyIndex, playerIndex, card }) => {
      state.players[enemyIndex].units.forEach((unit, index) => {
        if (unit.hp > 0) damageUnit(state, enemyIndex, index, card.value, playerIndex);
      });
      if (state.winner === null) damageAvatar(state, enemyIndex, 2, playerIndex);
    },
  }],
  ['shield', {
    resolve: ({ state, player, playerIndex, targetUnitIndex, targetId, card, effect }) => {
      const amount = effect.value ?? card.value;
      player.units[targetUnitIndex].shield += amount;
      recordEvent(state, GAME_EVENTS.CARD_PLAYED, { playerIndex, targetId, effect: 'shield' }, `${player.units[targetUnitIndex].name} 获得 ${amount} 点护盾。`, 'success');
    },
  }],
  ['grant-unyielding', {
    resolve: ({ state, player, playerIndex, targetUnitIndex, targetId }) => {
      const target = player.units[targetUnitIndex];
      if (!target || target.hp <= 0 || target.unyielding) return;
      target.unyielding = true;
      recordEvent(state, GAME_EVENTS.CARD_PLAYED, { playerIndex, targetId, effect: 'grant-unyielding' }, `${target.name} 获得不屈：生命大于 1 时不会因伤害气绝。`, 'success');
    },
  }],
  ['fortify', {
    resolve: ({ state, player, playerIndex, sourceIndex, card, effect }) => {
      const source = player.units[sourceIndex];
      const amount = effect.value ?? card.value;
      const previousFrontUnitId = player.frontUnitId;
      player.frontUnitId = source.uid;
      source.shield += amount;
      emitGameEvent(state, GAME_EVENTS.UNIT_ENTERED_FRONT, { playerIndex, unitId: source.uid, previousFrontUnitId }, `${source.name} 进入前线并获得 ${amount} 点护盾。`, 'success');
    },
  }],
  ['heal', {
    resolve: ({ state, playerIndex, targetUnitIndex, card, effect }) => healUnit(state, playerIndex, targetUnitIndex, effect.value ?? card.value),
  }],
  ['draw-heal', {
    resolve: ({ state, player, playerIndex, card }) => {
      drawCards(state, playerIndex, card.value);
      if (state.winner !== null) return;
      healAvatar(state, playerIndex, 1);
    },
  }],
  ['revive', {
    resolve: ({ state, playerIndex, targetUnitIndex, card, effect }) => reviveUnit(state, playerIndex, targetUnitIndex, effect.value ?? card.value),
  }],
  ['freeze', {
    resolve: ({ state, enemyIndex, targetUnitIndex, targetId, effect }) => {
      const target = state.players[enemyIndex].units[targetUnitIndex];
      target.frozen = Math.max(effect.value ?? 1, target.frozen);
      recordEvent(state, GAME_EVENTS.CARD_PLAYED, { enemyIndex, targetId, effect: 'freeze' }, `${target.name} 被眩晕。`, 'card');
    },
  }],
  ['brittle', {
    resolve: ({ state, enemyIndex, targetUnitIndex, targetId, card, playerIndex }) => {
      damageUnit(state, enemyIndex, targetUnitIndex, card.value, playerIndex);
      const target = state.players[enemyIndex].units[targetUnitIndex];
      if (target.hp <= 0) return;
      target.brittle = card.id === 'erode-script' ? 1 : 2;
      recordEvent(state, GAME_EVENTS.CARD_PLAYED, { enemyIndex, targetId, effect: 'brittle', stacks: target.brittle }, `${target.name} 进入晶裂状态。`, 'card');
    },
  }],
  ['form', {
    resolve: ({ state, playerIndex, sourceIndex, card, effect }) => applyForm(state, playerIndex, sourceIndex, { ...card, value: effect.value ?? card.value }),
  }],
  ['realm', {
    resolve: ({ state, playerIndex, card }) => deployRealm(state, playerIndex, card),
  }],
  ['draw', {
    resolve: ({ state, playerIndex, effect }) => drawCards(state, playerIndex, effect.value),
  }],
  ['heal-avatar', {
    resolve: ({ state, playerIndex, effect }) => healAvatar(state, playerIndex, effect.value),
  }],
  ['divination', {
    resolve: ({ state, playerIndex, card, frame }) => startDivination(state, playerIndex, card, frame),
  }],
  ['apply-keyword', {
    resolve: (context) => {
      const { state, playerIndex } = context;
      const result = applyKeywordEffect(context);
      if (!result) return;
      recordEvent(
        state,
        GAME_EVENTS.KEYWORD_STATE_GAINED,
        { playerIndex, keywordId: result.keywordId, label: result.label, value: result.value },
        result.text,
        'success',
      );
    },
  }],
  ['apply-brittle', {
    resolve: ({ state, enemyIndex, targetUnitIndex, targetId, effect }) => {
      const target = state.players[enemyIndex].units[targetUnitIndex];
      target.brittle = effect.value;
      recordEvent(state, GAME_EVENTS.CARD_PLAYED, { enemyIndex, targetId, effect: 'brittle', stacks: target.brittle }, `${target.name} 进入晶裂状态。`, 'card');
    },
  }],
  ['chain-draw', {
    resolve: ({ state, player, playerIndex, card }) => {
      const unitName = getUnitDefinition(card.unitId)?.name ?? '同源';
      const deckIndex = player.deck.findIndex((instance) => getCardDefinition(instance.definitionId)?.unitId === card.unitId);
      if (deckIndex < 0) {
        recordEvent(state, GAME_EVENTS.CARD_PLAYED, { playerIndex, effect: 'chain-draw', found: false }, `连引未果：牌库中已没有${unitName}的牌。`, 'turn');
        return;
      }
      const [instance] = player.deck.splice(deckIndex, 1);
      player.hand.push(instance);
      recordEvent(state, GAME_EVENTS.CARD_DRAWN, { playerIndex, instanceId: instance.instanceId, effect: 'chain-draw' }, `连引：将「${getCardDefinition(instance.definitionId).name}」纳入手牌。`, 'success');
    },
  }],
  ['origin-shuffle', {
    resolve: ({ state, player, playerIndex, card }) => {
      const instance = { instanceId: `${player.id}-${state.nextCardId++}`, definitionId: card.id };
      const insertIndex = player.deck.length > 0
        ? Math.floor(nextRandom(state) * (player.deck.length + 1))
        : 0;
      player.deck.splice(insertIndex, 0, instance);
      recordEvent(state, GAME_EVENTS.CARD_PLAYED, { playerIndex, effect: 'origin-shuffle', definitionId: card.id }, `起源：一张「${card.name}」回到牌库深处。`, 'success');
    },
  }],
  ['focus-draw', {
    resolve: ({ state, player, playerIndex, effect }) => {
      if ((player.cardsPlayedThisTurn ?? 0) > 1) {
        recordEvent(state, GAME_EVENTS.CARD_PLAYED, { playerIndex, effect: 'focus-draw', focused: false }, '专注未达成：本回合已使用过其他卡牌。', 'turn');
        return;
      }
      drawCards(state, playerIndex, effect.value ?? 1);
      recordEvent(state, GAME_EVENTS.CARD_PLAYED, { playerIndex, effect: 'focus-draw', focused: true }, '专注达成，灵感涌现。', 'success');
    },
  }],
  ['cook-ingredient', {
    resolve: ({ state, player, playerIndex, effect }) => {
      const ingredientLabels = { fish: '鲜鱼', rice: '稻米', herb: '霜菜' };
      if (!player.keywordUsage.cook || typeof player.keywordUsage.cook !== 'object' || Array.isArray(player.keywordUsage.cook)) {
        player.keywordUsage.cook = { fish: 0, rice: 0, herb: 0 };
      }
      const usage = player.keywordUsage.cook;
      usage[effect.value] = (usage[effect.value] ?? 0) + 1;
      recordEvent(
        state,
        GAME_EVENTS.CARD_PLAYED,
        { playerIndex, effect: 'cook-ingredient', ingredient: effect.value },
        `获得食材「${ingredientLabels[effect.value] ?? effect.value}」（鱼${usage.fish} 米${usage.rice} 菜${usage.herb}）。`,
        'success',
      );
      if (usage.fish < 1 || usage.rice < 1 || usage.herb < 1) return;
      usage.fish -= 1;
      usage.rice -= 1;
      usage.herb -= 1;
      player.units.forEach((unit) => {
        if (unit.hp <= 0) return;
        unit.attack += 1;
        unit.maxHp += 1;
        unit.hp += 1;
      });
      recordEvent(state, GAME_EVENTS.KEYWORD_STATE_GAINED, { playerIndex, keywordId: 'cook', effect: 'cook-complete' }, '食材集齐，一席灵宴完成：全体己方角色 +1/+1。', 'success');
    },
  }],
  ['attach-charge', {
    resolve: ({ state, playerIndex, source, card, effect }) => {
      const value = effect.value;
      source.chargeUp = {
        cardId: card.id,
        name: card.name,
        threshold: value.threshold,
        counters: 0,
        effects: value.effects.map((step) => ({ ...step })),
      };
      recordEvent(state, GAME_EVENTS.CARD_PLAYED, { playerIndex, unitId: source.uid, effect: 'attach-charge' }, `${source.name} 进入蓄力（${value.threshold} 回合后结算）。`, 'success');
    },
  }],
  ['set-nightfall', {
    resolve: ({ state, player, playerIndex, card, effect }) => {
      const value = effect.value;
      player.keywordUsage.nightfall = {
        pending: {
          cardId: card.id,
          name: card.name,
          round: value.round,
          effect: value.effect,
          value: value.value,
          triggered: false,
        },
      };
      recordEvent(state, GAME_EVENTS.CARD_PLAYED, { playerIndex, effect: 'set-nightfall', round: value.round }, `夜幕预约：第 ${value.round} 回合开始时「${card.name}」生效。`, 'card');
    },
  }],
]);

function createCardResolutionFrames(state, playerIndex, instanceId, card, targetId, options = {}) {
  const resolutionId = state.nextResolutionId;
  state.nextResolutionId += 1;
  const baseFrame = {
    resolutionId,
    playerIndex,
    instanceId,
    definitionId: card.id,
    targetId,
  };
  state.resolutionStack.push({ ...baseFrame, kind: 'card-complete', respondable: false });
  const effects = getCardEffects(card);
  for (let effectIndex = effects.length - 1; effectIndex >= 0; effectIndex -= 1) {
    state.resolutionStack.push({
      ...baseFrame,
      kind: 'card-effect',
      effectIndex,
      respondable: options.respondable === true && effectIndex === 0,
      responseOffered: false,
      responseDepth: options.responseDepth ?? 0,
    });
  }
  if (state.resolutionStack.length > MAX_RESOLUTION_STACK_LENGTH) {
    throw new Error('结算栈超过安全上限。');
  }
}

function resolveCardEffectFrame(state, frame) {
  const card = getCardDefinition(frame.definitionId);
  const effect = getCardEffects(card)[frame.effectIndex];
  const player = state.players[frame.playerIndex];
  const enemyIndex = 1 - frame.playerIndex;
  const sourceIndex = sourceUnitFor(player, card);
  const source = player.units[sourceIndex];
  const targetOwner = card.target === 'enemy-unit' ? state.players[enemyIndex] : player;
  const targetUnitIndex = frame.targetId ? unitIndexByUid(targetOwner, frame.targetId) : null;
  const context = {
    state,
    player,
    playerIndex: frame.playerIndex,
    enemyIndex,
    targetUnitIndex,
    targetId: frame.targetId,
    card,
    source,
    sourceIndex,
    effect,
    condition: effect.condition,
    frame,
    random: () => nextRandom(state),
  };
  if (frame.effectIndex === 0) {
    applyCardResolutionKeywordHooks(context).forEach((payment) => {
      recordEvent(
        state,
        payment.eventType ?? GAME_EVENTS.KEYWORD_RESOURCE_SPENT,
        {
          playerIndex: frame.playerIndex,
          keywordId: payment.keywordId,
          label: payment.label,
          ...payment.value,
        },
        payment.text,
        'card',
      );
    });
  }
  const allowed = EFFECT_CONDITION_HANDLERS.get(effect.condition)?.allows(context) ?? false;
  if (allowed) EFFECT_HANDLERS.get(effect.action).resolve(context);
  recordEvent(state, GAME_EVENTS.RESOLUTION_STEP_RESOLVED, {
    resolutionId: frame.resolutionId,
    playerIndex: frame.playerIndex,
    definitionId: card.id,
    effectIndex: frame.effectIndex,
    action: effect.action,
    target: effect.target,
    skipped: !allowed,
  });
  checkWinner(state);
}

function resolveCardCompleteFrame(state, frame) {
  const card = getCardDefinition(frame.definitionId);
  const player = state.players[frame.playerIndex];
  const sourceIndex = sourceUnitFor(player, card);
  emitGameEvent(
    state,
    GAME_EVENTS.CARD_PLAYED,
    {
      playerIndex: frame.playerIndex,
      instanceId: frame.instanceId,
      definitionId: card.id,
      targetId: frame.targetId,
      sourceUnitId: player.units[sourceIndex]?.uid ?? null,
      resolutionId: frame.resolutionId,
    },
    `${player.name} 使用「${card.name}」。`,
    'card',
  );
}

function hasPlayableResponse(state, playerIndex) {
  return state.players[playerIndex].hand.some((instance) => getCardPlayability(
    state,
    playerIndex,
    instance.instanceId,
  ).playable);
}

function createResponseWindow(frame) {
  const effect = getCardEffects(getCardDefinition(frame.definitionId))[frame.effectIndex];
  return {
    id: `response-${frame.resolutionId}-${frame.responseDepth}`,
    playerIndex: 1 - frame.playerIndex,
    sourcePlayerIndex: frame.playerIndex,
    resolutionId: frame.resolutionId,
    definitionId: frame.definitionId,
    action: effect.action,
    target: effect.target,
    targetId: frame.targetId,
    consecutivePasses: 0,
    depth: frame.responseDepth,
  };
}

function eitherPlayerHasResponse(state) {
  const firstPlayerIndex = state.responseWindow.playerIndex;
  if (hasPlayableResponse(state, firstPlayerIndex)) return true;
  state.responseWindow.playerIndex = 1 - firstPlayerIndex;
  const otherPlayerHasResponse = hasPlayableResponse(state, 1 - firstPlayerIndex);
  state.responseWindow.playerIndex = firstPlayerIndex;
  return otherPlayerHasResponse;
}

function resolveResolutionStack(state) {
  if (state.isResolving || state.responseWindow || state.pendingChoice) return;
  state.isResolving = true;
  try {
    while (state.resolutionStack.length && state.winner === null) {
      const frame = state.resolutionStack.at(-1);
      if (frame.kind === 'card-effect' && frame.respondable && !frame.responseOffered) {
        frame.responseOffered = true;
        state.responseWindow = createResponseWindow(frame);
        if (eitherPlayerHasResponse(state)) {
          state.phase = 'response';
          recordEvent(state, GAME_EVENTS.RESPONSE_WINDOW_OPENED, clone(state.responseWindow));
          return;
        }
        state.responseWindow = null;
      }

      state.resolutionStack.pop();
      if (frame.kind === 'card-effect') resolveCardEffectFrame(state, frame);
      else resolveCardCompleteFrame(state, frame);
      if (state.pendingChoice) return;
    }
  } finally {
    state.isResolving = false;
    if (!state.responseWindow && !state.pendingChoice && state.winner === null) state.phase = 'main';
  }
}

export function resolveDivinationChoice(state, playerIndex, instanceId) {
  const choice = state.pendingChoice;
  if (!choice || choice.type !== 'divination' || choice.playerIndex !== playerIndex) {
    return { state, error: '当前没有可由你处理的占卜选择。' };
  }
  if (!choice.instanceIds.includes(instanceId)) return { state, error: '请选择占卜展示的卡牌。' };

  const next = clone(state);
  const player = next.players[playerIndex];
  const deckIndex = player.deck.findIndex((instance) => instance.instanceId === instanceId);
  if (deckIndex < 0) return { state, error: '占卜的卡牌已不在牌库中。' };
  const [selected] = player.deck.splice(deckIndex, 1);
  player.deck.push(selected);
  const definition = getCardDefinition(selected.definitionId);
  recordEvent(
    next,
    GAME_EVENTS.DIVINATION_RESOLVED,
    { playerIndex, resolutionId: next.pendingChoice.resolutionId, instanceId, definitionId: definition.id },
    `${player.name} 将「${definition.name}」置于牌库顶。`,
    'success',
  );
  next.pendingChoice = null;
  resolveResolutionStack(next);
  return { state: next, error: null };
}

function passiveUsageAllows(unit, hook, player) {
  const limit = hook.limit;
  if (!limit) return true;
  if (limit.scope !== 'owner-turn') return true;
  const usage = unit.passiveUsage?.[hook.id];
  return usage?.ownerTurn !== player.turnsTaken || usage.count < limit.max;
}

function markPassiveUsage(unit, hook, player) {
  if (!hook.limit) return;
  unit.passiveUsage ??= {};
  const current = unit.passiveUsage[hook.id];
  if (hook.limit.scope === 'owner-turn' && current?.ownerTurn === player.turnsTaken) {
    current.count += 1;
    return;
  }
  unit.passiveUsage[hook.id] = { ownerTurn: player.turnsTaken, count: 1 };
}

const PASSIVE_HANDLERS = new Map([
  ['passive-damage-enemy-front', {
    canTrigger: ({ event, playerIndex, unit }) => event.type === GAME_EVENTS.UNIT_ENTERED_FRONT
      && event.payload.playerIndex === playerIndex
      && event.payload.unitId === unit.uid,
    resolve: ({ state, playerIndex, hook }) => {
      const enemyIndex = 1 - playerIndex;
      const frontIndex = frontIndexOf(state.players[enemyIndex]);
      if (frontIndex >= 0) damageUnit(state, enemyIndex, frontIndex, hook.params.amount, playerIndex);
    },
  }],
  ['passive-shield-self-if-front', {
    canTrigger: ({ event, playerIndex, player, unit }) => event.type === GAME_EVENTS.TURN_STARTED
      && event.payload.playerIndex === playerIndex
      && player.frontUnitId === unit.uid,
    resolve: ({ hook, unit }) => {
      unit.shield += hook.params.amount;
    },
  }],
  ['passive-shield-self-after-combat', {
    canTrigger: ({ event, playerIndex, unit }) => event.type === GAME_EVENTS.COMBAT_RESOLVED
      && event.payload.attackerPlayerIndex === playerIndex
      && event.payload.attackerUnitId === unit.uid
      && !event.payload.remote,
    resolve: ({ hook, unit }) => {
      unit.shield += hook.params.amount;
    },
  }],
  ['passive-heal-self-if-front', {
    canTrigger: ({ event, playerIndex, player, unit }) => event.type === GAME_EVENTS.TURN_STARTED
      && event.payload.playerIndex === playerIndex
      && player.frontUnitId === unit.uid
      && unit.hp > 0,
    resolve: ({ state, playerIndex, hook, unit }) => {
      const healed = Math.min(hook.params.amount, unit.maxHp - unit.hp);
      if (healed <= 0) return;
      unit.hp += healed;
      recordEvent(state, GAME_EVENTS.UNIT_HEALED, { playerIndex, unitId: unit.uid, healed }, `${unit.name} 石肤自愈 ${healed} 点生命。`, 'success');
    },
  }],
  ['passive-heal-avatar-on-own-card', {
    canTrigger: ({ event, playerIndex, unit }) => event.type === GAME_EVENTS.CARD_PLAYED
      && event.payload.playerIndex === playerIndex
      && event.payload.sourceUnitId === unit.uid,
    resolve: ({ state, playerIndex, hook }) => healAvatar(state, playerIndex, hook.params.amount),
  }],
  ['passive-freeze-combat-defender', {
    canTrigger: ({ event, playerIndex, unit }) => event.type === GAME_EVENTS.COMBAT_RESOLVED
      && event.payload.attackerPlayerIndex === playerIndex
      && event.payload.attackerUnitId === unit.uid
      && event.payload.defenderSurvived,
    resolve: ({ state, event, hook }) => {
      const defender = state.players[event.payload.defenderPlayerIndex].units
        .find((candidate) => candidate.uid === event.payload.defenderUnitId);
      if (defender?.hp > 0) defender.frozen = Math.max(defender.frozen, hook.params.turns);
    },
  }],
  ['passive-damage-avatar-after-reserve-combat', {
    canTrigger: ({ event, playerIndex, unit }) => event.type === GAME_EVENTS.COMBAT_RESOLVED
      && event.payload.attackerPlayerIndex === playerIndex
      && event.payload.attackerUnitId === unit.uid
      && event.payload.enteredFromReserve,
    resolve: ({ state, playerIndex, hook }) => {
      damageAvatar(state, 1 - playerIndex, hook.params.amount, playerIndex);
    },
  }],
  ['passive-shield-front-on-realm', {
    canTrigger: ({ event, playerIndex }) => event.type === GAME_EVENTS.REALM_DEPLOYED
      && event.payload.playerIndex === playerIndex,
    resolve: ({ state, playerIndex, hook }) => {
      const frontIndex = frontIndexOf(state.players[playerIndex]);
      if (frontIndex >= 0) state.players[playerIndex].units[frontIndex].shield += hook.params.amount;
    },
  }],
]);

function dispatchPassiveHooks(state, event) {
  const candidates = state.players.flatMap((player, playerIndex) => player.units.flatMap((unit) => {
    if (unit.hp <= 0 || !unit.passive?.hooks) return [];
    return unit.passive.hooks
      .filter((hook) => hook.event === event.type)
      .map((hook) => ({ player, playerIndex, unit, hook }));
  }));

  candidates
    .sort((first, second) => (second.hook.priority - first.hook.priority)
      || (first.playerIndex - second.playerIndex)
      || first.unit.uid.localeCompare(second.unit.uid))
    .forEach((candidate) => {
      if (state.winner !== null || candidate.unit.hp <= 0) return;
      const handler = PASSIVE_HANDLERS.get(candidate.hook.effect);
      if (!handler || !passiveUsageAllows(candidate.unit, candidate.hook, candidate.player)) return;
      const context = { state, event, handler, ...candidate };
      if (!handler.canTrigger?.(context)) return;
      markPassiveUsage(candidate.unit, candidate.hook, candidate.player);
      handler.resolve(context);
      recordEvent(
        state,
        GAME_EVENTS.PASSIVE_TRIGGERED,
        { playerIndex: candidate.playerIndex, unitId: candidate.unit.uid, passiveId: candidate.unit.passive.id, hookId: candidate.hook.id, sourceEventId: event.id },
        `${candidate.unit.name} 的被动「${candidate.unit.passive.name}」触发。`,
        'success',
      );
      checkWinner(state);
    });
}

export function validateContentCatalog() {
  const errors = [];
  const knownTargets = new Set(['auto', 'ally-unit', 'knocked-ally', 'enemy-unit']);
  const knownEffectTargets = new Set([
    'source',
    'selected-ally',
    'selected-enemy',
    'all-enemy-units',
    'enemy-avatar',
    'ally-player',
    'ally-avatar',
  ]);
  const knownEvents = new Set(Object.values(GAME_EVENTS));
  const knownRarities = new Set(['common', 'rare', 'epic']);
  const knownTimings = new Set(['main', 'response']);
  const knownRealmTriggers = new Set(['owner-turn-start']);
  const cardIds = new Set();
  const passiveIds = new Set();
  UNIT_DEFINITIONS.forEach((unit) => {
    const unitCards = CARD_DEFINITIONS.filter((card) => card.unitId === unit.id);
    const starterCards = getStarterCardIdsForUnit(unit.id);
    if (unitCards.length < GAME_RULES.minCardDefinitionsPerUnit) {
      errors.push(`${unit.name} 的卡池至少需要 ${GAME_RULES.minCardDefinitionsPerUnit} 种卡。`);
    }
    if (starterCards.length !== GAME_RULES.cardsPerUnit) {
      errors.push(`${unit.name} 的起始构筑需要 ${GAME_RULES.cardsPerUnit} 张卡。`);
    }
    if (!unit.passive?.hooks?.length) {
      errors.push(`${unit.name} 缺少被动定义。`);
    }
    errors.push(...validateUnitKeywordConfiguration(unit));
    if (passiveIds.has(unit.passive?.id)) errors.push(`${unit.name} 使用了重复的被动 ID。`);
    if (unit.passive?.id) passiveIds.add(unit.passive.id);
    unit.passive?.hooks?.forEach((hook) => {
      if (!knownEvents.has(hook.event)) errors.push(`${unit.name} 的被动使用了未知事件 ${hook.event}。`);
      if (!PASSIVE_HANDLERS.has(hook.effect)) errors.push(`${unit.name} 的被动使用了未注册效果 ${hook.effect}。`);
    });
  });
  CARD_DEFINITIONS.forEach((card) => {
    if (cardIds.has(card.id)) errors.push(`卡牌 ID ${card.id} 重复。`);
    cardIds.add(card.id);
    if (!getUnitDefinition(card.unitId)) errors.push(`${card.name} 引用了未知角色 ${card.unitId}。`);
    if (!knownTargets.has(card.target)) errors.push(`${card.name} 使用了未知目标类型 ${card.target}。`);
    if (!EFFECT_HANDLERS.has(card.effect)) errors.push(`${card.name} 使用了未注册效果 ${card.effect}。`);
    if (!Array.isArray(card.effects) || card.effects.length === 0) {
      errors.push(`${card.name} 缺少数据化效果步骤。`);
    } else {
      card.effects.forEach((effect, effectIndex) => {
        const effectLabel = `${card.name} 的第 ${effectIndex + 1} 个效果`;
        if (!EFFECT_CONDITION_HANDLERS.has(effect.condition)) errors.push(`${effectLabel}使用了未知条件 ${effect.condition}。`);
        if (!EFFECT_HANDLERS.has(effect.action)) errors.push(`${effectLabel}使用了未注册动作 ${effect.action}。`);
        if (!knownEffectTargets.has(effect.target)) errors.push(`${effectLabel}使用了未知目标 ${effect.target}。`);
      });
    }
    if (!knownRarities.has(card.rarity)) errors.push(`${card.name} 使用了未知稀有度 ${card.rarity}。`);
    if (!knownTimings.has(card.timing)) errors.push(`${card.name} 使用了未知出牌时机 ${card.timing}。`);
    if (!Array.isArray(card.responseTo)) errors.push(`${card.name} 的响应条件必须是数组。`);
    card.responseTo.forEach((action) => {
      if (!EFFECT_HANDLERS.has(action)) errors.push(`${card.name} 响应了未知动作 ${action}。`);
    });
    if (!Array.isArray(card.tags)) errors.push(`${card.name} 的战术标签必须是数组。`);
    if (card.type === 'realm') {
      if (!Number.isInteger(card.realm?.hp) || card.realm.hp <= 0) errors.push(`${card.name} 的幻境耐久无效。`);
      if (!knownRealmTriggers.has(card.realm?.trigger)) errors.push(`${card.name} 使用了未知幻境触发时机 ${card.realm?.trigger}。`);
      if (!REALM_TRIGGER_HANDLERS.has(card.realm?.triggerEffect)) errors.push(`${card.name} 使用了未注册幻境效果 ${card.realm?.triggerEffect}。`);
      if (!Number.isFinite(card.realm?.triggerValue) || card.realm.triggerValue < 0) errors.push(`${card.name} 的幻境触发数值无效。`);
    }
    if (card.timing === 'response' && !card.keywords.includes(CARD_KEYWORDS.RESPONSE)) {
      errors.push(`${card.name} 的响应牌必须声明响应关键词。`);
    }
    if (card.effects.some((effect) => effect.action === 'freeze') && !card.keywords.includes(CARD_KEYWORDS.STUN)) {
      errors.push(`${card.name} 的眩晕效果必须声明眩晕关键词。`);
    }
    errors.push(...validateCardKeywordConfiguration(card, getUnitDefinition(card.unitId)));
    if (card.copies > GAME_RULES.copiesPerCard) errors.push(`${card.name} 的同名上限超出规则。`);
    if (card.starterCopies < 0 || card.starterCopies > card.copies) errors.push(`${card.name} 的起始牌组数量不合法。`);
    if (card.cost < 0 || card.cost > GAME_RULES.maxEnergy) errors.push(`${card.name} 的鬼火消耗不合法。`);
  });
  return { valid: errors.length === 0, errors };
}

const contentValidation = validateContentCatalog();
if (!contentValidation.valid) throw new Error(contentValidation.errors.join(' '));

export function playCard(state, playerIndex, instanceId, targetId = null) {
  const playability = getCardPlayability(state, playerIndex, instanceId);
  if (!playability.playable) return { state, error: playability.reason };
  if (isUpgradePending(state, playerIndex)) return { state, error: '升级阶段：请先选择一名角色提升勾玉。' };

  const next = clone(state);
  return commitCardPlayInPlace(next, playerIndex, instanceId, targetId);
}

function commitCardPlayInPlace(next, playerIndex, instanceId, targetId = null, options = {}) {
  const isResponse = next.responseWindow !== null;
  const responseContext = isResponse ? clone(next.responseWindow) : null;
  const player = next.players[playerIndex];
  const handIndex = player.hand.findIndex((item) => item.instanceId === instanceId);
  const instance = player.hand[handIndex];
  const card = getCardDefinition(instance.definitionId);
  const effectiveCost = options.free ? 0 : effectiveCardCostForDefinition(next, playerIndex, card);

  const validTargets = getValidTargets(next, playerIndex, card.id);
  const isCombatTarget = card.effect === 'assault' && targetId !== null && getValidCombatTargets(next, playerIndex).includes(targetId);
  if ((card.target !== 'auto' && !validTargets.includes(targetId)) || (card.target === 'auto' && targetId !== null && !isCombatTarget)) {
    return { state: next, error: '请选择一个有效目标。' };
  }

  player.energy -= effectiveCost;
  applyCardPlayedKeywordHooks({
    state: next,
    playerIndex,
    player,
    card,
    effectiveCost,
    automatic: options.automatic === true,
  });
  player.hand.splice(handIndex, 1);
  player.cardsPlayed += 1;
  player.cardsPlayedThisTurn = (player.cardsPlayedThisTurn ?? 0) + 1;
  if (options.automatic) {
    recordEvent(
      next,
      GAME_EVENTS.INCARNATION_TRIGGERED,
      { playerIndex, instanceId, definitionId: card.id },
      `${card.name} 以化身自动显现。`,
      'success',
    );
  }
  createCardResolutionFrames(
    next,
    playerIndex,
    instanceId,
    card,
    targetId,
    {
      respondable: options.respondable ?? (!isResponse || responseContext.depth + 1 < GAME_RULES.maxResponseDepth),
      responseDepth: isResponse ? responseContext.depth + 1 : 0,
    },
  );
  if (isResponse) {
    const previousFrame = next.resolutionStack
      .slice(0, -2)
      .findLast((frame) => frame.kind === 'card-effect' && frame.resolutionId === responseContext.resolutionId);
    if (previousFrame) previousFrame.responseOffered = false;
    next.responseWindow = null;
  }
  resolveResolutionStack(next);
  return { state: next, error: null, pending: next.responseWindow !== null };
}

function triggerAutomaticKeywordCards(state, playerIndex) {
  const player = state.players[playerIndex];
  const candidates = player.hand
    .map((instance) => {
      const card = getCardDefinition(instance.definitionId);
      const trigger = getAutomaticKeywordCardTrigger({ state, playerIndex, player, card, instance });
      return trigger ? { instance, card, trigger } : null;
    })
    .filter(Boolean)
    .filter(({ instance }) => getCardPlayability(state, playerIndex, instance.instanceId, { skipUpgradeGate: true }).playable)
    .sort((left, right) => (right.trigger.priority - left.trigger.priority)
      || left.instance.instanceId.localeCompare(right.instance.instanceId));
  const selected = candidates[0];
  if (!selected) return;
  commitCardPlayInPlace(state, playerIndex, selected.instance.instanceId, null, {
    automatic: true,
    free: true,
    respondable: false,
  });
}

export function passResponse(state, playerIndex) {
  if (state.pendingChoice) return { state, error: '请先完成当前的占卜选择。' };
  const responseWindow = state.responseWindow;
  if (!responseWindow || responseWindow.playerIndex !== playerIndex) {
    return { state, error: '当前没有可由你处理的响应窗口。' };
  }

  const next = clone(state);
  recordEvent(next, GAME_EVENTS.RESPONSE_PASSED, {
    playerIndex,
    resolutionId: next.responseWindow.resolutionId,
    definitionId: next.responseWindow.definitionId,
    consecutivePasses: next.responseWindow.consecutivePasses + 1,
  });
  if (next.responseWindow.consecutivePasses === 0) {
    next.responseWindow.consecutivePasses = 1;
    next.responseWindow.playerIndex = 1 - playerIndex;
  } else {
    next.responseWindow = null;
    resolveResolutionStack(next);
  }
  return { state: next, error: null, pending: next.responseWindow !== null };
}

export function levelUpUnit(state, playerIndex, unitId) {
  if (state.pendingChoice) return { state, error: '请先完成当前的占卜选择。' };
  if (state.responseWindow) return { state, error: '请先处理当前响应窗口。' };
  if (state.winner !== null || state.currentPlayer !== playerIndex) return { state, error: '现在不是你的升级阶段。' };
  const player = state.players[playerIndex];
  const unitIndex = unitIndexByUid(player, unitId);
  const unit = player.units[unitIndex];
  if (!unit) return { state, error: '没有找到该角色。' };
  // 齐头并进：只能升级处于全队最低勾玉等级的角色
  const minLevel = Math.min(...player.units.map((candidate) => candidate.level));
  if (unit.level > minLevel) {
    return { state, error: '升勾需齐头并进：所有角色达到相同勾玉等级后，才能迈向下一级。' };
  }
  let usesBonus = false;
  if (player.levelUpUsed) {
    if (player.bonusUpgrades > 0) usesBonus = true;
    else return { state, error: '本回合已经提升过一名角色。' };
  }
  if (unit.level >= GAME_RULES.maxUnitLevel) return { state, error: `${unit.name} 已达到最高勾玉等级。` };

  const next = clone(state);
  const nextPlayer = next.players[playerIndex];
  nextPlayer.units[unitIndex].level += 1;
  if (usesBonus) nextPlayer.bonusUpgrades -= 1;
  else nextPlayer.levelUpUsed = true;
  recordEvent(
    next,
    GAME_EVENTS.UNIT_LEVELED,
    { playerIndex, unitIndex, level: nextPlayer.units[unitIndex].level },
    `${nextPlayer.units[unitIndex].name} 提升至 ${nextPlayer.units[unitIndex].level} 勾玉。`,
    'success',
  );
  return { state: next, error: null };
}

export function basicAttack(state, playerIndex, unitId, targetId = null) {
  if (state.pendingChoice) return { state, error: '请先完成当前的占卜选择。' };
  if (state.responseWindow) return { state, error: '请先处理当前响应窗口。' };
  if (state.winner !== null || state.currentPlayer !== playerIndex) return { state, error: '现在不是你的行动阶段。' };
  if (isUpgradePending(state, playerIndex)) return { state, error: '升级阶段：请先选择一名角色提升勾玉。' };
  const player = state.players[playerIndex];
  const unitIndex = unitIndexByUid(player, unitId);
  const unit = player.units[unitIndex];
  if (!unit || unit.hp <= 0) return { state, error: '该角色无法出击。' };
  if (unit.frozen > 0) return { state, error: '该角色正处于眩晕状态。' };
  if (unit.level < 1) return { state, error: `${unit.name} 尚未激活（0 勾），先提升勾玉再出击。` };
  if (player.attackUsed) return { state, error: '本回合已经出击过。' };
  if (player.energy < 1) return { state, error: '鬼火不足。' };
  if (targetId !== null && !getValidCombatTargets(state, playerIndex).includes(targetId)) {
    return { state, error: '请选择一个有效的战斗目标。' };
  }

  const next = clone(state);
  next.players[playerIndex].energy -= 1;
  next.players[playerIndex].attackUsed = true;
  resolveCombat(next, playerIndex, unitIndex, { targetId });
  checkWinner(next);
  return { state: next, error: null };
}

export function endTurn(state, playerIndex) {
  if (state.pendingChoice) return { state, error: '请先完成当前的占卜选择。' };
  if (state.responseWindow) return { state, error: '请先处理当前响应窗口。' };
  if (state.winner !== null || state.currentPlayer !== playerIndex) return { state, error: '当前无法结束回合。' };
  const next = clone(state);
  const outgoing = next.players[playerIndex];
  outgoing.units.forEach((unit) => {
    if (unit.frozen > 0) unit.frozen -= 1;
  });
  next.currentPlayer = 1 - playerIndex;
  next.turnCounter += 1;
  beginTurn(next, next.currentPlayer);
  return { state: next, error: null };
}

export function getRound(state) {
  return Math.ceil(state.turnCounter / 2);
}
