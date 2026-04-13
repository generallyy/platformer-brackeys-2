'''
	Toggles Collision. For Parkour Courses.
'''
extends Area2D

var _phasing := false
@export_file("*.tscn") var target_level_path: String

var _player_nearby: Node = null


func _process(_delta: float) -> void:
	if not (_player_nearby is CharacterBody2D and _player_nearby.has_method("die")):
		return
	if NetworkManager.is_active() and not _player_nearby.is_multiplayer_authority():
		return
	if Input.is_action_just_pressed("interact"):
		_phasing = !_phasing
		var key := _get_interact_key()
		if _phasing:
			$PromptLabel.text = "%s — Restore Collision" % [key]
			for body in get_tree().get_nodes_in_group("player"):
				if body != _player_nearby:
					_player_nearby.add_collision_exception_with(body)
		else:
			$PromptLabel.text = "%s — Toggle Collision" % [key]
			for body in get_tree().get_nodes_in_group("player"):
				if body != _player_nearby:
					_player_nearby.remove_collision_exception_with(body)

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
	var key := _get_interact_key()
	$PromptLabel.text = "%s — %s" % [key, "Restore Collision" if _phasing else "Toggle Collision"]
	$PromptLabel.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == _player_nearby:
		_player_nearby = null
		$PromptLabel.visible = false
