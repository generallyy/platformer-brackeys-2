extends StaticBody2D

const MAX_HEALTH := 3
const CONTACT_KNOCKBACK := Vector2(100.0, -150.0)
const RESPAWN_DELAY := 4.0
const HIT_BLINK_DURATION := 0.4
const HIT_BLINK_INTERVAL := 0.12
const HIT_BLINK_THRESHOLD := 0.06

var health := MAX_HEALTH
var _dead := false
var _blink_timer := 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _process(delta: float) -> void:
	if _dead:
		return
	if _blink_timer > 0.0:
		_blink_timer -= delta
		animated_sprite.visible = fmod(_blink_timer, HIT_BLINK_INTERVAL) > HIT_BLINK_THRESHOLD
		if _blink_timer <= 0.0:
			animated_sprite.visible = true

func take_damage(amount: int) -> void:
	if _dead:
		return
	_rpc_blink_on_hit.rpc()
	health -= amount
	if health <= 0:
		_die()

@rpc("any_peer", "call_local", "unreliable")
func _rpc_blink_on_hit() -> void:
	_start_blink()

func _start_blink() -> void:
	if _dead:
		return
	_blink_timer = HIT_BLINK_DURATION

func _die() -> void:
	_dead = true
	animated_sprite.visible = true
	visible = false
	set_deferred("collision_layer", 0)
	$Hurtbox.set_deferred("monitorable", false)
	$PlayerHurtbox.set_deferred("monitoring", false)
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	health = MAX_HEALTH
	_blink_timer = 0.0
	animated_sprite.visible = true
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
