"""Synthèse procédurale des sons ORIGINAUX d'Automotive World (lot 0.8).

Tous les sons sont calculés ici, à partir de formules (oscillateurs, bruit
filtré, enveloppes) et d'une graine fixe : aucun échantillon, aucune musique ni
banque de sons tiers. La sortie est déterministe (mêmes octets à chaque
exécution) et décrite par src/shared/Assets/AssetManifest.luau.

Les fichiers produits (WAV 16 bits mono, 22 050 Hz) sont des ressources
PROVISOIRES à écouter, valider puis téléverser par le propriétaire ; rien n'est
téléversé par ce script et aucun identifiant Roblox n'est créé.

Boucles : moteurs (1 s), ambiances (6 s) et radio (16 à 24 s) bouclent sans
raccord audible (fréquences entières sur la durée, bruit filtré circulairement).

Usage : python tools/audio/synth.py [--out build/audio] [--list]
"""

from __future__ import annotations

import argparse
import sys
import wave
from pathlib import Path
from typing import Callable

import numpy as np

RATE = 22050
ROOT = Path(__file__).resolve().parents[2]


# ============================== OUTILS ==============================


def _time(seconds: float) -> np.ndarray:
    return np.arange(int(round(seconds * RATE))) / RATE


def _rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def _shaped_noise(seconds: float, seed: int, low: float, high: float, tilt: float = 0.0) -> np.ndarray:
    """Bruit blanc filtré en bande (FFT circulaire : la boucle est continue)."""
    n = int(round(seconds * RATE))
    spectrum = np.fft.rfft(_rng(seed).standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / RATE)
    band = ((freqs >= low) & (freqs <= high)).astype(float)
    # Pente spectrale (dB/octave rapportés à 1 kHz) pour colorer le bruit.
    with np.errstate(divide="ignore"):
        slope = np.where(freqs > 0, (freqs / 1000.0) ** (tilt / 6.02), 0.0)
    out = np.fft.irfft(spectrum * band * slope, n)
    return out / (np.max(np.abs(out)) + 1e-9)


def _envelope(n: int, attack: float, release: float) -> np.ndarray:
    env = np.ones(n)
    a, r = int(attack * RATE), int(release * RATE)
    if a > 0:
        env[:a] = np.linspace(0, 1, a)
    if r > 0:
        env[-r:] *= np.exp(-np.linspace(0, 6, r))
    return env


def _harmonics(t: np.ndarray, base: float, weights: list[float], jitter: float = 0.0, seed: int = 0) -> np.ndarray:
    """Somme d'harmoniques ENTIÈRES (Hz arrondis : boucle exacte d'une seconde)."""
    out = np.zeros_like(t)
    rng = _rng(seed)
    for k, weight in enumerate(weights, start=1):
        freq = round(base * k)
        phase = rng.uniform(0, 2 * np.pi)
        out += weight * np.sin(2 * np.pi * freq * t + phase + jitter * np.sin(2 * np.pi * 3 * t))
    return out


def _normalize(signal: np.ndarray, peak: float = 0.8) -> np.ndarray:
    return signal / (np.max(np.abs(signal)) + 1e-9) * peak


# ============================== MOTEURS ==============================

# Régime de référence de chaque couche (tr/min) : le client règle la vitesse
# de lecture (PlaybackSpeed = régime / référence) et le fondu entre couches.
ENGINE_LAYERS = {"idle": 850, "low": 2000, "mid": 3500, "high": 5500}


def engine_combustion(layer: str, diesel: bool) -> np.ndarray:
    rpm = ENGINE_LAYERS[layer]
    t = _time(1.0)
    firing = rpm / 60 * 2  # quatre cylindres, quatre temps
    if diesel:
        weights = [1.0, 0.7, 0.55, 0.4, 0.35, 0.25, 0.2, 0.15]
        knock = _shaped_noise(1.0, 31 + rpm, 1500, 5000) * 0.25
    else:
        weights = [1.0, 0.5, 0.35, 0.2, 0.12, 0.08]
        knock = _shaped_noise(1.0, 37 + rpm, 2000, 7000) * 0.08
    tone = _harmonics(t, firing, weights, jitter=0.15, seed=rpm)
    # Pulsation d'allumage : modulation d'amplitude à la fréquence de cycle.
    pulse = 0.75 + 0.25 * np.sin(2 * np.pi * round(firing / 2) * t)
    intake = _shaped_noise(1.0, 41 + rpm, 80, 900 if layer in ("idle", "low") else 2500, tilt=-3) * 0.35
    return _normalize(tone * pulse + intake + knock, 0.75)


