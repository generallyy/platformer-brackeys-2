class_name CosmeticIconRenderer
extends RefCounted

## Renders one frame of a cosmetic item's scene into an offscreen viewport
## and returns it as a static texture, so items never need a hand-authored icon.
func capture_icon(scene: PackedScene, parent: Node, size: Vector2i = Vector2i(96, 96)) -> Texture2D:
	if scene == null:
		return null
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	parent.add_child(viewport)
	viewport.add_child(scene.instantiate())
	await parent.get_tree().process_frame
	await parent.get_tree().process_frame
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return ImageTexture.create_from_image(image)
