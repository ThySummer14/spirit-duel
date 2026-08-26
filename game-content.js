import { CARD_KEYWORDS } from './game-keywords.js?v=0e568c45';

export const GAME_RULES = Object.freeze({
  lineupSize: 4,
  cardsPerUnit: 8,
  copiesPerCard: 2,
  minCardDefinitionsPerUnit: 12,
  startingAvatarHp: 30,
  maxEnergy: 2,
  openingHandSize: 5,
  mulliganCount: 2,
  maxHandSize: 12,
  mulliganCount: 2,
  knockoutCountdown: 2,
  maxUnitLevel: 3,
  bonusUpgradeTurn: 7, // 先手玩家在该回合获得一次额外升勾机会
  maxResponseDepth: 8,
});

export const DEFAULT_PLAYER_LINEUP = Object.freeze(['ember', 'basalt', 'lumen', 'rime']);
export const DEFAULT_ENEMY_LINEUP = Object.freeze(['storm', 'basalt', 'lumen', 'ink']);

export function getAllUnitIds() {
  return UNIT_DEFINITIONS.map((unit) => unit.id);
}

/** 随机挑选 4 名互不重复的角色（用于失序体随机编成） */
export function createRandomLineup(random = Math.random) {
  const pool = [...getAllUnitIds()];
  const picked = [];
  while (picked.length < 4 && pool.length) {
    picked.push(...pool.splice(Math.floor(random() * pool.length), 1));
  }
  return picked;
}

function passive(id, name, text, hooks) {
  return Object.freeze({
    id,
    name,
    text,
    hooks: Object.freeze(hooks.map((hook) => Object.freeze({ priority: 50, ...hook }))),
  });
}

export const UNIT_DEFINITIONS = Object.freeze([
  {
    id: 'ember',
    name: '赤曜',
    title: '焰锋',
    role: '爆发 / 突击',
    strategy: '以战斗牌快速换入前线，持续压低对方生命。',
    maxHp: 9,
    attack: 3,
    art: 'assets/ember.svg',
    color: '#e75b32',
    passive: passive('ember-pursuit', '余烬追击', '赤曜进入前线时，对敌方前线造成 1 点伤害。', [
      { id: 'front-burn', event: 'unit-entered-front', effect: 'passive-damage-enemy-front', params: { amount: 1 } },
    ]),
  },
  {
    id: 'basalt',
    name: '岚岳',
    title: '垒卫',
    role: '护阵 / 站场',
    strategy: '用护盾和高生命稳固战斗区，为后排争取时间。',
    maxHp: 12,
    attack: 1,
    art: 'assets/basalt.svg',
    color: '#a98b54',
    passive: passive('basalt-wall', '岩壁', '己方回合开始时，若岚岳位于前线，获得 1 点护盾。', [
      { id: 'turn-shield', event: 'turn-started', effect: 'passive-shield-self-if-front', params: { amount: 1 } },
    ]),
  },
  {
    id: 'lumen',
    name: '弦月',
    title: '织光',
    role: '恢复 / 调度',
    strategy: '恢复单位与核心生命，并用抽牌维持手牌质量。',
    maxHp: 8,
    attack: 2,
    art: 'assets/lumen.svg',
    color: '#d8bd42',
    passive: passive('lumen-return', '月返', '每个己方回合第一次使用弦月牌后，己方核心恢复 1 点生命。', [
      { id: 'card-heal-core', event: 'card-played', effect: 'passive-heal-avatar-on-own-card', params: { amount: 1 }, limit: { scope: 'owner-turn', max: 1 } },
    ]),
  },
  {
    id: 'rime',
    name: '白棱',
    title: '霜刃',
    role: '控制 / 破防',
    strategy: '以眩晕限制出击，用晶裂放大后续伤害。',
    maxHp: 9,
    attack: 2,
    art: 'assets/rime.svg',
    color: '#5d8797',
    passive: passive('rime-trace', '霜痕', '白棱完成一次与敌方角色的交战后，眩晕该角色。', [
      { id: 'combat-freeze', event: 'combat-resolved', effect: 'passive-freeze-combat-defender', params: { turns: 1 } },
    ]),
  },
  {
    id: 'storm',
    name: '霆鸢',
    title: '鸣羽',
    role: '连击 / 压制',
    strategy: '用高攻与频繁换位抢占战斗区，擅长快速收束交战。',
    maxHp: 8,
    attack: 3,
    art: 'assets/storm.svg',
    color: '#1599b5',
    keywords: Object.freeze([CARD_KEYWORDS.CHARGE]),
    keywordConfig: Object.freeze({
      [CARD_KEYWORDS.CHARGE]: Object.freeze({ max: 3, gainPerTurn: 1 }),
    }),
    passive: passive('storm-tailwind', '追风', '霆鸢从后场换入前线完成交战后，对敌方核心造成 1 点伤害。', [
      { id: 'reserve-strike', event: 'combat-resolved', effect: 'passive-damage-avatar-after-reserve-combat', params: { amount: 1 } },
    ]),
  },
  {
    id: 'ink',
    name: '玄砚',
    title: '墨相',
    role: '策略 / 消耗',
    strategy: '通过护印、晶裂与牌库调度累积长线优势。',
    maxHp: 10,
    attack: 2,
    art: 'assets/ink.svg',
    color: '#6f6288',
    passive: passive('ink-ward', '墨护', '玄砚存活时，己方部署幻境后，当前前线获得 1 点护盾。', [
      { id: 'realm-shield', event: 'realm-deployed', effect: 'passive-shield-front-on-realm', params: { amount: 1 } },
    ]),
  },
  {
    id: 'frostblade',
    name: '银狼',
    title: '狼牙',
    role: '狼刃 / 游击 / 连击',
    strategy: '用连击与先攻贴脸换血，交战后的护盾反哺续航。',
    maxHp: 8,
    attack: 3,
    art: 'assets/frostblade.svg',
    color: '#7fa8c9',
    passive: passive('frost-aegis', '刃胄', '银狼完成一次交战后，获得 1 点护盾。', [
      { id: 'combat-aegis', event: 'combat-resolved', effect: 'passive-shield-self-after-combat', params: { amount: 1 } },
    ]),
  },
  {
    id: 'kongo',
    name: '金刚',
    title: '不坏',
    role: '石佛 / 铁壁 / 不屈',
    strategy: '以不屈与护盾死守战斗区，让对手的攻势化为徒劳。',
    maxHp: 13,
    attack: 2,
    art: 'assets/kongo.svg',
    color: '#9aa085',
    passive: passive('kongo-skin', '石肤', '己方回合开始时，若金刚位于前线，恢复 1 点生命。', [
      { id: 'turn-heal', event: 'turn-started', effect: 'passive-heal-self-if-front', params: { amount: 1 } },
    ]),
  },
]);

