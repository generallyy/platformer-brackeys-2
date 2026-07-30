class_name CosmeticIconRenderer
extends RefCounted

## Renders one frame of a cosmetic item's scene into an offscreen viewport,
## scaled and centered to fit the item's full visual bounds, and returns it
## as a static texture, so items never need a hand-authored icon.
func capture_icon(scene: PackedScene, parent: Node, size: Vector2i = Vector2i(96, 96), padding: float = 0.85) -> Texture2D:
	if scene == null:
		return null
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	parent.add_child(viewport)

	var instance := scene.instantiate() as Node2D
	viewport.add_child(instance)
	_fit_instance_to_view(instance, size, padding)

	await parent.get_tree().process_frame
	await parent.get_tree().process_frame
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return ImageTexture.create_from_image(image)


func _fit_instance_to_view(instance: Node2D, size: Vector2i, padding: float) -> void:
	var bounds := _compute_bounds(instance)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return
	var fit_scale: float = minf(size.x / bounds.size.x, size.y / bounds.size.y) * padding
	instance.scale = Vector2(fit_scale, fit_scale)
	instance.position = Vector2(size) / 2.0 - bounds.get_center() * fit_scale


## Bounding rect (in root's local space) of every visual child under root.
func _compute_bounds(root: Node2D) -> Rect2:
	var bounds := Rect2()
	var first := true
	var root_inverse := root.global_transform.affine_inverse()
	for node in _collect_visual_nodes(root):
		var local_rect: Rect2 = node.get_rect()
		var xform: Transform2D = root_inverse * node.global_transform
		var world_rect: Rect2 = xform * local_rect
		if first:
			bounds = world_rect
			first = false
		else:
			bounds = bounds.merge(world_rect)
	return bounds


func _collect_visual_nodes(node: Node) -> Array:
	var found := []
	if node.has_method("get_rect"):
		found.append(node)
	for child in node.get_children():
		found.append_array(_collect_visual_nodes(child))
	return found
