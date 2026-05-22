extends AttackHitbox

var shield_spike_dmg: int = 0
var parry_stun: bool = false

func _init() -> void:
	lifetime = 0.12
	knockback_base = Vector2(670.0, -200.0)

func _handle_shield(body: Node2D) -> bool:
	if body.get("_is_shielding") != true:
		return true
	if shield_spike_dmg > 0:
		get_parent().take_damage(shield_spike_dmg, Vector2.ZERO, body.get_multiplayer_authority())
	if parry_stun:
		get_parent().apply_stun(1.0)
	return false
