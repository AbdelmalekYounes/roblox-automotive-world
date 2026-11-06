"""Contrôles hors Studio du lot AUDIO-04 (bruits de collision) : outil tools/audio/collision_sounds.py."""

import re
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

import collision_sounds as cs  # noqa: E402

MODEL = ROOT / "src/shared/Audio/CollisionAudioModel.luau"
MANIFEST = ROOT / "src/shared/Assets/AssetManifest.luau"


def test_onset_finds_the_attack():
    """L'attaque d'un choc est trouvée à quelques millisecondes près, même après un silence bruité."""
    sr = 48000
    rng = np.random.default_rng(1)
    x = rng.standard_normal(sr) * 0.001
    x[int(0.42 * sr) : int(0.5 * sr)] += np.exp(-np.arange(int(0.08 * sr)) / 800) * 0.8
    t = cs.onset(x, sr, None)
    assert 0.41 <= t <= 0.421, t


def test_shot_is_trimmed_faded_and_normalised():
    """Son ponctuel : durée demandée, fin fondue, crête au niveau visé, aucun clic au départ."""
    sr = 96000
    rng = np.random.default_rng(2)
    x = np.zeros(2 * sr)
    x[int(0.3 * sr) :] = rng.standard_normal(len(x) - int(0.3 * sr)) * np.exp(-np.arange(len(x) - int(0.3 * sr)) / sr)
    spec = {"search": None, "length": 0.8, "band": (50.0, 12000.0), "peak_db": -3.0}
    sound, info = cs.shot(x, sr, spec)
    assert abs(len(sound) / cs.OUT_RATE - 0.8) < 0.01
    assert abs(20 * np.log10(np.max(np.abs(sound))) + 3.0) < 0.01
    assert abs(sound[0]) < 1e-6 and np.max(np.abs(sound[-50:])) < 0.01
    assert 0.29 <= info["attaque_s"] <= 0.301


def test_sounds_match_game_model_and_manifest():
    """Les sept sons de l'outil sont exactement les ressources de CollisionAudioModel, déclarées au manifeste."""
    model = MODEL.read_text(encoding="utf-8")
    ids = set(re.findall(r'"audio\.effect\.collision\.([a-z.]+)"', model))
    assert ids == set(cs.SHOTS) | {cs.LOOP["name"]}, ids
    declared = set(re.findall(r'recordedCollision\("([a-z.]+)",', MANIFEST.read_text(encoding="utf-8")))
    assert declared == ids


def test_impact_port_follows_game_rules():
    """Portage Python (démo) : seuil, variantes, volume croissant, objet léger plus doux, hauteur bornée."""
    c = cs.model_constants()
    for key in ("MinImpactMs", "HeavyImpactMs", "FullImpactMs", "ScrapeMinSpeed", "ScrapeFullSpeed"):
        assert key in c, key
    assert cs.impact("Hard", 0.5, c) is None
    assert cs.impact("Hard", 2, c)[0] == "hard.light" and cs.impact("Hard", 6, c)[0] == "hard.heavy"
    assert cs.impact("Vehicle", 8, c)[0] == "vehicle.heavy" and cs.impact("Object", 8, c)[0] == "object"
    volumes = [cs.impact("Hard", dv, c)[1] for dv in (1, 2, 4, 8, 14, 40)]
    assert volumes == sorted(volumes) and volumes[-1] <= 1
    assert cs.impact("Object", 8, c)[1] < cs.impact("Hard", 8, c)[1]
    for r in (0.0, 1.0):
        assert 0.85 <= cs.impact("Vehicle", 40, c, r)[2] <= 1.1
