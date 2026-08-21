/**
 * game-audio.js — 灵枢战线程序化音频引擎 v2
 *
 * 全部音效与 BGM 由 Web Audio API 实时合成，不加载任何外部素材。
 * - 主链路：三层增益（总/音乐/音效）→ 压缩器 → 输出；音乐与部分音效经过程序化卷积混响
 * - 乐器：尺八（正弦 + 颤音 + 气声）、和筝（三角波拨弦 + 低通衰减）、太鼓（音高下滑正弦 + 鼓皮噪声）、铃
 * - BGM：编成用「阳调式」（yo scale，平和），战斗用「平调子」（hirajoshi，紧张），
 *   四小节和声循环 + 密度分层，随小节轻微变化
 * - 音效：出牌、抽牌、攻击、命中、护盾、治疗、升勾、气绝、核心受击、幻境部署、
 *   回合切换、响应窗口、占卜、胜负、UI 交互与错误提示
 * - 偏好持久化到 localStorage；首次用户交互后才会创建 AudioContext
 */

const STORAGE_KEY = 'nexus-front:audio-prefs';
const MASTER_DEFAULT = 0.8;
const MUSIC_DEFAULT = 0.5;
const SFX_DEFAULT = 0.9;

// 阳调式（yo）：D E G A B —— 编成场景，开阔平静
const YO_SCALE = [0, 2, 5, 7, 9];
// 平调子（hirajoshi）：D E F A C —— 战斗场景，收束紧张
const HIRAJOSHI_SCALE = [0, 2, 3, 7, 8];

function loadPrefs() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    if (typeof parsed !== 'object' || parsed === null) return null;
    return parsed;
  } catch {
    return null;
  }
}

/** 确定性伪随机：同一 (seed, salt) 总是得到同一个 0..1 值，保证 BGM 循环纹理稳定 */
function hashRandom(seed, salt = 0) {
  const value = Math.sin(seed * 127.1 + salt * 311.7) * 43758.5453;
  return value - Math.floor(value);
}

const NOTE = (semitonesFromA4) => 440 * Math.pow(2, semitonesFromA4 / 12);
// 以 D 为宫：D3 = A4 - 19 半音
const D3 = NOTE(-19);
const D4 = NOTE(-7);

class SpiritAudio {
  constructor() {
    const prefs = loadPrefs();
    this.enabled = prefs?.enabled !== false;
    this.masterVolume = typeof prefs?.master === 'number' ? prefs.master : MASTER_DEFAULT;
    this.musicVolume = typeof prefs?.music === 'number' ? prefs.music : MUSIC_DEFAULT;
    this.sfxVolume = typeof prefs?.sfx === 'number' ? prefs.sfx : SFX_DEFAULT;
    this.context = null;
    this.masterGain = null;
    this.musicGain = null;
    this.sfxGain = null;
    this.musicBus = null; // 音乐干声 + 混响发送
    this.reverb = null;
    this.musicTimer = null;
    this.musicMode = null;
    this.musicStep = 0;
    this.nextNoteTime = 0;
    this.noiseBuffer = null;
    this.unlockBound = false;
    this.lastFluteNote = null;
  }

