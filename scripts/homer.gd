extends ProjectileBase

const PARTICLE_COUNT = 50

func _init() -> void:
	WEAPON_NAME = "Homer"
	WEAPON_COOLDOWN = 1.0

func _process(_delta: float) -> void:
	if _origin_captured:
		return
	_origin_captured = true

	var target := global_position + Vector2(direction * 125.0, 0.0)
	# ±30° (PI/6) around the forward direction = PI/3 total spread
	var base_angle := 0.0 if direction == 1 else PI
	for i in PARTICLE_COUNT:
		var angle := base_angle + (float(i) / float(PARTICLE_COUNT - 1) - 0.5) * (2*PI)
		var delay := randf_range(0.0, 0.12)
		var p := HomerParticle.acquire()
		p.direction = direction
		p.thrower_peer_id = thrower_peer_id
		p.owner_node = owner_node
		p.setup(target, angle, delay)
		get_parent().add_child(p)
		p.global_position = global_position

	_despawn()
