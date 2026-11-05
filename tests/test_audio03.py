"""Contrôles hors Studio du lot AUDIO-03 (sons des pneus) : outil tools/audio/tire_loops.py et cohérence avec le jeu."""

import re
import struct
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "audio"))

import tire_loops  # noqa: E402

MODEL = ROOT / "src/shared/Audio/TireAudioModel.luau"
MANIFEST = ROOT / "src/shared/Assets/AssetManifest.luau"


def _wav(path: Path, samples: np.ndarray, rate: int, code: int, bits: int, channels: int = 1) -> None:
    """Écrit un WAV minimal (PCM entier ou flottant) pour tester le lecteur."""
    if code == 3:
        payload = samples.astype("<f4").tobytes()
    elif bits == 24:
        ints = np.round(samples * 8388607).astype(np.int64)
        payload = b"".join(int(v & 0xFFFFFF).to_bytes(3, "little") for v in ints)
    else:
        payload = np.round(samples * 32767).astype("<i2").tobytes()
    block = channels * bits // 8
    fmt = struct.pack("<HHIIHH", code, channels, rate, rate * block, block, bits)
    body = b"WAVE" + b"fmt " + struct.pack("<I", len(fmt)) + fmt + b"data" + struct.pack("<I", len(payload)) + payload
    path.write_bytes(b"RIFF" + struct.pack("<I", len(body)) + body)


def test_reader_handles_float_and_24_bit(tmp_path):
    """Le gravier n° 9 (529225) est en WAV 32 bits : flottant ou entier, les deux sont lus ; 24 bits aussi."""
    signal = 0.5 * np.sin(2 * np.pi * 440 * np.arange(4800) / 48000)
    for code, bits in [(3, 32), (1, 24), (1, 16)]:
        path = tmp_path / f"t_{code}_{bits}.wav"
        _wav(path, signal, 48000, code, bits)
        rate, read = tire_loops.read_audio(path)
        assert rate == 48000
        assert np.max(np.abs(read - signal)) < 1e-3, (code, bits)
    stereo = tmp_path / "stereo.wav"
    _wav(stereo, np.repeat(signal, 2), 48000, 3, 32, channels=2)
    assert np.max(np.abs(tire_loops.read_audio(stereo)[1] - signal)) < 1e-6, "stéréo ramenée en mono"


def test_resampling_keeps_long_signals_intact():
    """Non-régression du débordement d'AUDIO-01 : 3 s à 96 kHz ramenées à 48 kHz sans creux de niveau."""
    sr = 96000
    tone = np.sin(2 * np.pi * 1000 * np.arange(3 * sr, dtype=np.float64) / sr)
    out = tire_loops.to_out_rate(tone, sr)
    assert abs(len(out) - 3 * 48000) <= 1
    frames = [np.sqrt(np.mean(out[i : i + 2400] ** 2)) for i in range(4800, len(out) - 4800, 2400)]
    assert min(frames) > 0.68 and max(frames) < 0.73, (min(frames), max(frames))


def test_noise_loop_is_seamless_and_steady():
    """Boucle de bruit (grains puis raccord) : longueur exacte, raccord et creux faibles, niveau visé."""
    rng = np.random.default_rng(3)
    # Bruit dont le niveau monte de 12 dB, comme un passage de voiture : l'aplanissement doit l'effacer.
    noise = rng.standard_normal(48000) * np.linspace(0.25, 1.0, 48000)
    flat = tire_loops.flatten(noise, 48000)
    long = tire_loops.extend(flat, 48000, 2.2, seed=1)
    loop = tire_loops.level(tire_loops.make_loop(long, 48000, 2.0), -20.0)
    assert len(loop) == 96000
    assert abs(tire_loops.db(loop) + 20.0) < 1.0
    assert tire_loops.seam_jump_db(loop, 48000) < 3.0
    assert tire_loops.max_frame_dip_db(loop, 48000) < 4.0


def test_squeal_pick_prefers_tonal_segment():
    """L'extrait « crissement » est la partie sifflante (raie émergente), pas la plus bruyante."""
    sr = 48000
    rng = np.random.default_rng(0)
    noise = rng.standard_normal(3 * sr) * 0.3
    t = np.arange(sr) / sr
    noise[sr : 2 * sr] = 0.15 * rng.standard_normal(sr) + 0.3 * np.sin(2 * np.pi * 1800 * t)
    start, _ = tire_loops.pick_span(noise, sr, "squeal", seconds=0.8)
    assert 0.9 <= start <= 1.3, start


def test_loops_match_game_model_and_manifest():
    """Les six boucles de l'outil sont exactement les ressources de TireAudioModel, déclarées au manifeste avec la
    sortie de l'outil."""
    model = MODEL.read_text(encoding="utf-8")
    ids = set(re.findall(r'"audio\.effect\.tire\.([a-z.]+)"', model))
    assert ids == set(tire_loops.LOOPS), ids
    manifest = MANIFEST.read_text(encoding="utf-8")
    declared = set(re.findall(r'recordedTire\("([a-z.]+)",', manifest))
    assert declared == ids
    assert 'Output = "build/audio/tires/" .. name .. ".wav"' in manifest


def test_model_port_reads_game_constants():
    """Le portage Python (démos) lit les constantes du module Luau et en reproduit les règles principales."""
    c = tire_loops.model_constants()
    for key in ("RollReferenceSpeed", "RollFadeInSpeed", "ReferenceMassKg", "WetSquealFactor", "AbsPulseHz"):
        assert key in c, key
    base = {"Speed": 20.0, "Grounded": 1.0, "Squeal": 0.0, "Scrub": 0.0, "SlipSpeed": 0.0, "Surface": "Hard",
            "Wetness": 0.0, "Abs": False}
    still = tire_loops.model_layers({**base, "Speed": 0.0}, 1200, c)
    assert all(v == 0 for v, _ in still.values()), "silence à l'arrêt"
    dry = tire_loops.model_layers(base, 1200, c)
    assert dry["roll.dry"][0] > 0 and dry["roll.wet"][0] == 0 and dry["squeal"][0] == 0
    skid = tire_loops.model_layers({**base, "Squeal": 1.0, "Scrub": 1.0, "SlipSpeed": 20.0}, 1200, c)
    wet = tire_loops.model_layers({**base, "Squeal": 1.0, "Scrub": 1.0, "SlipSpeed": 20.0, "Wetness": 1.0}, 1200, c)
    assert wet["squeal"][0] < skid["squeal"][0] * 0.5, "crissement atténué sur le mouillé"
    gravel = tire_loops.model_layers({**base, "Squeal": 1.0, "Surface": "Loose"}, 1200, c)
    assert gravel["squeal"][0] == 0 and gravel["slide.loose"][0] > 0.5
