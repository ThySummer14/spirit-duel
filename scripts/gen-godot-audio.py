#!/usr/bin/env python3
"""Render the Godot build's sound effects and music loops procedurally.

Everything is synthesised here (koto via Karplus-Strong, shakuhachi-like breathy
sine, taiko, temple bell, paper noise), so there are no third-party samples.
Output: godot/assets/audio/*.wav (mono, 16-bit).

Usage: python3 scripts/gen-godot-audio.py
"""
import pathlib
import wave

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "godot" / "assets" / "audio"
SR = 32000
rng = np.random.default_rng(20261004)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def env(n, attack=0.005, decay=0.2, curve=1.0):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-4)) ** curve
    return a * d


def noise(dur):
    return rng.standard_normal(int(dur * SR))


def lowpass(x, cutoff):
    # one-pole low-pass, vectorised enough for short clips
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def bandpass(x, lo, hi):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    spec[(f < lo) | (f > hi)] = 0
    return np.fft.irfft(spec, len(x))


def koto(freq, dur=1.6, bright=0.5, gain=1.0):
    n = int(dur * SR)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period)
    buf = buf * (0.6 + 0.4 * bright) + np.convolve(buf, [0.5, 0.5], "same") * (0.4 - 0.4 * bright)
    out = np.zeros(n + period + 1)
    out[:period] = buf
    decay = 0.996 - 0.004 * (freq / 1000)
    pos = period
    while pos < len(out):
        end = min(pos + period, len(out))
        prev = out[pos - period:end - period]
        prev2 = out[pos - period - 1:end - period - 1] if pos - period - 1 >= 0 else np.concatenate(([0.0], prev[:-1]))
        if len(prev2) != len(prev):
            prev2 = np.concatenate(([0.0], prev[:-1]))
        out[pos:end] = 0.5 * (prev + prev2) * decay
        pos = end
    y = out[:n]
    # pluck transient + gentle body resonance
    y = y + 0.15 * np.sin(2 * np.pi * freq * 2 * t_axis(dur)) * env(n, 0.002, 0.08)
    return gain * y / (np.max(np.abs(y)) + 1e-9) * env(n, 0.001, dur * 0.7, 0.6)


def bell(freq, dur=2.5, gain=1.0):
    t = t_axis(dur)
    partials = [(0.5, 0.6, 2.2), (1.0, 1.0, 1.6), (1.19, 0.5, 1.1), (1.56, 0.35, 0.8), (2.0, 0.3, 0.6), (2.74, 0.2, 0.35), (3.76, 0.12, 0.25)]
    y = np.zeros_like(t)
    for ratio, amp, dec in partials:
        y += amp * np.sin(2 * np.pi * freq * ratio * t + rng.uniform(0, 6)) * np.exp(-t / (dec * dur / 2.5))
    y *= np.clip(t / 0.003, 0, 1)
    return gain * y / np.max(np.abs(y))


def chime(freq, dur=0.9, gain=1.0):
    t = t_axis(dur)
    y = np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / 0.15) + 0.2 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t / 0.06)
    return gain * y * env(len(t), 0.002, dur * 0.35)


def taiko(freq=70, dur=0.9, gain=1.0, slap=0.3):
    t = t_axis(dur)
    pitch = freq * (1 + 0.6 * np.exp(-t / 0.03))
    phase = 2 * np.pi * np.cumsum(pitch) / SR
    body = np.sin(phase) * np.exp(-t / 0.28)
    hit = lowpass(noise(dur), 1800) * np.exp(-t / 0.02) * slap * 4
    y = body + hit
    return gain * y / np.max(np.abs(y))


def flute(freq, dur, gain=1.0, vibrato=5.0):
    t = t_axis(dur)
    vib = 1 + 0.006 * np.sin(2 * np.pi * vibrato * t) * np.clip((t - 0.25) / 0.4, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq * vib) / SR
    tone = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.06 * np.sin(3 * phase)
    breath = bandpass(noise(dur), freq * 0.8, freq * 3.5) * 0.25
    n = len(t)
    a = np.clip(t / 0.12, 0, 1)
    r = np.clip((dur - t) / 0.25, 0, 1)
    swell = 0.85 + 0.15 * np.sin(np.pi * np.clip(t / dur, 0, 1))
    y = (tone + breath * (0.6 + 0.4 * np.exp(-t / 0.2))) * a * r * swell
    return gain * y / (np.max(np.abs(y)) + 1e-9)


