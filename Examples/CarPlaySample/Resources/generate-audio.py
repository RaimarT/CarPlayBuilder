#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Raimar Tasche
# SPDX-License-Identifier: MIT

"""Regenerate the original, eight-second sample loops with only Python's stdlib."""

import math
from pathlib import Path
import struct
import wave


SAMPLE_RATE = 16000
NOTES = {
    "morning": [261.63, 329.63, 392.00, 523.25, 392.00, 329.63, 293.66, 392.00],
    "coast": [220.00, 261.63, 329.63, 392.00, 329.63, 261.63, 196.00, 261.63],
    "night": [196.00, 246.94, 293.66, 369.99, 293.66, 246.94, 164.81, 196.00],
}


def render_loop(name, notes):
    frames = bytearray()
    for frame in range(SAMPLE_RATE * 8):
        time = frame / SAMPLE_RATE
        beat = time % 1
        envelope = min(beat / 0.02, 1) * max(0, 1 - beat) ** 2
        frequency = notes[int(time)]
        tone = math.sin(2 * math.pi * frequency * time)
        tone += 0.2 * math.sin(2 * math.pi * frequency * 2 * time)
        frames.extend(struct.pack("<h", int(tone * envelope * 6000)))
    with wave.open(str(Path(__file__).with_name(name + ".wav")), "wb") as audio:
        audio.setparams((1, 2, SAMPLE_RATE, 0, "NONE", "not compressed"))
        audio.writeframes(frames)


if __name__ == "__main__":
    for track_name, track_notes in NOTES.items():
        render_loop(track_name, track_notes)
