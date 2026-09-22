import test from 'node:test';
import assert from 'node:assert/strict';

import {
  COLLECTION_RULES,
  collectionStats,
  craftCard,
  createInitialCollection,
  deserializeCollection,
  grantMatchReward,
  openPack,
  ownedCopies,
  ownedHoloCopies,
  serializeCollection,
} from '../game-collection.js';
import { CARD_DEFINITIONS } from '../game-content.js';

/** 队列式确定性 rng：按序吐出预置值，供开包测试注入 */
function queuedRng(values) {
  let index = 0;
  return () => values[index++ % values.length];
}

/** 生成一包的 rng 序列：每张卡依次掷稀有度、挑卡和闪卡；区间对齐 v3 权重 */
function packSequence(rarities, pickValue = 0.5, holoIndexes = []) {
  const rarityValue = { common: 0.1, rare: 0.7, epic: 0.95, ssr: 0.99 };
  return rarities.flatMap((rarity, index) => [
    rarityValue[rarity],
    pickValue,
    holoIndexes.includes(index) ? COLLECTION_RULES.holoChance / 2 : 0.99,
  ]);
}

test('initial collection owns starter copies (deckLimit-capped for awakening cards) and nothing else', () => {
  const collection = createInitialCollection();
  const starters = CARD_DEFINITIONS.filter((card) => card.starterCopies > 0);
  const expansion = CARD_DEFINITIONS.filter((card) => card.starterCopies === 0);
  starters.forEach((card) => assert.equal(
    ownedCopies(collection, card.id),
    Math.min(COLLECTION_RULES.maxCopies, card.deckLimit ?? COLLECTION_RULES.maxCopies),
    `${card.name} 的初始发放份数应受牌组同名上限约束`,
  ));
  expansion.forEach((card) => assert.equal(ownedCopies(collection, card.id), 0));
  // 觉醒牌限带 1 份；SSR 全部属于扩展池
  assert.equal(ownedCopies(collection, 'awaken-ember'), 1);
  assert.equal(ownedCopies(collection, 'ssr-ember-meteorfall'), 0);
  assert.equal(collection.balance, COLLECTION_RULES.startingBalance);
  assert.equal(collection.version, COLLECTION_RULES.version);
  assert.equal(collectionStats(collection).holoCopies, 0);
  const stats = collectionStats(collection);
  assert.equal(stats.distinctOwned, starters.length);
  assert.equal(stats.totalCards, CARD_DEFINITIONS.length);
});

test('holo pulls are independent from rarity and persist as owned variants', () => {
  const collection = createInitialCollection();
  collection.balance = 100000;
  const rarities = ['common', 'rare', 'epic', 'common', 'rare'];
  const outcome = openPack(collection, queuedRng(packSequence(rarities, 0.37, [0, 2])));

  assert.deepEqual(outcome.results.map((entry) => entry.isHolo), [true, false, true, false, false]);
  const holoEntries = outcome.results.filter((entry) => entry.isHolo);
  holoEntries.forEach((entry) => assert.ok(ownedHoloCopies(outcome.collection, entry.cardId) > 0));
  assert.ok(collectionStats(outcome.collection).holoCopies >= 2);
});

test('opening a pack costs balance, returns five cards, and resets pity on epic', () => {
  const collection = createInitialCollection();
  const rarities = ['common', 'common', 'rare', 'common', 'epic'];
  const { collection: next, results, error } = openPack(collection, queuedRng(packSequence(rarities)));
  assert.equal(error, null);
  assert.equal(results.length, COLLECTION_RULES.packSize);
  assert.deepEqual(results.map((entry) => entry.rarity), rarities);
  // 同一包内选到重复卡会折算御札，余额按实际折算结算
  const refunds = results.reduce((total, entry) => total + entry.converted, 0);
  assert.equal(next.balance, COLLECTION_RULES.startingBalance - COLLECTION_RULES.packCost + refunds);
  assert.equal(next.packsOpened, 1);
  assert.equal(next.pitySinceEpic, 0, '开出史诗后保底计数归零');
  results.forEach((entry) => assert.ok(CARD_DEFINITIONS.some((card) => card.id === entry.cardId)));
});

test('duplicate cards convert into currency and never exceed the cap', () => {
  let collection = createInitialCollection();
  collection.balance = 100000;
  // 动态计算 pick 值，锁定池中指定的扩展史诗「长夜将尽」
  const epicPool = CARD_DEFINITIONS.filter((card) => card.rarity === 'epic');
  const targetIndex = epicPool.findIndex((card) => card.id === 'longest-night');
  const pickValue = (targetIndex + 0.5) / epicPool.length;
  // 5 连史诗全部命中同一张新卡
  const rng = queuedRng(packSequence(['epic', 'epic', 'epic', 'epic', 'epic'], pickValue));
  const first = openPack(collection, rng);
  assert.equal(first.error, null);
  const target = first.results[0].cardId;
  assert.equal(target, 'longest-night');
  // 同包内第 1、2 张入册，第 3-5 张全部折算
  assert.equal(ownedCopies(first.collection, target), 2);
  const samePackDupes = first.results.filter((entry) => entry.converted > 0);
  assert.equal(samePackDupes.length, 3);
  assert.equal(samePackDupes[0].converted, COLLECTION_RULES.dupeValue.epic);

  const second = openPack(first.collection, rng);
  assert.equal(ownedCopies(second.collection, target), 2, '重复卡不超出 2 张上限');
  assert.ok(second.results.every((entry) => entry.converted === COLLECTION_RULES.dupeValue.epic));
});

