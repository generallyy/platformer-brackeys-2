extends Area2D

var _triggered := false
@export_file("*.tscn") var target_level_path: String

func _on_body_entered(body) -> void:
	if _triggered:
		return
	if not (body is CharacterBody2D and body.has_method("die")):
		return
	if target_level_path == "":
		print("No level path set!")
		return
	_triggered = true
	var main = get_tree().get_root().get_node("Main")
	if NetworkManager.is_online():
		if multiplayer.is_server():
			main._broadcast_load_level(target_level_path)
		else:
			main._req_load_level.rpc_id(1, target_level_path)
	else:
		await main.load_level(target_level_path)
