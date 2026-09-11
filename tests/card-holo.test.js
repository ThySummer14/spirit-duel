import test from 'node:test';
import assert from 'node:assert/strict';

let runtimeId = 0;
async function runtime(t, reduced = false) {
  const frames = new Map();
  let frameId = 0;
  let now = 0;
  let mutations;
  let preferenceChange;
  const preference = {
    matches: reduced,
    addEventListener(type, listener) { if (type === 'change') preferenceChange = listener; },
  };
  class MockElement {
    constructor() {
      this.dataset = {};
      this.listeners = new Map();
      this.isConnected = true;
      this.values = new Map();
      this.style = {
        setProperty: (key, value) => this.values.set(key, value),
        removeProperty: (key) => this.values.delete(key),
      };
    }
    addEventListener(type, listener) { this.listeners.set(type, listener); }
    dispatch(type, card) {
      this.listeners.get(type)?.({ target: card, currentTarget: this, pointerType: 'mouse', clientX: 90, clientY: 30, relatedTarget: null });
    }
    closest() { return this; }
    contains(target) { return target === this; }
    getBoundingClientRect() { return { left: 0, top: 0, width: 100, height: 140 }; }
    querySelector() { return this.preview ?? null; }
  }
  const globals = {
    window: { matchMedia: () => preference, addEventListener() {} },
    document: { documentElement: {} },
    Element: MockElement,
    MutationObserver: class { constructor(listener) { mutations = listener; } observe() {} },
    requestAnimationFrame: (callback) => { frames.set(++frameId, callback); return frameId; },
    cancelAnimationFrame: (id) => frames.delete(id),
    performance: { now: () => now },
  };
  const originals = new Map(Object.keys(globals).map((key) => [key, Object.getOwnPropertyDescriptor(globalThis, key)]));
  for (const [key, value] of Object.entries(globals)) Object.defineProperty(globalThis, key, { configurable: true, writable: true, value });
  t.after(() => {
    for (const [key, descriptor] of originals) {
      if (descriptor) Object.defineProperty(globalThis, key, descriptor);
      else delete globalThis[key];
    }
  });
  const api = await import(`../card-holo.js?regression=${++runtimeId}`);
  return {
    api, element: () => new MockElement(), frames,
    drain() {
      for (let count = 0; frames.size && count < 300; count += 1) {
        now += 16;
        const pending = [...frames.values()];
        frames.clear();
        pending.forEach((callback) => callback(now));
      }
      assert.equal(frames.size, 0, 'pointer interpolation must settle and stop RAF');
    },
    mutate: () => mutations(),
    motion(value) { preference.matches = value; preferenceChange({ matches: value }); },
  };
}

test('collection hover settles without continuous RAF, resumes on move, and releases on leave', async (t) => {
  const r = await runtime(t);
  const container = r.element();
  const card = r.element();
  r.api.initCollectionHolo(container);
  container.dispatch('pointerover', card);
  assert.equal(r.frames.size, 1);
  r.drain();
  assert.equal(r.api.getHoloDiagnostics().activeCards, 1);
  assert.equal(r.api.getHoloDiagnostics().framePending, false);
  assert.equal(card.values.get('--holo-opacity'), '1.000');
  container.dispatch('pointermove', card);
  assert.equal(r.frames.size, 1);
  r.drain();
  container.dispatch('pointerout', card);
  r.drain();
  assert.equal(r.api.getHoloDiagnostics().activeCards, 0);
  assert.equal(card.values.get('--holo-rx'), '0.00deg');
});

test('preview replacement releases detached cards even after pointer RAF has stopped', async (t) => {
  const r = await runtime(t);
  const hand = r.element();
  const preview = r.element();
  const card = r.element();
  preview.preview = card;
  r.api.initPreviewHolo(hand, preview);
  hand.dispatch('pointerover', r.element());
  r.drain();
  assert.equal(r.api.getHoloDiagnostics().activeCards, 1);
  card.isConnected = false;
  r.mutate();
  assert.equal(r.api.getHoloDiagnostics().activeCards, 0);
  const replacement = r.element();
  preview.preview = replacement;
  hand.dispatch('pointermove', r.element());
  assert.equal(r.frames.size, 1);
  replacement.isConnected = false;
  r.mutate();
  assert.equal(r.frames.size, 0);
  assert.equal(r.api.getHoloDiagnostics().activeCards, 0);
});

test('dynamic reduced motion cancels active animation, clears variables, and restores pointer handling', async (t) => {
  const r = await runtime(t);
  const container = r.element();
  const card = r.element();
  r.api.initCollectionHolo(container);
  container.dispatch('pointerover', card);
  r.drain();
  container.dispatch('pointermove', card);
  r.motion(true);
  assert.equal(r.frames.size, 0);
  assert.equal(r.api.getHoloDiagnostics().activeCards, 0);
  assert.equal(card.values.size, 0);
  container.dispatch('pointermove', card);
  assert.equal(r.frames.size, 0);
  r.motion(false);
  container.dispatch('pointermove', card);
  assert.equal(r.frames.size, 1);
  r.drain();
  assert.equal(card.values.get('--holo-opacity'), '1.000');
});

test('initial reduced motion can be disabled without rebinding preview listeners', async (t) => {
  const r = await runtime(t, true);
  const hand = r.element();
  const preview = r.element();
  preview.preview = r.element();
  r.api.initPreviewHolo(hand, preview);
  hand.dispatch('pointerover', r.element());
  assert.equal(r.frames.size, 0);
  r.motion(false);
  hand.dispatch('pointermove', r.element());
  assert.equal(r.frames.size, 1);
  r.drain();
});
