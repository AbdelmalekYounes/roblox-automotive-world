"""Bruits de collision tirés d'ENREGISTREMENTS libres (lot AUDIO-04), pour Shared/Audio/CollisionAudioModel.

Entrée : les fichiers d'origine téléchargés par le propriétaire, hors dépôt, dans
`E:\\ROBLOX DEV\\aw-sound-references\\collisions\\freesound\\` (registre : docs/audio/SONS_TIERS.md, § collisions).
Sortie (dans `build/audio/collisions/`, jamais versionnée) :
- six sons ponctuels et une boucle, mono 48 kHz 16 bits, un par ressource `audio.effect.collision.<nom>` :
  `hard.light`, `hard.heavy`, `object`, `vehicle.light`, `vehicle.heavy`, `glass`, `scrape` (boucle) ;
- `a_envoyer/` : les mêmes fichiers nommés `collision_<nom avec _ au lieu de .>.wav` pour l'importation de Studio ;
- `demo_collisions.wav` : chocs de plus en plus violents de chaque famille (volume et hauteur du jeu), bris de verre,
  puis raclement à vitesse croissante ; `rapport.json`.

Traitement (outils communs de tools/audio/tire_loops.py, indices en flottants pour le passage à 48 kHz) :
- sons ponctuels : extrait pris à l'attaque (début détecté sur l'enveloppe), filtrage de bande, fin fondue, crête
  normalisée ;
- raclement : extrait bouclé par grains (bruit), raccord à puissance constante.

Usage :
  python -I tools/audio/collision_sounds.py inspect <dossier>
  python -I tools/audio/collision_sounds.py build <dossier> [--out build/audio/collisions]
L'assistant ne peut pas écouter : le jugement à l'oreille revient au propriétaire.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tire_loops as tl  # noqa: E402  (outils communs : lecture, filtres, grains, boucles)

ROOT = Path(__file__).resolve().parents[2]
OUT_RATE = tl.OUT_RATE
MODEL = ROOT / "src/shared/Audio/CollisionAudioModel.luau"

# ============================== Sources retenues ==============================

# Sons ponctuels : fichier (préfixe Freesound), début de recherche de l'attaque (s ; None = début du fichier),
# durée gardée (s), bande (Hz), crête visée (dBFS). Boucle : extrait (début, fin). Fixés après `inspect` et l'écoute.
SHOTS: dict[str, dict] = {
    "hard.light": {"file": "385938", "search": None, "length": 0.6, "band": (50.0, 9000.0), "peak_db": -6.0},
    "hard.heavy": {"file": "385937", "search": None, "length": 1.4, "band": (40.0, 12000.0), "peak_db": -2.0},
    "object": {"file": "385940", "search": None, "length": 0.8, "band": (60.0, 12000.0), "peak_db": -4.0},
    "vehicle.light": {"file": "346301", "search": None, "length": 0.8, "band": (50.0, 12000.0), "peak_db": -5.0},
    "vehicle.heavy": {"file": "346301", "search": None, "length": 2.5, "band": (40.0, 14000.0), "peak_db": -1.5},
    "glass": {"file": "848312", "search": None, "length": 1.8, "band": (300.0, 16000.0), "peak_db": -4.0},
}
LOOP = {"name": "scrape", "file": "385939", "span": None, "band": (150.0, 12000.0), "rms_db": -18.0}
LOOP_SECONDS = 2.0
FADE_S = 0.08

# ============================== Traitement ==============================


def onset(signal: np.ndarray, sr: int, start: float | None) -> float:
    """Début de l'attaque (s) : premier instant après `start` où l'enveloppe (5 ms) dépasse 20 % de son maximum."""
    begin = int((start or 0.0) * sr)
    env = tl.envelope(signal[begin:], sr, 0.005)
    above = np.where(env >= 0.2 * env.max())[0]
    first = int(above[0]) if len(above) else 0
    # Un peu avant l'attaque (3 ms) pour ne pas couper le transitoire.
    return max(0.0, (begin + first) / sr - 0.003)


def shot(signal: np.ndarray, sr: int, spec: dict) -> tuple[np.ndarray, dict]:
    t0 = onset(signal, sr, spec["search"])
    seg = signal[int(t0 * sr) : int((t0 + spec["length"]) * sr)]
    seg = tl.to_out_rate(seg, sr)
    seg = tl.bandpass(seg, OUT_RATE, *spec["band"])
    fade = int(FADE_S * OUT_RATE)
    if len(seg) > 2 * fade:
        seg[-fade:] *= np.cos(np.linspace(0, np.pi / 2, fade)) ** 2
    seg[:48] *= np.linspace(0, 1, 48)  # 1 ms : aucun clic au départ
    peak = np.max(np.abs(seg)) + 1e-12
    seg = seg * (10 ** (spec["peak_db"] / 20) / peak)
    return seg, {"attaque_s": round(t0, 3), "duree_s": round(len(seg) / OUT_RATE, 3), "niveau_db": round(tl.db(seg), 1)}


def loop(signal: np.ndarray, sr: int, spec: dict) -> tuple[np.ndarray, dict]:
    span = spec["span"] or tl.pick_span(signal, sr, "loudest", seconds=1.5)
    seg = signal[int(span[0] * sr) : int(span[1] * sr)]
    seg = tl.bandpass(tl.to_out_rate(seg, sr), OUT_RATE, *spec["band"])
    seg = tl.flatten(seg, OUT_RATE)
    long = tl.extend(seg, OUT_RATE, LOOP_SECONDS + 0.2, seed=7)
    out = tl.level(tl.make_loop(long, OUT_RATE, LOOP_SECONDS), spec["rms_db"])
    return out, {"extrait_s": [round(span[0], 2), round(span[1], 2)], "raccord_db": round(tl.seam_jump_db(out, OUT_RATE), 2),
                 "creux_max_db": round(tl.max_frame_dip_db(out, OUT_RATE), 2), "niveau_db": round(tl.db(out), 1)}


# ============================== Modèle du jeu (portage) ==============================


def model_constants(path: Path = MODEL) -> dict[str, float]:
    """Constantes numériques simples `CollisionAudioModel.X = nombre` du module Luau."""
    import re

    text = path.read_text(encoding="utf-8")
    return {k: float(v) for k, v in re.findall(r"^CollisionAudioModel\.(\w+) = ([0-9.]+)\s*(?:--.*)?$", text, re.M)}


def impact(kind: str, delta_v: float, c: dict[str, float], random01: float = 0.5) -> tuple[str, float, float] | None:
    """Portage de CollisionAudioModel.impact : (nom de son, volume, vitesse de lecture), ou None sous le seuil."""
    if delta_v < c["MinImpactMs"]:
        return None
    heavy = delta_v >= c["HeavyImpactMs"]
    name = {"Vehicle": "vehicle.heavy" if heavy else "vehicle.light", "Object": "object"}.get(
        kind, "hard.heavy" if heavy else "hard.light"
    )
    level = min(max((delta_v - c["MinImpactMs"]) / (c["FullImpactMs"] - c["MinImpactMs"]), 0.0), 1.0)
    volume = 0.25 + 0.75 * np.sqrt(level)
    if kind == "Object":
        volume *= 0.8
    speed = (1.05 - 0.1 * level) * (0.95 + 0.1 * random01)
    return name, float(min(volume, 1.0)), float(speed)


def place(out: np.ndarray, sound: np.ndarray, at: float, volume: float, speed: float) -> None:
    """Joue `sound` à l'instant `at` (s), au volume et à la vitesse de lecture donnés (rééchantillonnage simple)."""
    n = int(len(sound) / speed)
    src = np.interp(np.arange(n, dtype=np.float64) * speed, np.arange(len(sound), dtype=np.float64), sound)
    i = int(at * OUT_RATE)
    end = min(len(out), i + n)
    out[i:end] += volume * src[: end - i]


