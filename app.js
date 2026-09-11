import { createBattleRenderer } from './battle-render.js?v=e4daa5a4';
import { createBattleFx } from './battle-fx.js?v=e4daa5a4';
import {
  DEFAULT_PLAYER_LINEUP,
  GAME_RULES,
  UNIT_DEFINITIONS,
  basicAttack,
  createDefaultDeckDefinition,
  createGame,
  deserializeGame,
  endTurn,
  getCardDefinition,
  getCardArt,
  getCardPlayability,
  getCardsForUnit,
  getPlayerKeywordStatuses,
  getKeywordStatusText,
  canMulligan,
  getRound,
  getUnitDefinition,
  getValidCombatTargets,
  getValidTargets,
  isUpgradePending,
  levelUpUnit,
  mulliganCard,
  passResponse,
  playCard,
  resolveDivinationChoice,
  serializeGame,
  validateDeckDefinition,
} from './game-core.js?v=e4daa5a4';
import { chooseAiCommand } from './game-ai.js?v=e4daa5a4';
import { gameAudio } from './game-audio.js?v=e4daa5a4';
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
  ownedHoloCopies,
  serializeCollection,
} from './game-collection.js?v=e4daa5a4';
import {
  canUpgradeUnit,
  captureBattleSnapshot,
  deriveBattleFeedback,
} from './game-presentation.js?v=e4daa5a4';
import {
  appendCommand,
  createCommandReplay,
  createCommandJournal,
  createSessionSave,
  restoreSessionSave,
} from './game-session.js?v=e4daa5a4';
import {
  holoLayers,
  holoSheenMarkup,
  initCollectionHolo,
  initPreviewHolo,
  initRevealHolo,
} from './card-holo.js?v=e4daa5a4';

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
  codexHolo: document.querySelector('#codex-holo'),
  battleStage: document.querySelector('.battle-stage'),
  battleFeedback: document.querySelector('#battle-feedback'),
  cardRevealPlayer: document.querySelector('#card-reveal-player'),
  cardRevealEnemy: document.querySelector('#card-reveal-enemy'),
  targetingOverlay: document.querySelector('#targeting-overlay'),
  targetingPath: document.querySelector('#targeting-path'),
  targetingHead: document.querySelector('#targeting-head'),
  targetingDot: document.querySelector('#targeting-dot'),
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
  playerBattle: document.querySelector('#player-battle'),
  enemyBattle: document.querySelector('#enemy-battle'),
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
  attackMarker: document.querySelector('#attack-marker'),
  enemyEnergyPips: document.querySelector('#enemy-energy-pips'),
  enemyMaxEnergy: document.querySelector('#enemy-max-energy'),
  enemyDeckPile: document.querySelector('#enemy-deck-pile'),
  playerDeckPile: document.querySelector('#player-deck-pile'),
  mulliganBar: document.querySelector('#mulligan-bar'),
  mulliganHint: document.querySelector('#mulligan-hint'),
  mulliganDoneButton: document.querySelector('#mulligan-done-button'),
  realmPreviewDialog: document.querySelector('#realm-preview-dialog'),
  realmPreviewTitle: document.querySelector('#realm-preview-title'),
  realmPreviewBody: document.querySelector('#realm-preview-body'),
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
  themeButton: document.querySelector('#theme-button'),
  themeLabel: document.querySelector('#theme-label'),
  audioCloseButton: document.querySelector('#audio-close-button'),
  audioEnabledCheckbox: document.querySelector('#audio-enabled-checkbox'),
  audioMasterVolume: document.querySelector('#audio-master-volume'),
  audioMusicVolume: document.querySelector('#audio-music-volume'),
  audioSfxVolume: document.querySelector('#audio-sfx-volume'),
  bgmClassicButton: document.querySelector('#bgm-classic-button'),
  bgmHotButton: document.querySelector('#bgm-hot-button'),
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
let selectedAttackUnitId = null;
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
// 正在拖拽施放的手牌实例 id（法术 / 治疗 / 战斗牌拖到目标身上触发）
let draggedCardInstanceId = null;
// 开局调度条被玩家手动关闭
let mulliganDismissed = false;
// 本局失序体的随机编成（用于开战播报）
let lastEnemyLineup = [];
let lastFeedbackSfxKey = '';
let lastResponseWindowKey = '';
let lastHandInstanceIds = new Set();
let lastRealmTotal = 0;

