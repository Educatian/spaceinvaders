# Space Invaders — Roguelite Arcade Shooter

A top-down arena shooter built in **Godot 4.6**, playable in the browser.

## ▶ Play now

**https://educatian.github.io/spaceinvaders/**

(First load fetches the WebAssembly build, so give it a few seconds.)

## Features

- **3 ship classes** — Assault / Tank / Scout, each with distinct stats and a unique hull
- **5 weapons** with per-weapon upgrade levels — Single, Triple, Spiral, Laser, Homing
- **Roguelite upgrade drafts** — pick 1 of 3 cards after each wave to build your run
- **3 difficulties** + persistent high scores, achievements, and meta credits
- **Waves, bosses (with multiple attack patterns), elites, and biomes**
- **Powerups, combo multiplier, dash, screen-clearing bomb**
- Game feel: hit flash, damage numbers, screen shake, camera punch, gamepad + rumble
- Synthesized sound effects and music (no audio files)

## Controls

| Input | Action |
|---|---|
| WASD / Arrows | Move |
| Mouse | Aim |
| Left-click / Space | Fire |
| Q / Tab | Switch weapon |
| Shift / Right-click | Dash |
| E / Middle-click | Bomb (when charged) |
| Esc / P | Pause · **O** Options · **M** Mute |

Gamepad is supported (left stick move, right stick aim, triggers/buttons for fire/dash/bomb).

## Tech

Single-file game logic in GDScript (`scripts/Game.gd`) with procedural + sprite rendering,
particles (`Fx.gd`) and synthesized audio (`Sfx.gd`). Ship/enemy art from the CC0
[Kenney Space Shooter Redux](https://opengameart.org/content/space-shooter-redux) pack.

## Build the web version yourself

```bash
godot --headless --export-release "Web" docs/index.html
```

The `docs/` folder is what GitHub Pages serves (a no-threads web build, so it runs without
the COOP/COEP headers GitHub Pages can't set).
