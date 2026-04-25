extends CharacterBody2D

# ============================================================
# PRELOADS
# ============================================================

const DAGGER_SCENE        = preload("res://scenes/weapons/Dagger.tscn")
const MELEE_SCENE         = preload("res://scenes/weapons/MeleeHitbox.tscn")
const ZAP_SCENE           = preload("res://scenes/weapons/Zap.tscn")
const SHIELD_SCENE        = preload("res://scenes/weapons/Shield.tscn")
const HOMER_SCENE         = preload("res://scenes/weapons/Homer.tscn")
const BOMB_SCENE          = preload("res://scenes/weapons/Bomb.tscn")
const CONFUSION_RAY_SCENE = preload("res://scenes/weapons/ConfusionRay.tscn")

const GHOST_BOMB_COOLDOWN := 3.0

## Set to true to use the StickFigureRig, false to use AnimatedSprite2D.
@export var USE_STICK_RIG := true

const _JUMP_SFX  = preload("res://assets/sounds/my_jump.wav")
const _DBJ_SFX   = preload("res://assets/sounds/dbj.wav")
const _BOOST_SFX = preload("res://assets/sounds/boost.wav")

# ============================================================
# FSM
# ============================================================

enum PlayerState {
	GROUNDED,     ## on the floor (idle or running; animation handles the visual distinction)
	AIRBORNE,     ## in the air with normal movement control
	DOUBLE_JUMP,  ## DBJ animation is playing
	AIR_BOOST,    ## horizontal dash (air)
	DASH,         ## horizontal dash (grounded)
	KNOCKED_BACK, ## hit response — input disabled
	UI_LOCKED,    ## menus / round transitions
}

var _state: PlayerState = PlayerState.GROUNDED

# ============================================================
# EXPORTS & NODE REFERENCES
# ============================================================

@export var stats: PlayerStats

@onready var animated_sprite:     AnimatedSprite2D  = $AnimatedSprite2D
@onready var stick_rig:           StickFigureRig    = $StickRig
@onready var animation_player:    AnimationPlayer   = $AnimationPlayer
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var _effects_anchor:     Node2D            = $EffectsAnchor
@onready var _boost_particles:    GPUParticles2D    = $EffectsAnchor/BoostParticles
@onready var _name_label:         Label             = $Label
@onready var _kill_indicator:     Label             = $KillIndicator
#@onready var _collision_shape:    CollisionShape2D  = $CollisionShape2D

# ============================================================
# SIGNALS
# ============================================================

signal health_changed(new_health: int, max_health: int)
signal powerups_changed(passive: Array, active: String)
signal nudge_changed(text: String)

func set_display_name(display_name: String) -> void:
	_name_label.text = display_name

func set_team(tid: int, color: Color) -> void:
	team_id = tid
	if tid == 0:
		_name_label.remove_theme_color_override("font_color")
	else:
		_name_label.add_theme_color_override("font_color", color)

# ============================================================
# PLAYER STATE
# ============================================================

var health: int = 0
var outfit_id  := 0
var facing_direction := 1  # 1 = right, -1 = left

## Compatibility property — external code (main.gd) may set this to clear a
## stuck DBJ freeze on level load or respawn.
var is_frozen: bool:
	get: return _dbj_frozen
	set(v): _dbj_frozen = v

var _input_direction    := 0.0
var _input_locked       := false
var _pre_slide_velocity := Vector2.ZERO
var gravity: float       = ProjectSettings.get_setting("physics/2d/default_gravity")

# --- Air abilities ---
var has_dbj         := false
var has_air_boosted := false
var _dbj_frozen         := false
var _dbj_freeze_timer   := 0.0
var _dbj_boost_lockout  := 0.0
var _boost_dbj_lockout  := 0.0
var _boost_timer        := 0.0
var _dash_timer         := 0.0
var _dash_cooldown      := 0.0

# --- Team ---
var team_id: int = 0  # 0 = no team

# --- Ghost ---
var is_ghost             := false
var _ghost_can_bomb      := true
var _ghost_bomb_cooldown := 0.0

# --- Spectator ---
var is_spectator:         bool    = false
var _spectator_mode:      int     = 0       # 0 = ghost, 1 = camera_lock
var _spectate_idx:        int     = 0
var _finished_at_goal:    bool    = false
var _spectator_return_pos: Vector2
var _goal_marker:         Node2D  = null

# --- Combat ---
var in_safe_zone          := false
var is_invuln             := false
var _invuln_timer         := 0.0
var _knockback_timer      := 0.0
var _melee_cooldown       := 0.0
var _last_attacker_peer_id: int = -1
var _last_hit_timer       := 0.0

# --- Weapon ---
var equipped_projectile_scene: PackedScene
var _projectile_cooldown       := 0.0
var _equipped_cooldown_max     := 0.0
var _equipped_throw_count      := 1
var _equipped_max_simultaneous := 1
var _equipped_returns          := false
var _active_projectile_count   := 0

# --- Shield ---
var shield_charge := 0.0
var _is_shielding := false
var _shield_node: Node = null

# --- Powerups ---
var passive_powerups: Array[String] = []
var active_powerup: String = ""
var _active_used_this_round := false
var _speed_surge_active     := false
var _speed_surge_timer      := 0.0

# --- Status effects (from powerups) ---
var _extra_jumps_used  := 0
var _lifesteal_hits    := 0
var _is_slowed         := false
var _slow_timer        := 0.0
var _is_stunned        := false
var _stun_timer        := 0.0
var _is_invisible      := false
var _invisible_timer   := 0.0
var _is_confused       := false
var _confusion_timer   := 0.0
const INVISIBLE_DURATION := 3.0

# --- Kill indicator ---
const KILL_INDICATOR_DURATION := 1.0
var _kill_count            := 0
var _kill_indicator_timer  := 0.0

# --- Overhead passthrough ---
var _passthrough_targets: Array = []
var _passthrough_timer   := 0.0

# --- Network ---
var _sync_peers: Array = []
var _input_cooldown := 0.0

# --- Outfit ---
var _outfit: PlayerOutfit

# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	if stats == null:
		stats = PlayerStats.new()
	health        = stats.max_health
	shield_charge = stats.shield_max
	_kill_indicator.visible = false
	add_to_group("player")
	_outfit = PlayerOutfit.new()
	_outfit.setup(animated_sprite)
	outfit_id = _outfit.apply_visuals(outfit_id)
	_apply_rig_outfit_color(outfit_id)
	animated_sprite.visible = not USE_STICK_RIG
	if stick_rig != null:
		stick_rig.visible = USE_STICK_RIG
	_play_visual_animation(&"idle")
	equip_weapon(DAGGER_SCENE)
	_shield_node = SHIELD_SCENE.instantiate()
	add_child(_shield_node)
	_shield_node.visible = false


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return

	_tick_timers(delta)
	_update_damage_flash(delta)
	_update_shield(delta)
	_apply_gravity(delta)

	if is_spectator and _spectator_mode == 1:
		velocity = Vector2.ZERO

	_input_direction = 0.0 if (_state == PlayerState.KNOCKED_BACK or _is_shielding or _input_locked) \
			else Input.get_axis("move_left", "move_right")
	if _is_confused:
		_input_direction = -_input_direction
	update_direction(_input_direction)
	update_animation()

	match _state:
		PlayerState.UI_LOCKED:
			velocity.x = 0.0
			if is_on_floor():
				velocity.y = 0.0
		PlayerState.KNOCKED_BACK:
			pass  # gravity applied; no input
		PlayerState.AIR_BOOST:
			velocity.x = facing_direction * stats.boost_speed * pow(1.30, passive_powerups.count(PowerupIds.DASH_BOOST_AIR))
			velocity.y = 0.0
			if Input.is_action_just_pressed("jump") and not _is_shielding and _boost_dbj_lockout <= 0.0:
				if not has_dbj:
					_transition_to(PlayerState.DOUBLE_JUMP)
				elif _extra_jumps_used < passive_powerups.count(PowerupIds.EXTRA_JUMP):
					_extra_jumps_used += 1
					_transition_to(PlayerState.DOUBLE_JUMP)
				elif passive_powerups.has(PowerupIds.JUMP_BOOST):
					_transition_to(PlayerState.DOUBLE_JUMP)
		PlayerState.DASH:
			velocity.x = facing_direction * stats.dash_speed * pow(1.30, passive_powerups.count(PowerupIds.DASH_BOOST_GROUND))
			if is_multiplayer_authority():
				for t in _passthrough_targets:
					if is_instance_valid(t) and t.is_in_group("player"):
						if global_position.distance_to(t.global_position) < 12.0:
							var push_x := -facing_direction * stats.dash_speed
							if NetworkManager.is_online():
								t._rpc_receive_dash_push.rpc_id(t.get_multiplayer_authority(), push_x)
							else:
								t.velocity.x = push_x
		PlayerState.DOUBLE_JUMP:
			if _dbj_frozen:
				return
			_handle_input(delta)
			if _state == PlayerState.DOUBLE_JUMP:
				_apply_movement(delta)
		_:
			_handle_input(delta)
			if _state not in [PlayerState.AIR_BOOST, PlayerState.DASH]:
				_apply_movement(delta)

	_pre_slide_velocity = velocity
	move_and_slide()
	_check_landing()
	_resolve_body_collisions()
	_send_state_sync()

# ============================================================
# FSM
# ============================================================

func _transition_to(new_state: PlayerState) -> void:
	_exit_state(_state)
	_state = new_state
	_enter_state(_state)

func _enter_state(state: PlayerState) -> void:
	match state:
		PlayerState.GROUNDED:
			_dbj_frozen = false
		PlayerState.DOUBLE_JUMP:
			has_dbj            = true
			_dbj_boost_lockout = stats.dbj_boost_lockout
			_dbj_frozen        = false
			_play_visual_animation(&"dbj")
			animated_sprite.play(&"dbj")
			animation_player.play("dbj")
		PlayerState.DASH:
			_dash_timer    = stats.dash_duration
			_dash_cooldown = stats.dash_cooldown
			var ground_mult := pow(1.30, passive_powerups.count(PowerupIds.DASH_BOOST_GROUND))
			velocity.x = facing_direction * stats.dash_speed * ground_mult
			var others := get_tree().get_nodes_in_group("player").filter(func(p): return p != self)
			_add_passthrough(others, stats.dash_duration + 0.15)
		PlayerState.AIR_BOOST:
			_boost_timer       = stats.boost_duration
			has_air_boosted    = true
			_boost_dbj_lockout = stats.boost_dbj_lockout
			var air_mult := pow(1.30, passive_powerups.count(PowerupIds.DASH_BOOST_AIR))
			velocity.x = facing_direction * stats.boost_speed * air_mult
			velocity.y = 0.0
			audio_stream_player.stream = _BOOST_SFX
			audio_stream_player.play()
			_effects_anchor.position = Vector2(-facing_direction * 10.0, 0.0)
			_boost_particles.process_material.direction = Vector3(-facing_direction, 0.0, 0.0)
			_play_boost_particles()
			if NetworkManager.is_online():
				_rpc_effect_boost.rpc(-facing_direction * 10.0, 0.0, Vector3(-facing_direction, 0.0, 0.0))
		PlayerState.KNOCKED_BACK:
			_knockback_timer = stats.knockback_duration
		PlayerState.UI_LOCKED:
			velocity = Vector2.ZERO

func _exit_state(_exiting_state: PlayerState) -> void:
	pass

# ============================================================
# PER-FRAME HELPERS
# ============================================================

