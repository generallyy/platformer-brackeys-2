extends CharacterBody2D

const DAGGER_SCENE = preload("res://scenes/weapons/Dagger.tscn")
const MELEE_SCENE  = preload("res://scenes/weapons/MeleeHitbox.tscn")
const SPEED = 200.0
const ACCELERATION = 1400.0
const FRICTION = 2400.0
const TURN_ACCELERATION = 2800.0
const AIR_ACCELERATION = 900.0
const AIR_FRICTION = 1200.0
const AIR_TURN_ACCELERATION = 1800.0
const JUMP_VELOCITY = -300.0
const MAX_FALL_SPEED = 400.0
const MASS = 1.0
const PUSH_RESTITUTION = 0.0  # 0 = sticky, 1 = fully elastic
const MAX_HEALTH = 3
const WEAPON_SPAWN_OFFSET := Vector2(8, -5)
const IFRAMES_BLINK_INTERVAL := 0.2
const IFRAMES_BLINK_THRESHOLD := 0.1
const RESPAWN_DELAY := 0.25 
const CAPE_PRIMARY_SOURCE := Color(210.0 / 255.0, 32.0 / 255.0, 44.0 / 255.0, 1.0)
const CAPE_SECONDARY_SOURCE := Color(235.0 / 255.0, 167.0 / 255.0, 36.0 / 255.0, 1.0)
const CAPE_ACCENT_SOURCE := Color(10.0 / 255.0, 112.0 / 255.0, 48.0 / 255.0, 1.0)
const CAPE_COLOR_TOLERANCE := 0.01
const OUTFITS := [
	{
		"name": "Classic",
		"cape_primary": CAPE_PRIMARY_SOURCE,
		"cape_secondary": CAPE_SECONDARY_SOURCE,
		"cape_accent": CAPE_ACCENT_SOURCE,
	},
	{
		"name": "Frostguard",
		"cape_primary": Color(52.0 / 255.0, 156.0 / 255.0, 1.0, 1.0),
		"cape_secondary": Color(214.0 / 255.0, 245.0 / 255.0, 1.0, 1.0),
		"cape_accent": Color(11.0 / 255.0, 67.0 / 255.0, 143.0 / 255.0, 1.0),
	},
	{
		"name": "Royal",
		"cape_primary": Color(129.0 / 255.0, 45.0 / 255.0, 208.0 / 255.0, 1.0),
		"cape_secondary": Color(1.0, 233.0 / 255.0, 136.0 / 255.0, 1.0),
		"cape_accent": Color(255.0 / 255.0, 97.0 / 255.0, 211.0 / 255.0, 1.0),
	},
	{
		"name": "Ember",
		"cape_primary": Color(1.0, 108.0 / 255.0, 46.0 / 255.0, 1.0),
		"cape_secondary": Color(1.0, 224.0 / 255.0, 85.0 / 255.0, 1.0),
		"cape_accent": Color(168.0 / 255.0, 8.0 / 255.0, 8.0 / 255.0, 1.0),
	},
	{
		"name": "Moss",
		"cape_primary": Color(55.0 / 255.0, 150.0 / 255.0, 74.0 / 255.0, 1.0),
		"cape_secondary": Color(201.0 / 255.0, 1.0, 112.0 / 255.0, 1.0),
		"cape_accent": Color(87.0 / 255.0, 56.0 / 255.0, 28.0 / 255.0, 1.0),
	},
	{
		"name": "Night",
		"cape_primary": Color(48.0 / 255.0, 61.0 / 255.0, 150.0 / 255.0, 1.0),
		"cape_secondary": Color(0.85, 0.93, 1.0, 1.0),
		"cape_accent": Color(0.0, 213.0 / 255.0, 179.0 / 255.0, 1.0),
	},
]

var health := MAX_HEALTH
var outfit_id := 0

signal health_changed(new_health: int)


var _pre_slide_velocity := Vector2.ZERO

var is_boosting = false
var has_air_boosted = false
var boost_timer = 0.0
const BOOST_DURATION = 0.2 # SECONDS
const BOOST_SPEED = 300.0	# constant horizontal speed

var has_dbj = false
var is_dbj = false
var _dbj_boost_lockout := 0.0
const DBJ_SPEED = -350	#double jump
const DBJ_BOOST_LOCKOUT := 0.2

var is_frozen = false
var freeze_timer = 0.0
const FREEZE_DURATION = 0.2 # SECONDS

