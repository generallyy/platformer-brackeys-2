extends CanvasLayer

signal close_requested
signal challenge_requested(opponent_peer_id: int)
signal accept_requested
signal decline_requested
signal leave_requested
signal shot_requested(angle: float, power: float)

const _ANIMATION_FRAME_TIME := EightBallLogic.STEP_DELTA * EightBallLogic.SAMPLE_INTERVAL

@onready var subtitle_label: Label = $Root/Panel/Content/Header/Subtitle
@onready var table: Control = $Root/Panel/Content/Body/TableWrap/EightBallTable
@onready var players_label: Label = $Root/Panel/Content/Body/Sidebar/Players
@onready var turn_label: Label = $Root/Panel/Content/Body/Sidebar/Turn
@onready var assignment_label: Label = $Root/Panel/Content/Body/Sidebar/Assignments
@onready var status_label: Label = $Root/Panel/Content/Body/Sidebar/Status
@onready var opponent_select: OptionButton = $Root/Panel/Content/Body/Sidebar/OpponentSelect
@onready var challenge_button: Button = $Root/Panel/Content/Body/Sidebar/PrimaryActions/Challenge
@onready var accept_button: Button = $Root/Panel/Content/Body/Sidebar/PrimaryActions/Accept
@onready var decline_button: Button = $Root/Panel/Content/Body/Sidebar/PrimaryActions/Decline
@onready var leave_button: Button = $Root/Panel/Content/Body/Sidebar/SecondaryActions/Leave
@onready var close_button: Button = $Root/Panel/Content/Body/Sidebar/SecondaryActions/Close
@onready var hint_label: Label = $Root/Panel/Content/Body/Sidebar/Hint

var _session: Dictionary = EightBallLogic.create_idle_session()
var _player_names: Dictionary = {}
var _available_peer_ids: Array = []
var _local_peer_id := 0
var _display_balls: Array = []
var _animation_frames: Array = []
var _animation_frame_index := 0
var _animation_time := 0.0
var _seen_animation_id := 0


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4

	challenge_button.pressed.connect(_on_challenge_pressed)
	accept_button.pressed.connect(func() -> void: accept_requested.emit())
	decline_button.pressed.connect(func() -> void: decline_requested.emit())
	leave_button.pressed.connect(func() -> void: leave_requested.emit())
	close_button.pressed.connect(func() -> void: close_requested.emit())
	table.shot_requested.connect(_on_table_shot_requested)
	opponent_select.item_selected.connect(func(_index: int) -> void: _refresh_ui())

	_display_balls = Array(_session.get("balls", [])).duplicate(true)
	_refresh_shortcuts()
	_refresh_ui()


func _process(delta: float) -> void:
	if _animation_frames.is_empty():
		return
	_animation_time += delta
	while _animation_time >= _ANIMATION_FRAME_TIME and not _animation_frames.is_empty():
		_animation_time -= _ANIMATION_FRAME_TIME
		_animation_frame_index += 1
		if _animation_frame_index >= _animation_frames.size():
			_stop_animation()
			break
		_display_balls = Array(_animation_frames[_animation_frame_index]).duplicate(true)
		_refresh_table()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("eight_ball") or event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()


func open_menu() -> void:
	visible = true
	_refresh_shortcuts()
	_refresh_ui()


func close_menu() -> void:
	visible = false
	_stop_animation()


func apply_state(session: Dictionary, player_names: Dictionary, available_peer_ids: Array, local_peer_id: int) -> void:
	var next_session: Dictionary = session.duplicate(true)
	var next_animation_id := int(next_session.get("animation_id", 0))
	var should_start_animation := visible and next_animation_id != 0 and next_animation_id != _seen_animation_id and not Array(next_session.get("animation_frames", [])).is_empty()

	_session = next_session
	_player_names = player_names.duplicate(true)
	_available_peer_ids = available_peer_ids.duplicate()
	_local_peer_id = local_peer_id

	if should_start_animation:
		_seen_animation_id = next_animation_id
		_start_animation(Array(_session.get("animation_frames", [])))
	else:
		if next_animation_id == 0:
			_seen_animation_id = 0
		_display_balls = Array(_session.get("balls", [])).duplicate(true)
		_stop_animation(false)

	_refresh_ui()


func involved_with_session(peer_id: int) -> bool:
	return EightBallLogic.is_participant(_session, peer_id)


func _refresh_shortcuts() -> void:
	var toggle_key := InputUtils.get_action_key("eight_ball")
	subtitle_label.text = "Press [%s] to open or close the table." % toggle_key
	close_button.text = "Close [%s]" % toggle_key


