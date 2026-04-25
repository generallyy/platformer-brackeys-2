extends Node2D

const PLAYER_SCENE = preload("res://scenes/characters/Player.tscn")

const TEAM_DEFINITIONS := [
	{ "id": 0, "name": "No Team", "color": Color(0.65, 0.65, 0.65) },
	{ "id": 1, "name": "Red",     "color": Color(1.0, 0.3, 0.3) },
	{ "id": 2, "name": "Blue",    "color": Color(0.35, 0.6, 1.0) },
]
const _EIGHT_BALL_AI_ID := -99
const _EIGHT_BALL_AI_NAME := "Table AI"
const _EIGHT_BALL_AI_MIN_DELAY := 0.65
const _EIGHT_BALL_AI_POST_ANIM_DELAY := 0.35

var spawned_players: Dictionary = {}
var _player_numbers: Dictionary = {}  # peer_id -> display number (1, 2, 3...)
var player_names: Dictionary = {}     # peer_id -> display name String
var team_colors: Dictionary = {}      # peer_id -> Color
var player_teams: Dictionary = {}     # peer_id -> team_id (0 = no team)
var ghost_bombs_enabled: bool = true
var kills_required_for_goal: bool = false
var current_level_path := "res://scenes/levels/Level0.tscn"
var _respawn_points: Dictionary = {}
var _wardrobe_player: Node = null
<<<<<<< Updated upstream
=======
var _eight_ball_session: Dictionary = EightBallLogic.create_idle_session()
var _eight_ball_ai_turn_serial := 0
>>>>>>> Stashed changes

const _MOUSE_HIDE_DELAY := 2.0
var _mouse_idle := 0.0
var _window_focused := true

@onready var pause_menu = $PauseMenu
@onready var level_container = $LevelContainer
@onready var loading_screen = $LoadingScreen
@onready var hud = $HUD
@onready var wardrobe_menu = $WardrobeMenu
@onready var game_mode = $GameMode
@onready var powerups_menu = $HUD/PowerupsMenu

func _ready() -> void:
	get_window().focus_entered.connect(func(): _window_focused = true)
	get_window().focus_exited.connect(func():
		_window_focused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_mouse_idle = 0.0
	)
	#pause_menu.visible = false
	wardrobe_menu.visible = false
	hud.visible = true
	
	hud.set_game_mode(game_mode)
	game_mode.round_started.connect(_on_round_started)
	game_mode.round_ended.connect(_on_round_ended)
	game_mode.game_over.connect(_on_game_over)
	game_mode.scores_changed.connect(_on_scores_changed)
	game_mode.stocks_changed.connect(_on_stocks_changed)
	game_mode.kda_changed.connect(_on_kda_changed)
	game_mode.powerups_distribute.connect(_on_powerups_distribute)
	powerups_menu.powerup_picked.connect(_on_powerup_picked)
	if NetworkManager.is_online():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server():
		_spawn_player(multiplayer.get_unique_id())
		_register_name(multiplayer.get_unique_id(), NetworkManager.local_name)
		await _load_level_local(current_level_path)
	else:
		_request_state.rpc_id(1, NetworkManager.local_name)

func _process(delta: float) -> void:
	if not _window_focused or pause_menu.visible:
		return
	_mouse_idle += delta
	if _mouse_idle >= _MOUSE_HIDE_DELAY:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_idle = 0.0
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_peer_connected(_id: int):
	pass  # client initiates via _request_state

func _on_peer_disconnected(id: int):
	for p in spawned_players.values():
		p.remove_sync_peer(id)
	if multiplayer.is_server():
		_rpc_despawn.rpc(id)

# Client asks server for current state on join
@rpc("any_peer", "reliable")
func _request_state(player_name: String = ""):
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
	# Send existing players' names to the new client, then register the new player's name
	for existing_id in player_names:
		_sync_player_name.rpc_id(caller, existing_id, player_names[existing_id])
	_register_name(caller, player_name)
	# Sync team assignments to the new client
	for existing_id in player_teams:
		if player_teams[existing_id] != 0:
			_sync_team_change.rpc_id(caller, existing_id, player_teams[existing_id])

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

