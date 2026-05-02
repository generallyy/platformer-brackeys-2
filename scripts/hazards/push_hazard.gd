extends Area2D

@export var push_force: float = 360.0
@export var max_speed: float = 1000.0
@export var upward_lift_multiplier: float = 1.15

var _default_gravity: float = 0.0

var _tracked_bodies: Dictionary = {}


func _ready() -> void:
	_default_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if _tracked_bodies.is_empty() or is_zero_approx(push_force):
		return

	var world_push := Vector2(push_force, 0.0).rotated(global_rotation)
	if world_push.y < 0.0 and upward_lift_multiplier > 0.0:
		var minimum_upward_accel := _default_gravity * upward_lift_multiplier
		world_push.y = minf(world_push.y, -minimum_upward_accel)
	var direction := world_push.normalized()
	var source_id := get_instance_id()
	var stale_ids: Array[int] = []

	for body_id in _tracked_bodies.keys():
		var body := instance_from_id(body_id) as Node
		if body == null or not is_instance_valid(body) or not overlaps_body(body):
			_clear_push_source(body, source_id)
			stale_ids.append(body_id)
			continue
		if not HazardUtils.can_push_player(body):
			_clear_push_source(body, source_id)
			stale_ids.append(body_id)
			continue

		if body.has_method("set_environmental_push_source"):
			body.set_environmental_push_source(source_id, world_push, max_speed)
		else:
			body.velocity += world_push * delta
			if max_speed > 0.0:
				var along_push: float = body.velocity.dot(direction)
				if along_push > max_speed:
					body.velocity -= direction * (along_push - max_speed)

	for body_id in stale_ids:
		_tracked_bodies.erase(body_id)

	if _tracked_bodies.is_empty():
		set_physics_process(false)


func _on_body_entered(body: Node2D) -> void:
	if not HazardUtils.can_push_player(body):
		return
	_tracked_bodies[body.get_instance_id()] = true
	set_physics_process(true)


func _on_body_exited(body: Node2D) -> void:
	_clear_push_source(body, get_instance_id())
	_tracked_bodies.erase(body.get_instance_id())
	if _tracked_bodies.is_empty():
		set_physics_process(false)


func _clear_push_source(body: Node, source_id: int) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.has_method("clear_environmental_push_source"):
		body.clear_environmental_push_source(source_id)
