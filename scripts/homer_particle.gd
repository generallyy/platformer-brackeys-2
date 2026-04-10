extends ProjectileBase
class_name HomerParticle

# ── Static pool ──────────────────────────────────────────────────────────────
static var _pool: Array = []

## Grab a particle from the pool, or instantiate one if the pool is empty.
static func acquire() -> HomerParticle:
	for i in range(_pool.size() - 1, -1, -1):
		if not is_instance_valid(_pool[i]):
			_pool.remove_at(i)
	if _pool.size() > 0:
		return _pool.pop_back()
	return (load("res://scenes/weapons/HomerParticle.tscn") as PackedScene).instantiate()

# ── Per-particle state ────────────────────────────────────────────────────────
const TRAIL_MAX_POINTS := 14

var _target: Vector2
var _target_node: Node2D = null
var _control_relative: Vector2
var _particle_lifetime: float
var _delay: float = 0.0

@onready var _trail: Line2D = $Trail

func setup(target: Vector2, angle: float, delay: float, target_node: Node2D = null) -> void:
	_target = target
	_target_node = target_node
	var spread_dist := randf_range(15.0, 50.0)
	_control_relative = Vector2(cos(angle), sin(angle)) * spread_dist
	_particle_lifetime = randf_range(0.4, 0.6)
	_delay = delay

func _process(delta: float) -> void:
	if not _active:
		return
	if not _origin_captured:
		_origin = global_position
		_origin_captured = true
		# Bake relative control point into world space now that origin is known
		_control_relative = _origin + _control_relative

	_t += delta
	if is_instance_valid(_target_node):
		_target = _target_node.global_position + Vector2(0, -5)
	if _t < _delay:
		global_position = _origin
		return

	var elapsed := _t - _delay
	var f : float = clamp(elapsed / _particle_lifetime, 0.0, 1.0)
	var ti : float = 1.0 - f
	# Quadratic bezier: start -> control -> target
	global_position = ti * ti * _origin + 2.0 * ti * f * _control_relative + f * f * _target

	# Append current world position to trail, trim oldest point if over limit
	_trail.add_point(global_position)
	if _trail.get_point_count() > TRAIL_MAX_POINTS:
		_trail.remove_point(0)

	if f >= 1.0:
		if is_instance_valid(_target_node):
			_target_node.take_damage(damage, Vector2(direction * knockback.x, knockback.y))
		_despawn()

# ── Pool return instead of queue_free ────────────────────────────────────────
func _despawn() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	# remove_child on a CollisionObject during a physics callback crashes —
	# mark inactive immediately above, then defer the tree removal + pool return.
	call_deferred("_deferred_pool_return")

func _deferred_pool_return() -> void:
	if is_inside_tree():
		get_parent().remove_child(self)
	_reset_for_pool()

func _enter_tree() -> void:
	if _active:
		set_process(true)

func _reset_for_pool() -> void:
	_active = true
	_origin_captured = false
	_t = 0.0
	_origin = Vector2.ZERO
	_control_relative = Vector2.ZERO
	_target_node = null
	_trail.clear_points()
	visible = true
	# set_process(true) is deferred to _enter_tree so it's not called out-of-tree
	HomerParticle._pool.append(self)
