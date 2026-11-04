#!/usr/bin/env python3
"""Animiert ~/Bilder/wallpaper.png zu einer nahtlosen Schleife (lokal, ohne KI-Dienst).

Effekte, alle periodisch in T, damit das letzte Bild nahtlos ins erste übergeht:
  · Hitzeflimmern: Verschiebungsfeld nur auf den Flammen und Energiespritzern
  · Flackern: Helligkeitswellen, die durch die Flammen nach oben laufen
  · Glühen: weicher Lichthof um die Faust, pulsiert langsam
  · Glut: Funken steigen aus dem Flammenwirbel auf, dazu kühle Partikel rechts
Gesicht, Haare und Oberkörper bleiben unbewegt (Schutzzone).

Aufruf:
  render.py --preview            ein paar Standbilder in halber Auflösung (zum Prüfen)
  render.py --fps 55             ganze Schleife → loop-55.mp4 (2560×1440, HEVC 10 bit)

Bildrate: Der Monitor läuft mit 165 Hz. Ideal sind Teiler davon (33, 55, 165), dann steht
jedes Videobild gleich viele Refreshes lang. 30 fps ergibt 5,5 → abwechselnd 5/6 → Judder.
Das Wallpaper-Skript spielt loop.mp4 ab, ein Symlink auf die gewählte Variante.
"""
import argparse
import os
import subprocess
import sys
from functools import partial
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import gaussian_filter, map_coordinates

SRC = os.path.expanduser("~/Bilder/wallpaper.png")
DIR = os.path.dirname(os.path.abspath(__file__))
W, H = 2560, 1440
FPS = 55
T = 10.0                   # Schleifenlänge in Sekunden
SHIMMER_PX = 3.2           # maximale Verschiebung des Hitzeflimmerns
FLICKER = 0.10             # Helligkeitsschwankung in den Flammen
GLOW_CENTER = (660, 580)   # Energie in der Faust
GLOW_RADIUS = 300

G = {}  # pro Prozess: vorberechnete Daten


def cover(img, w, h):
    s = max(w / img.width, h / img.height)
    img = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
    left, top = (img.width - w) // 2, (img.height - h) // 2
    return img.crop((left, top, left + w, top + h))


def soft_ellipse(xx, yy, cx, cy, rx, ry, feather):
    d = np.sqrt(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2)
    return np.clip((1 + feather - d) / feather, 0, 1)


def setup(scale):
    w, h = round(W * scale), round(H * scale)
    img = cover(Image.open(SRC).convert("RGB"), W, H).resize((w, h), Image.LANCZOS)
    base = np.asarray(img).astype(np.float32) / 255
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32) / scale  # Koordinaten im 2560er-Raum

    hsv = np.asarray(img.convert("HSV")).astype(np.float32) / 255
    hue, sat, val = hsv[..., 0] * 360, hsv[..., 1], hsv[..., 2]
    warm = ((hue < 28) | (hue > 335)) & (sat > 0.30) & (val > 0.35)
    cool = (((hue > 185) & (hue < 235) & (sat > 0.15)) | (sat < 0.12)) & (val > 0.62) & (xx > 1900)

    # Schutzzone: Kopf, Haare, Oberkörper. Weich auslaufend, damit keine Kante sichtbar wird.
    protect = np.maximum.reduce([
        soft_ellipse(xx, yy, 1520, 380, 420, 480, 0.35),   # Kopf + Haare
        soft_ellipse(xx, yy, 1560, 980, 520, 420, 0.30),   # Oberkörper
        soft_ellipse(xx, yy, 1080, 600, 200, 200, 0.40),   # Ansatz des Arms
    ])
    zone_warm = gaussian_filter(warm.astype(np.float32), 5 * scale) * (1 - protect)
    zone_cool = gaussian_filter(cool.astype(np.float32), 5 * scale) * (1 - protect) * 0.7
    G.update(scale=scale, w=w, h=h, base=base, xx=xx, yy=yy,
             warm=np.clip(zone_warm * 1.6, 0, 1), cool=np.clip(zone_cool * 1.6, 0, 1),
             motion=np.clip((zone_warm + zone_cool) * 1.6, 0, 1))

    # Partikel: fester Seed, damit jeder Prozess dieselben hat
    rng = np.random.default_rng(7)
    wy, wx = np.nonzero(warm & (xx < 1050) & (yy > 120))
    pick = rng.choice(len(wx), 170)
    embers = dict(
        x0=wx[pick] / scale, y0=wy[pick] / scale,
        vx=rng.uniform(20, 120, 170), vy=-rng.uniform(140, 320, 170),   # nach oben, leicht rechts
        cycles=rng.integers(1, 3, 170), off=rng.random(170),
        size=rng.uniform(1.4, 3.4, 170), warmth=rng.random(170), sway=rng.uniform(4, 14, 170),
    )
    cy_, cx_ = np.nonzero(cool)
    pick = rng.choice(len(cx_), 60)
    specks = dict(
        x0=cx_[pick] / scale, y0=cy_[pick] / scale,
        vx=-rng.uniform(30, 110, 60), vy=-rng.uniform(20, 80, 60),       # nach links oben
        cycles=np.ones(60, int), off=rng.random(60),
        size=rng.uniform(1.0, 2.2, 60), warmth=np.zeros(60), sway=rng.uniform(3, 8, 60),
    )
    G.update(embers=embers, specks=specks)


