@tool
extends CanvasLayer

const ACTIONS := {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"f": "Boost",
	"attack": "Attack",
	"melee": "Melee",
	"shield": "Shield",
	"interact": "Interact / Equip",
}

const SLOTS := 3

var _keybinds_panel: Control
var _action_buttons := {}  # action -> Array of Button, size SLOTS
var _bindings       := {}  # action -> Array of InputEvent or null, size SLOTS
var _rebinding_action := ""
var _rebinding_slot   := -1
var _rebinding_button: Button = null

@export var row_template: PackedScene
@export var keybind_button: PackedScene

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
	_load_keybinds()
	
	#_keybinds_panel.visible = false
	#$PauseMenu.visible = true
	
	


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

	var vbox := _keybinds_panel.get_node("PanelContainer/VBoxContainer")

	# Column headers
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)
	var header_spacer := Label.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var kb_header := Label.new()
	kb_header.text = "Keyboard"
	kb_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kb_header.custom_minimum_size = Vector2(400, 0)  # two 110px buttons + 8px gap
	header.add_child(kb_header)
	var ctrl_header := Label.new()
	ctrl_header.text = "Controller"
	ctrl_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctrl_header.custom_minimum_size = Vector2(200, 0)
	header.add_child(ctrl_header)

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
			#btn.custom_minimum_size = Vector2(110, 0)
			btn.pressed.connect(_start_rebind.bind(action, slot, btn))
			hbox.add_child(btn)
			btns.append(btn)
		_action_buttons[action] = btns

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

func _refresh_all_buttons() -> void:
	for action in _action_buttons:
		var btns: Array = _action_buttons[action]
		var slots: Array = _bindings[action]
		for i in SLOTS:
			btns[i].text = _event_display_name(slots[i]) if slots[i] != null else "---"

func _event_display_name(event: InputEvent) -> String:
	if event is InputEventKey:
		return event.as_text_physical_keycode()
	if event is InputEventJoypadButton:
		return _joy_button_name(event.button_index)
	if event is InputEventJoypadMotion:
		return _joy_axis_name(event.axis, event.axis_value)
	return "???"

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
# INPUT — rebind capture
# ============================================================

func _input(event: InputEvent) -> void:
	if _rebinding_action == "":
		return

	var is_kb_slot := _rebinding_slot < SLOTS - 1

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			_cancel_rebind()
			get_viewport().set_input_as_handled()
		elif is_kb_slot:
			_commit_rebind(event)
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

func _unhandled_input(event):
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()
	if event.is_action_pressed("submit"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused and focused is Button:
			focused.emit_signal("pressed")
			UiAudio.play_click()

func pause_game():
	get_tree().paused = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$PauseMenu/PanelContainer/VBoxContainer/Resume.grab_focus()

func resume_game():
	visible = false
	get_tree().paused = false

func _on_resume_pressed():
	resume_game()

func _on_restart_pressed():
	get_tree().paused = false
	get_node("/root/Main").respawn_player_by_id(multiplayer.get_unique_id())
	visible = false

func _on_title_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/UI/TitleScreen.tscn")

func _on_keybinds_pressed():
	$PauseMenu.visible = false
	_keybinds_panel.visible = true

func _on_quit_pressed():
	get_tree().quit()

func _on_h_slider_value_changed(value):
	if value <= -39:
		AudioServer.set_bus_volume_db(0, -90)
	else:
		AudioServer.set_bus_volume_db(0, value)
