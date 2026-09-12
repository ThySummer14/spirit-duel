import test from 'node:test';
import assert from 'node:assert/strict';

import {
  GAME_EVENTS,
  GAME_RULES,
  CARD_DEFINITIONS,
  UNIT_DEFINITIONS,
  createDefaultDeckDefinition,
  createGame as rawCreateGame,
  deserializeGame,
  endTurn,
  getCardDefinition,
  getCardPlayability,
  passResponse,
  playCard,
  resolveDivinationChoice,
  serializeGame,
  validateContentCatalog,
  validateDeckDefinition,
} from '../game-core.js';
import { deployToFront, putCardInHand } from './front-helper.js';

function createGame(input = undefined) {
  const state = rawCreateGame(input);
  state.players.forEach((player) => {
    player.levelUpUsed = true;
    player.units.forEach((unit) => { if (unit.level < 1) unit.level = 1; });
  });
  return state;
}

/** 走完结算栈：处理占卜选择与响应窗口的交替弃权 */
function settle(state) {
  let current = state;
  for (let guard = 0; guard < 40; guard += 1) {
    if (current.pendingChoice?.type === 'divination') {
      const choice = resolveDivinationChoice(
        current,
        current.pendingChoice.playerIndex,
        current.pendingChoice.instanceIds[0],
      );
      assert.equal(choice.error, null);
      current = choice.state;
      continue;
    }
    if (current.responseWindow) {
      const passed = passResponse(current, current.responseWindow.playerIndex);
      assert.equal(passed.error, null);
      current = passed.state;
      continue;
    }
    break;
  }
  return current;
}

function play(state, playerIndex, definitionId, targetId = null) {
  const instance = putCardInHand(state, playerIndex, definitionId);
  const result = playCard(state, playerIndex, instance.instanceId, targetId);
  assert.equal(result.error, null, `${definitionId} 应可打出`);
  return settle(result.state);
}

function end(state, playerIndex) {
  const result = endTurn(state, playerIndex);
  assert.equal(result.error, null);
  return result.state;
}

// playCard 返回克隆状态：一切断言都必须从最终 state 重新取单位
function unit(state, playerIndex, unitId) {
  const found = state.players[playerIndex].units.find((candidate) => candidate.id === unitId);
  assert.ok(found, `找不到角色 ${unitId}`);
  return found;
}

function setLevel(state, playerIndex, unitId, level) {
  unit(state, playerIndex, unitId).level = level;
}

function hasLog(state, needle) {
  return state.log.some((entry) => entry.text.includes(needle));
}

// ============ 内容契约 ============

test('every unit carries exactly one awakening card and two SSRs, catalog stays valid', () => {
  assert.deepEqual(validateContentCatalog(), { valid: true, errors: [] });
  UNIT_DEFINITIONS.forEach((item) => {
    const cards = CARD_DEFINITIONS.filter((card) => card.unitId === item.id);
    assert.equal(cards.filter((card) => card.type === 'awakening').length, 1, `${item.name} 觉醒牌数量`);
    assert.equal(cards.filter((card) => card.rarity === 'ssr').length, 2, `${item.name} SSR 数量`);
    assert.ok(item.awakenedPassive, `${item.name} 应有觉醒被动`);
    assert.notEqual(item.awakenedPassive.id, item.passive.id);
  });
  assert.equal(CARD_DEFINITIONS.length, 138);
});

test('default decks pick up the awakening card while SSRs stay collectible-only', () => {
  UNIT_DEFINITIONS.forEach((item) => {
    const starter = createDefaultDeckDefinition([item.id]).cardIds;
    assert.equal(starter.length, GAME_RULES.cardsPerUnit);
    const awakening = CARD_DEFINITIONS.find((card) => card.unitId === item.id && card.type === 'awakening');
    assert.equal(starter.filter((id) => id === awakening.id).length, 1, `${item.name} 默认构筑应含 1 张觉醒牌`);
    assert.equal(starter.filter((id) => getCardDefinition(id).rarity === 'ssr').length, 0);
  });
});

