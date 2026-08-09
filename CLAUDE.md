# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Godot 4.6 (`gl_compatibility` renderer) 2D multiplayer platformer/brawler. GDScript only — no C#, no test framework, no linter. Entry scene is `res://scenes/ui/TitleScreen.tscn`; gameplay lives in `res://scenes/Main.tscn` driven by [main.gd](scripts/main.gd).

The editor binary on this machine is `C:\Program Files\Godot\Godot_v4.6.3-stable_win64.exe` (not on PATH).

```bash
"/c/Program Files/Godot/Godot_v4.6.3-stable_win64.exe" --path . --headless --quit
```

That import-and-quit is the closest thing to a build check — it surfaces parse errors and broken resource references. Run the game with `--path .` (no `--headless`). Export presets exist for Windows / Linux / Android (`export_presets.cfg`, gitignored). `launcher/` is a standalone PyInstaller updater that pulls releases from GitHub; it is unrelated to the game build.

## Session types

Three mutually exclusive modes, all set up by the `NetworkManager` autoload ([network_manager.gd](scripts/network_manager.gd)) before `Main.tscn` loads:

| Mode | Peer | Notes |
|---|---|---|
| Online | `ENetMultiplayerPeer` | Host binds `DEFAULT_PORT` 8080; clients dial a playit.gg tunnel |
| Solo | `OfflineMultiplayerPeer` | `play_solo()` |
| Local multiplayer | `OfflineMultiplayerPeer` | 2–4 players, one process, split input |

**`NetworkManager.owns_locally(node)` is the authority check, not `node.is_multiplayer_authority()`.** In local multiplayer every player node lives in one process, so authority ids never match `multiplayer.get_unique_id()`. Use `owns_locally()` anywhere you gate on "do I control this."

Local-multiplayer slots get **negative peer ids**: `LOCAL_PEER_ID_BASE = -1`, slot `i` → `-1 - i`. The 8-ball AI is `-99`. Any code that assumes peer ids are positive or that `1` means "the host's player" will break in local multiplayer.

## Networking idioms

There is **no `MultiplayerSynchronizer`**. Everything is hand-rolled, and two patterns cover nearly all of it.

**1. Request → server → broadcast.** Every state mutation follows this triple, e.g. accent color, cosmetics, team, checkpoints:

```gdscript
func request_x(...):                      # called from anywhere
    if NetworkManager.is_online() and not multiplayer.is_server():
        _req_x.rpc_id(1, ...); return
    _apply_x(...)

@rpc("any_peer", "reliable") func _req_x(peer_id, ...):   # server-side, validates sender
    if multiplayer.get_remote_sender_id() != peer_id: return
    _apply_x(...)

@rpc("authority", "call_local", "reliable") func _sync_x(...): ...  # applies everywhere
```

Clients never mutate shared state directly. When adding a new synced property, add all three pieces.

**2. Per-player relay via `_sync_peers`.** [player.gd](scripts/player.gd) `_send_state_sync()` pushes position/facing/animation/visibility every physics frame over an *unreliable* RPC. Clients send only to the server; the server re-broadcasts to each peer in that player's `_sync_peers` list. `main.gd` maintains those lists via `add_sync_peer` / `remove_sync_peer` on join and disconnect.

