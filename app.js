import {
  DEFAULT_PLAYER_LINEUP,
  GAME_RULES,
  UNIT_DEFINITIONS,
  basicAttack,
  canPlayCard,
  createDefaultDeckDefinition,
  createGame,
  deserializeGame,
  endTurn,
  getCardDefinition,
  getCardPlayability,
  getCardsForUnit,
  getEffectiveCardCost,
  getFormation,
  getKeywordCostReductionLabel,
  getPlayerKeywordStatuses,
  getUnitKeywordStatuses,
  getKeywordStatusText,
  getRound,
  getUnitDefinition,
  getValidCombatTargets,
  getValidTargets,
  levelUpUnit,
  passResponse,
  playCard,
  resolveDivinationChoice,
  serializeGame,
  validateDeckDefinition,
} from './game-core.js';
import { chooseAiCommand } from './game-ai.js';
import {
  captureBattleSnapshot,
  deriveBattleFeedback,
} from './game-presentation.js';
import {
  appendCommand,
  createCommandReplay,
  createCommandJournal,
  createSessionSave,
  restoreSessionSave,
} from './game-session.js';

const LOCAL_SAVE_KEY = 'nexus-front:session-slot-1';
const MAX_REPLAY_FILE_BYTES = 5 * 1024 * 1024;
const REPLAY_SOURCE_LABELS = Object.freeze({
  current: 'CURRENT',
  saved: 'SAVED SLOT',
  imported: 'IMPORTED FILE',
});

const nodes = {
  gameShell: document.querySelector('#game-shell'),
  formationScreen: document.querySelector('#formation-screen'),
  formationRoster: document.querySelector('#formation-roster'),
  rosterLibrary: document.querySelector('#roster-library'),
  deckBuilder: document.querySelector('#deck-builder'),
  lineupStepButton: document.querySelector('#lineup-step-button'),
  deckStepButton: document.querySelector('#deck-step-button'),
  deckUnitTabs: document.querySelector('#deck-unit-tabs'),
  passiveDossier: document.querySelector('#passive-dossier'),
  cardPool: document.querySelector('#card-pool'),
  activeDeckCount: document.querySelector('#active-deck-count'),
  formationSlots: document.querySelector('#formation-slots'),
  formationCount: document.querySelector('#formation-count'),
  formationUnitCount: document.querySelector('#formation-unit-count'),
  formationDeckCount: document.querySelector('#formation-deck-count'),
  formationError: document.querySelector('#formation-error'),
  formationStartButton: document.querySelector('#formation-start-button'),
  formationStartKicker: document.querySelector('#formation-start-kicker'),
  formationStartLabel: document.querySelector('#formation-start-label'),
  formationCancelButton: document.querySelector('#formation-cancel-button'),
  formationButton: document.querySelector('#formation-button'),
  battleStage: document.querySelector('.battle-stage'),
  battleFeedback: document.querySelector('#battle-feedback'),
  turnOwner: document.querySelector('#turn-owner'),
  round: document.querySelector('#round-value'),
  turnState: document.querySelector('#turn-state'),
  turnStateCode: document.querySelector('#turn-state-code'),
  turnStateKicker: document.querySelector('#turn-state-kicker'),
  turnStateLabel: document.querySelector('#turn-state-label'),
  turnCallout: document.querySelector('#turn-callout'),
  turnCalloutKicker: document.querySelector('#turn-callout-kicker'),
  turnCalloutLabel: document.querySelector('#turn-callout-label'),
  turnCalloutDetail: document.querySelector('#turn-callout-detail'),
  actionPrompt: document.querySelector('#action-prompt'),
  recentEvent: document.querySelector('#recent-event'),
  playerUnits: document.querySelector('#player-units'),
  enemyUnits: document.querySelector('#enemy-units'),
  playerHand: document.querySelector('#player-hand'),
  playerCoreHp: document.querySelector('#player-core-hp'),
  playerCoreBar: document.querySelector('#player-core-bar'),
  playerCore: document.querySelector('.player-core'),
  playerEnergy: document.querySelector('#player-energy'),
  playerMaxEnergy: document.querySelector('#player-max-energy'),
  keywordStatuses: document.querySelector('#keyword-statuses'),
  playerDeck: document.querySelector('#player-deck'),
  playerHandCount: document.querySelector('#player-hand-count'),
  enemyCoreHp: document.querySelector('#enemy-core-hp'),
  enemyCoreBar: document.querySelector('#enemy-core-bar'),
  enemyCore: document.querySelector('.enemy-core'),
  enemyEnergy: document.querySelector('#enemy-energy'),
  enemyDeck: document.querySelector('#enemy-deck'),
  enemyHand: document.querySelector('#enemy-hand'),
  attackButton: document.querySelector('#attack-button'),
  attackLabel: document.querySelector('#attack-label'),
  levelButton: document.querySelector('#level-button'),
  levelLabel: document.querySelector('#level-label'),
  cancelActionButton: document.querySelector('#cancel-action-button'),
  endTurnButton: document.querySelector('#end-turn-button'),
  energyPips: document.querySelector('#energy-pips'),
  playableCardCount: document.querySelector('#playable-card-count'),
  battleLogButton: document.querySelector('#battle-log-button'),
  battleLogDialog: document.querySelector('#battle-log-dialog'),
  logButtonCount: document.querySelector('#log-button-count'),
  logList: document.querySelector('#log-list'),
  logCount: document.querySelector('#log-count'),
  rulesButton: document.querySelector('#rules-button'),
  rulesDialog: document.querySelector('#rules-dialog'),
  sessionButton: document.querySelector('#session-button'),
  sessionDialog: document.querySelector('#session-dialog'),
  sessionCloseButton: document.querySelector('#session-close-button'),
  sessionStatus: document.querySelector('#session-status'),
  sessionCurrentRound: document.querySelector('#session-current-round'),
  sessionCommandCount: document.querySelector('#session-command-count'),
  sessionSavedAt: document.querySelector('#session-saved-at'),
  sessionSaveButton: document.querySelector('#session-save-button'),
  sessionLoadButton: document.querySelector('#session-load-button'),
  sessionReplayCurrentButton: document.querySelector('#session-replay-current-button'),
  sessionReplaySavedButton: document.querySelector('#session-replay-saved-button'),
  sessionExportCurrentButton: document.querySelector('#session-export-current-button'),
  sessionExportSavedButton: document.querySelector('#session-export-saved-button'),
  sessionImportButton: document.querySelector('#session-import-button'),
  sessionImportInput: document.querySelector('#session-import-input'),
  replayController: document.querySelector('#replay-controller'),
  replaySource: document.querySelector('#replay-source'),
  replayCommandLabel: document.querySelector('#replay-command-label'),
  replayStep: document.querySelector('#replay-step'),
  replayTotal: document.querySelector('#replay-total'),
  replayFirstButton: document.querySelector('#replay-first-button'),
  replayPreviousButton: document.querySelector('#replay-previous-button'),
  replayPlayButton: document.querySelector('#replay-play-button'),
  replayNextButton: document.querySelector('#replay-next-button'),
  replayLastButton: document.querySelector('#replay-last-button'),
  replayExitButton: document.querySelector('#replay-exit-button'),
  replayScrubber: document.querySelector('#replay-scrubber'),
  replayTimeline: document.querySelector('#replay-timeline'),
  divinationDialog: document.querySelector('#divination-dialog'),
  divinationOptions: document.querySelector('#divination-options'),
  restartButton: document.querySelector('#restart-button'),
  resultDialog: document.querySelector('#result-dialog'),
  resultCode: document.querySelector('#result-code'),
  resultTitle: document.querySelector('#result-title'),
  resultSummary: document.querySelector('#result-summary'),
  resultRounds: document.querySelector('#result-rounds'),
  resultCards: document.querySelector('#result-cards'),
  resultDamage: document.querySelector('#result-damage'),
  rematchButton: document.querySelector('#rematch-button'),
  inspectButton: document.querySelector('#inspect-button'),
  toast: document.querySelector('#toast'),
};

let selectedLineup = [...DEFAULT_PLAYER_LINEUP];
let deckSelections = new Map(UNIT_DEFINITIONS.map((unit) => [unit.id, createDefaultDeckDefinition([unit.id]).cardIds]));
let activeDeckUnitId = selectedLineup[0];
let formationStep = 'lineup';
let lockedPlayerDeckDefinition = createDefaultDeckDefinition(selectedLineup);
let game = createGame({ playerDeckDefinition: lockedPlayerDeckDefinition });
let displayedGame = game;
let commandJournal = createCommandJournal(game);
let replaySession = null;
let battleStarted = false;
let selectedCardId = null;
let selectedAttackUnitId = game.players[0].frontUnitId;
let aiBusy = false;
let gameSession = 1;
let toastTimer = null;
let resultShown = false;
let resultTimer = null;
let previousVisualState = null;
let visualFeedback = {
  unitImpacts: new Map(),
  coreImpacts: new Map(),
  realmImpacts: new Map(),
  cue: null,
};
let announcedTurnCounter = 0;
let turnCalloutTimer = null;
let feedbackClearTimer = null;
let draggedAttackUnitId = null;

const wait = (duration) => new Promise((resolve) => setTimeout(resolve, duration));

function emptyVisualFeedback() {
  return {
    unitImpacts: new Map(),
    coreImpacts: new Map(),
    realmImpacts: new Map(),
    cue: null,
  };
}

function announce(message, tone = 'neutral') {
  clearTimeout(toastTimer);
  nodes.toast.textContent = message;
  nodes.toast.dataset.tone = tone;
  nodes.toast.dataset.visible = 'true';
  toastTimer = setTimeout(() => { nodes.toast.dataset.visible = 'false'; }, 2200);
}

function recordCommand(command) {
  commandJournal = appendCommand(commandJournal, command);
}

function readLocalSave() {
  try {
    return { raw: localStorage.getItem(LOCAL_SAVE_KEY), error: null };
  } catch {
    return { raw: null, error: '当前浏览器禁止读取本地存储。' };
  }
}

