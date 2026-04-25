extends Node2D

@export var particle_texture: Texture2D
@export var particle_count: int = 56
@export var cloud_radius: float = 28.0
@export var min_particle_scale: float = 0.07
@export var max_particle_scale: float = 0.18
@export var min_alpha: float = 0.08
@export var max_alpha: float = 0.72
@export var min_cycle_duration: float = 1.2
@export var max_cycle_duration: float = 2.8
@export var drift_strength: float = 4.5

var _rng := RandomNumberGenerator.new()
var _particles: Array[Dictionary] = []


func _ready() -> void:
	if particle_texture == null or particle_count <= 0:
		set_process(false)
		return
	_rng.randomize()
	_rebuild_particles()
	set_process(true)


func _process(delta: float) -> void:
	for i in range(_particles.size()):
		var entry: Dictionary = _particles[i]
		var sprite: Sprite2D = entry.get("sprite")
		if sprite == null or not is_instance_valid(sprite):
			continue

		var phase: float = entry.get("phase", 0.0) + delta / entry.get("duration", 1.0)
		if phase >= 1.0:
			_reset_particle(entry, sprite)
			phase = entry.get("phase", 0.0)
		else:
			entry["phase"] = phase

		_apply_particle_state(entry, sprite)
		_particles[i] = entry


func _rebuild_particles() -> void:
	for child in get_children():
		child.queue_free()
	_particles.clear()

	var count := maxi(particle_count, 1)
	for _i in range(count):
		var sprite := Sprite2D.new()
		sprite.texture = particle_texture
		add_child(sprite)

		var entry: Dictionary = {}
		_particles.append(entry)
		_reset_particle(entry, sprite, true)
		_apply_particle_state(entry, sprite)


func _reset_particle(entry: Dictionary, sprite: Sprite2D, randomize_phase: bool = false) -> void:
	var radius_scale := sqrt(_rng.randf())
	var angle := _rng.randf_range(0.0, TAU)
	var target_position := Vector2.RIGHT.rotated(angle) * cloud_radius * radius_scale
	var drift_direction := Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
	var scale_value := _rng.randf_range(min_particle_scale, max_particle_scale)
	var tint := Color(
		_rng.randf_range(0.38, 0.80),
		_rng.randf_range(0.78, 1.00),
		_rng.randf_range(0.30, 0.58),
		1.0
	)

	entry["phase"] = _rng.randf() if randomize_phase else 0.0
	entry["duration"] = _rng.randf_range(min_cycle_duration, max_cycle_duration)
	entry["base_position"] = target_position
	entry["drift_direction"] = drift_direction
	entry["drift_amount"] = _rng.randf_range(drift_strength * 0.45, drift_strength)
	entry["scale"] = scale_value
	entry["color"] = tint
	entry["pulse"] = _rng.randf_range(0.88, 1.18)
	entry["sprite"] = sprite

	sprite.centered = true
	sprite.z_index = int(_rng.randi_range(0, 4))


func _apply_particle_state(entry: Dictionary, sprite: Sprite2D) -> void:
	var phase: float = clampf(entry.get("phase", 0.0), 0.0, 1.0)
	var fade := sin(phase * PI)
	var drift_direction: Vector2 = entry.get("drift_direction", Vector2.ZERO)
	var drift_amount: float = entry.get("drift_amount", 0.0)
	var base_position: Vector2 = entry.get("base_position", Vector2.ZERO)
	var pulse: float = entry.get("pulse", 1.0)
	var base_scale: float = entry.get("scale", min_particle_scale)
	var tint: Color = entry.get("color", Color(0.5, 1.0, 0.4, 1.0))

	sprite.position = base_position + drift_direction * drift_amount * (phase - 0.5)
	sprite.scale = Vector2.ONE * base_scale * lerpf(0.82, pulse, fade)

	var alpha := lerpf(min_alpha, max_alpha, fade)
	sprite.modulate = Color(tint.r, tint.g, tint.b, alpha)
