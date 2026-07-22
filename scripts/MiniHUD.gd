extends Control

@onready var _hearts_label: Label = $TopLeft/Hearts
@onready var _powerups_label: Label = $TopLeft/PowerupsLabel
@onready var _nudge_label: Label = $Nudge


func bind_to_player(p: Node) -> void:
	p.health_changed.connect(_on_health_changed)
	p.powerups_changed.connect(_on_powerups_changed)
	p.nudge_changed.connect(_on_nudge_changed)
	_on_health_changed(p.health, p.get_effective_max_health())


func _on_health_changed(current: int, max_health: int) -> void:
	var text := ""
	for i in max_health:
		text += "♥" if i < current else "♡"
	_hearts_label.text = text


func _on_powerups_changed(passive: Dictionary, active: String) -> void:
	var lines: Array[String] = []
	for id in passive:
		var powerup_name := PowerupIds.get_display_name(id)
		lines.append(powerup_name if passive[id] == 1 else "%s x%d" % [powerup_name, passive[id]])
	if active != "":
		lines.append("[%s]" % PowerupIds.get_display_name(active))
	_powerups_label.text = "\n".join(lines)
	_powerups_label.visible = not lines.is_empty()


func _on_nudge_changed(text: String) -> void:
	_nudge_label.text = text
	_nudge_label.visible = not text.is_empty()
