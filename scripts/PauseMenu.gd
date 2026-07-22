@tool
extends CanvasLayer

const ACTIONS := {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"f": "Boost",
	"projectile": "Projectile",
	"melee": "Melee",
	"shield": "Shield",
	"interact": "Interact / Equip",
	"use_active": "Use Active Powerup",
	"blackjack": "Blackjack",
	"eight_ball": "8-Ball",
	"ui_accept": "Confirm",
	"ui_cancel": "Back / Cancel",
}

const PAGES := [
	{ "title": "Keybinds - Combat", "actions": ["move_left", "move_right", "jump", "f", "projectile", "melee", "shield", "interact", "use_active"] },
	{ "title": "Keybinds - Misc",   "actions": ["blackjack", "eight_ball", "ui_accept", "ui_cancel"] },
]

const SLOTS := 3

var _keybinds_panel: Control
var _action_buttons := {}  # action -> Array of Button, size SLOTS
var _action_rows    := {}  # action -> HBoxContainer
var _bindings       := {}  # action -> Array of InputEvent or null, size SLOTS
var _rebinding_action := ""
var _rebinding_slot   := -1
var _rebinding_button: Button = null
var _allow_left_click := false
var _current_page := 0
var _title_label: Label

# ============================================================
# LOCAL-MULTIPLAYER SIMULTANEOUS KEYBINDS (see LocalBindings autoload)
# ============================================================

const LOCAL_ACTION_LABELS := {
	&"move_left": "Move Left", &"move_right": "Move Right", &"jump": "Jump", &"f": "Boost",
	&"projectile": "Projectile", &"melee": "Melee", &"shield": "Shield",
	&"interact": "Interact", &"use_active": "Use Active", &"ui_cancel": "Exit Spectate",
}

const LOCAL_KEYBINDS_MENU_SCENE = preload("res://scenes/ui/KeybindsMenu.tscn")

var _local_kb_panel: Control
var _local_columns_row: HBoxContainer
var _local_columns: Array = []  # Array[Dictionary] — one per active local-mp player slot
var _local_capture_slot: int = -1
var _local_capture_device: int = -1
var _local_capture_action: StringName = &""

@export var row_template: PackedScene
@export var keybind_button: PackedScene
var keybind_header = preload("res://scenes/ui/KeybindHeader.tscn")


func _ready():
	visible = false

	for button in get_node("PauseMenu/PanelContainer/VBoxContainer").get_children():
		if button is Button:
			button.mouse_entered.connect(func():
				button.grab_focus()
				UiAudio.play_click()
			)
			button.focus_entered.connect(func():
				UiAudio.play_click()
			)

	_init_bindings()
	_build_keybinds_panel()
	_build_local_keybinds_panel()
	_load_keybinds()

	_keybinds_panel.visible = false
	$PauseMenu.visible = true
	
	


# ============================================================
# BINDINGS DATA
# ============================================================

func _init_bindings() -> void:
	for action in ACTIONS:
		var events  := InputMap.action_get_events(action)
		var kb_events   := events.filter(func(e): return e is InputEventKey)
		var ctrl_events := events.filter(func(e): return e is InputEventJoypadButton or e is InputEventJoypadMotion)
		_bindings[action] = [
			kb_events[0]   if kb_events.size()   > 0 else null,
			kb_events[1]   if kb_events.size()   > 1 else null,
			ctrl_events[0] if ctrl_events.size() > 0 else null,
		]

func _apply_bindings(action: String) -> void:
	InputMap.action_erase_events(action)
	for e in _bindings[action]:
		if e != null:
			InputMap.action_add_event(action, e)

# ============================================================
# KEYBINDS UI
# ============================================================

