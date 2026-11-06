"""Boucles des pneus tirées d'ENREGISTREMENTS libres (lot AUDIO-03), pour Shared/Audio/TireAudioModel.

Entrée : les fichiers d'origine téléchargés par le propriétaire, hors dépôt, dans
`E:\\ROBLOX DEV\\aw-sound-references\\pneus\\freesound\\` (registre : docs/audio/SONS_TIERS.md, § pneus).
Sortie (dans `build/audio/tires/`, jamais versionnée) :
- six boucles mono 48 kHz 16 bits, une par ressource du manifeste (`audio.effect.tire.<nom>`) : `roll.dry`,
  `roll.loose`, `roll.wet`, `squeal`, `scrub`, `slide.loose` ;
- `a_envoyer/` : les mêmes fichiers nommés `tire_<nom avec _ au lieu de .>.wav` (ex. `tire_roll_dry.wav`) pour
  l'importation groupée de Studio ; `ecoute_boucles.wav` : chaque boucle trois fois, pour juger les raccords ;
- des DÉMOS d'écoute rendues avec le mélange du jeu (portage Python de TireAudioModel), à partir d'un relevé de la
  vraie dynamique (`tests/lune/tools/tire-sound-trace.luau`) ;
- `rapport.json` : sources, extraits retenus, niveaux et contrôles de raccord.

Principe (repris du lot AUDIO-01, voir docs/lot-audio-01/PLAN_AUDIO_01.md) :
- extrait choisi par l'analyse (`inspect`), passé à 48 kHz (indices en FLOTTANTS : sous Windows, `np.arange` donne
  des entiers 32 bits et `indice × 96 000` débordait au-delà de ~0,47 s, coupures entendues en AUDIO-01) ;
- filtrage de bande : un crissement vit entre ~0,6 et 6 kHz ; on retire le grondement du moteur enregistré avec ;
- enveloppe lente aplanie (un passage de voiture monte puis descend) ;
- allongement par GRAINS (fenêtre de Hann, recouvrement de moitié, ordre pseudo-aléatoire à graine fixe) : un bruit
  n'a pas de cycle, des grains non corrélés se somment à puissance constante ;
- raccord de boucle à puissance constante.

Usage :
  python -I tools/audio/tire_loops.py inspect <dossier>             (analyse de chaque fichier, sans rien écrire)
  python -I tools/audio/tire_loops.py build <dossier> [--out build/audio/tires] [--trace <relevé.csv>]
Lecture : WAV PCM 16, 24 ou 32 bits, ou flottant 32/64 bits (format 3 ou WAVE_FORMAT_EXTENSIBLE). Pas de FLAC ni de
MP3 (aucune dépendance hors numpy).
L'assistant ne peut pas écouter : le jugement à l'oreille (boucles et démos) revient au propriétaire.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import struct
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT_RATE = 48000
MODEL = ROOT / "src/shared/Audio/TireAudioModel.luau"

# ============================== Sources retenues ==============================

# Chaque boucle : fichier (préfixe d'identifiant Freesound), extrait (début, fin en s ; None = choisi par l'analyse),
# bande passante (Hz), niveau RMS visé (dBFS) et méthode :
# - "grains" pour un BRUIT (roulement, eau, gravier) : grains brassés, aucune répétition reconnaissable ;
# - "direct" pour un SIFFLEMENT (crissement) : l'extrait naturel est gardé tel quel et bouclé au point le plus
#   ressemblant, car des grains d'un son presque pur, superposés avec des phases au hasard, battent (chevrotement).
# Extraits fixés le 2026-11-06 d'après l'analyse par trames de 0,5 s (`inspect`, spectre lissé) ; l'oreille du
# propriétaire tranche.
LOOPS: dict[str, dict] = {
    # Nissan Leaf (électrique, pas de moteur thermique) : passage au plus près, 5,5 à 7,5 s (−19 dBFS, bruit large).
    "roll.dry": {"file": "170421", "span": (5.5, 7.5), "band": (60.0, 9000.0), "rms_db": -20.0, "mode": "grains"},
    # Gravier, micro près du pneu : roulement régulier du premier départ, 4,0 à 8,5 s (−31 à −34 dBFS).
    "roll.loose": {"file": "529225", "span": (4.0, 8.5), "band": (80.0, 12000.0), "rms_db": -20.0, "mode": "grains"},
    # Chaussée mouillée à ~100 km/h : passage, 1,3 à 3,3 s ; chuintement dominant entre 1 et 4 kHz.
    "roll.wet": {"file": "462862", "span": (1.3, 3.3), "band": (300.0, 12000.0), "rms_db": -22.0, "mode": "grains"},
    # Crissement en virage (Chrysler) : 6,0 à 9,0 s, raie vers 1 kHz, 25 à 34 dB au-dessus de la bande.
    "squeal": {"file": "71738", "span": (6.0, 9.0), "band": (400.0, 8000.0), "rms_db": -18.0, "mode": "direct"},
    # Glissade franche : patinage (Nissan), 3,0 à 5,5 s, raie vers 1,5 kHz, le plus net et le plus régulier des
    # enregistrements (moteur à −20 dB sous le crissement).
    "scrub": {"file": "71740", "span": (3.0, 5.5), "band": (400.0, 8000.0), "rms_db": -18.0, "mode": "direct"},
    # Glissade sur gravier : second passage du même enregistrement, plus fort et plus dense, 17,0 à 20,5 s. Aucune
    # vraie glissade sur gravier lisible (le n° 10, FLAC, n'a pas pu être lu) : à juger à l'écoute.
    "slide.loose": {
        "file": "529225",
        "span": (17.0, 20.5),
        "band": (200.0, 12000.0),
        "rms_db": -19.0,
        "mode": "grains",
    },
}
LOOP_SECONDS = 2.0

# ============================== Lecture, écriture ==============================


def read_audio(path: Path) -> tuple[int, np.ndarray]:
    """WAV mono ou multicanal, PCM entier (16, 24, 32 bits) ou flottant (32, 64 bits) ; renvoie (fréquence, mono)."""
    data = path.read_bytes()
    if data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError(f"{path.name} : pas un fichier WAV")
    fmt = None
    samples = None
    pos = 12
    while pos + 8 <= len(data):
        tag, size = data[pos : pos + 4], struct.unpack("<I", data[pos + 4 : pos + 8])[0]
        body = data[pos + 8 : pos + 8 + size]
        if tag == b"fmt ":
            code, channels, rate = struct.unpack("<HHI", body[:8])
            bits = struct.unpack("<H", body[14:16])[0]
            if code == 0xFFFE and len(body) >= 26:  # WAVE_FORMAT_EXTENSIBLE : vrai format dans le sous-type
                code = struct.unpack("<H", body[24:26])[0]
            fmt = (code, channels, rate, bits)
        elif tag == b"data":
            samples = body
        pos += 8 + size + (size & 1)
    if fmt is None or samples is None:
        raise ValueError(f"{path.name} : bloc fmt ou data absent")
    code, channels, rate, bits = fmt
    width = bits // 8
    usable = len(samples) - len(samples) % (width * channels)
    raw = samples[:usable]
    if code == 3 and bits == 32:
        x = np.frombuffer(raw, dtype="<f4").astype(np.float64)
    elif code == 3 and bits == 64:
        x = np.frombuffer(raw, dtype="<f8").astype(np.float64)
    elif code == 1 and bits == 16:
        x = np.frombuffer(raw, dtype="<i2") / 32768.0
    elif code == 1 and bits == 24:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int64)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        x = np.where(v & 0x800000, v - 0x1000000, v) / 8388608.0
    elif code == 1 and bits == 32:
        x = np.frombuffer(raw, dtype="<i4") / 2147483648.0
    else:
        raise ValueError(f"{path.name} : format {code}, {bits} bits non pris en charge")
    return rate, x.reshape(-1, channels).mean(axis=1)


def write_wav(path: Path, signal: np.ndarray, rate: int = OUT_RATE) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.clip(np.round(signal * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data.tobytes())


def find_source(folder: Path, prefix: str) -> Path:
    matches = sorted(p for p in folder.iterdir() if p.name.startswith(prefix + "__") and p.suffix.lower() == ".wav")
    if not matches:
        raise FileNotFoundError(f"{prefix} : aucun fichier « {prefix}__*.wav » dans {folder}")
    return matches[0]


# ============================== Traitement ==============================


def to_out_rate(signal: np.ndarray, sr: int) -> np.ndarray:
    """Ramène à 48 kHz : passe-bas par FFT, puis rééchantillonnage à indices FLOTTANTS (voir l'en-tête)."""
    if sr == OUT_RATE:
        return signal.astype(np.float64)
    spec = np.fft.rfft(signal)
    spec[np.fft.rfftfreq(len(signal), 1 / sr) > 0.45 * min(sr, OUT_RATE)] = 0
    smooth = np.fft.irfft(spec, len(signal))
    n_out = int(len(signal) * OUT_RATE / sr)
    positions = np.arange(n_out, dtype=np.float64) * (sr / OUT_RATE)
    return np.interp(positions, np.arange(len(signal), dtype=np.float64), smooth)


def bandpass(signal: np.ndarray, sr: int, low: float, high: float) -> np.ndarray:
    """Filtre de bande doux par FFT (pentes d'ordre 4 en amplitude, sans déphasage)."""
    spec = np.fft.rfft(signal)
    f = np.maximum(np.fft.rfftfreq(len(signal), 1 / sr), 1e-3)
    spec *= 1 / (1 + (low / f) ** 4) / (1 + (f / high) ** 4)
    return np.fft.irfft(spec, len(signal))


def envelope(signal: np.ndarray, sr: int, seconds: float) -> np.ndarray:
    width = max(3, int(seconds * sr))
    kernel = np.hanning(width)
    kernel /= kernel.sum()
    padded = np.pad(signal**2, width, mode="reflect")
    return np.sqrt(np.convolve(padded, kernel, mode="same")[width:-width]) + 1e-9


def flatten(signal: np.ndarray, sr: int, seconds: float = 0.25, strength: float = 1.0) -> np.ndarray:
    """Aplanit l'enveloppe lente (fenêtre `seconds`) : niveau constant pour les grains et la boucle."""
    env = envelope(signal, sr, seconds)
    return signal * (np.mean(env) / env) ** strength


def extend(signal: np.ndarray, sr: int, seconds: float, grain_s: float = 0.16, seed: int = 0) -> np.ndarray:
    """Allonge un bruit par grains de Hann (recouvrement de moitié) pris à des positions pseudo-aléatoires, sans
    répétition immédiate. Grains non corrélés : la somme garde, en moyenne, la puissance de la source."""
    grain = int(grain_s * sr)
    if len(signal) < grain * 2:
        raise ValueError("extrait trop court pour les grains")
    hop = grain // 2
    window = np.sin(np.pi * np.arange(grain) / grain)  # racine de Hann : puissance constante entre grains
    starts = np.arange(0, len(signal) - grain, max(1, grain // 4))
    n_out = int(seconds * sr)
    out = np.zeros(n_out + 2 * grain)
    rng = np.random.default_rng(seed)
    previous = -1
    position = 0
    while position < n_out + grain:
        choice = int(rng.integers(len(starts)))
        if choice == previous:
            choice = (choice + 1) % len(starts)
        previous = choice
        s = int(starts[choice])
        out[position : position + grain] += signal[s : s + grain] * window
        position += hop
    return out[grain : grain + n_out]


def make_loop(signal: np.ndarray, sr: int, seconds: float, crossfade: float = 0.08) -> np.ndarray:
    """Boucle de `seconds` : la suite du signal est fondue dans le début, à puissance constante (bruit non corrélé)."""
    length = int(seconds * sr)
    xf = int(crossfade * sr)
    if len(signal) < length + xf:
        raise ValueError("signal trop court pour la boucle")
    loop = signal[:length].copy()
    ramp = np.linspace(0, np.pi / 2, xf)
    loop[:xf] = loop[:xf] * np.sin(ramp) + signal[length : length + xf] * np.cos(ramp)
    return loop


def natural_loop(signal: np.ndarray, sr: int, crossfade: float = 0.2, search: float = 0.8) -> tuple[np.ndarray, float]:
    """Boucle d'un extrait naturel : la longueur L est choisie dans la dernière `search` s pour que la suite du signal
    après L ressemble le plus au début : corrélation normalisée sur la durée du fondu, pénalisée par l'écart de niveau
    (0,1 par dB ; un crissement change de hauteur, la corrélation seule ne suffit pas). Puis fondu de la suite dans le
    début : linéaire si les deux sont corrélés (sinon ils s'annulent en partie), à puissance constante sinon."""
    xf = int(crossfade * sr)
    head = signal[:xf]
    head_db = db(head)
    best_score, best, best_l = -1e9, 0.0, len(signal) - xf
    for length in range(max(xf * 2, len(signal) - xf - int(search * sr)), len(signal) - xf, 8):
        tail = signal[length : length + xf]
        c = float(np.dot(head, tail) / (np.linalg.norm(head) * np.linalg.norm(tail) + 1e-12))
        score = c - 0.1 * abs(db(tail) - head_db)
        if score > best_score:
            best_score, best, best_l = score, c, length
    loop = signal[:best_l].copy()
    tail = signal[best_l : best_l + xf]
    if best > 0.5:
        ramp = np.linspace(0.0, 1.0, xf)
        loop[:xf] = loop[:xf] * ramp + tail * (1 - ramp)
    else:
        ramp = np.linspace(0, np.pi / 2, xf)
        loop[:xf] = loop[:xf] * np.sin(ramp) + tail * np.cos(ramp)
    return loop, best


def level(signal: np.ndarray, rms_db: float, peak_db: float = -1.0) -> np.ndarray:
    rms = np.sqrt(np.mean(signal**2)) + 1e-12
    out = signal * (10 ** (rms_db / 20) / rms)
    limit = 10 ** (peak_db / 20)
    if np.max(np.abs(out)) > limit:
        out = np.tanh(out / limit) * limit  # écrêtage doux plutôt qu'une baisse globale
    return out


def db(signal: np.ndarray) -> float:
    return float(20 * np.log10(np.sqrt(np.mean(signal**2)) + 1e-12))


def seam_jump_db(loop: np.ndarray, sr: int, frame_s: float = 0.02) -> float:
    """Écart de niveau (dB) entre la dernière et la première trame de la boucle : raccord audible s'il est grand."""
    n = int(frame_s * sr)
    return abs(db(loop[-n:]) - db(loop[:n]))


def max_frame_dip_db(loop: np.ndarray, sr: int, frame_s: float = 0.05) -> float:
    """Plus grand creux d'une trame sous la médiane des trames (dB) : coupure audible s'il dépasse ~8 dB."""
    n = int(frame_s * sr)
    frames = [db(loop[i : i + n]) for i in range(0, len(loop) - n, n)]
    return float(np.median(frames) - np.min(frames))


# ============================== Analyse ==============================

BANDS = [(20, 300), (300, 1000), (1000, 4000), (4000, 12000)]


def band_profile(segment: np.ndarray, sr: int) -> list[float]:
    """Énergie relative (dB) de chaque bande de BANDS."""
    spec = np.abs(np.fft.rfft(segment * np.hanning(len(segment)))) ** 2
    f = np.fft.rfftfreq(len(segment), 1 / sr)
    total = spec.sum() + 1e-18
    return [float(10 * np.log10(spec[(f >= lo) & (f < hi)].sum() / total + 1e-12)) for lo, hi in BANDS]


def tonality(segment: np.ndarray, sr: int) -> tuple[float, float]:
    """Raie la plus forte entre 600 Hz et 6 kHz (Hz) et son émergence (dB au-dessus de la médiane de la bande) : un
    crissement est un sifflement presque pur, un roulement un bruit large."""
    spec = np.abs(np.fft.rfft(segment * np.hanning(len(segment))))
    f = np.fft.rfftfreq(len(segment), 1 / sr)
    band = (f > 600) & (f < 6000)
    i = np.argmax(spec[band])
    peak = spec[band][i]
    return float(f[band][i]), float(20 * np.log10(peak / (np.median(spec[band]) + 1e-12)))


def frames(signal: np.ndarray, sr: int, frame_s: float = 0.25):
    n = int(frame_s * sr)
    for i in range(0, len(signal) - n + 1, n):
        yield i / sr, signal[i : i + n]


def analyse(path: Path) -> dict:
    sr, x = read_audio(path)
    rows = []
    for t, seg in frames(x, sr):
        bands = band_profile(seg, sr)
        tone_hz, tone_db = tonality(seg, sr)
        rows.append({"t": round(t, 2), "db": round(db(seg), 1), "bandes": [round(b, 1) for b in bands],
                     "raie_hz": round(tone_hz), "emergence_db": round(tone_db, 1)})
    return {"fichier": path.name, "frequence": sr, "duree_s": round(len(x) / sr, 3), "niveau_db": round(db(x), 1),
            "crete_db": round(float(20 * np.log10(np.max(np.abs(x)) + 1e-12)), 1), "trames": rows}


def pick_span(signal: np.ndarray, sr: int, mode: str, seconds: float = 1.2) -> tuple[float, float]:
    """Extrait par défaut : la fenêtre la plus forte (`loudest`) ou la plus « sifflante » (`squeal` : émergence de la
    raie entre 600 Hz et 6 kHz × niveau), bornée au fichier."""
    best, best_t = -1e9, 0.0
    hop = 0.1
    for k in range(int(max(0.0, len(signal) / sr - seconds) / hop) + 1):
        t = k * hop
        seg = signal[int(t * sr) : int((t + seconds) * sr)]
        if len(seg) < int(seconds * sr * 0.9):
            break
        score = db(seg)
        if mode == "squeal":
            score += 2 * tonality(seg, sr)[1]
        if score > best:
            best, best_t = score, t
    return best_t, min(best_t + seconds, len(signal) / sr)


# ============================== Modèle du jeu (portage) ==============================


def model_constants(path: Path = MODEL) -> dict[str, float]:
    """Constantes numériques `TireAudioModel.X = nombre` lues dans le module Luau (une seule source de vérité)."""
    text = path.read_text(encoding="utf-8")
    return {k: float(v) for k, v in re.findall(r"^TireAudioModel\.(\w+) = ([0-9.]+)", text, re.M)}


def ramp(value: float, low: float, high: float) -> float:
    if high <= low:
        return 1.0 if value >= high else 0.0
    return min(max((value - low) / (high - low), 0.0), 1.0)


def model_layers(summary: dict, mass: float, c: dict[str, float], time: float | None = None) -> dict[str, tuple]:
    """Portage de TireAudioModel.layers (qualité haute) : {nom: (volume, vitesse de lecture)}. Contrôlé par pytest."""
    speed, wet, surface = summary["Speed"], summary["Wetness"], summary["Surface"]
    mass_ratio = max(mass, 100) / c["ReferenceMassKg"]
    mass_gain = min(max(mass_ratio**0.3, 0.8), 1.3)
    mass_pitch = min(max(mass_ratio**-0.1, 0.9), 1.1)
    roll = (min(max((speed / c["RollReferenceSpeed"]) ** 1.5, 0), 1)
            * ramp(speed, c["RollFadeInSpeed"] * 0.5, c["RollFadeInSpeed"] * 3) * summary["Grounded"] * mass_gain)
    pitch = (0.85 + 0.35 * min(max(speed / 40, 0), 1)) * mass_pitch
    dry = roll * (1 - 0.4 * wet) if surface == "Hard" else (roll * 0.4 if surface == "Ice" else 0.0)
    loose = roll if surface == "Loose" else (roll * 0.6 if surface == "Soft" else 0.0)
    wet_roll = roll * wet if surface in ("Hard", "Ice") else 0.0
    squeal = summary["Squeal"] * summary["Grounded"]
    if summary.get("Abs") and time is not None:
        squeal *= 0.55 + 0.45 * max(0.0, np.sin(2 * np.pi * c["AbsPulseHz"] * time))
    hard = (1 - (1 - c["WetSquealFactor"]) * wet) if surface == "Hard" else (0.1 if surface == "Ice" else 0.0)
    squeal_pitch = min(max(0.9 + 0.25 * ramp(summary["SlipSpeed"], 1, 12), 0.85), 1.2) * mass_pitch
    scrub = summary["Scrub"] * summary["Grounded"] * hard
    slide = squeal if surface == "Loose" else (squeal * 0.6 if surface == "Soft" else 0.0)
    out = {
        "roll.dry": (dry * 0.6, pitch),
        "roll.loose": (loose * 0.7, pitch * (0.85 if surface == "Soft" else 1)),
        "roll.wet": (wet_roll * 0.6, pitch),
        "squeal": (squeal * hard * 0.8 * mass_gain, squeal_pitch),
        "scrub": (scrub * 0.5 * mass_gain, pitch),
        "slide.loose": (slide * 0.7 * mass_gain, pitch),
    }
    return {k: (min(max(v, 0.0), 1.0), s) for k, (v, s) in out.items()}


# ============================== Démo ==============================


def read_trace(path: Path) -> list[dict]:
    """Relevé de tests/lune/tools/tire-sound-trace.luau : une ligne par pas, résumé sonore des pneus."""
    with path.open(encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    out = []
    for r in rows:
        out.append({"t": float(r["temps_s"]), "Speed": float(r["vitesse_ms"]), "Grounded": float(r["au_sol"]),
                    "Squeal": float(r["crissement"]), "Scrub": float(r["glissade"]),
                    "SlipSpeed": float(r["vitesse_glissement"]), "Surface": r["revetement"],
                    "Wetness": float(r["humidite"]), "Abs": r["abs"] == "1", "phase": r["phase"]})
    return out


def render_demo(trace: list[dict], loops: dict[str, np.ndarray], mass: float, c: dict, rate: int = OUT_RATE):
    """Mélange du jeu, échantillon par échantillon : volumes et vitesses interpolés entre les pas du relevé, chaque
    boucle lue à sa vitesse (phase cumulée), comme un objet Sound à PlaybackSpeed variable."""
    t_end = trace[-1]["t"]
    n = int(t_end * rate)
    times = np.arange(n, dtype=np.float64) / rate
    steps = np.array([r["t"] for r in trace])
    out = np.zeros(n)
    for name, loop in loops.items():
        vol = np.array([model_layers(r, mass, c, r["t"])[name][0] for r in trace])
        spd = np.array([model_layers(r, mass, c, r["t"])[name][1] for r in trace])
        v = np.interp(times, steps, vol)
        s = np.interp(times, steps, spd)
        phase = np.cumsum(s) % len(loop)
        out += v * np.interp(phase, np.arange(len(loop), dtype=np.float64), loop, period=len(loop))
    # Démo normalisée à −3 dBFS de crête : seules les proportions entre couches et phases comptent à l'écoute.
    peak = np.max(np.abs(out)) + 1e-12
    return out * (0.708 / peak)


# ============================== Construction ==============================


def build_loop(name: str, spec: dict, refs: Path) -> tuple[np.ndarray, dict]:
    path = find_source(refs, spec["file"])
    sr, x = read_audio(path)
    span = spec["span"] or pick_span(x, sr, spec.get("pick", "loudest"))
    seg = x[int(span[0] * sr) : int(span[1] * sr)]
    seg = to_out_rate(seg, sr)
    seg = bandpass(seg, OUT_RATE, *spec["band"])
    info: dict = {}
    if spec.get("mode", "grains") == "direct":
        # Sifflement : enveloppe aplanie en partie seulement (les variations naturelles du crissement sont gardées).
        seg = flatten(seg, OUT_RATE, seconds=0.2, strength=0.85)
        loop, corr = natural_loop(seg, OUT_RATE)
        info["correlation_raccord"] = round(corr, 3)
    else:
        seg = flatten(seg, OUT_RATE)
        long = extend(seg, OUT_RATE, LOOP_SECONDS + 0.2, seed=sum(map(ord, name)))
        loop = make_loop(long, OUT_RATE, LOOP_SECONDS)
    loop = level(loop, spec["rms_db"])
    info |= {"source": path.name, "methode": spec.get("mode", "grains"), "duree_s": round(len(loop) / OUT_RATE, 3),
             "extrait_s": [round(span[0], 2), round(span[1], 2)], "bande_hz": list(spec["band"]),
            "niveau_db": round(db(loop), 1), "raccord_db": round(seam_jump_db(loop, OUT_RATE), 2),
            "creux_max_db": round(max_frame_dip_db(loop, OUT_RATE), 2)}
    return loop, info


def build(refs: Path, out: Path, trace: Path | None) -> dict:
    report: dict = {"boucles": {}, "demos": []}
    loops = {}
    for name, spec in LOOPS.items():
        loop, info = build_loop(name, spec, refs)
        loops[name] = loop
        report["boucles"][name] = info
        write_wav(out / f"{name}.wav", loop)
        # Noms sans point pour l'importation groupée de Studio (comme brio_on_1000 au lot AUDIO-01).
        write_wav(out / "a_envoyer" / f"tire_{name.replace('.', '_')}.wav", loop)
    # Écoute des raccords : chaque boucle répétée 3 fois, dans l'ordre de LOOPS, séparées par 0,6 s de silence.
    gap = np.zeros(int(0.6 * OUT_RATE))
    write_wav(out / "ecoute_boucles.wav", np.concatenate([np.concatenate([np.tile(lp, 3), gap]) for lp in loops.values()]))
    report["ecoute_boucles"] = {"fichier": "ecoute_boucles.wav", "ordre": list(loops)}
    if trace is not None:
        c = model_constants()
        rows = read_trace(trace)
        demo = render_demo(rows, loops, 960.0, c)
        write_wav(out / "demo_pneus.wav", demo)
        report["demos"].append({"fichier": "demo_pneus.wav", "duree_s": round(len(demo) / OUT_RATE, 2),
                                "phases": sorted({r["phase"] for r in rows})})
    (out / "rapport.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    p_inspect = sub.add_parser("inspect", help="analyse des enregistrements (rien n'est écrit)")
    p_inspect.add_argument("refs", type=Path)
    p_build = sub.add_parser("build", help="boucles, démos et rapport")
    p_build.add_argument("refs", type=Path)
    p_build.add_argument("--out", type=Path, default=ROOT / "build/audio/tires")
    p_build.add_argument("--trace", type=Path, default=None)
    args = parser.parse_args(argv)
    if args.command == "inspect":
        for path in sorted(args.refs.iterdir()):
            if path.suffix.lower() != ".wav":
                print(json.dumps({"fichier": path.name, "erreur": "format non lu (WAV seulement)"}, ensure_ascii=False))
                continue
            print(json.dumps(analyse(path), ensure_ascii=False))
        return 0
    report = build(args.refs, args.out, args.trace)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
