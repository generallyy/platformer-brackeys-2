extends Area2D

var _triggered := false
@export_file("*.tscn") var target_level_path: String

func _on_body_entered(body) -> void:
	if _triggered:
		return
	if not (body is CharacterBody2D and body.has_method("die")):
		return
	if NetworkManager.is_active() and not multiplayer.is_server():
		return
	if target_level_path == "":
			print("No level path set!")
			return
	_triggered = true
	var main = get_tree().get_root().get_node("Main")
	if NetworkManager.is_active():
		main.load_level.rpc(target_level_path)
	else:
		await main.load_level(target_level_path)