function formatSavedAt(value) {
  return new Intl.DateTimeFormat('zh-CN', {
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(new Date(value));
}

function renderSessionDialog() {
  nodes.sessionCurrentRound.textContent = String(getRound(game)).padStart(2, '0');
  nodes.sessionCommandCount.textContent = commandJournal.commands.length;
  nodes.sessionSaveButton.disabled = aiBusy || !battleStarted;
  nodes.sessionReplayCurrentButton.disabled = aiBusy || !battleStarted || commandJournal.commands.length === 0;
  nodes.sessionExportCurrentButton.disabled = aiBusy || !battleStarted || commandJournal.commands.length === 0;
  nodes.sessionImportButton.disabled = aiBusy;
  const stored = readLocalSave();
  nodes.sessionLoadButton.disabled = true;
  nodes.sessionReplaySavedButton.disabled = true;
  nodes.sessionExportSavedButton.disabled = true;
  delete nodes.sessionStatus.dataset.state;
  nodes.sessionSavedAt.textContent = '未创建';
  if (stored.error) {
    nodes.sessionStatus.textContent = stored.error;
    nodes.sessionStatus.dataset.state = 'error';
    return;
  }
  if (!stored.raw) {
    nodes.sessionStatus.textContent = '当前没有本地存档。';
    return;
  }
  try {
    const restored = restoreSessionSave(stored.raw);
    nodes.sessionStatus.textContent = `存档可用：第 ${getRound(restored.state)} 回合，${restored.journal.commands.length} 条命令。`;
    nodes.sessionStatus.dataset.state = 'ready';
    nodes.sessionSavedAt.textContent = formatSavedAt(restored.savedAt);
    nodes.sessionLoadButton.disabled = aiBusy;
    nodes.sessionReplaySavedButton.disabled = aiBusy || restored.journal.commands.length === 0;
    nodes.sessionExportSavedButton.disabled = aiBusy || restored.journal.commands.length === 0;
  } catch (error) {
    nodes.sessionStatus.textContent = `存档损坏：${error.message}`;
    nodes.sessionStatus.dataset.state = 'error';
  }
}

function syncFormationFromJournal() {
  const initialState = deserializeGame(commandJournal.initialGame);
  const player = initialState.players[0];
  const allInstances = [...player.hand, ...player.deck];
  selectedLineup = player.units.map((unit) => unit.id);
  lockedPlayerDeckDefinition = {
    unitIds: [...selectedLineup],
    cardIds: allInstances.map((instance) => instance.definitionId),
  };
  deckSelections = new Map(UNIT_DEFINITIONS.map((unit) => [
    unit.id,
    selectedLineup.includes(unit.id)
      ? allInstances
        .filter((instance) => getCardDefinition(instance.definitionId).unitId === unit.id)
        .map((instance) => instance.definitionId)
      : createDefaultDeckDefinition([unit.id]).cardIds,
  ]));
  activeDeckUnitId = selectedLineup[0];
  formationStep = 'deck';
}

function saveCurrentSession() {
  try {
    const json = createSessionSave(game, commandJournal);
    localStorage.setItem(LOCAL_SAVE_KEY, json);
    renderSessionDialog();
    announce('当前对局已保存到本地存档槽。', 'success');
  } catch (error) {
    nodes.sessionStatus.textContent = `保存失败：${error.message}`;
    nodes.sessionStatus.dataset.state = 'error';
    announce('本地存档保存失败。', 'danger');
  }
}

function replayFileName(savedAt) {
  const timestamp = new Date(savedAt).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
  return `spirit-duel-replay-${timestamp}.json`;
}

function downloadReplayFile(json) {
  const restored = restoreSessionSave(json);
  const formatted = `${JSON.stringify(JSON.parse(json), null, 2)}\n`;
  const url = URL.createObjectURL(new Blob([formatted], { type: 'application/json' }));
  const link = document.createElement('a');
  link.href = url;
  link.download = replayFileName(restored.savedAt);
  link.hidden = true;
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 0);
  return restored;
}

function exportCurrentReplay() {
  try {
    const restored = downloadReplayFile(createSessionSave(game, commandJournal));
    announce(`已导出 ${restored.journal.commands.length} 条命令。`, 'success');
  } catch (error) {
    nodes.sessionStatus.textContent = `导出失败：${error.message}`;
    nodes.sessionStatus.dataset.state = 'error';
    announce('当前回放导出失败。', 'danger');
  }
}

function exportSavedReplay() {
  const stored = readLocalSave();
  if (!stored.raw || stored.error) {
    renderSessionDialog();
    return;
  }
  try {
    const restored = downloadReplayFile(stored.raw);
    announce(`已导出存档中的 ${restored.journal.commands.length} 条命令。`, 'success');
  } catch (error) {
    nodes.sessionStatus.textContent = `导出失败：${error.message}`;
    nodes.sessionStatus.dataset.state = 'error';
    announce('存档回放导出失败。', 'danger');
  }
}

async function importReplayFile() {
  const [file] = nodes.sessionImportInput.files;
  nodes.sessionImportInput.value = '';
  if (!file) return;
  if (file.size > MAX_REPLAY_FILE_BYTES) {
    nodes.sessionStatus.textContent = '导入失败：JSON 文件超过 5 MB。';
    nodes.sessionStatus.dataset.state = 'error';
    announce('回放文件过大。', 'danger');
    return;
  }
  try {
    const restored = restoreSessionSave(await file.text());
    if (restored.journal.commands.length === 0) throw new Error('文件中没有可回放的命令。');
    if (startCommandReplay(restored.journal, 'imported', restored.state)) {
      announce(`已导入 ${restored.journal.commands.length} 条命令，当前对局保持不变。`, 'success');
    }
  } catch (error) {
    nodes.sessionStatus.textContent = `导入失败：${error.message}`;
    nodes.sessionStatus.dataset.state = 'error';
    announce('回放文件校验失败。', 'danger');
  }
}

function loadLocalSession() {
  const stored = readLocalSave();
  if (!stored.raw || stored.error) {
    renderSessionDialog();
    return;
  }
  try {
    const restored = restoreSessionSave(stored.raw);
    gameSession += 1;
    game = restored.state;
    commandJournal = restored.journal;
    syncFormationFromJournal();
    selectedCardId = null;
    selectedAttackUnitId = game.players[0].frontUnitId;
    aiBusy = aiHasControl();
    resultShown = false;
    clearTimeout(resultTimer);
    clearTimeout(feedbackClearTimer);
    previousVisualState = null;
    visualFeedback = emptyVisualFeedback();
    announcedTurnCounter = game.turnCounter;
    clearTimeout(turnCalloutTimer);
    battleStarted = true;
    if (nodes.resultDialog.open) nodes.resultDialog.close();
    nodes.sessionDialog.close();
    hideFormation();
    render();
    announce('本地存档已恢复。', 'success');
    if (aiBusy) runAiTurn(gameSession);
  } catch (error) {
    nodes.sessionStatus.textContent = `读取失败：${error.message}`;
    nodes.sessionStatus.dataset.state = 'error';
    announce('本地存档无法读取。', 'danger');
  }
}

function replayCardName(state, playerIndex, instanceId) {
  const player = state.players[playerIndex];
  const instance = [...player.hand, ...player.deck].find((candidate) => candidate.instanceId === instanceId);
  return instance ? getCardDefinition(instance.definitionId).name : '未知卡牌';
}

function replayTargetName(state, playerIndex, targetId) {
  if (!targetId) return null;
  for (const player of state.players) {
    const unit = unitByUid(player, targetId);
    if (unit) return unit.name;
    const realm = player.realms.find((candidate) => candidate.uid === targetId);
    if (realm) return realm.name;
  }
  return playerIndex === 0 ? '敌方目标' : '己方目标';
}

function describeReplayCommand(command, state) {
  const actor = command.playerIndex === 0 ? '巡界者' : '失序体';
  if (command.type === 'play-card') return `${actor}使用「${replayCardName(state, command.playerIndex, command.instanceId)}」`;
  if (command.type === 'level-up') {
    const unit = unitByUid(state.players[command.playerIndex], command.unitId);
    return `${actor}将${unit?.name ?? '角色'}提升勾玉`;
  }
  if (command.type === 'attack') {
    const unit = unitByUid(state.players[command.playerIndex], command.unitId);
    const target = replayTargetName(state, command.playerIndex, command.targetId);
    return `${unit?.name ?? actor}出击${target ? ` → ${target}` : ''}`;
  }
  if (command.type === 'end-turn') return `${actor}结束回合`;
  if (command.type === 'pass-response') return `${actor}放弃响应`;
  return `${actor}将「${replayCardName(state, command.playerIndex, command.instanceId)}」置于牌库顶`;
}

function stopReplayPlayback() {
  if (!replaySession) return;
  clearTimeout(replaySession.timer);
  replaySession.timer = null;
  replaySession.playing = false;
  nodes.replayPlayButton.textContent = '▶';
  nodes.replayPlayButton.setAttribute('aria-label', '自动播放');
  nodes.replayPlayButton.title = '自动播放';
}

function renderReplayController() {
  if (!replaySession) return;
  const total = replaySession.replay.length - 1;
  const current = replaySession.cursor;
  nodes.replaySource.textContent = `COMMAND REPLAY / ${REPLAY_SOURCE_LABELS[replaySession.source] ?? 'UNKNOWN'}`;
  nodes.replayCommandLabel.textContent = replaySession.labels[current];
  nodes.replayStep.textContent = current;
  nodes.replayTotal.textContent = total;
  nodes.replayScrubber.max = total;
  nodes.replayScrubber.value = current;
  nodes.replayFirstButton.disabled = current === 0;
  nodes.replayPreviousButton.disabled = current === 0;
  nodes.replayNextButton.disabled = current === total;
  nodes.replayLastButton.disabled = current === total;
  nodes.replayTimeline.querySelectorAll('button').forEach((button, index) => {
    if (index === current) button.setAttribute('aria-current', 'step');
    else button.removeAttribute('aria-current');
  });
}

function setReplayCursor(cursor, { keepPlaying = false } = {}) {
  if (!replaySession) return;
  const bounded = Math.max(0, Math.min(replaySession.replay.length - 1, Number(cursor)));
  if (!Number.isInteger(bounded) || bounded === replaySession.cursor) return;
  try {
    const movingForwardOne = bounded === replaySession.cursor + 1;
    const previousState = deserializeGame(replaySession.currentFrame.game);
    const nextFrame = replaySession.replay.getFrame(bounded);
    if (!keepPlaying) stopReplayPlayback();
    replaySession.previousVisualState = movingForwardOne ? captureBattleSnapshot(previousState) : null;
    replaySession.currentFrame = nextFrame;
    replaySession.cursor = bounded;
    renderReplayController();
    render();
    requestAnimationFrame(() => {
      nodes.replayTimeline.querySelector('[aria-current="step"]')?.scrollIntoView({ block: 'nearest', inline: 'center' });
    });
  } catch (error) {
    stopReplayPlayback();
    renderReplayController();
    announce(`回放跳转失败：${error.message}`, 'danger');
  }
}

function queueReplayStep() {
  if (!replaySession?.playing) return;
  replaySession.timer = setTimeout(() => {
    if (!replaySession?.playing) return;
    if (replaySession.cursor >= replaySession.replay.length - 1) {
      stopReplayPlayback();
      renderReplayController();
      return;
    }
    setReplayCursor(replaySession.cursor + 1, { keepPlaying: true });
    queueReplayStep();
  }, 1150);
}

function toggleReplayPlayback() {
  if (!replaySession) return;
  if (replaySession.playing) {
    stopReplayPlayback();
    renderReplayController();
    return;
  }
  if (replaySession.cursor === replaySession.replay.length - 1) setReplayCursor(0);
  replaySession.playing = true;
  nodes.replayPlayButton.textContent = 'Ⅱ';
  nodes.replayPlayButton.setAttribute('aria-label', '暂停播放');
  nodes.replayPlayButton.title = '暂停播放';
  queueReplayStep();
}

function startCommandReplay(journal, source, finalState) {
  if (aiBusy || replaySession) return false;
  try {
    const replay = createCommandReplay(journal, { finalState });
    if (replay.length <= 1) throw new Error('当前没有可回放的命令。');
    const initialFrame = replay.getFrame(0);
    const initialState = deserializeGame(initialFrame.game);
    const labels = ['对局初始状态'];
    journal.commands.forEach((command) => {
      labels.push(describeReplayCommand(command, initialState));
    });
    gameSession += 1;
    clearTimeout(resultTimer);
    clearTimeout(feedbackClearTimer);
    clearTimeout(turnCalloutTimer);
    replaySession = {
      source,
      replay,
      currentFrame: initialFrame,
      labels,
      cursor: 0,
      playing: false,
      timer: null,
      previousVisualState: null,
    };
    nodes.replayTimeline.replaceChildren(...labels.map((label, index) => {
      const item = document.createElement('li');
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = index === 0 ? '00 初始' : `${String(index).padStart(2, '0')} ${label}`;
      button.title = label;
      button.addEventListener('click', () => setReplayCursor(index));
      item.append(button);
      return item;
    }));
    nodes.sessionDialog.close();
    nodes.replayController.hidden = false;
    nodes.turnCallout.setAttribute('aria-hidden', 'true');
    nodes.turnCallout.dataset.visible = 'false';
    document.body.dataset.replay = 'true';
    visualFeedback = emptyVisualFeedback();
    renderReplayController();
    render();
    announce('已进入只读命令回放。', 'success');
    return true;
  } catch (error) {
    nodes.sessionStatus.textContent = `回放失败：${error.message}`;
    nodes.sessionStatus.dataset.state = 'error';
    announce('无法建立命令回放。', 'danger');
    return false;
  }
}

function exitCommandReplay() {
  if (!replaySession) return;
  stopReplayPlayback();
  replaySession = null;
  gameSession += 1;
  displayedGame = game;
  nodes.replayController.hidden = true;
  nodes.turnCallout.removeAttribute('aria-hidden');
  delete document.body.dataset.replay;
  visualFeedback = emptyVisualFeedback();
  render();
  announce('已返回实时对局。', 'success');
}

function replayCurrentSession() {
  startCommandReplay(commandJournal, 'current', game);
}

function replaySavedSession() {
  const stored = readLocalSave();
  if (!stored.raw || stored.error) {
    renderSessionDialog();
    return;
  }
  try {
    const restored = restoreSessionSave(stored.raw);
    startCommandReplay(restored.journal, 'saved', restored.state);
  } catch (error) {
    nodes.sessionStatus.textContent = `回放失败：${error.message}`;
    nodes.sessionStatus.dataset.state = 'error';
  }
}

function currentSelectedCard() {
  if (replaySession) return null;
  return displayedGame.players[0].hand.find((card) => card.instanceId === selectedCardId) ?? null;
}

function selectionTarget() {
  const instance = currentSelectedCard();
  return instance ? getCardDefinition(instance.definitionId).target : null;
}

function unitByUid(player, unitId) {
  return player.units.find((unit) => unit.uid === unitId) ?? null;
}

function makeStatus(text, className) {
  const status = document.createElement('span');
  status.className = `unit-status ${className}`;
  status.textContent = text;
  return status;
}

function selectedCardsForUnit(unitId) {
  return deckSelections.get(unitId) ?? [];
}

function selectedCardCount(unitId, cardId) {
  return selectedCardsForUnit(unitId).filter((candidate) => candidate === cardId).length;
}

function currentDeckDefinition() {
  return {
    unitIds: [...selectedLineup],
    cardIds: selectedLineup.flatMap((unitId) => selectedCardsForUnit(unitId)),
  };
}

function playerFrontZone() {
  return [...nodes.playerUnits.children].find((child) => child.classList.contains('front-zone')) ?? null;
}

function renderFormationRoster() {
  nodes.formationRoster.replaceChildren(...UNIT_DEFINITIONS.map((unit, index) => {
    const selectedIndex = selectedLineup.indexOf(unit.id);
    const selected = selectedIndex >= 0;
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'roster-card';
    button.classList.toggle('is-selected', selected);
    button.style.setProperty('--unit-accent', unit.color);
    button.setAttribute('aria-pressed', String(selected));
    button.setAttribute('aria-label', `${unit.name}，${unit.role}，${selected ? `已加入第 ${selectedIndex + 1} 位` : '未加入编成'}`);

    const art = document.createElement('span');
    art.className = 'roster-art';
    const image = document.createElement('img');
    image.src = unit.art;
    image.alt = '';
    image.width = 180;
    image.height = 220;
    art.append(image);

    const order = document.createElement('span');
    order.className = 'roster-order';
    order.textContent = selected ? String(selectedIndex + 1).padStart(2, '0') : String(index + 1).padStart(2, '0');

    const identity = document.createElement('span');
    identity.className = 'roster-identity';
    identity.innerHTML = `<small>${unit.title} / ${unit.role}</small><strong>${unit.name}</strong><span>${unit.strategy}</span>`;

    const stats = document.createElement('span');
    stats.className = 'roster-stats';
    stats.innerHTML = `<span><small>攻击</small><b>${unit.attack}</b></span><span><small>生命</small><b>${unit.maxHp}</b></span>`;

    const deck = document.createElement('span');
    deck.className = 'roster-deck';
    deck.innerHTML = `<span><b>被动</b>${unit.passive.name}</span><span><b>卡池</b>${getCardsForUnit(unit.id).length} 张可选</span>`;

    const action = document.createElement('span');
    action.className = 'roster-action';
    action.textContent = selected ? '已纳入编成' : '加入编成';
    button.append(art, order, identity, stats, deck, action);
    button.addEventListener('click', () => toggleFormationUnit(unit.id));
    return button;
  }));
}

function renderDeckUnitTabs() {
  nodes.deckUnitTabs.replaceChildren(...selectedLineup.map((unitId, index) => {
    const unit = getUnitDefinition(unitId);
    const count = selectedCardsForUnit(unitId).length;
    const button = document.createElement('button');
    button.type = 'button';
    button.role = 'tab';
    button.className = 'deck-unit-tab';
    button.style.setProperty('--unit-accent', unit.color);
    button.setAttribute('aria-selected', String(activeDeckUnitId === unitId));
    button.innerHTML = `<small>0${index + 1} / ${count} OF 8</small><strong>${unit.name}</strong>`;
    button.addEventListener('click', () => {
      activeDeckUnitId = unitId;
      renderFormationEditor();
    });
    return button;
  }));
}

function adjustCardCount(unitId, cardId, delta) {
  const selected = [...selectedCardsForUnit(unitId)];
  const currentCount = selected.filter((candidate) => candidate === cardId).length;
  if (delta > 0) {
    if (currentCount >= GAME_RULES.copiesPerCard) return;
    if (selected.length >= GAME_RULES.cardsPerUnit) {
      announce(`${getUnitDefinition(unitId).name} 已选满 ${GAME_RULES.cardsPerUnit} 张牌。`, 'danger');
      return;
    }
    selected.push(cardId);
  } else {
    const index = selected.lastIndexOf(cardId);
    if (index < 0) return;
    selected.splice(index, 1);
  }
  deckSelections.set(unitId, selected);
  renderFormationEditor();
}

function renderCardPool() {
  const unit = getUnitDefinition(activeDeckUnitId);
  if (!unit) {
    nodes.cardPool.replaceChildren();
    nodes.passiveDossier.replaceChildren();
    return;
  }

  const selected = selectedCardsForUnit(unit.id);
  nodes.activeDeckCount.textContent = selected.length;
  nodes.activeDeckCount.parentElement.dataset.complete = String(selected.length === GAME_RULES.cardsPerUnit);
  nodes.passiveDossier.style.setProperty('--unit-accent', unit.color);
  nodes.passiveDossier.innerHTML = `<span>被动 / PASSIVE</span><strong>${unit.passive.name}</strong><p>${unit.passive.text}</p>`;

  nodes.cardPool.replaceChildren(...getCardsForUnit(unit.id).map((card) => {
    const count = selectedCardCount(unit.id, card.id);
    const article = document.createElement('article');
    article.className = 'pool-card';
    article.style.setProperty('--unit-accent', unit.color);
    article.dataset.selected = String(count > 0);

    const tags = card.tags.slice(0, 2).map((tag) => `<span>${tag}</span>`).join('');
    article.innerHTML = `
      <div class="pool-card-art"><img src="${unit.art}" alt="" width="180" height="220"><b>${card.cost}</b><em>${card.level} 勾</em></div>
      <div class="pool-card-copy"><small>${card.typeLabel} / ${card.rarity.toUpperCase()}</small><strong>${card.name}</strong><p>${card.text}</p><div>${tags}</div></div>
    `;

    const controls = document.createElement('div');
    controls.className = 'pool-card-controls';
    const remove = document.createElement('button');
    remove.type = 'button';
    remove.textContent = '−';
    remove.title = `减少一张${card.name}`;
    remove.setAttribute('aria-label', `减少一张${card.name}`);
    remove.disabled = count === 0;
    const counter = document.createElement('strong');
    counter.textContent = `${count} / ${GAME_RULES.copiesPerCard}`;
    const add = document.createElement('button');
    add.type = 'button';
    add.textContent = '+';
    add.title = `增加一张${card.name}`;
    add.setAttribute('aria-label', `增加一张${card.name}`);
    add.disabled = count >= GAME_RULES.copiesPerCard || selected.length >= GAME_RULES.cardsPerUnit;
    remove.addEventListener('click', () => adjustCardCount(unit.id, card.id, -1));
    add.addEventListener('click', () => adjustCardCount(unit.id, card.id, 1));
    controls.append(remove, counter, add);
    article.append(controls);
    return article;
  }));
}

function setFormationStep(step) {
  if (step === 'deck' && selectedLineup.length !== GAME_RULES.lineupSize) {
    announce(`请先选择 ${GAME_RULES.lineupSize} 名角色。`, 'danger');
    return;
  }
  formationStep = step;
  if (!selectedLineup.includes(activeDeckUnitId)) activeDeckUnitId = selectedLineup[0] ?? null;
  renderFormationEditor();
}

function renderFormationSlots() {
  const slots = Array.from({ length: GAME_RULES.lineupSize }, (_, index) => {
    const unitId = selectedLineup[index];
    const unit = unitId && getUnitDefinition(unitId);
    const slot = document.createElement(unit ? 'button' : 'div');
    if (unit) slot.type = 'button';
    slot.className = `formation-slot${unit ? ' is-filled' : ''}`;
    slot.style.setProperty('--unit-accent', unit?.color ?? 'var(--rule)');
    if (unit) {
      slot.setAttribute('aria-label', `从编成移除 ${unit.name}`);
      const image = document.createElement('img');
      image.src = unit.art;
      image.alt = '';
      image.width = 180;
      image.height = 220;
      const copy = document.createElement('span');
      copy.innerHTML = `<small>0${index + 1} / ${unit.role}</small><strong>${unit.name}</strong><em>8 张专属卡</em>`;
      slot.append(image, copy);
      slot.addEventListener('click', () => toggleFormationUnit(unit.id));
    } else {
      slot.innerHTML = `<span>0${index + 1}</span><strong>待选择</strong>`;
    }
    return slot;
  });
  nodes.formationSlots.replaceChildren(...slots);
}

function renderFormationEditor() {
  const deckDefinition = currentDeckDefinition();
  const validation = validateDeckDefinition(deckDefinition);
  const lineupComplete = selectedLineup.length === GAME_RULES.lineupSize;
  nodes.formationCount.textContent = selectedLineup.length;
  nodes.formationUnitCount.textContent = selectedLineup.length;
  nodes.formationDeckCount.textContent = deckDefinition.cardIds.length;
  nodes.formationError.textContent = validation.valid ? '编成合法，可以进入对局。' : validation.errors[0];
  nodes.formationError.dataset.valid = String(validation.valid);
  nodes.rosterLibrary.hidden = formationStep !== 'lineup';
  nodes.deckBuilder.hidden = formationStep !== 'deck';
  nodes.lineupStepButton.setAttribute('aria-current', formationStep === 'lineup' ? 'step' : 'false');
  nodes.deckStepButton.setAttribute('aria-current', formationStep === 'deck' ? 'step' : 'false');
  nodes.deckStepButton.disabled = !lineupComplete;
  nodes.formationStartKicker.textContent = formationStep === 'lineup' ? '下一步' : '锁定牌组';
  nodes.formationStartLabel.textContent = formationStep === 'lineup' ? '构筑卡组 →' : '进入对局 →';
  nodes.formationStartButton.disabled = formationStep === 'lineup' ? !lineupComplete : !validation.valid;
  renderFormationRoster();
  renderFormationSlots();
  renderDeckUnitTabs();
  renderCardPool();
}

function toggleFormationUnit(unitId) {
  const existingIndex = selectedLineup.indexOf(unitId);
  if (existingIndex >= 0) {
    selectedLineup.splice(existingIndex, 1);
  } else if (selectedLineup.length < GAME_RULES.lineupSize) {
    selectedLineup.push(unitId);
  } else {
    nodes.formationError.textContent = '编成已满，请先移除一名角色。';
    nodes.formationError.dataset.valid = 'false';
    announce('编成已满，请先移除一名角色。', 'danger');
    return;
  }
  if (!selectedLineup.includes(activeDeckUnitId)) activeDeckUnitId = selectedLineup[0] ?? null;
  renderFormationEditor();
}

function showFormation() {
  if (replaySession) return;
  nodes.formationCancelButton.hidden = !battleStarted;
  nodes.gameShell.hidden = true;
  nodes.formationScreen.hidden = false;
  renderFormationEditor();
  window.scrollTo({ top: 0 });
}

function hideFormation() {
  nodes.formationScreen.hidden = true;
  nodes.gameShell.hidden = false;
  window.scrollTo({ top: 0 });
}

function startBattle() {
  if (formationStep === 'lineup') {
    setFormationStep('deck');
    return;
  }
  const deckDefinition = currentDeckDefinition();
  const validation = validateDeckDefinition(deckDefinition);
  if (!validation.valid) {
    nodes.formationError.textContent = validation.errors[0];
    announce(validation.errors[0], 'danger');
    return;
  }

  gameSession += 1;
  lockedPlayerDeckDefinition = structuredClone(deckDefinition);
  game = createGame({ playerDeckDefinition: lockedPlayerDeckDefinition });
  commandJournal = createCommandJournal(game);
  selectedCardId = null;
  selectedAttackUnitId = game.players[0].frontUnitId;
  aiBusy = false;
  resultShown = false;
  clearTimeout(resultTimer);
  clearTimeout(feedbackClearTimer);
  previousVisualState = null;
  visualFeedback = emptyVisualFeedback();
  announcedTurnCounter = 0;
  clearTimeout(turnCalloutTimer);
  battleStarted = true;
  if (nodes.resultDialog.open) nodes.resultDialog.close();
  hideFormation();
  render();
  announce('灵契编成已锁定。', 'success');
}

function renderUnit(unit, ownerIndex, placement) {
  const owner = displayedGame.players[ownerIndex];
  const player = displayedGame.players[0];
  const card = document.createElement('button');
  const isPlayer = ownerIndex === 0;
  const viewSelectedCardId = replaySession ? null : selectedCardId;
  const targetMode = selectionTarget();
  const selectedInstance = currentSelectedCard();
  const definition = selectedInstance && getCardDefinition(selectedInstance.definitionId);
  const validTargets = definition ? getValidTargets(displayedGame, 0, definition.id) : [];
  const isCombatCardTarget = ownerIndex === 1
    && placement === 'front'
    && definition?.effect === 'assault'
    && getValidCombatTargets(displayedGame, 0).includes(unit.uid);
  const isValidTarget = isCombatCardTarget || (validTargets.includes(unit.uid)
    && ((isPlayer && ['ally-unit', 'knocked-ally'].includes(targetMode)) || (!isPlayer && targetMode === 'enemy-unit')));
  const viewAttackUnitId = replaySession ? player.frontUnitId : selectedAttackUnitId;
  const canSelectForAttack = !replaySession && isPlayer && unit.hp > 0 && !viewSelectedCardId && displayedGame.currentPlayer === 0 && !aiBusy;
  const selectedAttacker = unitByUid(player, viewAttackUnitId);
  const attackReady = !replaySession
    && !viewSelectedCardId
    && displayedGame.currentPlayer === 0
    && !aiBusy
    && displayedGame.winner === null
    && !player.attackUsed
    && player.energy > 0
    && selectedAttacker?.hp > 0
    && selectedAttacker.frozen === 0;
  const willBeHit = ownerIndex === 1 && owner.frontUnitId === unit.uid && unit.hp > 0 && attackReady;
  const isTargetMuted = Boolean(viewSelectedCardId) && !isValidTarget;
  const impact = visualFeedback.unitImpacts.get(unit.uid);
  const isInteractive = isValidTarget || canSelectForAttack;
  const canDragToFront = isPlayer
    && !replaySession
    && placement === 'reserve'
    && unit.hp > 0
    && unit.frozen === 0
    && !viewSelectedCardId
    && displayedGame.currentPlayer === 0
    && !aiBusy
    && displayedGame.winner === null
    && !player.attackUsed
    && player.energy > 0;

  card.type = 'button';
  card.className = `unit-card is-${placement}-slot`;
  card.dataset.owner = isPlayer ? 'player' : 'enemy';
  card.dataset.unitId = unit.uid;
  card.style.setProperty('--unit-accent', unit.color);
  card.classList.toggle('is-active', placement === 'front');
  card.classList.toggle('is-selected', isPlayer && viewAttackUnitId === unit.uid && !viewSelectedCardId && !replaySession);
  card.classList.toggle('is-target', isValidTarget);
  card.classList.toggle('is-target-muted', isTargetMuted);
  card.classList.toggle('will-be-hit', willBeHit);
  card.classList.toggle('is-away', unit.hp <= 0);
  card.classList.toggle('is-attacking', Boolean(impact?.isAttacker && !impact.isRemoteAttacker));
  card.classList.toggle('is-remote-attacking', Boolean(impact?.isRemoteAttacker));
  card.classList.toggle('is-keyword-empowered', Boolean(impact?.isKeywordEmpowered));
  card.classList.toggle('is-hit', Boolean(impact && (impact.hpDelta < 0 || impact.shieldDelta < 0)));
  card.classList.toggle('is-healed', Boolean(impact && (impact.hpDelta > 0 || impact.shieldDelta > 0)));
  card.classList.toggle('is-leveling', Boolean(impact?.levelDelta > 0));
  card.classList.toggle('is-knocked-out', Boolean(impact?.knockedOut));
  card.classList.toggle('is-returned', Boolean(impact?.returned));
  card.disabled = !isInteractive;
  card.draggable = canDragToFront;
  card.setAttribute('aria-label', `${unit.name}，${placement === 'front' ? '前线' : '准备区'}，${unit.level} 勾玉，攻击 ${unit.attack}，生命 ${unit.hp}/${unit.maxHp}${unit.shield ? `，护盾 ${unit.shield}` : ''}`);
  card.title = `${unit.passive.name}：${unit.passive.text}`;

  const art = document.createElement('span');
  art.className = 'unit-art';
  const image = document.createElement('img');
  image.src = unit.art;
  image.alt = '';
  image.width = 180;
  image.height = 220;
  art.append(image);

  const placementTag = document.createElement('span');
  placementTag.className = 'unit-placement';
  placementTag.textContent = placement === 'front' ? '战斗区' : '准备区';
  art.append(placementTag);

  const identity = document.createElement('span');
  identity.className = 'unit-identity';
  const title = document.createElement('small');
  title.textContent = unit.form?.name ?? `${unit.title} / ${unit.role}`;
  const name = document.createElement('strong');
  name.textContent = unit.name;
  const passiveName = document.createElement('span');
  passiveName.className = 'unit-passive';
  passiveName.textContent = `◇ ${unit.passive.name}`;
  passiveName.title = unit.passive.text;
  identity.append(title, name, passiveName);

  const level = document.createElement('span');
  level.className = 'unit-level';
  level.innerHTML = `<small>勾玉</small><b>${unit.level}</b>`;

  const stats = document.createElement('span');
  stats.className = 'unit-stats';
  stats.innerHTML = `<span class="attack-stat"><small>攻</small><b>${unit.attack}</b></span><span class="health-stat"><small>命</small><b>${unit.hp}</b><em>/${unit.maxHp}</em></span>`;

  const health = document.createElement('span');
  health.className = 'unit-health';
  const healthFill = document.createElement('i');
  healthFill.style.width = `${Math.max(0, (unit.hp / unit.maxHp) * 100)}%`;
  health.append(healthFill);

  const statuses = document.createElement('span');
  statuses.className = 'unit-statuses';
  if (placement === 'front' && unit.hp > 0) statuses.append(makeStatus('前线', 'status-front'));
  if (isPlayer && viewAttackUnitId === unit.uid && !viewSelectedCardId && unit.hp > 0 && !replaySession) statuses.append(makeStatus('待出击', 'status-selected'));
  if (isValidTarget) statuses.append(makeStatus('有效目标', 'status-target'));
  if (willBeHit) statuses.append(makeStatus('将承受出击', 'status-threat'));
  if (unit.form) statuses.append(makeStatus(unit.form.name, 'status-form'));
  if (unit.shield > 0) statuses.append(makeStatus(`盾 ${unit.shield}`, 'status-shield'));
  if (unit.frozen > 0) statuses.append(makeStatus('眩晕', 'status-frozen'));
  if (unit.brittle > 0) statuses.append(makeStatus(`晶裂 ${unit.brittle}`, 'status-brittle'));
  getUnitKeywordStatuses(owner, unit).forEach((status) => {
    statuses.append(makeStatus(`${status.label} ${status.detail}`, `status-${status.id}`));
  });
  if (unit.hp <= 0) statuses.append(makeStatus(`归队 ${unit.knockout}`, 'status-away'));

  card.append(art, identity, level, stats, health, statuses);

  if (impact && (impact.hpDelta || impact.shieldDelta || impact.levelDelta || impact.knockedOut || impact.returned || impact.isRemoteAttacker || impact.isKeywordEmpowered)) {
    const fxSurface = document.createElement('span');
    fxSurface.className = 'unit-fx-surface';
    fxSurface.classList.toggle('is-remote', Boolean(impact.isRemoteAttacker));
    fxSurface.classList.toggle('is-keyword-empowered', Boolean(impact.isKeywordEmpowered));
    fxSurface.setAttribute('aria-hidden', 'true');
    card.append(fxSurface);
  }

  if (impact && (impact.hpDelta || impact.shieldDelta)) {
    const isHealthChange = impact.hpDelta !== 0;
    const delta = isHealthChange ? impact.hpDelta : impact.shieldDelta;
    const impactNumber = document.createElement('span');
    impactNumber.className = 'impact-number';
    impactNumber.classList.toggle('is-positive', delta > 0);
    impactNumber.classList.toggle('is-shield', !isHealthChange);
    const label = document.createElement('small');
    label.textContent = isHealthChange
      ? (delta > 0 ? '生命恢复' : '受到伤害')
      : (delta > 0 ? '获得护盾' : '护盾破损');
    if (isHealthChange && impact.shieldDelta) label.textContent += ` / 护盾 ${impact.shieldDelta > 0 ? '+' : ''}${impact.shieldDelta}`;
    const value = document.createElement('strong');
    value.textContent = delta > 0 ? `+${delta}` : String(delta);
    impactNumber.append(label, value);
    card.append(impactNumber);
  }

  const callout = document.createElement('span');
  callout.className = 'unit-action-callout';
  if (impact?.knockedOut) {
    callout.classList.add('is-knockout');
    callout.innerHTML = `<small>气绝 / BREAK</small><strong>气绝 · ${unit.knockout} 回合</strong>`;
  } else if (impact?.levelDelta > 0) {
    callout.classList.add('is-level');
    callout.innerHTML = `<small>勾玉提升 / LEVEL UP</small><strong>${unit.level} 勾玉</strong>`;
  } else if (impact?.returned) {
    callout.classList.add('is-return');
    callout.innerHTML = '<small>重返战场 / RETURN</small><strong>复归</strong>';
  } else if (impact?.isKeywordEmpowered) {
    callout.classList.add('is-empowered');
    callout.innerHTML = impact.isRemoteAttacker
      ? '<small>关键词强化 / EMPOWERED</small><strong>鼓舞远程出击</strong>'
      : '<small>关键词强化 / EMPOWERED</small><strong>鼓舞出击</strong>';
  } else if (impact?.isRemoteAttacker) {
    callout.classList.add('is-remote');
    callout.innerHTML = '<small>远程攻击 / REMOTE</small><strong>远程出击</strong>';
  } else if (impact?.isAttacker) {
    callout.classList.add('is-attack');
    callout.innerHTML = '<small>攻击方 / ATTACKER</small><strong>出击</strong>';
  }
  if (callout.classList.length > 1) card.append(callout);
  card.addEventListener('click', () => handleUnitClick(ownerIndex, unit.uid));
  if (canDragToFront) {
    card.addEventListener('dragstart', (event) => {
      draggedAttackUnitId = unit.uid;
      selectedAttackUnitId = unit.uid;
      event.dataTransfer.effectAllowed = 'move';
      event.dataTransfer.setData('text/plain', unit.uid);
      requestAnimationFrame(() => card.classList.add('is-dragging'));
      playerFrontZone()?.classList.add('is-drop-ready');
    });
    card.addEventListener('dragend', () => {
      draggedAttackUnitId = null;
      card.classList.remove('is-dragging');
      playerFrontZone()?.classList.remove('is-drop-ready', 'is-drag-over');
    });
  }
  return card;
}

function renderRealmTrack(player, ownerIndex) {
  const track = document.createElement('div');
  track.className = 'realm-track';
  track.dataset.owner = ownerIndex === 0 ? 'player' : 'enemy';
  const label = document.createElement('span');
  label.className = 'zone-label';
  label.textContent = '幻境席';
  track.append(label);
  if (!player.realms.length) {
    const empty = document.createElement('span');
    empty.className = 'realm-empty';
    empty.textContent = '未部署';
    track.append(empty);
    return track;
  }
  player.realms.forEach((realm) => {
    const viewSelectedCardId = replaySession ? null : selectedCardId;
    const chip = document.createElement('button');
    const selected = currentSelectedCard();
    const selectedDefinition = selected && getCardDefinition(selected.definitionId);
    const selectedCombatCard = selectedDefinition?.effect === 'assault';
    const attackerId = replaySession ? displayedGame.players[0].frontUnitId : selectedAttackUnitId;
    const attacker = unitByUid(displayedGame.players[0], attackerId);
    const attackReady = ownerIndex === 1
      && !replaySession
      && !viewSelectedCardId
      && displayedGame.currentPlayer === 0
      && !aiBusy
      && displayedGame.winner === null
      && !displayedGame.players[0].attackUsed
      && displayedGame.players[0].energy > 0
      && attacker?.hp > 0
      && attacker.frozen === 0;
    const isCardTarget = ownerIndex === 1
      && selectedCombatCard
      && getValidCombatTargets(displayedGame, 0).includes(realm.uid);
    const isTarget = attackReady || isCardTarget;
    const impact = visualFeedback.realmImpacts.get(realm.uid);
    chip.type = 'button';
    chip.className = 'realm-chip';
    chip.dataset.realmId = realm.uid;
    chip.classList.toggle('is-target', isTarget);
    chip.classList.toggle('is-target-muted', Boolean(viewSelectedCardId) && !isCardTarget);
    chip.classList.toggle('is-hit', Boolean(impact?.hpDelta < 0));
    chip.disabled = !isTarget;
    const keywordStatus = getKeywordStatusText(realm);
    const keywordSuffix = keywordStatus ? ` · ${keywordStatus}` : '';
    chip.title = `${realm.text}${keywordSuffix}`;
    chip.innerHTML = `<span class="realm-title"><b>${realm.name}</b><small>${keywordSuffix || '持续生效'}</small></span><span class="realm-vital"><strong>${realm.hp}</strong><small>/ ${realm.maxHp} 耐久</small></span><span class="realm-health"><i style="width:${Math.max(0, (realm.hp / realm.maxHp) * 100)}%"></i></span>`;
    if (impact?.hpDelta) {
      const number = document.createElement('span');
      number.className = 'realm-impact-number';
      number.textContent = String(impact.hpDelta);
      chip.append(number);
    }
    chip.addEventListener('click', () => handleRealmClick(ownerIndex, realm.uid));
    track.append(chip);
  });
  return track;
}

function renderFormationLine(container, ownerIndex) {
  const owner = displayedGame.players[ownerIndex];
  const formation = getFormation(displayedGame, ownerIndex);
  const ownerImpacts = [...visualFeedback.unitImpacts.values()]
    .filter((impact) => impact.playerIndex === ownerIndex);
  if (ownerImpacts.some((impact) => impact.isAttacker)) container.dataset.feedback = 'attacker';
  else if (ownerImpacts.length) container.dataset.feedback = 'target';
  else delete container.dataset.feedback;
  const frontZone = document.createElement('section');
  frontZone.className = 'front-zone';
  frontZone.setAttribute('aria-label', ownerIndex === 0 ? '己方战斗区' : '敌方战斗区');
  const frontLabel = document.createElement('span');
  frontLabel.className = 'zone-label';
  frontLabel.textContent = '战斗区 / FRONT';
  frontZone.append(frontLabel);
  const front = owner.units[formation.frontIndex];
  if (front) frontZone.append(renderUnit(front, ownerIndex, 'front'));
  else {
    const empty = document.createElement('div');
    empty.className = 'empty-front-slot';
    empty.innerHTML = '<strong>前线空缺</strong><span>下次攻击将直击核心</span>';
    frontZone.append(empty);
  }
  if (ownerIndex === 0 && !replaySession) {
    frontZone.addEventListener('dragover', (event) => {
      if (!draggedAttackUnitId) return;
      event.preventDefault();
      event.dataTransfer.dropEffect = 'move';
      frontZone.classList.add('is-drag-over');
    });
    frontZone.addEventListener('dragleave', (event) => {
      if (!frontZone.contains(event.relatedTarget)) frontZone.classList.remove('is-drag-over');
    });
    frontZone.addEventListener('drop', (event) => {
      event.preventDefault();
      const unitId = draggedAttackUnitId ?? event.dataTransfer.getData('text/plain');
      draggedAttackUnitId = null;
      frontZone.classList.remove('is-drop-ready', 'is-drag-over');
      if (unitId) performBasicAttack(unitId);
    });
  }

  const reserveZone = document.createElement('section');
  reserveZone.className = 'reserve-zone';
  reserveZone.setAttribute('aria-label', ownerIndex === 0 ? '己方准备区' : '敌方准备区');
  const reserveLabel = document.createElement('span');
  reserveLabel.className = 'zone-label';
  reserveLabel.textContent = '准备区 / RESERVE';
  const reserveCards = document.createElement('div');
  reserveCards.className = 'reserve-cards';
  formation.reserveIndexes.forEach((index) => reserveCards.append(renderUnit(owner.units[index], ownerIndex, 'reserve')));
  reserveZone.append(reserveLabel, reserveCards);

  container.replaceChildren(reserveZone, frontZone, renderRealmTrack(owner, ownerIndex));
}

function renderUnits() {
  renderFormationLine(nodes.playerUnits, 0);
  renderFormationLine(nodes.enemyUnits, 1);
}

function renderHandCard(instance) {
  const definition = getCardDefinition(instance.definitionId);
  const unit = getUnitDefinition(definition.unitId);
  const playability = getCardPlayability(displayedGame, 0, instance.instanceId);
  const effectiveCost = getEffectiveCardCost(displayedGame, 0, instance.instanceId);
  const costIsReduced = effectiveCost < definition.cost;
  const costReductionLabel = costIsReduced ? getKeywordCostReductionLabel(definition) : null;
  const playerResponding = displayedGame.responseWindow?.playerIndex === 0;
  const playable = !replaySession && playability.playable && (!aiBusy || playerResponding);
  const card = document.createElement('button');
  card.type = 'button';
  card.className = 'hand-card';
  card.style.setProperty('--card-accent', unit.color);
  card.classList.toggle('is-selected', !replaySession && selectedCardId === instance.instanceId);
  card.classList.toggle('is-blocked', !playable);
  card.dataset.block = playable ? 'ready' : playability.code;
  card.disabled = !playable;
  card.setAttribute('aria-disabled', String(!playable));
  card.setAttribute('aria-label', `${definition.name}，${definition.level} 勾玉，消耗 ${effectiveCost} 鬼火，${definition.text}${playable ? '' : `，当前不可用：${replaySession ? '只读回放' : playability.reason}`}`);
  card.title = replaySession ? '只读回放中不可操作' : playable ? definition.text : playability.reason;

  const cost = document.createElement('span');
  cost.className = 'card-cost';
  cost.classList.toggle('is-unaffordable', playability.code === 'energy');
  cost.classList.toggle('is-free', costIsReduced);
  cost.textContent = effectiveCost;
  const level = document.createElement('span');
  level.className = 'card-level';
  level.textContent = `${definition.level} 勾`;
  const art = document.createElement('span');
  art.className = 'card-art';
  const image = document.createElement('img');
  image.src = unit.art;
  image.alt = '';
  image.width = 180;
  image.height = 220;
  art.append(image);
  const meta = document.createElement('span');
  meta.className = 'card-meta';
  meta.textContent = `${unit.name} / ${definition.typeLabel}`;
  const name = document.createElement('strong');
  name.className = 'card-name';
  name.textContent = definition.name;
  const text = document.createElement('span');
  text.className = 'card-text';
  text.textContent = definition.text;
  const availability = document.createElement('span');
  availability.className = 'card-availability';
  const availabilityLabels = {
    ready: '可使用',
    turn: '等待对手',
    energy: '鬼火不足',
    charge: '充能不足',
    'fusion-max': '融合已满',
    'source-away': `${unit.name}气绝`,
    level: `需 ${definition.level} 勾`,
    frozen: `${unit.name}眩晕`,
    'no-target': '暂无目标',
    finished: '对局结束',
    effect: '效果未接入',
    'response-only': '仅响应牌可用',
    'response-wait': '等待响应',
    'choice-wait': '等待占卜',
    missing: '状态异常',
  };
  availability.textContent = replaySession
    ? '只读回放'
    : costIsReduced && playable
    ? costReductionLabel ?? '费用减免'
    : availabilityLabels[playable ? 'ready' : playability.code] ?? playability.reason;
  card.append(cost, level, art, meta, name, text, availability);
  card.addEventListener('click', () => handleCardClick(instance));
  return card;
}

function renderHand() {
  nodes.playerHand.replaceChildren(...displayedGame.players[0].hand.map(renderHandCard));
  const playerResponding = displayedGame.responseWindow?.playerIndex === 0;
  nodes.playableCardCount.textContent = replaySession ? 0 : displayedGame.players[0].hand.filter((card) => (
    canPlayCard(displayedGame, 0, card.instanceId) && (!aiBusy || playerResponding)
  )).length;
  if (displayedGame.players[0].hand.length === 0) {
    const empty = document.createElement('p');
    empty.className = 'empty-hand';
    empty.textContent = '手牌已空';
    nodes.playerHand.append(empty);
  }
}

function renderResources() {
  const player = displayedGame.players[0];
  const enemy = displayedGame.players[1];
  nodes.playerCoreHp.textContent = player.avatarHp;
  nodes.playerCoreBar.style.width = `${(player.avatarHp / player.maxAvatarHp) * 100}%`;
  nodes.playerEnergy.textContent = player.energy;
  nodes.playerMaxEnergy.textContent = player.maxEnergy;
  nodes.playerDeck.textContent = player.deck.length;
  nodes.playerHandCount.textContent = player.hand.length;
  nodes.enemyCoreHp.textContent = enemy.avatarHp;
  nodes.enemyCoreBar.style.width = `${(enemy.avatarHp / enemy.maxAvatarHp) * 100}%`;
  nodes.enemyEnergy.textContent = `${enemy.energy} / ${enemy.maxEnergy}`;
  nodes.enemyDeck.textContent = enemy.deck.length;
  nodes.enemyHand.textContent = enemy.hand.length;
  nodes.sessionButton.disabled = aiBusy || Boolean(replaySession);
  nodes.formationButton.disabled = Boolean(replaySession);
  nodes.restartButton.disabled = Boolean(replaySession);
  nodes.energyPips.replaceChildren(...Array.from({ length: player.maxEnergy }, (_, index) => {
    const pip = document.createElement('i');
    pip.className = index < player.energy ? 'is-filled' : '';
    return pip;
  }));
  const keywordStatuses = getPlayerKeywordStatuses(player);
  nodes.keywordStatuses.replaceChildren(...keywordStatuses.map((status) => {
    const item = document.createElement('span');
    item.className = 'keyword-status';
    item.dataset.keyword = status.id;
    item.innerHTML = `<small>${status.label}</small><strong>${status.detail}</strong>`;
    item.title = status.title ?? '下一次出击自动生效并消耗';
    return item;
  }));
  nodes.keywordStatuses.hidden = keywordStatuses.length === 0;
}

function renderDivinationDialog() {
  if (replaySession) {
    if (nodes.divinationDialog.open) nodes.divinationDialog.close();
    return;
  }
  const choice = displayedGame.pendingChoice;
  if (!choice || choice.playerIndex !== 0) {
    if (nodes.divinationDialog.open) nodes.divinationDialog.close();
    return;
  }
  const player = displayedGame.players[0];
  nodes.divinationOptions.replaceChildren(...choice.instanceIds.map((instanceId) => {
    const instance = player.deck.find((candidate) => candidate.instanceId === instanceId);
    const card = getCardDefinition(instance.definitionId);
    const unit = getUnitDefinition(card.unitId);
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'divination-option';
    button.style.setProperty('--card-accent', unit.color);
    button.innerHTML = `<span>${card.level} 勾 · ${card.typeLabel}</span><strong>${card.name}</strong><small>${unit.name} / ${card.cost} 鬼火</small>`;
    button.addEventListener('click', () => {
      const result = resolveDivinationChoice(game, 0, instanceId);
      if (result.error) {
        announce(result.error, 'danger');
        return;
      }
      game = result.state;
      recordCommand({ type: 'divination-choice', playerIndex: 0, instanceId });
      render();
    });
    return button;
  }));
  if (!nodes.divinationDialog.open) nodes.divinationDialog.showModal();
}

function renderCoreImpact(coreNode, playerIndex) {
  coreNode.classList.remove('is-hit', 'is-healed');
  coreNode.getElementsByClassName('core-impact-number')[0]?.remove();
  const impact = visualFeedback.coreImpacts.get(playerIndex);
  if (!impact) return;

  void coreNode.offsetWidth;
  coreNode.classList.add(impact.hpDelta < 0 ? 'is-hit' : 'is-healed');
  const number = document.createElement('span');
  number.className = 'core-impact-number';
  number.classList.toggle('is-positive', impact.hpDelta > 0);
  const label = document.createElement('small');
  label.textContent = impact.hpDelta < 0 ? '核心受击' : '核心恢复';
  const value = document.createElement('strong');
  value.textContent = impact.hpDelta > 0 ? `+${impact.hpDelta}` : String(impact.hpDelta);
  number.append(label, value);
  coreNode.append(number);
}

function renderBattleFeedback() {
  nodes.battleFeedback.replaceChildren();
  const cue = visualFeedback.cue;
  if (!cue) {
    delete nodes.battleFeedback.dataset.type;
    return;
  }

  nodes.battleFeedback.dataset.type = cue.type;
  const flash = document.createElement('span');
  flash.className = 'battle-feedback-flash';
  flash.setAttribute('aria-hidden', 'true');
  const panel = document.createElement('span');
  panel.className = 'battle-feedback-cue';
  const kicker = document.createElement('small');
  kicker.textContent = cue.kicker;
  const title = document.createElement('strong');
  title.textContent = cue.title;
  const detail = document.createElement('span');
  detail.textContent = cue.detail;
  panel.append(kicker, title, detail);
  nodes.battleFeedback.append(flash, panel);
}

function renderLog() {
  const count = String(displayedGame.log.length).padStart(2, '0');
  nodes.logCount.textContent = count;
  nodes.logButtonCount.textContent = count;
  nodes.battleLogButton.setAttribute('aria-label', `查看战报，共 ${displayedGame.log.length} 条记录`);
  nodes.logList.replaceChildren(...displayedGame.log.map((entry) => {
    const item = document.createElement('li');
    item.dataset.tone = entry.tone;
    const turn = document.createElement('span');
    turn.textContent = String(entry.turn).padStart(2, '0');
    const message = document.createElement('p');
    message.textContent = entry.text;
    item.append(turn, message);
    return item;
  }));
}

function renderTurnCallout(turnMode) {
  if (replaySession || displayedGame.winner !== null || displayedGame.turnCounter === announcedTurnCounter) return;
  announcedTurnCounter = displayedGame.turnCounter;
  clearTimeout(turnCalloutTimer);
  const playerTurn = turnMode === 'player';
  const current = displayedGame.players[displayedGame.currentPlayer];
  nodes.turnCalloutKicker.textContent = playerTurn ? 'YOUR TURN' : 'OPPONENT TURN';
  nodes.turnCalloutLabel.textContent = playerTurn ? '巡界者行动' : '失序体行动';
  nodes.turnCalloutDetail.textContent = `${current.energy} 点鬼火`;
  nodes.turnCallout.dataset.owner = turnMode;
  nodes.turnCallout.dataset.visible = 'true';
  turnCalloutTimer = setTimeout(() => { nodes.turnCallout.dataset.visible = 'false'; }, 1150);
}

function getAttackPreview(attacker) {
  if (!attacker) return '当前没有可出击角色。';
  const enemy = displayedGame.players[1];
  const defender = unitByUid(enemy, enemy.frontUnitId);
  const combatStatuses = getPlayerKeywordStatuses(displayedGame.players[0]);
  const statusAttack = combatStatuses.reduce((total, status) => total + (status.attack ?? 0), 0);
  const statusShield = combatStatuses.reduce((total, status) => total + (status.shield ?? 0), 0);
  const attackPower = attacker.attack + statusAttack;
  const shield = attacker.shield + statusShield;
  const statusText = combatStatuses.length
    ? `（${combatStatuses.map((status) => `${status.label} ${status.detail}`).join('；')}）`
    : '';
  if (!defender || defender.hp <= 0) return `出击预估：${attacker.name} 将进入前线并直击敌方核心，造成 ${attackPower} 点伤害${statusText}。`;
  const outgoing = Math.max(0, attackPower + (defender.brittle > 0 ? 1 : 0) - defender.shield);
  const counter = defender.frozen > 0 ? 0 : Math.max(0, defender.attack - shield);
  const movement = attacker.uid === displayedGame.players[0].frontUnitId ? '从前线出击' : '从准备区换入前线';
  return `出击预估：${attacker.name} ${movement}，对 ${defender.name} 造成 ${outgoing} 点伤害，预计承受 ${counter} 点反击${statusText}。`;
}

function getRecentEventText() {
  const latest = displayedGame.log[0];
  if (!latest) return '等待第一条战报。';
  if (latest.tone !== 'turn' || aiBusy) return latest.text;
  const recentBattleEvent = displayedGame.log.find((entry) => entry.turn >= displayedGame.turnCounter - 1 && entry.tone !== 'turn');
  return recentBattleEvent?.text ?? latest.text;
}

function renderCommands() {
  const player = displayedGame.players[0];
  let viewAttackUnitId = replaySession ? player.frontUnitId : selectedAttackUnitId;
  const currentAttacker = unitByUid(player, viewAttackUnitId);
  if (!currentAttacker || currentAttacker.hp <= 0) {
    viewAttackUnitId = unitByUid(player, player.frontUnitId)?.uid
      ?? player.units.find((unit) => unit.hp > 0)?.uid
      ?? null;
    if (!replaySession) selectedAttackUnitId = viewAttackUnitId;
  }
  const attacker = unitByUid(player, viewAttackUnitId);
  const playerResponding = !replaySession && displayedGame.responseWindow?.playerIndex === 0 && displayedGame.winner === null;
  const userTurn = !replaySession && displayedGame.currentPlayer === 0 && !aiBusy && displayedGame.winner === null && !displayedGame.responseWindow;
  const turnMode = replaySession ? 'replay' : displayedGame.winner !== null ? 'over' : playerResponding ? 'response' : userTurn ? 'player' : 'enemy';
  const canAttack = userTurn && !selectedCardId && attacker && attacker.hp > 0 && attacker.frozen === 0 && player.energy > 0 && !player.attackUsed;
  const canLevel = userTurn && !selectedCardId && attacker && attacker.level < GAME_RULES.maxUnitLevel && !player.levelUpUsed;
  nodes.attackButton.disabled = !canAttack;
  nodes.levelButton.disabled = !canLevel;
  nodes.levelButton.hidden = !replaySession && Boolean(selectedCardId);
  nodes.endTurnButton.disabled = !userTurn && !playerResponding;
  nodes.endTurnButton.innerHTML = playerResponding
    ? '放弃响应 <span aria-hidden="true">→</span>'
    : '结束回合 <span aria-hidden="true">→</span>';
  nodes.attackLabel.textContent = attacker ? `${attacker.name}出击` : '无法出击';
  nodes.levelLabel.textContent = attacker ? `${attacker.name}升勾` : '无法升勾';
  const responseOwner = displayedGame.responseWindow?.playerIndex === 0 ? '巡界者' : '失序体';
  nodes.turnOwner.textContent = replaySession
    ? '命令回放'
    : displayedGame.responseWindow
      ? `优先权：${responseOwner}`
      : userTurn
        ? '巡界者行动'
        : displayedGame.winner !== null
          ? '对局结束'
          : '失序体行动';
  nodes.round.textContent = String(getRound(displayedGame)).padStart(2, '0');
  nodes.battleStage.dataset.turn = turnMode;
  document.body.dataset.turn = turnMode;
  nodes.turnState.dataset.owner = turnMode;
  nodes.turnStateCode.textContent = turnMode === 'replay' ? 'PLAY' : turnMode === 'player' ? 'YOU' : turnMode === 'response' ? 'REACT' : turnMode === 'enemy' ? 'AI' : 'END';
  nodes.turnStateKicker.textContent = turnMode === 'replay' ? 'COMMAND REPLAY' : turnMode === 'player' ? 'YOUR TURN' : turnMode === 'response' ? 'RESPONSE WINDOW' : turnMode === 'enemy' ? 'OPPONENT TURN' : 'MATCH COMPLETE';
  nodes.turnStateLabel.textContent = turnMode === 'replay' ? '只读回放' : turnMode === 'player' ? '你的回合' : turnMode === 'response' ? '等待响应' : turnMode === 'enemy' ? '对手行动' : '对局结束';
  nodes.cancelActionButton.hidden = replaySession || !selectedCardId;
  nodes.recentEvent.textContent = getRecentEventText();
  nodes.attackButton.querySelector('b').classList.toggle('is-unaffordable', player.energy < 1);
  renderTurnCallout(turnMode);

  const selected = currentSelectedCard();
  if (replaySession) {
    nodes.actionPrompt.textContent = replaySession.labels[replaySession.cursor];
  } else if (selected) {
    const card = getCardDefinition(selected.definitionId);
    const prompts = {
      'ally-unit': '选择一名友方角色。',
      'knocked-ally': '选择一名气绝角色。',
      'enemy-unit': '选择一名敌方角色。',
    };
    nodes.actionPrompt.textContent = card.effect === 'assault'
      ? `${card.name}：点击敌方前线或一处幻境。`
      : `${card.name}：${prompts[card.target]}`;
  } else if (displayedGame.pendingChoice?.playerIndex === 0) {
    nodes.actionPrompt.textContent = '占卜：从牌库顶的候选中选择一张置顶。';
  } else if (displayedGame.responseWindow) {
    const pending = getCardDefinition(displayedGame.responseWindow.definitionId);
    const { consecutivePasses, depth, playerIndex } = displayedGame.responseWindow;
    const priorityOwner = playerIndex === 0 ? '巡界者' : '失序体';
    nodes.actionPrompt.textContent = `响应「${pending.name}」 · 优先权 ${priorityOwner} · 深度 ${depth}/${GAME_RULES.maxResponseDepth} · 连续放弃 ${consecutivePasses}/2`;
  } else if (aiBusy) {
    nodes.actionPrompt.textContent = '失序体正在评估前线与准备区。';
  } else if (displayedGame.winner !== null) {
    nodes.actionPrompt.textContent = displayedGame.winner === 0 ? '界碑已稳定。' : '界碑核心失守。';
  } else if (player.attackUsed) {
    nodes.actionPrompt.textContent = '本回合已出击，仍可使用卡牌或提升勾玉。';
  } else if (attacker?.frozen > 0) {
    nodes.actionPrompt.textContent = `${attacker.name}处于眩晕状态，请选择其他角色。`;
  } else if (player.energy < 1) {
    nodes.actionPrompt.textContent = '鬼火已耗尽，可以提升勾玉或结束回合。';
  } else {
    nodes.actionPrompt.textContent = getAttackPreview(attacker);
  }
}

function render() {
  clearTimeout(feedbackClearTimer);
  displayedGame = replaySession
    ? deserializeGame(replaySession.currentFrame.game)
    : game;
  const previousState = replaySession ? replaySession.previousVisualState : previousVisualState;
  visualFeedback = deriveBattleFeedback(previousState, displayedGame);
  renderResources();
  renderCoreImpact(nodes.playerCore, 0);
  renderCoreImpact(nodes.enemyCore, 1);
  renderBattleFeedback();
  renderCommands();
  renderUnits();
  renderHand();
  renderDivinationDialog();
  renderLog();
  if (!replaySession) maybeShowResult();
  const currentSnapshot = captureBattleSnapshot(displayedGame);
  if (replaySession) replaySession.previousVisualState = currentSnapshot;
  else previousVisualState = currentSnapshot;
  if (visualFeedback.cue || visualFeedback.unitImpacts.size || visualFeedback.coreImpacts.size || visualFeedback.realmImpacts.size) {
    const session = gameSession;
    feedbackClearTimer = setTimeout(() => {
      if (session === gameSession) render();
    }, 1550);
  }
}

function handleCardClick(instance) {
  if (replaySession) return;
  const playability = getCardPlayability(game, 0, instance.instanceId);
  const playerResponding = game.responseWindow?.playerIndex === 0;
  if (!playability.playable || (aiBusy && !playerResponding)) {
    announce(aiBusy && !playerResponding ? '等待失序体完成行动。' : playability.reason, 'danger');
    return;
  }
  const card = getCardDefinition(instance.definitionId);
  if (card.target === 'auto') {
    if (card.effect === 'assault' && game.players[1].realms.length > 0) {
      selectedCardId = selectedCardId === instance.instanceId ? null : instance.instanceId;
      render();
      return;
    }
    commitCard(instance.instanceId, null);
    return;
  }
  selectedCardId = selectedCardId === instance.instanceId ? null : instance.instanceId;
  render();
}

function handleUnitClick(ownerIndex, unitId) {
  if (replaySession) return;
  const selected = currentSelectedCard();
  if (selected) {
    const card = getCardDefinition(selected.definitionId);
    const ownTarget = ownerIndex === 0 && ['ally-unit', 'knocked-ally'].includes(card.target);
    const enemyTarget = ownerIndex === 1 && (card.target === 'enemy-unit'
      || (card.effect === 'assault' && game.players[1].frontUnitId === unitId));
    const validTarget = card.effect === 'assault'
      ? getValidCombatTargets(game, 0).includes(unitId)
      : getValidTargets(game, 0, card.id).includes(unitId);
    if ((ownTarget || enemyTarget) && validTarget) {
      commitCard(selected.instanceId, unitId);
    }
    return;
  }
  const unit = unitByUid(game.players[ownerIndex], unitId);
  if (ownerIndex === 0 && unit?.hp > 0) {
    selectedAttackUnitId = unitId;
    render();
  }
}

function handleRealmClick(ownerIndex, realmId) {
  if (replaySession) return;
  if (ownerIndex !== 1) return;
  const selected = currentSelectedCard();
  if (selected) {
    const card = getCardDefinition(selected.definitionId);
    if (card.effect === 'assault' && getValidCombatTargets(game, 0).includes(realmId)) {
      commitCard(selected.instanceId, realmId);
    }
    return;
  }
  if (getValidCombatTargets(game, 0).includes(realmId)) performBasicAttack(selectedAttackUnitId, realmId);
}

function commitCard(instanceId, targetId) {
  if (replaySession) return;
  const result = playCard(game, 0, instanceId, targetId);
  if (result.error) {
    announce(result.error, 'danger');
    return;
  }
  game = result.state;
  recordCommand({ type: 'play-card', playerIndex: 0, instanceId, targetId });
  selectedCardId = null;
  if (game.responseWindow?.playerIndex === 1 && game.winner === null) {
    aiBusy = true;
    render();
    runAiTurn(gameSession);
    return;
  }
  render();
}

function performBasicAttack(unitId, targetId = null) {
  if (replaySession) return;
  selectedAttackUnitId = unitId;
  const result = basicAttack(game, 0, unitId, targetId);
  if (result.error) {
    announce(result.error, 'danger');
    return;
  }
  game = result.state;
  recordCommand({ type: 'attack', playerIndex: 0, unitId, targetId });
  selectedCardId = null;
  render();
}

function handleAttack() {
  if (replaySession) return;
  performBasicAttack(selectedAttackUnitId);
}

function handleLevelUp() {
  if (replaySession) return;
  const result = levelUpUnit(game, 0, selectedAttackUnitId);
  if (result.error) {
    announce(result.error, 'danger');
    return;
  }
  game = result.state;
  recordCommand({ type: 'level-up', playerIndex: 0, unitId: selectedAttackUnitId });
  render();
}

function executeAiCommand(command) {
  if (command.type === 'play-card') {
    return playCard(game, 1, command.instanceId, command.targetId);
  }
  if (command.type === 'level-up') return levelUpUnit(game, 1, command.unitId);
  if (command.type === 'attack') return basicAttack(game, 1, command.unitId, command.targetId);
  if (command.type === 'divination-choice') return resolveDivinationChoice(game, 1, command.instanceId);
  if (command.type === 'pass-response') return passResponse(game, 1);
  return { state: game, error: null };
}

function aiHasControl() {
  if (game.winner !== null) return false;
  if (game.pendingChoice) return game.pendingChoice.playerIndex === 1;
  if (game.responseWindow) return game.responseWindow.playerIndex === 1;
  return game.currentPlayer === 1;
}

async function runAiTurn(session) {
  await wait(1250);
  if (session !== gameSession || !aiHasControl()) return;
  let actions = 0;
  while (session === gameSession && aiHasControl() && actions < 24) {
    while (session === gameSession && (replaySession || nodes.battleLogDialog.open || nodes.rulesDialog.open || nodes.sessionDialog.open || nodes.divinationDialog.open)) await wait(120);
    if (session !== gameSession) return;
    const command = chooseAiCommand(game, 1);
    if (command.type === 'end-turn') break;
    if (session !== gameSession) return;
    const result = executeAiCommand(command);
    if (result.error) break;
    game = result.state;
    recordCommand({ ...command, playerIndex: 1 });
    actions += 1;
    if (!aiHasControl()) {
      aiBusy = false;
      render();
      return;
    }
    render();
    const cueType = visualFeedback.cue?.type;
    const holdDuration = cueType === 'knockout'
      ? 1350
      : cueType === 'level-up'
        ? 1250
        : cueType === 'remote-combat'
          ? 1200
        : command.type === 'attack'
          ? 1200
          : 1050;
    await wait(holdDuration);
  }

  if (session !== gameSession || game.winner !== null) {
    aiBusy = false;
    render();
    return;
  }
  if (game.responseWindow || game.pendingChoice || game.currentPlayer !== 1) {
    aiBusy = false;
    render();
    return;
  }
  await wait(320);
  if (session !== gameSession) return;
  while (session === gameSession && (replaySession || nodes.battleLogDialog.open || nodes.rulesDialog.open || nodes.sessionDialog.open || nodes.divinationDialog.open)) await wait(120);
  if (session !== gameSession) return;
  const result = endTurn(game, 1);
  if (!result.error) {
    game = result.state;
    recordCommand({ type: 'end-turn', playerIndex: 1 });
  }
  aiBusy = false;
  render();
}

function handleEndTurn() {
  if (replaySession) return;
  if (game.responseWindow?.playerIndex === 0) {
    const result = passResponse(game, 0);
    if (result.error) {
      announce(result.error, 'danger');
      return;
    }
    game = result.state;
    recordCommand({ type: 'pass-response', playerIndex: 0 });
    selectedCardId = null;
    aiBusy = aiHasControl();
    render();
    if (aiBusy) runAiTurn(gameSession);
    return;
  }
  if (aiBusy) return;
  const result = endTurn(game, 0);
  if (result.error) {
    announce(result.error, 'danger');
    return;
  }
  game = result.state;
  recordCommand({ type: 'end-turn', playerIndex: 0 });
  selectedCardId = null;
  aiBusy = true;
  render();
  runAiTurn(gameSession);
}

function showResultDialogWhenReady(session) {
  if (session !== gameSession || replaySession || game.winner === null || nodes.resultDialog.open) return;
  if (nodes.battleLogDialog.open || nodes.rulesDialog.open || nodes.sessionDialog.open || nodes.divinationDialog.open) {
    resultTimer = setTimeout(() => showResultDialogWhenReady(session), 160);
    return;
  }
  nodes.resultDialog.showModal();
}

function maybeShowResult() {
  if (replaySession || game.winner === null || resultShown) return;
  resultShown = true;
  const won = game.winner === 0;
  const player = game.players[0];
  nodes.resultCode.textContent = won ? 'VICTORY' : 'DEFEAT';
  nodes.resultCode.dataset.result = won ? 'win' : 'loss';
  nodes.resultTitle.textContent = won ? '界碑已稳定' : '核心同步中断';
  nodes.resultSummary.textContent = won ? '失序信号已经退离前线。' : '失序体突破了最后一道防线。';
  nodes.resultRounds.textContent = getRound(game);
  nodes.resultCards.textContent = player.cardsPlayed;
  nodes.resultDamage.textContent = player.damageDealt;
  const session = gameSession;
  clearTimeout(resultTimer);
  resultTimer = setTimeout(() => showResultDialogWhenReady(session), 1450);
}

function restartGame() {
  if (replaySession) return;
  gameSession += 1;
  game = createGame({ playerDeckDefinition: lockedPlayerDeckDefinition });
  commandJournal = createCommandJournal(game);
  selectedCardId = null;
  selectedAttackUnitId = game.players[0].frontUnitId;
  aiBusy = false;
  resultShown = false;
  clearTimeout(resultTimer);
  clearTimeout(feedbackClearTimer);
  previousVisualState = null;
  visualFeedback = emptyVisualFeedback();
  announcedTurnCounter = 0;
  clearTimeout(turnCalloutTimer);
  if (nodes.resultDialog.open) nodes.resultDialog.close();
  render();
  announce('新对局已建立。', 'success');
}

nodes.formationStartButton.addEventListener('click', startBattle);
nodes.lineupStepButton.addEventListener('click', () => setFormationStep('lineup'));
nodes.deckStepButton.addEventListener('click', () => setFormationStep('deck'));
nodes.formationCancelButton.addEventListener('click', hideFormation);
nodes.formationButton.addEventListener('click', showFormation);
nodes.attackButton.addEventListener('click', handleAttack);
nodes.levelButton.addEventListener('click', handleLevelUp);
nodes.endTurnButton.addEventListener('click', handleEndTurn);
nodes.cancelActionButton.addEventListener('click', () => {
  selectedCardId = null;
  render();
});
nodes.battleLogButton.addEventListener('click', () => nodes.battleLogDialog.showModal());
nodes.rulesButton.addEventListener('click', () => nodes.rulesDialog.showModal());
nodes.sessionButton.addEventListener('click', () => {
  renderSessionDialog();
  nodes.sessionDialog.showModal();
});
nodes.sessionCloseButton.addEventListener('click', () => nodes.sessionDialog.close());
nodes.sessionSaveButton.addEventListener('click', saveCurrentSession);
nodes.sessionLoadButton.addEventListener('click', loadLocalSession);
nodes.sessionReplayCurrentButton.addEventListener('click', replayCurrentSession);
nodes.sessionReplaySavedButton.addEventListener('click', replaySavedSession);
nodes.sessionExportCurrentButton.addEventListener('click', exportCurrentReplay);
nodes.sessionExportSavedButton.addEventListener('click', exportSavedReplay);
nodes.sessionImportButton.addEventListener('click', () => nodes.sessionImportInput.click());
nodes.sessionImportInput.addEventListener('change', importReplayFile);
nodes.replayFirstButton.addEventListener('click', () => setReplayCursor(0));
nodes.replayPreviousButton.addEventListener('click', () => {
  if (replaySession) setReplayCursor(replaySession.cursor - 1);
});
nodes.replayPlayButton.addEventListener('click', toggleReplayPlayback);
nodes.replayNextButton.addEventListener('click', () => {
  if (replaySession) setReplayCursor(replaySession.cursor + 1);
});
nodes.replayLastButton.addEventListener('click', () => {
  if (replaySession) setReplayCursor(replaySession.replay.length - 1);
});
nodes.replayExitButton.addEventListener('click', exitCommandReplay);
nodes.replayScrubber.addEventListener('input', (event) => setReplayCursor(Number(event.target.value)));
nodes.restartButton.addEventListener('click', restartGame);
nodes.rematchButton.addEventListener('click', restartGame);
nodes.inspectButton.addEventListener('click', () => nodes.resultDialog.close());
nodes.divinationDialog.addEventListener('cancel', (event) => event.preventDefault());

document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape') return;
  if (nodes.battleLogDialog.open || nodes.rulesDialog.open || nodes.sessionDialog.open || nodes.resultDialog.open) return;
  if (replaySession) {
    exitCommandReplay();
    return;
  }
  if (!nodes.formationScreen.hidden && battleStarted) {
    hideFormation();
    return;
  }
  if (!selectedCardId) return;
  selectedCardId = null;
  render();
});

renderFormationEditor();
