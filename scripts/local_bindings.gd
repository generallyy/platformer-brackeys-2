extends Node

## Per-slot bindings for local-multiplayer players (slots 0-3). Bypasses the global
## InputMap entirely — even for the session's keyboard slot, if any — because every
## action in project.godot binds gamepad events with device:-1 ("any device"), so
## reading the global Input singleton for ANY local-mp player would let every other
## local player's presses leak into theirs. `device == -1` is the convention (matching
## Player.local_joy_device's default) for "this slot is the keyboard slot".

const ACTIONS: Array[StringName] = [&"jump", &"f", &"projectile", &"melee", &"shield", &"interact", &"use_active", &"ui_cancel", &"move_left", &"move_right"]

const GAMEPAD_REBINDABLE_ACTIONS: Array[StringName] = [&"jump", &"projectile", &"melee", &"interact", &"use_active", &"ui_cancel"]
const KB_REBINDABLE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"jump", &"f", &"projectile", &"melee", &"shield", &"interact", &"use_active", &"ui_cancel"]

const DEFAULT_KB_KEYS := {
	&"jump":        KEY_SPACE,
	&"f":           KEY_F,
	&"projectile":  KEY_Z,
	&"melee":       KEY_X,
	&"shield":      KEY_V,
	&"interact":    KEY_C,
	&"use_active":  KEY_G,
	&"ui_cancel":   KEY_ESCAPE,
	&"move_left":   KEY_A,
	&"move_right":  KEY_D,
}

## Verified empirically against an actual Switch Pro Controller on this machine's
## Godot/SDL joypad driver (the "SDL remaps by Xbox position" assumption did NOT
## hold here — this mapping is from observed physical-button behavior, not theory):
##   physical X -> JOY_BUTTON_B   physical Y -> JOY_BUTTON_A
##   physical A -> JOY_BUTTON_X   physical B -> JOY_BUTTON_Y
const DEFAULT_GAMEPAD_BUTTONS := {
	&"jump":        JOY_BUTTON_B,   # physical X
	&"melee":       JOY_BUTTON_X,   # physical A
	&"projectile":  JOY_BUTTON_Y,   # physical B
	&"interact":    JOY_BUTTON_A,   # physical Y
	&"use_active":  JOY_BUTTON_BACK,
	&"ui_cancel":   JOY_BUTTON_START,
}

const SHIELD_TRIGGER_THRESHOLD := 0.5
const STICK_DEADZONE := 0.25

var _kb_bindings: Dictionary = {}       # slot -> { action: Key }, includes move_left/move_right
var _gamepad_bindings: Dictionary = {}  # slot -> { action: JoyButton }

# slot -> { action: bool } current / previous pressed state, for just-pressed edge detection.
var _pressed_now: Dictionary = {}
var _pressed_prev: Dictionary = {}


func _ready() -> void:
	for slot in 4:
		_kb_bindings[slot] = DEFAULT_KB_KEYS.duplicate()
		_gamepad_bindings[slot] = DEFAULT_GAMEPAD_BUTTONS.duplicate()
		_pressed_now[slot] = {}
		_pressed_prev[slot] = {}
	load_bindings()


## Call once per physics frame per active local-mp slot, before reading is_just_pressed for it.
func update(slot: int, device: int) -> void:
	_pressed_prev[slot] = _pressed_now[slot].duplicate()
	var cur := {}
	for action in ACTIONS:
		cur[action] = _raw_pressed(slot, device, action)
	_pressed_now[slot] = cur


func get_move_axis(slot: int, device: int) -> float:
	if device == -1:
		var l := Input.is_physical_key_pressed(_kb_bindings[slot].get(&"move_left", KEY_NONE))
		var r := Input.is_physical_key_pressed(_kb_bindings[slot].get(&"move_right", KEY_NONE))
		return (1.0 if r else 0.0) - (1.0 if l else 0.0)
	var v := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	if absf(v) >= STICK_DEADZONE:
		return clampf(v, -1.0, 1.0)
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		return -1.0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		return 1.0
	return 0.0


func is_pressed(slot: int, device: int, action: StringName) -> bool:
	return _raw_pressed(slot, device, action)


func is_just_pressed(slot: int, device: int, action: StringName) -> bool:
	return _pressed_now[slot].get(action, false) and not _pressed_prev[slot].get(action, false)


func rebind_gamepad(slot: int, action: StringName, button_index: int) -> void:
	_gamepad_bindings[slot][action] = button_index
	save_bindings()


func rebind_kb(slot: int, action: StringName, keycode: int) -> void:
	_kb_bindings[slot][action] = keycode
	save_bindings()


func get_gamepad_binding(slot: int, action: StringName) -> int:
	return _gamepad_bindings[slot].get(action, JOY_BUTTON_INVALID)


func get_kb_binding(slot: int, action: StringName) -> int:
	return _kb_bindings[slot].get(action, KEY_NONE)


func _raw_pressed(slot: int, device: int, action: StringName) -> bool:
	if action == &"move_left":
		return get_move_axis(slot, device) < -STICK_DEADZONE
	if action == &"move_right":
		return get_move_axis(slot, device) > STICK_DEADZONE
	if device == -1:
		var key: int = _kb_bindings[slot].get(action, KEY_NONE)
		if key == KEY_NONE:
			return false
		return Input.is_physical_key_pressed(key)
	if action == &"shield":
		return Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > SHIELD_TRIGGER_THRESHOLD \
			or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > SHIELD_TRIGGER_THRESHOLD
	if action == &"f":
		return Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER) \
			or Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER)
	var button: int = _gamepad_bindings[slot].get(action, JOY_BUTTON_INVALID)
	if button == JOY_BUTTON_INVALID:
		return false
	return Input.is_joy_button_pressed(device, button)


func save_bindings() -> void:
	var cfg := ConfigFile.new()
	for slot in 4:
		for action in GAMEPAD_REBINDABLE_ACTIONS:
			cfg.set_value("gamepad_slot%d" % slot, str(action), _gamepad_bindings[slot].get(action, JOY_BUTTON_INVALID))
		for action in KB_REBINDABLE_ACTIONS:
			cfg.set_value("kb_slot%d" % slot, str(action), _kb_bindings[slot].get(action, KEY_NONE))
	cfg.save("user://local_keybinds.cfg")


func load_bindings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://local_keybinds.cfg") != OK:
		return
	for slot in 4:
		var gsec := "gamepad_slot%d" % slot
		if cfg.has_section(gsec):
			for action in GAMEPAD_REBINDABLE_ACTIONS:
				var key := str(action)
				if cfg.has_section_key(gsec, key):
					_gamepad_bindings[slot][action] = cfg.get_value(gsec, key)
		var ksec := "kb_slot%d" % slot
		if cfg.has_section(ksec):
			for action in KB_REBINDABLE_ACTIONS:
				var key := str(action)
				if cfg.has_section_key(ksec, key):
					_kb_bindings[slot][action] = cfg.get_value(ksec, key)
