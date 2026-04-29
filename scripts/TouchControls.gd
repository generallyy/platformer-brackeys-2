extends CanvasLayer

var _button_actions: Dictionary = {}  # Button -> {action, held}
var _touch_map: Dictionary = {}       # touch index -> Button

func _ready() -> void:
	var tc := $TouchControls
	_button_actions = {
		tc.get_node("Left"):       {action = "move_left",  held = true},
		tc.get_node("Right"):      {action = "move_right", held = true},
		tc.get_node("Shield"):     {action = "shield",     held = true},
		tc.get_node("Jump"):       {action = "jump",       held = false},
		tc.get_node("Dash"):       {action = "f",          held = false},
		tc.get_node("Projectile"): {action = "attack",     held = false},
		tc.get_node("Melee"):      {action = "melee",      held = false},
		tc.get_node("Powerup"):    {action = "use_active", held = false},
		tc.get_node("Interact"):   {action = "interact",   held = false},
	}
	tc.get_node("Settings").pressed.connect(_on_settings_pressed)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var btn := _button_at(event.position)
			if btn != null:
				_touch_map[event.index] = btn
				_press_button(btn)
				get_viewport().set_input_as_handled()
		else:
			if event.index in _touch_map:
				var btn = _touch_map[event.index]
				if btn != null:
					_release_button(btn)
				_touch_map.erase(event.index)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index in _touch_map:
			var old_btn = _touch_map[event.index]
			var new_btn := _button_at(event.position)
			if new_btn != old_btn:
				if old_btn != null:
					_release_button(old_btn)
				_touch_map[event.index] = new_btn
				if new_btn != null:
					_press_button(new_btn)
			get_viewport().set_input_as_handled()

func _button_at(pos: Vector2) -> Button:
	for btn in _button_actions:
		if (btn as Button).get_global_rect().has_point(pos):
			return btn
	return null

func _press_button(btn: Button) -> void:
	var info: Dictionary = _button_actions[btn]
	Input.action_press(info.action)
	if not info.held:
		await get_tree().process_frame
		Input.action_release(info.action)

func _release_button(btn: Button) -> void:
	var info: Dictionary = _button_actions[btn]
	if info.held:
		Input.action_release(info.action)

func _on_settings_pressed() -> void:
	var pause_menu := get_parent().get_node_or_null("PauseMenu")
	if pause_menu == null:
		return
	if pause_menu.visible:
		pause_menu.resume_game()
	else:
		pause_menu.pause_game()
