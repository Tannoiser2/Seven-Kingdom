#!/usr/bin/env python3
"""Prepara le immagini del gioco a partire dalla cartella originale di Seven Kingdom.

Uso: python3 tools/prepara_asset.py "<cartella Seven Kingdom>"
Scrive in assets/ i file .webp ritagliati e ridimensionati per la versione digitale.
"""
import sys, os
import numpy as np
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else "/mnt/user-data/uploads/Ludoteca/Seven Kingdom"
ILL = os.path.join(SRC, "Seven_Kingdom_Tutte_Le_Illustrazioni")
OBJ = os.path.join(SRC, "Seven_Kingdom_27_Obiettivi_Illustrati_v02")
DST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")


def out(sub, name):
    d = os.path.join(DST, sub)
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, name)


def save(im, path, size=None, q=88, lossless=False):
    if size:
        im = im.copy()
        im.thumbnail(size, Image.LANCZOS)
    im.save(path, "WEBP", quality=q, method=6, lossless=lossless)


def crop_alpha(im, pad=4):
    a = im.getchannel("A").point(lambda v: 255 if v > 24 else 0)
    bb = a.getbbox()
    if not bb:
        return im
    x0, y0, x1, y1 = bb
    return im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad)))


def hex_alpha(im):
    """Rende trasparente il fondo bianco attorno all'esagono (le parti bianche che toccano il bordo)."""
    from scipy import ndimage
    a = np.asarray(im.convert("RGB")).astype(int)
    white = (a.min(axis=2) > 236)
    lab, n = ndimage.label(white)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    bg = ndimage.binary_dilation(bg, iterations=2)
    alpha = np.where(bg, 0, 255).astype(np.uint8)
    alpha = np.asarray(Image.fromarray(alpha).filter(__import__("PIL.ImageFilter", fromlist=["x"]).GaussianBlur(1.2)))
    out_im = im.copy()
    out_im.putalpha(Image.fromarray(alpha))
    return out_im