test('deck validation enforces per-card deckLimit for awakening cards', () => {
  const extraAwaken = createDefaultDeckDefinition(['ember', 'basalt', 'lumen', 'rime']);
  // 把一张焰闪换成第二张烬燃冲锋（同名觉醒 ×2）
  const idx = extraAwaken.cardIds.indexOf('flash-thrust');
  extraAwaken.cardIds[idx] = 'awaken-ember';
  const result = validateDeckDefinition(extraAwaken);
  assert.equal(result.valid, false);
  assert.ok(result.errors.some((error) => error.includes('烬燃冲锋') && error.includes('最多 1 张')), result.errors.join(';'));
});

// ============ 觉醒机制 ============

test('awakening swaps the passive, grants +1/+1 and cannot be repeated', () => {
  let state = createGame({ seed: 901 });
  setLevel(state, 0, 'ember', 2);
  state = play(state, 0, 'awaken-ember');

  const ember = unit(state, 0, 'ember');
  assert.equal(ember.awakened, true);
  assert.equal(ember.passive.id, 'ember-pursuit-awakened');
  assert.equal(ember.art, 'assets/ember-awakened.svg', '觉醒后头像应替换为觉醒相');
  assert.equal(ember.attack, 4); // 基础 3 + 成长 1
  assert.equal(ember.maxHp, 10); // 基础 9 + 成长 1
  assert.ok(hasLog(state, '烬燃冲锋'));

  const second = putCardInHand(state, 0, 'awaken-ember');
  const playability = getCardPlayability(state, 0, second.instanceId);
  assert.equal(playability.playable, false);
  assert.match(playability.reason, /觉醒/);
});

test('awakened ember burns the enemy core when the enemy lane is empty', () => {
  let state = createGame({ seed: 902 });
  setLevel(state, 0, 'ember', 2);
  state = play(state, 0, 'awaken-ember');
  // 出击：4 攻 +2 加成 = 6 直击核心，觉醒追击再补 2
  state = play(state, 0, 'flash-thrust');
  assert.equal(state.players[1].avatarHp, 30 - 6 - 2);
});

test('form switching preserves awakening growth (attack pipeline fix)', () => {
  let state = createGame({ seed: 903 });
  setLevel(state, 0, 'ember', 2);
  state = play(state, 0, 'awaken-ember'); // +1/+1
  state = play(state, 0, 'ember-form');   // 形态 +1/+2 与成长叠加
  const ember = unit(state, 0, 'ember');
  assert.equal(ember.attack, 3 + 1 + 1);
  assert.equal(ember.maxHp, 9 + 1 + 2);
});

test('awakened state survives serialization; forged passive is rejected', () => {
  let state = createGame({ seed: 904 });
  setLevel(state, 0, 'lumen', 2);
  state = play(state, 0, 'awaken-lumen');

  const restored = deserializeGame(serializeGame(state));
  assert.equal(unit(restored, 0, 'lumen').passive.id, 'lumen-return-awakened');
  assert.equal(unit(restored, 0, 'lumen').awakened, true);

  const forged = JSON.parse(serializeGame(state));
  const target = forged.state.players[0].units.find((candidate) => candidate.id === 'lumen');
  target.passive = JSON.parse(JSON.stringify(UNIT_DEFINITIONS.find((def) => def.id === 'lumen').passive));
  assert.throws(() => deserializeGame(JSON.stringify(forged)), /觉醒状态与角色定义不一致/);

  const forgedArt = JSON.parse(serializeGame(state));
  const artTarget = forgedArt.state.players[0].units.find((candidate) => candidate.id === 'lumen');
  artTarget.art = 'assets/lumen.svg'; // 觉醒态偷回基础头像
  assert.throws(() => deserializeGame(JSON.stringify(forgedArt)), /觉醒头像与角色定义不一致/);
});

test('form card fully heals its source only, not allies or the fallen', () => {
  let state = createGame({ seed: 918 });
  setLevel(state, 0, 'basalt', 2);
  const allyWounded = unit(state, 0, 'ember');
  const selfWounded = unit(state, 0, 'basalt');
  const fallen = unit(state, 0, 'rime');
  allyWounded.hp = 2;
  selfWounded.hp = 1;
  fallen.hp = 0; // 气绝者不回

  state = play(state, 0, 'bastion-form'); // 山门之相：+4 生命上限

  assert.equal(unit(state, 0, 'basalt').hp, unit(state, 0, 'basalt').maxHp, '该角色应回满到新上限');
  assert.equal(unit(state, 0, 'ember').hp, 2, '形态共鸣不应波及其他角色');
  assert.equal(unit(state, 0, 'rime').hp, 0, '形态共鸣不复活气绝角色');
  assert.ok(hasLog(state, '形态共鸣'));
});