const { renderUnit, renderRealmColumn, renderUnitRow, renderBattleStrip, renderUnits, renderHandCard, showHandPreview, hideHandPreview, renderHand } = createBattleRenderer({
  handleCoreTarget, nodes, selectionTarget, currentSelectedCard, frontUidOf, unitByUid, makeStatus, handleUnitClick, startCardTargeting, markDropZones, endTargeting, clearDropZones, performBasicAttack, openRealmPreview, handleRealmClick, getDragTargetMode, markCardDropZones, handleCardClick,
  get displayedGame() { return displayedGame; },
  get replaySession() { return replaySession; },
  get selectedCardId() { return selectedCardId; },
  get selectedAttackUnitId() { return selectedAttackUnitId; },
  get aiBusy() { return aiBusy; },
  get visualFeedback() { return visualFeedback; },
  get mulliganDismissed() { return mulliganDismissed; },
  get lastHandInstanceIds() { return lastHandInstanceIds; },
  get draggedAttackUnitId() { return draggedAttackUnitId; },
  get draggedCardInstanceId() { return draggedCardInstanceId; },
  set selectedAttackUnitId(value) { selectedAttackUnitId = value; },
  set lastHandInstanceIds(value) { lastHandInstanceIds = value; },
  set draggedAttackUnitId(value) { draggedAttackUnitId = value; },
  set draggedCardInstanceId(value) { draggedCardInstanceId = value; },
});

const fxToggle = document.querySelector('#battle-3d-toggle');
let fxEnabled = true;
try { fxEnabled = localStorage.getItem('nexus-front:3d') !== 'off'; } catch { /* settings may be unavailable */ }
fxToggle.checked = fxEnabled;
const battleFx = createBattleFx({
  stage: nodes.battleStage,
  surface: document.querySelector('.game-main'),
  enabled: fxEnabled,
  onStatus(status) {
    document.querySelector('#battle-3d-status').textContent = status.reducedMotion
      ? '减少动态效果：使用 2D' : status.unavailable ? '当前环境使用 2D' : status.enabled ? '卡牌光照 · 夜樱灯火 · 交战特效' : '已关闭，使用 2D';
  },
});
fxToggle.addEventListener('change', () => {
  battleFx.setEnabled(fxToggle.checked);
  try { localStorage.setItem('nexus-front:3d', fxToggle.checked ? 'on' : 'off'); } catch { /* session-only preference */ }
});
window.addEventListener('pagehide', () => battleFx.setActive(false));
window.addEventListener('pageshow', () => battleFx.setActive(battleStarted && !nodes.gameShell.hidden && game.winner === null));
// Read-only presentation diagnostics for renderer lifecycle acceptance.
export function getBattleFxDiagnostics() { return battleFx.diagnostics(); }

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
  nodes.codexHolo.textContent = `${stats.distinctHoloOwned} 种闪卡`;
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
      const holoCopies = ownedHoloCopies(collection, card.id);
      const tile = document.createElement('article');
      tile.className = 'codex-tile';
      tile.classList.toggle('is-holo', holoCopies > 0);
      tile.classList.toggle('is-holo-epic', holoCopies > 0 && (card.rarity === 'epic' || card.rarity === 'ssr'));
      tile.classList.toggle('is-holo-rare', holoCopies > 0 && card.rarity !== 'epic' && card.rarity !== 'ssr');
      tile.dataset.rarity = card.rarity;
      tile.dataset.owned = String(copies);
      tile.title = `${card.text}${holoCopies ? `\n闪卡 ${holoCopies} / ${copies}` : ''}`;
      const pips = Array.from({ length: COLLECTION_RULES.maxCopies }, (_, index) => (
        `<i class="${index < copies ? 'is-filled' : ''}${index < holoCopies ? ' is-holo-copy' : ''}"></i>`
      )).join('');
      tile.innerHTML = `
        <span class="tile-name">${card.name}</span>
        <span class="tile-type">${card.typeLabel} · <i>${RARITY_LABELS[card.rarity]}</i> · ${card.level}勾</span>
        ${holoCopies ? `<span class="tile-holo">闪卡 ${holoCopies} / ${copies}</span>` : ''}
        <span class="tile-pips">${pips}</span>`;
      tile.append(...holoLayers(holoCopies > 0));
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
    // 闪卡是独立外观变体，不再由稀有度自动触发。
    if (entry.isHolo) {
      el.classList.add('is-holo', entry.rarity === 'epic' || entry.rarity === 'ssr' ? 'is-holo-epic' : 'is-holo-rare');
    }
    el.style.setProperty('--reveal-delay', `${index * 0.14}s`);
    el.innerHTML = `
      <span class="reveal-art"><img src="${getCardArt(card) ?? unit.art}" alt="" width="200" height="260"></span>
      <span class="reveal-cost"><i>${card.cost}</i></span>
      <span class="reveal-rarity-tag">${RARITY_LABELS[entry.rarity]}</span>
      <strong class="reveal-name">${card.name}</strong>
      <span class="reveal-type">${unit.name} · ${card.typeLabel}</span>
      <span class="reveal-state ${entry.isNew ? 'is-new' : 'is-dupe'}">${entry.isHolo ? '闪卡 · ' : ''}${entry.isNew ? 'NEW' : `御札 +${entry.converted}`}</span>
      ${holoSheenMarkup(entry.isHolo)}`;
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
    holoCardIds: allInstances
      .filter((instance) => instance.isHolo === true)
      .map((instance) => instance.definitionId),
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
    selectedAttackUnitId = frontUidOf(game.players[0]);
    aiBusy = aiHasControl();
    resultShown = false;
  mulliganDismissed = false;
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