func _tick_timers(delta: float) -> void:
	if _last_hit_timer > 0.0:
		_last_hit_timer -= delta
		if _last_hit_timer <= 0.0:
			_last_attacker_peer_id = -1

	_input_cooldown       = max(0.0, _input_cooldown       - delta)
	_melee_cooldown       = max(0.0, _melee_cooldown       - delta)
	_projectile_cooldown  = max(0.0, _projectile_cooldown  - delta)
	_ghost_bomb_cooldown  = max(0.0, _ghost_bomb_cooldown  - delta)
	_dbj_boost_lockout   = max(0.0, _dbj_boost_lockout   - delta)
	_boost_dbj_lockout   = max(0.0, _boost_dbj_lockout   - delta)

	if _speed_surge_active:
		_speed_surge_timer -= delta
		if _speed_surge_timer <= 0.0:
			_speed_surge_active = false

	if _is_slowed:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_is_slowed = false

	if _is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_is_stunned   = false
			_input_locked = false

	if _is_confused:
		_confusion_timer -= delta
		if _confusion_timer <= 0.0:
			_is_confused = false

	if _is_invisible:
		_invisible_timer -= delta
		if _invisible_timer <= 0.0:
			_is_invisible = false
			if NetworkManager.is_online():
				_rpc_set_invisible.rpc(false)
			else:
				modulate.a = 1.0

	if _dbj_frozen:
		_dbj_freeze_timer -= delta
		if _dbj_freeze_timer <= 0.0:
			_dbj_frozen = false

	if _state == PlayerState.KNOCKED_BACK:
		_knockback_timer -= delta
		if _knockback_timer <= 0.0:
			_transition_to(PlayerState.AIRBORNE if not is_on_floor() else PlayerState.GROUNDED)

	if _state == PlayerState.AIR_BOOST:
		_boost_timer -= delta
		if _boost_timer <= 0.0:
			_transition_to(PlayerState.AIRBORNE if not is_on_floor() else PlayerState.GROUNDED)

	if _state == PlayerState.DASH:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_transition_to(PlayerState.GROUNDED)

	if _dash_cooldown > 0.0:
		_dash_cooldown -= delta

	if _kill_indicator_timer > 0.0:
		_kill_indicator_timer -= delta
		if _kill_indicator_timer <= 0.0:
			_kill_count = 0
			_kill_indicator.visible = false

	if _passthrough_timer > 0.0:
		_passthrough_timer -= delta
		if _passthrough_timer <= 0.0:
			# Don't drop the exception while still overlapping — sudden depenetration causes floating
			var still_overlapping := false
			for t in _passthrough_targets:
				if is_instance_valid(t):
					# Circle center is offset (0, -5) from origin, radius 5 each → overlap < 10
					var dist := (global_position + Vector2(0, -5)).distance_to(t.global_position + Vector2(0, -5))
					if dist < 11.0:
						still_overlapping = true
						break
			if still_overlapping:
				_passthrough_timer = 0.05
			else:
				_clear_passthrough()


func _get_overhead_players() -> Array:
	var result := []
	for p in get_tree().get_nodes_in_group("player"):
		if p == self or not is_instance_valid(p):
			continue
		var diff: Vector2 = p.global_position - global_position
		# Circle radius 5, center offset -5 → another player standing on our head
		# puts their origin roughly 10 px above ours.  Use a generous window.
		if diff.y < 0.0 and diff.y > -28.0 and abs(diff.x) < 14.0:
			result.append(p)
	return result

func _add_passthrough(targets: Array, duration: float) -> void:
	for t in targets:
		if is_instance_valid(t) and t not in _passthrough_targets:
			add_collision_exception_with(t)
			_passthrough_targets.append(t)
	if targets.size() > 0:
		_passthrough_timer = max(_passthrough_timer, duration)

func _clear_passthrough() -> void:
	for t in _passthrough_targets:
		if is_instance_valid(t):
			remove_collision_exception_with(t)
	_passthrough_targets.clear()

func _apply_gravity(delta: float) -> void:
	if is_on_floor() or _state == PlayerState.AIR_BOOST:
		return
	var low_grav := PowerupIds.LOW_GRAVITY in passive_powerups
	var gravity_scale := 0.5 if low_grav else 1.0
	var fall_cap      := stats.max_fall_speed * (0.6 if low_grav else 1.0)
	velocity.y = min(velocity.y + gravity * gravity_scale * delta, fall_cap)


func _update_shield(delta: float) -> void:
	var can_shield := _state != PlayerState.KNOCKED_BACK and _state != PlayerState.UI_LOCKED
	var want_shield := can_shield and Input.is_action_pressed("shield") \
			and (_is_shielding or shield_charge > 0.25)
	_is_shielding = want_shield
	if _is_shielding:
		shield_charge = max(0.0, shield_charge - delta)
		if shield_charge <= 0.0:
			_is_shielding = false
	else:
		shield_charge = min(stats.shield_max, shield_charge + stats.shield_recharge_rate * delta)
	_shield_node.set_active(_is_shielding)
	_shield_node.update_charge(shield_charge, stats.shield_max)


func _local_peer_id_or_1() -> int:
	return multiplayer.get_unique_id()



func enter_spectator_mode(pos: Vector2) -> void:
	is_spectator          = true
	_spectator_mode       = 0
	_spectator_return_pos = pos
	_dbj_frozen           = false
	_dbj_freeze_timer     = 0.0
	# Frozen character stays visible at the goal for everyone
	_goal_marker = animated_sprite.duplicate() as AnimatedSprite2D
	get_parent().add_child(_goal_marker)
	_goal_marker.global_position = pos + animated_sprite.position
	activate_ghost_mode(false, pos)
	nudge_changed.emit("Press [%s] to enter spectate mode." % InputUtils.get_action_key("interact"))
	if is_multiplayer_authority():
		get_node("Camera2D").make_current()


func exit_spectator_mode() -> void:
	if _goal_marker:
		_goal_marker.queue_free()
		_goal_marker = null
	var still_at_goal := _finished_at_goal  # deactivate_ghost_mode clears this
	deactivate_ghost_mode()
	if still_at_goal:
		_finished_at_goal = true
		global_position = _spectator_return_pos
		_transition_to(PlayerState.UI_LOCKED)
		nudge_changed.emit("You finished! Press [%s] to enter spectate mode." % InputUtils.get_action_key("interact"))
	else:
		_transition_to(PlayerState.GROUNDED if is_on_floor() else PlayerState.AIRBORNE)


func _enter_camera_lock_mode() -> void:
	_spectator_mode = 1
	modulate.a      = 0.0  # hide ghost body locally while watching another player
	_spectate_idx   = 0
	nudge_changed.emit("Press [%s] to enter ghost mode." % InputUtils.get_action_key("interact"))
	_advance_spectate_target(0)


func _exit_camera_lock_mode() -> void:
	_spectator_mode = 0
	modulate.a      = 0.4  # restore ghost visibility
	nudge_changed.emit("Press [%s] to enter spectate mode." % InputUtils.get_action_key("interact"))
	get_node("Camera2D").make_current()


