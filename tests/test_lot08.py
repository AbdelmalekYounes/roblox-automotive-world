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


# Identifiants des 19 sons de moteur de la Brio envoyés par le propriétaire (lot AUDIO-01, 2026-11-06), relevés dans
# son fichier brio_sound.rbxm : seuls identifiants audio déclarés au manifeste.
BRIO_ENGINE_SOUND_IDS = {
    "on.1000": 100316175913759,
    "on.1300": 71805665589957,
    "on.1700": 113780474099124,
    "on.2200": 88489584332634,
    "on.2900": 139847748681292,
    "on.3800": 132071504297109,
    "on.4900": 132995478418521,
    "on.6300": 133027765625226,
    "off.1000": 126024686217376,
    "off.1300": 90633302806466,
    "off.1700": 106378654172632,
    "off.2200": 72650990038478,
    "off.2900": 85091116230984,
    "off.3800": 108314634619106,
    "off.4900": 132177207806274,
    "off.6300": 118288604588883,
    "start": 119200249015180,
    "stop": 119630608706700,
    "stall": 118745681759489,
}


# Identifiants des 6 sons de pneus envoyés par le propriétaire (lot AUDIO-03, 2026-11-06), relevés dans son fichier
# audio03_pneus.rbxm.
TIRE_SOUND_IDS = {
    "roll.dry": 90291890857090,
    "roll.loose": 79688428452888,
    "roll.wet": 109725784350976,
    "squeal": 108267751330014,
    "scrub": 79292953985747,
    "slide.loose": 112587939989359,
}


# Identifiants des 7 sons de collision envoyés par le propriétaire (lot AUDIO-04, 2026-11-06), relevés dans son fichier
# audio04_collisions.rbxm.
COLLISION_SOUND_IDS = {
    "hard.light": 119936631540140,
    "hard.heavy": 84821488985222,
    "object": 107111383496078,
    "vehicle.light": 73753197716718,
    "vehicle.heavy": 103306869584523,
    "glass": 73806268842632,
    "scrape": 126532496130819,
}


def test_asset_manifest_declares_no_roblox_id():
    """Aucun identifiant Roblox n'est inventé : RobloxAssetId vaut nil, sauf les 12 icônes du téléphone et les 19 sons
    de moteur de la Brio envoyés par le propriétaire, lus dans deux tables uniques dont le contenu doit être exactement
    celui qu'il a fourni."""
    source = MANIFEST.read_text(encoding="utf-8")
    values = re.findall(r"RobloxAssetId\s*=\s*([^,\n]+)", source)
    assert values, "champ RobloxAssetId absent"
    others = [value.strip() for value in values if value.strip() != "nil"]
    assert others == [
        "if vehicle == \"brio\" then BRIO_ENGINE_SOUND_IDS[name] else nil",
        "TIRE_SOUND_IDS[name]",
        "COLLISION_SOUND_IDS[name]",
        "PHONE_ICON_IDS[appName]",
    ], others
    sounds = re.search(r"local BRIO_ENGINE_SOUND_IDS[^{]*\{(.*?)\n\}", source, re.S)
    assert sounds, "table BRIO_ENGINE_SOUND_IDS absente"
    assert {k: int(v) for k, v in re.findall(r'\["([a-z0-9.]+)"\] = (\d+),', sounds.group(1))} == BRIO_ENGINE_SOUND_IDS
    tires = re.search(r"local TIRE_SOUND_IDS[^{]*\{(.*?)\n\}", source, re.S)
    assert tires, "table TIRE_SOUND_IDS absente"
    assert {k: int(v) for k, v in re.findall(r'\["([a-z.]+)"\] = (\d+),', tires.group(1))} == TIRE_SOUND_IDS
    collisions = re.search(r"local COLLISION_SOUND_IDS[^{]*\{(.*?)\n\}", source, re.S)
    assert collisions, "table COLLISION_SOUND_IDS absente"
    found = {k: int(v) for k, v in re.findall(r'\["([a-z.]+)"\] = (\d+),', collisions.group(1))}
    assert found == COLLISION_SOUND_IDS
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
