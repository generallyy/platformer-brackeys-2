@tool
class_name StickFigureRig
extends Node2D

@export var line_color := Color(0.04, 0.04, 0.04, 1.0)
@export var accent_color := Color(0, 0.91317093, 0.9169842, 1.0)
@export var line_width := 60

@export_group("Outline")
@export var outline_enabled := true
@export var outline_color := Color(0.04, 0.04, 0.04, 1.0)
## Thickness in on-screen pixels at the gameplay camera's default zoom
## (Camera2D zoom = 3 in Player.tscn). Converted to rig units when built.
@export var outline_width := 3.0

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
	if not Engine.is_editor_hint():
		_build_outline()


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


# ============================================================
# OUTLINE
# ============================================================

const _OUTLINE_REFERENCE_ZOOM := 3.0   # gameplay Camera2D zoom in Player.tscn
const _OUTLINE_NODE_PREFIX := "RigOutline"
const _OUTLINE_TRACE_EPSILON := 2.0    # px; simplification of traced silhouettes

var _outline_retry_pending := false

## Builds a silhouette outline for the skin. Every part is rigidly weighted to a
## single bone, so instead of skinning we parent a closed Line2D per silhouette
## boundary directly to that bone — it follows every animation for free. The
## boundaries come from tracing the atlas texture's alpha (the polygon quads have
## transparent padding, and the head is a ring with a hole), and each line is
## centered on the boundary one z-index below the fills: the fill covers the
## inner half, leaving a crisp outline of half the line width outside the
## silhouette — including inside the head's hole rim.
## Runtime-only — the editor viewport shows the rig without an outline.
func _build_outline() -> void:
	_clear_outline()
	if not outline_enabled or _polygons == null:
		return
	var skeleton := get_node_or_null("Skeleton2D") as Skeleton2D
	if skeleton == null:
		return
	var world_scale := absf(global_scale.x) if is_inside_tree() else 0.0
	if world_scale < 0.0001:
		# Global transform not valid yet — retry once on the next frame.
		if not _outline_retry_pending:
			_outline_retry_pending = true
			_build_outline.call_deferred()
		return
	_outline_retry_pending = false
	# Screen px -> rig units, sized at build time. Later scale changes (facing
	# flips, Grow/Shrink) stretch the outline with the body, like a real edge.
	var delta := outline_width / (world_scale * _OUTLINE_REFERENCE_ZOOM)
	var skel_inv := skeleton.global_transform.affine_inverse()
	var bitmap_cache: Dictionary = {}
	for part in _polygons.get_children():
		var src := part as Polygon2D
		if src == null or src.polygon.size() < 3 or src.texture == null:
			continue
		var bone := _weighted_bone(src, skeleton)
		if bone == null:
			continue
		# Maps a point in the part's local space to the bone's local space such
		# that it lands exactly where skinning would put it (rigid weight-1 bind).
		var to_bone := _rest_in_skeleton(bone, skeleton).affine_inverse() \
				* (skel_inv * src.global_transform)
		var boundaries := _trace_visible_boundaries(src, bitmap_cache)
		for bi in boundaries.size():
			var boundary: PackedVector2Array = boundaries[bi]
			var line := Line2D.new()
			# Explicit unique name — a duplicate name would get auto-renamed to
			# "@RigOutline...@N", which _free_outline_nodes' prefix check misses.
			line.name = "%s%s_%d" % [_OUTLINE_NODE_PREFIX, src.name, bi]
			line.closed = true
			line.width = delta * 2.0
			line.default_color = outline_color
			line.z_index = _polygons.z_index - 1
			line.antialiased = false
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			var pts := PackedVector2Array()
			for v in boundary:
				pts.append(to_bone * v)
			line.points = pts
			bone.add_child(line)


## Outline nodes live scattered under the bones, so cleanup goes by name prefix
## (an instance array would break on rig duplicate(), e.g. the goal marker).
func _clear_outline() -> void:
	var skeleton := get_node_or_null("Skeleton2D")
	if skeleton != null:
		_free_outline_nodes(skeleton)


func _free_outline_nodes(node: Node) -> void:
	for child in node.get_children():
		if child.name.begins_with(_OUTLINE_NODE_PREFIX):
			child.queue_free()
		else:
			_free_outline_nodes(child)


func _weighted_bone(src: Polygon2D, skeleton: Skeleton2D) -> Bone2D:
	for i in src.get_bone_count():
		for w in src.get_bone_weights(i):
			if w > 0.0:
				return skeleton.get_node_or_null(src.get_bone_path(i)) as Bone2D
	return null


static func _rest_in_skeleton(bone: Bone2D, skeleton: Skeleton2D) -> Transform2D:
	var t := Transform2D.IDENTITY
	var n: Node = bone
	while n != null and n != skeleton:
		var b := n as Bone2D
		if b == null:
			break
		t = b.rest * t
		n = n.get_parent()
	return t


## Traces the opaque silhouette(s) of the part's texture region. Returns one
## closed boundary per blob edge — the head ring yields two (outer + hole rim).
## Assumes uv coords equal polygon coords (true for every part in Player.tscn),
## so traced atlas-pixel coordinates map straight into the part's local space.
func _trace_visible_boundaries(src: Polygon2D, bitmap_cache: Dictionary) -> Array:
	var bm: BitMap = bitmap_cache.get(src.texture)
	if bm == null:
		var img := src.texture.get_image()
		if img == null:
			return []
		bm = BitMap.new()
		bm.create_from_image_alpha(img)
		bitmap_cache[src.texture] = bm
	var uv := src.uv if src.uv.size() >= 3 else src.polygon
	var bounds := Rect2(uv[0], Vector2.ZERO)
	for p in uv:
		bounds = bounds.expand(p)
	var region := Rect2i(bounds.grow(1.0)).intersection(Rect2i(Vector2i.ZERO, bm.get_size()))
	if not region.has_area():
		return []
	var result: Array = []
	_append_clipped(result, bm.opaque_to_polygons(region, _OUTLINE_TRACE_EPSILON), region.position, uv)
	# opaque_to_polygons only returns outer contours. Recover interior holes
	# (e.g. the head ring's center) by tracing the inverted region and keeping
	# the blobs that don't touch the region border (the border blob is just the
	# transparent padding around the part).
	var inverted := BitMap.new()
	inverted.create(region.size)
	for y in region.size.y:
		for x in region.size.x:
			inverted.set_bit(x, y, not bm.get_bit(region.position.x + x, region.position.y + y))
	var holes: Array = []
	for hole in inverted.opaque_to_polygons(Rect2i(Vector2i.ZERO, region.size), _OUTLINE_TRACE_EPSILON):
		if not _touches_border(hole, region.size):
			holes.append(hole)
	_append_clipped(result, holes, region.position, uv)
	return result


## Offsets traced region-local polygons back into atlas space, clips them against
## the part's quad (so art bleeding in from neighboring atlas glyphs can't produce
## stray outlines), and appends the survivors.
static func _append_clipped(result: Array, polygons: Array, region_pos: Vector2i, uv: PackedVector2Array) -> void:
	for traced in polygons:
		var absolute := PackedVector2Array()
		for p in traced:
			absolute.append(p + Vector2(region_pos))
		for clipped in Geometry2D.intersect_polygons(absolute, uv):
			if clipped.size() >= 3:
				result.append(clipped)


static func _touches_border(points: PackedVector2Array, size: Vector2i) -> bool:
	for p in points:
		if p.x <= 1.0 or p.y <= 1.0 or p.x >= size.x - 1.0 or p.y >= size.y - 1.0:
			return true
	return false


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
