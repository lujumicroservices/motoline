"""Synthesize the ON/OFF mode-switch engine sounds (no third-party audio).

  python tool/build_mode_sounds.py

Writes assets/sounds/mode_off_2t.wav (two-stroke dirt bike blip) and
assets/sounds/mode_on_track.wav (four-cylinder track bike roar). Each firing is
a short damped pulse placed on an rpm curve, then shaped by resonant filters
(exhaust / airbox) and soft-clipped. Replace with real recordings when available.
"""

import math
import pathlib
import wave

import numpy as np

SR = 22050
OUT = pathlib.Path(__file__).resolve().parents[1] / "assets" / "sounds"
rng = np.random.default_rng(7)


def rpm_curve(points, dur):
    """Piecewise-smooth rpm over time from (t, rpm) keyframes."""
    t = np.arange(int(dur * SR)) / SR
    ks = np.array([p[0] for p in points])
    vs = np.array([p[1] for p in points])
    raw = np.interp(t, ks, vs)
    k = int(0.04 * SR)
    return np.convolve(np.pad(raw, (k, k), mode="edge"), np.ones(2 * k + 1) / (2 * k + 1), "valid")


def firings(rpm, fires_per_rev, jitter):
    """Sample indices of each combustion event."""
    phase, out = 0.0, []
    for i, r in enumerate(rpm):
        phase += r / 60.0 * fires_per_rev / SR
        if phase >= 1.0:
            phase -= 1.0
            out.append(i + int(rng.normal(0, jitter * SR / max(r, 1) * 60)))
    return [i for i in out if 0 <= i < len(rpm)]


def pulse(n, freqs, decay, noise):
    t = np.arange(n) / SR
    body = sum(a * np.sin(2 * math.pi * f * t) for f, a in freqs)
    body = body + noise * rng.normal(0, 1, n)
    return body * np.exp(-t * decay)


def biquad_bandpass(x, f0, q):
    w = 2 * math.pi * f0 / SR
    alpha = math.sin(w) / (2 * q)
    b0, b2 = alpha, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w), 1 - alpha
    b0, b2, a1, a2 = b0 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, xi in enumerate(x):
        yi = b0 * xi + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def lowpass(x, fc):
    a = math.exp(-2 * math.pi * fc / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, xi in enumerate(x):
        acc = (1 - a) * xi + a * acc
        y[i] = acc
    return y


def finish(x, drive, fade_in=0.03, fade_out=0.35):
    x = np.tanh(drive * x / (np.max(np.abs(x)) + 1e-9))
    n_in, n_out = int(fade_in * SR), int(fade_out * SR)
    x[:n_in] *= np.linspace(0, 1, n_in)
    x[-n_out:] *= np.linspace(1, 0, n_out) ** 1.5
    return 0.89 * x / (np.max(np.abs(x)) + 1e-9)


def write(name, x):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    print(path, path.stat().st_size, "bytes", round(len(x) / SR, 2), "s")


def two_stroke():
    """Single-cylinder 2T: one fire per rev, raspy expansion-chamber 'ring-ding' blip."""
    dur = 2.2
    rpm = rpm_curve([(0, 2200), (0.18, 2400), (0.32, 9800), (0.62, 11500), (0.78, 7000),
                     (0.95, 10800), (1.25, 11200), (1.5, 4200), (2.2, 2300)], dur)
    x = np.zeros(len(rpm) + SR // 10)
    for i in firings(rpm, 1, 0.012):
        r = rpm[i]
        p = pulse(int(0.03 * SR), [(170 + r * 0.02, 1.0), (780 + r * 0.05, 0.7), (1650, 0.35)],
                  decay=220 + r * 0.02, noise=0.55)
        x[i:i + len(p)] += p
    x = x[:len(rpm)]
    rasp = biquad_bandpass(x, 1250, 2.2) * 0.9 + biquad_bandpass(x, 2900, 3.5) * 0.45
    body = biquad_bandpass(x, 330, 1.4) * 0.6
    return finish(rasp + body + 0.12 * x, drive=2.8)


def track_four():
    """Inline-4 track bike: two fires per rev, deep airbox roar rising to a scream."""
    dur = 2.4
    rpm = rpm_curve([(0, 3200), (0.15, 3400), (0.35, 9000), (0.9, 13800), (1.15, 14200),
                     (1.35, 8200), (1.6, 6000), (2.4, 3300)], dur)
    x = np.zeros(len(rpm) + SR // 10)
    for i in firings(rpm, 2, 0.004):
        r = rpm[i]
        p = pulse(int(0.025 * SR), [(95 + r * 0.008, 1.0), (240 + r * 0.02, 0.8), (520, 0.4)],
                  decay=160 + r * 0.012, noise=0.25)
        x[i:i + len(p)] += p
    x = x[:len(rpm)]
    roar = lowpass(x, 900) * 1.2
    intake = biquad_bandpass(rng.normal(0, 1, len(x)) * (rpm / 14200) ** 2, 1500, 0.9) * 0.25
    scream = biquad_bandpass(x, 1900, 2.5) * 0.35 * (rpm / 14200) ** 2
    # Over-run pops on the closed-throttle drop.
    for t0 in (1.42, 1.55, 1.71):
        j = int(t0 * SR)
        pop = pulse(int(0.05 * SR), [(140, 1.0), (420, 0.6)], decay=70, noise=1.2)
        x2 = np.zeros(len(x))
        x2[j:j + len(pop)] = pop[:len(x) - j]
        roar += 0.9 * x2
    return finish(roar + intake + scream, drive=2.2)


if __name__ == "__main__":
    write("mode_off_2t.wav", two_stroke())
    write("mode_on_track.wav", track_four())
