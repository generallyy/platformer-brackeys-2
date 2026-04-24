extends Area2D

var _finished_peers: Array = []

func reset_for_new_round() -> void:
	_finished_peers.clear()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if NetworkManager.is_active() and not body.is_multiplayer_authority():
		return
	var gm: Node = get_tree().get_root().get_node("Main").game_mode
	if gm.state != gm.State.PLAYING:
		return
	if body.is_ghost:
		return
	var peer_id := body.get_multiplayer_authority() if NetworkManager.is_active() else 1
	if peer_id in _finished_peers:
		return
	_finished_peers.append(peer_id)
	body.velocity = Vector2.ZERO
	body.start_freeze(9999.0)
	body.set_finished(true)
	get_tree().get_root().get_node("Main").goal_reached(peer_id)