def swish(dur=0.2, lo=900, hi=7000, gain=1.0, rise=0.35):
    n = int(dur * SR)
    x = bandpass(noise(dur), lo, hi)
    t = np.arange(n) / n
    shape = np.where(t < rise, (t / rise) ** 1.5, ((1 - t) / (1 - rise)) ** 2)
    y = x * shape
    return gain * y / (np.max(np.abs(y)) + 1e-9)


def reverb(x, seconds=1.6, mix=0.25, wrap=False):
    n_ir = int(seconds * SR)
    t = np.arange(n_ir) / SR
    ir = rng.standard_normal(n_ir) * np.exp(-t / (seconds / 5))
    ir = lowpass(ir, 5000)
    ir /= np.sqrt(np.sum(ir ** 2))
    size = len(x) + n_ir
    nfft = 1 << (size - 1).bit_length()
    wet = np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[:size]
    if wrap:
        tail = wet[len(x):]
        wet = wet[:len(x)].copy()
        wet[:len(tail)] += tail
        dry = x
    else:
        dry = np.concatenate([x, np.zeros(n_ir)])
    return dry * (1 - mix) + wet * mix * 3


def place(track, clip, at):
    i = int(at * SR)
    if i >= len(track):
        return
    end = min(len(track), i + len(clip))
    track[i:end] += clip[:end - i]


def place_wrap(track, clip, at):
    """Add a clip to a loop, wrapping anything past the end back to the start."""
    i = int(at * SR) % len(track)
    first = min(len(clip), len(track) - i)
    track[i:i + first] += clip[:first]
    rest = clip[first:]
    while len(rest):
        take = min(len(rest), len(track))
        track[:take] += rest[:take]
        rest = rest[take:]


def trim(x, thresh=1e-3):
    idx = np.nonzero(np.abs(x) > thresh * np.max(np.abs(x)))[0]
    return x[: idx[-1] + int(0.02 * SR)] if len(idx) else x


def save(name, x, peak=0.89, loop=False):
    x = np.asarray(x, dtype=np.float64)
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    if not loop:
        fade = min(len(x), int(0.004 * SR))
        x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}.wav {len(x) / SR:.2f}s")


# In-scale (都节音阶) on D: D Eb G A Bb
def note(semitones_from_d4):
    return 293.66 * 2 ** (semitones_from_d4 / 12)


IN_SCALE = [0, 1, 5, 7, 8]


def scale_note(step, octave=0):
    o, i = divmod(step, len(IN_SCALE))
    return note(IN_SCALE[i] + 12 * (o + octave))


