extends Camera2D

var target_player: Node2D = null

## ParallaxBackground duplicates assigned exclusively to this cell (see
## main.gd:_setup_split_screen_cosmetics). Godot's built-in ParallaxBackground
## camera-autodetection can't find this camera (it lives inside a SubViewport,
## not in the duplicate's own scene-tree ancestry), so we drive scroll_offset
## directly instead.
var parallax_targets: Array = []


func _ready() -> void:
	# SubViewports don't inherit the world their parent branch of the tree lives in —
	# without this, this camera would render an empty, separate physics world instead
	# of the shared LevelContainer/players that live under Main.
	get_viewport().world_2d = get_tree().root.world_2d
	make_current()


func _physics_process(_delta: float) -> void:
	if is_instance_valid(target_player):
		global_position = target_player.global_position
	else:
		set_physics_process(false)
	for pb in parallax_targets:
		if is_instance_valid(pb):
			pb.scroll_offset = -global_position
