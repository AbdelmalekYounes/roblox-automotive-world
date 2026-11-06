"""Sonde en LECTURE SEULE de l'habitacle de la Brio (lot BRIO-02, 2026-11-06). N'enregistre pas le fichier .blend.

    blender --background --factory-startup --disable-autoexec <aw-art-citadine>/vehicles/wk_brio/blend/wk_brio_milano95.blend \
        --python docs/lot-brio-02/sonde_habitacle_brio.py -- <sortie.json>

Repère du jeu (1 unité = 1 stud) : x à droite, y en haut, z vers l'arrière (Blender : x, -z, y). Collections EXT et INT
préparées par `milano95_prepare.py` (dépôt d'art). Relève, aux places (x ∓1,2), par rayons :
- coupe longitudinale de l'assise (rayons verticaux, toutes les surfaces traversées) et du dossier (rayons horizontaux) ;
- dessus du coussin aux z candidats du siège du jeu ;
- plancher des pieds et dessous de la planche de bord (rayons vers le bas et vers le haut depuis y −0,5) ;
- dessous du pavillon (premier obstacle au-dessus de y 1,5, caisse et habitacle) ;
- boîte du volant.
"""
import json
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

dg = bpy.context.evaluated_depsgraph_get()


def at(x, y, z):
    return Vector((x, -z, y))


def tree(objs):
    verts, polys, off = [], [], 0
    for o in objs:
        me = o.evaluated_get(dg).to_mesh()
        me.calc_loop_triangles()
        verts += [o.matrix_world @ v.co for v in me.vertices]
        polys += [[i + off for i in t.vertices] for t in me.loop_triangles]
        off += len(me.vertices)
        o.evaluated_get(dg).to_mesh_clear()
    return BVHTree.FromPolygons(verts, polys)


EXT = [o for o in bpy.data.collections["EXT"].objects if o.type == "MESH"]
INT = [o for o in bpy.data.collections["INT"].objects if o.type == "MESH"]
T_ALL, T_INT = tree(EXT + INT), tree(INT)
DOWN, UP, BACK = Vector((0, 0, -1)), Vector((0, 0, 1)), Vector((0, -1, 0))


def first(t, o, d):
    h = t.ray_cast(o, d)
    return None if h[0] is None else h[0]


def all_hits(t, o, d, n=6):
    out, p = [], o
    for _ in range(n):
        h = t.ray_cast(p, d)
        if h[0] is None:
            break
        out.append(h[0])
        p = h[0] + d * 1e-4
    return out


def r(v):
    return None if v is None else round(v, 3)


out = {"places": {}}
for x in (-1.2, 1.2):
    place = {}
    # Assise et dossier : y des surfaces traversées vers le bas, de z 1,0 à 2,2.
    place["coupe_verticale"] = [
        [round(1.0 + i * 0.03, 3)] + [r(h.z) for h in all_hits(T_INT, at(x, 2.5, 1.0 + i * 0.03), DOWN)] for i in range(41)
    ]
    # Dossier : z de la première surface vers l'arrière depuis z 0, de y −0,2 à 2,1.
    place["dossier"] = [
        (round(-0.2 + k * 0.08, 2), r((lambda h: None if h is None else -h.y)(first(T_INT, at(x, -0.2 + k * 0.08, 0.0), BACK))))
        for k in range(30)
    ]
    place["coussin"] = [(z, r(first(T_INT, at(x, 2.0, z), DOWN).z)) for z in (0.45, 0.55, 0.65, 0.75, 0.85)]
    place["puits_des_pieds"] = [
        (
            round(-0.3 - i * 0.1, 2),
            r((lambda h: None if h is None else h.z)(first(T_ALL, at(x, -0.5, -0.3 - i * 0.1), DOWN))),
            r((lambda h: None if h is None else h.z)(first(T_ALL, at(x, -0.5, -0.3 - i * 0.1), UP))),
        )
        for i in range(27)
    ]
    place["pavillon"] = [
        (z, r((lambda h: None if h is None else h.z)(first(T_ALL, at(x, 1.5, z), UP))))
        for z in (0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8, 2.0, 2.2, 2.4)
    ]
    out["places"][str(x)] = place

v = bpy.data.objects["BRIO_Volant"]
pts = [v.matrix_world @ p.co for p in v.data.vertices]
game = [(p.x, p.z, -p.y) for p in pts]
out["volant"] = {"min": [r(min(p[i] for p in game)) for i in range(3)], "max": [r(max(p[i] for p in game)) for i in range(3)]}
json.dump(out, open(sys.argv[sys.argv.index("--") + 1], "w", encoding="utf-8"), indent=1)
print("AW_SONDE ok")