export const CARD_TYPE_LABELS = Object.freeze({
  combat: '战斗牌',
  spell: '法术牌',
  form: '形态牌',
  realm: '幻境牌',
});

function effectStep(condition, action, target, value = null) {
  const stableValue = value && typeof value === 'object'
    ? Object.freeze({ ...value })
    : value;
  return Object.freeze({ condition, action, target, value: stableValue });
}

function createEffectSteps(id, effect, target, value) {
  if (effect === 'assault') return [effectStep('source-ready', 'assault', 'source', value)];
  if (effect === 'damage') return [effectStep('always', 'damage', 'selected-enemy', value)];
  if (effect === 'burn-all') {
    return [
      effectStep('always', 'damage', 'all-enemy-units', value),
      effectStep('match-active', 'damage', 'enemy-avatar', 2),
    ];
  }
  if (effect === 'shield') return [effectStep('always', 'shield', 'selected-ally', value)];
  if (effect === 'fortify') return [effectStep('always', 'fortify', 'source', value)];
  if (effect === 'heal') return [effectStep('always', 'heal', 'selected-ally', value)];
  if (effect === 'draw-heal') {
    return [
      effectStep('always', 'draw', 'ally-player', value),
      effectStep('match-active', 'heal-avatar', 'ally-avatar', 1),
    ];
  }
  if (effect === 'revive') return [effectStep('always', 'revive', 'selected-ally', value)];
  if (effect === 'freeze') return [effectStep('always', 'freeze', 'selected-enemy', value)];
  if (effect === 'brittle') {
    return [
      effectStep('always', 'damage', 'selected-enemy', value),
      effectStep('target-alive', 'apply-brittle', 'selected-enemy', id === 'erode-script' ? 1 : 2),
    ];
  }
  if (effect === 'form') return [effectStep('always', 'form', 'source', value)];
  if (effect === 'realm') return [effectStep('always', 'realm', 'ally-player')];
  if (effect === 'apply-keyword') return [effectStep('always', 'apply-keyword', 'ally-player', value)];
  if (effect === 'grant-unyielding') return [effectStep('always', 'grant-unyielding', 'selected-ally', value)];
  if (effect === 'draw') return [effectStep('always', 'draw', 'ally-player', value)];
  return [effectStep('always', effect, target, value)];
}

function card(id, unitId, name, type, level, text, target, effect, value = null, extra = {}) {
  const {
    effects: configuredEffects,
    keywords: configuredKeywords = [],
    responseTo: configuredResponseTo = [],
    ...metadata
  } = extra;
  const effects = Object.freeze(configuredEffects
    ? configuredEffects.map((step) => effectStep(step.condition, step.action, step.target, step.value))
    : createEffectSteps(id, effect, target, value));
  return Object.freeze({
    id,
    unitId,
    name,
    type,
    typeLabel: CARD_TYPE_LABELS[type],
    level,
    cost: extra.cost ?? 1,
    copies: GAME_RULES.copiesPerCard,
    starterCopies: extra.starterCopies ?? 0,
    rarity: extra.rarity ?? 'common',
    tags: extra.tags ?? [],
    keywords: Object.freeze([...configuredKeywords]),
    timing: extra.timing ?? 'main',
    responseTo: Object.freeze([...configuredResponseTo]),
    text,
    target,
    effect,
    value,
    effects,
    ...metadata,
  });
}

