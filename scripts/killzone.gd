extends Area2D

func _on_body_entered(body):
	if body is CharacterBody2D and body.has_method("die"):
		if NetworkManager.owns_locally(body):
			body.die(true)