test('kongo awakening grants permanent unyielding', () => {
  let state = createGame({ seed: 905, playerUnitIds: ['kongo', 'ember', 'lumen', 'rime'] });
  setLevel(state, 0, 'kongo', 2);
  assert.equal(unit(state, 0, 'kongo').unyielding, false);
  state = play(state, 0, 'awaken-kongo');
  const kongo = unit(state, 0, 'kongo');
  assert.equal(kongo.unyielding, true);
  assert.equal(kongo.passive.id, 'kongo-skin-awakened');
});

test('awakened lumen heals and draws on the first spell of the turn only', () => {
  let state = createGame({ seed: 906 });
  setLevel(state, 0, 'lumen', 2);
  state.players[0].avatarHp = 25;
  // 觉醒牌自身触发月返：回复 2（觉醒牌非法术，不抽牌）
  state = play(state, 0, 'awaken-lumen');
  assert.equal(state.players[0].avatarHp, 27);

  // 本回合月返已达上限：再用法术不触发
  unit(state, 0, 'rime').hp = 5;
  const rimeUid = unit(state, 0, 'rime').uid;
  state = play(state, 0, 'mend', rimeUid);
  assert.equal(state.players[0].avatarHp, 27);
  assert.equal(unit(state, 0, 'rime').hp, 9); // 回复 4 但不超过上限

  // 新回合第一张是法术：回复 2 + 抽 1
  state = end(state, 0);
  state = end(state, 1);
  state.players[0].avatarHp = 24;
  const handBefore = state.players[0].hand.length;
  unit(state, 0, 'rime').hp = 5;
  state = play(state, 0, 'mend', rimeUid);
  assert.equal(state.players[0].avatarHp, 26);
  // 测试牌塞入 +1、打出 -1、月返抽 +1 → 净 +1
  assert.equal(state.players[0].hand.length, handBefore + 1, '打出后应有月返抽牌');
});

// ============ SSR：战斗关键词组合 ============

test('burst dumps all charge into one pierce strike (storm)', () => {
  let state = createGame({ seed: 907, playerUnitIds: ['storm', 'ember', 'lumen', 'rime'] });
  setLevel(state, 0, 'storm', 3);
  const stormUid = unit(state, 0, 'storm').uid;
  state.players[0].keywordUsage.charge = { units: { [stormUid]: { current: 3, max: 3 } } };
  state = play(state, 0, 'ssr-storm-jolt');
  // 3 基础 +1 加成 +3 爆能 = 7 直击空防线核心，追风被动再 +1
  assert.equal(state.players[1].avatarHp, 30 - 7 - 1);
  assert.equal(state.players[0].keywordUsage.charge.units[stormUid].current, 0);
  assert.ok(hasLog(state, '爆能'));
});

test('lone wolf flash returns to reserve with a shield after the kill (frostblade)', () => {
  let state = createGame({ seed: 908, playerUnitIds: ['frostblade', 'ember', 'lumen', 'rime'] });
  setLevel(state, 0, 'frostblade', 3);
  const victim = unit(state, 1, 'storm');
  victim.hp = 1;
  const victimUid = victim.uid;
  deployToFront(state, 1, victimUid);
  const coreBefore = state.players[1].avatarHp;

  state = play(state, 0, 'ssr-frostblade-flash', victimUid);
  assert.equal(state.players[0].frontUnitId, null, '击杀后应撤回准备区');
  assert.ok(unit(state, 1, 'storm').hp <= 0);
  const wolf = unit(state, 0, 'frostblade');
  assert.ok(wolf.shield >= 2, `应有击杀后撤护盾，实际 ${wolf.shield}`);
  assert.ok(coreBefore > state.players[1].avatarHp, '贯通/斩杀应打到核心');
});

