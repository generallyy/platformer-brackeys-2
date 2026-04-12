extends Node2D

const PLAYER_SCENE = preload("res://scenes/characters/Player.tscn")

var spawned_players: Dictionary = {}
var _player_numbers: Dictionary = {}  # peer_id -> display number (1, 2, 3...)
var current_level_path := "res://scenes/levels/Level0.tscn"
var _respawn_points: Dictionary = {}
var _wardrobe_player: Node = null

@onready var pause_menu = $PauseMenu
@onready var level_container = $LevelContainer
@onready var loading_screen = $LoadingScreen
@onready var hud = $HUD
@onready var wardrobe_menu = $WardrobeMenu
@onready var game_mode = $GameMode

func _ready() -> void:
	pause_menu.visible = false
	wardrobe_menu.visible = false
	hud.set_game_mode(game_mode)
	game_mode.round_started.connect(_on_round_started)
	game_mode.round_ended.connect(_on_round_ended)
	game_mode.game_over.connect(_on_game_over)
	game_mode.scores_changed.connect(_on_scores_changed)
	game_mode.stocks_changed.connect(_on_stocks_changed)
	game_mode.kda_changed.connect(_on_kda_changed)
	if NetworkManager.is_active():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		if multiplayer.is_server():
			_spawn_player(multiplayer.get_unique_id())
			await _load_level_local(current_level_path)
		else:
			_request_state.rpc_id(1)
	else:
		_spawn_player(1)
		await _load_level_local(current_level_path)

func _on_peer_connected(_id: int):
	pass  # client initiates via _request_state

func _on_peer_disconnected(id: int):
	for p in spawned_players.values():
		p.remove_sync_peer(id)
	if multiplayer.is_server():
		_rpc_despawn.rpc(id)

# Client asks server for current state on join
@rpc("any_peer", "reliable")
func _request_state():
	var caller = multiplayer.get_remote_sender_id()
	# Load the level first so spawned players have a valid spawn/platform context.
	load_level.rpc_id(caller, current_level_path)
	# Tell new client to spawn every already-existing player, then start syncing to them
	for existing_id in spawned_players:
		_rpc_spawn.rpc_id(caller, existing_id)
		spawned_players[existing_id].add_sync_peer(caller)
		_sync_player_outfit.rpc_id(caller, existing_id, spawned_players[existing_id].get_outfit_id())
	# Tell everyone (including server) to spawn the new player
	_rpc_spawn.rpc(caller)
	# Add existing clients to new player's sync_peers so the server can relay their state to each other
	for existing_id in spawned_players:
		if existing_id != caller and existing_id != 1:
			spawned_players[caller].add_sync_peer(existing_id)
	# Ensure late-joining player is included in scores before syncing state
	game_mode.register_player(caller)
	# Sync current game state to the new client
	game_mode.sync_to_peer(caller)

@rpc("authority", "call_local", "reliable")
func _rpc_spawn(peer_id: int):
	_spawn_player(peer_id)

@rpc("authority", "call_local", "reliable")
func _rpc_despawn(peer_id: int):
	if peer_id in spawned_players:
		spawned_players[peer_id].queue_free()
		spawned_players.erase(peer_id)

func get_player_number(peer_id: int) -> int:
	return _player_numbers.get(peer_id, peer_id)

func _spawn_player(peer_id: int):
	if peer_id in spawned_players:
		return
	_player_numbers[peer_id] = _player_numbers.size() + 1
	var p = PLAYER_SCENE.instantiate()
	p.name = "Player_%d" % peer_id
	p.set_multiplayer_authority(peer_id)
	add_child(p)
	spawned_players[peer_id] = p
	var spawn = _get_spawn()
	if spawn:
		p.global_position = spawn.global_position
		p.set_physics_process(true)
	else:
		p.set_physics_process(false)
	if not NetworkManager.is_active() or peer_id == multiplayer.get_unique_id():
		var cam = p.get_node("Camera2D")
		cam.make_current()
		p.health_changed.connect(hud.update_hearts)

func request_load_level(path: String) -> void:
	if NetworkManager.is_active() and not multiplayer.is_server():
		_req_load_level.rpc_id(1, path)
		return
	if NetworkManager.is_active():
		load_level.rpc(path)
	else:
		await load_level(path)

@rpc("any_peer", "reliable")
func _req_load_level(path: String) -> void:
	load_level.rpc(path)

@rpc("authority", "call_local", "reliable")
func load_level(path: String) -> void:
	if await _load_level_local(path):
		current_level_path = path

