"""Boucles de moteur tirées d'ENREGISTREMENTS libres (lot AUDIO-01), pour un profil sonore du jeu.

Entrée : les fichiers d'origine téléchargés par le propriétaire, hors dépôt (registre : docs/audio/SONS_TIERS.md).
Sortie (dans `build/`, jamais versionnée), une sous-partie par variante de micro :
- une boucle par régime de référence, en charge (`on.<tr/min>`) et en décharge (`off.<tr/min>`) ;
- des sons ponctuels (`start`, `stop`, `stall`) ;
- `rapport.json` et une DÉMO d'écoute rendue avec le mélange du jeu (Shared/Audio/EngineAudioModel.profileLayers).

Version 2 (2026-11-05), après l'écoute du propriétaire (« on entend très bien le découpage ») :
- chaque point vient, autant que possible, d'un même BALAYAGE CONTINU (montée en charge, descente pied levé) : timbre
  cohérent d'un point au voisin ; points plus rapprochés (facteur ~1,3) ;
- boucles longues (~1,6 s) : extrait déplié à régime constant puis allongé par GRAINS alignés sur le cycle moteur
  (6 cycles, recouvrement de moitié, fenêtre de Hann, ordre pseudo-aléatoire à graine fixe) : pas de répétition
  courte audible ;
- enveloppe lente aplanie avant les grains (un balayage devient plus fort en montant : sans cela, sauts de niveau
  entre grains) ; niveaux suivant une courbe régulière du régime (plus fort en montant) ;
- démo : fondus à puissance constante et volumes interpolés échantillon par échantillon (plus d'escalier).

Mesure du régime : raie d'allumage d'un 4 cylindres (fréquence × 30 = tr/min), cherchée à ±12 % d'un régime approché
(points d'ancrage relevés à l'analyse) pour écarter les raies d'ordre 1, 2,5 ou 4.

Usage : python -I tools/audio/engine_loops.py brio <dossier des enregistrements> [--out build/audio/engines]
        [--trace build/audio/engines/brio_trace.csv]   (relevé : lune run tests/lune/tools/engine-sound-trace.luau)
L'assistant ne peut pas écouter : le jugement à l'oreille (démos et boucles) revient au propriétaire.
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

# Brio : pack « The Dyno Sessions: 190E » (Chippy569, CC0). Points communs aux boucles en charge et en décharge
# (Shared/Audio/EngineSoundProfiles). Une source est soit STABLE (régime attendu, remesuré), soit un BALAYAGE décrit
# par des ancres (temps s, régime approché) : chaque point y prend une fenêtre de ±10 % de son régime.
BRIO_POINTS = [1000, 1300, 1700, 2200, 2900, 3800, 4900, 6300]

BRIO_MOTEUR = {
    "label": "micro du compartiment moteur (DPA 4062) : montée et descente continues, timbre le plus homogène",
    "sources": {
        # Ralenti stable à la fin de la descente (6,4 à 8,6 s), ~1 420 tr/min.
        "ralenti": {"file": "162502__chippy569__18_medsweep_4062.wav", "rpm": 1420, "span": (6.4, 8.6)},
        "montee": {
            "file": "162499__chippy569__acceleration-sweep-4062.wav",
            # Arrêt à 3,55 s (~6 400 tr/min) : au-delà, le moteur approche du rupteur du banc (coupures d'allumage, niveau
            # instable dans la boucle de 6 300 tr/min).
            "anchors": [(0.9, 1626), (1.3, 2153), (1.7, 2856), (2.1, 3560), (2.6, 4521), (3.2, 5752), (3.55, 6400)],
        },
        "descente": {
            "file": "162502__chippy569__18_medsweep_4062.wav",
            "anchors": [(0.0, 6899), (0.5, 6108), (1.0, 5142), (1.5, 4438), (2.0, 3560), (2.5, 3076), (3.0, 2417),
                        (3.5, 1890), (4.0, 1450), (4.3, 1318)],
        },
        "demarrage": {"file": "162523__chippy569__23_startismall_4062.wav"},
        "demarrage_fort": {"file": "162526__chippy569__23_startbig_4062.wav"},
    },
    "loops": {
        **{("on", p): {"source": "ralenti"} for p in (1000, 1300)},
        **{("on", p): {"source": "montee"} for p in (1700, 2200, 2900, 3800, 4900, 6300)},
        **{("off", p): {"source": "ralenti"} for p in (1000, 1300)},
        **{("off", p): {"source": "descente"} for p in (1700, 2200, 2900, 3800, 4900, 6300)},
    },
}

BRIO_ECHAPPEMENT = {
    "label": "micro d'échappement (Audix D6) : plus « pot d'échappement », mais bas régimes pris sur d'autres prises",
    "sources": {
        "ralenti": {"file": "162515__chippy569__21_500_d6.wav", "rpm": 1030},
        "charge_1300": {"file": "162506__chippy569__19_500_d6.wav", "rpm": 1290},
        "vide_6300": {"file": "162521__chippy569__21_6500_d6.wav", "rpm": 6297},
        "montee": {
            "file": "162501__chippy569__17_shortsweep_d6.wav",
            "anchors": [(0.2, 2021), (0.6, 2944), (1.0, 3955), (1.4, 5098), (1.8, 6152), (2.1, 6812)],
        },
        "descente_haute": {"file": "162504__chippy569__17_medsweep_d6.wav", "anchors": [(1.1, 5977), (2.2, 4966)]},
        "descente": {
            "file": "162504__chippy569__17_medsweep_d6.wav",
            "anchors": [(3.3, 4043), (4.0, 3516), (5.0, 2812), (6.0, 2197), (7.0, 1626), (7.5, 1362)],
        },
        "demarrage": {"file": "162528__chippy569__23_startismall_d6.wav"},
        "demarrage_fort": {"file": "162525__chippy569__23_startbig_d6.wav"},
    },
    "loops": {
        ("on", 1000): {"source": "ralenti"},
        ("on", 1300): {"source": "charge_1300"},
        ("on", 1700): {"source": "charge_1300"},
        **{("on", p): {"source": "montee"} for p in (2200, 2900, 3800, 4900, 6300)},
        ("off", 1000): {"source": "ralenti"},
        ("off", 1300): {"source": "ralenti"},
        **{("off", p): {"source": "descente"} for p in (1700, 2200, 2900, 3800)},
        ("off", 4900): {"source": "descente_haute"},
        ("off", 6300): {"source": "vide_6300"},
    },
}

EVENTS = {
    "Start": {"source": "demarrage", "span": (1.85, 4.6), "fade": (0.01, 0.6)},
    "Stop": {"source": "demarrage_fort", "span": (6.55, 8.2), "fade": (0.05, 0.4)},
    "Stall": {"source": "demarrage_fort", "span": (6.75, 7.9), "fade": (0.02, 0.3)},
}

BRIO = {
    "prefix": "audio.engine.brio.",
    "points": BRIO_POINTS,
    "idle_rpm": 850,
    "limiter_rpm": 7200,
    "variants": {"moteur": BRIO_MOTEUR, "echappement": BRIO_ECHAPPEMENT},
    "events": EVENTS,
    # Courbe de niveau (dBFS RMS) : valeur à 6 300 tr/min et pente par octave de régime. La décharge reste plus
    # discrète que la charge, comme en vrai.
    "level_on": (-14.0, 3.0),
    "level_off": (-20.0, 2.0),
    "rms_event": -18.0,
    # Boîte automatique de la définition (Definitions/Brio.luau) pour la démo des passages : rapports, passage à
    # 6 800 tr/min, couple coupé 0,25 s, décollage au régime de calage du convertisseur (~2 500 tr/min).
    "gearbox": {"ratios": [3.4, 2.1, 1.5, 1.15], "shift_up": 6800, "shift_s": 0.25, "launch_rpm": 2550},
}

# ============================== Comète (lot AUDIO-02) ==============================

# Pack « V8 Lotus » de wikusv (Freesound, CC BY 4.0 : crédit en jeu), un micro par canal ; démarreur de la 190E de la
# Brio (CC0) ; sifflement et décharge du turbo d'une Supra au banc (editboy23, CC0) ; pétarades d'un anti-lag
# (modusmogulus, CC0). Régimes mesurés le 2026-11-06 (raie d'allumage d'un V8 = régime / 15, suivie pas à pas à
# partir d'une crête ; cycle moteur par autocorrélation au ralenti) : docs/lot-audio-02/PLAN_AUDIO_02.md.
COMETE_POINTS = [900, 1300, 1850, 2600, 3700, 5000, 6000]
LOTUS_IDLE = "232274__wikusv__idle.wav"
LOTUS_REVS = "232272__wikusv__idle-and-rev-engine.wav"
LOTUS_PULL = "232271__wikusv__rev-and-pull.wav"
STARTER_190E = "../../brio/freesound/162525__chippy569__23_startbig_d6.wav"
SUPRA = "496171__editboy23__import-car-revs-on-chassis-dyno-with-turbo.wav"
ANTILAG = "797835__modusmogulus__car-antilag-no-cleanup-32float.wav"


def comete_variant(channel: int, label: str) -> dict:
    return {
        "label": label,
        "sources": {
            # Ralenti stable (fichier « Idle ») : ~960 tr/min (raie de 64 Hz, cycle de 125 ms).
            "ralenti": {"file": LOTUS_IDLE, "rpm": 960, "span": (0.5, 6.5), "channel": channel},
            # Retombée continue après un coup de gaz : 3 090 → 1 460 tr/min (9,0–10,2 s), puis 1 420 → 920 tr/min.
            "descente": {
                "file": LOTUS_REVS,
                "channel": channel,
                "anchors": [(9.0, 3087), (9.2, 2766), (9.4, 2392), (9.6, 2109), (9.8, 1905), (10.0, 1650),
                            (10.2, 1460)],
            },
            "descente_basse": {
                "file": LOTUS_REVS,
                "channel": channel,
                "anchors": [(10.9, 1423), (11.0, 1348), (11.2, 1190), (11.4, 1051), (11.6, 920)],
            },
            # Retombée depuis la crête la plus haute : 5 060 → 3 640 tr/min (7,98–8,56 s).
            "retombee_haute": {
                "file": LOTUS_REVS,
                "channel": channel,
                "anchors": [(7.98, 5060), (8.1, 4827), (8.2, 4543), (8.3, 4277), (8.4, 4029), (8.5, 3777),
                            (8.56, 3640)],
            },
            # Sommet de cette crête (~5 000 tr/min), transposé pour la boucle de 6 000 tr/min en décharge.
            "sommet": {"file": LOTUS_REVS, "rpm": 5000, "span": (7.96, 8.12), "channel": channel},
            # Coup de gaz avant le départ : 2 340 → 3 360 tr/min (2,0–2,38 s).
            "coup_de_gaz": {
                "file": LOTUS_PULL,
                "channel": channel,
                "anchors": [(2.0, 2342), (2.1, 2422), (2.2, 2793), (2.3, 3233), (2.38, 3360)],
            },
            # Départ EN CHARGE : montée continue 3 260 → 5 990 tr/min (3,30–4,42 s).
            "montee": {
                "file": LOTUS_PULL,
                "channel": channel,
                "anchors": [(3.30, 3264), (3.40, 3434), (3.50, 3604), (3.60, 3959), (3.70, 4192), (3.80, 4440),
                            (3.90, 4658), (4.00, 4868), (4.10, 5191), (4.20, 5472), (4.30, 5815), (4.42, 5990)],
            },
            "reprise": {"file": LOTUS_REVS, "channel": channel},
            "arret": {"file": LOTUS_REVS, "channel": channel},
            "demarreur": {"file": STARTER_190E},
            "turbo": {"file": SUPRA},
            "antilag": {"file": ANTILAG},
        },
        "loops": {
            ("on", 900): {"source": "ralenti"},
            ("on", 1300): {"source": "ralenti"},
            # Aucune prise EN CHARGE vers 1 850 tr/min : retombée (décharge) en attendant l'écoute du propriétaire.
            ("on", 1850): {"source": "descente"},
            ("on", 2600): {"source": "coup_de_gaz"},
            **{("on", p): {"source": "montee"} for p in (3700, 5000, 6000)},
            ("off", 900): {"source": "ralenti"},
            ("off", 1300): {"source": "descente_basse"},
            **{("off", p): {"source": "descente"} for p in (1850, 2600)},
            **{("off", p): {"source": "retombee_haute"} for p in (3700, 5000)},
            ("off", 6000): {"source": "sommet"},
        },
    }


COMETE = {
    "prefix": "audio.engine.comete.",
    "points": COMETE_POINTS,
    "idle_rpm": 850,
    "limiter_rpm": 8500,
    "divisor": 15.0,
    "variants": {
        "micro_a": comete_variant(0, "pack « V8 Lotus », canal 0 (premier micro de chaque prise)"),
        "micro_b": comete_variant(1, "pack « V8 Lotus », canal 1 (second micro de chaque prise)"),
    },
    "events": {
        # Démarreur de la 190E (0,15–0,98 s, avant que son moteur prenne), enchaîné sur un coup de gaz du V8 Lotus
        # depuis le ralenti (2,2–3,4 s) : décision Q2 du propriétaire.
        "Start": {
            "parts": [
                {"source": "demarreur", "span": (0.15, 0.98), "rms": -30.0},
                {"source": "reprise", "span": (2.2, 3.4), "rms": -18.0},
            ],
            "fade": (0.01, 0.3),
        },
        # Fin du long enregistrement : ralenti puis extinction (32,0–32,5 s).
        "Stop": {"source": "arret", "span": (31.3, 32.62), "fade": (0.05, 0.1)},
        "Stall": {"source": "arret", "span": (31.7, 32.62), "fade": (0.03, 0.1)},
        # Cinq détonations de l'anti-lag (1,58 à 2,19 s).
        "Pops": {"source": "antilag", "span": (1.45, 2.40), "fade": (0.01, 0.1)},
        # Décharge du turbo de la Supra : souffle large après l'arrêt du sifflement (25,55–26,1 s).
        "BlowOff": {"source": "turbo", "span": (25.5, 26.15), "fade": (0.01, 0.25), "band": (1500.0, 14000.0)},
    },
    # Couche « turbo » du jeu : sifflement de la Supra (raie stable vers 10,5 kHz, 23,9–25,45 s), bouclé sur l'extrait
    # naturel (un son presque pur ne se brasse pas par grains, leçon d'AUDIO-03).
    "extra_loops": {"turbo": {"source": "turbo", "span": (23.9, 25.45), "band": (7000.0, 13500.0), "rms": -24.0}},
    "level_on": (-14.0, 3.0),
    "level_off": (-20.0, 2.0),
    "rms_event": -18.0,
    # Boîte à double embrayage de la définition (Definitions/Comete.luau, décision du propriétaire du 2026-11-06) :
    # passage conseillé 8 100 tr/min, couple coupé 0,06 s.
    "gearbox": {"ratios": [3.2, 2.2, 1.65, 1.3], "shift_up": 8100, "shift_s": 0.06, "launch_rpm": 3000},
    "turbo": True,
    "pops": True,
}

PROFILES = {"brio": BRIO, "comete": COMETE}

# ============================== Lecture, écriture ==============================


def read_wav(path: Path, channel: int | None = None) -> tuple[int, np.ndarray]:
    """WAV mono ou multicanal (PCM 16, 24 ou 32 bits, ou flottant 32/64 bits). `channel` : canal gardé (lot AUDIO-02 :
    le pack « V8 Lotus » porte un micro par canal) ; None = moyenne des canaux."""
    if channel is not None or _wave_format(path) != 1:
        # Lecteur RIFF de tools/audio/tire_loops.py (flottant, WAVE_FORMAT_EXTENSIBLE), puis choix du canal.
        return _read_riff(path, channel)
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


def _wave_format(path: Path) -> int:
    """Code de format du bloc « fmt » (1 = PCM entier, 3 = flottant, 0xFFFE = étendu)."""
    data = path.read_bytes()[:64]
    i = data.find(b"fmt ")
    return int.from_bytes(data[i + 8 : i + 10], "little") if i >= 0 else 1


def _read_riff(path: Path, channel: int | None) -> tuple[int, np.ndarray]:
    import struct

    data = path.read_bytes()
    fmt, samples, pos = None, None, 12
    while pos + 8 <= len(data):
        tag, size = data[pos : pos + 4], struct.unpack("<I", data[pos + 4 : pos + 8])[0]
        body = data[pos + 8 : pos + 8 + size]
        if tag == b"fmt ":
            code, channels, rate = struct.unpack("<HHI", body[:8])
            bits = struct.unpack("<H", body[14:16])[0]
            if code == 0xFFFE and len(body) >= 26:
                code = struct.unpack("<H", body[24:26])[0]
            fmt = (code, channels, rate, bits)
        elif tag == b"data":
            samples = body
        pos += 8 + size + (size & 1)
    if fmt is None or samples is None:
        raise ValueError(f"{path.name} : bloc fmt ou data absent")
    code, channels, rate, bits = fmt
    width = bits // 8
    raw = samples[: len(samples) - len(samples) % (width * channels)]
    if code == 3:
        x = np.frombuffer(raw, dtype="<f4" if bits == 32 else "<f8").astype(np.float64)
    elif bits == 16:
        x = np.frombuffer(raw, dtype="<i2") / 32768.0
    elif bits == 24:
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3).astype(np.int64)
        v = b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16)
        x = np.where(v & 0x800000, v - 0x1000000, v) / 8388608.0
    elif bits == 32:
        x = np.frombuffer(raw, dtype="<i4") / 2147483648.0
    else:
        raise ValueError(f"{path.name} : format {code}, {bits} bits non pris en charge")
    frames = x.reshape(-1, channels)
    return rate, (frames.mean(axis=1) if channel is None else frames[:, min(channel, channels - 1)])


def write_wav(path: Path, signal: np.ndarray, rate: int = OUT_RATE) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = np.clip(np.round(signal * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data.tobytes())


# ============================== Mesure du régime ==============================


def line_rpm(segment: np.ndarray, sr: int, expected: float | None = None, divisor: float = 30.0) -> float:
    """Régime (tr/min) d'un extrait : raie d'allumage la plus forte (régime / `divisor` Hz : 30 pour un 4 cylindres,
    15 pour un V8, lot AUDIO-02), cherchée sur la plage de 750 à 7 800 tr/min ou à ±12 % du régime attendu."""
    n = len(segment)
    nfft = 1 << int(np.ceil(np.log2(max(n, 2) * 8)))
    mag = np.abs(np.fft.rfft(segment * np.hanning(n), nfft))
    freqs = np.fft.rfftfreq(nfft, 1 / sr)
    lo, hi = (
        (750.0 / divisor, 7800.0 / divisor)
        if expected is None
        else (expected / divisor * 0.88, expected / divisor * 1.12)
    )
    band = np.where((freqs > lo) & (freqs < hi))[0]
    i = band[np.argmax(mag[band])]
    if 0 < i < len(mag) - 1:
        a, b, c = np.log(mag[i - 1] + 1e-12), np.log(mag[i] + 1e-12), np.log(mag[i + 1] + 1e-12)
        i = i + 0.5 * (a - c) / (a - 2 * b + c + 1e-12)
    return float(i * sr / nfft * divisor)


def sweep_fit(
    signal: np.ndarray, sr: int, span: tuple[float, float], approx: tuple[float, float], divisor: float = 30.0
) -> tuple[float, float]:
    """Régime linéaire r(t) = a + b·t (t depuis le début de l'extrait) : mesures par trames de 0,08 s cherchées à
    ±12 % du régime approché, valeurs à plus de 8 % d'une première droite écartées."""
    t0, t1 = span
    win, hop = int(0.08 * sr), int(0.02 * sr)
    times, rpms = [], []
    for start in range(int(t0 * sr), int(t1 * sr) - win, hop):
        t = (start + win / 2) / sr - t0
        guess = approx[0] + (approx[1] - approx[0]) * (t / (t1 - t0))
        times.append(t)
        rpms.append(line_rpm(signal[start : start + win], sr, guess, divisor))
    tt, r = np.array(times), np.array(rpms)
    b, a = np.polyfit(tt, r, 1)
    keep = np.abs(r - (a + b * tt)) / (a + b * tt) < 0.08
    if keep.sum() >= 4:
        b, a = np.polyfit(tt[keep], r[keep], 1)
    return float(a), float(b)


def window_for(anchors: list[tuple[float, float]], rpm: float, spread: float = 1.10, min_cycles: int = 8):
    """Fenêtre (début, fin) d'un balayage où le régime approché reste à ±10 % de `rpm`, élargie si besoin pour
    contenir au moins `min_cycles` cycles moteur (variété des grains), sans sortir du balayage."""
    minimum = max(0.22, min_cycles * 120.0 / rpm)
    times = np.array([a[0] for a in anchors])
    rpms = np.array([a[1] for a in anchors])
    fine_t = np.linspace(times[0], times[-1], 2000)
    fine_r = np.interp(fine_t, times, rpms)
    inside = np.where((fine_r >= rpm / spread) & (fine_r <= rpm * spread))[0]
    if len(inside) == 0:
        raise ValueError(f"{rpm} tr/min hors du balayage")
    t0, t1 = fine_t[inside[0]], fine_t[inside[-1]]
    if t1 - t0 < minimum:
        mid = (t0 + t1) / 2
        t0, t1 = mid - minimum / 2, mid + minimum / 2
        if t0 < times[0]:
            t0, t1 = times[0], times[0] + minimum
        if t1 > times[-1]:
            t0, t1 = max(times[0], times[-1] - minimum), times[-1]
    return float(t0), float(t1), float(np.interp(t0, times, rpms)), float(np.interp(t1, times, rpms))


# ============================== Traitement ==============================


def warp(signal: np.ndarray, sr: int, rpm_of_t, target: float, duration: float) -> np.ndarray:
    """Rééchantillonne pour un régime CONSTANT `target` en conservant la phase moteur ∫ r(t) dt."""
    phase = np.concatenate([[0.0], np.cumsum(rpm_of_t[:-1]) / sr])
    n_out = int(min(duration, phase[-1] / target) * sr)
    src_index = np.interp(target * np.arange(n_out) / sr, phase, np.arange(len(signal)))
    return np.interp(src_index, np.arange(len(signal)), signal)


def to_out_rate(signal: np.ndarray, sr: int) -> np.ndarray:
    """Ramène à 48 kHz : filtre passe-bas par FFT, puis rééchantillonnage."""
    if sr == OUT_RATE:
        return signal
    spec = np.fft.rfft(signal)
    spec[np.fft.rfftfreq(len(signal), 1 / sr) > 0.45 * OUT_RATE] = 0
    smooth = np.fft.irfft(spec, len(signal))
    n_out = int(len(signal) * OUT_RATE / sr)
    # Indices en flottants : sous Windows, `np.arange` donne des entiers 32 bits et `indice × 96 000` débordait
    # au-delà de ~0,47 s de son (positions fausses, donc coupures entendues par le propriétaire, versions 1 et 2).
    positions = np.arange(n_out, dtype=np.float64) * (sr / OUT_RATE)
    return np.interp(positions, np.arange(len(signal), dtype=np.float64), smooth)


def highpass(signal: np.ndarray, sr: int, cutoff: float = 25.0) -> np.ndarray:
    """Retire la composante continue et l'infra-grave sous `cutoff` Hz."""
    spec = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / sr)
    spec *= 1 / (1 + (cutoff / np.maximum(freqs, 1e-3)) ** 4)
    return np.fft.irfft(spec, len(signal))