test('wrath arhat smashes harder with a shield wall (kongo threshold)', () => {
  let state = createGame({ seed: 909, playerUnitIds: ['kongo', 'ember', 'lumen', 'rime'] });
  setLevel(state, 0, 'kongo', 3);
  const kongoUid = unit(state, 0, 'kongo').uid;
  const victim = unit(state, 1, 'basalt');
  victim.hp = 20; // 抬高生命避免气绝干扰伤害断言
  const victimUid = victim.uid;
  deployToFront(state, 1, victimUid);

  // 无护盾：2 攻 +1 加成 = 3，暴击翻倍 6
  state = play(state, 0, 'ssr-kongo-arhat', victimUid);
  assert.equal(unit(state, 1, 'basalt').hp, 20 - 6);
  assert.equal(state.players[0].frontUnitId, kongoUid);

  // 补 3 护盾后越过门槛：(2+1+2) ×2 = 10（补满鬼火便于连续三张牌）
  unit(state, 1, 'basalt').hp = 20;
  state.players[0].energy = 2;
  state = play(state, 0, 'iron-aegis', kongoUid);
  state.players[0].energy = 2; // 终结牌需要完整的两点鬼火
  state = play(state, 0, 'ssr-kongo-arhat', victimUid);
  assert.equal(unit(state, 1, 'basalt').hp, 20 - 10, '护盾门槛应额外 +2 攻击再翻倍');
});

// ============ SSR：法术与关键词经济 ============

test('absolute zero spends both fires to lock the enemy board', () => {
  let state = createGame({ seed: 910 });
  setLevel(state, 0, 'rime', 3);
  const energiesBefore = state.players[0].energy;
  const hpsBefore = state.players[1].units.map((item) => item.hp);
  state = play(state, 0, 'ssr-rime-zero');

  assert.equal(state.players[0].energy, energiesBefore - 2, '全体控制必须消耗完整行动资源');
  state.players[1].units.forEach((item, index) => {
    assert.ok(item.frozen >= 1, `${item.name} 应被眩晕`);
    assert.equal(item.hp, hpsBefore[index] - 1);
  });
});

test('mountain resonance answers an incoming damage step with a shield wall (basalt)', () => {
  let state = createGame({ seed: 911, enemyUnitIds: ['basalt', 'storm', 'lumen', 'ink'] });
  setLevel(state, 1, 'basalt', 3);
  state.players[1].energy = 2;
  const stormUid = unit(state, 1, 'storm').uid;
  // 响应窗口只在对方手里存在合法响应牌时才会开启：先备牌再触发伤害
  const response = putCardInHand(state, 1, 'ssr-basalt-resonance');
  const spell = putCardInHand(state, 0, 'cinder-mark');
  const pending = playCard(state, 0, spell.instanceId, stormUid).state;
  assert.equal(pending.responseWindow.playerIndex, 1);

  const played = playCard(pending, 1, response.instanceId, null);
  assert.equal(played.error, null);
  const state2 = settle(played.state);

  const basalt = unit(state2, 1, 'basalt');
  assert.equal(basalt.unyielding, true, '响应护盾应附带不屈');
  assert.ok(basalt.shield >= 4, `岚岳应获得 4+ 护盾，实际 ${basalt.shield}`);
  state2.players[1].units
    .filter((item) => ['lumen', 'ink'].includes(item.id))
    .forEach((item) => assert.ok(item.shield >= 2, `${item.name} 应获得 2 点护盾`));
  // 霆鸢吃到的群盾会被后结算的烬印吸收（响应先于原伤害结算），验证其存活血量
  assert.ok(unit(state2, 1, 'storm').hp > 0);
});

test('moonlit aria chains draws with an explicit one-fire cost (lumen)', () => {
  let state = createGame({ seed: 912 });
  setLevel(state, 0, 'lumen', 3);
  // 确保牌库里有弦月牌供连引
  if (!state.players[0].deck.some((card) => getCardDefinition(card.definitionId).unitId === 'lumen')) {
    state.players[0].deck.push({ instanceId: 'seed-lumen-mend', definitionId: 'mend' });
  }
  const energyBefore = state.players[0].energy;
  const handBefore = state.players[0].hand.length;
  state = play(state, 0, 'ssr-lumen-aria');

  assert.equal(state.players[0].energy, energyBefore - 1, '调度牌消耗一点鬼火');
  // 塞入测试牌 +1：打出 -1 + 抽 2 + 连引 1 = 相对 handBefore +3
  assert.equal(state.players[0].hand.length, handBefore + 3);
});