func _build_keybinds_panel() -> void:
	_keybinds_panel = $KeybindsMenu
	_keybinds_panel.visible = false

	var vbox := _keybinds_panel.get_node("PanelContainer/HBoxContainer/VBoxContainer")
	_title_label = vbox.get_node("Title")

	# Column headers
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)
	var header_spacer := Label.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)

	var kb_header := keybind_header.instantiate()
	kb_header.text = "Keyboard"
	kb_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kb_header.custom_minimum_size = Vector2(408, 0)
	header.add_child(kb_header)

	var ctrl_header := keybind_header.instantiate()
	ctrl_header.text = "Controller"
	ctrl_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctrl_header.custom_minimum_size = Vector2(200, 0)
	header.add_child(ctrl_header)

	# Build all action rows (all pages), show/hide via _show_page
	for action in ACTIONS:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		vbox.add_child(hbox)

		var lbl: Label = row_template.instantiate()
		lbl.text = ACTIONS[action]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.custom_minimum_size = Vector2(400, 0)
		hbox.add_child(lbl)

		var btns := []
		for slot in SLOTS:
			var btn := keybind_button.instantiate()
			btn.pressed.connect(_start_rebind.bind(action, slot, btn))
			hbox.add_child(btn)
			btns.append(btn)
		_action_buttons[action] = btns
		_action_rows[action] = hbox

	var lmb_row := HBoxContainer.new()
	lmb_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lmb_row.add_theme_constant_override("separation", 16)
	vbox.add_child(lmb_row)
	var lmb_label := Label.new()
	lmb_label.text = "Allow binding Left Click"
	lmb_label.add_theme_font_size_override("font_size", 24)
	lmb_row.add_child(lmb_label)
	var lmb_check := CheckButton.new()
	lmb_check.add_theme_font_size_override("font_size", 24)
	lmb_check.toggled.connect(func(on: bool): _allow_left_click = on)
	lmb_row.add_child(lmb_check)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	vbox.add_child(spacer)

	var reset := Button.new()
	reset.text = "RESET TO DEFAULTS"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	reset.custom_minimum_size = Vector2(800, 0)
	reset.pressed.connect(_reset_keybinds)
	vbox.add_child(reset)

	var back := Button.new()
	back.text = "BACK"
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(800, 0)
	back.pressed.connect(_close_keybinds)
	vbox.add_child(back)

	_refresh_all_buttons()
	_show_page(0)

func _show_page(page: int) -> void:
	_current_page = page
	var page_actions: Array = PAGES[page]["actions"]
	for action in ACTIONS:
		if action in _action_rows:
			_action_rows[action].visible = action in page_actions
	if _title_label:
		_title_label.text = PAGES[page]["title"]

func _refresh_all_buttons() -> void:
	for action in _action_buttons:
		var btns: Array = _action_buttons[action]
		var slots: Array = _bindings[action]
		for i in SLOTS:
			btns[i].text = _event_display_name(slots[i]) if slots[i] != null else "---"

func _event_display_name(event: InputEvent) -> String:
	if event is InputEventKey:
		return event.as_text_physical_keycode()
	if event is InputEventMouseButton:
		return _mouse_button_name(event.button_index)
	if event is InputEventJoypadButton:
		return _joy_button_name(event.button_index)
	if event is InputEventJoypadMotion:
		return _joy_axis_name(event.axis, event.axis_value)
	return "???"



func _mouse_button_name(index: int) -> String:
	match index:
		MOUSE_BUTTON_LEFT:        return "LMB"
		MOUSE_BUTTON_RIGHT:       return "RMB"
		MOUSE_BUTTON_MIDDLE:      return "MMB"
		MOUSE_BUTTON_WHEEL_UP:    return "Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN:  return "Wheel Down"
		MOUSE_BUTTON_XBUTTON1:    return "Mouse 4"
		MOUSE_BUTTON_XBUTTON2:    return "Mouse 5"
		_:                        return "Mouse %d" % index

func _joy_button_name(index: int) -> String:
	match index:
		0:  return "B"
		1:  return "A"
		2:  return "Y"
		3:  return "X"
		4:  return "Minus"
		5:  return "Home"
		6:  return "Plus"
		7:  return "L3"
		8:  return "R3"
		9:  return "L"
		10: return "R"
		11: return "D-Up"
		12: return "D-Down"
		13: return "D-Left"
		14: return "D-Right"
		_:  return "Btn %d" % index