def engine_electric(layer: str) -> np.ndarray:
    t = _time(1.0)
    if layer == "hum":
        signal = _harmonics(t, 100, [1.0, 0.3, 0.1], seed=5) + _shaped_noise(1.0, 51, 60, 400) * 0.2
    elif layer == "whine":
        signal = _harmonics(t, 620, [1.0, 0.15], seed=6) * 0.8 + _shaped_noise(1.0, 52, 600, 2000) * 0.1
    else:  # inverter : sifflement aigu de l'onduleur
        signal = _harmonics(t, 2400, [1.0, 0.2], seed=7) * 0.5 + _shaped_noise(1.0, 53, 2000, 6000) * 0.05
    return _normalize(signal, 0.6)


# ============================== EFFETS ==============================


def effect(name: str) -> np.ndarray:
    if name == "skid":
        t = _time(1.0)
        squeal = _harmonics(t, 900, [1.0, 0.4, 0.2], jitter=2.0, seed=11)
        return _normalize(squeal * 0.6 + _shaped_noise(1.0, 61, 600, 4000) * 0.5, 0.7)
    if name == "wind":
        return _normalize(_shaped_noise(2.0, 62, 40, 3000, tilt=-6), 0.6)
    if name == "impact":
        t = _time(0.6)
        thump = np.sin(2 * np.pi * 70 * t * (1 - 0.4 * t)) * np.exp(-t * 18)
        crunch = _shaped_noise(0.6, 63, 300, 6000) * np.exp(-t * 9)
        return _normalize(thump + crunch * 0.6, 0.9)
    # shift : petit claquement mécanique
    t = _time(0.15)
    return _normalize(_shaped_noise(0.15, 64, 800, 5000) * np.exp(-t * 60), 0.5)


# ============================== AMBIANCES ==============================


def _events(seconds: float, seed: int, count: int, make: Callable[[np.random.Generator], np.ndarray]) -> np.ndarray:
    """Petits événements ponctuels répartis sur la boucle (avec retour au début)."""
    n = int(round(seconds * RATE))
    out = np.zeros(n)
    rng = _rng(seed)
    for _ in range(count):
        sound = make(rng)
        start = int(rng.uniform(0, n))
        idx = (start + np.arange(len(sound))) % n
        out[idx] += sound
    return out


def _chirp(rng: np.random.Generator) -> np.ndarray:
    t = _time(rng.uniform(0.08, 0.2))
    f0 = rng.uniform(2500, 4200)
    sweep = f0 * (1 + rng.uniform(-0.3, 0.3) * t / t[-1])
    return np.sin(2 * np.pi * np.cumsum(sweep) / RATE) * np.hanning(len(t)) * 0.25


def _gull(rng: np.random.Generator) -> np.ndarray:
    t = _time(0.5)
    sweep = rng.uniform(900, 1200) * (1 - 0.35 * t / t[-1])
    return np.sin(2 * np.pi * np.cumsum(sweep) / RATE) * np.hanning(len(t)) * 0.2


def _horn(rng: np.random.Generator) -> np.ndarray:
    t = _time(rng.uniform(0.25, 0.6))
    f = rng.choice([330, 392, 415])
    tone = np.sign(np.sin(2 * np.pi * f * t)) * 0.4 + np.sin(2 * np.pi * f * 1.26 * t) * 0.3
    return tone * _envelope(len(t), 0.02, 0.1) * 0.05


def _clank(rng: np.random.Generator) -> np.ndarray:
    t = _time(0.4)
    f = rng.uniform(300, 700)
    return np.sin(2 * np.pi * f * t) * np.exp(-t * 14) * 0.15


