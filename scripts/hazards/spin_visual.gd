extends Node2D

@export var spin_speed: float = 8.0


func _process(delta: float) -> void:
	rotation += spin_speed * delta
