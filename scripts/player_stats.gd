class_name PlayerStats
extends Resource

# Movement
@export var speed: float = 200.0
@export var acceleration: float = 1400.0
@export var friction: float = 2400.0
@export var turn_acceleration: float = 2800.0
@export var air_acceleration: float = 900.0
@export var air_friction: float = 1200.0
@export var air_turn_acceleration: float = 1800.0

# Jump / Air
@export var jump_velocity: float = -300.0
@export var max_fall_speed: float = 400.0
@export var dbj_speed: float = -350.0
@export var dbj_boost_lockout: float = 0.2
@export var boost_dbj_lockout: float = 0.1

# Air Boost
@export var boost_speed: float = 300.0
@export var boost_duration: float = 0.2

# Dash
@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.05
@export var dash_cooldown: float = 0.5

# Combat / Hit
@export var knockback_duration: float = 0.35
@export var invuln_duration: float = 1.0
@export var melee_cooldown: float = 0.4
@export var kill_credit_window: float = 2.0

# Shield
@export var shield_max: float = 1.0
@export var shield_recharge_rate: float = 0.25

# Health
@export var max_health: int = 3

# Powerups
@export var speed_surge_speed: float = 400.0
@export var speed_surge_duration: float = 2.5

# Jump boost scale (applied per stack via pow(jump_boost_scale, n))
@export var jump_boost_scale: float = 1.35

# Misc
@export var mass: float = 1.0
@export var push_restitution: float = 0.0
@export var respawn_delay: float = 0.25
@export var weapon_spawn_offset: Vector2 = Vector2(8.0, -5.0)
@export var iframes_blink_interval: float = 0.2
@export var iframes_blink_threshold: float = 0.1
