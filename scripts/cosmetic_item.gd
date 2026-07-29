class_name CosmeticItem
extends Resource

@export var display_name: String = ""
## hat,
@export var slot: StringName = &"":
	set(value):
		slot = value
		emit_changed()
@export var scene: PackedScene:
	set(value):
		scene = value
		emit_changed()
@export var offset: Vector2 = Vector2.ZERO:
	set(value):
		offset = value
		emit_changed()
@export var rotation_degrees: float = 0.0:
	set(value):
		rotation_degrees = value
		emit_changed()
@export var item_scale: Vector2 = Vector2.ONE:
	set(value):
		item_scale = value
		emit_changed()

## Scans a folder for CosmeticItem resources belonging to the given slot.
static func load_catalog(folder: String, slot: StringName) -> Array[CosmeticItem]:
	var items: Array[CosmeticItem] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return items
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var item := load(folder.path_join(file_name)) as CosmeticItem
			if item != null and item.slot == slot:
				items.append(item)
		file_name = dir.get_next()
	dir.list_dir_end()
	return items
