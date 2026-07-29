extends CanvasLayer

const COLOR_BUTTON_GROUP := &"wardrobe_color_button"
const PREVIEW_SCALE := 0.35
const PREVIEW_POSITION := Vector2(110, 260)

const COSMETIC_FOLDER := "res://assets/sprites/cosmetics/resources"
const COSMETIC_SLOTS: Array[StringName] = [&"hat"]

@onready var preview_viewport: SubViewport = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/PreviewBox/VBoxContainer/PreviewCenter/PreviewViewportContainer/PreviewViewport
@onready var cosmetic_box: VBoxContainer = $ColorRect/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/CosmeticBox/VBoxContainer

var _player: Player = null
var _preview_rig: Node2D = null

var _cosmetic_catalogs: Dictionary = {}    # slot -> Array[CosmeticItem], index 0 is always "None"
var _cosmetic_index: Dictionary = {}       # slot -> current index into its catalog
var _cosmetic_icon_rects: Dictionary = {}  # slot -> TextureRect
var _cosmetic_name_labels: Dictionary = {} # slot -> Label
var _icon_cache: Dictionary = {}           # resource_path -> Texture2D

func _ready() -> void:
	visible = false
	for button in get_tree().get_nodes_in_group(COLOR_BUTTON_GROUP):
		var color: Color = button.get_theme_stylebox("normal").bg_color
		button.pressed.connect(_on_color_pressed.bind(color))
	for slot in COSMETIC_SLOTS:
		_build_cosmetic_row(slot)

func _build_cosmetic_row(slot: StringName) -> void:
	var catalog: Array[CosmeticItem] = CosmeticItem.load_catalog(COSMETIC_FOLDER, slot)
	catalog.insert(0, null)
	_cosmetic_catalogs[slot] = catalog
	_cosmetic_index[slot] = 0

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var left := Button.new()
	left.text = "<"
	left.pressed.connect(_on_cosmetic_arrow_pressed.bind(slot, -1))
	row.add_child(left)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(75, 75)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon_rect)

	var right := Button.new()
	right.text = ">"
	right.pressed.connect(_on_cosmetic_arrow_pressed.bind(slot, 1))
	row.add_child(right)

	cosmetic_box.add_child(row)

	var name_label := Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cosmetic_box.add_child(name_label)

	_cosmetic_icon_rects[slot] = icon_rect
	_cosmetic_name_labels[slot] = name_label

	_refresh_cosmetic_display(slot)

func _refresh_cosmetic_display(slot: StringName) -> void:
	var catalog: Array = _cosmetic_catalogs[slot]
	var item: CosmeticItem = catalog[_cosmetic_index[slot]]
	var icon_rect: TextureRect = _cosmetic_icon_rects[slot]
	var name_label: Label = _cosmetic_name_labels[slot]
	if item == null:
		icon_rect.texture = null
		name_label.text = "None"
		return
	name_label.text = item.display_name if item.display_name != "" else String(slot).capitalize()
	if not _icon_cache.has(item.resource_path):
		var renderer := CosmeticIconRenderer.new()
		_icon_cache[item.resource_path] = await renderer.capture_icon(item.scene, self)
	icon_rect.texture = _icon_cache[item.resource_path]

func _on_cosmetic_arrow_pressed(slot: StringName, delta: int) -> void:
	var catalog: Array = _cosmetic_catalogs[slot]
	if catalog.is_empty():
		return
	_cosmetic_index[slot] = wrapi(_cosmetic_index[slot] + delta, 0, catalog.size())
	_refresh_cosmetic_display(slot)
	var item: CosmeticItem = catalog[_cosmetic_index[slot]]
	_equip_cosmetic_selection(slot, item)

func _equip_cosmetic_selection(slot: StringName, item: CosmeticItem) -> void:
	var item_path := "" if item == null else item.resource_path
	if _player != null:
		_player.request_cosmetic_change(slot, item_path)
	if _preview_rig == null:
		return
	if item == null:
		_preview_rig.unequip_slot(slot)
	else:
		_preview_rig.equip_cosmetic(item)

func _sync_cosmetic_selections_to_player() -> void:
	if _player == null:
		return
	var equipped: Dictionary = _player.get_equipped_cosmetics()
	for slot in COSMETIC_SLOTS:
		var catalog: Array = _cosmetic_catalogs.get(slot, [])
		var current_path: String = equipped.get(slot, "")
		var index := 0
		for i in range(catalog.size()):
			var candidate: CosmeticItem = catalog[i]
			if candidate != null and candidate.resource_path == current_path:
				index = i
				break
		_cosmetic_index[slot] = index
		_refresh_cosmetic_display(slot)

func open_for_player(player: Node) -> void:
	_player = player
	visible = true
	_spawn_preview_rig()
	_focus_equipped_button()
	_sync_cosmetic_selections_to_player()

func _spawn_preview_rig() -> void:
	if _preview_rig != null:
		_preview_rig.queue_free()
		_preview_rig = null
	if _player == null or _player.stick_rig == null:
		return
	_preview_rig = _player.stick_rig.duplicate() as Node2D
	_preview_rig.position = PREVIEW_POSITION
	_preview_rig.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	preview_viewport.add_child(_preview_rig)
	_preview_rig.play(&"idle")

func close_menu() -> void:
	visible = false
	_player = null
	if _preview_rig != null:
		_preview_rig.queue_free()
		_preview_rig = null

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().get_root().get_node("Main").close_wardrobe()


func _on_color_pressed(color: Color) -> void:
	if _player == null:
		return
	_player.request_accent_color_change(color)
	if _preview_rig != null:
		_preview_rig.set_accent_color(color)

func _on_close_pressed() -> void:
	get_tree().get_root().get_node("Main").close_wardrobe()

func _focus_equipped_button() -> void:
	if _player == null:
		return
	var current: Color = _player.get_accent_color()
	for button in get_tree().get_nodes_in_group(COLOR_BUTTON_GROUP):
		if (button.get_theme_stylebox("normal").bg_color as Color).is_equal_approx(current):
			button.grab_focus()
			return
