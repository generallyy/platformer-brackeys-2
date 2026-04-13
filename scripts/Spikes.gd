extends Area2D

const CONTACT_KNOCKBACK := Vector2(50.0, -100.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):		
		# transform.y points "down" relative to the node, so -transform.y is "away"
		var push_direction = -global_transform.y 
		var final_knockback = push_direction * 150.0 # Constant force
		body.take_damage(1, final_knockback)
