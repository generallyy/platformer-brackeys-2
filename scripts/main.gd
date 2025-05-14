extends Node2D

@onready var pause_menu = $PauseMenu
@onready var level_container = $LevelContainer
@onready var loading_screen = $LoadingScreen


func _ready():
	load_level("res://scenes/levels/Level0.tscn")
	pause_menu.visible = false
	

func load_level(path: String):
	# loading screen iteration
	loading_screen.visible = true
	await get_tree().process_frame
	#await get_tree().create_timer(.5).timeout	# because i want you to see this
	
	free_children(level_container)

	var level = load(path).instantiate()
	level_container.add_child(level)

	# Optional: Move player to spawn point
	await get_tree().process_frame
	var spawn = level.get_node_or_null("PlayerSpawn")
	if spawn:
		$Player.global_position = spawn.global_position

	$Player/Camera2D.reset_smoothing()
	
	# optional delay, but why not
	await get_tree().create_timer(.5).timeout
	loading_screen.visible = false


func free_children(node: Node):
	for child in node.get_children():
		child.queue_free()
