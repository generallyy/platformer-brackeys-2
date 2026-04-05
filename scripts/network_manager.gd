extends Node

const DEFAULT_PORT = 8080
const MAX_PLAYERS = 4
# Set this to the host part of your playit.gg address (everything before the colon)
const PLAYIT_HOST := "remember-absorption.gl.at.ply.gg"

var is_host := false
var _active := false

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
	multiplayer.connection_failed.connect(func():
		connection_failed.emit()
		multiplayer.multiplayer_peer = null
		_active = false
	)
	multiplayer.server_disconnected.connect(func():
		server_disconnected.emit()
		multiplayer.multiplayer_peer = null
		_active = false
	)
	is_host = false
	_active = true
	return OK

func close():
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_host = false
	_active = false

func is_active() -> bool:
	return _active
