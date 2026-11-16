#!/usr/bin/env python3
"""Draws Jigwave's own logo, app icons and store graphics (100% original).

    python3 -I tools/make_art.py

The mark is four jigsaw pieces (coral, mint, gold, sky) locking together,
with the top-right piece lifted as if it is being placed — the "bloom" of
a picture coming together. Pieces use the same tab curve as the game.

Writes:
    icon.png                               192x192 launcher icon (also Godot's)
    assets/images/logo.png                 1200x420 logo (home screen, splash)
    assets/images/store_icon.png           512x512 Google Play icon
    assets/images/icon_foreground.png      432x432 adaptive icon foreground
    assets/images/icon_background.png      432x432 adaptive icon background
    assets/images/feature_graphic.png      1024x500 Google Play feature graphic
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
IMG = ROOT / "assets" / "images"
FONT = ROOT / "assets" / "fonts" / "Fredoka.ttf"

# Jigwave's warm, light identity (same colors as ui/ui_kit.gd).
BG_TOP = (255, 247, 238)  # cream paper
BG_BOTTOM = (251, 225, 204)  # warm peach
INK = (46, 58, 75)
CORAL = (255, 122, 89)
MINT = (34, 181, 165)  # teal
GOLD = (255, 190, 60)
SKY = (106, 169, 255)
SHADOW = (115, 72, 30)
SS = 4  # supersampling for smooth edges


# --- jigsaw geometry (same curve as logic/jigsaw_cut.gd) ----------------------

def bezier(p0, p1, p2, p3, t):
    u = 1 - t
    return (u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
            u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1])


def edge(a, b, side, flip, cell, steps=12):
    """Tabbed edge from a to b; side = unit vector of a positive bulge."""
    t = 0.1
    ctrl = [(0, 0), (0.2, 0), (0.5, -t), (0.5 - t, t), (0.5 - 2 * t, 3 * t), (0.5 + 2 * t, 3 * t),
            (0.5 + t, t), (0.5, -t), (0.8, 0), (1, 0)]
    ax, ay = b[0] - a[0], b[1] - a[1]
    world = [(a[0] + ax * c[0] + side[0] * c[1] * flip * cell,
              a[1] + ay * c[0] + side[1] * c[1] * flip * cell) for c in ctrl]
    pts = [world[0]]
    for s in range(3):
        p0, p1, p2, p3 = world[s * 3:s * 3 + 4]
        for i in range(1, steps + 1):
            pts.append(bezier(p0, p1, p2, p3, i / steps))
    return pts


def piece(x, y, cell, top=0, right=0, bottom=0, left=0):
    """Outline of one piece at (x, y). Each side: 0 flat, +1 tab out, -1 blank in."""
    tl, tr, br, bl = (x, y), (x + cell, y), (x + cell, y + cell), (x, y + cell)
    pts = []
    pts += edge(tl, tr, (0, -1), top, cell)[:-1] if top else [tl]
    pts += edge(tr, br, (1, 0), right, cell)[:-1] if right else [tr]
    pts += edge(br, bl, (0, 1), bottom, cell)[:-1] if bottom else [br]
    pts += edge(bl, tl, (-1, 0), left, cell)[:-1] if left else [bl]
    return pts


def rotate(pts, center, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(center[0] + (px - center[0]) * c - (py - center[1]) * s,
             center[1] + (px - center[0]) * s + (py - center[1]) * c) for px, py in pts]


def shade(color, k):
    return tuple(max(0, min(255, int(v * k))) for v in color)


def gradient(size, top, bottom):
    w, h = size
    img = Image.new("RGBA", size)
    d = ImageDraw.Draw(img)
    for yy in range(h):
        k = yy / max(1, h - 1)
        d.line([(0, yy), (w, yy)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(3)) + (255,))
    return img


def draw_piece(base, pts, color, shadow=True, lift=0.0):
    """Colored piece with a soft shadow, bottom edge and highlight."""
    w, h = base.size
    if shadow:
        sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
        off = 10 * SS + lift
        ImageDraw.Draw(sh).polygon([(px + off * 0.4, py + off) for px, py in pts], fill=SHADOW + (80,))
        base.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8 * SS + lift * 0.3)))
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.polygon([(px, py + 5 * SS) for px, py in pts], fill=shade(color, 0.7) + (255,))  # 3D edge
    d.polygon(pts, fill=color + (255,))
    # Highlight: same shape, lighter, clipped to the upper part.
    hl = Image.new("RGBA", base.size, (0, 0, 0, 0))
    ImageDraw.Draw(hl).polygon(pts, fill=(255, 255, 255, 70))
    ys = [p[1] for p in pts]
    cut = min(ys) + (max(ys) - min(ys)) * 0.42
    mask = Image.new("L", base.size, 0)
    ImageDraw.Draw(mask).rectangle([0, 0, w, cut], fill=255)
    layer.alpha_composite(Image.composite(hl, Image.new("RGBA", base.size, (0, 0, 0, 0)), mask))
    base.alpha_composite(layer)


def sparkle(base, cx, cy, r, color=(255, 255, 255)):
    d = ImageDraw.Draw(base)
    pts = []
    for k in range(8):
        a = -math.pi / 2 + k * math.pi / 4
        rr = r if k % 2 == 0 else r * 0.28
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=color + (255,))


def mark(size, lifted=True):
    """The four-piece logo mark on a transparent square (supersampled)."""
    S = size * SS
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cell = S * 0.30
    ox = (S - 2 * cell) / 2
    oy = (S - 2 * cell) / 2 + S * 0.03
    # 2x2 pieces; matching tabs/blanks between neighbours.
    tl = piece(ox, oy, cell, right=1, bottom=-1)
    bl = piece(ox, oy + cell, cell, top=1, right=-1)
    br = piece(ox + cell, oy + cell, cell, top=1, left=1)
    tr = piece(ox + cell, oy, cell, left=-1, bottom=-1)
    draw_piece(img, bl, SKY)
    draw_piece(img, br, GOLD)
    draw_piece(img, tl, CORAL)
    if lifted:
        c = (ox + cell * 1.5, oy + cell * 0.5)
        tr = [(px + cell * 0.16, py - cell * 0.2) for px, py in rotate(tr, c, 12)]
        draw_piece(img, tr, MINT, lift=6 * SS)
        sparkle(img, ox + cell * 2.25, oy - cell * 0.05, cell * 0.16, GOLD)
        sparkle(img, ox + cell * 2.45, oy + cell * 0.32, cell * 0.08, CORAL)
    else:
        draw_piece(img, tr, MINT)
    return img


def down(img, size):
    return img.resize(size, Image.Resampling.LANCZOS)


def rounded_bg(size, radius_k=0.22):
    S = size * SS
    bg = gradient((S, S), BG_TOP, BG_BOTTOM)
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * radius_k), fill=255)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(bg, (0, 0), mask)
    return out


def font(px, weight=650):
    f = ImageFont.truetype(str(FONT), px)
    try:
        axes = f.get_variation_axes()
        f.set_variation_by_axes([weight if a.get("name", b"") in (b"Weight", "Weight") else a["default"] for a in axes])
    except Exception:
        pass
    return f


def wordmark(d, x, y, px):
    """'Jig' in ink + 'wave' in coral, with a soft warm shadow."""
    f = font(px)
    parts = [("Jig", INK), ("wave", CORAL)]
    cx = x
    for text, color in parts:
        d.text((cx + px * 0.02, y + px * 0.045), text, font=f, fill=SHADOW + (45,))
        d.text((cx, y), text, font=f, fill=color + (255,))
        cx += d.textlength(text, font=f)
    return cx - x


def main():
    IMG.mkdir(parents=True, exist_ok=True)

    # Store icon 512 and launcher icon 192: rounded background + mark.
    icon = rounded_bg(512)
    icon.alpha_composite(mark(512))
    down(icon, (512, 512)).save(IMG / "store_icon.png")
    down(icon, (192, 192)).save(ROOT / "icon.png")

    # Adaptive icon: mark inside the 66% safe zone; full-bleed background.
    fg = Image.new("RGBA", (432 * SS, 432 * SS), (0, 0, 0, 0))
    m = mark(300)
    fg.alpha_composite(m, ((432 * SS - m.width) // 2, (432 * SS - m.height) // 2))
    down(fg, (432, 432)).save(IMG / "icon_foreground.png")
    down(gradient((432, 432), BG_TOP, BG_BOTTOM), (432, 432)).save(IMG / "icon_background.png")

    # Logo 1200x420 on transparent: mark + wordmark.
    W, H = 1200 * SS, 420 * SS
    logo = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    m = mark(400)
    logo.alpha_composite(m, (0, (H - m.height) // 2))
    d = ImageDraw.Draw(logo)
    # Largest wordmark that fits next to the mark.
    px = 210 * SS
    room = W - 400 * SS - 20 * SS
    while d.textlength("Jigwave", font=font(px)) > room:
        px -= 4 * SS
    wordmark(d, 400 * SS, (H - px * 1.25) // 2, px)
    down(logo, (1200, 420)).save(IMG / "logo.png")

    # Feature graphic: gradient, a few real puzzle pictures as pieces, logo.
    W, H = 1024 * SS, 500 * SS
    fgx = gradient((W, H), BG_TOP, BG_BOTTOM)
    cat = json.loads((ROOT / "assets/puzzles/catalog.json").read_text())
    picks = [c for c in cat if c["category"] in ("nature", "animals", "food", "kids", "space")][:6]
    spots = [(50, 30, -8), (40, 270, 6), (230, 300, -4), (810, 25, 7), (840, 255, -6), (650, 300, 4)]
    cell = 120 * SS
    for (sx, sy, rot), c in zip(spots, picks):
        pic = Image.open(ROOT / "assets/puzzles" / c["category"] / (c["id"] + ".jpg")).convert("RGBA")
        pic = pic.resize((int(cell * 1.7), int(cell * 1.7)))
        pts = piece(cell * 0.35, cell * 0.35, cell, top=1, right=-1, bottom=1, left=-1)
        mask = Image.new("L", pic.size, 0)
        ImageDraw.Draw(mask).polygon(pts, fill=255)
        tile = Image.new("RGBA", pic.size, (0, 0, 0, 0))
        tile.paste(pic, (0, 0), mask)
        ImageDraw.Draw(tile).line(pts + [pts[0]], fill=(255, 255, 255, 220), width=3 * SS)
        tile = tile.rotate(rot, resample=Image.Resampling.BICUBIC, expand=True)
        sh = Image.new("RGBA", tile.size, (0, 0, 0, 0))
        sh.paste(SHADOW + (90,), (0, 0), tile.split()[3])
        fgx.alpha_composite(sh.filter(ImageFilter.GaussianBlur(10 * SS)), (sx * SS + 10 * SS, sy * SS + 16 * SS))
        fgx.alpha_composite(tile, (sx * SS, sy * SS))
    lg = Image.open(IMG / "logo.png").convert("RGBA").resize((660 * SS, 231 * SS), Image.Resampling.LANCZOS)
    fgx.alpha_composite(lg, ((W - lg.width) // 2, (H - lg.height) // 2 - 10 * SS))
    down(fgx, (1024, 500)).convert("RGB").save(IMG / "feature_graphic.png")
    print("art written to", IMG, "and icon.png")


if __name__ == "__main__":
    main()
