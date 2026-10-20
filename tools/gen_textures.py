"""Generate the low-res placeholder textures in textures/.

Run from the repo root: python3 tools/gen_textures.py
Every texture is 64x64 with a small palette so the PS1 look stays consistent.
"""
import os
import random
import struct
import zlib

SIZE = 64
OUT = os.path.join(os.path.dirname(__file__), "..", "textures")


def write_png(path, pixels):
    raw = b"".join(b"\x00" + bytes(c for px in row for c in px) for row in pixels)

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def value_noise(rng, cell):
    n = SIZE // cell + 1
    grid = [[rng.random() for _ in range(n)] for _ in range(n)]

    def sample(x, y):
        gx, gy = x / cell, y / cell
        x0, y0 = int(gx), int(gy)
        fx, fy = gx - x0, gy - y0
        x1, y1 = (x0 + 1) % (n - 1), (y0 + 1) % (n - 1)
        a = grid[y0][x0] * (1 - fx) + grid[y0][x1] * fx
        b = grid[y1][x0] * (1 - fx) + grid[y1][x1] * fx
        return a * (1 - fy) + b * fy

    return sample


def shade(color, k):
    return tuple(max(0, min(255, int(c * k))) for c in color)


def quantize(color, levels=16):
    step = 256 // levels
    return tuple((c // step) * step for c in color)


def make(name, fn, seed):
    rng = random.Random(seed)
    pixels = [[quantize(fn(rng, x, y)) for x in range(SIZE)] for y in range(SIZE)]
    write_png(os.path.join(OUT, name + ".png"), pixels)


def concrete():
    state = {}

    def fn(rng, x, y):
        if "n" not in state:
            state["n"] = value_noise(rng, 8)
            state["m"] = value_noise(rng, 32)
        k = 0.55 + 0.25 * state["n"](x, y) + 0.2 * state["m"](x, y) + rng.uniform(-0.05, 0.05)
        return shade((120, 116, 108), k)

    return fn


def brick():
    state = {}

    def fn(rng, x, y):
        if "n" not in state:
            state["n"] = value_noise(rng, 4)
            state["tone"] = {}
        row = y // 8
        offset = 8 if row % 2 else 0
        col = (x + offset) // 16
        if y % 8 == 0 or (x + offset) % 16 == 0:
            return shade((60, 52, 46), 0.8 + 0.2 * state["n"](x, y))
        tone = state["tone"].setdefault((row, col % 4), rng.uniform(0.7, 1.05))
        return shade((118, 52, 38), tone * (0.8 + 0.3 * state["n"](x, y)))

    return fn


def rust_metal():
    state = {}

    def fn(rng, x, y):
        if "n" not in state:
            state["n"] = value_noise(rng, 8)
            state["r"] = value_noise(rng, 16)
        rust = state["r"](x, y)
        base = (88, 84, 80) if rust < 0.5 else (122, 66, 34)
        k = 0.7 + 0.35 * state["n"](x, y)
        if x % 32 in (0, 31) or y % 32 in (0, 31):
            k *= 0.55
        if (x % 32, y % 32) in ((3, 3), (28, 3), (3, 28), (28, 28)):
            k = 1.3
        return shade(base, k)

    return fn


def grate():
    def fn(rng, x, y):
        bar = x % 8 < 2 or y % 8 < 2
        if bar:
            return shade((96, 92, 86), rng.uniform(0.8, 1.05))
        return (14, 12, 12)

    return fn


def pipe():
    state = {}

    def fn(rng, x, y):
        if "n" not in state:
            state["n"] = value_noise(rng, 8)
        k = 0.65 + 0.3 * state["n"](x, y)
        if y % 32 < 3:
            return shade((70, 64, 58), k)
        return shade((132, 84, 52), k + 0.15 * (1 - abs((x % 64) / 32 - 1)))

    return fn


def brass():
    state = {}

    def fn(rng, x, y):
        if "n" not in state:
            state["n"] = value_noise(rng, 8)
        return shade((184, 146, 70), 0.7 + 0.35 * state["n"](x, y))

    return fn


def tile():
    """Mall floor: cream and teal checker with grimy grout."""
    state = {}

    def fn(rng, x, y):
        if "n" not in state:
            state["n"] = value_noise(rng, 16)
        if x % 16 == 0 or y % 16 == 0:
            return shade((70, 66, 58), 0.9)
        cream = ((x // 16) + (y // 16)) % 2 == 0
        base = (200, 190, 160) if cream else (70, 130, 130)
        return shade(base, 0.7 + 0.3 * state["n"](x, y) + rng.uniform(-0.03, 0.03))

    return fn


def carpet():
    """Shop carpet: 90s confetti pattern on dark purple."""
    def fn(rng, x, y):
        r = rng.random()
        if r < 0.04:
            return (200, 60, 120)
        if r < 0.08:
            return (60, 170, 200)
        if r < 0.1:
            return (220, 200, 60)
        return shade((54, 36, 70), rng.uniform(0.85, 1.1))

    return fn


def panel():
    """Research station: off-white wall panels with rivets and seams."""
    state = {}

    def fn(rng, x, y):
        if "n" not in state:
            state["n"] = value_noise(rng, 16)
        k = 0.75 + 0.2 * state["n"](x, y)
        if x % 32 in (0, 1) or y % 64 in (0, 1):
            k *= 0.6
        if (x % 32, y % 16) in ((4, 4), (27, 4)):
            k = 0.5
        return shade((196, 200, 196), k)

    return fn


def snow():
    state = {}

    def fn(rng, x, y):
        if "n" not in state:
            state["n"] = value_noise(rng, 8)
            state["m"] = value_noise(rng, 32)
        k = 0.82 + 0.1 * state["n"](x, y) + 0.08 * state["m"](x, y) + rng.uniform(-0.02, 0.02)
        return shade((226, 232, 240), k)

    return fn


def wood():
    state = {}

    def fn(rng, x, y):
        if "n" not in state:
            state["n"] = value_noise(rng, 4)
        plank = y // 16
        grain = 0.8 + 0.2 * state["n"]((x * 0.25 + plank * 7) % 63, (y * 2) % 63)
        if y % 16 == 0:
            return shade((60, 40, 26), 0.8)
        return shade((140, 96, 58), grain * (0.9 + 0.1 * (plank % 3)))

    return fn


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    make("concrete", concrete(), 1)
    make("brick", brick(), 2)
    make("rust_metal", rust_metal(), 3)
    make("grate", grate(), 4)
    make("pipe", pipe(), 5)
    make("brass", brass(), 6)
    make("tile", tile(), 7)
    make("carpet", carpet(), 8)
    make("panel", panel(), 9)
    make("snow", snow(), 10)
    make("wood", wood(), 11)
    print("textures written to", os.path.abspath(OUT))