export const CARD_DEFINITIONS = Object.freeze([
  card('flash-thrust', 'ember', '焰闪', 'combat', 1, '赤曜出击，本次攻击 +2。', 'auto', 'assault', 2, { starterCopies: 2, rarity: 'common', tags: ['爆发', '出击'] }),
  card('cinder-mark', 'ember', '烬印', 'spell', 1, '对一名敌方角色造成 3 点伤害。', 'enemy-unit', 'damage', 3, { starterCopies: 2, rarity: 'common', tags: ['解场'] }),
  card('ember-form', 'ember', '赤炼之躯', 'form', 2, '赤曜获得 +1 攻击与 +2 生命上限。', 'auto', 'form', { attack: 1, hp: 2 }, { starterCopies: 2, rarity: 'rare', tags: ['成长'] }),
  card('horizon-burn', 'ember', '灼界', 'spell', 3, '敌方全体受到 1 点伤害，敌方核心受到 2 点伤害。', 'auto', 'burn-all', 1, { starterCopies: 2, rarity: 'epic', tags: ['终结'] }),

  card('brace', 'basalt', '固阵', 'spell', 1, '一名友方角色获得 4 点护盾。', 'ally-unit', 'shield', 4, { starterCopies: 2, rarity: 'common', tags: ['保护'] }),
  card('iron-vow', 'basalt', '镇守', 'combat', 1, '岚岳进入前线并获得 3 点护盾。', 'auto', 'fortify', 3, { starterCopies: 2, rarity: 'common', tags: ['站场'] }),
  card('unyielding-wall', 'basalt', '不动如山', 'spell', 2, '一名友方角色获得不屈：生命大于 1 时，不会因伤害气绝。', 'ally-unit', 'grant-unyielding', 1, { rarity: 'epic', tags: ['保护'], keywords: [CARD_KEYWORDS.UNYIELDING] }),
  card('bastion-form', 'basalt', '山门之相', 'form', 2, '岚岳获得 +4 生命上限，并恢复 4 点生命。', 'auto', 'form', { attack: 0, hp: 4 }, { starterCopies: 2, rarity: 'rare', tags: ['成长'] }),
  card('wardline', 'basalt', '界碑阵列', 'realm', 3, '幻境：己方回合开始时，前线角色获得 1 点护盾。', 'auto', 'realm', null, {
    starterCopies: 2, rarity: 'epic', tags: ['幻境', '保护'], realm: { hp: 5, trigger: 'owner-turn-start', triggerEffect: 'shield-front', triggerValue: 1 },
  }),

  card('mend', 'lumen', '回响疗愈', 'spell', 1, '为一名友方角色恢复 4 点生命。', 'ally-unit', 'heal', 4, { starterCopies: 2, rarity: 'common', tags: ['恢复'] }),
  card('refract', 'lumen', '折光', 'spell', 1, '抽 2 张牌，并为己方核心恢复 1 点生命。', 'auto', 'draw-heal', 2, { starterCopies: 2, rarity: 'common', tags: ['调度'] }),
  card('prism-form', 'lumen', '月环之相', 'form', 2, '弦月获得 +1 攻击与 +2 生命上限。', 'auto', 'form', { attack: 1, hp: 2 }, { starterCopies: 2, rarity: 'rare', tags: ['成长'] }),
  card('recall', 'lumen', '余辉唤回', 'spell', 3, '唤醒一名离场角色，并回复全部生命。', 'knocked-ally', 'revive', 4, { starterCopies: 2, rarity: 'epic', tags: ['复归'] }),

  card('ice-cut', 'rime', '冰脉斩', 'combat', 1, '白棱出击，本次攻击 +1。', 'auto', 'assault', 1, { starterCopies: 2, rarity: 'common', tags: ['出击'] }),
  card('glacier-crack', 'rime', '冰河爆碎', 'combat', 2, '白棱出击，本次伤害翻倍。', 'auto', 'assault', 0, { rarity: 'epic', tags: ['爆发'], keywords: [CARD_KEYWORDS.CRIT] }),
  card('hush', 'rime', '静默霜域', 'spell', 1, '眩晕一名敌方角色，使其下回合无法出击或反击。', 'enemy-unit', 'freeze', 1, {
    starterCopies: 2, rarity: 'common', tags: ['控制', '眩晕'], keywords: [CARD_KEYWORDS.STUN],
  }),
  card('rime-form', 'rime', '冰镜之相', 'form', 2, '白棱获得 +1 攻击与 +1 生命上限。', 'auto', 'form', { attack: 1, hp: 1 }, { starterCopies: 2, rarity: 'rare', tags: ['成长'] }),
  card('fracture', 'rime', '晶裂', 'spell', 3, '造成 2 点伤害；目标后续受到的 2 次伤害各 +1。', 'enemy-unit', 'brittle', 2, { starterCopies: 2, rarity: 'epic', tags: ['破防'] }),

  card('thunder-step', 'storm', '雷走', 'combat', 1, '霆鸢出击，本次攻击 +1。', 'auto', 'assault', 1, { starterCopies: 2, rarity: 'common', tags: ['出击'] }),
  card('lightning-pierce', 'storm', '雷光先袭', 'combat', 1, '霆鸢出击，先攻：若首次伤害即气绝目标，则不受反击。', 'auto', 'assault', 0, { rarity: 'rare', tags: ['出击'], keywords: [CARD_KEYWORDS.FIRST_STRIKE] }),
  card('spark-shot', 'storm', '鸣闪', 'spell', 1, '对一名敌方角色造成 2 点伤害。', 'enemy-unit', 'damage', 2, { starterCopies: 2, rarity: 'common', tags: ['压制'] }),
  card('storm-form', 'storm', '惊雷之翼', 'form', 2, '霆鸢获得 +2 攻击。', 'auto', 'form', { attack: 2, hp: 0 }, { starterCopies: 2, rarity: 'rare', tags: ['爆发'] }),
  card('sky-net', 'storm', '引雷天网', 'realm', 3, '幻境：己方回合开始时，对敌方前线造成 1 点伤害。', 'auto', 'realm', null, {
    starterCopies: 2, rarity: 'epic', tags: ['幻境', '压制'], realm: { hp: 3, trigger: 'owner-turn-start', triggerEffect: 'damage-enemy-front', triggerValue: 1 },
  }),

  card('ink-ward', 'ink', '墨障', 'spell', 1, '一名友方角色获得 3 点护盾。', 'ally-unit', 'shield', 3, { starterCopies: 2, rarity: 'common', tags: ['保护'] }),
  card('erode-script', 'ink', '蚀字', 'spell', 1, '造成 1 点伤害，并使目标进入 1 层晶裂。', 'enemy-unit', 'brittle', 1, { starterCopies: 2, rarity: 'common', tags: ['消耗'] }),
  card('ink-form', 'ink', '无相墨躯', 'form', 2, '玄砚获得 +3 生命上限，并恢复 3 点生命。', 'auto', 'form', { attack: 0, hp: 3 }, { starterCopies: 2, rarity: 'rare', tags: ['成长'] }),
  card('living-archive', 'ink', '活页归档', 'realm', 3, '幻境：己方回合开始时，额外抽 1 张牌。', 'auto', 'realm', null, {
    starterCopies: 2, rarity: 'epic', tags: ['幻境', '调度'], realm: { hp: 3, trigger: 'owner-turn-start', triggerEffect: 'draw', triggerValue: 1 },
  }),

  // 赤曜：用直接伤害、前线压力与终结牌组织快攻构筑。
  card('coal-step', 'ember', '炽步', 'combat', 1, '赤曜出击，本次攻击 +1。', 'auto', 'assault', 1, { tags: ['出击', '节奏'] }),
  card('flare-guard', 'ember', '焰幕', 'spell', 1, '一名友方角色获得 2 点护盾。', 'ally-unit', 'shield', 2, { tags: ['保护'] }),
  card('ash-bind', 'ember', '灰烬锁', 'spell', 1, '造成 1 点伤害，并使目标进入 1 层晶裂。', 'enemy-unit', 'brittle', 1, { tags: ['破防'] }),
  card('cinder-return', 'ember', '余火复燃', 'spell', 2, '唤醒一名离场角色，使其恢复 3 点生命。', 'knocked-ally', 'revive', 3, { rarity: 'rare', tags: ['复归'] }),
  card('sunsteel-form', 'ember', '日铸之相', 'form', 2, '赤曜获得 +2 攻击。', 'auto', 'form', { attack: 2, hp: 0 }, { rarity: 'rare', tags: ['爆发'] }),
  card('fireline', 'ember', '焚线', 'realm', 2, '倒计时 2：对敌方前线造成 3 点伤害，然后重置。', 'auto', 'realm', null, {
    rarity: 'rare', tags: ['幻境', '压制', '倒计时'], keywords: [CARD_KEYWORDS.COUNTDOWN],
    realm: { hp: 3, trigger: 'owner-turn-start', triggerEffect: 'damage-enemy-front', triggerValue: 3, countdown: 2, countdownReset: 2 },
  }),
  card('ember-wave', 'ember', '燎原波', 'spell', 2, '敌方全体受到 1 点伤害，敌方核心受到 2 点伤害。', 'auto', 'burn-all', 1, { cost: 2, rarity: 'rare', tags: ['群攻'] }),
  card('twin-flame', 'ember', '双焰连斩', 'combat', 2, '赤曜出击，并追加一次连击伤害。', 'auto', 'assault', 0, { rarity: 'rare', tags: ['出击'], keywords: [CARD_KEYWORDS.COMBO] }),
  card('combustion-edge', 'ember', '熔锋决', 'combat', 3, '贯通：赤曜出击，本次攻击 +3。', 'auto', 'assault', 3, {
    cost: 2, rarity: 'epic', tags: ['终结', '出击', '贯通'], keywords: [CARD_KEYWORDS.PIERCE],
  }),

  // 岚岳：以护盾、复归和幻境组成耐久前线。
  card('stonefist', 'basalt', '岩拳', 'combat', 1, '岚岳出击，本次攻击 +1。', 'auto', 'assault', 1, { tags: ['出击'] }),
  card('crag-ward', 'basalt', '岩隙护壁', 'spell', 1, '一名友方角色获得 2 点护盾。', 'ally-unit', 'shield', 2, { tags: ['保护'] }),
  card('faultline', 'basalt', '断层', 'spell', 1, '造成 1 点伤害，并使目标进入 1 层晶裂。', 'enemy-unit', 'brittle', 1, { tags: ['破防'] }),
  card('earth-rest', 'basalt', '地脉休整', 'spell', 2, '为一名友方角色恢复 3 点生命。', 'ally-unit', 'heal', 3, { rarity: 'rare', tags: ['恢复'] }),
  card('monolith-form', 'basalt', '磐碑之相', 'form', 2, '岚岳获得 +5 生命上限，并恢复 5 点生命。', 'auto', 'form', { attack: 0, hp: 5 }, { rarity: 'rare', tags: ['成长'] }),
  card('granite-oath', 'basalt', '重岩誓约', 'combat', 2, '岚岳进入前线并获得 4 点护盾。', 'auto', 'fortify', 4, { cost: 2, rarity: 'rare', tags: ['站场'] }),
  card('gatehouse', 'basalt', '守界石门', 'realm', 2, '幻境：己方回合开始时，前线角色获得 1 点护盾。', 'auto', 'realm', null, {
    rarity: 'rare', tags: ['幻境', '保护'], realm: { hp: 4, trigger: 'owner-turn-start', triggerEffect: 'shield-front', triggerValue: 1 },
  }),
  card('last-watch', 'basalt', '不坠守望', 'spell', 3, '唤醒一名离场角色，使其恢复 5 点生命。', 'knocked-ally', 'revive', 5, { cost: 2, rarity: 'epic', tags: ['复归'] }),

  // 弦月：恢复、抽牌和低风险攻击构成调度构筑。
  card('light-step', 'lumen', '逐光', 'combat', 1, '协战：弦月出击，本次攻击 +1；若另一名友方角色本回合已攻击，再 +2。', 'auto', 'assault', 1, {
    tags: ['出击', '协战'], keywords: [CARD_KEYWORDS.COOP], coop: { attackBonus: 2 },
  }),
  card('dawn-needle', 'lumen', '曙针', 'spell', 1, '运势 4：造成 2 点伤害；运势成功则再造成 2 点伤害。', 'enemy-unit', 'damage', 2, {
    tags: ['解场', '运势'], keywords: [CARD_KEYWORDS.FORTUNE], fortune: { sides: 6, threshold: 4 },
    effects: [
      { condition: 'always', action: 'damage', target: 'selected-enemy', value: 2 },
      { condition: 'fortune-success', action: 'damage', target: 'selected-enemy', value: 2 },
    ],
  }),
  card('moon-ward', 'lumen', '月幕', 'spell', 1, '瞬发：一名友方角色获得 2 点护盾。', 'ally-unit', 'shield', 2, {
    tags: ['保护', '瞬发'], keywords: [CARD_KEYWORDS.INSTANT],
  }),
  card('radiant-encouragement', 'lumen', '辉月鼓舞', 'spell', 1, '鼓舞：下一次出击获得 +2 攻击与 1 点护盾。', 'auto', 'apply-keyword', {
    keywordId: CARD_KEYWORDS.ENCOURAGE,
    attack: 2,
    shield: 1,
  }, {
    tags: ['鼓舞', '支援'], keywords: [CARD_KEYWORDS.ENCOURAGE],
  }),
  card('luminous-form', 'lumen', '晓环之相', 'form', 2, '弦月获得 +2 生命上限，并恢复 2 点生命。', 'auto', 'form', { attack: 0, hp: 2 }, { rarity: 'rare', tags: ['成长'] }),
  card('pale-survey', 'lumen', '微光巡阅', 'spell', 2, '抽 1 张牌，并为己方核心恢复 1 点生命。', 'auto', 'draw-heal', 1, { rarity: 'rare', tags: ['调度'] }),
  card('soft-revival', 'lumen', '柔光归返', 'spell', 2, '唤醒一名离场角色，使其恢复 3 点生命。', 'knocked-ally', 'revive', 3, { rarity: 'rare', tags: ['复归'] }),
  card('moonlit-chamber', 'lumen', '月室', 'realm', 3, '幻境：己方回合开始时，额外抽 1 张牌。', 'auto', 'realm', null, {
    cost: 2, rarity: 'epic', tags: ['幻境', '调度'], realm: { hp: 4, trigger: 'owner-turn-start', triggerEffect: 'draw', triggerValue: 1 },
  }),

  // 白棱：眩晕与晶裂形成控制和破防的连续决策。
  card('frost-step', 'rime', '霜步', 'combat', 1, '白棱出击，本次攻击 +1。', 'auto', 'assault', 1, { tags: ['出击'] }),
  card('needle-frost', 'rime', '冰针', 'spell', 1, '对一名敌方角色造成 2 点伤害。', 'enemy-unit', 'damage', 2, { tags: ['解场'] }),
  card('hoar-barrier', 'rime', '霜障', 'spell', 1, '响应伤害、出击或护盾：一名友方角色获得 2 点护盾。', 'ally-unit', 'shield', 2, {
    timing: 'response', responseTo: ['damage', 'assault', 'shield'], tags: ['保护', '响应'], keywords: [CARD_KEYWORDS.RESPONSE],
  }),
  card('sever-flow', 'ink', '断流', 'spell', 1, '响应治疗：敌方全体受到 1 点伤害，敌方核心受到 2 点伤害。', 'auto', 'burn-all', 1, {
    timing: 'response', responseTo: ['heal', 'heal-avatar'], tags: ['响应', '压制'], keywords: [CARD_KEYWORDS.RESPONSE],
  }),
  card('soul-tithe', 'storm', '摄魂税', 'spell', 1, '响应复活：抽 2 张牌。', 'auto', 'draw', 2, {
    timing: 'response', responseTo: ['revive'], tags: ['响应', '调度'], keywords: [CARD_KEYWORDS.RESPONSE],
  }),
  card('warm-thaw', 'lumen', '融雪暖光', 'spell', 1, '响应冻结：一名友方角色获得 3 点护盾。', 'ally-unit', 'shield', 3, {
    timing: 'response', responseTo: ['freeze'], tags: ['响应', '保护'], keywords: [CARD_KEYWORDS.RESPONSE],
  }),
  card('shatterline', 'rime', '裂霜线', 'spell', 2, '造成 1 点伤害，并使目标进入 1 层晶裂。', 'enemy-unit', 'brittle', 1, { rarity: 'rare', tags: ['破防'] }),
  card('winter-form', 'rime', '凛冬之相', 'form', 2, '白棱获得 +2 攻击。', 'auto', 'form', { attack: 2, hp: 0 }, { rarity: 'rare', tags: ['压制'] }),
  card('cold-snap', 'rime', '寒束', 'spell', 2, '眩晕一名敌方角色，使其下回合无法出击或反击。', 'enemy-unit', 'freeze', 1, {
    rarity: 'rare', tags: ['控制', '眩晕'], keywords: [CARD_KEYWORDS.STUN],
  }),
  card('rime-return', 'rime', '冰封归途', 'spell', 2, '唤醒一名离场角色，使其恢复 3 点生命。', 'knocked-ally', 'revive', 3, { rarity: 'rare', tags: ['复归'] }),
  card('glacial-edge', 'rime', '极霜断', 'combat', 3, '白棱出击，本次攻击 +3。', 'auto', 'assault', 3, { cost: 2, rarity: 'epic', tags: ['终结', '出击'] }),

  // 霆鸢：高频换位、精准伤害和幻境压制。
  card('static-dash', 'storm', '疾电', 'combat', 1, '远程：霆鸢从当前位置发动攻击，本次攻击 +1，且不会受到反击。', 'auto', 'assault', 1, {
    tags: ['远程', '压制'], keywords: [CARD_KEYWORDS.REMOTE],
  }),
  card('gust-guard', 'storm', '风障', 'spell', 1, '一名友方角色获得 2 点护盾。', 'ally-unit', 'shield', 2, { tags: ['保护'] }),
  card('needle-arc', 'storm', '针雷', 'spell', 1, '对一名敌方角色造成 3 点伤害。', 'enemy-unit', 'damage', 3, { tags: ['解场'] }),
  card('charged-bolt', 'storm', '聚雷矢', 'spell', 1, '充能 2：对一名敌方角色造成 5 点伤害。', 'enemy-unit', 'damage', 5, {
    chargeCost: 2, rarity: 'rare', tags: ['充能', '解场'], keywords: [CARD_KEYWORDS.CHARGE],
  }),
  card('cloud-form', 'storm', '云隙之相', 'form', 2, '融合：霆鸢获得 +1 攻击与 +1 生命上限，同名牌最多融合 2 层。', 'auto', 'apply-keyword', {
    keywordId: CARD_KEYWORDS.FUSION, attack: 1, hp: 1, maxStacks: 2,
  }, {
    rarity: 'rare', tags: ['成长', '融合'], keywords: [CARD_KEYWORDS.FUSION],
    fusion: { attack: 1, hp: 1, maxStacks: 2 },
    effects: [{
      condition: 'always', action: 'apply-keyword', target: 'source',
      value: { keywordId: CARD_KEYWORDS.FUSION, attack: 1, hp: 1, maxStacks: 2 },
    }],
  }),
  card('afterimage', 'storm', '残影回环', 'spell', 2, '化身：己方回合开始时可自动免费使用；抽 1 张牌并为己方核心恢复 1 点生命。', 'auto', 'draw-heal', 1, {
    rarity: 'rare', tags: ['调度', '化身'], keywords: [CARD_KEYWORDS.INCARNATION],
    incarnation: { trigger: 'owner-turn-start', priority: 60 },
  }),
  card('squall-field', 'storm', '风暴域', 'realm', 2, '幻境：己方回合开始时，对敌方前线造成 1 点伤害。', 'auto', 'realm', null, {
    rarity: 'rare', tags: ['幻境', '压制'], realm: { hp: 4, trigger: 'owner-turn-start', triggerEffect: 'damage-enemy-front', triggerValue: 1 },
  }),
  card('thunder-return', 'storm', '鸣雷返航', 'spell', 3, '唤醒一名离场角色，并回复全部生命。', 'knocked-ally', 'revive', 4, { cost: 2, rarity: 'epic', tags: ['复归'] }),

  // 玄砚：护盾、消耗与幻境调度组成长线构筑。
  card('margin-ward', 'ink', '页边障', 'spell', 1, '一名友方角色获得 2 点护盾。', 'ally-unit', 'shield', 2, { tags: ['保护'] }),
  card('black-stain', 'ink', '墨渍', 'spell', 1, '投射：对敌方前线造成 2 点伤害；前线空缺时改为伤害敌方核心。', 'auto', 'damage', 2, {
    tags: ['消耗', '投射'], keywords: [CARD_KEYWORDS.PROJECTILE],
  }),
  card('redline-script', 'ink', '朱批', 'spell', 1, '造成 1 点伤害，并使目标进入 1 层晶裂。', 'enemy-unit', 'brittle', 1, { tags: ['破防'] }),
  card('archival-mend', 'ink', '归档修补', 'spell', 2, '为一名友方角色恢复 3 点生命。', 'ally-unit', 'heal', 3, { rarity: 'rare', tags: ['恢复'] }),
  card('paper-form', 'ink', '墨卷之相', 'form', 2, '玄砚获得 +1 攻击与 +2 生命上限。', 'auto', 'form', { attack: 1, hp: 2 }, { rarity: 'rare', tags: ['成长'] }),
  card('index-page', 'ink', '索引页', 'spell', 2, '占卜 3：检视牌库顶 3 张牌，选择一张置于牌库顶。', 'auto', 'divination', 3, {
    rarity: 'rare', tags: ['调度', '占卜'], keywords: [CARD_KEYWORDS.DIVINATION], divination: { count: 3 },
    effects: [{ condition: 'always', action: 'divination', target: 'ally-player', value: 3 }],
  }),
  card('seal-library', 'ink', '封缄书库', 'realm', 2, '幻境：己方回合开始时，前线角色获得 1 点护盾。', 'auto', 'realm', null, {
    rarity: 'rare', tags: ['幻境', '保护'], realm: { hp: 4, trigger: 'owner-turn-start', triggerEffect: 'shield-front', triggerValue: 1 },
  }),
  card('black-surge', 'ink', '墨潮压境', 'combat', 3, '玄砚出击，本次攻击 +3。', 'auto', 'assault', 3, { cost: 2, rarity: 'epic', tags: ['终结', '出击'] }),

  // ============ 扩展包·不夜宴席：蓄力/连引/赐能/烹饪/入夜/起源/专注 ============
  // 以下卡牌不进入默认构筑（starterCopies 为 0），需在秘闻阁开包收集或御札合成。
  card('ember-feast-fish', 'ember', '炙鱼备宴', 'spell', 1, '对敌方核心造成 1 点伤害，并获得食材「鲜鱼」。', 'auto', 'cook-ingredient', null, {
    rarity: 'common', tags: ['烹饪', '压制'], keywords: [CARD_KEYWORDS.COOK],
    effects: [
      { condition: 'always', action: 'damage', target: 'enemy-avatar', value: 1 },
      { condition: 'always', action: 'cook-ingredient', target: 'ally-player', value: 'fish' },
    ],
  }),
  card('undying-ember', 'ember', '不灭余烬', 'spell', 2, '对一名敌方角色造成 2 点伤害；起源：将一张「不灭余烬」洗回牌库。', 'enemy-unit', 'damage', 2, {
    rarity: 'rare', tags: ['起源', '解场'], keywords: [CARD_KEYWORDS.ORIGIN],
    effects: [
      { condition: 'always', action: 'damage', target: 'selected-enemy', value: 2 },
      { condition: 'always', action: 'origin-shuffle', target: 'ally-player' },
    ],
  }),
  card('mountain-granary', 'basalt', '山家米仓', 'spell', 1, '一名友方角色获得 2 点护盾，并获得食材「稻米」。', 'ally-unit', 'shield', 2, {
    rarity: 'common', tags: ['烹饪', '保护'], keywords: [CARD_KEYWORDS.COOK],
    effects: [
      { condition: 'always', action: 'shield', target: 'selected-ally', value: 2 },
      { condition: 'always', action: 'cook-ingredient', target: 'ally-player', value: 'rice' },
    ],
  }),
  card('bedrock-attitude', 'basalt', '磐石蓄势', 'spell', 2, '蓄力 2：两个己方回合后，岚岳获得 4 点护盾，并对敌方前线造成 2 点伤害。', 'auto', 'attach-charge', null, {
    rarity: 'rare', tags: ['蓄力', '站场'], keywords: [CARD_KEYWORDS.CHARGED],
    effects: [{
      condition: 'always',
      action: 'attach-charge',
      target: 'source',
      value: {
        threshold: 2,
        effects: [
          { action: 'shield-self', value: 4 },
          { action: 'damage-enemy-front', value: 2 },
        ],
      },
    }],
  }),
  card('moonlit-verse', 'lumen', '月下连句', 'spell', 1, '为一名友方角色恢复 3 点生命；连引：抽取牌库中下一张弦月的牌。', 'ally-unit', 'heal', 3, {
    rarity: 'rare', tags: ['连引', '恢复'], keywords: [CARD_KEYWORDS.CHAIN],
    effects: [
      { condition: 'always', action: 'heal', target: 'selected-ally', value: 3 },
      { condition: 'always', action: 'chain-draw', target: 'ally-player' },
    ],
  }),
  card('single-mind', 'lumen', '凝神一注', 'spell', 1, '抽 1 张牌；专注：若这是你本回合使用的第一张牌，再抽 1 张。', 'auto', 'draw', 1, {
    rarity: 'common', tags: ['专注', '调度'], keywords: [CARD_KEYWORDS.FOCUS],
    effects: [
      { condition: 'always', action: 'draw', target: 'ally-player', value: 1 },
      { condition: 'always', action: 'focus-draw', target: 'ally-player', value: 1 },
    ],
  }),
  card('longest-night', 'rime', '长夜将尽', 'spell', 3, '入夜：第 5 回合开始时，敌方全体角色受到 2 点伤害。', 'auto', 'set-nightfall', null, {
    rarity: 'epic', tags: ['入夜', '终结'], keywords: [CARD_KEYWORDS.NIGHTFALL],
    effects: [{
      condition: 'always',
      action: 'set-nightfall',
      target: 'ally-player',
      value: { round: 5, effect: 'damage-all-enemy-units', value: 2 },
    }],
  }),
  card('frost-pickle', 'rime', '霜厨腌菜', 'spell', 1, '对一名敌方角色造成 1 点伤害，并获得食材「霜菜」。', 'enemy-unit', 'damage', 1, {
    rarity: 'common', tags: ['烹饪', '解场'], keywords: [CARD_KEYWORDS.COOK],
    effects: [
      { condition: 'always', action: 'damage', target: 'selected-enemy', value: 1 },
      { condition: 'always', action: 'cook-ingredient', target: 'ally-player', value: 'herb' },
    ],
  }),
  card('thunder-endow', 'storm', '雷能赐灌', 'spell', 2, '对一名敌方角色造成 2 点伤害；赐能 2：若霆鸢充能不小于 2，消耗 2 点并额外造成 3 点伤害。', 'enemy-unit', 'damage', 2, {
    rarity: 'rare', tags: ['赐能', '解场'], keywords: [CARD_KEYWORDS.BESTOW], bestow: { cost: 2 },
    effects: [
      { condition: 'always', action: 'damage', target: 'selected-enemy', value: 2 },
      { condition: 'bestow-ready', action: 'damage', target: 'selected-enemy', value: 3 },
    ],
  }),
  card('ink-feast-fish', 'ink', '墨府家宴', 'spell', 1, '抽 1 张牌，并获得食材「鲜鱼」。', 'auto', 'draw', 1, {
    rarity: 'common', tags: ['烹饪', '调度'], keywords: [CARD_KEYWORDS.COOK],
    effects: [
      { condition: 'always', action: 'draw', target: 'ally-player', value: 1 },
      { condition: 'always', action: 'cook-ingredient', target: 'ally-player', value: 'fish' },
    ],
  }),
  card('origin-manuscript', 'ink', '起源抄本', 'spell', 2, '抽 1 张牌；起源：将一张「起源抄本」洗回牌库。', 'auto', 'draw', 1, {
    rarity: 'rare', tags: ['起源', '调度'], keywords: [CARD_KEYWORDS.ORIGIN],
    effects: [
      { condition: 'always', action: 'draw', target: 'ally-player', value: 1 },
      { condition: 'always', action: 'origin-shuffle', target: 'ally-player' },
    ],
  }),
  // ---- 霜刃：连击 / 先攻 游击手 ----
  card('frost-bite', 'frostblade', '霜咬', 'combat', 1, '霜刃出击，本次攻击 +1。', 'auto', 'assault', 1, { starterCopies: 2, rarity: 'common', tags: ['出击'] }),
  card('twin-gale', 'frostblade', '连霜双击', 'combat', 2, '银狼出击，并追加一次连击伤害。', 'auto', 'assault', 0, { starterCopies: 2, rarity: 'rare', tags: ['出击'], keywords: [CARD_KEYWORDS.COMBO] }),
  card('wolf-pounce', 'frostblade', '狼袭', 'combat', 1, '银狼出击，先攻：若首次伤害即气绝目标，则不受反击。', 'auto', 'assault', 0, { starterCopies: 2, rarity: 'rare', tags: ['出击'], keywords: [CARD_KEYWORDS.FIRST_STRIKE] }),
  card('frost-armor', 'frostblade', '刃胄', 'spell', 1, '一名友方角色获得 2 点护盾。', 'ally-unit', 'shield', 2, { starterCopies: 2, rarity: 'common', tags: ['保护'] }),
  card('moon-fang-form', 'frostblade', '月牙之相', 'form', 2, '银狼获得 +2 攻击与 +1 生命上限。', 'auto', 'form', { attack: 2, hp: 1 }, { rarity: 'rare', tags: ['成长'] }),
  card('blizzard-step', 'frostblade', '踏雪', 'spell', 1, '眩晕一名敌方角色，使其下回合无法出击或反击。', 'enemy-unit', 'freeze', 1, { rarity: 'rare', tags: ['控制', '眩晕'], keywords: [CARD_KEYWORDS.STUN] }),
  card('silver-fang', 'frostblade', '银牙', 'combat', 3, '银狼出击，本次攻击 +2。', 'auto', 'assault', 2, { rarity: 'common', tags: ['出击'] }),
  card('war-howl', 'frostblade', '战嚎', 'spell', 2, '鼓舞：下一次出击获得 +2 攻击与 1 点护盾。', 'auto', 'apply-keyword', {
    keywordId: CARD_KEYWORDS.ENCOURAGE,
    attack: 2,
    shield: 1,
  }, { rarity: 'rare', tags: ['鼓舞'], keywords: [CARD_KEYWORDS.ENCOURAGE] }),
  card('shadow-flicker', 'frostblade', '绝影', 'combat', 3, '银狼出击，本次伤害翻倍。', 'auto', 'assault', 0, { rarity: 'epic', tags: ['爆发'], keywords: [CARD_KEYWORDS.CRIT] }),
  card('frost-bulwark', 'frostblade', '霜壁', 'spell', 2, '一名友方角色获得不屈：生命大于 1 时，不会因伤害气绝。', 'ally-unit', 'grant-unyielding', 1, { rarity: 'epic', tags: ['保护'], keywords: [CARD_KEYWORDS.UNYIELDING] }),
  card('wild-awakening', 'frostblade', '野性苏醒', 'spell', 3, '唤醒一名离场角色，并回复全部生命。', 'knocked-ally', 'revive', 4, { rarity: 'epic', tags: ['复归'] }),
  card('gust-breath', 'frostblade', '风息', 'spell', 1, '抽 1 张牌，并为己方核心恢复 1 点生命。', 'auto', 'draw-heal', 1, { rarity: 'common', tags: ['调度'] }),

  // ---- 金刚：不屈 / 铁壁 石佛 ----
  card('stone-fist', 'kongo', '岩拳', 'combat', 1, '金刚出击，本次攻击 +1。', 'auto', 'assault', 1, { starterCopies: 2, rarity: 'common', tags: ['出击'] }),
  card('mountain-vow', 'kongo', '山岳之誓', 'combat', 2, '金刚进入前线并获得 3 点护盾。', 'auto', 'fortify', 3, { starterCopies: 2, rarity: 'common', tags: ['站场'] }),
  card('kongo-guard', 'kongo', '金刚不坏', 'spell', 2, '一名友方角色获得不屈：生命大于 1 时，不会因伤害气绝。', 'ally-unit', 'grant-unyielding', 1, { starterCopies: 2, rarity: 'epic', tags: ['保护'], keywords: [CARD_KEYWORDS.UNYIELDING] }),
  card('guardian-form', 'kongo', '金身之相', 'form', 2, '金刚获得 +4 生命上限。', 'auto', 'form', { attack: 0, hp: 4 }, { starterCopies: 1, rarity: 'rare', tags: ['成长'] }),
  card('quake-stomp', 'kongo', '震地踏', 'spell', 2, '敌方全体受到 1 点伤害，敌方核心受到 2 点伤害。', 'auto', 'burn-all', 1, { starterCopies: 1, rarity: 'rare', tags: ['压制'] }),
  card('iron-aegis', 'kongo', '铁楯', 'spell', 1, '一名友方角色获得 3 点护盾。', 'ally-unit', 'shield', 3, { rarity: 'common', tags: ['保护'] }),
  card('counter-stance', 'kongo', '待月架', 'combat', 2, '金刚出击，先攻：若首次伤害即气绝目标，则不受反击。', 'auto', 'assault', 0, { rarity: 'rare', tags: ['出击'], keywords: [CARD_KEYWORDS.FIRST_STRIKE] }),
  card('avalanche-fist', 'kongo', '崩山拳', 'combat', 3, '金刚出击，本次伤害翻倍。', 'auto', 'assault', 0, { rarity: 'epic', tags: ['爆发'], keywords: [CARD_KEYWORDS.CRIT] }),
  card('stone-mend', 'kongo', '磐石自愈', 'spell', 1, '为一名友方角色恢复 3 点生命。', 'ally-unit', 'heal', 3, { rarity: 'common', tags: ['恢复'] }),
  card('war-drum', 'kongo', '战鼓', 'spell', 2, '鼓舞：下一次出击获得 +1 攻击与 2 点护盾。', 'auto', 'apply-keyword', {
    keywordId: CARD_KEYWORDS.ENCOURAGE,
    attack: 1,
    shield: 2,
  }, { rarity: 'rare', tags: ['鼓舞'], keywords: [CARD_KEYWORDS.ENCOURAGE] }),
  card('warding-stone', 'kongo', '结界石', 'realm', 3, '幻境：己方回合开始时，前线角色获得 1 点护盾。', 'auto', 'realm', null, {
    rarity: 'rare', tags: ['幻境', '保护'], realm: { hp: 4, trigger: 'owner-turn-start', triggerEffect: 'shield-front', triggerValue: 1 },
  }),
  card('stone-whisper', 'kongo', '石语', 'spell', 1, '抽 1 张牌，并为己方核心恢复 1 点生命。', 'auto', 'draw-heal', 1, { rarity: 'common', tags: ['调度'] }),
]);

