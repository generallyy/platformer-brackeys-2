extends Node

## enables rush, the game mode.
@export var game_mode_enabled: bool = true
## "rush" = existing Rush mode; "bridge_wars" = Bridge Wars team mode.
@export_enum("rush", "bridge_wars") var game_mode_type: String = "rush"
@export var round_time_limit: float = 60.0
@export var points_to_win: int = 10
## Bridge Wars: if false, players have a limited number of lives.
@export var bridge_wars_infinite_lives: bool = true
## Bridge Wars: lives per player when bridge_wars_infinite_lives is false.
@export var bridge_wars_lives_per_player: int = 3
## bool for revenge bombs, when you lose all of your lives.
@export var ghost_bombs_enabled: bool = true
## If True, there is a required N - 1 kills per player
## in order to see the goal. For each player at the goal,
## the requirement decrements.
@export var kills_required_for_goal: bool = false
## If false, the powerup selection screen is skipped during intermission.
@export var powerups_enabled: bool = true
## Forces only one powerup to be visible.
## Used for Debug. Use the String name!
@export var debug_forced_powerup: String = "" # String name!

func _ready() -> void:
	PowerupIds.debug_forced_powerup = debug_forced_powerup
