extends Node2D

const FUSE_TIME         := 2.0
const DAMAGE            := 1
const EXPLOSION_RADIUS  := 60.0
const EXPLOSION_SHOW    := 0.2  # seconds the explosion flash is visible

var thrower_peer_id: int = -1

var _timer       := 0.0
var _exploded    := false
var _show_timer  := 0.0

func _ready() -> void:
	add_to_group(&"projectile")

func _process(delta: float) -> void:
	if _exploded:
		_show_timer -= delta
		queue_redraw()
		if _show_timer <= 0.0:
			queue_free()
		return

	_timer += delta
	queue_redraw()
	if _timer >= FUSE_TIME:
		_explode()

func _draw() -> void:
	if _exploded:
		var alpha := clampf(_show_timer / EXPLOSION_SHOW, 0.0, 1.0)
		draw_circle(Vector2.ZERO, EXPLOSION_RADIUS, Color(1.0, 0.45, 0.0, alpha * 0.45))
		draw_arc(Vector2.ZERO, EXPLOSION_RADIUS, 0.0, TAU, 32, Color(1.0, 0.2, 0.0, alpha), 3.0)
		return

	# Bomb body
	draw_circle(Vector2.ZERO, 5.0, Color(0.15, 0.15, 0.15))

	# Fuse ring: draws the remaining time as an arc that shrinks
	var frac  := clampf(_timer / FUSE_TIME, 0.0, 1.0)
	var angle := TAU * (1.0 - frac)
	# Flash faster as time runs out
	var blink_rate := 3.0 + frac * 12.0
	var lit := fmod(_timer * blink_rate, 1.0) > 0.3
	if lit:
		draw_arc(Vector2.ZERO, 9.0, -PI * 0.5, -PI * 0.5 + angle, 32, Color(1.0, 0.55, 0.0), 2.5)

func _explode() -> void:
	_exploded   = true
	_show_timer = EXPLOSION_SHOW
	set_process(false)  # timer loop done; show_timer handled above

	for body in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(body):
			continue
		if body.get("is_ghost") == true:
			continue
		var dist: float = body.global_position.distance_to(global_position)
		if dist > EXPLOSION_RADIUS:
			continue
		var dir: Vector2 = (body.global_position - global_position).normalized()
		if dir.is_zero_approx():
			dir = Vector2.UP
		body.take_damage(DAMAGE, dir * 350.0 + Vector2(0.0, -80.0), thrower_peer_id)

	set_process(true)  # re-enable so _show_timer can count down
