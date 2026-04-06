extends AnimatableBody2D

@export var travel_offset: Vector2 = Vector2(80, 0)
@export var cycle_duration: float = 2.0
@export_range(0.0, 1.0, 0.01) var phase_offset: float = 0.0

var _origin: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0

func _ready() -> void:
	_origin = position

func _physics_process(delta: float) -> void:
	if cycle_duration <= 0.0:
		return
	_elapsed += delta
	var phase: float = fposmod(_elapsed / cycle_duration + phase_offset, 1.0)
	var ping_pong: float = 1.0 - abs(phase * 2.0 - 1.0)
	position = _origin + travel_offset * ping_pong
