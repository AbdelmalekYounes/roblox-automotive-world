"""Contrôles statiques du projet Roblox, exécutables sans Roblox Studio."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"


def _sources():
    return sorted(SRC.rglob("*.luau"))


def test_manifest_valid_and_paths_exist():
    """Vérifie que le manifeste Rojo pointe vers les trois dossiers sources."""
    project = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))
    assert project["name"] == "AutomotiveWorld_Development"
    tree = project["tree"]
    assert (ROOT / tree["ReplicatedStorage"]["Shared"]["$path"]).is_dir()
    assert (ROOT / tree["ServerScriptService"]["AutomotiveWorldServer"]["$path"]).is_dir()
    assert (ROOT / tree["StarterPlayer"]["StarterPlayerScripts"]["AutomotiveWorldClient"]["$path"]).is_dir()


def test_rojo_and_validation_tools_pinned():
    """Évite les variations de format entre versions des outils."""
    tools = (ROOT / "rokit.toml").read_text(encoding="utf-8")
    assert 'rojo-rbx/rojo@7.7.1' in tools
    for tool in ("kampfkarren/selene@", "johnnymorganz/stylua@", "johnnymorganz/luau-lsp@", "lune-org/lune@"):
        assert tool in tools, f"outil non épinglé : {tool}"
    assert (ROOT / "selene.toml").is_file()
    assert (ROOT / "stylua.toml").is_file()


def test_contract_values_and_bootstrap():
    """Contrôle les valeurs approuvées et les points d'entrée présents."""
    config = (SRC / "shared/ProjectSettings.luau").read_text(encoding="utf-8")
    assert 'RequirementsVersion = "1.0"' in config
    assert 'DevelopmentVersion = "0.4.0-dev"' in config
    assert "LaunchVehicleModelCount = 2" in config  # lot BASE-01, amendement A-01
    assert "LaunchZoneCount = 7" in config
    assert "MaximumPlayersTarget = 24" in config
    assert "TargetFps = 60" in config
    assert (SRC / "server/Bootstrap.server.luau").is_file()
    assert (SRC / "client/Bootstrap.client.luau").is_file()


DATASTORE_ADAPTER = "DataStoreProfileRepository.luau"
# Lot 0.6 : coordination inter-serveurs (MemoryStore, téléportation) et tableaux
# de classement (OrderedDataStore) isolés dans un adaptateur instancié seulement
# si une expérience de test isolée ou de production est déclarée (aucune).
CROSS_SERVER_ADAPTER = "CrossServerAdapter.luau"
# Lot 0.8 : seul le manifeste des ressources forme une URL de contenu, à partir
# d'un identifiant RÉEL qu'il déclare (aucun aujourd'hui : voir test_lot08.py).
ASSET_MANIFEST = "AssetManifest.luau"
# Lot BRAND-01 : recopie du logo pour l'écran de chargement (ReplicatedFirst, lu avant la réplication du manifeste) ;
# identifiant égal à celui du manifeste (test Lune Brand01) et table exacte contrôlée (tests/test_brand01.py).
BRAND_FIRST = "Brand.luau"


def test_no_premature_datastore_economy_or_external_code():
    """Ni économie, ni code/actif externe ; DataStore réservé à son adaptateur (lot 0.4)."""
    datastore_tokens = ["GetDataStore(", "UpdateAsync(", "DataStoreService"]
    forbidden = [
        "SetAsync(",
        "MarketplaceService",
        "ProcessReceipt",
        "InsertService",
        "loadstring",
        "rbxassetid://",
    ]
    adapters = []
    for script in _sources():
        source = script.read_text(encoding="utf-8")
        for token in forbidden:
            if script.name == CROSS_SERVER_ADAPTER and token == "SetAsync(":
                continue
            if script.name in (ASSET_MANIFEST, BRAND_FIRST) and token == "rbxassetid://":
                continue
            assert token not in source, f"{token} interdit dans {script.name}"
        if any(token in source for token in datastore_tokens):
            adapters.append(script.name)
        assert not re.search(r"require\(\s*\d", source), f"module externe par identifiant dans {script.name}"
        assert "--" in source, f"Commentaires manquants dans {script.name}"
    assert sorted(adapters) == sorted([DATASTORE_ADAPTER, CROSS_SERVER_ADAPTER]), f"DataStore hors de ses adaptateurs : {adapters}"


