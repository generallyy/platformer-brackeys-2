extends RefCounted
class_name HazardUtils


static func is_target(body: Node) -> bool:
	return body != null and is_instance_valid(body) and (body.is_in_group("player") or body.is_in_group("enemy"))


static func can_push_player(body: Node) -> bool:
	return body != null and is_instance_valid(body) and body.is_in_group("player") and body.is_multiplayer_authority()


static func damage_target(body: Node, amount: int, knockback: Vector2 = Vector2.ZERO, attacker_peer_id: int = -1, bypass_ghost: bool = false) -> void:
	if not is_target(body):
		return
	if body.is_in_group("player"):
		body.take_damage(amount, knockback, attacker_peer_id, bypass_ghost)
	elif body.has_method("take_damage"):
		body.take_damage(amount)