const UNIT_MAP = new Map(UNIT_DEFINITIONS.map((unit) => [unit.id, unit]));
const CARD_MAP = new Map(CARD_DEFINITIONS.map((definition) => [definition.id, definition]));

export function getUnitDefinition(unitId) {
  return UNIT_MAP.get(unitId);
}

export function getCardDefinition(definitionId) {
  return CARD_MAP.get(definitionId);
}

export function getCardsForUnit(unitId) {
  return CARD_DEFINITIONS.filter((definition) => definition.unitId === unitId);
}

export function getStarterCardIdsForUnit(unitId) {
  return getCardsForUnit(unitId)
    .flatMap((definition) => Array.from({ length: definition.starterCopies }, () => definition.id));
}

export function createDefaultDeckDefinition(unitIds) {
  return {
    unitIds: [...unitIds],
    cardIds: unitIds.flatMap((unitId) => getStarterCardIdsForUnit(unitId)),
  };
}

export function validateDeckDefinition(deckDefinition) {
  const errors = [];
  const unitIds = deckDefinition?.unitIds ?? [];
  const cardIds = deckDefinition?.cardIds ?? [];
  const uniqueUnitIds = new Set(unitIds);

  if (unitIds.length !== GAME_RULES.lineupSize) errors.push(`需要选择 ${GAME_RULES.lineupSize} 名角色。`);
  if (uniqueUnitIds.size !== unitIds.length) errors.push('编成中不能出现重复角色。');
  unitIds.forEach((unitId) => {
    if (!getUnitDefinition(unitId)) errors.push(`未知角色：${unitId}。`);
  });

  if (cardIds.length !== GAME_RULES.lineupSize * GAME_RULES.cardsPerUnit) {
    errors.push(`牌组必须包含 ${GAME_RULES.lineupSize * GAME_RULES.cardsPerUnit} 张牌。`);
  }

  const copyCounts = new Map();
  const unitCardCounts = new Map(unitIds.map((unitId) => [unitId, 0]));
  cardIds.forEach((cardId) => {
    const definition = getCardDefinition(cardId);
    if (!definition) {
      errors.push(`未知卡牌：${cardId}。`);
      return;
    }
    if (!uniqueUnitIds.has(definition.unitId)) errors.push(`卡牌「${definition.name}」不属于当前编成。`);
    copyCounts.set(cardId, (copyCounts.get(cardId) ?? 0) + 1);
    unitCardCounts.set(definition.unitId, (unitCardCounts.get(definition.unitId) ?? 0) + 1);
  });

  copyCounts.forEach((count, cardId) => {
    if (count > GAME_RULES.copiesPerCard) {
      errors.push(`同名卡「${getCardDefinition(cardId)?.name ?? cardId}」最多 ${GAME_RULES.copiesPerCard} 张。`);
    }
  });
  unitCardCounts.forEach((count, unitId) => {
    if (count !== GAME_RULES.cardsPerUnit) {
      errors.push(`${getUnitDefinition(unitId)?.name ?? unitId} 需要携带 ${GAME_RULES.cardsPerUnit} 张卡。`);
    }
  });

  return { valid: errors.length === 0, errors };
}
