/** Optional, state-free Three.js presentation. No game action is dispatched here. */
export class ResourceTracker {
  constructor() { this.resources = new Set(); }
  track(resource) {
    if (!resource) return resource;
    if (Array.isArray(resource)) { resource.forEach((item) => this.track(item)); return resource; }
    if (resource.dispose || resource.isObject3D) this.resources.add(resource);
    if (resource.isObject3D) {
      this.track(resource.geometry);
      this.track(resource.material);
      resource.children.forEach((child) => this.track(child));
    }
    if (resource.isMaterial) Object.values(resource).filter((value) => value?.isTexture).forEach((texture) => this.track(texture));
    return resource;
  }
  dispose() {
    for (const resource of this.resources) { resource.removeFromParent?.(); resource.dispose?.(); }
    this.resources.clear();
  }
}

/**
 * setActive(false) frees every GPU allocation and renderer internals. The canvas
 * and its WebGL2 context are retained; the next renderer uses that SAME context.
 * Renderer.dispose() is terminal, so we never render through a disposed wrapper.
 */
export function createBattleFx({ stage, surface = stage, enabled = true, onStatus = () => {}, loadThree = () => import('three') } = {}) {
  if (!stage) throw new TypeError('createBattleFx requires a battle stage');
  const media = window.matchMedia('(prefers-reduced-motion: reduce)');
  const canvas = document.createElement('canvas');
  canvas.className = 'battle-three-canvas';
  canvas.setAttribute('aria-hidden', 'true');
  Object.assign(canvas.style, { position: 'absolute', inset: '0', width: '100%', height: '100%', pointerEvents: 'none', zIndex: '8', display: 'none' });
  surface.append(canvas);
  let THREE, context, renderer, scene, camera, tracker, lighting, cardMesh, previewMesh;
  let active = false, disposed = false, unavailable = false, loading = null, frame = 0;
  let settleUntil = 0;
  let width = 1, height = 1, hover = null, pointer = { x: 0, y: 0 }, lastRealms = null;
  let renderCount = 0, rendererCreations = 0, contextCreations = 0, effectsPlayed = 0;
  const effects = [];
  const permitted = () => active && enabled && !media.matches && !unavailable && !disposed;
  const notify = () => {
    stage.dataset.fx = renderer ? 'three' : media.matches ? 'reduced-motion' : unavailable ? 'unavailable' : 'off';
    onStatus(diagnostics());
  };
  function diagnostics() {
    return { active, enabled, reducedMotion: media.matches, unavailable, ready: !!renderer, pendingFrame: !!frame,
      contextCount: context ? 1 : 0, contextCreations, rendererCreations, renderCount, effectsPlayed,
      effects: effects.length, resources: tracker?.resources.size ?? 0,
      geometries: renderer?.info.memory.geometries ?? 0, textures: renderer?.info.memory.textures ?? 0,
      programs: renderer?.info.programs?.length ?? 0, pixelRatio: renderer?.getPixelRatio() ?? 1 };
  }
  function requestFrame() { if (permitted() && renderer && !frame && !document.hidden) frame = requestAnimationFrame(draw); }
  function resize() {
    if (!renderer) return;
    width = Math.max(1, surface.clientWidth); height = Math.max(1, surface.clientHeight);
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.fov = 2 * Math.atan(height / 2000) * 180 / Math.PI;
    camera.updateProjectionMatrix();
    requestFrame();
  }
  function position(element, fallback = { x: 0, y: 0 }) {
    if (!element) return fallback;
    const outer = surface.getBoundingClientRect(), rect = element.getBoundingClientRect();
    return { x: rect.left + rect.width / 2 - outer.left - width / 2, y: height / 2 - (rect.top + rect.height / 2 - outer.top) };
  }
  function find(attribute, value) {
    return [...stage.querySelectorAll(`[${attribute}]`)].find((node) => node.getAttribute(attribute) === String(value));
  }
  function sidePosition(index) { return { x: 0, y: height * (index === 0 ? -0.23 : 0.23) }; }
  function addAtmosphere() {
    // A single static depth field. It moves only during a meaningful transition.
    const count = width < 700 ? 18 : 44;
    const geometry = tracker.track(new THREE.BufferGeometry());
    const positions = [], colors = [];
    for (let i = 0; i < count; i += 1) {
      const edge = i % 2 ? -1 : 1;
      positions.push(edge * width * (0.35 + ((i * 17) % 19) / 100), (((i * 47) % 101) / 100 - 0.5) * height, -30 - i * 3);
      const color = new THREE.Color(i % 3 ? 0xcfa684 : 0xbda1bf);
      colors.push(color.r, color.g, color.b);
    }
    geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
    geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    const material = tracker.track(new THREE.PointsMaterial({ size: width < 700 ? 3 : 5, vertexColors: true, transparent: true, opacity: 0.22, depthWrite: false, blending: THREE.AdditiveBlending }));
    scene.add(tracker.track(new THREE.Points(geometry, material)));
  }
  function clearScene() {
    if (frame) cancelAnimationFrame(frame);
    frame = 0; settleUntil = 0;
    if (hover) { hover.style.removeProperty('--fx-rx'); hover.style.removeProperty('--fx-ry'); }
    hover = null; lastRealms = null;
    effects.splice(0).forEach((effect) => effect.tracker.dispose());
    tracker?.dispose(); tracker = null;
    renderer?.clear(); renderer?.dispose(); renderer = null;
    scene = camera = lighting = cardMesh = previewMesh = null;
    canvas.style.display = 'none';
    notify();
  }
  async function ensure() {
    if (!permitted() || renderer) return;
    if (loading) return loading;
    loading = (async () => {
      try {
        THREE = await (THREE ?? loadThree());
        if (!permitted()) return;
        if (!context) {
          context = canvas.getContext('webgl2', { alpha: true, antialias: false, powerPreference: 'low-power', premultipliedAlpha: true });
          if (!context) throw new Error('WebGL2 unavailable');
          contextCreations += 1;
        }
        renderer = new THREE.WebGLRenderer({ canvas, context, alpha: true, antialias: false });
        rendererCreations += 1;
        renderer.setPixelRatio(width < 700 || window.matchMedia('(pointer: coarse)').matches ? 1 : Math.min(window.devicePixelRatio || 1, 1.5));
        renderer.setClearColor(0x000000, 0);
        scene = new THREE.Scene(); tracker = new ResourceTracker();
        camera = new THREE.PerspectiveCamera(45, 1, 1, 2400); camera.position.z = 1000;
        scene.add(tracker.track(new THREE.AmbientLight(0xb6becf, 1.2)));
        lighting = tracker.track(new THREE.PointLight(0xffdec0, 700000, 1800)); lighting.position.z = 260; scene.add(lighting);
        const material = tracker.track(new THREE.MeshPhysicalMaterial({ color: 0x9acfc6, metalness: 0.85, roughness: 0.2, iridescence: 1, iridescenceIOR: 1.5, transparent: true, opacity: 0.2, depthWrite: false, side: THREE.DoubleSide }));
        // A narrow physical frame leaves the original DOM artwork and text intact.
        const rounded = (path, inset, radius) => {
          const lo = -0.5 + inset, hi = 0.5 - inset;
          path.moveTo(lo + radius, lo); path.lineTo(hi - radius, lo);
          path.quadraticCurveTo(hi, lo, hi, lo + radius); path.lineTo(hi, hi - radius);
          path.quadraticCurveTo(hi, hi, hi - radius, hi); path.lineTo(lo + radius, hi);
          path.quadraticCurveTo(lo, hi, lo, hi - radius); path.lineTo(lo, lo + radius);
          path.quadraticCurveTo(lo, lo, lo + radius, lo); path.closePath(); return path;
        };
        const shape = rounded(new THREE.Shape(), 0, 0.06);
        shape.holes.push(rounded(new THREE.Path(), 0.012, 0.05));
        cardMesh = tracker.track(new THREE.Mesh(tracker.track(new THREE.ShapeGeometry(shape)), material)); cardMesh.visible = false; scene.add(cardMesh);
        previewMesh = tracker.track(new THREE.Mesh(cardMesh.geometry, tracker.track(material.clone()))); previewMesh.visible = false; scene.add(previewMesh);
        canvas.style.display = 'block'; resize(); addAtmosphere(); requestFrame(); notify();
      } catch {
        unavailable = true; clearScene();
      } finally { loading = null; }
    })();
    return loading;
  }
  function updateCard() {
    if (!cardMesh) return;
    const hovered = hover?.isConnected ? hover : null;
    const preview = surface.querySelector('.hand-preview.is-visible .hand-preview-card');
    for (const [mesh, element, followsPointer] of [[cardMesh, hovered, true], [previewMesh, preview, false]]) {
      if (!element || !element.getClientRects().length || element.getBoundingClientRect().width < 2) { mesh.visible = false; continue; }
      const rect = element.getBoundingClientRect(), location = position(element);
      const x = followsPointer ? Math.max(-1, Math.min(1, (pointer.x - rect.left) / rect.width * 2 - 1)) : 0;
      const y = followsPointer ? Math.max(-1, Math.min(1, (pointer.y - rect.top) / rect.height * 2 - 1)) : 0;
      mesh.visible = true;
      mesh.position.set(location.x, location.y, 8);
      mesh.scale.set(rect.width, rect.height, 1);
      mesh.rotation.set(-y * 0.1, x * 0.1, 0);
      const rarity = element.dataset.rarity ?? hovered?.dataset.rarity ?? (element.classList.contains('is-holo-epic') ? 'epic' : 'rare');
      const rare = /ssr|legend|sr|epic/i.test(rarity);
      mesh.material.color.set(rare ? 0xe4bf75 : 0x8fbeb8);
      mesh.material.iridescence = rare ? 1 : 0.35;
      mesh.material.opacity = followsPointer ? 0.65 : 0.38;
      if (followsPointer) lighting.position.set(location.x + x * 140, location.y - y * 140, 230);
    }
  }
  function burst(kind, location) {
    if (!renderer) return;
    // Each burst owns and releases its buffers as soon as its finite timeline ends.
    const resources = new ResourceTracker(), group = resources.track(new THREE.Group());
    group.position.set(location.x, location.y, 20);
    const color = kind === 'realm' ? 0x7acbbd : kind === 'break' ? 0xc795c8 : 0xf0b47c;
    const material = resources.track(new THREE.MeshBasicMaterial({ color, transparent: true, opacity: 0.7, depthWrite: false, blending: THREE.AdditiveBlending, side: THREE.DoubleSide }));
    const ring = resources.track(new THREE.Mesh(resources.track(new THREE.RingGeometry(18, 20, 40)), material)); group.add(ring);
    const count = width < 700 ? 8 : 18;
    const geometry = resources.track(new THREE.TetrahedronGeometry(kind === 'break' ? 4 : 2));
    const shards = [];
    for (let i = 0; i < count; i += 1) {
      const shard = resources.track(new THREE.Mesh(geometry, material)); group.add(shard);
      shards.push({ mesh: shard, angle: i / count * Math.PI * 2, speed: 45 + (i % 5) * 12 });
    }
    scene.add(group); effectsPlayed += 1;
    effects.push({ tracker: resources, group, ring, material, shards, kind, start: performance.now(), duration: kind === 'break' ? 760 : 540 });
    // Finite resource ceiling even if callers submit many events in one turn.
    if (effects.length > 12) effects.shift().tracker.dispose();
    requestFrame();
  }
  function draw(now) {
    frame = 0;
    if (!permitted() || !renderer) return;
    try {
      for (let i = effects.length - 1; i >= 0; i -= 1) {
        const effect = effects[i], p = Math.min(1, (now - effect.start) / effect.duration);
        if (p >= 1) { effect.tracker.dispose(); effects.splice(i, 1); continue; }
        effect.ring.scale.setScalar(0.5 + p * (effect.kind === 'realm' ? 5 : 3));
        effect.ring.rotation.x = effect.kind === 'realm' ? 0.8 : 0;
        effect.material.opacity = 0.65 * (1 - p) ** 2;
        for (const shard of effect.shards) {
          const distance = shard.speed * p;
          shard.mesh.position.set(Math.cos(shard.angle) * distance, Math.sin(shard.angle) * distance - (effect.kind === 'break' ? 65 * p * p : 0), Math.sin(shard.angle * 3) * p * 45);
          shard.mesh.rotation.set(p * 3, p * 2, shard.angle);
        }
      }
      updateCard(); renderer.render(scene, camera); renderCount += 1;
      if (effects.length || now < settleUntil) requestFrame();
    } catch { unavailable = true; clearScene(); }
  }
  function present(feedback = {}, state) {
    if (state?.players) {
      const realms = new Map(state.players.flatMap((player, index) => (player.realms ?? []).map((realm) => [realm.uid, index])));
      if (lastRealms) for (const [id, index] of realms) if (!lastRealms.has(id)) burst('realm', position(find('data-realm-id', id), sidePosition(index)));
      lastRealms = realms;
    }
    if (!renderer) { if (permitted()) void ensure(); return; }
    for (const impact of feedback.unitImpacts?.values?.() ?? []) {
      if (impact.knockedOut || impact.isAttacker) burst(impact.knockedOut ? 'break' : 'combat', position(find('data-unit-id', impact.unitId), sidePosition(impact.playerIndex)));
    }
    for (const impact of feedback.coreImpacts?.values?.() ?? []) if (impact.hpDelta < 0) {
      burst('core', position(stage.querySelector(impact.playerIndex === 0 ? '#player-core-hp' : '#enemy-core-hp'), sidePosition(impact.playerIndex)));
    }
    for (const impact of feedback.realmImpacts?.values?.() ?? []) if (impact.destroyed) burst('break', position(find('data-realm-id', impact.realmId), sidePosition(impact.playerIndex)));
    requestFrame();
  }
  function pointerMove(event) {
    const target = event.target.closest?.('.hand-card, .hand-preview-card');
    if (!target && !hover) return;
    if (hover && hover !== target) { hover.style.removeProperty('--fx-rx'); hover.style.removeProperty('--fx-ry'); }
    hover = target; pointer = { x: event.clientX, y: event.clientY };
    if (target && permitted()) {
      const rect = target.getBoundingClientRect();
      target.style.setProperty('--fx-rx', `${(0.5 - (event.clientY - rect.top) / rect.height) * 12}deg`);
      target.style.setProperty('--fx-ry', `${((event.clientX - rect.left) / rect.width - 0.5) * 12}deg`);
    }
    const preview = surface.querySelector('.hand-preview-card');
    if (preview && target && permitted()) {
      preview.style.setProperty('--fx-rx', target.style.getPropertyValue('--fx-rx'));
      preview.style.setProperty('--fx-ry', target.style.getPropertyValue('--fx-ry'));
    }
    settleUntil = performance.now() + 240;
    requestFrame();
  }
  function pointerLeave() { if (hover) { hover.style.removeProperty('--fx-rx'); hover.style.removeProperty('--fx-ry'); } hover = null; requestFrame(); }
  function refresh() { if (permitted()) void ensure(); else clearScene(); }
  function visibility() {
    if (document.hidden) { if (frame) cancelAnimationFrame(frame); frame = 0; }
    else requestFrame();
  }
  function contextLost(event) { event.preventDefault(); unavailable = true; clearScene(); }
  const resizeObserver = new ResizeObserver(resize); resizeObserver.observe(surface);
  const mutationObserver = new MutationObserver(requestFrame);
  mutationObserver.observe(surface, { childList: true, subtree: true });
  surface.addEventListener('pointermove', pointerMove, { passive: true });
  surface.addEventListener('pointerleave', pointerLeave);
  surface.addEventListener('scroll', requestFrame, true);
  media.addEventListener('change', refresh);
  document.addEventListener('visibilitychange', visibility);
  canvas.addEventListener('webglcontextlost', contextLost);
  return {
    setActive(value) { active = !!value; refresh(); },
    setEnabled(value) { enabled = !!value; refresh(); },
    present, diagnostics,
    ready() { return ensure(); },
    dispose() {
      if (disposed) return;
      disposed = true; active = false; clearScene();
      resizeObserver.disconnect(); mutationObserver.disconnect();
      surface.removeEventListener('pointermove', pointerMove); surface.removeEventListener('pointerleave', pointerLeave);
      surface.removeEventListener('scroll', requestFrame, true); media.removeEventListener('change', refresh);
      document.removeEventListener('visibilitychange', visibility); canvas.removeEventListener('webglcontextlost', contextLost);
      context?.getExtension('WEBGL_lose_context')?.loseContext(); context = null; canvas.remove();
    },
  };
}
