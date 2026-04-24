@tool
extends Area2D

@export var team_id: int = 1  # 0 = no team

var _player_nearby: Node = null

func _ready() -> void:
	var main := get_tree().get_root().get_node_or_null("Main")
	var color: Color = main.get_team_color(team_id) if main else Color.WHITE
	$Color.modulate = color
	var team_name: String = main.get_team_name(team_id) if main else "Team %d" % team_id
	$PromptLabel.text = team_name
	$PromptLabel.visible = true

func _process(_delta: float) -> void:
	if _player_nearby and Input.is_action_just_pressed("interact"):
		var peer_id := multiplayer.get_unique_id()
		get_tree().get_root().get_node("Main").request_team_change(peer_id, team_id)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.is_multiplayer_authority():
		return
	_player_nearby = body
	$PromptLabel.text = "Press %s to join!" % InputUtils.get_action_key("interact")

func _on_body_exited(body: Node2D) -> void:
	if body == _player_nearby:
		_player_nearby = null
		var main := get_tree().get_root().get_node_or_null("Main")
		$PromptLabel.text = main.get_team_name(team_id) if main else "Team %d" % team_id
