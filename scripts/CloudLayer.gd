extends ParallaxLayer

const CLOUD_SPEED = -10

func _process(delta):
	self.motion_offset.x += CLOUD_SPEED * delta
