/** Portable project audit. Browser geometry/gameplay acceptance lives in output/playwright/v6-play-match.js. */
import { readFileSync, existsSync, readdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (file) => readFileSync(resolve(root, file), 'utf8');
const html = read('index.html'), css = read('styles.css');
const failures = [];
let checks = 0;
function check(condition, label) { checks++; if (!condition) failures.push(label); }
const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map((m) => m[1]);
check(ids.length === new Set(ids).size, 'HTML ids must be unique');
for (const match of html.matchAll(/\b(?:aria-controls|aria-labelledby|aria-describedby)="([^"]+)"/g)) {
  for (const id of match[1].split(/\s+/)) check(ids.includes(id), `ARIA reference missing: ${id}`);
}
check(/class="skip-link"[^>]*href="#battlefield"|href="#battlefield"[^>]*class="skip-link"/.test(html), 'skip-link must target battlefield');
check(/<main\b[^>]*id="battlefield"/.test(html), 'battlefield must have main landmark');
check(/<html[^>]*lang="zh/.test(html), 'document must declare Chinese language');
check(/name="viewport"/.test(html), 'responsive viewport metadata');
for (const dialog of html.matchAll(/<dialog\b([^>]*)>/g)) check(/aria-label(?:ledby)?=/.test(dialog[1]), 'dialogs must have accessible names');
for (const input of html.matchAll(/<input\b([^>]*)>/g)) {
  const id = input[1].match(/\bid="([^"]+)"/)?.[1];
  check(/aria-label=/.test(input[1]) || (id && new RegExp(`<label[^>]*for="${id}"`).test(html)) || html.slice(Math.max(0, input.index - 180), input.index).lastIndexOf('<label') > html.slice(Math.max(0, input.index - 180), input.index).lastIndexOf('</label>'), `input needs a label: ${id}`);
}
check(/prefers-reduced-motion:\s*reduce/.test(css), 'reduced-motion CSS fallback');
check(/:focus-visible/.test(css), 'visible keyboard focus');
check(/max-width:\s*760px/.test(css) && /max-width:\s*1100px/.test(css), 'mobile and tablet breakpoints');
check(/\.board-column\s*\{[^}]*grid-template-columns:\s*minmax\(0,\s*1fr\)/s.test(css), 'battle board must have an explicit full-width grid column');
check(/\.unit-row\s*\{[^}]*flex-wrap:\s*nowrap/s.test(css), 'reserve units must not wrap into other tracks');
check(/\.hand-scroll\s+\.hand-card\s*\{[^}]*flex:\s*0\s+0/s.test(css), 'hand cards must not shrink into slices');
for (const match of html.matchAll(/(?:src|href)="([^"#]+)"/g)) {
  const path = match[1].split('?')[0];
  if (!/^(https?:|data:)/.test(path)) check(existsSync(resolve(root, path)), `missing HTML resource: ${path}`);
}
for (const file of readdirSync(root).filter((f) => /\.(js|css)$/.test(f))) {
  const source = read(file);
  for (const match of source.matchAll(/from\s+['"](\.\/[^'"]+)['"]/g)) check(existsSync(resolve(root, match[1].split('?')[0])), `missing module: ${file} -> ${match[1]}`);
  for (const match of source.matchAll(/(?:url\(['"]?|art:\s*['"])(assets\/[^'"\s)]+)/g)) check(existsSync(resolve(root, match[1])), `missing asset: ${match[1]}`);
  check(!/https?:\/\/[^'"\s]*(?:onmyoji|163\.com|netease)/i.test(source), `commercial game asset source in ${file}`);
}
const map = JSON.parse(html.match(/<script type="importmap">([\s\S]*?)<\/script>/)?.[1] ?? '{}');
check(/^https:\/\/cdn\.jsdelivr\.net\/npm\/three@\d+\.\d+\.\d+\/build\/three\.module\.js$/.test(map.imports?.three), 'Three must be pinned ESM via jsdelivr importmap');
check(map.imports?.['three/addons/'] === map.imports?.three?.replace('build/three.module.js', 'examples/jsm/'), 'addons must use the same Three version');
const fx = read('battle-fx.js');
check(/import\('three'\)/.test(fx) && /catch\s*\{/.test(fx), 'Three import must be optional and guarded');
check(!/setAnimationLoop\(/.test(fx), '3D must not use a continuous animation loop');
check(/renderer\?\.dispose\(/.test(fx) && /resource\.dispose\?\.\(/.test(fx), 'renderer and tracked resources must be disposed');
const pkg = JSON.parse(read('package.json'));
check(!Object.keys({ ...pkg.dependencies, ...pkg.devDependencies }).length, 'zero-build project must not gain package dependencies');
console.log(`UI audit: ${checks} checks, ${failures.length} errors`);
failures.forEach((failure) => console.error(`- ${failure}`));
process.exitCode = failures.length ? 1 : 0;
