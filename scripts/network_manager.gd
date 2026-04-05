extends Node

const DEFAULT_PORT = 8080
const MAX_PLAYERS = 4
# Set this to the host part of your playit.gg address (everything before the colon)
const PLAYIT_HOST := "remember-absorption.gl.at.ply.gg"

var is_host := false
var _active := false
var _on_mp_connection_failed: Callable
var _on_mp_server_disconnected: Callable

signal connection_failed
signal server_disconnected

func host_game() -> Error:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(DEFAULT_PORT, MAX_PLAYERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	_active = true
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
	_active = true
	return OK

func close():
	if _on_mp_connection_failed.is_valid() and multiplayer.connection_failed.is_connected(_on_mp_connection_failed):
		multiplayer.connection_failed.disconnect(_on_mp_connection_failed)
	if _on_mp_server_disconnected.is_valid() and multiplayer.server_disconnected.is_connected(_on_mp_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_mp_server_disconnected)
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	_active = false

func is_active() -> bool:
	return _active

func _handle_connection_failed():
	connection_failed.emit()
	multiplayer.multiplayer_peer = null
	_active = false

func _handle_server_disconnected():
	server_disconnected.emit()
	multiplayer.multiplayer_peer = null
	_active = false
