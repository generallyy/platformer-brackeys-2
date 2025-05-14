extends Area2D


func _on_body_entered(body):
	if body.name == "Player":
		var main = get_tree().get_root().get_node("Main")
		main.call_deferred("load_level", "res://scenes/levels/Level1.tscn")

