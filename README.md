# Orc Defense

A top-down tower-defense game (Godot 4, Android). Orcs walk a path toward your
base — place towers to stop them.

## How to get the APK on your phone

1. Every push to `main` triggers **GitHub Actions** (see the **Actions** tab).
2. When the build finishes (~5–10 min), the APK is attached to the
   **[latest release](../../releases/tag/latest)** and also as a build artifact.
3. Download `orc-defense.apk`, open it on your phone, allow "install from
   unknown sources", install, and play.

## Phase 1 (current)

- One snaking map, waves of orcs
- Tap empty ground to place a tower (costs gold)
- Towers auto-shoot the nearest orc; kills drop gold
- Base has lives; lose them all = game over (tap to restart)
- Art is placeholder shapes — real art comes in a later phase.

## Project layout

- `scenes/Main.tscn` — entry scene
- `scripts/Main.gd` — game loop, waves, economy, HUD, input
- `scripts/Enemy.gd` / `Tower.gd` / `Bullet.gd` — the units
- `.github/workflows/android.yml` — builds the APK automatically

## License

All Rights Reserved — see [LICENSE](LICENSE). This is a proprietary project;
no copying, redistribution, or commercial use is permitted.
