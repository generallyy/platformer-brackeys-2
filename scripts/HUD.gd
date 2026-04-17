extends CanvasLayer

const ANNOUNCEMENT_DURATION := 1

var _score_row: VBoxContainer
var _announcement_label: Label
var _announcement_timer := 0.0
var _time_label: Label
var _game_mode: Node = null

func _ready() -> void:
	#$Hearts/Label.text = "♥♥♥♥♥"
	_score_row = $Scores
	_announcement_label = $Announcement/PanelContainer/Announce
	$Announcement/PanelContainer.visible = false
	_time_label = $Time/Label
	$Time.visible = false
	$KDA.visible = false
	_powerups_label.visible = false

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
		_time_label.text = "%.2f" % _game_mode._time_remaining
	else:
		$Time.visible = false

func set_game_mode(gm: Node) -> void:
	_game_mode = gm


@onready var _powerups_label: Label = $PowerupsLabel

func update_hearts(current: int, max_health: int = 3) -> void:
	var text := ""
	for i in max_health:
		text += "♥" if i < current else "♡"
	$Hearts/Label.text = text

func update_powerups(passive: Array, active: String) -> void:
	var lines: Array[String] = []
	var counts := {}
	for id in passive:
		counts[id] = counts.get(id, 0) + 1
	for id in counts:
		var powerup_name := _powerup_display_name(id)
		lines.append(powerup_name if counts[id] == 1 else "%s x%d" % [powerup_name, counts[id]])
	if active != "":
		lines.append("[%s]" % _powerup_display_name(active))
	_powerups_label.text = "\n".join(lines)
	_powerups_label.visible = not lines.is_empty()

func _powerup_display_name(id: String) -> String:
	match id:
		PowerupIds.JUMP_BOOST:      return "Jump Boost"
		PowerupIds.DAMAGE_BOOST:    return "Damage Boost"
		PowerupIds.KNOCKBACK_BOOST: return "Knockback Boost"
		PowerupIds.EXTRA_HEARTS:    return "Extra Hearts"
		PowerupIds.LOW_GRAVITY:     return "Low Gravity"
		PowerupIds.SPEED_BOOST:     return "Speed Boost"
		PowerupIds.HOMER_ONCE:      return "Homer"
		_:                          return id

func update_scores(scores: Dictionary, player_numbers: Dictionary = {}, stocks: Dictionary = {}) -> void:
	for child in _score_row.get_children():
		child.queue_free()
	for peer_id in scores:
		var display_num: int = player_numbers.get(peer_id, peer_id)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 24)
		if peer_id in stocks:
			lbl.text = "  P%d: %d  (%d stocks)" % [display_num, scores[peer_id], stocks[peer_id]]
		else:
			lbl.text = "  P%d: %d" % [display_num, scores[peer_id]]
		_score_row.add_child(lbl)

func update_kda(kda_kills: Dictionary, kda_deaths: Dictionary, player_numbers: Dictionary = {}) -> void:
	var vbox := $KDA/VBoxContainer
	for child in vbox.get_children():
		child.queue_free()
	var peers := player_numbers.keys()
	peers.sort_custom(func(a, b): return player_numbers[a] < player_numbers[b])
	for peer_id in peers:
		var display_num: int = player_numbers.get(peer_id, peer_id)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.text = "  P%d  K: %d  D: %d" % [display_num, kda_kills.get(peer_id, 0), kda_deaths.get(peer_id, 0)]
		vbox.add_child(lbl)

func show_announcement(text: String, duration: float = ANNOUNCEMENT_DURATION) -> void:
	_announcement_label.text = text
	#_announcement_label.visible = true
	$Announcement/PanelContainer.visible = true
	_announcement_timer = duration