func _load_level_local(path: String) -> bool:
	game_mode.stop_game()
	for p in spawned_players.values():
		p.is_frozen = false
	loading_screen.visible = true
	close_wardrobe()
	await get_tree().process_frame
	var level_scene: PackedScene = load(path) as PackedScene
	if level_scene == null:
		push_error("Failed to load level scene: %s" % path)
		loading_screen.visible = false
		return false
	free_children(level_container)
	level_container.add_child(level_scene.instantiate())
	_respawn_points.clear()
	await get_tree().process_frame
	var spawn = _get_spawn()
	if spawn == null:
		push_error("No PlayerSpawn found in level: %s" % path)
	var spawn_pos: Vector2 = spawn.global_position if spawn else Vector2.ZERO
	var idx := 0
	for p in spawned_players.values():
		if spawn:
			p.global_position = spawn_pos + _spawn_offset(idx)
			p.set_physics_process(true)
		else:
			p.set_physics_process(false)
		p.velocity = Vector2.ZERO
		var cam = p.get_node_or_null("Camera2D")
		if cam:
			cam.reset_smoothing()
		idx += 1
	await get_tree().create_timer(0.5).timeout
	loading_screen.visible = false
	var settings := level_container.get_child(0).get_node_or_null("LevelSettings")
	if settings and settings.game_mode_enabled:
		if not NetworkManager.is_active() or multiplayer.is_server():
			game_mode.start_game(settings.round_time_limit)
		hud.get_node("Scores").visible = true
	else: hud.get_node("Scores").visible = false
	return true

func _get_spawn():
	if level_container.get_child_count() == 0:
		return null
	return level_container.get_child(0).get_node_or_null("PlayerSpawn")

func get_current_spawn_for_peer(peer_id: int) -> Node2D:
	if peer_id in _respawn_points:
		var checkpoint = _respawn_points[peer_id]
		if is_instance_valid(checkpoint):
			return checkpoint
		_respawn_points.erase(peer_id)
	return _get_spawn()

func activate_checkpoint(checkpoint: Node2D, peer_id: int) -> void:
	if NetworkManager.is_active() and not multiplayer.is_server():
		_req_activate_checkpoint.rpc_id(1, checkpoint.get_path(), peer_id)
		return
	_set_checkpoint(checkpoint, peer_id)

