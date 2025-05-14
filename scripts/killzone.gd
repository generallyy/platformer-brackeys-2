extends Area2D

@onready var timer = $Timer

func _on_body_entered(_body):
	#unused(body) (not used but you can find a replicant)
	print("You died.")
	timer.start()


func _on_timer_timeout():
	get_tree().reload_current_scene()
