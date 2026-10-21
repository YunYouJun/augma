# /// script
# requires-python = ">=3.11"
# dependencies = ["numpy>=2.1", "scipy>=1.14"]
# ///
"""Compose the Augma promo theme in code.

An original track in an anime-film style: supersaw pads, a formant choir, an arpeggio, a glassy FM bell motif
and driving drums, in D minor at 140 BPM. Every note is written below, so the sections and hits line up with
the video's cuts, and a fixed seed makes the result reproducible.

    uv run video/music/compose.py

Writes video/music/out/augma-theme.wav and .m4a (loudness-normalised to -14 LUFS), beats.json with the bar,
section and hit times the edit cuts to, and spectrum.png / waveform.png for a quick look at the structure.
"""
import json
import subprocess
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100
BPM = 140
BEAT = 60 / BPM
BAR = 4 * BEAT
TAIL = 4.0
OUT = Path(__file__).parent / 'out'
rng = np.random.default_rng(20261022)

# Sections with one chord per bar. Intro and build share the i-VI-III-VII loop; the chorus lifts to VI-VII-i.
SECTIONS = [
    ('intro', ['Dm', 'Bb', 'F', 'C'] * 2),
    ('build', ['Dm', 'Bb', 'F', 'C'] * 2),
    ('rise', ['Gm', 'Bb', 'C', 'A']),
    ('chorus', ['Bb', 'C', 'Dm', 'Dm', 'Bb', 'C', 'F', 'A'] * 2),
    ('bridge', ['Bb', 'Bb', 'C', 'C']),
    ('final', ['Bb', 'C', 'Dm', 'Dm', 'Bb', 'C', 'F', 'A']),
    ('outro', ['Dm', 'Bb', 'Dsus', 'Dm']),
]
CHORDS = {'Dm': (2, 5, 9), 'Bb': (10, 2, 5), 'F': (5, 9, 0), 'C': (0, 4, 7), 'Gm': (7, 10, 2), 'A': (9, 1, 4), 'Dsus': (2, 7, 9)}

# The chorus melody over Bb | C | Dm | Dm | Bb | C | F | A: (bar, beat, beats, midi note).
MELODY = [
    (0, 0, .5, 74), (0, .5, .5, 77), (0, 1, 1.5, 82), (0, 2.5, .5, 81), (0, 3, 1, 77),
    (1, 0, .5, 76), (1, .5, .5, 79), (1, 1, 1.5, 84), (1, 2.5, .5, 82), (1, 3, 1, 79),
    (2, 0, 1.5, 81), (2, 1.5, .5, 77), (2, 2, 2, 86),
    (3, 0, .5, 84), (3, .5, .5, 81), (3, 1, 1, 77), (3, 2, 1, 76), (3, 3, 1, 74),
    (4, 0, .5, 74), (4, .5, .5, 77), (4, 1, 1, 82), (4, 2, 1, 84), (4, 3, 1, 86),
    (5, 0, 1.5, 88), (5, 1.5, .5, 86), (5, 2, 1, 84), (5, 3, 1, 79),
    (6, 0, 1, 81), (6, 1, 1, 84), (6, 2, 1.5, 89), (6, 3.5, .5, 88),
    (7, 0, 2, 88), (7, 2, 1, 85), (7, 3, 1, 81),
]

START = {}
SEC = []
for _name, _chords in SECTIONS:
    START[_name] = len(SEC)
    SEC += [_name] * len(_chords)
PROG = [c for _, chords in SECTIONS for c in chords]
BARS = len(PROG)
N = int((BARS * BAR + TAIL) * SR)
T = np.arange(N, dtype=np.float32) / SR


def at(bar, beat=0.0):
    return (bar * 4 + beat) * BEAT


def mtof(m):
    return 440.0 * 2 ** ((np.asarray(m, float) - 69) / 12)


def voice(pcs, lo):
    """Place each pitch class in the octave starting at midi note `lo`."""
    return sorted(lo + (pc - lo) % 12 for pc in pcs)


def bars_of(*names):
    return [b for b in range(BARS) if SEC[b] in names]


