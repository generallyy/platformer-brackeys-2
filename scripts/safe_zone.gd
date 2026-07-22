extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not NetworkManager.owns_locally(body):
		return
	body.in_safe_zone = true

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not NetworkManager.owns_locally(body):
		return
	body.in_safe_zone = false