func _advance_spectate_target(delta: int) -> void:
	var main := get_tree().get_root().get_node("Main")
	var targets: Array = []
	for p in main.spawned_players.values():
		if p != self and not p.is_spectator and not p.is_ghost:
			targets.append(p)
	if targets.is_empty():
		_exit_camera_lock_mode()
		return
	_spectate_idx = (_spectate_idx + delta) % targets.size()
	targets[_spectate_idx].get_node("Camera2D").make_current()


func _handle_ghost_input() -> void:
	if is_spectator:
		if _spectator_mode == 1:  # camera lock
			var main := get_tree().get_root().get_node("Main")
			var has_valid := false
			for p in main.spawned_players.values():
				if p != self and not p.is_spectator and not p.is_ghost:
					has_valid = true
					break
			if not has_valid:
				_exit_camera_lock_mode()
			elif Input.is_action_just_pressed("interact"):
				_exit_camera_lock_mode()
			elif Input.is_action_just_pressed("move_right"):
				_advance_spectate_target(1)
			elif Input.is_action_just_pressed("move_left"):
				_advance_spectate_target(-1)
			return  # no body movement in camera lock
		else:  # ghost submode
			if Input.is_action_just_pressed("interact"):
				_enter_camera_lock_mode()
				return
	# Jump / double jump
	if Input.is_action_just_pressed("jump") and _input_cooldown <= 0.0:
		if is_on_floor():
			_do_jump()
		elif not has_dbj and _boost_dbj_lockout <= 0.0:
			_transition_to(PlayerState.DOUBLE_JUMP)

	# Dash / air boost
	if Input.is_action_just_pressed("f"):
		if is_on_floor() and _dash_cooldown <= 0.0:
			_transition_to(PlayerState.DASH)
		elif not is_on_floor() and not has_air_boosted and _dbj_boost_lockout <= 0.0:
			_transition_to(PlayerState.AIR_BOOST)

	# Bomb placement
	if not _ghost_can_bomb:
		return
	if Input.is_action_just_pressed("attack") and _ghost_bomb_cooldown <= 0.0 and not in_safe_zone:
		_ghost_bomb_cooldown = GHOST_BOMB_COOLDOWN
		_rpc_place_bomb.rpc(global_position, multiplayer.get_unique_id())


@rpc("authority", "call_local", "reliable")
func _rpc_place_bomb(pos: Vector2, thrower_id: int) -> void:
	_do_spawn_bomb(pos, thrower_id)


func _do_spawn_bomb(pos: Vector2, thrower_id: int) -> void:
	var bomb := BOMB_SCENE.instantiate()
	bomb.thrower_peer_id = thrower_id
	get_parent().add_child(bomb)
	bomb.global_position = pos


func activate_ghost_mode(can_bomb: bool = true, spawn_pos: Vector2 = Vector2.ZERO) -> void:
	is_ghost             = true
	_ghost_can_bomb      = can_bomb
	_ghost_bomb_cooldown = 0.0
	health               = 1  # keep non-zero so normal death logic doesn't re-trigger
	global_position      = spawn_pos
	velocity             = Vector2.ZERO
	show()
	modulate.a = 0.4 if can_bomb else 0.0
	if _state == PlayerState.UI_LOCKED or _state == PlayerState.KNOCKED_BACK:
		_transition_to(PlayerState.AIRBORNE if not is_on_floor() else PlayerState.GROUNDED)
	if can_bomb and not is_spectator:
		nudge_changed.emit("You are dead! Press [%s] to drop a bomb." % InputUtils.get_action_key("attack"))
	for p in get_tree().get_nodes_in_group("player"):
		if p != self:
			add_collision_exception_with(p)
			p.add_collision_exception_with(self)


func deactivate_ghost_mode() -> void:
	if not is_ghost:
		return
	if is_spectator:
		if is_multiplayer_authority():
			get_node("Camera2D").make_current()
		is_spectator      = false
		_spectator_mode   = 0
		_finished_at_goal = false
	if _goal_marker:
		_goal_marker.queue_free()
		_goal_marker = null
	nudge_changed.emit("")
	is_ghost   = false
	modulate.a = 1.0
	for p in get_tree().get_nodes_in_group("player"):
		if p != self:
			remove_collision_exception_with(p)
			p.remove_collision_exception_with(self)


func _input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if _finished_at_goal and not is_spectator and _state == PlayerState.UI_LOCKED:
		if event.is_action_pressed("interact"):
			get_tree().get_root().get_node("Main").request_enter_spectator(_local_peer_id_or_1())
			get_viewport().set_input_as_handled()
			return
	if is_spectator and event.is_action_pressed("ui_cancel"):
		get_tree().get_root().get_node("Main").request_exit_spectator(_local_peer_id_or_1())
		get_viewport().set_input_as_handled()


func _handle_input(_delta: float) -> void:
	if is_ghost:
		_handle_ghost_input()
		return
	if _is_stunned:
		return
	if Input.is_action_just_pressed("jump") and not _is_shielding and _input_cooldown <= 0.0:
		if is_on_floor():
			_add_passthrough(_get_overhead_players(), 0.4)
			_do_jump()
		elif _boost_dbj_lockout <= 0.0:
			if not has_dbj:
				_transition_to(PlayerState.DOUBLE_JUMP)
			elif _extra_jumps_used < passive_powerups.count(PowerupIds.EXTRA_JUMP):
				_extra_jumps_used += 1
				_transition_to(PlayerState.DOUBLE_JUMP)
			elif passive_powerups.has(PowerupIds.JUMP_BOOST):
				_transition_to(PlayerState.DOUBLE_JUMP)

	if Input.is_action_just_pressed("f") and not _is_shielding:
		if is_on_floor() and _dash_cooldown <= 0.0:
			_transition_to(PlayerState.DASH)
		elif not is_on_floor() and not has_air_boosted and _dbj_boost_lockout <= 0.0:
			_transition_to(PlayerState.AIR_BOOST)

	var can_throw := _projectile_cooldown <= 0.0 \
			and (not _equipped_returns or _active_projectile_count < _equipped_max_simultaneous)
	if Input.is_action_just_pressed("attack") and can_throw and not _is_shielding and not in_safe_zone:
		_throw_weapon(equipped_projectile_scene, facing_direction)
		if _equipped_returns:
			_active_projectile_count += 1
		_projectile_cooldown = _equipped_cooldown_max

	if Input.is_action_just_pressed("melee") and _melee_cooldown <= 0.0 and not _is_shielding and not in_safe_zone:
		if Input.get_axis("move_left", "move_right") != 0.0:
			_do_melee()
		else:
			_do_zap()

	if Input.is_action_just_pressed("use_active") and not _active_used_this_round and not _is_shielding:
		match active_powerup:
			PowerupIds.SPEED_BOOST:
				_speed_surge_active     = true
				_speed_surge_timer      = stats.speed_surge_duration
				_active_used_this_round = true
			PowerupIds.HOMER_ONCE:
				if not in_safe_zone:
					_throw_weapon(HOMER_SCENE, facing_direction)
					_active_used_this_round = true
			PowerupIds.INVISIBLE:
				_is_invisible       = true
				_invisible_timer    = INVISIBLE_DURATION
				_active_used_this_round = true
				if NetworkManager.is_online():
					_rpc_set_invisible.rpc(true)
				else:
					modulate.a = 0.0
			PowerupIds.TELEPORT:
				_active_used_this_round = true
				var nearest := _find_nearest_player()
				if nearest != null:
					_rpc_teleport_to.rpc(nearest.global_position)
			PowerupIds.HEART_RESET:
				_active_used_this_round = true
				_rpc_heart_reset.rpc()
			PowerupIds.CONFUSION_RAY:
				if not in_safe_zone:
					_throw_weapon(CONFUSION_RAY_SCENE, facing_direction)
					_active_used_this_round = true


