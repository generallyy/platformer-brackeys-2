extends Area2D

var speed := 400.0
var straight_distance := 64.0
var direction := 1
var thrower_peer_id := -1

var _traveled := 0.0
var _gravity_vel := 0.0
var _landed := false

func _process(delta: float) -> void:
	var move := Vector2.ZERO
	move.x = direction * speed * delta
	if _traveled < straight_distance:
		_traveled += speed * delta
	else:
		_gravity_vel += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
		move.y = _gravity_vel * delta
	position += move

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if NetworkManager.is_active() and body.get_multiplayer_authority() == thrower_peer_id:
			return
		body.take_damage(1, Vector2(direction * 100, -150))
		queue_free()
		return
	if body is CharacterBody2D or body.is_in_group("enemy"):
		return
	_land()

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hurtbox"):
		area.get_parent().take_damage(1)
		queue_free()

func _land() -> void:
	if _landed:
		return
	_landed = true
	set_process(false)
	await get_tree().create_timer(1.0).timeout
	queue_free()

func _on_screen_exited() -> void:
	queue_free()
