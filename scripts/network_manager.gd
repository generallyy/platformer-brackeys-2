extends Node

const DEFAULT_PORT = 8080
const MAX_PLAYERS = 8
# Set this to the host part of your playit.gg address (everything before the colon)
const PLAYIT_HOST := "remember-absorption.gl.at.ply.gg"

const MAX_RECONNECT_ATTEMPTS := 5
const RECONNECT_DELAY        := 3.0

var local_name: String = ""
var is_host := false
var _on_mp_connection_failed: Callable
var _on_mp_server_disconnected: Callable

var _reconnect_address  := ""
var _reconnect_attempts := 0
var _reconnect_timer    := 0.0

signal connection_failed
signal server_disconnected
signal reconnecting(attempt: int, max_attempts: int)
signal reconnected
signal reconnect_failed

func host_game() -> Error:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	return OK

func join_game(address: String) -> Error:
	var host: String
	var port: int
	if ":" in address:
		var parts = address.rsplit(":", true, 1)
		host = parts[0]
		port = parts[1].to_int()
	else:
		host = address
		port = DEFAULT_PORT
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(host, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_on_mp_connection_failed = _handle_connection_failed
	_on_mp_server_disconnected = _handle_server_disconnected
	multiplayer.connection_failed.connect(_on_mp_connection_failed)
	multiplayer.server_disconnected.connect(_on_mp_server_disconnected)
	is_host = false
	_reconnect_address = address
	return OK

func close():
	set_process(false)
	_reconnect_address  = ""
	_reconnect_attempts = 0
	_reconnect_timer    = 0.0
	if _on_mp_connection_failed.is_valid() and multiplayer.connection_failed.is_connected(_on_mp_connection_failed):
		multiplayer.connection_failed.disconnect(_on_mp_connection_failed)
	if _on_mp_server_disconnected.is_valid() and multiplayer.server_disconnected.is_connected(_on_mp_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_mp_server_disconnected)
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false

func is_online() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer

func play_solo() -> void:
	close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	is_host = true

func _handle_connection_failed():
	multiplayer.multiplayer_peer = null
	if _reconnect_attempts > 0:
		_schedule_reconnect()
	else:
		connection_failed.emit()

func _handle_server_disconnected():
	server_disconnected.emit()
	multiplayer.multiplayer_peer = null
	if not is_host and not _reconnect_address.is_empty():
		_reconnect_attempts = 0
		_schedule_reconnect()

func _schedule_reconnect() -> void:
	_reconnect_timer = RECONNECT_DELAY
	set_process(true)

func _process(delta: float) -> void:
	_reconnect_timer -= delta
	if _reconnect_timer > 0.0:
		return
	set_process(false)
	if _reconnect_attempts >= MAX_RECONNECT_ATTEMPTS:
		_reconnect_address = ""
		reconnect_failed.emit()
		return
	_reconnect_attempts += 1
	reconnecting.emit(_reconnect_attempts, MAX_RECONNECT_ATTEMPTS)
	var host: String
	var port: int
	if ":" in _reconnect_address:
		var parts = _reconnect_address.rsplit(":", true, 1)
		host = parts[0]
		port = parts[1].to_int()
	else:
		host = _reconnect_address
		port = DEFAULT_PORT
	var peer = ENetMultiplayerPeer.new()
	if peer.create_client(host, port) != OK:
		_schedule_reconnect()
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_reconnect_success, CONNECT_ONE_SHOT)

func _on_reconnect_success() -> void:
	_reconnect_attempts = 0
	reconnected.emit()