func _apply_movement(delta: float) -> void:
	var effective_speed := stats.speed_surge_speed if _speed_surge_active else stats.speed
	var speed_up_stacks := passive_powerups.count(PowerupIds.SPEED_UP)
	if speed_up_stacks > 0:
		effective_speed *= pow(1.10, speed_up_stacks)
	if PowerupIds.GET_BIGGER in passive_powerups:
		effective_speed *= 1.15
	if PowerupIds.GET_SMALLER in passive_powerups:
		effective_speed *= 0.80
	var hh_stacks := passive_powerups.count(PowerupIds.HEAVY_HITTER)
	if hh_stacks > 0:
		effective_speed *= pow(0.80, hh_stacks)
	if _is_slowed:
		effective_speed *= 0.60
	if _input_direction:
		_add_passthrough(_get_overhead_players(), 0.12)  # refreshed every frame while walking
		var turning := _input_direction * velocity.x < 0.0
		var accel: float
		if turning:
			accel = stats.turn_acceleration if is_on_floor() else stats.air_turn_acceleration
		else:
			accel = stats.acceleration if is_on_floor() else stats.air_acceleration
		velocity.x = move_toward(velocity.x, _input_direction * effective_speed, accel * delta)
	else:
		var fric := stats.friction if is_on_floor() else stats.air_friction
		velocity.x = move_toward(velocity.x, 0.0, fric * delta)


func _check_landing() -> void:
	if _state in [PlayerState.KNOCKED_BACK, PlayerState.UI_LOCKED, PlayerState.AIR_BOOST, PlayerState.DASH]:
		return
	if is_on_floor():
		has_air_boosted   = false
		has_dbj           = false
		_extra_jumps_used = 0
		if _state != PlayerState.GROUNDED:
			_transition_to(PlayerState.GROUNDED)
	elif _state == PlayerState.GROUNDED:
		_transition_to(PlayerState.AIRBORNE)

# ============================================================
# DIRECTION & ANIMATION
# ============================================================

func update_direction(direction: float) -> void:
	if direction != 0.0:
		facing_direction = 1 if direction > 0.0 else -1
	animated_sprite.flip_h = (facing_direction == -1)
	if USE_STICK_RIG and stick_rig != null:
		stick_rig.set_facing(facing_direction)


func update_animation() -> void:
	var next_animation: StringName
	if is_on_floor():
		if abs(velocity.x) < 1.0:
			next_animation = &"idle"
		else:
			next_animation = &"run"
	elif _state != PlayerState.DOUBLE_JUMP:
		next_animation = &"jump"
	else:
		return
	animated_sprite.play(next_animation)
	_play_visual_animation(next_animation)


func _play_visual_animation(animation_name: StringName) -> void:
	if USE_STICK_RIG and stick_rig != null:
		stick_rig.play(animation_name)


func _set_visual_visible(visibility: bool) -> void:
	if USE_STICK_RIG:
		if stick_rig != null:
			stick_rig.visible = visibility
		animated_sprite.visible = false
	else:
		animated_sprite.visible = visibility

# ============================================================
# DBJ ANIMATION CALLBACKS  (called by AnimationPlayer tracks)
# ============================================================

func start_freeze(duration: float) -> void:
	_dbj_frozen       = true
	_dbj_freeze_timer = duration


func freeze_for_duration(duration: float) -> void:
	_input_locked = true
	velocity.x    = 0.0
	await get_tree().create_timer(duration).timeout
	_input_locked = false


func run_dbj(_delta = null) -> void:
	velocity.y = stats.dbj_speed * pow(0.90, passive_powerups.count(PowerupIds.JUMP_BOOST))
	audio_stream_player.stream = _DBJ_SFX
	audio_stream_player.play()
	_effects_anchor.position.y = 10.0
	_boost_particles.process_material.direction = Vector3(0.0, 1.0, 0.0)
	_play_boost_particles()
	if NetworkManager.is_online():
		_rpc_effect_boost.rpc(0.0, 10.0, Vector3(0.0, 1.0, 0.0))


func end_dbj() -> void:
	if _state == PlayerState.DOUBLE_JUMP:
		_transition_to(PlayerState.AIRBORNE)

# ============================================================
# JUMP
# ============================================================

func _do_jump() -> void:
	velocity.y = stats.jump_velocity
	audio_stream_player.stream = _JUMP_SFX
	audio_stream_player.play()

# ============================================================
# COMBAT — helpers
# ============================================================

func _effective_damage() -> int:
	return 1 + passive_powerups.count(PowerupIds.DAMAGE_BOOST)


func _effective_knockback_scale() -> float:
	var base := pow(1.6, passive_powerups.count(PowerupIds.KNOCKBACK_BOOST))
	return base * pow(1.20, passive_powerups.count(PowerupIds.HEAVY_HITTER))

# ============================================================
# COMBAT — weapons
# ============================================================

