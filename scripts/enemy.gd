extends StaticBody2D

const MAX_HEALTH := 3
const CONTACT_KNOCKBACK := Vector2(100.0, -150.0)
const RESPAWN_DELAY := 4.0

var health := MAX_HEALTH
var _dead := false

func take_damage(amount: int) -> void:
	if _dead:
		return
	health -= amount
	if health <= 0:
		_die()

func _die() -> void:
	_dead = true
	visible = false
	collision_layer = 0               # player walks through
	$Hurtbox.monitorable = false      # weapons can't hit it
	$PlayerHurtbox.monitoring = false # it can't hit the player
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	health = MAX_HEALTH
	visible = true
	collision_layer = 1
	$Hurtbox.monitorable = true
	$PlayerHurtbox.monitoring = true
	_dead = false

func _on_player_hurtbox_body_entered(body: Node2D) -> void:
	if _dead:
		return
	if body.is_in_group("player"):
		var dir = sign((body.global_position - global_position).x)
		body.take_damage(1, Vector2(dir * CONTACT_KNOCKBACK.x, CONTACT_KNOCKBACK.y))