**The join handshake is the thing that most often breaks.** `main.gd::_request_state` is the single place where a newly connected client is brought up to date — it replays level, existing player spawns, sync-peer wiring, accent colors, cosmetics, mode state, names, teams, and the 8-ball session, in that order. Anything new that a late joiner must see has to be added there, and the value replayed must match what a freshly spawned node already looks like. (A mismatch between `player.gd`'s `accent_color` default and the authored `StickRig/Polygons` modulate in `Player.tscn` is exactly how the "player turns dark blue on join" bug happened.)

## Game modes

`gm_rush` ([game_mode.gd](scripts/game_mode.gd)) and `gm_bridge` ([bridge_wars_mode.gd](scripts/bridge_wars_mode.gd)) are sibling nodes under `Main`, both always present. `main.gd` picks `_active_mode` per level and mirrors mode signals into the HUD.

Which mode runs is **data on the level, not code**: each level scene may contain a `LevelSettings` node ([LevelSettings.gd](scripts/LevelSettings.gd)) whose exports drive game mode, round timer, points to win, stocks, ghost bombs, and whether powerups are offered. `_load_level_local()` reads it after instantiating the level. `debug_forced_powerup` there is the hook for testing a single powerup.

Modes are server-authoritative: scoring and round transitions run on the server and reach clients through `_sync_round_state` / `_sync_scores` / `_sync_kda_rpc`.

## Player

[player.gd](scripts/player.gd) (~1.6k lines) is a `CharacterBody2D` with an explicit `PlayerState` FSM (`_transition_to` / `_enter_state` / `_exit_state`) plus a large block of timer-driven flags ticked in `_tick_timers`. Tuning values live in a `PlayerStats` resource (`resources/player_stats.tres`), not in the script.

Input goes through `_in_axis()` / `_in_pressed()` / `_in_just_pressed()` — never `Input.*` directly. Those helpers route to the global `InputMap` for online/solo, and to the `LocalBindings` autoload for local-multiplayer slots. [local_bindings.gd](scripts/local_bindings.gd) deliberately bypasses `InputMap` entirely because every gamepad action in `project.godot` is bound with `device: -1` ("any device"), which would leak one local player's presses into every other's. Its header comment documents an empirically verified Switch Pro Controller button mapping — trust that comment over SDL button-name intuition.

Powerup ids are constants in [powerup_ids.gd](scripts/powerup_ids.gd) (`PowerupIds.DAMAGE_BOOST`, …) with per-id stack caps. Use the constants, never raw strings.

## Visuals and cosmetics

The player's body is a `StickFigureRig` ([stick_figure_rig.gd](scripts/stick_figure_rig.gd)) — a `Skeleton2D` with `Polygon2D` skin, an `AnimationTree` state machine (`BodySM` for the body, `UpperSM` + `UpperBlend` for upper-body attack overlays), and `Line2D` limbs. It is `@tool`-scripted, so editing it affects the editor viewport too.

`set_accent_color()` writes `_polygons.modulate` wholesale, overwriting the color authored in `Player.tscn`. Script defaults for `accent_color` must stay in sync with that scene value.

The rig's silhouette outline is generated by `_build_outline()` — at runtime and in the editor viewport (the generated nodes are unowned, so they never save into the scene). It traces each part's visible shape from the atlas texture's alpha (`assets/sprites/sticky-man.webp` — the polygon quads have transparent padding, and the head is a ring with a hole), then parents one closed `Line2D` per boundary directly to the part's bone (every part is rigidly weighted to a single bone), one z-index below the fills. `outline_width` is in screen pixels at the reference view (base_scale 0.05 × zoom 3), converted against that fixed reference — not the node's live scale — so the wardrobe preview and any zoom show it proportionally.

Three things about the outline are load-bearing and easy to undo by accident:

- **Each stroke sits outside the silhouette, not straddling it.** Several states fade the player (ghost 0.4, Cloak 0.4, spectator 0.4, Blink 0.5) and `modulate` inherits down to the outline. A stroke centered on the traced edge would show its normally-fill-covered inner half through the faded body as a band down every limb. `_outline_loops()` offsets each path outward by half a stroke (inward for the head's hole) so only `_OUTLINE_FILL_OVERLAP` of it hides under the fill. Known remaining limitation: where two parts' strokes overlap at a joint they still blend twice, so joints read slightly denser when translucent — fixing that properly needs flattening to one layer, which is the CanvasGroup route rejected for this rig.
- **Generated `Line2D`s must get explicit unique names** (`RigOutline<Part>_<i>`) and must release their name before `queue_free()`. Godot auto-renames collisions to `@RigOutline…@N`, which `_free_outline_nodes()`' prefix sweep misses — so a same-frame rebuild (what the wardrobe's `duplicate()` triggers) would leak outlines on every rebuild.
- Cosmetics are **not** outlined — they hang off sockets, outside the traced parts. If that becomes a problem, alpha-trace the cosmetic sprite at equip time rather than flattening the rig.

Cosmetics are `CosmeticItem` resources ([cosmetic_item.gd](scripts/cosmetic_item.gd)) under `assets/sprites/cosmetics/resources/`, discovered at runtime by `CosmeticItem.load_catalog(folder, slot)` and attached to named sockets on the rig. Adding a hat means adding a `.tres`, not editing code.

## Repo gotchas

- `scenes/**/*.tscn*.tmp` are Godot editor backups. Twelve are committed (tracked before `*.tmp` was gitignored) — ignore them when globbing scenes; the real files have no `.tmp` suffix.
- `.claude/` and `export_presets.cfg` are gitignored but present locally.
- `addons/rmsmartshape` (SmartShape2D) is the only vendored addon and is the exception to the `addons/*` ignore; levels depend on it.
- Join targets are hardcoded in [LobbyScreen.gd](scripts/LobbyScreen.gd)'s `JOIN_ADDRESSES` (localhost + two playit.gg tunnels). `NetworkManager.PLAYIT_HOST` is a leftover from the older free-text address flow.
- `README.md` is a joke placeholder — no information in it.
