extends Area2D

@onready var _bar: TextureProgressBar = $TextureProgressBar

func _ready() -> void:
	add_to_group("shield")
	_bar.step = 0.01
	$CollisionShape2D.disabled = true

func set_active(active: bool) -> void:
	visible = active
	$CollisionShape2D.set_deferred("disabled", not active)

func update_charge(charge: float, max_charge: float) -> void:
	_bar.max_value = max_charge
	_bar.value = charge
