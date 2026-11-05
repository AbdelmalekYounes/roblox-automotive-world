"""Boucles de moteur tirées d'ENREGISTREMENTS libres (lot AUDIO-01), pour un profil sonore du jeu.

Entrée : les fichiers d'origine téléchargés par le propriétaire, hors dépôt (registre : docs/audio/SONS_TIERS.md).
Sortie (dans `build/`, jamais versionnée) :
- une boucle par régime de référence, en charge (`on.<tr/min>`) et en décharge (`off.<tr/min>`) ;
- des sons ponctuels (`start`, `stop`, `stall`) ;
- `rapport.json` (régimes mesurés, niveaux, longueurs) et une DÉMO d'écoute rendue avec le mélange du jeu
  (Shared/Audio/EngineAudioModel.profileLayers) : montée en régime en charge, lever de pied, ralenti.

Méthode, numpy seul, sans dépendance nouvelle :
- régime mesuré par la raie d'allumage d'un 4 cylindres (fréquence × 30 = tr/min), raie la plus forte entre 25 et
  260 Hz. La règle a été vérifiée sur les boucles étiquetées 2 500 et 6 500 tr/min du pack 190E ;
- boucle stable : transposée par rééchantillonnage au régime de référence, longueur = nombre entier de cycles moteur
  (120 / tr/min s), raccord par fondu à puissance constante ;
- extrait d'une montée ou d'une descente en régime : régime ajusté linéairement sur l'extrait, puis temps « déplié »
  pour un régime constant (phase moteur conservée), puis bouclé de même ;
- 96 kHz ramenés à 48 kHz (filtre par FFT), mono, 16 bits ; niveaux RMS homogènes, crête sous −1 dBFS.

Usage : python -I tools/audio/engine_loops.py brio <dossier des enregistrements> [--out build/audio/engines]
L'assistant ne peut pas écouter : le jugement à l'oreille (démo et boucles) revient au propriétaire.
"""

from __future__ import annotations

import argparse
import json
import sys
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT_RATE = 48000

# ============================== Profils ==============================

# Brio (lot AUDIO-01, décision du propriétaire du 2026-11-05 : la Brio d'abord). Pack « The Dyno Sessions: 190E »
# (Chippy569, CC0), micro d'échappement (Audix D6, 30 cm derrière la sortie). Régimes indiqués = attendus (±12 %),
# remplacés par la mesure. Les points de référence sont communs aux boucles en charge et en décharge
# (Shared/Audio/EngineSoundProfiles), espacés d'un facteur ~1,45.
BRIO = {
    "prefix": "audio.engine.brio.",
    "points": [1000, 1450, 2100, 3000, 4300, 6200],
    "idle_rpm": 850,
    "limiter_rpm": 7200,
    "sources": {
        "ralenti": {"file": "162515__chippy569__21_500_d6.wav", "rpm": 1030},
        "charge_1300": {"file": "162506__chippy569__19_500_d6.wav", "rpm": 1290},
        "charge_2550": {"file": "162509__chippy569__19_2500_d6.wav", "rpm": 2556},
        "charge_6200": {"file": "162512__chippy569__20_6500_d6.wav", "rpm": 6207},
        "vide_2430": {"file": "162518__chippy569__21_2500_d6.wav", "rpm": 2430},
        "vide_6300": {"file": "162521__chippy569__21_6500_d6.wav", "rpm": 6297},
        "montee": {"file": "162501__chippy569__17_shortsweep_d6.wav"},
        "descente": {"file": "162504__chippy569__17_medsweep_d6.wav"},
        "demarrage": {"file": "162528__chippy569__23_startismall_d6.wav"},
        "demarrage_fort": {"file": "162525__chippy569__23_startbig_d6.wav"},
    },
    # Boucle : (charge ou décharge, régime de référence) → source stable, ou extrait de balayage (début, fin en s).
    "loops": {
        ("on", 1000): {"source": "ralenti"},
        ("on", 1450): {"source": "charge_1300"},
        ("on", 2100): {"source": "charge_2550"},
        ("on", 3000): {"source": "charge_2550"},
        ("on", 4300): {"source": "montee", "span": (0.95, 1.50), "approx": (3700, 5300)},
        ("on", 6200): {"source": "charge_6200"},
        ("off", 1000): {"source": "ralenti"},
        ("off", 1450): {"source": "descente", "span": (6.85, 7.40), "approx": (1750, 1400)},
        ("off", 2100): {"source": "vide_2430"},
        ("off", 3000): {"source": "vide_2430"},
        ("off", 4300): {"source": "descente", "span": (3.25, 4.05), "approx": (4100, 3500)},
        ("off", 6200): {"source": "vide_6300"},
    },
    # Sons ponctuels : extrait (début, fin en s), fondus d'entrée et de sortie (s).
    "events": {
        "Start": {"source": "demarrage", "span": (1.85, 4.6), "fade": (0.01, 0.6)},
        "Stop": {"source": "demarrage_fort", "span": (6.55, 8.2), "fade": (0.05, 0.4)},
        "Stall": {"source": "demarrage_fort", "span": (6.75, 7.9), "fade": (0.02, 0.3)},
    },
    # Niveaux RMS visés (dBFS) : la décharge reste plus discrète que la charge, comme en vrai.
    "rms_on": -15.0,
    "rms_off": -21.0,
    "rms_event": -18.0,
}

