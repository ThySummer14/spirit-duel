import test from 'node:test';
import assert from 'node:assert/strict';

import { createGame, serializeGame } from '../game-core.js';
import {
  appendCommand,
  applyRecordedCommand,
  createCommandReplay,
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
    type: 'attack', playerIndex: 0, unitId: state.players[0].units[2].uid, targetId: null,
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
    type: 'attack', playerIndex: 0, unitId: state.players[0].units[2].uid, targetId: null,
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

test('lazily replays from bounded frame caches and reusable checkpoints', () => {
  const initial = createGame(805);
  for (let playerIndex = 0; playerIndex < 2; playerIndex += 1) {
    for (let index = 0; index < 80; index += 1) {
      initial.players[playerIndex].deck.unshift({
        instanceId: `long-${playerIndex}-${index}`,
        definitionId: 'cinder-mark',
      });
    }
  }
  let state = initial;
  const journal = createCommandJournal(initial);
  for (let sequence = 1; sequence <= 60; sequence += 1) {
    const command = { sequence, type: 'end-turn', playerIndex: state.currentPlayer };
    journal.commands.push(command);
    const result = applyRecordedCommand(state, command);
    assert.equal(result.error, null);
    state = result.state;
  }

  const replay = createCommandReplay(journal, { checkpointInterval: 10, cacheLimit: 4 });
  assert.deepEqual(replay.getStats(), {
    cacheLimit: 4,
    cachedFrames: 1,
    checkpointInterval: 10,
    checkpoints: 1,
    replayedCommands: 0,
  });

  assert.equal(replay.getFrame(35).sequence, 35);
  assert.equal(replay.getStats().replayedCommands, 35);
  assert.equal(replay.getStats().checkpoints, 4);
  assert.equal(replay.getFrame(38).sequence, 38);
  assert.equal(replay.getStats().replayedCommands, 38);
  assert.equal(replay.getFrame(21).sequence, 21);
  assert.equal(replay.getStats().replayedCommands, 39);
  assert.ok(replay.getStats().cachedFrames <= 4);
  assert.equal(replay.getFrame(60).game, serializeGame(state));
});

test('accepts a validated final-state seed without eagerly replaying the journal', () => {
  const initial = createGame(806);
  let state = initial;
  const journal = createCommandJournal(initial);
  for (let sequence = 1; sequence <= 4; sequence += 1) {
    const command = { sequence, type: 'end-turn', playerIndex: state.currentPlayer };
    journal.commands.push(command);
    state = applyRecordedCommand(state, command).state;
  }

  const replay = createCommandReplay(journal, { finalState: state });
  assert.equal(replay.getStats().replayedCommands, 0);
  assert.equal(replay.getFrame(4).game, serializeGame(state));
  assert.equal(replay.getStats().replayedCommands, 0);
  assert.throws(() => replay.getFrame(5), /回放帧序号无效/);
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
  const unsupported = structuredClone(valid);
  unsupported.version = 999;
  assert.throws(() => restoreSessionSave(JSON.stringify(unsupported)), /不支持的本地存档版本/);

  const altered = structuredClone(valid);
  const alteredGame = JSON.parse(altered.game);
  alteredGame.state.players[0].avatarHp -= 1;
  altered.game = JSON.stringify(alteredGame);
  assert.throws(() => restoreSessionSave(JSON.stringify(altered)), /本地存档与命令日志不一致/);

  valid.journal.commands.push({ sequence: 2, type: 'end-turn', playerIndex: 0 });
  assert.throws(() => restoreSessionSave(JSON.stringify(valid)), /序号不连续/);
});