// 失序体随机编成：从全部角色中随机抽 4 名（允许与玩家阵容重合，增加 PVE 变化）
function pickEnemyLineup() {
  const pool = UNIT_DEFINITIONS.map((unit) => unit.id);
  const picked = [];
  while (picked.length < 4 && pool.length) {
    picked.push(...pool.splice(Math.floor(Math.random() * pool.length), 1));
  }
  return picked;
}

// 战斗区角色的有效 uid；战斗区为空或角色已气绝时返回 null
function frontUidOf(player) {
  const front = unitByUid(player, player.frontUnitId);
  return front?.hp > 0 ? front.uid : null;
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

function addOwnedHoloVariants(deckDefinition) {
  const remainingByCard = new Map();
  deckDefinition.cardIds.forEach((cardId) => {
    if (!remainingByCard.has(cardId)) {
      remainingByCard.set(cardId, ownedHoloCopies(collection, cardId));
    }
  });
  const holoCardIds = deckDefinition.cardIds.filter((cardId) => {
    const remaining = remainingByCard.get(cardId) ?? 0;
    if (remaining <= 0) return false;
    remainingByCard.set(cardId, remaining - 1);
    return true;
  });
  return { ...deckDefinition, holoCardIds };
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
  const deckLimit = getCardDefinition(cardId)?.deckLimit ?? GAME_RULES.copiesPerCard;
  const currentCount = selected.filter((candidate) => candidate === cardId).length;
  if (delta > 0) {
    if (currentCount >= deckLimit) return;
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

    const tags = card.tags.slice(0, 3).map((tag) => `<span>${tag}</span>`).join('');
    article.innerHTML = `
      <div class="pool-card-art"><img src="${getCardArt(card) ?? unit.art}" alt="" width="200" height="260"><b><i>${card.cost}</i></b><em>${card.level} 勾</em></div>
      <div class="pool-card-copy"><small>${card.typeLabel} · <i class="rar-${card.rarity}">${RARITY_LABELS[card.rarity] ?? card.rarity}</i></small><strong>${card.name}</strong><p>${card.text}</p><div>${tags}</div></div>
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
    counter.textContent = `${count} / ${card.deckLimit ?? GAME_RULES.copiesPerCard}`;
    counter.classList.toggle('maxed', count === (card.deckLimit ?? GAME_RULES.copiesPerCard));
    const add = document.createElement('button');
    add.type = 'button';
    add.textContent = '+';
    add.title = `增加一张${card.name}`;
    add.setAttribute('aria-label', `增加一张${card.name}`);
    const owned = ownedCopies(collection, card.id);
    const cardLimit = card.deckLimit ?? GAME_RULES.copiesPerCard;
    add.disabled = count >= cardLimit
      || count >= owned
      || selected.length >= GAME_RULES.cardsPerUnit;
    if (count >= owned && count < cardLimit) {
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
  battleFx.setActive(false);
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
  battleFx.setActive(game.winner === null);
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
  lockedPlayerDeckDefinition = addOwnedHoloVariants(structuredClone(deckDefinition));
  const enemyLineup = pickEnemyLineup();
  game = createGame({ playerDeckDefinition: lockedPlayerDeckDefinition, enemyUnitIds: enemyLineup });
  commandJournal = createCommandJournal(game);
  lastEnemyLineup = enemyLineup;
  selectedCardId = null;
  selectedAttackUnitId = frontUidOf(game.players[0]);
  aiBusy = false;
  resultShown = false;
  mulliganDismissed = false;
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
  if (lastEnemyLineup.length) {
    const names = lastEnemyLineup.map((id) => UNIT_DEFINITIONS.find((unit) => unit.id === id)?.name ?? id);
    setTimeout(() => announce(`失序体编成：${names.join(' / ')}`, 'neutral'), 900);
  }
}

/** 手牌拖拽：判定该卡是否支持「拖到目标身上施放」及其目标类别 */
function getDragTargetMode(definition) {
  if (!definition) return null;
  if (['ally-unit', 'knocked-ally'].includes(definition.target)) return 'ally';
  if (definition.target === 'enemy-unit') return 'enemy';
  if (definition.effect === 'assault') return 'combat';
  return null;
}

/** 点亮这张手牌的全部合法落点（角色卡与幻境） */
function markCardDropZones(definition) {
  const mode = getDragTargetMode(definition);
  if (!mode) return;
  const uids = mode === 'combat'
    ? getValidCombatTargets(displayedGame, 0)
    : getValidTargets(displayedGame, 0, definition.id);
  document.querySelectorAll('.unit-card').forEach((el) => {
    if (uids.includes(el.dataset.unitId)) el.classList.add('is-drop-ready');
  });
  if (mode === 'combat') {
    nodes.enemyRealms.querySelectorAll('.realm-chip:not(:disabled)').forEach((chip) => chip.classList.add('is-drop-ready'));
    // 敌方战斗区为空时，空槽位也是合法落点：直击核心
    document.querySelectorAll('#enemy-battle .empty-front-slot, #player-battle .empty-front-slot')
      .forEach((el) => el.classList.add('is-drop-ready'));
  }
}

// ---------------------------------------------------------------- 指示箭头
// 拖拽卡牌/角色时：一条弧形虚线箭头从起点跟随鼠标，合法目标显示虚圈

const targetingState = { active: false, kind: null, originX: 0, originY: 0 };

function showTargetingArrow(kind, originX, originY) {
  targetingState.active = true;
  targetingState.kind = kind;
  targetingState.originX = originX;
  targetingState.originY = originY;
  nodes.targetingOverlay.dataset.kind = kind;
  nodes.targetingOverlay.classList.add('is-active');
}

function updateTargetingArrow(x, y) {
  if (!targetingState.active) return;
  const { originX, originY } = targetingState;
  nodes.targetingDot.setAttribute('cx', x);
  nodes.targetingDot.setAttribute('cy', y);
  const dx = x - originX;
  const dy = y - originY;
  if (Math.hypot(dx, dy) < 14) {
    nodes.targetingPath.setAttribute('d', '');
    nodes.targetingHead.setAttribute('points', '');
    return;
  }
  // 弧线控制点：垂直于连线方向偏移，形成自然弓形
  const mx = (originX + x) / 2 - dy * 0.18;
  const my = (originY + y) / 2 + dx * 0.18;
  nodes.targetingPath.setAttribute('d', `M ${originX} ${originY} Q ${mx} ${my} ${x} ${y}`);
  // 箭头三角：朝向曲线末端切线方向
  const angle = Math.atan2(y - my, x - mx);
  const size = 13;
  const a1 = angle + Math.PI * 0.85;
  const a2 = angle - Math.PI * 0.85;
  nodes.targetingHead.setAttribute('points', [
    `${x + Math.cos(angle) * size * 0.6},${y + Math.sin(angle) * size * 0.6}`,
    `${x + Math.cos(a1) * size},${y + Math.sin(a1) * size}`,
    `${x + Math.cos(a2) * size},${y + Math.sin(a2) * size}`,
  ].join(' '));
}

function hideTargetingArrow() {
  targetingState.active = false;
  nodes.targetingOverlay.classList.remove('is-active');
  nodes.targetingPath.setAttribute('d', '');
  nodes.targetingHead.setAttribute('points', '');
  nodes.targetingDot.setAttribute('cx', '-100');
  nodes.targetingDot.setAttribute('cy', '-100');
  document.querySelectorAll('.is-targeting').forEach((el) => el.classList.remove('is-targeting'));
}

// 文档级 dragover：捕获指针坐标更新箭头，并为悬停中的合法目标加虚圈
document.addEventListener('dragover', (event) => {
  if (!targetingState.active) return;
  updateTargetingArrow(event.clientX, event.clientY);
  const el = event.target.closest?.('.is-drop-ready');
  document.querySelectorAll('.is-targeting').forEach((item) => {
    if (item !== el) item.classList.remove('is-targeting');
  });
  if (el && el !== event.target) el.classList.add('is-targeting');
  else if (el === event.target) el.classList.add('is-targeting');
});

/** 卡牌拖拽起手：记录起点并显示箭头 */
function startCardTargeting(card, kind) {
  const rect = card.getBoundingClientRect();
  showTargetingArrow(kind, rect.left + rect.width / 2, rect.top + rect.height / 2);
}

/** 卡牌拖拽结束：收起箭头与虚圈 */
function endTargeting() {
  hideTargetingArrow();
}

/** 卡牌拖拽落点：容器级监听，气绝等禁用态卡牌也能作为目标 */
function attachCardDropTarget(container) {
  container.addEventListener('dragover', (event) => {
    if (!draggedCardInstanceId) return;
    const el = event.target.closest('.unit-card, .realm-chip, .empty-front-slot');
    if (!el || !el.classList.contains('is-drop-ready')) return;
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
    el.classList.add('is-drag-over');
  });
  container.addEventListener('dragleave', (event) => {
    const el = event.target.closest('.unit-card, .realm-chip, .empty-front-slot');
    if (el && !el.contains(event.relatedTarget)) el.classList.remove('is-drag-over');
  });
  container.addEventListener('drop', (event) => {
    if (!draggedCardInstanceId) return;
    const el = event.target.closest('.unit-card, .realm-chip, .empty-front-slot');
    if (!el || !el.classList.contains('is-drop-ready')) return;
    event.preventDefault();
    const instanceId = draggedCardInstanceId;
    draggedCardInstanceId = null;
    document.body.classList.remove('is-dragging');
    endTargeting();
    clearDropZones();
    commitCard(instanceId, el.dataset.unitId ?? el.dataset.realmId ?? null);
  });
}

/** 拖拽出击时点亮可打击目标（敌方战斗区角色、双方战斗区槽位 + 敌方幻境） */
function markDropZones() {
  nodes.enemyBattle.querySelector('.unit-card.is-front')?.classList.add('is-drop-ready');
  nodes.enemyBattle.classList.add('is-drop-ready');
  nodes.playerBattle.classList.add('is-drop-ready');
  nodes.enemyRealms.querySelectorAll('.realm-chip:not(:disabled)').forEach((chip) => chip.classList.add('is-drop-ready'));
}

function clearDropZones() {
  [nodes.enemyUnits, nodes.playerUnits, nodes.enemyBattle, nodes.playerBattle].forEach((el) => {
    el.querySelectorAll('.is-drop-ready, .is-drag-over').forEach((item) => item.classList.remove('is-drop-ready', 'is-drag-over'));
    el.classList.remove('is-drop-ready', 'is-drag-over');
  });
  nodes.enemyRealms.querySelectorAll('.is-drop-ready, .is-drag-over').forEach((el) => el.classList.remove('is-drop-ready', 'is-drag-over'));
}

function attachBattleDrop(container) {
  // 拖拽己方准备区角色到战斗区槽位 = 直接出击（自动结算：打对方战斗区角色或直击核心）
  container.addEventListener('dragover', (event) => {
    if (!draggedAttackUnitId) return;
    event.preventDefault();
    event.dataTransfer.dropEffect = 'move';
    container.classList.add('is-drag-over');
  });
  container.addEventListener('dragleave', (event) => {
    if (!container.contains(event.relatedTarget)) container.classList.remove('is-drag-over');
  });
  container.addEventListener('drop', (event) => {
    event.preventDefault();
    const unitId = draggedAttackUnitId ?? event.dataTransfer.getData('text/plain');
    draggedAttackUnitId = null;
    document.body.classList.remove('is-dragging');
    endTargeting();
    clearDropZones();
    if (unitId) performBasicAttack(unitId);
  });
}

function renderResources() {
  const player = displayedGame.players[0];
  const enemy = displayedGame.players[1];
  nodes.playerCore.setAttribute('aria-label', `巡界者，核心生命 ${player.avatarHp}/${player.maxAvatarHp}，鬼火 ${player.energy}/${player.maxEnergy}`);
  nodes.enemyCore.setAttribute('aria-label', `失序体，核心生命 ${enemy.avatarHp}/${enemy.maxAvatarHp}，鬼火 ${enemy.energy}/${enemy.maxEnergy}，手牌 ${enemy.hand.length}`);
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
  nodes.enemyEnergy.textContent = enemy.energy;
  nodes.enemyMaxEnergy.textContent = enemy.maxEnergy;
  nodes.attackMarker.classList.toggle('is-used', player.attackUsed || Boolean(replaySession));
  nodes.enemyDeck.textContent = enemy.deck.length;
  nodes.enemyHand.textContent = enemy.hand.length;
  nodes.sessionButton.disabled = aiBusy || Boolean(replaySession);
  nodes.formationButton.disabled = Boolean(replaySession);
  nodes.restartButton.disabled = Boolean(replaySession);
  const renderFlames = (container, filled, total) => {
    container.replaceChildren(...Array.from({ length: total }, (_, index) => {
      const pip = document.createElement('i');
      pip.className = index < filled ? 'is-filled' : '';
      return pip;
    }));
  };
  renderFlames(nodes.energyPips, player.energy, player.maxEnergy);
  renderFlames(nodes.enemyEnergyPips, enemy.energy, enemy.maxEnergy);
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
  // 开局调度条：首回合行动前可替换最多 2 张手牌
  const mulliganActive = !replaySession && !mulliganDismissed && canMulligan(game, 0);
  nodes.mulliganBar.hidden = !mulliganActive;
  if (mulliganActive) {
    const left = GAME_RULES.mulliganCount - game.players[0].mulligansUsed;
    nodes.mulliganHint.innerHTML = `开局调度：点击手牌替换，剩余 <b>${left}</b> 次`;
  }
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
  // 数字大小随伤害值变化
  number.style.setProperty('--impact-scale', String(1 + Math.min(8, Math.abs(impact.hpDelta)) * 0.05));
  number.append(label, value);
  coreNode.append(number);
}

function renderBattleFeedback() {
  // 出牌卡面展示：己方卡面从左侧弹出，敌方从右侧
  const cardPlayed = visualFeedback.cardPlayed;
  if (cardPlayed?.definitionId) {
    const container = cardPlayed.playerIndex === 0 ? nodes.cardRevealPlayer : nodes.cardRevealEnemy;
    const revealKey = cardPlayed.instanceId ?? cardPlayed.definitionId;
    if (container.dataset.revealKey !== revealKey) {
      const definition = getCardDefinition(cardPlayed.definitionId);
      const unit = getUnitDefinition(definition.unitId);
      container.dataset.revealKey = revealKey;
      container.classList.toggle('is-holo', cardPlayed.isHolo);
      container.classList.toggle('is-holo-epic', cardPlayed.isHolo && (definition.rarity === 'epic' || definition.rarity === 'ssr'));
      container.innerHTML = `
        <span class="reveal-art"><img src="${getCardArt(definition) ?? unit.art}" alt="" width="120" height="156"></span>
        <span class="reveal-meta"><b>${definition.name}</b><small>${unit.name} / ${definition.typeLabel}${cardPlayed.isHolo ? ' / 闪卡' : ''}</small></span>
        ${holoSheenMarkup(cardPlayed.isHolo)}`;
      container.classList.remove('is-visible');
      void container.offsetWidth;
      container.classList.add('is-visible');
      clearTimeout(Number(container.dataset.timer));
      container.dataset.timer = String(setTimeout(() => {
        container.classList.remove('is-visible');
        delete container.dataset.revealKey;
      }, 1500));
    }
  } else {
    [nodes.cardRevealPlayer, nodes.cardRevealEnemy].forEach((container) => {
      if (!cardPlayed) delete container.dataset.revealKey;
    });
  }
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
  if (!defender || defender.hp <= 0) return `出击预估：${attacker.name} 将进入战斗区并直击敌方核心，造成 ${attackPower} 点伤害${statusText}。`;
  const outgoing = Math.max(0, attackPower + (defender.brittle > 0 ? 1 : 0) - defender.shield);
  const counter = defender.frozen > 0 ? 0 : Math.max(0, defender.attack - shield);
  const movement = attacker.uid === displayedGame.players[0].frontUnitId ? '已在战斗区出击' : '从准备区进入战斗区';
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
  const upgradePending = isUpgradePending(displayedGame, 0);
  const livingUnits = player.units;
  const minimumLevel = livingUnits.length
    ? Math.min(...livingUnits.map((unit) => unit.level))
    : GAME_RULES.maxUnitLevel;
  let viewAttackUnitId = replaySession ? frontUidOf(player) : selectedAttackUnitId;
  const currentAttacker = unitByUid(player, viewAttackUnitId);
  if (!currentAttacker || (!upgradePending && currentAttacker.hp <= 0) || (upgradePending && currentAttacker.level !== minimumLevel)) {
    viewAttackUnitId = (upgradePending
      ? livingUnits.find((unit) => unit.level === minimumLevel)?.uid
      : frontUidOf(player))
      ?? livingUnits[0]?.uid
      ?? null;
    if (!replaySession) selectedAttackUnitId = viewAttackUnitId;
  }
  const attacker = unitByUid(player, viewAttackUnitId);
  const playerResponding = !replaySession && displayedGame.responseWindow?.playerIndex === 0 && displayedGame.winner === null;
  const userTurn = !replaySession && displayedGame.currentPlayer === 0 && !aiBusy && displayedGame.winner === null && !displayedGame.responseWindow;
  const turnMode = replaySession ? 'replay' : displayedGame.winner !== null ? 'over' : playerResponding ? 'response' : userTurn ? 'player' : 'enemy';
  // 升级阶段强制先行：未完成升勾时禁止出击
  const hand = displayedGame.players[0].hand;
  const canAttack = userTurn && !upgradePending && !selectedCardId && attacker && attacker.hp > 0 && attacker.level >= 1 && attacker.frozen === 0 && player.energy > 0 && !player.attackUsed;
  const canLevel = userTurn && !selectedCardId && attacker && canUpgradeUnit(displayedGame, attacker.uid);
  nodes.attackButton.disabled = !canAttack;
  nodes.levelButton.disabled = !canLevel;
  nodes.levelButton.hidden = !replaySession && Boolean(selectedCardId);
  nodes.endTurnButton.disabled = !userTurn && !playerResponding;
  // 本家规则：无可行操作时结束回合自动亮起
  const noActionsLeft = userTurn
    && !upgradePending
    && player.levelUpUsed
    && player.attackUsed
    && hand.every((instance) => !getCardPlayability(displayedGame, 0, instance.instanceId).playable);
  nodes.endTurnButton.classList.toggle('is-idle-glow', Boolean(noActionsLeft));
  nodes.endTurnButton.innerHTML = playerResponding
    ? '放弃响应 <span aria-hidden="true">→</span>'
    : '结束回合 <span aria-hidden="true">→</span>';
  nodes.attackLabel.textContent = attacker ? '出击' : '无法出击';
  nodes.attackButton.title = attacker ? `${attacker.name}出击，消耗 1 点鬼火` : '当前没有可出击角色';
  nodes.levelLabel.textContent = attacker ? '升勾' : '无法升勾';
  nodes.levelButton.title = attacker ? `免费提升 ${attacker.name} 的勾玉等级${player.levelUpUsed && player.bonusUpgrades > 0 ? '（额外升勾机会）' : ''}` : '当前没有可升勾角色';
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
  } else if (upgradePending) {
    nodes.actionPrompt.textContent = '升级阶段：点击一名角色，为其提升勾玉。';
  } else if (selected) {
    const card = getCardDefinition(selected.definitionId);
    const prompts = {
      'ally-unit': '选择一名友方角色。',
      'knocked-ally': '选择一名气绝角色。',
      'enemy-unit': '选择一名敌方角色。',
    };
    nodes.actionPrompt.textContent = card.effect === 'assault'
      ? `${card.name}：选择敌方战斗区（空缺时直击核心）或一处幻境。`
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
  document.querySelector('#unit-inspect-dock').hidden = true;
  renderUnits();
  renderHand();
  battleFx.setActive(battleStarted && !nodes.gameShell.hidden && displayedGame.winner === null);
  battleFx.present(visualFeedback, displayedGame);
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
  // 开局调度：点击手牌直接替换
  if (!mulliganDismissed && canMulligan(game, 0)) {
    const swap = mulliganCard(game, 0, instance.instanceId);
    if (swap.error) {
      announce(swap.error, 'danger');
      return;
    }
    game = swap.state;
    recordCommand({ type: 'mulligan', playerIndex: 0, instanceId: instance.instanceId });
    gameAudio.cardDraw?.();
    render();
    return;
  }
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
  if (ownerIndex === 0 && unit) {
    if ((isUpgradePending(game, 0) || unit.hp <= 0) && canUpgradeUnit(game, unitId)) {
      handleLevelUp(unitId);
      return;
    }
    if (unit.hp > 0) {
      if (selectedAttackUnitId !== unitId) gameAudio.selectTick();
      selectedAttackUnitId = unitId;
      selectedCardId = null;
      render();
    }
  }
}

function handleCoreTarget() {
  const selected = currentSelectedCard();
  if (!replaySession && selected && !game.players[1].frontUnitId && getCardDefinition(selected.definitionId).effect === 'assault') commitCard(selected.instanceId, null);
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

function handleLevelUp(unitId = selectedAttackUnitId) {
  if (replaySession) return;
  selectedAttackUnitId = unitId;
  const result = levelUpUnit(game, 0, unitId);
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
  try {
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
  } catch (error) {
    // 渲染或指令抛异常时绝不能把 aiBusy 卡在 true（否则 AI 永久不动、对局软锁）
    console.error('失序体行动异常，提前收束回合。', error);
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
  const enemyLineup = pickEnemyLineup();
  lastEnemyLineup = enemyLineup;
  game = createGame({ playerDeckDefinition: lockedPlayerDeckDefinition, enemyUnitIds: enemyLineup });
  commandJournal = createCommandJournal(game);
  selectedCardId = null;
  selectedAttackUnitId = frontUidOf(game.players[0]);
  aiBusy = false;
  resultShown = false;
  mulliganDismissed = false;
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

document.querySelector('#battle-log-shortcut').addEventListener('click', () => nodes.battleLogDialog.showModal());

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
attachBattleDrop(nodes.playerBattle);
attachBattleDrop(nodes.enemyBattle);
nodes.enemyDeckPile.addEventListener('click', () => {
  announce(`敌方牌库剩余 ${displayedGame.players[1].deck.length} 张待抽。`, 'neutral');
});
nodes.playerDeckPile.addEventListener('click', () => {
  announce(`我方牌库剩余 ${displayedGame.players[0].deck.length} 张待抽。`, 'neutral');
});
const buildTagValue = document.querySelector('meta[name="build"]')?.content ?? 'dev';
const buildTagNode = document.querySelector('#build-tag span');
if (buildTagNode) buildTagNode.textContent = buildTagValue;
nodes.mulliganDoneButton.addEventListener('click', () => {
  mulliganDismissed = true;
  render();
});
nodes.realmPreviewDialog.addEventListener('close', () => {
  nodes.realmPreviewBody.replaceChildren();
});

/** 幻境小方块点击：弹出效果预览 */
function openRealmPreview(realm) {
  if (replaySession) return;
  nodes.realmPreviewTitle.textContent = realm.name;
  const keywordText = getKeywordStatusText(realm);
  nodes.realmPreviewBody.innerHTML = `
    <p class="realm-preview-vital">耐久 <b>${realm.hp}</b> / ${realm.maxHp}${keywordText ? ` · <span>${keywordText}</span>` : ''}</p>
    <p class="realm-preview-text">${realm.text}</p>`;
  if (!nodes.realmPreviewDialog.open) nodes.realmPreviewDialog.showModal();
}
// 卡牌拖拽落点：准备区行（友方/敌方目标）、战斗区带（战斗牌目标）、敌方幻境席
[nodes.playerUnits, nodes.enemyUnits, nodes.playerBattle, nodes.enemyBattle, nodes.enemyRealms]
  .forEach(attachCardDropTarget);
nodes.levelButton.addEventListener('click', () => handleLevelUp());
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

// ---------------------------------------------------------------- 主题切换
const THEME_KEY = 'nexus-front:theme';

function applyTheme(theme) {
  const value = theme === 'day' ? 'day' : 'night';
  document.documentElement.dataset.theme = value;
  if (nodes.themeLabel) nodes.themeLabel.textContent = value === 'day' ? '宣纸' : '墨夜';
  try {
    localStorage.setItem(THEME_KEY, value);
  } catch {
    /* 存储不可用时仅当前会话生效 */
  }
}

applyTheme((() => {
  try {
    return localStorage.getItem(THEME_KEY) ?? 'night';
  } catch {
    return 'night';
  }
})());

nodes.themeButton?.addEventListener('click', () => {
  applyTheme(document.documentElement.dataset.theme === 'day' ? 'night' : 'day');
});
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
function syncBgmTrackButtons() {
  const hot = gameAudio.bgmTrack === 'hot';
  nodes.bgmClassicButton.setAttribute('aria-pressed', String(!hot));
  nodes.bgmHotButton.setAttribute('aria-pressed', String(hot));
}
nodes.bgmClassicButton.addEventListener('click', () => { gameAudio.setBgmTrack('classic'); syncBgmTrackButtons(); });
nodes.bgmHotButton.addEventListener('click', () => { gameAudio.setBgmTrack('hot'); syncBgmTrackButtons(); });

function syncAudioDialog() {
  nodes.audioEnabledCheckbox.checked = gameAudio.enabled;
  syncBgmTrackButtons();
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
// 闪卡特效仅在收藏、开卷和战斗大卡预览中跟踪指针。
initCollectionHolo(nodes.codexUnits);
initPreviewHolo(nodes.playerHand, nodes.handPreview);
initRevealHolo(nodes.packRevealCards);
