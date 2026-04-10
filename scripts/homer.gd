extends ProjectileBase

const PARTICLE_COUNT = 50

## When true, particles home toward the nearest enemy player instead of a fixed point.
@export var home_to_player: bool = true

func _init() -> void:
	WEAPON_NAME = "Homer"
	WEAPON_COOLDOWN = 1.0

func _find_nearest_player() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for p in get_tree().get_nodes_in_group("player"):
		if p.get_multiplayer_authority() == thrower_peer_id:
			continue
		var d := global_position.distance_to(p.global_position)
		if d < best_dist:
			best_dist = d
			best = p
	return best

func _process(_delta: float) -> void:
	if _origin_captured:
		return
	_origin_captured = true

	var target_node: Node2D = _find_nearest_player() if home_to_player else null
	var target := target_node.global_position + Vector2(0, -5) if target_node else global_position + Vector2(direction * 125.0, 0.0)
	# ±30° (PI/6) around the forward direction = PI/3 total spread
	var base_angle := 0.0 if direction == 1 else PI
	for i in PARTICLE_COUNT:
		var angle := base_angle + (float(i) / float(PARTICLE_COUNT - 1) - 0.5) * (2*PI)
		var delay := randf_range(0.0, 0.12)
		var p := HomerParticle.acquire()
		p.direction = direction
		p.thrower_peer_id = thrower_peer_id
		p.owner_node = owner_node
		p.setup(target, angle, delay, target_node)
		get_parent().add_child(p)
		p.global_position = global_position

	_despawn()
