extends HazardBase

@export var damage: int = 1
@export var hit_interval: float = 0.0
@export var local_knockback := Vector2.ZERO
@export var radial_knockback_strength: float = 0.0
@export var tangential_knockback_strength: float = 0.0
@export_node_path("Node2D") var tangent_spin_source_path: NodePath
@export var attacker_peer_id: int = -1
@export var bypass_ghost := false
@export var hits_on_enter := true

func _ready() -> void:
	super._ready()
	set_physics_process(hit_interval > 0.0)

func _on_body_entered(body: Node2D) -> void:
	if not HazardUtils.is_target(body):
		return
	if hits_on_enter or hit_interval <= 0.0:
		_apply_hit(body)
	if hit_interval > 0.0:
		_tracked_bodies[body.get_instance_id()] = hit_interval

func _tick_body(body: Node2D, body_id: int, delta: float) -> void:
	_tracked_bodies[body_id] -= delta
	if _tracked_bodies[body_id] <= 0.0:
		_apply_hit(body)
		_tracked_bodies[body_id] = hit_interval

func _apply_hit(body: Node) -> void:
	var final_knockback := local_knockback.rotated(global_rotation)
	if body is Node2D and (radial_knockback_strength > 0.0 or tangential_knockback_strength > 0.0):
		var radial_direction: Vector2 = (body.global_position - global_position).normalized()
		if radial_direction.is_zero_approx():
			radial_direction = Vector2.UP
		if radial_knockback_strength > 0.0:
			final_knockback += radial_direction * radial_knockback_strength
		if tangential_knockback_strength > 0.0:
			var tangent_sign := _tangent_spin_sign()
			if is_zero_approx(tangent_sign):
				tangent_sign = 1.0
			var tangential_direction := radial_direction.rotated(tangent_sign * PI * 0.5)
			final_knockback += tangential_direction * tangential_knockback_strength
	HazardUtils.damage_target(body, damage, final_knockback, attacker_peer_id, bypass_ghost)

func _tangent_spin_sign() -> float:
	if tangent_spin_source_path == NodePath(""):
		return 0.0
	var spin_source := get_node_or_null(tangent_spin_source_path)
	if spin_source == null:
		return 0.0
	var spin_speed = spin_source.get("spin_speed")
	if spin_speed == null:
		return 0.0
	return sign(float(spin_speed))
