"""Generate the low-fi placeholder sound effects in sounds/.

Run from the repo root: python3 tools/gen_sounds.py
Everything is synthesised at 11025 Hz, 8-bit-ish crunch included, for a PS1 feel.
"""
import math
import os
import random
import struct
import wave

RATE = 11025
OUT = os.path.join(os.path.dirname(__file__), "..", "sounds")
rng = random.Random(7)


def write(name, samples, loop=False):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = bytearray()
        for s in samples:
            s = max(-1.0, min(1.0, s))
            s = round(s * 64) / 64  # bit crush
            frames += struct.pack("<h", int(s * 32000))
        w.writeframes(bytes(frames))


def env(i, n, attack=0.01, release=0.3):
    t = i / n
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = 1.0 if t < 1 - release else max(0.0, (1 - t) / release)
    return a * r


def lowpass(samples, k):
    out, y = [], 0.0
    for s in samples:
        y += k * (s - y)
        out.append(y)
    return out


def noise(n):
    return [rng.uniform(-1, 1) for _ in range(n)]


def thump():
    n = int(RATE * 0.9)
    base = [math.sin(2 * math.pi * (55 - 25 * i / n) * i / RATE) * math.exp(-i / (RATE * 0.18)) for i in range(n)]
    crunch = lowpass(noise(n), 0.08)
    return [b * 0.9 + c * math.exp(-i / (RATE * 0.05)) * 0.8 for i, (b, c) in enumerate(zip(base, crunch))]


def hiss():
    n = int(RATE * 3.0)
    raw = noise(n)
    hp = [raw[i] - raw[i - 1] if i else 0 for i in range(n)]
    return [h * 0.5 * env(i, n, 0.05, 0.4) for i, h in enumerate(hp)]


def whistle():
    n = int(RATE * 1.6)
    out = []
    for i in range(n):
        t = i / RATE
        f = 420 + 8 * math.sin(2 * math.pi * 5 * t)
        s = math.sin(2 * math.pi * f * t) * 0.5 + math.sin(2 * math.pi * f * 1.5 * t) * 0.3
        s += rng.uniform(-0.15, 0.15)
        out.append(s * env(i, n, 0.08, 0.35))
    return out


def step():
    n = int(RATE * 0.12)
    return [s * math.exp(-i / (RATE * 0.02)) * 0.6 for i, s in enumerate(lowpass(noise(n), 0.3))]


def pickup():
    n = int(RATE * 0.15)
    return [math.sin(2 * math.pi * (600 + 900 * i / n) * i / RATE) * 0.4 * env(i, n, 0.01, 0.5) for i in range(n)]


def clank():
    n = int(RATE * 0.8)
    out = []
    for i in range(n):
        t = i / RATE
        s = sum(math.sin(2 * math.pi * f * t) for f in (310, 523, 787, 1130)) / 4
        out.append(s * math.exp(-t * 6) * 0.7 + rng.uniform(-1, 1) * math.exp(-t * 40) * 0.5)
    return out


def tink():
    n = int(RATE * 0.3)
    return [math.sin(2 * math.pi * 1800 * i / RATE) * math.exp(-i / (RATE * 0.04)) * 0.5 for i in range(n)]


def drone():
    n = RATE * 6
    out = []
    for i in range(n):
        t = i / RATE
        s = math.sin(2 * math.pi * 41 * t) * 0.35 + math.sin(2 * math.pi * 61.5 * t + math.sin(t * 0.5)) * 0.2
        out.append(s)
    rumble = lowpass(noise(n), 0.02)
    return [o + r * 0.6 for o, r in zip(out, rumble)]


def heartbeat():
    n = int(RATE * 0.8)
    out = [0.0] * n
    for start in (0, int(RATE * 0.22)):
        for i in range(int(RATE * 0.15)):
            out[start + i] += math.sin(2 * math.pi * 50 * i / RATE) * math.exp(-i / (RATE * 0.04))
    return out


def death():
    n = int(RATE * 2.5)
    out = []
    for i in range(n):
        t = i / RATE
        f = 200 * math.exp(-t * 1.2) + 30
        out.append((math.sin(2 * math.pi * f * t) * 0.6 + rng.uniform(-1, 1) * 0.3) * env(i, n, 0.01, 0.5))
    return out


def creak():
    """Stiff wooden joint: the mannequin moving while nobody looks."""
    n = int(RATE * 0.45)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = 95 + 60 * math.sin(2 * math.pi * 3 * t) + rng.uniform(-20, 20)
        phase += 2 * math.pi * f / RATE
        pulse = 1.0 if (phase % (2 * math.pi)) < 0.6 else -0.2
        out.append(pulse * 0.45 * env(i, n, 0.05, 0.4))
    return lowpass(out, 0.5)


def flutter():
    """Papery wing beats."""
    n = int(RATE * 0.6)
    raw = lowpass(noise(n), 0.4)
    return [r * (0.5 + 0.5 * math.sin(2 * math.pi * 28 * i / RATE)) * 0.6 * env(i, n, 0.05, 0.3) for i, r in enumerate(raw)]


