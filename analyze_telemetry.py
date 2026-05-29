#!/usr/bin/env python3
"""Analyze Space Invaders "Physics Lab" learning telemetry.

The game's PHYSICS LAB mode logs one JSON object per line to
``telemetry.jsonl`` in the Godot user data directory. Each line is one of:

  * ``session_start`` - a run began  (mode, class, difficulty)
  * ``shot``          - the player fired (launch vector + gravity context)
  * ``hit``           - a player bullet struck an enemy
  * ``session_end``   - a run ended   (score + per-run shot/assist totals)

This script reads that file and prints summary metrics. It is pure Python 3
standard library and is robust to malformed / partial lines (a crash mid-write
should never break the whole analysis).

DEFAULT INPUT PATH (Windows):
    %APPDATA%/Godot/app_userdata/Space Invaders/telemetry.jsonl
You may also pass an explicit path as the first argument.

------------------------------------------------------------------------------
PEDAGOGICAL READING OF THE METRICS
------------------------------------------------------------------------------
The Physics Lab turns aiming into a *vector + gravity* problem: a projectile
launched at angle theta with speed v is continuously deflected by the
inverse-square field of nearby planets ( a = G*m / r^2 toward each body ).

* gravity-assist hit rate
    Fraction of HITS whose bullet actually passed close to a planet (its path
    was bent by gravity before connecting). A learner who is only taking
    straight-line shots will have a LOW rate; rising over a session indicates
    the learner is beginning to *exploit* gravity (banking / slingshot shots)
    rather than fighting it. This is the headline "did they learn the physics"
    signal.

* mean shot speed
    Reported for completeness; speed is fixed per weapon, so variance here
    reflects weapon choice, not aiming skill.

* distribution of shot angles
    How the learner orients shots. A spread that broadens over time (not just
    firing "forward") suggests the learner is reasoning about the *whole* field
    geometry, aiming away from the target to let gravity carry the round in.

* dist_from_straight_line (on hits)
    Perpendicular distance from the struck enemy to the bullet's ORIGINAL aim
    ray. ~0 == a straight shot; large == the shot had to curve to connect, i.e.
    direct evidence of successful gravity compensation / vector reasoning.

* accuracy over time / per wave
    Hits-per-shot bucketed by wave. Improvement across waves (where the planet
    configuration changes) is evidence of *transfer* - applying the gravity
    model to a new geometry rather than memorizing one screen.
"""

import json
import os
import sys
import math
from collections import defaultdict


def default_path():
    """Best-effort default location of telemetry.jsonl on each OS."""
    appdata = os.environ.get("APPDATA")
    if appdata:  # Windows
        return os.path.join(
            appdata, "Godot", "app_userdata", "Space Invaders", "telemetry.jsonl"
        )
    home = os.path.expanduser("~")
    # Linux / macOS fall-backs (Godot user data conventions).
    candidates = [
        os.path.join(home, ".local", "share", "godot", "app_userdata",
                     "Space Invaders", "telemetry.jsonl"),
        os.path.join(home, "Library", "Application Support", "Godot",
                     "app_userdata", "Space Invaders", "telemetry.jsonl"),
    ]
    for c in candidates:
        if os.path.exists(c):
            return c
    return candidates[0]


def load_events(path):
    """Return (events, bad_count). bad_count == -1 if the file is missing.

    Malformed JSON lines are counted and skipped so partial/corrupt logs still
    analyze cleanly.
    """
    events = []
    bad = 0
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except (ValueError, TypeError):
                    bad += 1
                    continue
                if isinstance(obj, dict):
                    events.append(obj)
                else:
                    bad += 1
    except FileNotFoundError:
        return [], -1
    return events, bad


def fnum(d, key, default=0.0):
    """Coerce a possibly-missing field to float, robust to bad types."""
    try:
        return float(d.get(key, default))
    except (TypeError, ValueError):
        return default


def angle_histogram(angles, buckets=12):
    """Histogram of shot angles over [-pi, pi] into `buckets` bins."""
    counts = [0] * buckets
    span = 2.0 * math.pi / buckets
    for a in angles:
        na = (a + math.pi) % (2.0 * math.pi) - math.pi  # normalize to [-pi, pi)
        idx = int((na + math.pi) / span)
        if idx < 0:
            idx = 0
        if idx >= buckets:
            idx = buckets - 1
        counts[idx] += 1
    return counts, span


def bar(n, scale):
    return "#" * int(round(n * scale))


