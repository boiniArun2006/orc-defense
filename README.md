# Orc Defense

A top-down tower-defense game (Godot 4, Android). Orcs walk a path toward your
base — place towers to stop them.

## How to get the APK on your phone

1. Every push to `main` triggers **GitHub Actions** (see the **Actions** tab).
2. When the build finishes (~5–10 min), the APK is attached to the
   **[latest release](../../releases/tag/latest)** and also as a build artifact.
3. Download `orc-defense.apk`, open it on your phone, allow "install from
   unknown sources", install, and play.

## Phase 6 (current)

- 24+ generated maps across 3 biomes with ponds, groves, ground detail and depth
- Two-part turrets (stone base + gun that turns to track its target)
- Enemy variants: runners (fast/frail) and armored brutes force real tactics
- AIR STRIKE: drag a line and planes fly in to carpet-bomb the corridor
- Hard-earned progression: turret unlocks spread to char levels 4/8/13/18,
  lean coin economy — losing and replanning is part of the game
- Proper loading screens with tactics tips, themed HUD and menus

## Project layout

- `scenes/Loading.tscn` — entry scene (boot + level loading screen)
- `scripts/Battle.gd` — game loop, waves, economy, HUD, input
- `scripts/Enemy.gd` / `Turret.gd` / `StrikePlane.gd` / `Bullet.gd` — the units
- `scripts/MapData.gd` / `GroundLayer.gd` — map generation and rendering
- `.github/workflows/android.yml` — builds the APK automatically

## License

All Rights Reserved — see [LICENSE](LICENSE). This is a proprietary project;
no copying, redistribution, or commercial use is permitted.
