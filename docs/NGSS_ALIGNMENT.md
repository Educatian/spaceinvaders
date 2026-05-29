# Physics Lab — NGSS Alignment

The Physics Lab mode turns the shooter's gravity engine into a hands-on physical-science
sandbox. Every mechanic maps to a Next Generation Science Standards performance
expectation (PE), disciplinary core idea (DCI), science & engineering practice (SEP), or
crosscutting concept (CCC).

| In-game mechanic | NGSS | What the learner does |
|---|---|---|
| Bullet path curves by `Σ G·m / r²` near planets | **MS-PS2-4** (gravitational force depends on mass), **MS-PS2-5** (forces act at a distance via fields) | Predicts and adjusts shots, reasoning that bigger/closer planets bend the path more. |
| Gravity-field overlay (vector grid, falls off with 1/r²) | **MS-PS2-5**; CCC **Scale, Proportion & Quantity** | Sees the otherwise-invisible field; relates field strength to distance. |
| Orbit-insertion challenge (tangential speed + gravity = circular motion) | **MS-ESS1-2** (gravity governs orbital motion), HS-ESS1-4 (Kepler) | Finds the speed that keeps a satellite in orbit; explains why orbiting objects don't fall in. |
| Mass-comparison ("which planet bends more?") predict → test | **MS-PS2-4**; SEP **Engaging in argument from evidence** | Makes a prediction, fires, compares to the field/trajectory, revises. |
| Recoil: firing pushes the ship back | **MS-PS2-1 / MS-PS2-2** (Newton's 3rd law / forces & motion), HS-PS2-1 | Experiences action–reaction directly. |
| Telemetry → personal data review (claim–evidence) | SEP **Analyzing & interpreting data**, **Using mathematics & computational thinking** | Inspects own shot data; argues whether they improved at gravity compensation. |

**Crosscutting concepts** recur throughout: *Cause and Effect* (force → trajectory change),
*Systems and System Models* (the predicted-trajectory overlay is a model the learner tests),
and *Scale, Proportion, and Quantity* (the 1/r² relationship).

**Grade band:** primary target middle school (MS-PS2 / MS-ESS1); extensions (energy
conservation in slingshots, Kepler) reach into HS-PS2 / HS-PS3 / HS-ESS1.

**Assessment hook:** `telemetry.jsonl` + `analyze_telemetry.py` provide an evidence trail
(shot vectors, gravity-assist rate, accuracy per wave) suitable for formative assessment or
learning-analytics research.