def sfx():
    # UI
    click = lowpass(noise(0.05), 3000) * env(int(0.05 * SR), 0.001, 0.01) + 0.6 * np.sin(2 * np.pi * 1350 * t_axis(0.05)) * env(int(0.05 * SR), 0.001, 0.012)
    save("ui_click", click, 0.6)
    hover = np.sin(2 * np.pi * 2400 * t_axis(0.035)) * env(int(0.035 * SR), 0.001, 0.008)
    save("ui_hover", hover, 0.25)
    # Cards
    save("card_hover", swish(0.07, 2500, 9000, rise=0.3), 0.3)
    save("card_draw", swish(0.22, 1500, 8000, rise=0.25), 0.55)
    thump = np.sin(2 * np.pi * 110 * t_axis(0.18)) * env(int(0.18 * SR), 0.002, 0.05)
    play = swish(0.26, 900, 6000, rise=0.55)
    place(play, thump * 0.9, 0.13)
    save("card_play", reverb(play, 0.6, 0.18), 0.75)
    # Combat
    whoosh = swish(0.3, 300, 3500, rise=0.7)
    save("attack", whoosh, 0.7)
    hit = taiko(95, 0.35, slap=0.8)
    crack = bandpass(noise(0.12), 1200, 6000) * env(int(0.12 * SR), 0.001, 0.025)
    place(hit, crack * 0.8, 0)
    save("hit", reverb(hit, 0.5, 0.15), 0.85)
    heavy = taiko(58, 1.1, slap=0.5)
    place(heavy, taiko(88, 0.6, slap=0.9) * 0.5, 0.0)
    save("core_hit", reverb(heavy, 1.2, 0.25), 0.95)
    shield_t = t_axis(0.6)
    shield = sum(np.sin(2 * np.pi * f * shield_t) * np.exp(-shield_t / d) for f, d in ((1760, 0.25), (2637, 0.18), (3520, 0.12), (4186, 0.09)))
    shield = shield * np.clip(shield_t / 0.004, 0, 1) + swish(0.6, 4000, 11000, rise=0.05) * 0.2
    save("shield", reverb(shield, 0.8, 0.3), 0.55)
    heal = np.zeros(int(0.9 * SR))
    for i, s in enumerate([0, 2, 4, 5]):
        place(heal, chime(scale_note(s, 1), 0.6, 0.7), i * 0.07)
    save("heal", reverb(heal, 1.0, 0.3), 0.55)
    up = np.zeros(int(1.0 * SR))
    for i, s in enumerate([2, 4, 7]):
        place(up, chime(scale_note(s, 1), 0.8, 0.9), i * 0.08)
    place(up, swish(0.5, 5000, 12000, rise=0.1) * 0.25, 0.1)
    save("level_up", reverb(up, 1.2, 0.3), 0.7)
    ko = np.zeros(int(1.2 * SR))
    tt = t_axis(0.9)
    place(ko, np.sin(2 * np.pi * np.cumsum(220 * np.exp(-tt / 0.5)) / SR) * env(len(tt), 0.005, 0.35), 0)
    place(ko, lowpass(noise(0.7), 900) * env(int(0.7 * SR), 0.01, 0.2) * 0.8, 0.05)
    save("knockout", reverb(ko, 1.0, 0.3), 0.8)
    # Turn flow
    save("turn_start", trim(reverb(bell(392, 2.4), 1.8, 0.3)), 0.6)
    clack = lowpass(noise(0.08), 2500) * env(int(0.08 * SR), 0.001, 0.015) + 0.7 * np.sin(2 * np.pi * 620 * t_axis(0.08)) * env(int(0.08 * SR), 0.001, 0.03)
    save("turn_end", reverb(clack, 0.5, 0.2), 0.6)
    err = np.zeros(int(0.28 * SR))
    for i in range(2):
        place(err, np.sin(2 * np.pi * 150 * t_axis(0.1)) * env(int(0.1 * SR), 0.002, 0.04), i * 0.12)
    save("error", err, 0.35)
    # Shop / reveal
    coin = np.zeros(int(0.6 * SR))
    for i, f in enumerate((2093, 2637, 3136)):
        place(coin, chime(f, 0.35, 0.8 - i * 0.15), i * 0.05)
    save("purchase", reverb(coin, 0.6, 0.25), 0.5)
    flip = swish(0.18, 2000, 9000, rise=0.5)
    place(flip, chime(scale_note(4, 1), 0.4, 0.4), 0.08)
    save("reveal", reverb(flip, 0.6, 0.2), 0.6)
    ssr = np.zeros(int(2.4 * SR))
    for i, s in enumerate([0, 2, 4, 5, 7, 9]):
        place(ssr, chime(scale_note(s, 1), 1.2, 0.8), i * 0.06)
    place(ssr, bell(587, 2.0, 0.6), 0.36)
    place(ssr, swish(1.0, 5000, 12000, rise=0.1) * 0.3, 0.0)
    save("reveal_ssr", trim(reverb(ssr, 1.6, 0.35)), 0.8)
    # Match result
    win = np.zeros(int(3.2 * SR))
    for i, s in enumerate([0, 2, 4, 5, 7]):
        place(win, koto(scale_note(s), 1.4, 0.7), i * 0.11)
    place(win, taiko(70, 1.0, 0.8), 0.0)
    place(win, bell(587, 2.6, 0.7), 0.6)
    save("victory", trim(reverb(win, 1.8, 0.3)), 0.85)
    lose = np.zeros(int(3.2 * SR))
    for i, s in enumerate([4, 3, 1, 0]):
        place(lose, koto(scale_note(s, -1), 1.6, 0.4), i * 0.28)
    place(lose, flute(scale_note(0, -1), 2.2, 0.5), 0.9)
    save("defeat", trim(reverb(lose, 1.8, 0.35)), 0.8)


