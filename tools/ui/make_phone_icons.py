"""Icônes du téléphone (lot UI-02) : PNG blancs 64 et 128 px tracés depuis les chemins SVG de la maquette du propriétaire
(`docs/ui/handoff-v1.2/Smartphone.dc.html`, objet ICON) : grille 24, trait 1,75, extrémités et jonctions arrondies,
sans remplissage. Teinte appliquée dans le jeu par `ImageColor3` (ambre, cyan pour la carte).

    python -I tools/ui/make_phone_icons.py <Smartphone.dc.html> <dossier de sortie>

Rastérisation propre (aucune bibliothèque SVG) : commandes M L H V C S A Z (absolues et relatives), courbes et arcs
découpés en segments, rendu suréchantillonné ×4 puis réduit. Écrit aussi `icons.json` (noms, tailles, SHA-256).
"""
import hashlib
import json
import math
import os
import re
import sys

from PIL import Image, ImageDraw

SRC, OUT = sys.argv[1], sys.argv[2]
os.makedirs(OUT, exist_ok=True)
html = open(SRC, encoding="utf-8").read()
block = re.search(r"const ICON=\{(.*?)\};", html, re.S).group(1)
ICONS = dict(re.findall(r"(\w+):'([^']*)'", block))
assert len(ICONS) == 12, len(ICONS)

TOKEN = re.compile(r"[MmLlHhVvCcSsAaZz]|-?\d*\.?\d+(?:e-?\d+)?")


def arc(x1, y1, rx, ry, phi, fa, fs, x2, y2):
    # Conversion SVG « extrémités » → centre (spécification SVG 1.1, annexe F.6.5).
    if rx == 0 or ry == 0:
        return [(x2, y2)]
    phi = math.radians(phi)
    c, s = math.cos(phi), math.sin(phi)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p, y1p = c * dx + s * dy, -s * dx + c * dy
    rx, ry = abs(rx), abs(ry)
    lam = x1p ** 2 / rx ** 2 + y1p ** 2 / ry ** 2
    if lam > 1:
        rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam)
    num = rx ** 2 * ry ** 2 - rx ** 2 * y1p ** 2 - ry ** 2 * x1p ** 2
    den = rx ** 2 * y1p ** 2 + ry ** 2 * x1p ** 2
    coef = math.sqrt(max(0, num / den)) if den else 0
    if fa == fs:
        coef = -coef
    cxp, cyp = coef * rx * y1p / ry, -coef * ry * x1p / rx
    cx = c * cxp - s * cyp + (x1 + x2) / 2
    cy = s * cxp + c * cyp + (y1 + y2) / 2

    def ang(ux, uy, vx, vy):
        a = math.atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        return a

    t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not fs and dt > 0:
        dt -= 2 * math.pi
    elif fs and dt < 0:
        dt += 2 * math.pi
    n = max(8, int(abs(dt) / (math.pi / 32)))
    pts = []
    for i in range(1, n + 1):
        t = t1 + dt * i / n
        pts.append((cx + rx * math.cos(t) * c - ry * math.sin(t) * s, cy + rx * math.cos(t) * s + ry * math.sin(t) * c))
    return pts


def parse(d):
    toks = TOKEN.findall(d)
    i, cmd = 0, None
    x = y = sx = sy = 0.0
    last_ctrl = None  # second point de contrôle de la dernière courbe (pour S)
    paths, cur = [], []

    def num():
        nonlocal i
        v = float(toks[i])
        i += 1
        return v

    while i < len(toks):
        if re.match(r"[A-Za-z]", toks[i]):
            cmd = toks[i]
            i += 1
            if cmd in "Zz":
                if cur:
                    cur.append((sx, sy))
                    paths.append(cur)
                    cur = []
                x, y = sx, sy
                continue
        rel = cmd.islower()
        C = cmd.upper()
        if C not in "CS":
            last_ctrl = None
        if C == "M":
            nx, ny = num(), num()
            if rel:
                nx, ny = x + nx, y + ny
            if cur:
                paths.append(cur)
            cur = [(nx, ny)]
            x, y, sx, sy = nx, ny, nx, ny
            cmd = "l" if rel else "L"
        elif C == "L":
            nx, ny = num(), num()
            if rel:
                nx, ny = x + nx, y + ny
            cur.append((nx, ny))
            x, y = nx, ny
        elif C == "H":
            nx = num()
            x = x + nx if rel else nx
            cur.append((x, y))
        elif C == "V":
            ny = num()
            y = y + ny if rel else ny
            cur.append((x, y))
        elif C in "CS":
            if C == "C":
                p = [num() for _ in range(6)]
                if rel:
                    p = [p[0] + x, p[1] + y, p[2] + x, p[3] + y, p[4] + x, p[5] + y]
            else:
                q = [num() for _ in range(4)]
                if rel:
                    q = [q[0] + x, q[1] + y, q[2] + x, q[3] + y]
                # Premier point de contrôle : reflet du précédent (ou le point courant).
                c1 = (2 * x - last_ctrl[0], 2 * y - last_ctrl[1]) if last_ctrl else (x, y)
                p = [c1[0], c1[1], q[0], q[1], q[2], q[3]]
            last_ctrl = (p[2], p[3])
            for k in range(1, 17):
                t = k / 16
                a, b, c2, e = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t ** 2, t ** 3
                cur.append((a * x + b * p[0] + c2 * p[2] + e * p[4], a * y + b * p[1] + c2 * p[3] + e * p[5]))
            x, y = p[4], p[5]
            continue
        elif C == "A":
            rx, ry, rot, fa, fs, nx, ny = num(), num(), num(), num(), num(), num(), num()
            if rel:
                nx, ny = x + nx, y + ny
            cur.extend(arc(x, y, rx, ry, rot, int(fa), int(fs), nx, ny))
            x, y = nx, ny
        else:
            raise ValueError("commande non gérée : " + cmd)
    if cur:
        paths.append(cur)
    return paths


def render(d, size):
    ss = 4
    big = size * ss
    k = big / 24
    width = 1.75 * k
    img = Image.new("L", (big, big), 0)
    draw = ImageDraw.Draw(img)
    r = width / 2
    for path in parse(d):
        pts = [(px * k, py * k) for px, py in path]
        if len(pts) > 1:
            draw.line(pts, fill=255, width=max(1, round(width)), joint="curve")
        for px, py in (pts[0], pts[-1]) if pts else []:
            draw.ellipse((px - r, py - r, px + r, py + r), fill=255)
        for px, py in pts[1:-1]:
            draw.ellipse((px - r, py - r, px + r, py + r), fill=255)
    alpha = img.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(alpha)
    return out


manifest = {"source": os.path.basename(SRC), "grid": 24, "stroke": 1.75, "icons": {}}
for name, d in ICONS.items():
    entry = {}
    for size in (64, 128):
        path = os.path.join(OUT, f"{name}_{size}.png")
        render(d, size).save(path)
        entry[str(size)] = {"file": os.path.basename(path), "sha256": hashlib.sha256(open(path, "rb").read()).hexdigest()}
    manifest["icons"][name] = entry
json.dump(manifest, open(os.path.join(OUT, "icons.json"), "w", encoding="utf-8"), indent=2, ensure_ascii=False)
print("ok", len(ICONS), "icônes")
