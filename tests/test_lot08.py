"""Contrôles statiques du lot 0.8 : manifeste des ressources et sons synthétisés."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "src/shared/Assets/AssetManifest.luau"


def test_asset_manifest_sources_exist():
    """Chaque source déclarée par le manifeste existe dans le dépôt."""
    source = MANIFEST.read_text(encoding="utf-8")
    paths = set(re.findall(r'"((?:src|tools)/[^"]+)"', source))
    assert paths, "aucune source déclarée"
    for path in paths:
        assert (ROOT / path).is_file(), f"source absente : {path}"


def test_asset_manifest_declares_no_roblox_id():
    """Aucun identifiant Roblox n'est inventé : tous les RobloxAssetId sont nil."""
    source = MANIFEST.read_text(encoding="utf-8")
    values = re.findall(r"RobloxAssetId\s*=\s*([^,\n]+)", source)
    assert values, "champ RobloxAssetId absent"
    assert all(value.strip() == "nil" for value in values), values
    # Aucune URL de contenu écrite en dur : seule contentId() en forme une, depuis RobloxAssetId.
    assert not re.search(r"rbxassetid://\d|roblox\.com/asset", source)
    assert source.count("rbxassetid://") == 1


def _synth():
    import importlib.util

    spec = importlib.util.spec_from_file_location("aw_synth", ROOT / "tools/audio/synth.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_audio_synthesis_matches_manifest(tmp_path):
    """Le script produit exactement les sons du manifeste, en WAV 16 bits mono, de façon déterministe."""
    import hashlib
    import wave

    synth = _synth()
    # Le manifeste compose les mêmes 30 noms (contrôlé par le test Lune du lot 0.8).
    files = set(synth.catalogue())
    assert len(files) == 30
    for prefix in ("engine_petrol_", "engine_diesel_", "engine_electric_", "effect_", "ambience_", "ui_", "radio_"):
        assert any(name.startswith(prefix) for name in files), prefix
    first, second = tmp_path / "a", tmp_path / "b"
    assert synth.main(["--out", str(first)]) == 0
    assert synth.main(["--out", str(second)]) == 0
    for name in files:
        a, b = (first / name).read_bytes(), (second / name).read_bytes()
        assert hashlib.sha256(a).digest() == hashlib.sha256(b).digest(), name
        with wave.open(str(first / name)) as handle:
            assert handle.getnchannels() == 1 and handle.getsampwidth() == 2 and handle.getframerate() == 22050


def test_engine_loops_are_seamless():
    """Les couches moteur bouclent sans saut (fréquences entières sur une seconde)."""
    synth = _synth()
    for layer in synth.ENGINE_LAYERS:
        for diesel in (False, True):
            signal = synth.engine_combustion(layer, diesel)
            assert abs(signal[0] - signal[-1]) < 0.15, (layer, diesel)