var is_knocked_back := false
var _knockback_timer := 0.0
const KNOCKBACK_DURATION := 0.35

var _melee_cooldown := 0.0
const MELEE_COOLDOWN := 0.4

# Currently equipped projectile weapon (changed at weapon stations)
var equipped_projectile_scene: PackedScene
var _projectile_cooldown := 0.0
var _equipped_cooldown_max := 0.0
var _equipped_throw_count := 1
var _equipped_max_simultaneous := 1
var _equipped_returns := false
var _active_projectile_count := 0

var is_invuln := false
var _invuln_timer := 0.0
const INVULN_DURATION := 1.0
var _ui_locked := false
var _base_sprite_frames: SpriteFrames
var _outfit_sprite_frames_cache: Dictionary = {}
var _outfit_preview_cache: Dictionary = {}

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var facing_direction = 1 	# right = 1, left = -1
var _sync_peers: Array = []  # only used on server: peers that have this player spawned

func add_sync_peer(peer_id: int) -> void:
	if peer_id not in _sync_peers:
		_sync_peers.append(peer_id)

func remove_sync_peer(peer_id: int) -> void:
	_sync_peers.erase(peer_id)
@onready var animated_sprite = $AnimatedSprite2D
@onready var animation_player = $AnimationPlayer
@onready var audio_stream_player = $AudioStreamPlayer

@onready var dbj_sfx = preload("res://assets/sounds/dbj.wav")
@onready var boost_jump_sfx = preload("res://assets/sounds/boost.wav")
@onready var jump_sfx = preload("res://assets/sounds/my_jump.wav")

func _ready() -> void:
	add_to_group("player")
	_base_sprite_frames = animated_sprite.sprite_frames
	_apply_outfit_visuals(outfit_id)
	equip_weapon(DAGGER_SCENE)

func _physics_process(delta):
	if NetworkManager.is_active() and not is_multiplayer_authority():
		return
	_update_damage_flash(delta)
	if _ui_locked:
		velocity.x = 0.0
		if not is_on_floor() and not is_boosting:
			velocity.y += gravity * delta
		else:
			velocity.y = 0.0
		update_direction(0.0)
		update_animation()
		move_and_slide()
		_send_state_sync()
		return
	

	# tick knockback
	if is_knocked_back:
		_knockback_timer -= delta
		if _knockback_timer <= 0.0:
			is_knocked_back = false

	var direction = 0.0 if is_knocked_back else Input.get_axis("move_left", "move_right")

	# flip sprite or don't flip sprite
	update_direction(direction)
	update_animation()

	_melee_cooldown      = max(0.0, _melee_cooldown - delta)
	_projectile_cooldown = max(0.0, _projectile_cooldown - delta)
	_dbj_boost_lockout   = max(0.0, _dbj_boost_lockout - delta)

	if not is_knocked_back:
		# Handle jump.
		if Input.is_action_just_pressed("jump"):
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
				audio_stream_player.stream = jump_sfx
				audio_stream_player.play()
			elif not has_dbj and not is_boosting:
				start_dbj()

		if Input.is_action_just_pressed("f") and not is_on_floor() and not has_air_boosted and _dbj_boost_lockout <= 0.0:
			start_air_boost()
		var _can_throw := _projectile_cooldown <= 0.0 and (not _equipped_returns or _active_projectile_count < _equipped_max_simultaneous)
		if Input.is_action_just_pressed("attack") and _can_throw:
			_throw_weapon(equipped_projectile_scene, facing_direction)
			if _equipped_returns:
				_active_projectile_count += 1
			_projectile_cooldown = _equipped_cooldown_max
		if Input.is_action_just_pressed("melee") and _melee_cooldown <= 0.0:
			_do_melee()

	# Add the gravity.
	if not is_on_floor() and not is_boosting:
		velocity.y = min(velocity.y + gravity * delta, MAX_FALL_SPEED)

	if not is_knocked_back:
		update_air_boost(delta)
	update_freeze(delta)

	if is_on_floor():
		has_air_boosted = false
		has_dbj = false

	if is_frozen:
		return		# skips movement physics

	# apply movement
	if not is_knocked_back and (is_on_floor() or not is_boosting):
		var fric := FRICTION if is_on_floor() else AIR_FRICTION
		if direction:
			var turning : float = direction * velocity.x < 0.0  # moving opposite to input
			var accel := (TURN_ACCELERATION if is_on_floor() else AIR_TURN_ACCELERATION) if turning else \
						 (ACCELERATION      if is_on_floor() else AIR_ACCELERATION)
			velocity.x = move_toward(velocity.x, direction * SPEED, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, fric * delta)
	
		
	_pre_slide_velocity = velocity
	move_and_slide()
	_resolve_body_collisions()
	_send_state_sync()