def _pass_by(rng: np.random.Generator) -> np.ndarray:
    t = _time(2.5)
    f = rng.uniform(140, 220) * (1.1 - 0.2 * t / t[-1])
    tone = np.sin(2 * np.pi * np.cumsum(f) / RATE)
    return tone * np.hanning(len(t)) * 0.12


def ambience(name: str) -> np.ndarray:
    seconds = 6.0
    if name == "city":
        bed = _shaped_noise(seconds, 71, 60, 2500, tilt=-4) * 0.5
        extra = _events(seconds, 72, 3, _horn) + _events(seconds, 73, 2, _pass_by)
    elif name == "suburb":
        bed = _shaped_noise(seconds, 74, 80, 2000, tilt=-6) * 0.25
        extra = _events(seconds, 75, 6, _chirp) + _events(seconds, 76, 1, _pass_by)
    elif name == "harbour":
        bed = _shaped_noise(seconds, 77, 40, 1200, tilt=-5) * 0.5
        extra = _events(seconds, 78, 4, _clank) + _events(seconds, 79, 2, _gull)
    elif name == "mountain":
        bed = _shaped_noise(seconds, 80, 30, 1500, tilt=-7) * 0.45
        extra = _events(seconds, 81, 2, _chirp)
    elif name == "countryside":
        bed = _shaped_noise(seconds, 82, 100, 3000, tilt=-6) * 0.2
        extra = _events(seconds, 83, 10, _chirp)
    elif name == "circuit":
        bed = _shaped_noise(seconds, 84, 60, 2000, tilt=-4) * 0.35
        extra = _events(seconds, 85, 3, _pass_by) * 2
    elif name == "coast":
        t = _time(seconds)
        waves = 0.6 + 0.4 * np.sin(2 * np.pi * t / 3.0)  # houle : 2 vagues par boucle
        bed = _shaped_noise(seconds, 86, 100, 5000, tilt=-3) * waves * 0.6
        extra = _events(seconds, 87, 3, _gull)
    else:  # rain
        bed = _shaped_noise(seconds, 88, 800, 9000, tilt=-2) * 0.6
        extra = _events(seconds, 89, 40, lambda r: _shaped_noise(0.02, int(r.integers(1e6)), 2000, 8000) * 0.15)
    return _normalize(bed + extra, 0.6)


# ============================== INTERFACE ==============================


def ui(name: str) -> np.ndarray:
    def tone(freqs: list[float], length: float) -> np.ndarray:
        t = _time(length)
        out = sum(np.sin(2 * np.pi * f * t) for f in freqs)
        return out * _envelope(len(t), 0.005, length * 0.8)

    if name == "info":
        return _normalize(np.concatenate([tone([880], 0.09), tone([1320], 0.14)]), 0.5)
    if name == "warning":
        return _normalize(np.concatenate([tone([660, 990], 0.12), np.zeros(800), tone([660, 990], 0.12)]), 0.6)
    if name == "critical":
        part = tone([523, 784], 0.16)
        return _normalize(np.concatenate([part, np.zeros(600), part, np.zeros(600), part]), 0.7)
    return _normalize(tone([1800], 0.03), 0.35)  # click


# ============================== RADIO (compositions originales) ==============================

# Accords (demi-tons depuis la tonique) et tempo de chaque station.
STATIONS = {
    "ville": {"bpm": 112, "root": 57, "chords": [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]], "bars": 8},
    "route": {"bpm": 96, "root": 52, "chords": [[0, 7, 12], [5, 12, 17], [3, 10, 15], [10, 17, 22]], "bars": 8},
    "nuit": {"bpm": 80, "root": 50, "chords": [[0, 3, 7, 10], [5, 8, 12, 15], [8, 12, 15, 19], [7, 10, 14, 17]], "bars": 6},
}


def _midi(note: float) -> float:
    return 440.0 * 2 ** ((note - 69) / 12)


