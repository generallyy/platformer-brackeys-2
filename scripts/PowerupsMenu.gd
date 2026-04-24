extends Control

const POWERUPS_LIST := [
	{ "id": PowerupIds.EXTRA_HEARTS,    "name": "Extra Hearts", "desc": "+2 max hearts\n(per round)",                  "is_active": false, "min_place": 0, "max_place": 9999 },
	{ "id": PowerupIds.SPEED_BOOST,     "name": "Speed Surge",  "desc": "Press {key}: 2× speed\nfor 2.5s (once/round)",   "is_active": true,  "min_place": 0, "max_place": 9999 },
	{ "id": PowerupIds.JUMP_BOOST,      "name": "Spring Legs",  "desc": "Jump 35% higher",                             "is_active": false, "min_place": 0, "max_place": 9999 },
	{ "id": PowerupIds.LOW_GRAVITY,     "name": "Featherweight","desc": "Half gravity,\nfloat further",                "is_active": false, "min_place": 0, "max_place": 9999 },
	{ "id": PowerupIds.KNOCKBACK_BOOST, "name": "Knock Out",    "desc": "1.6× knockback\non all attacks (stacks)",    "is_active": false, "min_place": 0, "max_place": 9999 },
	{ "id": PowerupIds.DAMAGE_BOOST,    "name": "Heavy Hitter", "desc": "+1 heart damage\nper attack (stacks)",        "is_active": false, "min_place": 0, "max_place": 9999 },
	{ "id": PowerupIds.HOMER_ONCE,      "name": "Seeker",       "desc": "Press {key}: fire Homer\nonce per round",         "is_active": true,  "min_place": 0, "max_place": 9999 },
]

signal powerup_picked

var _player: Node = null
var _time_left := 0.0
var _is_open := false
var _pick_buttons: Array[Button] = []

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
	_player.set_ui_locked(true)
	_time_left = time_left
	_is_open = true
	_rebuild_options(placement)
	_time_label.text = "%.2f" % _time_left
	_inner.visible = true
	_time_label.visible = true
	# Wait one frame for the buttons to enter the tree, then focus the first one
	await get_tree().process_frame
	if _pick_buttons.size() > 0 and get_window().has_focus():
		_pick_buttons[0].grab_focus()

func close_menu() -> void:
	_is_open = false
	_inner.visible = false
	_time_label.visible = false
	if is_instance_valid(_player):
		_player.set_ui_locked(false)
	_player = null

func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("move_left"):
		_shift_focus(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_shift_focus(1)
		get_viewport().set_input_as_handled()

func _shift_focus(dir: int) -> void:
	if _pick_buttons.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var idx := _pick_buttons.find(focused)
	_pick_buttons[wrapi(idx + dir, 0, _pick_buttons.size())].grab_focus()

func _rebuild_options(placement: int) -> void:
	for child in _options_container.get_children():
		child.queue_free()
	_pick_buttons.clear()

	var eligible: Array = POWERUPS_LIST.filter(
		func(pw: Dictionary) -> bool:
			if placement < pw.min_place or placement > pw.max_place:
				return false
			var id: String = pw.id
			if _player != null:
				if id in PowerupIds.ALL_ACTIVE:
					return _player.active_powerup != id or PowerupIds.get_max_stacks(id) > 1
				if _player.passive_powerups.count(id) >= PowerupIds.get_max_stacks(id):
					return false
			return true
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
	desc_lbl.text = pw.desc.replace("{key}", InputUtils.get_action_key("use_active"))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 22)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	if pw.is_active:
		var tag_lbl := Label.new()
		tag_lbl.text = "[ Active: %s ]" % InputUtils.get_action_key("use_active")
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
	_pick_buttons.append(btn)

	return panel

func _on_option_pressed(id: String) -> void:
	if _player != null:
		_player.apply_powerup(id)
	powerup_picked.emit()
	close_menu()
