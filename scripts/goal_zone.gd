extends Area2D

var _finished_peers: Array = []

func reset_for_new_round() -> void:
	_finished_peers.clear()

func _process(_delta: float) -> void:
	var main := get_tree().get_root().get_node_or_null("Main")
	if main == null or not main.kills_required_for_goal:
		modulate = Color.WHITE
		return
	var local_player := _find_local_player()
	if local_player == null:
		modulate = Color.WHITE
		return
	var peer_id := local_player.get_multiplayer_authority()
	var n: int = main.spawned_players.size()
	var k: int = main.game_mode.round_kills.get(peer_id, 0)
	var qualified := k >= n - 1 or _is_last_active(peer_id, main)
	modulate = Color.WHITE if qualified else Color(0.4, 0.4, 0.4, 0.5)

func _find_local_player() -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p
	return null

func _is_last_active(peer_id: int, main: Node) -> bool:
	var gm: Node = main.game_mode
	var active_count := 0
	var peer_is_active := false
	for pid in main.spawned_players:
		if gm.stocks.get(pid, 0) > 0 and pid not in gm._finishers:
			active_count += 1
			if pid == peer_id:
				peer_is_active = true
	return active_count == 1 and peer_is_active

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.is_multiplayer_authority():
		return
	var _main := get_tree().get_root().get_node("Main")
	var gm: Node = _main.game_mode
	if gm.state != gm.State.PLAYING:
		return
	if body.is_ghost:
		return
	var peer_id := body.get_multiplayer_authority()
	if peer_id in _finished_peers:
		return
	if _main.kills_required_for_goal:
		var n: int = _main.spawned_players.size()
		var k: int = gm.round_kills.get(peer_id, 0)
		if k < n - 1 and not _is_last_active(peer_id, _main):
			return
	_finished_peers.append(peer_id)
	body.velocity = Vector2.ZERO
	body.start_freeze(9999.0)
	body.set_finished(true)
	_main.goal_reached(peer_id)