func get_player_display_name(peer_id: int) -> String:
	if peer_id == _EIGHT_BALL_AI_ID:
		return _EIGHT_BALL_AI_NAME
	var n: String = player_names.get(peer_id, "")
	if not n.is_empty():
		return n
	return "P%d" % _player_numbers.get(peer_id, peer_id)

func _local_peer_id() -> int:
	return multiplayer.get_unique_id()

<<<<<<< Updated upstream
=======
func _active_peer_ids() -> Array:
	var result: Array = []
	for peer_id in spawned_players.keys():
		result.append(peer_id)
	if _local_peer_id() != 0 and not result.has(_EIGHT_BALL_AI_ID):
		result.append(_EIGHT_BALL_AI_ID)
	result.sort()
	return result

func _eight_ball_names() -> Dictionary:
	var names: Dictionary = player_names.duplicate(true)
	names[_EIGHT_BALL_AI_ID] = _EIGHT_BALL_AI_NAME
	return names

func _push_eight_ball_state_local(auto_open: bool = false) -> void:
	if eight_ball_menu == null:
		return
	eight_ball_menu.apply_state(_eight_ball_session, _eight_ball_names(), _active_peer_ids(), _local_peer_id())
	var local_peer := _local_peer_id()
	var phase := String(_eight_ball_session.get("phase", "idle"))
	var should_open := (phase == "invite" and int(_eight_ball_session.get("opponent_id", 0)) == local_peer) \
			or (phase == "active" and EightBallLogic.is_participant(_eight_ball_session, local_peer))
	if auto_open and should_open and not eight_ball_menu.visible and not loading_screen.visible and not powerups_menu.visible and not pause_menu.visible:
		close_blackjack()
		close_wardrobe()
		open_eight_ball()

func _set_eight_ball_session(session: Dictionary) -> void:
	_sync_eight_ball_session.rpc(session)

@rpc("authority", "call_local", "reliable")
func _sync_eight_ball_session(session: Dictionary) -> void:
	var previous_phase := String(_eight_ball_session.get("phase", "idle"))
	_eight_ball_session = session.duplicate(true)
	var local_peer := _local_peer_id()
	var new_phase := String(_eight_ball_session.get("phase", "idle"))
	var auto_open := (new_phase == "invite" and int(_eight_ball_session.get("opponent_id", 0)) == local_peer and previous_phase != "invite") \
			or (new_phase == "active" and EightBallLogic.is_participant(_eight_ball_session, local_peer) and previous_phase != "active")
	_push_eight_ball_state_local(auto_open)
	if multiplayer.is_server():
		_schedule_eight_ball_ai_turn()

func _schedule_eight_ball_ai_turn() -> void:
	_eight_ball_ai_turn_serial += 1
	var token := _eight_ball_ai_turn_serial
	if String(_eight_ball_session.get("phase", "idle")) != "active":
		return
	if int(_eight_ball_session.get("current_turn", 0)) != _EIGHT_BALL_AI_ID:
		return
	var frames: Array = _eight_ball_session.get("animation_frames", [])
	var animation_delay := float(frames.size()) * EightBallLogic.STEP_DELTA * EightBallLogic.SAMPLE_INTERVAL
	var wait_time := maxf(_EIGHT_BALL_AI_MIN_DELAY, animation_delay + _EIGHT_BALL_AI_POST_ANIM_DELAY)
	_run_eight_ball_ai_turn(token, wait_time)

func _run_eight_ball_ai_turn(token: int, wait_time: float) -> void:
	await get_tree().create_timer(wait_time).timeout
	if token != _eight_ball_ai_turn_serial:
		return
	if String(_eight_ball_session.get("phase", "idle")) != "active":
		return
	if int(_eight_ball_session.get("current_turn", 0)) != _EIGHT_BALL_AI_ID:
		return
	var shot := EightBallLogic.choose_ai_shot(_eight_ball_session, _EIGHT_BALL_AI_ID)
	_do_eight_ball_shot(_EIGHT_BALL_AI_ID, float(shot.get("angle", 0.0)), float(shot.get("power", 0.58)))

>>>>>>> Stashed changes
func _active_player_numbers() -> Dictionary:
	var result := {}
	for peer_id in _player_numbers:
		if peer_id in spawned_players:
			result[peer_id] = _player_numbers[peer_id]
	return result

