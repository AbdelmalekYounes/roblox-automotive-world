"""Contrôles de l'outil de boucles moteur (lot AUDIO-01), sur des signaux synthétiques de régime connu."""

import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

import engine_loops as el  # noqa: E402

SR = 48000


def engine(rpm_of_t: np.ndarray) -> np.ndarray:
    """Moteur 4 cylindres stylisé : raie d'allumage (× 2 par tour) dominante, ordre 1 et ordre 4 plus faibles."""
    phase = 2 * np.pi * np.cumsum(rpm_of_t / 60) / SR  # radians de vilebrequin
    return 0.5 * np.sin(2 * phase) + 0.2 * np.sin(phase) + 0.15 * np.sin(4 * phase)


def test_line_rpm_reads_the_firing_line():
    for rpm in (1000.0, 2556.0, 6200.0):
        signal = engine(np.full(SR, rpm))
        assert abs(el.line_rpm(signal, SR) - rpm) / rpm < 0.01


def test_sweep_is_unfolded_to_a_constant_rpm_loop():
    t = np.arange(int(0.6 * SR)) / SR
    rpm = 3700 + 2600 * t  # 3 700 → 5 260 tr/min en 0,6 s
    signal = engine(rpm)
    a, b = el.sweep_fit(signal, SR, (0.0, 0.6), (3700, 5260))
    assert abs(a - 3700) < 120 and abs(b - 2600) < 400
    steady = el.warp(signal, SR, a + b * t, 4300, duration=4.0)
    loop = el.make_loop(steady, SR, 4300)
    assert abs(el.line_rpm(loop, SR, 4300) - 4300) < 40
    # Longueur = nombre entier de cycles moteur (2 tours), à un échantillon près.
    cycle = 120 / 4300 * SR
    assert abs(len(loop) / cycle - round(len(loop) / cycle)) * cycle <= 1


def test_level_targets_rms_and_limits_peak():
    loud = el.level(engine(np.full(SR, 3000.0)) * 5, -15.0)
    assert np.max(np.abs(loud)) <= 10 ** (-1 / 20) + 1e-9
    assert abs(el.db(el.level(engine(np.full(SR, 3000.0)), -21.0)) + 21.0) < 0.5


def test_brio_profile_matches_the_game_profile():
    source = (ROOT / "src/shared/Audio/EngineSoundProfiles.luau").read_text(encoding="utf-8")
    points = ", ".join(str(p) for p in el.BRIO["points"])
    assert f"Points = {{ {points} }}" in source
    for variant in el.BRIO["variants"].values():
        assert set(variant["loops"]) == {(kind, p) for kind in ("on", "off") for p in el.BRIO["points"]}
    assert set(el.BRIO["events"]) == {"Start", "Stop", "Stall"}


def test_grains_extend_without_seams():
    """Allongement par grains d'un signal à régime constant : durée demandée, niveau régulier (pas de trou)."""
    signal = engine(np.full(int(0.4 * SR), 3000.0))
    longer = el.extend(signal, SR, 3000, seconds=1.6)
    assert len(longer) == int(1.6 * SR)
    frames = longer[: len(longer) // 2400 * 2400].reshape(-1, 2400)
    rms = np.sqrt((frames**2).mean(axis=1))
    assert rms.min() > 0.8 * rms.mean()
    assert abs(el.line_rpm(longer, SR, 3000) - 3000) < 30


def test_window_holds_enough_engine_cycles():
    anchors = [(0.0, 1500.0), (1.0, 2500.0)]
    t0, t1, _, _ = el.window_for(anchors, 1700)
    assert t1 - t0 >= 8 * 120 / 1700 - 1e-9 and 0.0 <= t0 < t1 <= 1.0


def test_resampling_keeps_long_signals_intact():
    """Régression (coupures entendues par le propriétaire) : 96 kHz → 48 kHz sur 3 s, le niveau reste constant
    par trames de 100 ms et le signal suit l'original (aucun débordement d'entier dans les indices)."""
    sr = 96000
    t = np.arange(3 * sr, dtype=np.float64) / sr
    signal = 0.3 * np.sin(2 * np.pi * 440 * t)
    out = el.to_out_rate(signal, sr)
    assert len(out) == 3 * el.OUT_RATE
    frames = out[: len(out) // 4800 * 4800].reshape(-1, 4800)
    rms = np.sqrt((frames**2).mean(axis=1))
    assert rms.min() > 0.95 * rms.max()
    assert np.max(np.abs(out - signal[::2])) < 0.01
