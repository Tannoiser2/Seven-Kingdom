#!/usr/bin/env python3
"""Ricava dalle tessere dipinte una mappa delle altezze per la mappa 3D.
Rocce e montagne salgono, boschi un poco, acqua e paludi scendono; i riquadri dei siti, la traccia
Ricchezza, il cerchio del Vescovo, il cartiglio del nome e i bordi restano piatti.
Uso: python3 tools/rilievo.py  (legge assets/tiles/*.webp, scrive assets/tiles/<nome>_h.png)"""
import os, sys, colorsys
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
sys.path.insert(0, os.path.dirname(__file__))
BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
W, H = 336, 293   # un quarto della risoluzione della tessera
SITES = {"capitale": [[671, 585], [506, 367], [764, 366], [1014, 476], [988, 735], [804, 913], [537, 897], [316, 723], [305, 476]], "boschivo": [[670, 584], [505, 361], [805, 362], [1021, 550], [913, 795], [616, 899], [313, 717]], "fluviale": [[682, 596], [490, 384], [790, 384], [1005, 580], [870, 860], [578, 906], [322, 740]], "montano": [[672, 592], [494, 375], [847, 375], [1012, 681], [673, 892], [330, 680]], "autunnale": [[672, 580], [506, 373], [834, 373], [992, 580], [666, 889], [325, 729]], "collinare": [[677, 603], [509, 376], [837, 375], [857, 865], [464, 865]], "palustre": [[670, 609], [448, 378], [894, 378], [893, 861], [447, 861]]}
BISHOP = {"capitale": [484, 647], "boschivo": [473, 613], "fluviale": [474, 628], "montano": [492, 649], "autunnale": [487, 642], "collinare": [481, 642], "palustre": [428, 623]}
for name, sites in SITES.items():
    im = Image.open(os.path.join(BASE, "assets/tiles", name + ".webp")).convert("RGB").resize((W, H), Image.LANCZOS)
    a = np.asarray(im).astype(float) / 255.0
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = a.max(-1); mn = a.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    val = mx
    h = np.zeros((H, W))
    rock = (sat < 0.18) & (val > 0.45)
    h += rock * (0.6 + 0.6 * val)
    forest = (g > r * 0.95) & (g > b * 1.15) & (val < 0.55)
    h += forest * 0.35
    water = (b > r * 1.15) & (b > g * 0.9) & (sat > 0.2)
    h -= water * 0.45
    autumn = (r > g * 1.25) & (r > 0.45) & (sat > 0.35) & (val < 0.85)
    h += autumn * 0.3
    h = ndimage.gaussian_filter(h, 3.4)
    h += ndimage.gaussian_filter(np.random.RandomState(3).rand(H, W), 6) * 0.15
    # maschera: piatto dove ci sono elementi di gioco e ai bordi dell'esagono
    yy, xx = np.mgrid[0:H, 0:W]
    sx, sy = W / 1342.0, H / 1172.0
    mask = np.ones((H, W))
    def flat_rect(cx, cy, hw, hh):
        d = np.maximum(np.abs(xx - cx * sx) - hw * sx, np.abs(yy - cy * sy) - hh * sy)
        m = np.clip(d / (28 * sx), 0, 1)
        return m
    for (x, y) in sites:
        mask = np.minimum(mask, flat_rect(x, y, 75, 75))
    bx, by = BISHOP[name]
    mask = np.minimum(mask, flat_rect(bx, by, 65, 70))
    mask = np.minimum(mask, flat_rect(670, 172, 250, 75))   # Ricchezza
    mask = np.minimum(mask, flat_rect(671, 55, 150, 45))    # cartiglio del nome
    # bordo dell'esagono (lato in alto): distanza dal contorno
    cx, cy = W / 2, H / 2
    R = W / 2.0
    px, py = (xx - cx) / R, (yy - cy) / R
    k = np.sqrt(3) / 2
    d = np.maximum(np.abs(py) / k, (np.abs(px) * k + np.abs(py) * 0.5) / k)
    edge = np.clip((0.95 - d) / 0.1, 0, 1)
    mask = mask * edge
    h = h * mask
    h = np.clip(h, -0.5, 1.2)
    out = ((h + 0.5) / 1.7 * 255).astype(np.uint8)
    Image.fromarray(out, "L").filter(ImageFilter.GaussianBlur(0.8)).save(os.path.join(BASE, "assets/tiles", name + "_h.png"))
    print(name, round(float(h.min()), 2), round(float(h.max()), 2))