def flatten(signal: np.ndarray, sr: int, rpm: float, cycles: int = 6, strength: float = 1.0) -> np.ndarray:
    """Aplanit l'enveloppe LENTE (moyenne quadratique glissante sur `cycles` cycles moteur) : un balayage devient plus
    fort en montant ; sans cela, des grains pris à des instants différents s'enchaînent avec des sauts de niveau
    (cause principale du « découpage » entendu par le propriétaire, version 1). Les impulsions d'allumage, plus
    courtes qu'un cycle, sont conservées. `strength` < 1 : aplanissement partiel (irrégularité naturelle gardée)."""
    width = max(3, int(cycles * 120.0 / rpm * sr))
    kernel = np.hanning(width)
    kernel /= kernel.sum()
    padded = np.pad(signal**2, width, mode="reflect")
    env = np.sqrt(np.convolve(padded, kernel, mode="same")[width:-width]) + 1e-9
    return signal * (np.mean(env) / env) ** strength


def extend(signal: np.ndarray, sr: int, rpm: float, seconds: float = 1.7, cycles: int = 6, seed: int = 0) -> np.ndarray:
    """Allonge un extrait à régime constant par grains de `cycles` cycles moteur, recouvrement de moitié (fenêtre de
    Hann périodique, somme constante), pris à des débuts alignés sur le cycle, dans un ordre pseudo-aléatoire sans
    répétition immédiate. Les grains étant en phase (même régime, mêmes bornes de cycle), le raccord est continu."""
    cycle = 120.0 / rpm * sr
    usable = int((len(signal) - 1) // cycle)
    cycles = max(2, min(cycles, usable - 1))
    grain = int(round(cycles * cycle))
    hop = grain / 2
    starts = [int(round(k * cycle)) for k in range(0, usable - cycles + 1)]
    if len(starts) < 2:
        return signal
    window = 0.5 - 0.5 * np.cos(2 * np.pi * np.arange(grain) / grain)
    n_out = int(seconds * sr)
    out = np.zeros(n_out + grain + 2)
    rng = np.random.default_rng(seed)
    previous = -1
    position = 0.0
    while position < n_out:
        choice = int(rng.integers(len(starts)))
        if choice == previous:
            choice = (choice + 1) % len(starts)
        previous = choice
        s = starts[choice]
        p = int(round(position))
        out[p : p + grain] += signal[s : s + grain] * window
        position += hop
    return out[grain // 2 : grain // 2 + n_out]


def make_loop(signal: np.ndarray, sr: int, rpm: float, crossfade: float = 0.04) -> np.ndarray:
    """Boucle sans raccord : longueur = nombre entier de cycles moteur, fin fondue dans le début (puissance constante)."""
    cycle = 120.0 / rpm * sr
    xf = int(crossfade * sr)
    cycles = int((len(signal) - xf) // cycle)
    if cycles < 2:
        raise ValueError("extrait trop court pour boucler")
    length = int(round(cycles * cycle))
    loop = signal[:length].copy()
    ramp = np.sin(np.linspace(0, np.pi / 2, xf)) ** 2
    loop[:xf] = loop[:xf] * np.sqrt(ramp) + signal[length : length + xf] * np.sqrt(1 - ramp)
    return loop


def level(signal: np.ndarray, rms_db: float, peak_db: float = -1.0) -> np.ndarray:
    rms = np.sqrt(np.mean(signal**2)) + 1e-12
    out = signal * (10 ** (rms_db / 20) / rms)
    limit = 10 ** (peak_db / 20)
    if np.max(np.abs(out)) > limit:
        out = np.tanh(out / limit) * limit  # écrêtage doux plutôt qu'une baisse globale
    return out


def db(signal: np.ndarray) -> float:
    return float(20 * np.log10(np.sqrt(np.mean(signal**2)) + 1e-12))


def target_level(curve: tuple[float, float], rpm: float) -> float:
    at_top, per_octave = curve
    return at_top + per_octave * float(np.log2(rpm / 6300))


# ============================== Démo d'écoute ==============================


def amplitudes(points: list[int], rpm: float, load: float, idle: float) -> dict:
    """Amplitudes du mélange du jeu (EngineAudioModel.profileLayers) : poids triangulaires du régime et de la charge,
    transformés à puissance constante (sinus du quart de tour)."""
    knee = 0.25
    t = float(np.clip((load - knee * 0.4) / knee, 0, 1))
    on = t * t * (3 - 2 * t)
    if rpm < idle * 1.15:
        on *= 0.5
    out = {}
    for i, here in enumerate(points):
        below = points[i - 1] if i > 0 else None
        above = points[i + 1] if i + 1 < len(points) else None
        if rpm <= here:
            w = 1.0 if below is None else float(np.clip((rpm - below) / (here - below), 0, 1))
        else:
            w = 1.0 if above is None else float(np.clip((above - rpm) / (above - here), 0, 1))
        a = np.sin(w * np.pi / 2)
        out[("on", here)] = a * np.sin(on * np.pi / 2)
        out[("off", here)] = a * np.cos(on * np.pi / 2)
    return out


def shift_trajectory(profile: dict, step: float = 0.005) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Scénario « passages de rapport » (approché, pour l'écoute) : ralenti 1,5 s ; pied au plancher, décollage au
    régime de calage du convertisseur ; montée dans chaque rapport jusqu'au passage (accélération de moins en moins
    vive) ; à chaque passage, couple coupé (`shift_s`) et régime ramené à régime × rapport suivant / rapport actuel ;
    en 4ᵉ, lever de pied à 6 000 tr/min, descente vers 1 800 tr/min en 5 s, puis ralenti 2 s. La charge est lissée
    comme dans le jeu (constante de temps 0,06 s, AudioController). Retourne (temps, régime, charge)."""
    box = profile["gearbox"]
    idle = profile["idle_rpm"]
    ratios = box["ratios"]
    rpm_t, load_t = [], []
    rpm, load_target = float(idle), 0.0

    def push(seconds: float, rpm_of, load: float):
        nonlocal rpm
        for i in range(int(round(seconds / step))):
            rpm = rpm_of(i * step, rpm)
            rpm_t.append(rpm)
            load_t.append(load)

    push(1.5, lambda t, r: idle, 0.0)
    start = rpm
    push(0.35, lambda t, r: start + (box["launch_rpm"] - start) * min(1.0, t / 0.3), 1.0)
    for gear, ratio in enumerate(ratios):
        # Accélération du régime (tr/min/s) décroissante avec le rapport, ordre de grandeur d'une petite essence.
        climb = 2600.0 * (ratio / ratios[0]) ** 1.3
        top = box["shift_up"] if gear + 1 < len(ratios) else 6000.0
        push(max(0.0, (top - rpm) / climb), lambda t, r: r + climb * step, 1.0)
        if gear + 1 < len(ratios):
            target = top * ratios[gear + 1] / ratio
            # Pendant la coupure, le convertisseur déverrouillé laisse le régime rejoindre celui du rapport suivant.
            push(box["shift_s"], lambda t, r, target=target: r + (target - r) * (1 - np.exp(-step / 0.07)), 0.0)
    high = rpm
    push(5.0, lambda t, r: 1800 + (high - 1800) * np.exp(-t / 1.8), 0.0)
    low = rpm
    push(0.6, lambda t, r: idle + (low - idle) * np.exp(-t / 0.2), 0.0)
    push(2.0, lambda t, r: idle, 0.0)
    loads = np.array(load_t)
    smooth = np.zeros_like(loads)
    k = 1 - np.exp(-step / 0.06)
    for i in range(1, len(loads)):
        smooth[i] = smooth[i - 1] + (loads[i] - smooth[i - 1]) * k
    times = np.arange(len(loads), dtype=np.float64) * step
    return times, np.array(rpm_t), smooth


def trace_trajectory(path: Path, smoothing: float = 0.06) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Relevé de conduite produit par la VRAIE dynamique du jeu (tests/lune/tools/engine-sound-trace.luau) : temps,
    régime et charge réelle (0 pendant un passage de rapport), plus le coup de gaz sonore des rétrogradages. La charge
    est lissée comme dans le jeu (AudioController, constante de temps 0,06 s)."""
    import csv

    rows = list(csv.DictReader(path.open(encoding="utf-8")))
    times = np.array([float(r["temps_s"]) for r in rows])
    rpm = np.array([float(r["regime"]) for r in rows])
    raw = np.array([float(r["charge"]) for r in rows])
    gears = np.array([int(r["rapport"]) for r in rows])
    # Coup de gaz SONORE à chaque rétrogradage (même règle que AudioController : charge au moins 0,35 pendant 0,15 s).
    blip_until = -1.0
    for i in range(1, len(raw)):
        if 1 <= gears[i] < gears[i - 1]:
            blip_until = times[i] + 0.15
        if times[i] < blip_until:
            raw[i] = max(raw[i], 0.35)
    load = np.zeros_like(raw)
    for i in range(1, len(raw)):
        k = 1 - np.exp(-(times[i] - times[i - 1]) / smoothing)
        load[i] = load[i - 1] + (raw[i] - load[i - 1]) * k
    return times, rpm, load


def _bandpass(signal: np.ndarray, sr: int, low: float, high: float) -> np.ndarray:
    spec = np.fft.rfft(signal)
    f = np.maximum(np.fft.rfftfreq(len(signal), 1 / sr), 1e-3)
    spec *= 1 / (1 + (low / f) ** 4) / (1 + (f / high) ** 4)
    return np.fft.irfft(spec, len(signal))


def render_demo(
    profile: dict, loops: dict, rate: int = OUT_RATE, trajectory=None, extras=None, events=None
) -> np.ndarray:
    """Démo d'écoute : par défaut ralenti 1,5 s, montée en charge jusqu'au rupteur en 6 s, lever de pied et descente
    en 4 s, ralenti 2 s ; ou une trajectoire (temps, régime, charge) fournie. Volumes interpolés linéairement dans
    chaque bloc de 5 ms ; transposition bornée 0,7–1,45 comme le jeu."""
    idle, top = profile["idle_rpm"], profile["limiter_rpm"] * 0.97
    if trajectory is None:
        keys = [(0, idle, 0), (1.5, idle, 0), (1.6, idle, 1), (7.6, top, 1), (7.7, top, 0), (11.7, idle, 0), (13.7, idle, 0)]
        times = np.array([k[0] for k in keys], dtype=np.float64)
        rpms = np.array([k[1] for k in keys], dtype=np.float64)
        loads = np.array([k[2] for k in keys], dtype=np.float64)
    else:
        times, rpms, loads = trajectory
    block = int(0.005 * rate)
    total = int(times[-1] * rate)
    out = np.zeros(total)
    phases = {key: 0.0 for key in loops}

    def state(t):
        return float(np.interp(t, times, rpms)), float(np.interp(t, times, loads))

    for start in range(0, total, block):
        n = min(block, total - start)
        rpm0, load0 = state(start / rate)
        rpm1, load1 = state((start + n) / rate)
        amp0 = amplitudes(profile["points"], rpm0, load0, idle)
        amp1 = amplitudes(profile["points"], rpm1, load1, idle)
        ramp = np.arange(n) / n
        for key, loop in loops.items():
            a = amp0[key] + (amp1[key] - amp0[key]) * ramp
            speed = float(np.clip(rpm0 / key[1], 0.7, 1.45))
            pos = phases[key] + speed * np.arange(n)
            phases[key] = (phases[key] + speed * n) % len(loop)
            if np.max(a) > 1e-4:
                idx = pos % len(loop)
                i0 = idx.astype(int)
                frac = idx - i0
                out[start : start + n] += a * (loop[i0] * (1 - frac) + loop[(i0 + 1) % len(loop)] * frac)
    # Lot AUDIO-02 : couche « turbo » (même règle qu'EngineAudioModel.profileLayers : pression selon la charge et le
    # régime au-delà de 2 500 tr/min ; vitesse 0,8 + 0,5 × pression) et événements « Pops » et « BlowOff » au lever de
    # pied (charge de ≥ 0,6 à ≤ 0,15 en 0,1 s ; pétarades au-delà de 55 % du rupteur, décharge au-delà de 3 000 tr/min).
    def smooth(v):
        t = min(max(v, 0.0), 1.0)
        return t * t * (3 - 2 * t)

    if extras and "turbo" in extras:
        loop, phase = extras["turbo"], 0.0
        for start in range(0, total, block):
            n = min(block, total - start)
            rpm, load = state(start / rate)
            boost = smooth(load) * smooth((rpm - 2500) / 3500)
            speed = 0.8 + 0.5 * boost
            pos = phase + speed * np.arange(n)
            phase = (phase + speed * n) % len(loop)
            out[start : start + n] += 0.35 * boost * np.interp(pos % len(loop), np.arange(len(loop)), loop)
    if events:
        last = {"Pops": -9.0, "BlowOff": -9.0}
        cooldown = {"Pops": 0.8, "BlowOff": 1.2}
        t = 0.1
        while t < total / rate:
            rpm0, load0 = state(t - 0.1)
            rpm1, load1 = state(t)
            if load0 >= 0.6 and load1 <= 0.15:
                for name_, ok in (
                    ("Pops", profile.get("pops") and rpm1 >= profile["limiter_rpm"] * 0.55),
                    ("BlowOff", profile.get("turbo") and rpm1 >= 3000),
                ):
                    if ok and name_ in events and t - last[name_] >= cooldown[name_]:
                        last[name_] = t
                        clip = events[name_]
                        i = int(t * rate)
                        end = min(total, i + len(clip))
                        out[i:end] += 0.9 * clip[: end - i]
            t += 0.1
    return out


# ============================== Programme ==============================


def build_variant(profile: dict, name: str, variant: dict, refs: Path, out: Path, trace: Path | None = None) -> dict:
    report: dict = {"variante": name, "description": variant["label"], "sources": {}, "boucles": {}, "evenements": {}}
    # Raie d'allumage : régime / 30 pour un 4 cylindres (Brio), régime / 15 pour un V8 (Comète, lot AUDIO-02).
    divisor = float(profile.get("divisor", 30.0))
    signals: dict = {}
    for key, spec in variant["sources"].items():
        sr, x = read_wav(refs / spec["file"], spec.get("channel"))
        x = highpass(x, sr)
        signals[key] = (sr, x)
        entry = {"fichier": spec["file"], "duree_s": round(len(x) / sr, 3)}
        if "rpm" in spec:
            a, b = spec.get("span", (0.25 * len(x) / sr, 0.75 * len(x) / sr))
            spec["measured"] = line_rpm(x[int(a * sr) : int(b * sr)], sr, spec["rpm"], divisor)
            entry["regime_mesure"] = round(spec["measured"])
        report["sources"][key] = entry

    loops: dict = {}
    for index, ((kind, ref), loop_spec) in enumerate(sorted(variant["loops"].items())):
        src = variant["sources"][loop_spec["source"]]
        sr, x = signals[loop_spec["source"]]
        if "anchors" in src:
            t0, t1, r0, r1 = window_for(src["anchors"], ref)
            a, b = sweep_fit(x, sr, (t0, t1), (r0, r1), divisor)
            seg = x[int(t0 * sr) : int(t1 * sr)]
            rpm_t = a + b * (np.arange(len(seg)) / sr)
            how = f"balayage {t0:.2f}–{t1:.2f} s ({a:.0f} → {a + b * (t1 - t0):.0f} tr/min), déplié et allongé par grains"
        else:
            a0, b0 = src.get("span", (0.0, len(x) / sr))
            seg = x[int(a0 * sr) : int(b0 * sr)]
            rpm_t = np.full(len(seg), src["measured"])
            how = f"prise stable à {src['measured']:.0f} tr/min, transposée × {ref / src['measured']:.3f}"
        steady = to_out_rate(warp(seg, sr, rpm_t, ref, duration=6.0), sr)
        steady = flatten(steady, OUT_RATE, ref, strength=1.0 if "anchors" in src else 0.6)
        if len(steady) < 1.5 * OUT_RATE:
            steady = extend(steady, OUT_RATE, ref, seed=1000 + index)
        loop = make_loop(steady, OUT_RATE, ref)
        loop = level(loop, target_level(profile["level_on" if kind == "on" else "level_off"], ref))
        loops[(kind, ref)] = loop
        file = f"{kind}.{ref}.wav"
        write_wav(out / file, loop)
        report["boucles"][f"{kind}.{ref}"] = {
            "fichier": file,
            "methode": how,
            "duree_s": round(len(loop) / OUT_RATE, 3),
            "regime_verifie": round(line_rpm(loop, OUT_RATE, ref, divisor)),
            "rms_dbfs": round(db(loop), 1),
        }

    events_audio: dict = {}
    extras: dict = {}
    for event, spec in profile["events"].items():
        # Lot AUDIO-02 : un événement peut enchaîner plusieurs parties (démarreur puis reprise du moteur), chacune à son
        # niveau, avec un fondu de 50 ms ; ou être filtré dans une bande (décharge du turbo).
        parts = spec.get("parts") or [{"source": spec["source"], "span": spec["span"]}]
        pieces = []
        for part in parts:
            sr, x = signals[part["source"]]
            t0, t1 = part["span"]
            piece = to_out_rate(x[int(t0 * sr) : int(t1 * sr)], sr)
            if "rms" in part:
                piece = level(piece, part["rms"])
            pieces.append(piece)
        seg = pieces[0]
        xf = int(0.05 * OUT_RATE)
        for piece in pieces[1:]:
            ramp_ = np.linspace(0, 1, xf)
            joined = np.concatenate([seg[:-xf], seg[-xf:] * (1 - ramp_) + piece[:xf] * ramp_, piece[xf:]])
            seg = joined
        if "band" in spec:
            seg = _bandpass(seg, OUT_RATE, *spec["band"])
        t0, t1 = parts[0]["span"][0], parts[-1]["span"][1]
        fin, fout = (int(f * OUT_RATE) for f in spec["fade"])
        env = np.ones(len(seg))
        env[:fin] = np.linspace(0, 1, fin)
        env[len(seg) - fout :] *= np.linspace(1, 0, fout)
        seg = level(seg * env, profile["rms_event"])
        file = f"{event.lower()}.wav"  # identifiants du manifeste en minuscules
        write_wav(out / file, seg)
        report["evenements"][event] = {
            "fichier": file,
            "extrait": " + ".join(f"{p['source']} {p['span'][0]}–{p['span'][1]} s" for p in parts),
        }
        events_audio[event] = seg

    # Lot AUDIO-02 : boucles supplémentaires du profil (couche « turbo »), bouclées sur l'extrait naturel.
    for name_, spec in profile.get("extra_loops", {}).items():
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import tire_loops as tl  # outils communs (boucle d'un extrait naturel)

        sr, x = signals[spec["source"]]
        t0, t1 = spec["span"]
        seg = _bandpass(to_out_rate(x[int(t0 * sr) : int(t1 * sr)], sr), OUT_RATE, *spec["band"])
        seg = tl.flatten(seg, OUT_RATE, seconds=0.2, strength=0.85)
        loop, corr = tl.natural_loop(seg, OUT_RATE)
        loop = level(loop, spec["rms"])
        extras[name_] = loop
        write_wav(out / f"{name_}.wav", loop)
        report["boucles"][name_] = {
            "fichier": f"{name_}.wav",
            "methode": f"{spec['source']} {t0}–{t1} s, bande {spec['band'][0]:.0f}–{spec['band'][1]:.0f} Hz, extrait naturel bouclé (corrélation {corr:.2f})",
            "duree_s": round(len(loop) / OUT_RATE, 3),
            "rms_dbfs": round(db(loop), 1),
        }

    def full(trajectory=None):
        return render_demo(profile, loops, trajectory=trajectory, extras=extras, events=events_audio)

    demo = level(full(), -16.0)
    write_wav(out / f"demo_{name}.wav", demo)
    report["demo"] = f"demo_{name}.wav : ralenti, montée en charge 6 s, lever de pied 4 s, ralenti"
    if "gearbox" in profile:
        shifts = level(full(shift_trajectory(profile)), -16.0)
        write_wav(out / f"demo_passages_{name}.wav", shifts)
        report["demo_passages"] = (
            f"demo_passages_{name}.wav : ralenti, départ pied au plancher, passages 1-2, 2-3, 3-4 à 6 800 tr/min "
            "(couple coupé 0,25 s), lever de pied en 4e, ralenti"
        )
    if trace is not None:
        drive = level(full(trace_trajectory(trace)), -16.0)
        write_wav(out / f"demo_conduite_{name}.wav", drive)
        report["demo_conduite"] = (
            f"demo_conduite_{name}.wav : relevé de la dynamique du jeu ({trace.name}) — départ à fond, montées de "
            "rapports, lever de pied et rétrogradages, rétrogradage forcé, freinage, ralenti"
        )
    (out / "rapport.json").write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
    return report


def build(name: str, refs: Path, out_root: Path, trace: Path | None = None) -> dict:
    profile = PROFILES[name]
    return {
        variant: build_variant(profile, variant, spec, refs, out_root / name / variant, trace)
        for variant, spec in profile["variants"].items()
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("profile", choices=sorted(PROFILES))
    parser.add_argument("refs", type=Path, help="dossier des enregistrements d'origine")
    parser.add_argument("--out", type=Path, default=ROOT / "build" / "audio" / "engines")
    parser.add_argument(
        "--trace", type=Path, default=None, help="relevé de conduite (tests/lune/tools/engine-sound-trace.luau)"
    )
    args = parser.parse_args(argv)
    report = build(args.profile, args.refs, args.out, args.trace)
    sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[attr-defined]
    print(json.dumps(report, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