@rpc("any_peer", "unreliable_ordered")
func _sync_state(pos: Vector2, flip: bool, anim: String, body_visible: bool, sprite_visible: bool):
	if is_multiplayer_authority():
		return
	global_position = pos
	visible = body_visible
	animated_sprite.visible = sprite_visible
	animated_sprite.flip_h = flip
	if animated_sprite.animation != anim:
		animated_sprite.play(anim)

func _update_damage_flash(delta: float) -> void:
	if not is_invuln:
		animated_sprite.visible = true
		return
	_invuln_timer -= delta
	animated_sprite.visible = fmod(_invuln_timer, IFRAMES_BLINK_INTERVAL) > IFRAMES_BLINK_THRESHOLD
	if _invuln_timer <= 0.0:
		is_invuln = false
		animated_sprite.visible = true

func _send_state_sync() -> void:
	if not NetworkManager.is_active():
		return
	if multiplayer.is_server():
		for pid in _sync_peers:
			_sync_state.rpc_id(pid, global_position, animated_sprite.flip_h, animated_sprite.animation, visible, animated_sprite.visible)
	else:
		_sync_state.rpc_id(1, global_position, animated_sprite.flip_h, animated_sprite.animation, visible, animated_sprite.visible)

func update_direction(direction: float):
	if direction != 0:
		facing_direction = sign(direction)
	animated_sprite.flip_h = (facing_direction == - 1)
	
func update_animation():
	if is_on_floor():
		if abs(velocity.x) < 1:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	elif not is_dbj:
		animated_sprite.play("jump")

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if NetworkManager.is_active() and not is_multiplayer_authority():
		return
	if is_invuln:
		return
	health -= amount
	health_changed.emit(health)
	if health <= 0:
		die()
		return
	if knockback != Vector2.ZERO:
		velocity = knockback
		is_knocked_back = true
		_knockback_timer = KNOCKBACK_DURATION
	is_invuln = true
	_invuln_timer = INVULN_DURATION

func _apply_outfit_visuals(new_outfit_id: int) -> void:
	var clamped_id := clampi(new_outfit_id, 0, OUTFITS.size() - 1)
	outfit_id = clamped_id
	if _base_sprite_frames == null:
		return
	var current_animation: StringName = animated_sprite.animation
	var current_frame: int = animated_sprite.frame
	var current_progress: float = animated_sprite.frame_progress
	animated_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
	animated_sprite.material = null
	animated_sprite.sprite_frames = _get_outfit_sprite_frames(clamped_id)
	if animated_sprite.sprite_frames.has_animation(current_animation):
		animated_sprite.play(current_animation)
		animated_sprite.frame = min(current_frame, animated_sprite.sprite_frames.get_frame_count(current_animation) - 1)
		animated_sprite.frame_progress = current_progress

func get_outfit_preview_texture(outfit_index: int) -> Texture2D:
	var clamped_id := clampi(outfit_index, 0, OUTFITS.size() - 1)
	if clamped_id not in _outfit_preview_cache:
		_outfit_preview_cache[clamped_id] = _recolor_texture(_base_sprite_frames.get_frame_texture(&"idle", 0), OUTFITS[clamped_id])
	return _outfit_preview_cache[clamped_id]

func _get_outfit_sprite_frames(outfit_index: int) -> SpriteFrames:
	if outfit_index not in _outfit_sprite_frames_cache:
		_outfit_sprite_frames_cache[outfit_index] = _build_outfit_sprite_frames(outfit_index)
	return _outfit_sprite_frames_cache[outfit_index]

