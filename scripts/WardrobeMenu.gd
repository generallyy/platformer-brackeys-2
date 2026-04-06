extends CanvasLayer

const KNIGHT_TEXTURE = preload("res://assets/sprites/knight.png")
var _player: Node = null

@onready var title_label: Label = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Subtitle
@onready var preview_name_label: Label = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewName
@onready var preview_texture: TextureRect = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewCenter/PreviewTexture
@onready var options_container: VBoxContainer = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Options

func _ready() -> void:
	visible = false
	_setup_preview_texture()

func open_for_player(player: Node) -> void:
	_player = player
	title_label.add_theme_font_size_override("font_size", 28)
	subtitle_label.add_theme_font_size_override("font_size", 16)
	_rebuild_options()
	_preview_outfit(_player.get_outfit_id())
	visible = true
	_focus_equipped_button()

func close_menu() -> void:
	visible = false
	_player = null

func _rebuild_options() -> void:
	for child in options_container.get_children():
		options_container.remove_child(child)
		child.queue_free()

	if _player == null:
		return

	var outfits: Array = _player.get_outfit_options()
	var current_outfit: int = _player.get_outfit_id()

	for index in range(outfits.size()):
		var outfit: Dictionary = outfits[index]
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER

		row.add_child(_make_option_preview(outfit))

		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(240, 34)
		button.add_theme_font_size_override("font_size", 18)
		button.set_meta("outfit_id", index)
		button.pressed.connect(_on_outfit_pressed.bind(index))
		button.mouse_entered.connect(_preview_outfit.bind(index))
		button.focus_entered.connect(_preview_outfit.bind(index))
		row.add_child(button)
		options_container.add_child(row)

	_refresh_option_labels(current_outfit)

func _on_outfit_pressed(outfit_id: int) -> void:
	if _player == null:
		return
	_player.request_outfit_change(outfit_id)
	_preview_outfit(outfit_id)
	_refresh_option_labels(outfit_id)

func _on_close_pressed() -> void:
	get_tree().get_root().get_node("Main").close_wardrobe()

func _setup_preview_texture() -> void:
	preview_texture.texture = _build_base_preview_texture()

func _make_option_preview(outfit: Dictionary) -> TextureRect:
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(42, 42)
	var outfit_id: int = _find_outfit_id(outfit)
	if _player != null:
		preview.texture = _player.get_outfit_preview_texture(outfit_id)
	else:
		preview.texture = _build_base_preview_texture()
	return preview

func _preview_outfit(outfit_id: int) -> void:
	if _player == null:
		return
	var outfits: Array = _player.get_outfit_options()
	if outfit_id < 0 or outfit_id >= outfits.size():
		return
	var outfit: Dictionary = outfits[outfit_id]
	preview_name_label.text = outfit["name"]
	preview_texture.texture = _player.get_outfit_preview_texture(outfit_id)

func _refresh_option_labels(current_outfit: int) -> void:
	if _player == null:
		return
	var outfits: Array = _player.get_outfit_options()
	for row in options_container.get_children():
		for child in row.get_children():
			if child is Button:
				var outfit_id: int = int(child.get_meta("outfit_id"))
				var label: String = str(outfits[outfit_id]["name"])
				if outfit_id == current_outfit:
					label += " [equipped]"
				child.text = label

func _focus_equipped_button() -> void:
	if _player == null:
		return
	var current_outfit: int = _player.get_outfit_id()
	for row in options_container.get_children():
		for child in row.get_children():
			if child is Button and int(child.get_meta("outfit_id")) == current_outfit:
				child.grab_focus()
				return

func _build_base_preview_texture() -> Texture2D:
	var atlas := AtlasTexture.new()
	atlas.atlas = KNIGHT_TEXTURE
	atlas.region = Rect2(0, 0, 32, 32)
	return atlas

func _find_outfit_id(outfit: Dictionary) -> int:
	if _player == null:
		return 0
	var outfits: Array = _player.get_outfit_options()
	for index in range(outfits.size()):
		if outfits[index] == outfit:
			return index
	return 0
