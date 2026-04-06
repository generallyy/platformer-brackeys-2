extends Area2D

var _triggered := false

func _on_body_entered(body) -> void:
	if _triggered:
		return
	if not (body is CharacterBody2D and body.has_method("die")):
		return
	if NetworkManager.is_active() and not multiplayer.is_server():
		return
	_triggered = true
	var main = get_tree().get_root().get_node("Main")
	if NetworkManager.is_active():
		main.load_level.rpc("res://scenes/levels/Level1.tscn")
	else:
		await main.load_level("res://scenes/levels/Level1.tscn")
