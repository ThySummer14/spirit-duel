import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

test('parity harness ships neutral samples and compare tool', () => {
  assert.ok(existsSync(join(root, 'scripts/godot-parity.sh')));
  assert.ok(existsSync(join(root, 'scripts/parity/run-js.mjs')));
  assert.ok(existsSync(join(root, 'scripts/parity/compare.mjs')));
  assert.ok(existsSync(join(root, 'godot/scripts/parity_run.gd')));
  for (const name of ['sample-origin.json', 'sample-keywords.json']) {
    const sample = JSON.parse(readFileSync(join(root, 'scripts/parity', name), 'utf8'));
    assert.equal(sample.version, 1);
    assert.ok(Array.isArray(sample.commands) && sample.commands.length > 0);
    assert.ok(Number.isFinite(sample.seed));
    assert.equal(sample.lineupA.length, 4);
  }
});

test('parity snapshots after a match run stay consistent when present', () => {
  const reportPath = join(root, 'scripts/parity/out/sample-origin-report.json');
  if (!existsSync(reportPath)) return; // 本地未跑对拍时跳过
  const report = JSON.parse(readFileSync(reportPath, 'utf8'));
  assert.equal(report.match, true, JSON.stringify(report.summary));
  assert.equal(report.summary.finalDiffCount, 0);
});
