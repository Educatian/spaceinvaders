# Space Invaders — Educational Design Plan (Physics Lab)

> A roguelite space shooter whose **Physics Lab mode** turns its gravity engine into a
> hands-on, NGSS-aligned physical-science sandbox. This document is the design spec:
> learning goals, the mechanic-to-standard mapping, what is already built, and the planned
> extensions with feasibility notes.

- **Live game:** https://educatian.github.io/spaceinvaders/
- **Target band:** primary Middle School (MS-PS2, MS-ESS1); extensions reach HS-PS2 / HS-PS3 / HS-ESS1
- **Mode switch:** on the ship-select screen, key **G** (or click) toggles `MODE: ARCADE / PHYSICS LAB`. Arcade play is byte-for-byte unchanged when physics mode is off.

---

## 1. Design vision

The game already contains a real inverse-square gravity simulation: projectiles are
integrated under `a = Σ G·mₙ / rₙ²` from every planet ("gravity well") on the field.
That single physical law is the pedagogical core — instead of bolting quiz questions onto a
shooter, **the physics *is* the gameplay**: to hit anything you must reason about vectors,
mass, and distance. Learning is assessed not by multiple choice but by the **telemetry of
your shots** (angles, speeds, gravity-assisted hits), which doubles as a learning-analytics
data source.

Three design commitments:

1. **Phenomenon-first (NGSS 3D learning).** Every mechanic is a *phenomenon* the learner
   acts on and explains, not a fact to memorize.
2. **Make the invisible visible.** Fields, predicted trajectories, and ideal-orbit speeds
   are rendered so abstract relationships (1/r², v=√(GM/r)) become perceptible and testable.
3. **Evidence trail.** Play produces `telemetry.jsonl`; `analyze_telemetry.py` turns it into
   claim–evidence metrics for formative assessment or research.

---

## 2. Learning-theory framing

| Lens | How the game embodies it |
|---|---|
| **NGSS 3-dimensional learning** | DCIs (forces, gravity, orbits) + SEPs (modeling, data analysis, argument) + CCCs (cause/effect, scale, systems) are co-present in one task. |
| **Constructionism (Papert)** | The predicted-trajectory overlay is a *model the learner manipulates*; firing tests a hypothesis. |
| **Productive failure / variation theory** | Wells vary in mass and position per wave, so learners encounter the 1/r² and mass dependencies across contrasting cases. |
| **Formative assessment** | Immediate visual feedback (curve, orbit ring, field) + telemetry create a tight assess–revise loop. |
| **Learning analytics** | Shot vectors and gravity-assist rate are interpretable process data (cf. open game data / stealth assessment). |

---

## 3. Current implementation status

✅ = built and shipping, 🔶 = planned (Section 5).

| Capability | Status | Code anchor |
|---|---|---|
| Inverse-square gravity on projectiles | ✅ | `_gravity_accel(p)`, `_update_bullets` |
| Multiple gravity wells per wave (pos, **mass**, radius, color, name) | ✅ | `gravity_wells`, `_spawn_wells_for_wave()` |
| Predicted-trajectory overlay (toggle **T**) | ✅ | `_predict_trajectory()`, `_draw_trajectory()`, `opt_trajectory` |
| Planet rendering | ✅ | `_draw_wells()` |
| Mode toggle (arcade vs physics), HUD hint | ✅ | `physics_mode`, key **G** |
| Telemetry logging (shot/hit, gravity-assist) → `user://telemetry.jsonl` | ✅ | `telemetry`, `_telemetry_append/_flush/_session_start` |
| Telemetry analysis script | ✅ | `analyze_telemetry.py` |
| **Gravity-field visualization** | 🔶 | reuse `_gravity_accel` on a grid |
| **Orbit-insertion challenge** (v=√(GM/r)) | 🔶 | per-bullet orbit tracking |
| **Mass comparison** labels + spread | 🔶 | well `mass` already present |
| **Recoil = Newton's 3rd law** | 🔶 | `recoil_vel` on player |
| **Data-analysis learner view** | 🔶 | extend `analyze_telemetry.py` + in-game summary |

Constants today: `GRAV_G = 1.0` (folded into masses), `GRAV_MIN_R2 = 900.0` (≈30 px floor
preventing the 1/0 singularity and over-violent slingshots).

---

## 4. NGSS alignment — mechanic → standard

Performance Expectations (PE), Disciplinary Core Ideas (DCI), Science & Engineering
Practices (SEP), Crosscutting Concepts (CCC).

| In-game mechanic | PE | DCI | SEP / CCC | Learner action |
|---|---|---|---|---|
| Bullet path bends near planets by `Σ G·m/r²` | **MS-PS2-4** | PS2.B Gravitational interactions depend on mass & distance | CCC Cause & Effect | Predicts/adjusts shots; argues bigger/closer ⇒ more bend |
| Gravity-field overlay (1/r² vector grid) 🔶 | **MS-PS2-5** | PS2.B Forces act at a distance via fields | CCC Scale, Proportion & Quantity | Sees the field; relates strength to distance |
| Orbit-insertion ring + ideal v=√(GM/r) 🔶 | **MS-ESS1-2** | ESS1.B Gravity governs orbital motion | SEP Developing & using models | Finds the tangential speed for a stable orbit; explains why orbiting ≠ falling |
| Mass-comparison challenge 🔶 | **MS-PS2-4** | PS2.B Force depends on mass | SEP Engaging in argument from evidence | Predict → fire → compare → revise |
| Firing recoil pushes ship back 🔶 | **MS-PS2-1**, MS-PS2-2 | PS2.A Newton's 3rd law; force & motion | CCC Systems & System Models | Experiences action–reaction |
| Slingshot speed-up past a planet | HS-PS3-1/2 (extension) | PS3.A/B energy transfer (PE↔KE) | CCC Energy & Matter | Notices speed gain leaving a well; energy framing |
| Telemetry → personal data review 🔶 | — (practice-focused) | — | SEP Analyzing & interpreting data; Using math & computational thinking | Inspects own shot data; argues improvement |

