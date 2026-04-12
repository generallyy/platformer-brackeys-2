extends ProjectileBase

const PARTICLE_COUNT = 50

## When true, particles home toward the nearest enemy player instead of a fixed point.
@export var home_to_player: bool = true

func _init() -> void:
	WEAPON_NAME = "Homer"
	WEAPON_COOLDOWN = 1.0

func _find_enemy_players() -> Array:
	var enemies: Array = []
	for p in get_tree().get_nodes_in_group("player"):
		if p.get_multiplayer_authority() == thrower_peer_id:
			continue
		enemies.append(p)
	return enemies

func _process(_delta: float) -> void:
	if _origin_captured:
		return
	_origin_captured = true

	var base_angle := 0.0 if direction == 1 else PI
	var targets: Array = _find_enemy_players() if home_to_player else []

	if targets.is_empty():
		# No homing targets — all particles go to the fixed point ahead
		var fixed := global_position + Vector2(direction * 125.0, 0.0)
		for i in PARTICLE_COUNT:
			var angle := base_angle + (float(i) / float(PARTICLE_COUNT - 1) - 0.5) * (2*PI)
			_spawn_particle(fixed, angle, null)
	else:
		# Split particles evenly across all enemy players
		var per_target: int = PARTICLE_COUNT / targets.size()
		var remainder := PARTICLE_COUNT % targets.size()
		var particle_index := 0
		for t in range(targets.size()):
			var count := per_target + (1 if t < remainder else 0)
			var target_node: Node2D = targets[t]
			var target := target_node.global_position + Vector2(0, -5)
			for i in count:
				var angle := base_angle + (float(particle_index) / float(PARTICLE_COUNT - 1) - 0.5) * (2*PI)
				_spawn_particle(target, angle, target_node)
				particle_index += 1

	_despawn()

func _spawn_particle(target: Vector2, angle: float, target_node: Node2D) -> void:
	var delay := randf_range(0.0, 0.12)
	var p := HomerParticle.acquire()
	p.direction = direction
	p.thrower_peer_id = thrower_peer_id
	p.owner_node = owner_node
	p.setup(target, angle, delay, target_node)
	get_parent().add_child(p)
	p.global_position = global_position