def particles(layer, p, t, warm_rgb, cool_rgb, alpha_max):
    s, w, h = G["scale"], G["w"], G["h"]
    ph = (t / T * p["cycles"] + p["off"]) % 1.0                 # 0..1, periodisch in T
    x = (p["x0"] + p["vx"] * ph + p["sway"] * np.sin(2 * np.pi * (2 * ph + p["off"]))) * s
    y = (p["y0"] + p["vy"] * ph) * s
    a = alpha_max * np.sin(np.pi * ph) ** 1.5                    # ein- und ausblenden
    for i in range(len(x)):
        r = p["size"][i] * s
        rad = int(np.ceil(r * 3))
        xi, yi = int(x[i]), int(y[i])
        x0, x1, y0, y1 = max(xi - rad, 0), min(xi + rad + 1, w), max(yi - rad, 0), min(yi + rad + 1, h)
        if x0 >= x1 or y0 >= y1:
            continue
        gy, gx = np.mgrid[y0:y1, x0:x1]
        blob = np.exp(-((gx - x[i]) ** 2 + (gy - y[i]) ** 2) / (2 * r * r)) * a[i]
        col = warm_rgb * p["warmth"][i] + cool_rgb * (1 - p["warmth"][i])
        layer[y0:y1, x0:x1] += blob[..., None] * col


def frame(i, fps):
    t = i / fps
    ph = 2 * np.pi * t / T
    xx, yy, base, m = G["xx"], G["yy"], G["base"], G["motion"]
    s = G["scale"]

    # Hitzeflimmern: Wellen, die nach oben wandern (ganzzahlige Zyklen pro Schleife)
    dx = (0.6 * np.sin(0.045 * yy + 0.020 * xx - 2 * ph)
          + 0.4 * np.sin(0.083 * yy + 0.031 * xx - 3 * ph + 1.3))
    dy = 0.5 * np.sin(0.050 * xx + 0.040 * yy - 2 * ph + 2.1)
    amp = SHIMMER_PX * s * m
    coords = [np.arange(G["h"])[:, None] + dy * amp, np.arange(G["w"])[None, :] + dx * amp]
    out = np.stack([map_coordinates(base[..., c], coords, order=1, mode="reflect") for c in range(3)], -1)

    # Flackern: Helligkeitswellen durch die warmen Flammen
    flick = (0.6 * np.sin(0.012 * xx + 0.020 * yy - 2 * ph)
             + 0.4 * np.sin(0.030 * yy - 3 * ph + 0.7))
    out *= (1 + FLICKER * G["warm"] * flick)[..., None]

    # Glühen um die Faust (Screen-Blend)
    gx, gy = GLOW_CENTER
    glow = np.exp(-((xx - gx) ** 2 + (yy - gy) ** 2) / (2 * GLOW_RADIUS ** 2))
    glow *= 0.10 + 0.05 * np.sin(2 * ph)
    light = glow[..., None] * np.array([1.0, 0.62, 0.52], np.float32)

    # Partikel
    add = np.zeros_like(out)
    particles(add, G["embers"], t, np.array([1.0, 0.86, 0.74]), np.array([0.96, 0.52, 0.44]), 0.85)
    particles(add, G["specks"], t, np.zeros(3), np.array([0.85, 0.92, 1.0]), 0.55)
    light += add

    out = 1 - (1 - np.clip(out, 0, 1)) * (1 - np.clip(light, 0, 1))  # Screen
    return (np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", action="store_true")
    ap.add_argument("--fps", type=int, default=FPS)
    args = ap.parse_args()
    fps = args.fps
    frames = int(T * fps)
    assert frames == T * fps, "T × fps muss ganzzahlig sein, sonst ist die Schleife nicht nahtlos"
    out = os.path.join(DIR, f"loop-{fps}.mp4")

    if args.preview:
        setup(0.5)
        Image.fromarray((G["motion"] * 255).astype(np.uint8)).save(os.path.join(DIR, "preview-motion.png"))
        for i in (0, frames // 4, frames // 2):
            Image.fromarray(frame(i, fps)).save(os.path.join(DIR, f"preview-{i:03d}.png"))
        # Schleifentest: Bild `frames` muss Bild 0 gleichen
        diff = np.abs(frame(frames, fps).astype(int) - frame(0, fps).astype(int)).max()
        print("Schleife nahtlos:", diff <= 1, f"(max. Abweichung {diff})")
        return

    enc = subprocess.Popen([
        "ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
        "-s", f"{W}x{H}", "-r", str(fps), "-i", "-",
        "-c:v", "libx265", "-preset", "slow", "-crf", "16", "-pix_fmt", "yuv420p10le",
        "-x265-params", f"log-level=error:keyint={2 * fps}", "-tag:v", "hvc1", "-movflags", "+faststart", out,
    ], stdin=subprocess.PIPE)
    with Pool(os.cpu_count(), initializer=setup, initargs=(1.0,)) as pool:
        for n, f in enumerate(pool.imap(partial(frame, fps=fps), range(frames), chunksize=2), 1):
            enc.stdin.write(f.tobytes())
            if n % fps == 0:
                print(f"{n}/{frames}", file=sys.stderr, flush=True)
    enc.stdin.close()
    sys.exit(enc.wait())


if __name__ == "__main__":
    main()
