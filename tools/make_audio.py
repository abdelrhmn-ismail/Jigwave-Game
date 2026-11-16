#!/usr/bin/env python3
"""Generates Jigwave's own sound effects and relaxing music (100% original).

    python3 -I tools/make_audio.py

Pure Python (no numpy). Writes mono 22.05 kHz WAV files to assets/sounds/:
  effects: pick, snap, wrong, click, star, coin, peek, magic, win
  music:   music_home, music_puzzle_1, music_puzzle_2, music_puzzle_3
Music is calm and warm (music box, kalimba, soft pads, round bass) and
loops seamlessly. Godot imports the WAVs compressed (QOA), so they stay small.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
TAU = 2 * math.pi
OUT = Path(__file__).resolve().parent.parent / "assets" / "sounds"


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


NAMES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def n(name):
    base = NAMES[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        base, rest = base + 1, rest[1:]
    elif rest.startswith("b"):
        base, rest = base - 1, rest[1:]
    return 12 * (int(rest) + 1) + base


# --- instruments (each adds into a float buffer) -------------------------------

def add_tone(buf, start, dur, partials, amp, attack=0.005, decay=3.0, release=0.05, vibrato=0.0):
    """partials: [(freq, relative amp, extra decay)]. Exponential decay voice."""
    i0 = int(start * RATE)
    count = int((dur + release) * RATE)
    for i in range(count):
        idx = i0 + i
        if idx >= len(buf):
            break
        t = i / RATE
        env = min(1.0, t / attack) if attack > 0 else 1.0
        if t > dur:
            env *= max(0.0, 1.0 - (t - dur) / release)
        s = 0.0
        vib = 1.0 + vibrato * math.sin(TAU * 5.0 * t)
        for f, a, d in partials:
            s += a * math.exp(-t * (decay + d)) * math.sin(TAU * f * vib * t)
        buf[idx] += amp * env * s


def music_box(buf, start, note, amp=0.25, dur=1.6):
    f = midi(note)
    add_tone(buf, start, dur, [(f, 1.0, 0.0), (f * 2, 0.35, 2.0), (f * 4.2, 0.12, 6.0)], amp, 0.002, 2.2, 0.2)


def kalimba(buf, start, note, amp=0.25, dur=1.2):
    f = midi(note)
    add_tone(buf, start, dur, [(f, 1.0, 0.0), (f * 3.0, 0.18, 9.0), (f * 5.4, 0.08, 14.0)], amp, 0.003, 3.2, 0.15)


def bell(buf, start, note, amp=0.2, dur=1.8):
    f = midi(note)
    add_tone(buf, start, dur, [(f, 1.0, 0.0), (f * 2.76, 0.3, 2.5), (f * 5.4, 0.15, 5.0)], amp, 0.001, 1.6, 0.3)


def pad(buf, start, notes, dur, amp=0.05):
    """Soft chord: detuned sines, slow swell in and out."""
    i0 = int(start * RATE)
    count = int(dur * RATE)
    fade = min(0.8, dur * 0.3)
    freqs = []
    for note in notes:
        f = midi(note)
        freqs += [f * 0.997, f * 1.003, f * 2.0]
    for i in range(count):
        idx = i0 + i
        if idx >= len(buf):
            break
        t = i / RATE
        env = min(1.0, t / fade, (dur - t) / fade)
        trem = 0.85 + 0.15 * math.sin(TAU * 0.25 * (start + t))
        s = 0.0
        for k, f in enumerate(freqs):
            s += (0.35 if k % 3 == 2 else 1.0) * math.sin(TAU * f * t + k)
        buf[idx] += amp * env * trem * s / len(notes)


def bass(buf, start, note, dur, amp=0.18):
    f = midi(note)
    add_tone(buf, start, dur, [(f, 1.0, 0.0), (f * 2, 0.15, 1.0)], amp, 0.02, 1.2, 0.12)


def noise_burst(buf, start, dur, amp, cutoff=0.2, rng=None):
    """Soft filtered noise (brush / shaker / whoosh)."""
    rng = rng or random.Random(1)
    i0 = int(start * RATE)
    y = 0.0
    for i in range(int(dur * RATE)):
        idx = i0 + i
        if idx >= len(buf):
            break
        t = i / RATE
        env = math.exp(-t * 18.0 / max(dur, 0.01) * 0.3) * min(1.0, t / 0.004)
        y += cutoff * (rng.uniform(-1, 1) - y)
        buf[idx] += amp * env * y


# --- writing -------------------------------------------------------------------

def master(buf, peak=0.82):
    m = max(1e-9, max(abs(v) for v in buf))
    k = peak / m
    return [math.tanh(v * k * 1.1) / math.tanh(1.1) for v in buf]


def write(name, buf):
    OUT.mkdir(parents=True, exist_ok=True)
    data = master(buf)
    if not name.startswith("music"):
        # Short fade at the very end so no effect stops with a click.
        fade = min(len(data), int(0.02 * RATE))
        for i in range(fade):
            data[len(data) - fade + i] *= 1.0 - (i + 1) / fade
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in data))
    print(f"  {name}.wav  {len(buf) / RATE:.1f}s")


def blank(seconds):
    return [0.0] * int(seconds * RATE)


# --- sound effects -------------------------------------------------------------

def sfx():
    # pick: a soft wooden "tok" + a tiny rising blip (lifting the piece)
    b = blank(0.25)
    noise_burst(b, 0.0, 0.05, 0.5, 0.35)
    for i in range(int(0.12 * RATE)):
        t = i / RATE
        f = 520 + 900 * t
        b[i] += 0.35 * math.exp(-t * 30) * math.sin(TAU * f * t)
    write("pick", b)

    # snap: crisp click + bright two-note chime (the piece locks in)
    b = blank(0.9)
    noise_burst(b, 0.0, 0.012, 0.9, 0.8)
    kalimba(b, 0.005, n("E6"), 0.5, 0.5)
    kalimba(b, 0.045, n("B6"), 0.3, 0.5)
    write("snap", b)

    # wrong: soft, low, muted "bu-bum" (not harsh)
    b = blank(0.5)
    add_tone(b, 0.0, 0.12, [(midi(n("D3")), 1.0, 0.0), (midi(n("D4")), 0.2, 4.0)], 0.6, 0.004, 14.0, 0.05)
    add_tone(b, 0.11, 0.18, [(midi(n("A2")), 1.0, 0.0), (midi(n("A3")), 0.2, 4.0)], 0.6, 0.004, 12.0, 0.06)
    write("wrong", b)

    # click: a bubble pop for buttons
    b = blank(0.12)
    for i in range(len(b)):
        t = i / RATE
        f = 380 + 2600 * t
        b[i] = 0.5 * math.exp(-t * 45) * math.sin(TAU * f * t)
    write("click", b)

    # star: a clear music-box ding (played three times, higher each)
    b = blank(1.2)
    bell(b, 0.0, n("E6"), 0.6, 1.0)
    write("star", b)

    # coin: two quick bright notes
    b = blank(0.5)
    bell(b, 0.0, n("B5"), 0.45, 0.2)
    bell(b, 0.07, n("E6"), 0.5, 0.35)
    write("coin", b)

    # peek: an airy whoosh that opens up
    b = blank(0.9)
    rng = random.Random(4)
    y = 0.0
    for i in range(len(b)):
        t = i / RATE
        cut = 0.02 + 0.25 * math.sin(math.pi * min(1.0, t / 0.8))
        y += cut * (rng.uniform(-1, 1) - y)
        b[i] = 0.7 * math.sin(math.pi * min(1.0, t / 0.85)) * y
    for k, note in enumerate(["C6", "G6", "C7"]):
        bell(b, 0.25 + k * 0.08, n(note), 0.1, 0.4)
    write("peek", b)

    # magic: sparkly falling arpeggio (a hint places a piece)
    b = blank(1.3)
    for k, note in enumerate(["C7", "G6", "E6", "C6", "G5"]):
        kalimba(b, k * 0.06, n(note), 0.35, 0.6)
    noise_burst(b, 0.0, 0.5, 0.06, 0.9)
    write("magic", b)

    # win: rising kalimba arpeggio + a warm chord + shimmer
    b = blank(2.6)
    for k, note in enumerate(["C5", "E5", "G5", "C6", "E6", "G6"]):
        kalimba(b, k * 0.09, n(note), 0.4, 1.0)
    for note in ["C5", "E5", "G5", "C6"]:
        music_box(b, 0.6, n(note), 0.22, 1.8)
    pad(b, 0.5, [n("C4"), n("G4"), n("E5")], 2.0, 0.08)
    for k in range(10):
        bell(b, 0.7 + k * 0.11, n(["C7", "E7", "G7"][k % 3]), 0.05, 0.3)
    write("win", b)


# --- music ---------------------------------------------------------------------

def song(name, bpm, chords, melody_scale, seed, lead="music_box", bars=16, arp=True, shaker=False):
    """chords: list of (bass note, [pad notes]) — one per bar, repeated.
    The melody is a seeded motif on melody_scale with call/answer phrases,
    so it repeats enough to be catchy but varies enough not to bore."""
    rng = random.Random(seed)
    beat = 60.0 / bpm
    bar = beat * 4
    length = bar * bars
    buf = blank(length + 3.0)  # tail is wrapped to the start (seamless loop)
    voice = {"music_box": music_box, "kalimba": kalimba, "bell": bell}[lead]

    # Two 2-bar motifs (A and B) as (beat offset, scale step, length in beats).
    def motif():
        notes, t = [], 0.0
        while t < 8:
            dur = rng.choice([0.5, 0.5, 1.0, 1.0, 1.5, 2.0])
            if rng.random() < 0.18:
                t += dur  # a rest
                continue
            notes.append((t, rng.randint(0, len(melody_scale) - 1), dur))
            t += dur
        return notes

    a, bm = motif(), motif()
    form = [a, a, bm, a]  # 4 phrases of 2 bars = 8 bars, played twice
    for b_i in range(bars):
        root, notes = chords[b_i % len(chords)]
        t0 = b_i * bar
        pad(buf, t0, notes, bar + 0.4, 0.045)
        bass(buf, t0, root, beat * 1.8, 0.16)
        bass(buf, t0 + beat * 2, root + (7 if b_i % 2 else 12), beat * 1.6, 0.11)
        if arp:
            pattern = [0, 1, 2, 1, 2, 3, 2, 1]
            for k in range(8):
                note = notes[pattern[k] % len(notes)] + 12
                kalimba(buf, t0 + k * beat * 0.5, note, 0.07 if k % 2 else 0.09, beat * 0.45)
        if shaker:
            for k in range(8):
                noise_burst(buf, t0 + k * beat * 0.5, 0.06, 0.035 if k % 2 else 0.02, 0.6, rng)
    for p_i in range(bars // 2):
        phrase = form[p_i % len(form)]
        t0 = p_i * 2 * bar
        shift = 0 if p_i < bars // 4 else rng.choice([0, 0, 2])  # second half: small lift
        for beat_off, step, dur in phrase:
            note = melody_scale[min(len(melody_scale) - 1, step + shift)]
            voice(buf, t0 + beat_off * beat, note, 0.2, dur * beat)
    # Wrap the tail into the beginning so the loop point is seamless.
    total = int(length * RATE)
    for i in range(total, len(buf)):
        buf[i - total] += buf[i]
    write(name, buf[:total])


def music():
    C = n
    # Home: warm C major, music box.
    song("music_home", 76, [
        (C("C2"), [C("C4"), C("E4"), C("G4"), C("B4")]),
        (C("A1"), [C("A3"), C("C4"), C("E4"), C("G4")]),
        (C("F1"), [C("F3"), C("A3"), C("C4"), C("E4")]),
        (C("G1"), [C("G3"), C("B3"), C("D4"), C("A4")]),
    ], [C(x) for x in ["C5", "D5", "E5", "G5", "A5", "C6", "D6"]], seed=11)
    # Puzzle 1: floating F lydian, kalimba.
    song("music_puzzle_1", 84, [
        (C("F1"), [C("F3"), C("A3"), C("C4"), C("E4")]),
        (C("G1"), [C("G3"), C("B3"), C("D4"), C("F4")]),
        (C("E1"), [C("E3"), C("G3"), C("B3"), C("D4")]),
        (C("A1"), [C("A3"), C("C4"), C("E4"), C("G4")]),
    ], [C(x) for x in ["F5", "G5", "A5", "C6", "D6", "E6", "F6"]], seed=23, lead="kalimba")
    # Puzzle 2: slow D major pentatonic, bells, no arpeggio (very calm).
    song("music_puzzle_2", 68, [
        (C("D2"), [C("D4"), C("F#4"), C("A4"), C("C#5")]),
        (C("B1"), [C("B3"), C("D4"), C("F#4"), C("A4")]),
        (C("G1"), [C("G3"), C("B3"), C("D4"), C("F#4")]),
        (C("A1"), [C("A3"), C("C#4"), C("E4"), C("G4")]),
    ], [C(x) for x in ["D5", "E5", "F#5", "A5", "B5", "D6", "E6"]], seed=37, lead="bell", arp=False)
    # Puzzle 3: gentle A minor with a light shaker groove.
    song("music_puzzle_3", 88, [
        (C("A1"), [C("A3"), C("C4"), C("E4"), C("B4")]),
        (C("F1"), [C("F3"), C("A3"), C("C4"), C("E4")]),
        (C("C2"), [C("C4"), C("E4"), C("G4"), C("D5")]),
        (C("G1"), [C("G3"), C("B3"), C("D4"), C("E4")]),
    ], [C(x) for x in ["A4", "C5", "D5", "E5", "G5", "A5", "C6"]], seed=41, lead="music_box", shaker=True)


if __name__ == "__main__":
    print("effects:")
    sfx()
    print("music:")
    music()