def runs(bars):
    """Merge consecutive bars holding the same chord into (first bar, length, chord)."""
    out = []
    for b in bars:
        if out and out[-1][2] == PROG[b] and out[-1][0] + out[-1][1] == b:
            out[-1][1] += 1
        else:
            out.append([b, 1, PROG[b]])
    return out


# --- buffers, mixing helpers and filters ---------------------------------------------------------------

def bus(stereo=True):
    return np.zeros((2, N) if stereo else N, np.float32)


def pan(x, p=0.0):
    a = (p + 1) * np.pi / 4
    return np.vstack([x * np.cos(a), x * np.sin(a)]) * np.sqrt(2)


def add(buf, t, x, gain=1.0, p=0.0):
    i = int(round(t * SR))
    if i >= N:
        return
    if buf.ndim == 2 and x.ndim == 1:
        x = pan(x, p)
    n = min(N - i, x.shape[-1])
    buf[..., i:i + n] += gain * x[..., :n]


def sos(kind, fc, order=2):
    return signal.butter(order, fc, kind, fs=SR, output='sos')


def filt(x, kind, fc, order=2):
    return signal.sosfilt(sos(kind, fc, order), x, axis=-1).astype(np.float32)


def sweep(x, times, freqs, kind='lowpass', block=256):
    """Filter with a cutoff that follows (times, freqs), interpolated on a log scale."""
    out = np.empty_like(x)
    zi = np.zeros((1,) + x.shape[:-1] + (2,))
    logf = np.log(freqs)
    for i in range(0, x.shape[-1], block):
        fc = min(float(np.exp(np.interp(i / SR, times, logf))), SR * 0.45)
        out[..., i:i + block], zi = signal.sosfilt(sos(kind, fc), x[..., i:i + block], axis=-1, zi=zi)
    return out


def auto(points):
    """A gain curve through (time, value) points."""
    t, v = zip(*points)
    return np.interp(T, t, v).astype(np.float32)


def env(dur, a=0.005, d=0.1, s=0.8, r=0.1):
    n, na, nd, nr = int(dur * SR), max(1, int(a * SR)), max(1, int(d * SR)), int(r * SR)
    e = np.full(n, s, np.float32)
    e[:min(na, n)] = np.linspace(0, 1, na, endpoint=False)[:n]
    if n > na:
        e[na:na + nd] = np.linspace(1, s, nd)[:n - na]
    tail = (e[-1] if n else 0) * np.exp(-np.linspace(0, 6, nr))
    return np.concatenate([e, tail]).astype(np.float32)


def shape(x, e):
    n = min(x.shape[-1], len(e))
    return x[..., :n] * e[:n]


# --- oscillators -----------------------------------------------------------------------------------------

def saw(f, n, phase=None):
    """Band-limited sawtooth (polyBLEP); f may be a per-sample array."""
    if n <= 0:
        return np.zeros(0, np.float32)
    dt = np.broadcast_to(np.asarray(f, float) / SR, (n,))
    ph = ((rng.random() if phase is None else phase) + np.cumsum(dt)) % 1.0
    y = 2 * ph - 1
    m = ph < dt
    x = ph[m] / dt[m]
    y[m] -= x + x - x * x - 1
    m = ph > 1 - dt
    x = (ph[m] - 1) / dt[m]
    y[m] -= x * x + x + x + 1
    return y.astype(np.float32)


def square(f, n):
    ph = rng.random()
    return 0.5 * (saw(f, n, ph) - saw(f, n, (ph + 0.5) % 1))


def supersaw(m, dur, voices=7, cents=26, width=0.8):
    n = int(dur * SR)
    out = np.zeros((2, n), np.float32)
    for c, p in zip(np.linspace(-cents, cents, voices), np.linspace(-width, width, voices)):
        out += pan(saw(mtof(m) * 2 ** (c / 1200), n), p)
    return out / np.sqrt(voices)


def noise(n):
    return rng.standard_normal(n).astype(np.float32)


# --- instruments -----------------------------------------------------------------------------------------

