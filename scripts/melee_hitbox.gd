extends AttackHitbox

func _init() -> void:
	lifetime = 0.12
	knockback_base = Vector2(670.0, -200.0)

func _handle_shield(body: Node2D) -> bool:
	return body.get("_is_shielding") != true
