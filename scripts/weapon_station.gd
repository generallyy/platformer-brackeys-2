extends Area2D

@export var weapon_scene: PackedScene

var _weapon_name: String = "Weapon"
var _weapon_cooldown: float = 0.0
var _player_nearby: Node = null

func _ready() -> void:
	if weapon_scene == null:
		push_error("%s has no weapon_scene assigned" % name)
		$NameLabel.text = "Broken Station"
		$PromptLabel.visible = false
		return
	# Read name and cooldown directly from the weapon scene
	var temp := weapon_scene.instantiate()
	_weapon_name = temp.WEAPON_NAME
	_weapon_cooldown = temp.WEAPON_COOLDOWN
	var weapon_icon = temp.get_node("Visual")
	temp.remove_child(weapon_icon)
	temp.free()

	$NameLabel.text = _weapon_name
	$PromptLabel.visible = false
	var icon = $WeaponIcon
	icon.replace_by(weapon_icon)
	weapon_icon.position = Vector2(0, -25)
	icon.queue_free()

func _process(_delta: float) -> void:
	if weapon_scene == null:
		return
	if _player_nearby and Input.is_action_just_pressed("interact"):
		_player_nearby.equip_weapon(weapon_scene, _weapon_cooldown)
		$PromptLabel.text = "Equipped!"
		_show_equipped_flash()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if not body.is_multiplayer_authority():
		return
	_player_nearby = body
	$PromptLabel.text = "%s — Equip" % InputUtils.get_action_key("interact")
	$PromptLabel.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body == _player_nearby:
		_player_nearby = null
		$PromptLabel.visible = false

func _show_equipped_flash() -> void:
	await get_tree().create_timer(0.8).timeout
	if _player_nearby:
		$PromptLabel.text = "%s — Equip" % InputUtils.get_action_key("interact")
	else:
		$PromptLabel.visible = false