def screech():
    """The moth's scream after it snuffs a lantern."""
    n = int(RATE * 1.4)
    out = []
    for i in range(n):
        t = i / RATE
        f = 1400 + 500 * math.sin(2 * math.pi * 9 * t) - 300 * t
        s = math.sin(2 * math.pi * f * t) * 0.4 + rng.uniform(-1, 1) * 0.35
        out.append(s * env(i, n, 0.02, 0.3))
    return out


def tick():
    """A loot item that ticks a little too much like a heart."""
    n = int(RATE * 0.08)
    return [math.sin(2 * math.pi * 2600 * i / RATE) * math.exp(-i / (RATE * 0.006)) * 0.5 for i in range(n)]


def bite():
    n = int(RATE * 0.5)
    crunch = lowpass(noise(n), 0.5)
    return [c * math.exp(-i / (RATE * 0.06)) * 0.9 + math.sin(2 * math.pi * 140 * i / RATE) * math.exp(-i / (RATE * 0.1)) * 0.5
            for i, c in enumerate(crunch)]


def chime():
    """The mall PA's two-tone ding-dong, slightly out of tune."""
    n = int(RATE * 1.4)
    out = []
    for i in range(n):
        t = i / RATE
        f, start = (659.0, 0.0) if t < 0.6 else (523.0 * 0.985, 0.6)
        local = t - start
        tone = math.sin(2 * math.pi * f * local) + 0.3 * math.sin(2 * math.pi * f * 2.01 * local)
        out.append(tone * math.exp(-local / 0.35) * 0.45)
    return out


def wind():
    """A looping blizzard howl."""
    n = int(RATE * 4.0)
    base = lowpass(noise(n), 0.06)
    out = []
    for i, b in enumerate(base):
        t = i / RATE
        swell = 0.6 + 0.4 * math.sin(2 * math.pi * t / 4.0)
        howl = math.sin(2 * math.pi * (180 + 40 * math.sin(2 * math.pi * t / 2.0)) * t) * 0.08
        out.append((b * 2.2 + howl) * swell)
    # Cross-fade the ends so it loops cleanly.
    fade = int(RATE * 0.3)
    for i in range(fade):
        k = i / fade
        out[i] = out[i] * k + out[n - fade + i] * (1 - k)
    return out[: n - fade]


def lullaby():
    """A music-box lullaby, a little off pitch, looping."""
    notes = [0, 4, 7, 4, 0, 4, 7, 12, 11, 7, 5, 2, 0, 0]
    beat = int(RATE * 0.42)
    out = []
    for k, semis in enumerate(notes):
        f = 523.0 * 2 ** (semis / 12) * (0.99 if k % 3 == 0 else 1.0)
        for i in range(beat):
            t = i / RATE
            tone = math.sin(2 * math.pi * f * t) + 0.25 * math.sin(2 * math.pi * f * 3.01 * t)
            out.append(tone * math.exp(-t / 0.25) * 0.35)
    return out


def cough():
    """A dry cough from somewhere in the fog."""
    n = int(RATE * 0.5)
    base = lowpass(noise(n), 0.35)
    out = []
    for i, b in enumerate(base):
        t = i / RATE
        burst = math.exp(-t / 0.05) + 0.7 * math.exp(-max(0.0, t - 0.22) / 0.05) * (t > 0.22)
        out.append(b * burst * 1.2)
    return out


def rumble():
    """Something huge and long tearing down a corridor, looping."""
    n = int(RATE * 2.0)
    base = lowpass(noise(n), 0.03)
    out = []
    for i, b in enumerate(base):
        t = i / RATE
        clack = 0.5 * math.exp(-((t * 6) % 1.0) / 0.08)
        out.append(b * 3.0 * (0.7 + clack) + math.sin(2 * math.pi * 38 * t) * 0.25)
    fade = int(RATE * 0.2)
    for i in range(fade):
        k = i / fade
        out[i] = out[i] * k + out[n - fade + i] * (1 - k)
    return out[: n - fade]


def giggle():
    """A child's laugh, pitched oddly, from far off."""
    n = int(RATE * 0.9)
    out = []
    for i in range(n):
        t = i / RATE
        pulse = max(0.0, math.sin(2 * math.pi * 7 * t)) ** 2
        f = 700 + 120 * math.sin(2 * math.pi * 3 * t)
        out.append(math.sin(2 * math.pi * f * t) * pulse * env(i, n, 0.05, 0.4) * 0.45)
    return out


def static():
    """Radio static with a detuned tuning-fork whine."""
    n = int(RATE * 0.8)
    out = []
    for i, b in enumerate(noise(n)):
        t = i / RATE
        out.append((b * 0.3 + math.sin(2 * math.pi * 441.5 * t) * 0.3) * env(i, n, 0.02, 0.3))
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("thump", thump), ("hiss", hiss), ("whistle", whistle), ("step", step),
                     ("pickup", pickup), ("clank", clank), ("tink", tink), ("drone", drone),
                     ("heartbeat", heartbeat), ("death", death), ("creak", creak),
                     ("flutter", flutter), ("screech", screech), ("tick", tick), ("bite", bite),
                     ("chime", chime), ("wind", wind),
                     ("lullaby", lullaby), ("cough", cough), ("rumble", rumble), ("giggle", giggle),
                     ("static", static)]:
        write(name, fn())
    print("sounds written to", os.path.abspath(OUT))
