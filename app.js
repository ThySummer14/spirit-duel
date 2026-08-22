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
import { gameAudio } from './game-audio.js';
import {
  COLLECTION_RULES,
  RARITY_LABELS,
  collectionStats,
  craftCard,
  createInitialCollection,
  deserializeCollection,
  grantMatchReward,
  openPack,
  ownedCopies,
  serializeCollection,
} from './game-collection.js';
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
const COLLECTION_STORAGE_KEY = 'nexus-front:collection';
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
  collectionScreen: document.querySelector('#collection-screen'),
  collectionButton: document.querySelector('#collection-button'),
  collectionBackButton: document.querySelector('#collection-back-button'),
  packOpenButton: document.querySelector('#pack-open-button'),
  packReveal: document.querySelector('#pack-reveal'),
  packRevealCards: document.querySelector('#pack-reveal-cards'),
  packRevealCloseButton: document.querySelector('#pack-reveal-close'),
  pityCount: document.querySelector('#pity-count'),
  collectionBalance: document.querySelector('#collection-balance'),
  collectionPacks: document.querySelector('#collection-packs'),
  collectionRecord: document.querySelector('#collection-record'),
  codexUnits: document.querySelector('#codex-units'),
  codexOwned: document.querySelector('#codex-owned'),
  codexTotal: document.querySelector('#codex-total'),
  battleStage: document.querySelector('.battle-stage'),
  battleFeedback: document.querySelector('#battle-feedback'),
  turnOwner: document.querySelector('#turn-owner'),
  round: document.querySelector('#round-value'),
  turnCallout: document.querySelector('#turn-callout'),
  turnCalloutKicker: document.querySelector('#turn-callout-kicker'),
  turnCalloutLabel: document.querySelector('#turn-callout-label'),
  turnCalloutDetail: document.querySelector('#turn-callout-detail'),
  actionPrompt: document.querySelector('#action-prompt'),
  recentEvent: document.querySelector('#recent-event'),
  playerUnits: document.querySelector('#player-units'),
  enemyUnits: document.querySelector('#enemy-units'),
  enemyRealms: document.querySelector('#enemy-realms'),
  playerRealms: document.querySelector('#player-realms'),
  playerHand: document.querySelector('#player-hand'),
  handPreview: document.querySelector('#hand-preview'),
  spiritDetail: document.querySelector('#spirit-detail'),
  deckAutofillButton: document.querySelector('#deck-autofill-button'),
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
  resultReward: document.querySelector('#result-reward'),
  rematchButton: document.querySelector('#rematch-button'),
  inspectButton: document.querySelector('#inspect-button'),
  toast: document.querySelector('#toast'),
  audioToggleButton: document.querySelector('#audio-toggle-button'),
  audioDialog: document.querySelector('#audio-dialog'),
  menuDialog: document.querySelector('#menu-dialog'),
  menuButton: document.querySelector('#menu-button'),
  menuCloseButton: document.querySelector('#menu-close-button'),
  audioCloseButton: document.querySelector('#audio-close-button'),
  audioEnabledCheckbox: document.querySelector('#audio-enabled-checkbox'),
  audioMasterVolume: document.querySelector('#audio-master-volume'),
  audioMusicVolume: document.querySelector('#audio-music-volume'),
  audioSfxVolume: document.querySelector('#audio-sfx-volume'),
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
let lastFeedbackSfxKey = '';
let lastResponseWindowKey = '';
let lastHandInstanceIds = new Set();
let lastRealmTotal = 0;

/** 根据当前视觉反馈播放一次受击/气绝/核心音效（同一反馈只播一次） */
function playImpactSfx() {
  const parts = [];
  for (const [uid, impact] of visualFeedback.unitImpacts) {
    if (impact.knockedOut) parts.push(`ko:${uid}`);
    else if (impact.hpDelta < 0 || impact.shieldDelta < 0) parts.push(`hit:${uid}`);
    else if (impact.hpDelta > 0) parts.push(`heal:${uid}`);
    else if (impact.shieldDelta > 0) parts.push(`shield:${uid}`);
  }
  for (const [index, impact] of visualFeedback.coreImpacts) {
    if (impact.hpDelta < 0) parts.push(`core:${index}`);
  }
  const key = parts.join('|');
  if (!key || key === lastFeedbackSfxKey) return;
  lastFeedbackSfxKey = key;
  if (parts.some((part) => part.startsWith('ko:'))) gameAudio.knockout();
  else if (parts.some((part) => part.startsWith('core:'))) gameAudio.coreHit();
  else if (parts.some((part) => part.startsWith('hit:'))) gameAudio.hit();
  else if (parts.some((part) => part.startsWith('heal:'))) gameAudio.heal();
  else if (parts.some((part) => part.startsWith('shield:'))) gameAudio.shield();
}

