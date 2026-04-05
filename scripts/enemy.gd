extends StaticBody2D

var health := 3

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()

func _on_player_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var dir = sign((body.global_position - global_position).x)
		body.take_damage(1, Vector2(dir * 100, -150))
