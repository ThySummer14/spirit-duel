import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve, sep } from 'node:path';
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
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
// Godot 的角色卡面必须与同源内容一起迁入，避免只导出 JSON 后新角色没有肖像。
const artPaths = new Set(UNIT_DEFINITIONS.flatMap((unit) => [unit.art, unit.awakenedArt]).filter(Boolean));
const portraits = [...artPaths].map((path) => {
  const source = resolve(root, path);
  if (!source.startsWith(resolve(root, 'assets') + sep) || !existsSync(source)) {
    throw new Error(`Missing or invalid unit art: ${path}`);
  }
  return { destination: resolve(root, 'godot', path), bytes: readFileSync(source) };
});
let copied = 0;
for (const { destination, bytes } of portraits) {
  if (existsSync(destination) && readFileSync(destination).equals(bytes)) continue;
  mkdirSync(dirname(destination), { recursive: true });
  writeFileSync(destination, bytes);
  copied += 1;
}
const targets = [
  '../prototypes/godot-content-probe/content.json',
  '../godot/content/content.json',
];
for (const rel of targets) {
  const out = fileURLToPath(new URL(rel, import.meta.url));
  mkdirSync(dirname(out), { recursive: true });
  writeFileSync(out, json);
}
console.log(`Exported ${data.units.length} units / ${data.cards.length} cards → probe + godot/content; ${portraits.length} portraits (${copied} updated)`);
