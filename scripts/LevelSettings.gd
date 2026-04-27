extends Node

@export var game_mode_enabled: bool = true
@export var round_time_limit: float = 60.0
@export var points_to_win: int = 10
@export var ghost_bombs_enabled: bool = true
@export var kills_required_for_goal: bool = false
@export var debug_forced_powerup: String = "" # String name!

func _ready() -> void:
	PowerupIds.debug_forced_powerup = debug_forced_powerup
