#!/usr/bin/env node
/**
 * 将 game-content-wave{4,5,6}.js 合并进 game-content.js / game-core.js / Godot 编成筛选。
 * 幂等：已合并则跳过。
 */
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const waves = [
  {
    n: 4,
    packId: 'WAVE4_PACK_ID',
    packName: 'WAVE4_PACK_NAME',
    units: 'WAVE4_UNIT_DEFINITIONS',
    cards: 'WAVE4_CARD_DEFINITIONS',
    file: 'game-content-wave4.js',
    subpacks: 'WAVE4_SUBPACKS',
  },
  {
    n: 5,
    packId: 'WAVE5_PACK_ID',
    packName: 'WAVE5_PACK_NAME',
    units: 'WAVE5_UNIT_DEFINITIONS',
    cards: 'WAVE5_CARD_DEFINITIONS',
    file: 'game-content-wave5.js',
    subpacks: 'WAVE5_SUBPACKS',
  },
  {
    n: 6,
    packId: 'WAVE6_PACK_ID',
    packName: 'WAVE6_PACK_NAME',
    units: 'WAVE6_UNIT_DEFINITIONS',
    cards: 'WAVE6_CARD_DEFINITIONS',
    file: 'game-content-wave6.js',
    subpacks: 'WAVE6_SUBPACKS',
  },
];

function mergeContent() {
  const path = join(root, 'game-content.js');
  let t = readFileSync(path, 'utf8');
  for (const w of waves) {
    if (t.includes(w.units)) {
      console.log(`skip content wave${w.n} (already merged)`);
      continue;
    }
    if (!existsSync(join(root, w.file))) {
      console.log(`skip content wave${w.n} (missing ${w.file})`);
      continue;
    }
    const names = [w.packId, w.packName, w.units, w.cards, w.subpacks].filter(Boolean);
    const importBlock = `import {\n  ${names.join(',\n  ')},\n} from './${w.file}?v=1';\n`;
    // insert import before `export {`
    const exportAt = t.indexOf('\nexport {\n');
    if (exportAt < 0) throw new Error('export block not found');
    t = t.slice(0, exportAt + 1) + importBlock + t.slice(exportAt + 1);
    // extend export block
    t = t.replace(
      `\nexport {\n  CLASSIC_CARD_DEFINITIONS,`,
      `\nexport {\n  ${names.join(',\n  ')},\n  CLASSIC_CARD_DEFINITIONS,`,
      1,
    );
    // CONTENT_PACKS
    const packExtra = w.subpacks
      ? `, subpacks: ${w.subpacks}`
      : '';
    t = t.replace(
      `  Object.freeze({ id: WAVE3_PACK_ID, name: WAVE3_PACK_NAME, pack: WAVE3_PACK_ID, subpacks: WAVE3_SUBPACKS }),`,
      `  Object.freeze({ id: WAVE3_PACK_ID, name: WAVE3_PACK_NAME, pack: WAVE3_PACK_ID, subpacks: WAVE3_SUBPACKS }),\n  Object.freeze({ id: ${w.packId}, name: ${w.packName}, pack: ${w.packId}${packExtra} }),`,
      1,
    );
    // spreads
    t = t.replace(
      '  // 经典基础包 29 式神\n  ...CLASSIC_UNIT_DEFINITIONS,',
      `  // wave${w.n}\n  ...${w.units},\n  // 经典基础包 29 式神\n  ...CLASSIC_UNIT_DEFINITIONS,`,
      1,
    );
    t = t.replace(
      '  // 经典基础包卡牌与 token\n  ...CLASSIC_CARD_DEFINITIONS,',
      `  // wave${w.n} cards\n  ...${w.cards},\n  // 经典基础包卡牌与 token\n  ...CLASSIC_CARD_DEFINITIONS,`,
      1,
    );
    console.log(`merged content wave${w.n}`);
  }
  writeFileSync(path, t);
}

function mergeCore() {
  const path = join(root, 'game-core.js');
  let t = readFileSync(path, 'utf8');
  const old = `const isClassic = unit.pack === 'classic' || unit.pack === 'wave2' || unit.pack === 'wave3';`;
  const neu = `const isClassic = unit.pack === 'classic' || unit.pack === 'wave2' || unit.pack === 'wave3' || unit.pack === 'wave4' || unit.pack === 'wave5' || unit.pack === 'wave6';`;
  if (t.includes(old)) {
    t = t.replace(old, neu, 1);
    writeFileSync(path, t);
    console.log('merged game-core pack rules');
  } else if (t.includes(neu)) {
    console.log('skip game-core (already)');
  } else {
    console.log('WARN game-core pattern not found');
  }
}

function mergeFormation() {
  const path = join(root, 'godot/scripts/ui/formation_screen.gd');
  if (!existsSync(path)) return;
  let t = readFileSync(path, 'utf8');
  if (!t.includes('"wave4"')) {
    t = t.replace(
      'for pack_id in ["all", "origin", "classic", "wave2", "wave3"]:',
      'for pack_id in ["all", "origin", "classic", "wave2", "wave3", "wave4", "wave5", "wave6"]:',
      1,
    );
    t = t.replace(
      `		"wave3":
			return "月夜沧海"`,
      `		"wave3":
			return "月夜沧海"
		"wave4":
			return "吉运善恶"
		"wave5":
			return "繁花喧哗"
		"wave6":
			return "空弦鸣雷"`,
      1,
    );
    writeFileSync(path, t);
    console.log('merged formation pack chips');
  } else {
    console.log('skip formation (already)');
  }
}

mergeContent();
mergeCore();
mergeFormation();
console.log('merge-wave456 done');