PROFILES = {"brio": BRIO}

# ============================== Lecture, écriture ==============================


def read_wav(path: Path) -> tuple[int, np.ndarray]:
    with wave.open(str(path), "rb") as w:
        sr, ch, width, n = w.getframerate(), w.getnchannels(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(n)
    if width == 3:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int32)
        x = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        x = np.where(x & 0x800000, x - 0x1000000, x) / 8388608.0
    elif width == 2:
        x = np.frombuffer(raw, dtype=np.int16) / 32768.0
    else:
        raise ValueError(f"{path.name} : {8 * width} bits non pris en charge")
    return sr, x.reshape(-1, ch).mean(axis=1)


def write_wav(path: Path, signal: np.ndarray, rate: int = OUT_RATE) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.clip(np.round(signal * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data.tobytes())


# ============================== Mesure du régime ==============================


def line_rpm(segment: np.ndarray, sr: int, expected: float | None = None) -> float:
    """Régime (tr/min) d'un extrait : raie la plus forte entre 25 et 260 Hz (ou à ±12 % du régime attendu), × 30."""
    n = len(segment)
    nfft = 1 << int(np.ceil(np.log2(max(n, 2) * 8)))
    mag = np.abs(np.fft.rfft(segment * np.hanning(n), nfft))
    freqs = np.fft.rfftfreq(nfft, 1 / sr)
    lo, hi = (25.0, 260.0) if expected is None else (expected / 30 * 0.88, expected / 30 * 1.12)
    band = np.where((freqs > lo) & (freqs < hi))[0]
    i = band[np.argmax(mag[band])]
    # Affinage parabolique du pic.
    if 0 < i < len(mag) - 1:
        a, b, c = np.log(mag[i - 1] + 1e-12), np.log(mag[i] + 1e-12), np.log(mag[i + 1] + 1e-12)
        i = i + 0.5 * (a - c) / (a - 2 * b + c + 1e-12)
    return float(i * sr / nfft * 30)


def sweep_fit(
    signal: np.ndarray, sr: int, span: tuple[float, float], approx: tuple[float, float]
) -> tuple[float, float]:
    """Régime linéaire r(t) = a + b·t sur un extrait de balayage : mesure par trames de 0,1 s, chacune cherchée à
    ±12 % du régime approché (`approx` : début, fin, relevés à l'analyse) pour écarter les raies d'ordre 1 ou 4 ;
    valeurs aberrantes (écart > 8 % à une première droite) écartées. Retourne (a, b) en tr/min et tr/min/s."""
    t0, t1 = span
    win, hop = int(0.1 * sr), int(0.025 * sr)
    times, rpms = [], []
    for start in range(int(t0 * sr), int(t1 * sr) - win, hop):
        times.append((start + win / 2) / sr - t0)
        guess = approx[0] + (approx[1] - approx[0]) * (times[-1] / (t1 - t0))
        rpms.append(line_rpm(signal[start : start + win], sr, guess))
    t, r = np.array(times), np.array(rpms)
    b, a = np.polyfit(t, r, 1)
    keep = np.abs(r - (a + b * t)) / (a + b * t) < 0.08
    if keep.sum() >= 4:
        b, a = np.polyfit(t[keep], r[keep], 1)
    return float(a), float(b)


# ============================== Traitement ==============================


def warp(signal: np.ndarray, sr: int, rpm_of_t, target: float, duration: float) -> np.ndarray:
    """Rééchantillonne pour un régime CONSTANT `target` : l'échantillon de sortie τ lit l'entrée à l'instant t où la
    phase moteur ∫ r(t) dt vaut target·τ. `rpm_of_t` donne le régime de l'entrée (tableau aligné sur `signal`)."""
    phase = np.concatenate([[0.0], np.cumsum(rpm_of_t[:-1]) / sr])  # tr/min · s, à un facteur 1/60 près
    n_out = int(min(duration, phase[-1] / target) * sr)
    tau_phase = target * np.arange(n_out) / sr
    src_index = np.interp(tau_phase, phase, np.arange(len(signal)))
    return np.interp(src_index, np.arange(len(signal)), signal)


def to_out_rate(signal: np.ndarray, sr: int) -> np.ndarray:
    """Ramène à 48 kHz : filtre passe-bas par FFT sous 20 kHz, puis rééchantillonnage."""
    if sr == OUT_RATE:
        return signal
    spec = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / sr)
    spec[freqs > 0.45 * OUT_RATE] = 0
    smooth = np.fft.irfft(spec, len(signal))
    n_out = int(len(signal) * OUT_RATE / sr)
    return np.interp(np.arange(n_out) * sr / OUT_RATE, np.arange(len(signal)), smooth)