const wait = (duration) => new Promise((resolve) => setTimeout(resolve, duration));

/** ===== 秘闻阁：收藏与御札经济 ===== */

function loadCollection() {
  try {
    const raw = localStorage.getItem(COLLECTION_STORAGE_KEY);
    if (raw) return deserializeCollection(raw);
  } catch { /* 损坏或不可用时重建初始收藏 */ }
  return createInitialCollection();
}

function saveCollection() {
  try {
    localStorage.setItem(COLLECTION_STORAGE_KEY, serializeCollection(collection));
  } catch { /* 存储不可用时静默降级 */ }
}

let collection = loadCollection();

function showCollection() {
  nodes.formationScreen.hidden = true;
  nodes.collectionScreen.hidden = false;
  window.scrollTo({ top: 0 });
  renderCollectionScreen();
}

function hideCollection() {
  nodes.collectionScreen.hidden = true;
  nodes.formationScreen.hidden = false;
  window.scrollTo({ top: 0 });
  renderFormationEditor();
}

function renderCollectionScreen() {
  const stats = collectionStats(collection);
  nodes.collectionBalance.textContent = collection.balance;
  nodes.collectionPacks.textContent = collection.packsOpened;
  nodes.collectionRecord.textContent = `${collection.wins}胜 ${collection.losses}败`;
  nodes.pityCount.textContent = Math.max(0, COLLECTION_RULES.pityLimit - collection.pitySinceEpic);
  nodes.codexOwned.textContent = stats.distinctOwned;
  nodes.codexTotal.textContent = stats.totalCards;
  nodes.packOpenButton.disabled = collection.balance < COLLECTION_RULES.packCost;
  renderCodex();
}

function renderCodex() {
  nodes.codexUnits.replaceChildren(...UNIT_DEFINITIONS.map((unit) => {
    const section = document.createElement('section');
    section.className = 'codex-unit';
    section.style.setProperty('--unit-accent', unit.color);
    const cards = getCardsForUnit(unit.id);
    const ownedKinds = cards.filter((card) => ownedCopies(collection, card.id) > 0).length;
    const head = document.createElement('header');
    head.innerHTML = `<strong>${unit.name}</strong><small>${unit.title} · ${unit.role}</small><em>${ownedKinds} / ${cards.length} 种</em>`;
    const grid = document.createElement('div');
    grid.className = 'codex-grid';
    cards.forEach((card) => {
      const copies = ownedCopies(collection, card.id);
      const tile = document.createElement('article');
      tile.className = 'codex-tile';
      tile.dataset.rarity = card.rarity;
      tile.dataset.owned = String(copies);
      tile.title = card.text;
      const pips = Array.from({ length: COLLECTION_RULES.maxCopies }, (_, index) => (
        `<i${index < copies ? ' class="is-filled"' : ''}></i>`
      )).join('');
      tile.innerHTML = `
        <span class="tile-name">${card.name}</span>
        <span class="tile-type">${card.typeLabel} · <i>${RARITY_LABELS[card.rarity]}</i> · ${card.level}勾</span>
        <span class="tile-pips">${pips}</span>`;
      const cost = COLLECTION_RULES.craftCost[card.rarity];
      const capped = copies >= COLLECTION_RULES.maxCopies;
      const craft = document.createElement('button');
      craft.type = 'button';
      craft.className = 'tile-craft';
      craft.classList.toggle('is-capped', capped);
      craft.disabled = capped || collection.balance < cost;
      craft.innerHTML = capped ? '<span>已收齐</span><b></b>' : `<span>御札合成</span><b>${cost}</b>`;
      craft.addEventListener('click', () => {
        const outcome = craftCard(collection, card.id);
        if (outcome.error) {
          announce(outcome.error, 'danger');
          return;
        }
        collection = outcome.collection;
        saveCollection();
        gameAudio.craft();
        announce(`已合成「${card.name}」。`, 'success');
        renderCollectionScreen();
      });
      tile.append(craft);
      grid.append(tile);
    });
    section.append(head, grid);
    return section;
  }));
}

