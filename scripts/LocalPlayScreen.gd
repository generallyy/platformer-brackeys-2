extends Control

@onready var kb_check: CheckButton   = $CenterContainer/VBoxContainer/KeyboardCheck
@onready var pads_list: VBoxContainer = $CenterContainer/VBoxContainer/PadsList
@onready var start_button: Button    = $CenterContainer/VBoxContainer/StartButton
@onready var status_label: Label     = $CenterContainer/VBoxContainer/StatusLabel

var _pad_checks: Dictionary = {}  # joypad device index -> CheckButton


func _ready() -> void:
	kb_check.toggled.connect(func(_v): _refresh_status())
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_rebuild_pads_list()


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_rebuild_pads_list()


func _rebuild_pads_list() -> void:
	var previously_checked: Dictionary = {}
	for device in _pad_checks:
		previously_checked[device] = _pad_checks[device].button_pressed
	for c in pads_list.get_children():
		c.queue_free()
	_pad_checks.clear()
	for device in Input.get_connected_joypads():
		var check := CheckButton.new()
		check.text = "Gamepad %d — %s" % [device, Input.get_joy_name(device)]
		check.button_pressed = previously_checked.get(device, true)
		check.toggled.connect(func(_v): _refresh_status())
		pads_list.add_child(check)
		_pad_checks[device] = check
	_refresh_status()


func _selected_joy_devices() -> Array:
	var devices: Array = []
	for device in _pad_checks:
		if _pad_checks[device].button_pressed:
			devices.append(device)
	devices.sort()
	return devices


func _refresh_status() -> void:
	var n := (1 if kb_check.button_pressed else 0) + _selected_joy_devices().size()
	start_button.disabled = n < 1
	status_label.text = "%d player%s selected" % [n, "" if n == 1 else "s"]


func _on_start_button_pressed() -> void:
	UiAudio.play_click()
	var joy_devices := _selected_joy_devices()
	var use_kb := kb_check.button_pressed
	var n := (1 if use_kb else 0) + joy_devices.size()
	if n <= 1:
		NetworkManager.play_solo()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	var kb_slot := 0 if use_kb else -1
	var devices_by_slot: Array[int] = []
	devices_by_slot.resize(n)
	var start_idx := 1 if use_kb else 0
	for i in joy_devices.size():
		devices_by_slot[start_idx + i] = joy_devices[i]
	NetworkManager.play_local_multiplayer(n, kb_slot, devices_by_slot)
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_back_button_pressed() -> void:
	UiAudio.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/LobbyScreen.tscn")
