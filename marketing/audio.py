"""Synthesises a soundtrack for each rendered video and muxes it in.

A soft looping arpeggio sits under the sound cues the engine recorded
(typing, tile flips, pops, ticks, the win chime), so no licensed music is
needed. Usage: python3 audio.py <outDir>
"""

import json
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100


def env(n, attack=0.005, decay=0.15):
    t = np.arange(n) / SR
    a = np.clip(t / attack, 0, 1)
    return a * np.exp(-t / decay)


def tone(freq, dur, decay=0.15, kind="sine"):
    n = int(SR * dur)
    t = np.arange(n) / SR
    if kind == "tri":
        w = 2 / np.pi * np.arcsin(np.sin(2 * np.pi * freq * t))
    else:
        w = np.sin(2 * np.pi * freq * t)
    return w * env(n, decay=decay)


def noise(dur, decay, seed=0, lp=0.6):
    n = int(SR * dur)
    x = np.random.default_rng(seed).standard_normal(n)
    # One-pole low-pass to soften the hiss.
    y = np.zeros(n)
    acc = 0.0
    for i in range(n):
        acc += lp * (x[i] - acc)
        y[i] = acc
    return y * env(n, 0.001, decay)


def sweep(dur):
    n = int(SR * dur)
    t = np.arange(n) / SR
    x = np.random.default_rng(3).standard_normal(n)
    out = np.zeros(n)
    acc = 0.0
    for i in range(n):
        k = 0.02 + 0.25 * np.sin(np.pi * t[i] / dur)
        acc += k * (x[i] - acc)
        out[i] = acc
    return out * np.sin(np.pi * t / dur) ** 2


def layer(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


SFX = {
    "type": layer(0.35 * noise(0.04, 0.012, 1, 0.5), 0.2 * tone(1800, 0.03, 0.01)),
    "flip": layer(0.4 * tone(520, 0.12, 0.05, "tri"), 0.25 * tone(1040, 0.08, 0.03)),
    "pop": 0.4 * tone(880, 0.12, 0.05),
    "tick": layer(0.5 * tone(1400, 0.08, 0.02), 0.3 * noise(0.03, 0.008, 2, 0.8)),
    "whoosh": 0.5 * sweep(0.5),
}


def chime(notes, step=0.09, decay=0.6):
    out = np.zeros(int(SR * (step * len(notes) + 1.4)))
    for i, f in enumerate(notes):
        s = int(i * step * SR)
        w = layer(0.28 * tone(f, 1.3, decay, "tri"), 0.12 * tone(f * 2, 1.0, decay / 2))
        out[s:s + len(w)] += w
    return out


SFX["win"] = chime([523.25, 659.25, 783.99, 1046.5])
SFX["chime"] = 0.7 * chime([783.99, 1046.5], 0.12)


def bed(dur):
    """C major arpeggio over a gentle pulse, 110 bpm."""
    n = int(SR * dur)
    out = np.zeros(n + SR * 2)
    beat = 60 / 110 / 2
    prog = [[261.63, 329.63, 392.0, 523.25], [220.0, 261.63, 329.63, 440.0],
            [174.61, 220.0, 261.63, 349.23], [196.0, 246.94, 293.66, 392.0]]
    i = 0
    t = 0.0
    while t < dur:
        chord = prog[(i // 8) % 4]
        f = chord[i % 4] * (2 if (i // 4) % 2 else 1)
        w = 0.09 * tone(f, 0.6, 0.25, "tri")
        s = int(t * SR)
        out[s:s + len(w)] += w
        if i % 4 == 0:
            k = 0.18 * tone(chord[0] / 4, 0.5, 0.18)
            out[s:s + len(k)] += k
        i += 1
        t += beat
    out = out[:n]
    fade = int(SR * 0.8)
    out[:fade] *= np.linspace(0, 1, fade)
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


def mix(dur, events):
    n = int(SR * dur)
    out = bed(dur)
    for e in events:
        w = SFX.get(e["type"])
        if w is None:
            continue
        s = int(e["t"] * SR)
        if s >= n:
            continue
        w = w[: n - s]
        out[s:s + len(w)] += w
    peak = np.max(np.abs(out)) or 1
    return np.tanh(out / peak * 1.2) * 0.85


def write_wav(path, data):
    pcm = (np.clip(data, -1, 1) * 32767).astype(np.int16)
    stereo = np.repeat(pcm[:, None], 2, axis=1)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(stereo.tobytes())


def main(out_dir):
    for ev in sorted(Path(out_dir).glob("day-*/*.events.json")):
        base = ev.with_name(ev.name.replace(".events.json", ""))
        silent = base.with_suffix(".silent.mp4")
        final = base.with_suffix(".mp4")
        if not silent.exists():
            continue
        info = json.loads(ev.read_text())
        wav = base.with_suffix(".wav")
        write_wav(wav, mix(info["dur"], info["events"]))
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(silent), "-i", str(wav),
                        "-c:v", "copy", "-c:a", "aac", "-b:a", "160k", "-shortest",
                        "-movflags", "+faststart", str(final)], check=True)
        silent.unlink()
        wav.unlink()
        ev.unlink()
        print("muxed", final)


if __name__ == "__main__":
    main(sys.argv[1])
