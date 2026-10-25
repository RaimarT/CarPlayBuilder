#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Raimar Tasche
# SPDX-License-Identifier: MIT

"""Select an available iPhone on iOS 26.4+ from simctl's JSON output."""

import json
import sys


def select_simulator(devices):
    candidates = []
    for runtime, entries in devices.items():
        if ".iOS-" not in runtime:
            continue
        version = tuple(int(part) for part in runtime.split(".iOS-")[1].split("-"))
        if version < (26, 4):
            continue
        for device in entries:
            if device.get("isAvailable") and device["name"].startswith("iPhone"):
                candidates.append((version, device["name"], device["udid"]))
    if not candidates:
        raise SystemExit("No available iPhone simulator on iOS 26.4 or later.")
    return max(candidates)[2]


if __name__ == "__main__":
    print(select_simulator(json.load(sys.stdin)["devices"]))
