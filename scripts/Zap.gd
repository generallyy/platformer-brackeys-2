extends Area2D

const LIFETIME := 0.06
const KNOCKBACK_BASE := Vector2(100.0, -300.0)

var direction := 1
var thrower_peer_id := -1
var damage := 1
var knockback_scale := 1.0
var slow_on_hit: bool = false

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
		if body.get_multiplayer_authority() == thrower_peer_id:
			return
		_hit.append(body)
		# Strong horizontal knockback like a forward aerial — mostly sideways, slight upward
		body.take_damage(damage, Vector2(direction * KNOCKBACK_BASE.x, KNOCKBACK_BASE.y) * knockback_scale, thrower_peer_id)
		if slow_on_hit:
			body.apply_slow(PowerupIds.SLOW_DURATION)

func _on_area_entered(area: Area2D) -> void:
	if area in _hit:
		return
	if area.is_in_group("shield"):
		queue_free()
		return
	if area.is_in_group("enemy_hurtbox"):
		_hit.append(area)
		area.get_parent().take_damage(1)
