extends HazardBase

@export var damage: int = 1
@export var delay_before_damage: float = 1.4
@export var tick_interval: float = 1.25
@export var local_knockback := Vector2(30.0, -35.0)
@export var attacker_peer_id: int = -1
@export var bypass_ghost := false

func _on_body_entered(body: Node2D) -> void:
	if not HazardUtils.is_target(body):
		return
	_tracked_bodies[body.get_instance_id()] = {
		"delay": maxf(delay_before_damage, 0.0),
		"tick": maxf(tick_interval, 0.01),
	}
	set_physics_process(true)

func _tick_body(body: Node2D, body_id: int, delta: float) -> void:
	var safe_tick := maxf(tick_interval, 0.01)
	var state: Dictionary = _tracked_bodies[body_id]
	var delay_remaining: float = state.get("delay", delay_before_damage)
	var tick_remaining: float = state.get("tick", safe_tick)

	if body.get("_is_dying"):
		_tracked_bodies[body_id] = {
			"delay": maxf(delay_before_damage, 0.0),
			"tick": safe_tick,
		}
		return

	if delay_remaining > 0.0:
		delay_remaining -= delta
		if delay_remaining <= 0.0:
			_apply_hit(body)
			tick_remaining = safe_tick
	else:
		tick_remaining -= delta
		if tick_remaining <= 0.0:
			_apply_hit(body)
			tick_remaining = safe_tick

	_tracked_bodies[body_id] = {"delay": delay_remaining, "tick": tick_remaining}

func _apply_hit(body: Node) -> void:
	HazardUtils.damage_target(body, damage, local_knockback, attacker_peer_id, bypass_ghost)
