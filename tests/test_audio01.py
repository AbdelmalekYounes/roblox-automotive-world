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
    assert set(el.BRIO["loops"]) == {(kind, p) for kind in ("on", "off") for p in el.BRIO["points"]}
    assert set(el.BRIO["events"]) == {"Start", "Stop", "Stall"}