def music_menu():
    bpm = 66
    beat = 60 / bpm
    bars = 8
    length = bars * 4 * beat
    track = np.zeros(int(length * SR))
    drone_t = t_axis(length)
    drone = (np.sin(2 * np.pi * note(-12) * drone_t) + 0.5 * np.sin(2 * np.pi * note(-5) * drone_t)) * (0.6 + 0.4 * np.sin(2 * np.pi * drone_t / length) ** 2)
    track += 0.08 * drone
    melody = [(0, 0, 1.5), (2, 1.5, 0.5), (3, 2, 2), (4, 4, 1), (3, 5, 1), (2, 6, 2),
              (1, 8, 1), (2, 9, 1), (0, 10, 2), (-1, 12, 1.5), (0, 13.5, 0.5), (1, 14, 2),
              (4, 16, 1.5), (5, 17.5, 0.5), (4, 18, 1), (3, 19, 1), (2, 20, 2), (3, 22, 1), (1, 23, 1),
              (0, 24, 1.5), (1, 25.5, 0.5), (2, 26, 1), (1, 27, 1), (0, 28, 4)]
    for step, at, dur in melody:
        place_wrap(track, koto(scale_note(step + 5), dur * beat + 1.0, 0.55, 0.42), at * beat)
    # low koto pulse on each bar
    for bar in range(bars):
        root = [0, 0, -2, 0, 1, 0, -2, 0][bar]
        place_wrap(track, koto(scale_note(root), 2.4, 0.3, 0.32), bar * 4 * beat)
        place_wrap(track, koto(scale_note(root + 2), 2.0, 0.3, 0.2), bar * 4 * beat + 2 * beat)
    # a breathy phrase in the second half
    place_wrap(track, flute(scale_note(7), 3 * beat, 0.16), 16 * beat)
    place_wrap(track, flute(scale_note(6), 2.5 * beat, 0.14), 20 * beat)
    return reverb(track, 2.4, 0.35, wrap=True)


def music_battle():
    bpm = 84
    beat = 60 / bpm
    bars = 8
    length = bars * 4 * beat
    track = np.zeros(int(length * SR))
    drone_t = t_axis(length)
    track += 0.06 * (np.sin(2 * np.pi * note(-17) * drone_t) + 0.4 * np.sin(2 * np.pi * note(-10) * drone_t))
    kick = taiko(62, 0.9, slap=0.4)
    rim = taiko(150, 0.25, slap=1.0)
    for bar in range(bars):
        b0 = bar * 4 * beat
        place_wrap(track, kick * 0.55, b0)
        place_wrap(track, kick * 0.32, b0 + 1.5 * beat)
        place_wrap(track, rim * 0.18, b0 + 2 * beat)
        place_wrap(track, kick * 0.4, b0 + 3 * beat)
        if bar % 2 == 1:
            place_wrap(track, rim * 0.14, b0 + 3.5 * beat)
            place_wrap(track, rim * 0.12, b0 + 3.75 * beat)
    ostinato = [0, 2, 3, 2, 0, 2, 4, 3]
    for bar in range(bars):
        shift = [0, 0, 1, 0, -1, 0, 1, 2][bar]
        for i, s in enumerate(ostinato):
            place_wrap(track, koto(scale_note(s + shift), 0.9, 0.6, 0.22 if i % 2 else 0.3), (bar * 4 + i * 0.5) * beat)
    phrase = [(7, 0, 3), (8, 3, 1), (7, 4, 2), (5, 6, 2), (4, 8, 4), (5, 12, 2), (7, 14, 2),
              (9, 16, 3), (8, 19, 1), (7, 20, 2), (5, 22, 2), (4, 24, 3), (3, 27, 1), (2, 28, 4)]
    for s, at, dur in phrase:
        place_wrap(track, flute(scale_note(s), dur * beat * 0.95, 0.2), at * beat)
    return reverb(track, 1.8, 0.28, wrap=True)


if __name__ == "__main__":
    sfx()
    save("bgm_menu", music_menu(), 0.7, loop=True)
    save("bgm_battle", music_battle(), 0.7, loop=True)
