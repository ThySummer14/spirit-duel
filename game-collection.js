/**
 * game-collection.js — 秘闻阁收藏与御札经济
 *
 * 纯数据模块：不碰 DOM、不用 Math.random 以外的引擎状态。
 * - 初始收藏：所有默认构筑用牌（starterCopies > 0）直接拥有 2 张
 * - 秘闻卷：每包 5 张，常见 60% / 稀有 34.5% / 史诗 5.5%，25 包保底史诗
 * - 重复卡自动折算御札；御札可合成任意未满 2 张的卡
 * - 对局胜利 / 失败发放御札奖励
 * - 偏好由 app.js 负责持久化到 localStorage
 */

import { CARD_DEFINITIONS } from './game-content.js?v=97af4cd1';

export const COLLECTION_RULES = Object.freeze({
  version: 1,
  packSize: 5,
  packCost: 100,
  startingBalance: 300,
  // 与《百闻牌》秘闻卷一致的稀有度分布
  rarityWeights: Object.freeze({ common: 0.6, rare: 0.345, epic: 0.055 }),
  pityLimit: 25,
  maxCopies: 2,
  winReward: 50,
  lossReward: 20,
  dupeValue: Object.freeze({ common: 5, rare: 25, epic: 100 }),
  craftCost: Object.freeze({ common: 40, rare: 200, epic: 600 }),
});

export const INGREDIENT_LABELS = Object.freeze({ fish: '鲜鱼', rice: '稻米', herb: '霜菜' });
export const RARITY_LABELS = Object.freeze({ common: '常见', rare: '稀有', epic: '史诗' });

const CARDS_BY_RARITY = Object.freeze({
  common: Object.freeze(CARD_DEFINITIONS.filter((card) => card.rarity === 'common').map((card) => card.id)),
  rare: Object.freeze(CARD_DEFINITIONS.filter((card) => card.rarity === 'rare').map((card) => card.id)),
  epic: Object.freeze(CARD_DEFINITIONS.filter((card) => card.rarity === 'epic').map((card) => card.id)),
});

export function createInitialCollection() {
  const owned = {};
  CARD_DEFINITIONS.forEach((card) => {
    if (card.starterCopies > 0) owned[card.id] = COLLECTION_RULES.maxCopies;
  });
  return {
    version: COLLECTION_RULES.version,
    balance: COLLECTION_RULES.startingBalance,
    owned,
    packsOpened: 0,
    pitySinceEpic: 0,
    wins: 0,
    losses: 0,
  };
}

export function ownedCopies(collection, cardId) {
  return collection?.owned?.[cardId] ?? 0;
}

export function collectionStats(collection) {
  const ownedEntries = Object.entries(collection?.owned ?? {}).filter(([, copies]) => copies > 0);
  const totalCopies = ownedEntries.reduce((total, [, copies]) => total + copies, 0);
  return {
    distinctOwned: ownedEntries.length,
    totalCards: CARD_DEFINITIONS.length,
    totalCopies,
    maxCopies: CARD_DEFINITIONS.length * COLLECTION_RULES.maxCopies,
  };
}

function rollRarity(pityDue, rng) {
  if (pityDue) return 'epic';
  const roll = rng();
  const { common, rare } = COLLECTION_RULES.rarityWeights;
  if (roll < common) return 'common';
  if (roll < common + rare) return 'rare';
  return 'epic';
}

/**
 * 打开一包秘闻卷（纯函数，返回新收藏与开包结果）。
 * rng 需返回 [0, 1) 随机数；传入以便测试注入确定性序列。
 */
export function openPack(collection, rng = Math.random) {
  if (collection.balance < COLLECTION_RULES.packCost) {
    return { collection, error: `御札不足：开启一包需要 ${COLLECTION_RULES.packCost} 御札。` };
  }
  const next = structuredClone(collection);
  next.balance -= COLLECTION_RULES.packCost;
  next.packsOpened += 1;
  const results = [];
  for (let index = 0; index < COLLECTION_RULES.packSize; index += 1) {
    const pityDue = next.pitySinceEpic + 1 >= COLLECTION_RULES.pityLimit;
    const rarity = rollRarity(pityDue, rng);
    const pool = CARDS_BY_RARITY[rarity];
    const cardId = pool[Math.floor(rng() * pool.length)];
    const copiesBefore = ownedCopies(next, cardId);
    let entry;
    if (copiesBefore < COLLECTION_RULES.maxCopies) {
      next.owned[cardId] = copiesBefore + 1;
      entry = { cardId, rarity, isNew: copiesBefore === 0, copies: copiesBefore + 1, converted: 0 };
    } else {
      const refund = COLLECTION_RULES.dupeValue[rarity];
      next.balance += refund;
      entry = { cardId, rarity, isNew: false, copies: copiesBefore, converted: refund };
    }
    results.push(entry);
  }
  const hitEpic = results.some((entry) => entry.rarity === 'epic');
  next.pitySinceEpic = hitEpic ? 0 : next.pitySinceEpic + 1;
  return { collection: next, results, error: null };
}

/** 御札合成：将一张卡补至已持有数量 + 1（不超过同名上限） */
export function craftCard(collection, cardId) {
  const card = CARD_DEFINITIONS.find((definition) => definition.id === cardId);
  if (!card) return { collection, error: `未知卡牌：${cardId}。` };
  const copies = ownedCopies(collection, cardId);
  if (copies >= COLLECTION_RULES.maxCopies) {
    return { collection, error: `「${card.name}」已达 ${COLLECTION_RULES.maxCopies} 张上限。` };
  }
  const cost = COLLECTION_RULES.craftCost[card.rarity];
  if (collection.balance < cost) {
    return { collection, error: `御札不足：合成「${card.name}」需要 ${cost} 御札。` };
  }
  const next = structuredClone(collection);
  next.balance -= cost;
  next.owned[cardId] = copies + 1;
  return { collection: next, error: null };
}

/** 对局结算奖励：胜 50 / 败 20 御札 */
export function grantMatchReward(collection, won) {
  const next = structuredClone(collection);
  const reward = won ? COLLECTION_RULES.winReward : COLLECTION_RULES.lossReward;
  next.balance += reward;
  if (won) next.wins += 1;
  else next.losses += 1;
  return { collection: next, reward };
}

export function serializeCollection(collection) {
  return JSON.stringify(collection);
}

export function deserializeCollection(json) {
  const parsed = JSON.parse(json);
  if (parsed?.version !== COLLECTION_RULES.version
    || typeof parsed.balance !== 'number'
    || typeof parsed.owned !== 'object'
    || parsed.owned === null
    || Array.isArray(parsed.owned)) {
    throw new Error('收藏数据版本或结构无效。');
  }
  // 只保留已知卡牌 id，防止内容版本变化后出现幽灵卡
  const owned = {};
  Object.entries(parsed.owned).forEach(([cardId, copies]) => {
    if (CARD_DEFINITIONS.some((card) => card.id === cardId) && Number.isInteger(copies)) {
      owned[cardId] = Math.max(0, Math.min(COLLECTION_RULES.maxCopies, copies));
    }
  });
  return {
    version: COLLECTION_RULES.version,
    balance: Math.max(0, parsed.balance),
    owned,
    packsOpened: parsed.packsOpened ?? 0,
    pitySinceEpic: Math.min(parsed.pitySinceEpic ?? 0, COLLECTION_RULES.pityLimit),
    wins: parsed.wins ?? 0,
    losses: parsed.losses ?? 0,
  };
}