def radio(name: str) -> np.ndarray:
    spec = STATIONS[name]
    beat = 60 / spec["bpm"]
    bar = beat * 4
    total = bar * spec["bars"]
    n = int(round(total * RATE))
    out = np.zeros(n)
    rng = _rng(sum(map(ord, name)))  # graine stable (hash() varie entre exécutions)
    for b in range(spec["bars"]):
        chord = spec["chords"][b % len(spec["chords"])]
        start = int(b * bar * RATE)
        t = _time(bar)
        # Nappe : accords doux (sinus et quinte légère).
        pad = sum(np.sin(2 * np.pi * _midi(spec["root"] + 12 + i) * t) for i in chord) / len(chord)
        pad *= _envelope(len(t), 0.2, 0.4) * 0.35
        # Basse : tonique de l'accord, une note par temps.
        bass = np.zeros(len(t))
        for k in range(4):
            seg = _time(beat)
            note = _midi(spec["root"] - 12 + chord[0])
            s = int(k * beat * RATE)
            bass[s : s + len(seg)] += np.sin(2 * np.pi * note * seg) * np.exp(-seg * 3) * 0.45
        # Mélodie : notes de l'accord choisies par la graine (composition générée).
        melody = np.zeros(len(t))
        for k in range(8):
            seg = _time(beat / 2)
            if rng.uniform() < 0.6:
                note = _midi(spec["root"] + 24 + chord[int(rng.integers(len(chord)))])
                s = int(k * beat / 2 * RATE)
                melody[s : s + len(seg)] += (
                    np.sin(2 * np.pi * note * seg) * _envelope(len(seg), 0.01, beat / 2 * 0.7) * 0.18
                )
        # Batterie : grosse caisse (sinus descendant) et charleston (bruit bref).
        drums = np.zeros(len(t))
        for k in range(4):
            kick = _time(0.25)
            s = int(k * beat * RATE)
            drums[s : s + len(kick)] += np.sin(2 * np.pi * 55 * kick * (1 + 2 * np.exp(-kick * 30))) * np.exp(-kick * 12) * 0.5
            hat = _shaped_noise(0.05, 900 + b * 8 + k, 5000, 10000) * np.exp(-_time(0.05) * 80) * 0.08
            h = int((k + 0.5) * beat * RATE)
            drums[h : h + len(hat)] += hat
        segment = pad + bass + melody + drums
        end = min(n, start + len(segment))
        out[start:end] += segment[: end - start]
    return _normalize(out, 0.7)


# ============================== CATALOGUE ==============================


def catalogue() -> dict[str, Callable[[], np.ndarray]]:
    """Nom de fichier → fonction de synthèse (même liste que le manifeste)."""
    items: dict[str, Callable[[], np.ndarray]] = {}
    for layer in ENGINE_LAYERS:
        items[f"engine_petrol_{layer}.wav"] = lambda layer=layer: engine_combustion(layer, False)
        items[f"engine_diesel_{layer}.wav"] = lambda layer=layer: engine_combustion(layer, True)
    for layer in ("hum", "whine", "inverter"):
        items[f"engine_electric_{layer}.wav"] = lambda layer=layer: engine_electric(layer)
    for name in ("skid", "wind", "impact", "shift"):
        items[f"effect_{name}.wav"] = lambda name=name: effect(name)
    for name in ("city", "suburb", "harbour", "mountain", "countryside", "circuit", "coast", "rain"):
        items[f"ambience_{name}.wav"] = lambda name=name: ambience(name)
    for name in ("info", "warning", "critical", "click"):
        items[f"ui_{name}.wav"] = lambda name=name: ui(name)
    for name in STATIONS:
        items[f"radio_{name}.wav"] = lambda name=name: radio(name)
    return items


def write_wav(path: Path, signal: np.ndarray) -> None:
    data = (np.clip(signal, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(data)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", default=str(ROOT / "build" / "audio"))
    parser.add_argument("--list", action="store_true", help="affiche les fichiers sans les produire")
    args = parser.parse_args(argv)
    items = catalogue()
    if args.list:
        for name in items:
            print(name)
        return 0
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    total = 0
    for name, make in items.items():
        signal = make()
        write_wav(out / name, signal)
        total += len(signal)
    print(f"{len(items)} sons synthétisés ({total / RATE:.1f} s au total) -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
