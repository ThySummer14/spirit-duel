#!/usr/bin/env python3
"""Render the Godot build's sound effects and music loops procedurally.

Everything is synthesised here (koto via Karplus-Strong, shakuhachi-like breathy
sine, taiko, temple bell, paper noise), so there are no third-party samples.
Output: godot/assets/audio/*.wav (16-bit mono effects and stereo music).

Usage: python3 scripts/gen-godot-audio.py
"""
import argparse
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


def taiko(freq=70, dur=0.9, gain=1.0, slap=0.3, random=None):
    t = t_axis(dur)
    pitch = freq * (1 + 0.6 * np.exp(-t / 0.03))
    phase = 2 * np.pi * np.cumsum(pitch) / SR
    body = np.sin(phase) * np.exp(-t / 0.28)
    excitation = noise(dur) if random is None else random.standard_normal(len(t))
    hit = lowpass(excitation, 1800) * np.exp(-t / 0.02) * slap * 4
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
        w.setnchannels(1 if data.ndim == 1 else data.shape[1])
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


def midi_hz(pitch):
    return 440.0 * 2 ** ((pitch - 69) / 12)


def swell(t, duration, attack, release):
    enter = np.clip(t / attack, 0.0, 1.0)
    exit = np.clip((duration - t) / release, 0.0, 1.0)
    return np.sin(np.pi * enter / 2) ** 2 * np.sin(np.pi * exit / 2) ** 2


def score_pluck(pitch, duration, touch):
    """A plucked string with a soft bridge transient and a separate body resonance."""
    t = t_axis(duration)
    freq = midi_hz(pitch)
    tone = np.zeros_like(t)
    for h in range(1, 12):
        partial = freq * h * (1 + 0.00015 * h * h)
        if partial >= SR * 0.44:
            break
        level = np.sin(0.46 * h) / (h ** 1.17)
        tone += level * np.sin(2 * np.pi * partial * t) * np.exp(-t * (1.45 + h * 0.63))
    body = np.sin(2 * np.pi * freq * t + 0.28) * np.exp(-2.5 * t)
    return (tone * (0.86 + touch * 0.14) + 0.20 * body) * swell(t, duration, 0.008, 0.12)


def score_wind(pitch, duration, breath_noise):
    t = t_axis(duration)
    vibrato = np.sin(2 * np.pi * 4.7 * t) * np.clip((t - 0.18) / 0.48, 0, 1)
    bend = -0.009 * np.exp(-t / 0.055) + 0.0038 * vibrato
    phase = 2 * np.pi * np.cumsum(midi_hz(pitch) * (1 + bend)) / SR
    tone = np.sin(phase) + 0.23 * np.sin(2 * phase + 0.4) + 0.11 * np.sin(3 * phase)
    air = bandpass(breath_noise[:len(t)], 650, 3700)
    return (tone + air * 0.19) * swell(t, duration, 0.15, 0.26)


def score_strings(pitches, duration):
    t = t_axis(duration)
    left = np.zeros_like(t)
    right = np.zeros_like(t)
    for index, pitch in enumerate(pitches):
        phase = 2 * np.pi * midi_hz(pitch) * t
        movement = 0.09 * np.sin(2 * np.pi * (0.33 + 0.07 * index) * t + index)
        left += np.sin(phase * 0.999 + movement) + 0.24 * np.sin(2 * phase)
        right += np.sin(phase * 1.001 - movement + 0.25 * index) + 0.24 * np.sin(2 * phase + 0.5)
    return np.column_stack((left, right)) * swell(t, duration, 0.68, 0.75)[:, None] / len(pitches)


def score_room(track, random, tail, wet):
    # Circular convolution keeps the room's decay continuous at the loop boundary.
    t = t_axis(tail)
    impulse = random.standard_normal((len(t), 2))
    impulse = (impulse + np.roll(impulse, 1, axis=0) * 0.62 + np.roll(impulse, 2, axis=0) * 0.27)
    impulse *= (np.clip(t / 0.014, 0, 1) * np.exp(-5.0 * t / tail))[:, None]
    impulse /= np.sqrt(np.sum(impulse ** 2, axis=0))
    signal = np.fft.rfft(track, axis=0)
    response = np.fft.rfft(impulse, n=len(track), axis=0)
    room = np.fft.irfft(signal * response, n=len(track), axis=0)
    early = np.roll(track[:, ::-1], int(SR * 0.037), axis=0)
    return track + 0.073 * early + wet * room


