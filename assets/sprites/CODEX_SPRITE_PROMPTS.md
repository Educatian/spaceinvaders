# Sprite generation with Codex (gpt-5.5) imagegen — interactive

Headless `codex exec` does NOT support image generation. Run Codex **interactively**:

```
cd C:\Users\jewoo\Projects\SpaceInvaders
codex
```

Then paste the prompt below. Save each PNG into `assets/sprites/` with the EXACT filenames so the
game auto-detects them (it already falls back to procedural art when a file is missing).

Required files (transparent background, top-down view):
- `player.png`  — sleek arrow/jet fighter, nose pointing RIGHT (+X), blue/cyan neon, ~128x128
- `grunt.png`   — small red spiky drone with a single glowing eye, ~96x96
- `fast.png`    — small orange dart/triangle, sense of speed, ~80x80
- `tank.png`    — bulky purple hexagonal cruiser with a gold core, ~160x160
- `bullet.png`  — bright yellow energy bolt, oriented horizontally (points RIGHT), ~48x24
- `background.png` — dark space field, subtle nebula + stars, 480x720, seamless-ish, NOT transparent

## Paste-in prompt

Generate a cohesive set of 2D game sprites in a clean neon-vector arcade style,
flat shading with soft glow, crisp edges, TRANSPARENT background (except the
background image). Top-down orientation. Consistent palette across all sprites
(deep space navy base; player = cyan/blue; enemies = red / orange / purple;
projectiles = warm yellow). Produce these as separate PNG files and save them to
the current folder `assets/sprites/` with these exact names and intents:

1. player.png — sleek single-seat fighter seen from above, nose pointing to the
   RIGHT, glowing engines at the back, cyan/blue.
2. grunt.png — small hostile drone, spiky red body, one glowing eye, top-down.
3. fast.png — tiny fast orange interceptor, dart/arrow shape, motion vibe.
4. tank.png — heavy purple hexagonal warship with a gold energy core, armored.
5. bullet.png — a single bright yellow plasma bolt, elongated, pointing RIGHT.
6. background.png — 480x720 vertical dark-space backdrop, faint nebula and stars,
   low contrast so gameplay reads clearly; opaque (no transparency).

Keep all sprites center-aligned in their canvas with a little padding.

## After generating

The game checks `res://assets/sprites/<name>.png` at startup and switches from
procedural shapes to your textures automatically. Just re-run the project:
ask Claude to `run_project`, or in Godot press F5.
