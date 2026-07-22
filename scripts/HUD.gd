extends CanvasLayer

const ANNOUNCEMENT_DURATION := 1

var _score_row: VBoxContainer
var _announcement_label: Label
var _announcement_timer := 0.0
var _time_label: Label
var _game_mode: Node = null
var _objective_label: Label
@onready var _powerups_label: Label = $PowerupsLabel
@onready var _nudge_label: Label = $Nudge

func _ready() -> void:
	#$Hearts/Label.text = "♥♥♥"
	_score_row = $Scores
	_announcement_label = $Announcement/PanelContainer/Announce
	$Announcement/PanelContainer.visible = false
	_time_label = $Time/Label
	$Time.visible = false
	$KDA.visible = false
	_powerups_label.visible = false
	_objective_label = $ObjectiveLabel


func set_objective(text: String) -> void:
	_objective_label.text = text
	_objective_label.visible = not text.is_empty()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next") or event.is_action_released("ui_focus_next"):  # Tab
		$KDA.visible = Input.is_action_pressed("ui_focus_next")

func _process(delta: float) -> void:
	if _announcement_timer > 0.0:
		_announcement_timer -= delta
		if _announcement_timer <= 0.0:
			$Announcement/PanelContainer.visible = false

	if _game_mode and _game_mode._round_active:
		$Time.visible = true
		var t: float = _game_mode._time_remaining
		if t > 60.0:
			var mins: int = int(t / 60)
			var secs := int(t) % 60
			var frac := int((t - floor(t)) * 100)
			_time_label.text = "%d:%02d.%02d" % [mins, secs, frac]
		else:
			_time_label.text = "%.2f" % t
	else:
		$Time.visible = false

func set_game_mode(gm: Node) -> void:
	_game_mode = gm


func set_nudge(text: String) -> void:
	_nudge_label.text    = text
	_nudge_label.visible = not text.is_empty()

## Hides this shared HUD's single-player Hearts/Powerups/Nudge widgets when split-screen
## is active (each local player gets their own via MiniHUD instead). Scores/KDA/Announcement/
## Objective stay visible — they're already multi-peer-aware.
func set_single_player_widgets_visible(v: bool) -> void:
	$Hearts.visible = v
	_powerups_label.visible = v and not _powerups_label.text.is_empty()
	_nudge_label.visible = v and not _nudge_label.text.is_empty()

func update_hearts(current: int, max_health: int = 3) -> void:
	var text := ""
	for i in max_health:
		text += "♥" if i < current else "♡"
	$Hearts/Label.text = text

func update_powerups(passive: Dictionary, active: String) -> void:
	var lines: Array[String] = []
	for id in passive:
		var powerup_name := _powerup_display_name(id)
		lines.append(powerup_name if passive[id] == 1 else "%s x%d" % [powerup_name, passive[id]])
	if active != "":
		lines.append("[%s]" % _powerup_display_name(active))
	_powerups_label.text = "\n".join(lines)
	_powerups_label.visible = not lines.is_empty()

func _powerup_display_name(id: String) -> String:
	return PowerupIds.get_display_name(id)

func update_team_scores(team_scores: Dictionary) -> void:
	for child in _score_row.get_children():
		child.queue_free()
	var names := {1: "Red", 2: "Blue"}
	var colors := {1: Color(1.0, 0.3, 0.3), 2: Color(0.35, 0.6, 1.0)}
	for tid in [1, 2]:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 30)
		lbl.add_theme_color_override("font_color", colors[tid])
		lbl.text = "  %s: %d" % [names[tid], team_scores.get(tid, 0)]
		_score_row.add_child(lbl)

func update_scores(scores: Dictionary, player_numbers: Dictionary = {}, stocks: Dictionary = {}, player_names: Dictionary = {}) -> void:
	for child in _score_row.get_children():
		child.queue_free()
	for peer_id in scores:
		var display_num: int = player_numbers.get(peer_id, peer_id)
		var label: String = player_names.get(peer_id, "P%d" % display_num)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 30)
		if peer_id in stocks:
			lbl.text = "  %s: %d  (%d stocks)" % [label, scores[peer_id], stocks[peer_id]]
		else:
			lbl.text = "  %s: %d" % [label, scores[peer_id]]
		_score_row.add_child(lbl)

func update_kda(kda_kills: Dictionary, kda_deaths: Dictionary, player_numbers: Dictionary = {}, player_names: Dictionary = {}, kda_damage: Dictionary = {}, local_peer_id: int = -1, team_colors: Dictionary = {}, kda_damage_taken: Dictionary = {}) -> void:
	var grid := $KDA/GridContainer
	grid.columns = 6
	for child in grid.get_children():
		child.queue_free()

	# Header row
	for i in 6:
		var header_text: String = ["", "Name", "Kills", "Deaths", "Dmg Dealt", "Dmg Taken"][i]
		var h := Label.new()
		h.add_theme_font_size_override("font_size", 30)
		h.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		if i != 0:
			h.custom_minimum_size.x = 150
		h.text = header_text
		if i == 1:
			h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(h)

	var peers := player_numbers.keys()
	peers.sort_custom(func(a, b): return player_numbers[a] < player_numbers[b])
	for peer_id in peers:
		var display_num: int = player_numbers.get(peer_id, peer_id)
		var name_str: String = player_names.get(peer_id, "P%d" % display_num)
		var is_local: bool = peer_id == local_peer_id
		var color: Color
		if peer_id in team_colors:
			var c: Color = team_colors[peer_id]
			color = c.lightened(0.3) if is_local else c
		elif is_local:
			color = Color(1.0, 0.9, 0.4)
		else:
			color = Color.WHITE
		var prefix := "▶" if is_local else ""
		var cells := [prefix, name_str, str(kda_kills.get(peer_id, 0)), str(kda_deaths.get(peer_id, 0)), str(kda_damage.get(peer_id, 0)), str(kda_damage_taken.get(peer_id, 0))]
		for i in 6:
			var lbl := Label.new()
			lbl.add_theme_font_size_override("font_size", 40)
			lbl.add_theme_color_override("font_color", color)
			if i != 0:
				lbl.custom_minimum_size.x = 150
			else:
				lbl.custom_minimum_size.x = 40
				lbl.add_theme_font_size_override("font_size", 30)
			lbl.text = cells[i]
			if i == 1:
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(lbl)

func show_announcement(text: String, duration: float = ANNOUNCEMENT_DURATION) -> void:
	_announcement_label.text = text
	$Announcement/PanelContainer.visible = true
	_announcement_timer = duration