func equip_weapon(scene: PackedScene, cooldown: float = 0.0) -> void:
	if scene == null:
		push_error("%s tried to equip a null weapon scene" % name)
		return
	equipped_projectile_scene  = scene
	_equipped_cooldown_max     = cooldown
	_projectile_cooldown       = 0.0
	_active_projectile_count   = 0
	var temp := scene.instantiate()
	_equipped_throw_count      = temp.THROW_COUNT
	_equipped_max_simultaneous = temp.MAX_SIMULTANEOUS
	_equipped_returns          = temp.RETURNS
	temp.free()


func _throw_weapon(scene: PackedScene, dir: int, extra_offset: Vector2 = Vector2.ZERO) -> void:
	if scene == null:
		push_error("%s tried to throw a null weapon scene" % name)
		return
	var spawn_pos := global_position + stats.weapon_spawn_offset * Vector2(dir, 1) + extra_offset
	var soh := PowerupIds.SLOW_ON_HIT in passive_powerups
	_rpc_throw_weapon.rpc(scene.resource_path, dir, spawn_pos, multiplayer.get_unique_id(), _effective_damage(), _effective_knockback_scale(), soh)


@rpc("authority", "call_local", "reliable")
func _rpc_throw_weapon(scene_path: String, dir: int, pos: Vector2, thrower_id: int, dmg: int = 1, kbs: float = 1.0, slow_on_hit: bool = false) -> void:
	var scene := load(scene_path) as PackedScene
	if scene == null:
		push_error("Failed to load weapon scene: %s" % scene_path)
		return
	_do_spawn_weapon(scene, dir, pos, thrower_id, dmg, kbs, slow_on_hit)


func _do_spawn_weapon(scene: PackedScene, dir: int, pos: Vector2, thrower_id: int, dmg: int = 1, kbs: float = 1.0, slow_on_hit: bool = false) -> void:
	if scene == null:
		push_error("%s tried to spawn a null weapon scene" % name)
		return
	var p := scene.instantiate()
	p.direction       = dir
	p.scale.x         = dir
	p.thrower_peer_id = thrower_id
	p.damage          = dmg
	p.knockback       = p.knockback * kbs
	p.slow_on_hit     = slow_on_hit
	if not NetworkManager.is_online():
		p.owner_node = self
	get_parent().add_child(p)
	p.global_position = pos
	if _equipped_returns and is_multiplayer_authority():
		p.tree_exiting.connect(_on_projectile_returned)


func _on_projectile_returned() -> void:
	_active_projectile_count = max(0, _active_projectile_count - 1)
	_projectile_cooldown     = _equipped_cooldown_max

# ============================================================
# COMBAT — melee & zap
# ============================================================

func _do_melee() -> void:
	_melee_cooldown = stats.melee_cooldown
	var bm  := passive_powerups.count(PowerupIds.BIG_MELEE)
	var soh := PowerupIds.SLOW_ON_HIT in passive_powerups
	var ss  := passive_powerups.count(PowerupIds.SHIELD_SPIKE)
	var ps  := PowerupIds.PARRY_STUN in passive_powerups
	_rpc_throw_melee.rpc(facing_direction, multiplayer.get_unique_id(), _effective_damage(), _effective_knockback_scale(), bm, soh, ss, ps)


@rpc("authority", "call_local", "reliable")
func _rpc_throw_melee(dir: int, thrower_id: int, dmg: int = 1, kbs: float = 1.0, big_melee_stacks: int = 0, slow_on_hit: bool = false, shield_spike_dmg: int = 0, parry_stun: bool = false) -> void:
	_do_spawn_melee(dir, thrower_id, dmg, kbs, big_melee_stacks, slow_on_hit, shield_spike_dmg, parry_stun)


func _do_spawn_melee(dir: int, thrower_id: int, dmg: int = 1, kbs: float = 1.0, big_melee_stacks: int = 0, slow_on_hit: bool = false, shield_spike_dmg: int = 0, parry_stun: bool = false) -> void:
	var m := MELEE_SCENE.instantiate()
	m.direction       = dir
	m.thrower_peer_id = thrower_id
	m.damage          = dmg
	m.knockback_scale = kbs
	m.slow_on_hit     = slow_on_hit
	m.shield_spike_dmg = shield_spike_dmg
	m.parry_stun      = parry_stun
	if big_melee_stacks > 0:
		var s := pow(1.40, big_melee_stacks)
		m.scale = Vector2(dir * s, s)
	else:
		m.scale.x = dir
	m.hit_landed.connect(_on_melee_hit_landed)
	add_child(m)
	m.position = stats.weapon_spawn_offset * Vector2(dir, 1)


func _do_zap() -> void:
	_melee_cooldown = stats.melee_cooldown
	_rpc_throw_zap.rpc(facing_direction, multiplayer.get_unique_id(), _effective_damage(), _effective_knockback_scale())


@rpc("authority", "call_local", "reliable")
func _rpc_throw_zap(dir: int, thrower_id: int, dmg: int = 1, kbs: float = 1.0) -> void:
	_do_spawn_zap(dir, thrower_id, dmg, kbs)


func _do_spawn_zap(dir: int, thrower_id: int, dmg: int = 1, kbs: float = 1.0) -> void:
	var z := ZAP_SCENE.instantiate()
	z.direction       = dir
	z.thrower_peer_id = thrower_id
	z.damage          = dmg
	z.knockback_scale = kbs
	add_child(z)
	z.position = Vector2(0.0, -7.0)

# ============================================================
# DAMAGE & DEATH
# ============================================================

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, attacker_peer_id: int = -1, bypass_ghost: bool = false) -> void:
	if not is_multiplayer_authority():
		return
	if is_ghost and not bypass_ghost:
		return
	if is_invuln or _is_shielding or _state == PlayerState.UI_LOCKED:
		return
	# Friendly-fire prevention
	if attacker_peer_id != -1 and team_id != 0:
		var _main := get_tree().get_root().get_node_or_null("Main")
		if _main:
			var attacker_team: int = _main.player_teams.get(attacker_peer_id, 0)
			if attacker_team != 0 and attacker_team == team_id:
				return
	if attacker_peer_id != -1:
		_last_attacker_peer_id = attacker_peer_id
		_last_hit_timer        = stats.kill_credit_window
	var actual := mini(amount, health)
	health -= amount
	health_changed.emit(health, get_effective_max_health())
	if attacker_peer_id != -1:
		var main := get_tree().get_root().get_node_or_null("Main")
		if main:
			main.notify_damage(attacker_peer_id, multiplayer.get_unique_id(), actual)
	if health <= 0:
		die()
		return
	if knockback != Vector2.ZERO:
		velocity = knockback
		_transition_to(PlayerState.KNOCKED_BACK)
	is_invuln     = true
	_invuln_timer = stats.invuln_duration


