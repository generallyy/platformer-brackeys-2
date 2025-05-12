extends Node2D

@onready var pause_menu = $PauseMenu
@onready var level_container = $LevelContainer

func _ready():
	load_level("res://scenes/levels/Level1.tscn")
	pause_menu.visible = false
	

func load_level(path: String):
	free_children(level_container)

	var level = load(path).instantiate()
	level_container.add_child(level)

	# Optional: Move player to spawn point
	await get_tree().process_frame
	var spawn = level.get_node_or_null("PlayerSpawn")
	if spawn:
		$Player.global_position = spawn.global_position

func free_children(node: Node):
	for child in node.get_children():
		child.queue_free()
