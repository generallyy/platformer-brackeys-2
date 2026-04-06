extends Node2D

const PLAYER_SCENE = preload("res://scenes/characters/Player.tscn")

var spawned_players: Dictionary = {}
var current_level_path := "res://scenes/levels/Level0.tscn"
var _respawn_points: Dictionary = {}
var _wardrobe_player: Node = null

@onready var pause_menu = $PauseMenu
@onready var level_container = $LevelContainer
@onready var loading_screen = $LoadingScreen
@onready var hud = $HUD
@onready var wardrobe_menu = $WardrobeMenu

func _ready() -> void:
	pause_menu.visible = false
	wardrobe_menu.visible = false
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

@rpc("authority", "call_local", "reliable")
func _rpc_spawn(peer_id: int):
	_spawn_player(peer_id)

@rpc("authority", "call_local", "reliable")
func _rpc_despawn(peer_id: int):
	if peer_id in spawned_players:
		spawned_players[peer_id].queue_free()
		spawned_players.erase(peer_id)

func _spawn_player(peer_id: int):
	if peer_id in spawned_players:
		return
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
		var cam = Camera2D.new()
		cam.zoom = Vector2(4, 4)
		cam.limit_bottom = 120
		cam.position_smoothing_enabled = true
		p.add_child(cam)
		cam.make_current()
		p.health_changed.connect(hud.update_hearts)

@rpc("authority", "call_local", "reliable")
func load_level(path: String) -> void:
	if await _load_level_local(path):
		current_level_path = path

func _load_level_local(path: String) -> bool:
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
	for p in spawned_players.values():
		if spawn:
			p.global_position = spawn.global_position
			p.set_physics_process(true)
		else:
			p.set_physics_process(false)
		p.velocity = Vector2.ZERO
		var cam = p.get_node_or_null("Camera2D")
		if cam:
			cam.reset_smoothing()
	await get_tree().create_timer(0.5).timeout
	loading_screen.visible = false
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
	_respawn_points[peer_id] = checkpoint
	if NetworkManager.is_active():
		_sync_checkpoint.rpc(peer_id, checkpoint.get_path())
	else:
		_sync_checkpoint(peer_id, checkpoint.get_path())

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

func free_children(node: Node):
	for child in node.get_children():
		child.queue_free()

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
		