func die() -> void:
	if is_ghost:
		var ghost_main := get_tree().get_root().get_node_or_null("Main")
		if ghost_main:
			var ghost_spawn: Node2D = ghost_main.get_current_spawn_for_peer(multiplayer.get_unique_id())
			if ghost_spawn:
				global_position = ghost_spawn.global_position
		velocity = Vector2.ZERO
		return
	is_invuln = true
	velocity = Vector2.ZERO
	_kill_count = 0
	_kill_indicator_timer = 0.0
	_kill_indicator.visible = false
	hide()
	await get_tree().create_timer(stats.respawn_delay).timeout
	health = get_effective_max_health()
	health_changed.emit(health, get_effective_max_health())
	_state = PlayerState.GROUNDED
	var main    := get_tree().get_root().get_node("Main")
	var peer_id := multiplayer.get_unique_id()
	if _last_attacker_peer_id != -1 and _last_attacker_peer_id != peer_id:
		main.notify_kill(_last_attacker_peer_id, peer_id)
	else:
		main.notify_self_death(peer_id)
	_last_attacker_peer_id = -1
	_last_hit_timer        = 0.0
	main.respawn_player_by_id(peer_id)

# ============================================================
# EFFECTS
# ============================================================

func show_kill() -> void:
	_kill_count += 1
	_kill_indicator.text = "+%d" % _kill_count
	_kill_indicator.visible = true
	_kill_indicator_timer = KILL_INDICATOR_DURATION

func _update_damage_flash(delta: float) -> void:
	if not is_invuln:
		_set_visual_visible(true)
		return
	_invuln_timer -= delta
	_set_visual_visible(fmod(_invuln_timer, stats.iframes_blink_interval) > stats.iframes_blink_threshold)
	if _invuln_timer <= 0.0:
		is_invuln = false
		_set_visual_visible(true)


func warmup_effects() -> void:
	_boost_particles.restart()
	_boost_particles.emitting = true

func _play_boost_particles() -> void:
	_boost_particles.restart()
	_boost_particles.emitting = true


@rpc("any_peer", "reliable")
func _rpc_receive_dash_push(push_velocity_x: float) -> void:
	velocity.x = push_velocity_x

@rpc("authority", "unreliable")
func _rpc_effect_boost(anchor_x: float, anchor_y: float, dir: Vector3) -> void:
	_effects_anchor.position                    = Vector2(anchor_x, anchor_y)
	_boost_particles.process_material.direction = dir
	_play_boost_particles()

# ============================================================
# BODY COLLISIONS
# ============================================================

func _resolve_body_collisions() -> void:
	if NetworkManager.is_online() and not multiplayer.is_server():
		return
	for i in get_slide_collision_count():
		var col   := get_slide_collision(i)
		var other := col.get_collider()
		if not (other is CharacterBody2D and other.is_in_group("pushable")):
			continue
		var other_mass: float = other.get("MASS") if other.get("MASS") != null else stats.mass
		other.velocity.x  = _pre_slide_velocity.x
		velocity.x       *= 1.0 - (other_mass * 0.3)

# ============================================================
# UI LOCK / FINISHED
# ============================================================

func set_ui_locked(locked: bool) -> void:
	if locked:
		_transition_to(PlayerState.UI_LOCKED)
	else:
		_input_cooldown = 0.1
		_transition_to(PlayerState.AIRBORNE if not is_on_floor() else PlayerState.GROUNDED)


func set_finished(finished: bool) -> void:
	_rpc_set_finished.rpc(finished)


@rpc("any_peer", "call_local", "reliable")
func _rpc_set_finished(finished: bool) -> void:
	_finished_at_goal = finished
	if finished:
		_transition_to(PlayerState.UI_LOCKED)
		nudge_changed.emit("You have finished! Press [%s] to enter spectate mode." % InputUtils.get_action_key("interact"))
	else:
		_transition_to(PlayerState.GROUNDED if is_on_floor() else PlayerState.AIRBORNE)
		nudge_changed.emit("")

# ============================================================
# POWERUPS
# ============================================================

func get_effective_max_health() -> int:
	return stats.max_health + passive_powerups.count(PowerupIds.EXTRA_HEARTS) * 2


func apply_powerup(id: String) -> void:
	if id in PowerupIds.ALL_ACTIVE:
		active_powerup          = id
		_active_used_this_round = false
	else:
		if id == PowerupIds.GET_BIGGER and PowerupIds.GET_SMALLER in passive_powerups:
			return
		if id == PowerupIds.GET_SMALLER and PowerupIds.GET_BIGGER in passive_powerups:
			return
		if passive_powerups.count(id) >= PowerupIds.get_max_stacks(id):
			return
		passive_powerups.append(id)
		if id == PowerupIds.EXTRA_HEARTS:
			health = mini(health + 2, get_effective_max_health())
			health_changed.emit(health, get_effective_max_health())
		elif id == PowerupIds.GET_BIGGER:
			scale = Vector2(1.25, 1.25)
		elif id == PowerupIds.GET_SMALLER:
			scale = Vector2(0.75, 0.75)
	powerups_changed.emit(passive_powerups, active_powerup)


func clear_powerups() -> void:
	passive_powerups.clear()
	active_powerup          = ""
	_active_used_this_round = false
	_speed_surge_active     = false
	_speed_surge_timer      = 0.0
	_extra_jumps_used       = 0
	_lifesteal_hits         = 0
	_is_slowed              = false
	_slow_timer             = 0.0
	_is_stunned             = false
	_stun_timer             = 0.0
	_input_locked           = false
	_is_confused            = false
	_confusion_timer        = 0.0
	_is_invisible           = false
	_invisible_timer        = 0.0
	scale                   = Vector2(1.0, 1.0)
	if NetworkManager.is_online():
		_rpc_set_invisible.rpc(false)
	else:
		modulate.a = 1.0
	powerups_changed.emit(passive_powerups, active_powerup)


