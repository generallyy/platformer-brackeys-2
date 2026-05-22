extends AttackHitbox

func _init() -> void:
	lifetime = 0.06
	knockback_base = Vector2(100.0, -300.0)

func _on_area_entered(area: Area2D) -> void:
	if area in _hit:
		return
	if area.is_in_group("shield"):
		queue_free()
		return
	super._on_area_entered(area)
