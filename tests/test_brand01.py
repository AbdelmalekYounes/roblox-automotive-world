"""Contrôles statiques du lot BRAND-01 (nom du jeu, logo, écran de chargement)."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BRAND = ROOT / "src/first/Brand.luau"
MANIFEST = ROOT / "src/shared/Assets/AssetManifest.luau"

# Identifiants d'image envoyés par le propriétaire (aucun pour l'instant : le logo n'est pas encore envoyé sur
# Roblox). À remplir avec la valeur RÉELLE qu'il communique, en même temps que Brand.luau et le manifeste.
BRAND_IMAGE_IDS: dict[str, int] = {}


def test_brand_image_ids_are_exactly_those_provided():
    """La table de Brand.luau est exactement celle fournie par le propriétaire : rien n'est inventé."""
    source = BRAND.read_text(encoding="utf-8")
    block = re.search(r"local BRAND_IMAGE_IDS[^=]*=\s*\{(.*?)\}", source, re.S)
    assert block, "table BRAND_IMAGE_IDS absente"
    found = {k: int(v) for k, v in re.findall(r"(\w+)\s*=\s*(\d+),", block.group(1))}
    assert found == BRAND_IMAGE_IDS


def test_manifest_logo_entry_matches():
    """L'entrée ui.brand.logo du manifeste porte le même identifiant (nil tant qu'il n'y en a pas)."""
    source = MANIFEST.read_text(encoding="utf-8")
    entry = re.search(r'Id = "ui\.brand\.logo",(.*?)\n\}\)', source, re.S)
    assert entry, "entrée ui.brand.logo absente"
    value = re.search(r"RobloxAssetId = ([^,\n]+)", entry.group(1)).group(1).strip()
    expected = str(BRAND_IMAGE_IDS["logo"]) if "logo" in BRAND_IMAGE_IDS else "nil"
    assert value == expected


def test_replicated_first_is_mapped_in_both_places():
    """L'écran de chargement est construit dans les deux places (zone d'essai et monde ouvert)."""
    for name in ("default.project.json", "openworld.project.json"):
        tree = json.loads((ROOT / name).read_text(encoding="utf-8"))["tree"]
        first = tree.get("ReplicatedFirst")
        assert first and first["$className"] == "ReplicatedFirst", name
        assert first["AutomotiveWorldFirst"]["$path"] == "src/first", name
    assert (ROOT / "src/first/LoadingScreen.client.luau").is_file()


def test_technical_name_unchanged():
    """Le nom technique du code n'est pas renommé sans accord du propriétaire (projets Rojo)."""
    for name, expected in (("default.project.json", "AutomotiveWorld_Development"),
                           ("openworld.project.json", "AutomotiveWorld_OpenWorld")):
        assert json.loads((ROOT / name).read_text(encoding="utf-8"))["name"] == expected