@rpc("any_peer", "reliable")
func _req_activate_checkpoint(checkpoint_path: NodePath, peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	var checkpoint = get_node_or_null(checkpoint_path)
	if checkpoint:
		_set_checkpoint(checkpoint, peer_id)

func _set_checkpoint(checkpoint: Node2D, peer_id: int) -> void:
	if peer_id in _respawn_points:
		var old: Node2D = _respawn_points[peer_id]
		if is_instance_valid(old) and old != checkpoint:
			if NetworkManager.is_active():
				_sync_reset_checkpoint.rpc(peer_id, old.get_path())
			else:
				_sync_reset_checkpoint(peer_id, old.get_path())
	_respawn_points[peer_id] = checkpoint
	if NetworkManager.is_active():
		_sync_checkpoint.rpc(peer_id, checkpoint.get_path())
	else:
		_sync_checkpoint(peer_id, checkpoint.get_path())

@rpc("authority", "call_local", "reliable")
func _sync_reset_checkpoint(peer_id: int, checkpoint_path: NodePath) -> void:
	var old := get_node_or_null(checkpoint_path)
	if old:
		old.reset_for_peer(peer_id)

@rpc("authority", "call_local", "reliable")
func _sync_checkpoint(peer_id: int, checkpoint_path: NodePath) -> void:
	var checkpoint = get_node_or_null(checkpoint_path)
	if checkpoint:
		_respawn_points[peer_id] = checkpoint

func open_wardrobe(player: Node) -> void:
	var local_peer_id := multiplayer.get_unique_id() if NetworkManager.is_active() else 1
	if player.get_multiplayer_authority() != local_peer_id:
		return
	if _wardrobe_player == player and wardrobe_menu.visible:
		return
	close_wardrobe()
	_wardrobe_player = player
	if is_instance_valid(_wardrobe_player):
		_wardrobe_player.set_ui_locked(true)
	wardrobe_menu.open_for_player(player)

func close_wardrobe() -> void:
	if is_instance_valid(_wardrobe_player):
		_wardrobe_player.set_ui_locked(false)
	_wardrobe_player = null
	wardrobe_menu.close_menu()

func request_player_outfit_change(peer_id: int, outfit_id: int) -> void:
	if NetworkManager.is_active() and not multiplayer.is_server():
		_req_player_outfit_change.rpc_id(1, peer_id, outfit_id)
		return
	_apply_player_outfit(peer_id, outfit_id)

@rpc("any_peer", "reliable")
func _req_player_outfit_change(peer_id: int, outfit_id: int) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_apply_player_outfit(peer_id, outfit_id)

func _apply_player_outfit(peer_id: int, outfit_id: int) -> void:
	if not peer_id in spawned_players:
		return
	if NetworkManager.is_active():
		_sync_player_outfit.rpc(peer_id, outfit_id)
	else:
		_sync_player_outfit(peer_id, outfit_id)

@rpc("authority", "call_local", "reliable")
func _sync_player_outfit(peer_id: int, outfit_id: int) -> void:
	if peer_id in spawned_players:
		spawned_players[peer_id].set_outfit_from_sync(outfit_id)

func goal_reached(peer_id: int) -> void:
	if NetworkManager.is_active() and not multiplayer.is_server():
		_req_goal_reached.rpc_id(1, peer_id)
		return
	game_mode.player_finished(peer_id)

@rpc("any_peer", "reliable")
func _req_goal_reached(peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	game_mode.player_finished(peer_id)

func respawn_all_at_spawn() -> void:
	_respawn_points.clear()
	var spawn: Marker2D = _get_spawn()
	var pos: Vector2 = spawn.global_position if spawn else Vector2.ZERO
	if NetworkManager.is_active():
		_sync_respawn_all.rpc(pos)
	else:
		_sync_respawn_all(pos)

@rpc("authority", "call_local", "reliable")
func _sync_respawn_all(pos: Vector2) -> void:
	var idx := 0
	for p in spawned_players.values():
		p.global_position = pos + _spawn_offset(idx)
		p.velocity = Vector2.ZERO
		p.is_frozen = false
		p.set_finished(false)
		p.health = p.MAX_HEALTH
		p.health_changed.emit(p.health)
		p.set_physics_process(true)
		p.show()
		idx += 1
	if level_container.get_child_count() > 0:
		var goal = level_container.get_child(0).get_node_or_null("GoalZone")
		if goal:
			goal.reset_for_new_round()

func _freeze_all_players(duration: float) -> void:
	for p in spawned_players.values():
		p.start_freeze(duration)

func _on_round_started(round_number: int) -> void:
	hud.show_announcement("GO!" if round_number == 1 else "Round %d — GO!" % round_number)
	hud.update_scores(game_mode.scores, _player_numbers, game_mode.stocks)
	hud.update_kda(game_mode.kda_kills, game_mode.kda_deaths, _player_numbers)
	_freeze_all_players(hud.ANNOUNCEMENT_DURATION)

func _on_round_ended(finishers: Array, scores: Dictionary) -> void:
	hud.update_scores(scores, _player_numbers, game_mode.stocks)
	var msg: String
	if finishers.is_empty():
		msg = "Time's up! Nobody finished."
	else:
		var first_num := get_player_number(finishers[0])
		msg = "P%d finished first! +%d pts" % [first_num, game_mode.FINISH_POINTS[0]]
	hud.show_announcement(msg)
	_freeze_all_players(hud.ANNOUNCEMENT_DURATION)
	for p in spawned_players.values():
		p.set_finished(false)

func _on_game_over(winner_peer_id: int, scores: Dictionary) -> void:
	hud.update_scores(scores, _player_numbers)
	hud.show_announcement("Player %d wins!" % get_player_number(winner_peer_id))
	respawn_all_at_spawn()

func _on_scores_changed(scores: Dictionary) -> void:
	hud.update_scores(scores, _player_numbers, game_mode.stocks)

func _on_stocks_changed(_stocks: Dictionary) -> void:
	hud.update_scores(game_mode.scores, _player_numbers, _stocks)

func _on_kda_changed(kda_kills: Dictionary, kda_deaths: Dictionary) -> void:
	hud.update_kda(kda_kills, kda_deaths, _player_numbers)

func _spawn_offset(index: int) -> Vector2:
	return Vector2(0, -index * 20)

func free_children(node: Node):
	for child in node.get_children():
		child.queue_free()

func notify_kill(killer_peer_id: int, victim_peer_id: int) -> void:
	if NetworkManager.is_active() and not multiplayer.is_server():
		_req_notify_kill.rpc_id(1, killer_peer_id, victim_peer_id)
		return
	game_mode.record_kill(killer_peer_id, victim_peer_id)

@rpc("any_peer", "reliable")
func _req_notify_kill(killer_peer_id: int, victim_peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != victim_peer_id:
		return
	game_mode.record_kill(killer_peer_id, victim_peer_id)

func notify_self_death(victim_peer_id: int) -> void:
	if NetworkManager.is_active() and not multiplayer.is_server():
		_req_notify_self_death.rpc_id(1, victim_peer_id)
		return
	game_mode.record_death(victim_peer_id)

@rpc("any_peer", "reliable")
func _req_notify_self_death(victim_peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != victim_peer_id:
		return
	game_mode.record_death(victim_peer_id)

func respawn_player_by_id(peer_id: int):
	if NetworkManager.is_active() and not multiplayer.is_server():
		_req_respawn.rpc_id(1, peer_id)
		return
	_do_respawn(peer_id)

@rpc("any_peer", "reliable")
func _req_respawn(peer_id: int):
	if multiplayer.get_remote_sender_id() == peer_id:
		_do_respawn(peer_id)

func _do_respawn(peer_id: int):
	if not peer_id in spawned_players:
		return
	if not game_mode.can_respawn(peer_id):
		return
	var spawn = get_current_spawn_for_peer(peer_id)
	var pos = spawn.global_position if spawn else Vector2.ZERO
	if NetworkManager.is_active():
		_sync_respawn.rpc(peer_id, pos)
	else:
		_sync_respawn(peer_id, pos)

@rpc("authority", "call_local", "reliable")
func _sync_respawn(peer_id: int, pos: Vector2):
	if peer_id in spawned_players:
		var p = spawned_players[peer_id]
		p.global_position = pos
		p.velocity = Vector2.ZERO
		p.set_physics_process(true)
		p.show()
		p.is_invuln = true
		p._invuln_timer = 0.5
		