def highpass(signal: np.ndarray, sr: int, cutoff: float = 25.0) -> np.ndarray:
    """Retire la composante continue et l'infra-grave (vent, choc du micro) sous `cutoff` Hz."""
    spec = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / sr)
    spec *= 1 / (1 + (cutoff / np.maximum(freqs, 1e-3)) ** 4)
    return np.fft.irfft(spec, len(signal))


def make_loop(signal: np.ndarray, sr: int, rpm: float, crossfade: float = 0.04) -> np.ndarray:
    """Boucle sans raccord : longueur = nombre entier de cycles moteur (2 tours), fin fondue dans le début."""
    cycle = 120.0 / rpm * sr
    xf = int(crossfade * sr)
    cycles = int((len(signal) - xf) // cycle)
    if cycles < 2:
        raise ValueError("extrait trop court pour boucler")
    length = int(round(cycles * cycle))
    loop = signal[:length].copy()
    ramp = np.sin(np.linspace(0, np.pi / 2, xf)) ** 2
    loop[:xf] = loop[:xf] * ramp + signal[length : length + xf] * (1 - ramp)
    return loop


def level(signal: np.ndarray, rms_db: float, peak_db: float = -1.0) -> np.ndarray:
    rms = np.sqrt(np.mean(signal**2)) + 1e-12
    out = signal * (10 ** (rms_db / 20) / rms)
    peak = np.max(np.abs(out))
    limit = 10 ** (peak_db / 20)
    if peak > limit:
        # Écrêtage doux (tanh) au-delà de la limite plutôt qu'une baisse globale du niveau.
        out = np.tanh(out / limit) * limit
    return out


def db(signal: np.ndarray) -> float:
    return float(20 * np.log10(np.sqrt(np.mean(signal**2)) + 1e-12))


# ============================== Démo d'écoute ==============================


def smoothstep(x):
    t = np.clip(x, 0, 1)
    return t * t * (3 - 2 * t)


def point_weights(points: list[int], rpm: float) -> list[float]:
    out = []
    for i, here in enumerate(points):
        below = points[i - 1] if i > 0 else None
        above = points[i + 1] if i + 1 < len(points) else None
        if rpm <= here:
            out.append(1.0 if below is None else float(np.clip((rpm - below) / (here - below), 0, 1)))
        else:
            out.append(1.0 if above is None else float(np.clip((above - rpm) / (above - here), 0, 1)))
    return out


def render_demo(profile: dict, loops: dict, rate: int = OUT_RATE) -> np.ndarray:
    """Même mélange que EngineAudioModel.profileLayers (fondu régime et charge, transposition bornée 0,7–1,45),
    calculé par blocs de 10 ms : ralenti 1,5 s, montée en charge jusqu'au rupteur en 6 s, lever de pied et
    descente en 4 s, ralenti 2 s."""
    knee = 0.25
    keyframes = [(0, profile["idle_rpm"], 0), (1.5, profile["idle_rpm"], 0), (1.6, profile["idle_rpm"], 1),
                 (7.6, profile["limiter_rpm"] * 0.97, 1), (7.7, profile["limiter_rpm"] * 0.97, 0),
                 (11.7, profile["idle_rpm"], 0), (13.7, profile["idle_rpm"], 0)]
    times = np.array([k[0] for k in keyframes])
    block = int(0.01 * rate)
    total = int(times[-1] * rate)
    out = np.zeros(total)
    phases = {key: 0.0 for key in loops}
    for start in range(0, total, block):
        t = start / rate
        rpm = float(np.interp(t, times, [k[1] for k in keyframes]))
        load = float(np.interp(t, times, [k[2] for k in keyframes]))
        on = float(smoothstep((load - knee * 0.4) / knee))
        if rpm < profile["idle_rpm"] * 1.15:
            on *= 0.5
        weights = point_weights(profile["points"], rpm)
        n = min(block, total - start)
        for (kind, ref), loop in loops.items():
            w = weights[profile["points"].index(ref)] * (on if kind == "on" else 1 - on)
            speed = float(np.clip(rpm / ref, 0.7, 1.45))
            pos = phases[(kind, ref)] + speed * np.arange(n)
            phases[(kind, ref)] = (phases[(kind, ref)] + speed * n) % len(loop)
            if w > 0:
                idx = pos % len(loop)
                i0 = idx.astype(int)
                frac = idx - i0
                out[start : start + n] += w * (loop[i0] * (1 - frac) + loop[(i0 + 1) % len(loop)] * frac)
    return out


# ============================== Programme ==============================


def build(name: str, refs: Path, out_root: Path) -> dict:
    profile = PROFILES[name]
    out = out_root / name
    signals: dict[str, tuple[int, np.ndarray]] = {}
    report: dict = {"profil": name, "prefixe": profile["prefix"], "sources": {}, "boucles": {}, "evenements": {}}
    for key, spec in profile["sources"].items():
        path = refs / spec["file"]
        sr, x = read_wav(path)
        x = highpass(x, sr)
        signals[key] = (sr, x)
        entry = {"fichier": spec["file"], "duree_s": round(len(x) / sr, 3), "frequence_hz": sr, "rms_dbfs": round(db(x), 1)}
        if "rpm" in spec:
            mid = x[len(x) // 4 : 3 * len(x) // 4]
            measured = line_rpm(mid, sr, spec["rpm"])
            entry["regime_attendu"], entry["regime_mesure"] = spec["rpm"], round(measured)
            spec = dict(spec, measured=measured)
            profile["sources"][key] = spec
        report["sources"][key] = entry

    loops: dict = {}
    for (kind, ref), spec in profile["loops"].items():
        sr, x = signals[spec["source"]]
        if "span" in spec:
            a, b = sweep_fit(x, sr, spec["span"], spec["approx"])
            t0, t1 = spec["span"]
            seg = x[int(t0 * sr) : int(t1 * sr)]
            rpm_t = a + b * (np.arange(len(seg)) / sr)
            how = f"balayage {t0}–{t1} s : {a:.0f} → {a + b * (t1 - t0):.0f} tr/min, déplié à {ref}"
        else:
            src_rpm = profile["sources"][spec["source"]]["measured"]
            seg = x
            rpm_t = np.full(len(seg), src_rpm)
            how = f"boucle stable à {src_rpm:.0f} tr/min, transposée × {ref / src_rpm:.3f}"
        steady = warp(seg, sr, rpm_t, ref, duration=4.0)
        steady = to_out_rate(steady, sr)
        loop = make_loop(steady, OUT_RATE, ref)
        loop = level(loop, profile["rms_on"] if kind == "on" else profile["rms_off"])
        loops[(kind, ref)] = loop
        file = f"{kind}.{ref}.wav"
        write_wav(out / file, loop)
        report["boucles"][f"{kind}.{ref}"] = {
            "fichier": file,
            "methode": how,
            "duree_s": round(len(loop) / OUT_RATE, 3),
            "regime_verifie": round(line_rpm(loop, OUT_RATE, ref)),
            "rms_dbfs": round(db(loop), 1),
        }

    for name_, spec in profile["events"].items():
        sr, x = signals[spec["source"]]
        t0, t1 = spec["span"]
        seg = to_out_rate(x[int(t0 * sr) : int(t1 * sr)], sr)
        fin, fout = (int(f * OUT_RATE) for f in spec["fade"])
        env = np.ones(len(seg))
        env[:fin] = np.linspace(0, 1, fin)
        env[len(seg) - fout :] *= np.linspace(1, 0, fout)
        seg = level(seg * env, profile["rms_event"])
        # Identifiants du manifeste en minuscules : `<préfixe>start`, `<préfixe>stop`, `<préfixe>stall`.
        file = f"{name_.lower()}.wav"
        write_wav(out / file, seg)
        report["evenements"][name_] = {"fichier": file, "extrait": f"{spec['source']} {t0}–{t1} s",
                                        "duree_s": round(len(seg) / OUT_RATE, 3)}

    demo = render_demo(profile, loops)
    demo = level(demo, -16.0)
    write_wav(out / "demo_montee_lever_de_pied.wav", demo)
    report["demo"] = "demo_montee_lever_de_pied.wav : ralenti, montée en charge 6 s, lever de pied 4 s, ralenti"
    (out / "rapport.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("profile", choices=sorted(PROFILES))
    parser.add_argument("refs", type=Path, help="dossier des enregistrements d'origine")
    parser.add_argument("--out", type=Path, default=ROOT / "build" / "audio" / "engines")
    args = parser.parse_args(argv)
    # Console Windows : sortie en UTF-8 (flèches et accents du rapport).
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    report = build(args.profile, args.refs, args.out)
    print(json.dumps(report, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
