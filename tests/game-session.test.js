import test from 'node:test';
import assert from 'node:assert/strict';

import { createGame, serializeGame } from '../game-core.js';
import {
  appendCommand,
  applyRecordedCommand,
  createCommandReplayFrames,
  createCommandJournal,
  createSessionSave,
  replayCommandJournal,
  restoreSessionSave,
} from '../game-session.js';

function applyAndRecord(state, journal, command) {
  const nextJournal = appendCommand(journal, command);
  const result = applyRecordedCommand(state, nextJournal.commands.at(-1));
  assert.equal(result.error, null);
  return { state: result.state, journal: nextJournal };
}

test('replays a mixed player and AI command journal to the exact deterministic state', () => {
  const initial = createGame(801);
  let state = initial;
  let journal = createCommandJournal(initial);
  ({ state, journal } = applyAndRecord(state, journal, {
    type: 'level-up', playerIndex: 0, unitId: state.players[0].units[1].uid,
  }));
  ({ state, journal } = applyAndRecord(state, journal, {
    type: 'attack', playerIndex: 0, unitId: state.players[0].frontUnitId, targetId: null,
  }));
  ({ state, journal } = applyAndRecord(state, journal, { type: 'end-turn', playerIndex: 0 }));
  ({ state, journal } = applyAndRecord(state, journal, {
    type: 'level-up', playerIndex: 1, unitId: state.players[1].units[2].uid,
  }));
  ({ state, journal } = applyAndRecord(state, journal, { type: 'end-turn', playerIndex: 1 }));

  assert.equal(journal.commands.length, 5);
  assert.deepEqual(journal.commands.map((command) => command.sequence), [1, 2, 3, 4, 5]);
  assert.equal(serializeGame(replayCommandJournal(journal)), serializeGame(state));
});

test('builds immutable replay frames from the initial state through every command', () => {
  const initial = createGame(804);
  let state = initial;
  let journal = createCommandJournal(initial);
  ({ state, journal } = applyAndRecord(state, journal, {
    type: 'level-up', playerIndex: 0, unitId: state.players[0].units[0].uid,
  }));
  const afterLevel = state;
  ({ state, journal } = applyAndRecord(state, journal, {
    type: 'attack', playerIndex: 0, unitId: state.players[0].frontUnitId, targetId: null,
  }));

  const frames = createCommandReplayFrames(journal);
  assert.deepEqual(frames.map((frame) => frame.sequence), [0, 1, 2]);
  assert.equal(frames[0].command, null);
  assert.equal(frames[0].game, serializeGame(initial));
  assert.equal(frames[1].game, serializeGame(afterLevel));
  assert.equal(frames[2].game, serializeGame(state));
  assert.notStrictEqual(frames[1].command, journal.commands[0]);

  frames[1].command.unitId = 'tampered';
  assert.notEqual(journal.commands[0].unitId, 'tampered');
  const tamperedFrame = JSON.parse(frames[1].game);
  tamperedFrame.state.players[0].avatarHp = 1;
  assert.equal(JSON.parse(frames[2].game).state.players[0].avatarHp, initial.players[0].avatarHp);
});

test('round-trips a session save with current state, initial snapshot, and command journal', () => {
  const initial = createGame(802);
  let journal = createCommandJournal(initial);
  journal = appendCommand(journal, {
    type: 'level-up', playerIndex: 0, unitId: initial.players[0].units[0].uid,
  });
  const state = applyRecordedCommand(initial, journal.commands[0]).state;
  const json = createSessionSave(state, journal, '2026-07-27T12:00:00.000Z');
  const restored = restoreSessionSave(json);

  assert.equal(restored.savedAt, '2026-07-27T12:00:00.000Z');
  assert.equal(serializeGame(restored.state), serializeGame(state));
  assert.deepEqual(restored.journal, journal);
});

test('rejects malformed commands and state-journal mismatches', () => {
  const initial = createGame(803);
  const journal = createCommandJournal(initial);
  assert.throws(
    () => appendCommand(journal, { type: 'attack', playerIndex: 0, unitId: '', targetId: null }),
    /缺少有效字段 unitId/,
  );

  const changed = structuredClone(initial);
  changed.players[0].avatarHp -= 1;
  assert.throws(() => createSessionSave(changed, journal), /命令日志不一致/);

  const valid = JSON.parse(createSessionSave(initial, journal, '2026-07-27T12:00:00.000Z'));
  valid.journal.commands.push({ sequence: 2, type: 'end-turn', playerIndex: 0 });
  assert.throws(() => restoreSessionSave(JSON.stringify(valid)), /序号不连续/);
});
