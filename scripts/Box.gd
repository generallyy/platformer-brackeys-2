extends CharacterBody2D

const MASS     = 0.9
const FRICTION = 900.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	add_to_group("pushable")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	move_and_slide()
