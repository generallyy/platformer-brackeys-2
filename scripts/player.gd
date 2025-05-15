extends CharacterBody2D


const SPEED = 200.0
const JUMP_VELOCITY = -300.0


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

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var facing_direction = 1 	# right = 1, left = -1
@onready var animated_sprite = $AnimatedSprite2D
@onready var animation_player = $AnimationPlayer
@onready var audio_stream_player = $AudioStreamPlayer

@onready var dbj_sfx = preload("res://assets/sounds/dbj.wav")
@onready var boost_jump_sfx = preload("res://assets/sounds/boost.wav")
@onready var jump_sfx = preload("res://assets/sounds/my_jump.wav")

func _physics_process(delta):
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction = Input.get_axis("move_left", "move_right")

	# flip sprite or don't flip sprite
	update_direction(direction)
	update_animation()

		# Handle jump.
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			audio_stream_player.stream = jump_sfx
			audio_stream_player.play()
		elif not has_dbj:
			start_dbj();
			
	if Input.is_action_just_pressed("f") and not is_on_floor() and not has_air_boosted:
		start_air_boost()
	# Add the gravity.
	if not is_on_floor() and not is_boosting:
		velocity.y += gravity * delta
		
	update_air_boost(delta)
	update_freeze(delta)
	
	if is_on_floor():
		has_air_boosted = false
		has_dbj = false
	
	if is_frozen:
		return		# skips movement physics
	
		# apply movement
	if is_on_floor() or not is_boosting:
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	
		
	move_and_slide()
	
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

func die():
	# could play an animation or smtg (oh wait i so could though but im lazy)
	velocity = Vector2.ZERO
	hide()
	
	await get_tree().create_timer(.5).timeout
	
	var main = get_tree().get_root().get_node("Main")
	main.respawn_player()
	show()

func start_dbj():
	if not has_dbj and not is_on_floor():
		has_dbj = true
		is_dbj = true

		animation_player.play("dbj")
	
func run_dbj(_delta):
	velocity.y = DBJ_SPEED
	audio_stream_player.stream = dbj_sfx
	audio_stream_player.play()
	$EffectsAnchor.position.y = 10
	$EffectsAnchor/BoostParticles.process_material.direction = Vector3(0, 1, 0)
	effect_boost()

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
			
func effect_boost():
	$EffectsAnchor/BoostParticles.restart()
	$EffectsAnchor/BoostParticles.emitting = true
	#$BoostSound.play()
