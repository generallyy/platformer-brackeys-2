extends Area2D

const FLAG_TEAM_ID := 1

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.is_multiplayer_authority():
		return
	if body.is_ghost:
		return
	var main := get_tree().get_root().get_node_or_null("Main")
	if main == null:
		return
	main.flag_crossed(body.get_multiplayer_authority(), FLAG_TEAM_ID)
