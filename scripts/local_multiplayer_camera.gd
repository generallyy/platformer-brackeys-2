extends Camera2D
class_name LocalMultiplayerCamera

## One shared camera for every local player, framing all of them at once —
## Towerfall/Nidhogg-style. Zoom is clamped between max_zoom (how close it can
## get when players are clustered — the "minimum size" of the visible area)
## and min_zoom (how far it can pull back when players spread out).

@export var max_zoom := Vector2(3.0, 3.0)
@export var min_zoom := Vector2(1.0, 1.0)
@export var margin := Vector2(120.0, 120.0)
@export var pan_speed := 5.0
@export var zoom_speed := 3.0

var tracked_players: Array = []
var _needs_snap := true


func _ready() -> void:
	make_current()


func request_snap() -> void:
	_needs_snap = true


func _physics_process(delta: float) -> void:
	var valid_players: Array = []
	for p in tracked_players:
		if is_instance_valid(p):
			valid_players.append(p)
	if valid_players.is_empty():
		return

	var min_pos: Vector2 = valid_players[0].global_position
	var max_pos: Vector2 = min_pos
	for p in valid_players:
		var pos: Vector2 = p.global_position
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)

	var target_pos: Vector2 = (min_pos + max_pos) / 2.0
	var spread: Vector2 = (max_pos - min_pos) + margin * 2.0

	var viewport_size: Vector2 = get_viewport_rect().size
	var zoom_for_spread_x: float = viewport_size.x / max(spread.x, 1.0)
	var zoom_for_spread_y: float = viewport_size.y / max(spread.y, 1.0)
	# Uniform zoom (same x/y) so the world doesn't stretch — use whichever axis
	# needs to be more zoomed out so both directions still fit on screen.
	var uniform_zoom: float = clamp(min(zoom_for_spread_x, zoom_for_spread_y), min_zoom.x, max_zoom.x)
	var target_zoom := Vector2(uniform_zoom, uniform_zoom)

	if _needs_snap:
		global_position = target_pos
		zoom = target_zoom
		_needs_snap = false
		return

	global_position = global_position.lerp(target_pos, clampf(pan_speed * delta, 0.0, 1.0))
	zoom = zoom.lerp(target_zoom, clampf(zoom_speed * delta, 0.0, 1.0))