function openPackFlow() {
  const outcome = openPack(collection);
  if (outcome.error) {
    announce(outcome.error, 'danger');
    return;
  }
  collection = outcome.collection;
  saveCollection();
  gameAudio.packOpen();
  nodes.packRevealCards.replaceChildren(...outcome.results.map((entry, index) => {
    const card = getCardDefinition(entry.cardId);
    const unit = getUnitDefinition(card.unitId);
    const el = document.createElement('article');
    el.className = 'reveal-card';
    el.dataset.rarity = entry.rarity;
    el.style.setProperty('--reveal-delay', `${index * 0.14}s`);
    el.innerHTML = `
      <span class="reveal-art"><img src="${unit.art}" alt="" width="200" height="260"></span>
      <span class="reveal-cost"><i>${card.cost}</i></span>
      <span class="reveal-rarity-tag">${RARITY_LABELS[entry.rarity]}</span>
      <strong class="reveal-name">${card.name}</strong>
      <span class="reveal-type">${unit.name} · ${card.typeLabel}</span>
      <span class="reveal-state ${entry.isNew ? 'is-new' : 'is-dupe'}">${entry.isNew ? 'NEW' : `御札 +${entry.converted}`}</span>`;
    setTimeout(() => gameAudio.reveal(entry.rarity), 320 + index * 140);
    return el;
  }));
  nodes.packReveal.hidden = false;
  renderCollectionScreen();
}

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
  if (tone === 'danger') gameAudio.errorBuzz();
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
    lastHandInstanceIds = new Set();
    lastRealmTotal = 0;
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
  // 回放期间手牌追踪被回放状态覆盖，静默同步回实时对局，避免误触抽牌音效
  lastHandInstanceIds = new Set(game.players[0].hand.map((card) => card.instanceId));
  lastRealmTotal = game.players[0].realms.length + game.players[1].realms.length;
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

function makeStatus(text, className, title) {
  const status = document.createElement('span');
  status.className = `unit-status ${className}`;
  status.textContent = text;
  if (title) status.title = title;
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
    image.width = 200;
    image.height = 260;
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
    button.addEventListener('mouseenter', () => renderSpiritDetail(unit));
    button.addEventListener('focus', () => renderSpiritDetail(unit));
    return button;
  }));
}

