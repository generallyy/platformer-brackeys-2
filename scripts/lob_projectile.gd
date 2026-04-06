extends ProjectileBase

const SPEED_X := 180.0
const LAUNCH_VY := -320.0
const MAX_LIFETIME := 2.0

@onready var visual = $Visual

var _gravity: float

func _init() -> void:
	WEAPON_NAME = "Lob"
	WEAPON_COOLDOWN = 0.8

func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _get_offset(t: float) -> Vector2:
	return Vector2(
		direction * SPEED_X * t,
		LAUNCH_VY * t + 0.5 * _gravity * t * t
	)

func _get_max_lifetime() -> float:
	return MAX_LIFETIME
