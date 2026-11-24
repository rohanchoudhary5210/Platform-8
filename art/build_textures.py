"""Generates Platform 8's tileable surface textures in Blender and saves them as PNG.

Run (from the project folder):
  "C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" --background --factory-startup --python art/build_textures.py

Each texture covers 1.2 m x 1.2 m of surface; Station.gd maps them world-space (triplanar), so any box gets tiles.
Outputs game/assets/textures/{wall_tile,floor_tile,ceiling,concrete}.png
"""
import os

import bpy
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
N = 512  # pixels per 1.2 m
rng = np.random.default_rng(8)


def smooth_noise(cells, amp):
    """Tileable value noise: random grid, bilinear upsampled with wrap-around."""
    g = rng.random((cells, cells))
    x = np.arange(N) * cells / N
    i0 = np.floor(x).astype(int)
    f = x - i0
    i1 = (i0 + 1) % cells
    a = g[i0][:, i0] * (1 - f)[None, :] + g[i0][:, i1] * f[None, :]
    b = g[i1][:, i0] * (1 - f)[None, :] + g[i1][:, i1] * f[None, :]
    return ((a * (1 - f)[:, None] + b * f[:, None]) - 0.5) * 2 * amp


def tiles(cols, rows, grout_px, base, grout, tint_amp, speckle=0.0, grime=0.0):
    img = np.zeros((N, N, 3))
    img[:] = base
    tw, th = N // cols, N // rows
    for r in range(rows):
        for c in range(cols):
            img[r * th:(r + 1) * th, c * tw:(c + 1) * tw] *= 1 + rng.uniform(-tint_amp, tint_amp)
    if speckle:
        img *= (1 + rng.uniform(-speckle, speckle, (N, N)))[..., None]
        dots = rng.random((N, N)) < 0.02
        img[dots] *= 0.55
    if grime:
        img *= (1 + smooth_noise(8, grime))[..., None]
    y, x = np.mgrid[0:N, 0:N]
    gmask = ((x % tw) < grout_px) | ((y % th) < grout_px)
    img[gmask] = grout
    return img


def slats(count, gap_px, base, gap):
    img = np.zeros((N, N, 3))
    img[:] = base
    x = np.arange(N)
    img[:, (x % (N // count)) < gap_px] = gap
    img *= (1 + smooth_noise(6, 0.08))[..., None]
    return img


def concrete(base):
    img = np.zeros((N, N, 3))
    img[:] = base
    img *= (1 + smooth_noise(16, 0.18) + rng.uniform(-0.06, 0.06, (N, N)))[..., None]
    return img


def save(name, img):
    img = np.clip(img, 0, 1)
    rgba = np.concatenate([img, np.ones((N, N, 1))], axis=2)
    im = bpy.data.images.new(name, N, N, alpha=False)
    im.pixels = np.flipud(rgba).ravel().astype(np.float32)  # Blender pixels start bottom-left
    im.filepath_raw = os.path.join(OUT, name + ".png")
    im.file_format = "PNG"
    im.save()


bpy.ops.wm.read_factory_settings(use_empty=True)
# Wall: cream 30 x 60 cm ceramic, 4 rows x 2 columns per 1.2 m, light grout, a little grime.
save("wall_tile", tiles(2, 4, 3, (0.86, 0.84, 0.78), (0.55, 0.55, 0.52), 0.03, grime=0.12))
# Floor: grey granite 60 x 60 cm, speckled, dark grout.
save("floor_tile", tiles(2, 2, 3, (0.55, 0.55, 0.57), (0.22, 0.22, 0.23), 0.05, speckle=0.12, grime=0.08))
# Ceiling: linear metal slats with dark gaps.
save("ceiling", slats(8, 6, (0.7, 0.71, 0.72), (0.08, 0.08, 0.09)))
# Track pit / rough concrete.
save("concrete", concrete((0.32, 0.31, 0.3)))
print("textures written to", OUT)
