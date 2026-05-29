<div align="center">

# 🚀 SPACE INVADERS — Roguelite Arcade Shooter

A top-down arena shooter built in **Godot 4.6**, playable right in your browser.

### ▶ **[Play now → educatian.github.io/spaceinvaders](https://educatian.github.io/spaceinvaders/)**

<sub>(First load fetches the WebAssembly build, so give it a few seconds.)</sub>

<img src="docs/screenshots/menu.png" alt="Space Invaders — ship select screen" width="420">

</div>

---

## ✨ Features

- **3 ship classes** — Assault / Tank / Scout, each with distinct stats and a unique hull
- **5 weapons** with per-weapon upgrade levels — Single, Triple, Spiral, Laser, Homing
- **Roguelite upgrade drafts** — pick 1 of 3 cards after each wave to build your run
- **3 difficulties** + persistent high scores, achievements, and meta credits
- **Waves, bosses** (multiple attack patterns), **elites, and biomes**
- **Powerups, combo multiplier, dash, screen-clearing bomb**
- Game feel: hit flash, damage numbers, screen shake, camera punch, gamepad + rumble
- Synthesized sound effects and music — **no audio files**

## 🎮 Controls

| Input | Action | | Input | Action |
|---|---|---|---|---|
| WASD / Arrows | Move | | Shift / Right-click | Dash |
| Mouse | Aim | | E / Middle-click | Bomb (when charged) |
| Left-click / Space | Fire | | Esc / P | Pause |
| Q / Tab | Switch weapon | | O · M | Options · Mute |

Gamepad supported (left stick move, right stick aim, triggers/buttons for fire/dash/bomb).

## 🛠 Tech

Single-file game logic in GDScript (`scripts/Game.gd`) with procedural + sprite rendering,
particles (`Fx.gd`), and synthesized audio (`Sfx.gd`). Ship/enemy art from the CC0
[Kenney Space Shooter Redux](https://opengameart.org/content/space-shooter-redux) pack.

The `docs/` folder is the GitHub Pages deployment — a no-threads web build that runs
without the COOP/COEP headers GitHub Pages can't set.

### Build the web version yourself

```bash
godot --headless --export-release "Web" docs/index.html
```

## 📄 License

Game code: MIT. Sprite art: CC0 (Kenney). Built with [Godot Engine](https://godotengine.org) 4.6.
