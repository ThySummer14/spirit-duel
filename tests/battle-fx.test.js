import test from 'node:test';
import assert from 'node:assert/strict';
import { createBattleFx, ResourceTracker } from '../battle-fx.js';

test('ResourceTracker frees shared geometry/material/texture once and detaches objects', () => {
  const calls = { geometry: 0, material: 0, texture: 0, object: 0 };
  const texture = { isTexture: true, dispose: () => calls.texture++ };
  const material = { isMaterial: true, map: texture, dispose: () => calls.material++ };
  const geometry = { dispose: () => calls.geometry++ };
  const object = { isObject3D: true, children: [], material, geometry, removeFromParent: () => calls.object++ };
  const tracker = new ResourceTracker();
  tracker.track([object, material, geometry]); tracker.dispose(); tracker.dispose();
  assert.deepEqual(calls, { geometry: 1, material: 1, texture: 1, object: 1 });
  assert.equal(tracker.resources.size, 0);
});

function harness(reduced = false) {
  class Node extends EventTarget {
    constructor() { super(); this.style = {}; this.dataset = {}; this.clientWidth = 900; this.clientHeight = 700; }
    setAttribute() {}
    append(node) { this.child = node; }
    remove() { this.removed = true; }
    getContext() { return null; }
  }
  const media = new EventTarget(); media.matches = reduced;
  globalThis.window = { matchMedia: () => media, devicePixelRatio: 2 };
  globalThis.document = new Node(); document.createElement = () => new Node();
  globalThis.ResizeObserver = class { observe() {} disconnect() {} };
  globalThis.MutationObserver = class { observe() {} disconnect() {} };
  globalThis.requestAnimationFrame = () => { throw new Error('fallback must not schedule frames'); };
  globalThis.cancelAnimationFrame = () => {};
  return { stage: new Node(), media };
}

test('reduced motion and disabled mode never import Three or allocate a context', async () => {
  const { stage } = harness(true);
  let imports = 0;
  const fx = createBattleFx({ stage, loadThree: async () => { imports++; return {}; } });
  fx.setActive(true); await fx.ready(); fx.present({}, { players: [] });
  assert.equal(imports, 0); assert.equal(fx.diagnostics().contextCount, 0);
  assert.equal(stage.dataset.fx, 'reduced-motion');
  fx.dispose(); fx.dispose(); assert.equal(stage.child.removed, true);
});

test('CDN failure degrades once without rejecting DOM presentation or retry loops', async () => {
  const { stage } = harness(); let imports = 0;
  const fx = createBattleFx({ stage, loadThree: async () => { imports++; throw new Error('offline'); } });
  fx.setActive(true); await fx.ready(); fx.present({}, { players: [] });
  fx.setActive(false); fx.setActive(true); await fx.ready();
  assert.equal(imports, 1); assert.equal(fx.diagnostics().unavailable, true);
  assert.equal(fx.diagnostics().pendingFrame, false); assert.equal(stage.dataset.fx, 'unavailable'); fx.dispose();
});

test('leaving while Three loads prevents late renderer initialization', async () => {
  const { stage } = harness(); let resolve;
  const loading = new Promise((done) => { resolve = done; });
  const fx = createBattleFx({ stage, loadThree: () => loading });
  fx.setActive(true); const ready = fx.ready(); fx.setActive(false); resolve({}); await ready;
  assert.equal(fx.diagnostics().rendererCreations, 0); assert.equal(fx.diagnostics().contextCount, 0); fx.dispose();
});

test('cached Three module re-enters three times without a stale loading promise or new context', async () => {
  const { stage } = harness();
  let allocations = 0;
  document.createElement = () => {
    const node = new EventTarget(); node.style = {}; node.setAttribute = () => {}; node.remove = () => {};
    node.getContext = () => { allocations++; return {}; };
    return node;
  };
  globalThis.requestAnimationFrame = () => 1;
  const vector = () => ({ set() {}, setScalar() {} });
  class Object3D {
    constructor() { this.children = []; this.position = vector(); this.rotation = vector(); this.scale = vector(); this.isObject3D = true; }
    add(...children) { this.children.push(...children); }
    removeFromParent() {}
  }
  class Geometry { setAttribute() {} dispose() {} }
  class Material { constructor() { this.isMaterial = true; } clone() { return new Material(); } dispose() {} }
  class Mesh extends Object3D { constructor(geometry, material) { super(); this.geometry = geometry; this.material = material; } }
  class Camera extends Object3D { updateProjectionMatrix() {} }
  class Shape { constructor() { this.holes = []; } moveTo() {} lineTo() {} quadraticCurveTo() {} closePath() {} }
  class Renderer {
    constructor() { this.info = { memory: {}, programs: [] }; }
    setPixelRatio() {} getPixelRatio() { return 1; } setClearColor() {} setSize() {} clear() {} dispose() {}
  }
  const THREE = { WebGLRenderer: Renderer, Scene: Object3D, PerspectiveCamera: Camera,
    AmbientLight: Object3D, PointLight: Object3D, MeshPhysicalMaterial: Material,
    Shape, Path: Shape, ShapeGeometry: Geometry, Mesh, BufferGeometry: Geometry,
    Float32BufferAttribute: class {}, PointsMaterial: Material, Points: Mesh,
    Color: class { constructor() { this.r = this.g = this.b = 1; } } };
  const fx = createBattleFx({ stage, loadThree: async () => THREE });
  for (let i = 0; i < 4; i++) {
    fx.setActive(true); await fx.ready();
    assert.equal(fx.diagnostics().ready, true, `entry ${i + 1}`);
    fx.setActive(false);
    assert.equal(fx.diagnostics().resources, 0);
  }
  assert.equal(fx.diagnostics().rendererCreations, 4);
  assert.equal(allocations, 1);
});
