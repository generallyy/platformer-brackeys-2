extends Area2D

const HazardUtils = preload("res://scripts/hazards/hazard_utils.gd")

@export var damage: int = 1
@export var delay_before_damage: float = 1.4
@export var tick_interval: float = 1.25
@export var local_knockback := Vector2(30.0, -35.0)
@export var attacker_peer_id: int = -1
@export var bypass_ghost := false

var _tracked_bodies: Dictionary = {}


func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _tracked_bodies.is_empty():
		return

	var safe_tick: float = maxf(tick_interval, 0.01)
	var stale_ids: Array[int] = []

	for body_id in _tracked_bodies.keys():
		var body := instance_from_id(body_id) as Node2D
		if body == null or not is_instance_valid(body) or not overlaps_body(body):
			stale_ids.append(body_id)
			continue

		var state: Dictionary = _tracked_bodies[body_id]
		var delay_remaining: float = state.get("delay", delay_before_damage)
		var tick_remaining: float = state.get("tick", safe_tick)

		if body.get("_is_dying"):
			_tracked_bodies[body_id] = {
				"delay": maxf(delay_before_damage, 0.0),
				"tick": maxf(tick_interval, 0.01),
			}
			continue

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

		_tracked_bodies[body_id] = {
			"delay": delay_remaining,
			"tick": tick_remaining,
		}

	for body_id in stale_ids:
		_tracked_bodies.erase(body_id)

	if _tracked_bodies.is_empty():
		set_physics_process(false)


func _on_body_entered(body: Node2D) -> void:
	if not HazardUtils.is_target(body):
		return
	_tracked_bodies[body.get_instance_id()] = {
		"delay": maxf(delay_before_damage, 0.0),
		"tick": maxf(tick_interval, 0.01),
	}
	set_physics_process(true)


func _on_body_exited(body: Node2D) -> void:
	_tracked_bodies.erase(body.get_instance_id())
	if _tracked_bodies.is_empty():
		set_physics_process(false)


func _apply_hit(body: Node) -> void:
	HazardUtils.damage_target(body, damage, local_knockback, attacker_peer_id, bypass_ghost)
