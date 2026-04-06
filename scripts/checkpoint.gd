extends Area2D

@onready var prompt_label: Label = $PromptLabel
@onready var flag: Polygon2D = $Flag

var _activated_peers: Dictionary = {}

func _ready() -> void:
	prompt_label.text = "checkpoint"
	flag.color = Color(0.95, 0.85, 0.2, 1)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if NetworkManager.is_active() and not body.is_multiplayer_authority():
		return

	var peer_id := body.get_multiplayer_authority() if NetworkManager.is_active() else 1
	if peer_id in _activated_peers:
		return

	_activated_peers[peer_id] = true
	prompt_label.text = "checkpoint set"
	flag.color = Color(0.3, 1.0, 0.45, 1)
	var main = get_tree().get_root().get_node("Main")
	main.activate_checkpoint(self, peer_id)
