extends Area2D

var _player_nearby: Node = null

func _process(_delta: float) -> void:
	if _player_nearby and Input.is_action_just_pressed("interact"):
		get_tree().get_root().get_node("Main").open_wardrobe(_player_nearby)
		#$PromptLabel.text = "Equipped!"

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if NetworkManager.is_active() and not body.is_multiplayer_authority():
		return
	_player_nearby = body
	$PromptLabel.visible = true
	

func _on_body_exited(body: Node2D) -> void:
	if body == _player_nearby:
		_player_nearby = null
		$PromptLabel.visible = false
		
