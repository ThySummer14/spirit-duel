#!/usr/bin/env node
/**
 * 将 game-content-wave{10,11,12}.js 合并进主内容 / 编成筛选。
 */
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const waves = [
  { n: 10, packId: 'WAVE10_PACK_ID', packName: 'WAVE10_PACK_NAME', units: 'WAVE10_UNIT_DEFINITIONS', cards: 'WAVE10_CARD_DEFINITIONS', file: 'game-content-wave10.js', subpacks: 'WAVE10_SUBPACKS', label: '鬼灭联动' },
  { n: 11, packId: 'WAVE11_PACK_ID', packName: 'WAVE11_PACK_NAME', units: 'WAVE11_UNIT_DEFINITIONS', cards: 'WAVE11_CARD_DEFINITIONS', file: 'game-content-wave11.js', subpacks: null, label: '衍生式神' },
  { n: 12, packId: 'WAVE12_PACK_ID', packName: 'WAVE12_PACK_NAME', units: 'WAVE12_UNIT_DEFINITIONS', cards: 'WAVE12_CARD_DEFINITIONS', file: 'game-content-wave12.js', subpacks: null, label: '灵枢二弹' },
];

const path = join(root, 'game-content.js');
let t = readFileSync(path, 'utf8');
for (const w of waves) {
  if (t.includes(w.units)) {
    console.log(`skip content wave${w.n}`);
    continue;
  }
  if (!existsSync(join(root, w.file))) {
    console.log(`skip wave${w.n} missing ${w.file}`);
    continue;
  }
  const names = [w.packId, w.packName, w.units, w.cards, w.subpacks].filter(Boolean);
  // detect SUBPACKS export if file has it even when subpacks null in table
  const src = readFileSync(join(root, w.file), 'utf8');
  if (!w.subpacks && src.includes(`WAVE${w.n}_SUBPACKS`)) {
    names.push(`WAVE${w.n}_SUBPACKS`);
    w.subpacks = `WAVE${w.n}_SUBPACKS`;
  }
  const importBlock = `import {\n  ${names.join(',\n  ')},\n} from './${w.file}?v=1';\n`;
  const exportAt = t.indexOf('\nexport {\n');
  t = t.slice(0, exportAt + 1) + importBlock + t.slice(exportAt + 1);
  t = t.replace(
    `\nexport {\n  CLASSIC_CARD_DEFINITIONS,`,
    `\nexport {\n  ${names.join(',\n  ')},\n  CLASSIC_CARD_DEFINITIONS,`,
    1,
  );
  const packExtra = w.subpacks ? `, subpacks: ${w.subpacks}` : '';
  t = t.replace(
    `  Object.freeze({ id: WAVE9_PACK_ID, name: WAVE9_PACK_NAME, pack: WAVE9_PACK_ID, subpacks: WAVE9_SUBPACKS }),`,
    `  Object.freeze({ id: WAVE9_PACK_ID, name: WAVE9_PACK_NAME, pack: WAVE9_PACK_ID, subpacks: WAVE9_SUBPACKS }),\n  Object.freeze({ id: ${w.packId}, name: ${w.packName}, pack: ${w.packId}${packExtra} }),`,
    1,
  );
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

const fp = join(root, 'godot/scripts/ui/formation_screen.gd');
if (existsSync(fp)) {
  let ft = readFileSync(fp, 'utf8');
  if (!ft.includes('"wave10"')) {
    ft = ft.replace(
      'for pack_id in ["all", "origin", "classic", "wave2", "wave3", "wave4", "wave5", "wave6", "wave7", "wave8", "wave9"]:',
      'for pack_id in ["all", "origin", "classic", "wave2", "wave3", "wave4", "wave5", "wave6", "wave7", "wave8", "wave9", "wave10", "wave11", "wave12"]:',
      1,
    );
    ft = ft.replace(
      `		"wave9":
			return "龙渊花札"`,
      `		"wave9":
			return "龙渊花札"
		"wave10":
			return "鬼灭联动"
		"wave11":
			return "衍生式神"
		"wave12":
			return "灵枢二弹"`,
      1,
    );
    writeFileSync(fp, ft);
    console.log('formation chips wave10-12');
  } else {
    console.log('formation already');
  }
}
console.log('merge-wave101112 done');
