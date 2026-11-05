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


# Identifiants d'image envoyés par le propriétaire (lot UI-02, 2026-11-05) : les seuls déclarés au manifeste.
PHONE_ICON_IDS = {
    "Map": 139759611688719,
    "Vehicles": 75819885655066,
    "Properties": 86911212052819,
    "Missions": 123109347713390,
    "Races": 135512154723543,
    "Market": 79661493327089,
    "Social": 104529493537486,
    "Radio": 97090714931696,
    "Photo": 124133194296037,
    "Guide": 78344066959818,
    "Settings": 117473178109905,
    "Notifications": 77842663800346,
}


def test_asset_manifest_declares_no_roblox_id():
    """Aucun identifiant Roblox n'est inventé : RobloxAssetId vaut nil, sauf les 12 icônes du téléphone envoyées par
    le propriétaire, lues dans une table unique dont le contenu doit être exactement celui qu'il a fourni."""
    source = MANIFEST.read_text(encoding="utf-8")
    values = re.findall(r"RobloxAssetId\s*=\s*([^,\n]+)", source)
    assert values, "champ RobloxAssetId absent"
    others = [value.strip() for value in values if value.strip() != "nil"]
    assert others == ["PHONE_ICON_IDS[appName]"], others
    block = re.search(r"local PHONE_ICON_IDS[^{]*\{(.*?)\n\}", source, re.S)
    assert block, "table PHONE_ICON_IDS absente"
    declared = {name: int(number) for name, number in re.findall(r"(\w+) = (\d+),", block.group(1))}
    assert declared == PHONE_ICON_IDS
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
