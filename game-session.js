import {
  basicAttack,
  deserializeGame,
  endTurn,
  levelUpUnit,
  mulliganCard,
  passResponse,
  playCard,
  resolveDivinationChoice,
  serializeGame,
} from './game-core.js?v=0e568c45';

export const COMMAND_JOURNAL_VERSION = 1;
export const SESSION_SAVE_VERSION = 1;
export const REPLAY_CHECKPOINT_INTERVAL = 20;
export const REPLAY_FRAME_CACHE_LIMIT = 12;

const COMMAND_TYPES = new Set([
  'play-card',
  'level-up',
  'attack',
  'mulligan',
  'end-turn',
  'pass-response',
  'divination-choice',
]);

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function requiredString(command, field) {
  if (typeof command[field] !== 'string' || !command[field]) {
    throw new Error(`命令 ${command.type} 缺少有效字段 ${field}。`);
  }
  return command[field];
}

function optionalTargetId(command) {
  if (command.targetId === undefined || command.targetId === null) return null;
  if (typeof command.targetId !== 'string' || !command.targetId) {
    throw new Error(`命令 ${command.type} 的 targetId 无效。`);
  }
  return command.targetId;
}

function normalizeCommand(command, sequence = undefined) {
  if (!command || typeof command !== 'object' || Array.isArray(command)) {
    throw new Error('命令记录必须是对象。');
  }
  if (!COMMAND_TYPES.has(command.type)) throw new Error(`未知命令类型：${String(command.type)}。`);
  if (command.playerIndex !== 0 && command.playerIndex !== 1) throw new Error('命令玩家索引无效。');

  const normalized = {
    sequence: sequence ?? command.sequence,
    type: command.type,
    playerIndex: command.playerIndex,
  };
  if (!Number.isInteger(normalized.sequence) || normalized.sequence <= 0) {
    throw new Error('命令序号无效。');
  }
  if (command.type === 'play-card') {
    normalized.instanceId = requiredString(command, 'instanceId');
    normalized.targetId = optionalTargetId(command);
  } else if (command.type === 'attack') {
    normalized.unitId = requiredString(command, 'unitId');
    normalized.targetId = optionalTargetId(command);
  } else if (command.type === 'level-up') {
    normalized.unitId = requiredString(command, 'unitId');
  } else if (command.type === 'mulligan') {
    normalized.instanceId = requiredString(command, 'instanceId');
  } else if (command.type === 'divination-choice') {
    normalized.instanceId = requiredString(command, 'instanceId');
  }
  return normalized;
}

function assertJournal(journal) {
  if (!journal || typeof journal !== 'object' || Array.isArray(journal)) {
    throw new Error('命令日志结构无效。');
  }
  if (journal.version !== COMMAND_JOURNAL_VERSION) {
    throw new Error(`不支持的命令日志版本：${String(journal.version)}。`);
  }
  deserializeGame(journal.initialGame);
  if (!Array.isArray(journal.commands)) throw new Error('命令日志缺少 commands 数组。');
  journal.commands.forEach((command, index) => {
    const normalized = normalizeCommand(command);
    if (normalized.sequence !== index + 1) throw new Error('命令日志序号不连续。');
    if (JSON.stringify(normalized) !== JSON.stringify(command)) throw new Error('命令日志包含未声明字段。');
  });
}

export function createCommandJournal(initialState) {
  return {
    version: COMMAND_JOURNAL_VERSION,
    initialGame: serializeGame(initialState),
    commands: [],
  };
}

export function appendCommand(journal, command) {
  assertJournal(journal);
  const normalized = normalizeCommand(command, journal.commands.length + 1);
  return {
    ...clone(journal),
    commands: [...clone(journal.commands), normalized],
  };
}

export function applyRecordedCommand(state, command) {
  const normalized = normalizeCommand(command);
  if (normalized.type === 'play-card') {
    return playCard(state, normalized.playerIndex, normalized.instanceId, normalized.targetId);
  }
  if (normalized.type === 'level-up') return levelUpUnit(state, normalized.playerIndex, normalized.unitId);
  if (normalized.type === 'mulligan') return mulliganCard(state, normalized.playerIndex, normalized.instanceId);
  if (normalized.type === 'attack') return basicAttack(state, normalized.playerIndex, normalized.unitId, normalized.targetId);
  if (normalized.type === 'end-turn') return endTurn(state, normalized.playerIndex);
  if (normalized.type === 'pass-response') return passResponse(state, normalized.playerIndex);
  return resolveDivinationChoice(state, normalized.playerIndex, normalized.instanceId);
}

export function replayCommandJournal(journal) {
  assertJournal(journal);
  let state = deserializeGame(journal.initialGame);
  journal.commands.forEach((command) => {
    const result = applyRecordedCommand(state, command);
    if (result.error) throw new Error(`命令 ${command.sequence} 无法重放：${result.error}`);
    state = result.state;
  });
  return state;
}

