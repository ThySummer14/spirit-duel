/**
 * card-holo.js — 全息卡牌效果驱动
 *
 * 职责：跟踪悬停卡牌的指针位置，经指数平滑（帧率无关）后写入 CSS 变量，
 * 由 card-holo.css 的镭射 / 眩光 / 倾斜层消费。
 *
 * 设计要点：
 * - 单例 rAF 循环，只在有活动卡牌时运行，全部收敛后自动停止；
 * - 容器级事件委托（收藏与预览 DOM 会重建，不逐卡绑定）；
 * - 静息透明度 REST_OPACITY：不悬停时镭射仍以低强度存在，稀有度可辨识；
 * - prefers-reduced-motion：动态停止帧并清理变量，CSS 同步降级。
 */

const motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');

/** 静息态效果强度（悬停时升至 1） */
const REST_OPACITY = 0.3;
/** 倾斜幅度：光标从中心到边缘 → 最大倾斜角（deg） */
const TILT_DEGREES = 15;
/** 收敛判定阈值 */
const SETTLE_EPSILON = 0.05;

/**
 * 指数平滑器（holo-card-studio 同款缓动公式，帧率无关）：
 * value += (target - value) * (1 - exp(-rate * dt))
 */
function createSmooth(value, rate) {
  return { value, target: value, rate, settled: true };
}

function stepSmooth(smooth, dt) {
  const alpha = 1 - Math.exp(-smooth.rate * dt);
  smooth.value += (smooth.target - smooth.value) * alpha;
  if (Math.abs(smooth.target - smooth.value) < SETTLE_EPSILON) {
    smooth.value = smooth.target;
    smooth.settled = true;
  } else {
    smooth.settled = false;
  }
}

/** 每张活动卡牌的平滑器组与状态 */
function createCardState() {
  return {
    hover: false,
    px: createSmooth(50, 30),
    py: createSmooth(50, 30),
    near: createSmooth(0, 20),
    rx: createSmooth(0, 10),
    ry: createSmooth(0, 10),
    bgx: createSmooth(50, 14),
    bgy: createSmooth(50, 14),
    op: createSmooth(REST_OPACITY, 16),
  };
}

const activeCards = new Map();
let rafId = 0;
let lastTime = 0;


const POINTER_PROPERTIES = ['--pointer-x', '--pointer-y', '--holo-near', '--holo-rx',
  '--holo-ry', '--holo-bg-x', '--holo-bg-y', '--holo-opacity'];

function clearActiveCards() {
  if (rafId) cancelAnimationFrame(rafId);
  rafId = 0;
  for (const el of activeCards.keys()) {
    POINTER_PROPERTIES.forEach((property) => el.style.removeProperty(property));
  }
  activeCards.clear();
}

motionPreference.addEventListener('change', () => {
  if (motionPreference.matches) clearActiveCards();
});
window.addEventListener('pagehide', clearActiveCards);
// DOM 重建可能没有 pointerout；即使 RAF 已收敛也必须释放悬停卡引用。
const detachedObserver = new MutationObserver(() => {
  for (const el of activeCards.keys()) {
    if (!el.isConnected) activeCards.delete(el);
  }
  if (!activeCards.size && rafId) {
    cancelAnimationFrame(rafId);
    rafId = 0;
  }
});
detachedObserver.observe(document.documentElement, { childList: true, subtree: true });

/** 可用于生命周期回归的只读统计。 */
export function getHoloDiagnostics() {
  return { activeCards: activeCards.size, framePending: Boolean(rafId), reducedMotion: motionPreference.matches };
}

function writeVars(el, state) {
  const style = el.style;
  style.setProperty('--pointer-x', `${state.px.value.toFixed(2)}%`);
  style.setProperty('--pointer-y', `${state.py.value.toFixed(2)}%`);
  style.setProperty('--holo-near', state.near.value.toFixed(3));
  style.setProperty('--holo-rx', `${state.rx.value.toFixed(2)}deg`);
  style.setProperty('--holo-ry', `${state.ry.value.toFixed(2)}deg`);
  style.setProperty('--holo-bg-x', `${state.bgx.value.toFixed(2)}%`);
  style.setProperty('--holo-bg-y', `${state.bgy.value.toFixed(2)}%`);
  style.setProperty('--holo-opacity', state.op.value.toFixed(3));
}

function tick(now) {
  const dt = Math.min((now - lastTime) / 1000, 0.05) || 0.016;
  lastTime = now;
  let alive = false;
  for (const [el, state] of activeCards) {
    if (!el.isConnected) {
      activeCards.delete(el);
      continue;
    }
    let moving = false;
    for (const key of ['px', 'py', 'near', 'rx', 'ry', 'bgx', 'bgy', 'op']) {
      stepSmooth(state[key], dt);
      moving = moving || !state[key].settled;
    }
    writeVars(el, state);
    // 已离开且全部收敛 → 摘除；静止悬停不继续请求帧
    if (!state.hover && !moving) {
      activeCards.delete(el);
    }
    alive = alive || moving;
  }
  rafId = alive ? requestAnimationFrame(tick) : 0;
}