func _joy_axis_name(axis: int, value: float) -> String:
	match axis:
		0: return "L-Stick ←" if value < 0 else "L-Stick →"
		1: return "L-Stick ↑" if value < 0 else "L-Stick ↓"
		2: return "R-Stick ←" if value < 0 else "R-Stick →"
		3: return "R-Stick ↑" if value < 0 else "R-Stick ↓"
		4: return "ZL"
		5: return "ZR"
		_: return "Axis%d%s" % [axis, "-" if value < 0 else "+"]

func _start_rebind(action: String, slot: int, btn: Button) -> void:
	# Second click on the same slot — clear it
	if _rebinding_action == action and _rebinding_slot == slot:
		_commit_rebind(null)
		return
	# Clicking a different slot while already rebinding — cancel the old one first
	if _rebinding_action != "":
		_cancel_rebind()
	_rebinding_action = action
	_rebinding_slot   = slot
	_rebinding_button = btn
	btn.text = "[ press... ]"

func _close_keybinds() -> void:
	_keybinds_panel.visible = false
	$PauseMenu.visible = true

# ============================================================
# LOCAL-MULTIPLAYER KEYBINDS UI
# ============================================================

func _build_local_keybinds_panel() -> void:
	_local_kb_panel = LOCAL_KEYBINDS_MENU_SCENE.instantiate()
	_local_kb_panel.name = "LocalKeybindsMenu"
	_local_kb_panel.visible = false
	add_child(_local_kb_panel)

	var hbox: HBoxContainer = _local_kb_panel.get_node("PanelContainer/HBoxContainer")
	# Pagination arrows don't apply here — every player's column fits side by side at once.
	hbox.get_node("ArrowLeft").visible = false
	hbox.get_node("ArrowRight").visible = false

	var vbox: VBoxContainer = hbox.get_node("VBoxContainer")
	var title: Label = vbox.get_node("Title")
	title.text = "Keybinds Menu"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD

	_local_columns_row = HBoxContainer.new()
	_local_columns_row.name = "Columns"
	_local_columns_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_local_columns_row.add_theme_constant_override("separation", 40)
	_local_columns_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_local_columns_row)


func _open_local_keybinds() -> void:
	$PauseMenu.visible = false
	_rebuild_local_columns()
	_local_kb_panel.visible = true


func _rebuild_local_columns() -> void:
	for c in _local_columns_row.get_children():
		c.queue_free()
	_local_columns.clear()
	_local_capture_slot = -1
	var n: int = NetworkManager.local_player_count
	for i in n:
		var is_kb := i == NetworkManager.keyboard_slot
		var device := -1 if is_kb else NetworkManager.local_player_devices[i]
		var col := _build_local_column(i, is_kb, device)
		_local_columns_row.add_child(col["panel"])
		_local_columns.append(col)


func _build_local_column(slot: int, is_kb: bool, device: int) -> Dictionary:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.add_theme_constant_override("separation", 8)

	var header: Label = keybind_header.instantiate()
	header.text = "Player %d%s" % [slot + 1, "  (Keyboard)" if is_kb else "  (Gamepad %d)" % device]
	panel.add_child(header)

	var actions: Array = LocalBindings.KB_REBINDABLE_ACTIONS if is_kb else LocalBindings.GAMEPAD_REBINDABLE_ACTIONS
	var name_labels: Array = []
	var bind_buttons: Array = []
	for action in actions:
		var row := HBoxContainer.new()
		panel.add_child(row)

		var name_lbl: Label = row_template.instantiate()
		name_lbl.text = LOCAL_ACTION_LABELS.get(action, str(action))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		name_labels.append(name_lbl)

		var bind_btn: Button = keybind_button.instantiate()
		row.add_child(bind_btn)
		if is_kb:
			bind_btn.pressed.connect(_start_kb_capture.bind(slot, action))
		bind_buttons.append(bind_btn)

	var hint := Label.new()
	hint.text = "Click a row, then press the key" if is_kb else "D-pad: select   A: rebind   B: ready"
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate.a = 0.7
	panel.add_child(hint)

	var ready_btn: Button = keybind_button.instantiate()
	ready_btn.toggle_mode = true
	ready_btn.text = "Not Ready"
	panel.add_child(ready_btn)

	var col := {
		"slot": slot, "is_kb": is_kb, "device": device, "cursor": 0,
		"ready": false, "panel": panel, "header": header,
		"name_labels": name_labels, "row_labels": bind_buttons, "ready_button": ready_btn,
	}
	ready_btn.pressed.connect(_toggle_ready.bind(slot))
	_refresh_local_column(col)
	return col