func _refresh_ui() -> void:
	_rebuild_opponents()

	var phase := String(_session.get("phase", "idle"))
	var challenger_id := int(_session.get("challenger_id", 0))
	var opponent_id := int(_session.get("opponent_id", 0))
	var local_involved := EightBallLogic.is_participant(_session, _local_peer_id)
	var local_is_target := phase == "invite" and opponent_id == _local_peer_id
	var local_is_challenger := phase == "invite" and challenger_id == _local_peer_id
	var current_turn := int(_session.get("current_turn", 0))
	var winner_id := int(_session.get("winner_id", 0))

	players_label.text = _players_text(phase, challenger_id, opponent_id)
	turn_label.text = _turn_text(phase, current_turn, winner_id)
	assignment_label.text = _assignments_text(phase, challenger_id, opponent_id)
	status_label.text = _status_text(phase, challenger_id, opponent_id, winner_id)

	var can_challenge := phase == "idle" and _selected_opponent_id() != 0 and _available_peer_ids.size() > 1
	challenge_button.visible = phase == "idle"
	challenge_button.disabled = not can_challenge

	accept_button.visible = local_is_target
	accept_button.disabled = false

	decline_button.visible = local_is_target
	decline_button.disabled = false

	leave_button.visible = (phase == "invite" and (local_is_challenger or local_is_target)) or ((phase == "active" or phase == "finished") and local_involved)
	leave_button.disabled = false
	if phase == "invite":
		leave_button.text = "Cancel Challenge" if local_is_challenger else "Back Out"
	elif phase == "finished":
		leave_button.text = "Clear Table"
	else:
		leave_button.text = "Leave Match"

	opponent_select.visible = phase == "idle"
	opponent_select.disabled = phase != "idle"

	var can_shoot := visible and phase == "active" and current_turn == _local_peer_id and local_involved and _animation_frames.is_empty()
	hint_label.text = _hint_text(phase, can_shoot)
	_refresh_table(can_shoot)


func _players_text(phase: String, challenger_id: int, opponent_id: int) -> String:
	if phase == "idle":
		return "Players: choose another player or Table AI to start a rack."
	if challenger_id == 0 or opponent_id == 0:
		return "Players: waiting for a full table."
	return "Players: %s vs %s" % [_player_name(challenger_id), _player_name(opponent_id)]


func _turn_text(phase: String, current_turn: int, winner_id: int) -> String:
	if phase == "active":
		return "Turn: %s" % _player_name(current_turn) if current_turn != 0 else "Turn: settling"
	if phase == "finished":
		return "Winner: %s" % _player_name(winner_id) if winner_id != 0 else "Winner: undecided"
	if phase == "invite":
		return "Turn: waiting for challenge response."
	return "Turn: no active rack."


func _assignments_text(phase: String, challenger_id: int, opponent_id: int) -> String:
	if phase != "active" and phase != "finished":
		return "Assignments: open table."
	if challenger_id == 0 or opponent_id == 0:
		return "Assignments: open table."
	var challenger_group := _group_label(EightBallLogic.assignment_for(_session, challenger_id))
	var opponent_group := _group_label(EightBallLogic.assignment_for(_session, opponent_id))
	return "%s: %s    %s: %s" % [_player_name(challenger_id), challenger_group, _player_name(opponent_id), opponent_group]


func _status_text(phase: String, challenger_id: int, opponent_id: int, winner_id: int) -> String:
	var base_message := String(_session.get("message", ""))
	if phase == "invite":
		if opponent_id == _local_peer_id:
			return "%s challenged you to 8-ball.\n%s" % [_player_name(challenger_id), base_message]
		if challenger_id == _local_peer_id:
			return "Waiting for %s to respond.\n%s" % [_player_name(opponent_id), base_message]
		return "%s challenged %s.\n%s" % [_player_name(challenger_id), _player_name(opponent_id), base_message]
	if phase == "finished" and winner_id != 0:
		return "%s wins the rack.\n%s" % [_player_name(winner_id), base_message]
	return base_message


func _hint_text(phase: String, can_shoot: bool) -> String:
	if can_shoot:
		return "Click and drag away from the cue ball to line up the shot, then release to strike."
	if phase == "active":
		return "Watch the table or wait for your turn."
	if phase == "invite":
		return "Invite another player or respond to an incoming challenge."
	return "The current implementation supports one shared rack at a time, including solo play against Table AI."


func _rebuild_opponents() -> void:
	var previous_peer_id := _selected_opponent_id()
	opponent_select.clear()
	opponent_select.add_item("Choose Opponent")
	opponent_select.set_item_metadata(0, 0)
	var selected_index := 0
	var index := 1
	for peer_id in _available_peer_ids:
		if int(peer_id) == _local_peer_id:
			continue
		opponent_select.add_item(_player_name(int(peer_id)))
		opponent_select.set_item_metadata(index, int(peer_id))
		if int(peer_id) == previous_peer_id:
			selected_index = index
		index += 1
	opponent_select.select(selected_index)


func _selected_opponent_id() -> int:
	if opponent_select.item_count == 0:
		return 0
	var index := opponent_select.selected
	if index < 0 or index >= opponent_select.item_count:
		return 0
	return int(opponent_select.get_item_metadata(index))


func _player_name(peer_id: int) -> String:
	if peer_id == 0:
		return "Nobody"
	return String(_player_names.get(peer_id, "P%d" % peer_id))


func _group_label(group_name: String) -> String:
	if group_name.is_empty():
		return "Open"
	return group_name.capitalize()


func _refresh_table(can_shoot: bool = false) -> void:
	table.set_view(_session, _display_balls, can_shoot)


func _start_animation(frames: Array) -> void:
	_animation_frames = frames.duplicate(true)
	_animation_frame_index = 0
	_animation_time = 0.0
	if not _animation_frames.is_empty():
		_display_balls = Array(_animation_frames[0]).duplicate(true)
	_refresh_table()


func _stop_animation(reset_display: bool = true) -> void:
	_animation_frames.clear()
	_animation_frame_index = 0
	_animation_time = 0.0
	if reset_display:
		_display_balls = Array(_session.get("balls", [])).duplicate(true)
	_refresh_table()


func _on_challenge_pressed() -> void:
	var opponent_id := _selected_opponent_id()
	if opponent_id == 0:
		return
	challenge_requested.emit(opponent_id)


func _on_table_shot_requested(angle: float, power: float) -> void:
	if _animation_frames.is_empty():
		shot_requested.emit(angle, power)