export function createCommandReplay(journal, options = {}) {
  assertJournal(journal);
  const checkpointInterval = options.checkpointInterval ?? REPLAY_CHECKPOINT_INTERVAL;
  const cacheLimit = options.cacheLimit ?? REPLAY_FRAME_CACHE_LIMIT;
  if (!Number.isInteger(checkpointInterval) || checkpointInterval <= 0) {
    throw new Error('回放检查点间隔必须是正整数。');
  }
  if (!Number.isInteger(cacheLimit) || cacheLimit < 2) {
    throw new Error('回放帧缓存上限不能小于 2。');
  }

  const commands = clone(journal.commands);
  const initialFrame = { sequence: 0, command: null, game: journal.initialGame };
  const checkpoints = new Map([[0, initialFrame]]);
  const frameCache = new Map([[0, initialFrame]]);
  let replayedCommands = 0;

  if (options.finalState !== undefined) {
    const finalGame = serializeGame(options.finalState);
    const sequence = commands.length;
    frameCache.set(sequence, {
      sequence,
      command: sequence === 0 ? null : clone(commands[sequence - 1]),
      game: finalGame,
    });
  }

  function cacheFrame(frame) {
    frameCache.delete(frame.sequence);
    frameCache.set(frame.sequence, frame);
    while (frameCache.size > cacheLimit) {
      frameCache.delete(frameCache.keys().next().value);
    }
  }

  function nearestFrame(sequence) {
    let nearest = checkpoints.get(0);
    checkpoints.forEach((frame, frameSequence) => {
      if (frameSequence <= sequence && frameSequence > nearest.sequence) nearest = frame;
    });
    frameCache.forEach((frame, frameSequence) => {
      if (frameSequence <= sequence && frameSequence > nearest.sequence) nearest = frame;
    });
    return nearest;
  }

  function getFrame(sequence) {
    if (!Number.isInteger(sequence) || sequence < 0 || sequence > commands.length) {
      throw new Error(`回放帧序号无效：${String(sequence)}。`);
    }
    const cached = frameCache.get(sequence) ?? checkpoints.get(sequence);
    if (cached) {
      cacheFrame(cached);
      return clone(cached);
    }

    const origin = nearestFrame(sequence);
    let state = deserializeGame(origin.game);
    let frame = origin;
    for (let index = origin.sequence; index < sequence; index += 1) {
      const command = commands[index];
      const result = applyRecordedCommand(state, command);
      if (result.error) throw new Error(`命令 ${command.sequence} 无法重放：${result.error}`);
      state = result.state;
      replayedCommands += 1;
      frame = { sequence: command.sequence, command: clone(command), game: serializeGame(state) };
      if (frame.sequence % checkpointInterval === 0) checkpoints.set(frame.sequence, frame);
    }
    cacheFrame(frame);
    return clone(frame);
  }

  return Object.freeze({
    length: commands.length + 1,
    getFrame,
    getStats: () => ({
      cacheLimit,
      cachedFrames: frameCache.size,
      checkpointInterval,
      checkpoints: checkpoints.size,
      replayedCommands,
    }),
  });
}

export function createCommandReplayFrames(journal) {
  const replay = createCommandReplay(journal);
  return Array.from({ length: replay.length }, (_, sequence) => replay.getFrame(sequence));
}

export function createSessionSave(state, journal, savedAt = new Date().toISOString()) {
  if (typeof savedAt !== 'string' || Number.isNaN(Date.parse(savedAt))) throw new Error('存档时间无效。');
  const replayed = replayCommandJournal(journal);
  const currentGame = serializeGame(state);
  if (serializeGame(replayed) !== currentGame) throw new Error('当前对局与命令日志不一致，拒绝保存。');
  return JSON.stringify({
    version: SESSION_SAVE_VERSION,
    savedAt,
    game: currentGame,
    journal: clone(journal),
  });
}

export function restoreSessionSave(json) {
  if (typeof json !== 'string') throw new Error('本地存档必须是 JSON 字符串。');
  let envelope;
  try {
    envelope = JSON.parse(json);
  } catch {
    throw new Error('本地存档不是有效的 JSON。');
  }
  if (!envelope || typeof envelope !== 'object' || Array.isArray(envelope)) throw new Error('本地存档结构无效。');
  if (envelope.version !== SESSION_SAVE_VERSION) {
    throw new Error(`不支持的本地存档版本：${String(envelope.version)}。`);
  }
  if (typeof envelope.savedAt !== 'string' || Number.isNaN(Date.parse(envelope.savedAt))) throw new Error('本地存档时间无效。');
  const state = deserializeGame(envelope.game);
  const replayed = replayCommandJournal(envelope.journal);
  if (serializeGame(replayed) !== serializeGame(state)) throw new Error('本地存档与命令日志不一致。');
  return {
    state,
    journal: clone(envelope.journal),
    savedAt: envelope.savedAt,
  };
}
