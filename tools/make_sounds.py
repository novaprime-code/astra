#!/usr/bin/env python3
"""Generate every sound effect used by Astra.

The game ships with no third-party audio. These nine files are synthesised
from scratch with the standard library, which keeps the repository free of
licensing questions and makes the sound design reproducible: change a number
here, re-run, and the whole set regenerates.

Usage:
    python3 tools/make_sounds.py [output_dir]

Defaults to assets/audio relative to the repository root.
"""

from __future__ import annotations

import math
import os
import random
import struct
import sys
import wave

SAMPLE_RATE = 22050
AMPLITUDE = 0.85


def envelope(t: float, duration: float, attack: float = 0.004, curve: float = 2.0) -> float:
    """Percussive envelope: near-instant attack, exponential-ish decay."""
    if t < attack:
        return t / attack
    remaining = (duration - t) / max(duration - attack, 1e-6)
    return max(0.0, remaining) ** curve


def write_wav(path: str, samples: list[float]) -> None:
    peak = max((abs(s) for s in samples), default=1.0) or 1.0
    scale = AMPLITUDE / peak
    frames = bytearray()
    for sample in samples:
        value = int(max(-1.0, min(1.0, sample * scale)) * 32767)
        frames += struct.pack("<h", value)
    with wave.open(path, "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(bytes(frames))
    print(f"  {os.path.basename(path):<20} {len(samples) / SAMPLE_RATE:.2f}s")


def frames(duration: float) -> int:
    return int(SAMPLE_RATE * duration)


def sweep(duration: float, f_start: float, f_end: float, curve: float = 2.0,
          wave_shape: str = "sine", noise_mix: float = 0.0) -> list[float]:
    """A pitch sweep from f_start to f_end, optionally mixed with noise."""
    out: list[float] = []
    phase = 0.0
    total = frames(duration)
    for i in range(total):
        t = i / SAMPLE_RATE
        progress = i / max(total - 1, 1)
        freq = f_start + (f_end - f_start) * progress
        phase += 2.0 * math.pi * freq / SAMPLE_RATE
        if wave_shape == "square":
            tone = 1.0 if math.sin(phase) >= 0.0 else -1.0
        elif wave_shape == "saw":
            tone = 2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0
        else:
            tone = math.sin(phase)
        if noise_mix > 0.0:
            tone = tone * (1.0 - noise_mix) + random.uniform(-1.0, 1.0) * noise_mix
        out.append(tone * envelope(t, duration, curve=curve))
    return out


def noise_burst(duration: float, low_pass: float = 0.35, curve: float = 2.5) -> list[float]:
    """Filtered noise. low_pass is the smoothing factor, 0..1 (lower = duller)."""
    out: list[float] = []
    state = 0.0
    total = frames(duration)
    for i in range(total):
        t = i / SAMPLE_RATE
        state += (random.uniform(-1.0, 1.0) - state) * low_pass
        out.append(state * envelope(t, duration, curve=curve))
    return out


def mix(*layers: list[float]) -> list[float]:
    length = max(len(layer) for layer in layers)
    out = [0.0] * length
    for layer in layers:
        for i, sample in enumerate(layer):
            out[i] += sample
    return out


def build() -> dict[str, list[float]]:
    random.seed(1618)  # Deterministic output, so regenerating is a no-op in git.
    return {
        # Bowstring release: a short, bright snap with air behind it.
        "bow_release": mix(
            sweep(0.16, 880.0, 180.0, curve=2.6, noise_mix=0.25),
            noise_burst(0.12, low_pass=0.6, curve=3.0),
        ),
        # Arrow landing: a dry tick. Plays often, so it must not fatigue.
        "arrow_hit": mix(
            sweep(0.055, 1400.0, 600.0, curve=3.5),
            noise_burst(0.045, low_pass=0.8, curve=4.0),
        ),
        # Enemy death: lower, with more body than a hit.
        "enemy_death": mix(
            sweep(0.26, 420.0, 90.0, curve=2.2, wave_shape="saw", noise_mix=0.2),
            noise_burst(0.22, low_pass=0.3, curve=2.0),
        ),
        # Player hurt: deliberately unpleasant, a low square buzz.
        "player_hurt": mix(
            sweep(0.3, 220.0, 70.0, curve=1.8, wave_shape="square"),
            noise_burst(0.14, low_pass=0.2, curve=2.5),
        ),
        # Dodge: a short whoosh, no pitch, so it never sounds like a shot.
        "dodge": noise_burst(0.18, low_pass=0.12, curve=1.6),
        # Astra: a rising sweep with a second voice above it.
        "astra": mix(
            sweep(0.55, 240.0, 1500.0, curve=1.2),
            sweep(0.55, 360.0, 2250.0, curve=1.6),
            noise_burst(0.3, low_pass=0.5, curve=2.0),
        ),
        # Wave start: two ascending notes, a clear "here they come".
        "wave_start": sweep(0.1, 520.0, 520.0, curve=1.5) + sweep(0.18, 780.0, 780.0, curve=1.8),
        # Run over: a long fall.
        "game_over": sweep(0.9, 440.0, 90.0, curve=1.1, wave_shape="saw"),
        # Menu click.
        "ui_select": sweep(0.07, 760.0, 980.0, curve=2.5),
    }


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    default_out = os.path.join(os.path.dirname(here), "assets", "audio")
    out_dir = sys.argv[1] if len(sys.argv) > 1 else default_out
    os.makedirs(out_dir, exist_ok=True)

    print(f"Writing sounds to {out_dir}")
    for name, samples in build().items():
        write_wav(os.path.join(out_dir, f"{name}.wav"), samples)
    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
