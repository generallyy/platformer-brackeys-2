extends Control

signal shot_requested(angle: float, power: float)

const _WOOD_COLOR := Color(0.33, 0.17, 0.08)
const _WOOD_HIGHLIGHT := Color(0.49, 0.26, 0.12)
const _FELT_COLOR := Color(0.08, 0.45, 0.29)
const _FELT_GLOW := Color(0.14, 0.63, 0.41)
const _RAIL_COLOR := Color(0.24, 0.13, 0.06)
const _POCKET_COLOR := Color(0.03, 0.04, 0.05)

var _session: Dictionary = {}
var _display_balls: Array = []
var _interactive := false
var _mouse_table_position := Vector2.ZERO
var _dragging_shot := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func set_view(session: Dictionary, display_balls: Array, interactive: bool) -> void:
	_session = session.duplicate(true)
	_display_balls = display_balls.duplicate(true)
	_interactive = interactive
	if not _interactive:
		_dragging_shot = false
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_table_position = _to_table_space(event.position)
		queue_redraw()
		return

	if event is not InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return

	_mouse_table_position = _to_table_space(event.position)
	if event.pressed:
		if _interactive and _has_cue_ball():
			_dragging_shot = true
			queue_redraw()
			accept_event()
	else:
		if not _dragging_shot:
			return
		_dragging_shot = false
		var shot := _shot_vector()
		if shot.length() >= 12.0:
			shot_requested.emit(shot.angle(), clampf(shot.length() / 190.0, 0.0, 1.0))
		queue_redraw()
		accept_event()


func _draw() -> void:
	var scale_factor := _view_scale()
	var offset := _view_offset()
	var outer_rect := Rect2(offset, EightBallLogic.TABLE_SIZE * scale_factor)
	var inner_rect := Rect2(_to_screen(EightBallLogic.PLAYFIELD_RECT.position), EightBallLogic.PLAYFIELD_RECT.size * scale_factor)

	draw_rect(outer_rect.grow(10.0 * scale_factor), _WOOD_COLOR, true)
	draw_rect(outer_rect.grow(4.0 * scale_factor), _WOOD_HIGHLIGHT, false, 14.0 * scale_factor)
	draw_rect(outer_rect, _RAIL_COLOR, true)
	draw_rect(inner_rect, _FELT_COLOR, true)
	draw_rect(inner_rect.grow(-12.0 * scale_factor), _FELT_GLOW, false, 3.0 * scale_factor)

	for pocket_position in EightBallLogic.POCKET_POSITIONS:
		draw_circle(_to_screen(pocket_position), EightBallLogic.POCKET_RADIUS * scale_factor, _POCKET_COLOR)

	_draw_diamonds(inner_rect, scale_factor)

	for ball in _display_balls:
		if bool(ball.get("pocketed", false)):
			continue
		_draw_ball(ball, scale_factor)

	if _interactive and _has_cue_ball():
		_draw_cue_preview(scale_factor)


func _draw_diamonds(inner_rect: Rect2, scale_factor: float) -> void:
	var diamond_color := Color(0.92, 0.85, 0.64, 0.85)
	for i in range(1, 4):
		var x := lerpf(inner_rect.position.x, inner_rect.end.x, float(i) / 4.0)
		draw_circle(Vector2(x, inner_rect.position.y - 22.0 * scale_factor), 3.0 * scale_factor, diamond_color)
		draw_circle(Vector2(x, inner_rect.end.y + 22.0 * scale_factor), 3.0 * scale_factor, diamond_color)
	for i in range(1, 3):
		var y := lerpf(inner_rect.position.y, inner_rect.end.y, float(i) / 3.0)
		draw_circle(Vector2(inner_rect.position.x - 22.0 * scale_factor, y), 3.0 * scale_factor, diamond_color)
		draw_circle(Vector2(inner_rect.end.x + 22.0 * scale_factor, y), 3.0 * scale_factor, diamond_color)


