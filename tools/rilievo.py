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
SITES = {
 "capitale": [[675, 606], [470, 388], [738, 320], [1014, 458], [956, 724], [817, 886], [548, 861], [331, 715], [308, 465]],
 "boschivo": [[672, 594], [454, 352], [896, 352], [1092, 602], [852, 848], [513, 848], [239, 602]],
 "fluviale": [[672, 596], [456, 352], [896, 352], [1092, 602], [852, 848], [513, 848], [239, 602]],
 "montano": [[672, 569], [422, 374], [954, 374], [940, 774], [672, 894], [398, 773]],
 "autunnale": [[672, 570], [422, 374], [952, 374], [941, 774], [672, 894], [398, 774]],
 "collinare": [[670, 614], [378, 426], [988, 426], [953, 834], [430, 834]],
 "palustre": [[670, 614], [378, 426], [988, 426], [954, 834], [430, 835]],
}
BISHOP = {"capitale": [472, 658], "boschivo": [432, 689], "fluviale": [432, 689], "montano": [458, 634], "autunnale": [458, 640], "collinare": [390, 662], "palustre": [390, 662]}
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
        mask = np.minimum(mask, flat_rect(x, y, 70, 70))
    bx, by = BISHOP[name]
    mask = np.minimum(mask, flat_rect(bx, by, 60, 60))
    mask = np.minimum(mask, flat_rect(668, 194, 260, 70))   # Ricchezza
    mask = np.minimum(mask, flat_rect(671, 1040, 230, 45))  # cartiglio del nome
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
