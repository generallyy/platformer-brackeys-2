extends Control

const CONNECT_TIMEOUT = 10.0

@onready var host_button = $CenterContainer/VBoxContainer/HostButton
@onready var name_input = $CenterContainer/VBoxContainer/NameInput
@onready var address_input = $CenterContainer/VBoxContainer/AddressInput
@onready var join_button = $CenterContainer/VBoxContainer/JoinButton
@onready var status_label = $CenterContainer/VBoxContainer/StatusLabel

var _connect_timer := 0.0

func _ready():
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.server_disconnected.connect(_on_connection_failed)
	set_process(false)
	host_button.grab_focus()

func _on_host_button_pressed():
	UiAudio.play_click()
	NetworkManager.local_name = name_input.text.strip_edges()
	var err = NetworkManager.host_game()
	if err != OK:
		status_label.text = "Failed to host (port %d in use?)" % NetworkManager.DEFAULT_PORT
		return
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_join_button_pressed():
	UiAudio.play_click()
	NetworkManager.local_name = name_input.text.strip_edges()
	var address = address_input.text.strip_edges()
	if address.is_empty():
		status_label.text = "Enter the 5-digit tunnel number."
		return
	if address.is_valid_int():
		address = "%s:%s" % [NetworkManager.PLAYIT_HOST, address]
	var err = NetworkManager.join_game(address)
	if err != OK:
		status_label.text = "Connection error."
		return
	status_label.text = "Connecting..."
	join_button.disabled = true
	_connect_timer = 0.0
	set_process(true)

func _process(delta):
	if not NetworkManager.is_online():
		_fail("Connection lost.")
		return
	match multiplayer.multiplayer_peer.get_connection_status():
		MultiplayerPeer.CONNECTION_CONNECTED:
			set_process(false)
			get_tree().change_scene_to_file("res://scenes/main.tscn")
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			_fail("Disconnected.")
			return
	_connect_timer += delta
	if _connect_timer >= CONNECT_TIMEOUT:
		NetworkManager.close()
		_fail("Timed out. Is the host running and is playit.gg active?")

func _fail(msg: String):
	set_process(false)
	status_label.text = msg
	join_button.disabled = false

func _on_connection_failed():
	NetworkManager.close()
	_fail("Connection failed. Check the number and try again.")

func _on_solo_button_pressed():
	UiAudio.play_click()
	NetworkManager.local_name = name_input.text.strip_edges()
	NetworkManager.play_solo()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back_button_pressed():
	UiAudio.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