test('verdict brush divines, maims with brittle and recycles via origin (ink)', () => {
  let state = createGame({ seed: 913, playerUnitIds: ['ink', 'ember', 'lumen', 'rime'] });
  setLevel(state, 0, 'ink', 3);
  const victim = unit(state, 1, 'basalt');
  victim.hp = 12;
  const victimUid = victim.uid;

  const instance = putCardInHand(state, 0, 'ssr-ink-verdict');
  const first = playCard(state, 0, instance.instanceId, victimUid);
  assert.equal(first.error, null);
  assert.equal(first.state.pendingChoice?.type === 'divination', true, '应先弹出占卜选择');
  state = settle(first.state);

  const target = unit(state, 1, 'basalt');
  assert.equal(target.hp, 12 - 3);
  assert.equal(target.brittle, 2, '存活目标应进入 2 层晶裂');
  assert.equal(
    state.players[0].deck.filter((card) => card.definitionId === 'ssr-ink-verdict').length,
    1,
    '起源应将一张同名卡洗回牌库',
  );
});

test('immovable fudou-myoo ward shields every ally each turn', () => {
  let state = createGame({ seed: 914 });
  setLevel(state, 0, 'basalt', 3);
  state = play(state, 0, 'ssr-basalt-fudou');
  assert.equal(state.players[0].realms.length, 1);
  assert.equal(state.players[0].realms[0].maxHp, 8);

  state = end(state, 0);
  state = end(state, 1);
  state.players[0].units.forEach((item) => {
    if (item.hp > 0) assert.ok(item.shield >= 1, `${item.name} 应吃到明王阵护盾`);
  });
});

test('boundless inksea explodes with a three-part countdown burst', () => {
  let state = createGame({ seed: 915, playerUnitIds: ['ink', 'ember', 'lumen', 'rime'] });
  setLevel(state, 0, 'ink', 3);
  const storm = unit(state, 1, 'storm');
  deployToFront(state, 1, storm.uid);
  const enemyHpBefore = storm.hp;

  state = play(state, 0, 'ssr-ink-sea');
  const realm = state.players[0].realms.find((candidate) => candidate.cardId === 'ssr-ink-sea');
  assert.ok(realm, '应部署墨海无量幻境');
  assert.equal(realm.countdown, 2);

  // 第一个己方回合开始只推进倒计时
  state = end(state, 0);
  state = end(state, 1);
  assert.equal(unit(state, 1, 'storm').hp, enemyHpBefore, '倒计时未归零不应触发');

  state = end(state, 0);
  state = end(state, 1);
  // 敌方前线角色会在敌方回合开始自动归位，改以事件与战报断言三联爆发
  const triggered = state.events.filter(
    (event) => event.type === GAME_EVENTS.COUNTDOWN_TRIGGERED && event.payload.cardId === 'ssr-ink-sea',
  );
  assert.equal(triggered.length, 1, '倒计时应恰好归零触发一次');
  assert.ok(hasLog(state, '翻开一页'), '应触发抽牌子效果');
});

test('benevolent king trades a full turn for team protection (kongo)', () => {
  let state = createGame({ seed: 916, playerUnitIds: ['kongo', 'ember', 'lumen', 'rime'] });
  setLevel(state, 0, 'kongo', 3);
  const energyBefore = state.players[0].energy;
  state = play(state, 0, 'ssr-kongo-nioh');

  assert.equal(state.players[0].energy, energyBefore - 2, '全队保护消耗两点鬼火');
  state.players[0].units.forEach((item) => {
    if (item.hp > 0) assert.equal(item.unyielding, true, `${item.name} 应获得不屈`);
  });
  assert.ok(unit(state, 0, 'kongo').shield >= 4);
});

// ============ 觉醒被动：充能闭环（P5） ============

test('awakened storm banks charge from every combat (gale fury)', () => {
  let state = createGame({ seed: 917, playerUnitIds: ['storm', 'ember', 'lumen', 'rime'] });
  setLevel(state, 0, 'storm', 2);
  state = play(state, 0, 'awaken-storm');
  const storm = unit(state, 0, 'storm');
  assert.equal(storm.passive.id, 'storm-tailwind-awakened');
  const before = state.players[0].keywordUsage.charge.units[storm.uid].current;

  // 一次普通出击交战后应 +1 充能（不超过上限）
  state = play(state, 0, 'thunder-step');
  const after = state.players[0].keywordUsage.charge.units[storm.uid].current;
  assert.equal(after, Math.min(3, before + 1));
});

