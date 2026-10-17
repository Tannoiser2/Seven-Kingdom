"""Tessere dei regni v0.4 (Seven_Kingdom_7_Regni_Illustrati_A4_v04.pdf): il dipinto di ogni regno più la
traccia della Ricchezza ingrandita, che nel PDF è un'immagine a parte sovrapposta in alto.
Uso: python3 tools/tessere_v04.py <cartella con il PDF>"""
import os, sys, subprocess, tempfile, glob
from PIL import Image
sys.path.insert(0, os.path.dirname(__file__))
import prepara_asset as P

PDF = "Seven_Kingdom_7_Regni_Illustrati_A4_v04.pdf"
# posizioni nel PDF (punti): tessera e traccia della Ricchezza
TILE = (8.132909, 164.549469, 587.138855, 676.033691)
TRACK = (150.792374, 172.006195, 444.338193, 269.818603)
ORDER = ["capitale", "boschivo", "fluviale", "montano", "autunnale", "collinare", "palustre"]


def main(src):
    pdf = os.path.join(src, PDF)
    d = tempfile.mkdtemp()
    subprocess.run(["pdfimages", "-png", pdf, os.path.join(d, "i")], check=True)
    files = sorted(glob.glob(os.path.join(d, "i-*.png")))
    # per pagina: dipinto, traccia, maschera della traccia
    sx = 1342 / (TILE[2] - TILE[0])
    sy = 1172 / (TILE[3] - TILE[1])
    box = [round((TRACK[0] - TILE[0]) * sx), round((TRACK[1] - TILE[1]) * sy), round((TRACK[2] - TILE[0]) * sx), round((TRACK[3] - TILE[1]) * sy)]
    for k, t in enumerate(ORDER):
        tile = Image.open(files[3 * k]).convert("RGBA")
        tr = Image.open(files[3 * k + 1]).convert("RGBA")
        tr.putalpha(Image.open(files[3 * k + 2]).convert("L"))
        tr = tr.resize((box[2] - box[0], box[3] - box[1]), Image.LANCZOS)
        tile.alpha_composite(tr, (box[0], box[1]))
        P.save(P.hex_alpha(tile), P.out("tiles", t + ".webp"), q=86)


if __name__ == "__main__":
    main(sys.argv[1])
