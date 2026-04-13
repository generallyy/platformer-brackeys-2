extends Control

const POWERUPS_LIST := [
	{ "id": "extra_hearts", "name": "Extra Hearts", "desc": "+2 max hearts\n(per round)", "is_active": false, "min_place": 0, "max_place": 9999 },
	{ "id": "speed_boost", "name": "Speed Surge", "desc": "Press G: 2× speed\nfor 2.5s (once/round)", "is_active": true, "min_place": 0, "max_place": 9999 },
	{ "id": "jump_boost", "name": "Spring Legs", "desc": "Jump 35% higher\n(stacks)", "is_active": false, "min_place": 0, "max_place": 9999 },
	{ "id": "low_gravity", "name": "Featherweight", "desc": "Half gravity,\nfloat further", "is_active": false, "min_place": 0, "max_place": 9999 },
	{ "id": "knockback_boost", "name": "Knock Out", "desc": "1.6× knockback\non all attacks (stacks)", "is_active": false, "min_place": 0, "max_place": 9999 },
	{ "id": "damage_boost", "name": "Heavy Hitter", "desc": "+1 heart damage\nper attack (stacks)", "is_active": false, "min_place": 0, "max_place": 9999 },
	{ "id": "homer_once", "name": "Seeker", "desc": "Press G: fire Homer\nonce per round", "is_active": true, "min_place": 0, "max_place": 9999 },
]

signal powerup_picked

var _player: Node = null
var _time_left := 0.0
var _is_open := false

@onready var _inner: CenterContainer = $PowerupsMenu
@onready var _options_container: HBoxContainer = $PowerupsMenu/Panel/HBoxContainer
@onready var _time_label: Label = $Time

func _ready() -> void:
	_inner.visible = false
	_time_label.visible = false

func _process(delta: float) -> void:
	if not _is_open:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		close_menu()
		return
	_time_label.text = "Time left: %.0f" % _time_left

func open_for_player(player: Node, placement: int, time_left: float) -> void:
	_player = player
	_time_left = time_left
	_is_open = true
	_rebuild_options(placement)
	_time_label.text = "%.2f" % _time_left
	_inner.visible = true
	_time_label.visible = true

func close_menu() -> void:
	_is_open = false
	_inner.visible = false
	_time_label.visible = false
	_player = null

func _rebuild_options(placement: int) -> void:
	for child in _options_container.get_children():
		child.queue_free()

	var eligible: Array = POWERUPS_LIST.filter(
		func(pw: Dictionary) -> bool:
			return placement >= pw.min_place and placement <= pw.max_place
	)
	eligible.shuffle()
	var chosen: Array = eligible.slice(0, min(3, eligible.size()))

	for pw in chosen:
		_options_container.add_child(_make_card(pw))

func _make_card(pw: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 240)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = pw.name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 32)
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = pw.desc
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 22)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	if pw.is_active:
		var tag_lbl := Label.new()
		tag_lbl.text = "[ Active: G ]"
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_lbl.add_theme_font_size_override("font_size", 18)
		vbox.add_child(tag_lbl)

	# Spacer pushes the button to the same vertical position across all cards
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var btn := Button.new()
	btn.text = "Pick"
	btn.add_theme_font_size_override("font_size", 26)
	btn.pressed.connect(_on_option_pressed.bind(pw.id))
	vbox.add_child(btn)

	return panel

func _on_option_pressed(id: String) -> void:
	if _player != null:
		_player.apply_powerup(id)
	powerup_picked.emit()
	close_menu()
