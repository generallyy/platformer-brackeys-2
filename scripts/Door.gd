'''
	Acts like a Level Transition, however, one must press C
		in order to transition levels. 
		Must specify destination in the inspector.
'''
extends Area2D

var _triggered := false
@export_file("*.tscn") var target_level_path: String

var _player_nearby: Node = null


func _process(_delta: float) -> void:
	if _triggered:
		return
	if not (_player_nearby is CharacterBody2D and _player_nearby.has_method("die")):
		return
	if NetworkManager.is_active() and not _player_nearby.is_multiplayer_authority():
		return
	if target_level_path == "":
		print("No level path set!")
		return
	if Input.is_action_just_pressed("interact"):
		_triggered = true
		get_tree().get_root().get_node("Main").request_load_level(target_level_path)

func _get_interact_key() -> String:
	for e in InputMap.action_get_events("interact"):
		if e is InputEventKey:
			return OS.get_keycode_string(e.physical_keycode)
	return "?"

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if NetworkManager.is_active() and not body.is_multiplayer_authority():
		return
	_player_nearby = body
	var actual_path := target_level_path
	if actual_path.begins_with("uid://"):
			# 1. Convert the "uid://..." string to an integer ID
			var id = ResourceUID.text_to_id(actual_path)
			# 2. Get the "res://" path from that ID
			actual_path = ResourceUID.get_id_path(id)
	var key := _get_interact_key()
	$PromptLabel.text = "%s — Go to %s!" % [key, actual_path.get_file().get_basename()]
	$PromptLabel.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == _player_nearby:
		_player_nearby = null
		$PromptLabel.visible = false