func _start_kb_capture(slot: int, action: StringName) -> void:
	_local_capture_slot = slot
	_local_capture_device = -1
	_local_capture_action = action
	_refresh_local_columns()


func _toggle_ready(slot: int) -> void:
	for col in _local_columns:
		if col["slot"] == slot:
			col["ready"] = not col["ready"]
			col["ready_button"].text = "Ready ✓" if col["ready"] else "Not Ready"
			col["ready_button"].button_pressed = col["ready"]
			break
	_maybe_auto_close_local_keybinds()


func _maybe_auto_close_local_keybinds() -> void:
	for col in _local_columns:
		if not col["ready"]:
			return
	_local_kb_panel.visible = false
	$PauseMenu.visible = true


## Returns true if the event was consumed (should not reach normal GUI/gameplay input).
func _handle_local_keybinds_input(event: InputEvent) -> bool:
	if event.is_action_pressed("pause"):
		return true  # closing only happens once every column marks itself Ready

	if _local_capture_slot != -1:
		if _local_capture_device == -1:
			if event is InputEventKey and event.pressed and not event.echo:
				LocalBindings.rebind_kb(_local_capture_slot, _local_capture_action, event.physical_keycode)
				_local_capture_slot = -1
				_refresh_local_columns()
				return true
			return event is InputEventKey
		if event is InputEventJoypadButton and event.pressed and event.device == _local_capture_device:
			LocalBindings.rebind_gamepad(_local_capture_slot, _local_capture_action, event.button_index)
			_local_capture_slot = -1
			_refresh_local_columns()
			return true
		return event is InputEventJoypadButton or event is InputEventJoypadMotion

	if event.is_action_pressed("ui_cancel"):
		return true  # a bare Escape (no capture in progress) shouldn't fall through to resume

	if event is InputEventJoypadButton and event.pressed:
		for col in _local_columns:
			if col["is_kb"] or col["device"] != event.device:
				continue
			var actions: Array = LocalBindings.GAMEPAD_REBINDABLE_ACTIONS
			match event.button_index:
				JOY_BUTTON_DPAD_UP:
					col["cursor"] = (col["cursor"] - 1 + actions.size()) % actions.size()
					_refresh_local_column(col)
					return true
				JOY_BUTTON_DPAD_DOWN:
					col["cursor"] = (col["cursor"] + 1) % actions.size()
					_refresh_local_column(col)
					return true
				JOY_BUTTON_A:
					_local_capture_slot = col["slot"]
					_local_capture_device = col["device"]
					_local_capture_action = actions[col["cursor"]]
					_refresh_local_column(col)
					return true
				JOY_BUTTON_B:
					_toggle_ready(col["slot"])
					return true
	return false


func _refresh_local_column(col: Dictionary) -> void:
	var actions: Array = LocalBindings.KB_REBINDABLE_ACTIONS if col["is_kb"] else LocalBindings.GAMEPAD_REBINDABLE_ACTIONS
	for i in actions.size():
		var action: StringName = actions[i]
		var name_lbl: Label = col["name_labels"][i]
		var bind_btn: Button = col["row_labels"][i]
		var capturing: bool = _local_capture_slot == col["slot"] and _local_capture_action == action
		if col["is_kb"]:
			name_lbl.text = LOCAL_ACTION_LABELS.get(action, str(action))
			var binding_key: int = LocalBindings.get_kb_binding(col["slot"], action)
			bind_btn.text = "[ press key... ]" if capturing else (_key_name(binding_key) if binding_key != KEY_NONE else "---")
		else:
			var selected: bool = i == col["cursor"]
			name_lbl.text = "%s%s" % ["> " if selected else "   ", LOCAL_ACTION_LABELS.get(action, str(action))]
			var binding_idx: int = LocalBindings.get_gamepad_binding(col["slot"], action)
			bind_btn.text = "[ press... ]" if capturing else ("---" if binding_idx == JOY_BUTTON_INVALID else _joy_button_name(binding_idx))


