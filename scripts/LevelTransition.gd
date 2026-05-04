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
	get_tree().get_root().get_node("Main").request_load_level(target_level_path)