MENU_CHORDS = (
    (50, 57, 62, 66), (47, 54, 62, 69), (43, 55, 59, 66), (45, 57, 62, 64),
    (50, 57, 62, 66), (47, 54, 59, 62), (43, 55, 59, 64), (45, 57, 61, 64),
    (47, 54, 62, 66), (43, 55, 59, 62), (50, 57, 62, 69), (45, 57, 62, 64),
    (43, 55, 59, 66), (47, 54, 62, 64), (45, 57, 61, 64), (50, 57, 62, 66),
)
MENU_MELODY = (
    ((0.5, 66), (1.5, 69), (2.5, 71)), ((0, 69), (1.75, 66), (3, 64)),
    ((0.5, 62), (2, 64), (3, 66)), ((0, 64), (2.5, 62)),
    ((0.5, 66), (1.5, 69), (2.5, 74)), ((0, 71), (1.5, 69), (3, 66)),
    ((0.5, 64), (2, 62), (3, 59)), ((0, 61), (2.5, 64)),
    ((0.5, 66), (1.75, 69)), ((0, 71), (2.25, 74)),
    ((0, 76), (1.75, 74), (3, 69)), ((0.5, 66), (2, 64)),
    ((0.5, 62), (1.5, 66), (2.5, 69)), ((0, 71), (1.5, 69), (3, 66)),
    ((0.5, 64), (2.25, 61)), ((0.5, 62), (2.5, 69)),
)
BATTLE_CHORDS = (
    (38, 50, 57, 65), (46, 53, 58, 62), (43, 50, 55, 58), (45, 52, 57, 60),
    (38, 50, 57, 65), (48, 55, 60, 64), (46, 53, 58, 65), (45, 52, 57, 61),
    (43, 50, 55, 62), (46, 53, 58, 65), (38, 50, 57, 65), (48, 55, 60, 67),
    (43, 50, 55, 58), (46, 53, 58, 62), (45, 52, 57, 60), (45, 52, 57, 61),
)
BATTLE_MELODY = (
    ((0.5, 65), (1.5, 69), (2.75, 72)), ((0.25, 70), (1.75, 69), (3, 65)),
    ((0.5, 67), (1.5, 65), (2.5, 62)), ((0.25, 64), (2, 69)),
    ((0.5, 65), (1.5, 69), (2.75, 74)), ((0.25, 72), (2, 67)),
    ((0.5, 65), (1.5, 62), (2.75, 65)), ((0.25, 64), (2.25, 61)),
    ((0.5, 67), (2.25, 70)), ((0.25, 74), (1.75, 72), (3, 70)),
    ((0.5, 69), (1.5, 65), (2.75, 62)), ((0.25, 64), (2, 67)),
    ((0.5, 65), (2.25, 67)), ((0.25, 70), (1.75, 74), (3, 70)),
    ((0.5, 69), (2.25, 65)), ((0.25, 64), (2.75, 61)),
)


def music_score(battle):
    beat = 60 / (92 if battle else 72)
    chords = BATTLE_CHORDS if battle else MENU_CHORDS
    melody = BATTLE_MELODY if battle else MENU_MELODY
    random = np.random.default_rng(318 if battle else 718)
    track = np.zeros((round(len(chords) * 4 * beat * SR), 2))
    breath = random.standard_normal(3 * SR)
    pattern = ((0.0, 0), (0.75, 1), (1.5, 2), (2.25, 1), (3, 3), (3.5, 2)) if battle else (
        (0.0, 0), (0.75, 1), (1.75, 2), (2.5, 3), (3.25, 1),
    )

    def add(clip, at, gain, pan=0.0):
        stereo = clip if clip.ndim == 2 else clip[:, None] * np.sqrt((1 + np.array([-pan, pan])) / 2)
        place_wrap(track, stereo * gain, at)

    for index, (chord, phrase) in enumerate(zip(chords, melody)):
        start = index * 4 * beat
        add(score_strings(chord[1:], 4 * beat + 0.38), start, 0.09 if battle else 0.105)
        for j, (position, degree) in enumerate(pattern):
            touch = random.uniform(0.79, 1.0)
            dur = 0.84 if battle else 1.45
            offset = position * beat + random.uniform(0, 0.016)
            add(score_pluck(chord[degree], dur, touch), start + offset,
                (0.21 if degree == 0 else 0.15) * touch, -0.30 + 0.11 * (j % 3))
        for j, (position, pitch) in enumerate(phrase):
            touch = random.uniform(0.81, 1.0)
            at = start + position * beat + random.uniform(0, 0.012)
            if index in range(8, 12) or (battle and index % 4 == 3):
                next_position = phrase[j + 1][0] if j + 1 < len(phrase) else 4.06
                dur = max(0.40, (next_position - position) * beat + 0.16)
                add(score_wind(pitch, dur, breath), at, 0.21 * touch, 0.20)
            else:
                add(score_pluck(pitch, 1.48, touch), at, 0.48 * touch, 0.14)
        if battle:
            hits = (0.0, 2.5) if index % 2 == 0 else (0.0, 1.5, 3.0)
            for position in hits:
                add(taiko(72, 0.45, slap=0.20, random=random), start + position * beat,
                    0.19 if position == 0 else 0.095, -0.06)
            add(taiko(185, 0.13, slap=0.64, random=random), start + 2 * beat, 0.062, 0.32)

    mixed = score_room(track, random, 1.16 if battle else 1.72, 0.14 if battle else 0.20)
    mixed -= np.mean(mixed, axis=0)
    # A gentle saturation gives louder phrases headroom without hard clipping.
    return np.tanh(mixed * 1.12)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--music-only", action="store_true", help="replace only the two background loops")
    if not parser.parse_args().music_only:
        sfx()
    save("bgm_menu", music_score(False), 0.65, loop=True)
    save("bgm_battle", music_score(True), 0.61, loop=True)
