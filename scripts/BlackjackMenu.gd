extends CanvasLayer

signal close_requested

const SUITS := ["spades", "hearts", "clubs", "diamonds"]
const SUIT_SYMBOLS := {
	"spades": "S",
	"hearts": "H",
	"clubs": "C",
	"diamonds": "D",
}
const SUIT_COLORS := {
	"spades": Color(0.10, 0.13, 0.16),
	"clubs": Color(0.10, 0.13, 0.16),
	"hearts": Color(0.76, 0.16, 0.20),
	"diamonds": Color(0.76, 0.16, 0.20),
}
const RANKS := [
	{"label": "A", "value": 11},
	{"label": "2", "value": 2},
	{"label": "3", "value": 3},
	{"label": "4", "value": 4},
	{"label": "5", "value": 5},
	{"label": "6", "value": 6},
	{"label": "7", "value": 7},
	{"label": "8", "value": 8},
	{"label": "9", "value": 9},
	{"label": "10", "value": 10},
	{"label": "J", "value": 10},
	{"label": "Q", "value": 10},
	{"label": "K", "value": 10},
]

@onready var subtitle_label: Label = $Root/Panel/Content/Header/Subtitle
@onready var dealer_label: Label = $Root/Panel/Content/DealerSection/Header
@onready var dealer_cards: HBoxContainer = $Root/Panel/Content/DealerSection/Cards
@onready var player_label: Label = $Root/Panel/Content/PlayerSection/Header
@onready var player_cards: HBoxContainer = $Root/Panel/Content/PlayerSection/Cards
@onready var status_label: Label = $Root/Panel/Content/Status
@onready var hit_button: Button = $Root/Panel/Content/Controls/Hit
@onready var stand_button: Button = $Root/Panel/Content/Controls/Stand
@onready var deal_button: Button = $Root/Panel/Content/Controls/Deal
@onready var close_button: Button = $Root/Panel/Content/Controls/Close

var _deck: Array[Dictionary] = []
var _player_hand: Array[Dictionary] = []
var _dealer_hand: Array[Dictionary] = []
var _round_over := true


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 3

	hit_button.pressed.connect(_on_hit_pressed)
	stand_button.pressed.connect(_on_stand_pressed)
	deal_button.pressed.connect(_on_deal_pressed)
	close_button.pressed.connect(func(): close_requested.emit())

	_refresh_shortcuts()
	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("blackjack") or event.is_action_pressed("ui_cancel"):
		close_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		if not _round_over and not hit_button.disabled:
			_on_hit_pressed()
		elif _round_over:
			_on_deal_pressed()
		get_viewport().set_input_as_handled()


func open_menu() -> void:
	visible = true
	_refresh_shortcuts()
	if _player_hand.is_empty():
		_start_round()
	else:
		_refresh_ui()
	_focus_primary_button()


func close_menu() -> void:
	visible = false


func _on_hit_pressed() -> void:
	if _round_over:
		return
	_player_hand.append(_draw_card())
	if _hand_value(_player_hand) > 21:
		_finish_round("Bust. Dealer wins.")
	elif _hand_value(_player_hand) == 21:
		_dealer_turn()
	else:
		_refresh_ui()


func _on_stand_pressed() -> void:
	if _round_over:
		return
	_dealer_turn()


func _on_deal_pressed() -> void:
	_start_round()


func _start_round() -> void:
	if _deck.size() < 16:
		_build_deck()

	_player_hand.clear()
	_dealer_hand.clear()
	_round_over = false

	_player_hand.append(_draw_card())
	_dealer_hand.append(_draw_card())
	_player_hand.append(_draw_card())
	_dealer_hand.append(_draw_card())

	var player_blackjack := _is_blackjack(_player_hand)
	var dealer_blackjack := _is_blackjack(_dealer_hand)
	if player_blackjack and dealer_blackjack:
		_finish_round("Push. Both hands hit blackjack.")
	elif player_blackjack:
		_finish_round("Blackjack! You win.")
	elif dealer_blackjack:
		_finish_round("Dealer blackjack. You lose.")
	else:
		_refresh_ui()


func _dealer_turn() -> void:
	while _hand_value(_dealer_hand) < 17:
		_dealer_hand.append(_draw_card())

	var player_total := _hand_value(_player_hand)
	var dealer_total := _hand_value(_dealer_hand)

	if dealer_total > 21:
		_finish_round("Dealer busts. You win.")
	elif dealer_total > player_total:
		_finish_round("Dealer wins with %d." % dealer_total)
	elif dealer_total < player_total:
		_finish_round("You win with %d." % player_total)
	else:
		_finish_round("Push. Both hands are %d." % player_total)


