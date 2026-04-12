extends Area2D

const LIFETIME := 0.12
const KNOCKBACK := Vector2(900.0, -200.0)

var direction := 1
var thrower_peer_id := -1

# Track what we've already hit this swing so multi-frame overlap only hits once
var _hit: Array = []

func _ready() -> void:
	await get_tree().create_timer(LIFETIME).timeout
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body in _hit:
		return
	if body == get_parent():
		return
	if body.is_in_group("player"):
		if NetworkManager.is_active() and body.get_multiplayer_authority() == thrower_peer_id:
			return
		_hit.append(body)
		# Strong horizontal knockback like a forward aerial — mostly sideways, slight upward
		body.take_damage(1, Vector2(direction * KNOCKBACK.x, KNOCKBACK.y), thrower_peer_id)

func _on_area_entered(area: Area2D) -> void:
	if area in _hit:
		return
	if area.is_in_group("shield"):
		queue_free()
		return
	if area.is_in_group("enemy_hurtbox"):
		_hit.append(area)
		area.get_parent().take_damage(1)