def kick():
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 42 + 120 * np.exp(-t / 0.03) + 30 * np.exp(-t / 0.12)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.32)
    click = filt(noise(n), 'highpass', 1500) * np.exp(-t / 0.004)
    return (np.tanh(1.6 * (body + 0.25 * click)) / np.tanh(1.6)).astype(np.float32)


def snare():
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    rattle = filt(noise(n), 'bandpass', [1200, 7000]) * np.exp(-t / 0.11)
    body = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.05) + 0.5 * np.sin(2 * np.pi * 330 * t) * np.exp(-t / 0.03)
    return (0.6 * rattle + 0.7 * body).astype(np.float32)


def clap():
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    burst = sum(np.exp(-np.maximum(t - d, 0) / 0.006) * (t >= d) for d in (0, 0.011, 0.022))
    tail = np.exp(-np.maximum(t - 0.022, 0) / 0.09) * (t >= 0.022)
    return (filt(noise(n), 'bandpass', [900, 3500]) * (burst + 0.6 * tail)).astype(np.float32)


def hat(open_=False):
    n = int((0.45 if open_ else 0.09) * SR)
    t = np.arange(n) / SR
    return (filt(noise(n), 'highpass', 7500) * np.exp(-t / (0.15 if open_ else 0.022)) * np.minimum(1, t / 0.0008)).astype(np.float32)


def crash(dur=3.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    ring = (np.sin(2 * np.pi * 3150 * t) + np.sin(2 * np.pi * 4280 * t) + np.sin(2 * np.pi * 5490 * t)) / 3
    air = filt(filt(noise(n), 'highpass', 3000), 'lowpass', 11000)
    return (air * np.exp(-t / 1.0) * np.minimum(1, t / 0.003) * (0.7 + 0.3 * ring)).astype(np.float32)


def tom(hz):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    f = hz * (0.7 + 0.3 * np.exp(-t / 0.08))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.25)
    return (body + 0.2 * filt(noise(n), 'lowpass', 2500) * np.exp(-t / 0.02)).astype(np.float32)


def impact(dur=3.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 32 + 40 * np.exp(-t / 0.25)
    boom = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 1.2)
    thud = filt(noise(n), 'lowpass', 400) * np.exp(-t / 0.25)
    return np.tanh(1.5 * (boom + 0.6 * thud)).astype(np.float32)