def test_storage_environments_declared():
    """Seule l'expérience de TEST privée du propriétaire est déclarée (2026-11-05) ; aucune production."""
    config = (SRC / "server/Persistence/EnvironmentConfig.luau").read_text(encoding="utf-8")
    assert "TestGameIds = table.freeze({ 10774855477 })" in config
    assert "ProdGameIds = table.freeze({})" in config


def test_client_server_shared_separation():
    """Le client ne référence pas le code serveur ; le partagé n'utilise pas de services réservés."""
    for script in (SRC / "client").rglob("*.luau"):
        source = script.read_text(encoding="utf-8")
        assert "ServerScriptService" not in source, script.name
        assert "ServerStorage" not in source, script.name
    for script in (SRC / "shared").rglob("*.luau"):
        source = script.read_text(encoding="utf-8")
        assert "ServerScriptService" not in source, script.name
        assert "LocalPlayer" not in source, script.name
        assert "SetNetworkOwner" not in source, script.name


def test_server_authority_on_network_ownership():
    """Seul le serveur attribue la propriété réseau et assied le joueur."""
    for script in _sources():
        source = script.read_text(encoding="utf-8")
        if "SetNetworkOwner(" in source or ":Sit(" in source:
            assert script.is_relative_to(SRC / "server"), f"autorité serveur contournée dans {script.name}"


def test_test_vehicle_is_declared_as_prototype_without_aids():
    """Le véhicule d'essai P-01 est fictif, marqué prototype et sans aides déclarées.

    Lot BASE-01 : retiré du jeu, il reste un jeu d'essai des tests (tests/lune/fixtures).
    """
    definition = (ROOT / "tests/lune/fixtures/PrototypeP01.luau").read_text(encoding="utf-8")
    assert "IsTestPrototype = true" in definition
    assert "Abs = false" in definition
    assert "TractionControl = false" in definition
    assert "StabilityControl = false" in definition


def test_strict_typing_in_modules():
    """Les modules Luau du lot sont en typage strict."""
    for script in _sources():
        if script.name.endswith((".server.luau", ".client.luau")) or script.name == "ProjectSettings.luau":
            continue
        first_line = script.read_text(encoding="utf-8").splitlines()[0]
        assert first_line.strip() == "--!strict", f"--!strict manquant dans {script.name}"


def test_open_world_place_separated_from_dev_place():
    """Lot 0.3 : la place monde ouvert est distincte ; la zone d'essai reste en développement."""
    dev = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))
    world = json.loads((ROOT / "openworld.project.json").read_text(encoding="utf-8"))
    assert dev["tree"]["ReplicatedStorage"]["PlaceConfig"]["$path"] == "places/dev/PlaceConfig.luau"
    assert world["tree"]["ReplicatedStorage"]["PlaceConfig"]["$path"] == "places/openworld/PlaceConfig.luau"
    assert 'Mode = "Dev"' in (ROOT / "places/dev/PlaceConfig.luau").read_text(encoding="utf-8")
    assert 'Mode = "OpenWorld"' in (ROOT / "places/openworld/PlaceConfig.luau").read_text(encoding="utf-8")
    workspace = world["tree"]["Workspace"]
    assert workspace["$properties"]["StreamingEnabled"] is True
    assert workspace["OpenWorld"]["$path"] == "build/world/OpenWorld.rbxm"
    assert "Workspace" not in dev["tree"], "la place de développement ne doit pas inclure la carte"