  /** 偏好持久化（存储不可用时静默降级） */
  persist() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify({
        enabled: this.enabled,
        master: this.masterVolume,
        music: this.musicVolume,
        sfx: this.sfxVolume,
      }));
    } catch { /* 忽略 */ }
  }

  /** 首次用户交互后调用；浏览器自动播放策略要求 AudioContext 在手势内创建或恢复 */
  unlock() {
    if (!this.enabled) return;
    if (!this.context) {
      const Ctx = window.AudioContext ?? window.webkitAudioContext;
      if (!Ctx) return;
      this.context = new Ctx();
      const compressor = this.context.createDynamicsCompressor();
      compressor.threshold.value = -14;
      compressor.knee.value = 24;
      compressor.ratio.value = 5;
      compressor.attack.value = 0.004;
      compressor.release.value = 0.24;
      compressor.connect(this.context.destination);
      this.masterGain = this.context.createGain();
      this.masterGain.gain.value = this.masterVolume;
      this.masterGain.connect(compressor);
      this.musicGain = this.context.createGain();
      this.musicGain.gain.value = this.musicVolume;
      this.musicGain.connect(this.masterGain);
      this.sfxGain = this.context.createGain();
      this.sfxGain.gain.value = this.sfxVolume;
      this.sfxGain.connect(this.masterGain);
      this.musicBus = this.context.createGain();
      this.musicBus.connect(this.musicGain);
      this.reverb = this.createReverb(2.1, 2.6);
      this.reverb.output.connect(this.musicGain);
      this.sfxReverb = this.createReverb(1.2, 1.8);
      this.sfxReverb.output.connect(this.masterGain);
      this.noiseBuffer = this.createNoiseBuffer();
    }
    if (this.context.state === 'suspended') this.context.resume();
    if (!this.unlockBound) {
      this.unlockBound = true;
      document.addEventListener('visibilitychange', () => {
        if (document.hidden) this.suspendMusic();
        else if (this.musicMode) this.resumeMusic();
      });
    }
  }

  createNoiseBuffer() {
    const length = this.context.sampleRate * 1.4;
    const buffer = this.context.createBuffer(1, length, this.context.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < length; i += 1) data[i] = Math.random() * 2 - 1;
    return buffer;
  }

  /** 程序化卷积混响：指数衰减噪声脉冲响应 */
  createReverb(seconds, decay) {
    const rate = this.context.sampleRate;
    const length = Math.floor(rate * seconds);
    const impulse = this.context.createBuffer(2, length, rate);
    for (let channel = 0; channel < 2; channel += 1) {
      const data = impulse.getChannelData(channel);
      for (let i = 0; i < length; i += 1) {
        data[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / length, decay);
      }
    }
    const convolver = this.context.createConvolver();
    convolver.buffer = impulse;
    const wet = this.context.createGain();
    wet.gain.value = 0.32;
    convolver.connect(wet);
    return { input: convolver, output: wet };
  }

  setEnabled(enabled) {
    this.enabled = enabled;
    if (!enabled) {
      this.stopMusic();
      if (this.masterGain) this.masterGain.gain.value = 0;
    } else {
      this.unlock();
      if (this.masterGain) this.masterGain.gain.value = this.masterVolume;
    }
    this.persist();
  }

  setMusicVolume(value) {
    this.musicVolume = value;
    if (this.musicGain) this.musicGain.gain.value = value;
    this.persist();
  }

  setMasterVolume(value) {
    this.masterVolume = value;
    if (this.masterGain) this.masterGain.gain.value = this.enabled ? value : 0;
    this.persist();
  }

  setSfxVolume(value) {
    this.sfxVolume = value;
    if (this.sfxGain) this.sfxGain.gain.value = value;
    this.persist();
  }

  // ---------------------------------------------------------------- 基础合成

  tone({ freq, dur = 0.2, type = 'sine', gain = 0.5, attack = 0.01, release = 0.12, dest, detune = 0, when = 0, vibrato = 0, vibratoRate = 5, curve = 'exp' }) {
    if (!this.context) return null;
    const t0 = this.context.currentTime + when;
    const osc = this.context.createOscillator();
    osc.type = type;
    osc.frequency.value = freq;
    if (detune) osc.detune.value = detune;
    let source = osc;
    if (vibrato > 0) {
      const lfo = this.context.createOscillator();
      lfo.frequency.value = vibratoRate;
      const lfoGain = this.context.createGain();
      lfoGain.gain.value = vibrato;
      lfo.connect(lfoGain).connect(osc.detune);
      lfo.start(t0);
      lfo.stop(t0 + dur + release + 0.1);
    }
    const env = this.context.createGain();
    env.gain.setValueAtTime(0.0001, t0);
    env.gain.linearRampToValueAtTime(gain, t0 + attack);
    if (curve === 'exp') env.gain.exponentialRampToValueAtTime(0.0001, t0 + dur + release);
    else env.gain.linearRampToValueAtTime(0.0001, t0 + dur + release);
    source.connect(env).connect(dest ?? this.sfxGain);
    source.start(t0);
    source.stop(t0 + dur + release + 0.05);
    return osc;
  }

  noise({ dur = 0.15, gain = 0.4, filterFreq = 1200, q = 1, type = 'bandpass', when = 0, sweepTo = null, dest }) {
    if (!this.context || !this.noiseBuffer) return;
    const t0 = this.context.currentTime + when;
    const src = this.context.createBufferSource();
    src.buffer = this.noiseBuffer;
    src.loop = true;
    const filter = this.context.createBiquadFilter();
    filter.type = type;
    filter.frequency.setValueAtTime(filterFreq, t0);
    if (sweepTo) filter.frequency.exponentialRampToValueAtTime(sweepTo, t0 + dur);
    filter.Q.value = q;
    const env = this.context.createGain();
    env.gain.setValueAtTime(0.0001, t0);
    env.gain.linearRampToValueAtTime(gain, t0 + Math.min(0.02, dur * 0.2));
    env.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
    src.connect(filter).connect(env).connect(dest ?? this.sfxGain);
    src.start(t0);
    src.stop(t0 + dur + 0.05);
  }

  // ---------------------------------------------------------------- 乐器

  /** 和筝拨弦：三角波 + 快速低通衰减，带一点簧感 */
  koto(freq, { when = 0, gain = 0.16, dur = 0.5, dest = null } = {}) {
    if (!this.context) return;
    const t0 = this.context.currentTime + when;
    const bus = dest ?? this.musicBus;
    const osc = this.context.createOscillator();
    osc.type = 'triangle';
    osc.frequency.value = freq;
    const shimmer = this.context.createOscillator();
    shimmer.type = 'sawtooth';
    shimmer.frequency.value = freq * 2;
    const shimmerGain = this.context.createGain();
    shimmerGain.gain.value = 0.18;
    const lp = this.context.createBiquadFilter();
    lp.type = 'lowpass';
    lp.frequency.setValueAtTime(freq * 6, t0);
    lp.frequency.exponentialRampToValueAtTime(Math.max(200, freq * 1.2), t0 + dur);
    const env = this.context.createGain();
    env.gain.setValueAtTime(0.0001, t0);
    env.gain.linearRampToValueAtTime(gain, t0 + 0.006);
    env.gain.exponentialRampToValueAtTime(0.0001, t0 + dur + 0.25);
    osc.connect(lp);
    shimmer.connect(shimmerGain).connect(lp);
    lp.connect(env).connect(bus);
    if (this.reverb) env.connect(this.reverb.input);
    osc.start(t0); shimmer.start(t0);
    osc.stop(t0 + dur + 0.3); shimmer.stop(t0 + dur + 0.3);
  }

  /** 尺八：正弦主音 + 缓颤音 + 起吹气声 */
  shakuhachi(freq, { when = 0, gain = 0.12, dur = 0.9, dest = null } = {}) {
    if (!this.context) return;
    const t0 = this.context.currentTime + when;
    const bus = dest ?? this.musicBus;
    const osc = this.context.createOscillator();
    osc.type = 'sine';
    osc.frequency.value = freq;
    const lfo = this.context.createOscillator();
    lfo.frequency.value = 4.6;
    const lfoGain = this.context.createGain();
    lfoGain.gain.setValueAtTime(2, t0);
    lfoGain.gain.linearRampToValueAtTime(11, t0 + dur);
    lfo.connect(lfoGain).connect(osc.detune);
    const harmonic = this.context.createOscillator();
    harmonic.type = 'triangle';
    harmonic.frequency.value = freq * 2.01;
    const harmonicGain = this.context.createGain();
    harmonicGain.gain.value = 0.12;
    const env = this.context.createGain();
    env.gain.setValueAtTime(0.0001, t0);
    env.gain.linearRampToValueAtTime(gain, t0 + 0.09);
    env.gain.setValueAtTime(gain, t0 + dur * 0.7);
    env.gain.exponentialRampToValueAtTime(0.0001, t0 + dur + 0.4);
    osc.connect(env);
    harmonic.connect(harmonicGain).connect(env);
    env.connect(bus);
    if (this.reverb) env.connect(this.reverb.input);
    osc.start(t0); harmonic.start(t0); lfo.start(t0);
    osc.stop(t0 + dur + 0.5); harmonic.stop(t0 + dur + 0.5); lfo.stop(t0 + dur + 0.5);
    // 起吹气声
    this.noise({ dur: 0.12, gain: gain * 0.5, filterFreq: freq * 2.4, q: 1.6, when, dest: bus === this.musicBus ? this.musicBus : undefined });
  }

  /** 太鼓：音高下滑的低音体 + 鼓皮噪声 */
  taiko({ when = 0, gain = 0.3, pitch = 96, dest = null } = {}) {
    if (!this.context) return;
    const t0 = this.context.currentTime + when;
    const bus = dest ?? this.musicBus;
    const osc = this.context.createOscillator();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(pitch * 1.7, t0);
    osc.frequency.exponentialRampToValueAtTime(pitch * 0.72, t0 + 0.1);
    const env = this.context.createGain();
    env.gain.setValueAtTime(gain, t0);
    env.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.32);
    osc.connect(env).connect(bus);
    osc.start(t0);
    osc.stop(t0 + 0.4);
    this.noise({ dur: 0.05, gain: gain * 0.42, filterFreq: 340, q: 1.2, type: 'lowpass', when, dest: bus === this.musicBus ? this.musicBus : undefined });
  }

  /** 铃/风铃 */
  bell(freq, { when = 0, gain = 0.08, dur = 1.6, dest = null } = {}) {
    if (!this.context) return;
    const t0 = this.context.currentTime + when;
    const bus = dest ?? this.musicBus;
    [1, 2.76, 5.4].forEach((partial, index) => {
      const osc = this.context.createOscillator();
      osc.type = 'sine';
      osc.frequency.value = freq * partial;
      const env = this.context.createGain();
      const partialGain = gain / (index + 1.6);
      env.gain.setValueAtTime(0.0001, t0);
      env.gain.linearRampToValueAtTime(partialGain, t0 + 0.008);
      env.gain.exponentialRampToValueAtTime(0.0001, t0 + dur / (index * 0.7 + 1));
      osc.connect(env).connect(bus);
      if (this.reverb) env.connect(this.reverb.input);
      osc.start(t0);
      osc.stop(t0 + dur + 0.2);
    });
  }

  /** 大音效时轻微压低音乐（侧链闪避） */
  duckMusic(depth = 0.45, seconds = 0.9) {
    if (!this.context || !this.musicGain || !this.enabled) return;
    const t0 = this.context.currentTime;
    const target = this.musicVolume * (1 - depth);
    this.musicGain.gain.cancelScheduledValues(t0);
    this.musicGain.gain.setValueAtTime(this.musicGain.gain.value, t0);
    this.musicGain.gain.linearRampToValueAtTime(target, t0 + 0.05);
    this.musicGain.gain.linearRampToValueAtTime(this.musicVolume, t0 + seconds);
  }

  // ---------------------------------------------------------------- 音效库

  /** UI 点击：木鱼叩击 */
  uiTap() {
    if (!this.enabled || !this.context) return;
    this.tone({ freq: 640, dur: 0.05, type: 'triangle', gain: 0.2, release: 0.07 });
    this.tone({ freq: 1280, dur: 0.035, type: 'sine', gain: 0.07, release: 0.05 });
  }

  /** UI 悬停：极轻风铃 */
  uiHover() {
    if (!this.enabled || !this.context) return;
    this.bell(1568, { gain: 0.025, dur: 0.5, dest: this.sfxGain });
  }

  /** 选中/聚焦：短促高音tick */
  selectTick() {
    if (!this.enabled || !this.context) return;
    this.tone({ freq: 880, dur: 0.05, type: 'sine', gain: 0.12, release: 0.08 });
  }

  /** 非法操作：低沉短嗡 */
  errorBuzz() {
    if (!this.enabled || !this.context) return;
    this.tone({ freq: 130, dur: 0.12, type: 'square', gain: 0.1, release: 0.12 });
    this.tone({ freq: 123, dur: 0.14, type: 'square', gain: 0.08, release: 0.14, when: 0.09 });
  }

  /** 出牌：太鼓轻击 + 拍子木 */
  cardPlay() {
    if (!this.enabled || !this.context) return;
    this.noise({ dur: 0.07, gain: 0.26, filterFreq: 2300, q: 2 });
    this.tone({ freq: 210, dur: 0.1, type: 'sine', gain: 0.38, release: 0.1 });
    this.tone({ freq: 880, dur: 0.045, type: 'triangle', gain: 0.1, release: 0.06, when: 0.02 });
  }

  /** 抽牌：纸滑过锦面的嗖声 */
  cardDraw() {
    if (!this.enabled || !this.context) return;
    this.noise({ dur: 0.16, gain: 0.16, filterFreq: 900, sweepTo: 3600, q: 1.2 });
    this.tone({ freq: 1174, dur: 0.05, type: 'sine', gain: 0.06, release: 0.12, when: 0.1 });
  }

  /** 攻击前冲：太鼓滚奏起手 */
  attackLunge() {
    if (!this.enabled || !this.context) return;
    for (let i = 0; i < 3; i += 1) {
      this.tone({ freq: 150 - i * 12, dur: 0.08, type: 'sine', gain: 0.3, release: 0.06, when: i * 0.055 });
    }
    this.noise({ dur: 0.2, gain: 0.22, filterFreq: 900, sweepTo: 2600, when: 0.1 });
  }

  /** 命中：斩击 + 闷响 */
  hit() {
    if (!this.enabled || !this.context) return;
    this.duckMusic(0.3, 0.5);
    this.noise({ dur: 0.12, gain: 0.4, filterFreq: 3200, sweepTo: 700, q: 1.4 });
    this.tone({ freq: 98, dur: 0.16, type: 'sine', gain: 0.48, release: 0.14 });
    this.tone({ freq: 185, dur: 0.08, type: 'square', gain: 0.09, release: 0.06 });
  }

  /** 远程：箭矢破空 */
  hitRemote() {
    if (!this.enabled || !this.context) return;
    this.noise({ dur: 0.28, gain: 0.28, filterFreq: 600, sweepTo: 4200, q: 3 });
    this.tone({ freq: 1244, dur: 0.1, type: 'sine', gain: 0.12, release: 0.1, when: 0.16 });
  }

  /** 升勾：金色风铃上行 + 筝拨弦 */
  levelUp() {
    if (!this.enabled || !this.context) return;
    const base = D4 * 1.5; // A4 上行
    [0, 3, 5, 10].forEach((step, i) => {
      const freq = base * Math.pow(2, step / 12);
      this.bell(freq, { gain: 0.09, dur: 1.1, when: i * 0.08, dest: this.sfxGain });
    });
    this.koto(base, { gain: 0.1, dur: 0.4, when: 0.05, dest: this.sfxGain });
  }

  /** 护盾：石垣落成 */
  shield() {
    if (!this.enabled || !this.context) return;
    this.tone({ freq: 196, dur: 0.2, type: 'triangle', gain: 0.28, release: 0.2 });
    this.noise({ dur: 0.14, gain: 0.14, filterFreq: 500, q: 1 });
  }

  /** 治疗：清泉泛音 */
  heal() {
    if (!this.enabled || !this.context) return;
    this.tone({ freq: 1046, dur: 0.16, type: 'sine', gain: 0.15, release: 0.22 });
    this.tone({ freq: 1568, dur: 0.14, type: 'sine', gain: 0.09, release: 0.24, when: 0.08 });
  }

  /** 气绝：墨色崩落 */
  knockout() {
    if (!this.enabled || !this.context) return;
    this.duckMusic(0.55, 1.2);
    this.tone({ freq: 130, dur: 0.5, type: 'sawtooth', gain: 0.2, release: 0.4 });
    this.tone({ freq: 65, dur: 0.6, type: 'sine', gain: 0.38, release: 0.45 });
    this.noise({ dur: 0.5, gain: 0.18, filterFreq: 800, sweepTo: 160, when: 0.05 });
  }

  /** 核心受击：钟鸣 + 裂纹 */
  coreHit() {
    if (!this.enabled || !this.context) return;
    this.duckMusic(0.6, 1.4);
    this.tone({ freq: 220, dur: 0.7, type: 'sine', gain: 0.38, release: 0.6 });
    this.tone({ freq: 331, dur: 0.5, type: 'sine', gain: 0.14, release: 0.5, detune: 8 });
    this.noise({ dur: 0.3, gain: 0.22, filterFreq: 1800, sweepTo: 300, when: 0.02 });
  }

  /** 回合切换：拍子木两连 */
  turnSwitch(isPlayer) {
    if (!this.enabled || !this.context) return;
    const base = isPlayer ? 523 : 392;
    this.tone({ freq: base, dur: 0.08, type: 'square', gain: 0.1, release: 0.1 });
    this.tone({ freq: base * 1.5, dur: 0.1, type: 'square', gain: 0.1, release: 0.12, when: 0.14 });
    if (isPlayer) this.bell(1046, { gain: 0.05, dur: 0.8, when: 0.2, dest: this.sfxGain });
  }

  /** 响应窗口：紧张的拨弦 */
  response() {
    if (!this.enabled || !this.context) return;
    this.tone({ freq: 440, dur: 0.1, type: 'sawtooth', gain: 0.09, release: 0.15 });
    this.tone({ freq: 466, dur: 0.12, type: 'sawtooth', gain: 0.09, release: 0.18, when: 0.09 });
  }

  /** 幻境部署：空间展开 */
  realmDeploy() {
    if (!this.enabled || !this.context) return;
    this.duckMusic(0.3, 0.8);
    this.tone({ freq: 110, dur: 0.9, type: 'sine', gain: 0.22, attack: 0.2, release: 0.7 });
    this.bell(660, { gain: 0.08, dur: 1.8, when: 0.05, dest: this.sfxGain });
    this.bell(990, { gain: 0.05, dur: 1.4, when: 0.18, dest: this.sfxGain });
  }

  /** 角色换入前线：换位脚步 + 石落 */
  unitEnterFront() {
    if (!this.enabled || !this.context) return;
    this.noise({ dur: 0.1, gain: 0.14, filterFreq: 700, sweepTo: 1800, q: 1 });
    this.tone({ freq: 140, dur: 0.14, type: 'sine', gain: 0.26, release: 0.12, when: 0.08 });
  }

  /** 占卜开启：神秘铃声 */
  divinationOpen() {
    if (!this.enabled || !this.context) return;
    [784, 988, 1318].forEach((freq, i) => {
      this.bell(freq, { gain: 0.07, dur: 1.2, when: i * 0.12, dest: this.sfxGain });
    });
  }

  /** 胜利：太鼓与上行号角 */
  victory() {
    if (!this.enabled || !this.context) return;
    this.duckMusic(0.8, 2.6);
    const root = D4;
    [0, 3, 7, 12, 19].forEach((step, i) => {
      const freq = root * Math.pow(2, step / 12);
      this.tone({ freq, dur: i === 4 ? 0.9 : 0.18, type: 'triangle', gain: 0.22, release: 0.5, when: 0.1 + i * 0.15 });
      this.tone({ freq: freq / 2, dur: 0.12, type: 'sine', gain: 0.24, release: 0.1, when: 0.1 + i * 0.15 });
    });
    this.taiko({ when: 0.1, gain: 0.3, pitch: 88, dest: this.sfxGain });
    this.taiko({ when: 0.4, gain: 0.26, pitch: 88, dest: this.sfxGain });
    this.taiko({ when: 0.7, gain: 0.34, pitch: 76, dest: this.sfxGain });
  }

  /** 开包：卷轴展开 + 太鼓落定 */
  packOpen() {
    if (!this.enabled || !this.context) return;
    this.duckMusic(0.4, 1.2);
    this.noise({ dur: 0.5, gain: 0.18, filterFreq: 500, sweepTo: 3200, q: 1.2 });
    this.taiko({ when: 0.32, gain: 0.32, pitch: 84, dest: this.sfxGain });
    this.bell(784, { when: 0.36, gain: 0.08, dur: 1.4, dest: this.sfxGain });
  }

  /** 揭卡：按稀有度抬升的铃音（common/rare/epic） */
  reveal(rarity) {
    if (!this.enabled || !this.context) return;
    const base = rarity === 'epic' ? 1174 : rarity === 'rare' ? 932 : 698;
    this.bell(base, { gain: 0.09, dur: 1.1, dest: this.sfxGain });
    if (rarity !== 'common') this.bell(base * 1.5, { when: 0.09, gain: 0.06, dur: 1.2, dest: this.sfxGain });
    if (rarity === 'epic') this.bell(base * 2, { when: 0.18, gain: 0.05, dur: 1.4, dest: this.sfxGain });
  }

  /** 合成：铁笔落印 */
  craft() {
    if (!this.enabled || !this.context) return;
    this.tone({ freq: 1244, dur: 0.1, type: 'triangle', gain: 0.16, release: 0.2 });
    this.tone({ freq: 1866, dur: 0.12, type: 'sine', gain: 0.08, release: 0.24, when: 0.06 });
    this.noise({ dur: 0.08, gain: 0.1, filterFreq: 4200, q: 3, when: 0.02 });
  }

  /** 失败：下沉的墨色低音 */
  defeat() {
    if (!this.enabled || !this.context) return;
    this.duckMusic(0.85, 3);
    this.tone({ freq: 220, dur: 0.8, type: 'sine', gain: 0.26, release: 0.9 });
    this.tone({ freq: 110, dur: 1.1, type: 'sine', gain: 0.32, release: 1.1, when: 0.18 });
    this.tone({ freq: 55, dur: 1.4, type: 'triangle', gain: 0.28, release: 1.2, when: 0.4 });
    this.taiko({ when: 0.5, gain: 0.3, pitch: 62, dest: this.sfxGain });
  }

  // ---------------------------------------------------------------- BGM

  /**
   * 启动程序化 BGM 循环。
   * mode: 'formation'（阳调式，尺八与筝，平静） | 'battle'（平调子，太鼓与短促拨弦，紧张）
   */
  startMusic(mode) {
    if (!this.enabled || !this.context) return;
    if (this.musicMode === mode && this.musicTimer) return;
    this.stopMusic();
    this.musicMode = mode;
    this.musicStep = 0;
    this.lastFluteNote = null;
    this.nextNoteTime = this.context.currentTime + 0.15;
    const runner = this.createMusicRunner(mode);
    runner();
    this.musicTimer = setInterval(runner, 120);
  }

  createMusicRunner(mode) {
    const tempo = mode === 'battle' ? 0.27 : 0.42;
    return () => {
      if (!this.context || this.musicMode !== mode) return;
      while (this.nextNoteTime < this.context.currentTime + 0.4) {
        this.scheduleMusicStep(mode, this.musicStep, this.nextNoteTime - this.context.currentTime);
        this.musicStep += 1;
        this.nextNoteTime += tempo;
      }
    };
  }

  scheduleMusicStep(mode, step, when) {
    const tempo = mode === 'battle' ? 0.27 : 0.42;
    const scale = mode === 'battle' ? HIRAJOSHI_SCALE : YO_SCALE;
    const root = mode === 'battle' ? D3 : D3; // 都以 D3 为基座
    const bar = Math.floor(step / 8) % 4;
    const beat = step % 8;
    const seed = step + (mode === 'battle' ? 1000 : 0);

    // 四小节和声进行：编成 I-IV-V-vi 感；战斗 i-VI-VII-v 感
    const progression = mode === 'battle' ? [0, 3, 4, 3] : [0, 2, 3, 1];
    const degree = progression[bar];
    const rootFreq = root * Math.pow(2, scale[degree] / 12);

    // --- 低音持续音（每小节起）：根音 + 纯五度，战斗加一层八度 ---
    if (beat === 0) {
      const droneGain = mode === 'battle' ? 0.11 : 0.085;
      this.tone({ freq: rootFreq, dur: tempo * 8, type: 'sine', gain: droneGain, attack: 0.5, release: 1.2, dest: this.musicBus, curve: 'lin' });
      this.tone({ freq: rootFreq * 1.5, dur: tempo * 7.5, type: 'sine', gain: droneGain * 0.5, attack: 0.6, release: 1.2, dest: this.musicBus, curve: 'lin' });
      if (mode === 'battle') {
        this.tone({ freq: rootFreq / 2, dur: tempo * 8, type: 'triangle', gain: 0.07, attack: 0.4, release: 1.4, dest: this.musicBus, curve: 'lin' });
      }
    }

    // --- 和筝拨弦 ---
    const pluckChance = mode === 'battle' ? 0.62 : 0.4;
    if (hashRandom(seed, 1) < pluckChance) {
      const idx = Math.floor(hashRandom(seed, 2) * scale.length);
      const octave = hashRandom(seed, 3) > (mode === 'battle' ? 0.35 : 0.6) ? 2 : 1;
      const freq = rootFreq * octave * Math.pow(2, scale[idx] / 12);
      this.koto(freq, { when, gain: mode === 'battle' ? 0.075 : 0.085, dur: mode === 'battle' ? 0.34 : 0.6 });
    }
    // 战斗：反拍短促拨弦制造驱动力
    if (mode === 'battle' && (beat === 3 || beat === 6) && hashRandom(seed, 4) > 0.35) {
      const idx = Math.floor(hashRandom(seed, 5) * scale.length);
      this.koto(rootFreq * 2 * Math.pow(2, scale[idx] / 12), { when, gain: 0.05, dur: 0.2 });
    }

    // --- 尺八旋律：级进为主，偶有跳进与长音 ---
    const melodyChance = mode === 'battle' ? 0.34 : 0.3;
    if (hashRandom(seed, 6) < melodyChance) {
      const options = [-2, -1, -1, 0, 1, 1, 2];
      const move = options[Math.floor(hashRandom(seed, 7) * options.length)];
      const prev = this.lastFluteNote ?? degree;
      let next = prev + move;
      if (next < 0) next = scale.length - 1;
      if (next >= scale.length * 2) next = scale.length - 1;
      const octave = next >= scale.length ? 2 : 1;
      const idx = ((next % scale.length) + scale.length) % scale.length;
      this.lastFluteNote = next;
      const freq = rootFreq * octave * Math.pow(2, scale[idx] / 12);
      const long = hashRandom(seed, 8) > 0.72;
      this.shakuhachi(freq, { when, gain: mode === 'battle' ? 0.06 : 0.1, dur: long ? tempo * 3 : tempo * 1.4 });
    }

    // --- 太鼓：战斗节拍（0 强拍、4 中鼓、偶尔 6 弱鼓） ---
    if (mode === 'battle') {
      if (beat === 0) this.taiko({ when, gain: 0.22, pitch: 92 });
      if (beat === 4) this.taiko({ when, gain: 0.15, pitch: 92 });
      if (beat === 6 && bar % 2 === 1) this.taiko({ when, gain: 0.1, pitch: 118 });
    } else if (beat === 0 && bar % 2 === 0) {
      this.taiko({ when, gain: 0.09, pitch: 72 }); // 编成：极轻的心跳感
    }

    // --- 编成：偶尔的风铃点缀 ---
    if (mode === 'formation' && step % 32 === 20) {
      this.bell(rootFreq * 4, { when, gain: 0.028, dur: 2.4 });
    }
  }

  suspendMusic() {
    if (this.musicTimer) {
      clearInterval(this.musicTimer);
      this.musicTimer = null;
    }
  }

  resumeMusic() {
    if (!this.musicMode || !this.enabled || !this.context) return;
    if (this.musicTimer) return;
    this.nextNoteTime = this.context.currentTime + 0.1;
    const runner = this.createMusicRunner(this.musicMode);
    runner();
    this.musicTimer = setInterval(runner, 120);
  }

  stopMusic() {
    this.suspendMusic();
    this.musicMode = null;
  }

  /** 场景切换入口：formation | battle | off */
  setScene(scene) {
    if (!this.enabled) return;
    if (scene === 'off') {
      this.stopMusic();
      return;
    }
    this.startMusic(scene);
  }
}

export const gameAudio = new SpiritAudio();
