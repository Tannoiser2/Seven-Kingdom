#!/usr/bin/env python3
"""Compone copertina del menu, splash, icona e copertina della ludoteca dalle immagini del gioco."""
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import math, os, sys
SRC = sys.argv[1] if len(sys.argv) > 1 else "/mnt/user-data/uploads/Ludoteca/Seven Kingdom"
mare = Image.open('assets/board/mare.webp').convert('RGBA')
W, H = 1920, 1080
bg = mare.resize((W, W)).crop((0, (W - H) // 2, W, (W - H) // 2 + H))
bg = ImageEnhance.Brightness(bg).enhance(0.8)
tiles = {3: "montano", 4: "fluviale", 5: "autunnale", 6: "palustre", 7: "boschivo", 8: "capitale", 9: "collinare"}
COL = [0, 0, 0, 1, 1, 1, 1, 2, 2, 2]; ROW = [0, 1, 2, 0, 1, 2, 3, 0, 1, 2]
R = 150
cx, cy = 1230, 545
for p, t in tiles.items():
    c = COL[p]; r = ROW[p]
    x = (c - 1) * 1.5; y = r * math.sqrt(3) + (0 if c == 1 else math.sqrt(3) / 2) - math.sqrt(3) * 1.5
    im = Image.open('assets/tiles/%s.webp' % t).convert('RGBA').resize((int(2 * R * 0.97), int(2 * R * 0.97 * 1172 / 1342)))
    sh = Image.new('RGBA', im.size, (0, 0, 0, 255)); sh.putalpha(im.getchannel('A').point(lambda a: int(a * 0.6)))
    px = int(cx + x * R - im.width / 2); py = int(cy + y * R - im.height / 2)
    bg.alpha_composite(sh.filter(ImageFilter.GaussianBlur(9)), (px + 12, py + 16))
    bg.alpha_composite(im, (px, py))
figs = Image.open(os.path.join(SRC, 'Seven_Kingdom_Tutte_Le_Illustrazioni/fef4ccb4-77f4-4f33-be78-510b326f058b.png')).convert('RGBA')
fw, fh = figs.size
for i, (x, y) in enumerate([(1500, 640), (1640, 650)]):
    f = figs.crop((i * fw // 3, 0, (i + 1) * fw // 3, fh // 2)).resize((360, 360))
    bg.alpha_composite(f, (x, y))
grad = Image.new('L', (W, 1), 0)
for x in range(W):
    grad.putpixel((x, 0), int(max(0, min(255, (1 - (x / 1050)) * 225))))
grad = grad.resize((W, H))
dark = Image.new('RGBA', (W, H), (8, 12, 24, 255)); dark.putalpha(grad)
bg.alpha_composite(dark)
bg.convert('RGB').save('assets/ui/cover.webp', quality=85)
bg.resize((960, 540)).convert('RGB').save('assets/ui/splash.png')
cr = Image.open('assets/tokens/corona.webp').convert('RGBA')
ic = Image.new('RGBA', (256, 256), (20, 34, 61, 255)); d = ImageDraw.Draw(ic); d.rounded_rectangle((4, 4, 252, 252), 40, outline=(217, 172, 79, 255), width=8)
cr.thumbnail((200, 200)); ic.alpha_composite(cr, ((256 - cr.width) // 2, (256 - cr.height) // 2))
ic.save('assets/ui/icon.png')
os.makedirs('ludoteca', exist_ok=True)
bg.crop((640, 0, 1920, 1080)).resize((800, 675)).convert('RGB').save('ludoteca/copertina.webp', quality=82)
