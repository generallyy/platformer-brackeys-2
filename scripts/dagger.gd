extends ProjectileBase

const SPEED := 400.0
const STRAIGHT_DISTANCE := 64.0
const LAND_LIFETIME := 1.0

@onready var visual = $Visual

var _gravity: float
var _straight_time: float
var _landed := false

func _init() -> void:
	WEAPON_NAME = "Dagger"
	WEAPON_COOLDOWN = 0.5

func _ready() -> void:
	_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
	_straight_time = STRAIGHT_DISTANCE / SPEED  # 0.16 s

func _get_offset(t: float) -> Vector2:
	var x := direction * SPEED * t
	var y := 0.0
	if t > _straight_time:
		var fall_t := t - _straight_time
		y = 0.5 * _gravity * fall_t * fall_t
	return Vector2(x, y)

func _on_landed() -> void:
	if _landed:
		return
	_landed = true
	set_process(false)
	await get_tree().create_timer(LAND_LIFETIME).timeout
	_despawn()
