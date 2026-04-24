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
	if not _player_nearby.is_multiplayer_authority():
		return
	if Input.is_action_just_pressed("interact"):
		_phasing = !_phasing
		var key := InputUtils.get_action_key("interact")
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


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.is_multiplayer_authority():
		return
	_player_nearby = body
	var key := InputUtils.get_action_key("interact")
	$PromptLabel.text = "%s — %s" % [key, "Restore Collision" if _phasing else "Toggle Collision"]
	$PromptLabel.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == _player_nearby:
		_player_nearby = null
		$PromptLabel.visible = false