def grid(im, cols, rows):
    """Ritagli di una tavola a griglia regolare (con trasparenza)."""
    W, H = im.size
    res = []
    for r in range(rows):
        for c in range(cols):
            cell = im.crop((c * W // cols, r * H // rows, (c + 1) * W // cols, (r + 1) * H // rows))
            res.append(crop_alpha(cell))
    return res


def split_white(im, n_cols, n_rows, thr=245):
    """Divide una tavola di carte su fondo bianco cercando le strisce bianche fra le carte."""
    a = np.asarray(im.convert("L")).astype(int)
    def bands(profile, n):
        # profilo: frazione di pixel non bianchi per riga/colonna
        on = profile > 0.15
        segs = []
        start = None
        for i, v in enumerate(on):
            if v and start is None:
                start = i
            if not v and start is not None:
                segs.append((start, i))
                start = None
        if start is not None:
            segs.append((start, len(on)))
        segs = sorted(segs, key=lambda s: s[1] - s[0], reverse=True)[:n]
        return sorted(segs)
    cols = bands((a < thr).mean(axis=0), n_cols)
    rows = bands((a < thr).mean(axis=1), n_rows)
    res = []
    for (y0, y1) in rows:
        for (x0, x1) in cols:
            res.append(im.crop((x0, y0, x1, y1)))
    return res


def pdf_images(pdf):
    """Immagini incorporate in un PDF, nell'ordine (senza i duplicati della stessa immagine)."""
    import subprocess, tempfile, glob, hashlib
    d = tempfile.mkdtemp()
    subprocess.run(["pdfimages", "-png", pdf, os.path.join(d, "i")], check=True)
    out, seen = [], set()
    for f in sorted(glob.glob(os.path.join(d, "i-*.png"))):
        h = hashlib.md5(open(f, "rb").read()).hexdigest()
        if h not in seen:
            seen.add(h)
            out.append(Image.open(f).convert("RGB"))
    return out


def white_alpha(im, thr=238):
    """Toglie il fondo bianco che tocca il bordo dell'immagine."""
    from scipy import ndimage
    a = np.asarray(im.convert("RGB")).astype(int)
    white = a.min(axis=2) > thr
    lab, n = ndimage.label(white)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = ndimage.binary_dilation(np.isin(lab, list(edge)), iterations=1)
    o = im.convert("RGBA")
    o.putalpha(Image.fromarray(np.where(bg, 0, 255).astype(np.uint8)))
    return crop_alpha(o, 0)


V03_REGNI = "Seven_Kingdom_7_Regni_Illustrati_A4_v03.pdf"
V03_PORTI = "Seven_Kingdom_4_Porti_A4_v03.pdf"
V03_PATTI = "Seven_Kingdom_16_Patti_A4_v03.pdf"


def main():
    # tessere dei regni
    names = {"01_Capitale_9_siti": "capitale", "02_Regno_Boschivo_7_siti": "boschivo", "03_Regno_Fluviale_7_siti": "fluviale",
             "04_Regno_Montano_6_siti": "montano", "05_Regno_Autunnale_6_siti": "autunnale", "06_Regno_Collinare_5_siti": "collinare",
             "07_Regno_Palustre_5_siti": "palustre"}
    if os.path.exists(os.path.join(SRC, V03_REGNI)):
        # grafica v0.3: un'immagine per regno, nell'ordine Capitale, Boschivo, Fluviale, Montano, Autunnale, Collinare, Palustre
        for im, n in zip(pdf_images(os.path.join(SRC, V03_REGNI)), list(names.values())):
            save(hex_alpha(im.convert("RGBA")), out("tiles", n + ".webp"), q=86)
    else:
        for f, n in names.items():
            im = Image.open(os.path.join(ILL, "01_Tessere", f + ".png")).convert("RGBA")
            save(hex_alpha(im), out("tiles", n + ".webp"), q=86)
    # tabellone del mare
    im = Image.open(os.path.join(ILL, "02_Tabellone", "Tabellone_Mare_10_Posizioni_Titolo.png")).convert("RGB")
    save(im, out("board", "mare.webp"), q=84)
    # risorse
    im = Image.open(os.path.join(ILL, "03_Componenti", "Cinque_Risorse.png")).convert("RGBA")
    W, H = im.size
    boxes = [(0, 0, W // 3, H // 2), (W // 3, 0, 2 * W // 3, H // 2), (2 * W // 3, 0, W, H // 2), (W // 6, H // 2, W // 2, H), (W // 2, H // 2, 5 * W // 6, H)]
    for b, n in zip(boxes, ["legno", "pietra", "grano", "ferro", "oro"]):
        save(crop_alpha(im.crop(b)), out("res", n + ".webp"), (256, 256))
    # villaggi e vescovi
    im = Image.open(os.path.join(ILL, "03_Componenti", "Quattro_Villaggi_e_Vescovi.png")).convert("RGBA")
    W, H = im.size
    cols = ["rosso", "blu", "verde", "giallo"]
    for i, c in enumerate(cols):
        save(crop_alpha(im.crop((i * W // 4, 0, (i + 1) * W // 4, int(H * 0.44)))), out("tokens", "villaggio_%s.webp" % c), (256, 256))
        save(crop_alpha(im.crop((i * W // 4, int(H * 0.44), (i + 1) * W // 4, H))), out("tokens", "vescovo_%s.webp" % c), (256, 320))
    # segnalini (guerra, pace, accampamento, favore, corona, ricchezza, influenza, invasore)
    im = Image.open(os.path.join(ILL, "481b65ce-bb6f-4427-bc1a-2ad1de83a5fa.png")).convert("RGBA")
    for t, n in zip(grid(im, 4, 2), ["guerra", "pace", "accampamento", "favore", "corona", "ricchezza", "influenza", "invasore"]):
        save(t, out("tokens", n + ".webp"), (256, 256))
    # ponte, porti piccoli, segnalini azione
    im = Image.open(os.path.join(ILL, "0460c43d-485a-4515-a84f-6ac3911928bf.png")).convert("RGBA")
    W, H = im.size
    save(crop_alpha(im.crop((W // 4, 0, 3 * W // 4, int(H * 0.33)))), out("tokens", "ponte.webp"), (256, 256))
    row2 = [crop_alpha(im.crop((i * W // 4, int(H * 0.33), (i + 1) * W // 4, int(H * 0.645)))) for i in range(4)]
    save(row2[0], out("tokens", "porto_I.webp"), (192, 192))
    save(row2[2], out("tokens", "porto_II.webp"), (192, 192))
    for i, c in enumerate(cols):
        save(crop_alpha(im.crop((i * W // 4, int(H * 0.645), (i + 1) * W // 4, H))), out("tokens", "azione_%s.webp" % c), (192, 192))
    # tessere dei porti
    if os.path.exists(os.path.join(SRC, V03_PORTI)):
        im = pdf_images(os.path.join(SRC, V03_PORTI))[0]
        W, H = im.size
        for k, n in enumerate(["alba", "vespro", "rupe", "bruma"]):
            c = im.crop(((k % 2) * W // 2, (k // 2) * H // 2, (k % 2 + 1) * W // 2, (k // 2 + 1) * H // 2))
            save(white_alpha(c), out("tokens", "porto_%s.webp" % n), (420, 300))
    else:
        im = Image.open(os.path.join(ILL, "b32ee478-0d12-4d42-b542-7c04b236fb33.png")).convert("RGBA")
        for t, n in zip(grid(im, 2, 2), ["alba", "vespro", "rupe", "bruma"]):
            save(t, out("tokens", "porto_%s.webp" % n), (420, 300))
    # personaggi: carte italiane e ritratti (dalle illustrazioni delle miniature)
    cards = ["01_Re", "02_Papa", "03_Mercante", "04_Spia", "05_Fanteria", "06_Cavalleria"]
    for c in cards:
        im = Image.open(os.path.join(ILL, "04_Personaggi", "Carte_Italiane", c + ".png")).convert("RGB")
        save(im, out("cards", c.lower() + ".webp"), (600, 900))
    im = Image.open(os.path.join(ILL, "fef4ccb4-77f4-4f33-be78-510b326f058b.png")).convert("RGBA")
    for t, n in zip(grid(im, 3, 2), ["re", "papa", "mercante", "spia", "fanteria", "cavalleria"]):
        save(t, out("chars", n + ".webp"), (320, 320))
    # ritratti a mezzo busto dalle carte (per i pulsanti delle azioni)
    for c, n in zip(cards, ["re", "papa", "mercante", "spia", "fanteria", "cavalleria"]):
        im = Image.open(os.path.join(ILL, "04_Personaggi", "Carte_Italiane", c + ".png")).convert("RGB")
        W, H = im.size
        art = im.crop((int(W * 0.035), int(H * 0.085), int(W * 0.965), int(H * 0.50)))
        save(art, out("chars", n + "_art.webp"), (480, 300))
    # carte obiettivo illustrate (27 fronti)
    k = 1
    for f in ["01_Obiettivi_Illustrati_O01_O09.png", "02_Obiettivi_Illustrati_O10_O18.png", "03_Obiettivi_Illustrati_O19_O27.png"]:
        im = Image.open(os.path.join(OBJ, f)).convert("RGB")
        for c in split_white(im, 3, 3):
            save(c, out("cards/obiettivi", "O%02d.webp" % k), (420, 600))
            k += 1
    # i 16 Patti dei tre regni v0.3 (O12-O27) sostituiscono i territoriali
    if os.path.exists(os.path.join(SRC, V03_PATTI)):
        k = 12
        for im in pdf_images(os.path.join(SRC, V03_PATTI)):
            W, H = im.size
            for j in range(4):
                c = im.crop(((j % 2) * W // 2, (j // 2) * H // 2, (j % 2 + 1) * W // 2, (j // 2 + 1) * H // 2))
                a = np.asarray(c.convert("L"))
                ys, xs = np.where(a < 235)
                c = c.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
                save(c, out("cards/obiettivi", "O%02d.webp" % k), (420, 600))
                k += 1
    print("fatto")


if __name__ == "__main__":
    main()
