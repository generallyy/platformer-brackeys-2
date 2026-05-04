extends Area2D

const HazardUtils = preload("res://scripts/hazards/hazard_utils.gd")

@export var damage: int = 1
@export var local_velocity := Vector2(320.0, 0.0)
@export var world_acceleration := Vector2.ZERO
@export var lifetime: float = 3.0
@export var hit_knockback: float = 220.0
@export var knockback_bias := Vector2.ZERO
@export var rotate_with_velocity := true
@export var spin_speed: float = 0.0
@export var attacker_peer_id: int = -1
@export var bypass_ghost := false

var _velocity := Vector2.ZERO
var _time_alive := 0.0


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_velocity = local_velocity.rotated(global_rotation)
	if rotate_with_velocity and not _velocity.is_zero_approx():
		rotation = _velocity.angle()


func _process(delta: float) -> void:
	_time_alive += delta
	if _time_alive >= lifetime:
		queue_free()
		return

	_velocity += world_acceleration * delta
	global_position += _velocity * delta

	if rotate_with_velocity and not _velocity.is_zero_approx():
		rotation = _velocity.angle()
	elif spin_speed != 0.0:
		rotation += spin_speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		HazardUtils.damage_target(body, damage, _current_knockback(), attacker_peer_id, bypass_ghost)
		queue_free()
		return
	if body is CharacterBody2D or body.is_in_group("enemy"):
		return
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("shield"):
		queue_free()
		return
	if area.is_in_group("enemy_hurtbox"):
		HazardUtils.damage_target(area.get_parent(), damage, _current_knockback(), attacker_peer_id, bypass_ghost)
		queue_free()


func _current_knockback() -> Vector2:
	var impulse := Vector2.ZERO
	if hit_knockback > 0.0 and not _velocity.is_zero_approx():
		impulse = _velocity.normalized() * hit_knockback
	return impulse + knockback_bias
