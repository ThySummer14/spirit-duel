import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CARD_DEFINITIONS, UNIT_DEFINITIONS, GAME_RULES } from '../game-content.js';

// 内容仅含可序列化数据；效果标识保留，执行器仍属于浏览器规则层 / Godot 纵向切片。
const data = {
  schema: 1,
  rules: {
    lineupSize: GAME_RULES.lineupSize,
    cardsPerUnit: GAME_RULES.cardsPerUnit,
    copiesPerCard: GAME_RULES.copiesPerCard,
    startingAvatarHp: GAME_RULES.startingAvatarHp,
    maxEnergy: GAME_RULES.maxEnergy,
    openingHandSize: GAME_RULES.openingHandSize,
    maxHandSize: GAME_RULES.maxHandSize,
    knockoutCountdown: GAME_RULES.knockoutCountdown,
    maxUnitLevel: GAME_RULES.maxUnitLevel,
    bonusUpgradeTurn: GAME_RULES.bonusUpgradeTurn,
  },
  units: UNIT_DEFINITIONS,
  cards: CARD_DEFINITIONS,
};
const json = JSON.stringify(data, null, 2) + '\n';
const here = dirname(fileURLToPath(import.meta.url));
const targets = [
  '../prototypes/godot-content-probe/content.json',
  '../godot/content/content.json',
];
for (const rel of targets) {
  const out = fileURLToPath(new URL(rel, import.meta.url));
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, json);
}
console.log(`Exported ${data.units.length} units / ${data.cards.length} cards → probe + godot/content`);
