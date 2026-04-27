extends Area2D

@export var single_use: bool = false

@onready var prompt_label: Label = $PromptLabel
@onready var flag: Polygon2D = $Flag

var _activated_peers: Dictionary = {}
var _spent_peers: Dictionary = {}

func _ready() -> void:
	add_to_group("checkpoint")
	prompt_label.text = "checkpoint"
	flag.color = Color(0.95, 0.85, 0.2, 1)

func reset_for_round() -> void:
	_activated_peers.clear()
	_spent_peers.clear()
	flag.color = Color(0.95, 0.85, 0.2, 1)
	prompt_label.text = "checkpoint"

func reset_for_peer(peer_id: int) -> void:
	if single_use and peer_id in _spent_peers:
		return
	_activated_peers.erase(peer_id)
	if _activated_peers.is_empty():
		flag.color = Color(0.95, 0.85, 0.2, 1)
		prompt_label.text = "checkpoint"

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.is_multiplayer_authority():
		return

	var peer_id := body.get_multiplayer_authority()
	if peer_id in _activated_peers:
		return

	_activated_peers[peer_id] = true
	if single_use:
		_spent_peers[peer_id] = true
	prompt_label.text = "checkpoint set"
	flag.color = Color(0.3, 1.0, 0.45, 1)
	var main = get_tree().get_root().get_node("Main")
	main.activate_checkpoint(self, peer_id, not body.get("is_ghost"))
