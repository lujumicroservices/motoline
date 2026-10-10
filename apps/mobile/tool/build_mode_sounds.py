"""Build high-quality ON/OFF mode-switch cues from CC0 motorcycle recordings.

Sources (BigSoundBank / La Sonothèque, CC0 public domain — Denis Chardonnet):
  0603  75 cm³ motorcycle acceleration   -> OFF (2T / dirt character)
  0884  Ducati Granturismo start + pull  -> ON  (track / road roar)
  0281  motorcycle start + accelerations -> fallback / extra punch

  python tool/build_mode_sounds.py

Writes 48 kHz mono WAV (loud, faded, lightly EQ'd) under assets/sounds/.
"""

from __future__ import annotations

import pathlib
import struct
import wave
import zipfile

import numpy as np

SR_OUT = 48000
OUT = pathlib.Path(__file__).resolve().parents[1] / "assets" / "sounds"
SRC = pathlib.Path.home() / "AppData" / "Local" / "Temp" / "rl_sounds"
# Also accept a local cache next to this script.
LOCAL = pathlib.Path(__file__).resolve().parent / "sound_src"


def read_wav(path: pathlib.Path):
    with wave.open(str(path), "rb") as w:
        ch, width, rate, n, _, _ = w.getparams()
        raw = w.readframes(n)
    if width == 2:
        data = np.frombuffer(raw, dtype="<i2").astype(np.float64) / 32768.0
    elif width == 3:
        # 24-bit packed little-endian
        b = np.frombuffer(raw, dtype=np.uint8).reshape(-1, 3)
        vals = b[:, 0].astype(np.int32) | (b[:, 1].astype(np.int32) << 8) | (
            b[:, 2].astype(np.int32) << 16
        )
        vals = np.where(vals >= 0x800000, vals - 0x1000000, vals)
        data = vals.astype(np.float64) / 8388608.0
    elif width == 4:
        data = np.frombuffer(raw, dtype="<i4").astype(np.float64) / 2147483648.0
    else:
        raise SystemExit(f"unsupported width {width} in {path}")
    if ch > 1:
        data = data.reshape(-1, ch).mean(axis=1)
    return data, rate


def resample(x: np.ndarray, sr_in: int, sr_out: int = SR_OUT) -> np.ndarray:
    if sr_in == sr_out:
        return x
    n_out = int(round(len(x) * sr_out / sr_in))
    t_in = np.linspace(0, 1, len(x), endpoint=False)
    t_out = np.linspace(0, 1, n_out, endpoint=False)
    return np.interp(t_out, t_in, x)


def biquad_peak(x, sr, f0, gain_db, q=1.2):
    """One-pole peaking EQ (RBJ)."""
    A = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * f0 / sr
    alpha = np.sin(w0) / (2 * q)
    b0 = 1 + alpha * A
    b1 = -2 * np.cos(w0)
    b2 = 1 - alpha * A
    a0 = 1 + alpha / A
    a1 = -2 * np.cos(w0)
    a2 = 1 - alpha / A
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, xi in enumerate(x):
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def highpass(x, sr, fc=80.0):
    """Simple 1-pole high-pass to remove rumble."""
    rc = 1 / (2 * np.pi * fc)
    dt = 1 / sr
    a = rc / (rc + dt)
    y = np.zeros_like(x)
    prev_x = prev_y = 0.0
    for i, xi in enumerate(x):
        yi = a * (prev_y + xi - prev_x)
        prev_x, prev_y = xi, yi
        y[i] = yi
    return y


def soft_clip(x, drive=1.15):
    return np.tanh(drive * x)


def normalize(x, peak=0.92):
    m = np.max(np.abs(x)) + 1e-12
    return x * (peak / m)


def fade(x, sr, fade_in=0.04, fade_out=0.22):
    n_in = int(fade_in * sr)
    n_out = int(fade_out * sr)
    x = x.copy()
    if n_in > 0:
        x[:n_in] *= np.linspace(0, 1, n_in) ** 1.2
    if n_out > 0:
        x[-n_out:] *= np.linspace(1, 0, n_out) ** 1.6
    return x


