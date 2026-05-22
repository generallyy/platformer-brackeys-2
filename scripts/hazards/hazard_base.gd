extends Area2D
class_name HazardBase

var _tracked_bodies: Dictionary = {}

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if _tracked_bodies.is_empty():
		return
	var stale_ids: Array[int] = []
	for body_id in _tracked_bodies.keys():
		var body := instance_from_id(body_id) as Node2D
		if body == null or not is_instance_valid(body) or not overlaps_body(body):
			_on_body_stale(body, body_id)
			stale_ids.append(body_id)
			continue
		_tick_body(body, body_id, delta)
	for body_id in stale_ids:
		_tracked_bodies.erase(body_id)
	if _tracked_bodies.is_empty():
		set_physics_process(false)

## Called each frame for each valid tracked body. Override to apply damage, push, etc.
func _tick_body(_body: Node2D, _body_id: int, _delta: float) -> void:
	pass

## Called when a tracked body becomes stale (freed or left the area).
## Override to do cleanup (e.g. clear a push source).
func _on_body_stale(_body: Node2D, _body_id: int) -> void:
	pass

## Called just before a body is erased from tracking on body_exited.
## Override for the same cleanup as _on_body_stale if needed.
func _on_body_removed(_body: Node2D) -> void:
	pass

func _on_body_entered(_body: Node2D) -> void:
	pass

func _on_body_exited(body: Node2D) -> void:
	_on_body_removed(body)
	_tracked_bodies.erase(body.get_instance_id())
	if _tracked_bodies.is_empty():
		set_physics_process(false)
