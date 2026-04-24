extends ProjectileBase

const FLIGHT_TIME := 1.2
const MAX_DISTANCE := 120.0
const ARC_HEIGHT := 20.0

@onready var visual = $Visual

var _hit_targets: Array = []

func _init() -> void:
	WEAPON_NAME = "Boomerang"
	WEAPON_COOLDOWN = 0.3  # short delay after each boomerang returns
	MAX_SIMULTANEOUS = 3
	RETURNS = true

func _get_offset(t: float) -> Vector2:
	# Let progress run freely past 1.0 — sin(p*PI) goes negative after 1,
	# curving the arc continuously in the opposite direction
	var progress := t / FLIGHT_TIME
	var x := direction * MAX_DISTANCE * sin(progress * PI)
	var y := -ARC_HEIGHT * sin(progress * TAU)
	return Vector2(x, y)

func _get_max_lifetime() -> float:
	return FLIGHT_TIME * 2.0

func _on_hit_character(_target: Node) -> void:
	pass  # boomerang passes through characters; hit tracking prevents double-hits

# Full override to handle _hit_targets tracking and no-despawn-on-hit behavior
func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	if body == owner_node:
		return
	if body in _hit_targets:
		return
	if body.is_in_group("player"):
		if body.get_multiplayer_authority() == thrower_peer_id:
			return
		_hit_targets.append(body)
		body.take_damage(damage, Vector2(direction * knockback.x, knockback.y))
		return
	if body is CharacterBody2D or body.is_in_group("enemy"):
		return
	_despawn()

func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if area in _hit_targets:
		return
	if area.is_in_group("enemy_hurtbox"):
		_hit_targets.append(area)
		area.get_parent().take_damage(damage)
