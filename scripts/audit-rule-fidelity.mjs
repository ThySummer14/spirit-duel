import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CARD_DEFINITIONS, UNIT_DEFINITIONS } from '../game-content.js';

// This is an inventory, not a natural-language proof of semantic equivalence.
// Absence of a simplification marker means unreviewed, never restored.
const root = fileURLToPath(new URL('../', import.meta.url));
const overlay = JSON.parse(readFileSync(resolve(root, 'godot/content/verified_rules.json'), 'utf8'));
const marker = /简化|近似|可玩化|暂未|占位/;
const errors = [];
const rows = [];
for (const [kind, definitions] of [['units', UNIT_DEFINITIONS], ['cards', CARD_DEFINITIONS]]) {
  const patches = overlay[kind] ?? {};
  for (const id of Object.keys(patches)) {
    if (!definitions.some((definition) => definition.id === id)) errors.push(`Unknown ${kind} reference: ${id}`);
  }
  for (const original of definitions) {
    const patch = patches[original.id];
    const effective = { ...original, ...patch };
    const texts = kind === 'units'
      ? [effective.passive?.text, effective.awakenedPassive?.text]
      : [effective.text, effective.formAbility];
    const knownApproximation = texts.some((text) => marker.test(text ?? ''));
    const status = knownApproximation ? 'known-approximation' : patch?.verificationPending?.length ? 'pending-verification' : patch ? 'source-backed-native' : 'unreviewed';
    if (patch && knownApproximation) errors.push(`Approximation in reviewed ${kind}: ${original.id}`);
    if (kind === 'cards' && patch && (!patch.verifiedRules || !patch.effects?.length)) errors.push(`Missing executable reviewed rules: ${original.id}`);
    rows.push({ kind, id: original.id, name: original.name, unitId: original.unitId, pack: original.pack, status,
      implementationText: texts.filter(Boolean).join('\n'),
      verificationPending: patch?.verificationPending,
      sourceSnapshot: kind === 'units' ? original.officialAbility ?? '' : original.officialText ?? '',
      actions: kind === 'cards' ? effective.effects?.map((effect) => effect.action) ?? [] : undefined });
  }
}
const summary = {};
for (const kind of ['units', 'cards']) {
  const selected = rows.filter((row) => row.kind === kind);
  summary[kind] = Object.fromEntries(['known-approximation', 'unreviewed', 'pending-verification', 'source-backed-native'].map((status) => [status, selected.filter((row) => row.status === status).length]));
}
const fullCatalogRestored = errors.length === 0 && rows.every((row) => row.status === 'source-backed-native');
const report = { schema: 1, engine: 'godot', fullCatalogRestored, summary, errors,
  limitations: ['仅扫描显式简化标记；未标记内容仍需逐条比对。', 'source-backed-native 表示已建立资料和原生实现，不能替代原版实机交互核验。', '旧 JS 卡牌效果没有应用 Godot 核对数据。'], rows };
const outputIndex = process.argv.indexOf('--out');
if (outputIndex >= 0) {
  if (!process.argv[outputIndex + 1]) throw new Error('--out requires a path');
  writeFileSync(resolve(process.argv[outputIndex + 1]), JSON.stringify(report, null, 2) + '\n');
}
console.log(JSON.stringify({ fullCatalogRestored, summary, errors }, null, 2));
if (!fullCatalogRestored) console.error('RULE_FIDELITY_INCOMPLETE: 全库仍存在简化或未核对内容。稳定性测试通过不等于效果还原。');
if (errors.length || (!process.argv.includes('--report') && !fullCatalogRestored)) process.exitCode = 1;