func reset_round_powerup_state() -> void:
	_active_used_this_round = false
	_speed_surge_active     = false
	_speed_surge_timer      = 0.0
	_extra_jumps_used       = 0
	_lifesteal_hits         = 0
	_is_slowed              = false
	_slow_timer             = 0.0
	_is_stunned             = false
	_stun_timer             = 0.0
	_input_locked           = false
	_is_confused            = false
	_confusion_timer        = 0.0
	_is_invisible           = false
	_invisible_timer        = 0.0
	if NetworkManager.is_online():
		_rpc_set_invisible.rpc(false)
	else:
		modulate.a = 1.0

# ============================================================
# POWERUP HELPERS & STATUS EFFECTS
# ============================================================

func _on_melee_hit_landed() -> void:
	if not is_multiplayer_authority():
		return
	if PowerupIds.LIFESTEAL not in passive_powerups:
		return
	var threshold := 4 - passive_powerups.count(PowerupIds.LIFESTEAL)  # 4 at 1 stack, 3 at 2 stacks
	_lifesteal_hits += 1
	if _lifesteal_hits >= threshold:
		_lifesteal_hits = 0
		health = mini(health + 1, get_effective_max_health())
		health_changed.emit(health, get_effective_max_health())


func apply_slow(duration: float) -> void:
	if not is_multiplayer_authority():
		return
	_is_slowed  = true
	_slow_timer = max(_slow_timer, duration)


func apply_stun(duration: float) -> void:
	if not is_multiplayer_authority():
		return
	_is_stunned   = true
	_stun_timer   = duration
	_input_locked = true


func apply_confusion(duration: float) -> void:
	if not is_multiplayer_authority():
		return
	_is_confused     = true
	_confusion_timer = max(_confusion_timer, duration)


func _find_nearest_player() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist   := INF
	for p in get_tree().get_nodes_in_group("player"):
		if p == self or p.is_ghost:
			continue
		var d := global_position.distance_to(p.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest      = p
	return nearest


func _find_player_by_peer_id(peer_id: int) -> Node2D:
	for p in get_tree().get_nodes_in_group("player"):
		if p.get_multiplayer_authority() == peer_id:
			return p
	return null


func _find_local_player() -> Node:
	for p in get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p
	return null


@rpc("authority", "call_local", "reliable")
func _rpc_set_invisible(invisible: bool) -> void:
	_is_invisible = invisible
	if is_multiplayer_authority():
		return  # local player always sees themselves at full opacity
	var local_player := _find_local_player()
	var has_hunter: bool = local_player != null and PowerupIds.GHOST_HUNTER in local_player.passive_powerups
	modulate.a = (0.4 if has_hunter else 0.0) if invisible else 1.0


@rpc("authority", "call_local", "reliable")
func _rpc_teleport_to(target_pos: Vector2) -> void:
	global_position = target_pos


@rpc("authority", "call_local", "reliable")
func _rpc_heart_reset() -> void:
	# Each peer sets health on the player they control
	for p in get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority() and not p.is_ghost:
			p.health = 1
			p.health_changed.emit(1, p.get_effective_max_health())

# ============================================================
# OUTFIT / VISUALS
# ============================================================

func get_outfit_preview_texture(outfit_index: int) -> Texture2D:
	return _outfit.get_preview_texture(outfit_index)


func get_outfit_options() -> Array:
	return _outfit.get_options()


func get_outfit_id() -> int:
	return outfit_id


func request_outfit_change(new_outfit_id: int) -> void:
	get_tree().get_root().get_node("Main").request_player_outfit_change(multiplayer.get_unique_id(), new_outfit_id)


func set_outfit_from_sync(new_outfit_id: int) -> void:
	outfit_id = _outfit.apply_visuals(new_outfit_id)
	_apply_rig_outfit_color(outfit_id)


func _apply_rig_outfit_color(new_outfit_id: int) -> void:
	if stick_rig == null or _outfit == null:
		return
	var options := _outfit.get_options()
	if options.is_empty():
		return
	var outfit := options[clampi(new_outfit_id, 0, options.size() - 1)] as Dictionary
	var accent := outfit.get("cape_primary", Color(0.1, 0.48, 0.95, 1.0)) as Color
	stick_rig.set_accent_color(accent)

# ============================================================
# NETWORKING
# ============================================================

func add_sync_peer(peer_id: int) -> void:
	if peer_id not in _sync_peers:
		_sync_peers.append(peer_id)


func remove_sync_peer(peer_id: int) -> void:
	_sync_peers.erase(peer_id)


func _send_state_sync() -> void:
	if not NetworkManager.is_online():
		return
	var shield_visible: bool = _shield_node.visible if _shield_node else false
	var visual_visible := true
	var visual_animation := str(animated_sprite.animation)
	if USE_STICK_RIG and stick_rig != null:
		visual_visible = stick_rig.visible
		visual_animation = str(stick_rig.current_animation)
	elif not USE_STICK_RIG:
		visual_visible = animated_sprite.visible
	if multiplayer.is_server():
		for pid in _sync_peers:
			_sync_state.rpc_id(pid, global_position, animated_sprite.flip_h,
					visual_animation, visible, visual_visible, shield_visible)
	else:
		_sync_state.rpc_id(1, global_position, animated_sprite.flip_h,
				visual_animation, visible, visual_visible, shield_visible)


@rpc("any_peer", "unreliable_ordered")
func _sync_state(pos: Vector2, flip: bool, anim: String, body_visible: bool, visual_visible: bool, shield_visible: bool) -> void:
	if is_multiplayer_authority():
		return
	global_position         = pos
	visible                 = body_visible
	animated_sprite.flip_h  = flip
	if animated_sprite.animation != anim:
		animated_sprite.play(anim)
	if USE_STICK_RIG and stick_rig != null:
		stick_rig.set_facing(-1 if flip else 1)
	_play_visual_animation(StringName(anim))
	_set_visual_visible(visual_visible)
	_shield_node.set_active(shield_visible)
	if multiplayer.is_server():
		var sender := multiplayer.get_remote_sender_id()
		for pid in _sync_peers:
			if pid != sender:
				_sync_state.rpc_id(pid, pos, flip, anim, body_visible, visual_visible, shield_visible)
