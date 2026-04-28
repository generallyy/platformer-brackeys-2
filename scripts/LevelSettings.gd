extends Node

## enables rush, the game mode.
@export var game_mode_enabled: bool = true
@export var round_time_limit: float = 60.0
@export var points_to_win: int = 10
## bool for revenge bombs, when you lose all of your lives.
@export var ghost_bombs_enabled: bool = true
## If True, there is a required N - 1 kills per player
## in order to see the goal. For each player at the goal,
## the requirement decrements.
@export var kills_required_for_goal: bool = false
## Forces only one powerup to be visible.
## Used for Debug. Use the String name!
@export var debug_forced_powerup: String = "" # String name!

func _ready() -> void:
	PowerupIds.debug_forced_powerup = debug_forced_powerup