test('form hooks amplify identity, survive save/load, and stop after switching', () => {
  let state = createGame({ seed: 931 });
  setLevel(state, 0, 'ember', 3);
  state = play(state, 0, 'ember-form');
  state = deserializeGame(serializeGame(state));
  const victim = unit(state, 1, 'basalt');
  deployToFront(state, 1, victim.uid);
  const hp = victim.hp;
  state = play(state, 0, 'flash-thrust', victim.uid);
  assert.equal(unit(state, 1, 'basalt').hp, hp - 8, '基础入阵1 + 形态1 + 本次攻击6');
  assert.ok(hasLog(state, '形态「赤炼之躯」'));
  state.players[0].energy = 2;
  state = play(state, 0, 'sunsteel-form');
  assert.equal(unit(state, 0, 'ember').form.cardId, 'sunsteel-form');
  assert.equal(unit(state, 0, 'ember').attack, 5, '替换形态而非累加旧形态攻击');
});

test('switching out of wolf king removes its shield amplifier', () => {
  let state = createGame({ seed: 932, playerUnitIds: ['frostblade', 'ember', 'lumen', 'rime'] });
  setLevel(state, 0, 'frostblade', 3);
  state = play(state, 0, 'ssr-frostblade-king');
  assert.equal(unit(state, 0, 'frostblade').passiveAmp.aegisBonus, 1);
  state.players[0].energy = 2;
  state = play(state, 0, 'moon-fang-form');
  assert.equal(unit(state, 0, 'frostblade').passiveAmp, null);
  state = play(state, 0, 'frost-bite');
  assert.equal(unit(state, 0, 'frostblade').shield, 2, '刃胄1 + 当前月牙形态1，不残留苍狼王增幅');
});

test('shattered mirror removes armor and rewards a surviving frozen target', () => {
  for (const frozen of [0, 1]) {
    let state = createGame({ seed: 933 });
    setLevel(state, 0, 'rime', 3);
    const victim = unit(state, 1, 'basalt');
    victim.shield = 8; victim.frozen = frozen;
    state = play(state, 0, 'ssr-rime-slash', victim.uid);
    assert.equal(unit(state, 1, 'basalt').shield, 0);
    assert.equal(unit(state, 1, 'basalt').hp, 12 - (frozen ? 6 : 3));
    assert.equal(state.players[0].energy, 0);
    assert.ok(hasLog(state, '被碎甲'));
  }
});

test('spell form triggers once per owner turn and ignores another character spells', () => {
  let state = createGame({ seed: 934 });
  setLevel(state, 0, 'rime', 3);
  state = play(state, 0, 'winter-form');
  state.players[0].energy = 2;
  state = play(state, 0, 'hush', unit(state, 1, 'basalt').uid);
  assert.equal(unit(state, 0, 'rime').shield, 2);
  state = play(state, 0, 'hush', unit(state, 1, 'basalt').uid);
  assert.equal(unit(state, 0, 'rime').shield, 2);
  state.players[0].energy = 2;
  state = play(state, 0, 'mend', unit(state, 0, 'lumen').uid);
  assert.equal(unit(state, 0, 'rime').shield, 2);
  state = end(state, 0); state = end(state, 1);
  state.players[0].levelUpUsed = true;
  state = play(state, 0, 'hush', unit(state, 1, 'basalt').uid);
  assert.equal(unit(state, 0, 'rime').shield, 4);
});

test('SSR definitions allow a pair while awakenings stay unique', () => {
  for (const card of CARD_DEFINITIONS.filter((card) => card.rarity === 'ssr')) assert.equal(card.deckLimit, 2);
  const deck = createDefaultDeckDefinition(['ember', 'basalt', 'lumen', 'rime']);
  let replaced = 0;
  deck.cardIds = deck.cardIds.map((id) => getCardDefinition(id).unitId === 'ember' && replaced++ < 2 ? 'ssr-ember-blaze' : id);
  assert.equal(validateDeckDefinition(deck).valid, true);
});
