import { readFileSync, writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CARD_DEFINITIONS, UNIT_DEFINITIONS, getCardDefinition, getUnitDefinition } from '../game-content.js';

const root = dirname(fileURLToPath(import.meta.url));
const verified = JSON.parse(readFileSync(resolve(root, '../godot/content/verified_rules.json'), 'utf8'));
const marker = /简化|近似|可玩化|暂未|占位/;

const UNIT_LABELS = {
  'datiangou-gangfeng': '钢风（大天狗·钢风）',
  yaoginshi: '妖琴师',
  datiangou: '大天狗',
  yimulian: '一目连',
  zhen: '鸩',
  fenghuanghuo: '凤凰火',
  taohuayao: '桃花妖',
  yingcao: '萤草',
};

function rawCard(id) {
  return CARD_DEFINITIONS.find((c) => c.id === id);
}

function rawUnit(id) {
  return UNIT_DEFINITIONS.find((u) => u.id === id);
}

function summarizeImplementation(card) {
  if (!card) return '（卡库中无此 id）';
  const texts = [card.text, card.formAbility].filter(Boolean).join(' / ');
  const actions = (card.effects ?? []).map((e) => e.action).join(', ') || card.effect || '—';
  const flags = [];
  if (marker.test(texts)) flags.push('文案含简化标记');
  if (!card.verifiedRules) flags.push('未挂 verifiedRules');
  if (card.verifiedRules && (!card.effects?.length)) flags.push('缺 effects');
  return `文案：${texts.slice(0, 120)}${texts.length > 120 ? '…' : ''}；动作：${actions}${flags.length ? `；⚠ ${flags.join('、')}` : ''}`;
}

function godotStatus(unitId) {
  const map = {
    'datiangou-gangfeng': 'verify_steel_wind.gd',
    yaoginshi: 'verify_yaoginshi.gd',
    datiangou: 'verify_datiangou.gd',
    yimulian: 'verify_yimulian.gd',
    zhen: 'verify_zhen.gd',
    fenghuanghuo: 'verify_phoenix.gd',
    taohuayao: 'verify_peach.gd',
    yingcao: 'verify_firefly.gd',
  };
  return map[unitId] ? `Godot 专测 \`${map[unitId]}\` + verified_card_rules.gd` : '—';
}

const rows = [];
for (const unitId of Object.keys(verified.units)) {
  const patch = verified.units[unitId];
  const before = rawUnit(unitId);
  const merged = before ? { ...before, ...patch } : null;
  rows.push({
    kind: 'unit-passive',
    unitId,
    id: unitId,
    name: UNIT_LABELS[unitId] ?? unitId,
    verifiedText: [patch.passive?.text, patch.awakenedPassive?.text].filter(Boolean).join('\n'),
    beforeImpl: before
      ? summarizeImplementation({ text: before.passive?.text, effects: [] })
      : '无角色定义',
    afterOverlay: merged ? `被动：${merged.passive?.text}\n觉醒：${merged.awakenedPassive?.text}` : '—',
    godot: godotStatus(unitId),
    pending: patch.verificationPending ?? [],
    jsEngine: 'Web/JS 引擎未读取 verified_rules（本 PR 起对凤凰火批次接入 overlay + phoenix 结算）',
  });
}

const cardsByUnit = {};
for (const cardId of Object.keys(verified.cards)) {
  const patch = verified.cards[cardId];
  const before = rawCard(cardId);
  const unitId = before?.unitId ?? patch.unitId;
  if (!cardsByUnit[unitId]) cardsByUnit[unitId] = [];
  cardsByUnit[unitId].push({ cardId, patch, before });
}

for (const unitId of Object.keys(verified.units)) {
  for (const { cardId, patch, before } of cardsByUnit[unitId] ?? []) {
    rows.push({
      kind: 'card',
      unitId,
      id: cardId,
      name: before?.name ?? cardId,
      verifiedText: patch.text + (patch.formAbility ? `\n形态持续：${patch.formAbility}` : ''),
      beforeImpl: summarizeImplementation(before),
      afterOverlay: `核对牌文：${patch.text}`,
      godot: godotStatus(unitId),
      pending: patch.verificationPending ?? [],
      jsEngine: before?.verifiedRules
        ? 'overlay 后数据与 verified_rules 对齐；结算依赖 game-core 专规（凤凰火本 PR）'
        : '仅旧 game-content 映射',
    });
  }
}

writeFileSync(resolve(root, '../docs/verified-gap-data.json'), JSON.stringify({ generatedAt: new Date().toISOString(), rows }, null, 2) + '\n');
console.log('wrote', rows.length, 'rows');
