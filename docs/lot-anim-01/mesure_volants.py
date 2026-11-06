"""Lot ANIM-01 : mesure du centre, de l'axe et du rayon de la jante d'un volant (lecture seule, hors Blender).

    python -I docs/lot-anim-01/mesure_volants.py glb <export.glb> <nom de la pièce>
    python -I docs/lot-anim-01/mesure_volants.py releve <relevé.json>

- `glb` : sommets d'une pièce d'un export glTF binaire du dépôt d'art (Brio : `wk_brio_milano95_lod0.glb`,
  `BRIO_Volant`). Les sommets du maillage y sont déjà dans le repère du jeu (le demi-tour de l'export est porté par le
  nœud, pas par les sommets) : contrôlé par le centre de boîte, identique au relevé JSON de l'export.
- `releve` : sommets écrits par `tools/blender/comete_volant_separe.py` (Comète, `volant_anim01.json`).

Méthode : on part d'une normale approchée (analyse en composantes principales), puis on garde les sommets de la jante
(loin de l'axe, proches du plan médian), on ajuste leur plan (normale) et un cercle dans ce plan (moindres carrés),
quatre fois. La normale est orientée vers l'arrière (+Z, vers le conducteur). Nécessite numpy.
"""
import json
import struct
import sys

import numpy as np


def glb_vertices(path, name):
    data = open(path, "rb").read()
    _, _, total = struct.unpack_from("<III", data, 0)
    offset, chunks = 12, {}
    while offset < total:
        length, kind = struct.unpack_from("<II", data, offset)
        chunks[kind] = data[offset + 8 : offset + 8 + length]
        offset += 8 + length
    gltf, binary = json.loads(chunks[0x4E4F534A]), chunks[0x004E4942]
    for node in gltf["nodes"]:
        if node.get("name") == name and "mesh" in node:
            points = []
            for primitive in gltf["meshes"][node["mesh"]]["primitives"]:
                accessor = gltf["accessors"][primitive["attributes"]["POSITION"]]
                view = gltf["bufferViews"][accessor["bufferView"]]
                start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
                points.append(np.frombuffer(binary, "<f4", accessor["count"] * 3, start).reshape(-1, 3))
            return np.vstack(points).astype(float)
    raise SystemExit("pièce introuvable : " + name)


def fit(points):
    center = points.mean(0)
    normal = np.linalg.svd(points - center)[2][2]
    for _ in range(4):
        if normal[2] < 0:
            normal = -normal
        e1 = np.array([1.0, 0, 0]) - normal * normal[0]
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(normal, e1)
        rel = points - center
        radius = np.hypot(rel @ e1, rel @ e2)
        height = rel @ normal
        outer = radius > 0.8 * np.percentile(radius, 98)
        rim = points[outer & (np.abs(height - np.median(height[outer])) < 0.25)]
        middle = rim.mean(0)
        normal = np.linalg.svd(rim - middle)[2][2]
        normal = normal if normal[2] > 0 else -normal
        x, y = (rim - middle) @ e1, (rim - middle) @ e2
        a = np.c_[2 * x, 2 * y, np.ones(len(rim))]
        sol = np.linalg.lstsq(a, x * x + y * y, rcond=None)[0]
        center = middle + sol[0] * e1 + sol[1] * e2
        r = np.sqrt(sol[2] + sol[0] ** 2 + sol[1] ** 2)
    spread = np.linalg.norm(np.cross(rim - center, normal), axis=1)
    return {
        "sommets_jante": int(len(rim)),
        "centre": [round(float(c), 3) for c in center],
        "axe": [round(float(c), 4) for c in normal],
        "inclinaison_sur_verticale_deg": round(float(np.degrees(np.arcsin(abs(normal[1])))), 1),
        "rayon": round(float(r), 3),
        "rayon_min_max": [round(float(spread.min()), 3), round(float(spread.max()), 3)],
    }


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "glb":
        pts = glb_vertices(sys.argv[2], sys.argv[3])
    else:
        pts = np.array(json.load(open(sys.argv[2], encoding="utf-8"))["sommets_repere_jeu"], dtype=float)
    lo, hi = pts.min(0), pts.max(0)
    result = {"sommets": int(len(pts)), "centre_boite": [round(float(c), 3) for c in (lo + hi) / 2]}
    result.update(fit(pts))
    print(json.dumps(result, ensure_ascii=False))
