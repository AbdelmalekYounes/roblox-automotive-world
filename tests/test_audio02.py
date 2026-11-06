"""Contrôles hors Studio du lot AUDIO-02 (moteur de la Comète) : cohérence de l'outil et du jeu."""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

import engine_loops as el  # noqa: E402

PROFILES = ROOT / "src/shared/Audio/EngineSoundProfiles.luau"
MANIFEST = ROOT / "src/shared/Assets/AssetManifest.luau"


def test_comete_profile_matches_game():
    """Régimes de référence, ralenti et rupteur de l'outil = profil du jeu ; V8 (raie / 15) ; turbo et pétarades."""
    source = PROFILES.read_text(encoding="utf-8")
    block = source[source.index("local COMETE"):]
    points = [int(v) for v in re.search(r"Points = \{([^}]*)\}", block).group(1).split(",")]
    assert points == el.COMETE["points"] == el.COMETE_POINTS
    assert "LimiterRpm = 8500" in block and el.COMETE["limiter_rpm"] == 8500
    assert "IdleRpm = 850" in block and el.COMETE["idle_rpm"] == 850
    assert "Turbo = true" in block and "Pops = true" in block
    assert el.COMETE["divisor"] == 15.0


def test_every_comete_loop_and_event_is_in_the_manifest():
    """Chaque boucle et chaque événement des deux variantes est déclaré au manifeste (variante « micro B »)."""
    manifest = MANIFEST.read_text(encoding="utf-8")
    assert 'Output = "build/audio/engines/comete/micro_b/" .. name .. ".wav"' in manifest
    for variant in el.COMETE["variants"].values():
        for kind, rpm in variant["loops"]:
            assert f"{kind}.{rpm}" in {f"on.{p}" for p in el.COMETE_POINTS} | {f"off.{p}" for p in el.COMETE_POINTS}
    for event in el.COMETE["events"]:
        assert f'recordedComete(\n    "{event.lower()}"' in manifest or f'recordedComete("{event.lower()}"' in manifest, event
    assert 'recordedComete(\n    "turbo"' in manifest or 'recordedComete("turbo"' in manifest


def test_loops_cover_the_limiter():
    """La dernière boucle, transposée au plus de × 1,45 (EngineAudioModel), atteint le rupteur de 8 500 tr/min."""
    assert el.COMETE_POINTS[-1] * 1.45 >= el.COMETE["limiter_rpm"]
    ratios = [b / a for a, b in zip(el.COMETE_POINTS, el.COMETE_POINTS[1:])]
    assert max(ratios) <= 1.45 / 0.7
