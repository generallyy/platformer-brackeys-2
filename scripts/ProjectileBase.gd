extends Area2D
class_name ProjectileBase

# Weapon identity — override these in each subclass
var WEAPON_NAME := "Projectile"
var WEAPON_COOLDOWN := 0.0
var THROW_COUNT := 1        # how many to spawn per attack press
var MAX_SIMULTANEOUS := 1   # max in flight at once (only meaningful when RETURNS = true)
var RETURNS := false        # if true, player cooldown waits until projectile returns

# Public properties — set by spawner before add_child
var direction: int = 1
var thrower_peer_id: int = -1
var owner_node: Node2D = null   # singleplayer self-hit prevention
var damage: int = 1
var knockback := Vector2(100.0, -150.0)

# Private flight state
var _t := 0.0
var _origin := Vector2.ZERO
var _origin_captured := false
var _active := true

func _process(delta: float) -> void:
	if not _active:
		return
	if not _origin_captured:
		_origin = global_position
		_origin_captured = true
	_t += delta
	if _t >= _get_max_lifetime():
		_despawn()
		return
	global_position = _origin + _get_offset(_t)

# --- Virtual trajectory interface ---

## Returns the world-space offset from _origin at time t.
## direction should be baked into the x component by convention.
func _get_offset(_t_val: float) -> Vector2:
	return Vector2.ZERO

## Returns how many seconds this projectile lives before auto-despawning.
## Return INF for no lifetime limit (despawn only on hit or screen exit).
func _get_max_lifetime() -> float:
	return INF

## Called when the projectile hits a solid non-character body (terrain/platform).
## Default: despawn immediately.
func _on_landed() -> void:
	_despawn()

## Called when the projectile hits a character (player or enemy).
## Default: despawn immediately.
func _on_hit_character(_target: Node) -> void:
	_despawn()

# --- Shared collision handlers ---
# These are connected in each weapon's .tscn

func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	if body == owner_node:
		return
	if body.is_in_group("player"):
		if NetworkManager.is_active() and body.get_multiplayer_authority() == thrower_peer_id:
			return
		body.take_damage(damage, Vector2(direction * knockback.x, knockback.y))
		_on_hit_character(body)
		return
	if body is CharacterBody2D or body.is_in_group("enemy"):
		return
	_on_landed()

func _on_area_entered(area: Area2D) -> void:
	if not _active:
		return
	if area.is_in_group("enemy_hurtbox"):
		area.get_parent().take_damage(damage)
		_on_hit_character(area.get_parent())


func _despawn() -> void:
	if not _active:
		return
	_active = false
	set_process(false)
	queue_free()
