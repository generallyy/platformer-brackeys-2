extends CanvasLayer

const ACTIONS := {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"jump": "Jump",
	"f": "Boost",
	"attack": "Attack",
}

var _keybinds_panel: Control
var _action_buttons := {}
var _rebinding_action := ""
var _rebinding_button: Button = null

func _ready():
	visible = false

	for button in get_node("CenterContainer/PanelContainer/VBoxContainer").get_children():
		if button is Button:
			button.mouse_entered.connect(func():
				button.grab_focus()
				UiAudio.play_click()
			)
			button.focus_entered.connect(func():
				UiAudio.play_click()
			)

	_build_keybinds_panel()
	_load_keybinds()

func _build_keybinds_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.visible = false
	add_child(center)
	_keybinds_panel = center

	var panel := PanelContainer.new()
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "KEYBINDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	for action in ACTIONS:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		vbox.add_child(hbox)

		var lbl := Label.new()
		lbl.text = ACTIONS[action]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(lbl)

		var btn := Button.new()
		btn.text = _get_key_name(action)
		btn.custom_minimum_size = Vector2(140, 0)
		btn.pressed.connect(_start_rebind.bind(action, btn))
		hbox.add_child(btn)
		_action_buttons[action] = btn

	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(_close_keybinds)
	vbox.add_child(back)

func _get_key_name(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return e.as_text_physical_keycode()
	return "???"

func _start_rebind(action: String, btn: Button) -> void:
	_rebinding_action = action
	_rebinding_button = btn
	btn.text = "[ press key ]"

func _close_keybinds() -> void:
	_keybinds_panel.visible = false
	$CenterContainer.visible = true

func _input(event):
	if _rebinding_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE:
				_rebinding_button.text = _get_key_name(_rebinding_action)
			else:
				InputMap.action_erase_events(_rebinding_action)
				InputMap.action_add_event(_rebinding_action, event)
				_rebinding_button.text = _get_key_name(_rebinding_action)
				_save_keybinds()
			_rebinding_action = ""
			_rebinding_button = null
		get_viewport().set_input_as_handled()

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

func _save_keybinds() -> void:
	var cfg := ConfigFile.new()
	for action in ACTIONS:
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				cfg.set_value("keybinds", action, e.physical_keycode)
				break
	cfg.save("user://keybinds.cfg")

func _load_keybinds() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://keybinds.cfg") != OK:
		return
	for action in ACTIONS:
		if cfg.has_section_key("keybinds", action):
			var keycode: int = cfg.get_value("keybinds", action)
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_erase_events(action)
			InputMap.action_add_event(action, event)
	for action in _action_buttons:
		_action_buttons[action].text = _get_key_name(action)

func pause_game():
	get_tree().paused = true
	visible = true
	$CenterContainer/PanelContainer/VBoxContainer/Resume.grab_focus()

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
	get_tree().change_scene_to_file("res://scenes/TitleScreen.tscn")

func _on_keybinds_pressed():
	$CenterContainer.visible = false
	_keybinds_panel.visible = true

func _on_quit_pressed():
	get_tree().quit()

func _on_h_slider_value_changed(value):
	if value <= -39:
		AudioServer.set_bus_volume_db(0, -90)
	else:
		AudioServer.set_bus_volume_db(0, value)
