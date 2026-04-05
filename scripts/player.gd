extends CharacterBody2D

const DAGGER_SCENE = preload("res://scenes/weapons/Dagger.tscn")

const SPEED = 200.0
const JUMP_VELOCITY = -300.0
const MAX_HEALTH = 3

var health := MAX_HEALTH

signal health_changed(new_health: int)


var is_boosting = false
var has_air_boosted = false
var boost_timer = 0.0
const BOOST_DURATION = 0.2 # SECONDS
const BOOST_SPEED = 300.0	# constant horizontal speed

var has_dbj = false
var is_dbj = false
const DBJ_SPEED = -350	#double jump

var is_frozen = false
var freeze_timer = 0.0
const FREEZE_DURATION = 0.2 # SECONDS

var is_knocked_back := false
var _knockback_timer := 0.0
const KNOCKBACK_DURATION := 0.35

var is_invuln := false
var _invuln_timer := 0.0
const INVULN_DURATION := 1.0

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

func _physics_process(delta):
	if NetworkManager.is_active() and not is_multiplayer_authority():
		return
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	# tick invuln
	if is_invuln:
		_invuln_timer -= delta
		animated_sprite.visible = fmod(_invuln_timer, 0.2) > 0.1
		if _invuln_timer <= 0.0:
			is_invuln = false
			animated_sprite.visible = true

	# tick knockback
	if is_knocked_back:
		_knockback_timer -= delta
		if _knockback_timer <= 0.0:
			is_knocked_back = false

	var direction = 0.0 if is_knocked_back else Input.get_axis("move_left", "move_right")

	# flip sprite or don't flip sprite
	update_direction(direction)
	update_animation()

	if not is_knocked_back:
		# Handle jump.
		if Input.is_action_just_pressed("jump"):
			if is_on_floor():
				velocity.y = JUMP_VELOCITY
				audio_stream_player.stream = jump_sfx
				audio_stream_player.play()
			elif not has_dbj:
				start_dbj()

		if Input.is_action_just_pressed("f") and not is_on_floor() and not has_air_boosted:
			start_air_boost()
		if Input.is_action_just_pressed("attack"):
			_throw_dagger()

	# Add the gravity.
	if not is_on_floor() and not is_boosting:
		velocity.y += gravity * delta

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
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	
		
	move_and_slide()

	if NetworkManager.is_active():
		if multiplayer.is_server():
			for pid in _sync_peers:
				_sync_state.rpc_id(pid, global_position, animated_sprite.flip_h, animated_sprite.animation)
		else:
			_sync_state.rpc_id(1, global_position, animated_sprite.flip_h, animated_sprite.animation)

@rpc("any_peer", "unreliable_ordered")
func _sync_state(pos: Vector2, flip: bool, anim: String):
	if is_multiplayer_authority():
		return
	global_position = pos
	animated_sprite.flip_h = flip
	if animated_sprite.animation != anim:
		animated_sprite.play(anim)

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

func _throw_dagger() -> void:
	var spawn_pos := global_position + Vector2(facing_direction * 8, -5)
	var pid := multiplayer.get_unique_id() if NetworkManager.is_active() else -1
	if NetworkManager.is_active():
		_rpc_throw_dagger.rpc(facing_direction, spawn_pos, pid)
	else:
		_do_spawn_dagger(facing_direction, spawn_pos, pid)

@rpc("authority", "call_local", "reliable")
func _rpc_throw_dagger(dir: int, pos: Vector2, thrower_id: int) -> void:
	_do_spawn_dagger(dir, pos, thrower_id)

func _do_spawn_dagger(dir: int, pos: Vector2, thrower_id: int) -> void:
	var d = DAGGER_SCENE.instantiate()
	d.direction = dir
	d.scale.x = dir
	d.thrower_peer_id = thrower_id
	get_parent().add_child(d)
	d.global_position = pos

func die():
	# could play an animation or smtg (oh wait i so could though but im lazy)
	velocity = Vector2.ZERO
	hide()

	await get_tree().create_timer(.5).timeout

	health = MAX_HEALTH
	health_changed.emit(health)
	var main = get_tree().get_root().get_node("Main")
	var peer_id = multiplayer.get_unique_id() if NetworkManager.is_active() else 1
	main.respawn_player_by_id(peer_id)

func start_dbj():
	if not has_dbj and not is_on_floor():
		#has_dbj = true
		is_dbj = true

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
			velocity.x -= facing_direction * BOOST_SPEED
			#start_freeze(FREEZE_DURATION)

func start_freeze(duration: float):
	is_frozen = true
	freeze_timer = duration
	velocity = Vector2.ZERO  # lock player instantly

func update_freeze(delta):
	if is_frozen:
		freeze_timer -= delta
		velocity = Vector2.ZERO  # Optional: keep locked during freeze
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
	#$BoostSound.play()
