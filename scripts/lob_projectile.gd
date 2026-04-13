extends ProjectileBase

const SPEED_X := 180.0
const LAUNCH_VY := -320.0
const MAX_LIFETIME := 2.0

@onready var visual = $Visual

func _init() -> void:
	WEAPON_NAME = "Lob"
	WEAPON_COOLDOWN = 0.1

func _get_offset(t: float) -> Vector2:
	return Vector2(
		direction * SPEED_X * t,
		LAUNCH_VY * t + 0.5 * gravity * t * t
	)

func _get_max_lifetime() -> float:
	return MAX_LIFETIME
