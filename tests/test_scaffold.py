"""Contrôles statiques du socle Roblox, exécutables sans Roblox Studio."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_manifest_valid_and_paths_exist():
    """Vérifie que le manifeste Rojo pointe vers les trois dossiers sources."""
    project = json.loads((ROOT / "default.project.json").read_text(encoding="utf-8"))
    assert project["name"] == "AutomotiveWorld_Development"
    tree = project["tree"]
    assert (ROOT / tree["ReplicatedStorage"]["Shared"]["$path"]).is_dir()
    assert (ROOT / tree["ServerScriptService"]["AutomotiveWorldServer"]["$path"]).is_dir()
    assert (ROOT / tree["StarterPlayer"]["StarterPlayerScripts"]["AutomotiveWorldClient"]["$path"]).is_dir()


def test_rojo_version_pinned():
    """Évite les variations de format entre versions majeures de Rojo."""
    tools = (ROOT / "rokit.toml").read_text(encoding="utf-8")
    assert 'rojo-rbx/rojo@7.7.1' in tools


def test_contract_values_and_bootstrap():
    """Contrôle les valeurs approuvées et les points d'entrée présents."""
    config = (ROOT / "src/shared/ProjectSettings.luau").read_text(encoding="utf-8")
    assert 'RequirementsVersion = "1.0"' in config
    assert "LaunchVehicleModelCount = 18" in config
    assert "LaunchZoneCount = 7" in config
    assert "MaximumPlayersTarget = 24" in config
    assert "TargetFps = 60" in config
    assert (ROOT / "src/server/Bootstrap.server.luau").is_file()
    assert (ROOT / "src/client/Bootstrap.client.luau").is_file()


def test_no_premature_datastore_or_external_code():
    """Le socle initial ne doit pas écrire dans les sauvegardes ni importer d'autres jeux."""
    for script in (ROOT / "src").rglob("*.luau"):
        source = script.read_text(encoding="utf-8")
        assert 'GetDataStore(' not in source
        assert 'SetAsync(' not in source
        assert 'UpdateAsync(' not in source
        assert 'require(123' not in source
        assert '--' in source, f"Commentaires manquants dans {script.name}"
