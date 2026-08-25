#!/usr/bin/env node
/**
 * bump-cache.mjs — 按内容哈希自动同步所有缓存版本参数
 *
 * - 对全部 *.js、*.css 与 index.html 的内容做 SHA-256，取前 8 位作为版本号
 * - 重写 index.html 的 href/src 与各模块 `from './x.js'` 导入中的 ?v= 参数
 * - 任何文件内容变化都会使整体版本号变化，浏览器缓存随之失效
 *
 * 用法：node scripts/bump-cache.mjs（或 npm run cache:sync）
 */
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

const jsFiles = readdirSync(root).filter((name) => name.endsWith('.js'));
const cssFiles = ['styles.css', 'formation.css'].filter((name) => {
  try { readFileSync(join(root, name)); return true; } catch { return false; }
});
const htmlFiles = ['index.html'];

const hash = createHash('sha256');
for (const name of [...jsFiles, ...cssFiles, ...htmlFiles]) {
  // 剥离已有版本参数后再哈希，避免「版本号写入文件 → 哈希变化」的自引用抖动
  hash.update(readFileSync(join(root, name), 'utf8').replace(/\?v=[a-z0-9]+/g, ''));
}
const version = hash.digest('hex').slice(0, 8);

let touched = 0;
for (const name of [...jsFiles, ...htmlFiles]) {
  const path = join(root, name);
  const src = readFileSync(path, 'utf8');
  let next = src.replace(/\?v=[a-z0-9]+/g, `?v=${version}`);
  if (name === 'index.html') {
    next = next.replace(/(<meta name="build" content=")[^"]*(" \/>)/, `$1${version}$2`);
  }
  // 兜底：新写的相对导入可能漏掉版本参数
  next = next.replace(/(from '\.\/[a-z-]+\.js)(?!\?v=)/g, `$1?v=${version}`);
  if (next !== src) {
    writeFileSync(path, next);
    touched += 1;
    console.log(`synced ${name} -> ?v=${version}`);
  }
}
if (touched === 0) console.log(`all imports already at ?v=${version}`);
