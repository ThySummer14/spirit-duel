#!/usr/bin/env node
/**
 * 比对 JS / Godot 快照
 * 用法: node scripts/parity/compare.mjs out/js.json out/godot.json
 */
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';

function flatten(obj, prefix = '', out = {}) {
  if (obj === null || typeof obj !== 'object') {
    out[prefix || '$'] = obj;
    return out;
  }
  if (Array.isArray(obj)) {
    obj.forEach((item, index) => flatten(item, `${prefix}[${index}]`, out));
    return out;
  }
  for (const [key, value] of Object.entries(obj)) {
    flatten(value, prefix ? `${prefix}.${key}` : key, out);
  }
  return out;
}

const [, , jsPath, godotPath, reportPath] = process.argv;
const js = JSON.parse(readFileSync(jsPath, 'utf8'));
const godot = JSON.parse(readFileSync(godotPath, 'utf8'));
const a = flatten(js.snapshot);
const b = flatten(godot.snapshot);
const keys = [...new Set([...Object.keys(a), ...Object.keys(b)])].sort();
const diffs = [];
for (const key of keys) {
  const av = a[key];
  const bv = b[key];
  if (av !== bv) diffs.push({ key, js: av ?? null, godot: bv ?? null });
}

const stepDiffs = [];
const maxSteps = Math.max(js.steps?.length ?? 0, godot.steps?.length ?? 0);
for (let i = 0; i < maxSteps; i += 1) {
  const sa = js.steps?.[i];
  const sb = godot.steps?.[i];
  if (!sa || !sb) {
    stepDiffs.push({ seq: sa?.seq ?? sb?.seq, reason: 'missing-step', js: sa?.type, godot: sb?.type });
    continue;
  }
  if (sa.ok !== sb.ok) {
    stepDiffs.push({ seq: sa.seq, type: sa.type, jsOk: sa.ok, godotOk: sb.ok, jsError: sa.error ?? null });
    continue;
  }
  if (sa.ok && sb.ok) {
    const fa = flatten(sa.after);
    const fb = flatten(sb.after);
    const local = [];
    for (const key of new Set([...Object.keys(fa), ...Object.keys(fb)])) {
      if ((fa[key] ?? null) !== (fb[key] ?? null)) {
        local.push({ key, js: fa[key] ?? null, godot: fb[key] ?? null });
      }
    }
    if (local.length) stepDiffs.push({ seq: sa.seq, type: sa.type, fields: local.slice(0, 12), total: local.length });
  }
}

const report = {
  sample: js.sample,
  seed: js.seed,
  match: diffs.length === 0 && stepDiffs.length === 0,
  finalDiffs: diffs,
  stepDiffs,
  summary: {
    finalDiffCount: diffs.length,
    stepDiffCount: stepDiffs.length,
    jsSteps: js.steps?.length ?? 0,
    godotSteps: godot.steps?.length ?? 0,
  },
};
if (reportPath) {
  mkdirSync(dirname(reportPath), { recursive: true });
  writeFileSync(reportPath, JSON.stringify(report, null, 2) + '\n');
}
if (report.match) {
  console.log(`PARITY_MATCH sample=${js.sample} steps=${report.summary.jsSteps}`);
  process.exit(0);
}
console.log(`PARITY_DIFF sample=${js.sample} final=${diffs.length} steps=${stepDiffs.length}`);
for (const d of diffs.slice(0, 20)) console.log(`  final ${d.key}: js=${d.js} godot=${d.godot}`);
for (const d of stepDiffs.slice(0, 12)) console.log('  step', JSON.stringify(d).slice(0, 240));
process.exit(1);
