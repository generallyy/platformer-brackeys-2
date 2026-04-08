extends CanvasLayer

const ANNOUNCEMENT_DURATION := 2.5

var _hearts: Array = []
var _score_row: HBoxContainer
var _announcement_label: Label
var _announcement_timer := 0.0

func _ready() -> void:
	# Hearts (top-left)
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(16, 16)
	add_child(hbox)
	for i in 3:
		var lbl := Label.new()
		lbl.text = "♥"
		lbl.add_theme_font_size_override("font_size", 32)
		_hearts.append(lbl)
		hbox.add_child(lbl)

	# Score row (top-right)
	_score_row = HBoxContainer.new()
	_score_row.anchor_left = 1.0
	_score_row.anchor_right = 1.0
	_score_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_score_row.position = Vector2(-16, 16)
	add_child(_score_row)

	# Announcement label (center)
	_announcement_label = Label.new()
	_announcement_label.set_anchors_preset(Control.PRESET_CENTER)
	_announcement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announcement_label.add_theme_font_size_override("font_size", 48)
	_announcement_label.visible = false
	add_child(_announcement_label)

func _process(delta: float) -> void:
	if _announcement_timer > 0.0:
		_announcement_timer -= delta
		if _announcement_timer <= 0.0:
			_announcement_label.visible = false

func update_hearts(current: int) -> void:
	for i in _hearts.size():
		_hearts[i].text = "♥" if i < current else "♡"

func update_scores(scores: Dictionary, player_numbers: Dictionary = {}) -> void:
	for child in _score_row.get_children():
		child.queue_free()
	for peer_id in scores:
		var display_num: int = player_numbers.get(peer_id, peer_id)
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.text = "  P%d: %d" % [display_num, scores[peer_id]]
		_score_row.add_child(lbl)

func show_announcement(text: String, duration: float = ANNOUNCEMENT_DURATION) -> void:
	_announcement_label.text = text
	_announcement_label.visible = true
	_announcement_timer = duration  # 0.0 = stays until next call