func _register_name(peer_id: int, raw_name: String) -> void:
	var n := raw_name.strip_edges()
	if n.is_empty():
		n = "P%d" % _player_numbers.get(peer_id, peer_id)
	player_names[peer_id] = n
	if peer_id in spawned_players:
		spawned_players[peer_id].set_display_name(n)
	_sync_player_name.rpc(peer_id, n)

@rpc("authority", "call_local", "reliable")
func _sync_player_name(peer_id: int, display_name: String) -> void:
	player_names[peer_id] = display_name
	if peer_id in spawned_players:
		spawned_players[peer_id].set_display_name(display_name)
	hud.update_scores(game_mode.scores, _player_numbers, game_mode.stocks, player_names)
	hud.update_kda(game_mode.kda_kills, game_mode.kda_deaths, _active_player_numbers(), player_names, game_mode.kda_damage, _local_peer_id(), team_colors, game_mode.kda_damage_taken)

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
	if peer_id == multiplayer.get_unique_id():
		var cam = p.get_node("Camera2D")
		cam.make_current()
		p.health_changed.connect(hud.update_hearts)
		p.powerups_changed.connect(hud.update_powerups)
		p.nudge_changed.connect(hud.set_nudge)

func request_load_level(path: String) -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_load_level.rpc_id(1, path)
		return
	if NetworkManager.is_online():
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
	_clear_all_player_powerups()
	for p in spawned_players.values():
		p.is_frozen = false
		p.health = p.get_effective_max_health()
		p.health_changed.emit(p.health, p.get_effective_max_health())
	loading_screen.visible = true
	close_wardrobe()
	powerups_menu.close_menu()
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
	for p in spawned_players.values():
		p.deactivate_ghost_mode()
		for other in spawned_players.values():
			if other != p:
				p.remove_collision_exception_with(other)
	var idx: int = 0
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
	# Fire particles once while the loading screen is visible to compile their shader
	for p in spawned_players.values():
		p.warmup_effects()
	await get_tree().create_timer(0.5).timeout
	loading_screen.visible = false
	var settings := level_container.get_child(0).get_node_or_null("LevelSettings")
	ghost_bombs_enabled = settings.ghost_bombs_enabled if settings != null else true
	kills_required_for_goal = settings.kills_required_for_goal if settings != null else false
	if settings and settings.game_mode_enabled:
		if multiplayer.is_server():
			game_mode.start_game(settings.round_time_limit, settings.points_to_win)
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
	if NetworkManager.is_online() and not multiplayer.is_server():
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
			_sync_reset_checkpoint.rpc(peer_id, old.get_path())
	_respawn_points[peer_id] = checkpoint
	_sync_checkpoint.rpc(peer_id, checkpoint.get_path())
	game_mode.reset_stocks_for_peer(peer_id)

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
	if player.get_multiplayer_authority() != multiplayer.get_unique_id():
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

<<<<<<< Updated upstream
=======

func open_blackjack() -> void:
	var player: Node2D = spawned_players.get(multiplayer.get_unique_id())
	close_eight_ball()
	if player != null:
		player.set_external_input_lock(&"blackjack", true)
	_mouse_idle = 0.0
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	blackjack_menu.open_menu()


func close_blackjack() -> void:
	if not blackjack_menu.visible:
		return
	blackjack_menu.close_menu()
	var player: Node2D = spawned_players.get(multiplayer.get_unique_id())
	if player != null:
		player.set_external_input_lock(&"blackjack", false)


func open_eight_ball() -> void:
	var player: Node2D = spawned_players.get(multiplayer.get_unique_id())
	close_blackjack()
	close_wardrobe()
	if player != null:
		player.set_external_input_lock(&"eight_ball", true)
	_mouse_idle = 0.0
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	eight_ball_menu.open_menu()
	_push_eight_ball_state_local(false)


func close_eight_ball() -> void:
	if not eight_ball_menu.visible:
		return
	eight_ball_menu.close_menu()
	var player: Node2D = spawned_players.get(multiplayer.get_unique_id())
	if player != null:
		player.set_external_input_lock(&"eight_ball", false)

