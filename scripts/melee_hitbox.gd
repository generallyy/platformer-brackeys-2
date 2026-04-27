extends Area2D

const LIFETIME := 0.12
const KNOCKBACK_BASE := Vector2(670.0, -200.0)

var direction := 1
var thrower_peer_id := -1
var damage := 1
var knockback_scale := 1.0

var slow_on_hit: bool = false
var shield_spike_dmg: int = 0
var parry_stun: bool = false
var can_hit_ghosts: bool = false

signal hit_landed

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

		# Ghost Hunter: skip ghosts unless attacker has the powerup
		if body.get("is_ghost") == true and not can_hit_ghosts:
			return

		# SHIELD_SPIKE / PARRY_STUN: check before taking damage
		if body.get("_is_shielding") == true:
			if shield_spike_dmg > 0:
				get_parent().take_damage(shield_spike_dmg, Vector2.ZERO, body.get_multiplayer_authority())
			if parry_stun:
				get_parent().apply_stun(1.0)
			return  # shielded player takes no damage

		body.take_damage(damage, Vector2(direction * KNOCKBACK_BASE.x, KNOCKBACK_BASE.y) * knockback_scale, thrower_peer_id, can_hit_ghosts)
		hit_landed.emit()

		if slow_on_hit:
			body.apply_slow(PowerupIds.SLOW_DURATION)

func _on_area_entered(area: Area2D) -> void:
	if area in _hit:
		return
	if area.is_in_group("enemy_hurtbox"):
		_hit.append(area)
		area.get_parent().take_damage(1)
