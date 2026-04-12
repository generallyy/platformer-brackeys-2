extends CanvasLayer

const ANNOUNCEMENT_DURATION := 1

var _score_row: VBoxContainer
var _announcement_label: Label
var _announcement_timer := 0.0
var _time_label: Label
var _game_mode: Node = null

func _ready() -> void:
	$Hearts/Label.text = "♥♥♥"
	_score_row = $Scores
	_announcement_label = $Announcement/PanelContainer/Announce
	$Announcement/PanelContainer.visible = false
	_time_label = $Time/Label
	$Time.visible = false

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


func update_hearts(current: int) -> void:
	var text := ""
	for i in 3:
		text += "♥" if i < current else "♡"
	$Hearts/Label.text = text

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

func show_announcement(text: String, duration: float = ANNOUNCEMENT_DURATION) -> void:
	_announcement_label.text = text
	#_announcement_label.visible = true
	$Announcement/PanelContainer.visible = true
	_announcement_timer = duration