func _finish_round(message: String) -> void:
	_round_over = true
	status_label.text = message
	_refresh_ui()


func _build_deck() -> void:
	_deck.clear()
	for suit in SUITS:
		for rank in RANKS:
			_deck.append({
				"suit": suit,
				"label": rank["label"],
				"value": rank["value"],
			})
	_deck.shuffle()


func _draw_card() -> Dictionary:
	if _deck.is_empty():
		_build_deck()
	return _deck.pop_back()


func _refresh_shortcuts() -> void:
	var toggle_key := InputUtils.get_action_key("blackjack")
	subtitle_label.text = "Press [%s] to open or close the table." % toggle_key
	close_button.text = "Close [%s]" % toggle_key


func _refresh_ui() -> void:
	_rebuild_hand(dealer_cards, _dealer_hand, not _round_over)
	_rebuild_hand(player_cards, _player_hand, false)

	var dealer_text := "Dealer"
	if _dealer_hand.is_empty():
		dealer_text += "  |  --"
	elif _round_over:
		dealer_text += "  |  %d" % _hand_value(_dealer_hand)
	else:
		dealer_text += "  |  %s" % _visible_dealer_value_text()
	dealer_label.text = dealer_text

	var player_text := "Player"
	if _player_hand.is_empty():
		player_text += "  |  --"
	else:
		player_text += "  |  %d" % _hand_value(_player_hand)
	player_label.text = player_text

	if _player_hand.is_empty():
		status_label.text = "Deal a hand to begin."
	elif not _round_over:
		status_label.text = "Hit or stand."

	hit_button.disabled = _round_over
	stand_button.disabled = _round_over
	deal_button.text = "New Hand" if _round_over else "Restart Hand"
	_focus_primary_button()


func _visible_dealer_value_text() -> String:
	if _dealer_hand.is_empty():
		return "--"
	if _dealer_hand.size() == 1:
		return str(_hand_value(_dealer_hand))
	return str(_card_value(_dealer_hand[0])) + "+"


func _rebuild_hand(container: HBoxContainer, hand: Array[Dictionary], hide_hole_card: bool) -> void:
	for child in container.get_children():
		child.queue_free()

	for i in range(hand.size()):
		var hidden := hide_hole_card and i == 1
		container.add_child(_make_card(hand[i], hidden))


func _make_card(card: Dictionary, hidden: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(96, 136)

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.83, 0.70, 0.38)
	style.bg_color = Color(0.10, 0.18, 0.14) if hidden else Color(0.97, 0.95, 0.90)
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	var top := Label.new()
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	top.add_theme_font_size_override("font_size", 24)
	vbox.add_child(top)

	var center := Label.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center.add_theme_font_size_override("font_size", 38)
	vbox.add_child(center)

	var bottom := Label.new()
	bottom.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bottom.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	bottom.add_theme_font_size_override("font_size", 24)
	vbox.add_child(bottom)

	if hidden:
		top.text = "##"
		center.text = "###"
		bottom.text = "##"
		top.modulate = Color(0.82, 0.90, 0.98)
		center.modulate = Color(0.82, 0.90, 0.98)
		bottom.modulate = Color(0.82, 0.90, 0.98)
	else:
		var symbol: String = SUIT_SYMBOLS.get(card.get("suit", "spades"), "?")
		var rank := str(card.get("label", "?"))
		var color: Color = SUIT_COLORS.get(card.get("suit", "spades"), Color.BLACK)
		top.text = "%s%s" % [rank, symbol]
		center.text = symbol
		bottom.text = "%s%s" % [symbol, rank]
		top.modulate = color
		center.modulate = color
		bottom.modulate = color

	return panel


func _hand_value(hand: Array[Dictionary]) -> int:
	var total := 0
	var aces := 0
	for card in hand:
		total += _card_value(card)
		if card.get("label", "") == "A":
			aces += 1

	while total > 21 and aces > 0:
		total -= 10
		aces -= 1

	return total


func _card_value(card: Dictionary) -> int:
	return int(card.get("value", 0))


func _is_blackjack(hand: Array[Dictionary]) -> bool:
	return hand.size() == 2 and _hand_value(hand) == 21


func _focus_primary_button() -> void:
	if not visible:
		return
	if _round_over:
		deal_button.grab_focus()
	else:
		hit_button.grab_focus()
