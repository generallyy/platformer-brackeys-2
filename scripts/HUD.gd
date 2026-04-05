extends CanvasLayer

var _hearts: Array = []

func _ready() -> void:
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(16, 16)
	add_child(hbox)
	for i in 3:
		var lbl := Label.new()
		lbl.text = "♥"
		lbl.add_theme_font_size_override("font_size", 32)
		_hearts.append(lbl)
		hbox.add_child(lbl)

func update_hearts(current: int) -> void:
	for i in _hearts.size():
		_hearts[i].text = "♥" if i < current else "♡"
