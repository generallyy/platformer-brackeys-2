@tool
class_name StickFigureRig
extends Node2D

@export var line_color := Color(0.04, 0.04, 0.04, 1.0)
@export var accent_color := Color(0, 0.91317093, 0.9169842, 1.0)
@export var line_width := 60

@export_group("Outline")
@export var outline_enabled := true:
	set(v):
		outline_enabled = v
		_rebuild_outline_if_ready()
@export var outline_color := Color(0.04, 0.04, 0.04, 1.0):
	set(v):
		outline_color = v
		_rebuild_outline_if_ready()
## Thickness in on-screen pixels at the standard gameplay view (player base_scale
## 0.05, camera zoom 3). The outline is part of the rig, so wardrobe preview,
## editor viewport, camera zoom, and Grow/Shrink all scale it with the body.
@export var outline_width := 3.0:
	set(v):
		outline_width = v
		_rebuild_outline_if_ready()

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

const _OUTLINE_REFERENCE_ZOOM := 3.0    # gameplay Camera2D zoom in Player.tscn
const _OUTLINE_REFERENCE_SCALE := 0.05  # PlayerStats.base_scale — the canonical in-game rig scale
const _OUTLINE_NODE_PREFIX := "RigOutline"
const _OUTLINE_TRACE_EPSILON := 2.0     # px; simplification of traced silhouettes
const _OUTLINE_SMOOTH_ITERATIONS := 2   # Chaikin corner-cutting passes on each loop
## Fraction of the stroke tucked under the fill, as insurance against a hairline
## gap where the alpha-traced edge sits a hair outside the drawn art. Keep small:
## it is the only part of the stroke that shows through a translucent body.
const _OUTLINE_FILL_OVERLAP := 0.15

## Builds a silhouette outline for the skin. Every part is rigidly weighted to a
## single bone, so instead of skinning we parent a closed Line2D per silhouette
## boundary directly to that bone — it follows every animation for free. The
## boundaries come from tracing the atlas texture's alpha (the polygon quads have
## transparent padding, and the head is a ring with a hole), and each stroke is
## pushed off the edge so it lies essentially entirely OUTSIDE the solid, one
## z-index below the fills — including inside the head's hole rim. Sitting
## outside rather than straddling the edge is what keeps the outline correct
## when the body is translucent (ghost mode, Cloak, Blink): a straddling stroke
## would show its hidden inner half through the faded fill.
## Runs in the editor too (@tool); the generated lines are unowned, so they show
## in the viewport but are never saved into the scene.
func _build_outline() -> void:
	_clear_outline()
	if not outline_enabled or _polygons == null:
		return
	var skeleton := get_node_or_null("Skeleton2D") as Skeleton2D
	if skeleton == null:
		return
	# Screen px at the reference gameplay view -> rig units. Sizing against the
	# fixed reference (not this node's live scale) makes the outline part of the
	# rig: wardrobe preview, editor, camera zoom, and Grow/Shrink scale it with
	# the body, like a real edge.
	var delta := outline_width / (_OUTLINE_REFERENCE_SCALE * _OUTLINE_REFERENCE_ZOOM)
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
		var loops := _outline_loops(src, bitmap_cache, delta)
		for li in loops.size():
			var loop_points: PackedVector2Array = loops[li]
			var line := Line2D.new()
			# Explicit unique name — a duplicate name would get auto-renamed to
			# "@RigOutline...@N", which _free_outline_nodes' prefix check misses.
			line.name = "%s%s_%d" % [_OUTLINE_NODE_PREFIX, src.name, li]
			line.closed = true
			# Spans from delta * _OUTLINE_FILL_OVERLAP inside the traced edge to
			# delta outside it, so exactly `outline_width` px stay visible.
			line.width = delta * (1.0 + _OUTLINE_FILL_OVERLAP)
			line.default_color = outline_color
			line.z_index = _polygons.z_index - 1
			line.antialiased = false
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			var pts := PackedVector2Array()
			for v in loop_points:
				pts.append(to_bone * v)
			line.points = pts
			bone.add_child(line)