function ensureLoop() {
  if (!motionPreference.matches && !rafId) {
    lastTime = performance.now();
    rafId = requestAnimationFrame(tick);
  }
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

/** 指针事件 → 平滑器目标值（percent 坐标系） */
function updateTargets(el, state, event) {
  const rect = el.getBoundingClientRect();
  if (!rect.width || !rect.height) return;
  const x = clamp(((event.clientX - rect.left) / rect.width) * 100, 0, 100);
  const y = clamp(((event.clientY - rect.top) / rect.height) * 100, 0, 100);
  const cx = x - 50;
  const cy = y - 50;
  state.px.target = x;
  state.py.target = y;
  state.near.target = Math.min(1, Math.hypot(cx, cy) / 50);
  // 光标在右侧 → 卡面绕纵轴转向光标（rotateY）；在下方 → 绕横轴上仰（rotateX）
  state.ry.target = (cx / 50) * TILT_DEGREES;
  state.rx.target = (-cy / 50) * TILT_DEGREES;
  // 镭射纹理重映射到小邻域（pokemon-cards-css 的 background 映射手法）
  state.bgx.target = 37 + x * 0.26;
  state.bgy.target = 33 + y * 0.34;
  state.op.target = 1;
}

function resetTargets(state) {
  state.px.target = 50;
  state.py.target = 50;
  state.near.target = 0;
  state.rx.target = 0;
  state.ry.target = 0;
  state.bgx.target = 50;
  state.bgy.target = 50;
  state.op.target = REST_OPACITY;
}

function enterCard(el, event) {
  let state = activeCards.get(el);
  if (!state) {
    state = createCardState();
    activeCards.set(el, state);
  }
  state.hover = true;
  updateTargets(el, state, event);
  ensureLoop();
}

function moveCard(el, event) {
  const state = activeCards.get(el);
  if (!state) {
    enterCard(el, event);
    return;
  }
  state.hover = true;
  updateTargets(el, state, event);
  ensureLoop();
}

function leaveCard(el) {
  const state = activeCards.get(el);
  if (state) {
    state.hover = false;
    resetTargets(state);
    ensureLoop();
  }
}

/**
 * 在容器上启用全息指针跟踪（事件委托，选择器可定制）。
 * 手牌与开包揭示卡共用同一套驱动，CSS 端决定变量消费方式。
 * @param {Element} container 卡牌所在容器
 * @param {string} selector 卡牌选择器
 */
function initHoloPointer(container, selector) {
  if (!container) return;
  const boundKey = 'holoBound' + selector.replace(/[^a-zA-Z]/g, '');
  if (container.dataset[boundKey] === '1') return;
  container.dataset[boundKey] = '1';

  const cardOf = (target) => (target instanceof Element ? target.closest(selector) : null);

  container.addEventListener('pointerover', (event) => {
    if (motionPreference.matches || event.pointerType === 'touch') return; // 触屏点按不需要悬停跟踪
    const card = cardOf(event.target);
    if (card) enterCard(card, event);
  });

  container.addEventListener('pointermove', (event) => {
    if (motionPreference.matches || event.pointerType === 'touch') return;
    const card = cardOf(event.target);
    if (card) moveCard(card, event);
  });

  container.addEventListener('pointerout', (event) => {
    if (motionPreference.matches || event.pointerType === 'touch') return;
    const card = cardOf(event.target);
    if (card && !card.contains(event.relatedTarget)) leaveCard(card);
  });
}

/** 战斗大卡预览：用手牌上的指针坐标驱动独立预览层。 */
export function initPreviewHolo(handContainer, previewContainer) {
  if (!handContainer || !previewContainer || handContainer.dataset.holoPreviewBound === '1') return;
  handContainer.dataset.holoPreviewBound = '1';
  const previewCard = () => previewContainer.querySelector('.hand-preview-card.is-holo');
  handContainer.addEventListener('pointerover', (event) => {
    if (motionPreference.matches || event.pointerType === 'touch') return;
    const card = previewCard();
    if (card) enterCard(card, event);
  });
  handContainer.addEventListener('pointermove', (event) => {
    if (motionPreference.matches || event.pointerType === 'touch') return;
    const card = previewCard();
    if (card) moveCard(card, event);
  });
  handContainer.addEventListener('pointerout', (event) => {
    if (motionPreference.matches || event.pointerType === 'touch') return;
    const card = previewCard();
    if (card && !event.currentTarget.contains(event.relatedTarget)) leaveCard(card);
  });
}

/** 秘闻阁图鉴：只跟踪已收藏的闪卡条目。 */
export function initCollectionHolo(container) {
  initHoloPointer(container, '.codex-tile.is-holo');
}

/** 开包揭示容器：跟踪 .reveal-card.is-holo（变量由卡片自身消费） */
export function initRevealHolo(container) {
  initHoloPointer(container, '.reveal-card.is-holo');
}

/**
 * 生成闪卡的全息效果层。
 * @param {boolean} enabled 当前副本是否为闪卡
 * @returns {HTMLSpanElement[]}
 */
export function holoLayers(enabled) {
  if (!enabled) return [];
  const foil = document.createElement('span');
  foil.className = 'card-holo-foil';
  foil.setAttribute('aria-hidden', 'true');
  const glare = document.createElement('span');
  glare.className = 'card-holo-glare';
  glare.setAttribute('aria-hidden', 'true');
  return [foil, glare];
}

/**
 * 开包揭示卡的扫光层标记（注入到 innerHTML 模板中）。
 * @param {boolean} enabled
 * @returns {string} 闪卡返回 sheen span 标记，否则空串
 */
export function holoSheenMarkup(enabled) {
  if (!enabled) return '';
  return '<span class="card-holo-sheen" aria-hidden="true"></span>';
}