func request_eight_ball_challenge(opponent_id: int) -> void:
	var peer_id := _local_peer_id()
	if peer_id == 0 or opponent_id == 0 or peer_id == opponent_id:
		return
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_eight_ball_challenge.rpc_id(1, peer_id, opponent_id)
		return
	_do_eight_ball_challenge(peer_id, opponent_id)

@rpc("any_peer", "reliable")
func _req_eight_ball_challenge(peer_id: int, opponent_id: int) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_do_eight_ball_challenge(peer_id, opponent_id)

func _do_eight_ball_challenge(peer_id: int, opponent_id: int) -> void:
	if String(_eight_ball_session.get("phase", "idle")) != "idle":
		return
	if peer_id not in spawned_players:
		return
	if opponent_id == _EIGHT_BALL_AI_ID:
		_set_eight_ball_session(EightBallLogic.create_match_session(peer_id, opponent_id))
		return
	if opponent_id not in spawned_players:
		return
	_set_eight_ball_session(EightBallLogic.create_invite_session(peer_id, opponent_id))

func request_accept_eight_ball() -> void:
	var peer_id := _local_peer_id()
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_accept_eight_ball.rpc_id(1, peer_id)
		return
	_do_accept_eight_ball(peer_id)

@rpc("any_peer", "reliable")
func _req_accept_eight_ball(peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_do_accept_eight_ball(peer_id)

func _do_accept_eight_ball(peer_id: int) -> void:
	if String(_eight_ball_session.get("phase", "idle")) != "invite":
		return
	if int(_eight_ball_session.get("opponent_id", 0)) != peer_id:
		return
	_set_eight_ball_session(EightBallLogic.create_match_session(int(_eight_ball_session.get("challenger_id", 0)), peer_id))

func request_decline_eight_ball() -> void:
	var peer_id := _local_peer_id()
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_decline_eight_ball.rpc_id(1, peer_id)
		return
	_do_decline_eight_ball(peer_id)

@rpc("any_peer", "reliable")
func _req_decline_eight_ball(peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_do_decline_eight_ball(peer_id)

func _do_decline_eight_ball(peer_id: int) -> void:
	if String(_eight_ball_session.get("phase", "idle")) != "invite":
		return
	if int(_eight_ball_session.get("opponent_id", 0)) != peer_id:
		return
	_set_eight_ball_session(EightBallLogic.create_idle_session("%s declined the challenge." % get_player_display_name(peer_id)))

func request_leave_eight_ball() -> void:
	var peer_id := _local_peer_id()
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_leave_eight_ball.rpc_id(1, peer_id)
		return
	_do_leave_eight_ball(peer_id)

@rpc("any_peer", "reliable")
func _req_leave_eight_ball(peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_do_leave_eight_ball(peer_id)

func _do_leave_eight_ball(peer_id: int) -> void:
	if not EightBallLogic.is_participant(_eight_ball_session, peer_id):
		return
	var phase := String(_eight_ball_session.get("phase", "idle"))
	var message := "%s left the table." % get_player_display_name(peer_id)
	if phase == "invite":
		if int(_eight_ball_session.get("challenger_id", 0)) == peer_id:
			message = "%s cancelled the challenge." % get_player_display_name(peer_id)
		else:
			message = "%s backed out of the challenge." % get_player_display_name(peer_id)
	_set_eight_ball_session(EightBallLogic.create_idle_session(message))

func request_eight_ball_shot(angle: float, power: float) -> void:
	var peer_id := _local_peer_id()
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_eight_ball_shot.rpc_id(1, peer_id, angle, power)
		return
	_do_eight_ball_shot(peer_id, angle, power)

@rpc("any_peer", "reliable")
func _req_eight_ball_shot(peer_id: int, angle: float, power: float) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_do_eight_ball_shot(peer_id, angle, power)

func _do_eight_ball_shot(peer_id: int, angle: float, power: float) -> void:
	if not EightBallLogic.is_shot_allowed(_eight_ball_session, peer_id):
		return
	var animation_id := int(_eight_ball_session.get("animation_id", 0)) + 1
	_set_eight_ball_session(EightBallLogic.apply_shot(_eight_ball_session, peer_id, angle, power, animation_id))

>>>>>>> Stashed changes
func request_player_outfit_change(peer_id: int, outfit_id: int) -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
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
	_sync_player_outfit.rpc(peer_id, outfit_id)

@rpc("authority", "call_local", "reliable")
func _sync_player_outfit(peer_id: int, outfit_id: int) -> void:
	if peer_id in spawned_players:
		spawned_players[peer_id].set_outfit_from_sync(outfit_id)

func goal_reached(peer_id: int) -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_goal_reached.rpc_id(1, peer_id)
		return
	game_mode.player_finished(peer_id)

@rpc("any_peer", "reliable")
func _req_goal_reached(peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	game_mode.player_finished(peer_id)

func respawn_all_at_spawn() -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		return
	_respawn_points.clear()
	var spawn: Marker2D = _get_spawn()
	var pos: Vector2 = spawn.global_position if spawn else Vector2.ZERO
	_sync_respawn_all.rpc(pos)

@rpc("authority", "call_local", "reliable")
func _sync_respawn_all(pos: Vector2) -> void:
	var idx := 0
	for p in spawned_players.values():
		p.deactivate_ghost_mode()
		p.global_position = pos + _spawn_offset(idx)
		p.velocity = Vector2.ZERO
		p.is_frozen = false
		p.set_finished(false)
		p.health = p.get_effective_max_health()
		p.health_changed.emit(p.health, p.get_effective_max_health())
		p.set_physics_process(true)
		p.show()
		idx += 1
	if level_container.get_child_count() > 0:
		var goal = level_container.get_child(0).get_node_or_null("GoalZone")
		if goal:
			goal.reset_for_new_round()

func _freeze_for_all_players(duration: float) -> void:
	for p in spawned_players.values():
		p.freeze_for_duration(duration)

func _on_round_started(round_number: int) -> void:
	powerups_menu.close_menu()
	_grant_round_powerup_state()
	var msg: String
	if game_mode.sudden_death_peers.size() > 0:
		msg = "SUDDEN DEATH!"
	elif round_number == 1:
		msg = "GO!"
	else:
		msg = "Round %d — GO!" % round_number
	hud.show_announcement(msg)
	hud.update_scores(game_mode.scores, _player_numbers, game_mode.stocks, player_names)
	hud.update_kda(game_mode.kda_kills, game_mode.kda_deaths, _active_player_numbers(), player_names, game_mode.kda_damage, _local_peer_id(), team_colors, game_mode.kda_damage_taken)
	_freeze_for_all_players(hud.ANNOUNCEMENT_DURATION)

func _on_round_ended(finishers: Array, scores: Dictionary) -> void:
	hud.update_scores(scores, _player_numbers, game_mode.stocks, player_names)
	var msg: String
	if finishers.is_empty():
		msg = "Time's up! Nobody finished."
	else:
		msg = "%s finished first! +%d pts" % [get_player_display_name(finishers[0]), game_mode.FINISH_POINTS[0]]
	hud.show_announcement(msg)
	_freeze_for_all_players(hud.ANNOUNCEMENT_DURATION)
	for p in spawned_players.values():
		p.set_finished(false)

func _on_game_over(winner_peer_id: int, scores: Dictionary) -> void:
	hud.update_scores(scores, _player_numbers, {}, player_names)
	hud.show_announcement("%s wins!" % get_player_display_name(winner_peer_id), 3.0)
	respawn_all_at_spawn()

func _on_scores_changed(scores: Dictionary) -> void:
	hud.update_scores(scores, _player_numbers, game_mode.stocks, player_names)

func _on_stocks_changed(_stocks: Dictionary) -> void:
	hud.update_scores(game_mode.scores, _player_numbers, _stocks, player_names)

func _on_kda_changed(kda_kills: Dictionary, kda_deaths: Dictionary, kda_damage: Dictionary, kda_damage_taken: Dictionary = {}) -> void:
	hud.update_kda(kda_kills, kda_deaths, _active_player_numbers(), player_names, kda_damage, _local_peer_id(), team_colors, kda_damage_taken)

func _on_powerups_distribute(_scores: Dictionary, finishers: Array) -> void:
	var local_peer := multiplayer.get_unique_id()
	var player = spawned_players.get(local_peer)
	if player == null:
		return
	var placement := finishers.find(local_peer) + 1  # 1-indexed; 0 means not in finishers
	if placement == 0: 
		placement = spawned_players.size()
	var delay := 1.0
	await get_tree().create_timer(delay).timeout
	if game_mode.state == game_mode.State.INTERMISSION:
		var time_left: float = game_mode.INTERMISSION_DURATION - delay
		powerups_menu.open_for_player(player, placement, time_left)

func _on_powerup_picked() -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_notify_picked.rpc_id(1)
	else:
		game_mode.notify_player_picked()

@rpc("any_peer", "reliable")
func _req_notify_picked() -> void:
	var caller := multiplayer.get_remote_sender_id()
	if caller not in spawned_players:
		return
	game_mode.notify_player_picked()

func _clear_all_player_powerups() -> void:
	for p in spawned_players.values():
		p.clear_powerups()

func _grant_round_powerup_state() -> void:
	for p in spawned_players.values():
		p.reset_round_powerup_state()

func _spawn_offset(index: int) -> Vector2:
	return Vector2(0, -index * 20)

func free_children(node: Node):
	for child in node.get_children():
		child.queue_free()

func get_team_color(tid: int) -> Color:
	if tid < TEAM_DEFINITIONS.size():
		return TEAM_DEFINITIONS[tid]["color"]
	return Color.WHITE

func get_team_name(tid: int) -> String:
	if tid < TEAM_DEFINITIONS.size():
		return TEAM_DEFINITIONS[tid]["name"]
	return "Team %d" % tid

func request_team_change(peer_id: int, tid: int) -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_team_change.rpc_id(1, peer_id, tid)
		return
	_apply_team_change(peer_id, tid)

@rpc("any_peer", "reliable")
func _req_team_change(peer_id: int, tid: int) -> void:
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_apply_team_change(peer_id, tid)

func _apply_team_change(peer_id: int, tid: int) -> void:
	_sync_team_change.rpc(peer_id, tid)

@rpc("authority", "call_local", "reliable")
func _sync_team_change(peer_id: int, tid: int) -> void:
	player_teams[peer_id] = tid
	if tid == 0:
		team_colors.erase(peer_id)
	else:
		team_colors[peer_id] = get_team_color(tid)
	if peer_id in spawned_players:
		spawned_players[peer_id].set_team(tid, get_team_color(tid))
	hud.update_kda(game_mode.kda_kills, game_mode.kda_deaths, _active_player_numbers(), player_names, game_mode.kda_damage, _local_peer_id(), team_colors, game_mode.kda_damage_taken)

func notify_kill(killer_peer_id: int, victim_peer_id: int) -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_notify_kill.rpc_id(1, killer_peer_id, victim_peer_id)
		return
	game_mode.record_kill(killer_peer_id, victim_peer_id)
	_notify_kill_indicator(killer_peer_id)

@rpc("any_peer", "reliable")
func _req_notify_kill(killer_peer_id: int, victim_peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != victim_peer_id:
		return
	game_mode.record_kill(killer_peer_id, victim_peer_id)
	_notify_kill_indicator(killer_peer_id)

func _notify_kill_indicator(killer_peer_id: int) -> void:
	if killer_peer_id == multiplayer.get_unique_id():
		var player: Node2D = spawned_players.get(killer_peer_id)
		if player:
			player.show_kill()
	elif NetworkManager.is_online():
		_rpc_kill_indicator.rpc_id(killer_peer_id, killer_peer_id)

@rpc("authority", "reliable")
func _rpc_kill_indicator(killer_peer_id: int) -> void:
	var player: Node2D = spawned_players.get(killer_peer_id)
	if player:
		player.show_kill()

func notify_self_death(victim_peer_id: int) -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_notify_self_death.rpc_id(1, victim_peer_id)
		return
	game_mode.record_death(victim_peer_id)

@rpc("any_peer", "reliable")
func _req_notify_self_death(victim_peer_id: int) -> void:
	if multiplayer.get_remote_sender_id() != victim_peer_id:
		return
	game_mode.record_death(victim_peer_id)

func notify_damage(attacker_peer_id: int, victim_peer_id: int, amount: int) -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_notify_damage.rpc_id(1, attacker_peer_id, victim_peer_id, amount)
		return
	game_mode.record_damage(attacker_peer_id, amount)
	game_mode.record_damage_taken(victim_peer_id, amount)

@rpc("any_peer", "reliable")
func _req_notify_damage(attacker_peer_id: int, victim_peer_id: int, amount: int) -> void:
	if multiplayer.get_remote_sender_id() != victim_peer_id:
		return
	game_mode.record_damage(attacker_peer_id, amount)
	game_mode.record_damage_taken(victim_peer_id, amount)

func respawn_player_by_id(peer_id: int):
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_respawn.rpc_id(1, peer_id)
		return
	_do_respawn(peer_id)

@rpc("any_peer", "reliable")
func _req_respawn(peer_id: int):
	if multiplayer.get_remote_sender_id() == peer_id:
		_do_respawn(peer_id)

func _activate_ghost(peer_id: int) -> void:
	var spawn := get_current_spawn_for_peer(peer_id)
	var pos   := spawn.global_position if spawn else Vector2.ZERO
	_sync_activate_ghost.rpc(peer_id, ghost_bombs_enabled, pos)

@rpc("authority", "call_local", "reliable")
func _sync_activate_ghost(peer_id: int, can_bomb: bool, pos: Vector2) -> void:
	if peer_id in spawned_players:
		spawned_players[peer_id].activate_ghost_mode(can_bomb, pos)
		_update_spectator_visibility()

# ============================================================
# SPECTATOR
# ============================================================

func _update_spectator_visibility() -> void:
	var local_id  := _local_peer_id()
	var local_p   = spawned_players.get(local_id)
	var can_see: bool = local_p == null or local_p.is_ghost or local_p.is_spectator
	for peer_id in spawned_players:
		var p = spawned_players[peer_id]
		if p.is_spectator:
			p.modulate.a = 0.4 if can_see else 0.0

func request_enter_spectator(peer_id: int) -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_enter_spectator.rpc_id(1, peer_id)
		return
	_do_enter_spectator(peer_id)

@rpc("any_peer", "reliable")
func _req_enter_spectator(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_do_enter_spectator(peer_id)

func _do_enter_spectator(peer_id: int) -> void:
	if peer_id not in spawned_players:
		return
	var pos: Vector2 = spawned_players[peer_id].global_position
	_sync_enter_spectator.rpc(peer_id, pos)

@rpc("authority", "call_local", "reliable")
func _sync_enter_spectator(peer_id: int, pos: Vector2) -> void:
	if peer_id in spawned_players:
		spawned_players[peer_id].enter_spectator_mode(pos)
		_update_spectator_visibility()

func request_exit_spectator(peer_id: int) -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		_req_exit_spectator.rpc_id(1, peer_id)
		return
	_do_exit_spectator(peer_id)

@rpc("any_peer", "reliable")
func _req_exit_spectator(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_do_exit_spectator(peer_id)

func _do_exit_spectator(peer_id: int) -> void:
	if peer_id not in spawned_players:
		return
	_sync_exit_spectator.rpc(peer_id)

@rpc("authority", "call_local", "reliable")
func _sync_exit_spectator(peer_id: int) -> void:
	if peer_id in spawned_players:
		spawned_players[peer_id].exit_spectator_mode()
		_update_spectator_visibility()

func _do_respawn(peer_id: int):
	if not peer_id in spawned_players:
		return
	if not game_mode.can_respawn(peer_id):
		if game_mode.state == game_mode.State.PLAYING:
			_activate_ghost(peer_id)
		elif game_mode.state == game_mode.State.INTERMISSION:
			# Out of stocks but round just ended — snap to spawn so the player
			# isn't falling off-screen during the powerup menu.
			var spawn = get_current_spawn_for_peer(peer_id)
			var pos = spawn.global_position if spawn else Vector2.ZERO
			_sync_respawn.rpc(peer_id, pos)
		return
	var spawn = get_current_spawn_for_peer(peer_id)
	var pos = spawn.global_position if spawn else Vector2.ZERO
	_sync_respawn.rpc(peer_id, pos)

@rpc("authority", "call_local", "reliable")
func _sync_respawn(peer_id: int, pos: Vector2):
	if peer_id in spawned_players:
		var p: Node2D = spawned_players[peer_id]
		p.global_position = pos
		p.velocity = Vector2.ZERO
		p.set_physics_process(true)
		p.show()
		p.is_invuln = true
		p._invuln_timer = 0.5
		