/** 编成名录底部的悬停详情条：被动全文、卡池概况与定位 */
function renderSpiritDetail(unit) {
  if (!unit) return;
  const pool = getCardsForUnit(unit.id);
  const roleTags = [...new Set(pool.flatMap((card) => card.tags))].slice(0, 6);
  nodes.spiritDetail.style.setProperty('--unit-accent', unit.color);
  nodes.spiritDetail.innerHTML = `
    <span class="detail-name"><b>${unit.name}</b><small>${unit.title} · ${unit.role}</small></span>
    <i class="detail-seal" aria-hidden="true"></i>
    <span class="detail-passive"><b>◇ 被动 · ${unit.passive.name}</b><p>${unit.passive.text}</p></span>
    <span class="detail-meta">
      <span>攻击 <b>${unit.attack}</b> / 生命 <b>${unit.maxHp}</b></span>
      <span>专属卡池 <b>${pool.length}</b> 张 · ${roleTags.join(' / ')}</span>
    </span>`;
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
    button.innerHTML = `
      <img src="${unit.art}" alt="" width="200" height="260">
      <span class="tab-copy"><small>0${index + 1} · ${unit.title}</small><strong>${unit.name}</strong></span>
      <b class="tab-count" title="已选 ${count} / 8">${count}</b>`;
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
    const owned = ownedCopies(collection, cardId);
    if (currentCount >= owned) {
      announce(`收藏不足：「${getCardDefinition(cardId).name}」仅持有 ${owned} 张，可到秘闻阁开卷收集。`, 'danger');
      return;
    }
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
    article.dataset.rarity = card.rarity;

    const rarityLabels = { common: '常见', rare: '稀有', epic: '史诗' };
    const tags = card.tags.slice(0, 3).map((tag) => `<span>${tag}</span>`).join('');
    article.innerHTML = `
      <div class="pool-card-art"><img src="${unit.art}" alt="" width="200" height="260"><b><i>${card.cost}</i></b><em>${card.level} 勾</em></div>
      <div class="pool-card-copy"><small>${card.typeLabel} · <i class="rar-${card.rarity}">${rarityLabels[card.rarity] ?? card.rarity}</i></small><strong>${card.name}</strong><p>${card.text}</p><div>${tags}</div></div>
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
    counter.classList.toggle('maxed', count === GAME_RULES.copiesPerCard);
    const add = document.createElement('button');
    add.type = 'button';
    add.textContent = '+';
    add.title = `增加一张${card.name}`;
    add.setAttribute('aria-label', `增加一张${card.name}`);
    const owned = ownedCopies(collection, card.id);
    add.disabled = count >= GAME_RULES.copiesPerCard
      || count >= owned
      || selected.length >= GAME_RULES.cardsPerUnit;
    if (count >= owned && count < GAME_RULES.copiesPerCard) {
      add.title = `收藏不足：「${card.name}」仅持有 ${owned} 张，可到秘闻阁收集`;
    }
    remove.addEventListener('click', () => adjustCardCount(unit.id, card.id, -1));
    add.addEventListener('click', () => adjustCardCount(unit.id, card.id, 1));
    controls.append(remove, counter, add);
    article.append(controls);
    return article;
  }));
}

/** 一键填充当前角色卡组为推荐默认构筑 */
function autofillActiveDeck() {
  const unit = getUnitDefinition(activeDeckUnitId);
  if (!unit) return;
  deckSelections.set(unit.id, createDefaultDeckDefinition([unit.id]).cardIds);
  renderFormationEditor();
  announce(`${unit.name} 的卡组已填充为推荐构筑。`, 'success');
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
      image.width = 200;
      image.height = 260;
      const copy = document.createElement('span');
      copy.className = 'slot-copy';
      copy.innerHTML = `<small>0${index + 1} / ${unit.role}</small><strong>${unit.name}</strong><em>8 张专属卡</em>`;
      slot.append(image, copy);
      slot.addEventListener('click', () => toggleFormationUnit(unit.id));
      slot.addEventListener('mouseenter', () => renderSpiritDetail(unit));
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
  gameAudio.unlock();
  gameAudio.setScene('formation');
}

function hideFormation() {
  nodes.formationScreen.hidden = true;
  nodes.gameShell.hidden = false;
  window.scrollTo({ top: 0 });
  gameAudio.setScene('battle');
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
  lastFeedbackSfxKey = '';
  lastResponseWindowKey = '';
  lastHandInstanceIds = new Set();
  lastRealmTotal = 0;
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
  card.className = 'unit-card';
  card.dataset.owner = isPlayer ? 'player' : 'enemy';
  card.dataset.unitId = unit.uid;
  card.style.setProperty('--unit-accent', unit.color);
  card.classList.toggle('is-front', placement === 'front');
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
  image.width = 200;
  image.height = 260;
  art.append(image);

  // 名牌：只保留名字与形态名，被动与完整状态移入检视层
  const plate = document.createElement('span');
  plate.className = 'unit-plate';
  const plateName = document.createElement('strong');
  plateName.textContent = unit.name;
  plate.append(plateName);
  if (unit.form) {
    const formName = document.createElement('em');
    formName.textContent = unit.form.name;
    plate.append(formName);
  }

  // 勾玉：紧凑菱形点，悬停看数值
  const pips = document.createElement('span');
  pips.className = 'unit-pips';
  pips.title = `勾玉 ${unit.level} / ${GAME_RULES.maxUnitLevel}`;
  pips.innerHTML = Array.from({ length: GAME_RULES.maxUnitLevel }, (_, index) => (
    `<i${index < unit.level ? ' class="is-filled"' : ''}></i>`
  )).join('');

  // 攻/血角标：叠在立绘两下角，一眼可读
  const stats = document.createElement('span');
  stats.className = 'unit-stats';
  const hpLow = unit.hp > 0 && unit.hp <= Math.max(1, Math.floor(unit.maxHp / 3));
  stats.innerHTML = `<b class="unit-atk" title="攻击">${unit.attack}</b><b class="unit-hp" title="生命"${hpLow ? ' data-low="true"' : ''}>${unit.hp}</b>`;

  const health = document.createElement('span');
  health.className = 'unit-health';
  const healthFill = document.createElement('i');
  healthFill.style.width = `${Math.max(0, (unit.hp / unit.maxHp) * 100)}%`;
  health.append(healthFill);

  // 状态：紧凑徽章 + 完整文本进 title 与检视层；前线/目标/受击威胁由卡片状态样式表达，不再占文字位
  const statuses = document.createElement('span');
  statuses.className = 'unit-statuses';
  const fullStatuses = [];
  if (isPlayer && viewAttackUnitId === unit.uid && !viewSelectedCardId && !replaySession && unit.hp > 0) {
    statuses.append(makeStatus('出', 'status-selected', '待出击'));
    fullStatuses.push('待出击：已选为出击角色');
  }
  if (isValidTarget) fullStatuses.push('当前卡牌的有效目标');
  if (willBeHit) fullStatuses.push('将承受敌方出击');
  if (unit.form) {
    statuses.append(makeStatus('形', 'status-form', `形态：${unit.form.name}`));
    fullStatuses.push(`形态 ${unit.form.name}`);
  }
  if (unit.shield > 0) {
    statuses.append(makeStatus(`盾${unit.shield}`, 'status-shield', `护盾 ${unit.shield}`));
    fullStatuses.push(`护盾 ${unit.shield}`);
  }
  if (unit.frozen > 0) {
    statuses.append(makeStatus('眩', 'status-frozen', `眩晕 ${unit.frozen} 回合`));
    fullStatuses.push(`眩晕 ${unit.frozen} 回合：无法出击或反击`);
  }
  if (unit.brittle > 0) {
    statuses.append(makeStatus(`裂${unit.brittle}`, 'status-brittle', `晶裂 ${unit.brittle}`));
    fullStatuses.push(`晶裂 ${unit.brittle}：受到的攻击伤害 +1`);
  }
  getUnitKeywordStatuses(owner, unit).forEach((status) => {
    statuses.append(makeStatus(status.label.slice(0, 2), `status-${status.id}`, `${status.label} ${status.detail}`));
    fullStatuses.push(`${status.label} ${status.detail}`);
  });
  if (unit.hp <= 0) {
    statuses.append(makeStatus(`归${unit.knockout}`, 'status-away', `气绝，${unit.knockout} 回合后归队`));
    fullStatuses.push(`气绝：${unit.knockout} 回合后自动归队`);
  }

  // 检视层：悬停/聚焦时展开被动与全部状态
  const inspect = document.createElement('span');
  inspect.className = 'unit-inspect';
  inspect.setAttribute('aria-hidden', 'true');
  const inspectHead = document.createElement('header');
  inspectHead.innerHTML = `<small>${unit.title} / ${unit.role}</small><strong>${unit.name}</strong>`;
  const inspectPassive = document.createElement('p');
  inspectPassive.className = 'inspect-passive';
  inspectPassive.innerHTML = `<b>◇ ${unit.passive.name}</b>${unit.passive.text}`;
  inspect.append(inspectHead, inspectPassive);
  if (fullStatuses.length) {
    const statusList = document.createElement('ul');
    statusList.className = 'inspect-statuses';
    fullStatuses.forEach((line) => {
      const item = document.createElement('li');
      item.textContent = line;
      statusList.append(item);
    });
    inspect.append(statusList);
  }

  card.append(art, plate, pips, stats, health, statuses, inspect);

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
      markDropZones();
    });
    card.addEventListener('dragend', () => {
      draggedAttackUnitId = null;
      card.classList.remove('is-dragging');
      clearDropZones();
    });
  }
  if (ownerIndex === 1 && placement === 'front' && !replaySession) {
    // 拖拽己方角色到敌方前线 = 直接出击
    card.addEventListener('dragover', (event) => {
      if (!draggedAttackUnitId) return;
      event.preventDefault();
      event.dataTransfer.dropEffect = 'move';
      card.classList.add('is-drag-over');
    });
    card.addEventListener('dragleave', (event) => {
      if (!card.contains(event.relatedTarget)) card.classList.remove('is-drag-over');
    });
    card.addEventListener('drop', (event) => {
      event.preventDefault();
      const unitId = draggedAttackUnitId ?? event.dataTransfer.getData('text/plain');
      draggedAttackUnitId = null;
      clearDropZones();
      if (unitId) performBasicAttack(unitId);
    });
  }
  return card;
}

/** 拖拽出击时点亮敌方可打击目标（前线 + 幻境） */
function markDropZones() {
  nodes.enemyUnits.querySelector('.unit-card.is-front')?.classList.add('is-drop-ready');
  nodes.enemyRealms.querySelectorAll('.realm-chip:not(:disabled)').forEach((chip) => chip.classList.add('is-drop-ready'));
}

function clearDropZones() {
  nodes.enemyUnits.querySelectorAll('.is-drop-ready, .is-drag-over').forEach((el) => el.classList.remove('is-drop-ready', 'is-drag-over'));
  nodes.enemyRealms.querySelectorAll('.is-drop-ready, .is-drag-over').forEach((el) => el.classList.remove('is-drop-ready', 'is-drag-over'));
}

function renderRealmColumn(column, player, ownerIndex) {
  const label = document.createElement('span');
  label.className = 'zone-label';
  label.textContent = ownerIndex === 0 ? '己方幻境' : '敌方幻境';
  column.replaceChildren(label);
  if (!player.realms.length) {
    const empty = document.createElement('span');
    empty.className = 'realm-empty';
    empty.textContent = '未部署';
    column.append(empty);
    return;
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
    if (ownerIndex === 1 && !replaySession) {
      // 拖拽己方角色到敌方幻境 = 指定该幻境出击
      chip.addEventListener('dragover', (event) => {
        if (!draggedAttackUnitId) return;
        event.preventDefault();
        event.dataTransfer.dropEffect = 'move';
        chip.classList.add('is-drag-over');
      });
      chip.addEventListener('dragleave', (event) => {
        if (!chip.contains(event.relatedTarget)) chip.classList.remove('is-drag-over');
      });
      chip.addEventListener('drop', (event) => {
        event.preventDefault();
        const unitId = draggedAttackUnitId ?? event.dataTransfer.getData('text/plain');
        draggedAttackUnitId = null;
        clearDropZones();
        if (unitId && getValidCombatTargets(game, 0).includes(realm.uid)) performBasicAttack(unitId, realm.uid);
      });
    }
    column.append(chip);
  });
}

function renderUnitRow(container, ownerIndex) {
  const owner = displayedGame.players[ownerIndex];
  const formation = getFormation(displayedGame, ownerIndex);
  const ownerImpacts = [...visualFeedback.unitImpacts.values()]
    .filter((impact) => impact.playerIndex === ownerIndex);
  if (ownerImpacts.some((impact) => impact.isAttacker)) container.dataset.feedback = 'attacker';
  else if (ownerImpacts.length) container.dataset.feedback = 'target';
  else delete container.dataset.feedback;

  // 先清空再重建：render() 会被操作与反馈定时器反复调用，直接 append 会无限堆叠卡牌
  container.replaceChildren();

  const label = document.createElement('span');
  label.className = 'zone-label';
  label.textContent = ownerIndex === 0 ? '己方战线' : '敌方战线';

  const front = owner.units[formation.frontIndex];
  if (front) container.append(renderUnit(front, ownerIndex, 'front'));
  else {
    const empty = document.createElement('div');
    empty.className = 'empty-front-slot';
    empty.innerHTML = '<strong>前线空缺</strong><span>下次攻击将直击核心</span>';
    container.append(empty);
  }
  formation.reserveIndexes.forEach((index) => container.append(renderUnit(owner.units[index], ownerIndex, 'reserve')));
  container.append(label);
}

function renderUnits() {
  renderUnitRow(nodes.playerUnits, 0);
  renderUnitRow(nodes.enemyUnits, 1);
  renderRealmColumn(nodes.enemyRealms, displayedGame.players[1], 1);
  renderRealmColumn(nodes.playerRealms, displayedGame.players[0], 0);
}

function renderHandCard(instance, index, totalCount, freshIds) {
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
  card.dataset.cardType = definition.type;
  card.classList.toggle('is-selected', !replaySession && selectedCardId === instance.instanceId);
  card.classList.toggle('is-blocked', !playable);
  card.classList.toggle('is-drawn', !replaySession && freshIds.has(instance.instanceId));
  // 扇形排布：以手牌中位为轴，边缘卡牌微微旋转
  const fanStep = Math.min(3.2, 26 / Math.max(totalCount, 1));
  const mid = (totalCount - 1) / 2;
  card.style.setProperty('--fan-rotate', `${((index - mid) * fanStep).toFixed(2)}deg`);
  card.style.zIndex = String(index + 1);
  card.dataset.block = playable ? 'ready' : playability.code;
  card.disabled = !playable;
  card.setAttribute('aria-disabled', String(!playable));
  card.setAttribute('aria-label', `${definition.name}，${definition.level} 勾玉，消耗 ${effectiveCost} 鬼火，${definition.text}${playable ? '' : `，当前不可用：${replaySession ? '只读回放' : playability.reason}`}`);
  card.title = replaySession ? '只读回放中不可操作' : playable ? definition.text : playability.reason;

  const cost = document.createElement('span');
  cost.className = 'card-cost';
  cost.classList.toggle('is-unaffordable', playability.code === 'energy');
  cost.classList.toggle('is-free', costIsReduced);
  cost.innerHTML = `<span>${effectiveCost}</span>`;
  const level = document.createElement('span');
  level.className = 'card-level';
  level.textContent = `${definition.level} 勾`;
  const art = document.createElement('span');
  art.className = 'card-art';
  const image = document.createElement('img');
  image.src = unit.art;
  image.alt = '';
  image.width = 200;
  image.height = 260;
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
  card.addEventListener('mouseenter', () => showHandPreview(instance));
  card.addEventListener('focus', () => showHandPreview(instance));
  card.addEventListener('mouseleave', hideHandPreview);
  return card;
}

/** 手牌悬停大卡预览：完整卡面文本始终可读 */
function showHandPreview(instance) {
  const definition = getCardDefinition(instance.definitionId);
  const unit = getUnitDefinition(definition.unitId);
  const effectiveCost = getEffectiveCardCost(displayedGame, 0, instance.instanceId);
  const tags = definition.tags.map((tag) => `<span>${tag}</span>`).join('');
  nodes.handPreview.innerHTML = `
    <div class="hand-preview-card" data-card-type="${definition.type}" style="--card-accent:${unit.color}">
      <span class="card-art"><img src="${unit.art}" alt="" width="200" height="260"></span>
      <span class="card-cost"><span>${effectiveCost}</span></span>
      <span class="card-level">${definition.level} 勾 · ${definition.typeLabel}</span>
      <span class="card-meta">${unit.name} / ${unit.title}</span>
      <strong class="card-name">${definition.name}</strong>
      <span class="card-text">${definition.text}</span>
      <span class="card-tags">${tags}</span>
    </div>`;
  nodes.handPreview.classList.add('is-visible');
}

function hideHandPreview() {
  nodes.handPreview.classList.remove('is-visible');
}

function renderHand() {
  const hand = displayedGame.players[0].hand;
  const freshIds = new Set(hand
    .map((card) => card.instanceId)
    .filter((instanceId) => !lastHandInstanceIds.has(instanceId)));
  if (!replaySession && freshIds.size && lastHandInstanceIds.size > 0) gameAudio.cardDraw();
  lastHandInstanceIds = new Set(hand.map((card) => card.instanceId));
  nodes.playerHand.replaceChildren(...hand.map((instance, index) => renderHandCard(instance, index, hand.length, freshIds)));
  const playerResponding = displayedGame.responseWindow?.playerIndex === 0;
  nodes.playableCardCount.textContent = replaySession ? 0 : hand.filter((card) => (
    canPlayCard(displayedGame, 0, card.instanceId) && (!aiBusy || playerResponding)
  )).length;
  if (hand.length === 0) {
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
  nodes.playerCoreBar.classList.toggle('is-low', player.avatarHp <= player.maxAvatarHp * 0.3);
  nodes.playerEnergy.textContent = player.energy;
  nodes.playerMaxEnergy.textContent = player.maxEnergy;
  nodes.playerDeck.textContent = player.deck.length;
  nodes.playerHandCount.textContent = player.hand.length;
  nodes.enemyCoreHp.textContent = enemy.avatarHp;
  nodes.enemyCoreBar.style.width = `${(enemy.avatarHp / enemy.maxAvatarHp) * 100}%`;
  nodes.enemyCoreBar.classList.toggle('is-low', enemy.avatarHp <= enemy.maxAvatarHp * 0.3);
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
  if (!nodes.divinationDialog.open) {
    nodes.divinationDialog.showModal();
    gameAudio.divinationOpen();
  }
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
  gameAudio.turnSwitch(playerTurn);
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
  nodes.attackLabel.textContent = attacker ? '出击' : '无法出击';
  nodes.attackButton.title = attacker ? `${attacker.name}出击，消耗 1 点鬼火` : '当前没有可出击角色';
  nodes.levelLabel.textContent = attacker ? '升勾' : '无法升勾';
  nodes.levelButton.title = attacker ? `免费提升 ${attacker.name} 的勾玉等级` : '当前没有可升勾角色';
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
  playImpactSfx();
  // 幻境部署检测：场上幻境总数增加时播放展开音效
  const realmTotal = displayedGame.players[0].realms.length + displayedGame.players[1].realms.length;
  if (!replaySession && realmTotal > lastRealmTotal && lastRealmTotal >= 0 && battleStarted) gameAudio.realmDeploy();
  lastRealmTotal = realmTotal;
  const responseWindow = displayedGame.responseWindow;
  const responseKey = responseWindow ? `${responseWindow.playerIndex}:${responseWindow.depth}` : '';
  if (responseKey && responseKey !== lastResponseWindowKey) gameAudio.response();
  lastResponseWindowKey = responseKey;
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
    if (selectedAttackUnitId !== unitId) gameAudio.selectTick();
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
  gameAudio.cardPlay();
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
  gameAudio.attackLunge();
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
  gameAudio.levelUp();
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
    if (command.type === 'play-card') gameAudio.cardPlay();
    else if (command.type === 'attack') gameAudio.attackLunge();
    else if (command.type === 'level-up') gameAudio.levelUp();
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
  if (won) gameAudio.victory(); else gameAudio.defeat();
  nodes.resultRounds.textContent = getRound(game);
  nodes.resultCards.textContent = player.cardsPlayed;
  nodes.resultDamage.textContent = player.damageDealt;
  const rewardOutcome = grantMatchReward(collection, won);
  collection = rewardOutcome.collection;
  saveCollection();
  nodes.resultReward.textContent = `御札 +${rewardOutcome.reward} · 现有 ${collection.balance}`;
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
  lastFeedbackSfxKey = '';
  lastResponseWindowKey = '';
  lastHandInstanceIds = new Set();
  lastRealmTotal = 0;
  render();
  announce('新对局已建立。', 'success');
}

nodes.formationStartButton.addEventListener('click', startBattle);
nodes.lineupStepButton.addEventListener('click', () => setFormationStep('lineup'));
nodes.deckStepButton.addEventListener('click', () => setFormationStep('deck'));
nodes.deckAutofillButton.addEventListener('click', autofillActiveDeck);
nodes.collectionButton.addEventListener('click', showCollection);
nodes.collectionBackButton.addEventListener('click', hideCollection);
nodes.packOpenButton.addEventListener('click', openPackFlow);
nodes.packRevealCloseButton.addEventListener('click', () => { nodes.packReveal.hidden = true; });
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
nodes.audioToggleButton.addEventListener('click', () => {
  syncAudioDialog();
  nodes.audioDialog.showModal();
});
nodes.menuButton.addEventListener('click', () => nodes.menuDialog.showModal());
nodes.menuCloseButton.addEventListener('click', () => nodes.menuDialog.close());
// 从菜单打开对应功能时自动收起菜单
for (const id of ['formation-button', 'battle-log-button', 'session-button', 'rules-button']) {
  document.getElementById(id).addEventListener('click', () => {
    if (nodes.menuDialog.open) nodes.menuDialog.close();
  });
}
nodes.audioCloseButton.addEventListener('click', () => nodes.audioDialog.close());
nodes.audioEnabledCheckbox.addEventListener('change', () => {
  gameAudio.setEnabled(nodes.audioEnabledCheckbox.checked);
  if (gameAudio.enabled) gameAudio.setScene(nodes.gameShell.hidden ? 'formation' : 'battle');
});
nodes.audioMasterVolume.addEventListener('input', (event) => gameAudio.setMasterVolume(Number(event.target.value) / 100));
nodes.audioMusicVolume.addEventListener('input', (event) => gameAudio.setMusicVolume(Number(event.target.value) / 100));
nodes.audioSfxVolume.addEventListener('input', (event) => gameAudio.setSfxVolume(Number(event.target.value) / 100));

function syncAudioDialog() {
  nodes.audioEnabledCheckbox.checked = gameAudio.enabled;
  nodes.audioMasterVolume.value = Math.round(gameAudio.masterVolume * 100);
  nodes.audioMusicVolume.value = Math.round(gameAudio.musicVolume * 100);
  nodes.audioSfxVolume.value = Math.round(gameAudio.sfxVolume * 100);
}

// 首次交互解锁音频并进入当前场景的 BGM
document.addEventListener('pointerdown', () => {
  gameAudio.unlock();
  gameAudio.setScene(nodes.gameShell.hidden ? 'formation' : 'battle');
}, { once: true, capture: true });

// 统一的按钮音效：普通按钮用叩击音，卡牌/单位选择用清脆 tick
document.addEventListener('click', (event) => {
  const target = event.target instanceof Element ? event.target : null;
  if (!target) return;
  if (target.closest('.hand-card, .unit-card, .roster-card, .formation-slot, .deck-unit-tab, .pool-card-controls')) return;
  if (target.closest('button')) gameAudio.uiTap();
}, { capture: true });
nodes.divinationDialog.addEventListener('cancel', (event) => event.preventDefault());

document.addEventListener('keydown', (event) => {
  if (event.key !== 'Escape') return;
  if (nodes.battleLogDialog.open || nodes.rulesDialog.open || nodes.sessionDialog.open || nodes.resultDialog.open) return;
  if (replaySession) {
    exitCommandReplay();
    return;
  }
  if (!nodes.collectionScreen.hidden) {
    hideCollection();
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
