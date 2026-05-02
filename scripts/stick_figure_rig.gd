class_name StickFigureRig
extends Node2D

@export var line_color := Color(0.04, 0.04, 0.04, 1.0)
@export var accent_color := Color(0.1, 0.48, 0.95, 1.0)
@export var line_width := 2.0

var current_animation: StringName = &"idle"
var facing_direction := 1

@onready var _animator: AnimationPlayer = $RigAnimationPlayer
@onready var _scarf: Line2D = $Scarf


func _ready() -> void:
	_apply_line_style()
	play(current_animation)


func play(animation_name: StringName) -> void:
	current_animation = animation_name
	if _animator == null or not _animator.has_animation(animation_name):
		return
	if _animator.current_animation != animation_name:
		_reset_pose_defaults()
		_animator.play(animation_name)


func set_facing(direction: int) -> void:
	if direction == 0:
		return
	facing_direction = 1 if direction > 0 else -1
	scale.x = float(facing_direction)


func set_accent_color(color: Color) -> void:
	accent_color = color
	if _scarf != null:
		_configure_line(_scarf, accent_color)


func _apply_line_style() -> void:
	for line in _collect_lines(self):
		_configure_line(line, accent_color if line == _scarf else line_color)


func _configure_line(line: Line2D, color: Color) -> void:
	line.default_color = color
	line.width = line_width
	line.antialiased = false
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND


func _reset_pose_defaults() -> void:
	var root := get_node_or_null("Root") as Node2D
	if root != null:
		root.position = Vector2.ZERO


func _collect_lines(node: Node) -> Array:
	var lines := []
	for child in node.get_children():
		if child is Line2D:
			lines.append(child)
		lines.append_array(_collect_lines(child))
	return lines