func _build_outfit_sprite_frames(outfit_index: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	var outfit: Dictionary = OUTFITS[outfit_index]
	for animation_name in _base_sprite_frames.get_animation_names():
		frames.add_animation(animation_name)
		frames.set_animation_loop(animation_name, _base_sprite_frames.get_animation_loop(animation_name))
		frames.set_animation_speed(animation_name, _base_sprite_frames.get_animation_speed(animation_name))
		for frame_idx in range(_base_sprite_frames.get_frame_count(animation_name)):
			frames.add_frame(animation_name, _recolor_texture(_base_sprite_frames.get_frame_texture(animation_name, frame_idx), outfit))
	return frames

func _recolor_texture(texture: Texture2D, outfit: Dictionary) -> Texture2D:
	var image: Image
	if texture is AtlasTexture:
		var atlas_texture: AtlasTexture = texture as AtlasTexture
		var region: Rect2i = Rect2i(atlas_texture.region.position, atlas_texture.region.size)
		image = atlas_texture.atlas.get_image().get_region(region)
	else:
		image = texture.get_image()
	var recolored: Image = image.duplicate()
	for y in range(recolored.get_height()):
		for x in range(recolored.get_width()):
			var pixel: Color = recolored.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			if _is_color_match(pixel, CAPE_PRIMARY_SOURCE):
				recolored.set_pixel(x, y, outfit["cape_primary"])
			elif _is_color_match(pixel, CAPE_SECONDARY_SOURCE):
				recolored.set_pixel(x, y, outfit["cape_secondary"])
			elif _is_color_match(pixel, CAPE_ACCENT_SOURCE):
				recolored.set_pixel(x, y, outfit["cape_accent"])
	return ImageTexture.create_from_image(recolored)

func _is_color_match(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= CAPE_COLOR_TOLERANCE and absf(a.g - b.g) <= CAPE_COLOR_TOLERANCE and absf(a.b - b.b) <= CAPE_COLOR_TOLERANCE

func get_outfit_options() -> Array:
	return OUTFITS

func get_outfit_id() -> int:
	return outfit_id

func request_outfit_change(new_outfit_id: int) -> void:
	var peer_id := multiplayer.get_unique_id() if NetworkManager.is_active() else 1
	get_tree().get_root().get_node("Main").request_player_outfit_change(peer_id, new_outfit_id)

func set_outfit_from_sync(new_outfit_id: int) -> void:
	_apply_outfit_visuals(new_outfit_id)

func set_ui_locked(locked: bool) -> void:
	_ui_locked = locked
	if locked:
		velocity = Vector2.ZERO

func equip_weapon(scene: PackedScene, cooldown: float = 0.0) -> void:
	if scene == null:
		push_error("%s tried to equip a null weapon scene" % name)
		return
	equipped_projectile_scene = scene
	_equipped_cooldown_max = cooldown
	_projectile_cooldown = 0.0
	_active_projectile_count = 0
	var temp := scene.instantiate()
	_equipped_throw_count = temp.THROW_COUNT
	_equipped_max_simultaneous = temp.MAX_SIMULTANEOUS
	_equipped_returns = temp.RETURNS
	temp.free()

func _throw_weapon(scene: PackedScene, dir: int, extra_offset: Vector2 = Vector2.ZERO) -> void:
	if scene == null:
		push_error("%s tried to throw a null weapon scene" % name)
		return
	var spawn_pos := global_position + WEAPON_SPAWN_OFFSET * Vector2(dir, 1) + extra_offset
	var pid := multiplayer.get_unique_id() if NetworkManager.is_active() else -1
	if NetworkManager.is_active():
		_rpc_throw_weapon.rpc(scene.resource_path, dir, spawn_pos, pid)
	else:
		_do_spawn_weapon(scene, dir, spawn_pos, pid)

@rpc("authority", "call_local", "reliable")
func _rpc_throw_weapon(scene_path: String, dir: int, pos: Vector2, thrower_id: int) -> void:
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		push_error("Failed to load weapon scene: %s" % scene_path)
		return
	_do_spawn_weapon(scene, dir, pos, thrower_id)

func _do_spawn_weapon(scene: PackedScene, dir: int, pos: Vector2, thrower_id: int) -> void:
	if scene == null:
		push_error("%s tried to spawn a null weapon scene" % name)
		return
	var p = scene.instantiate()
	p.direction = dir
	p.scale.x = dir
	p.thrower_peer_id = thrower_id
	if not NetworkManager.is_active():
		p.owner_node = self
	get_parent().add_child(p)
	p.global_position = pos
	if _equipped_returns and (not NetworkManager.is_active() or is_multiplayer_authority()):
		p.tree_exiting.connect(_on_projectile_returned)

func _on_projectile_returned() -> void:
	_active_projectile_count = max(0, _active_projectile_count - 1)
	_projectile_cooldown = _equipped_cooldown_max

func _do_melee() -> void:
	_melee_cooldown = MELEE_COOLDOWN
	var pid := multiplayer.get_unique_id() if NetworkManager.is_active() else -1
	if NetworkManager.is_active():
		_rpc_throw_melee.rpc(facing_direction, pid)
	else:
		_do_spawn_melee(facing_direction, pid)

@rpc("authority", "call_local", "reliable")
func _rpc_throw_melee(dir: int, thrower_id: int) -> void:
	_do_spawn_melee(dir, thrower_id)

func _do_spawn_melee(dir: int, thrower_id: int) -> void:
	var m = MELEE_SCENE.instantiate()
	m.direction = dir
	m.scale.x = dir
	m.thrower_peer_id = thrower_id
	add_child(m)
	m.position = WEAPON_SPAWN_OFFSET * Vector2(dir, 1)

func _resolve_body_collisions() -> void:
	if NetworkManager.is_active() and not multiplayer.is_server():
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var other := col.get_collider()
		if not (other is CharacterBody2D and other.is_in_group("pushable")):
			continue
		var other_mass: float = other.get("MASS") if other.get("MASS") != null else MASS
		other.velocity.x = _pre_slide_velocity.x
		velocity.x *= 1.0 - (other_mass * 0.3)

func die():
	# TODO: play death animation
	velocity = Vector2.ZERO
	hide()

	await get_tree().create_timer(RESPAWN_DELAY).timeout

	health = MAX_HEALTH
	health_changed.emit(health)
	var main = get_tree().get_root().get_node("Main")
	var peer_id = multiplayer.get_unique_id() if NetworkManager.is_active() else 1
	main.respawn_player_by_id(peer_id)

func start_dbj():
	if not has_dbj and not is_on_floor():
		has_dbj = true
		is_dbj = true
		_dbj_boost_lockout = DBJ_BOOST_LOCKOUT

		animation_player.play("dbj")
	
func run_dbj(_delta):
	velocity.y = DBJ_SPEED
	audio_stream_player.stream = dbj_sfx
	audio_stream_player.play()
	$EffectsAnchor.position.y = 10
	$EffectsAnchor/BoostParticles.process_material.direction = Vector3(0, 1, 0)
	effect_boost()
	if NetworkManager.is_active():
		_rpc_effect_boost.rpc(0.0, 10.0, Vector3(0, 1, 0))

func end_dbj():
	is_dbj = false


func start_air_boost():
	if not has_air_boosted and not is_on_floor():
		is_boosting = true
		boost_timer = BOOST_DURATION
		has_air_boosted = true

		audio_stream_player.stream = boost_jump_sfx
		audio_stream_player.play()

		$EffectsAnchor.position.x = -facing_direction * 10
		$EffectsAnchor/BoostParticles.process_material.direction = Vector3(-facing_direction, 0, 0)
		effect_boost()
		if NetworkManager.is_active():
			_rpc_effect_boost.rpc(-facing_direction * 10, 0.0, Vector3(-facing_direction, 0, 0))

func update_air_boost(delta):
	if is_boosting:
		boost_timer -= delta
		velocity.x = facing_direction * BOOST_SPEED
		velocity.y = 0  # Optional: freeze vertical motion
		if boost_timer <= 0:
			is_boosting = false
			#velocity.x -= facing_direction * BOOST_SPEED

func set_finished(finished: bool) -> void:
	if NetworkManager.is_active():
		_rpc_set_finished.rpc(finished)
	else:
		_rpc_set_finished(finished)

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_finished(finished: bool) -> void:
	$CollisionShape2D.set_deferred("disabled", finished)

func start_freeze(duration: float):
	is_frozen = true 
	freeze_timer = duration
	#velocity = Vector2.ZERO  # lock player instantly

func update_freeze(delta):
	if is_frozen:
		freeze_timer -= delta
		#velocity = Vector2.ZERO  # Optional: keep locked during freeze
		if freeze_timer <= 0:
			is_frozen = false
			
@rpc("authority", "unreliable")
func _rpc_effect_boost(anchor_x: float, anchor_y: float, dir: Vector3) -> void:
	$EffectsAnchor.position = Vector2(anchor_x, anchor_y)
	$EffectsAnchor/BoostParticles.process_material.direction = dir
	effect_boost()

func effect_boost():
	$EffectsAnchor/BoostParticles.restart()
	$EffectsAnchor/BoostParticles.emitting = true