def riser(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    air = filt(sweep(noise(n), [0, dur], [300, 7000]), 'highpass', 200)
    f = mtof(62) * 2 ** (t / dur)
    tone = filt(sum(saw(f * 2 ** (c / 1200), n) for c in (-12, 0, 12)) / 3, 'lowpass', 5000)
    return ((0.45 * air + 0.45 * tone) * (t / dur) ** 2).astype(np.float32)


def downlifter(dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    return (sweep(noise(n), [0, dur], [8000, 250]) * np.exp(-t / (dur / 3))).astype(np.float32)


def reverse_crash(dur):
    return crash(dur + 0.5)[:int(dur * SR)][::-1].copy()


def bell(m, dur=2.5):
    """A glassy FM bell, the motif's 'AR chime'."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = mtof(m)
    y = np.sin(2 * np.pi * f * t + 1.6 * np.exp(-t / 0.5) * np.sin(2 * np.pi * 3 * f * t))
    return (y * np.exp(-t / 1.1) * np.minimum(1, t / 0.002)).astype(np.float32)


def choir_voice(m, dur):
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros((2, n), np.float32)
    for c, p in zip((-9, -3, 3, 9), (-0.6, -0.2, 0.2, 0.6)):
        vib = 1 + 0.0035 * np.sin(2 * np.pi * (5 + rng.random()) * t + rng.random() * 6.3) * np.minimum(1, t / 0.6)
        out += pan(saw(mtof(m) * 2 ** (c / 1200) * vib, n), p)
    return out / 2


def formants(x):
    """Shape the choir's saws into an open 'ah' with four vocal formants."""
    y = 0.15 * filt(x, 'lowpass', 500)
    for fc, g in ((730, 1.0), (1090, 0.55), (2440, 0.3), (3400, 0.15)):
        y += g * filt(x, 'bandpass', [fc / 1.12, fc * 1.12])
    return y


def delay(x, beats=0.75, feedback=0.38, taps=5):
    """Ping-pong delay, dotted eighths by default."""
    d = int(beats * BEAT * SR)
    y = np.zeros_like(x)
    for k in range(1, taps + 1):
        src = x[k % 2] if x.ndim == 2 else x
        dst = y[(k + 1) % 2] if x.ndim == 2 else y
        dst[k * d:] += feedback ** k * src[:N - k * d]
    return y


def reverb(x, rt60=2.6, pre=0.02):
    n = int((rt60 * 1.3) * SR)
    t = np.arange(n) / SR
    ir = rng.standard_normal((2, n)) * np.exp(-6.91 * t / rt60)
    ir = signal.sosfilt(sos('lowpass', 6000, 1), ir, axis=-1)
    ir = np.concatenate([np.zeros((2, int(pre * SR))), ir], axis=1)
    ir /= np.sqrt((ir ** 2).sum(axis=1, keepdims=True))
    return signal.oaconvolve(x, ir, axes=-1)[:, :N].astype(np.float32)


def rms(x, t0, t1):
    seg = x[..., int(t0 * SR):int(t1 * SR)]
    return float(np.sqrt(np.mean(seg.astype(np.float64) ** 2)) + 1e-12)


# --- arrangement -----------------------------------------------------------------------------------------

def compose():
    hits = []  # (time, kind) for the edit

    # Pads: the whole track, opening up through the intro and dipping for the bridge.
    pads = bus()
    for b, length, ch in runs(range(BARS)):
        dur = length * BAR
        e = env(dur, a=0.35, d=0.4, s=0.8, r=0.9)
        for m in voice(CHORDS[ch], 57) + voice(CHORDS[ch][:1], 45):
            add(pads, at(b), shape(supersaw(m, dur + 0.9), e), 0.5)
    c, b2, f = at(START['chorus']), at(START['bridge']), at(START['final'])
    pads = sweep(pads, [0, at(8), at(16), c - 0.01, c, b2, b2 + 1, at(START['bridge'] + 3), f, at(START['outro']), N / SR],
                 [280, 4000, 4000, 7500, 6500, 6500, 2200, 4000, 7000, 7000, 900])

    # Arpeggio in sixteenths over the chord, filtered open through the intro and the rise.
    arp = bus()
    for b in bars_of('intro', 'build', 'rise', 'chorus', 'final'):
        v = voice(CHORDS[PROG[b]], 69)
        seq = [v[0], v[1], v[2], v[0] + 12, v[2], v[1], v[0] + 12, v[2] + 12]
        for k in range(16):
            if SEC[b] == 'rise' and b == START['rise'] + 3 and k >= 14:
                break
            e = env(BEAT / 4 * 0.9, a=0.002, d=0.12, s=0.25, r=0.08)
            fr = mtof(seq[k % 8])
            x = 0.6 * saw(fr, len(e)) + 0.4 * square(fr, len(e))
            add(arp, at(b, k / 4), x * e, 1.0 if k % 4 == 0 else 0.7, 0.35 if k % 2 else -0.35)
    arp = sweep(arp, [0, at(8), at(16), c, f, N / SR], [400, 5000, 3000, 5500, 6000, 6000])
    arp *= auto([(0, 0.25), (at(4), 0.7), (at(8), 1), (N / SR, 1)])

    # Glass bells: the opening motif, answered in the bridge and the outro.
    bells = bus()
    for b in bars_of('intro', 'bridge', 'outro'):
        v = voice(CHORDS[PROG[b]], 74)
        motif = [(0, v[0]), (1.5, v[2]), (3, v[1] + 12)] if SEC[b] != 'outro' else [(0, v[2]), (2, v[0] + 12)]
        for i, (beat, m) in enumerate(motif):
            add(bells, at(b, beat), bell(m), 0.8 if beat == 0 else 0.6, -0.4 if i % 2 else 0.4)

    # Choir: rises with the build-up, carries the chorus and the bridge, and holds the last chord.
    choir_dry = bus()
    for b, length, ch in runs(bars_of('rise', 'chorus', 'bridge', 'final', 'outro')):
        dur = length * BAR
        e = env(dur, a=0.8, d=0.5, s=0.85, r=1.4)
        for m in voice(CHORDS[ch], 62) + voice(CHORDS[ch][:1], 50):
            add(choir_dry, at(b), shape(choir_voice(m, dur + 1.4), e), 0.5)
    choir = formants(choir_dry)
    del choir_dry
    choir *= auto([(0, 0), (at(START['rise']), 0.2), (c, 1), (N / SR, 1)])

    # Bass: a sine sub and a filtered saw on the root, in quarters, then eighths.
    sub, bass_mid = bus(False), bus(False)
    def bass(t, m, dur, gain=1.0):
        e = env(dur, a=0.003, d=0.12, s=0.75, r=0.05)
        add(sub, t, np.sin(2 * np.pi * mtof(m) * np.arange(len(e)) / SR).astype(np.float32) * e, gain)
        add(bass_mid, t, saw(mtof(m), len(e)) * e, gain)
    for b in range(BARS):
        root = voice(CHORDS[PROG[b]][:1], 33)[0]
        s = SEC[b]
        if s == 'build' and b >= START['build'] + 4:
            for k in range(4):
                bass(at(b, k), root, BEAT * 0.9)
        elif s == 'rise':
            steps = [k / 4 for k in range(12)] if b == START['rise'] + 3 else [k / 2 for k in range(8)]
            for k in steps:
                bass(at(b, k), root, BEAT * (0.22 if b == START['rise'] + 3 else 0.45))
        elif s in ('chorus', 'final'):
            for k in range(8):
                bass(at(b, k / 2), root, BEAT * 0.45, 1.0 if k % 2 == 0 else 0.85)
    bass(at(START['outro']), 38, 2 * BAR, 1.0)
    bass_mid = np.tanh(1.5 * filt(bass_mid, 'lowpass', 800)).astype(np.float32)

    # Lead: the chorus melody twice, then once more with an octave above in the final chorus.
    lead_dry = bus()
    for start, octave_up in ((START['chorus'], False), (START['chorus'] + 8, False), (START['final'], True)):
        for bar, beat, beats, m in MELODY:
            dur = beats * BEAT * 0.95
            e = env(dur, a=0.008, d=0.25, s=0.7, r=0.15)
            x = supersaw(m, dur + 0.2, voices=5, cents=14, width=0.5)
            x[:, :] += pan(0.35 * saw(mtof(m - 12), x.shape[1]))
            add(lead_dry, at(start + bar, beat), shape(x, e), 1.0)
            if octave_up:
                add(lead_dry, at(start + bar, beat), shape(supersaw(m + 12, dur + 0.2, voices=5, cents=10, width=0.7), e), 0.35)
    lead = filt(lead_dry, 'lowpass', 6000)
    lead += 0.28 * delay(lead)
    del lead_dry

    # Drums.
    kicks, snares, hats, crashes, fx = bus(False), bus(False), bus(), bus(), bus()
    duck_hits = []
    def kick_at(t, g=1.0):
        add(kicks, t, kick(), g)
        duck_hits.append((t, g))
    for b in range(BARS):
        s, o = SEC[b], b - START[SEC[b]]
        if s == 'build':
            for beat in ([0, 1.5] if o < 4 else [0, 1, 2, 3]):
                kick_at(at(b, beat))
            for beat in ([2] if o < 4 else [1, 3]):
                add(snares, at(b, beat), clap(), 0.8)
            if o >= 4:
                for k in range(4):
                    add(hats, at(b, k + 0.5), hat(), 0.8, 0.25)
        elif s == 'rise':
            if o < 2:
                for beat in range(4):
                    kick_at(at(b, beat))
                for k in range(4):
                    add(hats, at(b, k + 0.5), hat(), 0.7, 0.25)
            step = [1, 0.5, 0.25, 0.125][o]
            for i in range(int((3.5 if o == 3 else 4) / step)):
                beat = i * step
                level = 0.25 + 0.5 * (o * 4 + beat) / 16
                add(snares, at(b, beat), snare(), level)
        elif s in ('chorus', 'final'):
            phrase_end = o % 8 == 7
            for beat in range(4):
                if not (phrase_end and beat == 3):
                    kick_at(at(b, beat))
            for beat in (1, 3):
                if not (phrase_end and beat == 3):
                    add(snares, at(b, beat), snare(), 0.8)
                    add(snares, at(b, beat), clap(), 0.6)
            for k in range(16):
                add(hats, at(b, k / 4), hat(), (0.5, 0.3, 0.8, 0.3)[k % 4], -0.2)
            for k in range(4):
                add(hats, at(b, k + 0.5), hat(True), 0.35, 0.3)
            if o % 8 == 0:
                add(crashes, at(b), crash(), 1.0, -0.3)
            if phrase_end:
                for i, hz in enumerate((170, 150, 130, 110, 95, 85, 80, 75)[-4 if o < 15 else -8:]):
                    add(snares, at(b, (3 if o < 15 else 2) + i / 4), tom(hz), 0.9)
        elif s == 'bridge':
            if o < 3:
                kick_at(at(b), 0.5)
            else:
                for i in range(8):
                    add(snares, at(b, 2 + i / 4), snare(), 0.3 + 0.08 * i)
        elif s == 'outro' and o == 0:
            kick_at(at(b))
            add(crashes, at(b), crash(5.0), 1.0)

    # Transitions: the opening hit, crashes and reversed crashes into each section, risers, impacts.
    add(fx, 0, impact(), 0.5)
    hits.append((0.0, 'impact'))
    add(crashes, at(START['build']), crash(), 0.9, 0.3)
    hits.append((at(START['build']), 'crash'))
    for t in (at(START['build']), at(START['chorus']), at(START['final'])):
        rc = reverse_crash(2 * BEAT)
        add(fx, t - len(rc) / SR, rc, 0.6)
    add(fx, at(START['rise']), riser(4 * BAR - BEAT / 2), 1.0)
    add(fx, at(START['bridge'] + 3), riser(BAR), 0.8)
    for t in (at(START['chorus']), at(START['final']), at(START['outro'])):
        add(fx, t, impact(), 1.0)
        add(fx, t, downlifter(BAR), 0.5)
        hits.append((t, 'drop'))

    # Sidechain: everything melodic breathes around the kick.
    curve = np.ones(N, np.float32)
    tt = np.arange(int(0.6 * SR)) / SR
    dip = np.exp(-tt / 0.16) * (1 - np.exp(-tt / 0.004))
    for t, g in duck_hits:
        i = int(t * SR)
        m = min(len(dip), N - i)
        curve[i:i + m] = np.minimum(curve[i:i + m], 1 - g * dip[:m])
    def duck(depth):
        return 1 - depth * (1 - curve)
    pads *= duck(0.45)
    arp *= duck(0.35)
    choir *= duck(0.25)
    lead *= duck(0.15)
    sub *= duck(0.75)
    bass_mid *= duck(0.6)

    # A breath before each drop.
    gap = auto([(0, 1)] + [p for t in (at(START['chorus']), at(START['final'])) for p in ((t - BEAT / 2 - 0.02, 1), (t - BEAT / 2, 0.15), (t - 0.01, 0.15), (t, 1))] + [(N / SR, 1)])
    for x in (pads, arp, choir):
        x *= gap

    # Balance the parts by loudness within the chorus (bells in the intro, effects in the rise).
    chorus = (at(START['chorus']), at(START['bridge']))
    ref = rms(kicks, *chorus)
    def level(x, db, window=chorus):
        return x * (ref * 10 ** (db / 20) / rms(x, *window))
    kicks = level(kicks, 0)
    snares = level(snares, -4)
    hats = level(hats, -21)
    crashes = level(crashes, -19)
    sub = level(sub, -4)
    bass_mid = level(bass_mid, -8)
    pads = level(pads, -8)
    arp = level(arp, -12)
    choir = level(choir, -10)
    lead = level(lead, -6)
    bells = level(bells, -9, (0, at(START['build'])))
    fx = level(fx, -12, (at(START['rise']), at(START['chorus'])))

    send = 0.3 * pads + 0.3 * arp + 0.6 * choir + 0.35 * lead + 0.6 * bells + 0.5 * fx + 0.2 * crashes + pan(0.25 * snares)
    wet = reverb(filt(send, 'highpass', 300))
    del send
    mix = pads + arp + choir + lead + bells + fx + hats + crashes + pan(kicks + snares + sub + bass_mid) + 0.55 * wet

    # Trim the rumble and gently roll off the top, so the saws and cymbals do not turn harsh.
    mix = filt(filt(mix, 'highpass', 30), 'lowpass', 13000, 1)
    mix /= np.percentile(np.abs(mix), 99.95)
    mix = np.tanh(1.1 * mix) / np.tanh(1.1)
    mix *= auto([(0, 1), (N / SR - 2.5, 1), (N / SR, 0)])
    mix *= 0.89 / np.max(np.abs(mix))
    return mix, hits


def master(raw, wav, m4a):
    """Two-pass EBU R128 normalisation to -14 LUFS, -1 dBTP."""
    target = 'I=-14:TP=-1.0:LRA=11'
    probe = subprocess.run(['ffmpeg', '-hide_banner', '-i', raw, '-af', f'loudnorm={target}:print_format=json', '-f', 'null', '-'],
                           capture_output=True, text=True, check=True).stderr
    m = json.loads(probe[probe.rindex('{'):probe.rindex('}') + 1])
    measured = ':'.join(f'measured_{k}={m["input_" + k.lower()]}' for k in ('I', 'TP', 'LRA')) + f':measured_thresh={m["input_thresh"]}:offset={m["target_offset"]}'
    af = f'loudnorm={target}:{measured}:linear=true'
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', raw, '-af', af, '-ar', str(SR), '-c:a', 'pcm_s16le', wav], check=True)
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'aac', '-b:a', '256k', '-movflags', '+faststart', m4a], check=True)
    return m


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    mix, hits = compose()
    raw = OUT / 'augma-theme.raw.wav'
    from scipy.io import wavfile
    wavfile.write(raw, SR, mix.T.astype(np.float32))
    wav, m4a = OUT / 'augma-theme.wav', OUT / 'augma-theme.m4a'
    m = master(str(raw), str(wav), str(m4a))
    raw.unlink()
    for name, size, lavfi in (('spectrum.png', '1800x600', 'showspectrumpic=s=1800x600:legend=1:scale=log'),
                              ('waveform.png', '1800x300', 'showwavespic=s=1800x300:split_channels=1')):
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(wav), '-lavfi', lavfi, '-frames:v', '1', str(OUT / name)], check=True)

    sections = []
    for name, chords in SECTIONS:
        first = START[name]
        sections.append({'name': name, 'start': round(at(first), 3), 'end': round(at(first + len(chords)), 3), 'bars': [first, first + len(chords)], 'chords': chords})
    beats = {
        'bpm': BPM, 'beat': round(BEAT, 6), 'bar': round(BAR, 6), 'key': 'D minor',
        'duration': round(N / SR, 3), 'music_end': round(at(BARS), 3),
        'sections': sections,
        'downbeats': [round(at(b), 3) for b in range(BARS)],
        'hits': [{'t': round(t, 3), 'kind': k} for t, k in sorted(hits)],
    }
    (OUT / 'beats.json').write_text(json.dumps(beats, indent=2) + '\n')
    print(f'{wav} ({N / SR:.1f}s, input {m["input_i"]} LUFS → -14 LUFS)')
    for s in sections:
        print(f'  {s["name"]:<7} {s["start"]:6.2f}–{s["end"]:6.2f}s  bars {s["bars"][0]}–{s["bars"][1]}')


if __name__ == '__main__':
    main()
