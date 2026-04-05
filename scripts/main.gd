extends Node2D

const PLAYER_SCENE = preload("res://scenes/characters/Player.tscn")

var spawned_players: Dictionary = {}
var current_level_path := "res://scenes/levels/Level0.tscn"

@onready var pause_menu = $PauseMenu
@onready var level_container = $LevelContainer
@onready var loading_screen = $LoadingScreen
@onready var hud = $HUD

func _ready():
	pause_menu.visible = false
	if NetworkManager.is_active():
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		if multiplayer.is_server():
			_spawn_player(multiplayer.get_unique_id())
			_load_level_local(current_level_path)
		else:
			_request_state.rpc_id(1)
	else:
		_spawn_player(1)
		_load_level_local(current_level_path)

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
	# Tell new client to spawn every already-existing player, then start syncing to them
	for existing_id in spawned_players:
		_rpc_spawn.rpc_id(caller, existing_id)
		spawned_players[existing_id].add_sync_peer(caller)
	# Tell everyone (including server) to spawn the new player
	_rpc_spawn.rpc(caller)
	# Send current level to new client
	load_level.rpc_id(caller, current_level_path)

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
	if not NetworkManager.is_active() or peer_id == multiplayer.get_unique_id():
		var cam = Camera2D.new()
		cam.zoom = Vector2(4, 4)
		cam.limit_bottom = 120
		cam.position_smoothing_enabled = true
		p.add_child(cam)
		cam.make_current()
		p.health_changed.connect(hud.update_hearts)

@rpc("authority", "call_local", "reliable")
func load_level(path: String):
	current_level_path = path
	_load_level_local(path)

func _load_level_local(path: String):
	loading_screen.visible = true
	await get_tree().process_frame
	free_children(level_container)
	level_container.add_child(load(path).instantiate())
	await get_tree().process_frame
	var spawn = _get_spawn()
	for p in spawned_players.values():
		if spawn:
			p.global_position = spawn.global_position
		var cam = p.get_node_or_null("Camera2D")
		if cam:
			cam.reset_smoothing()
	await get_tree().create_timer(0.5).timeout
	loading_screen.visible = false

func _get_spawn():
	if level_container.get_child_count() == 0:
		return null
	return level_container.get_child(0).get_node_or_null("PlayerSpawn")

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
	var spawn = _get_spawn()
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
		p.show()
