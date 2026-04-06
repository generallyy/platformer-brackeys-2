extends ProjectileBase


const SPEED := 100.0
const AMPLITUDE := 24.0
const FREQUENCY := 1
const MAX_LIFETIME := 1.8
@onready var visual = $Visual

func _init() -> void:
	WEAPON_NAME = "Sine Bolt"
	WEAPON_COOLDOWN = 0.5


func _get_offset(t: float) -> Vector2:
	return Vector2(
		direction * SPEED * t,
		-AMPLITUDE * sin(TAU * FREQUENCY * t)
	)

func _get_max_lifetime() -> float:
	return MAX_LIFETIME