def render_demo(sounds: dict[str, np.ndarray], c: dict[str, float]) -> tuple[np.ndarray, list]:
    """Chocs à 2, 5, 9 et 14 m/s pour chaque famille, bris de verre, puis raclement de 2 à 15 m/s et retour."""
    timeline = []
    out = np.zeros(int(30 * OUT_RATE))
    t = 0.5
    rng = np.random.default_rng(4)
    for kind in ("Hard", "Object", "Vehicle"):
        for dv in (2.0, 5.0, 9.0, 14.0):
            r = impact(kind, dv, c, float(rng.random()))
            if r:
                name, volume, speed = r
                place(out, sounds[name], t, volume, speed)
                timeline.append({"t": round(t, 2), "famille": kind, "dv_ms": dv, "son": name, "volume": round(volume, 2)})
            t += 1.6
        t += 0.6
    place(out, sounds["glass"], t, 0.7, 1.0)
    timeline.append({"t": round(t, 2), "famille": "Glass", "son": "glass"})
    t += 2.0
    # Raclement : 6 s, vitesse 2 → 15 → 2 m/s (volume et hauteur du jeu).
    scrape = sounds["scrape"]
    n = int(6 * OUT_RATE)
    v = 2 + 13 * np.sin(np.linspace(0, np.pi, n))
    level = np.clip((v - c["ScrapeMinSpeed"]) / (c["ScrapeFullSpeed"] - c["ScrapeMinSpeed"]), 0, 1)
    phase = np.cumsum(0.85 + 0.35 * level) % len(scrape)
    seg = (0.2 + 0.7 * level) * np.interp(phase, np.arange(len(scrape), dtype=np.float64), scrape, period=len(scrape))
    i = int(t * OUT_RATE)
    out[i : i + n] += seg[: len(out) - i]
    timeline.append({"t": round(t, 2), "famille": "Scrape", "duree_s": 6})
    out = out[: i + n + OUT_RATE // 2]
    return out * (0.708 / (np.max(np.abs(out)) + 1e-12)), timeline


# ============================== Construction ==============================


def build(refs: Path, out: Path) -> dict:
    report: dict = {"sons": {}}
    sounds: dict[str, np.ndarray] = {}
    for name, spec in SHOTS.items():
        path = tl.find_source(refs, spec["file"])
        sr, x = tl.read_audio(path)
        sound, info = shot(x, sr, spec)
        sounds[name] = sound
        report["sons"][name] = {"source": path.name, **info}
    path = tl.find_source(refs, LOOP["file"])
    sr, x = tl.read_audio(path)
    sound, info = loop(x, sr, LOOP)
    sounds[LOOP["name"]] = sound
    report["sons"][LOOP["name"]] = {"source": path.name, "boucle": True, **info}
    for name, sound in sounds.items():
        tl.write_wav(out / f"{name}.wav", sound)
        tl.write_wav(out / "a_envoyer" / f"collision_{name.replace('.', '_')}.wav", sound)
    demo, timeline = render_demo(sounds, model_constants())
    tl.write_wav(out / "demo_collisions.wav", demo)
    report["demo"] = {"fichier": "demo_collisions.wav", "duree_s": round(len(demo) / OUT_RATE, 2), "deroule": timeline}
    (out / "rapport.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    p_inspect = sub.add_parser("inspect")
    p_inspect.add_argument("refs", type=Path)
    p_build = sub.add_parser("build")
    p_build.add_argument("refs", type=Path)
    p_build.add_argument("--out", type=Path, default=ROOT / "build/audio/collisions")
    args = parser.parse_args(argv)
    if args.command == "inspect":
        for path in sorted(args.refs.iterdir()):
            if path.suffix.lower() == ".wav":
                print(json.dumps(tl.analyse(path), ensure_ascii=False))
        return 0
    print(json.dumps(build(args.refs, args.out), ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