def best_window(x, sr, dur, hop=0.05, prefer_bright=True):
    """Pick the loudest (and optionally brightest) window of length `dur`."""
    win = int(dur * sr)
    step = int(hop * sr)
    if len(x) <= win:
        return x
    best_i, best_score = 0, -1.0
    # Pre-emphasis for brightness score
    diff = np.diff(x, prepend=x[0])
    for i in range(0, len(x) - win, step):
        seg = x[i : i + win]
        rms = float(np.sqrt(np.mean(seg * seg)))
        bright = float(np.sqrt(np.mean(diff[i : i + win] ** 2)))
        score = rms * (1.35 if prefer_bright else 1.0) + 0.45 * bright
        # Prefer later revs over cold idle at the start
        score *= 0.85 + 0.30 * (i / max(1, len(x) - win))
        if score > best_score:
            best_score, best_i = score, i
    return x[best_i : best_i + win]


def find_src(name: str) -> pathlib.Path:
    for base in (SRC, LOCAL):
        p = base / name
        if p.exists() and p.stat().st_size > 100_000:
            return p
    raise SystemExit(f"missing source {name} in {SRC} or {LOCAL}")


def process(src_name: str, out_name: str, dur: float, eq_mid: float, eq_presence: float):
    path = find_src(src_name)
    x, sr = read_wav(path)
    x = resample(x, sr, SR_OUT)
    x = best_window(x, SR_OUT, dur, hop=0.04, prefer_bright=True)
    x = highpass(x, SR_OUT, 70)
    x = biquad_peak(x, SR_OUT, 180, 2.5, q=0.9)  # body
    x = biquad_peak(x, SR_OUT, eq_mid, 4.0, q=1.1)  # bark / mid
    x = biquad_peak(x, SR_OUT, eq_presence, 3.5, q=1.4)  # clarity
    x = soft_clip(x, drive=1.25)
    x = normalize(x, peak=0.94)
    x = fade(x, SR_OUT, fade_in=0.035, fade_out=0.28)
    # Tiny silence pad so the player doesn't click on start
    pad = np.zeros(int(0.015 * SR_OUT))
    x = np.concatenate([pad, x, pad * 0])
    OUT.mkdir(parents=True, exist_ok=True)
    dest = OUT / out_name
    with wave.open(str(dest), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR_OUT)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    print(
        f"{out_name}: {dest.stat().st_size} B, {len(x)/SR_OUT:.2f}s, "
        f"peak={np.max(np.abs(x)):.2f}, from {path.name}"
    )


def write_license():
    (OUT / "SOURCES.md").write_text(
        """# Mode-switch engine sounds

Built from CC0 (public domain) recordings on BigSoundBank / La Sonothèque
by Denis Chardonnet — free for commercial use, attribution not required.

| File | Source |
|---|---|
| `mode_off_2t.wav` | [75 cm³ motorcycle acceleration](https://bigsoundbank.com/75-cm3-motorcycle-acceleration-s0603.html) (s0603) |
| `mode_on_track.wav` | [Starting a motorcycle (Ducati)](https://bigsoundbank.com/starting-a-motorcycle-s0884.html) (s0884) |

Clips are trimmed to the loudest rev window, EQ'd for phone speakers, and
normalized. Regenerate with `python tool/build_mode_sounds.py` after placing
the source WAVs in `%TEMP%/rl_sounds/` or `tool/sound_src/`.
""",
        encoding="utf-8",
    )


if __name__ == "__main__":
    # OFF: small-displacement accel — sharper, more 2T / dirt character
    process("0603.wav", "mode_off_2t.wav", dur=2.15, eq_mid=950, eq_presence=2800)
    # ON: Ducati start + pull-away — deeper, track / street roar
    process("0884.wav", "mode_on_track.wav", dur=2.45, eq_mid=420, eq_presence=2200)
    write_license()
