extends Area2D

var _round_claimed := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func reset_for_new_round() -> void:
	_round_claimed = false

func _on_body_entered(body: Node2D) -> void:
	if _round_claimed:
		return
	if not body.is_in_group("player"):
		return
	if NetworkManager.is_active() and not body.is_multiplayer_authority():
		return
	_round_claimed = true
	var peer_id := body.get_multiplayer_authority() if NetworkManager.is_active() else 1
	get_tree().get_root().get_node("Main").goal_reached(peer_id)
