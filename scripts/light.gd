extends PointLight2D

const MIN_ENERGY = .8
const MAX_ENERGY = 1.0
const FLICKER_SPEED = 2

func _process(_delta):
	var t = Time.get_ticks_msec() / 1000.0
	energy = lerp(MIN_ENERGY, MAX_ENERGY, randf()) * (0.9 + 0.1 * sin(t * FLICKER_SPEED))