def main(argv):
    path = argv[1] if len(argv) > 1 else default_path()
    print("Space Invaders - Physics Lab telemetry analysis")
    print("input: %s" % path)
    print("-" * 70)

    events, bad = load_events(path)
    if bad == -1:
        print("No telemetry file found at that path.")
        print("Play a run in PHYSICS LAB mode (press G on the start screen) "
              "to generate one.")
        return 1
    if not events:
        print("File present but no valid events were parsed.")
        if bad:
            print("(%d malformed line(s) skipped.)" % bad)
        return 1

    sessions = [e for e in events if e.get("event") == "session_start"]
    ends = [e for e in events if e.get("event") == "session_end"]
    shots = [e for e in events if e.get("event") == "shot"]
    hits = [e for e in events if e.get("event") == "hit"]

    total_sessions = len(sessions)
    total_shots = len(shots)
    total_hits = len(hits)
    assist_hits = sum(1 for h in hits if h.get("used_gravity"))

    print("total sessions      : %d" % total_sessions)
    print("total shots         : %d" % total_shots)
    print("total hits          : %d" % total_hits)
    if bad:
        print("malformed lines     : %d (skipped)" % bad)
    print()

    # Gravity-assist hit rate (of all hits, how many were curved shots).
    if total_hits:
        rate = 100.0 * assist_hits / total_hits
        print("gravity-assist hits : %d / %d  (%.1f%%)"
              % (assist_hits, total_hits, rate))
    else:
        print("gravity-assist hits : n/a (no hits logged)")

    # Fraction of SHOTS aimed to use gravity (intent, vs. outcome above).
    grav_shots = sum(1 for s in shots if s.get("used_gravity"))
    if total_shots:
        print("gravity-aimed shots : %d / %d  (%.1f%%)"
              % (grav_shots, total_shots, 100.0 * grav_shots / total_shots))

    # Mean shot speed.
    if shots:
        speeds = [fnum(s, "shot_speed") for s in shots]
        print("mean shot speed     : %.1f px/s" % (sum(speeds) / len(speeds)))
    print()

    # Distribution of shot angles.
    if shots:
        angles = [fnum(s, "shot_angle") for s in shots]
        counts, span = angle_histogram(angles)
        peak = max(counts) or 1
        scale = 30.0 / peak
        print("shot angle distribution (radians, %d bins):" % len(counts))
        for i, c in enumerate(counts):
            lo = -math.pi + i * span
            hi = lo + span
            print("  [%+5.2f, %+5.2f) %4d %s" % (lo, hi, c, bar(c, scale)))
        print()

    # Mean curvature of successful shots.
    if hits:
        offs = [fnum(h, "dist_from_straight_line") for h in hits]
        print("mean dist_from_straight_line on hits : %.1f px"
              % (sum(offs) / len(offs)))
        assisted_offs = [fnum(h, "dist_from_straight_line")
                         for h in hits if h.get("used_gravity")]
        if assisted_offs:
            print("  (gravity-assisted hits only        : %.1f px)"
                  % (sum(assisted_offs) / len(assisted_offs)))
        print()

    # Accuracy over time / per wave.
    shots_by_wave = defaultdict(int)
    hits_by_wave = defaultdict(int)
    assist_by_wave = defaultdict(int)
    for s in shots:
        shots_by_wave[int(fnum(s, "wave"))] += 1
    for h in hits:
        w = int(fnum(h, "wave"))
        hits_by_wave[w] += 1
        if h.get("used_gravity"):
            assist_by_wave[w] += 1

    waves = sorted(set(shots_by_wave) | set(hits_by_wave))
    if waves:
        print("accuracy per wave (hits / shots):")
        print("  wave   shots   hits   accuracy   grav-assist hits")
        for w in waves:
            sc = shots_by_wave.get(w, 0)
            hc = hits_by_wave.get(w, 0)
            acc = (100.0 * hc / sc) if sc else 0.0
            print("  %4d   %5d   %4d   %7.1f%%   %d"
                  % (w, sc, hc, acc, assist_by_wave.get(w, 0)))
        print()

    # Per-session end summary, if present.
    if ends:
        print("per-session results:")
        print("  #   score   shots   grav-assist hits")
        for i, e in enumerate(ends, 1):
            print("  %2d  %6d   %5d   %d"
                  % (i, int(fnum(e, "score")), int(fnum(e, "shots")),
                     int(fnum(e, "gravity_assist_hits"))))

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
