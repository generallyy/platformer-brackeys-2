extends ProjectileBase

const SPEED := 350.0

func _ready() -> void:
	damage   = 0
	knockback = Vector2.ZERO

func _get_offset(t: float) -> Vector2:
	return Vector2(direction * SPEED * t, 0.0)

func _get_max_lifetime() -> float:
	return 3.0

func _on_hit_character(target: Node) -> void:
	if target.has_method("apply_confusion"):
		target.apply_confusion(2.0)
	_despawn()