test('pity forces an epic at the 25th pack since the last epic', () => {
  let collection = createInitialCollection();
  collection.balance = 100000;
  const neverEpic = queuedRng(packSequence(['common', 'common', 'common', 'common', 'common']));
  for (let packIndex = 0; packIndex < COLLECTION_RULES.pityLimit - 1; packIndex += 1) {
    collection = openPack(collection, neverEpic).collection;
    assert.equal(collection.pitySinceEpic, packIndex + 1);
  }
  const forced = openPack(collection, neverEpic);
  assert.equal(forced.error, null);
  assert.ok(forced.results.some((entry) => entry.rarity === 'epic'), '第 25 包必出史诗');
  assert.equal(forced.collection.pitySinceEpic, 0);
});

test('insufficient balance refuses to open a pack', () => {
  const collection = createInitialCollection();
  collection.balance = COLLECTION_RULES.packCost - 1;
  const outcome = openPack(collection);
  assert.equal(outcome.error, '御札不足：开启一包需要 100 御札。');
  assert.equal(outcome.collection, collection, '失败时原样返回');
});

test('crafting charges rarity cost and stops at the copy cap', () => {
  const collection = createInitialCollection();
  collection.balance = 1000;
  const target = CARD_DEFINITIONS.find((card) => card.starterCopies === 0 && card.rarity === 'rare');

  const crafted = craftCard(collection, target.id);
  assert.equal(crafted.error, null);
  assert.equal(crafted.collection.balance, 1000 - COLLECTION_RULES.craftCost.rare);
  assert.equal(ownedCopies(crafted.collection, target.id), 1);

  const capped = craftCard(crafted.collection, target.id);
  assert.equal(capped.error, null);
  assert.equal(ownedCopies(capped.collection, target.id), 2);

  const refused = craftCard(capped.collection, target.id);
  assert.match(refused.error, /上限/);

  const broke = createInitialCollection();
  broke.balance = 0;
  const cheap = craftCard(broke, target.id);
  assert.match(cheap.error, /御札不足/);
});

test('match rewards track wins and losses', () => {
  const collection = createInitialCollection();
  const won = grantMatchReward(collection, true);
  assert.equal(won.reward, COLLECTION_RULES.winReward);
  assert.equal(won.collection.wins, 1);
  const lost = grantMatchReward(won.collection, false);
  assert.equal(lost.reward, COLLECTION_RULES.lossReward);
  assert.equal(lost.collection.losses, 1);
  assert.equal(lost.collection.wins, 1);
});

test('collection survives a serialization round trip and drops ghost cards', () => {
  const collection = createInitialCollection();
  const withGhost = structuredClone(collection);
  withGhost.owned['ghost-card'] = 2;
  withGhost.owned['undying-ember'] = 9;
  withGhost.holoOwned['ghost-card'] = 2;
  withGhost.holoOwned['undying-ember'] = 9;
  const restored = deserializeCollection(JSON.stringify(withGhost));
  assert.equal(restored.owned['ghost-card'], undefined);
  assert.equal(restored.owned['undying-ember'], COLLECTION_RULES.maxCopies);
  assert.equal(restored.holoOwned['ghost-card'], undefined);
  assert.equal(restored.holoOwned['undying-ember'], COLLECTION_RULES.maxCopies);
  assert.equal(restored.owned['flash-thrust'], 2);
  assert.throws(() => deserializeCollection('{"version":99}'), /无效/);
  assert.equal(typeof serializeCollection(collection), 'string');
});

test('version 1 collections migrate without losing progress', () => {
  const legacy = createInitialCollection();
  legacy.version = 1;
  delete legacy.holoOwned;
  legacy.balance = 777;
  const restored = deserializeCollection(JSON.stringify(legacy));

  assert.equal(restored.version, COLLECTION_RULES.version);
  assert.equal(restored.balance, 777);
  assert.deepEqual(restored.holoOwned, {});
  assert.equal(restored.owned['flash-thrust'], 2);
});

test('trial availability never grants ownership and respects individual limits', async () => {
  const { availableDeckCopies, validateCollectionDeck } = await import('../game-collection.js');
  const collection = createInitialCollection();
  const before = structuredClone(collection);
  const ssr = CARD_DEFINITIONS.find(card => card.rarity === 'ssr' && !ownedCopies(collection, card.id));
  const awakening = CARD_DEFINITIONS.find(card => card.deckLimit === 1);
  assert.equal(availableDeckCopies(collection, ssr.id), 0);
  assert.equal(availableDeckCopies(collection, ssr.id, true), 2);
  assert.equal(validateCollectionDeck(collection, { cardIds: [ssr.id, ssr.id] }, true).valid, true);
  assert.equal(validateCollectionDeck(collection, { cardIds: [ssr.id] }).valid, false);
  assert.equal(validateCollectionDeck(collection, { cardIds: [awakening.id, awakening.id] }, true).valid, false);
  assert.equal(validateCollectionDeck(collection, { cardIds: ['unknown-card'] }, true).valid, false);
  assert.deepEqual(collection, before);
});

test('testing rewards grant three packs per win and one and a half per loss without unlocking cards', () => {
  const original = createInitialCollection();
  const win = grantMatchReward(original, true);
  const loss = grantMatchReward(win.collection, false);
  assert.equal(win.reward, 300);
  assert.equal(loss.reward, 150);
  assert.equal(loss.collection.balance, original.balance + 450);
  assert.deepEqual(loss.collection.owned, original.owned);
  assert.equal(original.wins, 0);
});
