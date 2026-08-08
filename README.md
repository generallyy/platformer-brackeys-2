# Stick Brawl (platformer-brackeys-2)

A 2D multiplayer platformer/brawler built in **Godot 4.6** (GDScript, `gl_compatibility` renderer). Stick figures with skeletal animation race, fight, and knock each other around across handmade levels — solo, online, or up to 4 players on one screen.

## Features

- **Three session types**
  - **Solo** — offline free play.
  - **Online multiplayer** — one player hosts (port 8080), others join through a playit.gg tunnel. Hand-rolled server-authoritative networking (no `MultiplayerSynchronizer`), with automatic client reconnection.
  - **Local multiplayer** — 2–4 players in one window with a shared dynamic camera. One keyboard slot plus any number of gamepads, each with per-slot rebindable controls.
- **Game modes** (chosen per level via a `LevelSettings` node)
  - **Rush** — race to the goal zone over multiple rounds. Finish placement and kills earn points; stocks limit deaths per round; ties go to sudden death. First to the target score wins.
  - **Bridge Wars** — two teams (red/blue) fight to cross the enemy flag. Team scoring, optional limited lives, team spawn points.
- **Combat** — melee swings, a zap attack, throwable weapons (dagger, boomerang, sine bolt, lob shots, homing "Homer" swarm, confusion ray), a rechargeable shield, knockback, i-frames, and bombs droppable by ghosts of dead players.
- **Powerups** — between rounds players pick from an offer of stackable passives (damage/knockback/speed boosts, extra hearts, extra jumps, lifesteal, big melee, ghost hunter…) and one-shot actives (speed surge, invisibility, teleport, heart reset…). IDs and stack caps live in [powerup_ids.gd](scripts/powerup_ids.gd).
- **Cosmetics & wardrobe** — accent colors and hat/face cosmetics (`CosmeticItem` resources discovered at runtime) equipped at wardrobe stations, synced to all peers.
- **Side attractions** — an in-game blackjack table (`P`) and a full 8-ball pool minigame (`B`) with challenges between players and a table AI.
- **Extras** — checkpoints, moving platforms, hazards, spectator/ghost mode with camera-follow spectating, kill feed / KDA HUD, touch controls, and a net-stats debug overlay (`F3`).

## Running the game

Open the project in **Godot 4.6** and hit Play. The entry scene is `scenes/ui/TitleScreen.tscn`.

From the command line (Windows, editor binary not on PATH):

```bash
"/c/Program Files/Godot/Godot_v4.6.3-stable_win64.exe" --path .
```

Quick "build check" (surfaces parse errors and broken resource references):

```bash
"/c/Program Files/Godot/Godot_v4.6.3-stable_win64.exe" --path . --headless --quit
```

### Hosting / joining online

The host binds port **8080** (`NetworkManager.DEFAULT_PORT`); clients connect to one of the addresses hardcoded in [LobbyScreen.gd](scripts/LobbyScreen.gd) (`JOIN_ADDRESSES` — localhost plus two playit.gg tunnels). To play over the internet, run a playit.gg tunnel pointing at the host's port 8080 and update those addresses.

## Controls (keyboard defaults)

| Action | Key |
|---|---|
| Move | A / D (or arrows) |
| Jump / double jump | Space |
| Dash / air boost | F |
| Throw weapon | Z |
| Melee (moving) / Zap (standing) | X |
| Shield (hold) | V |
| Interact (stations, checkpoints, spectate) | C |
| Use active powerup | G |
| Blackjack / 8-ball menu | P / B |
| Pause | Esc |
| Net debug overlay | F3 |

Gamepads work everywhere; local-multiplayer slots get their own rebindable bindings (stored in `user://local_keybinds.cfg`).

## Project layout

| Path | What lives there |
|---|---|
| `scenes/Main.tscn` + [main.gd](scripts/main.gd) | Gameplay orchestrator: spawning, level loads, join handshake, RPC hub |
| `scripts/network_manager.gd` | Autoload; session setup (host/join/solo/local), reconnect logic |
| `scripts/player.gd` | Player FSM (movement, combat, powerups, sync) |
| `scripts/game_mode.gd` / `bridge_wars_mode.gd` | Rush and Bridge Wars modes |
| `scripts/stick_figure_rig.gd` | Skeletal stick-figure rig with animation state machines |
| `scenes/levels/` | Levels; each may contain a `LevelSettings` node that drives mode/rules |
| `assets/sprites/cosmetics/resources/` | Cosmetic `.tres` items (add a file, not code, for a new hat) |
| `launcher/` | Standalone PyInstaller updater that pulls releases from GitHub (unrelated to the game build) |
| `addons/rmsmartshape` | Vendored SmartShape2D (levels depend on it) |

Development notes for AI-assisted work (architecture, networking idioms, gotchas) are in [CLAUDE.md](CLAUDE.md).