func _draw_ball(ball: Dictionary, scale_factor: float) -> void:
	var ball_id := int(ball.get("id", -1))
	var center := _to_screen(Vector2(ball.get("pos", Vector2.ZERO)))
	var radius := EightBallLogic.BALL_RADIUS * scale_factor
	var color := EightBallLogic.ball_color(ball_id)
	draw_circle(center + Vector2(radius * 0.16, radius * 0.2), radius * 0.98, Color(0.0, 0.0, 0.0, 0.18))

	if EightBallLogic.is_stripe(ball_id):
		draw_circle(center, radius, Color(0.98, 0.98, 0.96))
		var stripe_rect := Rect2(center - Vector2(radius * 0.95, radius * 0.44), Vector2(radius * 1.9, radius * 0.88))
		draw_rect(stripe_rect, color, true)
	else:
		draw_circle(center, radius, color)

	draw_arc(center, radius, 0.0, TAU, 28, Color(0.0, 0.0, 0.0, 0.28), 1.8 * scale_factor, true)
	draw_circle(center + Vector2(-radius * 0.22, -radius * 0.26), radius * 0.28, Color(1.0, 1.0, 1.0, 0.20))

	if ball_id != 0:
		draw_circle(center, radius * 0.46, Color(0.98, 0.98, 0.95))
		_draw_ball_number(center, radius, str(ball_id), Color(0.08, 0.08, 0.10))


func _draw_ball_number(center: Vector2, radius: float, label: String, color: Color) -> void:
	var font := get_theme_default_font()
	if font == null:
		return
	var font_size: int = max(10, int(radius * 0.82))
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_position: Vector2= center + Vector2(-text_size.x * 0.5, text_size.y * 0.35)
	draw_string(font, text_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_cue_preview(scale_factor: float) -> void:
	var cue_ball := _cue_ball()
	if cue_ball.is_empty():
		return
	var cue_position := Vector2(cue_ball.get("pos", Vector2.ZERO))
	var shot := _shot_vector()
	if shot.length() < 4.0:
		shot = cue_position - _mouse_table_position
	if shot.length() < 4.0:
		return

	var direction := shot.normalized()
	var power := clampf(shot.length() / 190.0, 0.0, 1.0)
	var screen_cue := _to_screen(cue_position)
	var guide_end := _to_screen(cue_position + direction * (170.0 + 140.0 * power))
	draw_dashed_line(screen_cue, guide_end, Color(1.0, 1.0, 1.0, 0.45), 3.0 * scale_factor, 12.0 * scale_factor)

	var back_pull := 24.0 + shot.length() * 0.45
	var stick_start := _to_screen(cue_position - direction * back_pull)
	var stick_end := _to_screen(cue_position - direction * (160.0 + back_pull))
	draw_line(stick_start, stick_end, Color(0.86, 0.72, 0.47), 8.0 * scale_factor, true)
	draw_line(stick_start, stick_end, Color(0.38, 0.20, 0.08, 0.55), 2.0 * scale_factor, true)
	draw_circle(screen_cue, EightBallLogic.BALL_RADIUS * scale_factor * 0.35, Color(1.0, 1.0, 1.0, 0.22))


func _cue_ball() -> Dictionary:
	for ball in _display_balls:
		if int(ball.get("id", -1)) == 0 and not bool(ball.get("pocketed", false)):
			return ball
	return {}


func _has_cue_ball() -> bool:
	return not _cue_ball().is_empty()


func _shot_vector() -> Vector2:
	var cue_ball := _cue_ball()
	if cue_ball.is_empty():
		return Vector2.ZERO
	return Vector2(cue_ball.get("pos", Vector2.ZERO)) - _mouse_table_position


func _to_screen(table_position: Vector2) -> Vector2:
	return _view_offset() + table_position * _view_scale()


func _to_table_space(local_position: Vector2) -> Vector2:
	return (local_position - _view_offset()) / _view_scale()


func _view_scale() -> float:
	return min(size.x / EightBallLogic.TABLE_SIZE.x, size.y / EightBallLogic.TABLE_SIZE.y)


func _view_offset() -> Vector2:
	return (size - EightBallLogic.TABLE_SIZE * _view_scale()) * 0.5
