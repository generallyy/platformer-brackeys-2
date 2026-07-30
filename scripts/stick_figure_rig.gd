@tool
class_name StickFigureRig
extends Node2D

@export var line_color := Color(0.04, 0.04, 0.04, 1.0)
@export var accent_color := Color(0.1, 0.48, 0.95, 1.0)
@export var line_width := 60

## Editor-only: assign a CosmeticItem here to see it live on the rig in the
## scene editor while tuning its offset/rotation/scale. No effect at runtime.
## Polled every editor frame (see _process) rather than signal-driven, since
## signal connections don't reliably survive scene reloads.
@export_group("Editor Preview")
@export var preview_cosmetic: CosmeticItem

var _preview_state_key: String = ""

var current_animation: StringName = &"idle"
var facing_direction := 1

@onready var _animator: AnimationPlayer = $RigAnimationPlayer
@onready var _scarf: Line2D = $Scarf
@onready var _animation_tree: AnimationTree = $AnimationTree
@onready var _polygons: Node2D = get_node_or_null("Polygons")
@onready var _hat_socket: Node2D = get_node_or_null("Skeleton2D/Torso/Head/HeadCosmetic")


func _ready() -> void:
	_animation_tree.active = true
	play(current_animation)


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var key := _compute_preview_state_key()
	if key != _preview_state_key:
		_preview_state_key = key
		_refresh_preview_cosmetic()


func _compute_preview_state_key() -> String:
	if preview_cosmetic == null:
		return ""
	return "%s|%s|%s|%s" % [
		preview_cosmetic.resource_path,
		preview_cosmetic.offset,
		preview_cosmetic.rotation_degrees,
		preview_cosmetic.item_scale,
	]


func play(animation_name: StringName) -> void:
	current_animation = animation_name
	if _animator == null or not _animator.has_animation(animation_name):
		return
	if _animation_tree != null and _animation_tree.active:
		var state := _animation_tree.get("parameters/BodySM/playback") as AnimationNodeStateMachinePlayback
		if state != null:
			if not state.is_playing() or (animation_name == &"boost dash" and state.get_current_node() == &"jump"):
				state.start(animation_name)
			else:
				state.travel(animation_name)
		return
	if _animator.current_animation != animation_name:
		_animator.play(animation_name)


func play_upper(animation_name: StringName) -> void:
	if _animation_tree == null or not _animation_tree.active:
		return
	_animation_tree.set("parameters/UpperBlend/blend_amount", 1.0)
	var state := _animation_tree.get("parameters/UpperSM/playback") as AnimationNodeStateMachinePlayback
	if state != null:
		state.start(animation_name)


func stop_upper() -> void:
	if _animation_tree == null or not _animation_tree.active:
		return
	_animation_tree.set("parameters/UpperBlend/blend_amount", 0.0)
	var upper_state := _animation_tree.get("parameters/UpperSM/playback") as AnimationNodeStateMachinePlayback
	if upper_state != null:
		upper_state.start(&"idle")
	var body_state := _animation_tree.get("parameters/BodySM/playback") as AnimationNodeStateMachinePlayback
	if body_state != null:
		body_state.travel(current_animation)


func set_facing(direction: int) -> void:
	if direction == 0:
		return
	facing_direction = 1 if direction > 0 else -1
	scale.x = abs(scale.x) * float(facing_direction)


func set_accent_color(color: Color) -> void:
	accent_color = color
	if _scarf != null:
		_configure_line(_scarf, accent_color)
	if _polygons != null:
		_polygons.modulate = color


func _socket_for_slot(slot: StringName) -> Node2D:
	match slot:
		&"hat":
			return _hat_socket
		_:
			return null


func equip_cosmetic(item: CosmeticItem) -> void:
	if item == null:
		return
	var socket := _socket_for_slot(item.slot)
	if socket == null:
		return
	for child in socket.get_children():
		child.queue_free()
	if item.scene == null:
		return
	var instance := item.scene.instantiate() as Node2D
	socket.add_child(instance)
	instance.position = item.offset
	instance.rotation_degrees = item.rotation_degrees
	instance.scale = item.item_scale


func unequip_slot(slot: StringName) -> void:
	var socket := _socket_for_slot(slot)
	if socket == null:
		return
	for child in socket.get_children():
		child.queue_free()


func _refresh_preview_cosmetic() -> void:
	if preview_cosmetic == null:
		if _hat_socket != null:
			for child in _hat_socket.get_children():
				child.queue_free()
		return
	equip_cosmetic(preview_cosmetic)


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
