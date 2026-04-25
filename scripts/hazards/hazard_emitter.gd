extends Node2D

@export var projectile_scene: PackedScene
@export var fire_interval: float = 2.0
@export var start_delay: float = 0.0
@export var shots_per_burst: int = 1
@export var spread_degrees: float = 0.0
@export var projectile_offset := Vector2(16.0, 0.0)
@export var projectile_rotation_offset_degrees: float = 0.0
@export var active_duration: float = -1.0
@export var inactive_duration: float = 0.0
@export var starts_active := true
@export var autoplay := true

var _delay_remaining := 0.0
var _cooldown := 0.0
var _is_active := true
var _phase_time_remaining := 0.0


func _ready() -> void:
	_delay_remaining = maxf(start_delay, 0.0)
	_cooldown = maxf(fire_interval, 0.01)
	_is_active = true
	_phase_time_remaining = 0.0
	if _has_cycle():
		_is_active = starts_active
		_phase_time_remaining = maxf(active_duration if _is_active else inactive_duration, 0.01)
	set_process(autoplay and projectile_scene != null)


func _process(delta: float) -> void:
	if projectile_scene == null:
		return
	_update_cycle(delta)
	if not _is_active:
		return

	if _delay_remaining > 0.0:
		_delay_remaining -= delta
		if _delay_remaining > 0.0:
			return
		_fire()
		_cooldown = maxf(fire_interval, 0.01)
		return

	_cooldown -= delta
	if _cooldown > 0.0:
		return

	_fire()
	_cooldown = maxf(fire_interval, 0.01)


func fire_once() -> void:
	_fire()


func _has_cycle() -> bool:
	return active_duration > 0.0 and inactive_duration > 0.0


func _update_cycle(delta: float) -> void:
	if not _has_cycle():
		_is_active = true
		return

	_phase_time_remaining -= delta
	while _phase_time_remaining <= 0.0:
		if _is_active:
			_is_active = false
			_phase_time_remaining += maxf(inactive_duration, 0.01)
		else:
			_is_active = true
			_phase_time_remaining += maxf(active_duration, 0.01)


func _fire() -> void:
	var container: Node = get_tree().current_scene
	if container == null:
		container = get_parent()

	var shot_count := maxi(shots_per_burst, 1)
	var base_rotation := global_rotation + deg_to_rad(projectile_rotation_offset_degrees)
	var center_offset := 0.5 * float(shot_count - 1)

	for i in range(shot_count):
		var projectile := projectile_scene.instantiate()
		var angle_offset := deg_to_rad(spread_degrees) * (float(i) - center_offset)
		container.add_child(projectile)
		if projectile is Node2D:
			projectile.global_position = to_global(projectile_offset)
			projectile.global_rotation = base_rotation + angle_offset