func _key_name(keycode: int) -> String:
	return OS.get_keycode_string(keycode)


func _refresh_local_columns() -> void:
	for col in _local_columns:
		_refresh_local_column(col)

# ============================================================
# INPUT — rebind capture
# ============================================================

func _input(event: InputEvent) -> void:
	if _local_kb_panel != null and _local_kb_panel.visible:
		if _handle_local_keybinds_input(event):
			get_viewport().set_input_as_handled()
		return

	# Pause toggle always runs
	if event.is_action_pressed("pause"):
		var blackjack_menu := get_parent().get_node_or_null("BlackjackMenu")
		if blackjack_menu != null and blackjack_menu.visible:
			get_viewport().set_input_as_handled()
			return
		var eight_ball_menu := get_parent().get_node_or_null("EightBallMenu")
		if eight_ball_menu != null and eight_ball_menu.visible:
			get_viewport().set_input_as_handled()
			return
		if visible:
			if _keybinds_panel != null and _keybinds_panel.visible:
				_close_keybinds()
			else:
				resume_game()
		else:
			pause_game()
		get_viewport().set_input_as_handled()
		return

	# ui_cancel closes keybinds or resumes when pause menu is open
	if event.is_action_pressed("ui_cancel") and visible and _rebinding_action == "":
		if _keybinds_panel != null and _keybinds_panel.visible:
			_close_keybinds()
		else:
			resume_game()
		get_viewport().set_input_as_handled()
		return

	# Eat game inputs while paused, but let mouse and UI navigation through
	if visible and _rebinding_action == "":
		if event is InputEventMouse:
			return
		if event.is_action("ui_left") or event.is_action("ui_right") \
				or event.is_action("ui_up") or event.is_action("ui_down") \
				or event.is_action("ui_accept") or event.is_action("ui_cancel"):
			return
		get_viewport().set_input_as_handled()
		return

	# Keybind rebinding
	if _rebinding_action == "":
		return
	if event is InputEventMouseMotion:
		return

	var is_kb_slot := _rebinding_slot < SLOTS - 1

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_cancel_rebind()
			get_viewport().set_input_as_handled()
		elif is_kb_slot:
			_commit_rebind(event)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.pressed and is_kb_slot:
		if event.button_index == MOUSE_BUTTON_LEFT and not _allow_left_click:
			_commit_rebind(null)
		else:
			var e := InputEventMouseButton.new()
			e.button_index = event.button_index
			_commit_rebind(e)
		get_viewport().set_input_as_handled()

	elif not is_kb_slot:
		if event is InputEventJoypadButton and event.pressed:
			_commit_rebind(event)
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadMotion and abs(event.axis_value) >= 0.5:
			var e := InputEventJoypadMotion.new()
			e.device     = event.device
			e.axis       = event.axis
			e.axis_value = sign(event.axis_value)
			_commit_rebind(e)
			get_viewport().set_input_as_handled()

func _commit_rebind(event: InputEvent) -> void:
	_bindings[_rebinding_action][_rebinding_slot] = event
	_apply_bindings(_rebinding_action)
	_save_keybinds()
	_refresh_all_buttons()
	_rebinding_action = ""
	_rebinding_slot   = -1
	_rebinding_button = null

func _cancel_rebind() -> void:
	var e = _bindings[_rebinding_action][_rebinding_slot]
	_rebinding_button.text = _event_display_name(e) if e != null else "---"
	_rebinding_action = ""
	_rebinding_slot   = -1
	_rebinding_button = null

func _reset_keybinds() -> void:
	if _rebinding_action != "":
		_cancel_rebind()
	InputMap.load_from_project_settings()
	_init_bindings()
	for action in ACTIONS:
		_apply_bindings(action)
	DirAccess.remove_absolute("user://keybinds.cfg")
	_refresh_all_buttons()