**Recurring CCCs:** *Cause and Effect* (force → trajectory), *Scale/Proportion/Quantity*
(the 1/r² law), *Systems and System Models* (trajectory overlay as a tested model),
*Energy and Matter* (slingshot energy).

---

## 5. Planned extensions (chosen, with feasibility)

All four reuse the existing `_gravity_accel` / `_predict_trajectory` / telemetry engine, so
no new physics core is needed. All gated behind `physics_mode`; arcade untouched.

### 5.1 Gravity-field visualization — **MS-PS2-5** · feasibility ⭐⭐⭐
Toggle **F**. Sample `_gravity_accel(cell_center)` on a coarse grid (~48 px, ≤13×19 cells),
draw a short arrow per cell with length/alpha scaled (sqrt/log) to field magnitude, cyan,
low alpha, drawn under entities. Renders the invisible 1/r² field; learner relates arrow
length to distance from mass. *Pure draw call over an existing function — lowest risk.*

### 5.2 Orbit-insertion challenge — **MS-ESS1-2** · feasibility ⭐⭐⭐
Draw a target-orbit ring around each well (~radius×2.5). Track per-bullet time spent within
a tolerance band of that radius; ≥~0.6 s continuous ⇒ "ORBIT!" (fx + toast + telemetry
`{type:"orbit"}`, `orbits_achieved++`). Show the **ideal circular speed v=√(G·m/r)** for the
nearest well so learners compare their shot speed to the target. Teaches why orbiting
objects don't fall in. *Uses existing integration; adds per-bullet fields + a HUD readout.*

### 5.3 Mass comparison — **MS-PS2-4** · feasibility ⭐⭐⭐
Label each planet `M=…`, scale drawn size/density by mass, and ensure `_spawn_wells_for_wave`
produces a clear mass spread (one light, one heavy). Makes the mass dependence directly
comparable across planets. *Labels + draw scaling + tuning only — no new system.*

### 5.4 Recoil (Newton's 3rd law) — **MS-PS2-1** · feasibility ⭐⭐⭐ (recoil) / ⭐⭐ (full inertial flight)
On fire in physics mode, add a small `recoil_vel` impulse opposite the shot, decaying with
friction in `_process`; ship stays clamped to arena. Felt but not frustrating. *Small,
self-contained.* (Full Newton's-1st-law inertial drift for the ship is a larger game-feel
change — deferred.)

### 5.5 Data-analysis learner layer — SEP (data) · feasibility ⭐⭐⭐
Extend telemetry (orbit events, `field_strength_at_ship` per shot). Extend
`analyze_telemetry.py` to report orbits/session, gravity-assist hit rate, shot-angle
distribution, and accuracy per wave, each annotated with its NGSS PE. Optional in-game
end-of-run "your physics report" panel. Closes the loop: *play → data → scientific argument.*

---

## 6. Assessment & learning analytics

**Telemetry schema** (`user://telemetry.jsonl`, one JSON object per line; flushed every N
events and on game over):

- `{event:"session_start", mode, class, difficulty, t}`
- `{type:"shot", t, wave, shot_angle, shot_speed, ship_pos:[x,y], aim_target:[x,y], num_wells, nearest_well_dist, used_gravity, field_strength_at_ship}` 🔶 last field
- `{type:"hit", t, dist_from_straight_line, enemy_type}` — distance off the initial aim ray = proxy for a gravity-curved hit
- `{type:"orbit", t, well, bullet_speed}` 🔶

**Formative signals:** gravity-assist hit rate ↑, shots needed per kill ↓, orbit successes,
shot-angle spread narrowing per wave = developing vector/gravity reasoning.

**Research use:** process data suitable for stealth assessment / open-game-data style
analysis of strategic decision-making and conceptual change.

---

## 7. Roadmap

- **Phase 0 (done):** gravity engine, wells, trajectory overlay, mode toggle, telemetry, analysis script.
- **Phase 1 (next):** 5.1 field viz + 5.3 mass labels (pure-draw, lowest risk) → visible field + comparison.
- **Phase 2:** 5.2 orbit challenge + ideal-speed HUD (core NGSS MS-ESS1-2 hook).
- **Phase 3:** 5.4 recoil + 5.5 data-analysis layer (in-game report + richer `analyze_telemetry.py`).
- **Phase 4 (research/classroom):** teacher dashboard over telemetry; alignment validation with a science educator; small usability/learning pilot.

---

## 8. Standards index

- **MS-PS2-1** — Newton's 3rd law (recoil)
- **MS-PS2-2** — forces & motion
- **MS-PS2-4** — gravitational force depends on mass (core curve mechanic, mass comparison)
- **MS-PS2-5** — fields / forces at a distance (field visualization)
- **MS-ESS1-2** — gravity & orbital motion (orbit-insertion challenge)
- **HS-PS2-1**, **HS-PS3-1/2**, **HS-ESS1-4** — extensions (forces, energy conservation, Kepler)
- **SEPs** — Developing & using models; Analyzing & interpreting data; Using mathematics & computational thinking; Engaging in argument from evidence
- **CCCs** — Cause & Effect; Scale, Proportion & Quantity; Systems & System Models; Energy & Matter
