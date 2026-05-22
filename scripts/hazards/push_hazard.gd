extends HazardBase

@export var push_force: float = 360.0
@export var max_speed: float = 1000.0
@export var upward_lift_multiplier: float = 1.15

var _default_gravity: float = 0.0

func _ready() -> void:
	_default_gravity = float(ProjectSettings.get_setting("physics/2d/default_gravity"))
	super._ready()

func _on_body_entered(body: Node2D) -> void:
	if not HazardUtils.can_push_player(body):
		return
	_tracked_bodies[body.get_instance_id()] = true
	set_physics_process(true)

func _tick_body(body: Node2D, _body_id: int, delta: float) -> void:
	if is_zero_approx(push_force) or not HazardUtils.can_push_player(body):
		return
	var world_push := Vector2(push_force, 0.0).rotated(global_rotation)
	if world_push.y < 0.0 and upward_lift_multiplier > 0.0:
		world_push.y = minf(world_push.y, -_default_gravity * upward_lift_multiplier)
	var direction := world_push.normalized()
	if body.has_method("set_environmental_push_source"):
		body.set_environmental_push_source(get_instance_id(), world_push, max_speed)
	else:
		body.velocity += world_push * delta
		if max_speed > 0.0:
			var along_push: float = body.velocity.dot(direction)
			if along_push > max_speed:
				body.velocity -= direction * (along_push - max_speed)

func _on_body_stale(body: Node2D, _body_id: int) -> void:
	_clear_push_source(body, get_instance_id())

func _on_body_removed(body: Node2D) -> void:
	_clear_push_source(body, get_instance_id())

func _clear_push_source(body: Node, source_id: int) -> void:
	if body == null or not is_instance_valid(body):
		return
	if body.has_method("clear_environmental_push_source"):
		body.clear_environmental_push_source(source_id)