# ============================================================
# SAVE / LOAD
# ============================================================

func _save_keybinds() -> void:
	var cfg := ConfigFile.new()
	for action in ACTIONS:
		for slot in SLOTS:
			var e = _bindings[action][slot]
			# 1. Create a variable to hold the result
			var save_data = null 
			# 2. Use a standard IF block instead of the one-liner
			if e != null:
				save_data = _serialize_event(e)
				
			# 3. Save the result (ConfigFile handles 'null' perfectly)
			cfg.set_value("keybinds", "%s/%d" % [action, slot], save_data)
	cfg.save("user://keybinds.cfg")

func _load_keybinds() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://keybinds.cfg") != OK:
		return
	for action in ACTIONS:
		for slot in SLOTS:
			var key := "%s/%d" % [action, slot]
			if not cfg.has_section_key("keybinds", key):
				continue
			var data = cfg.get_value("keybinds", key)
			_bindings[action][slot] = _deserialize_event(data) if data != null else null
		_apply_bindings(action)
	_refresh_all_buttons()

func _serialize_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "keycode": event.physical_keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse_button", "button_index": event.button_index}
	if event is InputEventJoypadButton:
		return {"type": "button", "button_index": event.button_index}
	if event is InputEventJoypadMotion:
		return {"type": "motion", "axis": event.axis, "axis_value": event.axis_value}
	return {}

func _deserialize_event(data: Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = data["keycode"] as Key
			return e
		"mouse_button":
			var e := InputEventMouseButton.new()
			e.button_index = data["button_index"] as MouseButton
			return e
		"button":
			var e := InputEventJoypadButton.new()
			e.button_index = data["button_index"] as JoyButton
			return e
		"motion":
			var e := InputEventJoypadMotion.new()
			e.axis       = data["axis"] as JoyAxis
			e.axis_value = data["axis_value"]
			return e
	return null

# ============================================================
# PAUSE / RESUME
# ============================================================

func _get_local_player() -> Node:
	if NetworkManager.is_local_multiplayer:
		var main := get_node("/root/Main")
		return main.spawned_players.get(main._local_peer_id())
	for p in get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p
	return null

func pause_game():
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$PauseMenu/PanelContainer/VBoxContainer/Resume.grab_focus()
	_set_local_players_input_locked(true)

func resume_game():
	visible = false
	_set_local_players_input_locked(false)

## Pausing must freeze every locally-controlled player, not just one — _get_local_player()
## picks a single "UI viewer" player (slot 0 in local-multiplayer), which would otherwise
## leave players 2-4 free to keep moving/fighting while the menu (and especially the
## simultaneous Keybinds screen) is open.
func _set_local_players_input_locked(locked: bool) -> void:
	if NetworkManager.is_local_multiplayer:
		var main := get_node("/root/Main")
		for p in main.spawned_players.values():
			p._input_locked = locked
		return
	var p := _get_local_player()
	if p:
		p._input_locked = locked

func _on_resume_pressed():
	resume_game()

func _on_restart_pressed():
	var main := get_node("/root/Main")
	main.respawn_player_by_id(main._local_peer_id())
	visible = false

func _on_title_pressed():
	get_tree().change_scene_to_file("res://scenes/UI/TitleScreen.tscn")

func _on_keybinds_pressed():
	if NetworkManager.is_local_multiplayer:
		_open_local_keybinds()
		return
	$PauseMenu.visible = false
	_keybinds_panel.visible = true
	_show_page(0)

func _on_quit_pressed():
	get_tree().quit()

func _on_h_slider_value_changed(value):
	if value <= -39:
		AudioServer.set_bus_volume_db(0, -90)
	else:
		AudioServer.set_bus_volume_db(0, value)
		
func _on_arrow_left_pressed() -> void:
	_show_page((_current_page - 1 + PAGES.size()) % PAGES.size())

func _on_arrow_right_pressed() -> void:
	_show_page((_current_page + 1) % PAGES.size())
