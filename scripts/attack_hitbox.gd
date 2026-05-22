extends Area2D
class_name AttackHitbox

var lifetime := 0.1
var knockback_base := Vector2(300.0, -200.0)

var direction := 1
var thrower_peer_id := -1
var damage := 1
var knockback_scale := 1.0
var slow_on_hit: bool = false
var can_hit_ghosts: bool = false

signal hit_landed

var _hit: Array = []

func _ready() -> void:
	await get_tree().create_timer(lifetime).timeout
	queue_free()

static func calc_knockback(base: Vector2, dir: int, knockback_scale: float = 1.0) -> Vector2:
	return Vector2(dir * base.x, base.y) * knockback_scale

func _on_body_entered(body: Node2D) -> void:
	if body in _hit:
		return
	if body == get_parent():
		return
	if not body.is_in_group("player"):
		return
	if body.get_multiplayer_authority() == thrower_peer_id:
		return
	_hit.append(body)
	if body.get("is_ghost") == true and not can_hit_ghosts:
		return
	if not _handle_shield(body):
		return
	body.take_damage(damage, calc_knockback(knockback_base, direction, knockback_scale), thrower_peer_id, can_hit_ghosts)
	hit_landed.emit()
	if slow_on_hit:
		body.apply_slow(PowerupIds.SLOW_DURATION)

## Override to handle shield interactions.
## Return false to cancel damage (player is shielded).
func _handle_shield(_body: Node2D) -> bool:
	return true

func _on_area_entered(area: Area2D) -> void:
	if area in _hit:
		return
	if area.is_in_group("enemy_hurtbox"):
		_hit.append(area)
		area.get_parent().take_damage(1)