## Final outline paths for one part, in the part's local space: every traced
## boundary smoothed, then pushed off the silhouette edge by half a stroke so the
## stroke ends up outside the solid (see _build_outline).
func _outline_loops(src: Polygon2D, bitmap_cache: Dictionary, delta: float) -> Array:
	var push := delta * (0.5 - _OUTLINE_FILL_OVERLAP * 0.5)
	var result: Array = []
	for boundary in _trace_visible_boundaries(src, bitmap_cache):
		var raw: PackedVector2Array = boundary["points"]
		# Bitmap tracing leaves pixel stair-steps that the epsilon pass turns
		# into visible facets on curves; corner-cutting rounds them off. Done
		# before the offset so the parallel curve comes out smooth too.
		var smoothed := _smooth_closed(raw, _OUTLINE_SMOOTH_ITERATIONS)
		# A hole (the head ring's centre) is solid on the *outside*, so its
		# stroke belongs within the hole — push the other way. offset_polygon
		# grows on positive delta regardless of winding.
		var is_hole: bool = boundary["hole"]
		for loop in Geometry2D.offset_polygon(smoothed, -push if is_hole else push, Geometry2D.JOIN_ROUND):
			var loop_points: PackedVector2Array = loop
			if loop_points.size() >= 3:
				result.append(loop_points)
	return result


func _rebuild_outline_if_ready() -> void:
	if is_node_ready():
		_build_outline()


## Outline nodes live scattered under the bones, so cleanup goes by name prefix
## (an instance array would break on rig duplicate(), e.g. the goal marker).
func _clear_outline() -> void:
	var skeleton := get_node_or_null("Skeleton2D")
	if skeleton != null:
		_free_outline_nodes(skeleton)


func _free_outline_nodes(node: Node) -> void:
	for child in node.get_children():
		if child.name.begins_with(_OUTLINE_NODE_PREFIX):
			# Release the name before queue_free: the node lives until end of
			# frame, and a same-frame rebuild must be able to reuse canonical
			# names (an auto-renamed "@RigOutline...@N" would escape this sweep).
			child.name = "_freed_outline"
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
## { "points": PackedVector2Array, "hole": bool } per blob edge — the head ring
## yields two (outer contour + hole rim). Assumes uv coords equal polygon coords
## (true for every part in Player.tscn), so traced atlas-pixel coordinates map
## straight into the part's local space.
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
	_append_clipped(result, bm.opaque_to_polygons(region, _OUTLINE_TRACE_EPSILON), region.position, uv, false)
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
	_append_clipped(result, holes, region.position, uv, true)
	return result


## Offsets traced region-local polygons back into atlas space, clips them against
## the part's quad (so art bleeding in from neighboring atlas glyphs can't produce
## stray outlines), and appends the survivors tagged as outer contours or holes.
static func _append_clipped(result: Array, polygons: Array, region_pos: Vector2i, uv: PackedVector2Array, is_hole: bool) -> void:
	for traced in polygons:
		var absolute := PackedVector2Array()
		for p in traced:
			absolute.append(p + Vector2(region_pos))
		for clipped in Geometry2D.intersect_polygons(absolute, uv):
			var clipped_points: PackedVector2Array = clipped
			if clipped_points.size() >= 3:
				result.append({ "points": clipped_points, "hole": is_hole })


## Chaikin corner cutting for a closed loop: each pass replaces every vertex
## with two points at 1/4 and 3/4 of its outgoing edge, converging on a smooth
## curve. Flat runs stay flat; only corners get rounded.
static func _smooth_closed(points: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var pts := points
	for _i in iterations:
		var out := PackedVector2Array()
		var n := pts.size()
		for j in n:
			var a := pts[j]
			var b := pts[(j + 1) % n]
			out.append(a.lerp(b, 0.25))
			out.append(a.lerp(b, 0.75))
		pts = out
	return pts


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
